-- =====================================================================
-- Profondeur des séries annuelles — 24.08.2026
--
-- CONSTAT. Sept indicateurs annuels comptent EXACTEMENT trois points,
-- 2023-2025, quelle que soit leur source. Ce n'est pas la source qui
-- limite : c'est la liaison. Deux mécanismes distincts, tous deux
-- déclarés et donc corrigibles :
--
--   * S3 et S4 portent « periode_min: 2023 » dans leur MAPPING. Le fichier
--     source est intégralement téléchargé — Our World in Data remonte à
--     1957 pour les lancements spatiaux, SIPRI à 1949 pour les dépenses
--     militaires — puis tronqué à la lecture. La donnée était là.
--   * H3, M1, A4 et S6 demandent « {{ANNEES_LISTE:4}} » à Comtrade.
--
-- POURQUOI CELA COMPTE. Le seuil d'éligibilité de v_sante_secteur est de
-- huit points. Avec trois, aucun de ces indicateurs n'entre dans le score
-- de santé — ce qui laisse horlogerie, automobile et aérospatial en
-- « base insuffisante » sur un indicateur unique. Le plancher de 2023
-- était un choix de démarrage ; il est devenu la cause du silence du
-- tableau de bord.
--
-- CHOIX DES BORNES, et pourquoi pas plus :
--   * 2010 pour S3 et S4 : seize points, assez pour une base solide, et
--     assez récent pour que la comparaison garde un sens économique. Une
--     moyenne calculée sur 1957-2025 dirait peu de chose du marché actuel.
--   * douze années pour Comtrade : c'est la limite de périodes par requête
--     de l'API. Au-delà, il faudrait fractionner les appels.
--
-- STATUT REMIS À `a_verifier` : une liaison dont les paramètres changent
-- n'est plus la liaison qualifiée (§ 7). À revoir en réponse réelle.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- S3, S4 : abaisser le plancher de lecture. Aucun changement d'appel — le
-- fichier téléchargé contenait déjà ces années.
UPDATE source_bindings
   SET mapping = jsonb_set(mapping, '{periode_min}', '"2010"'),
       statut = 'a_verifier',
       note = coalesce(note || ' | ', '')
            || 'Plancher de lecture abaissé de 2023 à 2010 le 24.08.2026 : la source contenait '
            || 'déjà ces années, le mapping les écartait. Objectif — franchir le seuil de huit '
            || 'points de v_sante_secteur.'
 WHERE indicator_id IN ('S3', 'S4') AND mapping ? 'periode_min';

-- H3, M1, A4, S6 : douze années au lieu de quatre (limite de l'API Comtrade).
UPDATE source_bindings
   SET params = jsonb_set(params, '{period}', '"{{ANNEES_LISTE:12}}"'),
       statut = 'a_verifier',
       note = coalesce(note || ' | ', '')
            || 'Fenêtre portée de 4 à 12 années le 24.08.2026 (limite de périodes par requête '
            || 'de l''API Comtrade). Objectif — franchir le seuil de huit points.'
 WHERE indicator_id IN ('H3', 'M1', 'A4', 'S6')
   AND params->>'period' = '{{ANNEES_LISTE:4}}';

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus AVANT exécution :
--   V51 : six liaisons modifiées, toutes en `a_verifier`.
--   V52 : le registre n'est PAS touché — la profondeur n'arrive qu'après
--         collecte, sous un run daté.
--   V53 : rappel de l'état d'éligibilité AVANT collecte, pour comparaison.
-- ---------------------------------------------------------------------

SELECT 'V51' AS verif, indicator_id, statut,
       coalesce(params->>'period', 'mapping periode_min=' || (mapping->>'periode_min')) AS fenetre
FROM source_bindings
WHERE indicator_id IN ('S3','S4','H3','M1','A4','S6') ORDER BY indicator_id;

SELECT 'V52' AS verif, count(*) AS observations FROM indicator_values;

SELECT 'V53' AS verif, sector_code, n_indicateurs_orientables, etat FROM v_sante_secteur ORDER BY sector_code;
