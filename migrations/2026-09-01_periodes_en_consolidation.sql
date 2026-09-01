-- =====================================================================
-- PÉRIODES EN CONSOLIDATION À LA SOURCE — 01.09.2026
--
-- CONSTAT. L'écran automobile signalait « A7 · France, 2022 : -74,7 % ».
-- Vérification sur la base, pas sur l'intuition : les SIX pays de la
-- série s'effondrent ensemble sur 2021 puis 2022 (moyenne des six :
-- 534 → 535 → 347 → 190 de 2019 à 2022 ; DEU 674 → 275 → 133 ; USA
-- 848 → 504 → 238). Un effondrement synchrone de 35 puis 45 % sur six
-- économies n'est pas une conjoncture, c'est la troncature connue des
-- comptages de brevets par date de priorité : les dépôts se publient
-- dix-huit mois après, l'OCDE prévient que les dernières années sont
-- incomplètes. Le -74,7 % de la France n'était pas un signal.
--
-- L'historique des runs ne pouvait pas le montrer : quatorze runs du
-- 24.08 au 01.09 lisent le même instantané annuel de l'OCDE (valeurs
-- identiques au centième). C'est la structure de la série, pas son
-- évolution entre runs, qui le prouve.
--
-- RÈGLE. Ce n'est PAS une règle de restitution mais une règle de
-- DÉTECTION — elle n'est juste qu'aux trois conditions posées avant de
-- l'écrire :
--   1. DÉCLARÉE : colonne `indicators.periodes_incompletes_source`,
--      déclaration humaine par indicateur, jamais présumée (doctrine
--      admet_negatifs / sens_favorable / geo_reference — quatrième cas).
--   2. VISIBLE : v_metriques marque ces périodes `periode_en_consolidation`
--      et l'énonce dans `completude` et dans `franchissement` ; la note
--      de conception le dit à l'écran du référentiel.
--   3. CONSERVATRICE : la valeur reste au registre. Seul le signalement
--      RI4 est différé — la période sortira de la consolidation d'elle-
--      même quand des périodes plus récentes l'auront poussée.
--
-- Nombre déclaré pour A7 : DEUX, pas trois — 2020 est plat par rapport à
-- 2019 (534 → 535) ; ne pas taire plus que ce que la série prouve.
--
-- SEUIL RECALIBRÉ. Le p90 du 31.08 (55 %, n = 48) incluait les chutes
-- tronquées de 2021-2022, c'est-à-dire l'artefact lui-même. Sur les
-- périodes complètes (≤ 2020) : n = 36 · moyenne 17,6 % · p90 38,1 % ·
-- max 107,8 %. Méthode du 10.08 inchangée : p90 arrondi vers le bas.
--
-- DÉRIVE CORRIGÉE AU PASSAGE. La note de conception d'A7 affirmait
-- encore « seuil laissé nul à dessein » alors que le calibrage du 31.08
-- l'avait fixé à 55 : un texte contredisait la base. Le texte est
-- réécrit — la base fait foi.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE indicators ADD COLUMN IF NOT EXISTS periodes_incompletes_source smallint;
COMMENT ON COLUMN indicators.periodes_incompletes_source IS 'Nombre de périodes en queue de série que la source publie INCOMPLÈTES par construction (comptages par date de priorité, déclarations en retard). DÉCLARATION HUMAINE, jamais présumée — quatrième application de la doctrine admet_negatifs. NULL = aucune. Effet : v_metriques marque ces périodes « en consolidation », RI4 n''y signale rien ; la valeur reste au registre, seul le signalement est différé. Déclaré le 01.09.2026 pour A7 (OCDE, brevets : effondrement synchrone des six pays sur les deux dernières années).';

UPDATE indicators
   SET periodes_incompletes_source = 2,
       alert_threshold_pct = 38,
       note_conception = 'Zone de référence DEU — premier déposant européen et premier débouché de la sous-traitance automobile suisse.

