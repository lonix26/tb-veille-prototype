-- =====================================================================
-- 2026-09-04 — LA SOURCE D'A1 DIT CE QUI EST COLLECTÉ : L'ANNUAIRE CCFA
--
-- Constat : l'entrée « oica » du référentiel décrivait un accès
-- « Tableaux web » à https://www.oica.net/production-statistics, qualifié
-- le 07.08.2026. Depuis la requalification d'A1 en composite (31.08.2026,
-- note_conception de l'indicateur), ce n'est pas ce que le dispositif
-- lit : le document collecté est l'annuaire du CCFA (« L'industrie
-- automobile française »), PDF, qui republie le tableau « La production
-- mondiale de véhicules » avec la mention imprimée « Source : OICA »
-- (composite_queue 9-11 : page des analyses et statistiques, éditions
-- 2023 et 2024 ; workflow extraction_composite_A1_ccfa, runs 187-189 du
-- 31.08.2026, série 2021-2024 en base). L'accès web de l'OICA reste la
-- vérité terrain opportuniste du rang 1 : les classements top-10 de sa
-- page (JSON incorporé) confrontent les valeurs extraites quand l'année
-- est servie, et ne rendent jamais de faux verdict sinon.
--
-- Le § 8.6.4 du rapport affirme que la bibliographie des sources de
-- données cite l'OICA comme producteur et le CCFA comme document
-- collecté. Cette section étant PRODUITE PAR REQUÊTE sur cette table
-- (exports/generer_sources_donnees.sh), l'affirmation ne peut devenir
-- vraie qu'ici — même geste que pour l'OFS le 30.08 et le CPB/SIPRI le
-- 27.08. Le producteur reste l'OICA (organisation) ; le CCFA est une
-- association professionnelle, jamais « donnée officielle ».
--
-- VÉRIFIÉ EN RÉPONSE RÉELLE le 31.08.2026 : les trois documents CCFA ont
-- été téléchargés et lus par le workflow (runs 187-189, statut ok) ; la
-- page OICA a servi neuf concordances lors du même run. La date de
-- qualification est reprise à ce jour, conformément à la règle de tête
-- de la section.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS : elle ne touche ni aux liaisons
-- (A1 n'en a pas — la collecte passe par composite_queue), ni aux
-- valeurs, ni au libellé de l'indicateur, ni au format « Tableaux web »
-- que le tableau du § 8.6.4 (C2, ligne A1) et l'annexe 1 reprennent : ces
-- deux-là suivent à la prochaine régénération / relecture.
-- =====================================================================

BEGIN;

UPDATE sources SET
  name = 'Production mondiale de véhicules par pays — tableau republié dans l''annuaire du CCFA « L''industrie automobile française » (mention imprimée « Source : OICA »), document collecté ; classements top-10 de la page OICA en vérité terrain',
  format = 'PDF (annuaire CCFA, https://ccfa.fr/analyses-et-statistiques/) ; tableaux web OICA pour la confrontation opportuniste',
  qualified_by = 'N. Castillo',
  qualified_at = '2026-08-31 00:00:00+00',
  notes = 'Producteur : OICA. Document collecté : annuaire CCFA (association professionnelle française), PDF, une édition par an, tableau « La production mondiale de véhicules » par pays en milliers, mention « Source : OICA » imprimée. Éditions traitées au 31.08.2026 : page des analyses et statistiques (édition courante), CCFA-2023, CCFA-2024 (composite_queue 9-11), série 2021-2024. Découpe par sentinelles avant envoi aux modèles (~2,5 % du document). Vérité terrain de rang 1 : classements top-10 de https://www.oica.net/production-statistics, JSON incorporé, confrontation opportuniste (non_verifiable quand l''année n''est pas servie, jamais de faux verdict). Détection des nouvelles éditions : workflow veille_documentaire_annuelle.'
WHERE source_id = 'oica';

COMMIT;

-- Contrôle : l'entrée doit nommer le CCFA et garder l'OICA en producteur.
SELECT source_id, organisation, qualified_at::date,
       position('CCFA' in name) > 0 AS nomme_ccfa,
       (SELECT string_agg(i.indicator_id, ', ') FROM indicators i WHERE i.source_id = s.source_id) AS indicateurs
  FROM sources s WHERE source_id = 'oica';
