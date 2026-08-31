-- =====================================================================
-- A1 EN VITRINE : la production mondiale reçoit sa carte, et QV3 son
-- porteur littéral (décision de l'étudiant du 31.08.2026)
--
-- A1 a désormais une série démontrée par workflow : 2021-2024, ~20 pays
-- plus la zone World (ligne TOTAL du tableau CCFA, extraite comme les
-- autres — jamais recalculée), trois runs verts (187-189), consensus
-- unanime, recouvrement inter-éditions contrôlé (v_a1_recouvrement_editions).
-- Zone de référence : World, la convention des indicateurs mondiaux de la
-- grille (A3, A11).
--
-- Le gabarit QV3 automobile citait A3 seul (les VE, un segment) ; A1 est
-- le porteur littéral de la géographie de l'ASSEMBLAGE, tous véhicules.
-- Même geste que le 28.08 pour H2/M4 : le manque comblé, le gabarit suit.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE indicators
   SET en_vitrine = true,
       geo_reference = 'World',
       note_conception = trim(both E'\n' from coalesce(note_conception, '') || E'\n\n' || $txt$EN VITRINE le 31.08.2026 : série 2021-2024 constituée par le workflow d'extraction composite (trois éditions CCFA, trois runs verts 187-189, consensus unanime sur toutes les lignes). Zone de référence World = ligne TOTAL du tableau, extraite et non recalculée. Seuil de matérialité semé (5 %), NON CALIBRÉ — quatre points annuels ne portent pas de p90 ; à calibrer quand l'historique s'allonge, comme H1.$txt$)
 WHERE indicator_id = 'A1';

UPDATE sector_watch_questions SET reponse_gabarit =
 '{A1.val} véhicules produits dans le monde en {A1.per} ({A1.ga} sur un an) — la carte A1 dit où l''assemblage se déplace, tous véhicules confondus ; le segment électrique ({A3.val} VE vendus, {A3.ga}) dit vers quoi il bascule.'
 WHERE sector_code = 'automobile' AND watch_question_code = 'QV3';

COMMIT;

\echo ''
\echo '--- Vérifications'
SELECT indicator_id, en_vitrine, geo_reference, alert_threshold_pct FROM indicators WHERE indicator_id = 'A1';
SELECT sector_code, count(*) FILTER (WHERE en_vitrine) AS en_vitrine FROM indicators WHERE status='certifie' GROUP BY 1 ORDER BY 1;
