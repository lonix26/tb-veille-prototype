-- =====================================================================
-- Migration du 17.08.2026 — liaisons du lot 1 (A3, M3, S4), semées a_verifier
--
-- Objet. Reprise du développement (décision N. Castillo du 17.08.2026,
-- levée de l'arrêt technique). Trois indicateurs certifiés à zéro
-- observation reçoivent une liaison candidate, compatible avec les
-- connecteurs existants (csv_generique, json_generique).
--
-- AUCUNE des URL ci-dessous n'a été vue en réponse réelle : la
-- reconnaissance du 17.08 s'est faite sans accès shell (voir
-- RECONNAISSANCE_SOURCES_LOT1_2026-08-17.md, commandes de vérification
-- incluses). Les liaisons sont donc semées a_verifier, sans verifie_par
-- ni verifie_le. L'activation est un acte humain, nominatif et daté,
-- après lecture de la réponse réelle — contrainte chk_binding_verifie.
--
-- H2, M4, T3 : PAS de liaison ici — leur connecteur (http_post, xlsx,
-- page_index) n'existe pas encore ; une liaison référençant un connecteur
-- absent serait une surdéclaration en base.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_bindings_lot1.sql
--
-- Non destructive : aucune écriture dans indicator_values. Idempotente
-- (ON CONFLICT DO NOTHING sur la contrainte d'unicité de la liaison).
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- A3 — Ventes mondiales de véhicules électriques (AIE, Global EV Data
-- Explorer). Point d'accès documenté de l'explorateur, réputé sans clé.
-- Colonnes réelles à relever à la première réponse ; le mapping ci-dessous
-- est un CANDIDAT (noms de colonnes non constatés).
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note) VALUES
('A3', 'csv_generique',
 'https://api.iea.org/evs',
 '{"parameters":"EV sales","category":"Historical","mode":"Cars","csv":"true"}'::jsonb,
 '{"colonne_periode":"year","colonne_valeur":"value","colonne_code":"region","periode_min":"2023"}'::jsonb,
 'WORLD', 'a_verifier',
 'Semée le 17.08.2026 sans réponse réelle vue (session sans shell — appel resté vide, cause indéterminée : rendu client ou en-têtes requis). Noms de colonnes du mapping NON CONSTATÉS, à corriger à la première réponse. Commande de vérification dans RECONNAISSANCE_SOURCES_LOT1_2026-08-17.md.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

-- M3 — Dépenses de santé par pays (OMS, API GHO / OData). Le code
-- d'indicateur GHED_CHEGDP_SHA2011 (part du PIB) est un CANDIDAT à
-- confirmer par la requête de listage avant activation. Structure OData :
-- liste sous "value", champs SpatialDim / TimeDim / NumericValue.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note) VALUES
('M3', 'json_generique',
 'https://ghoapi.azureedge.net/api/GHED_CHEGDP_SHA2011',
 '{}'::jsonb,
 '{"chemin_donnees":"value","colonne_periode":"TimeDim","colonne_valeur":"NumericValue","colonne_code":"SpatialDim","periode_min":"2023"}'::jsonb,
 'WORLD', 'a_verifier',
 'Semée le 17.08.2026 sans réponse réelle vue. CODE D''INDICATEUR GHO CANDIDAT, à confirmer par le listage (voir reconnaissance lot 1) ; corriger url_base si le code réel diffère. Ne couvre que la part du PIB — la composante USD/habitant de M3 exigerait une seconde liaison, à trancher après lecture du catalogue GHO.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

-- S4 — Dépenses militaires par pays (SIPRI). Le format de distribution
-- connu est un classeur xlsx (nom de fichier à relever sur la page) ;
-- l'existence d'un export CSV direct est à vérifier. Liaison-repère : si
-- seul le xlsx existe, S4 bascule au groupe 2 (connecteur xlsx) et cette
-- liaison est remplacée — ne jamais l'activer telle quelle.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note) VALUES
('S4', 'csv_generique',
 'https://milex.sipri.org',
 '{}'::jsonb,
 '{"colonne_periode":"a_relever","colonne_valeur":"a_relever","colonne_code":"a_relever","periode_min":"2023"}'::jsonb,
 'WORLD', 'a_verifier',
 'Semée le 17.08.2026 comme repère de travail — URL de la base interactive, PAS un point d''accès de collecte. Distribution connue en xlsx uniquement (à confirmer) : si aucun CSV direct n''existe, basculer S4 au connecteur xlsx (groupe 2) et remplacer cette liaison. Ne pas activer en l''état.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. Trois liaisons semées, toutes a_verifier, aucune vérifiée'
\echo '    Attendu : A3, M3, S4 en a_verifier, verifie_par NULL.'
SELECT indicator_id, connecteur, statut, verifie_par
FROM source_bindings WHERE indicator_id IN ('A3','M3','S4')
ORDER BY indicator_id;

\echo ''
\echo '--- 2. Aucune liaison active nouvelle (l''activation est un acte humain)'
\echo '    Attendu : le décompte des liaisons actives est inchangé par cette migration.'
SELECT statut, count(*) FROM source_bindings GROUP BY statut ORDER BY statut;

\echo ''
\echo '--- 3. Le registre n''est pas touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
