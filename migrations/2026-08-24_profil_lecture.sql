-- ============================================================================
-- Sensibilité au profil métier — préparation du schéma, 24.08.2026
--
-- Le profil métier de lecture_decision_ted.py décide de tout : il a motivé
-- 74 des 77 exclusions du 24.08, et il n'est pas ratifié. Plutôt que de
-- demander une ratification à l'aveugle, on MESURE sa sensibilité : plusieurs
-- profils lisent le même corpus, et l'écart entre leurs verdicts est un
-- résultat. C'est la doctrine du § 10.5 appliquée à une hypothèse interne —
-- substituer une mesure à une affirmation.
--
-- PIÈGE ÉVITÉ ICI : v_actions joint ted_lecture_ia sans filtre. Semer un
-- second profil sans ancrer la vue dupliquerait chaque appel à l'écran — le
-- défaut exact qui avait doublé v_flux_a_examiner le 23.08.
-- ============================================================================

BEGIN;

ALTER TABLE ted_lecture_ia
  ADD COLUMN IF NOT EXISTS profil text NOT NULL DEFAULT 'A_metier_declare';

COMMENT ON COLUMN ted_lecture_ia.profil IS
  'Profil métier ayant produit la lecture. A_metier_declare est le profil de '
  'référence, seul servi à la restitution ; les autres n''existent que pour la '
  'mesure de sensibilité et ne doivent jamais atteindre un écran.';

-- La lecture est identifiée par le triplet, non plus par le couple.
ALTER TABLE ted_lecture_ia DROP CONSTRAINT IF EXISTS ted_lecture_ia_publication_number_modele_key;
DROP INDEX IF EXISTS ted_lecture_ia_publication_number_modele_key;
CREATE UNIQUE INDEX IF NOT EXISTS ted_lecture_ia_cle
  ON ted_lecture_ia (publication_number, modele, profil);

COMMIT;

-- ---------------------------------------------------------------------------
-- v_actions ancrée sur le profil de référence.
-- ---------------------------------------------------------------------------
BEGIN;

DROP VIEW IF EXISTS v_actions;

CREATE VIEW v_actions AS
WITH recurrence AS (
  SELECT acheteur, sum(avis_publies) AS avis_publies,
         sum(dont_encore_ouverts) AS dont_encore_ouverts
  FROM v_acheteurs_recurrents GROUP BY acheteur
)
SELECT a.publication_number, a.sector_code, a.titre, a.url,
       a.acheteur, a.acheteur_pays, a.acheteur_ville, a.acheteur_courriel,
       a.acheteur_site, a.valeur_estimee, a.devise, a.cpv, a.nature_contrat,
       a.date_publication, a.date_limite,
       a.date_limite - CURRENT_DATE AS jours_restants,
       CASE WHEN (a.date_limite - CURRENT_DATE) <= 7  THEN 'urgent'
            WHEN (a.date_limite - CURRENT_DATE) <= 21 THEN 'proche'
            ELSE 'confortable' END AS urgence,
       l.adressable, l.piece_concernee, l.action_proposee, l.justification,
       l.modele,
       r.avis_publies      AS acheteur_avis_publies,
       r.dont_encore_ouverts AS acheteur_appels_ouverts,
       r.acheteur IS NOT NULL AS acheteur_recurrent
FROM ted_avis a
-- Le profil de référence, et lui seul : les lectures de sensibilité restent
-- en base comme pièces de mesure, jamais comme contenu de restitution.
LEFT JOIN ted_lecture_ia l
       ON l.publication_number = a.publication_number
      AND l.profil = 'A_metier_declare'
LEFT JOIN recurrence r ON r.acheteur = a.acheteur
WHERE a.est_appel_ouvert AND a.date_limite IS NOT NULL
  AND a.date_limite >= CURRENT_DATE;

COMMIT;

-- Contrôle de non-régression : le décompte doit être INCHANGÉ (105 / 12).
SELECT count(*) AS appels_ouverts,
       count(*) FILTER (WHERE adressable >= 1) AS adressables,
       count(*) FILTER (WHERE adressable = 2) AS coeur
FROM v_actions;

-- ---------------------------------------------------------------------------
-- Complément : v_lecture_a_echantillonner joignait elle aussi ted_lecture_ia
-- sans filtre. C'est la mesure du triage — trois profils l'auraient triplée.
-- ---------------------------------------------------------------------------
BEGIN;

DROP VIEW IF EXISTS v_lecture_a_echantillonner;

CREATE VIEW v_lecture_a_echantillonner AS
SELECT l.adressable, e.decision, count(*) AS n
FROM ted_lecture_ia l
JOIN flux_items fi ON fi.titre LIKE ('[TED ' || l.publication_number || ']%')
JOIN flux_examens e ON e.item_id = fi.item_id
WHERE l.profil = 'A_metier_declare'   -- la mesure porte sur le profil servi
GROUP BY l.adressable, e.decision
ORDER BY l.adressable DESC, e.decision;

COMMIT;

SELECT 'v_lecture_a_echantillonner' AS vue, count(*) AS lignes, sum(n) AS total
FROM v_lecture_a_echantillonner;
