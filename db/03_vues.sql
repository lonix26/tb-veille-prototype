-- =====================================================================
-- Vues de restitution et de contrôle
--
-- Deux familles. Les vues de RESTITUTION alimentent le tableau de bord.
-- Les vues de CONTRÔLE calculent des affirmations que le rapport faisait
-- jusqu'ici à la main — décompte des indicateurs, couverture des
-- questions de veille, taux de correction humaine. Elles existent pour
-- que le texte cite un résultat plutôt qu'une estimation.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Restitution
-- ---------------------------------------------------------------------

-- Dernière valeur retenue par indicateur / période / zone.
-- Le registre étant en ajout seul, « la valeur actuelle » est un calcul,
-- pas un état : c'est la dernière observation non rejetée.
CREATE VIEW v_current AS
SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo)
       iv.indicator_id,
       i.label            AS indicator_label,
       i.sector_code,
       i.category,
       i.unit,
       iv.period,
       iv.geo,
       iv.value,
       iv.validation_status,
       iv.obtained_by,
       iv.consensus_score,
       iv.raw_ref,
       s.organisation     AS source_organisation,
       s.url              AS source_url,
       iv.run_id,
       r.executed_at
FROM indicator_values iv
JOIN indicators i ON i.indicator_id = iv.indicator_id
JOIN sources    s ON s.source_id    = i.source_id
JOIN runs       r ON r.run_id       = iv.run_id
WHERE iv.validation_status <> 'rejete'
ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC;

COMMENT ON VIEW v_current IS
  'Ce que le tableau de bord affiche. Toute ligne porte son statut de validation et sa source : le décideur sait toujours ce qu''il regarde et d''où cela vient (E6).';

-- Historique complet des exécutions : la timeline de l'outil vivant.
CREATE VIEW v_run_history AS
SELECT iv.indicator_id, iv.period, iv.geo, iv.run_id, r.executed_at,
       iv.value, iv.validation_status
FROM indicator_values iv
JOIN runs r ON r.run_id = iv.run_id
ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id;

-- Écart entre deux exécutions successives pour une même observation.
-- C'est la matérialisation littérale de la consigne de séance 3 :
-- « exécuté aujourd'hui puis dans trois mois — l'écart constitue la tendance ».
CREATE VIEW v_ecart_entre_runs AS
SELECT indicator_id, period, geo, run_id, executed_at, value,
       LAG(value)   OVER w AS value_run_precedent,
       LAG(run_id)  OVER w AS run_precedent,
       CASE WHEN LAG(value) OVER w IS NULL OR LAG(value) OVER w = 0 THEN NULL
            ELSE ROUND((value - LAG(value) OVER w) / LAG(value) OVER w * 100, 2)
       END AS ecart_pct
FROM v_run_history
WINDOW w AS (PARTITION BY indicator_id, period, geo ORDER BY run_id);

COMMENT ON VIEW v_ecart_entre_runs IS
  'Un écart non nul signale une révision de la donnée par sa source entre deux collectes — information de veille en soi, invisible d''un dispositif qui écraserait ses valeurs.';

-- Vue « Contexte » (QV0) : le socle transversal, séparé des vues sectorielles.
CREATE VIEW v_contexte AS
SELECT * FROM v_current WHERE sector_code = 'transversal';

-- ---------------------------------------------------------------------
-- Métriques dérivées (RI2, RI4, RI5 du § 10.4.3)
--
-- Trois principes. Les métriques sont calculées en SQL, jamais par un
-- modèle — « les chiffres par le code ». Elles ne sont jamais écrites
-- dans indicator_values, dont la sémantique est « valeur observée d'une
-- source » : mêler le collecté et le calculé détruirait la traçabilité.
-- Et une métrique impossible à calculer vaut NULL, jamais une
-- approximation, la colonne « completude » en énonçant la raison.
-- ---------------------------------------------------------------------

