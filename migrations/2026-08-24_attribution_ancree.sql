-- ============================================================================
-- Attribution ancrée — table de démonstration. 24.08.2026.
--
-- OBJET. Le dispositif s'interdit d'attribuer une cause (RI9 : « en raison de »,
-- « causé par », « s'explique par » sont proscrits). L'interdit est juste tant
-- que le modèle n'a AUCUN fait à sa disposition : la charge d'entrée du
-- commentaire exécutif ne contient que des chiffres, un cadre de veille et un
-- score. Lever RI9 dans ces conditions ne produirait pas une explication mais
-- une invention fluide, puisée dans la mémoire paramétrique du modèle.
--
-- CE QUE CETTE DÉMONSTRATION TESTE. Une variante où l'attribution est AUTORISÉE
-- mais ANCRÉE : le modèle reçoit le contexte factuel du secteur — signaux
-- validés et items de flux versés au contexte par examen humain — et ne peut
-- relier un mouvement qu'à un fait de ce contexte, qu'il doit citer par son
-- identifiant. L'affirmation causale devient alors traçable et réfutable, au
-- lieu d'être interdite. C'est le même régime que celui appliqué aux chiffres.
--
-- GARDE-FOU. Écriture dans le schéma `sandbox`, comme l'artefact du scénario C :
-- aucune sortie n'atteint la restitution. C'est une démonstration de
-- faisabilité, pas un composant de production.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS sandbox.commentaires_attribution (
  id                bigserial PRIMARY KEY,
  run_id            integer,
  sector_code       text NOT NULL,
  variante          text NOT NULL DEFAULT 'attribution_ancree',
  input_payload     jsonb,
  contexte_fourni   jsonb,
  model             text,
  text              text,
  -- Contrôle déterministe : les identifiants de contexte effectivement cités.
  ancres_citees     text[],
  ancres_disponibles integer,
  statut            text NOT NULL DEFAULT 'demonstration',
  created_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE sandbox.commentaires_attribution IS
  'Démonstration de faisabilité de l''attribution ancrée (24.08.2026). '
  'Hors production : aucune ligne n''est servie par l''interface de restitution. '
  'La comparaison se fait contre le commentaire de production du même secteur, '
  'rédigé sous RI9 et sans contexte factuel.';

COMMIT;

SELECT to_regclass('sandbox.commentaires_attribution') AS table_creee;
