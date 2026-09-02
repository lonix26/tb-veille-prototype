-- =====================================================================
-- A7 — LES TEXTES DE LA BASE ALIGNÉS SUR LA BASE — 02.09.2026
--
-- Item A7 du plan de correction (evaluation_critique_prototype_2026-09-02.md,
-- § 5, constats BD-2, BD-3, BD-7, BD-11). Quatre textes portés par la
-- base contredisaient ce que la base contient. Un texte qui contredit la
-- base est la faute que le § 7.2.2 du rapport s'interdit ; il est corrigé
-- ici, et la base fait foi.
--
-- 1. M6 (BD-3). La note disait « seuil laissé nul à dessein, RI4
--    inapplicable » ; la base porte 22 depuis le calibrage du 31.08. M6
--    est lu sur le MÊME jeu OCDE qu'A7 (DSD_PATENTS, dimension PRIORITY,
--    même clé à la technologie près) : la troncature des deux dernières
--    années par date de priorité, déclarée pour A7 le 01.09, s'applique
--    par construction. Sur la série : moyenne des six pays 1 794 → 1 813
--    → 1 677 → 1 361 de 2019 à 2022, soit -7 % puis -19 % ; les six
--    pays baissent ensemble en 2022 (de -16 % à -32 %), 2021 est mêlé
--    (trois hausses, trois baisses). La série prouve nettement 2022 et
--    faiblement 2021 ; la déclaration suit le MÉCANISME de la source,
--    identique à celui d'A7, et non la seule lecture de la série —
--    décision d'étudiant, à ratifier. Le seuil est recalibré sur les
--    périodes complètes (≤ 2020) par la méthode du 10.08 : n = 36 ·
--    moyenne 8,9 % · p90 20,7 % · max 61,5 % → 20 (le 22 du 31.08
--    incluait 2021-2022, tronquées). Vérifié avant d'écrire : la même
--    requête reproduit les chiffres d'A7 du 01.09 (n = 36, p90 38,1).
--    Effet attendu : les deux « franchi » de M6 (CHE 2022 -31,64 %,
--    FRA 2022 -25,89 %) deviennent « non signalé : période en
--    consolidation » ; la valeur reste au registre.
--
-- 2. H2 / H12 (BD-11). La note de H2 affirmait que les observations
--    STATENT « ont été réattribuées à H12 » ; celle de H12 dit qu'elles
--    « n'ont PAS été déplacées ». Tranché par requête : 56 lignes
--    etl/valide_source, runs 43-161, sont toujours sous H2 (le registre
--    en ajout seul a refusé la réattribution, D-18). H12 disait vrai ;
--    H2 est corrigé. La note de H12 est inchangée.
--
-- 3. sante_a_la_date() (BD-7). Le commentaire disait « identique à
--    v_sante_secteur » ; la fonction filtrait status = 'certifie' quand
--    la vue filtre en_vitrine (élagage du 25-26.08, postérieur à la
--    fonction du 25.08 au matin). Sur l'horlogerie : 0,71 par la vue,
--    0,93 par la fonction, les deux servis par l'API (v_sante_secteur et
--    v_sante_ecart). Le prédicat est aligné sur en_vitrine ; le
--    commentaire devient vrai. La colonne indicateurs_certifies de
--    v_sante_secteur compte les indicateurs EN VITRINE : elle n'est pas
--    renommée (une vue ne se renomme pas par CREATE OR REPLACE, et
--    l'écran la lit) mais commentée ; l'écran dit « en vitrine ».
--
-- 4. v_ecart_entre_runs (BD-2). Le commentaire attribuait tout écart à
--    « une révision de la donnée par sa source ». Vérifié ligne à ligne
--    sur les écarts non nuls : H2 (11 écarts, +13 à +15 %) est le
--    changement de source STATENT → Convention patronale, sous le même
--    identifiant ; A1 (28) sont des ré-extractions par modèle du même
--    document ; M3 2023 WORLD (+143,6 %) est une valeur erronée depuis
--    rejetée (A4) ; A5, M2, H1, T6, T8 (écarts de l'ordre du pour-cent,
--    même collecteur, même liaison) sont compatibles avec une révision
--    par la source — PRÉSUMÉE, la vue ne peut pas le prouver. La vue
--    reçoit une colonne nature_ecart qui distingue ces quatre cas par
--    ce que le registre sait (statut, collecteur) ; v_run_history expose
--    obtained_by pour le permettre. Colonnes ajoutées en fin de liste :
--    aucun consommateur existant ne change de forme.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ---------------------------------------------------------------------
-- 1. M6 — seuil, périodes en consolidation, note
-- ---------------------------------------------------------------------

\echo '== 1. M6 : contrôle de la méthode (A7 doit redonner n = 36, p90 38,1)'
SELECT indicator_id, count(*) AS n,
       round(avg(abs(glissement_annuel_pct)), 1) AS moyenne,
       round(percentile_cont(0.9) WITHIN GROUP (ORDER BY abs(glissement_annuel_pct))::numeric, 1) AS p90,
       round(max(abs(glissement_annuel_pct)), 1) AS max
  FROM v_metriques
 WHERE indicator_id IN ('A7', 'M6') AND period <= '2020' AND glissement_annuel_pct IS NOT NULL
 GROUP BY indicator_id ORDER BY indicator_id;

\echo '== 1. M6 : avant'
SELECT geo, period, glissement_annuel_pct, franchissement
  FROM v_metriques WHERE indicator_id = 'M6' AND period >= '2021' ORDER BY geo, period;

UPDATE indicators
   SET periodes_incompletes_source = 2,
       alert_threshold_pct = 20,
       note_conception = 'Zone de référence CHE : ce qui intéresse un atelier neuchâtelois est la vitalité technologique de son écosystème.

SEUIL DE MATÉRIALITÉ 20 % (recalibré le 02.09.2026 sur les périodes complètes, n = 36, p90 20,7 %, méthode du 10.08). Le calibrage du 31.08 (22 %) incluait les deux dernières années, tronquées à la source. La note disait jusqu''au 02.09 « seuil laissé nul à dessein » : le texte contredisait la base, il est réécrit.

DEUX DERNIÈRES PÉRIODES EN CONSOLIDATION, déclarées le 02.09.2026 : même jeu OCDE qu''A7 (DSD_PATENTS, comptage par date de priorité, publication dix-huit mois plus tard), donc même troncature par construction. Sur la série, la moyenne des six pays fait 1 813 → 1 677 → 1 361 de 2020 à 2022 (-7 % puis -19 %) ; les six pays baissent ensemble en 2022, 2021 est mêlé. La déclaration suit le mécanisme de la source, pas seulement la série — décision d''étudiant, à ratifier. Sur ces périodes la valeur reste au registre, rien n''est signalé (RI4 différé).

CHANGEMENT DE SOURCE le 25.08.2026 : déclaré sur l''OMPI depuis le 06.08 et jamais collecté, faute de point d''accès programmable libre chez ce producteur. L''OCDE publie le même objet en API SDMX sans clé.

HORS SCORE DE SANTÉ, par construction et non par élagage : le dernier point disponible est 2022. Un score de position cyclique calculé sur une série qui s''arrête quatre ans plus tôt figerait la position du secteur sur un état périmé. L''indicateur répond à QV4 et à elle seule.

HORS VITRINE le 25.08.2026 — dernier point en 2022 : la source publie avec un retard qui la rend inutilisable en conjoncture.'
 WHERE indicator_id = 'M6';

\echo '== 1. M6 : après (attendu : 2021 et 2022 « non signale : periode en consolidation »)'
SELECT geo, period, glissement_annuel_pct, franchissement, periode_en_consolidation
  FROM v_metriques WHERE indicator_id = 'M6' AND period >= '2021' ORDER BY geo, period;

-- ---------------------------------------------------------------------
-- 2. H2 — la note dit ce que le registre contient
-- ---------------------------------------------------------------------

\echo '== 2. H2 : où sont les 56 lignes STATENT (attendu : sous H2, etl/valide_source, runs 43-161)'
SELECT indicator_id, obtained_by, validation_status, min(run_id), max(run_id), count(*)
  FROM indicator_values WHERE indicator_id IN ('H2', 'H12') AND obtained_by = 'etl'
 GROUP BY 1, 2, 3 ORDER BY 1;

UPDATE indicators
   SET note_conception = replace(note_conception,
       'Les observations STATENT antérieures ont été réattribuées à H12, jamais supprimées.',
       'Les 56 observations STATENT antérieures (runs 43-161) RESTENT sous H2 : le registre est en ajout seul (D-18) et le déclencheur a refusé la réattribution. Elles sont l''histoire d''avant la redéfinition ; la collecte STATENT se poursuit sous H12, qui a reçu la liaison. La note disait jusqu''au 02.09 « réattribuées à H12 » : c''était faux, H12 disait vrai.')
 WHERE indicator_id = 'H2';

\echo '== 2. H2 : la note ne porte plus l''affirmation fausse (attendu : 0 puis 1)'
-- Le contrôle cherche l'affirmation « ont été réattribuées », pas la
-- citation « réattribuées à H12 » que la correction reprend entre
-- guillemets (première exécution : le contrôle comptait la citation).
SELECT count(*) FILTER (WHERE note_conception ~ 'ont été réattribuées') AS reste,
       count(*) FILTER (WHERE note_conception ~ 'RESTENT sous H2') AS corrige
  FROM indicators WHERE indicator_id = 'H2';

-- ---------------------------------------------------------------------
-- 3. sante_a_la_date() — même périmètre que v_sante_secteur
-- ---------------------------------------------------------------------

\echo '== 3. Santé : avant (horlogerie attendue 0,71 par la vue, 0,93 par la fonction)'
SELECT 'v_sante_secteur' AS objet, sector_code, score_sante AS score, indicateurs FROM v_sante_secteur
UNION ALL
SELECT 'sante_a_la_date', sector_code, score, NULL FROM sante_a_la_date(now())
ORDER BY 2, 1;

CREATE OR REPLACE FUNCTION sante_a_la_date(p_limite timestamptz)
RETURNS TABLE(sector_code text, n_series bigint, score numeric)
LANGUAGE sql STABLE AS $$
  WITH courant AS (
    SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo)
           iv.indicator_id, iv.period, iv.geo, iv.value
      FROM indicator_values iv
     WHERE iv.validation_status = ANY (ARRAY['valide_source','pre_valide_consensus','valide_humain'])
       AND iv.collected_at <= p_limite
     ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC
  ), rang AS (
    SELECT c.indicator_id, c.period, c.value,
           row_number() OVER (PARTITION BY c.indicator_id ORDER BY c.period)::numeric AS t
      FROM courant c
      JOIN indicators i ON i.indicator_id = c.indicator_id
                       AND i.geo_reference IS NOT NULL AND c.geo = i.geo_reference
  ), droite AS (
    SELECT rang.indicator_id,
           regr_slope(rang.value::double precision, rang.t::double precision)     AS pente,
           regr_intercept(rang.value::double precision, rang.t::double precision) AS ordonnee,
           count(*) AS n_points
      FROM rang GROUP BY rang.indicator_id
  ), residus AS (
    SELECT r.indicator_id, r.t,
           r.value::double precision - (d.ordonnee + d.pente * r.t::double precision) AS residu
      FROM rang r JOIN droite d USING (indicator_id)
  ), resume AS (
    SELECT re.indicator_id,
           stddev_samp(re.residu)::numeric AS sd_residu,
           (array_agg(re.residu ORDER BY re.t DESC))[1]::numeric AS dernier_residu
      FROM residus re GROUP BY re.indicator_id
  ), par_indicateur AS (
    SELECT i.sector_code, i.indicator_id,
           r.dernier_residu / NULLIF(r.sd_residu, 0) * i.sens_favorable::numeric AS z
      FROM resume r JOIN droite d USING (indicator_id) JOIN indicators i USING (indicator_id)
     -- 02.09.2026 (A7) : en_vitrine, comme v_sante_secteur — la fonction
     -- filtrait status = 'certifie' et servait un autre score que la vue.
     WHERE i.sens_favorable IN (-1, 1) AND i.en_vitrine
       AND r.sd_residu IS NOT NULL AND r.sd_residu > 0 AND d.n_points >= 8
  )
  SELECT p.sector_code, count(*),
         CASE WHEN count(*) >= 2 THEN round(avg(p.z), 2) END
    FROM par_indicateur p GROUP BY p.sector_code;
