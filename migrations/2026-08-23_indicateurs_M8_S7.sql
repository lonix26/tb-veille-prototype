-- =====================================================================
-- Deux indicateurs de comptage à la source — 23.08.2026
--
-- M8 : autorisations FDA 510(k) de dispositifs médicaux, par mois (US).
-- S7 : avis de marchés publics UE en aéronefs et engins spatiaux, par mois.
--
-- MOTIF — décision de l'étudiant du 23.08.2026. Le chantier des signaux
-- faibles a établi que openFDA et TED aérospatial sont les deux sources
-- les plus antérieures du dispositif (57 % et 67 % de rétention au triage).
-- Mais un acte isolé — une autorisation, un avis — n'est pas un signal
-- pour un sous-traitant : c'est une ligne de registre. Ce qui parle, c'est
-- le RYTHME. Ces deux indicateurs comptent ce que les flux de l'étage 2
-- ne faisaient qu'énumérer, exactement comme M7 le fait depuis le 20.08
-- pour le CPV 33. La même source sert donc deux étages : le flux pour
-- l'examen à l'unité, le comptage pour la tendance.
--
-- AUTOMOBILE ÉCARTÉ, à dessein et sur mesure. Le CPV automobile affiné
-- donne pourtant une série tout aussi propre (73 à 127 sur onze mois).
-- Elle n'est pas retenue parce que le triage du 23.08 a établi que ces
-- avis sont des marchés d'entretien de flottes municipales — 2 % de
-- pertinence — et que le verdict écrit du jour dit « l'acheteur public
-- n'est pas le marché automobile ». Construire l'indicateur contredirait
-- le constat. Une série propre n'est pas une série pertinente.
--
-- HORLOGERIE : aucune voie. Il n'existe pas de commande publique de
-- montres, et la source amont naturelle — les dépôts de brevets, déjà
-- inscrits en H4 — n'a pas d'accès gratuit sans clé (EPO OPS : 403 sans
-- clé, vérifié le 23.08). Lacune documentée, pas oubli.
--
-- Décompte après cette migration : 32 indicateurs, 28 certifiés.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-23_indicateurs_M8_S7.sql \
--     | tee ../annexe_5/indicateurs_M8_S7_2026-08-23.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO sources (source_id, name, organisation, url, frequency, format, access,
                     qualification_status, qualified_by, qualified_at, notes)
VALUES ('openfda', 'openFDA — bases publiques de la Food and Drug Administration',
        'U.S. Food and Drug Administration', 'https://open.fda.gov',
        'quotidienne', 'API', 'libre', 'certifiee', 'N. Castillo', '2026-08-23',
        'API libre et sans clé (quota anonyme). Vérifiée en réponse réelle le 23.08.2026 : onze mois consécutifs de décomptes 510(k). Deux pièges d''appel consignés — la syntaxe d''intervalle « champ:[debut+TO+fin] » ne doit pas voir son « + » encodé (sinon 500), et une recherche sans résultat répond 404 et non 200 avec liste vide.')
ON CONFLICT (source_id) DO NOTHING;

INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency, unit,
                        status, alert_threshold_pct, description_metier)
VALUES
 ('M8', 'medical',
  'Autorisations FDA 510(k) de dispositifs médicaux (États-Unis)',
  'openfda', 'hard', 'mensuelle', 'nombre d''autorisations', 'certifie', NULL,
  'Le nombre de dispositifs médicaux autorisés chaque mois à la mise sur le marché américain. Un acte réglementaire précède la production en série, donc la commande de pièces usinées : l''indicateur est avancé par construction. Se lit en tendance — un décompte d''autorisations n''est ni un volume ni un chiffre d''affaires, et le périmètre est américain, non mondial.'),
 ('S7', 'aerospatial',
  'Avis de marchés publics UE en aéronefs et engins spatiaux (TED, CPV 347)',
  'ted', 'hard', 'mensuelle', 'nombre d''avis', 'certifie', NULL,
  'La demande publique adressée au secteur aérospatial, comptée à la source. Transposition de la méthode de M7 au CPV 34700000. Le secteur où elle a le plus de sens : dans l''aérospatial, l''acheteur public — armées, agences spatiales — EST une part majeure du marché, ce qui n''est pas le cas de l''automobile. Se lit en tendance.')
ON CONFLICT (indicator_id) DO NOTHING;

INSERT INTO indicator_watch_questions (indicator_id, watch_question_code)
VALUES ('M8', 'QV2'), ('M8', 'QV4'), ('S7', 'QV2'), ('S7', 'QV5')
ON CONFLICT DO NOTHING;

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note)
VALUES
 ('M8', 'json_generique', 'https://api.fda.gov/device/510k.json',
  jsonb_build_object('_methode', 'GET',
    '_gabarit_url', 'https://api.fda.gov/device/510k.json?search=decision_date:[{debut}+TO+{fin}]&count=decision_date',
    '_remarque', 'Le + de +TO+ ne doit pas être encodé : URL construite à la main.'),
  jsonb_build_object('champ_scalaire', 'somme(results[].count)', 'periode', 'mois de la fenêtre'),
  'US', 'a_verifier',
  'Décompte mensuel par somme des occurrences quotidiennes (count=decision_date). Onze mois vus en réponse réelle le 23.08.2026, de 2025-09 à 2026-07.'),
 ('S7', 'json_generique', 'https://api.ted.europa.eu/v3/notices/search',
  jsonb_build_object('_methode', 'POST',
    '_corps', jsonb_build_object(
      'query', 'classification-cpv IN (34700000) AND publication-date >= {debut} AND publication-date <= {fin}',
      'limit', 1, 'fields', jsonb_build_array('publication-number'))),
  jsonb_build_object('champ_scalaire', 'totalNoticeCount', 'periode', 'mois de la fenêtre'),
  'EU', 'a_verifier',
  'Même méthode que M7, CPV 34700000. Onze mois vus en réponse réelle le 23.08.2026, de 2025-09 à 2026-07.')
ON CONFLICT DO NOTHING;

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V19 : M8 et S7 certifiés, rattachés à deux questions de veille chacun.
--   V20 : décompte 32 indicateurs, 28 certifiés.
--   V21 : le registre n'est PAS touché par cette migration — les valeurs
--         arrivent par collecte, sous un run daté, avec leur pièce brute.
-- ---------------------------------------------------------------------

SELECT 'V19' AS verif, i.indicator_id, i.status, i.frequency,
       (SELECT string_agg(watch_question_code, ',' ORDER BY watch_question_code)
          FROM indicator_watch_questions q WHERE q.indicator_id = i.indicator_id) AS questions,
       (SELECT count(*) FROM source_bindings b WHERE b.indicator_id = i.indicator_id) AS liaisons
FROM indicators i WHERE i.indicator_id IN ('M8','S7') ORDER BY i.indicator_id;

SELECT 'V20' AS verif, count(*) AS indicateurs, count(*) FILTER (WHERE status='certifie') AS certifies
FROM indicators;

SELECT 'V21' AS verif, count(*) AS observations_en_base,
       count(*) FILTER (WHERE indicator_id IN ('M8','S7')) AS dont_M8_S7
FROM indicator_values;
