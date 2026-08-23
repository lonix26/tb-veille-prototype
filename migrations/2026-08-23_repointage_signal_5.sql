-- =====================================================================
-- Repointage de la promotion 759 vers le signal 5 — 23.08.2026
--
-- Décision de N. CASTILLO, session terminale du 23.08.2026.
--
-- Trois extractions successives ont été menées sur le MÊME document
-- (résumé FDA 510(k) K262290). Elles sont toutes conservées : la série
-- documente la mise au point du dispositif, et l'effacer reviendrait à
-- effacer la preuve que les contrôles ont fonctionné.
--
--   signal 3 — REJETÉ (traçabilité) : archive nommant trois modèles qui
--              n'avaient pas tourné, identifiants écrits en dur.
--   signal 4 — REJETÉ ici (exécution incomplète) : produit à DEUX modèles
--              sur trois, l'appel OpenAI ayant échoué en 429. Le
--              recoupement n'avait donc jamais eu trois avis à comparer :
--              son score de 0,25 ne mesurait pas un désaccord, il mesurait
--              une absence.
--   signal 5 — RETENU : première exécution nominale du dispositif —
--              gpt-5.6-sol, claude-opus-5, gemini-3.7-flash, aucun
--              incident. Recoupement 0,50, `acteur` et `echeance` retenus.
--
-- CE QUE LE SIGNAL 5 NE RÉSOUT PAS, et qui doit rester écrit : son champ
-- `evenement` est vide alors que les TROIS modèles ont énoncé le même fait
-- — la détermination d'équivalence substantielle par la FDA. Ils l'ont
-- rédigé différemment (« a déterminé » / « établit »), et la règle de
-- recoupement, transposée du pipeline A2 qui extrait des NOMBRES, exige la
-- coïncidence de chaînes. Sur du texte libre elle mesure la coïncidence de
-- formulation, non l'accord factuel. Le score de 0,50 est donc le taux de
-- champs assez pauvres pour que trois rédactions coïncident : une date et
-- un nom propre.
--
-- La règle N'EST PAS modifiée ici : l'assouplir effacerait la mesure qu'on
-- vient d'obtenir. Elle est à rapporter avant d'être corrigée.
--
-- Le signal 5 reste `a_valider` : il n'atteindra pas le tableau de bord
-- sans validation humaine, et son événement est vide — il n'y a, en
-- l'état, rien à valider.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE signals
   SET statut = 'rejete',
       validated_by = 'N. Castillo',
       validated_at = now(),
       note_validation = 'Rejeté le 23.08.2026 : produit à deux modèles sur trois (appel OpenAI '
         || 'en échec, 429). Le recoupement de 0,25 mesurait une absence, non un désaccord. '
         || 'Remplacé par le signal 5, première exécution nominale à trois modèles. Conservé '
         || 'comme trace de l''exécution dégradée.'
 WHERE signal_id = 4;

UPDATE flux_examens
   SET signal_id = 5,
       note = note || ' | REPOINTÉ le 23.08.2026 vers le signal 5 : première exécution nominale '
                   || 'à trois modèles (gpt-5.6-sol, claude-opus-5, gemini-3.7-flash, aucun '
                   || 'incident), recoupement 0,50, acteur et échéance retenus. Le signal 4, '
                   || 'produit à deux modèles, est rejeté et conservé.'
 WHERE item_id = 759 AND decision = 'promu_signal';

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications :
--   V35 : trois signaux sur le même document — 3 et 4 rejetés avec motif,
--         5 en a_valider. Aucune suppression.
--   V36 : la promotion pointe le signal 5.
--   V37 : la contrainte chk_promotion_rattachee tient toujours.
-- ---------------------------------------------------------------------

SELECT 'V35' AS verif, signal_id, statut, score_recoupement,
       left(coalesce(note_validation,'—'), 58) AS motif
FROM signals ORDER BY signal_id;

SELECT 'V36' AS verif, e.item_id, e.decision, e.signal_id, s.statut AS statut_signal,
       s.score_recoupement, left(s.acteur,34) AS acteur_retenu
FROM flux_examens e JOIN signals s ON s.signal_id = e.signal_id
WHERE e.decision = 'promu_signal';
