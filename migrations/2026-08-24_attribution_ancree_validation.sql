-- ============================================================================
-- Attribution ancrée — traçabilité de validation, et validation du run 98.
-- N. Castillo, 24.08.2026.
--
-- POURQUOI CES COLONNES. La conception de la restitution pose que rien de non
-- validé n'atteint l'écran hors compteurs. Cette règle vaut AUSSI pour une
-- démonstration : afficher un commentaire ancré non relu, au motif qu'il est
-- expérimental, serait précisément la porte dérobée que la règle interdit.
-- La table de bac à sable doit donc porter la même trace que la table de
-- production, et la contrainte l'impose plutôt que la consigne.
-- ============================================================================

BEGIN;

ALTER TABLE sandbox.commentaires_attribution
  ADD COLUMN IF NOT EXISTS validated_by  text,
  ADD COLUMN IF NOT EXISTS validated_at  timestamptz,
  ADD COLUMN IF NOT EXISTS note_validation text;

ALTER TABLE sandbox.commentaires_attribution
  DROP CONSTRAINT IF EXISTS chk_attribution_statut,
  DROP CONSTRAINT IF EXISTS chk_attribution_valide_trace;

ALTER TABLE sandbox.commentaires_attribution
  ADD CONSTRAINT chk_attribution_statut
    CHECK (statut IN ('demonstration', 'valide', 'rejete')),
  ADD CONSTRAINT chk_attribution_valide_trace
    CHECK (statut <> 'valide' OR (validated_by IS NOT NULL AND validated_at IS NOT NULL));

-- ---------------------------------------------------------------------------
-- Validation du run 98 (médical). Les SEPT ancres citées ont été ouvertes une
-- à une et confrontées à l'item qu'elles désignent.
-- ---------------------------------------------------------------------------
UPDATE sandbox.commentaires_attribution
   SET statut = 'valide',
       validated_by = 'N. Castillo',
       validated_at = now(),
       note_validation =
'Validé le 24.08.2026 après vérification des sept ancres, une à une, contre l''item désigné.

CTX-146  TED 566493-2026, Croatie, suppléance orthopédique — implant. Exact.
CTX-161  TED 566782-2026, Espagne, implants chirurgicaux. Exact.
CTX-1625 TED 512543-2026, France, fourniture de prothèses. Exact.
CTX-1626 TED 512551-2026, Pologne, articulations artificielles (endoprothèses). Exact.
CTX-1631 TED 512625-2026, Pologne — catalogué « consommables médicaux » par la nomenclature,
         mais l''intitulé d''origine porte « dostawa implantów ». Le modèle a lu le libellé
         polonais plutôt que l''étiquette de catégorie : le rattachement aux implants est
         FONDÉ, et plus juste que la catégorie elle-même. Point notable, conservé.
CTX-726  FDA 510(k) K253702, Intuitive Endoluminal Gastrointestinal System. Plateforme
         endoluminale — la qualification du commentaire est exacte.
CTX-728  FDA 510(k) K260382, MONARCH Platform, Auris Health. Plateforme robotique. Exact.

AUCUNE ancre inexistante, AUCUNE attribution non ancrée : les trois contrôles déterministes
de la variante passent. Le commentaire déclare de lui-même les mouvements sans ancre
disponible (commerce suisse, production UE, dépenses de santé, emploi de branche).

PORTÉE DE CETTE VALIDATION, à ne pas dépasser : elle établit que chaque fait cité existe et
correspond à ce qui en est dit. Elle n''établit PAS que ces faits expliquent le niveau
d''avis observé — le commentaire ne le prétend pas davantage, il écrit « composante
identifiée » et « hypothèse documentée ». La distinction est le fond de la démonstration.'
 WHERE id = 1 AND statut = 'demonstration';

COMMIT;

SELECT id, sector_code, statut, validated_by, array_length(ancres_citees,1) AS ancres_citees,
       ancres_disponibles
FROM sandbox.commentaires_attribution;
