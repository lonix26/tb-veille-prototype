-- =====================================================================
-- Migration du 17.08.2026 (6/6) — liaisons xlsx_indexe pour S4 et T3
--
-- Nouveau connecteur xlsx_indexe, porté par le workflow dédié
-- collecte_xlsx_indexe.json (résolution du lien sur page d'index,
-- téléchargement binaire, extraction native, pivot large -> long).
-- Le collecteur générique exclut désormais ce connecteur de sa lecture.
--
-- ÉTAT DE VÉRIFICATION, différent pour les deux liaisons :
--   S4 — la page et le nom du fichier ont été vus le 17.08.2026
--        (SIPRI-Milex-data-1949-2025_v1.2.xlsx). La STRUCTURE INTERNE du
--        classeur (nom de feuille, plage, libellés de pays) n'a PAS été
--        vue : feuille et entites_geo sont des CANDIDATS à corriger après
--        ouverture du fichier téléchargé.
--   T3 — la page worldtrademonitor ne montrait AUCUN lien xlsx dans son
--        HTML le 17.08 (sondes des pages mensuelles restées sans réponse).
--        La liaison est semée avec le motif candidat, mais la PAGE de
--        résolution elle-même est à confirmer. Si le lien n'est pas dans
--        le HTML statique, T3 bascule en dépôt manuel mensuel (conforme
--        au scénario B) — à trancher après le premier essai.
--
-- Les deux restent a_verifier ; l'activation suit la règle habituelle.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_bindings_xlsx.sql
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 0. Extension du CHECK des connecteurs admis. Le socle déclaratif du
--    07.08 fixait quatre connecteurs ; xlsx_indexe est le cinquième.
--    La contrainte a fait son travail au premier essai (rejet constaté
--    le 17.08 — pièce d'annexe 5) : un connecteur ne s'ajoute pas
--    silencieusement, il s'ajoute par migration datée.
ALTER TABLE source_bindings DROP CONSTRAINT source_bindings_connecteur_check;
ALTER TABLE source_bindings ADD CONSTRAINT source_bindings_connecteur_check CHECK (connecteur IN (
    'eurostat_jsonstat',   -- API de dissémination Eurostat, format JSON-stat 2.0
    'owid_csv',            -- Our World in Data, CSV à colonnes nommées
    'csv_generique',       -- CSV distant, colonnes à préciser dans params
    'json_generique',      -- JSON distant, chemin d'accès à préciser dans params
    'xlsx_indexe'          -- classeur Excel derrière une page d'index, workflow dédié (17.08.2026)
));

-- S4 — Dépenses militaires (SIPRI), classeur annuel versionné.
-- Panier initial : les principaux budgets + la Suisse. Les libellés exacts
-- des pays dans le classeur sont À RELEVER (candidats d'après l'usage
-- SIPRI : « United States of America », « Russia », « Korea, South »…).
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note) VALUES
('S4', 'xlsx_indexe',
 'https://www.sipri.org/databases/milex',
 '{}'::jsonb,
 '{"motif_lien":"href=\"([^\"]*SIPRI-Milex-data[^\"]*\\.xlsx)\"","feuille":"Current US$","plage":"","colonne_entite":"Country","entites_retenues":["United States of America","China","Russia","India","Saudi Arabia","United Kingdom","Germany","France","Japan","Korea, South","Switzerland"],"entites_geo":{"United States of America":"USA","China":"CHN","Russia":"RUS","India":"IND","Saudi Arabia":"SAU","United Kingdom":"GBR","Germany":"DEU","France":"FRA","Japan":"JPN","Korea, South":"KOR","Switzerland":"CHE"},"motif_periode":"^\\d{4}$","periode_min":"2023"}'::jsonb,
 'WORLD', 'a_verifier',
 'Semée le 17.08.2026. Page et nom de fichier VUS (SIPRI-Milex-data-1949-2025_v1.2.xlsx) ; structure interne du classeur NON VUE — feuille, plage et libellés de pays sont des candidats, à corriger après ouverture du fichier téléchargé (dépôt brut du premier run d''essai). Unité source : millions USD courants — l''indicateur annonce des mia USD, conversion ou correction d''unité à trancher AVANT activation.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

-- T3 — Commerce mondial en volume (CPB World Trade Monitor), classeur
-- mensuel à nom variable. Page de résolution À CONFIRMER (voir en-tête).
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note) VALUES
('T3', 'xlsx_indexe',
 'https://www.cpb.nl/en/worldtrademonitor',
 '{}'::jsonb,
 '{"motif_lien":"href=\"([^\"]*[Ww]orld[_ -]?[Tt]rade[_ -]?[Mm]onitor[^\"]*\\.xlsx)\"","feuille":"","plage":"","colonne_entite":"","entites_retenues":null,"entites_geo":{},"motif_periode":"^\\d{4}[Mm]\\d{2}$","periode_min":"2023"}'::jsonb,
 'WORLD', 'a_verifier',
 'Semée le 17.08.2026. ATTENTION : le HTML statique de la page ne montrait aucun lien xlsx le 17.08 — la résolution peut échouer. Premier essai à faire ; en cas d''échec, options par ordre : trouver la page de parution mensuelle stable, sinon dépôt manuel mensuel du classeur (conforme scénario B), à documenter. Feuille et colonne d''entité à relever sur le classeur réel (série cible : commerce mondial, volume, indice 2010=100).')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. S4 et T3 semés en xlsx_indexe, a_verifier'
SELECT indicator_id, connecteur, statut, verifie_par
FROM source_bindings WHERE connecteur = 'xlsx_indexe' ORDER BY indicator_id;

\echo ''
\echo '--- 2. Le collecteur générique ne les verra pas (exclusion par connecteur)'
\echo '    Attendu : 0 ligne xlsx_indexe dans ce que lit le générique une fois actives.'
SELECT count(*) AS liaisons_generiques_xlsx
FROM v_bindings_actifs WHERE connecteur = 'xlsx_indexe';

\echo ''
\echo '--- 3. Le registre n''est pas touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
