-- ============================================================================
-- SCORE DE SANTÉ DÉTENDANCÉ — N. Castillo, 24.08.2026. Fondement : § 5.6.
--
-- CE QUI EST CORRIGÉ, ET COMMENT ON L'A SU.
-- Le score valait (dernière valeur − moyenne) ÷ écart-type. Sur une série qui
-- croît régulièrement, la dernière observation est MÉCANIQUEMENT loin au-dessus
-- de sa moyenne : la mesure capte la pente, pas la position dans le cycle.
--
-- Mesuré le 24.08.2026 sur les 17 indicateurs entrant alors dans le score :
-- corrélation de 0,639 entre |corrélation de la série au temps| et |contribution
-- au score|. Quatre dixièmes de la variance du score s'expliquaient par la
-- tendance de la série, non par sa conjoncture. Conséquence pratique : un
-- secteur dont les indicateurs croissent affichait « nettement au-dessus » en
-- permanence, et le dispositif ne pouvait signaler AUCUN retournement — ce qui
-- est la fonction même d'un outil de veille.
--
-- LA CORRECTION. On ajuste une droite sur chaque série, on prend le RÉSIDU, et
-- l'on standardise ce résidu. Le score devient la position par rapport au
-- régime récent, comparable entre indicateurs de dynamiques différentes.
--
-- CE QU'ON NE JETTE PAS. La tendance reste une information — décisive pour un
-- déclin structurel, où la pente EST le sujet. Elle est donc conservée en
-- colonne à côté du score, jamais à sa place. Les deux lectures coexistent :
-- la position pour l'alerte, la pente pour la stratégie.
--
-- L'ANCIENNE VUE EST CONSERVÉE sous v_sante_secteur_brut : la comparaison des
-- deux est elle-même un résultat, et le rapport la cite.
-- ============================================================================

BEGIN;

-- ── L'ancienne définition, conservée pour la comparaison ────────────────────
DROP VIEW IF EXISTS v_sante_secteur_brut;
CREATE VIEW v_sante_secteur_brut AS
WITH courant AS (
  SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo)
         iv.indicator_id, iv.period, iv.geo, iv.value
  FROM indicator_values iv
  WHERE iv.validation_status IN ('valide_source','pre_valide_consensus','valide_humain')
  ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC
), stats AS (
  SELECT c.indicator_id, avg(c.value) AS moyenne, stddev_samp(c.value) AS ecart_type,
         count(*) AS n_points,
         (array_agg(c.value ORDER BY c.period DESC))[1] AS derniere_valeur
  FROM courant c
  JOIN indicators i ON i.indicator_id = c.indicator_id
                   AND i.geo_reference IS NOT NULL AND c.geo = i.geo_reference
  GROUP BY c.indicator_id
)
SELECT i.sector_code, count(*) AS n_indicateurs,
       CASE WHEN count(*) >= 2 THEN round(avg((st.derniere_valeur - st.moyenne)
            / NULLIF(st.ecart_type,0) * i.sens_favorable::numeric), 2) END AS score_brut
FROM stats st JOIN indicators i USING (indicator_id)
WHERE i.sens_favorable IN (-1,1) AND i.status='certifie'
  AND st.ecart_type IS NOT NULL AND st.ecart_type > 0 AND st.n_points >= 8
GROUP BY i.sector_code;

COMMENT ON VIEW v_sante_secteur_brut IS
  'Définition ANTÉRIEURE au 24.08.2026 : écart standardisé sur série brute. '
  'Conservée pour documenter l''écart avec la définition détendancée — elle '
  'mesure la pente autant que la position (corrélation 0,64 à la tendance).';

-- ── La définition détendancée ───────────────────────────────────────────────
DROP VIEW IF EXISTS v_sante_secteur;

