-- =====================================================================
-- Migration du 07.08.2026 — socle déclaratif de collecte
--
-- Objet. Le § 10.6 décrit une architecture où l'ajout d'une source est
-- une opération de configuration et non de développement. Cette table la
-- matérialise : un indicateur, un connecteur, ses paramètres. Ajouter un
-- indicateur devient une LIGNE, plus un workflow.
--
-- Principe cardinal, hérité du § 8.2.1 : la qualification d'une source
-- n'est pas délégable. Une liaison n'est donc jamais активée par défaut.
-- Elle porte un statut, et le collecteur générique refuse de lire une
-- liaison dont les paramètres n'ont pas été vérifiés contre l'API réelle
-- par une personne nommée. C'est la transposition, au niveau de la
-- collecte, de la contrainte `qualified_by` qui protège le référentiel
-- des sources.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-07_socle_declaratif.sql
--
-- Non destructive : aucune écriture dans indicator_values.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS source_bindings (
    binding_id    BIGSERIAL PRIMARY KEY,
    indicator_id  TEXT NOT NULL REFERENCES indicators(indicator_id),
    connecteur    TEXT NOT NULL CHECK (connecteur IN (
                     'eurostat_jsonstat',   -- API de dissémination Eurostat, format JSON-stat 2.0
                     'owid_csv',            -- Our World in Data, CSV à colonnes nommées
                     'csv_generique',       -- CSV distant, colonnes à préciser dans params
                     'json_generique'       -- JSON distant, chemin d'accès à préciser dans params
                   )),
    url_base      TEXT NOT NULL,
    params        JSONB NOT NULL DEFAULT '{}'::jsonb,   -- paramètres de requête
    mapping       JSONB NOT NULL DEFAULT '{}'::jsonb,   -- colonnes/chemins de lecture
    geo_defaut    TEXT NOT NULL DEFAULT 'WORLD',
    statut        TEXT NOT NULL DEFAULT 'a_verifier'
                  CHECK (statut IN ('a_verifier','actif','suspendu')),
    verifie_par   TEXT,
    verifie_le    TIMESTAMPTZ,
    note          TEXT,

    -- Une liaison ne peut être активée sans vérification nominative et datée.
    -- Même exigence, même forme que pour la qualification des sources : la
    -- décision d'admettre une donnée au registre est humaine et imputable.
    CONSTRAINT chk_binding_verifie CHECK (
        statut <> 'actif' OR (verifie_par IS NOT NULL AND verifie_le IS NOT NULL)
    ),
    UNIQUE (indicator_id, connecteur, url_base, params)
);

COMMENT ON TABLE source_bindings IS
  'Socle déclaratif de collecte (§ 10.6). Ajouter un indicateur au flux est une configuration, non un développement. Aucune liaison n''est active sans vérification nominative de ses paramètres contre l''API réelle.';

COMMENT ON COLUMN source_bindings.statut IS
  'a_verifier : paramètres plausibles, jamais testés — le collecteur les ignore. actif : vérifiés sur pièce par la personne nommée. suspendu : source devenue inatteignable, conservée pour trace.';

-- Vue de travail : ce que le collecteur générique lit réellement.
CREATE OR REPLACE VIEW v_bindings_actifs AS
SELECT b.binding_id, b.indicator_id, i.label AS indicator_label, i.sector_code,
       i.frequency, i.unit, b.connecteur, b.url_base, b.params, b.mapping,
       b.geo_defaut, b.verifie_par, b.verifie_le
FROM source_bindings b
JOIN indicators i ON i.indicator_id = b.indicator_id
WHERE b.statut = 'actif'
ORDER BY i.sector_code, b.indicator_id;

COMMENT ON VIEW v_bindings_actifs IS
  'Le collecteur générique ne lit que cette vue. Une liaison non vérifiée n''est pas collectée — l''absence de donnée est préférable à une donnée dont on ignore d''où elle vient.';

-- ---------------------------------------------------------------------
-- Liaisons VÉRIFIÉES le 07.08.2026 contre les API réelles
-- ---------------------------------------------------------------------

