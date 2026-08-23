-- =====================================================================
-- Migration du 23.08.2026 — Étage 2 : flux, triage IA, santé sectorielle
--
-- Conception : prototype/CONCEPTION_ETAGE2.md (décision de l'étudiant du
-- 22.08.2026, levée du gel — tracée en notes de rédaction, § 7.2.2).
--
-- CE QUE CETTE MIGRATION CRÉE :
--   1. flux_sources   — descripteurs déclaratifs des flux (même logique
--                       que source_bindings : la source est une donnée).
--   2. flux_items     — les items collectés, EN AJOUT SEUL, dédupliqués
--                       par empreinte, chacun avec sa pièce brute (E6).
--   3. flux_triage_ia — les scores de triage produits par modèle. Un
--                       score n'est PAS un statut : l'IA propose un
--                       ordre de lecture, elle ne décide rien.
--   4. flux_examens   — les décisions HUMAINES sur les items (promotion
--                       vers la chaîne signals, écartement, mise en
--                       contexte), nominatives et datées.
--   5. indicators.sens_favorable et indicators.latence — déclarations
--                       de lecture par indicateur (doctrine admet_negatifs :
--                       une hypothèse s'écrit, ne se présume pas).
--   6. v_sante_secteur — score de santé par secteur, calculé PAR LE CODE
--                       (écarts standardisés orientés, base 3 ans).
--   7. v_flux_a_examiner — la file de lecture du veilleur, triée par
--                       score de triage.
--
-- RÈGLES REPRISES DE L'ARCHITECTURE :
--   - Ajout seul sur flux_items (même trigger-doctrine que le registre).
--   - Aucun item n'atteint le décideur sans passer par flux_examens
--     (humain) puis, s'il est promu, par la chaîne signals existante
--     (3 modèles, extraits obligatoires, validation nominative).
--   - Le triage IA est mesurable : la vue v_triage_a_echantillonner
--     sert l'échantillon de relecture humaine (taux d'erreur mesuré,
--     jamais supposé — protocole OSINT, F3).
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-23_etage2_flux.sql \
--     | tee ../annexe_5/migration_etage2_2026-08-23.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Descripteurs de flux
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS flux_sources (
    flux_id        TEXT PRIMARY KEY,               -- ex. 'ted_medical', 'gdelt_horlogerie', 'marches_aero'
    famille        TEXT NOT NULL CHECK (famille IN
                     ('marches_publics','communications','actualite','marches_financiers',
                      'registres','trafic','brevets_flux','emploi')),
    sector_code    TEXT REFERENCES sectors(code),  -- NULL = transversal
    libelle        TEXT NOT NULL,
    url_base       TEXT NOT NULL,
    parametres     JSONB NOT NULL DEFAULT '{}'::jsonb,  -- requête, CPV, tickers… : la source est une donnée
    statut         TEXT NOT NULL DEFAULT 'a_verifier'
                   CHECK (statut IN ('a_verifier','actif','ecarte')),
    qualified_by   TEXT,
    qualified_at   DATE,
    note           TEXT,

    -- La qualification d'un flux est un acte humain nominatif et daté,
    -- comme celle d'une source de l'étage 1.
    CONSTRAINT chk_flux_qualifie_trace CHECK (
        statut = 'a_verifier' OR (qualified_by IS NOT NULL AND qualified_at IS NOT NULL)
    )
);

COMMENT ON TABLE flux_sources IS
  'Descripteurs déclaratifs des flux de l''étage 2 (CONCEPTION_ETAGE2.md). Même principe que source_bindings : ajouter un flux est une déclaration, pas un développement. Un flux écarté avec motif est un résultat (protocole OSINT).';

-- ---------------------------------------------------------------------
-- 2. Items de flux — ajout seul
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS flux_items (
    item_id          BIGSERIAL PRIMARY KEY,
    flux_id          TEXT NOT NULL REFERENCES flux_sources(flux_id),
    run_id           BIGINT REFERENCES runs(run_id),
    date_publication DATE,
    titre            TEXT NOT NULL,
    url              TEXT,
    payload          JSONB NOT NULL DEFAULT '{}'::jsonb,  -- l'item tel que servi par la source
    empreinte        TEXT NOT NULL,                        -- sha256(flux_id + identifiant naturel) : déduplication
    raw_ref          TEXT NOT NULL,                        -- pièce brute (E6) : sans elle, l'item n'est pas auditable
    collecte_le      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (empreinte)
);

