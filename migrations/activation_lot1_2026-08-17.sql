-- =====================================================================
-- Activation lot 1 — acte nominatif de l'étudiant, 17.08.2026
--
-- À exécuter APRÈS 2026-08-17_dedoublonnage_lot1.sql.
--
-- L'exécution de ce script vaut décision : il n'active que les liaisons
-- dont l'étudiant a VU la réponse réelle le 17.08.2026 (sorties curl
-- conservées) : M3 (OMS/GHO) et A3 fenêtre 2023.
--
-- A3 2024 et 2025 : NE PAS les activer avant d'avoir vu leur réponse :
--   curl -s --compressed -A "Mozilla/5.0" "https://api.iea.org/evs?parameters=EV%20sales&category=Historical&mode=Cars&csv=true&year=2024" | head -10
--   curl -s --compressed -A "Mozilla/5.0" "https://api.iea.org/evs?parameters=EV%20sales&category=Historical&mode=Cars&csv=true&year=2025" | head -10
-- puis décommenter le bloc en fin de script et ré-exécuter.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/activation_lot1_2026-08-17.sql \
--     | tee ../annexe_5/activation_lot1_2026-08-17.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- M3 — OMS, API GHO, GHED_CHEGDP_SHA2011 (réponse réelle vue le 17.08)
UPDATE source_bindings
SET statut = 'actif', verifie_par = 'N. Castillo', verifie_le = '2026-08-17'
WHERE indicator_id = 'M3' AND statut = 'a_verifier'
  AND url_base = 'https://ghoapi.azureedge.net/api/GHED_CHEGDP_SHA2011';

-- A3 — AIE, fenêtre 2023 (réponse réelle vue le 17.08 : en-têtes,
-- granularité pays, filtrage constatés)
UPDATE source_bindings
SET statut = 'actif', verifie_par = 'N. Castillo', verifie_le = '2026-08-17'
WHERE indicator_id = 'A3' AND statut = 'a_verifier'
  AND url_base = 'https://api.iea.org/evs' AND params->>'year' = '2023';

-- A3 — fenêtres 2024 et 2025 : décommenter APRÈS avoir vu les réponses,
-- et ajuster verifie_le à la date réelle du contrôle.
 UPDATE source_bindings
 SET statut = 'actif', verifie_par = 'N. Castillo', verifie_le = '2026-08-17'
 WHERE indicator_id = 'A3' AND statut = 'a_verifier'
   AND url_base = 'https://api.iea.org/evs' AND params->>'year' IN ('2024','2025');

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. M3 et A3-2023 actives, nominatives, datées du 17.08.2026'
\echo '    (A3 2024/2025 restent a_verifier tant que leurs réponses ne sont pas vues)'
SELECT indicator_id, params->>'year' AS annee, statut, verifie_par,
       to_char(verifie_le, 'DD.MM.YYYY') AS verifie_le
FROM source_bindings
WHERE indicator_id IN ('A3','M3')
ORDER BY indicator_id, annee NULLS FIRST;

\echo ''
\echo '--- 2. Le registre n''est pas touché (la collecte viendra du run, pas de l''activation)'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
