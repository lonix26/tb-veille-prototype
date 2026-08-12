-- =====================================================================
-- Validation humaine d'une extraction composite A2 — procédure
--
-- PRINCIPE. Le registre est en ajout seul : la validation humaine n'est
-- pas un UPDATE de la ligne pré-validée, c'est une NOUVELLE ligne
-- « valide_humain », nominative et datée, dans un nouveau run. v_current
-- la fait prévaloir par supersession ; la ligne pré-validée reste dans
-- l'historique — la validation fait partie de l'audit, elle ne l'écrase pas.
--
-- AVANT D'EXÉCUTER : ouvrir le PDF déposé en staging (raw_ref du run
-- d'extraction), trouver la ligne « EUROPEAN UNION » du tableau mensuel,
-- et vérifier que la valeur ci-dessous correspond. C'est ça, la validation.
--
-- Usage (depuis prototype/) — remplacer les trois variables :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     -v valeur=<VALEUR_VERIFIEE> -v periode="'<AAAA-MM>'" -v raw="'<RAW_REF_DU_RUN_D_EXTRACTION>'" \
--     < valider_A2.sql | tee ../annexe_5/validation_humaine_A2_$(date +%F).txt
--
-- Exemple :
--   ... -v valeur=855000 -v periode="'2025-11'" -v raw="'/data/staging/A2_run27.pdf'" ...
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

WITH nouveau_run AS (
    INSERT INTO runs (trigger_type, scenario, status, note)
    VALUES ('manual', 'B', 'en_cours',
            'Validation humaine A2 — valeur vérifiée contre le document source (ligne EUROPEAN UNION du tableau mensuel)')
    RETURNING run_id
)
INSERT INTO indicator_values
    (indicator_id, run_id, period, geo, value, obtained_by, validation_status,
     validated_by, validated_at, raw_ref)
SELECT 'A2', run_id, :periode, 'EU27', :valeur, 'ia_extraction', 'valide_humain',
       'N. Castillo', now(), :raw
FROM nouveau_run
RETURNING value_id, run_id;

UPDATE runs SET status = 'ok', closed_at = now()
WHERE run_id = (SELECT max(run_id) FROM runs WHERE note LIKE 'Validation humaine A2%');

COMMIT;

-- =====================================================================
-- Vérifications
-- =====================================================================

\echo ''
\echo '--- Historique A2 sur la période : la pré-validée ET la validée coexistent.'
SELECT run_id, value, validation_status, validated_by, validated_at::date
FROM indicator_values
WHERE indicator_id = 'A2' AND period = :periode
ORDER BY run_id;

\echo ''
\echo '--- Valeur courante servie au tableau de bord : la validée doit prévaloir.'
SELECT period, geo, value, validation_status
FROM v_current WHERE indicator_id = 'A2' AND period = :periode;
