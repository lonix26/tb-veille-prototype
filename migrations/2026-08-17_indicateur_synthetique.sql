-- =====================================================================
-- Migration du 17.08.2026 — indicateur synthétique (engagement de la
-- demande de ratification, demande explicite de la séance 2)
--
-- Définition : part de la Suisse dans le commerce mondial d'articles
-- d'horlogerie (chapitre SH 91), calculée comme CHE / somme du panier de
-- déclarants de H3, par année. Un ratio, une seule source (H3), calculé
-- par vue — aucun modèle, aucune collecte nouvelle, reconstructible par
-- quiconque relit la requête.
--
-- Choix de conception, motivés :
--   1. H3 SEUL, pas H1/H3 : mêler le mensuel H1 et l'annuel H3
--      importerait l'écart constaté entre les deux points d'accès
--      Comtrade (H1 total 2023 ~25,7 mia USD contre H3 CHE 29,76 —
--      relevé du 17.08, cohérence de chaîne à documenter au § 12.5).
--      Même source, même convention, même millésime.
--   2. Périmètre honnête : le dénominateur est le PANIER DE DÉCLARANTS
--      de H3 (7 pays au complet en 2023-2024), pas « le monde ». La part
--      est donc une part du panier — dit tel quel, jamais surdéclaré.
--   3. Règle du déclarant le plus lent (leçon Chine, § 12.5) : la part
--      n'est calculée QUE si tous les déclarants attendus ont soumis
--      l'année. Sinon NULL, avec les manquants nommés — l'absence
--      s'énonce, elle ne se comble pas. Attendu à la création : la part
--      2025 est NULL, motif « CHN manquant ».
--
-- La vue ne s'écrit pas au registre (même principe que v_metriques : le
-- calculé n'entre pas dans la table des valeurs).
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_indicateur_synthetique.sql \
--     | tee ../annexe_5/indicateur_synthetique_2026-08-17.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW v_indicateur_synthetique AS
WITH h3 AS (
    SELECT period, geo, value, validation_status
    FROM v_current
    WHERE indicator_id = 'H3'
),
-- Le panier attendu : tout déclarant vu au moins une année dans H3.
attendus AS (
    SELECT DISTINCT geo FROM h3
),
par_annee AS (
    SELECT h.period,
           count(*)                                    AS nb_declarants,
           SUM(h.value)                                AS total_panier_usd,
           SUM(h.value) FILTER (WHERE h.geo = 'CHE')   AS che_usd,
           bool_and(h.validation_status IN ('valide_source','valide_humain')) AS tous_valides
    FROM h3 h
    GROUP BY h.period
),
manquants AS (
    SELECT p.period,
           string_agg(a.geo, ', ' ORDER BY a.geo)
             FILTER (WHERE a.geo NOT IN (SELECT geo FROM h3 WHERE period = p.period)) AS declarants_manquants
    FROM par_annee p CROSS JOIN attendus a
    GROUP BY p.period
)
SELECT p.period,
       (SELECT count(*) FROM attendus)                 AS nb_declarants_attendus,
       p.nb_declarants,
       ROUND(p.total_panier_usd / 1e9, 2)              AS total_panier_mia_usd,
       ROUND(p.che_usd / 1e9, 2)                       AS che_mia_usd,
       -- La part n'existe que si le panier est complet : la fraîcheur
       -- d'un panier est celle de son déclarant le plus lent.
       CASE WHEN p.nb_declarants = (SELECT count(*) FROM attendus)
              AND p.che_usd IS NOT NULL AND p.total_panier_usd > 0
            THEN ROUND(p.che_usd / p.total_panier_usd * 100, 2)
       END                                             AS part_suisse_pct,
       CASE WHEN p.nb_declarants < (SELECT count(*) FROM attendus)
            THEN 'part non calculable : déclarant(s) sans soumission pour ' || p.period
                 || ' — ' || COALESCE(m.declarants_manquants, '?')
                 || '. La fraîcheur d''un panier est celle de son déclarant le plus lent.'
            ELSE ''
       END                                             AS completude,
       p.tous_valides
FROM par_annee p
JOIN manquants m USING (period)
ORDER BY p.period;

COMMENT ON VIEW v_indicateur_synthetique IS
  'Indicateur synthétique (engagement de la ratification, séance 2) : part de la Suisse dans le commerce d''articles d''horlogerie (SH 91) du panier de déclarants H3. Calcul par vue, une seule source, part calculée uniquement à panier complet — sinon l''absence est énoncée avec les déclarants manquants (leçon Chine 2024, § 12.5).';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. La part suisse par année'
\echo '    Attendu : 2023 et 2024 calculées (~61 %), 2025 NULL avec CHN nommé manquant.'
SELECT * FROM v_indicateur_synthetique;

\echo ''
\echo '--- 2. Contrôle de cohérence manuel : 2023 = 29.76 / 48.51 = 61.35 % environ'
SELECT ROUND(29.76 / (29.76+4.79+2.12+3.10+6.96+1.07+0.71) * 100, 2) AS part_2023_recalculee_a_la_main;

\echo ''
\echo '--- 3. Le registre n''est pas touché (le calculé n''entre pas au registre)'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
