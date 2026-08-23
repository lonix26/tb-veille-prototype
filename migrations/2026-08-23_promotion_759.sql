-- =====================================================================
-- Rejet du signal 3, promotion de l'item de flux 759 — 23.08.2026
--
-- Décisions de N. CASTILLO, session terminale du 23.08.2026.
--
-- SIGNAL 3 REJETÉ — motif de TRAÇABILITÉ, non de contenu. Son archive
-- (`extraits.extractions`) nommait « gpt-4o », « claude-opus-4-8 » et
-- « gemini-pro-latest » : trois identifiants écrits en dur dans le nœud de
-- normalisation, dont AUCUN n'avait tourné (les appels utilisaient déjà
-- gpt-5.6, claude-opus-5 et gemini-3.7-flash). Une pièce d'audit qui
-- désigne un modèle n'ayant pas servi est inexploitable dans un travail
-- dont la thèse est la traçabilité.
--
-- Le signal 3 est REJETÉ et NON SUPPRIMÉ : il documente le défaut et sa
-- correction. Effacer la trace d'une erreur corrigée reviendrait à effacer
-- la preuve que le contrôle a fonctionné.
--
-- SIGNAL 4 CONSERVÉ : même document, archive exacte — l'identifiant de
-- modèle y est désormais lu DANS la réponse de l'API, et l'appel OpenAI en
-- échec y est nommé « (aucun — appel en échec) » plutôt qu'attribué à un
-- modèle.
--
-- PROMOTION DE L'ITEM 759 rattachée au signal 4. La contrainte
-- chk_promotion_rattachee impose ce rattachement : une promotion sans
-- signal n'existe pas.
--
-- RÉSERVE INSCRITE ICI PARCE QU'ELLE COMPTE : le signal 4 a un champ
-- `evenement` VIDE et un recoupement de 0,25. L'appel OpenAI ayant échoué
-- (429, deux fois), le recoupement n'a jamais eu trois avis à comparer :
-- il n'a donc pas été mis à l'épreuve. Le signal reste `a_valider` — il
-- n'atteindra pas le tableau de bord tant qu'un humain ne l'aura pas
-- validé, et il n'y a en l'état rien à valider.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE signals
   SET statut = 'rejete',
       validated_by = 'N. Castillo',
       validated_at = now(),
       note_validation = 'Rejeté le 23.08.2026 pour défaut de traçabilité : l''archive nommait '
         || 'gpt-4o, claude-opus-4-8 et gemini-pro-latest, trois identifiants écrits en dur dans '
         || 'le nœud de normalisation, dont aucun n''a tourné. Remplacé par le signal 4, produit '
         || 'après correction (identifiant lu dans la réponse de l''API). Conservé comme trace du '
         || 'défaut et de sa correction.'
 WHERE signal_id = 3;

INSERT INTO flux_examens (item_id, decision, signal_id, decide_par, note)
SELECT 759, 'promu_signal', 4, 'N. Castillo',
       'Autorisation FDA 510(k) K262290, cupule acétabulaire REMEDY POLY+PLUS (Osteoremedies). '
       'Promu : implant articulaire, usinage de précision au coeur du métier. Extraction menée '
       'sur le résumé 510(k) publié (PDF, 508 Ko). RÉSERVE : recoupement 0,25 et champ evenement '
       'vide — l''appel OpenAI a échoué en 429, le recoupement n''a donc jamais eu trois avis à '
       'comparer. Signal laissé en a_valider.'
WHERE NOT EXISTS (SELECT 1 FROM flux_examens x WHERE x.item_id = 759);

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications :
--   V32 : signal 3 rejeté, nominatif et daté ; signal 4 toujours a_valider.
--   V33 : la promotion existe et pointe le signal 4.
--   V34 : 37 examens (21 + 10 + 5 + 1).
-- ---------------------------------------------------------------------

SELECT 'V32' AS verif, signal_id, statut, validated_by, validated_at::date
FROM signals ORDER BY signal_id;

SELECT 'V33' AS verif, e.item_id, e.decision, e.signal_id, e.decide_par, s.statut AS statut_signal
FROM flux_examens e LEFT JOIN signals s ON s.signal_id = e.signal_id
WHERE e.decision = 'promu_signal';

SELECT 'V34' AS verif, decision, count(*) FROM flux_examens GROUP BY decision ORDER BY decision;
