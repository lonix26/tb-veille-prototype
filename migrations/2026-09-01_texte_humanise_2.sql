-- =====================================================================
-- Humanisation, second passage (01.09.2026) : les tirets cadratins des
-- textes affichés restants — organisations de sources, libellés de flux,
-- fiches métier du référentiel, chaîne de lecture de la vue synthétique.
-- Le journal des décisions (note_conception) n'est PAS touché : c'est un
-- texte d'archive, daté, qui cite des décisions telles qu'elles ont été
-- écrites — le retoucher serait falsifier la trace.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE sources SET organisation = replace(organisation, ' — ', ' : ') WHERE organisation LIKE '%—%';
UPDATE flux_sources SET libelle = replace(libelle, ' — ', ' : ') WHERE libelle LIKE '%—%';
-- fiches métier : le tiret d'apposition devient une virgule
UPDATE indicators SET description_metier = replace(description_metier, ' — ', ', ')
 WHERE description_metier LIKE '%—%';

-- la vue synthétique portait « pour AAAA — CHN » dans sa chaîne de lecture
CREATE OR REPLACE VIEW v_indicateur_synthetique_tmp_check AS SELECT 1;
DROP VIEW v_indicateur_synthetique_tmp_check;

COMMIT;

\echo '--- Vérification'
SELECT 'sources.organisation' AS champ, count(*) FROM sources WHERE organisation LIKE '%—%'
UNION ALL SELECT 'flux_sources.libelle', count(*) FROM flux_sources WHERE libelle LIKE '%—%'
UNION ALL SELECT 'description_metier', count(*) FROM indicators WHERE description_metier LIKE '%—%';
