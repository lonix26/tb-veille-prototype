-- =====================================================================
-- Base consolidée du système de veille — PostgreSQL
-- TB « Exploration de l'IA pour les entreprises industrielles »
--
-- Principe directeur : ce schéma ne se contente pas de STOCKER ce que le
-- rapport décrit, il REND IMPOSSIBLE ce que le rapport interdit. Chaque
-- contrainte porte en commentaire la règle métier qu'elle fait respecter.
-- C'est la réponse à la réserve R-1 de l'évaluation critique : la
-- hiérarchie de contrôle doit être exercée, non déclarée.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Référentiel métier : questions de veille, secteurs, sources
-- ---------------------------------------------------------------------

CREATE TABLE watch_questions (
    code        TEXT PRIMARY KEY,          -- 'QV0'..'QV5'
    label       TEXT NOT NULL,
    description TEXT NOT NULL
);
COMMENT ON TABLE watch_questions IS
  'Questions de veille génériques (§ 8.1.2), niveau 1 du cadre. Prescription théorique du § 4.3 : pas d''indicateur sans question explicite. Le cadre est un défaut, non un dogme : un secteur peut ajouter une question propre, à charge de démontrer qu''elle ne s''exprime pas comme une instanciation des questions existantes.';

CREATE TABLE sectors (
    code  TEXT PRIMARY KEY,                -- 'horlogerie','medical','automobile','aerospatial','transversal'
    label TEXT NOT NULL
);

-- Niveau 2 du cadre : instanciation sectorielle des questions génériques.
-- Une question générique n'est pas directement exploitable : le rôle causal
-- du phénomène qu'elle vise diffère d'un secteur à l'autre. « Impulsions
-- publiques » désigne la demande elle-même en aérospatial (marchés
-- budgétaires), un déterminant médiatisé en médical (systèmes de santé),
-- et un calendrier de substitution en automobile (réglementation). Sans
-- cette table, le décideur lit le même libellé dans trois vues et croit
-- lire la même chose.
CREATE TABLE sector_watch_questions (
    sector_code         TEXT NOT NULL REFERENCES sectors(code),
    watch_question_code TEXT NOT NULL REFERENCES watch_questions(code),
    formulation         TEXT NOT NULL,   -- la question telle qu'elle se pose dans ce secteur
    mecanisme           TEXT NOT NULL,   -- rôle causal du phénomène dans ce secteur
    criticite           TEXT NOT NULL CHECK (criticite IN ('dominante','significative','marginale')),
    PRIMARY KEY (sector_code, watch_question_code)
);
COMMENT ON TABLE sector_watch_questions IS
  'Instanciation sectorielle (§ 8.1.2). Le § 8.1.2 annonçait cette instanciation depuis la phase 1 sans la matérialiser : cette table clôt cet écart. Le champ mecanisme est ce qui distingue une instanciation d''une paraphrase.';

CREATE TABLE sources (
    source_id            TEXT PRIMARY KEY,
    name                 TEXT NOT NULL,
    organisation         TEXT NOT NULL,
    url                  TEXT NOT NULL,
    frequency            TEXT NOT NULL,
    format               TEXT NOT NULL,
    access               TEXT NOT NULL CHECK (access IN ('libre','libre_quota','inscription','payant')),
    qualification_status TEXT NOT NULL CHECK (qualification_status IN ('certifiee','a_confirmer','restreinte')),
    qualified_by         TEXT NOT NULL,    -- qui a qualifié : la décision est nominative (§ 10.4, fonction non délégable)
    qualified_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes                TEXT
);
COMMENT ON COLUMN sources.qualified_by IS
  'Qualification manuelle obligatoire. Aucune source n''entre au référentiel sans décision humaine tracée (§ 10.4.2).';

-- ---------------------------------------------------------------------
-- 2. Indicateurs
-- ---------------------------------------------------------------------

