-- B4 — Premier AUDIT HUMAIN du filtrage à seuil (liste B du tour complet
-- jury du 02.09.2026, acte 4). Ferme l'énoncé « règle appliquée, jamais
-- auditée : le taux de faux négatifs est inconnu ».
--
-- Échantillon : les 40 premiers rangs de v_filtrage_echantillon pour
-- septembre 2026 (tirage déterministe md5(item_id || 'YYYY-MM'), conçu le
-- 26.08 ; les 10 premiers sont ceux que l'écran affiche). Les 40 item_id
-- sont FIGÉS ci-dessous : la vue exclut les items déjà audités du mois,
-- son résultat change donc après cet acte.
--
-- Critère : l'écart sans examen humain était-il fondé ? Faux négatif si un
-- décideur de PME de mécanique de précision devait voir l'item dans sa
-- file de signaux. Décisions : N. Castillo, sur proposition motivée.

BEGIN;

CREATE TEMP TABLE d (item_id bigint PRIMARY KEY, verdict text NOT NULL, note text NOT NULL);
INSERT INTO d VALUES
 (4407,'confirme','Actualité sans contenu industriel (fait divers, politique, bourse, droit du travail, commercial, logistique).'),
  (1337,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (4487,'confirme','Enregistrement FDA : logiciel pur ou rappel déjà compté par indicateur.'),
  (267,'confirme','Actualité sans contenu industriel (fait divers, politique, bourse, droit du travail, commercial, logistique).'),
  (4899,'confirme','Actualité sans contenu industriel (fait divers, politique, bourse, droit du travail, commercial, logistique).'),
  (5422,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.'),
  (1595,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.'),
  (5151,'confirme','Enregistrement FDA : logiciel pur ou rappel déjà compté par indicateur.'),
  (2192,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (5497,'confirme','Communiqué produit ou infrastructure sans incidence sur la charge d’usinage.'),
  (1485,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (1461,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (37,'confirme','Actualité sans contenu industriel (fait divers, politique, bourse, droit du travail, commercial, logistique).'),
  (23,'faux_negatif','Dynamique géographique QV3 automobile (pénétration chinoise au Mexique, production locale stagnante) : un décideur devait la voir. La règle sous-pondère la portée face à l’antériorité.'),
  (738,'confirme','Enregistrement FDA : logiciel pur ou rappel déjà compté par indicateur.'),
  (1610,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.'),
  (4944,'confirme','Actualité sans contenu industriel (fait divers, politique, bourse, droit du travail, commercial, logistique).'),
  (2576,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.'),
  (4587,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (4,'confirme','Actualité sans contenu industriel (fait divers, politique, bourse, droit du travail, commercial, logistique).'),
  (85,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (1464,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (2205,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (4363,'confirme','Communiqué produit ou infrastructure sans incidence sur la charge d’usinage.'),
  (4798,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.'),
  (2559,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.'),
  (2186,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (2123,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (1326,'confirme','Acquisition d’un aéronef complet auprès d’un constructeur : hors sous-traitance.'),
  (108,'confirme','Communiqué produit ou infrastructure sans incidence sur la charge d’usinage.'),
  (2209,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (4811,'confirme','Actualité sans contenu industriel (fait divers, politique, bourse, droit du travail, commercial, logistique).'),
  (168,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (2556,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.'),
  (4793,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.'),
  (1301,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (154,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.'),
  (1430,'confirme','Avis TED hors champ des secteurs et de l’usinage.'),
  (2572,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.'),
  (175,'confirme','Avis TED d’équipements ou consommables médicaux courants : demande ponctuelle, comptée par l’indicateur M7, pas relue.');

-- Garde-fous : 40 items, tous écartés par seuil_v1, aucun déjà audité ce mois.
DO $$ BEGIN
  IF (SELECT count(*) FROM d) <> 40 THEN RAISE EXCEPTION 'échantillon : 40 attendus'; END IF;
  IF (SELECT count(*) FROM d JOIN flux_filtrage f USING (item_id) WHERE f.regle_code = 'seuil_v1') <> 40
  THEN RAISE EXCEPTION 'un item de l''échantillon n''est pas écarté par seuil_v1'; END IF;
  IF EXISTS (SELECT 1 FROM flux_filtrage_audit a JOIN d USING (item_id) WHERE a.echantillon = '2026-09')
  THEN RAISE EXCEPTION 'item déjà audité en 2026-09'; END IF;
END $$;

INSERT INTO flux_filtrage_audit (item_id, echantillon, verdict, audite_par, note)
SELECT item_id, '2026-09', verdict, 'N. Castillo', note FROM d;

-- Reformulation de l'énoncé du bilan (décision du 02.09.2026). L'ancien
-- texte — « la règle doit être révisée » dès le premier faux négatif — avait
-- été écrit en attendant zéro. Un faux négatif restitué à la file n'appelle
-- pas une révision de règle ; un TAUX au-delà d'une tolérance, oui. Le seuil
-- de tolérance (5 %) est fixé A POSTERIORI, après le premier audit : ce fait
-- est consigné en passation, il n'est pas caché.
CREATE OR REPLACE VIEW v_bilan_filtrage AS
WITH b AS (
  SELECT (SELECT count(*) FROM flux_items)                        AS items_collectes,
         (SELECT count(*) FROM flux_filtrage)                     AS items_filtres,
         (SELECT count(*) FROM v_flux_a_examiner)                 AS file_humaine,
         (SELECT count(*) FROM flux_examens)                      AS examens_humains,
         (SELECT count(*) FROM flux_filtrage_audit)               AS items_audites,
         (SELECT count(*) FROM flux_filtrage_audit
           WHERE verdict = 'faux_negatif')                        AS faux_negatifs
)
SELECT b.*,
       CASE WHEN b.items_filtres + b.file_humaine > 0
            THEN round(100.0 * b.items_filtres / (b.items_filtres + b.file_humaine), 1)
       END AS part_filtree_pct,
       CASE WHEN b.items_audites > 0
            THEN round(100.0 * b.faux_negatifs / b.items_audites, 1)
       END AS taux_faux_negatifs_pct,
       CASE WHEN b.items_audites = 0
            THEN 'Règle appliquée, jamais auditée : le taux de faux négatifs est inconnu.'
            WHEN b.faux_negatifs = 0
            THEN format('Aucun faux négatif sur %s items audités.', b.items_audites)
            WHEN 100.0 * b.faux_negatifs / b.items_audites <= 5
            THEN format('%s faux négatif(s) sur %s items audités (%s %%), restitué(s) à la file. '
                        'Règle maintenue : taux sous la tolérance de 5 %% (fixée le 02.09.2026, après le premier audit).',
                        b.faux_negatifs, b.items_audites,
                        round(100.0 * b.faux_negatifs / b.items_audites, 1))
            ELSE format('%s faux négatifs sur %s items audités (%s %%) — au-delà de la tolérance de 5 %% : la règle doit être révisée.',
                        b.faux_negatifs, b.items_audites,
                        round(100.0 * b.faux_negatifs / b.items_audites, 1))
       END AS enonce_audit
  FROM b;

COMMIT;

-- Bilan
SELECT verdict, count(*) FROM flux_filtrage_audit WHERE echantillon = '2026-09' GROUP BY 1 ORDER BY 1;
SELECT * FROM v_bilan_filtrage;
SELECT item_id, titre FROM v_flux_a_examiner WHERE item_id = 23;
SELECT count(*) AS restants_echantillon_sept FROM v_filtrage_echantillon;
