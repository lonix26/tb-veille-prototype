-- =====================================================================
-- Bornes glissantes — complément — 23.08.2026
--
-- POURQUOI CE COMPLÉMENT EXISTE. La migration principale du même jour a
-- traité H1, M1, A3 et M7, identifiés par une requête de détection qui
-- cherchait un motif AAAAMM ou AAAA-MM. Trois indicateurs y ont échappé —
-- A4, H3 et S6 — parce que leur période est une liste d'ANNÉES SEULES
-- (« 2023,2024,2025 »), que ce motif ne reconnaissait pas.
--
-- Ils ont été rattrapés non par une relecture mais par le contrôle V41 de
-- la migration précédente, qui comptait les liaisons actives portant encore
-- une période littérale et en a trouvé six au lieu des trois attendues.
-- C'est exactement ce à quoi sert un attendu chiffré énoncé AVANT
-- exécution : il attrape ce que le diagnostic a manqué.
--
-- Les trois sont des séries Comtrade ANNUELLES, même forme que M1 : même
-- traitement, les quatre dernières années, année courante incluse.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE source_bindings
   SET params = jsonb_set(params, '{period}', '"{{ANNEES_LISTE:4}}"'),
       statut = 'a_verifier',
       note = coalesce(note || ' | ', '')
            || 'Bornes rendues glissantes le 23.08.2026 (complément) : « 2023,2024,2025 » '
            || 'remplacé par {{ANNEES_LISTE:4}}. Manqué par la détection initiale, rattrapé par '
            || 'le contrôle V41. À revoir en réponse réelle avant réactivation.'
 WHERE binding_id IN (15, 17, 18);

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications :
--   V44 : plus AUCUNE liaison active ne porte de période littérale, hors
--         les années révolues de H1 (2023, 2024, 2025) qui restent figées
--         à dessein — une période close n'a pas à rouler.
--   V45 : treize liaisons portent désormais une règle, toutes en
--         `a_verifier`.
-- ---------------------------------------------------------------------

SELECT 'V44' AS verif, binding_id, indicator_id, statut,
       left(coalesce(params->>'period', params->'_corps'->>'query'), 44) AS periode_litterale
FROM source_bindings
WHERE statut = 'actif'
  AND (params::text ~ '"period": "20[0-9]{2}' OR params::text ~ 'publication-date >= 20')
ORDER BY indicator_id, binding_id;

SELECT 'V45' AS verif, count(*) AS liaisons_a_regle,
       count(*) FILTER (WHERE statut = 'a_verifier') AS dont_a_verifier
FROM source_bindings WHERE params::text LIKE '%{{%';
