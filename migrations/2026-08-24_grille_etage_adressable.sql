-- ============================================================================
-- REFONTE DE LA GRILLE SUR L'ÉTAGE ADRESSABLE — N. Castillo, 24.08.2026
--
-- MOTIF, établi par l'analyse du registre et fondé au § 5.5.
-- La grille mesurait presque exclusivement le MARCHÉ FINAL : immatriculations
-- de véhicules, exportations de montres finies, dépenses militaires, objets
-- lancés dans l'espace. Or le destinataire du dispositif ne vend pas au marché
-- final : il vend des pièces usinées à un donneur d'ordre. Entre les deux, trois
-- étages de chaîne, six à dix-huit mois de décalage, et une décision de faire ou
-- faire faire qui domine le signal.
--
-- Le dispositif l'avait d'ailleurs diagnostiqué tout seul : le commentaire
-- automobile du 24.08 constate que « ce marché final porteur ne se retrouve pas
-- dans la demande adressable » — sans pouvoir le mesurer, faute d'indicateur à
-- l'étage où la demande s'exprime.
--
-- CE QUE LA REFONTE AJOUTE. Sept indicateurs, tous VÉRIFIÉS EN RÉPONSE RÉELLE
-- le 24.08.2026 avant déclaration, tous sur des connecteurs déjà en service :
--   · la production de la BRANCHE CLIENTE de chaque secteur (NACE précise) ;
--   · l'enquête de conjoncture européenne — carnets de commandes, utilisation
--     des capacités, et facteurs limitant la production — qui sont les
--     instruments canoniques du suivi industriel à court terme et que le § 5.2
--     nommait sans qu'aucun n'ait été instrumenté ;
--   · l'activité manufacturière suisse, écosystème du cas d'illustration.
--
-- PROFONDEUR CONSTATÉE À LA VÉRIFICATION : 138 à 151 points depuis 2014 pour
-- chacun. C'est davantage que la quasi-totalité de la grille existante.
--
-- CE QUI N'EST PAS SUPPRIMÉ, ET POURQUOI. Aucun indicateur existant n'est
-- retiré. Les flux de commerce et les indicateurs de marché final restent :
-- ils portent la dynamique géographique (QV3), que les indices de production
-- ne donnent pas. Ils changent de rôle, non de statut — de mesure de la demande
-- à mesure du contexte. L'écart entre les deux étages devient lui-même une
-- lecture (§ 5.5).
-- ============================================================================

BEGIN;

-- ── Branches clientes : la demande adressée, à l'étage où elle s'exprime ─────

INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency,
                        unit, status, alert_threshold_pct, description_metier,
                        sens_favorable, latence, geo_reference)
VALUES
('A6','automobile',
 'Production d''équipements automobiles UE (NACE C29.3)','eurostat','hard','mensuelle',
 'indice','certifie',6,
 'LA DEMANDE ADRESSABLE DE LA SOUS-TRAITANCE AUTOMOBILE, à l''étage où elle '
 's''exprime. C29.3 est la fabrication d''équipements pour véhicules — le métier des '
 'donneurs d''ordre d''un atelier d''usinage. À comparer systématiquement à A5 '
 '(C29, fabrication de véhicules) : l''écart entre les deux mesure la transmission '
 'du marché final vers la sous-traitance, et un écart qui se creuse signale que le '
 'marché final ne se transmet plus.',
 1,'coincident','EU27_2020'),

('H6','horlogerie',
 'Production horlogère UE (NACE C26.52)','eurostat','hard','mensuelle',
 'indice','certifie',6,
 'L''activité de la branche cliente elle-même, et non ses exportations. Une '
 'exportation est une valeur en monnaie, sensible au change et au mix de gamme ; '
 'un indice de production mesure le VOLUME fabriqué, qui commande directement la '
 'charge d''usinage. Le secteur horloger ne disposait jusqu''ici que de flux de '
 'commerce et d''un point d''emploi de 2023.',
 1,'coincident','EU27_2020'),

('S8','aerospatial',
 'Production aéronautique et spatiale UE (NACE C30.3)','eurostat','hard','mensuelle',
 'indice','certifie',6,
 'L''activité de la branche cliente. Le secteur aérospatial n''était instrumenté que '
 'par des flux de commerce, des dépenses militaires et un décompte d''objets lancés '
 '— aucune mesure de ce que la branche PRODUIT, donc de ce qu''elle commande.',
 1,'coincident','EU27_2020'),

-- ── Socle : les instruments canoniques du suivi industriel à court terme ─────

('T8','transversal',
 'État du carnet de commandes de l''industrie UE (enquête de conjoncture)','eurostat','hard','mensuelle',
 'solde','certifie',NULL,
 'L''INDICATEUR AVANCÉ QUE LA GRILLE N''AVAIT PAS. Solde d''opinion des industriels '
 'sur l''état de leur carnet, publié à J+0 sans révision. Un carnet qui se dégarnit '
 'précède la baisse de production de plusieurs mois — c''est la variable que lit un '
 'directeur d''atelier avant toute statistique. Grandeur INTENSIVE et légitimement '
 'négative : ne jamais la sommer ni la traiter comme un flux.',
 1,'avance','EU27_2020'),

('T9','transversal',
 'Taux d''utilisation des capacités de l''industrie UE','eurostat','hard','trimestrielle',
 'pourcentage','certifie',NULL,
 'Mesure la marge de production disponible dans la branche. Un taux élevé annonce '
 'des investissements et des reports de charge vers la sous-traitance ; un taux bas '
 'signale que les donneurs d''ordre peuvent internaliser ce qu''ils sous-traitaient. '
 'C''est le mécanisme du « faire ou faire faire » (§ 5.5), rendu observable.',
 1,'coincident','EU27_2020'),

('T10','transversal',
 'Part des industriels déclarant la demande comme facteur limitant (UE)','eurostat','hard','trimestrielle',
 'pourcentage','certifie',NULL,
 'SIGNAL PRÉCOCE DE RETOURNEMENT. Part des entreprises citant l''insuffisance de la '
 'demande parmi les freins à leur production. Elle monte avant que les carnets ne se '
 'vident et bien avant que la production ne recule. SENS INVERSÉ : une hausse est '
 'défavorable — d''où sens_favorable = -1.',
 -1,'avance','EU27_2020'),

('T11','transversal',
 'Production manufacturière suisse (NACE C)','eurostat','hard','mensuelle',
 'indice','certifie',5,
 'L''activité industrielle de l''écosystème du cas d''illustration. La ventilation par '
 'branche n''est pas disponible pour la Suisse dans cette source — vérifié le '
 '24.08.2026, la série existe pour l''ensemble manufacturier et pour lui seul. '
 'Sert de repère national face à l''agrégat européen.',
 1,'coincident','CH')
ON CONFLICT (indicator_id) DO NOTHING;

-- ── Rattachement aux questions de veille : aucun indicateur orphelin ─────────
INSERT INTO indicator_watch_questions (indicator_id, watch_question_code) VALUES
('A6','QV1'), ('A6','QV2'),
('H6','QV1'),
('S8','QV1'),
('T8','QV0'), ('T9','QV0'), ('T10','QV0'), ('T11','QV0')
ON CONFLICT DO NOTHING;

COMMIT;

SELECT sector_code, count(*) AS indicateurs, count(*) FILTER (WHERE status='certifie') AS certifies
FROM indicators GROUP BY 1
UNION ALL SELECT '— TOTAL —', count(*), count(*) FILTER (WHERE status='certifie') FROM indicators
ORDER BY 1;
