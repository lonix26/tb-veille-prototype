-- B3 — Relecture humaine d'un ÉCHANTILLON d'événements extraits par le modèle
-- (liste B du tour complet jury du 02.09.2026, acte 3).
--
-- Population : 690 événements `non_relu` (309 presse, 287 avis TED, 94 FDA).
-- Tirage reproductible de 30 événements exécuté le 02.09.2026 :
--   SELECT setseed(0.42);
--   SELECT e.evenement_id FROM flux_evenements e
--    WHERE e.statut = 'non_relu' ORDER BY random() LIMIT 30;
-- La reproductibilité de random() dépend de l'état physique de la table ;
-- les 30 identifiants tirés sont donc FIGÉS ci-dessous.
--
-- Critère de relecture : l'extraction (type, sens, acteur, zone, résumé)
-- est-elle fidèle au TITRE, seule charge transmise au modèle ? La pertinence
-- de l'item relève du filtrage (audit B4), pas de cet acte.
-- Décisions : N. Castillo, sur proposition motivée de l'assistant.

ALTER TABLE flux_evenements ADD COLUMN IF NOT EXISTS motif text;
COMMENT ON COLUMN flux_evenements.motif IS
  'Motif humain de la décision de relecture (obligatoire en pratique pour un rejet).';

CREATE TEMP TABLE d (evenement_id int PRIMARY KEY, statut text NOT NULL, motif text NOT NULL);
INSERT INTO d VALUES
 (601,'valide','Extraction fidèle au titre (510(k) rendu par « approbation », tolérable).'),
 (219,'valide','Extraction fidèle au titre.'),
 (244,'valide','Extraction fidèle ; acteur « non précisé » honnête, absent du titre.'),
 (420,'valide','Extraction fidèle au titre.'),
 (377,'valide','Extraction fidèle au titre.'),
 (369,'valide','Extraction fidèle au titre.'),
 (551,'valide','Extraction fidèle ; zone « non précisée » honnête.'),
 (126,'valide','Extraction fidèle au titre.'),
 (536,'valide','Extraction fidèle au titre.'),
 (605,'valide','Extraction fidèle au titre (rappel FDA).'),
 (262,'valide','Extraction fidèle au titre.'),
 (586,'valide','Extraction fidèle au titre.'),
 (341,'valide','Extraction fidèle au titre.'),
 (313,'valide','Extraction fidèle ; sens « menace » justifié (vote de grève).'),
 (63,'valide','Extraction fidèle au titre.'),
 (192,'valide','Extraction fidèle au titre.'),
 (435,'valide','Extraction fidèle au titre.'),
 (286,'valide','Extraction fidèle au titre.'),
 (532,'valide','Extraction fidèle au titre.'),
 (207,'valide','Extraction fidèle au titre.'),
 (93,'valide','Extraction fidèle ; acteur générique mais non faux.'),
 (441,'valide','Extraction fidèle au titre.'),
 (622,'valide','Extraction fidèle au titre.'),
 (308,'valide','Extraction fidèle au titre.'),
 (42,'rejete','acteur = « TED » : plateforme de publication prise pour l''acheteur (Fraport AG dans buyer-name, non transmis au modèle) ; attendu « non précisé ».'),
 (46,'rejete','acteur = « TED » : plateforme de publication prise pour l''acheteur ; attendu « non précisé ».'),
 (65,'rejete','acteur = « TED » : plateforme de publication prise pour l''acheteur ; attendu « non précisé ».'),
 (57,'rejete','acteur = « TED » : plateforme de publication prise pour l''acheteur ; attendu « non précisé ».'),
 (364,'rejete','type = lancement_produit pour une démonstration technologique ; « autre » attendu. Résumé fidèle.'),
 (529,'rejete','acteur = personne physique (ministre) au lieu de l''organisation ; objet de défense classé automobile par le flux. Résumé fidèle.');

-- Garde-fou : les 30 sont bien non relus avant décision.
DO $$ BEGIN
  IF (SELECT count(*) FROM d JOIN flux_evenements e USING (evenement_id) WHERE e.statut = 'non_relu') <> 30
  THEN RAISE EXCEPTION 'échantillon altéré : les 30 ne sont pas tous non_relu'; END IF;
END $$;

UPDATE flux_evenements e
   SET statut = d.statut, motif = d.motif,
       verifie_par = 'N. Castillo', verifie_le = now()
  FROM d WHERE e.evenement_id = d.evenement_id;

-- Commentaire exécutif 82 (horlogerie, run 197), servi depuis le rejet du 87 :
-- contrôlé cohérent avec sa charge (588 / +20 % H9 ; 2 163,1 / +10,55 % H8 ;
-- 64 807 H2 ; 685 H11 ; +7,83 % H1). Validation proposée en B2, confirmée ici.
UPDATE commentaries
   SET status = 'valide', validated_by = 'N. Castillo', validated_at = now(),
       motif = 'Nombres retrouvés dans la charge, aucune affirmation contredite (contrôle B2 du 02.09.2026).'
 WHERE commentary_id = 82 AND status = 'a_valider';

-- Bilan
SELECT 'echantillon' AS quoi, statut, count(*) FROM flux_evenements
 WHERE evenement_id IN (SELECT evenement_id FROM d) GROUP BY statut ORDER BY statut;
SELECT 'acteur_TED_restants_non_relus' AS quoi, count(*) FROM flux_evenements
 WHERE statut = 'non_relu' AND acteur = 'TED';
SELECT 'flux_evenements' AS quoi, statut, count(*) FROM flux_evenements GROUP BY statut ORDER BY statut;
SELECT 'commentaries' AS quoi, status, count(*) FROM commentaries GROUP BY status ORDER BY status;
SELECT commentary_id, sector_code, status FROM commentaries WHERE commentary_id = 82;
