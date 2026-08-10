-- =====================================================================
-- Correction des dates de qualification des sources
--
-- Constat (PASSATION_PROTOTYPE.md § 4) : les 21 sources initiales portent
-- toutes `qualified_at = 2026-08-06`, qui est la date de PREMIER CHARGEMENT
-- du référentiel (seed de db/02_referentiel.sql), et non celle de l'acte
-- humain de qualification. Cet acte — vérification et affinage des URL,
-- source par source — a été effectué le 07.08.2026 (voir la reconnaissance
-- du 07.08 et la passation § 1, « URL de sources affinées par l'étudiant »).
-- La colonne `qualified_at` date l'acte humain : elle doit porter 07.08.
--
-- Portée. Seules les sources encore à 2026-08-06 sont recalées. La source
-- `fh` en est exclue : elle a été reclassée le 09.08 (référence de branche),
-- date qui reflète son propre acte et qui est déjà correcte.
--
-- La date, non l'heure, est ce qui fait foi. On fixe donc la date au 07.08 ;
-- l'heure exacte de l'acte n'a pas été consignée et n'est pas reconstruite —
-- ne pas inventer une précision qu'on n'a pas.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-09_dates_qualification.sql
--
-- Non destructive pour le registre.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE sources
SET qualified_at = DATE '2026-08-07'
WHERE qualified_at::date = DATE '2026-08-06';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. Répartition des dates de qualification après correction'
\echo '    Attendu : plus aucune source au 06.08 ; 21 au 07.08 ; fh au 09.08.'
SELECT to_char(qualified_at, 'YYYY-MM-DD') AS date_qualification,
       count(*) AS nb_sources,
       string_agg(source_id, ', ' ORDER BY source_id) AS sources
FROM sources
GROUP BY 1 ORDER BY 1;

\echo ''
\echo '--- 2. Le registre n''a pas été touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
