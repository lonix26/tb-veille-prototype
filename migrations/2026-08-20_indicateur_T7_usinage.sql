-- =====================================================================
-- Migration du 20.08.2026 — T7, production de l'usinage métallique UE
--
-- L'étage manquant du portefeuille, identifié à la revue critique du
-- 20.08 : la grille surveillait les marchés finaux (C29 automobile,
-- SH 91 horlogerie…) mais pas l'activité du MÉTIER lui-même — la
-- sous-traitance d'usinage. Le code NACE C25.6 « traitement et
-- revêtement des métaux ; usinage » est exactement ce métier, et le jeu
-- conjoncturel d'Eurostat le publie en mensuel : vérifié en réponse
-- réelle le 20.08.2026 (C256, SCA, indice base 2021, EU27, valeurs
-- 2026-01..06 = 90,3 → 91,0 — le métier tourne ~10 % sous son niveau
-- de 2021, ce que rien d'autre dans la grille ne montrait).
--
-- Rattachement : socle transversal / QV0. Ce n'est pas un indicateur de
-- marché final mais le référentiel du métier : quand un secteur client
-- bouge, T7 dit si la sous-traitance dans son ensemble bouge aussi —
-- même logique d'attribution que le socle, un cran plus près de CODEC.
--
-- Note pour le § 12.5 : la réponse porte le drapeau « i » (estimé)
-- d'Eurostat sur TOUTES les valeurs récentes — perdu à l'ingestion,
-- énième occurrence du motif, visible dans la réponse fondatrice même.
--
-- Décompte après activation : 29 indicateurs, 25 certifiés (24 hard).
-- Même API et même connecteur que A5/M2 : zéro code nouveau.
--
-- L'EXÉCUTION VAUT CERTIFICATION ET ACTIVATION : la réponse réelle
-- filtrée a été vue par l'étudiant le 20.08.2026 (sortie curl conservée).
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-20_indicateur_T7_usinage.sql \
--     | tee ../annexe_5/indicateur_T7_2026-08-20.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency, unit, status, alert_threshold_pct, description_metier)
VALUES ('T7', 'transversal',
        'Production de l''usinage et du traitement des métaux UE (NACE C25.6)',
        'eurostat', 'hard', 'mensuelle', 'indice', 'certifie', NULL,
        'L''activité du métier lui-même : la production européenne de traitement, revêtement et usinage des métaux — le code NACE de la sous-traitance mécanique de précision. Quand un marché client bouge, cet indice dit si c''est le secteur qui bouge ou toute la profession. Le chaînon entre la conjoncture des marchés finaux et le carnet d''un décolleteur.')
ON CONFLICT (indicator_id) DO NOTHING;

INSERT INTO indicator_watch_questions (indicator_id, watch_question_code)
VALUES ('T7', 'QV0')
ON CONFLICT DO NOTHING;

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, verifie_par, verifie_le, note) VALUES
('T7', 'eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpr_m',
 '{"format":"JSON","lang":"en","nace_r2":"C256","s_adj":"SCA","unit":"I21","geo":"EU27_2020","sinceTimePeriod":"2023-01"}'::jsonb,
 '{}'::jsonb,
 'EU27_2020', 'actif', 'N. Castillo', '2026-08-20',
 'Réponse réelle filtrée vue le 20.08.2026 : JSON-stat, valeurs mensuelles 2026-01..06 = 90,3..91,0, indice base 2021, désaisonnalisé. TOUTES les valeurs récentes portent le drapeau i (estimé) — perdu à l''ingestion, motif documenté au § 12.5. Même connecteur et même API que A5/M2.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. T7 certifié, liaison active, rattaché à QV0'
SELECT i.indicator_id, i.status, b.statut AS liaison, b.verifie_par
FROM indicators i JOIN source_bindings b USING (indicator_id)
WHERE i.indicator_id = 'T7';

\echo ''
\echo '--- 2. Décompte : 29 indicateurs, 25 certifiés (24 hard / 1 composite)'
SELECT count(*) AS indicateurs,
       count(*) FILTER (WHERE status = 'certifie') AS certifies
FROM indicators;

\echo ''
\echo '--- 3. Le registre n''est pas touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
