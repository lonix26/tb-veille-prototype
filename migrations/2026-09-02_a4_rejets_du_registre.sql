-- ============================================================================
-- A4 — Deux observations fausses ou doublées, servies en `valide_source` /
-- `valide_humain`, passent au statut `rejete` avec motif
-- N. Castillo, 02.09.2026 — correction A4 du tour « jury » (DATA-5, DATA-10)
--
-- CONSTAT. Le registre `indicator_values` est en ajout seul (D-18) : le
-- déclencheur `trg_registre_ajout_seul` interdit toute mise à jour et toute
-- suppression. Le statut `rejete` est prévu par les contraintes, mais aucun
-- chemin ne permet d'y amener une ligne déjà écrite : une valeur reconnue
-- fausse APRÈS coup ne pouvait qu'être laissée telle quelle — c'est ainsi que
-- la ligne WORLD du run 33 (M3, valeur de l'Éthiopie sous la zone monde,
-- incident du 17.08) est restée « conservée à l'historique » en `valide_source`,
-- et qu'A2 2025-11 est porté deux fois (runs 29 et 30, même validation rejouée).
--
-- CE QUE FAIT CETTE MIGRATION — et ce qu'elle ne fait pas.
--   1. Une colonne `rejet_motif` ; un statut `rejete` exige auteur, date et motif.
--   2. Le déclencheur d'ajout seul admet UNE transition, et une seule : passer
--      `validation_status` à `rejete` en renseignant `validated_by`,
--      `validated_at` et `rejet_motif`, TOUTES les autres colonnes restant
--      identiques. La valeur n'est jamais modifiée ni effacée ; le rejet est
--      un événement daté et signé. Toute autre mise à jour, et toute
--      suppression, restent interdites.
--   3. Deux lignes rejetées : value_id 4249 (M3 WORLD run 33) et 3400 (A2
--      2025-11 run 30). Les 1 077 « écartées par contrôles qualité » du run 209
--      (BD-5) ne sont PAS traitées ici : elles n'ont jamais été écrites.
-- TENSION SIGNALÉE : D-18 (« ajout seul ») est précisée, pas révisée — décision
-- d'étudiant du 02.09.2026, à ratifier (§ 7.2.2).
-- ============================================================================

BEGIN;

-- 1. Colonne et contrainte
ALTER TABLE public.indicator_values ADD COLUMN IF NOT EXISTS rejet_motif text;
COMMENT ON COLUMN public.indicator_values.rejet_motif IS
  'Motif du rejet, en clair. Obligatoire quand validation_status = rejete (chk_rejet_trace). Ajouté le 02.09.2026 (A4).';
ALTER TABLE public.indicator_values
  ADD CONSTRAINT chk_rejet_trace
  CHECK (validation_status <> 'rejete' OR (rejet_motif IS NOT NULL AND validated_by IS NOT NULL AND validated_at IS NOT NULL));

-- 2. Déclencheur : ajout seul, plus une transition vers `rejete`
CREATE OR REPLACE FUNCTION public.interdire_modification_du_registre()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF TG_OP = 'UPDATE'
       AND OLD.validation_status <> 'rejete' AND NEW.validation_status = 'rejete'
       AND NEW.rejet_motif IS NOT NULL AND NEW.validated_by IS NOT NULL AND NEW.validated_at IS NOT NULL
       AND NEW.value_id = OLD.value_id AND NEW.indicator_id = OLD.indicator_id
       AND NEW.run_id = OLD.run_id AND NEW.period = OLD.period AND NEW.geo = OLD.geo
       AND NEW.value IS NOT DISTINCT FROM OLD.value
       AND NEW.obtained_by = OLD.obtained_by
       AND NEW.consensus_score IS NOT DISTINCT FROM OLD.consensus_score
       AND NEW.raw_ref IS NOT DISTINCT FROM OLD.raw_ref
       AND NEW.collected_at IS NOT DISTINCT FROM OLD.collected_at
    THEN
        -- Seule transition admise (02.09.2026, A4) : le rejet motivé, signé et
        -- daté d'une ligne existante. La valeur reste lisible ; elle cesse
        -- d'être servie.
        RETURN NEW;
    END IF;
    RAISE EXCEPTION
      'Le registre des valeurs est en ajout seul (D-18). Pour corriger une valeur, ajoutez-la dans un nouveau run : la correction fait partie de l''historique, elle ne l''efface pas. Seule exception : passer une ligne au statut rejete avec motif, auteur et date, sans toucher au reste.';
