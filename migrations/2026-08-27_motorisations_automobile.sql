-- =====================================================================
-- 2026-08-27 — MOTORISATIONS AUTOMOBILE : LA PART ÉLECTRIQUE EN SÉRIE
--
-- Décision de l'étudiant du 27.08.2026 : porter au tableau le total
-- mondial des ventes de voitures et sa décomposition thermique/électrique.
-- L'examen de la base a montré que les deux tiers du chemin existaient :
-- A3 (ventes de véhicules électriques par pays, IEA) est instrumenté et
-- collecté — mais HORS VITRINE depuis l'élagage (3 points sur la zone de
-- référence) — et la même API publie « EV sales share », la part
-- électrique des ventes calculée par la source elle-même.
--
-- RÉPONSE RÉELLE VUE le 27.08.2026 (règle de qualification du § 8.2) sur
-- les millésimes 2010, 2015, 2020, 2024 : lignes World présentes chaque
-- année, powertrain agrégé « EV » disponible pour « EV sales », paramètre
-- « EV sales share » en percent (0,012 % en 2010 → 21 % en 2024).
-- Recoupement de vraisemblance : 17 M / 21 % ≈ 81 M de voitures vendues
-- en 2024 — cohérent avec l'ordre de grandeur connu du marché.
--
-- TROIS GESTES, AUCUNE IA :
-- 1. A11 — part électrique des ventes mondiales (collectée telle quelle,
--    hard, annuelle). C'est QV4 rendue chiffrable : l'électrification qui
--    recompose la demande de composants. Sens déclaré NEUTRE (0) : pour
--    un sous-traitant mécanique, la substitution supprime des familles de
--    pièces et en crée d'autres — même doctrine que A9/S9.
-- 2. A3 revient en vitrine : ses liaisons s'étendent de 2023-2025 à
--    2010-2025 (l'API exige year par appel — une liaison par millésime).
--    CONSTATÉ À L'EXÉCUTION (run 159) : la fenêtre d'historique des séries
--    annuelles (2014, règle du 24.08 « à ratifier ») écarte 2010-2013
--    « hors fenêtre » — la série servie est 2014-2025, soit 12 points sur
--    World : le critère d'élagage qui l'avait écarté (« moins de douze
--    points, la série ne se lit pas ») est satisfait au point près,
--    et son retour re-couvre automobile × QV3 et QV4 en certifié.
-- 3. v_motorisations_automobile : total mondial = EV / part, thermique =
--    total − EV. Dérivation SQL depuis deux séries collectées — les
--    chiffres par le code. La vue est requêtable et citable ; sa
--    restitution à l'écran est une évolution ultérieure.
--
-- TERMINOLOGIE (à tenir au rapport) : part d'une MOTORISATION dans les
-- ventes — veille économique —, jamais « part de marché » d'un acteur,
-- qui relèverait de la veille concurrentielle, hors périmètre (§ 3).
-- =====================================================================

BEGIN;

-- 1. A11 — la part électrique, collectée à la source.
INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency,
                        unit, status, en_vitrine, sens_favorable, latence, geo_reference,
                        description_metier, note_conception)
VALUES ('A11', 'automobile',
        'Part électrique des ventes mondiales de voitures (IEA)',
        'aie', 'hard', 'annuelle', 'pourcentage', 'certifie', true, 0, 'coincident', 'World',
        'Part des voitures électriques (BEV, PHEV, FCEV) dans les ventes mondiales de voitures neuves, telle que publiée par l''Agence internationale de l''énergie. C''est la mesure directe de la substitution de motorisation : pour un fournisseur de composants mécaniques, chaque point de part gagné par l''électrique déplace la demande de familles entières de pièces — la question QV4 en un chiffre.',
        'Créé le 27.08.2026 (décision de l''étudiant). Valeur collectée telle quelle — la part est calculée par la source, aucune dérivation de notre part. Réponse réelle vérifiée sur 2010/2015/2020/2024. Série 2010-2025, une liaison par millésime (l''API exige year). Sens neutre : la recomposition n''est ni favorable ni défavorable en soi pour la sous-traitance. Complète A9 (intensité de signalement QV4) : A9 mesure ce dont le marché parle, A11 ce qu''il fait. Le total mondial et le volume thermique s''en dérivent par vue (v_motorisations_automobile).');