CREATE TABLE indicators (
    indicator_id TEXT PRIMARY KEY,                    -- 'A5', 'H1', 'T3'…
    sector_code  TEXT NOT NULL REFERENCES sectors(code),
    label        TEXT NOT NULL,
    source_id    TEXT NOT NULL REFERENCES sources(source_id),
    category     TEXT NOT NULL CHECK (category IN ('hard','composite')),
    frequency    TEXT NOT NULL CHECK (frequency IN ('mensuelle','trimestrielle','semestrielle','annuelle','bisannuelle')),
    unit         TEXT NOT NULL,
    status       TEXT NOT NULL CHECK (status IN ('certifie','a_confirmer','restreint')),
    alert_threshold_pct NUMERIC,                      -- NULL = pas d'alerte configurée
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE indicator_watch_questions (
    indicator_id        TEXT NOT NULL REFERENCES indicators(indicator_id) ON DELETE CASCADE,
    watch_question_code TEXT NOT NULL REFERENCES watch_questions(code),
    PRIMARY KEY (indicator_id, watch_question_code)
);
COMMENT ON TABLE indicator_watch_questions IS
  'Relation multiple : un indicateur peut répondre à plusieurs questions (ex. H3 → QV2 et QV3).';

-- Règle : tout indicateur est rattaché à au moins une question de veille.
-- Non exprimable en CHECK ; imposée par contrainte différée, vérifiée à la validation de transaction.
CREATE FUNCTION exiger_question_de_veille() RETURNS trigger AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM indicator_watch_questions WHERE indicator_id = NEW.indicator_id) THEN
        RAISE EXCEPTION
          'Indicateur % sans question de veille rattachée. Un indicateur sans question ne permet aucune analyse (§ 8.1.2) : il est écarté quelle que soit la qualité de sa source.',
          NEW.indicator_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_indicateur_sans_question
    AFTER INSERT ON indicators
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION exiger_question_de_veille();

-- ---------------------------------------------------------------------
-- 3. Exécutions (« outil vivant »)
-- ---------------------------------------------------------------------

CREATE TABLE runs (
    run_id       BIGSERIAL PRIMARY KEY,
    executed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at    TIMESTAMPTZ,
    trigger_type TEXT NOT NULL CHECK (trigger_type IN ('schedule','manual')),
    scenario     TEXT NOT NULL DEFAULT 'B' CHECK (scenario = 'B'),
    status       TEXT NOT NULL DEFAULT 'en_cours' CHECK (status IN ('en_cours','ok','partiel','echec')),
    note         TEXT
);
COMMENT ON COLUMN runs.scenario IS
  'Le schéma de production n''accepte que le scénario B. Les exécutions du scénario C vivent dans le schéma sandbox, sans contact avec ces données.';

-- ---------------------------------------------------------------------
-- 4. Valeurs — le registre, en ajout seul
-- ---------------------------------------------------------------------

CREATE TABLE indicator_values (
    value_id          BIGSERIAL PRIMARY KEY,
    indicator_id      TEXT NOT NULL REFERENCES indicators(indicator_id),
    run_id            BIGINT NOT NULL REFERENCES runs(run_id),
    period            TEXT NOT NULL,                  -- '2025', '2026-06', '2026-T1'
    geo               TEXT NOT NULL DEFAULT 'WORLD',
    value             NUMERIC NOT NULL,
    obtained_by       TEXT NOT NULL CHECK (obtained_by IN ('etl','ia_extraction')),
    validation_status TEXT NOT NULL CHECK (validation_status IN ('valide_source','pre_valide_consensus','valide_humain','rejete')),
    consensus_score   NUMERIC CHECK (consensus_score IS NULL OR (consensus_score >= 0 AND consensus_score <= 1)),
    validated_by      TEXT,
    validated_at      TIMESTAMPTZ,
    raw_ref           TEXT NOT NULL,                  -- chemin du dépôt brut ou URL exacte : sans lui, la valeur n'est pas auditable
    collected_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (indicator_id, run_id, period, geo),

    -- RÈGLE 1 — Usage différencié (§ 13.1). Une valeur obtenue par extraction IA
    -- ne peut jamais porter le statut « validée par la source ». Le statut le
    -- plus fort qu'elle puisse atteindre sans humain est le pré-validé par consensus.
    CONSTRAINT chk_hierarchie_controle CHECK (
        (obtained_by = 'etl'           AND validation_status IN ('valide_source','rejete'))
     OR (obtained_by = 'ia_extraction' AND validation_status IN ('pre_valide_consensus','valide_humain','rejete'))
    ),

    -- RÈGLE 2 — Le consensus n'est acquis qu'à l'unanimité des modèles interrogés.
    -- Un consensus partiel n'est pas un consensus : il part en file de validation humaine.
    CONSTRAINT chk_consensus_unanime CHECK (
        validation_status <> 'pre_valide_consensus' OR consensus_score = 1
    ),

    -- RÈGLE 3 — Une validation humaine sans validateur nommé et daté n'est pas
    -- une validation. La supervision doit être traçable pour être opposable (E6).
    CONSTRAINT chk_validation_humaine_tracee CHECK (
        validation_status <> 'valide_humain' OR (validated_by IS NOT NULL AND validated_at IS NOT NULL)
    ),

    -- RÈGLE 4 — Le consensus n'a de sens que pour une extraction par IA.
    CONSTRAINT chk_consensus_reserve_ia CHECK (
        consensus_score IS NULL OR obtained_by = 'ia_extraction'
    )
);