SEUIL DE MATÉRIALITÉ 38 % (recalibré le 01.09.2026 sur les périodes complètes, n = 36, p90 38,1 %). Le calibrage du 31.08 (55 %) incluait les deux dernières années, tronquées à la source.

DEUX DERNIÈRES PÉRIODES EN CONSOLIDATION, déclarées le 01.09.2026 : l''OCDE compte les dépôts par date de priorité et les publie dix-huit mois plus tard ; les deux dernières années d''un instantané sont incomplètes par construction. Constaté sur la série : les six pays chutent ensemble de 35 % puis 45 % sur 2021-2022, 2020 est plat. Sur ces périodes la valeur est conservée au registre mais rien n''est signalé (RI4 différé) — un « -74,7 % » de la France y était un artefact, pas un signal.

HORS SCORE DE SANTÉ, par construction et non par élagage : le dernier point disponible est 2022. Un score de position cyclique calculé au 25.08.2026 sur une série qui s''arrête quatre ans plus tôt figerait la position du secteur sur un état périmé. L''indicateur répond à QV4, question de dynamique technologique dont l''horizon est pluriannuel, et à elle seule.

HORS VITRINE le 25.08.2026 — dernier point en 2022 : la source publie avec un retard qui la rend inutilisable en conjoncture.'
 WHERE indicator_id = 'A7';

