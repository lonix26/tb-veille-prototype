-- =====================================================================
-- Activation H2 / M4 — acte nominatif de l'étudiant
--
-- À exécuter UNIQUEMENT après avoir vu la réponse POST réelle de la table
-- OFS (commande en fin de 2026-08-17_bindings_H2_M4.sql) : un JSON-stat
-- "class":"dataset" avec "Jahr" dans "id". L'exécution vaut décision.
-- Ajuster verifie_le si le contrôle a lieu un autre jour.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/activation_H2_M4_2026-08-17.sql \
--     | tee ../annexe_5/activation_H2_M4_2026-08-17.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE source_bindings
SET statut = 'actif', verifie_par = 'N. Castillo', verifie_le = '2026-08-17'
WHERE indicator_id IN ('H2','M4') AND statut = 'a_verifier'
  AND url_base = 'https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. H2 et M4 actifs, nominatifs, datés'
SELECT indicator_id, statut, verifie_par, to_char(verifie_le, 'DD.MM.YYYY') AS verifie_le
FROM source_bindings WHERE indicator_id IN ('H2','M4') ORDER BY indicator_id;

\echo ''
\echo '--- 2. Le registre n''est pas touché par l''activation'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