COMMENT ON TABLE flux_items IS
  'Items collectés par l''étage 2, en AJOUT SEUL. Un item n''est ni une observation de série ni un signal : c''est un candidat brut, qui n''atteint jamais le décideur sans examen humain (flux_examens) puis chaîne signals.';

CREATE OR REPLACE FUNCTION interdire_modification_flux() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION
      'flux_items est en ajout seul : un item se corrige par une nouvelle collecte, jamais par modification — l''historique du flux fait partie de la preuve.';
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_flux_ajout_seul') THEN
    CREATE TRIGGER trg_flux_ajout_seul
        BEFORE UPDATE OR DELETE ON flux_items
        FOR EACH ROW EXECUTE FUNCTION interdire_modification_flux();
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_flux_items_lecture ON flux_items (flux_id, date_publication DESC);

-- ---------------------------------------------------------------------
-- 3. Triage IA — des scores, jamais des statuts
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS flux_triage_ia (
    triage_id      BIGSERIAL PRIMARY KEY,
    item_id        BIGINT NOT NULL REFERENCES flux_items(item_id),
    modele         TEXT NOT NULL,                  -- identifiant exact du modèle, consigné
    pertinence     SMALLINT NOT NULL CHECK (pertinence BETWEEN 0 AND 2),
    sector_code    TEXT REFERENCES sectors(code),
    watch_question_code TEXT REFERENCES watch_questions(code),
    resume         TEXT,                           -- une ligne, pour la file de lecture
    justification  TEXT,
    horodatage     TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (item_id, modele)
);

COMMENT ON TABLE flux_triage_ia IS
  'Scores de triage produits par modèle sur les items de flux. Le triage ordonne la lecture du veilleur, il ne valide rien : aucune colonne de statut, à dessein. Tâche réversible → un modèle unique et économique suffit (§ 9.4.2 : sur tâche contrainte, le coût décide). Le taux d''erreur se mesure par échantillon relu (v_triage_a_echantillonner).';

-- ---------------------------------------------------------------------
-- 4. Examens humains — la seule porte de sortie des items
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS flux_examens (
    examen_id    BIGSERIAL PRIMARY KEY,
    item_id      BIGINT NOT NULL REFERENCES flux_items(item_id),
    decision     TEXT NOT NULL CHECK (decision IN ('promu_signal','ecarte','contexte')),
    signal_id    BIGINT REFERENCES signals(signal_id),   -- renseigné si promu
    decide_par   TEXT NOT NULL,
    decide_le    TIMESTAMPTZ NOT NULL DEFAULT now(),
    note         TEXT,

    UNIQUE (item_id),

    -- Une promotion sans signal rattaché n'existe pas : la promotion N'EST PAS
    -- la validation — elle inscrit l'item dans la chaîne signals, qui applique
    -- ses propres règles (extraits obligatoires, validation nominative).
    CONSTRAINT chk_promotion_rattachee CHECK (
        decision <> 'promu_signal' OR signal_id IS NOT NULL
    )
);

COMMENT ON TABLE flux_examens IS
  'Décisions humaines sur les items de flux, nominatives et datées. C''est la seule porte entre le flux et le décideur : l''IA trie, l''humain décide, la chaîne signals valide.';

-- ---------------------------------------------------------------------
-- 5. Déclarations de lecture sur les indicateurs de l'étage 1
-- ---------------------------------------------------------------------

ALTER TABLE indicators ADD COLUMN IF NOT EXISTS sens_favorable SMALLINT
    CHECK (sens_favorable IN (-1, 0, 1));
ALTER TABLE indicators ADD COLUMN IF NOT EXISTS latence TEXT
    CHECK (latence IN ('retarde','coincident','avance','flux'));

COMMENT ON COLUMN indicators.sens_favorable IS
  'Orientation de lecture : +1 = une hausse est favorable au secteur, -1 = défavorable, 0 = non orientable. NULL = non déclaré — l''indicateur n''entre pas dans v_sante_secteur. Déclaration humaine par indicateur, jamais présumée (doctrine admet_negatifs).';
COMMENT ON COLUMN indicators.latence IS
  'Position temporelle de l''indicateur par rapport au cycle réel du marché : retardé, coïncident, avancé, ou flux (étage 2). Sert le critère d''utilité de la grille (CONCEPTION_ETAGE2.md § 5).';

-- Les déclarations elles-mêmes sont des actes de qualification : elles se
-- sèment par une migration dédiée après revue indicateur par indicateur
-- (2026-08-23_declarations_lecture.sql, à écrire lors de la revue), PAS ici.

