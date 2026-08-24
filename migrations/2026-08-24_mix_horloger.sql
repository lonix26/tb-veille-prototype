-- ============================================================================
-- MIX HORLOGER — la valeur ne dit pas le volume. N. Castillo, 24.08.2026.
--
-- Le mécanisme de la question de veille QV1 horlogère porte depuis le chapitre 8
-- un point de vigilance précis : « une montée en valeur qui masquerait l'érosion
-- du tissu de sous-traitance ». Le commentaire exécutif du 24.08 l'a énoncé
-- lui-même, en constatant qu'il n'était PAS observable — faute de série de
-- volume. Les données de la Fédération horlogère le rendent observable pour la
-- première fois.
--
-- CE QUE LA VUE CALCULE, et pourquoi ce n'est pas cosmétique :
--   · la part mécanique en VALEUR — ce que pèse le segment usiné dans le chiffre ;
--   · la part mécanique en VOLUME — combien de montres il représente ;
--   · la VALEUR MOYENNE d'une montre mécanique exportée — dont la hausse, à
--     volume constant, est la signature exacte d'une montée en gamme.
--
-- Un atelier facture des PIÈCES, pas des francs. Une valeur qui monte pendant
-- que le volume stagne signifie que le débouché s'enrichit sans s'élargir : le
-- chiffre d'affaires de la branche croît, la charge d'usinage non.
-- ============================================================================

BEGIN;

DROP VIEW IF EXISTS v_mix_horloger;

CREATE VIEW v_mix_horloger AS
WITH pts AS (
  SELECT DISTINCT ON (indicator_id, period) indicator_id, period, value
  FROM indicator_values
  WHERE indicator_id IN ('H7','H8','H9')
  ORDER BY indicator_id, period, run_id DESC
),
larges AS (
  SELECT period,
         max(value) FILTER (WHERE indicator_id='H7') AS total_chf,
         max(value) FILTER (WHERE indicator_id='H8') AS meca_chf,
         max(value) FILTER (WHERE indicator_id='H9') AS meca_pieces
  FROM pts GROUP BY period
)
SELECT period,
       total_chf, meca_chf, meca_pieces,
       round((100.0 * meca_chf / NULLIF(total_chf,0))::numeric, 1) AS part_meca_valeur_pct,
       -- Valeur moyenne d'une montre mécanique exportée, en francs :
       -- millions de CHF ÷ milliers de pièces × 1000.
       round((meca_chf * 1000.0 / NULLIF(meca_pieces,0))::numeric, 0) AS valeur_moyenne_chf,
       -- Glissement annuel de chacun, quand les douze mois existent.
       round((100.0 * (meca_chf - lag(meca_chf, 12) OVER (ORDER BY period))
              / NULLIF(lag(meca_chf, 12) OVER (ORDER BY period),0))::numeric, 1) AS meca_chf_ga_pct,
       round((100.0 * (meca_pieces - lag(meca_pieces, 12) OVER (ORDER BY period))
              / NULLIF(lag(meca_pieces, 12) OVER (ORDER BY period),0))::numeric, 1) AS meca_pieces_ga_pct
FROM larges
WHERE total_chf IS NOT NULL;

COMMENT ON VIEW v_mix_horloger IS
  'Mix mécanique des exportations horlogères suisses (source FH, en francs). '
  'Rend observable le point de vigilance du mécanisme QV1 horloger : une montée '
  'en valeur qui masquerait l''érosion du tissu de sous-traitance. Un atelier '
  'facture des pièces, pas des francs.';

COMMIT;

SELECT period, total_chf, meca_chf, meca_pieces, part_meca_valeur_pct AS part_val,
       valeur_moyenne_chf AS val_moy, meca_chf_ga_pct AS ga_valeur, meca_pieces_ga_pct AS ga_volume
FROM v_mix_horloger ORDER BY period DESC LIMIT 8;
