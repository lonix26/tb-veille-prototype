-- =====================================================================
-- Migration du 21.08.2026 — H1 en partenaires EXHAUSTIFS
--
-- Décision (N. Castillo, sur constat d'angle mort du 20-21.08) : le
-- panier de partenaires de H1, fixé à la qualification (les principaux
-- marchés selon la FH), présuppose que les marchés qui compteront demain
-- sont ceux d'hier — structurellement aveugle aux entrants, à rebours de
-- QV2 (« où la demande se déplace-t-elle ? »). Le panier devient
-- exhaustif : la liste de partenaires est retirée des quatre fenêtres
-- (absence de filtre = tous les partenaires) et le top 10 affiché par la
-- restitution devient un RÉSULTAT calculé à chaque run, plus une
-- hypothèse d'entrée.
--
-- Vérifications fondant la révision :
--   - point d'accès et forme de réponse inchangés (mêmes fenêtres, même
--     endpoint à clé data/v1/get, même mapping — dépôts bruts H1
--     existants au dossier) ;
--   - comportement tous-partenaires vu en réponse réelle le 21.08 sur le
--     point d'accès public (qui plafonne à 500 lignes — c'est ce plafond
--     qui impose l'endpoint à clé, sans plafond à cette échelle).
--   - contrôle d'auto-cohérence APRÈS le premier run, que seul
--     l'exhaustif rend possible : la somme des partenaires doit
--     retomber sur la ligne monde (W00), aux arrondis près.
--
-- Portée : H1 SEULEMENT. Les paniers de déclarants (H3, M1, A4, S6)
-- posent un problème différent — 180 déclarants aux calendriers
-- indépendants, la règle d'unanimité du déclarant le plus lent devrait
-- devenir une règle de couverture — consigné en perspective, pas ici.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-21_H1_tous_partenaires.sql \
--     | tee ../annexe_5/H1_tous_partenaires_2026-08-21.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE source_bindings
SET params = params - 'partnerCode',
    note = 'Fenêtre H1 passée en partenaires exhaustifs le 21.08.2026 (retrait du filtre partnerCode — panier fixe devenu résultat calculé). Endpoint à clé requis : le point d''accès public plafonne à 500 lignes, constaté le 21.08. Auto-cohérence somme partenaires ≈ W00 à contrôler au premier run.'
WHERE indicator_id = 'H1' AND statut = 'actif'
  AND url_base = 'https://comtradeapi.un.org/data/v1/get/C/M/HS'
  AND params ? 'partnerCode';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. Les 4 fenêtres H1 sans filtre de partenaires, toujours actives'
SELECT substr(params->>'period', 1, 6) AS debut_fenetre,
       params ? 'partnerCode' AS filtre_encore_present, statut
FROM source_bindings WHERE indicator_id = 'H1'
ORDER BY params->>'period';

\echo ''
\echo '--- 2. Le registre n''est pas touché par cette migration'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;

-- =====================================================================
-- CONTRÔLE D'AUTO-COHÉRENCE — APRÈS le premier run (Execute collecteur) :
--
-- docker compose exec -T db psql -U veille -d veille -c "
--   WITH dernier AS (SELECT max(run_id) AS r FROM indicator_values WHERE indicator_id='H1')
--   SELECT count(DISTINCT geo) AS partenaires,
--          ROUND(SUM(value) FILTER (WHERE geo <> 'W00' AND NOT geo LIKE 'X%')::numeric/1e9, 2) AS somme_partenaires_mia,
--          ROUND(MAX(value) FILTER (WHERE geo = 'W00')::numeric/1e9, 2) AS ligne_monde_mia
--   FROM indicator_values, dernier
--   WHERE indicator_id='H1' AND run_id=dernier.r AND period='2026-05';"
--
-- Attendu : ~150-220 partenaires, et somme ≈ ligne monde (l'écart
-- résiduel, s'il existe, vient des zones non spécifiées 'X*' de
-- Comtrade — à lire, pas à masquer).
-- =====================================================================
