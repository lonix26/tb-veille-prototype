-- =====================================================================
-- A1 : le recouvrement inter-éditions comme contrôle de rang 1
--
-- CONSTAT (runs 182-186 du 31.08.2026). Le contrôle OICA prévu au workflow
-- est OPPORTUNISTE par construction : le site OICA applique son filtre
-- d'année en JavaScript côté client, et le serveur rend un lot arbitraire
-- de graphiques — demander 2023 peut servir 1999-2026 sans 2023. Quand
-- l'année passe, le contrôle tranche (9 concordances au run 182) ; sinon
-- il rend « non vérifiable », jamais un faux verdict.
--
-- MAIS la collecte pluri-éditions porte son propre contrôle déterministe :
-- chaque année est lue par DEUX éditions indépendantes du CCFA (2022 par
-- les éditions 2023 et 2024 ; 2023 par les éditions 2024 et 2025). Deux
-- publications qui concordent chiffre à chiffre valent vérité terrain ;
-- un écart est une RÉVISION DU PRODUCTEUR, rendue visible — c'est
-- littéralement « l'écart entre runs fait la tendance », appliqué aux
-- révisions. Premier relevé : 9 révisions sur ~38 recouvrements
-- (USA 2023 : 10 612 -> 10 639 milliers entre éditions).
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

DROP VIEW IF EXISTS v_a1_recouvrement_editions;
CREATE VIEW v_a1_recouvrement_editions AS
WITH lectures AS (
  -- une lecture par ÉDITION (dérivée de raw_ref), pas par run : les runs
  -- répétés d'un même document (182-184) ne valent qu'une lecture, sinon
  -- ils fabriquent des concordances triviales. L'ordre est celui des
  -- MILLÉSIMES d'édition, pas des run_id — le run de l'édition 2025 a
  -- tourné AVANT celui de l'édition 2024, l'ordre des runs mentirait.
  SELECT DISTINCT ON (period, geo, edition) period, geo, edition, value
  FROM (
    SELECT period, geo, value,
           CASE WHEN raw_ref LIKE '%CCFA-2023%' THEN 2023
                WHEN raw_ref LIKE '%CCFA-2024%' THEN 2024
                ELSE 2025 END AS edition
    FROM indicator_values WHERE indicator_id = 'A1'
  ) t
  ORDER BY period, geo, edition
),
ordonnees AS (
  SELECT *, row_number() OVER (PARTITION BY period, geo ORDER BY edition) AS rang
  FROM lectures
)
SELECT a.period, a.geo,
       a.edition AS edition_1, a.value AS premiere_publication,
       b.edition AS edition_2, b.value AS publication_suivante,
       b.value - a.value AS revision,
       CASE WHEN a.value = b.value THEN 'concorde' ELSE 'revision_producteur' END AS verdict
FROM ordonnees a
JOIN ordonnees b ON b.period = a.period AND b.geo = a.geo AND b.rang = a.rang + 1
WHERE a.value IS NOT NULL AND b.value IS NOT NULL;

COMMENT ON VIEW v_a1_recouvrement_editions IS
'Contrôle inter-éditions d''A1 : chaque année lue par deux éditions CCFA. concorde = vérité terrain par double publication ; revision_producteur = écart rendu visible (jamais écrasé).';

COMMIT;

\echo ''
\echo '--- Bilan du recouvrement'
SELECT verdict, count(*) FROM v_a1_recouvrement_editions GROUP BY 1;
\echo ''
\echo '--- Les révisions du producteur, en clair'
SELECT period, geo, premiere_publication, publication_suivante, revision
FROM v_a1_recouvrement_editions WHERE verdict = 'revision_producteur' ORDER BY period, geo;