INSERT INTO indicator_watch_questions (indicator_id, watch_question_code)
VALUES ('A11', 'QV4');

-- 2. A3 revient en vitrine, motif daté.
UPDATE indicators
   SET en_vitrine = true,
       note_conception = coalesce(note_conception || E'\n', '')
         || 'RETOUR EN VITRINE le 27.08.2026 : les liaisons s''étendent de 2023-2025 à 2010-2025 (~16 points sur World) — le motif de l''écart du 25.08 (moins de douze points) tombe. Porteur certifié des cases automobile × QV3 et QV4, aux côtés des intensités de signalement.'
 WHERE indicator_id = 'A3';

-- 3. Les liaisons par millésime. Modèle : la liaison A3/2023 vérifiée le
-- 17.08 ; seule l'année change. Statut actif — réponse réelle vue ce jour.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut,
                             statut, verifie_par, verifie_le, note)
SELECT 'A3', 'csv_generique', 'https://api.iea.org/evs',
       jsonb_build_object('csv','true','mode','Cars','year',y::text,
                          'category','Historical','parameters','EV sales'),
       '{"filtres": {"unit": ["Vehicles"], "parameter": ["EV sales"], "powertrain": ["EV"]}, "colonne_code": "region", "colonne_valeur": "value", "colonne_periode": "year"}'::jsonb,
       'WORLD', 'actif', 'N. Castillo (délégation du 27.08.2026)', now(),
       'Extension d''historique du 27.08.2026 — réponse réelle vue (lignes World et powertrain agrégé EV présents sur les millésimes sondés).'
  FROM generate_series(2010, 2022) AS y
 WHERE NOT EXISTS (SELECT 1 FROM source_bindings b
                    WHERE b.indicator_id = 'A3' AND b.params->>'year' = y::text);

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut,
                             statut, verifie_par, verifie_le, note)
SELECT 'A11', 'csv_generique', 'https://api.iea.org/evs',
       jsonb_build_object('csv','true','mode','Cars','year',y::text,
                          'category','Historical','parameters','EV sales share'),
       '{"filtres": {"unit": ["percent"], "parameter": ["EV sales share"], "powertrain": ["EV"]}, "colonne_code": "region", "colonne_valeur": "value", "colonne_periode": "year"}'::jsonb,
       'WORLD', 'actif', 'N. Castillo (délégation du 27.08.2026)', now(),
       'Réponse réelle vue le 27.08.2026 : parameter « EV sales share », powertrain EV, unit percent, lignes World présentes de 2010 à 2024 (2025 sondé via la base A3).'
  FROM generate_series(2010, 2025) AS y;

-- 4. La dérivation : total et thermique depuis deux séries collectées.
CREATE OR REPLACE VIEW v_motorisations_automobile AS
SELECT ev.period,
       ev.value                                            AS ventes_ev,
       part.value                                          AS part_ev_pct,
       round(ev.value / nullif(part.value, 0) * 100.0, 0)  AS ventes_totales,
       round(ev.value / nullif(part.value, 0) * 100.0
             - ev.value, 0)                                AS ventes_thermiques
  FROM v_current ev
  JOIN v_current part
    ON part.indicator_id = 'A11' AND part.period = ev.period AND part.geo = ev.geo
 WHERE ev.indicator_id = 'A3' AND ev.geo = 'World'
 ORDER BY ev.period;

COMMENT ON VIEW v_motorisations_automobile IS
  'Ventes mondiales de voitures décomposées par motorisation : EV collecté (A3), part collectée (A11), total et thermique DÉRIVÉS (total = EV / part). Part d''une motorisation, jamais « part de marché » d''un acteur. Créée le 27.08.2026.';

COMMIT;
