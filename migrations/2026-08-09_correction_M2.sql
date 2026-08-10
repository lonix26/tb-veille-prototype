-- =====================================================================
-- Correction de M2 — granularité NACE et fréquence
--
-- Deux écarts constatés le 07.08, tranchés sur vérité terrain le 09.08 :
--
--   1. GRANULARITÉ. Le § 8.4.2 définit M2 sur la classe NACE C32.5
--      (instruments et fournitures médicodentaires). La liaison portait
--      l'agrégat large C32 (« Autres industries manufacturières », qui
--      englobe aussi bijouterie, instruments de musique, articles de
--      sport et jouets). Vérification du 09.08 sur le jeu sts_inpr_m : la
--      classe spécifiée EXISTE, sous le code `C325` (et non `C32_5`) —
--      41 valeurs mensuelles, 2023-01..2026-06. La réserve « agrégat trop
--      large » est donc levée : on corrige la liaison sur C325 plutôt que
--      de requalifier l'indicateur sur C32. Le label de l'indicateur, qui
--      annonçait déjà « NACE C32.5 », était juste ; c'est la liaison qui
--      était en écart.
--
--   2. FRÉQUENCE. La série sts_inpr_m est mensuelle ; `indicators.M2`
--      portait « trimestrielle ». Correction en « mensuelle ».
--
-- La liaison reste `a_verifier` : son activation, après vue de la réponse
-- réelle, appartient à l'étudiant (§ 8.2.1). Cette migration ne l'active pas.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-09_correction_M2.sql
--
-- Non destructive pour le registre.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Fréquence : mensuelle (série sts_inpr_m vérifiée le 09.08).
UPDATE indicators
SET frequency = 'mensuelle'
WHERE indicator_id = 'M2';

-- 2. Granularité : liaison recalée de l'agrégat C32 vers la classe C325.
--    Seule la clé nace_r2 change ; les autres paramètres sont préservés.
--    Statut inchangé (a_verifier) — activation réservée à l'étudiant.
UPDATE source_bindings
SET params = jsonb_set(params, '{nace_r2}', '"C325"'),
    note   = 'Eurostat sts_inpr_m, NACE C325 (= C32.5 du § 8.4.2 : instruments et fournitures à usage médical et dentaire). Granularité spécifiée confirmée présente le 09.08.2026 : 41 valeurs mensuelles 2023-01..2026-06 (le code est C325, non C32_5). La réserve antérieure — agrégat C32 trop large, englobant bijouterie, instruments de musique, sport et jouets — est levée. Fréquence mensuelle. Reste a_verifier : à activer après vérification de la réponse réelle par l''étudiant.'
WHERE indicator_id = 'M2';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. M2 : fréquence corrigée en mensuelle'
\echo '    Attendu : frequency = mensuelle.'
SELECT indicator_id, label, category, frequency, unit FROM indicators WHERE indicator_id = 'M2';

\echo ''
\echo '--- 2. Liaison M2 : NACE C325, toujours a_verifier'
\echo '    Attendu : nace_r2 = C325, statut = a_verifier.'
SELECT indicator_id, statut, params->>'nace_r2' AS nace_r2, verifie_par
FROM source_bindings WHERE indicator_id = 'M2';

\echo ''
\echo '--- 3. Le registre n''a pas été touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
