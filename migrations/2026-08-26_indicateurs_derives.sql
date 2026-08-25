-- =====================================================================
-- 2026-08-26 — LES INDICATEURS DÉRIVÉS : exploiter ce qui est déjà en base
--
-- Demande de la séance 4 (PV du 15.06.2026, § 4) restée sans suite :
-- « envisager, à partir de cette base, le développement de nouveaux
-- indicateurs synthétiques ». Analyse conduite le 26.08 sur les 122 000
-- observations ; trois dérivés retenus parce qu'ils DISCRIMINENT sur les
-- données réelles — les candidats muets ont été écartés.
--
-- 1. LA TENSION DE CHAÎNE (par marché, mensuelle). L'écart entre l'amont
--    d'un marché (demande finale ou signaux d'avance) et sa production
--    adressable, chacun mesuré contre SA PROPRE moyenne douze mois — on ne
--    compare jamais deux niveaux d'unités différentes, seulement deux
--    positions. Une tension positive = l'amont tire, la production ne suit
--    pas encore : c'est de la charge à venir pour la sous-traitance. C'est
--    le constat fondateur du § 8.6 (« le marché final porteur ne se
--    retrouve pas dans la demande adressable ») transformé en série.
--    Mesuré au 2026-06 : automobile +21, aérospatial +19,6.
--
-- 2. L'EXPOSITION AMÉRICAINE HORLOGÈRE. La part des États-Unis dans les
--    exportations horlogères suisses, et la concentration des trois
--    premiers débouchés. La série VALIDE le dispositif sur l'événement qui
--    fonde la problématique du travail : le choc douanier de 2025 s'y lit
--    intégralement — constitution de stocks à 34,1 % en avril 2025,
--    effondrement à 10,3 % en octobre, remontée à 27,1 % en juillet 2026.
--    Le dispositif voit le choc que l'introduction du rapport raconte.
--
-- 3. L'INDICE DE DIFFUSION (calculé à l'affichage, pas en vue : il ne
--    dépend que de la vitrine déjà servie). Combien des treize indicateurs
--    suivis sont au-dessus de leur moyenne, orientés par leur sens de
--    lecture. On compte des DIRECTIONS, jamais des grandeurs : aucune unité
--    mélangée, aucune pondération — la critique qui a retiré le score de
--    l'écran ne s'applique pas. Au 26.08 : 8 favorables sur 13, et les
--    quatre défavorables sont ceux du métier (T8, T7, A6, S7).
-- =====================================================================

BEGIN;

CREATE OR REPLACE VIEW v_tension_chaine AS
WITH m AS (
  SELECT mm.indicator_id, mm.period, mm.ecart_a_la_moyenne_pct AS e
    FROM v_metriques mm JOIN indicators i USING (indicator_id)
   WHERE mm.geo = i.geo_reference AND mm.ecart_a_la_moyenne_pct IS NOT NULL)
SELECT c.marche, am.period,
       round(am.e::numeric, 1) AS amont_vs_moyenne,
       round(av.e::numeric, 1) AS production_vs_moyenne,
       round((am.e - av.e)::numeric, 1) AS tension
  FROM (VALUES ('automobile','A2','A6'), ('medical','M7','M2'),
               ('aerospatial','S7','S8'), ('horlogerie','H9','H6'))
       AS c(marche, amont, aval)
  JOIN m am ON am.indicator_id = c.amont
  JOIN m av ON av.indicator_id = c.aval AND av.period = am.period
 ORDER BY c.marche, am.period;

COMMENT ON VIEW v_tension_chaine IS
  'Écart entre la position de l''amont d''un marché et celle de sa production adressable, chacune contre sa propre moyenne douze mois. Tension positive = l''amont tire, la production ne suit pas encore : charge à venir pour la sous-traitance. Le § 8.6 transformé en série. Couples : A2/A6, M7/M2, S7/S8, H9/H6.';

CREATE OR REPLACE VIEW v_exposition_horlogere AS
WITH h AS (
  SELECT DISTINCT ON (period, geo) period, geo, value
    FROM indicator_values
   WHERE indicator_id = 'H1' AND geo NOT IN ('W00','WORLD') AND geo !~ '^[SXF][0-9]'
   ORDER BY period, geo, run_id DESC),
tot AS (SELECT period, sum(value) AS t FROM h GROUP BY 1),
parts AS (SELECT h.period, h.geo, h.value / t.t * 100 AS part FROM h JOIN tot t USING (period))
SELECT p.period,
       round(max(p.part) FILTER (WHERE p.geo = 'USA')::numeric, 1) AS part_usa_pct,
       round(sum(p.part) FILTER (WHERE rn <= 3)::numeric, 1)       AS top3_pct
  FROM (SELECT *, row_number() OVER (PARTITION BY period ORDER BY part DESC) AS rn FROM parts) p
 GROUP BY p.period
 ORDER BY p.period;

COMMENT ON VIEW v_exposition_horlogere IS
  'Part des États-Unis dans les exportations horlogères suisses et concentration des trois premiers débouchés, par mois. Le choc douanier de 2025 s''y lit intégralement : 34,1 % en avril 2025 (stocks), 10,3 % en octobre (choc), 27,1 % en juillet 2026 (remontée) — le dispositif voit l''événement qui fonde la problématique du travail.';

COMMIT;
