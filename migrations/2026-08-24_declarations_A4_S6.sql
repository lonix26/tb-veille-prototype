-- =====================================================================
-- Déclaration de geo_reference pour A4 et S6 — 24.08.2026
--
-- CE QUI REVIENT SUR UNE DÉCISION ANTÉRIEURE, ET POURQUOI. Le 23.08,
-- l'étudiant a délibérément laissé A4 et S6 SANS zone de référence. Le
-- motif était explicite et juste : « ils ont trois points et ne seront pas
-- éligibles avant longtemps ; déclarer une référence arbitraire ne gagne
-- rien et créerait un Andorre en puissance ».
--
-- LA PRÉMISSE A CHANGÉ. Depuis l'extension de la profondeur (fenêtre par
-- périodicité, 24.08), A4 et S6 comptent ONZE points sur huit et six zones
-- respectivement. Le choix n'est plus arbitraire faute de données : il est
-- arbitrable sur des séries complètes.
--
-- CHOIX ET MOTIFS — ce sont des jugements, à ratifier :
--   * A4 (commerce mondial de parties et accessoires automobiles, SH 8708)
--     → DEU. Premier exportateur de la série (61,6 mrd USD de moyenne, soit
--     45 % de plus que les États-Unis), et surtout premier débouché européen
--     de la sous-traitance suisse. Alternative défendable : CHN, en forte
--     progression.
--   * S6 (commerce mondial aéronautique et spatial, SH 88) → FRA. Les
--     États-Unis dominent la série (124 mrd contre 45), mais l'écosystème
--     accessible à un sous-traitant suisse est européen — Airbus, Safran.
--     Prendre USA mesurerait un marché sur lequel la PME ne vend pas.
--     C'est le choix le plus discutable de la journée : il privilégie la
--     PERTINENCE sur l'AMPLEUR, et l'inverse se défend.
--
-- Cette migration ne touche ni le sens de lecture ni la latence, déjà
-- déclarés le 23.08 et inchangés.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE indicators SET geo_reference = 'DEU' WHERE indicator_id = 'A4' AND geo_reference IS NULL;
UPDATE indicators SET geo_reference = 'FRA' WHERE indicator_id = 'S6' AND geo_reference IS NULL;

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus AVANT exécution :
--   V54 : A4 et S6 déclarés, 11 points chacun sur leur zone.
--   V55 : les CINQ secteurs calculent un score. Aucun ne reste en
--         « base insuffisante ».
-- ---------------------------------------------------------------------

SELECT 'V54' AS verif, indicator_id, sector_code, geo_reference, sens_favorable, latence
FROM indicators WHERE indicator_id IN ('A4','S6');

SELECT 'V55' AS verif, sector_code, n_indicateurs_orientables AS n, score_sante, etat,
       profondeur_min, indicateurs
FROM v_sante_secteur ORDER BY etat, sector_code;
