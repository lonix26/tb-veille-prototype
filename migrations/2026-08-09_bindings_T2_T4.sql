-- =====================================================================
-- Migration du 09.08.2026 — liaisons T2 (BNS) et T4 (FMI)
--
-- Objet. Deux indicateurs du socle transversal (QV0), vérifiés contre
-- leurs API réelles depuis le shell le 09.08.2026 et activés. Ils sont
-- semés ici pour que l'état de source_bindings soit reproductible depuis
-- le dépôt, et non porté par la seule base — une PME doit pouvoir refaire.
--
-- Dépendance. La liaison T4 requiert le mode « objet_par_periode » du
-- connecteur json_generique (nœud « Décoder selon le connecteur » du
-- workflow collecte_generique.json), ajouté le même jour. Sans lui, la
-- structure imbriquée du FMI (annee -> valeur) n'est pas lisible.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-09_bindings_T2_T4.sql
--
-- Non destructive : aucune écriture dans indicator_values. Idempotente
-- (ON CONFLICT DO NOTHING sur la contrainte d'unicité de la liaison).
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- T2 — Taux de change CHF/USD et CHF/EUR (BNS, cube devkum, mensuel).
-- Deux séries dans un même cube, distinguées par la zone via geo_depuis
-- sur la dimension D1. Moyennes mensuelles seulement (filtre D0=M0).
-- En-tête en ligne 4 (3 lignes de métadonnées BNS), séparateur ';', BOM.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, verifie_par, verifie_le, note) VALUES
('T2', 'csv_generique',
 'https://data.snb.ch/api/cube/devkum/data/csv/fr',
 '{"fromDate":"2023-01","dimSel":"D0(M0),D1(USD1,EUR1)"}'::jsonb,
 '{"colonne_periode":"Date","colonne_valeur":"Value","separateur":";","sauter_lignes":3,"filtres":{"D0":["M0"]},"geo_depuis":{"D1":{"USD1":"CHF_USD","EUR1":"CHF_EUR"}}}'::jsonb,
 'WORLD', 'actif', 'N. Castillo', '2026-08-09',
 'BNS cube devkum, moyennes mensuelles (D0=M0). Deux séries distinguées par la zone via geo_depuis sur D1 : CHF_USD, CHF_EUR. En-tête en ligne 4, séparateur point-virgule, BOM. Vérifié le 09.08.2026 : 86 observations sur 2023-01..2026-07, URL testée sous forme encodée par le connecteur.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

-- T4 — Croissance du PIB mondial (FMI DataMapper, NGDP_RPCH, WEOWORLD).
-- Structure imbriquée annee -> valeur, lue par le mode objet_par_periode.
-- Borné à 2025 : les années 2026+ sont des PROJECTIONS FMI, écartées tant
-- que leur statut (distinct de valide_source) n'est pas tranché — ne pas
-- présenter une prévision comme une valeur observée.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, verifie_par, verifie_le, note) VALUES
('T4', 'json_generique',
 'https://www.imf.org/external/datamapper/api/v1/NGDP_RPCH/WEOWORLD',
 '{}'::jsonb,
 '{"chemin_donnees":"values.NGDP_RPCH.WEOWORLD","objet_par_periode":true,"periode_min":"2023","periode_max":"2025"}'::jsonb,
 'WORLD', 'actif', 'N. Castillo', '2026-08-09',
 'FMI DataMapper, indicateur NGDP_RPCH (croissance PIB réel), agrégat WEOWORLD. Structure imbriquée annee->valeur, lue par le mode objet_par_periode du connecteur. Vérifié le 09.08.2026 : 2023=3.3, 2024=3.4, 2025=3.4. Borné à 2025 : 2026+ sont des projections FMI, écartées.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. Les deux liaisons sont actives'
\echo '    Attendu : T2 (csv_generique) et T4 (json_generique), statut actif.'
SELECT indicator_id, connecteur, statut, verifie_par, to_char(verifie_le, 'DD.MM.YYYY') AS verifie_le
FROM source_bindings WHERE indicator_id IN ('T2','T4') ORDER BY indicator_id;

\echo ''
\echo '--- 2. Le registre n''est pas touché par cette migration'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
