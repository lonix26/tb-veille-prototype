-- =====================================================================
-- Migration du 17.08.2026 — indicateurs AVANCÉS du socle (T5, T6)
--
-- Révision de la grille (décision N. Castillo, 17.08.2026). Constat à
-- l'écran : le portefeuille regarde massivement en arrière — statistiques
-- consolidées, donc rétrospectives par nature. Le seul indicateur avancé
-- était T1 (CLI G20). Deux avancés vérifiés en réponse réelle le 17.08
-- rejoignent le socle transversal :
--
--   T5 — Attentes de production de l'industrie européenne (enquête de
--        conjoncture DG ECFIN, code BS-IPE : « Production expectations
--        over the next 3 months », solde d'opinion désaisonnalisé).
--        AVANCÉ PAR CONSTRUCTION : la question porte sur les trois mois
--        À VENIR. Diffusé par l'API Eurostat déjà connectée (ei_bsin_m_r2,
--        dimensions vérifiées : freq/indic/s_adj/unit/geo/time).
--   T6 — Baromètre conjoncturel KOF (ETH Zurich), avancé de l'économie
--        suisse — l'écosystème du cas d'illustration. API v2 publique
--        sans clé, CSV vérifié le 17.08 (mensuel depuis 1991).
--
-- Limite assumée, à écrire au ch. 8 : ces deux avancés sont TRANSVERSAUX.
-- La déclinaison par branche (NACE C29, C30, C32) existe chez DG ECFIN
-- (fichiers sectoriels) et constitue la prochaine extension — la grille
-- le dit plutôt que de laisser croire à des avancés sectoriels.
--
-- Décompte : la grille passe de 26 à 28 indicateurs. L'annexe 1 est à
-- régénérer ; tout passage du rapport citant « 26 » est à aligner.
--
-- Semés a_confirmer / a_verifier ; la certification et l'activation sont
-- l'acte nominatif de l'étudiant (activation_avances_2026-08-17.sql),
-- après les deux appels de contrôle en fin de fichier.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_indicateurs_avances.sql \
--     | tee ../annexe_5/indicateurs_avances_2026-08-17.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Nouvelle source : KOF (l'enquête DG ECFIN passe par la source
--    eurostat existante, même API de dissémination).
INSERT INTO sources (source_id, label, organisation, frequency, format, access, qualification_status, url, note)
VALUES ('kof', 'Baromètre conjoncturel KOF', 'KOF ETH Zurich', 'mensuelle', 'API / CSV', 'libre', 'a_confirmer',
        'https://data.kof.ethz.ch',
        'API v2 publique sans clé (access_type=public), CSV date/valeur, mensuel depuis 1991. Vérifiée en réponse réelle le 17.08.2026. Ancienne API v1 hors service — motif du re-sourçage documenté.')
ON CONFLICT (source_id) DO NOTHING;

-- 2. Les deux indicateurs, rattachés à QV0 (socle transversal) — comme T1,
--    ce sont des références d'attribution, et les seuls « regards devant »
--    quantitatifs du portefeuille avec lui.
INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency, unit, status, alert_threshold_pct, description_metier)
VALUES
('T5', 'transversal', 'Attentes de production de l''industrie européenne (solde d''opinion à 3 mois)',
 'eurostat', 'hard', 'mensuelle', 'solde d''opinion', 'a_confirmer', NULL,
 'Enquête de conjoncture DG ECFIN : ce que les industriels européens prévoient de produire dans les trois prochains mois. Indicateur avancé par construction — il précède les volumes, là où les statistiques consolidées les constatent.'),
('T6', 'transversal', 'Baromètre conjoncturel KOF (Suisse)',
 'kof', 'hard', 'mensuelle', 'indice', 'a_confirmer', NULL,
 'Indicateur avancé de l''économie suisse (ETH Zurich) : anticipe la conjoncture à environ six mois. Le pouls de l''écosystème dans lequel opère une PME industrielle neuchâteloise.')
ON CONFLICT (indicator_id) DO NOTHING;

INSERT INTO indicator_watch_questions (indicator_id, watch_question_code)
VALUES ('T5', 'QV0'), ('T6', 'QV0')
ON CONFLICT DO NOTHING;

-- 3. Liaisons, semées a_verifier.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note) VALUES
('T5', 'eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_bsin_m_r2',
 '{"format":"JSON","lang":"en","indic":"BS-IPE","s_adj":"SA","unit":"BAL","geo":"EU27_2020","sinceTimePeriod":"2023-01"}'::jsonb,
 '{"admet_negatifs":true}'::jsonb,
 'EU27_2020', 'a_verifier',
 'Structure du jeu vérifiée le 17.08.2026 (dimensions freq/indic/s_adj/unit/geo/time ; code BS-IPE présent). La réponse FILTRÉE de cette liaison reste à voir avant activation — commande en fin de migration.'),
('T6', 'csv_generique',
 'https://tsdb-api.kof.ethz.ch/v2/ts',
 '{"keys":"ch.kof.barometer","mime":"csv","access_type":"public"}'::jsonb,
 '{"colonne_periode":"date","colonne_valeur":"ch.kof.barometer","format_periode":"AAAA-MM-JJ","periode_min":"2023"}'::jsonb,
 'CH', 'a_verifier',
 'CSV vu en réponse réelle le 17.08.2026 (colonnes date / ch.kof.barometer, dates au premier du mois — d''où format_periode AAAA-MM-JJ, normalisation ajoutée au décodeur CSV le même jour). REQUIERT le réimport du collecteur générique.')
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. T5 et T6 au référentiel, a_confirmer, rattachés à QV0'
SELECT i.indicator_id, i.status, i.frequency, i.unit, w.watch_question_code
FROM indicators i JOIN indicator_watch_questions w USING (indicator_id)
WHERE i.indicator_id IN ('T5','T6') ORDER BY i.indicator_id;

\echo ''
\echo '--- 2. Liaisons semées a_verifier'
SELECT indicator_id, connecteur, statut FROM source_bindings
WHERE indicator_id IN ('T5','T6') ORDER BY indicator_id;

\echo ''
\echo '--- 3. Décompte : la grille passe à 28'
SELECT count(*) AS indicateurs, count(*) FILTER (WHERE status='certifie') AS certifies
FROM indicators;

\echo ''
\echo '--- 4. Le registre n''est pas touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;

-- =====================================================================
-- CONTRÔLES AVANT ACTIVATION (à faire, sorties à voir) :
--
-- curl -s "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_bsin_m_r2?format=JSON&lang=en&indic=BS-IPE&s_adj=SA&unit=BAL&geo=EU27_2020&sinceTimePeriod=2026-01" | head -c 600
--   Attendu : JSON-stat avec value {...} non vide (soldes d'opinion, valeurs
--   négatives possibles — c'est un solde, PAS une grandeur positive).
--
-- curl -s "https://tsdb-api.kof.ethz.ch/v2/ts?keys=ch.kof.barometer&mime=csv&access_type=public" | tail -5
--   Attendu : les derniers mois de 2026.
--
-- ATTENTION CONTRÔLE QUALITÉ : BS-IPE peut être NÉGATIF (solde d'opinion) ;
-- le contrôle « valeur négative » de la chaîne écarterait ces points. Si le
-- contrôle du curl montre des valeurs négatives sur la fenêtre, le point est
-- à traiter AVANT le premier run (voir note de passation).
-- =====================================================================
