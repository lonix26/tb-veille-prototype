-- =====================================================================
-- 2026-08-28 — H2 ET M4 : LA PROFONDEUR ÉTAIT UN PARAMÈTRE, PAS UNE LIMITE
--
-- Revue de l'étudiant sur horlogerie × QV1 : « les deux indicateurs
-- reliés répondent-ils à la question ? » Analyse sur pièces : H9 répond
-- au MÉCANISME (valeur vs pièces, § 8.6.4), H6 est un proxy d'activité au
-- périmètre UE — et le porteur LITTÉRAL de la question (« emplois et
-- établissements... suisse »), H2/STATENT, dormait en réserve avec quatre
-- points. Or la reconnaissance de ce jour sur le cube PX-Web
-- (px-x-0602010000_103) établit que **2011-2024 est disponible** — la
-- liaison du 25.08 ne demandait que « top: 4 ». Quatorze points ≥ plancher
-- de douze : le motif de l'écart tombe, comme pour A3 la veille.
--
-- M4 (emplois medtech, même cube, mêmes codes de reconnaissance) est
-- traité dans le même geste : la critique vaut à l'identique pour
-- médical × QV1, servi par le seul proxy UE (M2).
--
-- MÉTHODE (précédent du 24.08) : NOUVELLE liaison par indicateur avec
-- « top: 14 », l'ancienne SUSPENDUE nominativement dans le même geste —
-- faute de quoi 2021-2024 seraient collectés deux fois par run.
-- La grandeur reste « Emplois » (Beobachtungseinheit = 2) : le volet
-- « établissements » du même cube (code 1) est une extension identifiée,
-- non instrumentée — un indicateur, une grandeur.
-- =====================================================================

BEGIN;

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut,
                             statut, verifie_par, verifie_le, note)
SELECT b.indicator_id, b.connecteur, b.url_base,
       jsonb_set(b.params, '{_corps,query,0,selection,values}', '["14"]'::jsonb),
       b.mapping, b.geo_defaut,
       'actif', 'N. Castillo (délégation du 28.08.2026)', now(),
       'Profondeur pleine du cube STATENT (2011-2024, vérifiée sur métadonnées PX-Web le 28.08.2026) — remplace la liaison ' || b.binding_id || ' (top: 4). Quatorze points : le motif d''écart de la vitrine (moins de douze points) tombe.'
  FROM source_bindings b
 WHERE b.binding_id IN (97, 98);

UPDATE source_bindings
   SET statut = 'suspendu',
       note = note || ' — SUSPENDUE le 28.08.2026 au profit de la liaison pleine profondeur (top: 14), pour éviter la double collecte.'
 WHERE binding_id IN (97, 98);

COMMIT;