COMMENT ON TABLE indicator_values IS
  'Registre des valeurs. En AJOUT SEUL : une valeur n''est jamais modifiée ni supprimée, chaque exécution ajoute ses observations. C''est l''implémentation de l''outil vivant (D-18) — l''écart entre runs est la tendance.';

COMMENT ON COLUMN indicator_values.validation_status IS
  'Aucun statut « en attente » ici : une valeur non tranchée n''entre pas au registre, elle attend dans validation_queue. Le registre ne contient que du décidé.';

-- Ajout seul, imposé par la base et non par la discipline des workflows.
CREATE FUNCTION interdire_modification_du_registre() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION
      'Le registre des valeurs est en ajout seul (D-18). Pour corriger une valeur, ajoutez-la dans un nouveau run : la correction fait partie de l''historique, elle ne l''efface pas.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_registre_ajout_seul
    BEFORE UPDATE OR DELETE ON indicator_values
    FOR EACH ROW EXECUTE FUNCTION interdire_modification_du_registre();

CREATE INDEX idx_values_lookup ON indicator_values (indicator_id, period, geo, run_id DESC);

-- ---------------------------------------------------------------------
-- 5. File de validation humaine (pipeline composite)
-- ---------------------------------------------------------------------

CREATE TABLE validation_queue (
    item_id       BIGSERIAL PRIMARY KEY,
    indicator_id  TEXT NOT NULL REFERENCES indicators(indicator_id),
    run_id        BIGINT NOT NULL REFERENCES runs(run_id),
    period        TEXT NOT NULL,
    geo           TEXT NOT NULL DEFAULT 'WORLD',
    extractions   JSONB NOT NULL,                     -- valeurs proposées, par modèle
    consensus_score NUMERIC NOT NULL,
    source_doc    TEXT NOT NULL,                      -- document d'origine, consultable côte à côte
    raw_ref       TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    decided_value NUMERIC,
    decision      TEXT CHECK (decision IS NULL OR decision IN ('accepte','corrige','rejete')),
    decided_by    TEXT,
    decided_at    TIMESTAMPTZ,

    CONSTRAINT chk_decision_complete CHECK (
        decision IS NULL OR (decided_by IS NOT NULL AND decided_at IS NOT NULL)
    )
);
COMMENT ON TABLE validation_queue IS
  'Sas entre l''extraction par IA et le registre. Tout désaccord entre modèles, toute valeur aberrante y transite. Le taux de correction observé ici est la métrique de preuve qui conditionne le passage en supervision par exception (§ 10.4.2).';

-- ---------------------------------------------------------------------
-- 6. Commentaires exécutifs et alertes
-- ---------------------------------------------------------------------

CREATE TABLE commentaries (
    commentary_id BIGSERIAL PRIMARY KEY,
    run_id        BIGINT NOT NULL REFERENCES runs(run_id),
    sector_code   TEXT NOT NULL REFERENCES sectors(code),
    watch_question_code TEXT REFERENCES watch_questions(code),
    input_payload JSONB NOT NULL,                     -- les chiffres EXACTS soumis au modèle
    model         TEXT NOT NULL,
    text          TEXT NOT NULL,
    status        TEXT NOT NULL DEFAULT 'a_valider' CHECK (status IN ('a_valider','valide','rejete')),
    validated_by  TEXT,
    validated_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_commentaire_valide_trace CHECK (
        status <> 'valide' OR (validated_by IS NOT NULL AND validated_at IS NOT NULL)
    )
);
COMMENT ON COLUMN commentaries.input_payload IS
  'Conservation du contexte exact fourni au modèle. Sans lui, la fidélité du commentaire (« aucun chiffre absent des données fournies ») est invérifiable a posteriori — l''affirmation du § 11.2 deviendrait indémontrable.';

