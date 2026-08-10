-- =====================================================================
-- H1 — fenêtre temporelle complète (correctif du § 6 bis, suite n° 1)
--
-- DIAGNOSTIC (10.08.2026). La liaison H1 active ne demandait que trois
-- mois — `period = 202401,202402,202403` —, fenêtre de test jamais élargie.
-- D'où la série arrêtée à 2024-03, dont la dernière observation avait 29
-- mois : une alerte sur donnée périmée est un signal faux (§ 6 bis).
--
-- CONTRAINTE d'API confirmée sur pièce : UN Comtrade plafonne à
-- 12 périodes par requête mensuelle (la 13e renvoie HTTP 400,
-- « Maximum number of periods is 12 »). La fenêtre 2023-01..2026-05
-- (41 mois, dernière période disponible pour 757/SH 91/export vérifiée
-- le 10.08) ne tient donc pas en une seule liaison : il en faut quatre,
-- une par bloc annuel.
--
-- Ces quatre liaisons sont semées `a_verifier` — l'activation, après vue
-- de la réponse réelle, appartient à l'étudiant (§ 8.2.1). La liaison de
-- test à trois mois n'est PAS supprimée ici : à l'étudiant de la retirer
-- une fois les quatre fenêtres activées, pour éviter tout doublon.
--
-- Tous les autres paramètres (déclarant 757, SH 91, flux X, panier de
-- partenaires, breakdownMode, mapping partnerISO, format AAAAMM) sont
-- repris à l'identique de la liaison d'origine : seule la période change.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-10_H1_fenetre_complete.sql
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, verifie_par, verifie_le, note) VALUES

('H1', 'json_generique', 'https://comtradeapi.un.org/data/v1/get/C/M/HS',
 '{"reporterCode":"757","period":"202301,202302,202303,202304,202305,202306,202307,202308,202309,202310,202311,202312","cmdCode":"91","flowCode":"X","partnerCode":"0,842,344,156,392,826,702,276,251,380,784","breakdownMode":"classic","includeDesc":"true"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","format_periode":"AAAAMM","colonne_valeur":"primaryValue","colonne_geo":"partnerISO"}'::jsonb,
 'W00', 'a_verifier', NULL, NULL,
 'H1 fenêtre 2023 (12 mois). Bloc annuel imposé par le plafond Comtrade de 12 périodes/requête. Panier de partenaires identique à la liaison d''origine. À activer après vérification de la réponse réelle.'),

('H1', 'json_generique', 'https://comtradeapi.un.org/data/v1/get/C/M/HS',
 '{"reporterCode":"757","period":"202401,202402,202403,202404,202405,202406,202407,202408,202409,202410,202411,202412","cmdCode":"91","flowCode":"X","partnerCode":"0,842,344,156,392,826,702,276,251,380,784","breakdownMode":"classic","includeDesc":"true"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","format_periode":"AAAAMM","colonne_valeur":"primaryValue","colonne_geo":"partnerISO"}'::jsonb,
 'W00', 'a_verifier', NULL, NULL,
 'H1 fenêtre 2024 (12 mois). Recouvre et complète la liaison de test à trois mois (202401-03), à retirer une fois cette fenêtre active.'),

('H1', 'json_generique', 'https://comtradeapi.un.org/data/v1/get/C/M/HS',
 '{"reporterCode":"757","period":"202501,202502,202503,202504,202505,202506,202507,202508,202509,202510,202511,202512","cmdCode":"91","flowCode":"X","partnerCode":"0,842,344,156,392,826,702,276,251,380,784","breakdownMode":"classic","includeDesc":"true"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","format_periode":"AAAAMM","colonne_valeur":"primaryValue","colonne_geo":"partnerISO"}'::jsonb,
 'W00', 'a_verifier', NULL, NULL,
 'H1 fenêtre 2025 (12 mois).'),

('H1', 'json_generique', 'https://comtradeapi.un.org/data/v1/get/C/M/HS',
 '{"reporterCode":"757","period":"202601,202602,202603,202604,202605","cmdCode":"91","flowCode":"X","partnerCode":"0,842,344,156,392,826,702,276,251,380,784","breakdownMode":"classic","includeDesc":"true"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","format_periode":"AAAAMM","colonne_valeur":"primaryValue","colonne_geo":"partnerISO"}'::jsonb,
 'W00', 'a_verifier', NULL, NULL,
 'H1 fenêtre 2026 (5 mois : janvier à mai, dernière période disponible le 10.08.2026). À réétendre au fil des publications mensuelles Comtrade.');

COMMIT;

-- =====================================================================
-- Vérifications
-- =====================================================================

\echo ''
\echo '--- Liaisons H1 après ajout : la fenêtre couverte, par statut'
\echo '    Attendu : 1 active (test 3 mois) + 4 a_verifier (blocs annuels).'
SELECT statut, params->>'period' AS periode, verifie_par
FROM source_bindings WHERE indicator_id = 'H1'
ORDER BY statut DESC, params->>'period';

\echo ''
\echo '--- Aucune clé d''API dans les paramètres'
\echo '    Attendu : 0 ligne.'
SELECT indicator_id FROM source_bindings
WHERE indicator_id = 'H1' AND (params::text ILIKE '%subscription%' OR params::text ILIKE '%key%');
