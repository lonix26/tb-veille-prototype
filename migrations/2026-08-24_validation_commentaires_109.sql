-- ============================================================================
-- Validation de la fournée 109 — N. Castillo, 24.08.2026
--
-- Première fournée rédigée sur la grille refondue (42 indicateurs), avec le
-- score détendancé, le sens métier déclaré de chaque indicateur, et les séries
-- de la Fédération horlogère.
--
-- MÉTHODE. Chaque chiffre confronté à `input_payload` et à v_metriques.
-- Vérifié : H7 2 522,7 mio CHF et +9,78 % ; H8 +10,55 % ; H9 +20,00 % ;
-- H6 +1,02 % pour un seuil de 6 ; H1 +6,06 % pour un seuil de 25 ; H3 +5,73 %
-- pour un seuil de 10 — les trois derniers correctement déclarés non
-- significatifs. Côté automobile : A6 91,6 et −5,18 % (seuil 6), A5 106,6 et
-- −2,29 % (seuil 10), A4 +0,63 %. Tout exact.
--
-- LE RUN 108 EST REJETÉ : quatre appels sur cinq ont échoué faute de crédit
-- d'API, le cinquième est conservé au registre mais n'a pas vocation à être
-- servi seul.
--
-- CE QUE CETTE FOURNÉE CORRIGE, ET QUI COMPTE. Le commentaire horloger du run
-- 103 écrivait que « le tissu de sous-traitance n'est observé qu'au point 2023,
-- alors qu'il peut s'éroder sans que la valeur exportée le montre ». C'était
-- vrai à sa date et devenu FAUX depuis l'ajout de H9 : le volume mécanique est
-- désormais observé. La fournée 109 le lit correctement — « le volume mécanique
-- croît plus vite que la valeur : la hausse n'est pas qu'une montée en gamme,
-- elle porte sur des pièces réellement produites ». C'est exactement la réponse
-- au point de vigilance que le mécanisme de QV1 porte depuis le chapitre 8, et
-- elle contredit la crainte qu'il énonçait.
-- ============================================================================

BEGIN;

UPDATE commentaries SET status='rejete'
 WHERE run_id=108 AND status='a_valider';

UPDATE commentaries SET status='valide', validated_by='N. Castillo', validated_at=now()
 WHERE run_id=109 AND status='a_valider';

COMMIT;

SELECT run_id, status, count(*) FROM commentaries WHERE run_id>=103 GROUP BY 1,2 ORDER BY 1,2;
