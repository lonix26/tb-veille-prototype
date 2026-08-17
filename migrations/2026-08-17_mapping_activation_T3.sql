-- =====================================================================
-- Migration du 17.08.2026 (8/8) — mapping T3 corrigé au réel, activation
--
-- Fondée sur l'inspection du classeur réel par l'étudiant le 17.08.2026
-- (CPB-World-trade-monitor-may-2026.xlsx, résolu automatiquement depuis
-- la page stable /en/worldtrademonitor/latest — sortie openpyxl en
-- annexe 5) :
--   - deux feuilles : trade_out (commerce) et inpro_out (production) ;
--   - périodes en LIGNE 4, à partir de la colonne F, format « 2000m01 » ;
--   - séries en lignes ; le LIBELLÉ (col. B) voisine un horodatage de
--     production qui change à chaque parution — la clé de sélection est
--     donc le CODE de série (col. C), stable : tgz_w1_qnmi_sn =
--     World trade, volume, désaisonnalisé, base 2021=100 ;
--   - l'en-tête de la colonne C étant vide, l'extraction n8n la nommera
--     selon la convention SheetJS (« __EMPTY ») — HYPOTHÈSE à confronter
--     au premier run : s'il écrit 0 observation, l'incident listera les
--     clés réellement vues et le mapping sera recalé.
--
-- L'ancienne page worldtrademonitor est morte (404 constaté en
-- navigateur le 17.08) : url_base bascule sur /latest, qui porte le lien
-- du classeur dans son HTML statique — la résolution automatique est
-- donc possible, le mode manuel envisagé n'est pas nécessaire.
--
-- L'EXÉCUTION DE CE SCRIPT VAUT ACTIVATION : le classeur réel a été vu.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_mapping_activation_T3.sql \
--     | tee ../annexe_5/mapping_activation_T3_2026-08-17.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE source_bindings
SET url_base = 'https://www.cpb.nl/en/worldtrademonitor/latest',
    mapping  = '{"motif_lien":"href=\"([^\"]*[Ww]orld[_ -]?[Tt]rade[_ -]?[Mm]onitor[^\"]*\\.xlsx)\"","feuille":"trade_out","plage":"B4:MZ60","colonne_entite":"__EMPTY","entites_retenues":["tgz_w1_qnmi_sn"],"entites_geo":{"tgz_w1_qnmi_sn":"WORLD"},"motif_periode":"^\\d{4}[Mm]\\d{2}$","periode_min":"2023"}'::jsonb,
    note     = 'Classeur réel inspecté le 17.08.2026 (openpyxl, annexe 5) : feuille trade_out, périodes en ligne 4 dès la colonne F (2000m01), série cible par code stable tgz_w1_qnmi_sn (World trade, volume dsa, 2021=100), libellés voisins d''un horodatage variable. Page morte remplacée par /latest (lien xlsx présent en HTML statique, résolution automatique). Clé __EMPTY pour la colonne de codes : hypothèse SheetJS, à confronter au premier run.',
    statut = 'actif', verifie_par = 'N. Castillo', verifie_le = '2026-08-17'
WHERE indicator_id = 'T3' AND connecteur = 'xlsx_indexe';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. T3 actif sur /latest, série par code, nominatif et daté'
SELECT indicator_id, statut, verifie_par, url_base,
       mapping->>'feuille' AS feuille, mapping->'entites_retenues' AS series
FROM source_bindings WHERE indicator_id = 'T3' AND connecteur = 'xlsx_indexe';

\echo ''
\echo '--- 2. Les deux liaisons xlsx sont désormais actives'
SELECT indicator_id, statut FROM source_bindings WHERE connecteur = 'xlsx_indexe' ORDER BY indicator_id;

\echo ''
\echo '--- 3. Le registre n''est pas touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