-- Étiquette de la période homologue de l'année précédente. Le
-- rapprochement se fait par calcul d'étiquette et non par décalage de
-- douze rangs : sur une série trouée, un décalage positionnel comparerait
-- silencieusement juin à juillet. Ici, une période homologue absente
-- laisse le glissement à NULL — l'absence reste visible.
CREATE FUNCTION periode_annee_precedente(p TEXT)
RETURNS TEXT AS $$
BEGIN
    IF p ~ '^\d{4}$' THEN
        RETURN (p::int - 1)::text;
    ELSIF p ~ '^\d{4}-.+$' THEN
        RETURN (left(p, 4)::int - 1)::text || substr(p, 5);
    ELSE
        RETURN NULL;   -- format non reconnu : pas de rapprochement inventé
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE VIEW v_metriques AS
WITH base AS (
    SELECT c.indicator_id, c.indicator_label, c.sector_code, c.category, c.unit,
           c.period, c.geo, c.value, c.validation_status, c.obtained_by,
           c.source_organisation, c.source_url, c.raw_ref, c.run_id, c.executed_at,
           i.frequency, i.alert_threshold_pct
    FROM v_current c
    JOIN indicators i ON i.indicator_id = c.indicator_id
),
fenetres AS (
    SELECT b.*,
           LAG(b.value)  OVER w AS valeur_periode_precedente,
           LAG(b.period) OVER w AS periode_precedente,
           AVG(b.value)   OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period
                                ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS mm_12,
           COUNT(b.value) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period
                                ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS n_12,
           MIN(b.period)  OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period
                                ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS debut_12,
           AVG(b.value)   OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period
                                ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mm_4,
           COUNT(b.value) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period
                                ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS n_4,
           MIN(b.period)  OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period
                                ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS debut_4
    FROM base b
    WINDOW w AS (PARTITION BY b.indicator_id, b.geo ORDER BY b.period)
),
rapproche AS (
    SELECT f.*,
           periode_annee_precedente(f.period) AS periode_homologue,
           a.value                            AS valeur_annee_precedente,
           CASE f.frequency WHEN 'mensuelle' THEN f.mm_12  WHEN 'trimestrielle' THEN f.mm_4  END AS moyenne_mobile_annuelle,
           CASE f.frequency WHEN 'mensuelle' THEN f.n_12   WHEN 'trimestrielle' THEN f.n_4   END AS nb_points_moyenne,
           CASE f.frequency WHEN 'mensuelle' THEN 12       WHEN 'trimestrielle' THEN 4       END AS nb_points_attendus,
           CASE f.frequency WHEN 'mensuelle' THEN f.debut_12 WHEN 'trimestrielle' THEN f.debut_4 END AS debut_fenetre
    FROM fenetres f
    LEFT JOIN base a
           ON a.indicator_id = f.indicator_id
          AND a.geo          = f.geo
          AND a.period       = periode_annee_precedente(f.period)
),
calcule AS (
    SELECT r.*,
           CASE WHEN r.valeur_periode_precedente IS NULL OR r.valeur_periode_precedente = 0 THEN NULL
                ELSE ROUND((r.value - r.valeur_periode_precedente) / r.valeur_periode_precedente * 100, 2) END AS variation_periode_pct,
           CASE WHEN r.valeur_annee_precedente IS NULL OR r.valeur_annee_precedente = 0 THEN NULL
                ELSE ROUND((r.value - r.valeur_annee_precedente) / r.valeur_annee_precedente * 100, 2) END AS glissement_annuel_pct,
           CASE WHEN r.moyenne_mobile_annuelle IS NULL OR r.moyenne_mobile_annuelle = 0 THEN NULL
                ELSE ROUND((r.value - r.moyenne_mobile_annuelle) / r.moyenne_mobile_annuelle * 100, 2) END AS ecart_a_la_moyenne_pct
    FROM rapproche r
)
SELECT c.indicator_id, c.indicator_label, c.sector_code, c.category, c.frequency,
       c.unit, c.period, c.geo, c.value,
       c.periode_precedente, c.valeur_periode_precedente, c.variation_periode_pct,
       c.periode_homologue, c.valeur_annee_precedente, c.glissement_annuel_pct,
       ROUND(c.moyenne_mobile_annuelle, 2) AS moyenne_mobile_annuelle,
       c.nb_points_moyenne, c.nb_points_attendus, c.debut_fenetre, c.ecart_a_la_moyenne_pct,
       c.alert_threshold_pct AS seuil_materialite_pct,
       CASE
         WHEN c.alert_threshold_pct IS NULL       THEN 'seuil non configure'
         WHEN c.glissement_annuel_pct IS NOT NULL
              THEN CASE WHEN abs(c.glissement_annuel_pct) >= c.alert_threshold_pct
                        THEN 'franchi' ELSE 'sous le seuil' END
         WHEN c.variation_periode_pct IS NOT NULL
              THEN CASE WHEN abs(c.variation_periode_pct) >= c.alert_threshold_pct
                        THEN 'franchi (variation de periode, faute de glissement)'
                        ELSE 'sous le seuil (variation de periode, faute de glissement)' END
         ELSE 'indeterminable'
       END AS franchissement,
       c.validation_status, c.obtained_by, c.source_organisation, c.source_url,
       c.raw_ref, c.run_id, c.executed_at,
       trim(both ' ' FROM concat_ws(' · ',
         CASE WHEN c.periode_homologue IS NULL
              THEN 'glissement annuel impossible : format de periode non reconnu' END,
         CASE WHEN c.periode_homologue IS NOT NULL AND c.valeur_annee_precedente IS NULL
              THEN 'glissement annuel indisponible : periode ' || c.periode_homologue || ' absente du registre' END,
         CASE WHEN c.nb_points_attendus IS NULL
              THEN 'moyenne mobile annuelle non applicable : serie ' || c.frequency END,
         CASE WHEN c.nb_points_attendus IS NOT NULL AND c.nb_points_moyenne < c.nb_points_attendus
              THEN 'moyenne mobile partielle : ' || c.nb_points_moyenne || ' point(s) sur '
                   || c.nb_points_attendus || ', depuis ' || c.debut_fenetre END,
         CASE WHEN c.alert_threshold_pct IS NULL
              THEN 'seuil de materialite non configure (RI4 inapplicable)' END
       )) AS completude
