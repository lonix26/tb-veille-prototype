-- =====================================================================
-- Validation humaine d'un commentaire exécutif — procédure
--
-- AVANT D'EXÉCUTER : lire le commentaire À CÔTÉ de sa charge exacte
-- (input_payload). Trois contrôles, dans l'ordre :
--   1. RI0 — chaque chiffre du texte figure dans input_payload, à
--      l'identique (ni recalcul, ni arrondi, ni extrapolation) ;
--   2. RI9 — aucune formulation causale proscrite (« en raison de »,
--      « causé par », « s'explique par ») ;
--   3. le format imposé est respecté et la production s'arrête au
--      diagnostic (aucune recommandation).
-- Un manquement = rejet (decision 'rejete'), jamais de correction du
-- texte : on ne réécrit pas la production d'un modèle, on la refuse et
-- on regénère — sinon le « commentaire validé » serait en réalité un
-- texte humain attribué au dispositif.
--
-- Affichage préalable :
--   docker compose exec -T db psql -U veille -d veille -c \
--     "SELECT commentary_id, sector_code, status, text FROM commentaries WHERE status='a_valider' ORDER BY commentary_id;"
--   docker compose exec -T db psql -U veille -d veille -c \
--     "SELECT jsonb_pretty(input_payload) FROM commentaries WHERE commentary_id=<ID>;"
--
-- Usage (depuis prototype/) — decision = 'valide' ou 'rejete' :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     -v id=<COMMENTARY_ID> -v decision="'valide'" \
--     < valider_commentaire.sql | tee -a ../annexe_5/validation_commentaires_$(date +%F).txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE commentaries
SET status = :decision,
    validated_by = 'N. Castillo',
    validated_at = now()
WHERE commentary_id = :id AND status = 'a_valider'
RETURNING commentary_id, sector_code, status, validated_by, validated_at::date;

COMMIT;

\echo ''
\echo '--- État de la file de commentaires'
SELECT status, count(*) FROM commentaries GROUP BY status ORDER BY status;
