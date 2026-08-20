-- =====================================================================
-- Migration du 20.08.2026 — M7, avis de marchés publics UE en
-- équipements médicaux (TED, CPV 33) — premier indicateur OSINT
--
-- Famille F3 de la demande de ratification (marchés publics), vérifiée
-- accessible le 20.08.2026 : l'API de recherche TED répond sans clé, en
-- JSON, et sert le décompte total des avis pour une requête donnée
-- (totalNoticeCount = 6 239 pour CPV 33* en juillet 2026, réponse vue).
--
-- Définition : nombre d'avis publiés au TED par mois portant un code
-- CPV de la division 33 (équipements et fournitures médicaux). C'est la
-- demande PUBLIQUE adressée au secteur médical, en amont des commandes —
-- fraîcheur J+0, là où le commerce international (M1) constate à
-- plusieurs mois. Un décompte d'avis, pas un volume en francs : le
-- niveau se lit en tendance, pas en valeur absolue — dit dans la
-- description métier.
--
-- Architecture : voie POST existante + mode « scalaire » ajouté au
-- décodeur JSON le 20.08.2026 (REQUIERT le réimport du collecteur).
-- Une liaison PAR MOIS, corps de requête statique portant ses bornes de
-- dates (motif des fenêtres H1/A3) : sept fenêtres 2026-01..2026-07.
-- La collecte du mois courant en continu exigerait des bornes calculées
-- à l'exécution — évolution identifiée, non réalisée, documentée.
--
-- Semées a_verifier : la fenêtre de juillet a été vue en réponse réelle ;
-- les six autres sont à voir (boucle de contrôle en fin de fichier),
-- puis activation par activation_M7_2026-08-20.sql.
--
-- Décompte après activation : 30 indicateurs, 26 certifiés.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-20_indicateur_M7_ted.sql \
--     | tee ../annexe_5/indicateur_M7_2026-08-20.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO sources (source_id, name, organisation, url, frequency, format, access, qualification_status, qualified_by, qualified_at, notes)
VALUES ('ted', 'Tenders Electronic Daily — marchés publics UE', 'Office des publications de l''UE',
        'https://ted.europa.eu', 'quotidienne', 'API', 'libre', 'certifiee', 'N. Castillo', '2026-08-20',
        'API de recherche v3, POST JSON, sans clé pour la recherche. Vérifiée en réponse réelle le 20.08.2026 (totalNoticeCount par requête CPV + bornes de dates). Source de la famille OSINT F3 (marchés publics) de la demande de ratification.')
ON CONFLICT (source_id) DO NOTHING;

INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency, unit, status, alert_threshold_pct, description_metier)
VALUES ('M7', 'medical',
        'Avis de marchés publics UE en équipements médicaux (TED, CPV 33)',
        'ted', 'hard', 'mensuelle', 'nombre d''avis', 'certifie', NULL,
        'La demande publique adressée au secteur médical, comptée à la source : le nombre d''avis de marchés publiés chaque mois au journal des marchés publics européens pour des équipements et fournitures médicaux. En amont des commandes et des flux commerciaux, à fraîcheur immédiate. Se lit en tendance — un décompte d''avis n''est pas un volume en francs.')
ON CONFLICT (indicator_id) DO NOTHING;

INSERT INTO indicator_watch_questions (indicator_id, watch_question_code)
VALUES ('M7', 'QV2'), ('M7', 'QV5')
ON CONFLICT DO NOTHING;

-- Sept fenêtres mensuelles 2026. Corps statiques : les bornes font
-- partie de la liaison, donc de l'audit.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note)
SELECT 'M7', 'json_generique',
       'https://api.ted.europa.eu/v3/notices/search',
       jsonb_build_object(
         '_methode', 'POST',
         '_corps', jsonb_build_object(
           'query', 'classification-cpv IN (33100000) AND publication-date >= ' || f.debut || ' AND publication-date < ' || f.fin,
           'limit', 1,
           'fields', jsonb_build_array('publication-number')
         )
       ),
       jsonb_build_object('champ_scalaire', 'totalNoticeCount', 'periode_fixe', f.periode),
       'EU', 'a_verifier',
       'Fenêtre mensuelle TED CPV 33, décompte via totalNoticeCount (mode scalaire du 20.08.2026). ' ||
       CASE WHEN f.periode = '2026-07'
            THEN 'Réponse réelle VUE le 20.08.2026 : 6 239 avis.'
            ELSE 'Réponse réelle à voir avant activation (boucle de contrôle en fin de migration).' END
FROM (VALUES
  ('2026-01', '20260101', '20260201'),
  ('2026-02', '20260201', '20260301'),
  ('2026-03', '20260301', '20260401'),
  ('2026-04', '20260401', '20260501'),
  ('2026-05', '20260501', '20260601'),
  ('2026-06', '20260601', '20260701'),
  ('2026-07', '20260701', '20260801')
) AS f(periode, debut, fin)
ON CONFLICT (indicator_id, connecteur, url_base, params) DO NOTHING;

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. M7 certifié, 7 fenêtres a_verifier, QV2 et QV5'
SELECT i.indicator_id, i.status,
       (SELECT count(*) FROM source_bindings b WHERE b.indicator_id = 'M7') AS fenetres,
       (SELECT string_agg(watch_question_code, ',' ORDER BY watch_question_code)
          FROM indicator_watch_questions WHERE indicator_id = 'M7') AS questions
FROM indicators i WHERE i.indicator_id = 'M7';

\echo ''
\echo '--- 2. Décompte : 30 indicateurs, 26 certifiés'
SELECT count(*) AS indicateurs, count(*) FILTER (WHERE status = 'certifie') AS certifies
FROM indicators;

\echo ''
\echo '--- 3. Le registre n''est pas touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;

-- =====================================================================
-- CONTRÔLE AVANT ACTIVATION — les six fenêtres non vues, en une boucle :
--
-- for m in "20260101 20260201" "20260201 20260301" "20260301 20260401" \
--          "20260401 20260501" "20260501 20260601" "20260601 20260701"; do
--   set -- $m
--   curl -s -X POST "https://api.ted.europa.eu/v3/notices/search" \
--     -H "Content-Type: application/json" \
--     -d "{\"query\": \"classification-cpv IN (33100000) AND publication-date >= $1 AND publication-date < $2\", \"limit\": 1, \"fields\": [\"publication-number\"]}" \
--     | python3 -c "import json,sys; print('$1 :', json.load(sys.stdin).get('totalNoticeCount'))"
-- done
--
-- Attendu : six décomptes du même ordre de grandeur que juillet (6 239).
-- Puis : activation_M7_2026-08-20.sql.
-- =====================================================================
