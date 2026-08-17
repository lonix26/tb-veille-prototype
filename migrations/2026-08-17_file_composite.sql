-- =====================================================================
-- Migration du 17.08.2026 (9/9) — file de documents du pipeline composite
--
-- Objet. A2 ne porte que 2 observations sur une période unique (2025-11) :
-- le pipeline composite est démontré, pas exploité. La mise en série se
-- fait par une FILE DE DOCUMENTS en base : le veilleur inscrit les
-- communiqués qu'il a qualifiés (human-in-the-loop, scénario B), chaque
-- exécution du workflow traite le plus ancien document « a_traiter ».
-- Ajouter un mois devient une ligne — même philosophie que le socle
-- déclaratif du § 10.6, appliquée au non structuré.
--
-- Cycle de vie d'un document : a_verifier (URL candidate) -> a_traiter
-- (URL vue par le veilleur, acte nominatif) -> traite (consommé par un
-- run, horodaté) ; ecarte pour les URL mortes ou les mois sans communiqué.
--
-- Les sept URL semées suivent le motif du communiqué de novembre 2025
-- (seul VU en réponse réelle). AUCUNE n'est vérifiée : statut a_verifier.
-- ACEA peut nommer différemment le communiqué de décembre (bilan annuel) —
-- c'est précisément ce que la vérification par curl détectera.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-17_file_composite.sql \
--     | tee ../annexe_5/file_composite_2026-08-17.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS composite_queue (
    doc_id       BIGSERIAL PRIMARY KEY,
    indicator_id TEXT NOT NULL REFERENCES indicators(indicator_id),
    period       TEXT NOT NULL,
    geo          TEXT NOT NULL DEFAULT 'EU27',
    source_doc   TEXT NOT NULL,
    statut       TEXT NOT NULL DEFAULT 'a_verifier'
                 CHECK (statut IN ('a_verifier','a_traiter','traite','ecarte')),
    verifie_par  TEXT,
    verifie_le   DATE,
    run_id       BIGINT REFERENCES runs(run_id),
    traite_le    TIMESTAMPTZ,
    note         TEXT,
    -- Un document ne passe pas en traitement sans vérification nominative,
    -- même règle que chk_binding_verifie sur les liaisons.
    CONSTRAINT chk_doc_verifie CHECK (
        statut NOT IN ('a_traiter','traite')
        OR (verifie_par IS NOT NULL AND verifie_le IS NOT NULL)
    ),
    UNIQUE (indicator_id, period, source_doc)
);

COMMENT ON TABLE composite_queue IS
  'File de documents du pipeline composite (mise en série du 17.08.2026). Le veilleur inscrit et vérifie les documents ; le workflow consomme le plus ancien a_traiter. L''inscription est l''acte humain de sélection du scénario B.';

INSERT INTO composite_queue (indicator_id, period, geo, source_doc, note) VALUES
('A2', '2025-12', 'EU27', 'https://www.acea.auto/files/Press_release_car_registrations_December_2025.pdf',
 'URL candidate (motif de novembre 2025). Décembre est souvent un communiqué de bilan annuel au nom différent — vérifier, corriger ou écarter.'),
('A2', '2026-01', 'EU27', 'https://www.acea.auto/files/Press_release_car_registrations_January_2026.pdf',  'URL candidate, à vérifier.'),
('A2', '2026-02', 'EU27', 'https://www.acea.auto/files/Press_release_car_registrations_February_2026.pdf', 'URL candidate, à vérifier.'),
('A2', '2026-03', 'EU27', 'https://www.acea.auto/files/Press_release_car_registrations_March_2026.pdf',    'URL candidate, à vérifier.'),
('A2', '2026-04', 'EU27', 'https://www.acea.auto/files/Press_release_car_registrations_April_2026.pdf',    'URL candidate, à vérifier.'),
('A2', '2026-05', 'EU27', 'https://www.acea.auto/files/Press_release_car_registrations_May_2026.pdf',      'URL candidate, à vérifier.'),
('A2', '2026-06', 'EU27', 'https://www.acea.auto/files/Press_release_car_registrations_June_2026.pdf',     'URL candidate, à vérifier.')
ON CONFLICT (indicator_id, period, source_doc) DO NOTHING;

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. Sept documents candidats en file, tous a_verifier'
SELECT period, statut, source_doc FROM composite_queue ORDER BY period;

\echo ''
\echo '--- 2. La contrainte de vérification nominative est en place'
\echo '    (le passage direct en a_traiter sans verifie_par doit échouer — test à blanc)'
SAVEPOINT test_contrainte;
DO $$
BEGIN
  BEGIN
    UPDATE composite_queue SET statut = 'a_traiter' WHERE period = '2026-01';
    RAISE EXCEPTION 'DEFAUT : la contrainte chk_doc_verifie n''a pas refusé';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK : chk_doc_verifie refuse un passage a_traiter non nominatif';
  END;
END $$;
ROLLBACK TO SAVEPOINT test_contrainte;

\echo ''
\echo '--- 3. Le registre n''est pas touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
