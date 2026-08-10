-- =====================================================================
-- Liaison T1 — CLI, zone G20 — 10.08.2026
--
-- RÉSOLUTION DE L'ENQUÊTE T1. La série CLI de l'OCDE est vivante et
-- mensuelle (dernière période juin 2026), mais sa déclinaison pour
-- l'agrégat « OCDE total » n'est plus publiée : le flux courant la
-- propose pour 22 zones, dont les agrégats G20, G7, G4E, NAFTA et A5M.
-- La qualification initiale visait « le CLI, zone OCDE » — la mesure
-- existe, la zone n'existe plus.
--
-- DÉCISION (N. Castillo, 10.08.2026) : T1 est réancré sur la zone G20,
-- l'agrégat le plus large disponible et le plus conforme au périmètre
-- mondial de la ratification (il inclut la Chine et l'Inde, absentes du
-- G7). Le changement porte sur la zone de référence, non sur la mesure.
--
-- VERSION NON ÉPINGLÉE, et c'est un choix documenté. La version 4.1,
-- épinglée dans les premiers tests, ne porte plus la mesure LI — c'est
-- l'épinglage qui a masqué la série vivante et conduit au faux
-- diagnostic du 10.08 (voir notes de rédaction). La liaison suit donc
-- la version courante du flux, avec l'avertissement de la documentation
-- (changements structurels possibles) assumé et compensé par la
-- re-vérification périodique de la couche 0.
--
-- Clé relevée dans les données réelles et vérifiée en volume :
-- G20.M.LI...AA...H → 42 observations, 2023-01 à 2026-06.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-10_liaison_T1_cli_g20.sql
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Nettoyage : toute liaison T1 jamais activée, y compris la liaison
-- BCICP semée par la migration suspendue du même jour si elle avait été
-- exécutée. Licite : source_bindings est une table de configuration,
-- non le registre — l'ajout seul ne s'applique pas à elle.
DELETE FROM source_bindings
 WHERE indicator_id = 'T1' AND statut = 'a_verifier';

UPDATE indicators
   SET label = 'Indicateur composite avancé (CLI), zone G20'
 WHERE indicator_id = 'T1';

UPDATE sources
   SET notes = coalesce(notes || ' | ', '')
       || 'Vérifié le 10.08.2026 : la série CLI est vivante et mensuelle, mais l''agrégat « OCDE total » n''est plus publié — 22 zones disponibles dont G20, G7, G4E, NAFTA. T1 réancré sur G20. Version du flux non épinglée : la 4.1 ne porte plus la mesure LI. Limitation de débit annoncée par la documentation sans être chiffrée.'
 WHERE source_id = 'ocde';

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note) VALUES
('T1', 'csv_generique',
 'https://sdmx.oecd.org/public/rest/data/OECD.SDD.STES,DSD_STES@DF_CLI/G20.M.LI...AA...H',
 '{"startPeriod":"2023-01","format":"csvfilewithlabels"}'::jsonb,
 '{"colonne_periode":"TIME_PERIOD","colonne_valeur":"OBS_VALUE","colonne_code":"REF_AREA"}'::jsonb,
 'G20', 'a_verifier',
 'Clé à neuf dimensions relevée dans les données du 10.08.2026, volume vérifié : 42 observations, 2023-01 à 2026-06. CSV à virgules, en-tête en première ligne. La colonne OBS_STATUS porte un statut de qualité par observation — perdu à l''ingestion, troisième occurrence du motif (Eurostat, Comtrade, OCDE).');

COMMIT;

\echo ''
\echo '--- T1 : libellé et liaison CLI/G20'
SELECT indicator_id, label FROM indicators WHERE indicator_id = 'T1';
SELECT indicator_id, connecteur, statut, params->>'startPeriod' AS depuis
FROM source_bindings WHERE indicator_id = 'T1';
