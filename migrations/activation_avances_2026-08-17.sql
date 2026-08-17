-- =====================================================================
-- Activation T5 / T6 — acte nominatif de l'étudiant
--
-- À exécuter UNIQUEMENT après avoir vu les deux réponses réelles filtrées
-- (commandes en fin de 2026-08-17_indicateurs_avances.sql). L'exécution
-- vaut : certification des deux indicateurs ET activation des liaisons.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/activation_avances_2026-08-17.sql \
--     | tee ../annexe_5/activation_avances_2026-08-17.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE indicators SET status = 'certifie'
WHERE indicator_id IN ('T5','T6') AND status = 'a_confirmer';

UPDATE sources SET qualification_status = 'certifiee',
       qualified_by = 'N. Castillo', qualified_at = '2026-08-17'
WHERE source_id = 'kof' AND qualification_status = 'a_confirmer';

UPDATE source_bindings
SET statut = 'actif', verifie_par = 'N. Castillo', verifie_le = '2026-08-17'
WHERE indicator_id IN ('T5','T6') AND statut = 'a_verifier';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. T5 et T6 certifiés, liaisons actives, source KOF certifiée'
SELECT i.indicator_id, i.status, b.statut AS liaison, b.verifie_par
FROM indicators i JOIN source_bindings b USING (indicator_id)
WHERE i.indicator_id IN ('T5','T6') ORDER BY i.indicator_id;

\echo ''
\echo '--- 2. Nouveau décompte des certifiés (attendu : 24, dont 23 hard / 1 composite)'
SELECT category, count(*) FROM indicators WHERE status = 'certifie'
GROUP BY category ORDER BY category;

\echo ''
\echo '--- 3. Le registre n''est pas touché par l''activation'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