$$;

COMMENT ON FUNCTION sante_a_la_date(timestamptz) IS
'Score de santé sectorielle tel qu''il était à une date donnée : même calcul et même périmètre (indicateurs en vitrine, orientables, ≥ 8 points) que v_sante_secteur, borné aux observations collectées avant cette date. Le registre étant en ajout seul, l''état passé est intact : ce n''est pas une reconstitution. Jusqu''au 02.09.2026 la fonction filtrait status = ''certifie'' et servait un autre score que la vue (horlogerie 0,93 contre 0,71) ; aligné le 02.09 (A7).';

COMMENT ON COLUMN v_sante_secteur.indicateurs_certifies IS
'Nombre d''indicateurs EN VITRINE du secteur (en_vitrine), pas de certifiés : le nom date d''avant l''élagage du 25-26.08.2026 et n''a pas été changé parce que la restitution le lit. L''écran dit « en vitrine ».';

\echo '== 3. Santé : après (attendu : même score par les deux objets)'
SELECT v.sector_code, v.score_sante AS vue, f.score AS fonction,
       CASE WHEN v.score_sante IS NOT DISTINCT FROM f.score THEN 'ok' ELSE 'ECART' END AS controle
  FROM v_sante_secteur v FULL JOIN sante_a_la_date(now()) f USING (sector_code)
 ORDER BY 1;