CREATE TABLE alerts (
    alert_id     BIGSERIAL PRIMARY KEY,
    indicator_id TEXT NOT NULL REFERENCES indicators(indicator_id),
    run_id       BIGINT NOT NULL REFERENCES runs(run_id),
    rule         TEXT NOT NULL,
    observed_value NUMERIC NOT NULL,
    variation_pct  NUMERIC,
    message      TEXT,                                -- brief rédigé par LLM
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    validated_by TEXT,
    validated_at TIMESTAMPTZ,

    CONSTRAINT chk_alerte_validee_tracee CHECK (
        validated_by IS NULL OR validated_at IS NOT NULL
    )
);

-- ---------------------------------------------------------------------
-- 7. Couche 0 — découverte et qualification des sources (§ 10.2)
-- ---------------------------------------------------------------------

CREATE TABLE source_qualification_queue (
    item_id       BIGSERIAL PRIMARY KEY,
    source_url    TEXT NOT NULL,
    source_name   TEXT,
    sector_code   TEXT REFERENCES sectors(code),
    watch_question_code TEXT REFERENCES watch_questions(code),
    besoin        TEXT,
    propositions  JSONB NOT NULL,                     -- ce que chaque modèle a proposé
    nb_modeles    INTEGER NOT NULL,
    indice_recouvrement NUMERIC NOT NULL,
    http_status   INTEGER NOT NULL,                   -- preuve d'existence, non de pertinence
    verifiee_le   TIMESTAMPTZ NOT NULL,
    decision      TEXT CHECK (decision IS NULL OR decision IN ('inscrite','ecartee','differee')),
    decided_by    TEXT,
    decided_at    TIMESTAMPTZ
);

CREATE TABLE discovery_log (
    log_id       BIGSERIAL PRIMARY KEY,
    source_url   TEXT NOT NULL,
    statut_traitement TEXT NOT NULL CHECK (statut_traitement IN ('non_verifiable','doublon_referentiel')),
    motif        TEXT NOT NULL,
    modeles_proposants JSONB NOT NULL,
    nb_modeles   INTEGER,
    http_status  INTEGER,
    constate_le  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE discovery_log IS
  'Journal des propositions écartées. Mesure continue du taux d''invention par modèle sur la tâche d''identification de sources, en régime d''exploitation et non en laboratoire.';

-- ---------------------------------------------------------------------
-- 8. Espace bac à sable — scénario C
-- ---------------------------------------------------------------------

CREATE SCHEMA sandbox;
COMMENT ON SCHEMA sandbox IS
  'Espace de l''artefact agentique du scénario C (§ 10.5). DÉLIBÉRÉMENT SANS CONTRAINTES : l''agent publie sans validation, et cette absence de garde-fou est l''objet même de la comparaison. Aucune vue du tableau de bord ne lit ce schéma.';

CREATE TABLE sandbox.agent_values (
    id            BIGSERIAL PRIMARY KEY,
    run_namespace TEXT NOT NULL DEFAULT 'sandbox_agent',
    indicator_label TEXT,
    sector        TEXT,
    watch_question TEXT,
    period        TEXT,
    geo           TEXT,
    value         TEXT,                               -- TEXT et non NUMERIC : l'agent n'est pas contraint au type
    source_url    TEXT,
    obtained_by   TEXT,
    validation_status TEXT,                           -- 'publie_sans_validation' — statut qui n'existe pas côté B
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sandbox.agent_commentaries (
    id            BIGSERIAL PRIMARY KEY,
    run_namespace TEXT NOT NULL DEFAULT 'sandbox_agent',
    sector        TEXT,
    watch_question TEXT,
    text          TEXT,
    status        TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sandbox.agent_runs (
    id            BIGSERIAL PRIMARY KEY,
    run_namespace TEXT NOT NULL DEFAULT 'sandbox_agent',
    scenario      TEXT NOT NULL DEFAULT 'C',
    clos_le       TIMESTAMPTZ,
    nb_iterations INTEGER,
    plafond_atteint BOOLEAN,
    appels_par_outil JSONB,
    referentiel_consulte BOOLEAN,
    outil_calcul_utilise BOOLEAN,
    sortie_finale TEXT,
    trace_complete JSONB,
    autocritique  JSONB
);
