-- =====================================================================
-- Migration du 23.08.2026 — seconde doctrine de triage : antériorité et portée
--
-- CONSTAT QUI MOTIVE CE CHANTIER (session du 23.08, sur pièces) :
-- la première doctrine de triage note la PERTINENCE — « événement
-- susceptible d'affecter la demande, la réglementation ou la structure ».
-- Sur les dix premiers items notés 2, sept étaient des avis d'achat
-- individuels (dont un drone pour une police municipale) et deux étaient
-- deux dépêches sur le MÊME chiffre d'exportations horlogères de juillet,
-- c'est-à-dire l'indicateur H1 revenant par la presse.
--
-- Un signal faible est fragmentaire, ambigu et périphérique : une consigne
-- qui récompense la nouvelle claire et bien cadrée le pénalise par
-- construction. Le défaut n'est pas dans le modèle, il est dans la question
-- qu'on lui pose.
--
-- CE QUE CETTE MIGRATION AJOUTE — deux axes indépendants de la pertinence :
--   * anteriorite : l'item devance-t-il la statistique officielle, ou la
--     relaie-t-il ? C'est la question qui sépare la veille anticipative de
--     la revue de presse.
--   * portee : si l'information se confirmait, changerait-elle quelque chose
--     pour une PME suisse de mécanique de précision ?
--
-- Un signal faible se reconnaît à une ANTÉRIORITÉ haute avec une portée non
-- nulle — et souvent une pertinence BASSE, puisqu'il n'a pas encore la forme
-- d'un événement. C'est pourquoi les axes sont séparés et non fusionnés en
-- un score unique : les additionner masquerait exactement ce qu'on cherche.
--
-- MÉTHODE : la seconde doctrine est appliquée au MÊME corpus que la
-- première. L'écart entre les deux passes est une mesure — quels items la
-- doctrine « événement » a-t-elle manqués — et non une simple correction.
-- Les scores de la première passe sont CONSERVÉS : on ne réécrit pas
-- l'histoire d'une mesure.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE flux_triage_ia ADD COLUMN IF NOT EXISTS doctrine TEXT NOT NULL DEFAULT 'evenement'
    CHECK (doctrine IN ('evenement','signal'));
ALTER TABLE flux_triage_ia ADD COLUMN IF NOT EXISTS anteriorite SMALLINT
    CHECK (anteriorite BETWEEN 0 AND 2);
ALTER TABLE flux_triage_ia ADD COLUMN IF NOT EXISTS portee SMALLINT
    CHECK (portee BETWEEN 0 AND 2);

COMMENT ON COLUMN flux_triage_ia.doctrine IS
  'Doctrine de triage appliquée. « evenement » : première passe du 22-23.08, score de pertinence seul. « signal » : seconde passe du 23.08, qui score en plus l''antériorité et la portée. Les deux coexistent sur le même corpus — l''écart entre elles est une mesure, pas une correction.';
COMMENT ON COLUMN flux_triage_ia.anteriorite IS
  '0 = relaie une information déjà publiée par la statistique officielle (revue de presse) ; 1 = simultané ou non encore statistique ; 2 = en amont, ne figurera dans aucune statistique avant plusieurs mois. C''est l''axe qui sépare la veille anticipative de la revue de presse.';
COMMENT ON COLUMN flux_triage_ia.portee IS
  'Si l''information se confirmait, changerait-elle quelque chose pour une PME suisse de mécanique de précision sous-traitante ? 0 = non ; 1 = indirectement ; 2 = directement (charge d''usinage, matière, accès au marché, exigence technique).';

-- La clé d'unicité doit distinguer les doctrines, sinon la seconde passe
-- est rejetée comme doublon de la première.
ALTER TABLE flux_triage_ia DROP CONSTRAINT IF EXISTS flux_triage_ia_item_id_modele_key;
ALTER TABLE flux_triage_ia ADD CONSTRAINT flux_triage_ia_item_modele_doctrine_key
    UNIQUE (item_id, modele, doctrine);

-- ---------------------------------------------------------------------
-- File de lecture des signaux faibles — distincte de v_flux_a_examiner.
-- Tri par antériorité D'ABORD : c'est le renversement de doctrine rendu
-- opérationnel. Un item très antérieur et peu « pertinent » remonte ici,
-- alors qu'il coulait dans la file événementielle.
-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW v_signaux_faibles AS
SELECT fi.item_id, fs.famille, fs.libelle AS flux, t.sector_code, t.watch_question_code,
       t.anteriorite, t.portee, t.pertinence AS pertinence_doctrine_signal,
       e.pertinence AS pertinence_doctrine_evenement,
       t.resume, t.justification, fi.titre, fi.url, fi.date_publication
FROM flux_items fi
JOIN flux_sources fs ON fs.flux_id = fi.flux_id
JOIN flux_triage_ia t ON t.item_id = fi.item_id AND t.doctrine = 'signal'
LEFT JOIN flux_triage_ia e ON e.item_id = fi.item_id AND e.doctrine = 'evenement'
WHERE NOT EXISTS (SELECT 1 FROM flux_examens x WHERE x.item_id = fi.item_id)
  AND t.anteriorite >= 1 AND t.portee >= 1
ORDER BY t.anteriorite DESC, t.portee DESC, fi.date_publication DESC;

COMMENT ON VIEW v_signaux_faibles IS
  'File de lecture des signaux faibles : items que la seconde doctrine juge antérieurs à la statistique ET porteurs pour une PME de mécanique de précision. Volontairement SANS filtre de pertinence — un signal faible n''a pas encore la forme d''un événement, et l''exiger reviendrait à le manquer. La colonne pertinence_doctrine_evenement montre ce que la première passe en avait fait.';

-- ---------------------------------------------------------------------
-- Écart entre les deux doctrines — la mesure du chantier.
-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW v_ecart_doctrines AS
SELECT e.pertinence AS pertinence_evenement,
       t.anteriorite, t.portee,
       COUNT(*) AS n
FROM flux_triage_ia e
JOIN flux_triage_ia t ON t.item_id = e.item_id
WHERE e.doctrine = 'evenement' AND t.doctrine = 'signal'
GROUP BY 1,2,3
ORDER BY 1,2,3;

COMMENT ON VIEW v_ecart_doctrines IS
  'Croisement des deux doctrines sur le même corpus. La case qui compte : pertinence_evenement = 0 avec anteriorite = 2 — les items que la doctrine événementielle a jetés et que la doctrine signal remonte. S''ils existent, la critique du 23.08 est démontrée ; s''ils sont absents, elle est infirmée. Dans les deux cas, c''est un résultat.';

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V11 : les 286 scores existants portent doctrine = 'evenement' et
--         anteriorite/portee à NULL (la première passe ne les mesurait pas).
--   V12 : v_signaux_faibles rend 0 ligne tant que la seconde passe n'a
--         pas tourné — attendu, pas défaut.
-- ---------------------------------------------------------------------

SELECT 'V11' AS verif, doctrine, COUNT(*) AS scores,
       COUNT(anteriorite) AS avec_anteriorite
FROM flux_triage_ia GROUP BY doctrine;

SELECT 'V12' AS verif, COUNT(*) AS lignes_signaux_faibles FROM v_signaux_faibles;
