-- ============================================================================
-- BREVETS PAR DOMAINE TECHNOLOGIQUE — OCDE. N. Castillo, 25.08.2026.
--
-- VIDE COMBLÉ. L'audit de couverture du 24.08 a montré que la question de veille
-- QV4 — dynamique technologique — était la plus mal couverte de la grille, et
-- de criticité DOMINANTE dans trois secteurs. Les deux indicateurs prévus pour
-- elle, H4 et M6, étaient déclarés sur l'OMPI et n'avaient jamais été collectés :
-- l'export du producteur n'a pas de point d'accès programmable libre.
--
-- LA SOURCE RETENUE, et pourquoi elle plutôt qu'une autre. L'OCDE diffuse les
-- comptages de brevets par domaine technologique en API SDMX libre, SANS CLÉ —
-- et le dispositif interroge déjà l'OCDE pour l'indicateur avancé T1, donc sans
-- connecteur nouveau. L'alternative examinée, l'interface Open Patent Services
-- de l'Office européen des brevets, offre une granularité supérieure (recherche
-- par code CPC, donc l'horlogerie G04 serait atteignable) mais exige une
-- inscription et une clé OAuth : elle est notée en perspective, non retenue ici.
--
-- VÉRIFIÉ EN RÉPONSE RÉELLE le 25.08.2026 : 13 points annuels (2010→2022),
-- six zones dont la Suisse. Domaine MEDICAL — Suisse 689, États-Unis 4 381,
-- Allemagne 1 093. Domaine TRA — Suisse 35, Allemagne 133, Japon 340.
--
-- NATURE DE L'INDICATEUR, à ne pas confondre. Un comptage de brevets par date de
-- priorité se stabilise plusieurs années après le dépôt : le dernier point
-- disponible est 2022. Ce n'est donc PAS un indicateur conjoncturel et il ne doit
-- pas être lu comme tel. C'est une mesure de POSITION TECHNOLOGIQUE, dont
-- l'horizon utile se compte en années — exactement ce que QV4 demande, et rien
-- d'autre. Latence déclarée « retarde », seuil de matérialité laissé nul pour que
-- RI4 interdise au modèle de commenter les variations.
-- ============================================================================

BEGIN;

INSERT INTO sources (source_id, name, organisation, url, frequency, format, access,
                     qualification_status, qualified_by, qualified_at, notes)
VALUES ('ocde_brevets','Brevets par domaine technologique','OCDE',
        'https://data-explorer.oecd.org/vis?df[ag]=OECD.STI.PIE&df[id]=DSD_PATENTS@DF_PATENTS_OECDSPECIFIC',
        'annuelle','API SDMX','libre','certifiee','N. Castillo',DATE '2026-08-25',
        'Jeu DF_PATENTS_OECDSPECIFIC. Dix-huit domaines technologiques, dont MEDICAL et TRA '
        '(technologies de transport bas carbone). Sans clé. Vérifié en réponse réelle le '
        '25.08.2026 : 13 points annuels 2010-2022, 106 zones disponibles.')
ON CONFLICT (source_id) DO NOTHING;

-- M6 change de source : l'OMPI n'a jamais rendu de donnée, l'OCDE en rend.
UPDATE indicators
   SET source_id = 'ocde_brevets',
       label = 'Brevets en technologie médicale, dépôts à l''OEB (OCDE)',
       frequency = 'annuelle', unit = 'nombre', latence = 'retarde',
       alert_threshold_pct = NULL, sens_favorable = 1, geo_reference = 'CHE',
       description_metier =
'POSITION TECHNOLOGIQUE DE LA BRANCHE MÉDICALE, et non son activité. Comptage des '
'dépôts de brevets en technologie médicale, par pays du déposant. Un brevet précède '
'le produit de plusieurs années : c''est un indicateur de ce qui se PRÉPARE, pas de '
'ce qui se vend. Pour un sous-traitant, il renseigne sur le renouvellement des '
'générations d''instruments — donc sur le rythme auquel les plans, tolérances et '
'matériaux qu''on lui demandera vont changer.

À NE PAS LIRE COMME UN INDICATEUR CONJONCTUREL : le comptage par date de priorité se '
'stabilise des années après le dépôt, et le dernier point disponible est 2022. Le '
'seuil de matérialité est laissé nul à dessein, ce qui rend RI4 inapplicable et '
'interdit au modèle de commenter une variation. Zone de référence CHE : ce qui '
'intéresse un atelier neuchâtelois est la vitalité technologique de son écosystème.

