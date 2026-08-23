-- =====================================================================
-- Écartement motivé de la famille « marchés financiers » — 23.08.2026
--
-- Décision de l'étudiant du 23.08.2026, tracée dans
-- rapport/notes_de_redaction.md (« Décisions de conception du
-- 23.08.2026 », point 5). La qualification d'un flux est un acte humain
-- nominatif et daté : cette migration INSCRIT une décision déjà prise,
-- elle ne la prend pas. `qualified_by` porte le nom du décideur, pas
-- celui de l'exécutant.
--
-- MOTIF — reconnaissance du 22.08.2026, sur pièces :
--   * Stooq (source prévue) exige désormais une vérification de navigateur
--     par PREUVE DE TRAVAIL JavaScript. Les neuf symboles renvoient 404
--     sans en-tête de navigateur, et une page de défi avec. Le blocage
--     porte sur la SOURCE, pas sur les symboles : aucun des neuf n'a pu
--     être ni confirmé ni infirmé.
--   * Le dispositif n'a PAS été contourné, par principe : le protocole
--     d'exploration OSINT impose le respect des CGU et de robots.txt.
--     Contourner une protection anti-robot pour alimenter un travail dont
--     la thèse est la traçabilité serait contradictoire.
--   * Repli examiné et écarté : l'API `chart` de Yahoo Finance répond 429
--     et ses conditions d'utilisation sont restrictives.
--
-- STATUT ÉPISTÉMIQUE — identique à F4 (offres d'emploi) : l'écartement
-- documenté EST un résultat de recherche, pas un échec de collecte. Il
-- remplit la grille des neuf critères du protocole OSINT par un verdict
-- motivé, et alimente la sous-section « frontière légale et déontologique ».
--
-- PERSPECTIVE (au futur, jamais au présent) : une API de cours à clé
-- gratuite serait une piste de vague C. Elle n'a pas été instruite.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE flux_sources
   SET statut       = 'ecarte',
       qualified_by = 'N. Castillo',
       qualified_at = DATE '2026-08-23',
       note = note || ' | ÉCARTÉ le 23.08.2026 (décision tracée en notes de rédaction) : '
                   || 'Stooq impose une vérification de navigateur par preuve de travail '
                   || 'JavaScript, non contournée par principe (CGU, protocole OSINT). '
                   || 'Blocage au niveau de la source : les symboles n''ont pu être ni '
                   || 'confirmés ni infirmés. Repli Yahoo Finance écarté (429, CGU '
                   || 'restrictives). Une API de cours à clé gratuite serait une piste de '
                   || 'vague C, non instruite à ce jour.'
 WHERE famille = 'marches_financiers'
   AND statut  = 'a_verifier';

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V7 : les 4 flux de la famille sont 'ecarte', nominatifs et datés
--        (la contrainte chk_flux_qualifie_trace l'impose déjà : un statut
--        autre qu'a_verifier sans nom ni date est refusé par la base).
--   V8 : aucun item n'a été collecté pour ces flux — l'écartement ne
--        détruit donc aucune preuve.
-- ---------------------------------------------------------------------

SELECT 'V7' AS verif, flux_id, statut, qualified_by, qualified_at
FROM flux_sources WHERE famille = 'marches_financiers' ORDER BY flux_id;

SELECT 'V8' AS verif, COUNT(*) AS items_des_flux_ecartes
FROM flux_items fi JOIN flux_sources fs ON fs.flux_id = fi.flux_id
WHERE fs.famille = 'marches_financiers';
