-- =====================================================================
-- 2026-08-30 — LE GABARIT QV1 HORLOGER RÉPOND ENFIN À LA QUESTION ENTIÈRE
--
-- QV1 horlogère demande « emplois ET établissements ». Depuis l'origine, le
-- gabarit ne servait que les emplois : le volet établissements n'avait pas
-- de porteur. H11 le porte depuis aujourd'hui, extrait du même tableau et
-- de la même lecture que H2 — la question reçoit ses deux moitiés.
--
-- DEUXIÈME CORRECTION, moins visible et plus importante : le gabarit disait
-- « emplois dans la branche horlogère suisse ». Le recensement de la
-- Convention patronale couvre les industries horlogère ET MICROTECHNIQUE.
-- Laisser l'ancien libellé attribuerait à la seule horlogerie un chiffre qui
-- compte aussi la microtechnique — une surdéclaration de périmètre, du même
-- genre que « donnée officielle » pour la FH. Le périmètre est nommé.
--
-- Les gabarits vivent EN BASE et se modifient par migration, jamais par
-- retouche d'écran (vigilance du 28.08.2026) : ils sont datés et citables
-- comme le reste du référentiel.
-- =====================================================================

BEGIN;

UPDATE sector_watch_questions SET reponse_gabarit =
  'Le tissu productif se compte deux fois : {H2.val} emplois et {H11.val} entreprises dans les industries horlogère et microtechnique suisses en {H2.per} ({H2.ga} et {H11.ga} sur un an) ; le volume de montres mécaniques exportées fait {H9.ga} sur un an, la production horlogère UE {H6.ga}. Si la valeur montait sans les pièces, sans les emplois ni les ateliers, l''érosion serait masquée — les quatre se lisent ici.'
WHERE sector_code = 'horlogerie' AND watch_question_code = 'QV1';

COMMIT;

SELECT sector_code, watch_question_code, reponse_gabarit
  FROM sector_watch_questions
 WHERE sector_code = 'horlogerie' AND watch_question_code = 'QV1';