-- ---------------------------------------------------------------------
-- 6. Santé sectorielle — un calcul, pas un avis
-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW v_sante_secteur AS
WITH courant AS (
    -- dernière valeur retenue par (indicateur, période, zone) : dernier run
    SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo)
           iv.indicator_id, iv.period, iv.geo, iv.value
    FROM indicator_values iv
    WHERE iv.validation_status IN ('valide_source','pre_valide_consensus','valide_humain')
    ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC
),
series AS (
    -- une série par indicateur : sa zone la plus fournie (série de référence)
    SELECT c.indicator_id, c.geo,
           ROW_NUMBER() OVER (PARTITION BY c.indicator_id ORDER BY COUNT(*) DESC, c.geo) AS rang
    FROM courant c GROUP BY c.indicator_id, c.geo
),
stats AS (
    SELECT c.indicator_id,
           AVG(c.value)         AS moyenne,
           STDDEV_SAMP(c.value) AS ecart_type,
           COUNT(*)             AS n_points,
           (ARRAY_AGG(c.value ORDER BY c.period DESC))[1]  AS derniere_valeur,
           (ARRAY_AGG(c.period ORDER BY c.period DESC))[1] AS derniere_periode
    FROM courant c
    JOIN series s ON s.indicator_id = c.indicator_id AND s.geo = c.geo AND s.rang = 1
    GROUP BY c.indicator_id
)
SELECT i.sector_code,
       COUNT(*)                                   AS n_indicateurs_orientables,
       ROUND(AVG( (st.derniere_valeur - st.moyenne) / NULLIF(st.ecart_type, 0)
                  * i.sens_favorable )::numeric, 2) AS score_sante,
       MIN(st.n_points)                           AS profondeur_min,
       ARRAY_AGG(i.indicator_id ORDER BY i.indicator_id) AS indicateurs
FROM stats st
JOIN indicators i ON i.indicator_id = st.indicator_id
WHERE i.sens_favorable IN (-1, 1)
  AND i.status = 'certifie'
  AND st.ecart_type IS NOT NULL AND st.ecart_type > 0
  AND st.n_points >= 8
GROUP BY i.sector_code;

COMMENT ON VIEW v_sante_secteur IS
  'Score de santé par secteur : moyenne des écarts standardisés (dernière valeur contre la base de la série de référence), orientés par sens_favorable. Calcul déterministe — aucune IA. Ne couvre que les indicateurs certifiés, orientés, à série suffisante (>= 8 points) ; le nombre d''indicateurs couverts est affiché avec le score, jamais caché.';

-- ---------------------------------------------------------------------
-- 7. Files de lecture
-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW v_flux_a_examiner AS
SELECT fi.item_id, fs.famille, fs.libelle AS flux, t.sector_code, t.watch_question_code,
       t.pertinence, t.resume, fi.titre, fi.url, fi.date_publication, fi.collecte_le
FROM flux_items fi
JOIN flux_sources fs ON fs.flux_id = fi.flux_id
LEFT JOIN flux_triage_ia t ON t.item_id = fi.item_id
WHERE NOT EXISTS (SELECT 1 FROM flux_examens e WHERE e.item_id = fi.item_id)
ORDER BY t.pertinence DESC NULLS LAST, fi.date_publication DESC;

CREATE OR REPLACE VIEW v_triage_a_echantillonner AS
-- Échantillon de mesure du triage : items déjà examinés par l'humain,
-- confrontés au score IA — la matrice décision humaine × pertinence IA.
SELECT e.decision, t.pertinence, COUNT(*) AS n
FROM flux_examens e
JOIN flux_triage_ia t ON t.item_id = e.item_id
GROUP BY e.decision, t.pertinence
ORDER BY e.decision, t.pertinence;

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V1 : les 4 tables existent, les 3 vues existent.
--   V2 : flux_items refuse UPDATE (exception « ajout seul »).
--   V3 : flux_examens refuse une promotion sans signal_id (exception CHECK).
--   V4 : v_sante_secteur retourne 0 ligne tant qu'aucun sens_favorable
--        n'est déclaré — c'est l'attendu, pas un défaut.
-- ---------------------------------------------------------------------

SELECT 'V1' AS verif, COUNT(*) AS tables_et_vues
FROM information_schema.tables
WHERE table_name IN ('flux_sources','flux_items','flux_triage_ia','flux_examens')
   OR table_name IN ('v_sante_secteur','v_flux_a_examiner','v_triage_a_echantillonner');

SELECT 'V4' AS verif, COUNT(*) AS lignes_sante_avant_declarations FROM v_sante_secteur;
