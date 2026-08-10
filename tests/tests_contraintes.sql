-- =====================================================================
-- Tests de contraintes — la base fait-elle respecter la théorie ?
-- TB « Exploration de l'IA pour les entreprises industrielles »
--
-- Les cinq requêtes ci-dessous DOIVENT ÉCHOUER. Chaque échec démontre
-- qu'une règle du rapport est exercée par la base et non seulement
-- déclarée dans le texte (réserve R-1 de l'évaluation critique).
-- La sortie de ce script constitue la pièce de l'annexe 5.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille < tests/tests_contraintes.sql
--
-- ATTENTION : ce fichier n'est PAS dans db/ à dessein — db/ est monté
-- comme docker-entrypoint-initdb.d et serait rejoué à chaque init.
--
-- Après exécution, remettre la base à zéro avant tout run de référence :
--   docker compose down -v && docker compose up -d
-- =====================================================================

\echo '=== Contexte d execution ==='
SELECT now() AS horodatage, current_database() AS base, version() AS version_postgres;

\echo ''
\echo '=== Ouverture d un run de travail ==='
INSERT INTO runs (trigger_type, note) VALUES ('manual', 'Run de test des contraintes — annexe 5') RETURNING run_id;

\echo ''
\echo '=== (a) Extraction IA pretendant a la fiabilite d une source ==='
\echo '--- attendu : violation de chk_hierarchie_controle'
INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
VALUES ('A5', (SELECT max(run_id) FROM runs), '2025-01', 'EU27_2020', 100, 'ia_extraction', 'valide_source', '/data/test');

\echo ''
\echo '=== (b) Consensus partiel presente comme un consensus ==='
\echo '--- attendu : violation de chk_consensus_unanime'
INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, consensus_score, raw_ref)
VALUES ('A2', (SELECT max(run_id) FROM runs), '2025-01', 'EU27_2020', 100, 'ia_extraction', 'pre_valide_consensus', 0.66, '/data/test');

\echo ''
\echo '=== (c) Validation humaine sans validateur nomme ni date ==='
\echo '--- attendu : violation de chk_validation_humaine_tracee'
INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
VALUES ('A2', (SELECT max(run_id) FROM runs), '2025-02', 'EU27_2020', 100, 'ia_extraction', 'valide_humain', '/data/test');

\echo ''
\echo '=== (d) Ecrasement d une valeur du registre ==='
\echo '--- 1/2 : insertion licite (etl + valide_source), doit REUSSIR'
INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
VALUES ('A5', (SELECT max(run_id) FROM runs), '2025-03', 'EU27_2020', 100, 'etl', 'valide_source', '/data/test');
\echo '--- 2/2 : tentative de modification, attendu : declenchement de trg_registre_ajout_seul'
UPDATE indicator_values SET value = 999 WHERE indicator_id = 'A5' AND period = '2025-03';

\echo ''
\echo '=== (e) Indicateur sans question de veille rattachee ==='
\echo '--- attendu : declenchement de trg_indicateur_sans_question au COMMIT'
BEGIN;
INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency, unit, status)
VALUES ('X9', 'automobile', 'Indicateur sans question de veille',
        (SELECT source_id FROM sources ORDER BY source_id LIMIT 1),
        'hard', 'mensuelle', 'indice', 'certifie');
COMMIT;

\echo ''
\echo '=== (f) Suppression au registre (controle complementaire) ==='
\echo '--- attendu : declenchement de trg_registre_ajout_seul'
DELETE FROM indicator_values WHERE raw_ref = '/data/test';

\echo ''
\echo '=== Etat final : ce qui a effectivement ete ecrit ==='
SELECT indicator_id, period, geo, value, obtained_by, validation_status, raw_ref
FROM indicator_values WHERE raw_ref = '/data/test';
\echo '--- attendu : une seule ligne (celle de (d) 1/2). Les quatre autres ont ete refusees.'

\echo ''
\echo '=== Verification que X9 n a pas ete cree ==='
SELECT count(*) AS nb_x9 FROM indicators WHERE indicator_id = 'X9';
\echo '--- attendu : 0'
