-- 2026-08-25 — Les vues suivent la vitrine, et le score quitte l'écran de décision
--
-- SUITE DE L'ÉLAGAGE. Deux conséquences, dont une décision.
--
-- 1. Le score et les métriques portent désormais sur les indicateurs EN VITRINE.
--    Sans cela, l'écran afficherait treize indicateurs et calculerait sur quarante-quatre.
--
-- 2. LE SCORE SECTORIEL QUITTE L'ÉCRAN DE DÉCISION. Avec deux séries par marché,
--    « la moyenne des écarts détendancés » n'est plus une mesure : c'est la moyenne
--    de deux nombres. Le construit était déjà le plus fragile du dispositif — moyenne
--    non pondérée, périodicités mêlées, séries corrélées comptées deux fois — et
--    l'élagage, en réduisant le nombre de séries, le rend indéfendable comme chiffre
--    affiché à un dirigeant.
--
--    Il n'est PAS supprimé. Il reste calculé, et il reste au rapport comme ce qu'il
--    est : une expérimentation méthodologique — comment construire une position
--    cyclique détendancée, et pourquoi elle n'est pas décisionnelle en l'état. Il est
--    visible sur l'écran Fiabilité, avec ses réserves. Il n'ouvre plus la journée d'un
--    décideur avec un nombre que personne ne sait interpréter.
--
--    Ce que l'écran montre à la place : LES INDICATEURS EUX-MÊMES. Treize séries
--    nommées, chacune avec sa dernière valeur, sa variation et son écart à sa propre
--    moyenne. C'est plus long à lire qu'un nombre, et infiniment plus interprétable.

BEGIN;

CREATE OR REPLACE VIEW v_sante_secteur AS
WITH courant AS (
  SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo)
         iv.indicator_id, iv.period, iv.geo, iv.value
    FROM indicator_values iv
   WHERE iv.validation_status = ANY (ARRAY['valide_source','pre_valide_consensus','valide_humain'])
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
         corr(rang.value::double precision, rang.t::double precision)::numeric  AS tendance,
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
  SELECT i.sector_code, i.indicator_id, d.n_points, d.tendance,
         r.dernier_residu / NULLIF(r.sd_residu, 0) * i.sens_favorable::numeric AS z_detendance,
         d.pente AS pente_par_periode
    FROM resume r JOIN droite d USING (indicator_id) JOIN indicators i USING (indicator_id)
   -- EN VITRINE, et non plus « certifié » : le score porte sur ce qui est suivi.
   WHERE i.en_vitrine AND i.sens_favorable IN (-1, 1)
     AND r.sd_residu IS NOT NULL AND r.sd_residu > 0 AND d.n_points >= 8
)
SELECT sector_code,
       count(*) AS n_indicateurs_orientables,
       CASE WHEN count(*) >= 2 THEN round(avg(z_detendance), 2) END AS score_sante,
       CASE WHEN count(*) >= 2 THEN 'calcule' ELSE 'base_insuffisante' END AS etat,
       min(n_points) AS profondeur_min,
       array_agg(indicator_id ORDER BY indicator_id) AS indicateurs,
       round(avg(tendance), 2) AS tendance_moyenne,
       (SELECT count(*) FROM indicators x WHERE x.sector_code = p.sector_code AND x.en_vitrine)
         AS indicateurs_certifies
  FROM par_indicateur p
 GROUP BY sector_code;

-- ---------------------------------------------------------------------
-- LA VITRINE, PRÊTE À L'AFFICHAGE. Une ligne par indicateur suivi, avec
-- ce qu'il faut pour le lire SANS passer par un score : sa dernière
-- valeur, sa variation, son écart à sa propre moyenne, son rôle.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_vitrine AS
-- DISTINCT ON : `v_metriques` rend une ligne par période. La vitrine ne montre
-- que le DERNIER point de chaque série — c'est un écran de décision, pas une
-- table de données. L'historique reste accessible par la page du marché.
SELECT DISTINCT ON (i.indicator_id)
       i.indicator_id, i.sector_code, sec.label AS sector_label, i.label,
       i.description_metier, i.unit, i.frequency, i.latence, i.category,
       i.sens_favorable, i.geo_reference,
       m.period, m.value, m.variation_periode_pct, m.glissement_annuel_pct,
       m.moyenne_mobile_annuelle, m.ecart_a_la_moyenne_pct, m.nb_points_moyenne,
       m.seuil_materialite_pct, m.franchissement,
       s.organisation AS source_organisation, s.url AS source_url,
       (SELECT count(DISTINCT v.period) FROM indicator_values v
         WHERE v.indicator_id = i.indicator_id AND v.geo = i.geo_reference) AS n_periodes
  FROM indicators i
  JOIN sectors sec ON sec.code = i.sector_code
  LEFT JOIN sources s ON s.source_id = i.source_id
  LEFT JOIN v_metriques m ON m.indicator_id = i.indicator_id AND m.geo = i.geo_reference
 WHERE i.en_vitrine
 ORDER BY i.indicator_id, m.period DESC NULLS LAST;

COMMENT ON VIEW v_vitrine IS
  'Les indicateurs suivis, prêts à l''affichage : dernière valeur, variation, écart à leur propre moyenne, rôle (annonce/constate/confirme) et source. Remplace le score sectoriel sur l''écran de décision — treize séries nommées sont plus interprétables qu''un nombre agrégé.';

COMMIT;
