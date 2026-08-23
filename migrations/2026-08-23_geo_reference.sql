-- =====================================================================
-- Migration du 23.08.2026 — geo_reference déclaré, et seuil d'affichage
-- de la santé sectorielle.
--
-- Décisions de l'étudiant du 23.08.2026 (rapport/notes_de_redaction.md,
-- « Décisions de conception du 23.08.2026 ») :
--
--   1. La série de référence d'un indicateur est une DÉCLARATION HUMAINE,
--      jamais une heuristique. La version du 23.08 de v_sante_secteur
--      retenait « la zone la plus fournie, départage alphabétique » : sur
--      H1, où 42 zones sont à égalité à 41 points, cela désignait AND —
--      l'Andorre — alors que les marchés principaux (ARE, CHN, DEU, FRA,
--      GBR, HKG, ITA, JPN) portent 612 observations chacun. Le même
--      mécanisme donnait AFG pour M3, CZE pour A4, CAN pour S6, CHN pour S3.
--      La santé de l'horlogerie suisse aurait été calculée sur les
--      exportations vers l'Andorre : un résultat faux présenté comme un
--      score. Défaut de conception assumé, corrigé ici.
--
--      C'est la TROISIÈME occurrence du même motif — hypothèse implicite
--      transformée en déclaration explicite — après `admet_negatifs`
--      (négativité et variation relative des soldes d'opinion) et
--      `sens_favorable` (orientation de lecture). Le motif est à rédiger
--      au rapport : ce que le code présume, la base doit l'exiger écrit.
--
--   2. Un score de santé ne s'affiche qu'à partir de DEUX indicateurs
--      orientables. En dessous, la vue le dit en toutes lettres plutôt
--      que de rendre une moyenne d'un seul terme : une moyenne d'un terme
--      n'est pas une moyenne, et un score adossé à un indicateur unique
--      surdéclare par sa forme même, quand bien même le chiffre serait juste.
--      La vue ne CACHE pas le cas : elle le nomme (`base_insuffisante`),
--      pour que le tableau de bord puisse l'écrire au lieu de l'omettre.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-23_geo_reference.sql \
--     | tee ../annexe_5/migration_geo_reference_2026-08-23.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ---------------------------------------------------------------------
-- 1. La série de référence devient une déclaration
-- ---------------------------------------------------------------------

ALTER TABLE indicators ADD COLUMN IF NOT EXISTS geo_reference TEXT;

COMMENT ON COLUMN indicators.geo_reference IS
  'Zone de la série retenue pour le calcul de la santé sectorielle. DÉCLARATION HUMAINE : NULL = non déclaré, l''indicateur n''entre pas dans v_sante_secteur. Remplace l''heuristique « zone la plus fournie » du 23.08, qui désignait l''Andorre pour H1 (42 zones à égalité, départage alphabétique). Troisième application de la doctrine admet_negatifs / sens_favorable : ce que le code présumerait, la base l''exige écrit.';

-- ---------------------------------------------------------------------
-- 2. Santé sectorielle — sur déclaration seulement, et à partir de deux
-- ---------------------------------------------------------------------

-- La vue gagne une colonne `etat` en position médiane : CREATE OR REPLACE
-- refuse de renommer/insérer une colonne, il faut donc la reconstruire.
-- Aucune dépendance sur cette vue à ce jour (vérifié par le DROP sans CASCADE :
-- s'il en existait une, la migration échouerait ici plutôt que de la supprimer).
DROP VIEW IF EXISTS v_sante_secteur;

CREATE VIEW v_sante_secteur AS
WITH courant AS (
    -- dernière valeur retenue par (indicateur, période, zone) : dernier run
    SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo)
           iv.indicator_id, iv.period, iv.geo, iv.value
    FROM indicator_values iv
    WHERE iv.validation_status IN ('valide_source','pre_valide_consensus','valide_humain')
    ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC
),
stats AS (
    -- La série de référence n'est plus devinée : elle est lue dans la
    -- déclaration. Un indicateur sans geo_reference ne produit pas de ligne.
    SELECT c.indicator_id,
           AVG(c.value)         AS moyenne,
           STDDEV_SAMP(c.value) AS ecart_type,
           COUNT(*)             AS n_points,
           (ARRAY_AGG(c.value  ORDER BY c.period DESC))[1] AS derniere_valeur,
           (ARRAY_AGG(c.period ORDER BY c.period DESC))[1] AS derniere_periode
    FROM courant c
    JOIN indicators i
      ON i.indicator_id = c.indicator_id
     AND i.geo_reference IS NOT NULL
     AND c.geo = i.geo_reference
    GROUP BY c.indicator_id
)
SELECT i.sector_code,
       COUNT(*) AS n_indicateurs_orientables,
       -- En dessous de deux indicateurs, aucun score : la vue nomme le cas
       -- au lieu de rendre une moyenne d'un seul terme.
       CASE WHEN COUNT(*) >= 2
            THEN ROUND(AVG( (st.derniere_valeur - st.moyenne) / NULLIF(st.ecart_type, 0)
                            * i.sens_favorable )::numeric, 2)
       END AS score_sante,
       CASE WHEN COUNT(*) >= 2 THEN 'calcule' ELSE 'base_insuffisante' END AS etat,
       MIN(st.n_points) AS profondeur_min,
       ARRAY_AGG(i.indicator_id ORDER BY i.indicator_id) AS indicateurs
FROM stats st
JOIN indicators i ON i.indicator_id = st.indicator_id
WHERE i.sens_favorable IN (-1, 1)
  AND i.status = 'certifie'
  AND st.ecart_type IS NOT NULL AND st.ecart_type > 0
  AND st.n_points >= 8
GROUP BY i.sector_code;

COMMENT ON VIEW v_sante_secteur IS
  'Score de santé par secteur : moyenne des écarts standardisés (dernière valeur contre la base de la série DÉCLARÉE en geo_reference), orientés par sens_favorable. Calcul déterministe — aucune IA. Deux garde-fous explicites : la série de référence est déclarée et non devinée (défaut « Andorre » du 23.08) ; en dessous de deux indicateurs orientables, aucun score n''est rendu et l''état vaut base_insuffisante — le tableau de bord doit l''écrire en toutes lettres, jamais masquer le secteur.';

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V5 : la colonne geo_reference existe et vaut NULL partout (aucune
--        déclaration n'est semée par cette migration — la déclaration est
--        un acte humain, elle passera par une migration de revue).
--   V6 : v_sante_secteur retourne 0 ligne, puisque aucune geo_reference
--        n'est déclarée. C'est l'attendu, et c'est le point : la vue ne
--        calcule plus rien tant que rien n'est déclaré, là où l'ancienne
--        version calculait déjà — sur l'Andorre.
-- ---------------------------------------------------------------------

SELECT 'V5' AS verif,
       COUNT(*) FILTER (WHERE geo_reference IS NULL) AS non_declares,
       COUNT(*) AS total_indicateurs
FROM indicators;

SELECT 'V6' AS verif, COUNT(*) AS lignes_sante_avant_declarations FROM v_sante_secteur;
