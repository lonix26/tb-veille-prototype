-- =====================================================================
-- 2026-08-28 — H2 ET M4 EN VITRINE : la question QV1 reçoit son porteur
-- littéral, et les gabarits suivent
--
-- Suite de 2026-08-28_profondeur_H2_M4.sql, après collecte (run 160) :
-- onze points servis (2014-2024) — la fenêtre d'historique des séries
-- annuelles (2014, règle du 24.08) écarte 2011-2013, décodés puis
-- comptés « hors fenêtre », comme pour A3.
--
-- CRITÈRE D'ADMISSION, énoncé avec précision : les notes du 25.08
-- (« moins de douze points ») citaient les seuils de la PREMIÈRE coupe ;
-- la révision du 26.08 (§ 8.8.7) a établi le seuil en vigueur à HUIT
-- points. Onze points le satisfont. Aucun critère n'est plié : c'est le
-- texte des notes qui datait d'un état révisé depuis.
--
-- CE QUE CE RETOUR RÉPARE : horlogerie × QV1 demandait « emplois et
-- établissements... suisses » et n'était servie que par un proxy de
-- mécanisme (H9) et un proxy d'activité au périmètre UE (H6) — constat de
-- l'étudiant du 28.08. H2 est le porteur littéral (56 866 emplois en
-- 2024, -1,0 % sur un an — la question commence à répondre). Même
-- réparation pour médical × QV1 (M4, 33 104 emplois medtech, +0,2 %).
-- Les gabarits de réponse citent désormais les emplois EN PREMIER — la
-- formule antérieure (« le tissu se lit dans les pièces ») contournait
-- élégamment le manque ; le manque comblé, l'élégance tombe.
-- =====================================================================

BEGIN;

UPDATE indicators
   SET en_vitrine = true,
       note_conception = coalesce(note_conception || E'\n', '')
         || 'RETOUR EN VITRINE le 28.08.2026 : liaison étendue à la pleine profondeur du cube STATENT (2011-2024), onze points servis (fenêtre annuelle 2014) — au-dessus du seuil révisé de huit points (§ 8.8.7) ; les notes antérieures citaient le seuil de la première coupe. Porteur littéral de la question QV1 (« emplois et établissements »), aux côtés des proxys H6/H9 (horlogerie) ou M2 (médical). Volet « établissements » du même cube : extension identifiée, non instrumentée.'
 WHERE indicator_id IN ('H2', 'M4');

UPDATE sector_watch_questions SET reponse_gabarit =
 'L''appareil productif se compte : {H2.val} emplois dans la branche horlogère suisse en {H2.per} ({H2.ga} sur un an) ; le volume de montres mécaniques exportées fait {H9.ga} sur un an, la production horlogère UE {H6.ga}. Si la valeur montait sans les pièces ni les emplois, l''érosion serait masquée — les trois se lisent ici.'
 WHERE sector_code = 'horlogerie' AND watch_question_code = 'QV1';

UPDATE sector_watch_questions SET reponse_gabarit =
 '{M4.val} emplois medtech suisses en {M4.per} ({M4.ga} sur un an) — la base productive nationale, comptée ; la production manufacturière diverse UE, proxy de branche, varie de {M2.ga} sur un an.'
 WHERE sector_code = 'medical' AND watch_question_code = 'QV1';

COMMIT;
