-- =====================================================================
-- Migration du 07.08.2026 — couche de métriques dérivées
--
-- Objet. Les règles d'interprétation du § 10.4.3 exigent des métriques
-- que rien ne calculait :
--
--   RI2 — la variation par rapport à la même période de l'année
--         précédente et la moyenne mobile sur douze mois, et non la
--         seule variation entre périodes consécutives ;
--   RI4 — le seuil de matérialité propre à l'indicateur ;
--   RI5 — le statut de validation joint à toute valeur restituée.
--
-- Ces règles étaient spécifiées et non implémentées : le rapport
-- affirmait un contrôle que le dispositif n'exerçait pas. Cette
-- migration clôt cet écart.
--
-- Trois principes de conception, tous dictés par la thèse du travail.
--
--   1. DÉTERMINISME. Les métriques sont calculées en SQL, jamais par un
--      modèle de langage — « les chiffres par le code ». Elles sont
--      reconstructibles à l'identique par quiconque relit la vue.
--
--   2. SÉPARATION DU COLLECTÉ ET DU CALCULÉ. Rien n'est écrit dans
--      indicator_values. Cette table a une sémantique — une valeur
--      observée, obtenue d'une source, avec sa pièce d'audit — et y
--      insérer un calcul détruirait la traçabilité qui fonde le
--      dispositif. Les métriques sont des VUES : elles héritent de la
--      provenance de leurs entrants et ne peuvent pas s'en détacher.
--
--   3. L'ABSENCE SE DIT. Une métrique impossible à calculer vaut NULL,
--      jamais une valeur approchée, et la colonne « completude » en
--      énonce la raison en clair. C'est l'application littérale de la
--      règle du § 10.4.3 : quand une métrique requise manque, il faut le
--      dire plutôt que conclure.
--
-- Emplacement. Hors de db/, donc hors du répertoire d'initialisation
-- automatique : à ne pas rejouer sur une base neuve, où 03_vues.sql
-- produit le même état. Indépendante de la migration de scission des
-- questions de veille — l'ordre entre les deux est indifférent.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-07_metriques_derivees.sql
--
-- Non destructive : aucune écriture, uniquement des créations de vues.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Étiquette de la période homologue de l'année précédente
--
-- Le rapprochement se fait par CALCUL D'ÉTIQUETTE, non par décalage de
-- douze rangs. La différence est essentielle : un décalage positionnel
-- appliqué à une série trouée compare silencieusement juin à juillet,
-- et produit un chiffre faux d'apparence normale. Ici, si la période
-- homologue est absente du registre, la jointure ne trouve rien et le
-- glissement vaut NULL — l'absence est visible.
--
-- Formats admis : '2025', '2026-06', '2026-T1', '2026-S1'.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION periode_annee_precedente(p TEXT)
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

COMMENT ON FUNCTION periode_annee_precedente(TEXT) IS
  'Étiquette de la période homologue de l''année précédente. Renvoie NULL sur un format non reconnu plutôt que de deviner.';