-- A5 — production industrielle automobile UE. Paramètres vérifiés une
-- première fois le 06.08.2026, reconfirmés le 07.08 : 42 périodes
-- annoncées, 41 valeurs, la plus récente non encore publiée.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, verifie_par, verifie_le, note) VALUES
('A5', 'eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpr_m',
 '{"format":"JSON","lang":"FR","nace_r2":"C29","unit":"I21","s_adj":"SCA","geo":"EU27_2020","sinceTimePeriod":"2023-01"}'::jsonb,
 '{}'::jsonb, 'EU27_2020', 'actif', 'N. Castillo', '2026-08-07',
 'Libellés retournés par l''API : C29 = fabrication de véhicules automobiles, remorques et semi-remorques ; I21 = indice base 2021 ; SCA = désaisonnalisé et corrigé des jours ouvrables. Les deux dernières observations portent le drapeau « i » = valeur imputée par Eurostat.'),

-- M2 — production de l'industrie des instruments médicaux UE.
-- RÉSERVE EXPLICITE, à lever avant de publier au tableau de bord :
-- le § 8.4.2 spécifie la classe NACE C32.5 (instruments et fournitures
-- médicodentaires). La requête vérifiée porte sur C32 « Autres industries
-- manufacturières », agrégat qui CONTIENT C32.5 sans s'y réduire — il
-- comprend aussi la bijouterie, les instruments de musique, les articles
-- de sport et les jouets. La granularité collectée est donc plus grossière
-- que la granularité spécifiée. Deux issues possibles, l'une et l'autre
-- honnêtes, aucune ne pouvant être tranchée sans vérification :
--   (a) tester nace_r2=C32_5 ; si la série existe, corriger la liaison ;
--   (b) si elle n'existe pas dans ce jeu de données, requalifier M2 au
--       § 8.4.2 comme portant sur C32 et énoncer la limite.
-- La liaison reste 'a_verifier' tant que ce choix n'est pas fait.
('M2', 'eurostat_jsonstat',
 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpr_m',
 '{"format":"JSON","lang":"FR","nace_r2":"C32","unit":"I21","s_adj":"SCA","geo":"EU27_2020","sinceTimePeriod":"2023-01"}'::jsonb,
 '{}'::jsonb, 'EU27_2020', 'a_verifier', NULL, NULL,
 'Requête techniquement vérifiée le 07.08.2026 (41 valeurs retournées, série complète et cohérente). NON ACTIVÉE : C32 est un agrégat plus large que le C32.5 spécifié au § 8.4.2. Tester C32_5 avant activation, ou requalifier l''indicateur. La fréquence réelle est mensuelle, alors que le § 8.4.2 annonce trimestrielle — à corriger dans les deux cas.'),

-- S3 — objets lancés dans l'espace. Source Our World in Data reprenant
-- les données UNOOSA, conforme à la qualification du § 8.4.4.
('S3', 'owid_csv',
 'https://ourworldindata.org/grapher/yearly-number-of-objects-launched-into-outer-space.csv',
 '{"csvType":"full","useColumnShortNames":"true","v":"1"}'::jsonb,
 '{"colonne_entite":"entity","colonne_code":"code","colonne_periode":"year","colonne_valeur":"annual_launches","entites_retenues":["World","United States","China","Russia","United Kingdom","France","Germany","Japan","India"],"periode_min":"2023"}'::jsonb,
 'WORLD', 'actif', 'N. Castillo', '2026-08-07',
 'Structure vérifiée le 07.08.2026 : colonnes entity, code, year, annual_launches. L''entité « World » porte le code OWID_WRL. Série annuelle disponible jusqu''à 2025 inclus.');

-- ---------------------------------------------------------------------
-- Liaisons CANDIDATES — paramètres plausibles, jamais testés
--
-- Elles sont semées pour que le travail de vérification soit tracé et
-- ordonnancé, non pour être collectées. Le collecteur les ignore tant
-- que leur statut n'est pas passé à 'actif' par une personne nommée.
-- ---------------------------------------------------------------------
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note) VALUES

('M3', 'json_generique',
 'https://api.worldbank.org/v2/country/all/indicator/SH.XPD.CHEX.GD.ZS',
 '{"format":"json","date":"2023:2025","per_page":"500"}'::jsonb,
 '{"chemin_donnees":"[1]","colonne_periode":"date","colonne_valeur":"value","colonne_geo":"countryiso3code"}'::jsonb,
 'WORLD', 'a_verifier',
 'ATTENTION — REQUALIFICATION DE SOURCE REQUISE. Le § 8.4.2 qualifie l''OMS (base GHED) comme source de M3. La Banque mondiale REDIFFUSE ces données sous le code SH.XPD.CHEX.GD.ZS, avec un accès plus simple. Substituer l''une à l''autre n''est pas une décision technique : c''est une requalification de source, qui relève de la décision humaine tracée (§ 8.2.1) et doit être portée au tableau de confiance avant toute activation.'),

