-- =====================================================================
-- 02.09.2026 — Liste B, acte 2 : relecture humaine des textes de modèle
-- servis à l'écran — 5 commentaires exécutifs (run 199) et 13 lectures
-- transversales (runs 194 et 200). Contrôle préalable : chaque nombre des
-- commentaires retrouvé dans sa charge d'entrée (91/91) ; références [Fn]
-- des lectures confrontées aux faits joints. Décisions de l'étudiant.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

-- Commentaires exécutifs -----------------------------------------------
UPDATE commentaries SET status='valide', validated_by='N. Castillo', validated_at=now(),
  motif = CASE commentary_id
    WHEN 85 THEN 'Chiffres exacts (19/19 retrouvés dans la charge), neutralisations conformes aux seuils.'
    WHEN 86 THEN 'Chiffres exacts (23/23). Remarque : compare les niveaux de deux indices (A6 91,6 / A5 106,6), admissible à base Eurostat commune.'
    WHEN 88 THEN 'Chiffres exacts (19/19). « M3 : un seul point » était vrai au run 199, avant A8.'
    WHEN 89 THEN 'Chiffres exacts (9/9). « Série semestrielle » pour T4 reprend le libellé de la charge, corrigé depuis (A8) : pas une faute du modèle.'
  END
 WHERE commentary_id IN (85,86,88,89) AND status='a_valider';

UPDATE commentaries SET status='rejete', validated_by='N. Castillo', validated_at=now(),
  motif = 'Affirmation contredite par la charge : § 2 « les reculs d''emploi et d''établissements » alors que H11 (établissements) est à +0,44 %, ce que le § 5 du même texte énonce. Chiffres par ailleurs exacts (21/21).'
 WHERE commentary_id = 87 AND status='a_valider';

-- Lectures transversales -----------------------------------------------
ALTER TABLE lectures_transversales ADD COLUMN IF NOT EXISTS motif text;
COMMENT ON COLUMN lectures_transversales.motif IS
  'Motif de la décision humaine, obligatoire dès qu''une décision est posée (02.09.2026).';

UPDATE lectures_transversales SET statut='valide', validated_by='N. Castillo', validated_at=now(),
  motif = CASE lecture_id
    WHEN 12 THEN 'Chaque affirmation portée par un fait joint. L''incident « chiffre étranger » consigné par le pipeline est un faux positif : le « 20 » de « G20 ».'
    ELSE 'Chaque affirmation portée par un fait joint ; sens et signes corrects.'
  END
 WHERE lecture_id IN (1,2,4,8,9,12,13) AND statut='a_valider';

CREATE TEMP TABLE r (lecture_id int, motif text);
INSERT INTO r VALUES
 (3,'Référence invérifiable : [F7] cité dans l''hypothèse, absent des faits joints.'),
 (7,'Référence invérifiable : [F29] cité dans l''hypothèse, absent des faits joints.'),
 (11,'Références invérifiables : [F59] et [F60] cités, absents des faits joints ; « intensité réglementaire très élevée » sans base de comparaison.'),
 (5,'Affirmation non fondée : « les investissements annoncés progressent [F58] » — F58 est un dénombrement d''un seul mois (34 événements), qui ne fonde aucune progression.'),
 (6,'Affirmation contredite : « flux d''investissements les plus nourris de tous les secteurs [F39] » — 29 en aérospatial contre 34 en médical le même mois (F58 de la lecture 5, même run).'),
 (10,'Affirmation invérifiable : « presse professionnelle dominée par des annonces d''investissement [F39] » — un seul type dénombré, la dominance ne se lit pas dans les faits cités.');
UPDATE lectures_transversales l SET statut='rejete', validated_by='N. Castillo', validated_at=now(), motif=r.motif
  FROM r WHERE l.lecture_id=r.lecture_id AND l.statut='a_valider';

-- Contrôles
SELECT 'commentaires' AS t, status AS etat, count(*) FROM commentaries WHERE commentary_id BETWEEN 85 AND 89 GROUP BY 2
UNION ALL SELECT 'lectures', statut, count(*) FROM lectures_transversales GROUP BY 2 ORDER BY 1,2;
SELECT count(*) AS sans_motif FROM lectures_transversales WHERE statut<>'a_valider' AND motif IS NULL;
SELECT status, count(*) FROM commentaries GROUP BY 1 ORDER BY 1;
COMMIT;
