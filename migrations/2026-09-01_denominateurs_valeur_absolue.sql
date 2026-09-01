-- =====================================================================
-- v_metriques : les dénominateurs passent en VALEUR ABSOLUE
--
-- BOGUE TROUVÉ à l'audit des calculs du 01.09.2026, réel et mesuré :
-- les trois ratios (variation de période, glissement annuel, écart à la
-- moyenne) divisaient par la valeur BRUTE. Pour une série admettant des
-- négatifs, le dénominateur négatif INVERSE LE SIGNE du ratio.
-- Cas constaté : T8 (carnet UE) valeur -19,7, moyenne mobile -22,09 —
-- le carnet est AU-DESSUS de sa moyenne (il s'améliore), mais l'écart
-- affiché était -10,83 % : l'indice de diffusion de l'écran Anticiper le
-- classait DÉFAVORABLE à tort, le compte « 19 des 26 » aurait dû être
-- 20, et la narration « les défavorables sont ceux du métier — le
-- carnet… » reposait en partie sur ce signe inversé.
--
-- Le projet connaissait le piège (« PIÈGE DE LECTURE, DÉCLARÉ » sur
-- T8/T10, drapeau admet_negatifs, seuils NULL) mais l'avait neutralisé
-- pour la RÈGLE D'ALERTE seulement — pas pour le SIGNE, que l'indice de
-- diffusion et les cartes consomment. Diviser par |dénominateur| rend la
-- DIRECTION exacte partout ; l'ampleur d'un ratio sur base négative reste
-- un instrument limité (la lecture en POINTS reste la bonne, les notes le
-- disent toujours), mais un instrument limité qui pointe du bon côté.
-- Les séries à base positive — la quasi-totalité — sont inchangées.
--
-- Les notes de conception de T8 et T10 citaient le symptôme ancien
-- (« exprime en -34,5 % ») : mises à jour, la citation devenant fausse.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW v_metriques AS
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
            i.alert_threshold_pct
           FROM v_current c_1
             JOIN indicators i ON i.indicator_id = c_1.indicator_id
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
            f.valeur_periode_precedente,
            f.periode_precedente,
            f.mm_12,
            f.n_12,
            f.debut_12,
            f.mm_4,
            f.n_4,
            f.debut_4,
            periode_annee_precedente(f.period) AS periode_homologue,
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
           FROM fenetres f
             LEFT JOIN base a ON a.indicator_id = f.indicator_id AND a.geo = f.geo AND a.period = periode_annee_precedente(f.period)
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
                    WHEN r.valeur_periode_precedente IS NULL OR r.valeur_periode_precedente = 0::numeric THEN NULL::numeric
                    ELSE round((r.value - r.valeur_periode_precedente) / abs(r.valeur_periode_precedente) * 100::numeric, 2)
                END AS variation_periode_pct,
                CASE
                    WHEN r.valeur_annee_precedente IS NULL OR r.valeur_annee_precedente = 0::numeric THEN NULL::numeric
                    ELSE round((r.value - r.valeur_annee_precedente) / abs(r.valeur_annee_precedente) * 100::numeric, 2)
                END AS glissement_annuel_pct,
                CASE
                    WHEN r.moyenne_mobile_annuelle IS NULL OR r.moyenne_mobile_annuelle = 0::numeric THEN NULL::numeric
                    ELSE round((r.value - r.moyenne_mobile_annuelle) / abs(r.moyenne_mobile_annuelle) * 100::numeric, 2)
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
            WHEN alert_threshold_pct IS NULL THEN 'seuil non configure'::text
            WHEN glissement_annuel_pct IS NOT NULL THEN
            CASE
                WHEN abs(glissement_annuel_pct) >= alert_threshold_pct THEN 'franchi'::text
                ELSE 'sous le seuil'::text
            END
            WHEN variation_periode_pct IS NOT NULL THEN
            CASE
                WHEN abs(variation_periode_pct) >= alert_threshold_pct THEN 'franchi (variation de periode, faute de glissement)'::text
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
            WHEN periode_homologue IS NULL THEN 'glissement annuel impossible : format de periode non reconnu'::text
            ELSE NULL::text
        END,
        CASE
            WHEN periode_homologue IS NOT NULL AND valeur_annee_precedente IS NULL THEN ('glissement annuel indisponible : periode '::text || periode_homologue) || ' absente du registre'::text
            ELSE NULL::text
        END,
        CASE
            WHEN nb_points_attendus IS NULL THEN 'moyenne mobile annuelle non applicable : serie '::text || frequency
            ELSE NULL::text
        END,
        CASE
            WHEN nb_points_attendus IS NOT NULL AND nb_points_moyenne < nb_points_attendus THEN (((('moyenne mobile partielle : '::text || nb_points_moyenne) || ' point(s) sur '::text) || nb_points_attendus) || ', depuis '::text) || debut_fenetre
            ELSE NULL::text
        END,
        CASE
            WHEN alert_threshold_pct IS NULL THEN 'seuil de materialite non configure (RI4 inapplicable)'::text
            ELSE NULL::text
        END)) AS completude
   FROM calcule c;
;

UPDATE indicators
   SET note_conception = replace(note_conception,
     'que le calcul relatif exprime en -34,5 %',
     'que le calcul relatif exprimait en -34,5 % avant la correction du 01.09.2026 (dénominateur en valeur absolue : la direction est désormais exacte, l''ampleur reste à lire en points)')
 WHERE indicator_id IN ('T8','T10') AND note_conception LIKE '%exprime en -34,5%';

COMMIT;

\echo '--- Vérification : T8 avant/après sur la même ligne'
SELECT indicator_id, period, value, moyenne_mobile_annuelle, ecart_a_la_moyenne_pct,
       glissement_annuel_pct
FROM v_metriques WHERE indicator_id IN ('T8','T5') ORDER BY indicator_id, period DESC LIMIT 3;
\echo '--- Contrôle de non-régression : séries positives inchangées (échantillon)'
SELECT indicator_id, period, glissement_annuel_pct FROM v_metriques
WHERE indicator_id IN ('H7','A5','M1') AND glissement_annuel_pct IS NOT NULL
ORDER BY indicator_id, period DESC LIMIT 3;