FROM calcule c;

COMMENT ON VIEW v_metriques IS
  'Métriques exigées par RI2, RI4 et RI5, calculées de manière déterministe. Aucune valeur n''est écrite au registre : la vue hérite de la provenance de ses entrants. La colonne completude énonce toute métrique manquante et sa raison.';

CREATE VIEW v_dernier_point AS
SELECT DISTINCT ON (indicator_id, geo) *
FROM v_metriques
ORDER BY indicator_id, geo, period DESC;

COMMENT ON VIEW v_dernier_point IS
  'Dernière observation par indicateur et zone, avec ses métriques. C''est l''objet compact transmis au modèle pour le commentaire exécutif (§ 10.4.3).';

CREATE VIEW v_alertes_candidates AS
SELECT indicator_id, indicator_label, sector_code, period, geo, value, unit,
       glissement_annuel_pct, variation_periode_pct, seuil_materialite_pct,
       franchissement, validation_status,
       CASE WHEN validation_status IN ('valide_source','valide_humain') THEN true ELSE false END AS diffusable,
       CASE WHEN validation_status IN ('valide_source','valide_humain') THEN ''
            ELSE 'retenue : statut ' || validation_status || ' insuffisant pour une notification au decideur' END AS motif_de_retenue,
       source_organisation, source_url, raw_ref, completude
FROM v_metriques
WHERE franchissement LIKE 'franchi%'
ORDER BY sector_code, indicator_id, period DESC;

COMMENT ON VIEW v_alertes_candidates IS
  'Franchissements de seuil. « Candidates » et non « alertes » : la colonne diffusable applique RI5 — une valeur non validée ne remonte pas au décideur, mais reste visible ici avec son motif de retenue.';

-- ---------------------------------------------------------------------
-- Contrôle
-- ---------------------------------------------------------------------

-- Décompte du référentiel. À reporter tel quel dans le rapport (I-6).
CREATE VIEW v_bilan_referentiel AS
SELECT sector_code,
       COUNT(*)                                                              AS total,
       COUNT(*) FILTER (WHERE status = 'certifie')                           AS certifies,
       COUNT(*) FILTER (WHERE status = 'certifie' AND category = 'hard')     AS certifies_hard,
       COUNT(*) FILTER (WHERE status = 'certifie' AND category = 'composite') AS certifies_composite,
       COUNT(*) FILTER (WHERE status = 'a_confirmer')                        AS a_confirmer
FROM indicators
GROUP BY ROLLUP (sector_code)
ORDER BY sector_code NULLS LAST;

-- Couverture des questions de veille par secteur.
-- Rend calculable l'affirmation du § 8.4.5 (« chaque question de veille de
-- chaque secteur est couverte par au moins un indicateur certifié »), que
-- l'évaluation critique a trouvée fausse sur deux cas (I-9).
CREATE VIEW v_couverture_qv AS
SELECT s.code AS sector_code, q.code AS watch_question_code,
       COUNT(iwq.indicator_id)                                       AS nb_indicateurs,
       COUNT(iwq.indicator_id) FILTER (WHERE i.status = 'certifie')   AS nb_certifies,
       CASE
         WHEN COUNT(iwq.indicator_id) FILTER (WHERE i.status = 'certifie') > 0 THEN 'couverte'
         WHEN COUNT(iwq.indicator_id) > 0                                     THEN 'couverte_a_confirmer'
         ELSE 'non_couverte'
       END AS couverture
