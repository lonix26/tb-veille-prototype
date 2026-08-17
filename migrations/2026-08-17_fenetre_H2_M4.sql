-- =====================================================================
-- Migration du 17.08.2026 (5/5) — alignement de la fenêtre H2/M4
--
-- Constat du run 43 : les liaisons H2/M4 demandaient 2021-2023, mais les
-- contrôles qualité déterministes imposent la fenêtre d'historique >= 2023
-- (FENETRE_DEBUT). Les quatre observations 2021/2022 étaient donc
-- collectées puis écartées à chaque run (13 écartées au lieu de 9).
-- Le corps POST est réduit à 2023 — on ne demande pas ce que la chaîne
-- rejettera toujours.
--
-- Conséquence assumée, à énoncer au rapport : STATENT s'arrêtant à 2023,
-- H2 et M4 ne portent QU'UN SEUL point dans la fenêtre de trois ans.
-- L'écart entre runs ne pourra rien montrer avant la parution du
-- millésime 2024 par l'OFS. Limite de fraîcheur, pas de collecte.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_fenetre_H2_M4.sql
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE source_bindings
SET params = jsonb_set(params, '{_corps,query,0,selection,values}', '["2023"]'::jsonb),
    note   = note || ' Fenêtre réduite à 2023 le 17.08.2026 (alignement sur FENETRE_DEBUT des contrôles qualité — les millésimes 2021/2022 étaient systématiquement écartés).'
WHERE indicator_id IN ('H2','M4') AND statut = 'actif'
  AND url_base = 'https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px';

COMMIT;

\echo ''
\echo '--- Fenêtre H2/M4 réduite à 2023'
SELECT indicator_id,
       params->'_corps'->'query'->0->'selection'->'values' AS annees_demandees
FROM source_bindings WHERE indicator_id IN ('H2','M4') ORDER BY indicator_id;
