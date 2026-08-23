-- =====================================================================
-- Examen des autorisations FDA — volet `contexte` — 23.08.2026
--
-- Décisions de N. CASTILLO, session terminale du 23.08.2026, sur les sept
-- autorisations 510(k) notées 2/2 par la doctrine « signal ».
-- Deux promotions décidées (K261121, K262290) : elles NE FIGURENT PAS ici,
-- une promotion exigeant un signal_id issu de la chaîne d'extraction.
-- Ce fichier n'inscrit que les cinq décisions `contexte`, immédiatement
-- exécutables.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO flux_examens (item_id, decision, decide_par, note)
SELECT v.item_id, 'contexte', 'N. Castillo', v.note
FROM (VALUES
  (726, 'Système gastro-intestinal endoluminal Intuitive (K253702). Plateforme robotique complète : lien à la sous-traitance d''usinage réel mais indirect.'),
  (728, 'MONARCH Platform, Auris Health (K260382). Plateforme robotique complète, même raisonnement.'),
  (753, 'Revi System, Bluewind Medical (K253651). Micro-implant actif : intéressant, à confirmer sur pièces avant toute promotion.'),
  (756, 'Powered Aventus Thrombectomy System, Inquis Medical (K261105). Dispositif à dominante cathéter/polymère, éloigné de l''usinage métal.'),
  (758, 'Suture Button Repair System, Skeletal Dynamics (K261770). Implant de fixation, proche de K261121 déjà retenu — non doublé.')
) AS v(item_id, note)
JOIN flux_items fi ON fi.item_id = v.item_id
WHERE NOT EXISTS (SELECT 1 FROM flux_examens x WHERE x.item_id = v.item_id);

COMMIT;

-- V31 : 36 examens au total (21 marchés publics + 10 tirage bas + 5 FDA).
SELECT 'V31' AS verif, decision, count(*) FROM flux_examens GROUP BY decision ORDER BY decision;
