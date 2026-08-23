-- =====================================================================
-- Lecture décisionnelle des appels d'offres — 24.08.2026
--
-- OÙ L'IA SERT VRAIMENT, ET POURQUOI ICI. Le dispositif compte 77 appels
-- d'offres ouverts. Un dirigeant de PME n'en lira pas 77. La question qui
-- décide n'est pas « de quoi parle cet avis » — le CPV le dit déjà — mais
-- « EST-CE QUE JE PEUX LE FAIRE, ET QUE DOIS-JE FAIRE MAINTENANT ».
--
-- C'est une tâche de jugement contraint sur un texte court, réversible
-- (un avis mal classé se rattrape, il ne corrompt aucune série) et
-- vérifiable ligne à ligne contre l'avis officiel. Les trois conditions
-- qui, selon le § 9.4.2 et la doctrine de l'étage 2, autorisent un modèle
-- unique et économique.
--
-- CE QUE LA LECTURE N'EST PAS : une décision. Elle ne modifie aucun statut,
-- ne promeut rien, n'écarte rien. Elle ORDONNE et PRÉPARE — le dirigeant
-- garde la main, et l'écran affiche toujours l'avis officiel à un clic.
--
-- MESURABILITÉ : comme le triage, la lecture est confrontable au jugement
-- humain (v_lecture_a_echantillonner). Un taux non mesuré n'est pas un
-- taux.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS ted_lecture_ia (
    lecture_id      BIGSERIAL PRIMARY KEY,
    publication_number TEXT NOT NULL REFERENCES ted_avis(publication_number),
    modele          TEXT NOT NULL,
    adressable      SMALLINT NOT NULL CHECK (adressable BETWEEN 0 AND 2),
    piece_concernee TEXT,     -- ce qui serait à produire, en clair
    action_proposee TEXT,     -- le geste concret, pas un conseil général
    justification   TEXT,
    horodatage      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (publication_number, modele)
);

COMMENT ON TABLE ted_lecture_ia IS
  'Lecture décisionnelle des appels d''offres ouverts par un modèle unique. « adressable » : 0 = hors du savoir-faire d''un usineur de précision, 1 = périphérique, 2 = cœur de métier. Ce n''est PAS une décision : aucun statut n''est modifié, l''avis officiel reste à un clic. Confrontable au jugement humain, donc mesurable.';

-- ---------------------------------------------------------------------
-- LA VUE QUI DÉCLENCHE L'ACTION. Un appel ouvert, adressable, avec son
-- échéance, son interlocuteur, et le fait de savoir si l'acheteur est un
-- habitué. Tout ce qu'il faut pour agir, sur une ligne.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_actions AS
SELECT a.publication_number, a.sector_code, a.titre, a.url,
       a.acheteur, a.acheteur_pays, a.acheteur_ville,
       a.acheteur_courriel, a.acheteur_site,
       a.valeur_estimee, a.devise, a.cpv, a.nature_contrat,
       a.date_publication, a.date_limite,
       (a.date_limite - CURRENT_DATE) AS jours_restants,
       CASE WHEN a.date_limite - CURRENT_DATE <= 7  THEN 'urgent'
            WHEN a.date_limite - CURRENT_DATE <= 21 THEN 'proche'
            ELSE 'confortable' END AS urgence,
       l.adressable, l.piece_concernee, l.action_proposee, l.justification, l.modele,
       r.avis_publies      AS acheteur_avis_publies,
       r.dont_encore_ouverts AS acheteur_appels_ouverts,
       (r.acheteur IS NOT NULL) AS acheteur_recurrent,
       EXISTS (SELECT 1 FROM flux_examens e
                 JOIN flux_items fi ON fi.item_id = e.item_id
                WHERE fi.titre LIKE '[TED ' || a.publication_number || ']%') AS deja_examine
FROM ted_avis a
LEFT JOIN ted_lecture_ia l ON l.publication_number = a.publication_number
LEFT JOIN v_acheteurs_recurrents r ON r.acheteur = a.acheteur
                                  AND r.sector_code IS NOT DISTINCT FROM a.sector_code
WHERE a.est_appel_ouvert
  AND a.date_limite IS NOT NULL
  AND a.date_limite >= CURRENT_DATE
ORDER BY l.adressable DESC NULLS LAST, (a.date_limite - CURRENT_DATE) ASC;

COMMENT ON VIEW v_actions IS
  'Les appels d''offres sur lesquels un dirigeant peut encore agir : ouverts, non expirés, avec échéance, interlocuteur et lecture d''adressabilité. Triés par adressabilité puis par urgence — ce qui est faisable et qui expire bientôt vient en premier.';

-- Mesure de la lecture, sur le modèle de v_triage_a_echantillonner.
CREATE OR REPLACE VIEW v_lecture_a_echantillonner AS
SELECT l.adressable, e.decision, count(*) AS n
FROM ted_lecture_ia l
JOIN flux_items fi ON fi.titre LIKE '[TED ' || l.publication_number || ']%'
JOIN flux_examens e ON e.item_id = fi.item_id
GROUP BY l.adressable, e.decision ORDER BY l.adressable DESC, e.decision;

COMMIT;

SELECT 'V49' AS verif,
       (SELECT count(*) FROM v_actions) AS appels_actionnables,
       (SELECT count(*) FROM ted_lecture_ia) AS lectures_faites;
