-- 2026-08-25 — H2 et M4 : fenêtre glissante sur l'API PX-Web de l'OFS
--
-- CONSTAT. Les liaisons actives 29 (H2, emplois horlogers suisses) et 30 (M4, emplois
-- de l'industrie médicale suisse) demandent `Jahr = ["2023"]` — un littéral. Elles ne
-- rapporteront jamais autre chose que 2023, quel que soit le nombre de fois où on les
-- rejoue. Le dispositif est censé accumuler des exécutions datées ; ces deux liaisons,
-- elles, sont arrêtées.
--
-- Ce n'est pas une hypothèse : reconnaissance faite le 25.08.2026 sur la source réelle,
-- l'OFS publie déjà **2024**. La liaison figée perd donc une année dès aujourd'hui.
--
-- SOLUTION, SANS JETON. PX-Web sait sélectionner les N dernières valeurs disponibles
-- d'une dimension : `{"filter": "top", "values": ["4"]}`. C'est plus sûr qu'un jeton
-- d'année calculé côté collecteur — lequel demanderait 2026 à une source qui publie
-- avec deux ans de retard, et essuierait un refus. La source dit elle-même ce qu'elle
-- a de plus récent.
--
-- Réponse réelle du 25.08.2026 (HTTP 200, 1385 octets) : années rendues 2021, 2022,
-- 2023, 2024 ; 20 valeurs, aucune nulle.
--
-- STATUT `a_verifier`, ET C'EST VOULU. La qualification est un acte humain nominatif
-- (§ 10.4) : `chk_binding_verifie` l'impose en base. Ces deux liaisons sont SEMÉES,
-- pas activées. L'activation appartient à l'étudiant, qui la datera de son nom.
-- Tant qu'elle n'a pas lieu, les liaisons 29 et 30 restent seules actives et H2/M4
-- restent arrêtés sur 2023.

BEGIN;

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note)
VALUES
('H2', 'eurostat_jsonstat',
 'https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px',
 '{"_corps": {"query": [{"code": "Jahr", "selection": {"filter": "top", "values": ["4"]}}, {"code": "Kanton", "selection": {"filter": "item", "values": ["999"]}}, {"code": "Wirtschaftsart", "selection": {"filter": "item", "values": ["265201", "265202", "265203", "265204", "265205"]}}, {"code": "Beobachtungseinheit", "selection": {"filter": "item", "values": ["2"]}}], "response": {"format": "json-stat2"}}, "_methode": "POST"}'::jsonb,
 '{"agreger": "somme", "dim_temps": "Jahr"}'::jsonb,
 'CH', 'a_verifier',
 'Fenêtre glissante par filtre PX-Web « top: 4 » — remplace la liaison 29, figée sur 2023. Reconnaissance du 25.08.2026 : HTTP 200, années 2021-2024, 20 valeurs non nulles. À activer nominativement ; désactiver la liaison 29 dans le même geste, faute de quoi 2023 serait collecté deux fois.'),
('M4', 'eurostat_jsonstat',
 'https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px',
 '{"_corps": {"query": [{"code": "Jahr", "selection": {"filter": "top", "values": ["4"]}}, {"code": "Kanton", "selection": {"filter": "item", "values": ["999"]}}, {"code": "Wirtschaftsart", "selection": {"filter": "item", "values": ["266000", "325001", "325002", "325003", "325004"]}}, {"code": "Beobachtungseinheit", "selection": {"filter": "item", "values": ["2"]}}], "response": {"format": "json-stat2"}}, "_methode": "POST"}'::jsonb,
 '{"agreger": "somme", "dim_temps": "Jahr"}'::jsonb,
 'CH', 'a_verifier',
 'Fenêtre glissante par filtre PX-Web « top: 4 » — remplace la liaison 30, figée sur 2023. Même table et même reconnaissance que H2 (25.08.2026) ; seuls les codes Wirtschaftsart diffèrent. À activer nominativement, en désactivant la liaison 30 dans le même geste.');

COMMIT;
