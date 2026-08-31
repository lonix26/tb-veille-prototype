-- =====================================================================
-- DEUX ÉTAGES NOUVEAUX : ÉVÉNEMENTS TYPÉS ET LECTURES TRANSVERSALES
--
-- DÉCISION DE PÉRIMÈTRE de l'étudiant du 31.08.2026, réaffirmée après
-- signalement du coût calendaire (13 jours du dépôt) — à ratifier avec le
-- lot § 7.2.2. Deux constats l'ont motivée :
--  1. l'intensité de signalement COMPTE des items ; un décideur a besoin
--     de savoir CE QUI S'EST PASSÉ — l'événement typé (qui, quoi, où,
--     quel sens pour un sous-traitant) est requêtable et tendanciable ;
--  2. le dispositif ne RELIE rien : 42 indicateurs collectés, aucune
--     lecture inter-signaux. C'est le seul étage où un modèle produit
--     quelque chose que ni le code ni un humain pressé ne produiraient.
--
-- DOCTRINE, inchangée. Les événements : modèle de lecture UNIQUE (le
-- régime du triage, § 9.5.1) — pas de consensus sur du qualitatif, la
-- diffusion se fait sous étiquette « non relu » (le régime du commentaire
-- du 31.08). Les lectures : GÉNÉRATION CONTRAINTE — le modèle ne reçoit
-- que des faits calculés par le code (F1..Fn), n'écrit AUCUN chiffre, et
-- chaque hypothèse cite ses faits ; leçon des 38 rejets du commentaire
-- (calculs dérivés, chiffres contredits — l'IA fabrique des nombres si
-- on la laisse faire). Validation humaine : les deux tables portent un
-- statut ; rien ne passe « validé » sans nom et date.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE flux_evenements (
  evenement_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  item_id       bigint NOT NULL REFERENCES flux_items(item_id),
  run_id        bigint NOT NULL REFERENCES runs(run_id),
  sector_code   text REFERENCES sectors(code),
  -- le vocabulaire est FERMÉ : un type libre ne se compte pas
  type_evenement text NOT NULL CHECK (type_evenement IN
    ('investissement','fermeture_reduction','rachat_fusion','reglementation',
     'lancement_produit','resultat_financier','partenariat','autre')),
  acteur        text,
  zone          text,
  sens_sous_traitance text NOT NULL CHECK (sens_sous_traitance IN ('opportunite','menace','neutre')),
  resume        text NOT NULL,
  modele        text NOT NULL,
  statut        text NOT NULL DEFAULT 'non_relu' CHECK (statut IN ('non_relu','valide','rejete')),
  verifie_par   text,
  verifie_le    timestamptz,
  horodatage    timestamptz NOT NULL DEFAULT now(),
  -- un item ne porte qu'une lecture événementielle par modèle
  UNIQUE (item_id, modele),
  CONSTRAINT chk_evenement_verifie CHECK (statut = 'non_relu' OR (verifie_par IS NOT NULL AND verifie_le IS NOT NULL))
);
COMMENT ON TABLE flux_evenements IS
'Événements typés lus par un modèle unique dans les items de flux pertinents. Diffusés sous étiquette « non relu » tant qu''aucun humain n''a tranché — le régime du commentaire exécutif (décision du 31.08.2026).';

CREATE TABLE lectures_transversales (
  lecture_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  run_id        bigint NOT NULL REFERENCES runs(run_id),
  hypothese     text NOT NULL,
  -- les faits cités sont FIGÉS à la génération : la lecture reste auditable
  -- même quand le registre a avancé
  faits_cites   jsonb NOT NULL,
  confiance     text NOT NULL CHECK (confiance IN ('haute','moyenne','basse')),
  infirmable_par text,
  incidents     jsonb NOT NULL DEFAULT '[]'::jsonb,
  modele        text NOT NULL,
  statut        text NOT NULL DEFAULT 'a_valider' CHECK (statut IN ('a_valider','valide','rejete')),
  validated_by  text,
  validated_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_lecture_validee CHECK (statut = 'a_valider' OR (validated_by IS NOT NULL AND validated_at IS NOT NULL))
);
COMMENT ON TABLE lectures_transversales IS
'Hypothèses de liaison inter-signaux, générées sous contrainte : le modèle ne reçoit que des faits calculés (F1..Fn), n''écrit aucun chiffre, cite ses faits. La validation humaine tranche ; une hypothèse rejetée reste en base — le taux de rejet est une mesure du dispositif, pas un déchet.';

-- Le décompte par type et par mois : la vue qui remplace « N items triés »
CREATE VIEW v_evenements_mois AS
SELECT e.sector_code, to_char(i.date_publication,'YYYY-MM') AS mois,
       e.type_evenement, e.sens_sous_traitance, count(*) AS n,
       count(*) FILTER (WHERE e.statut = 'valide') AS n_valides
FROM flux_evenements e JOIN flux_items i USING (item_id)
WHERE e.statut <> 'rejete'
GROUP BY 1,2,3,4;

COMMIT;

\echo '--- Vérifications'
\d flux_evenements
SELECT count(*) AS evenements, (SELECT count(*) FROM lectures_transversales) AS lectures FROM flux_evenements;
