-- =====================================================================
-- 2026-09-02 — A9 : LE COURRIEL DES ACHETEURS TED SORT DE LA RESTITUTION
--
-- CONSTAT (tour « jury », DOC-8) : 1 284 avis TED portent un courriel de
-- contact, dont 442 de forme prenom.nom@ — des adresses nominatives. Elles
-- étaient servies telles quelles par l'API (`v_actions`, `v_acheteurs_
-- recurrents` → /veille/actions) et affichées en lien « Écrire à
-- l'acheteur », sans que rien ne le dise.
--
-- CE QUI EST FAIT. Le courriel reste dans `ted_avis` (c'est le contenu de
-- l'avis public, pièce d'audit E6 : on ne retouche pas une pièce) mais il
-- ne sort plus par les vues de restitution. L'écran renvoie à l'avis
-- lui-même (« Ouvrir l'avis »), où le contact figure, publié par TED pour
-- cet usage — le dispositif n'a pas à le redistribuer.
--
-- EFFET DE BORD ASSUMÉ : `v_acheteurs_recurrents` groupait aussi par
-- courriel — un même organisme avec deux contacts comptait pour deux
-- lignes (205 lignes pour 187 organismes distincts). Le groupement par
-- (acheteur, pays, site, secteur) fusionne ces doublons ; le seuil
-- « au moins deux avis » peut désormais retenir un organisme dont les avis
-- portaient des contacts différents. Décomptes avant/après en sortie.
--
-- Les deux vues sont recréées (DROP + CREATE : une colonne ne se retire
-- pas par CREATE OR REPLACE). Aucune autre vue ne dépend d'elles ;
-- l'API sérialise la vue entière et suit sans republication.
-- =====================================================================
\set ON_ERROR_STOP on

\echo '== avant'
SELECT (SELECT count(*) FROM v_acheteurs_recurrents) AS acheteurs_recurrents,
       (SELECT count(*) FROM v_actions) AS actions,
       (SELECT count(*) FILTER (WHERE acheteur_recurrent) FROM v_actions) AS actions_recurrentes,
       (SELECT count(*) FILTER (WHERE acheteur_courriel IS NOT NULL) FROM v_actions) AS actions_avec_courriel;

BEGIN;

DROP VIEW v_actions;
DROP VIEW v_acheteurs_recurrents;

CREATE VIEW v_acheteurs_recurrents AS
 SELECT acheteur,
    acheteur_pays,
    acheteur_site,
    sector_code,
    count(*) AS avis_publies,
    count(*) FILTER (WHERE est_appel_ouvert) AS dont_appels,
    count(*) FILTER (WHERE NOT est_appel_ouvert) AS dont_attributions,
    count(*) FILTER (WHERE date_limite >= CURRENT_DATE) AS dont_encore_ouverts,
    min(date_publication) AS premier_avis,
    max(date_publication) AS dernier_avis,
    sum(valeur_estimee) FILTER (WHERE devise = 'EUR'::text) AS valeur_eur_connue,
    ( SELECT array_agg(DISTINCT c.c ORDER BY c.c) AS array_agg
           FROM ted_avis b,
            LATERAL unnest(b.cpv) c(c)
          WHERE b.acheteur = a.acheteur AND NOT b.sector_code IS DISTINCT FROM a.sector_code) AS cpv_distincts
   FROM ted_avis a
  WHERE acheteur IS NOT NULL
  GROUP BY acheteur, acheteur_pays, acheteur_site, sector_code
 HAVING count(*) >= 2
  ORDER BY (count(*)) DESC, (max(date_publication)) DESC;

COMMENT ON VIEW v_acheteurs_recurrents IS
'Acheteurs publics ayant publié au moins deux avis sur la période. Un acheteur récurrent est un compte à démarcher, pas un événement. Corrigé le 24.08.2026 : la jointure LATERAL sur les CPV multipliait le décompte des avis. Le 02.09.2026 (A9) : le courriel de contact ne sort plus par cette vue (il reste dans ted_avis, pièce d''audit) et n''entre plus dans le groupement — un organisme à deux contacts comptait pour deux lignes.';

CREATE VIEW v_actions AS
 WITH recurrence AS (
         SELECT v_acheteurs_recurrents.acheteur,
            sum(v_acheteurs_recurrents.avis_publies) AS avis_publies,
            sum(v_acheteurs_recurrents.dont_encore_ouverts) AS dont_encore_ouverts
           FROM v_acheteurs_recurrents
          GROUP BY v_acheteurs_recurrents.acheteur
        )
 SELECT a.publication_number,
    a.sector_code,
    a.titre,
    a.url,
    a.acheteur,
    a.acheteur_pays,
    a.acheteur_ville,
    a.acheteur_site,
    a.valeur_estimee,
    a.devise,
    a.cpv,
    a.nature_contrat,
    a.date_publication,
    a.date_limite,
    a.date_limite - CURRENT_DATE AS jours_restants,
        CASE
            WHEN (a.date_limite - CURRENT_DATE) <= 7 THEN 'urgent'::text
            WHEN (a.date_limite - CURRENT_DATE) <= 21 THEN 'proche'::text
            ELSE 'confortable'::text
        END AS urgence,
    l.adressable,
    l.piece_concernee,
    l.action_proposee,
    l.justification,
    l.modele,
    l.statut AS lecture_statut,
    l.valide_par AS lecture_valide_par,
    r.avis_publies AS acheteur_avis_publies,
    r.dont_encore_ouverts AS acheteur_appels_ouverts,
    r.acheteur IS NOT NULL AS acheteur_recurrent
   FROM ted_avis a
     LEFT JOIN ted_lecture_ia l ON l.publication_number = a.publication_number AND l.profil = 'A_metier_declare'::text
     LEFT JOIN recurrence r ON r.acheteur = a.acheteur
  WHERE a.est_appel_ouvert AND a.date_limite IS NOT NULL AND a.date_limite >= CURRENT_DATE;

COMMENT ON VIEW v_actions IS
'Appels d''offres encore ouverts, avec la lecture d''adressabilité du modèle et SON STATUT de relecture (lecture_statut, ajouté le 02.09.2026). Servie par l''API veille/actions ; l''écran badge toute lecture non relue. Depuis le 02.09.2026 (A9), sans le courriel de contact de l''acheteur : il est dans l''avis TED (colonne url), publié pour cet usage, et n''a pas à être redistribué par le dispositif.';

COMMIT;

\echo '== après'
SELECT (SELECT count(*) FROM v_acheteurs_recurrents) AS acheteurs_recurrents,
       (SELECT count(*) FROM v_actions) AS actions,
       (SELECT count(*) FILTER (WHERE acheteur_recurrent) FROM v_actions) AS actions_recurrentes;
\echo '== aucune colonne de courriel dans les vues'
SELECT table_name, column_name FROM information_schema.columns
 WHERE table_schema = 'public' AND column_name ~ 'courriel|mail'
   AND table_name IN (SELECT viewname FROM pg_views WHERE schemaname = 'public');