-- ---------------------------------------------------------------------
-- 2. Métriques dérivées, période par période
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_metriques AS
WITH base AS (
    SELECT c.indicator_id,
           c.indicator_label,
           c.sector_code,
           c.category,
           c.unit,
           c.period,
           c.geo,
           c.value,
           c.validation_status,
           c.obtained_by,
           c.source_organisation,
           c.source_url,
           c.raw_ref,
           c.run_id,
           c.executed_at,
           i.frequency,
           i.alert_threshold_pct
    FROM v_current c
    JOIN indicators i ON i.indicator_id = c.indicator_id
),
fenetres AS (
    SELECT b.*,
           LAG(b.value)  OVER w AS valeur_periode_precedente,
           LAG(b.period) OVER w AS periode_precedente,
           -- Deux fenêtres calculées d'office ; la fréquence tranche
           -- ensuite laquelle a un sens. Une moyenne sur douze mois n'en
           -- a aucun sur une série annuelle.
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
           CASE f.frequency
               WHEN 'mensuelle'     THEN f.mm_12
               WHEN 'trimestrielle' THEN f.mm_4
           END AS moyenne_mobile_annuelle,
           CASE f.frequency
               WHEN 'mensuelle'     THEN f.n_12
               WHEN 'trimestrielle' THEN f.n_4
           END AS nb_points_moyenne,
           CASE f.frequency
               WHEN 'mensuelle'     THEN 12
               WHEN 'trimestrielle' THEN 4
           END AS nb_points_attendus,
           CASE f.frequency
               WHEN 'mensuelle'     THEN f.debut_12
               WHEN 'trimestrielle' THEN f.debut_4
           END AS debut_fenetre
    FROM fenetres f
    LEFT JOIN base a
           ON a.indicator_id = f.indicator_id
          AND a.geo          = f.geo
          AND a.period       = periode_annee_precedente(f.period)
),
calcule AS (
    SELECT r.*,
           CASE WHEN r.valeur_periode_precedente IS NULL
                  OR r.valeur_periode_precedente = 0 THEN NULL
                ELSE ROUND((r.value - r.valeur_periode_precedente)
                           / r.valeur_periode_precedente * 100, 2)
           END AS variation_periode_pct,
           CASE WHEN r.valeur_annee_precedente IS NULL
                  OR r.valeur_annee_precedente = 0 THEN NULL
                ELSE ROUND((r.value - r.valeur_annee_precedente)
                           / r.valeur_annee_precedente * 100, 2)
           END AS glissement_annuel_pct,
           CASE WHEN r.moyenne_mobile_annuelle IS NULL
                  OR r.moyenne_mobile_annuelle = 0 THEN NULL
                ELSE ROUND((r.value - r.moyenne_mobile_annuelle)
                           / r.moyenne_mobile_annuelle * 100, 2)
           END AS ecart_a_la_moyenne_pct
    FROM rapproche r
)
SELECT c.indicator_id,
       c.indicator_label,
       c.sector_code,
       c.category,
       c.frequency,
       c.unit,
       c.period,
       c.geo,
       c.value,

       -- RI2, premier volet : variation entre périodes consécutives
       c.periode_precedente,
       c.valeur_periode_precedente,
       c.variation_periode_pct,

       -- RI2, deuxième volet : glissement annuel, par rapprochement
       -- d'étiquette et non par décalage de rangs
       c.periode_homologue,
       c.valeur_annee_precedente,
       c.glissement_annuel_pct,

       -- RI2, troisième volet : moyenne mobile annuelle
       ROUND(c.moyenne_mobile_annuelle, 2) AS moyenne_mobile_annuelle,
       c.nb_points_moyenne,
       c.nb_points_attendus,
       c.debut_fenetre,
       c.ecart_a_la_moyenne_pct,

       -- RI4 : seuil de matérialité et son franchissement
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

       -- RI5 : la valeur ne circule jamais sans son statut ni sa source
       c.validation_status,
       c.obtained_by,
       c.source_organisation,
       c.source_url,
       c.raw_ref,
       c.run_id,
       c.executed_at,

       -- Ce qui manque, énoncé plutôt que dissimulé. Une chaîne vide
       -- signifie que toutes les métriques exigées par RI2 et RI4 sont
       -- disponibles pour cette observation.
       trim(both ' ' FROM concat_ws(' · ',
         CASE WHEN c.periode_homologue IS NULL
              THEN 'glissement annuel impossible : format de periode non reconnu' END,
         CASE WHEN c.periode_homologue IS NOT NULL AND c.valeur_annee_precedente IS NULL
              THEN 'glissement annuel indisponible : periode ' || c.periode_homologue
                   || ' absente du registre' END,
         CASE WHEN c.nb_points_attendus IS NULL
              THEN 'moyenne mobile annuelle non applicable : serie ' || c.frequency END,
         CASE WHEN c.nb_points_attendus IS NOT NULL
                   AND c.nb_points_moyenne < c.nb_points_attendus
              THEN 'moyenne mobile partielle : ' || c.nb_points_moyenne || ' point(s) sur '
                   || c.nb_points_attendus || ', depuis ' || c.debut_fenetre END,
         CASE WHEN c.alert_threshold_pct IS NULL
              THEN 'seuil de materialite non configure (RI4 inapplicable)' END
       )) AS completude
