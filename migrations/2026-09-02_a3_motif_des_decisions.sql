-- ============================================================================
-- A3 — Le motif d'une décision humaine est une colonne, pas une parenthèse
-- N. Castillo, 02.09.2026 — correction A3 du tour « jury » (constat B-2)
--
-- CONSTAT. Aucune des trois tables de décision (`validation_queue`,
-- `composite_queue`, `commentaries`) n'avait de colonne `motif`. Les motifs
-- existaient pourtant, mais dispersés : dans les commentaires des migrations
-- (runs 95, 108), dans l'auteur lui-même (« N. Castillo (archive de modele
-- erronee) », 24 lignes), dans `note` (composite_queue), ou nulle part
-- (run 101 : cinq rejets sans migration, sans auteur, sans date).
-- Les contraintes n'exigeaient un auteur que pour l'acceptation ; un rejet
-- pouvait rester anonyme. Or c'est la validation humaine, dernier rang de la
-- cascade (§ 7.2), qui doit être la mieux tracée.
--
-- CE QUE FAIT CETTE MIGRATION.
--   1. `motif text` sur les trois tables.
--   2. Un rejet exige auteur, date ET motif — contrainte CHECK. Sur
--      `commentaries`, elle est posée NOT VALID : cinq rejets du run 101 n'ont
--      ni auteur ni date connus, et cette migration ne les invente pas. La
--      contrainte s'applique à toute ligne écrite ou modifiée désormais ; les
--      cinq lignes restent en l'état, motif « aucune trace ».
--   3. Rapatriement des motifs existants, à partir des seules pièces
--      vérifiables : texte du commentaire (fournée 1), en-têtes de migration,
--      parenthèses de `validated_by`, `note` de `composite_queue`.
-- Rien n'est supprimé.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Colonnes
-- ----------------------------------------------------------------------------
ALTER TABLE public.validation_queue ADD COLUMN IF NOT EXISTS motif text;
ALTER TABLE public.composite_queue  ADD COLUMN IF NOT EXISTS motif text;
ALTER TABLE public.commentaries     ADD COLUMN IF NOT EXISTS motif text;

COMMENT ON COLUMN public.validation_queue.motif IS
  'Motif de la décision humaine, en clair. Obligatoire pour un rejet (chk_vq_rejet_motive). Ajouté le 02.09.2026 (A3).';
COMMENT ON COLUMN public.composite_queue.motif IS
  'Motif de l''écart d''un document (statut ecarte). Obligatoire (chk_cq_ecart_motive). `note` reste la note de travail libre. Ajouté le 02.09.2026 (A3).';
COMMENT ON COLUMN public.commentaries.motif IS
  'Motif du rejet, en clair. Obligatoire pour toute ligne rejetée écrite après le 02.09.2026 (chk_commentaire_rejet_trace, NOT VALID : cinq rejets antérieurs du run 101 sont sans trace). Ajouté le 02.09.2026 (A3).';

-- ----------------------------------------------------------------------------
-- 2. validation_queue — cinq rejets, motifs établis sur pièces
-- ----------------------------------------------------------------------------
-- Items 1-3 : A2 2025-11, runs 10, 26, 27. `consensus_score` = 0, trois
-- valeurs nulles, extraits vides : l'extraction n'a rien produit. La période
-- est portée par l'item 4 (accepté, 887 491).
UPDATE public.validation_queue
   SET motif = 'Extraction vide : consensus 0, trois valeurs nulles, aucun extrait. Période portée par l''item 4 (accepté).'
 WHERE item_id IN (1, 2, 3) AND decision = 'rejete';

-- Items 24-25 : H2 et H11 2025, run 168, mêmes valeurs (64 807 ; 685) que les
-- items 16-17 du run 163 acceptés deux minutes plus tôt sur le même document.
UPDATE public.validation_queue
   SET motif = 'Doublon : même document et mêmes valeurs que l''item ' ||
               CASE indicator_id WHEN 'H2' THEN '16' ELSE '17' END ||
               ' (run 163), accepté.'
 WHERE item_id IN (24, 25) AND decision = 'rejete';

ALTER TABLE public.validation_queue
  ADD CONSTRAINT chk_vq_rejet_motive
  CHECK (decision IS DISTINCT FROM 'rejete' OR motif IS NOT NULL);

-- ----------------------------------------------------------------------------
-- 3. composite_queue — un écart, dont la note portait auteur et date
-- ----------------------------------------------------------------------------
UPDATE public.composite_queue
   SET motif       = 'Bilan annuel 2025 (publié le 27.01.2026) : cumul janvier-décembre, pas de tableau mensuel de décembre exploitable pour l''extraction.',
       verifie_par = 'N. Castillo',
       verifie_le  = DATE '2026-08-17'
 WHERE doc_id = 1 AND statut = 'ecarte' AND verifie_par IS NULL;

ALTER TABLE public.composite_queue
  ADD CONSTRAINT chk_cq_ecart_motive
  CHECK (statut <> 'ecarte' OR (motif IS NOT NULL AND verifie_par IS NOT NULL AND verifie_le IS NOT NULL));

