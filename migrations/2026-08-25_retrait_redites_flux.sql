-- 2026-08-25 — Retrait des redites introduites par une empreinte défectueuse
--
-- CONTEXTE. Le portage du collecteur de flux vers n8n (workflow `collecteFluxV1`)
-- a d'abord employé un condensé maison au lieu du SHA-256 du script Python qu'il
-- remplace, au motif — vérifié faux depuis — que les nœuds Code n'exposeraient pas
-- `require('crypto')`. La clause de déduplication `ON CONFLICT (empreinte)` n'a donc
-- plus reconnu les items déjà collectés : 509 lignes ont été réécrites, dont 391
-- sont des redites strictes d'items déjà présents. La file d'examen est passée de
-- 344 à 1 135 entrées.
--
-- NATURE DE L'OPÉRATION. Ceci n'est PAS une réécriture de l'historique de collecte.
-- Aucune observation réelle n'est retirée : les 118 items authentiquement nouveaux
-- de la même fournée sont conservés, et les 391 lignes supprimées ont chacune un
-- jumeau exact (même URL, ou même titre lorsque l'URL est absente) qui reste en base
-- avec son empreinte SHA-256 correcte. Ce qui est retiré est un artefact de mon
-- erreur d'implémentation, pas une trace de veille.
--
-- SUSPENSION DE D-18. La décision D-18 (registre en ajout seul) est appliquée par le
-- déclencheur `trg_flux_ajout_seul`. Sa suspension ici est délibérée, bornée à cette
-- transaction et à cette table, et décidée par l'étudiant le 25.08.2026 après exposé
-- des trois options (ne rien faire / tout supprimer / supprimer les seules redites).
-- Le déclencheur est réarmé avant COMMIT ; l'échec de son rétablissement annule tout.
--
-- AUDITABILITÉ. Les 391 lignes retirées sont archivées avant suppression dans
-- `annexe_5/redites_flux_supprimees_2026-08-25.csv` (identifiant, flux, date, titre,
-- URL, empreinte fautive, horodatage de collecte). La suppression reste donc
-- vérifiable sur pièce, ce qui est l'esprit de D-18 même quand sa lettre est levée.

BEGIN;

CREATE TEMP TABLE redites_a_retirer ON COMMIT DROP AS
SELECT m.item_id
  FROM flux_items m
 WHERE length(m.empreinte) <> 64
   AND EXISTS (
        SELECT 1 FROM flux_items b
         WHERE length(b.empreinte) = 64
           AND ( (m.url IS NOT NULL AND b.url = m.url)
              OR (m.url IS NULL     AND b.titre = m.titre) ));

-- Garde-fou : si le compte s'écarte de ce qui a été mesuré et archivé, on n'exécute pas.
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM redites_a_retirer;
  IF n <> 391 THEN
    RAISE EXCEPTION 'Périmètre inattendu : % redites au lieu des 391 mesurées et archivées.', n;
  END IF;
END $$;

-- Les scores de triage rattachés aux redites partent avec elles : la clé étrangère
-- est en NO ACTION, et un score porté sur une redite n'a pas d'existence propre.
-- Les items jumeaux conservés seront rescorés au prochain passage de `triageFluxV1`.
DELETE FROM flux_triage_ia WHERE item_id IN (SELECT item_id FROM redites_a_retirer);

ALTER TABLE flux_items DISABLE TRIGGER trg_flux_ajout_seul;
DELETE FROM flux_items WHERE item_id IN (SELECT item_id FROM redites_a_retirer);
ALTER TABLE flux_items ENABLE TRIGGER trg_flux_ajout_seul;

-- Vérification du réarmement avant validation : sans lui, la transaction n'a pas lieu.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgrelid = 'flux_items'::regclass
                    AND tgname  = 'trg_flux_ajout_seul'
                    AND tgenabled <> 'D') THEN
    RAISE EXCEPTION 'Le déclencheur trg_flux_ajout_seul n''a pas été réarmé — annulation.';
  END IF;
END $$;

COMMIT;
