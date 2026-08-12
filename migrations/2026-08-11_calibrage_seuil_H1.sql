-- =====================================================================
-- Calibrage du seuil de matérialité de H1 — complément du calibrage
-- général du 10.08 (2026-08-10_calibrage_seuils.sql)
--
-- H1 avait été volontairement laissé de côté : sa série s'arrêtait à
-- 2024-03 (fenêtre de test) et aucune volatilité n'était calculable.
-- La fenêtre complète 2023-01..2026-05 étant collectée (451 lignes,
-- activation du 11.08), la mesure existe désormais :
--
--   n = 319 glissements · moyenne absolue 13,7 % · p90 28,2 % · max 171,2 %
--   (v_metriques, mesuré le 11.08.2026 — sortie à conserver en annexe 5)
--
-- Le seuil semé (5 %) est très en dessous du bruit de la série : les
-- exportations mensuelles par pays de destination sont nerveuses (petits
-- marchés, effets de calendrier). Il produisait 9 des 15 signaux courants.
--
-- SEUIL RETENU : 25 % — juste sous le p90, arrondi. Motif : un
-- franchissement redevient un événement (~1 observation sur 10), en
-- conservant un peu de sensibilité pour l'agrégat monde, structurellement
-- plus calme que les marchés pris un à un.
--
-- LIMITE ASSUMÉE, à porter au § 12.5 : le seuil est unique par indicateur,
-- toutes zones confondues. Un seuil par zone (le monde n'a pas la
-- volatilité de Singapour) serait plus juste ; c'est une évolution de
-- schéma (seuil porté par le couple indicateur × zone), documentée en
-- perspective, non réalisée dans cette itération.
--
-- L'EXÉCUTION VAUT DÉCISION (N. Castillo). Toute révision ultérieure
-- passe par une nouvelle migration datée, jamais par un UPDATE silencieux.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-11_calibrage_seuil_H1.sql \
--     | tee ../annexe_5/calibrage_seuil_H1_2026-08-11.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE indicators SET alert_threshold_pct = 25 WHERE indicator_id = 'H1';

COMMIT;

-- =====================================================================
-- Vérifications
-- =====================================================================

\echo ''
\echo '--- Seuil H1 après calibrage. Attendu : 25.'
SELECT indicator_id, label, alert_threshold_pct FROM indicators WHERE indicator_id = 'H1';

\echo ''
\echo '--- Signaux courants restants, par indicateur.'
\echo '    Attendu : H1 réduit à ses seuls mouvements réellement atypiques.'
SELECT a.indicator_id, a.geo, a.period,
       COALESCE(a.glissement_annuel_pct, a.variation_periode_pct) AS glissement,
       a.seuil_materialite_pct
FROM v_alertes_candidates a
WHERE EXISTS (SELECT 1 FROM v_dernier_point d
              WHERE d.indicator_id = a.indicator_id AND d.geo = a.geo AND d.period = a.period)
ORDER BY a.indicator_id, a.geo;