CREATE OR REPLACE VIEW public.v_metriques AS
 WITH base AS (
         SELECT c_1.indicator_id,
            c_1.indicator_label,
            c_1.sector_code,
            c_1.category,
            c_1.unit,
            c_1.period,
            c_1.geo,
            c_1.value,
            c_1.validation_status,
            c_1.obtained_by,
            c_1.source_organisation,
            c_1.source_url,
            c_1.raw_ref,
            c_1.run_id,
            c_1.executed_at,
            i.frequency,
            i.alert_threshold_pct,
            i.periodes_incompletes_source,
            dense_rank() OVER (PARTITION BY c_1.indicator_id ORDER BY c_1.period DESC) AS rang_depuis_fin
           FROM (public.v_current c_1
             JOIN public.indicators i ON ((i.indicator_id = c_1.indicator_id)))
        ), fenetres AS (
         SELECT b.indicator_id,
            b.indicator_label,
            b.sector_code,
            b.category,
            b.unit,
            b.period,
            b.geo,
            b.value,
            b.validation_status,
            b.obtained_by,
            b.source_organisation,
            b.source_url,
            b.raw_ref,
            b.run_id,
            b.executed_at,
            b.frequency,
            b.alert_threshold_pct,
            b.periodes_incompletes_source,
            b.rang_depuis_fin,
            lag(b.value) OVER w AS valeur_periode_precedente,
            lag(b.period) OVER w AS periode_precedente,
            avg(b.value) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS mm_12,
            count(b.value) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS n_12,
            min(b.period) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS debut_12,
            avg(b.value) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mm_4,
            count(b.value) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS n_4,
            min(b.period) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS debut_4
           FROM base b
          WINDOW w AS (PARTITION BY b.indicator_id, b.geo ORDER BY b.period)
        ), rapproche AS (
         SELECT f.indicator_id,
            f.indicator_label,
            f.sector_code,
            f.category,
            f.unit,
            f.period,
            f.geo,
            f.value,
            f.validation_status,
            f.obtained_by,
            f.source_organisation,
            f.source_url,
            f.raw_ref,
            f.run_id,
            f.executed_at,
            f.frequency,
            f.alert_threshold_pct,
            f.periodes_incompletes_source,
            f.rang_depuis_fin,
            f.valeur_periode_precedente,
            f.periode_precedente,
            f.mm_12,
            f.n_12,
            f.debut_12,
            f.mm_4,
            f.n_4,
            f.debut_4,
            public.periode_annee_precedente(f.period) AS periode_homologue,
            a.value AS valeur_annee_precedente,
                CASE f.frequency
                    WHEN 'mensuelle'::text THEN f.mm_12
                    WHEN 'trimestrielle'::text THEN f.mm_4
                    ELSE NULL::numeric
                END AS moyenne_mobile_annuelle,
                CASE f.frequency
                    WHEN 'mensuelle'::text THEN f.n_12
                    WHEN 'trimestrielle'::text THEN f.n_4
                    ELSE NULL::bigint
                END AS nb_points_moyenne,
                CASE f.frequency
                    WHEN 'mensuelle'::text THEN 12
                    WHEN 'trimestrielle'::text THEN 4
                    ELSE NULL::integer
                END AS nb_points_attendus,
                CASE f.frequency
                    WHEN 'mensuelle'::text THEN f.debut_12
                    WHEN 'trimestrielle'::text THEN f.debut_4
                    ELSE NULL::text
                END AS debut_fenetre
           FROM (fenetres f
             LEFT JOIN base a ON (((a.indicator_id = f.indicator_id) AND (a.geo = f.geo) AND (a.period = public.periode_annee_precedente(f.period)))))
        ), calcule AS (
         SELECT r.indicator_id,
            r.indicator_label,
            r.sector_code,
            r.category,
            r.unit,
            r.period,
            r.geo,
            r.value,
            r.validation_status,
            r.obtained_by,
            r.source_organisation,
            r.source_url,
            r.raw_ref,
            r.run_id,
            r.executed_at,
            r.frequency,
            r.alert_threshold_pct,
            r.periodes_incompletes_source,
            r.rang_depuis_fin,
            r.valeur_periode_precedente,
            r.periode_precedente,
            r.mm_12,
            r.n_12,
            r.debut_12,
            r.mm_4,
            r.n_4,
            r.debut_4,
            r.periode_homologue,
            r.valeur_annee_precedente,
            r.moyenne_mobile_annuelle,
            r.nb_points_moyenne,
            r.nb_points_attendus,
            r.debut_fenetre,
                CASE
                    WHEN ((r.valeur_periode_precedente IS NULL) OR (r.valeur_periode_precedente = (0)::numeric)) THEN NULL::numeric
                    ELSE round((((r.value - r.valeur_periode_precedente) / abs(r.valeur_periode_precedente)) * (100)::numeric), 2)
                END AS variation_periode_pct,
                CASE
                    WHEN ((r.valeur_annee_precedente IS NULL) OR (r.valeur_annee_precedente = (0)::numeric)) THEN NULL::numeric
                    ELSE round((((r.value - r.valeur_annee_precedente) / abs(r.valeur_annee_precedente)) * (100)::numeric), 2)
                END AS glissement_annuel_pct,
                CASE
                    WHEN ((r.moyenne_mobile_annuelle IS NULL) OR (r.moyenne_mobile_annuelle = (0)::numeric)) THEN NULL::numeric
                    ELSE round((((r.value - r.moyenne_mobile_annuelle) / abs(r.moyenne_mobile_annuelle)) * (100)::numeric), 2)
                END AS ecart_a_la_moyenne_pct
           FROM rapproche r
        )
 SELECT indicator_id,
    indicator_label,
    sector_code,
    category,
    frequency,
    unit,
    period,
    geo,
    value,
    periode_precedente,
    valeur_periode_precedente,
    variation_periode_pct,
    periode_homologue,
    valeur_annee_precedente,
    glissement_annuel_pct,
    round(moyenne_mobile_annuelle, 2) AS moyenne_mobile_annuelle,
    nb_points_moyenne,
    nb_points_attendus,
    debut_fenetre,
    ecart_a_la_moyenne_pct,
    alert_threshold_pct AS seuil_materialite_pct,
        CASE
            WHEN ((periodes_incompletes_source IS NOT NULL) AND (rang_depuis_fin <= periodes_incompletes_source)) THEN 'non signale : periode en consolidation a la source'::text
            WHEN (alert_threshold_pct IS NULL) THEN 'seuil non configure'::text
            WHEN (glissement_annuel_pct IS NOT NULL) THEN
            CASE
                WHEN (abs(glissement_annuel_pct) >= alert_threshold_pct) THEN 'franchi'::text
                ELSE 'sous le seuil'::text
            END
            WHEN (variation_periode_pct IS NOT NULL) THEN
            CASE
                WHEN (abs(variation_periode_pct) >= alert_threshold_pct) THEN 'franchi (variation de periode, faute de glissement)'::text
                ELSE 'sous le seuil (variation de periode, faute de glissement)'::text
            END
            ELSE 'indeterminable'::text
        END AS franchissement,
    validation_status,
    obtained_by,
    source_organisation,
    source_url,
    raw_ref,
    run_id,
    executed_at,
    TRIM(BOTH ' '::text FROM concat_ws(' · '::text,
        CASE
            WHEN (periode_homologue IS NULL) THEN 'glissement annuel impossible : format de periode non reconnu'::text
            ELSE NULL::text
        END,
        CASE
            WHEN ((periode_homologue IS NOT NULL) AND (valeur_annee_precedente IS NULL)) THEN (('glissement annuel indisponible : periode '::text || periode_homologue) || ' absente du registre'::text)
            ELSE NULL::text
        END,
        CASE
            WHEN (nb_points_attendus IS NULL) THEN ('moyenne mobile annuelle non applicable : serie '::text || frequency)
            ELSE NULL::text
        END,
        CASE
            WHEN ((nb_points_attendus IS NOT NULL) AND (nb_points_moyenne < nb_points_attendus)) THEN ((((('moyenne mobile partielle : '::text || nb_points_moyenne) || ' point(s) sur '::text) || nb_points_attendus) || ', depuis '::text) || debut_fenetre)
            ELSE NULL::text
        END,
        CASE
            WHEN (alert_threshold_pct IS NULL) THEN 'seuil de materialite non configure (RI4 inapplicable)'::text
            ELSE NULL::text
        END,
        CASE
            WHEN ((periodes_incompletes_source IS NOT NULL) AND (rang_depuis_fin <= periodes_incompletes_source)) THEN ((('periode en consolidation a la source : les '::text || periodes_incompletes_source) || ' derniere(s) periode(s) sont declarees incompletes, aucun signalement (RI4 differe)'::text))
            ELSE NULL::text
        END)) AS completude,
    periodes_incompletes_source,
    ((periodes_incompletes_source IS NOT NULL) AND (rang_depuis_fin <= periodes_incompletes_source)) AS periode_en_consolidation
   FROM calcule c;

