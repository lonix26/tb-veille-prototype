-- ============================================================================
-- Liaisons des sept indicateurs d'étage adressable — N. Castillo, 24.08.2026
--
-- Toutes sur le connecteur `eurostat_jsonstat`, déjà en service. Aucune ligne
-- de code n'est ajoutée au collecteur : c'est la démonstration en acte de la
-- modularité défendue au § 10.6 — une source nouvelle est une DONNÉE au
-- référentiel, pas un développement.
--
-- CHAQUE LIAISON A ÉTÉ VUE EN RÉPONSE RÉELLE LE 24.08.2026 avant d'être
-- déclarée active, avec sa profondeur constatée. La contrainte
-- `chk_binding_verifie` impose la trace ; la vérification, elle, a été faite.
--
-- FENÊTRE À 2014 et non 2023 : ces séries ont douze ans de profondeur, et le
-- § 5.6 exige de pouvoir estimer une tendance avant de la retirer. Sur trois
-- ans, la tendance estimée serait aussi incertaine que le résidu qu'elle
-- produit.
--
-- DRAPEAU `admet_negatifs` sur T8 et T10 : un solde d'opinion est légitimement
-- négatif (le carnet européen est à -17,5), et le contrôle qualité rejette les
-- valeurs négatives par défaut. Hypothèse déclarée par liaison, jamais
-- assouplie globalement (§ 12.6).
-- ============================================================================

BEGIN;

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut,
                             statut, verifie_par, verifie_le, note)
VALUES
-- ── Branches clientes : indices de production, mensuels, base 2021 ──────────
('A6','eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpr_m',
 '{"format":"JSON","lang":"FR","nace_r2":"C293","geo":"EU27_2020","unit":"I21","s_adj":"SCA","sinceTimePeriod":"2014-01"}'::jsonb,
 '{}'::jsonb,'EU27_2020','actif','N. Castillo',now(),
 'Vu en réponse réelle le 24.08.2026 : 150 points, 2014-01 à 2026-06, dernier 91,6. '
 'À lire en regard de A5 (C29 = 106,6 à la même date) : quinze points d''écart entre '
 'le marché final et la demande adressable.'),

('H6','eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpr_m',
 '{"format":"JSON","lang":"FR","nace_r2":"C2652","geo":"EU27_2020","unit":"I21","s_adj":"SCA","sinceTimePeriod":"2014-01"}'::jsonb,
 '{}'::jsonb,'EU27_2020','actif','N. Castillo',now(),
 'Vu en réponse réelle le 24.08.2026 : 150 points, 2014-01 à 2026-06, dernier 99,5.'),

('S8','eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpr_m',
 '{"format":"JSON","lang":"FR","nace_r2":"C303","geo":"EU27_2020","unit":"I21","s_adj":"SCA","sinceTimePeriod":"2014-01"}'::jsonb,
 '{}'::jsonb,'EU27_2020','actif','N. Castillo',now(),
 'Vu en réponse réelle le 24.08.2026 : 150 points, 2014-01 à 2026-06, dernier 150,8 — '
 'la branche produit cinquante pour cent au-dessus de sa base 2021.'),

('T11','eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpr_m',
 '{"format":"JSON","lang":"FR","nace_r2":"C","geo":"CH","unit":"I21","s_adj":"SCA","sinceTimePeriod":"2014-01"}'::jsonb,
 '{}'::jsonb,'CH','actif','N. Castillo',now(),
 'Vu en réponse réelle le 24.08.2026 : 150 points, dernier 124,7. LIMITE CONSTATÉE ET '
 'DÉCLARÉE : la ventilation par branche NACE n''existe pas pour la Suisse dans cette '
 'source — C25, C256 et C2562 y sont vides, seul l''agrégat manufacturier répond.'),

-- ── Enquête de conjoncture : les instruments avancés ────────────────────────
('T8','eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_bsin_m_r2',
 '{"format":"JSON","lang":"FR","indic":"BS-IOB","geo":"EU27_2020","s_adj":"SA","sinceTimePeriod":"2014-01"}'::jsonb,
 '{"admet_negatifs":true}'::jsonb,'EU27_2020','actif','N. Castillo',now(),
 'Vu en réponse réelle le 24.08.2026 : 151 points, 2014-01 à 2026-07, dernier -17,5 '
 '(carnets jugés inférieurs à la normale, en amélioration depuis -19,9 en février). '
 'Solde d''opinion : grandeur intensive et négative, drapeau admet_negatifs posé.'),

('T9','eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_bsin_q_r2',
 '{"format":"JSON","lang":"FR","indic":"BS-ICU-PC","geo":"EU27_2020","s_adj":"NSA","sinceTimePeriod":"2014-Q1"}'::jsonb,
 '{}'::jsonb,'EU27_2020','actif','N. Castillo',now(),
 'Vu en réponse réelle le 24.08.2026 : 51 points trimestriels, 2014-Q1 à 2026-Q3, '
 'dernier 78,3 %.'),

('T10','eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ei_bsin_q_r2',
 '{"format":"JSON","lang":"FR","indic":"BS-FLP2-PC","geo":"EU27_2020","s_adj":"NSA","sinceTimePeriod":"2014-Q1"}'::jsonb,
 '{"admet_negatifs":true}'::jsonb,'EU27_2020','actif','N. Castillo',now(),
 'Vu en réponse réelle le 24.08.2026 : 51 points trimestriels, dernier 33,5 % — en '
 'baisse depuis 37 %, donc signal favorable puisque le sens est inversé.')
ON CONFLICT DO NOTHING;

COMMIT;

SELECT b.indicator_id, i.frequency, b.params->>'nace_r2' AS nace, b.params->>'indic' AS indic,
       b.statut, b.verifie_par
FROM source_bindings b JOIN indicators i USING(indicator_id)
WHERE b.indicator_id IN ('A6','H6','S8','T8','T9','T10','T11') ORDER BY 1;
