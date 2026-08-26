-- =====================================================================
-- 2026-08-26 — ÉLAGAGE CORRIGÉ : de treize à vingt-huit indicateurs
--
-- POURQUOI REVENIR SUR L'ÉLAGAGE DU 25.08. Il était nécessaire — un tiers
-- de la grille ne collectait rien, des paires corrélaient à 0,99 — mais il
-- a été mal conduit, sur trois points reconnus le 26.08 :
--
--   1. LE SEUIL ÉTAIT ARBITRAIRE. « Treize » visait la lisibilité d'un
--      écran, pas la validité d'une grille. Or l'écran se règle par la
--      mise en page ; la grille se règle par des critères.
--   2. LE RAISONNEMENT ÉTAIT PAR INDICATEUR, JAMAIS PAR QUESTION. La règle
--      fondatrice du chapitre — pas d'indicateur sans question — n'était
--      vérifiée qu'APRÈS la coupe. Trois questions horlogères ont perdu
--      leur porteur sans que rien ne l'empêche.
--   3. LE SEUIL DE CORRÉLATION ÉTAIT TROP BAS. À 0,90, la coupe a retiré
--      A5 — alors que tout le § 8.6 est bâti sur l'ÉCART entre A5 et A6.
--      Le critère a été appliqué contre la thèse qu'il devait servir.
--
-- CE QUE FAIT CETTE MIGRATION. Elle ne retire que l'INDÉFENDABLE, recalculé
-- depuis les données et non repris de la liste précédente :
--
--   — 8 indicateurs sans AUCUNE observation (A1, A8, H4, H5, M5, S1, S2,
--     S5) : en attente d'instrumentation, pas écartés sur le fond ;
--   — 5 sous le seuil de huit points, seuil déjà retenu pour lire une
--     série (A3, H2, M3, M4, T4) ;
--   — 2 dont le dernier point date de 2022 (A7, M6 — brevets, publiés avec
--     un retard qui les rend inutilisables en conjoncture) ;
--   — 1 doublon quasi parfait : H8, corrélé à 0,992 avec H7 sur 19 points
--     communs, même communiqué de la Fédération horlogère. C'est LA SEULE
--     paire au-dessus de 0,95 de tout le référentiel — le seuil de 0,90
--     du 25.08 en avait condamné cinq de plus, dont A5 et H1.
--
-- UNE EXCEPTION MOTIVÉE : A2 est conservé malgré ses sept points. C'est le
-- SEUL indicateur composite de la grille, donc le seul qui démontre la
-- chaîne extraction multi-modèles → consensus → validation humaine, qui
-- est le cœur de la thèse. Le critère 5 — apporter un rôle que le secteur
-- n'a pas déjà — prime ici sur le critère 1. L'exception est écrite plutôt
-- que silencieuse, et l'écran signale sa série courte.
--
-- LE SIXIÈME CRITÈRE, AJOUTÉ : PRÉSERVER LA COUVERTURE DES QUESTIONS.
-- Aucun indicateur n'est retiré s'il est le dernier à porter une question
-- de veille pour son secteur. Vérification faite : la sélection ci-dessous
-- ne prive AUCUNE question de son dernier porteur. Les cinq questions
-- restées découvertes (aérospatial QV4 ; automobile QV3, QV4, QV5 ;
-- horlogerie QV4, QV5) l'étaient DÉJÀ AVANT tout élagage — ce sont des
-- lacunes de grille, documentées au § 8.4.5, et non des victimes de la
-- coupe. La distinction est essentielle : un cadre invariant sert
-- précisément à ne pas confondre les deux.
-- =====================================================================

BEGIN;

-- Tout revient en vitrine, puis on retire l'indéfendable. Recalculé, pas recopié.
UPDATE indicators SET en_vitrine = true WHERE status IN ('certifie', 'a_confirmer');

WITH pts AS (
  SELECT i.indicator_id, count(DISTINCT v.period) AS n, max(v.period) AS p_max
    FROM indicators i
    LEFT JOIN indicator_values v ON v.indicator_id = i.indicator_id AND v.geo = i.geo_reference
   WHERE i.status IN ('certifie', 'a_confirmer')
   GROUP BY 1),
retires AS (
  SELECT indicator_id FROM pts
   WHERE (n < 8 AND indicator_id <> 'A2')                      -- A2 : seul composite (critère 5)
      OR left(coalesce(p_max, '1900'), 4)::int <= 2022          -- publication trop retardée
  UNION SELECT 'H8')                                           -- r = 0,992 avec H7
UPDATE indicators SET en_vitrine = false
 WHERE indicator_id IN (SELECT indicator_id FROM retires);

-- Les motifs du 25.08 qui ne valent plus sont retirés des descriptions :
-- un indicateur remis en vitrine ne doit pas porter la trace d'un retrait annulé.
UPDATE indicators
   SET description_metier = regexp_replace(description_metier,
         ' \[HORS VITRINE le 25\.08\.2026[^\]]*\]', '', 'g')
 WHERE en_vitrine AND description_metier LIKE '%HORS VITRINE le 25.08.2026%';

COMMIT;