CHANGEMENT DE SOURCE le 25.08.2026 : déclaré sur l''OMPI depuis le 06.08 et jamais '
'collecté, faute de point d''accès programmable libre chez ce producteur. L''OCDE '
'publie le même objet en API SDMX sans clé.'
 WHERE indicator_id = 'M6';

-- Nouvel indicateur : la technologie qui recompose la demande automobile.
INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency,
                        unit, status, alert_threshold_pct, description_metier,
                        sens_favorable, latence, geo_reference)
VALUES
('A7','automobile',
 'Brevets en technologies de transport bas carbone (OCDE)','ocde_brevets','hard','annuelle',
 'nombre','certifie',NULL,
 'CE QUI RECOMPOSE LA DEMANDE DE COMPOSANTS, à la racine. La question de veille QV4 '
 'automobile demande si l''électrification recompose la demande adressée à la '
 'sous-traitance ; A3 mesure les ventes de véhicules électriques, c''est-à-dire le '
 'RÉSULTAT, plusieurs années après la décision technique. Le comptage de brevets en '
 'technologies de transport bas carbone mesure la décision elle-même, au moment où '
 'elle est prise. Un basculement de l''effort de R&D précède de cinq à dix ans le '
 'changement des familles de pièces commandées.

À NE PAS LIRE COMME UN INDICATEUR CONJONCTUREL : dernier point 2022, seuil de '
 'matérialité nul à dessein (RI4 inapplicable). Zone de référence DEU — premier '
 'déposant européen et premier débouché de la sous-traitance automobile suisse.',
 1,'retarde','DEU')
ON CONFLICT (indicator_id) DO NOTHING;

INSERT INTO indicator_watch_questions (indicator_id, watch_question_code)
VALUES ('A7','QV4') ON CONFLICT DO NOTHING;

-- Liaisons : connecteur csv_generique, celui de T1.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut,
                             statut, verifie_par, verifie_le, note)
VALUES
('M6','csv_generique',
 'https://sdmx.oecd.org/public/rest/data/OECD.STI.PIE,DSD_PATENTS@DF_PATENTS_OECDSPECIFIC,1.0/6F0.A.AP.PATN.PRIORITY.CHE+DEU+USA+CHN+JPN+FRA...APPLICANT...MEDICAL',
 '{"format":"csvfilewithlabels","startPeriod":"2010"}'::jsonb,
 '{"colonne_code":"REF_AREA","colonne_valeur":"OBS_VALUE","colonne_periode":"TIME_PERIOD","periode_min":"2010"}'::jsonb,
 'CHE','actif','N. Castillo',now(),
 'Vu en réponse réelle le 25.08.2026 : 78 lignes, 13 périodes 2010-2022, six zones. '
 'Dernier point CHE 689,4 — la valeur est fractionnaire parce que l''OCDE attribue les '
 'brevets co-déposés au prorata des déposants, ce qui est la convention du producteur '
 'et non un artefact.'),
('A7','csv_generique',
 'https://sdmx.oecd.org/public/rest/data/OECD.STI.PIE,DSD_PATENTS@DF_PATENTS_OECDSPECIFIC,1.0/6F0.A.AP.PATN.PRIORITY.CHE+DEU+USA+CHN+JPN+FRA...APPLICANT...TRA',
 '{"format":"csvfilewithlabels","startPeriod":"2010"}'::jsonb,
 '{"colonne_code":"REF_AREA","colonne_valeur":"OBS_VALUE","colonne_periode":"TIME_PERIOD","periode_min":"2010"}'::jsonb,
 'DEU','actif','N. Castillo',now(),
 'Vu en réponse réelle le 25.08.2026 : 78 lignes, 13 périodes 2010-2022. Dernier point '
 'DEU 132,75, CHE 35,0, JPN 340,0.')
ON CONFLICT DO NOTHING;

COMMIT;

SELECT i.indicator_id, i.sector_code, i.geo_reference, b.statut,
       left(b.url_base, 62) AS url
FROM indicators i JOIN source_bindings b USING(indicator_id)
WHERE i.indicator_id IN ('M6','A7');
