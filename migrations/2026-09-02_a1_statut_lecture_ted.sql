-- =====================================================================
-- STATUT DE RELECTURE DES LECTURES TED — 02.09.2026 (plan de correction A1)
--
-- CONSTAT (tour complet du 02.09, constats WF-1 / IA-1 / UI-7). L'API
-- sert 82 actions issues de ted_lecture_ia (adressable, pièce, geste,
-- justification), produites par un modèle unique. La table n'a AUCUNE
-- colonne de statut : la validation humaine n'y est pas « non exercée »,
-- elle est impossible par construction. Pendant ce temps deux notes de
-- l'API affirment que « la doctrine v4 interdit d'afficher du non validé ».
--
-- RÉGIME EN VIGUEUR (décision de l'étudiant du 31.08.2026, tracée) :
-- tout est servi AVEC son statut, et l'écran badge ce qui n'est pas relu.
-- Cette migration rend les lectures TED conformes à ce régime : elles
-- naissent `non_relu`, ne sont jamais validées automatiquement, et la
-- vue v_actions expose le statut pour que l'écran le montre.
--
-- Ajout seul : aucune ligne n'est modifiée, le défaut `non_relu` est la
-- vérité de l'état (0 relecture humaine sur 324 lectures au 02.09).
-- =====================================================================

ALTER TABLE public.ted_lecture_ia
  ADD COLUMN IF NOT EXISTS statut     text NOT NULL DEFAULT 'non_relu',
  ADD COLUMN IF NOT EXISTS valide_par text,
  ADD COLUMN IF NOT EXISTS valide_le  timestamptz;

ALTER TABLE public.ted_lecture_ia
  DROP CONSTRAINT IF EXISTS chk_lecture_ted_statut,
  ADD CONSTRAINT chk_lecture_ted_statut
    CHECK (statut IN ('non_relu', 'valide', 'rejete')),
  DROP CONSTRAINT IF EXISTS chk_lecture_ted_relecture_tracee,
  ADD CONSTRAINT chk_lecture_ted_relecture_tracee
    CHECK (statut = 'non_relu' OR (valide_par IS NOT NULL AND valide_le IS NOT NULL));

COMMENT ON COLUMN public.ted_lecture_ia.statut IS
  'Relecture humaine de la lecture d''adressabilité : non_relu (défaut, jamais changé par un workflow), valide, rejete. Ajouté le 02.09.2026 : avant, aucune validation n''était possible.';
COMMENT ON COLUMN public.ted_lecture_ia.valide_par IS
  'Relecteur humain ; obligatoire dès que le statut quitte non_relu (contrainte).';

-- v_actions : même définition, plus le statut de la lecture. DROP puis
-- CREATE : les colonnes s'ajoutent au milieu et aucune vue n'en dépend
-- (vérifié par pg_depend le 02.09).
DROP VIEW IF EXISTS public.v_actions;
CREATE VIEW public.v_actions AS
 WITH recurrence AS (
         SELECT v_acheteurs_recurrents.acheteur,
            sum(v_acheteurs_recurrents.avis_publies) AS avis_publies,
            sum(v_acheteurs_recurrents.dont_encore_ouverts) AS dont_encore_ouverts
           FROM v_acheteurs_recurrents
          GROUP BY v_acheteurs_recurrents.acheteur
        )
 SELECT a.publication_number, a.sector_code, a.titre, a.url, a.acheteur, a.acheteur_pays,
    a.acheteur_ville, a.acheteur_courriel, a.acheteur_site, a.valeur_estimee, a.devise,
    a.cpv, a.nature_contrat, a.date_publication, a.date_limite,
    a.date_limite - CURRENT_DATE AS jours_restants,
        CASE
            WHEN (a.date_limite - CURRENT_DATE) <= 7 THEN 'urgent'::text
            WHEN (a.date_limite - CURRENT_DATE) <= 21 THEN 'proche'::text
            ELSE 'confortable'::text
        END AS urgence,
    l.adressable, l.piece_concernee, l.action_proposee, l.justification, l.modele,
    l.statut AS lecture_statut, l.valide_par AS lecture_valide_par,
    r.avis_publies AS acheteur_avis_publies,
    r.dont_encore_ouverts AS acheteur_appels_ouverts,
    r.acheteur IS NOT NULL AS acheteur_recurrent
   FROM ted_avis a
     LEFT JOIN ted_lecture_ia l ON l.publication_number = a.publication_number AND l.profil = 'A_metier_declare'::text
     LEFT JOIN recurrence r ON r.acheteur = a.acheteur
  WHERE a.est_appel_ouvert AND a.date_limite IS NOT NULL AND a.date_limite >= CURRENT_DATE;

COMMENT ON VIEW public.v_actions IS
  'Appels d''offres encore ouverts, avec la lecture d''adressabilité du modèle et SON STATUT de relecture (lecture_statut, ajouté le 02.09.2026). Servie par l''API veille/actions ; l''écran badge toute lecture non relue.';

SELECT statut, count(*) FROM ted_lecture_ia GROUP BY 1;
SELECT lecture_statut, count(*) FROM v_actions GROUP BY 1;
