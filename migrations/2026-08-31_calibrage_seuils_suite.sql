-- =====================================================================
-- Calibrage des seuils de matérialité (RI4) — suite du 10.08.2026
--
-- ARBITRÉ EN SESSION le 31.08.2026 avec l'étudiant, sur la matière
-- recalculée le jour même (v_metriques, glissements annuels absolus :
-- n, moyenne, p90, maximum, nombre de valeurs négatives par indicateur).
--
-- PORTÉE. La migration du 10.08 traitait les onze indicateurs alors
-- pourvus d'historique. Treize indicateurs certifiés sont restés sans
-- seuil depuis — A11 et la famille transversale T5-T10, créés ou
-- alimentés après coup. Celle-ci les traite, et elle les traite en
-- TROIS familles, parce que la mesure de leur volatilité montre que le
-- pourcentage de variation n'est pas partout le bon instrument.
--
-- MÉTHODE, inchangée là où elle s'applique : seuil ≈ p90 des glissements
-- annuels absolus observés (un franchissement ≈ 1 observation sur 10).
-- Là où elle ne s'applique PAS, aucun seuil n'est posé et l'absence est
-- ÉNONCÉE dans note_conception — mécanisme déjà utilisé par T4, servi
-- par l'API de restitution et affiché sur la page Fiabilité. Un seuil
-- absent mais tu serait une surdéclaration par omission.
--
-- Les seuils restent des choix datés et révisables. Toute révision
-- ultérieure passe par une nouvelle migration, jamais par un UPDATE
-- silencieux.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-31_calibrage_seuils_suite.sql \
--     | tee "../annexe_5/calibrage_seuils_suite_2026-08-31.txt"
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ---------------------------------------------------------------------
-- FAMILLE 1 — Séries calibrables : la méthode du 10.08 s'applique telle quelle.
-- ---------------------------------------------------------------------

-- A7, brevets en technologies de transport bas carbone (dénombrement, DEU).
-- n = 48 · moyenne 23,9 % · p90 57,1 % · max 107,8 %. Série de comptage à
-- forte amplitude ; le p90 arrondi vers le bas retient l'événement rare.
UPDATE indicators SET alert_threshold_pct = 55 WHERE indicator_id = 'A7';

-- M6, brevets en technologie médicale à l'OEB (dénombrement, CHE).
-- n = 48 · moyenne 10,6 % · p90 22,4 % · max 61,5 %. Même famille qu'A7,
-- amplitude deux fois moindre : le seuil suit la série, pas l'inverse.
UPDATE indicators SET alert_threshold_pct = 22 WHERE indicator_id = 'M6';

-- T6, baromètre conjoncturel KOF (indice, CHE).
-- n = 32 · moyenne 5,9 % · p90 14,7 % · max 16,5 %. Historique court, seuil
-- posé au p90 et signalé comme provisoire — même prudence que H1 le 11.08.
UPDATE indicators SET alert_threshold_pct = 15 WHERE indicator_id = 'T6';

-- T7, production de l'usinage et du traitement des métaux (indice, UE).
-- n = 138 · moyenne 6,1 % · p90 10,1 % · max 66,5 %. Série longue et sage :
-- le p90 y est directement exploitable.
UPDATE indicators SET alert_threshold_pct = 10 WHERE indicator_id = 'T7';

-- T9, taux d'utilisation des capacités de l'industrie UE (pourcentage).
-- n = 47 · moyenne 2,8 % · p90 4,4 % · max 19,9 %. Seule part dont le
-- glissement reste borné — elle oscille autour de 80 % et ne s'approche
-- jamais de zéro : l'effet de base qui disqualifie A11 et T10 ne joue pas ici.
UPDATE indicators SET alert_threshold_pct = 4.5 WHERE indicator_id = 'T9';

-- ---------------------------------------------------------------------
-- FAMILLE 2 — Soldes d'opinion : le pourcentage de variation est un
-- artefact. Aucun seuil, et l'absence est dite.
-- ---------------------------------------------------------------------