END;
$function$;

COMMENT ON FUNCTION public.interdire_modification_du_registre() IS
  'Registre en ajout seul (D-18). Depuis le 02.09.2026 (A4), admet une seule mise à jour : validation_status → rejete, avec rejet_motif, validated_by et validated_at, toutes les autres colonnes inchangées.';

-- 3. Les deux rejets
-- 3a. M3, zone WORLD, run 33 : première ligne du fichier brut (SpatialDim ETH,
--     2,803) écrite sous WORLD par un mappage positionnel — incident du 17.08,
--     mappage corrigé au run 34 (note de la liaison 25). La valeur mondiale
--     GHO (GLOBAL) est 6,828, portée par tous les runs suivants.
UPDATE public.indicator_values
   SET validation_status = 'rejete',
       validated_by = 'N. Castillo',
       validated_at = now(),
       rejet_motif  = 'Valeur de l''Éthiopie (SpatialDim ETH, première ligne de M3_run33.raw) écrite sous la zone WORLD par un mappage positionnel ; valeur mondiale GHO = 6,828 (runs 34 et suivants). Incident du 17.08.2026, mappage corrigé depuis.'
 WHERE value_id = 4249 AND indicator_id = 'M3' AND geo = 'WORLD' AND run_id = 33
   AND validation_status = 'valide_source';

-- 3b. A2 2025-11, run 30 : la validation humaine du run 29 rejouée 50 minutes
--     plus tard, même valeur (887 491), même document, même note de run. La
--     période reste portée par value_id 3399 (run 29).
UPDATE public.indicator_values
   SET validation_status = 'rejete',
       validated_by = 'N. Castillo',
       validated_at = now(),
       rejet_motif  = 'Double écriture : le run 30 rejoue la validation humaine du run 29 (même valeur 887 491, même document A2_run28.pdf). Période portée par value_id 3399.'
 WHERE value_id = 3400 AND indicator_id = 'A2' AND period = '2025-11' AND run_id = 30
   AND validation_status = 'valide_humain';

COMMIT;

-- Contrôles
SELECT value_id, indicator_id, run_id, period, geo, value, validation_status, validated_by, left(rejet_motif, 60)
  FROM indicator_values WHERE validation_status = 'rejete' ORDER BY value_id;
SELECT indicator_id, period, geo, value, run_id FROM v_current
 WHERE (indicator_id = 'M3' AND geo = 'WORLD') OR (indicator_id = 'A2' AND period = '2025-11');
SELECT count(*) AS a2_2025_11_servies FROM v_current WHERE indicator_id = 'A2' AND period = '2025-11';
-- Le verrou tient toujours pour tout le reste :
DO $$ BEGIN
  BEGIN
    UPDATE indicator_values SET value = value + 1 WHERE value_id = 4249;
    RAISE EXCEPTION 'ÉCHEC DU CONTRÔLE : la mise à jour de la valeur a été acceptée';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'Le registre des valeurs est en ajout seul%' THEN
      RAISE NOTICE 'Contrôle 1 OK : modification de valeur refusée';
    ELSE RAISE; END IF;
  END;
  BEGIN
    DELETE FROM indicator_values WHERE value_id = 4249;
    RAISE EXCEPTION 'ÉCHEC DU CONTRÔLE : la suppression a été acceptée';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'Le registre des valeurs est en ajout seul%' THEN
      RAISE NOTICE 'Contrôle 2 OK : suppression refusée';
    ELSE RAISE; END IF;
  END;
  BEGIN
    UPDATE indicator_values SET validation_status = 'rejete' WHERE value_id = 3399;
    RAISE EXCEPTION 'ÉCHEC DU CONTRÔLE : rejet sans motif accepté';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'Le registre des valeurs est en ajout seul%' THEN
      RAISE NOTICE 'Contrôle 3 OK : rejet sans motif ni auteur refusé';
    ELSE RAISE; END IF;
  END;
END $$;
