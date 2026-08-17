-- =====================================================================
-- Migration du 17.08.2026 (4/4) — liaisons H2 et M4 (OFS, STATENT, POST)
--
-- Fondée sur la reconnaissance en réponse réelle du 17.08.2026 (métadonnées
-- de la table px-x-0602010000_103 relevées par l'étudiant) :
--   dimensions Jahr (time, 2011..2023), Kanton (999 = Suisse),
--   Wirtschaftsart (789 genres, dont les 10 codes NOGA cibles confirmés),
--   Beobachtungseinheit (1 Etablissements, 2 Emplois, 5 EPT, ...).
--
-- Décisions portées par cette migration :
--   - Mesure retenue : EMPLOIS (Beobachtungseinheit = 2). Le libellé des
--     indicateurs dit « emploi et établissements » ; le registre ne porte
--     qu'une valeur par (période, zone). Les établissements restent
--     possibles en seconde liaison. Décision du 17.08.2026, N. Castillo.
--   - Périmètre : Suisse entière (Kanton 999), années 2021-2023
--     (historique 3 ans ; la série STATENT s'arrête à 2023 — limite de
--     fraîcheur déjà consignée, à énoncer au § 8.4).
--   - Agrégation par somme des classes NOGA (motif M1) : sans elle, les
--     5 classes partageraient la clé (période, zone) et s'écraseraient.
--   - Transport : POST déclaré par la liaison (_methode/_corps, ajout du
--     17.08.2026 au collecteur) ; décodage JSON-stat via le décodeur
--     Eurostat avec dim_temps=Jahr (surcharge ajoutée le même jour).
--     LE WORKFLOW DOIT AVOIR ÉTÉ RÉIMPORTÉ AVEC CES DEUX ÉVOLUTIONS.
--
-- Semées a_verifier : l'activation exige d'avoir VU la réponse POST réelle
-- (commandes en fin de fichier), puis activation_H2_M4_2026-08-17.sql.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_bindings_H2_M4.sql
--
-- Non destructive : aucune écriture dans indicator_values. Idempotente.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- H2 — Emplois de la branche horlogère (NOGA 2652), Suisse, 2021-2023.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note) VALUES
('H2', 'eurostat_jsonstat',
 'https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px',
 '{"_methode":"POST","_corps":{"query":[{"code":"Jahr","selection":{"filter":"item","values":["2021","2022","2023"]}},{"code":"Kanton","selection":{"filter":"item","values":["999"]}},{"code":"Wirtschaftsart","selection":{"filter":"item","values":["265201","265202","265203","265204","265205"]}},{"code":"Beobachtungseinheit","selection":{"filter":"item","values":["2"]}}],"response":{"format":"json-stat2"}}}'::jsonb,
 '{"dim_temps":"Jahr","agreger":"somme"}'::jsonb,
 'CH', 'a_verifier',
 'OFS STATENT, table px-x-0602010000_103, POST JSON-stat2. Métadonnées vues en réponse réelle le 17.08.2026 ; la réponse POST elle-même reste À VOIR avant activation. Emplois (Beobachtungseinheit=2), Suisse (Kanton 999), 5 classes NOGA 2652 sommées (motif M1). Série arrêtée à 2023 — limite de fraîcheur STATENT.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

-- M4 — Emplois medtech suisses (NOGA 3250 + 2660), Suisse, 2021-2023.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note) VALUES
('M4', 'eurostat_jsonstat',
 'https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px',
 '{"_methode":"POST","_corps":{"query":[{"code":"Jahr","selection":{"filter":"item","values":["2021","2022","2023"]}},{"code":"Kanton","selection":{"filter":"item","values":["999"]}},{"code":"Wirtschaftsart","selection":{"filter":"item","values":["266000","325001","325002","325003","325004"]}},{"code":"Beobachtungseinheit","selection":{"filter":"item","values":["2"]}}],"response":{"format":"json-stat2"}}}'::jsonb,
 '{"dim_temps":"Jahr","agreger":"somme"}'::jsonb,
 'CH', 'a_verifier',
 'OFS STATENT, même table et même transport que H2. Emplois (Beobachtungseinheit=2), Suisse (999), classes 266000 + 325001-325004 sommées — périmètre qualifié au § 8.4.2 (NOGA 32.5 et 26.6). Réponse POST À VOIR avant activation. Série arrêtée à 2023.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. H2 et M4 semés en a_verifier, transport POST déclaré'
SELECT indicator_id, connecteur, params->>'_methode' AS methode, statut, verifie_par
FROM source_bindings WHERE indicator_id IN ('H2','M4') ORDER BY indicator_id;

\echo ''
\echo '--- 2. Le registre n''est pas touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;

-- =====================================================================
-- Vérification de la réponse POST réelle — À FAIRE AVANT ACTIVATION :
--
-- curl -s -X POST -H "Content-Type: application/json" \
--   -d '{"query":[{"code":"Jahr","selection":{"filter":"item","values":["2021","2022","2023"]}},{"code":"Kanton","selection":{"filter":"item","values":["999"]}},{"code":"Wirtschaftsart","selection":{"filter":"item","values":["265201","265202","265203","265204","265205"]}},{"code":"Beobachtungseinheit","selection":{"filter":"item","values":["2"]}}],"response":{"format":"json-stat2"}}' \
--   "https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px" \
--   | head -c 1200
--
-- Attendu : un JSON-stat ("class":"dataset") avec "id" contenant "Jahr",
-- et 15 valeurs (3 années x 5 classes). Si la structure diffère
-- (enveloppe "dataset" de JSON-stat 1.x, par exemple), NE PAS activer :
-- me rapporter la sortie, le décodage sera ajusté d'abord.
-- =====================================================================