UPDATE indicators
   SET alert_threshold_pct = NULL,
       note_conception = trim(both E'\n' from coalesce(note_conception, '') || E'\n\n' || $txt$MATÉRIALITÉ EN POURCENTAGE INAPPLICABLE, ÉNONCÉE (arbitrage du 31.08.2026). La série est un solde d'opinion : elle admet des valeurs négatives et passe par zéro (T8 : 119 valeurs négatives sur 139 ; T5 : 6 sur 140). Un glissement exprimé en pourcentage y produit des artefacts — maximum observé 18 200 % pour T8, 19 300 % pour T5 — qui décrivent le franchissement de zéro, non un événement conjoncturel. C'est la conséquence arithmétique du drapeau admet_negatifs déjà déclaré sur cette liaison. Aucun seuil n'est donc posé : RI4 est inapplicable à cette série, et le dispositif le dit plutôt que d'alerter sur du bruit. Un seuil exprimé en POINTS serait l'instrument juste ; il est documenté comme perspective, non implémenté dans cette itération.$txt$)
 WHERE indicator_id IN ('T5', 'T8');

-- ---------------------------------------------------------------------
-- FAMILLE 3 — Parts dominées par l'effet de base : même sort, autre motif.
-- ---------------------------------------------------------------------

UPDATE indicators
   SET alert_threshold_pct = NULL,
       note_conception = trim(both E'\n' from coalesce(note_conception, '') || E'\n\n' || $txt$MATÉRIALITÉ EN POURCENTAGE INAPPLICABLE, ÉNONCÉE (arbitrage du 31.08.2026). La série est une part, et son glissement en pourcentage est dominé par l'effet de base : A11 affiche une moyenne de 53 % et un p90 de 118 % parce que la part électrique croît depuis une base très faible, T10 une moyenne de 24 % et un p90 de 53 %. Un franchissement y décrirait une croissance régulière, pas un événement. Aucun seuil n'est posé, pour le même motif de fond que les soldes d'opinion : le pourcentage de variation n'est pas l'instrument de cette série. L'écart en POINTS est documenté comme perspective, non implémenté dans cette itération.$txt$)
 WHERE indicator_id IN ('A11', 'T10');

-- ---------------------------------------------------------------------
-- FAMILLE 4 — Pas encore calibrables : l'historique manque, on le dit.
-- ---------------------------------------------------------------------

UPDATE indicators
   SET alert_threshold_pct = NULL,
       note_conception = trim(both E'\n' from coalesce(note_conception, '') || E'\n\n' || $txt$SEUIL NON CALIBRABLE À CE JOUR, ÉNONCÉ (constat du 31.08.2026). Aucun glissement annuel n'est calculable sur cette série : elle n'a pas encore d'homologue à douze mois. Le seuil reste absent jusqu'à ce que l'historique le permette — il n'est pas posé par défaut, un seuil semé mais jamais confronté aux données n'étant qu'une valeur plausible. À reprendre lorsque la série atteindra deux cycles annuels.$txt$)
 WHERE indicator_id IN ('M7', 'M8', 'S7');

COMMIT;

-- =====================================================================
-- Vérifications
-- =====================================================================

\echo ''
\echo '--- 1. Seuils posés par cette migration'
\echo '    Attendu : A7 55 · M6 22 · T6 15 · T7 10 · T9 4,5.'
SELECT indicator_id, left(label, 46) AS libelle, alert_threshold_pct
  FROM indicators
 WHERE indicator_id IN ('A7','M6','T6','T7','T9')
 ORDER BY indicator_id;

\echo ''
\echo '--- 2. Absences de seuil ÉNONCÉES (et non tues)'
\echo '    Attendu : 7 lignes — T5, T8 (soldes) · A11, T10 (parts) · M7, M8, S7 (historique).'
SELECT indicator_id,
       alert_threshold_pct AS seuil,
       CASE
         WHEN note_conception LIKE '%INAPPLICABLE, ÉNONCÉE%' THEN 'inapplicable, énoncée'
         WHEN note_conception LIKE '%NON CALIBRABLE%'        THEN 'non calibrable, énoncé'
       END AS enonce
  FROM indicators
 WHERE indicator_id IN ('T5','T8','A11','T10','M7','M8','S7')
 ORDER BY indicator_id;

\echo ''
\echo '--- 3. Contrôle de complétude : indicateurs certifiés sans seuil NI énoncé'
\echo '    Attendu : aucune ligne, hors T4 (traité le 10.08).'
SELECT indicator_id, sector_code, left(label, 46) AS libelle
  FROM indicators
 WHERE status = 'certifie'
   AND alert_threshold_pct IS NULL
   AND indicator_id <> 'T4'
   AND coalesce(note_conception, '') NOT LIKE '%INAPPLICABLE, ÉNONCÉE%'
   AND coalesce(note_conception, '') NOT LIKE '%NON CALIBRABLE%'
 ORDER BY indicator_id;

\echo ''
\echo '--- 4. Effet sur les signaux : franchissements sur la dernière observation'
SELECT indicator_id, geo, period,
       COALESCE(glissement_annuel_pct, variation_periode_pct) AS glissement,
       seuil_materialite_pct, diffusable
  FROM v_alertes_candidates a
 WHERE EXISTS (SELECT 1 FROM v_dernier_point d
               WHERE d.indicator_id = a.indicator_id
                 AND d.geo = a.geo AND d.period = a.period)
 ORDER BY indicator_id, geo;
