-- =====================================================================
-- Migration du 17.08.2026 (3/3) — correction du mapping M3
--
-- Incident du run 33, diagnostiqué le 17.08.2026. Le mapping M3 semé le
-- même jour employait la clé colonne_code — convention du décodeur CSV —
-- là où le décodeur JSON attend colonne_geo. Conséquence : la zone était
-- ignorée, ~190 lignes pays retombaient toutes sur geo_defaut = WORLD et
-- la clé d'unicité (indicateur, run, période, zone) n'en a conservé
-- qu'UNE — la valeur d'un pays arbitraire, étiquetée WORLD, statut
-- valide_source. C'est le motif d'écrasement silencieux déjà documenté
-- pour M1 (agrégation), reproduit par une divergence de vocabulaire de
-- mapping entre décodeurs. À porter au § 12.5.
--
-- Traitement, conforme au registre en ajout seul (trigger
-- trg_registre_ajout_seul) : la ligne fausse du run 33 RESTE dans
-- l'historique, auditable par son raw_ref ; la correction est un nouveau
-- run après correction du mapping. Pour que le dernier point WORLD soit
-- supersédé, l'agrégat mondial GHO (code GLOBAL) est renommé WORLD par le
-- mécanisme geo_renommage ajouté au décodeur JSON le 17.08.2026 —
-- LE WORKFLOW collecte_generique DOIT ÊTRE RÉIMPORTÉ AVANT LE RUN
-- (procédure du § 2 de PASSATION_PROTOTYPE.md : id et credential Postgres
-- à rattacher si réimport à neuf).
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_correction_mapping_M3.sql
--
-- Non destructive : aucune écriture dans indicator_values.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE source_bindings
SET mapping = '{"chemin_donnees":"value","colonne_periode":"TimeDim","colonne_valeur":"NumericValue","colonne_geo":"SpatialDim","geo_renommage":{"GLOBAL":"WORLD"},"periode_min":"2023"}'::jsonb,
    note    = 'Mapping corrigé le 17.08.2026 après l''incident du run 33 (colonne_code au lieu de colonne_geo : ~190 pays écrasés en une ligne WORLD fausse, conservée à l''historique — registre en ajout seul). SpatialDim en ISO3, agrégats régionaux GHO (AFR, EUR…) conservés tels quels et à tenir hors classements ; GLOBAL renommé WORLD via geo_renommage pour superseder le dernier point WORLD. Réponse réelle vue le 17.08.2026.'
WHERE indicator_id = 'M3' AND statut = 'actif'
  AND url_base = 'https://ghoapi.azureedge.net/api/GHED_CHEGDP_SHA2011';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. Le mapping M3 porte colonne_geo et le renommage GLOBAL -> WORLD'
SELECT indicator_id, mapping->>'colonne_geo' AS colonne_geo,
       mapping->'geo_renommage' AS geo_renommage, statut
FROM source_bindings
WHERE indicator_id = 'M3';

\echo ''
\echo '--- 2. La ligne fausse du run 33 est identifiée (elle RESTE, en ajout seul)'
\echo '    Attendu : 1 ligne, geo = WORLD, à documenter — pas à supprimer.'
SELECT value_id, run_id, period, geo, value, validation_status, raw_ref
FROM indicator_values
WHERE indicator_id = 'M3' AND run_id = 33;

\echo ''
\echo '--- 3. Le registre n''est pas touché par cette migration'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