-- ---------------------------------------------------------------------
-- 4. v_ecart_entre_runs — la nature de l'écart, par ce que le registre sait
-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW v_run_history AS
 SELECT iv.indicator_id, iv.period, iv.geo, iv.run_id, r.executed_at, iv.value,
        iv.validation_status,
        iv.obtained_by   -- 02.09.2026 (A7) : pour qualifier les écarts
   FROM indicator_values iv JOIN runs r ON r.run_id = iv.run_id
  ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id;

CREATE OR REPLACE VIEW v_ecart_entre_runs AS
 SELECT indicator_id, period, geo, run_id, executed_at, value,
        lag(value) OVER w  AS value_run_precedent,
        lag(run_id) OVER w AS run_precedent,
        CASE WHEN lag(value) OVER w IS NULL OR lag(value) OVER w = 0 THEN NULL
             ELSE round((value - lag(value) OVER w) / lag(value) OVER w * 100, 2) END AS ecart_pct,
        -- 02.09.2026 (A7). Ce que le registre SAIT de l'écart, du plus
        -- certain au moins certain ; la révision par la source n'est
        -- jamais prouvée par la vue, seulement présumée par élimination.
        CASE WHEN lag(value) OVER w IS NULL THEN NULL
             WHEN validation_status = 'rejete' OR lag(validation_status) OVER w = 'rejete'
                  THEN 'valeur rejetee au registre'
             WHEN obtained_by IS DISTINCT FROM lag(obtained_by) OVER w
                  THEN 'changement de collecteur ou de source'
             WHEN obtained_by = 'ia_extraction'
                  THEN 're-extraction par modele'
             ELSE 'revision par la source (presumee)' END AS nature_ecart
   FROM v_run_history
 WINDOW w AS (PARTITION BY indicator_id, period, geo ORDER BY run_id);

