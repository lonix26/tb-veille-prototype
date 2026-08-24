-- ============================================================================
-- BREVETS DU MÉTIER — OMPI, après l'échec du portail de l'OEB. 25.08.2026.
--
-- CONTEXTE. L'interface Open Patent Services de l'Office européen des brevets
-- aurait permis la recherche par code de classification, donc l'horlogerie
-- (CIB G04) et l'aérospatial (B64) isolés — les deux vides QV4 restants. Le
-- portail d'inscription n'a pas délivré de compte à l'étudiant. L'OMPI offre
-- une alternative en accès DIRECT, sans inscription.
--
-- CE QUE L'ALTERNATIVE NE REMPLACE PAS, et il faut le dire d'abord. L'OMPI
-- classe en 35 domaines, l'OEB en milliers de codes. La table de concordance
-- officielle, vérifiée le 25.08.2026, place la CIB G04 (horlogerie) dans le
-- domaine « Techniques de mesure » et la CIB B64 (aéronefs) dans « Transport ».
-- Les deux sont trop larges pour isoler ce qu'on cherchait : les vides QV4 de
-- l'horlogerie et de l'aérospatial RESTENT OUVERTS.
--
-- CE QU'ELLE APPORTE, QUE PERSONNE D'AUTRE NE DONNE ICI. Les domaines du MÉTIER
-- lui-même. « Technique de surface, revêtement » recouvre exactement la
-- nomenclature d'activité du destinataire — NACE C25.6, traitement et
-- revêtement des métaux, usinage. « Machines-outils » mesure la technologie de
-- ses moyens de production. Aucun autre indicateur de la grille ne descend à
-- cet étage : tous décrivent des marchés clients, aucun ne décrivait le métier.
--
-- PROFONDEUR : 23 points annuels (2000-2022), sept zones. C'est le plus long
-- historique de toute la grille.
--
-- HORS SCORE, comme M6 et A7 et pour la même raison : dernier point 2022.
-- ============================================================================

BEGIN;

INSERT INTO sources (source_id, name, organisation, url, frequency, format, access,
                     qualification_status, qualified_by, qualified_at, notes)
VALUES ('ompi_tech','Indicateurs de brevets par domaine technologique','OMPI',
        'https://www.wipo.int/en/web/ip-statistics','annuelle','ZIP / CSV','libre',
        'certifiee','N. Castillo',DATE '2026-08-25',
        'Archive wipo-data-patent-indicators.zip, téléchargement direct sans inscription. '
        'Comptages par année, office, pays d''origine et domaine technologique (35 domaines). '
        'Vérifié en réponse réelle le 25.08.2026 : 663 584 lignes, 2000-2022. Table de '
        'concordance CIB/domaine publiée séparément et consultée pour établir les limites de '
        'granularité — G04 tombe dans « Techniques de mesure », B64 dans « Transport ».')
ON CONFLICT (source_id) DO NOTHING;

INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency,
                        unit, status, alert_threshold_pct, description_metier,
                        sens_favorable, latence, geo_reference)
VALUES
('T12','transversal',
 'Brevets en technique de surface et revêtement (OMPI)','ompi_tech','hard','annuelle',
 'nombre','certifie',NULL,
 'LA TECHNOLOGIE DU MÉTIER, mesurée à la racine. Le domaine « Technique de surface, '
 'revêtement » de la nomenclature de l''OMPI recouvre exactement l''activité du '
 'destinataire du dispositif — NACE C25.6, traitement et revêtement des métaux, '
 'usinage. Tous les autres indicateurs de la grille décrivent des marchés CLIENTS ; '
 'celui-ci décrit le métier lui-même, et la comparaison entre pays dit où la '
 'capacité technique se construit. Suisse : 29 dépôts en 2000, 75 en 2022.

À NE PAS LIRE COMME UN INDICATEUR CONJONCTUREL : dernier point 2022, hors score de '
 'santé, seuil de matérialité nul à dessein (RI4 inapplicable).',
 0,'retarde','CH'),

('T13','transversal',
 'Brevets en machines-outils (OMPI)','ompi_tech','hard','annuelle',
 'nombre','certifie',NULL,
 'LA TECHNOLOGIE DES MOYENS DE PRODUCTION. Un atelier d''usinage vit de ses machines : '
 'le rythme auquel la technologie des machines-outils se renouvelle détermine la '
 'pression d''investissement qu''il subit, et la comparaison entre pays indique où se '
 'construit la capacité d''usinage qui lui fera concurrence. Suisse : 64 dépôts en '
 '2000, 99 en 2022.

À NE PAS LIRE COMME UN INDICATEUR CONJONCTUREL : dernier point 2022, hors score, '
 'seuil nul (RI4 inapplicable).',
 0,'retarde','CH')
ON CONFLICT (indicator_id) DO NOTHING;

INSERT INTO indicator_watch_questions (indicator_id, watch_question_code)
VALUES ('T12','QV0'), ('T13','QV0') ON CONFLICT DO NOTHING;

-- Connecteur script : l'archive est un ZIP, format qu'aucun connecteur de
-- l'orchestrateur ne traite. Même choix, même motif que la FH.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut,
                             statut, verifie_par, verifie_le, note)
SELECT c.code, 'pdf_tableau_script',
       'https://www.wipo.int/documents/d/ip-statistics/wipo-data-patent-indicators.zip',
       jsonb_build_object('fichier','dc_indicator_patent_4_publication_by_technology.csv',
                          'office','**','domaine', c.domaine),
       jsonb_build_object('colonne_periode','year','colonne_code','origin',
                          'colonne_valeur','count','periode_min','2000'),
       'CH','actif','N. Castillo',now(),
       'Vu en réponse réelle le 25.08.2026 : 161 points, sept zones, 2000-2022. Collecteur : '
       'prototype/collecteurs/collecte_ompi_technologies.py. Office « ** » = tous offices '
       'confondus, soit les dépôts d''un pays d''origine PARTOUT dans le monde — la bonne '
       'lecture pour mesurer la vitalité technologique d''un écosystème, et non ses seuls '
       'dépôts domestiques.'
FROM (VALUES ('T12','21'), ('T13','26')) AS c(code, domaine)
ON CONFLICT DO NOTHING;

COMMIT;

SELECT indicator_id, label, geo_reference, sens_favorable FROM indicators
WHERE indicator_id IN ('T12','T13');
