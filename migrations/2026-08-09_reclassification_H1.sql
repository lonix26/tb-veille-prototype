-- =====================================================================
-- Reclassification de H1 — alignement sur le re-sourcing Comtrade
--
-- Décision de qualification de l'étudiant, 09.08.2026. H1 « Exportations
-- horlogères suisses par marché de destination » était sourcé sur la
-- Fédération de l'industrie horlogère (FH), qui ne publie que des PDF sous
-- des noms de fichiers à date encodée sans motif stable — non automatisable.
--
-- La migration des liaisons Comtrade (2026-08-09_bindings_comtrade.sql) a
-- re-sourcé H1 sur UN Comtrade (chapitre SH 91, déclarant Suisse, ventilé
-- par marché partenaire, mensuel). H1 RESTE donc un hard data automatisable :
-- il n'est PAS reclassé en composite. La FH est conservée comme référence de
-- branche au tableau de confiance, mais n'est plus la source de H1.
--
-- Cette migration aligne le référentiel (`indicators`, `sources`) sur cette
-- décision. Le décompte des certifiés reste 21 hard / 1 composite : A2
-- demeure l'unique composite certifié.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-09_reclassification_H1.sql
--
-- Non destructive pour le registre : aucune écriture dans indicator_values.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- H1 : source FH -> UN Comtrade, unité mio CHF -> USD (valeur Comtrade en USD,
-- comme H3/M1/A4/S6). Reste hard, mensuel — définition et criticité inchangées.
UPDATE indicators
SET source_id = 'comtrade',
    unit      = 'USD'
WHERE indicator_id = 'H1';

-- Source FH : reclassée « PDF / communiqués » — elle ne publie que du PDF.
-- Conservée au tableau de confiance comme référence de branche ; n'étant plus
-- rattachée à aucun indicateur, elle y figure désormais sans indicateur.
-- La date de qualification reflète l'acte humain de reclassification du 09.08.
UPDATE sources
SET format       = 'PDF / communiqués',
    qualified_at = '2026-08-09'
WHERE source_id = 'fh';

COMMIT;

-- =====================================================================
-- Vérifications — attendus énoncés avant exécution
-- =====================================================================

\echo ''
\echo '--- 1. H1 aligné sur Comtrade, resté hard, en USD'
\echo '    Attendu : source_id = comtrade, category = hard, unit = USD.'
SELECT indicator_id, source_id, category, frequency, unit
FROM indicators WHERE indicator_id = 'H1';

\echo ''
\echo '--- 2. Source FH reclassée, désormais référence de branche sans indicateur'
\echo '    Attendu : format = PDF / communiqués, 0 indicateur rattaché.'
SELECT s.source_id, s.format, s.url,
       count(i.indicator_id) AS indicateurs_rattaches
FROM sources s
LEFT JOIN indicators i ON i.source_id = s.source_id
WHERE s.source_id = 'fh'
GROUP BY s.source_id, s.format, s.url;

\echo ''
\echo '--- 3. Décompte des certifiés inchangé : A2 reste l''unique composite'
\echo '    Attendu : 21 hard, 1 composite.'
SELECT category, count(*) AS certifies
FROM indicators WHERE status = 'certifie'
GROUP BY category ORDER BY category;

\echo ''
\echo '--- 4. Le registre n''a pas été touché'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