-- ----------------------------------------------------------------------------
-- 4. commentaries — 38 rejets
-- ----------------------------------------------------------------------------
-- 4a. Fournée 1 (run 69, 17.08) : trois motifs, chacun vérifiable dans le texte.
UPDATE public.commentaries SET motif = 'Calcul dérivé : décompte obtenu par soustraction (12 − 7), interdit par RI0.'
 WHERE commentary_id = 2 AND status = 'rejete' AND text ~ '5 points';
UPDATE public.commentaries SET motif = 'Affirmation contredite par la charge : « seuil non documenté » alors que input_payload porte un seuil de 5 %.'
 WHERE commentary_id = 3 AND status = 'rejete' AND text ~* 'non document';
UPDATE public.commentaries SET motif = 'Arrondi : « 114,57 » pour une valeur de charge à onze décimales (114,56911748501), proscrit par RI0.'
 WHERE commentary_id = 5 AND status = 'rejete' AND text ~ '114,57';

-- 4b. Run 70 (17.08) : fournée intermédiaire, générée entre deux correctifs,
--     rejetée en bloc comme obsolète (C4 § 11.6).
UPDATE public.commentaries SET motif = 'Fournée intermédiaire générée entre deux correctifs de consigne, rejetée en bloc comme obsolète.'
 WHERE run_id = 70 AND status = 'rejete' AND motif IS NULL;

-- 4c. Motifs logés entre parenthèses dans l'auteur : rapatriés, auteur nettoyé.
UPDATE public.commentaries
   SET motif = 'Archive de modèle erronée : le libellé de modèle enregistré n''est pas celui réellement appelé (portage vers $env.MODELE_*).',
       validated_by = 'N. Castillo'
 WHERE status = 'rejete' AND validated_by = 'N. Castillo (archive de modele erronee)';
UPDATE public.commentaries
   SET motif = 'Données supplantées : profondeur de série étendue le 24.08.2026, commentaire rédigé sur l''état antérieur des données.',
       validated_by = 'N. Castillo'
 WHERE status = 'rejete' AND validated_by = 'N. Castillo (donnees superseded : profondeur etendue le 24.08)';

-- 4d. Runs 95 et 108 : rejet tracé en migration (en-têtes signés
--     « N. Castillo, 24.08.2026 »), mais sans auteur ni date en base.
--     La date est celle de la migration, à la précision du jour.
UPDATE public.commentaries
   SET motif = 'Version périmée du workflow exécutée par erreur (cinq exemplaires coexistants, § 12.6 occ. 13) : format abandonné et libellé de modèle écrit en dur. Migration 2026-08-24_validation_commentaires_97.',
       validated_by = 'N. Castillo', validated_at = TIMESTAMPTZ '2026-08-24 00:00:00+00'
 WHERE run_id = 95 AND status = 'rejete' AND validated_by IS NULL;
UPDATE public.commentaries
   SET motif = 'Quatre appels sur cinq échoués faute de crédit d''API ; le cinquième conservé mais non diffusable seul. Migration 2026-08-24_validation_commentaires_109.',
       validated_by = 'N. Castillo', validated_at = TIMESTAMPTZ '2026-08-24 00:00:00+00'
 WHERE run_id = 108 AND status = 'rejete' AND validated_by IS NULL;

-- 4e. Run 101 : aucune migration, aucune entrée de passation, aucun auteur.
--     Cette migration ne reconstitue ni l'auteur ni la date.
UPDATE public.commentaries
   SET motif = 'AUCUNE TRACE : rejet saisi hors dépôt, sans migration, sans auteur ni date (constat B-2 du 02.09.2026).'
 WHERE run_id = 101 AND status = 'rejete' AND validated_by IS NULL;

ALTER TABLE public.commentaries
  ADD CONSTRAINT chk_commentaire_rejet_trace
  CHECK (status <> 'rejete' OR (validated_by IS NOT NULL AND validated_at IS NOT NULL AND motif IS NOT NULL))
  NOT VALID;

COMMIT;

-- ----------------------------------------------------------------------------
-- Contrôle
-- ----------------------------------------------------------------------------
SELECT 'validation_queue' AS t, decision AS etat, count(*) AS n, count(motif) AS motives, count(decided_by) AS auteurs
  FROM validation_queue GROUP BY 1, 2
UNION ALL
SELECT 'composite_queue', statut, count(*), count(motif), count(verifie_par) FROM composite_queue GROUP BY 1, 2
UNION ALL
SELECT 'commentaries', status, count(*), count(motif), count(validated_by) FROM commentaries GROUP BY 1, 2
ORDER BY 1, 2;

SELECT validated_by, count(*) FROM commentaries GROUP BY 1 ORDER BY 1;
SELECT conname, convalidated FROM pg_constraint
 WHERE conname IN ('chk_vq_rejet_motive', 'chk_cq_ecart_motive', 'chk_commentaire_rejet_trace');
