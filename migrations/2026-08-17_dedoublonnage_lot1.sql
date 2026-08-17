-- =====================================================================
-- Migration du 17.08.2026 (2/2) — dédoublonnage et correction du lot 1
--
-- Constat. L'exécution de 2026-08-17_bindings_lot1.sql a révélé que des
-- liaisons candidates pour A3, M3 et S4 existaient déjà (semées lors de
-- la reconnaissance d'août, non consignées à la passation) : six liaisons
-- a_verifier pour trois indicateurs. Deux liaisons pour un même
-- indicateur = double ingestion à la collecte (précédent : liaison de
-- test H1 à retirer, 2026-08-10_H1_fenetre_complete.sql).
--
-- Décisions portées par cette migration, d'après les réponses réelles
-- vues par l'étudiant le 17.08.2026 (sorties curl conservées) :
--
-- 1. M3 : la source qualifiée au § 8.4.2 est l'OMS (GHED). L'API GHO
--    répond (GHED_CHEGDP_SHA2011, OData, SpatialDim/TimeDim/NumericValue,
--    données 2023+ constatées). La liaison Banque mondiale (binding 4),
--    qui aurait exigé une requalification de source, est SANS OBJET et
--    supprimée — aucune requalification n'a lieu.
-- 2. A3 : l'API api.iea.org/evs répond en CSV. Le paramètre year est
--    obligatoire ('Must specify a region or a year') et le flux mélange
--    EV sales / EV stock / parts : une liaison PAR ANNÉE (motif H1) avec
--    filtres au mapping. L'ancienne liaison page-produit (binding 6) est
--    supprimée ; son avertissement (§ 8.4.3 qualifie l'explorateur, la
--    bibliographie référence le rapport Global EV Outlook — à trancher)
--    est reporté dans rapport/notes_de_redaction.md.
-- 3. S4 : xlsx uniquement, confirmé le 17.08 (SIPRI-Milex-data-1949-
--    2025_v1.2.xlsx, nom versionné donc variable). Les deux liaisons
--    csv_generique sont supprimées ; S4 attend le connecteur xlsx
--    (groupe 2) — aucune liaison tant que le connecteur n'existe pas.
--
-- L'ACTIVATION n'est PAS dans cette migration : script séparé
-- activation_lot1_2026-08-17.sql, acte nominatif de l'étudiant.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_dedoublonnage_lot1.sql
--
-- Non destructive pour le registre : aucune écriture dans indicator_values.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Suppression des liaisons écartées (sélection par url_base, pas par
--    binding_id — les identifiants ne sont pas stables entre bases).
-- ---------------------------------------------------------------------

-- A3, ancienne liaison page-produit (avertissement reporté en notes de rédaction)
DELETE FROM source_bindings
WHERE indicator_id = 'A3' AND statut = 'a_verifier'
  AND url_base = 'https://www.iea.org/data-and-statistics/data-product/global-ev-outlook-2026';

-- M3, liaison Banque mondiale — substitution sans objet, l'OMS répond
DELETE FROM source_bindings
WHERE indicator_id = 'M3' AND statut = 'a_verifier'
  AND url_base LIKE 'https://api.worldbank.org%';

-- S4, les deux liaisons csv_generique — xlsx confirmé, bascule groupe 2
DELETE FROM source_bindings
WHERE indicator_id = 'S4' AND statut = 'a_verifier'
  AND connecteur = 'csv_generique';

-- ---------------------------------------------------------------------
-- 2. A3 — correction de la liaison du 17.08 en liaison annuelle 2023,
--    d'après la réponse réelle : year obligatoire, filtres sur
--    parameter/powertrain/unit (le flux mélange sales, stock, parts).
--    Les libellés d'agrégats (World, Europe, European Union, Advanced
--    Economies, Developing Economies excl. China, Africa, Asia Pacific,
--    Latin America…) coexistent avec les pays : à tenir hors classements
--    côté restitution (motif OWID_WRL, limite § 10.6).
-- ---------------------------------------------------------------------
UPDATE source_bindings
SET params  = '{"csv":"true","mode":"Cars","category":"Historical","parameters":"EV sales","year":"2023"}'::jsonb,
    mapping = '{"colonne_periode":"year","colonne_valeur":"value","colonne_code":"region","filtres":{"parameter":["EV sales"],"powertrain":["EV"],"unit":["Vehicles"]}}'::jsonb,
    note    = 'Réponse réelle vue le 17.08.2026 : CSV region,category,parameter,mode,powertrain,year,unit,value ; year obligatoire ; granularité pays confirmée, agrégats mêlés aux pays (à exclure des classements côté page). Filtres : EV sales / EV / Vehicles.'
WHERE indicator_id = 'A3' AND statut = 'a_verifier'
  AND url_base = 'https://api.iea.org/evs';

-- Liaisons sœurs 2024 et 2025 (réponses réelles à voir avant activation)
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note)
SELECT indicator_id, connecteur, url_base,
       jsonb_set(params, '{year}', to_jsonb(a.annee)),
       mapping, geo_defaut, 'a_verifier',
       'Liaison sœur de la fenêtre 2023 (motif H1, une liaison par année). Réponse réelle de cette année À VOIR avant activation.'
FROM source_bindings, (VALUES ('2024'), ('2025')) AS a(annee)
WHERE indicator_id = 'A3' AND url_base = 'https://api.iea.org/evs'
  AND params->>'year' = '2023'
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

-- ---------------------------------------------------------------------
-- 3. M3 — filtre serveur ajouté (constaté fonctionnel le 17.08),
--    le periode_min du mapping reste en ceinture et bretelles.
-- ---------------------------------------------------------------------
UPDATE source_bindings
SET params = '{"$filter":"TimeDim ge 2023"}'::jsonb,
    note   = 'Réponse réelle vue le 17.08.2026 : OData, liste sous value, SpatialDim ISO3, TimeDim, NumericValue, données 2023+ (part du PIB). Filtre serveur constaté fonctionnel. La composante USD/habitant de M3 exigerait une seconde liaison (autre code GHED) — non couverte, à documenter.'
WHERE indicator_id = 'M3' AND statut = 'a_verifier'
  AND url_base = 'https://ghoapi.azureedge.net/api/GHED_CHEGDP_SHA2011';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. Plus aucun doublon : A3 = 3 liaisons annuelles, M3 = 1, S4 = 0'
SELECT indicator_id, count(*) AS liaisons, string_agg(params->>'year', ', ' ORDER BY params->>'year') AS annees
FROM source_bindings
WHERE indicator_id IN ('A3','M3','S4') AND statut = 'a_verifier'
GROUP BY indicator_id ORDER BY indicator_id;

\echo ''
\echo '--- 2. Décompte global : 4 a_verifier (A3 x3, M3 x1), 14 actives inchangées'
SELECT statut, count(*) FROM source_bindings GROUP BY statut ORDER BY statut;

\echo ''
\echo '--- 3. Le registre n''est pas touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
