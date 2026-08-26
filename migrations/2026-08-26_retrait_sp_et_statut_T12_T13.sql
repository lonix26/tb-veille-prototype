-- =====================================================================
-- 2026-08-26 — Deux non-conformités de l'objectif O2, tranchées
--
-- Revue objectif par objectif conduite avec l'étudiant le 26.08. Deux
-- points relevés sur O2 (« identifier les indicateurs par secteur »), deux
-- décisions prises par lui, et deux traitements DIFFÉRENTS — parce que les
-- deux cas ne se ressemblent que superficiellement.
--
-- ---------------------------------------------------------------------
-- 1. S&P GLOBAL PMI — RETIRÉ DU RÉFÉRENTIEL.
--
-- L'OSINT est la contrainte fondatrice du travail (PV n° 1 ; PV n° 3 :
-- « les sources OSINT sont le pétrole de la veille »). Cette source porte
-- `access = payant` : elle n'aurait jamais dû être qualifiée, et sa
-- présence au tableau de confiance laissait une ligne « payant » dans un
-- document dont l'argument est justement l'accessibilité à coût nul.
--
-- Elle est SUPPRIMABLE sans dommage : zéro indicateur, zéro liaison, zéro
-- observation. Rien n'est perdu — seulement une ligne qui n'aurait pas dû
-- être écrite. Le retrait est donc franc, et non un changement de statut.
--
-- ---------------------------------------------------------------------
-- 2. T12 ET T13 — ÉCARTÉS, MAIS NON SUPPRIMÉS. Et la nuance est la
--    doctrine du travail, pas une commodité.
--
-- Ces deux indicateurs (brevets OMPI) sont sans question de veille depuis
-- leur abandon du 24.08 — ils violent donc la règle « pas d'indicateur
-- sans question », que le déclencheur `trg_indicateur_sans_question`
-- impose à l'insertion. L'intention de l'étudiant est de les retirer.
--
-- MAIS ils portent 322 OBSERVATIONS au registre, et le registre est en
-- AJOUT SEUL (décision D-18). Les supprimer exigerait de désactiver le
-- déclencheur `trg_registre_ajout_seul` pour effacer des observations
-- réellement collectées — c'est-à-dire de nier qu'elles l'ont été. Ce
-- serait exactement la surdéclaration que le travail s'interdit, et à
-- l'envers : effacer une trace pour faire propre.
--
-- La règle appliquée est donc celle du 25.08 (§ 8.8) : un indicateur sort
-- de la GRILLE, jamais du REGISTRE. Concrètement :
--   — statut porté à `restreint`, hors vitrine (déjà le cas) ;
--   — leurs liaisons de collecte : aucune, donc plus aucune collecte ;
--   — leur description porte le motif, daté, lisible à l'annexe 1 ;
--   — le socle reconstruit NE LES CONTIENT PAS : une base neuve démarre
--     sans eux, ce qui est la forme la plus complète du retrait dans un
--     dispositif dont l'historique est immuable.
--
-- Ce que le jury verra : deux lignes au référentiel en service, absentes
-- du socle et de la grille, avec leur motif. C'est le maximum de retrait
-- compatible avec l'immuabilité du registre — et l'écart entre les deux
-- est lui-même une démonstration de la contrainte.
-- =====================================================================

BEGIN;

DELETE FROM sources WHERE source_id = 'sp_global_pmi';

UPDATE indicators
   SET description_metier = coalesce(description_metier, '') ||
       ' [RETIRÉ DE LA GRILLE le 26.08.2026 sur décision de l''étudiant : sans question de veille rattachée depuis l''abandon du 24.08, cet indicateur viole la règle « pas d''indicateur sans question ». Il n''est pas supprimé du registre — ses 322 observations ont été réellement collectées et le registre est en ajout seul —, mais il ne collecte plus, n''entre dans aucun calcul, et le socle reconstruit ne le contient pas.]'
 WHERE indicator_id IN ('T12', 'T13')
   AND coalesce(description_metier, '') NOT LIKE '%RETIRÉ DE LA GRILLE%';

COMMIT;