('S4', 'csv_generique',
 'https://www.sipri.org/databases/milex',
 '{}'::jsonb,
 '{"note":"URL de la page de base de données, non du fichier. Le lien de téléchargement direct est à relever manuellement."}'::jsonb,
 'WORLD', 'a_verifier',
 'SIPRI diffuse en Excel derrière une page de présentation. Le connecteur csv_generique ne conviendra pas tel quel : soit un export CSV existe et son URL est à relever, soit l''indicateur relève du traitement composite.'),

('A3', 'csv_generique',
 'https://www.iea.org/data-and-statistics/data-product/global-ev-outlook-2026',
 '{}'::jsonb,
 '{"note":"Global EV Data Explorer. URL de téléchargement direct à relever."}'::jsonb,
 'WORLD', 'a_verifier',
 'L''AIE distingue le rapport Global EV Outlook et l''explorateur Global EV Data Explorer. Le § 8.4.3 qualifie l''explorateur ; la bibliographie référence le rapport. Incohérence à trancher avant activation.'),

('H3', 'json_generique', 'https://comtradeapi.un.org/data/v1/get/C/A/HS',
 '{"cmdCode":"91","flowCode":"M","period":"2023,2024","reporterCode":"all"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","colonne_valeur":"primaryValue","colonne_geo":"reporterISO"}'::jsonb,
 'WORLD', 'a_verifier',
 'UN Comtrade impose désormais une clé d''abonnement, y compris sur son offre gratuite. À vérifier : existence d''un accès sans clé, quota applicable, et forme exacte du chemin de données. Les indicateurs H3, M1, A4 et S6 partagent ce connecteur : une seule vérification les débloque tous les quatre.'),

('M1', 'json_generique', 'https://comtradeapi.un.org/data/v1/get/C/A/HS',
 '{"cmdCode":"9018,9019,9020,9021,9022","flowCode":"M","period":"2023,2024","reporterCode":"all"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","colonne_valeur":"primaryValue","colonne_geo":"reporterISO"}'::jsonb,
 'WORLD', 'a_verifier', 'Voir la note de H3 — même connecteur, même vérification.'),

('A4', 'json_generique', 'https://comtradeapi.un.org/data/v1/get/C/A/HS',
 '{"cmdCode":"8708","flowCode":"M","period":"2023,2024","reporterCode":"all"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","colonne_valeur":"primaryValue","colonne_geo":"reporterISO"}'::jsonb,
 'WORLD', 'a_verifier', 'Voir la note de H3 — même connecteur, même vérification.'),

('S6', 'json_generique', 'https://comtradeapi.un.org/data/v1/get/C/A/HS',
 '{"cmdCode":"88","flowCode":"M","period":"2023,2024","reporterCode":"all"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","colonne_valeur":"primaryValue","colonne_geo":"reporterISO"}'::jsonb,
 'WORLD', 'a_verifier', 'Voir la note de H3 — même connecteur, même vérification.');

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. Liaisons semées, par statut'
\echo '    Attendu : 2 actives (A5, S3), 8 a_verifier.'
SELECT statut, count(*), string_agg(indicator_id, ', ' ORDER BY indicator_id) AS indicateurs
FROM source_bindings GROUP BY statut ORDER BY statut;

\echo ''
\echo '--- 2. Ce que le collecteur générique lira'
SELECT indicator_id, sector_code, connecteur, geo_defaut, verifie_par,
       to_char(verifie_le, 'DD.MM.YYYY') AS verifie_le
FROM v_bindings_actifs;

\echo ''
\echo '--- 3. Une liaison ne peut pas être active sans vérification tracée'
\echo '    Attendu : violation de chk_binding_verifie.'
INSERT INTO source_bindings (indicator_id, connecteur, url_base, statut)
VALUES ('T1', 'json_generique', 'https://exemple.invalide/test', 'actif');

\echo ''
\echo '--- 4. Le registre est intact'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
