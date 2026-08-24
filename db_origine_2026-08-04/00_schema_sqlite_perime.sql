-- =====================================================================
-- FICHIER PÉRIMÉ — NE PAS UTILISER
--
-- Schéma SQLite de la première itération, remplacé par PostgreSQL le
-- 04.08.2026 (décision actée, révise le § 10.3). Le schéma en vigueur
-- est db/01_schema.sql, accompagné de db/02_referentiel.sql et
-- db/03_vues.sql, joués à l'initialisation du conteneur.
--
-- Conservé comme trace de l'évolution d'architecture — la conduite de
-- projet fait partie des critères d'appréciation. Aucune de ses
-- définitions n'est à jour : la numérotation des questions de veille
-- ci-dessous est celle d'avant la scission du 07.08.2026.
--
-- À supprimer, ou à déplacer en annexe documentaire, au moment de figer
-- le dépôt pour le dépôt final.
-- =====================================================================

-- Schéma de la base consolidée du système de veille (SQLite) — PÉRIMÉ
-- TB « Exploration de l'IA pour les entreprises industrielles » — architecture ch. 10

CREATE TABLE runs (
    run_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    executed_at  TEXT NOT NULL,              -- ISO 8601
    trigger_type TEXT NOT NULL,              -- 'schedule' | 'manual'
    status       TEXT NOT NULL DEFAULT 'ok'  -- 'ok' | 'partial' | 'failed'
);

CREATE TABLE indicators (
    indicator_id   TEXT PRIMARY KEY,          -- ex. 'H1', 'A3'
    sector         TEXT NOT NULL,             -- 'horlogerie' | 'medical' | 'automobile' | 'aerospatial' | 'transversal'
    label          TEXT NOT NULL,
    watch_question TEXT NOT NULL,             -- 'QV1'..'QV4' (CSV si multiple)
    source_name    TEXT NOT NULL,
    source_url     TEXT NOT NULL,
    category       TEXT NOT NULL,             -- 'hard' | 'composite'
    frequency      TEXT NOT NULL,             -- 'mensuelle' | 'trimestrielle' | 'annuelle' | 'bisannuelle'
    unit           TEXT NOT NULL,
    status         TEXT NOT NULL DEFAULT 'certifiee'  -- 'certifiee' | 'a_confirmer' | 'restreinte'
);

CREATE TABLE indicator_values (
    value_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    indicator_id      TEXT NOT NULL REFERENCES indicators(indicator_id),
    run_id            INTEGER NOT NULL REFERENCES runs(run_id),
    period            TEXT NOT NULL,           -- '2025', '2026-06', '2026-T1'
    geo               TEXT NOT NULL DEFAULT 'WORLD',  -- code pays ISO ou 'WORLD'
    value             REAL,
    obtained_by       TEXT NOT NULL,           -- 'etl' | 'ia_extraction'
    validation_status TEXT NOT NULL,           -- 'valide_source' | 'pre_valide_consensus' | 'valide_humain' | 'en_attente' | 'rejete'
    consensus_score   REAL,                    -- NULL pour ETL ; part des modèles concordants sinon
    raw_ref           TEXT,                    -- chemin/URL du dépôt brut (audit)
    UNIQUE (indicator_id, run_id, period, geo)
);

CREATE TABLE alerts (
    alert_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    indicator_id TEXT NOT NULL REFERENCES indicators(indicator_id),
    rule         TEXT NOT NULL,               -- ex. 'variation_annuelle < -5%'
    triggered_at TEXT,
    run_id       INTEGER REFERENCES runs(run_id),
    message      TEXT,                        -- brief rédigé par LLM
    validated_by TEXT                         -- NULL tant que non validé (E7)
);

-- File de validation humaine du pipeline composite
CREATE TABLE validation_queue (
    item_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    indicator_id TEXT NOT NULL REFERENCES indicators(indicator_id),
    run_id       INTEGER NOT NULL REFERENCES runs(run_id),
    period       TEXT NOT NULL,
    extractions  TEXT NOT NULL,               -- JSON : valeurs par modèle
    source_doc   TEXT NOT NULL,               -- URL/chemin du document
    decided_value REAL,
    decided_by   TEXT,
    decided_at   TEXT
);

-- Vue : dernière valeur validée par indicateur/période/geo (celle que le dashboard affiche)
CREATE VIEW v_current AS
SELECT iv.indicator_id, iv.period, iv.geo, iv.value, iv.validation_status,
       iv.obtained_by, i.sector, i.watch_question, i.category, i.unit,
       r.executed_at
FROM indicator_values iv
JOIN indicators i ON i.indicator_id = iv.indicator_id
JOIN runs r       ON r.run_id = iv.run_id
WHERE iv.validation_status IN ('valide_source','pre_valide_consensus','valide_humain')
  AND iv.run_id = (SELECT MAX(run_id) FROM indicator_values x
                   WHERE x.indicator_id = iv.indicator_id
                     AND x.period = iv.period AND x.geo = iv.geo
                     AND x.validation_status IN ('valide_source','pre_valide_consensus','valide_humain'));

-- Vue : évolution entre runs (timeline de l'outil vivant)
CREATE VIEW v_run_history AS
SELECT indicator_id, period, geo, run_id, value, validation_status
FROM indicator_values
ORDER BY indicator_id, period, geo, run_id;