FROM sectors s
CROSS JOIN watch_questions q
LEFT JOIN indicators i               ON i.sector_code = s.code
LEFT JOIN indicator_watch_questions iwq ON iwq.indicator_id = i.indicator_id AND iwq.watch_question_code = q.code
WHERE (s.code = 'transversal') = (q.code = 'QV0')   -- QV0 ne concerne que le socle, et réciproquement
GROUP BY s.code, q.code
ORDER BY s.code, q.code;

-- Le cadre à deux niveaux, restitué : question générique, formulation
-- sectorielle, mécanisme causal, criticité, et couverture effective.
-- Une criticité « dominante » sans indicateur certifié est une lacune à
-- énoncer au rapport, pas à masquer.
CREATE VIEW v_instanciation_qv AS
SELECT swq.sector_code,
       s.label            AS sector_label,
       swq.watch_question_code,
       q.label            AS question_generique,
       swq.formulation    AS question_sectorielle,
       swq.mecanisme,
       swq.criticite,
       COUNT(iwq.indicator_id)                                     AS nb_indicateurs,
       COUNT(iwq.indicator_id) FILTER (WHERE i.status = 'certifie') AS nb_certifies
FROM sector_watch_questions swq
JOIN sectors        s ON s.code = swq.sector_code
JOIN watch_questions q ON q.code = swq.watch_question_code
LEFT JOIN indicators i ON i.sector_code = swq.sector_code
LEFT JOIN indicator_watch_questions iwq
       ON iwq.indicator_id = i.indicator_id
      AND iwq.watch_question_code = swq.watch_question_code
GROUP BY swq.sector_code, s.label, swq.watch_question_code, q.label,
         swq.formulation, swq.mecanisme, swq.criticite
ORDER BY swq.sector_code, swq.watch_question_code;

COMMENT ON VIEW v_instanciation_qv IS
  'Le cadre à deux niveaux, restitué. Une criticité « dominante » sans indicateur certifié est une lacune à énoncer au rapport, pas à masquer.';

-- Métrique de preuve du § 10.4.2 : taux de correction humaine sur le
-- pipeline composite. C'est cette valeur, observée dans la durée, qui
-- conditionne le passage d'un contrôle systématique à un contrôle par
-- exception. Tant qu'elle n'est pas mesurée, la bascule reste interdite.
CREATE VIEW v_taux_correction_humaine AS
SELECT indicator_id,
       COUNT(*)                                        AS items_traites,
       COUNT(*) FILTER (WHERE decision = 'accepte')     AS acceptes,
       COUNT(*) FILTER (WHERE decision = 'corrige')     AS corriges,
       COUNT(*) FILTER (WHERE decision = 'rejete')      AS rejetes,
       COUNT(*) FILTER (WHERE decision IS NULL)         AS en_attente,
       ROUND(
         COUNT(*) FILTER (WHERE decision IN ('corrige','rejete'))::numeric
         / NULLIF(COUNT(*) FILTER (WHERE decision IS NOT NULL), 0) * 100, 2
       ) AS taux_correction_pct
FROM validation_queue
GROUP BY indicator_id;

-- Taux d'invention par modèle sur la tâche d'identification de sources,
-- mesuré en régime d'exploitation par la couche 0 (§ 10.2).
CREATE VIEW v_fiabilite_decouverte AS
SELECT modele,
       COUNT(*) AS propositions_ecartees,
       COUNT(*) FILTER (WHERE statut_traitement = 'non_verifiable') AS urls_inexistantes
FROM discovery_log, LATERAL jsonb_array_elements_text(modeles_proposants) AS modele
GROUP BY modele
ORDER BY urls_inexistantes DESC;

-- Santé des exécutions : complétude de la collecte, run par run.
CREATE VIEW v_sante_des_runs AS
SELECT r.run_id, r.executed_at, r.status,
       COUNT(iv.value_id)                                                       AS valeurs_ecrites,
       COUNT(DISTINCT iv.indicator_id)                                          AS indicateurs_couverts,
       (SELECT COUNT(*) FROM indicators WHERE status = 'certifie')               AS indicateurs_certifies_attendus,
       COUNT(iv.value_id) FILTER (WHERE iv.validation_status = 'valide_source')  AS issues_de_source,
       COUNT(iv.value_id) FILTER (WHERE iv.obtained_by = 'ia_extraction')        AS issues_d_extraction_ia
FROM runs r
LEFT JOIN indicator_values iv ON iv.run_id = r.run_id
GROUP BY r.run_id, r.executed_at, r.status
ORDER BY r.run_id DESC;
