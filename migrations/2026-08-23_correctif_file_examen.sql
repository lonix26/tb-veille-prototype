-- =====================================================================
-- Correctif — v_flux_a_examiner doublée par l'ajout de la doctrine
--
-- DÉFAUT INTRODUIT LE 23.08.2026 par la migration
-- 2026-08-23_triage_doctrine_signal.sql : la vue joignait flux_triage_ia
-- sans filtrer la doctrine. Depuis que chaque item porte DEUX scores (un
-- par doctrine), la file d'examen affiche chaque item deux fois — 344
-- items produisaient 688 lignes, et le compteur « items en attente
-- d'examen » de l'écran 1 aurait affiché le double.
--
-- Correctif : une jointure par doctrine, une ligne par item. L'ordre de
-- lecture suit la doctrine « signal » quand elle existe (antériorité puis
-- portée), avec repli sur la pertinence événementielle — la doctrine
-- signal est la meilleure des deux, il serait absurde de trier la file
-- humaine avec l'ancienne.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- La vue gagne des colonnes en position médiane : CREATE OR REPLACE refuse.
-- DROP sans CASCADE, pour qu'une dépendance éventuelle fasse échouer la
-- migration plutôt que d'être supprimée en silence.
DROP VIEW IF EXISTS v_flux_a_examiner;

CREATE VIEW v_flux_a_examiner AS
SELECT fi.item_id, fs.famille, fs.libelle AS flux,
       COALESCE(s.sector_code, e.sector_code)                   AS sector_code,
       COALESCE(s.watch_question_code, e.watch_question_code)   AS watch_question_code,
       e.pertinence,                       -- doctrine « evenement », conservée telle quelle
       s.anteriorite, s.portee,
       s.pertinence AS pertinence_signal,
       COALESCE(s.resume, e.resume)        AS resume,
       fi.titre, fi.url, fi.date_publication, fi.collecte_le
FROM flux_items fi
JOIN flux_sources fs ON fs.flux_id = fi.flux_id
LEFT JOIN flux_triage_ia e ON e.item_id = fi.item_id AND e.doctrine = 'evenement'
LEFT JOIN flux_triage_ia s ON s.item_id = fi.item_id AND s.doctrine = 'signal'
WHERE NOT EXISTS (SELECT 1 FROM flux_examens x WHERE x.item_id = fi.item_id)
ORDER BY s.anteriorite DESC NULLS LAST, s.portee DESC NULLS LAST,
         e.pertinence DESC NULLS LAST, fi.date_publication DESC;

COMMENT ON VIEW v_flux_a_examiner IS
  'File de lecture du veilleur, UNE ligne par item. Porte les scores des deux doctrines côte à côte ; l''ordre suit la doctrine « signal » (antériorité, puis portée) avec repli sur la pertinence événementielle. Corrigée le 23.08.2026 : la version précédente joignait flux_triage_ia sans filtrer la doctrine et doublait chaque item.';

COMMIT;

-- Vérification — V18 : une ligne par item non examiné, ni plus ni moins.
SELECT 'V18' AS verif,
       (SELECT count(*) FROM flux_items fi
         WHERE NOT EXISTS (SELECT 1 FROM flux_examens x WHERE x.item_id=fi.item_id)) AS items_non_examines,
       (SELECT count(*) FROM v_flux_a_examiner) AS lignes_de_la_vue;
