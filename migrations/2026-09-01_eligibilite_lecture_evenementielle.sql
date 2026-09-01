-- =====================================================================
-- ÉLIGIBILITÉ DES SOURCES À LA LECTURE ÉVÉNEMENTIELLE — 01.09.2026
--
-- CONSTAT. En expliquant le workflow extraction_evenements_flux nœud par
-- nœud, décompte des 690 événements par famille de source :
--   marchés publics (TED)   287  dont 183 « autre », 103 « investissement »
--   actualité (GDELT)       159
--   presse / communications 150
--   réglementaire (FDA)      94  tous « réglementation »
-- 42 % des « événements » sont des avis de marchés publics relus par le
-- modèle ; un appel d'offres devient « investissement » faute de case
-- (ex. « La Tchéquie lance une consultation pour l'acquisition d'un
-- appareil d'électrochirurgie »). Les 94 autorisations FDA 510(k)
-- deviennent chacune un événement alors que M8 les compte déjà. La
-- consigne du modèle commence par « Tu lis des titres d'articles de
-- presse professionnelle » : elle a été écrite pour la presse et
-- appliquée à tout item pertinent porteur d'un secteur. Il n'existait
-- AUCUN critère d'éligibilité de source propre aux événements.
--
-- RÈGLE. Règle de DÉTECTION, donc aux trois conditions :
--   1. DÉCLARÉE : colonne `flux_sources.lecture_evenementielle`,
--      déclaration humaine par source (doctrine admet_negatifs /
--      sens_favorable / geo_reference / periodes_incompletes_source).
--   2. VISIBLE : la colonne est lue par la requête du workflow, par
--      v_evenements_mois et par l'API ; le motif est dans `note`.
--   3. CONSERVATRICE : les 381 événements TED/FDA déjà écrits restent au
--      registre (ajout seul) — ils sont la preuve du constat. Ils ne
--      sont plus servis ; TED et FDA restent collectés, triés, comptés
--      (M7, M8, S7) et présents dans la file d'examen.
-- =====================================================================

\set ON_ERROR_STOP on
\pset footer off

\echo '--- 0. avant : événements par famille'
SELECT f.famille, count(*) AS n FROM flux_evenements e JOIN flux_items i USING (item_id)
  JOIN flux_sources f USING (flux_id) GROUP BY 1 ORDER BY 2 DESC;

ALTER TABLE public.flux_sources
  ADD COLUMN IF NOT EXISTS lecture_evenementielle boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.flux_sources.lecture_evenementielle IS
  'Déclaration humaine (01.09.2026) : la source est-elle éligible à la lecture événementielle par IA (extraction_evenements_flux) ? Vrai pour la presse de branche, les communiqués et l''actualité — les sources pour lesquelles la consigne de lecture a été écrite. Faux pour les enregistrements structurés (marchés publics, réglementaire) : ils sont comptés par des indicateurs (M7, M8, S7) et servis dans la file d''examen, une relecture en « événements » les dénaturait (42 % des événements du 01.09 étaient des avis TED). Sans déclaration, une source n''est pas lue.';

UPDATE public.flux_sources SET lecture_evenementielle = true
 WHERE famille IN ('communications', 'actualite');

UPDATE public.flux_sources
   SET note = note || ' | NON ÉLIGIBLE à la lecture événementielle (01.09.2026) : enregistrement structuré, compté par indicateur et servi dans la file d''examen ; relu comme « événement », un avis ou une autorisation devenait un faux « investissement » ou une redite.'
 WHERE famille IN ('marches_publics', 'reglementaire');

CREATE OR REPLACE VIEW public.v_evenements_mois AS
 SELECT e.sector_code,
    to_char(i.date_publication::timestamp with time zone, 'YYYY-MM') AS mois,
    e.type_evenement,
    e.sens_sous_traitance,
    count(*) AS n,
    count(*) FILTER (WHERE e.statut = 'valide') AS n_valides
   FROM flux_evenements e
     JOIN flux_items i USING (item_id)
     JOIN flux_sources s USING (flux_id)
  WHERE e.statut <> 'rejete' AND s.lecture_evenementielle
  GROUP BY e.sector_code, (to_char(i.date_publication::timestamp with time zone, 'YYYY-MM')), e.type_evenement, e.sens_sous_traitance;
COMMENT ON VIEW public.v_evenements_mois IS
  'Événements typés par secteur, mois de publication, type et sens — hors rejetés, et restreints aux sources déclarées éligibles à la lecture événementielle (flux_sources.lecture_evenementielle, 01.09.2026).';

\echo '--- 1. déclaration par source'
SELECT flux_id, famille, statut, lecture_evenementielle FROM flux_sources ORDER BY lecture_evenementielle DESC, famille, flux_id;

\echo '--- 2. après : événements servis (éligibles) vs conservés au registre (non éligibles)'
SELECT s.lecture_evenementielle AS eligible, count(*) AS n,
       count(*) FILTER (WHERE e.type_evenement = 'autre') AS autre,
       count(*) FILTER (WHERE e.type_evenement = 'investissement') AS investissement
  FROM flux_evenements e JOIN flux_items i USING (item_id) JOIN flux_sources s USING (flux_id)
 GROUP BY 1 ORDER BY 1 DESC;

\echo '--- 3. registre inchangé (ajout seul) : 690 attendus'
SELECT count(*) AS evenements_au_registre FROM flux_evenements;

\echo '--- 4. v_evenements_mois : somme = événements éligibles non rejetés'
SELECT sum(n) AS n_vue FROM v_evenements_mois;