FROM calcule c;

COMMENT ON VIEW v_metriques IS
  'Métriques exigées par RI2, RI4 et RI5, calculées de manière déterministe. Aucune valeur n''est écrite au registre : la vue hérite de la provenance de ses entrants. La colonne completude énonce toute métrique manquante et sa raison — l''absence se dit, elle ne se comble pas.';

-- ---------------------------------------------------------------------
-- 3. Dernier point connu par indicateur — ce que lit la restitution
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_dernier_point AS
SELECT DISTINCT ON (indicator_id, geo) *
FROM v_metriques
ORDER BY indicator_id, geo, period DESC;

COMMENT ON VIEW v_dernier_point IS
  'Dernière observation par indicateur et zone, avec ses métriques. C''est l''objet compact que la couche d''analyse transmet au modèle pour le commentaire exécutif (§ 10.4.3).';

-- ---------------------------------------------------------------------
-- 4. Franchissements de seuil — alertes candidates
--
-- Candidates, et non alertes : une valeur qui n'a pas atteint un statut
-- de validation suffisant ne doit pas déclencher de notification au
-- décideur. La colonne diffusable tranche, la vue ne filtre pas — ce
-- qui est écarté reste visible.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_alertes_candidates AS
SELECT indicator_id,
       indicator_label,
       sector_code,
       period,
       geo,
       value,
       unit,
       glissement_annuel_pct,
       variation_periode_pct,
       seuil_materialite_pct,
       franchissement,
       validation_status,
       CASE WHEN validation_status IN ('valide_source','valide_humain') THEN true
            ELSE false END AS diffusable,
       CASE WHEN validation_status IN ('valide_source','valide_humain') THEN ''
            ELSE 'retenue : statut ' || validation_status
                 || ' insuffisant pour une notification au decideur' END AS motif_de_retenue,
       source_organisation,
       source_url,
       raw_ref,
       completude
FROM v_metriques
WHERE franchissement LIKE 'franchi%'
ORDER BY sector_code, indicator_id, period DESC;

COMMENT ON VIEW v_alertes_candidates IS
  'Franchissements de seuil. « Candidates » et non « alertes » : la colonne diffusable applique RI5 — une valeur non validée ne remonte pas au décideur, mais reste visible ici avec son motif de retenue.';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. La fonction de rapprochement de periode'
\echo '    Attendu : 2024 | 2025-06 | 2025-T1 | (null)'
SELECT periode_annee_precedente('2025')    AS annuel,
       periode_annee_precedente('2026-06') AS mensuel,
       periode_annee_precedente('2026-T1') AS trimestriel,
       periode_annee_precedente('juin')    AS format_inconnu;

\echo ''
\echo '--- 2. Metriques sur l''indicateur pilote A5 — douze derniers points'
\echo '    Attendu : glissement annuel renseigne des que 2024-01,'
\echo '    moyenne mobile complete (12/12) des que douze points sont disponibles.'
SELECT period, value, variation_periode_pct, glissement_annuel_pct,
       moyenne_mobile_annuelle, nb_points_moyenne || '/' || nb_points_attendus AS fenetre,
       franchissement
FROM v_metriques
WHERE indicator_id = 'A5'
ORDER BY period DESC
LIMIT 12;

\echo ''
\echo '--- 3. Observations dont une metrique exigee manque, et pourquoi'
SELECT indicator_id, period, completude
FROM v_metriques
WHERE completude <> ''
ORDER BY indicator_id, period
LIMIT 20;

\echo ''
\echo '--- 4. Franchissements de seuil, et lesquels sont diffusables'
SELECT indicator_id, period, glissement_annuel_pct, seuil_materialite_pct,
       validation_status, diffusable, motif_de_retenue
FROM v_alertes_candidates;

\echo ''
\echo '--- 5. Le registre n''a pas ete touche'
\echo '    Attendu : le meme nombre qu''avant la migration.'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
