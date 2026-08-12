-- =====================================================================
-- Signaux qualitatifs — tranche verticale « signaux faibles »
--
-- PRÉPARÉE le 12.08.2026. Exécution du volet OSINT prévu au protocole
-- d'exploration (familles de sources non périodiques) en réutilisant la
-- chaîne d'extraction fiabilisée démontrée par A2 au run 28 : document →
-- trois modèles → extraits source obligatoires → validation humaine.
--
-- CE QUE CETTE TABLE N'EST PAS. Ce n'est pas le registre des valeurs :
-- un signal n'est pas une observation chiffrée d'une série, c'est un
-- ÉVÉNEMENT structuré extrait d'un document non périodique (règlement,
-- annonce, appel d'offres). Il ne porte pas de « value » et n'entre
-- jamais dans v_current ni dans les métriques.
--
-- RÈGLES REPRISES DE L'ARCHITECTURE :
--   1. Pas de signal sans question de veille rattachée (même règle que
--      les indicateurs). Premier terrain : automobile / QV5 — la lacune
--      typée du ch. 8 (les impulsions publiques automobiles sont des
--      actes réglementaires, pas des séries).
--   2. La validation humaine est SYSTÉMATIQUE : aucun statut « validé »
--      sans validateur nommé et daté. Sur du qualitatif, le consensus
--      inter-modèles est indicatif (score de recoupement), jamais
--      suffisant — a fortiori par rapport aux valeurs chiffrées.
--   3. Seuls les signaux validés sont montrés au décideur ; les
--      « à valider » n'apparaissent qu'en compteur (analogue de RI5).
--   4. La sélection du document reste MANUELLE (le veilleur choisit,
--      l'IA lit et structure, l'humain valide) — scénario B, pas de
--      moissonnage autonome.
--
-- Exécution (depuis prototype/) — AVANT le réimport d'api_restitution :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-12_signaux_qualitatifs.sql \
--     | tee ../annexe_5/migration_signaux_2026-08-12.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE signals (
    signal_id       BIGSERIAL PRIMARY KEY,
    run_id          BIGINT NOT NULL REFERENCES runs(run_id),
    sector_code     TEXT NOT NULL REFERENCES sectors(code),
    watch_question_code TEXT NOT NULL REFERENCES watch_questions(code),
    source_doc      TEXT NOT NULL,             -- URL du document d'origine
    raw_ref         TEXT NOT NULL,             -- dépôt brut (E6)

    -- Schéma d'événement. Champs retenus par recoupement des modèles ;
    -- NULL quand les modèles divergent — l'humain tranche à la validation
    -- sur la base du détail conservé dans extraits.
    evenement       TEXT,                      -- quoi : le fait, en une phrase
    acteur          TEXT,                      -- qui : institution, entreprise
    echeance        TEXT,                      -- quand : date(s) d'effet
    zone            TEXT,                      -- où : périmètre géographique

    extraits        JSONB NOT NULL,            -- détail complet par modèle : valeurs + extraits source
    score_recoupement NUMERIC CHECK (score_recoupement >= 0 AND score_recoupement <= 1),

    statut          TEXT NOT NULL DEFAULT 'a_valider'
                    CHECK (statut IN ('a_valider','valide','rejete')),
    validated_by    TEXT,
    validated_at    TIMESTAMPTZ,
    note_validation TEXT,                      -- portée pour un sous-traitant : jugement HUMAIN, jamais extrait
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Une validation (ou un rejet) sans auteur nommé et daté n'existe pas.
    CONSTRAINT chk_signal_decide_trace CHECK (
        statut = 'a_valider' OR (validated_by IS NOT NULL AND validated_at IS NOT NULL)
    )
);

COMMENT ON TABLE signals IS
  'Signaux qualitatifs extraits de documents non périodiques par la chaîne multi-modèles (workflow extraction_signal_qualitatif). Distinct du registre des valeurs : un signal est un événement, pas une observation de série. Validation humaine systématique — le recoupement inter-modèles est indicatif, jamais suffisant sur du qualitatif.';

COMMENT ON COLUMN signals.note_validation IS
  'Portée du signal pour un sous-traitant, rédigée par le validateur humain. Volontairement absente du schéma d''extraction : c''est une interprétation, pas un fait du document — la faire produire par les modèles reviendrait à déléguer la lecture stratégique.';

-- Vue de restitution : ce que l'interface sert au tableau de bord.
CREATE VIEW v_signaux AS
SELECT s.signal_id, s.sector_code, sec.label AS sector_label,
       s.watch_question_code, s.evenement, s.acteur, s.echeance, s.zone,
       s.source_doc, s.raw_ref, s.score_recoupement, s.statut,
       s.validated_by, s.validated_at, s.note_validation,
       s.run_id, s.created_at
FROM signals s
JOIN sectors sec ON sec.code = s.sector_code;

COMMENT ON VIEW v_signaux IS
  'Signaux pour la restitution. Le tableau de bord n''affiche en clair que les validés ; les « à valider » remontent en compteur (analogue de RI5 pour le qualitatif).';

COMMIT;

-- =====================================================================
-- Vérifications
-- =====================================================================

\echo ''
\echo '--- Table et vue créées'
\echo '    Attendu : signals (0 ligne), v_signaux (0 ligne).'
SELECT count(*) AS signaux FROM signals;
SELECT count(*) AS signaux_vue FROM v_signaux;

\echo ''
\echo '--- Contrainte de traçabilité : une validation sans auteur doit être refusée'
\echo '    Attendu : ERROR ... chk_signal_decide_trace. Cette erreur est le résultat'
\echo '    voulu du test — la sortie est une pièce d''annexe 5.'
\set ON_ERROR_STOP off
BEGIN;
INSERT INTO runs (trigger_type, scenario, status, note) VALUES ('manual','B','en_cours','test contrainte signaux') RETURNING run_id;
INSERT INTO signals (run_id, sector_code, watch_question_code, source_doc, raw_ref, extraits, statut)
VALUES ((SELECT max(run_id) FROM runs), 'automobile', 'QV5', 'test', 'test', '{}'::jsonb, 'valide');
ROLLBACK;
