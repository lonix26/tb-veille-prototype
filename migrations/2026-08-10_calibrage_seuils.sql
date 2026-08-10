-- =====================================================================
-- Calibrage des seuils de matérialité (RI4) — § 6 bis, suite n° 2
--
-- PRÉPARÉE le 10.08.2026 sur la base de la reconnaissance des volatilités
-- (annexe_5/reconnaissance_volatilites_2026-08-10.txt). L'EXÉCUTION VAUT
-- DÉCISION : relire chaque valeur, corriger ce qui ne convient pas, puis
-- exécuter. La décision est un acte de qualification de l'étudiant —
-- cette migration en est la proposition instruite, pas le substitut.
--
-- MÉTHODE. Point de départ : p90 des glissements annuels absolus observés
-- (un franchissement ≈ 1 observation sur 10 dans l'historique), arrondi,
-- puis corrigé par un jugement métier énoncé ligne par ligne. Les seuils
-- semés au référentiel (5/10/15 %) étaient des valeurs plausibles jamais
-- confrontées aux données ; la première exécution de la couche de lecture
-- (10.08 : 33 franchissements, tous diffusables) a montré qu'ils ne
-- discriminaient pas.
--
-- Les seuils restent des choix datés et révisables. Toute révision
-- ultérieure passe par une nouvelle migration, jamais par un UPDATE
-- silencieux — la trace des révisions fait partie de la thèse.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-10_calibrage_seuils.sql \
--     | tee ../annexe_5/calibrage_seuils_2026-08-10.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Flux commerciaux annuels en USD courants (Comtrade). p90 observés :
-- A4 6,8 · H3 9,7. Sous 10 %, le mouvement est indiscernable de l'effet
-- de change et de l'inflation ; un sous-traitant n'a pas à en être dérangé.
UPDATE indicators SET alert_threshold_pct = 10 WHERE indicator_id IN ('A4', 'H3');

-- Production industrielle UE, indice mensuel (Eurostat). p90 observé : 9,5.
-- Même famille de bruit ; 10 % aligne l'amont (production) sur les flux.
UPDATE indicators SET alert_threshold_pct = 10 WHERE indicator_id = 'A5';

-- Médical (Comtrade M1, Eurostat M2). p90 observés : 13,1 et 12,2.
UPDATE indicators SET alert_threshold_pct = 12 WHERE indicator_id IN ('M1', 'M2');

-- Franc suisse (BNS). p90 observé : 8,8. Seuil volontairement ABAISSÉ sous
-- le p90 : le change touche directement la marge d'un exportateur, le coût
-- d'une fausse alerte y est plus faible que celui d'un signal manqué.
UPDATE indicators SET alert_threshold_pct = 7 WHERE indicator_id = 'T2';

-- Commerce aéronautique et spatial (Comtrade S6). p90 observé : 22,0.
-- Série courte (12 points) et heurtée ; seuil haut assumé, à revoir quand
-- l'historique s'allonge.
UPDATE indicators SET alert_threshold_pct = 20 WHERE indicator_id = 'S6';

-- Objets lancés (S3). p90 observé : 80,0 — série structurellement erratique
-- (petits dénombrements par pays). Un seuil en pourcentage y est un
-- instrument limité : limite énoncée au § 12.5, seuil posé au p90 faute
-- de mieux dans cette itération.
UPDATE indicators SET alert_threshold_pct = 80 WHERE indicator_id = 'S3';

-- CLI G20 (OCDE, T1). Maximum observé : 0,8 — l'ancien seuil de 2 % ne se
-- serait jamais déclenché. Un indice de tendance bouge par dixièmes.
-- Le signal le plus parlant (passage sous 100) relève d'un futur attribut
-- niveau_reference, hors de cette migration.
UPDATE indicators SET alert_threshold_pct = 0.5 WHERE indicator_id = 'T1';

-- T4 (PIB mondial) : reste sans seuil. Deux points de comparaison — tout
-- seuil serait fictif. RI4 inapplicable, dit tel quel par le tableau de bord.
UPDATE indicators SET alert_threshold_pct = NULL WHERE indicator_id = 'T4';

COMMIT;

-- =====================================================================
-- Vérifications
-- =====================================================================

\echo ''
\echo '--- Seuils après calibrage'
\echo '    Attendu : T1 0,5 · T2 7 · A4/A5/H3 10 · M1/M2 12 · S6 20 · S3 80 · T4 NULL.'
SELECT indicator_id, label, alert_threshold_pct
FROM indicators
WHERE indicator_id IN ('T1','T2','T4','A4','A5','H1','H3','M1','M2','S3','S6')
ORDER BY indicator_id;

\echo ''
\echo '--- Effet sur les signaux : franchissements sur la dernière observation'
\echo '    Attendu : une poignée, plus 33. Chaque ligne restante est un événement.'
SELECT indicator_id, geo, period,
       COALESCE(glissement_annuel_pct, variation_periode_pct) AS glissement,
       seuil_materialite_pct, diffusable
FROM v_alertes_candidates a
WHERE EXISTS (SELECT 1 FROM v_dernier_point d
              WHERE d.indicator_id = a.indicator_id
                AND d.geo = a.geo AND d.period = a.period)
ORDER BY indicator_id, geo;
