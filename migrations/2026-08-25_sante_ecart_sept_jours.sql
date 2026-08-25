-- 2026-08-25 — L'écart depuis sept jours : le tableau de bord cesse de décrire un état
--
-- LE DÉFAUT. La restitution affichait un NIVEAU — « l'horlogerie est nettement au-dessus
-- de sa norme » — sans jamais dire si c'était nouveau. Un dirigeant qui ouvre l'outil
-- chaque lundi ne pouvait pas distinguer une nouveauté d'une permanence. Or la veille
-- vit sur les écarts, et le § 5 du rapport l'écrit : « c'est l'écart entre exécutions
-- qui fait la tendance ». Le dispositif portait la matière — registre en ajout seul,
-- soixante et onze exécutions — et n'en tirait rien à l'écran.
--
-- POURQUOI SEPT JOURS ET NON « LA COLLECTE PRÉCÉDENTE ». Une campagne de collecte n'est
-- pas un run mais un GROUPE de runs : le collecteur générique, le collecteur de
-- classeurs et celui de la Fédération horlogère écrivent chacun le leur. « Le run
-- précédent » désignerait donc tantôt une campagne entière, tantôt un seul collecteur,
-- selon l'ordre d'exécution — une définition qui change de sens sans prévenir. La
-- fenêtre de sept jours est arbitraire mais STABLE, et elle correspond à la cadence de
-- lecture visée. Elle est déclarée en paramètre pour pouvoir être changée sans toucher
-- au calcul.
--
-- CE QUE LA FONCTION FAIT. Elle recalcule le score exactement comme `v_sante_secteur`,
-- sur les seules observations COLLECTÉES avant une date donnée. Le score d'il y a sept
-- jours est donc celui qu'un lecteur aurait vu ce jour-là, pas une reconstitution
-- rétrospective : le registre étant en ajout seul, l'état passé est intact.

CREATE OR REPLACE FUNCTION sante_a_la_date(p_limite timestamptz)
RETURNS TABLE (sector_code text, n_series bigint, score numeric)
LANGUAGE sql STABLE AS $$
  WITH courant AS (
    SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo)
           iv.indicator_id, iv.period, iv.geo, iv.value
      FROM indicator_values iv
     WHERE iv.validation_status = ANY (ARRAY['valide_source','pre_valide_consensus','valide_humain'])
       AND iv.collected_at <= p_limite
     ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC
  ), rang AS (
    SELECT c.indicator_id, c.period, c.value,
           row_number() OVER (PARTITION BY c.indicator_id ORDER BY c.period)::numeric AS t
      FROM courant c
      JOIN indicators i ON i.indicator_id = c.indicator_id
                       AND i.geo_reference IS NOT NULL AND c.geo = i.geo_reference
  ), droite AS (
    SELECT rang.indicator_id,
           regr_slope(rang.value::double precision, rang.t::double precision)     AS pente,
           regr_intercept(rang.value::double precision, rang.t::double precision) AS ordonnee,
           count(*) AS n_points
      FROM rang GROUP BY rang.indicator_id
  ), residus AS (
    SELECT r.indicator_id, r.t,
           r.value::double precision - (d.ordonnee + d.pente * r.t::double precision) AS residu
      FROM rang r JOIN droite d USING (indicator_id)
  ), resume AS (
    SELECT re.indicator_id,
           stddev_samp(re.residu)::numeric AS sd_residu,
           (array_agg(re.residu ORDER BY re.t DESC))[1]::numeric AS dernier_residu
      FROM residus re GROUP BY re.indicator_id
  ), par_indicateur AS (
    SELECT i.sector_code, i.indicator_id,
           r.dernier_residu / NULLIF(r.sd_residu, 0) * i.sens_favorable::numeric AS z
      FROM resume r JOIN droite d USING (indicator_id) JOIN indicators i USING (indicator_id)
     WHERE i.sens_favorable IN (-1, 1) AND i.status = 'certifie'
       AND r.sd_residu IS NOT NULL AND r.sd_residu > 0 AND d.n_points >= 8
  )
  SELECT p.sector_code, count(*),
         CASE WHEN count(*) >= 2 THEN round(avg(p.z), 2) END
    FROM par_indicateur p GROUP BY p.sector_code;
$$;

COMMENT ON FUNCTION sante_a_la_date(timestamptz) IS
  'Score de santé sectorielle tel qu''il était à une date donnée. Identique à v_sante_secteur, borné aux observations collectées avant cette date. Le registre étant en ajout seul, l''état passé est intact : ce n''est pas une reconstitution.';

-- ---------------------------------------------------------------------
-- L'écart, prêt à l'affichage. `jours` est porté dans la vue pour que
-- l'écran puisse dire « depuis sept jours » sans le supposer.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_sante_ecart AS
WITH avant AS (SELECT * FROM sante_a_la_date(now() - interval '7 days')),
     maintenant AS (SELECT * FROM sante_a_la_date(now()))
SELECT coalesce(m.sector_code, a.sector_code) AS sector_code,
       7                                       AS jours,
       m.score                                 AS score_courant,
       a.score                                 AS score_precedent,
       CASE WHEN m.score IS NOT NULL AND a.score IS NOT NULL
            THEN round(m.score - a.score, 2) END AS ecart,
       m.n_series                              AS series_courantes,
       a.n_series                              AS series_precedentes
  FROM maintenant m FULL JOIN avant a USING (sector_code);

COMMENT ON VIEW v_sante_ecart IS
  'Écart du score de santé sur sept jours, par secteur. Répond à la seule question qu''on pose vraiment à un dispositif de veille : qu''est-ce qui a changé depuis la dernière fois ?';

-- ---------------------------------------------------------------------
-- CE QUI EST ARRIVÉ DEPUIS SEPT JOURS, au niveau de la donnée.
--
-- L'écart de score peut être indisponible — c'est le cas au 25.08.2026, la
-- fenêtre d'historique ayant été élargie la veille : sept jours plus tôt, la
-- plupart des séries n'atteignaient pas le seuil de huit points et aucun score
-- n'était calculé. Le dire est plus honnête que de comparer deux grandeurs qui
-- ne portent pas sur le même périmètre.
--
-- Reste ce qui est toujours calculable et qui intéresse autant : quels
-- indicateurs ont AVANCÉ, et de combien de périodes.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_nouveautes_7j AS
WITH avant AS (
  SELECT indicator_id, max(period) AS p_max, count(DISTINCT period) AS n_periodes
    FROM indicator_values WHERE collected_at <= now() - interval '7 days'
   GROUP BY 1),
maintenant AS (
  SELECT indicator_id, max(period) AS p_max, count(DISTINCT period) AS n_periodes
    FROM indicator_values GROUP BY 1)
SELECT m.indicator_id, i.sector_code, i.label, i.latence, i.unit,
       a.p_max AS periode_avant, m.p_max AS periode_maintenant,
       coalesce(a.n_periodes, 0) AS periodes_avant, m.n_periodes AS periodes_maintenant,
       m.n_periodes - coalesce(a.n_periodes, 0) AS periodes_gagnees,
       (a.indicator_id IS NULL) AS entierement_nouveau
  FROM maintenant m
  JOIN indicators i USING (indicator_id)
  LEFT JOIN avant a USING (indicator_id)
 WHERE a.indicator_id IS NULL OR m.p_max > a.p_max OR m.n_periodes > a.n_periodes;

COMMENT ON VIEW v_nouveautes_7j IS
  'Indicateurs ayant gagné des périodes depuis sept jours. Répond à « qu''est-ce qui est arrivé ? » quand l''écart de score n''est pas calculable — par exemple après un changement de périmètre.';