COMMENT ON VIEW v_ecart_entre_runs IS
'Écart entre deux collectes successives d''une même valeur (indicateur, période, zone). Un écart non nul est une information de veille, invisible d''un dispositif qui écraserait ses valeurs — mais il n''est PAS toujours une révision par la source : nature_ecart le qualifie par ce que le registre sait (valeur rejetée, changement de collecteur ou de source sous le même identifiant, ré-extraction par modèle) ; la révision par la source n''est que le cas résiduel, présumé. Vérifié le 02.09.2026 : H2 (+13 à +15 %) est le passage STATENT → Convention patronale, A1 des ré-extractions, M3 2023 une valeur rejetée ; seuls A5, M2, H1, T6, T8 (même collecteur, écarts de l''ordre du pour-cent) sont compatibles avec une révision.';

\echo '== 4. Écarts non nuls par nature (attendu : H2 = changement de collecteur, A1 = re-extraction, M3 = rejetee)'
SELECT nature_ecart, string_agg(indicator_id || ' ×' || n, ', ' ORDER BY indicator_id) AS detail, sum(n) AS total
  FROM (SELECT nature_ecart, indicator_id, count(*) AS n FROM v_ecart_entre_runs
         WHERE ecart_pct IS NOT NULL AND ecart_pct <> 0 GROUP BY 1, 2) x
 GROUP BY 1 ORDER BY 1;

COMMIT;

\echo '== Bilan : notes et paramètres après A7'
SELECT indicator_id, alert_threshold_pct, periodes_incompletes_source, status, en_vitrine,
       left(regexp_replace(note_conception, E'\\s+', ' ', 'g'), 110) AS note
  FROM indicators WHERE indicator_id IN ('M6', 'A7', 'H2', 'H12') ORDER BY 1;