COMMIT;

\echo '--- Vérification 1 : déclaration posée'
SELECT indicator_id, periodes_incompletes_source, alert_threshold_pct FROM indicators WHERE periodes_incompletes_source IS NOT NULL;

\echo '--- Vérification 2 : périodes marquées en consolidation (attendu : A7, 2021 et 2022, six zones)'
SELECT indicator_id, period, count(*) AS zones, min(franchissement) AS franchissement
  FROM v_metriques WHERE periode_en_consolidation GROUP BY 1,2 ORDER BY 1,2;

\echo '--- Vérification 3 : plus aucun franchissement d''A7 sur 2021-2022 ; ceux des périodes complètes'
\echo '    restent (historique, hors dernier point, donc hors API) ; autres indicateurs inchangés (attendu : 0 | 4331)'
SELECT count(*) FILTER (WHERE indicator_id = 'A7' AND period >= '2021') AS a7_tronquees,
       count(*) FILTER (WHERE indicator_id <> 'A7') AS autres FROM v_alertes_candidates;
SELECT geo, period, glissement_annuel_pct FROM v_alertes_candidates WHERE indicator_id = 'A7' ORDER BY period;

\echo '--- Vérification 4 : la valeur reste au registre (attendu : FRA 2022 = 54,33)'
SELECT geo, period, value, completude FROM v_metriques WHERE indicator_id = 'A7' AND geo = 'FRA' AND period = '2022';

\echo '--- Vérification 5 : nombre de lignes de v_metriques inchangé (attendu : 10497)'
SELECT count(*) FROM v_metriques;
