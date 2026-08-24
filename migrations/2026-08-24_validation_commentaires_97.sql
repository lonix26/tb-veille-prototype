-- ============================================================================
-- Validation des commentaires en attente — N. Castillo, 24.08.2026
--
-- MÉTHODE. Chaque chiffre cité a été confronté à la charge d'entrée conservée
-- avec le commentaire (`input_payload`), indicateur par indicateur, seuil par
-- seuil. C'est ce que la validation vaut : sans cette confrontation, elle ne
-- serait qu'un tampon, et la métrique de rejet du § 11.6 perdrait son sens.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- RUN 95 — REJETÉ EN BLOC, sans examen du fond.
--
-- Ces cinq commentaires ont été produits par une VERSION PÉRIMÉE du workflow,
-- exécutée par erreur le 24.08 : cinq exemplaires du commentaire exécutif
-- coexistaient dans l'orchestrateur, faute d'identifiant épinglé dans le dépôt
-- (§ 12.6, occurrence 13). Deux motifs suffisent à les écarter :
--   1. le format est celui, abandonné, de « Constat / Neutralisations /
--      Lecture », et non le format à cinq sections « réponse d'abord » ;
--   2. le libellé de modèle, `claude-opus-4-8`, est ÉCRIT EN DUR dans cette
--      version : il n'atteste pas du modèle réellement interrogé. Une sortie
--      dont on ne peut pas nommer l'auteur n'est pas diffusable.
-- Ils sont CONSERVÉS au registre, comme toute pièce : le rejet est un
-- événement de l'historique, pas un effacement.
-- ---------------------------------------------------------------------------
UPDATE commentaries
   SET status = 'rejete'
 WHERE run_id = 95 AND status = 'a_valider';

-- ---------------------------------------------------------------------------
-- RUN 97 — VALIDÉS. Vérification chiffre par chiffre contre input_payload.
-- ---------------------------------------------------------------------------

UPDATE commentaries SET status='valide', validated_by='N. Castillo', validated_at=now()
 WHERE run_id=97 AND sector_code='transversal' AND status='a_valider';
-- Vérifié : T3 +5,32 % ; T6 103,46 et +3,1 % ; T7 91, −2,88 %, moyenne 92,83 ;
-- T1 +0,34 % pour seuil 0,5 ; T2 −0,76 % pour seuil 7 ; seuils non configurés
-- pour T4/T5/T6/T7 et moyenne mobile non applicable à T4 (série semestrielle)
-- — les six mentions de complétude sont reprises telles quelles, RI0 respectée.

UPDATE commentaries SET status='valide', validated_by='N. Castillo', validated_at=now()
 WHERE run_id=97 AND sector_code='automobile' AND status='a_valider';
-- Vérifié : A2 1 147 962 et écart +18,41 % ; A3 21 000 000 et +23,53 % ;
-- A4 62,87 Md USD (62 869 928 862,70) et +0,63 % ; A5 indice 106,6 et −2,29 %.
-- Les deux variations sous seuil 10 % sont déclarées non significatives et
-- SANS explication attribuée — RI4 et RI9 tenues. Absence de glissement annuel
-- sur A2 énoncée, hypothèses concurrentes présentées avec la donnée qui
-- trancherait (RI10).

UPDATE commentaries SET status='valide', validated_by='N. Castillo', validated_at=now()
 WHERE run_id=97 AND sector_code='horlogerie' AND status='a_valider';
-- Vérifié : H1 2,68 Md USD (2 683 321 477,60) et +6,06 % pour seuil 25 % ;
-- H3 30,84 Md USD et +5,73 % pour seuil 10 % ; H2 57 422 (2023) avec sa
-- complétude reprise mot pour mot. RÉSERVE PORTÉE À L'ÉTUDIANT, sans incidence
-- sur la validité du texte : le commentaire conclut « routine » quand la tuile
-- du secteur affiche « nettement au-dessus » (+1,11). Les deux lectures sont
-- justes et n'emploient pas la même toise — le score est un écart-type, le
-- commentaire raisonne en seuils de matérialité. La tension est d'affichage,
-- pas de fond ; elle est instruite au § 12.2.

UPDATE commentaries SET status='valide', validated_by='N. Castillo', validated_at=now()
 WHERE run_id=97 AND sector_code='medical' AND status='a_valider';
-- Vérifié : exportations suisses 13 280 844 552,76 USD (2025), base medtech
-- 33 027 (2023), 283 autorisations FDA et 6 239 avis TED. Les deux écarts sous
-- seuil 12 % sont déclarés non significatifs. L'hypothèse de renouvellement de
-- générations d'instruments est explicitement marquée « à vérifier » (RI9/RI10).

UPDATE commentaries SET status='valide', validated_by='N. Castillo', validated_at=now()
 WHERE run_id=97 AND sector_code='aerospatial' AND status='a_valider';
-- Vérifié : S4 954 387 mio USD et −5,03 % ; S7 81 avis, moyenne 87,91,
-- écart −7,86 %. Neutralisations RI4 énoncées (objets lancés +58,3 % pour seuil
-- 80 ; commerce SH88 +16,8 % pour seuil 20). Moyenne mobile partielle
-- (11 points sur 12) reprise telle quelle. Aucune tendance qualifiée, RI6 tenue.

COMMIT;

SELECT run_id, status, count(*) AS n
FROM commentaries WHERE run_id IN (95, 97)
GROUP BY 1, 2 ORDER BY 1, 2;
