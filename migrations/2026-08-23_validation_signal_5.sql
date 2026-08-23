-- =====================================================================
-- Validation du signal 5 — 23.08.2026
--
-- ACTE HUMAIN de N. CASTILLO, session terminale du 23.08.2026.
--
-- POURQUOI CETTE VALIDATION COMPORTE UN ARBITRAGE. Le recoupement avait
-- laissé `evenement` et `zone` à NULL : les trois modèles disaient le même
-- fait en des termes différents, et la règle exige la coïncidence de
-- chaînes. Le nœud de recoupement prévoit exactement ce cas — « sinon le
-- champ reste NULL et l'humain tranche sur le détail conservé ». Valider,
-- ici, c'est donc arbitrer.
--
-- CE QUI EST ÉCRIT, ET D'OÙ CELA VIENT — aucune formulation nouvelle n'a
-- été inventée :
--   * `evenement` reprend MOT POUR MOT la proposition n° 2 (claude-opus-5),
--     retenue parce qu'elle est la seule à porter le numéro d'autorisation
--     (K262290) et le demandeur (Osteoremedies, LLC). Les propositions 1 et
--     3 disent le même fait sans ces identifiants ; elles restent conservées
--     dans `extraits.detail`.
--   * `zone` reprend la proposition n° 3, la plus sobre.
--   * Les TROIS extraits_source sont IDENTIQUES — la même phrase du résumé
--     510(k). Le désaccord ne portait donc que sur la rédaction, jamais sur
--     le fait.
--
-- La lecture pour un sous-traitant figure en note_validation et non dans le
-- schéma d'extraction : c'est une interprétation, elle appartient au
-- validateur humain, pas aux modèles.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE signals
   SET evenement = 'La FDA a déterminé que le dispositif REMEDY POLY+PLUS SNAP FIT Acetabular Cup '
                || '(K262290) d''Osteoremedies, LLC est substantiellement équivalent à des dispositifs '
                || 'légalement commercialisés, autorisant sa mise sur le marché au titre du 510(k).',
       zone = 'États-Unis',
       statut = 'valide',
       validated_by = 'N. Castillo',
       validated_at = now(),
       note_validation = 'Validé le 23.08.2026. ARBITRAGE : les champs evenement et zone avaient '
         || 'été laissés NULL par le recoupement — les trois modèles énonçaient le même fait en '
         || 'des termes différents, et la règle exige la coïncidence de chaînes. Les trois '
         || 'extraits_source sont IDENTIQUES : le désaccord portait sur la rédaction, jamais sur '
         || 'le fait. Retenu mot pour mot la proposition de claude-opus-5, seule à porter le '
         || 'numéro d''autorisation et le demandeur ; les deux autres restent conservées dans '
         || 'extraits.detail. '
         || 'LECTURE POUR LE SOUS-TRAITANT : une autorisation 510(k) précède la montée en cadence '
         || 'de production d''un implant articulaire — donc la commande de pièces usinées, '
         || 'plusieurs mois avant toute statistique. Signal à confirmer par M8 (autorisations '
         || 'FDA mensuelles) et M2 (production manufacturière diverse UE). '
         || 'RÉSERVE : signal isolé, portée non quantifiable en l''état.'
 WHERE signal_id = 5;

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications :
--   V38 : le signal 5 est validé, nominatif et daté, avec un evenement non vide.
--   V39 : deux signaux validés au total — le radar en affichera deux.
--   V40 : les confirmateurs existent (médical × QV2), contrairement au
--         signal 2 (automobile × QV5) qui n'en avait aucun.
-- ---------------------------------------------------------------------

SELECT 'V38' AS verif, signal_id, statut, validated_by, validated_at::date,
       left(evenement, 70) AS evenement, zone
FROM signals WHERE signal_id = 5;

SELECT 'V39' AS verif, statut, count(*) FROM signals GROUP BY statut ORDER BY statut;

SELECT 'V40' AS verif, s.signal_id, s.sector_code, s.watch_question_code,
       string_agg(i.indicator_id, ', ' ORDER BY i.indicator_id) AS confirmateurs
FROM signals s
LEFT JOIN indicator_watch_questions w ON w.watch_question_code = s.watch_question_code
LEFT JOIN indicators i ON i.indicator_id = w.indicator_id
                      AND i.sector_code = s.sector_code AND i.status = 'certifie'
WHERE s.statut = 'valide'
GROUP BY s.signal_id, s.sector_code, s.watch_question_code ORDER BY s.signal_id;
