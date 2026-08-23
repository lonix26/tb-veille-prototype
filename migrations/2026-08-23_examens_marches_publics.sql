-- =====================================================================
-- Examen humain des avis de marchés publics — 23.08.2026
--
-- DÉCISION DE N. CASTILLO, prise en session terminale le 23.08.2026 sur
-- les vingt et un avis notés en pertinence 2 par le triage. Le regroupement
-- en quatre familles a été PROPOSÉ par l'assistant et VALIDÉ tel quel par
-- l'étudiant ; la décision est la sienne, l'exécution est celle du script.
-- `decide_par` porte le nom du décideur, jamais celui de l'exécutant.
--
-- CRITÈRE APPLIQUÉ, unique et explicite : l'avis appelle-t-il de la
-- SOUS-TRAITANCE DE PIÈCES USINÉES, ou l'acquisition d'un appareil complet ?
-- Une PME de mécanique de précision fournit des pièces ; elle ne vend ni
-- drone ni hélicoptère. C'est ce critère, et non la pertinence sectorielle,
-- qui sépare une opportunité d'une actualité.
--
-- AUCUN AVIS N'EST PROMU EN SIGNAL ici : la promotion exige un signal_id,
-- donc l'extraction à trois modèles (chaîne signals, extraits obligatoires).
-- La décision `contexte` suffit à faire figurer un avis à l'écran
-- « Opportunités » — l'écran présente des pistes vérifiables, pas des
-- signaux validés, et la distinction est tenue.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO flux_examens (item_id, decision, decide_par, note)
SELECT v.item_id, v.decision, 'N. Castillo', v.note
FROM (VALUES
  -- ---- Groupe A — pièces détachées d'aéronefs : le métier même -------------
  (69,   'contexte', 'Pièces détachées pour aéronefs (Pologne). Marché de pièces : sous-traitance d''usinage directement adressable.'),
  (62,   'contexte', 'Pièces détachées aéronefs, spationefs et hélicoptères (Portugal, système UH-60). Marché de pièces.'),
  (1331, 'contexte', 'Pièces détachées pour aéronefs (Allemagne). Marché de pièces.'),
  (1325, 'contexte', 'Pièces détachées pour aéronefs (Allemagne, composant AFCS). Marché de pièces, composant de précision.'),
  (1324, 'contexte', 'Pièces détachées pour aéronefs (Allemagne, ZF). Marché de pièces.'),
  (1292, 'contexte', 'Pièces détachées aéronefs et spationefs (Allemagne, caméras stellaires haute précision). Composant de très haute précision, au coeur du savoir-faire.'),

  -- ---- Groupe B — implants et prothèses : second marché de la PME ----------
  (161,  'contexte', 'Implants chirurgicaux (Espagne, accord-cadre). Usinage de précision médical.'),
  (1631, 'contexte', 'Implants et endoprothèses orthopédiques (Pologne). Usinage de précision médical.'),
  (1625, 'contexte', 'Prothèses et dispositifs médicaux orthopédiques (France). Usinage de précision médical.'),
  (1626, 'contexte', 'Endoprothèses et articulations artificielles (Pologne). Usinage de précision médical.'),

  -- ---- Groupe C — composant spatial ----------------------------------------
  (65,   'contexte', 'Projet satellitaire, fourniture de cellules solaires et conseil (Allemagne). Fourniture de composants pour programme spatial.'),

  -- ---- Groupe D — appareils complets : écartés, motif unique ---------------
  (67,   'ecarte',   'Acquisition d''un aéronef sans pilote complet (Lettonie, police municipale de Jelgava). Aucune sous-traitance de pièces à la clé.'),
  (66,   'ecarte',   'Acquisition d''aéronefs sans pilote complets (Italie, génie militaire). Appareil complet.'),
  (63,   'ecarte',   'Acquisition d''un aéronef sans pilote complet (Lituanie). Appareil complet.'),
  (64,   'ecarte',   'Acquisition d''un drone complet (Pologne). Appareil complet.'),
  (1346, 'ecarte',   'Accord-cadre véhicules aériens sans pilote (Suède). Appareils complets.'),
  (1333, 'ecarte',   'Système de drone multisenseur complet (Pologne). Appareil complet.'),
  (1340, 'ecarte',   'Fourniture d''hélicoptères multifonctions moyens/lourds (Roumanie). Appareil complet.'),
  (1335, 'ecarte',   'Fourniture de deux hélicoptères AW139 (Italie). Appareil complet.'),
  (1316, 'ecarte',   'Technique hélicoptère, appareils moyens-lourds (Slovaquie). Appareil complet.'),
  (1306, 'ecarte',   'Fourniture d''hélicoptères multifonctions (Roumanie). Appareil complet.')
) AS v(item_id, decision, note)
JOIN flux_items fi ON fi.item_id = v.item_id
WHERE NOT EXISTS (SELECT 1 FROM flux_examens x WHERE x.item_id = v.item_id);

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V25 : 21 examens inscrits, 11 en `contexte` et 10 en `ecarte`, tous
--         nominatifs et datés.
--   V26 : la file d'examen a diminué d'exactement 21.
--   V27 : l'écran « Opportunités » compte 11 lignes — les `contexte`
--         seulement ; les `ecarte` n'y figurent pas, par construction.
-- ---------------------------------------------------------------------

SELECT 'V25' AS verif, decision, count(*), string_agg(DISTINCT decide_par, ',') AS par,
       min(decide_le)::date AS le
FROM flux_examens GROUP BY decision ORDER BY decision;

SELECT 'V26' AS verif,
       (SELECT count(*) FROM flux_items) AS items_total,
       (SELECT count(*) FROM flux_examens) AS examines,
       (SELECT count(*) FROM v_flux_a_examiner) AS restant_a_examiner;

SELECT 'V27' AS verif, fs.sector_code, count(*) AS lignes_opportunites
FROM flux_examens e
JOIN flux_items fi ON fi.item_id = e.item_id
JOIN flux_sources fs ON fs.flux_id = fi.flux_id
WHERE fs.famille = 'marches_publics' AND e.decision IN ('promu_signal','contexte')
GROUP BY fs.sector_code ORDER BY fs.sector_code;
