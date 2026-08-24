-- ============================================================================
-- Divergence géographique — le constat, calculé et non rédigé. 24.08.2026.
--
-- Une répartition par pays ne dit rien à elle seule : c'est l'ÉCART entre le
-- premier marché et les autres qui fait la décision. « Le premier débouché
-- recule pendant que les autres progressent » est une phrase qu'un modèle
-- pourrait écrire ; ici elle est CALCULÉE, avec sa règle affichée, de sorte
-- qu'un lecteur puisse la contester.
--
-- RÈGLE, déclarée et contestable : il y a divergence lorsque la variation du
-- premier marché et la moyenne pondérée des autres sont de SIGNES OPPOSÉS, et
-- que l'écart entre les deux dépasse 5 points de pourcentage. Le seuil est un
-- choix ; il est ici pour être discuté, non pour être cru.
-- ============================================================================

BEGIN;

DROP VIEW IF EXISTS v_divergence_geographique;

CREATE VIEW v_divergence_geographique AS
WITH classe AS (
  SELECT g.*, row_number() OVER (PARTITION BY indicator_id ORDER BY part_pct DESC) AS rang
  FROM v_dynamique_geographique g
  WHERE poids_significatif
),
premier AS (SELECT * FROM classe WHERE rang = 1),
autres AS (
  SELECT indicator_id,
         count(*) AS n_autres,
         round(sum(variation_pct * part_pct) / nullif(sum(part_pct),0), 1) AS var_moy_ponderee,
         count(*) FILTER (WHERE variation_pct > 0) AS n_en_hausse,
         count(*) FILTER (WHERE variation_pct < 0) AS n_en_recul
  FROM classe WHERE rang > 1 GROUP BY indicator_id
)
SELECT p.indicator_id, p.sector_code, p.label, p.unit,
       p.geo             AS premier_marche,
       p.part_pct        AS premier_part_pct,
       p.variation_pct   AS premier_variation_pct,
       a.n_autres, a.var_moy_ponderee, a.n_en_hausse, a.n_en_recul,
       p.base_comparaison, p.periode_ref,
       (sign(p.variation_pct) <> sign(a.var_moy_ponderee)
        AND abs(p.variation_pct - a.var_moy_ponderee) >= 5) AS divergence,
       round(p.variation_pct - a.var_moy_ponderee, 1) AS ecart_points
FROM premier p JOIN autres a USING (indicator_id);

COMMENT ON VIEW v_divergence_geographique IS
  'Écart entre le premier débouché d''un indicateur et la moyenne pondérée des '
  'autres. Divergence déclarée quand les signes s''opposent et que l''écart '
  'atteint 5 points. Le seuil est un choix affiché, pas une vérité.';

COMMIT;

SELECT indicator_id, sector_code, premier_marche, premier_part_pct AS part,
       premier_variation_pct AS var_premier, var_moy_ponderee AS var_autres,
       ecart_points, divergence
FROM v_divergence_geographique ORDER BY divergence DESC, abs(ecart_points) DESC;
