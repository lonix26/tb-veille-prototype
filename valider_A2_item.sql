-- =====================================================================
-- Validation humaine d'un item de la file A2 — variante par item_id
--
-- Complète valider_A2.sql (17.08.2026, mise en série) : la période et le
-- raw_ref sont lus DEPUIS l'item de la file de validation — plus de
-- retape, donc plus d'erreur de recopie possible. L'item est soldé
-- (decision = accepte) dans le même geste, et la valeur validée entre au
-- registre en NOUVELLE ligne valide_humain (ajout seul, supersession).
--
-- AVANT D'EXÉCUTER, pour chaque item : ouvrir le PDF déposé (raw_ref de
-- l'item), trouver la ligne « EUROPEAN UNION » du tableau mensuel, lire
-- le TOTAL du mois (la valeur suivie du total de l'année précédente et
-- d'une variation en %, PAS le premier nombre de la ligne qui est le
-- décompte BEV), et vérifier que la valeur passée en variable est bien
-- celle-là. C'est ça, la validation — l'exécution vaut décision.
--
-- Usage (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     -v item=<ITEM_ID> -v valeur=<VALEUR_VERIFIEE> \
--     < valider_A2_item.sql | tee -a ../annexe_5/validation_serie_A2_2026-08-17.txt
--
-- Exemple : ... -v item=5 -v valeur=799625 ...
-- Pour un REJET (valeur inexploitable), utiliser valider_A2.sql à la main
-- ou marquer decision='rejete' — ne pas forcer une valeur douteuse ici.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Solder l'item de la file (uniquement s'il est encore ouvert).
UPDATE validation_queue
SET decided_value = :valeur, decision = 'accepte',
    decided_by = 'N. Castillo', decided_at = now()
WHERE item_id = :item AND decision IS NULL
RETURNING item_id, period, decided_value;

-- 2. Écrire la valeur validée au registre, dans un nouveau run.
WITH q AS (
    SELECT indicator_id, period, geo, raw_ref
    FROM validation_queue WHERE item_id = :item
),
nouveau_run AS (
    INSERT INTO runs (trigger_type, scenario, status, note)
    VALUES ('manual', 'B', 'en_cours',
            'Validation humaine A2 (série, item ' || :item || ') — valeur vérifiée contre le document source')
    RETURNING run_id
)
INSERT INTO indicator_values
    (indicator_id, run_id, period, geo, value, obtained_by, validation_status,
     validated_by, validated_at, raw_ref)
SELECT q.indicator_id, r.run_id, q.period, q.geo, :valeur, 'ia_extraction', 'valide_humain',
       'N. Castillo', now(), q.raw_ref
FROM q, nouveau_run r
RETURNING value_id, run_id, period;

UPDATE runs SET status = 'ok', closed_at = now()
WHERE run_id = (SELECT max(run_id) FROM runs WHERE note LIKE 'Validation humaine A2 (série%');

COMMIT;

-- =====================================================================
-- Vérifications
-- =====================================================================

\echo ''
\echo '--- Item soldé et valeur au registre'
SELECT vq.item_id, vq.period, vq.decision, vq.decided_value,
       iv.value AS valeur_registre, iv.validation_status
FROM validation_queue vq
LEFT JOIN indicator_values iv
       ON iv.indicator_id = vq.indicator_id AND iv.period = vq.period
      AND iv.validation_status = 'valide_humain'
WHERE vq.item_id = :item
ORDER BY iv.run_id DESC LIMIT 1;
