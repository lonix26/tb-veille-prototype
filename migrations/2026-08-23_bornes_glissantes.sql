-- =====================================================================
-- Bornes glissantes — 23.08.2026
--
-- CONSTAT. Quatre indicateurs énuméraient leurs périodes EN CLAIR dans la
-- liaison : relancer la collecte recollectait indéfiniment les mêmes mois.
-- H1 s'arrêtait à 2026-05 quelle que soit la date d'exécution, alors que la
-- source publie jusqu'à 2026-07. Un dispositif dont les séries ne peuvent
-- pas avancer contredit la décision acquise « le dispositif accumule des
-- exécutions datées, c'est l'écart entre runs qui fait la tendance ».
--
-- NE SONT PAS CONCERNÉS — et la vérification a corrigé un diagnostic trop
-- large : A5, M2, T1, T2, T5 et T7 portent une borne de DÉBUT ouverte
-- (`sinceTimePeriod`, `startPeriod`, `fromDate`), à laquelle la source
-- répond jusqu'au dernier point publié. Ils étaient DÉJÀ glissants.
--
-- CE QUI CHANGE. La liaison déclare désormais une RÈGLE au lieu d'un
-- littéral, résolue à l'exécution par le nœud « Préparer les appels ».
-- L'auditabilité est préservée : le workflow archive l'URL exacte appelée
-- et le corps résolu — la trace reste littérale, seule l'intention devient
-- lisible. « Les douze derniers mois » plutôt que « ces douze mois-là ».
--
-- Le mois COURANT n'est jamais collecté : il est incomplet, et une valeur
-- partielle prise pour une valeur mensuelle fausserait toute variation.
--
-- HISTORIQUE CONSERVÉ FIGÉ. Les liaisons des années révolues (H1 2023,
-- 2024, 2025) ne sont PAS touchées : ces périodes sont closes, leurs bornes
-- font légitimement partie de l'audit. Seule la liaison courante roule, et
-- elle recouvre les douze derniers mois — le recouvrement avec l'historique
-- est voulu : il revérifie les points récents à chaque exécution, ce qui est
-- exactement ce que « l'écart entre runs » suppose.
--
-- STATUT REMIS À `a_verifier`. Une liaison dont les paramètres changent n'est
-- plus la liaison qualifiée : la règle du § 7 impose que ses paramètres
-- soient revus EN RÉPONSE RÉELLE avant réactivation. C'est à l'étudiant de
-- les repasser en `actif`.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- H1 — Comtrade mensuel. La liaison de l'année courante devient glissante
-- sur douze mois (quota de périodes de l'API : une requête par lot d'un an).
UPDATE source_bindings
   SET params = jsonb_set(params, '{period}', '"{{MOIS_GLISSANTS:12}}"'),
       statut = 'a_verifier',
       note = coalesce(note || ' | ', '')
            || 'Bornes rendues glissantes le 23.08.2026 : « 202601,…,202605 » remplacé par '
            || '{{MOIS_GLISSANTS:12}}. À revoir en réponse réelle avant réactivation.'
 WHERE binding_id = 23;

-- M1 — Comtrade annuel : les quatre dernières années, année courante incluse.
UPDATE source_bindings
   SET params = jsonb_set(params, '{period}', '"{{ANNEES_LISTE:4}}"'),
       statut = 'a_verifier',
       note = coalesce(note || ' | ', '')
            || 'Bornes rendues glissantes le 23.08.2026 : « 2023,2024,2025 » remplacé par '
            || '{{ANNEES_LISTE:4}}. À revoir en réponse réelle avant réactivation.'
 WHERE indicator_id = 'M1' AND statut = 'actif';

-- A3 — IEA, une liaison par année. Celle de 2025 devient l'année courante ;
-- 2023 et 2024 restent figées (années closes).
UPDATE source_bindings
   SET params = jsonb_set(params, '{year}', '"{{ANNEE_COURANTE}}"'),
       statut = 'a_verifier',
       note = coalesce(note || ' | ', '')
            || 'Bornes rendues glissantes le 23.08.2026 : année 2025 remplacée par '
            || '{{ANNEE_COURANTE}}. À revoir en réponse réelle avant réactivation.'
 WHERE binding_id = 28;

-- M7 — TED, sept fenêtres mensuelles. Chacune devient RELATIVE : la liaison
-- k couvre le mois (courant − k), et son mapping `periode_fixe` devient une
-- période relative résolue au même moment.
UPDATE source_bindings b
   SET params = jsonb_set(b.params, '{_corps,query}',
                  to_jsonb('classification-cpv IN (33100000) AND publication-date >= {{MOIS_DEBUT:'
                        || d.k || '}} AND publication-date < {{MOIS_FIN:' || d.k || '}}')),
       mapping = jsonb_set(b.mapping, '{periode_fixe}', to_jsonb('{{PERIODE:' || d.k || '}}'::text)),
       statut = 'a_verifier',
       note = coalesce(b.note || ' | ', '')
            || 'Fenêtre rendue relative le 23.08.2026 : mois (courant − ' || d.k || '). '
            || 'À revoir en réponse réelle avant réactivation.'
  FROM (VALUES (44,1),(43,2),(42,3),(41,4),(40,5),(39,6),(38,7)) AS d(bid, k)
 WHERE b.binding_id = d.bid;

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V41 : plus aucune liaison ACTIVE ne porte de période littérale.
--   V42 : les 10 liaisons modifiées sont en `a_verifier` — elles ne
--         repasseront `actif` que par un acte humain, après réponse réelle.
--   V43 : les liaisons d'années révolues (H1 2023-2025) restent figées et
--         actives : une période close n'a pas à rouler.
-- ---------------------------------------------------------------------

SELECT 'V41' AS verif, count(*) AS liaisons_actives_a_periode_litterale
FROM source_bindings
WHERE statut = 'actif'
  AND (params::text ~ '"period": "20[0-9]{2}' OR params::text ~ 'publication-date >= 20');

SELECT 'V42' AS verif, indicator_id, count(*) AS liaisons, statut
FROM source_bindings WHERE params::text LIKE '%{{%' GROUP BY 1,3 ORDER BY 1;

SELECT 'V43' AS verif, binding_id, indicator_id, statut,
       left(params->>'period', 46) AS periode
FROM source_bindings WHERE indicator_id = 'H1' ORDER BY binding_id;
