-- =====================================================================
-- 2026-08-27 — CORRECTIONS DES QUESTIONS DE VEILLE (revue du 26.08)
--
-- Quatre points de cohérence identifiés à la revue critique du 26.08.2026,
-- validés par l'étudiant et reportés à sa demande ; traités ce jour sur
-- son instruction. Deux relèvent de la base (ci-dessous), deux du rapport
-- (QV0 assumé au § 8, tableau décision → question).
--
-- 1) HORLOGERIE QV5 : 'marginale' → 'significative'.
--    Contradiction constatée : la criticité disait « marginale » alors que
--    le mécanisme de la question énonce lui-même que le choc douanier de
--    2025 « rend la question observable », et que le § 11.12 du rapport
--    fait de ce choc l'événement fondateur de la problématique. Les deux
--    ne tiennent pas ensemble. Arbitrage : la criticité remonte — c'est la
--    lecture cohérente avec le mécanisme ET avec l'exposition américaine
--    mesurée par v_exposition_horlogere (34,1 % → 10,3 % → 27,1 %). La
--    formulation et le mécanisme, exacts, ne changent pas.
--    Conséquence assumée : la case horlogerie × QV5 étant sans porteur en
--    vitrine, remonter sa criticité AGGRAVE la lacune déclarée — c'est
--    voulu. Une lacune sur question significative se déclare, elle ne se
--    minimise pas par l'étiquette.
--
-- 2) MATRICE DE COUVERTURE DE LA VITRINE : promue au rang d'objet
--    requêtable (v_couverture_vitrine). v_couverture_qv existait mais
--    compte tout le référentiel (46 lignes) ; or ce que le décideur voit,
--    c'est la vitrine. L'écart entre les deux — une case « couverte » au
--    référentiel peut être vide à l'écran — est précisément le résultat
--    que le § 8 doit porter. Règle du projet : tout décompte cité se tire
--    d'une vue, jamais d'un texte.
-- =====================================================================

BEGIN;

UPDATE sector_watch_questions
   SET criticite = 'significative'
 WHERE sector_code = 'horlogerie'
   AND watch_question_code = 'QV5'
   AND criticite = 'marginale';

-- Matrice de couverture telle que le décideur la voit : vitrine seulement.
CREATE OR REPLACE VIEW v_couverture_vitrine AS
SELECT s.code                                   AS sector_code,
       q.code                                   AS watch_question_code,
       sw.criticite,
       count(i.indicator_id)                    AS nb_en_vitrine,
       count(i.indicator_id) FILTER (WHERE i.status = 'certifie')    AS nb_certifies,
       count(i.indicator_id) FILTER (WHERE i.status = 'a_confirmer') AS nb_a_confirmer,
       string_agg(i.indicator_id, ', ' ORDER BY i.indicator_id)      AS porteurs,
       CASE
         WHEN count(i.indicator_id) FILTER (WHERE i.status = 'certifie') > 0 THEN 'couverte'
         WHEN count(i.indicator_id) > 0 THEN 'couverte_a_confirmer'
         ELSE 'non_couverte'
       END AS couverture
  FROM sectors s
 CROSS JOIN watch_questions q
  JOIN sector_watch_questions sw
    ON sw.sector_code = s.code AND sw.watch_question_code = q.code
  LEFT JOIN indicator_watch_questions iwq
    ON iwq.watch_question_code = q.code
  LEFT JOIN indicators i
    ON i.indicator_id = iwq.indicator_id
   AND i.sector_code = s.code
   AND i.en_vitrine
 GROUP BY s.code, q.code, sw.criticite
 ORDER BY s.code, q.code;

COMMENT ON VIEW v_couverture_vitrine IS
  'Couverture des questions de veille par les indicateurs EN VITRINE (ce que le décideur voit). À confronter à v_couverture_qv (référentiel complet) : l''écart entre les deux est un résultat du § 8. Créée le 27.08.2026.';

COMMIT;
