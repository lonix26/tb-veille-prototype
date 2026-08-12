-- =====================================================================
-- Validation humaine d'un signal qualitatif — procédure
--
-- AVANT D'EXÉCUTER : ouvrir le document déposé (raw_ref du signal) et
-- vérifier chaque champ contre les extraits source conservés dans la
-- colonne extraits. Corriger directement les champs si les modèles ont
-- divergé (les champs NULL attendent l'arbitrage humain). La note de
-- validation — la portée pour un sous-traitant — est TON jugement,
-- volontairement absent du schéma d'extraction.
--
-- Usage (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     -v signal=<ID> -v note="'<PORTEE POUR UN SOUS-TRAITANT>'" \
--     < valider_signal.sql | tee ../annexe_5/validation_signal_$(date +%F).txt
--
-- Pour REJETER un signal (document non pertinent, extraction fausse) :
--   ... -c "UPDATE signals SET statut='rejete', validated_by='N. Castillo',
--           validated_at=now(), note_validation='<motif>' WHERE signal_id=<ID>;"
-- Un rejet tracé est un résultat, pas un échec.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE signals
SET statut = 'valide',
    validated_by = 'N. Castillo',
    validated_at = now(),
    note_validation = :note
WHERE signal_id = :signal AND statut = 'a_valider';

COMMIT;

-- =====================================================================
-- Vérifications
-- =====================================================================

\echo ''
\echo '--- Le signal validé, tel que le tableau de bord le servira'
SELECT signal_id, sector_code, watch_question_code, evenement, acteur, echeance, zone,
       statut, validated_by, validated_at::date, note_validation
FROM v_signaux WHERE signal_id = :signal;
