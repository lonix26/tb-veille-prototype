-- ============================================================================
-- S7 ET M8 PORTÉS AU COLLECTEUR — N. Castillo, 25.08.2026.
--
-- CONSTAT À L'ORIGINE. L'audit d'automatisation du 25.08 a montré que deux
-- indicateurs sur trente-six ne se collectaient PAS par l'orchestrateur : ils
-- dépendaient d'un script exécuté à la main. Leurs liaisons existaient au
-- référentiel mais portaient un mapping rédigé en langage humain — « périodes :
-- mois de la fenêtre », « champ_scalaire : somme(results[].count) » — que le
-- collecteur ne sait pas lire. La déclaration décrivait donc une intention et
-- non un traitement, et rien ne le signalait.
--
-- EXIGENCE À TENIR : déployer les workflows doit suffire. Un dispositif de
-- veille dont une partie se collecte à la main n'est pas un dispositif de
-- veille, c'est une procédure.
--
-- S7 — comptage mensuel d'avis de marchés publics européens, CPV 347. Même
-- méthode que M7 (CPV 33), certifiée le 20.08 : une liaison par mois glissant,
-- avec les jetons résolus à l'exécution. Aucun code nouveau.
--
-- M8 — comptage mensuel d'autorisations FDA 510(k). A exigé DEUX extensions du
-- collecteur, écrites le même jour :
--   · les jetons sont désormais résolus DANS L'URL DE BASE — openFDA veut un
--     intervalle « [debut+TO+fin] » dont le signe + ne doit pas être encodé, ce
--     qui interdit de passer les bornes en paramètres de requête ;
--   · un jeton MOIS_FIN_INCLUSIF donne le DERNIER jour du mois, l'intervalle
--     d'openFDA étant inclusif — y passer le 1er du mois suivant compterait un
--     jour de trop ;
--   · un mode de décodage `somme_champ` additionne une liste de comptages
--     quotidiens en une valeur mensuelle. Sommer est un calcul, donc du code.
--
-- FENÊTRE : douze mois glissants. Le mois courant n'est jamais demandé, il est
-- incomplet — règle déjà tenue par M7 et par tout le collecteur.
-- ============================================================================

BEGIN;

DELETE FROM source_bindings WHERE indicator_id IN ('S7','M8');

-- S7 : douze liaisons, une par mois révolu.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut,
                             statut, verifie_par, verifie_le, note)
SELECT 'S7', 'json_generique',
       'https://api.ted.europa.eu/v3/notices/search',
       jsonb_build_object(
         '_methode','POST',
         '_corps', jsonb_build_object(
            'query', 'classification-cpv IN (34700000) AND publication-date >= {{MOIS_DEBUT:' || k ||
                     '}} AND publication-date < {{MOIS_FIN:' || k || '}}',
            'limit', 1,
            'fields', jsonb_build_array('publication-number'))),
       jsonb_build_object('periode_fixe','{{PERIODE:' || k || '}}',
                          'champ_scalaire','totalNoticeCount'),
       'EU','actif','N. Castillo',now(),
       'Porté au collecteur le 25.08.2026 — mois glissant −' || k || '. Même méthode que M7, '
       'certifiée le 20.08.2026 sur le CPV 33. Remplace collecte_comptages.py, supprimé.'
FROM generate_series(1, 12) AS k;

-- M8 : douze liaisons également, sur l'URL entière à jetons.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut,
                             statut, verifie_par, verifie_le, note)
SELECT 'M8', 'json_generique',
       'https://api.fda.gov/device/510k.json?search=decision_date:[{{MOIS_DEBUT:' || k ||
       '}}+TO+{{MOIS_FIN_INCLUSIF:' || k || '}}]&count=decision_date',
       '{"_methode":"GET"}'::jsonb,
       jsonb_build_object('chemin_donnees','results',
                          'somme_champ','count',
                          'periode_fixe','{{PERIODE:' || k || '}}'),
       'US','actif','N. Castillo',now(),
       'Porté au collecteur le 25.08.2026 — mois glissant −' || k || '. L''URL porte les bornes '
       'en clair parce que le signe + de « +TO+ » ne doit pas être encodé : les jetons sont donc '
       'résolus dans l''URL de base, extension écrite le même jour. La réponse liste un comptage '
       'par jour ; la valeur mensuelle est leur somme, calculée par le décodeur. '
       'Remplace collecte_comptages.py, supprimé.'
FROM generate_series(1, 12) AS k;

COMMIT;

SELECT indicator_id, count(*) AS liaisons, min(url_base) AS exemple_url
FROM source_bindings WHERE indicator_id IN ('S7','M8') GROUP BY 1;
