-- ============================================================================
-- Correction de deux URL périmées au référentiel des sources — 24.08.2026
--
-- Constat : la vérification systématique des 25 URL du référentiel, conduite
-- en vue de la bibliographie des sources de données, a rendu deux liens morts.
-- Ils auraient été publiés tels quels dans le rapport. Un travail dont la thèse
-- est la traçabilité ne peut pas citer des liens qu'il n'a pas testés.
--
-- Les URL de remplacement sont celles que les LIAISONS de collecte utilisent
-- déjà et qui répondent en 200 — la source de vérité était donc dans la base,
-- à un autre endroit qu'où le rapport allait la chercher.
-- ============================================================================

BEGIN;

-- 404 sur https://www.cpb.nl/en/worldtrademonitor. L'URL de la liaison T3
-- répond et redirige vers le dernier millésime publié.
UPDATE sources
   SET url = 'https://www.cpb.nl/en/worldtrademonitor/latest',
       notes = coalesce(notes || ' · ', '')
             || 'URL corrigée le 24.08.2026 : l''ancienne (…/en/worldtrademonitor) '
             || 'renvoyait 404. La nouvelle redirige vers le millésime courant.'
 WHERE source_id = 'cpb';

-- Erreur TLS sur https://milex.sipri.org. Le portail des bases répond en 200.
UPDATE sources
   SET url = 'https://www.sipri.org/databases/milex',
       notes = coalesce(notes || ' · ', '')
             || 'URL corrigée le 24.08.2026 : l''ancienne (milex.sipri.org) '
             || 'échouait à la négociation TLS. Adresse alignée sur celle de la liaison S4.'
 WHERE source_id = 'sipri';

COMMIT;

SELECT source_id, url FROM sources WHERE source_id IN ('cpb', 'sipri') ORDER BY source_id;
