-- =====================================================================
-- Migration du 17.08.2026 (7/7) — mapping S4 corrigé au réel, activation
--
-- Fondée sur l'inspection du classeur réel par l'étudiant le 17.08.2026
-- (SIPRI-Milex-data-1949-2025_v1.2.xlsx, sortie openpyxl conservée) :
--   - feuille « Current US$ » confirmée ; en-tête en LIGNE 6
--     (Country, Notes, 1949..2025) -> plage A6:CA400 ;
--   - libellés vérifiés : United States of America, China, Korea, South,
--     Russia, Switzerland, Saudi Arabia (les autres du panier sont des
--     graphies standard, le premier run fera foi — attendu 11 pays) ;
--   - série jusqu'à 2025 ; « xxx » et « . . » deviennent NaN, écartés ;
--   - unité RÉELLE : millions USD courants. indicators.S4 annonçait
--     « mia USD » : l'unité est alignée sur la source (précédent H1).
--
-- Point pour le § 12.5 : « Figures in blue are SIPRI estimates » — le
-- drapeau de qualité est porté par la COULEUR de cellule, invisible à
-- toute extraction de valeurs. Quatrième occurrence du motif des drapeaux
-- perdus, celle-ci structurellement irrécupérable par ETL.
--
-- L'EXÉCUTION DE CE SCRIPT VAUT ACTIVATION : le classeur réel a été vu,
-- la condition de qualification est remplie.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_mapping_activation_S4.sql \
--     | tee ../annexe_5/mapping_activation_S4_2026-08-17.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Plage alignée sur l'en-tête réel (ligne 6), le reste du mapping
--    étant confirmé tel quel.
UPDATE source_bindings
SET mapping = jsonb_set(mapping, '{plage}', '"A6:CA400"'),
    note    = 'Classeur réel inspecté le 17.08.2026 (openpyxl, sortie en annexe 5) : feuille Current US$, en-tête ligne 6 (Country, Notes, 1949..2025), libellés du panier confirmés pour USA/CHN/KOR/RUS/CHE/SAU, série jusqu''à 2025, unité millions USD. Drapeaux de qualité portés par la couleur des cellules — perdus par construction, consigné pour le § 12.5.'
WHERE indicator_id = 'S4' AND connecteur = 'xlsx_indexe';

-- 2. Unité de l'indicateur alignée sur la source.
UPDATE indicators SET unit = 'mio USD' WHERE indicator_id = 'S4';

-- 3. Activation nominative — le classeur réel a été vu.
UPDATE source_bindings
SET statut = 'actif', verifie_par = 'N. Castillo', verifie_le = '2026-08-17'
WHERE indicator_id = 'S4' AND connecteur = 'xlsx_indexe';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. S4 actif, plage A6:CA400, unité mio USD'
SELECT b.indicator_id, b.statut, b.verifie_par, b.mapping->>'plage' AS plage, i.unit
FROM source_bindings b JOIN indicators i USING (indicator_id)
WHERE b.indicator_id = 'S4' AND b.connecteur = 'xlsx_indexe';

\echo ''
\echo '--- 2. T3 reste a_verifier (page de résolution non confirmée)'
SELECT indicator_id, statut FROM source_bindings WHERE connecteur = 'xlsx_indexe' ORDER BY indicator_id;

\echo ''
\echo '--- 3. Le registre n''est pas touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
