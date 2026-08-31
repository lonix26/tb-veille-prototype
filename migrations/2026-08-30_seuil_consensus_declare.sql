-- =====================================================================
-- 2026-08-30 — LE SEUIL DE CONSENSUS SORT DU CODE ET ENTRE AU RÉFÉRENTIEL
--
-- Demande de l'étudiant : ne pas faire passer toute extraction composite par
-- l'humain ; au-dessus d'un seuil de consensus, la valeur rejoint directement
-- le tableau de bord ; en dessous, elle part en validation humaine.
--
-- CE QUI EXISTAIT DÉJÀ. Le routage automatique fonctionnait, mais à
-- UNANIMITÉ STRICTE et en dur dans un nœud Code. Au chargement du 30.08,
-- 32 valeurs sur 34 sont parties directement au registre en
-- `pre_valide_consensus` — l'humain n'a été sollicité que sur 6 % d'entre
-- elles. Ce que cette migration ajoute n'est donc pas le mécanisme, c'est
-- sa DÉCLARATION : le seuil devient un attribut du référentiel, daté,
-- citable par requête et réglable indicateur par indicateur, au lieu d'un
-- choix enterré dans du code.
--
-- POURQUOI 1.0 PAR DÉFAUT, ET NON 0,66. Avec trois modèles, descendre sous
-- l'unanimité signifie « deux sur trois suffisent ». Or les erreurs de
-- lecture d'un tableau sont CORRÉLÉES entre modèles : deux qui lisent mal
-- la même cellule se donnent raison, et la majorité écrit une valeur fausse
-- que personne ne voit. L'historique d'A2 va dans ce sens — six routages en
-- validation, quatre modes de défaillance typés, dont une omission réelle
-- attrapée par le désaccord. Le défaut reste donc l'unanimité ; l'abaisser
-- est possible, mais devient une décision VISIBLE et defendable.
--
-- CE QUE LE SEUIL NE COMMANDE PAS. Les contrôles déterministes restent une
-- condition INDÉPENDANTE et non contournable : la règle d'écriture est
-- « consensus >= seuil ET contrôles satisfaits ». C'est ce second facteur
-- qui empêche le consensus de devenir une preuve, contrairement à la
-- doctrine du projet. La ligne 2025 du recensement CP le démontre : trois
-- modèles unanimes ET exacts, et pourtant une valeur à faire voir à un
-- humain, parce que c'est le document publié qui se trompait. Un seuil de
-- consensus, si haut soit-il, ne l'aurait jamais vu.
-- =====================================================================

BEGIN;

ALTER TABLE indicators
  ADD COLUMN IF NOT EXISTS seuil_consensus numeric;

-- Bornes de sens : une proportion de modèles d'accord.
ALTER TABLE indicators DROP CONSTRAINT IF EXISTS chk_seuil_consensus_borne;
ALTER TABLE indicators ADD CONSTRAINT chk_seuil_consensus_borne
  CHECK (seuil_consensus IS NULL OR (seuil_consensus > 0 AND seuil_consensus <= 1));

-- Tout composite DOIT déclarer son seuil : un indicateur dont les valeurs
-- peuvent entrer au registre sans humain ne peut pas laisser tacite la
-- règle qui le permet. Les indicateurs hard n'en ont pas (leurs valeurs ne
-- passent pas par un consensus) : la colonne y reste nulle.
UPDATE indicators SET seuil_consensus = 1.0 WHERE category = 'composite';

ALTER TABLE indicators DROP CONSTRAINT IF EXISTS chk_seuil_consensus_composite;
ALTER TABLE indicators ADD CONSTRAINT chk_seuil_consensus_composite
  CHECK (category <> 'composite' OR seuil_consensus IS NOT NULL);

COMMIT;

-- Vue de lecture : le seuil ET ce qu'il a produit. Sans le second, le seuil
-- n'est qu'une intention ; c'est le taux d'écriture directe qui dit ce que
-- la règle a réellement fait, et il se cite par requête comme le reste.
CREATE OR REPLACE VIEW v_seuils_consensus AS
SELECT i.indicator_id,
       i.sector_code,
       i.label,
       i.seuil_consensus,
       count(*) FILTER (WHERE v.validation_status = 'pre_valide_consensus') AS ecrites_sans_humain,
       count(*) FILTER (WHERE v.validation_status = 'valide_humain')        AS ecrites_apres_humain,
       (SELECT count(*) FROM validation_queue q
         WHERE q.indicator_id = i.indicator_id AND q.decision IS NULL)      AS en_attente_humain,
       (SELECT count(*) FROM validation_queue q
         WHERE q.indicator_id = i.indicator_id AND q.decision IS NOT NULL)  AS arbitrees_par_humain,
       round(100.0 * count(*) FILTER (WHERE v.validation_status = 'pre_valide_consensus')
             / nullif(count(*), 0), 1)                                      AS taux_ecriture_directe_pct
  FROM indicators i
  LEFT JOIN indicator_values v
         ON v.indicator_id = i.indicator_id AND v.obtained_by = 'ia_extraction'
 WHERE i.category = 'composite'
 GROUP BY i.indicator_id, i.sector_code, i.label, i.seuil_consensus
 ORDER BY i.indicator_id;

COMMENT ON COLUMN indicators.seuil_consensus IS
  'Proportion minimale de modèles d''accord pour qu''une valeur composite entre au registre sans arbitrage humain. Obligatoire pour les composites, nul pour les hard. La règle d''écriture est « consensus >= seuil ET contrôles déterministes satisfaits » : le seuil ne dispense JAMAIS des contrôles.';

SELECT * FROM v_seuils_consensus;
