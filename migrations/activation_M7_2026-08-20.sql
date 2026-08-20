-- =====================================================================
-- Activation M7 — acte nominatif de l'étudiant, 20.08.2026
--
-- À exécuter UNIQUEMENT après la boucle de contrôle des six fenêtres
-- (fin de 2026-08-20_indicateur_M7_ted.sql) : six décomptes plausibles
-- vus. L'exécution vaut décision.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/activation_M7_2026-08-20.sql \
--     | tee ../annexe_5/activation_M7_2026-08-20.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE source_bindings
SET statut = 'actif', verifie_par = 'N. Castillo', verifie_le = '2026-08-20'
WHERE indicator_id = 'M7' AND statut = 'a_verifier';

COMMIT;

\echo ''
\echo '--- M7 : 7 fenêtres actives, nominatives, datées'
SELECT params->'_corps'->>'query' IS NOT NULL AS corps_present,
       mapping->>'periode_fixe' AS periode, statut, verifie_par
FROM source_bindings WHERE indicator_id = 'M7'
ORDER BY mapping->>'periode_fixe';
