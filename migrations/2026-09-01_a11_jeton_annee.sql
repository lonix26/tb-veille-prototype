-- =====================================================================
-- A11 : la liaison à jeton d'année qui manquait (audit de fraîcheur du
-- 01.09.2026). Les 16 liaisons d'A11 portaient toutes une année EN DUR :
-- l'historique était couvert, mais RIEN n'irait chercher 2026 puis 2027 —
-- l'indicateur se serait figé en silence après 2025. Son frère A3, sur la
-- même API, porte le jeton {{ANNEE_MOINS:1}} depuis l'origine ; A11 ne
-- l'avait pas reçu à sa création du 27.08. La liaison à jeton est
-- PERPÉTUELLE : l'année demandée est calculée à chaque exécution.
-- Vérification nominative par délégation (précédent de la liaison 144).
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, verifie_par, verifie_le, note)
VALUES ('A11', 'csv_generique', 'https://api.iea.org/evs',
  '{"csv": "true", "mode": "Cars", "year": "{{ANNEE_MOINS:1}}", "category": "Historical", "parameters": "EV sales share"}',
  '{"filtres": {"unit": ["percent"], "parameter": ["EV sales share"], "powertrain": ["EV"]}, "colonne_code": "region", "colonne_valeur": "value", "colonne_periode": "year"}',
  'WORLD', 'actif', 'N. Castillo (délégation du 01.09.2026)', now(),
  'Liaison perpétuelle au jeton {{ANNEE_MOINS:1}}, à l''image de la liaison 28 (A3) : l''année est résolue à l''exécution. Comble l''angle mort relevé à l''audit de fraîcheur du 01.09.2026.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

COMMIT;

\echo '--- Vérification : A11 a désormais sa liaison à jeton'
SELECT binding_id, indicator_id, params->>'year' AS annee, statut
FROM source_bindings WHERE indicator_id='A11' AND params::text LIKE '%{{%';