CREATE VIEW v_sante_secteur AS
WITH courant AS (
  SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo)
         iv.indicator_id, iv.period, iv.geo, iv.value
  FROM indicator_values iv
  WHERE iv.validation_status IN ('valide_source','pre_valide_consensus','valide_humain')
  ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC
),
rang AS (   -- un temps NUMÉRIQUE et régulier : le rang chronologique
  SELECT c.indicator_id, c.period, c.value,
         row_number() OVER (PARTITION BY c.indicator_id ORDER BY c.period)::numeric AS t
  FROM courant c
  JOIN indicators i ON i.indicator_id = c.indicator_id
                   AND i.geo_reference IS NOT NULL AND c.geo = i.geo_reference
),
droite AS (   -- l'ajustement linéaire, par indicateur
  SELECT indicator_id,
         regr_slope(value, t)     AS pente,
         regr_intercept(value, t) AS ordonnee,
         corr(value, t)::numeric AS tendance,       -- conservée : c'est une information
         count(*)                 AS n_points,
         max(t)                   AS t_max
  FROM rang GROUP BY indicator_id
),
residus AS (
  SELECT r.indicator_id, r.period, r.t,
         r.value - (d.ordonnee + d.pente * r.t) AS residu
  FROM rang r JOIN droite d USING (indicator_id)
),
resume AS (
  SELECT re.indicator_id,
         stddev_samp(re.residu)::numeric AS sd_residu,
         (array_agg(re.residu ORDER BY re.t DESC))[1]::numeric AS dernier_residu
  FROM residus re GROUP BY re.indicator_id
),
par_indicateur AS (
  SELECT i.sector_code, i.indicator_id, d.n_points, d.tendance,
         (r.dernier_residu / NULLIF(r.sd_residu,0) * i.sens_favorable::numeric) AS z_detendance,
         -- La pente, exprimée en pourcentage du niveau moyen par période :
         -- lisible, et c'est elle qui porte la lecture stratégique.
         d.pente AS pente_par_periode
  FROM resume r
  JOIN droite d USING (indicator_id)
  JOIN indicators i USING (indicator_id)
  WHERE i.sens_favorable IN (-1,1) AND i.status = 'certifie'
    AND r.sd_residu IS NOT NULL AND r.sd_residu > 0 AND d.n_points >= 8
)
SELECT sector_code,
       count(*) AS n_indicateurs_orientables,
       CASE WHEN count(*) >= 2 THEN round(avg(z_detendance)::numeric, 2) END AS score_sante,
       CASE WHEN count(*) >= 2 THEN 'calcule' ELSE 'base_insuffisante' END AS etat,
       min(n_points) AS profondeur_min,
       array_agg(indicator_id ORDER BY indicator_id) AS indicateurs,
       -- La TENDANCE moyenne du secteur, conservée à côté du score et non à sa
       -- place : le score dit où l'on est dans le cycle, la tendance dit où va
       -- la branche. Les deux lectures répondent à des questions différentes.
       round(avg(tendance)::numeric, 2) AS tendance_moyenne,
       (SELECT count(*) FROM indicators x
         WHERE x.sector_code = p.sector_code AND x.status = 'certifie') AS indicateurs_certifies
FROM par_indicateur p
GROUP BY sector_code;

COMMENT ON VIEW v_sante_secteur IS
  'Score de santé DÉTENDANCÉ (§ 5.6, 24.08.2026) : résidu d''un ajustement '
  'linéaire, standardisé, orienté par sens_favorable. Mesure la position dans '
  'le cycle, non la pente — la pente est fournie séparément en tendance_moyenne. '
  'La définition antérieure reste consultable en v_sante_secteur_brut.';

COMMIT;

SELECT b.sector_code AS secteur, b.score_brut AS ancien,
       n.score_sante AS detendance, n.tendance_moyenne AS tendance,
       n.n_indicateurs_orientables AS n, n.profondeur_min AS profondeur
FROM v_sante_secteur_brut b FULL JOIN v_sante_secteur n USING (sector_code)
ORDER BY 1;
