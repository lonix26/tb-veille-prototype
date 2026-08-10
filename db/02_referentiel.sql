-- =====================================================================
-- Référentiel — grille d'indicateurs du chapitre 8
--
-- Ce fichier est la source de vérité du décompte des indicateurs. Le
-- rapport en donnait trois valeurs contradictoires (I-6 de l'évaluation
-- critique) ; la vue v_bilan_referentiel le calcule désormais, et c'est
-- ce calcul qui doit être reporté dans le texte, jamais l'inverse.
-- =====================================================================

-- Questions génériques (niveau 1). Six questions depuis la révision du
-- 07.08.2026 : l'ancienne QV3 « dynamique géographique et innovation »
-- confondait deux interrogations distinctes — où le centre de gravité se
-- déplace, et quelle mutation technique recompose la demande. En
-- automobile, la montée de la Chine et l'électrification sont deux
-- phénomènes, avec des indicateurs et des horizons différents. La
-- scission les sépare ; « impulsions publiques » devient QV5.
INSERT INTO watch_questions (code, label, description) VALUES
 ('QV0','Attribution',              'Le mouvement observé sur un secteur est-il propre à ce secteur, ou porté par la conjoncture générale ?'),
 ('QV1','Santé structurelle',       'Comment évolue la substance de la branche : production, emploi, tissu d''entreprises ?'),
 ('QV2','Demande et débouchés',     'Où la demande mondiale croît-elle ou se contracte-t-elle ? Quels flux commerciaux se déplacent ?'),
 ('QV3','Dynamique géographique',   'Où le centre de gravité du secteur se déplace-t-il : quels pays produisent, importent ou accèdent à une capacité nouvelle ?'),
 ('QV4','Dynamique technologique',  'Quelle mutation technique recompose la demande de composants : quels procédés, matériaux ou architectures se substituent aux précédents ?'),
 ('QV5','Impulsions publiques',     'Quelle action publique — dépense, réglementation, condition d''accès — modifie le niveau ou la composition de la demande à moyen terme ?');

INSERT INTO sectors (code, label) VALUES
 ('transversal','Socle transversal'),
 ('horlogerie','Horlogerie'),
 ('medical','Médical'),
 ('automobile','Automobile'),
 ('aerospatial','Aérospatial');

-- ---------------------------------------------------------------------
-- Sources — qualification du § 8.2, tableau de confiance du § 8.3
-- ---------------------------------------------------------------------

INSERT INTO sources (source_id, name, organisation, url, frequency, format, access, qualification_status, qualified_by, notes) VALUES
 ('eurostat',       'Eurostat — statistiques conjoncturelles et structurelles', 'Commission européenne', 'https://ec.europa.eu/eurostat/data/database', 'mensuelle',   'API + CSV',        'libre',       'certifiee',   'N. Castillo', 'API de dissémination sans authentification'),
 ('ofs',            'STATENT et statistiques conjoncturelles',                  'Office fédéral de la statistique', 'https://www.bfs.admin.ch',        'annuelle',    'CSV / Excel',      'libre',       'certifiee',   'N. Castillo', 'Nomenclature NOGA'),
 ('comtrade',       'UN Comtrade — commerce international par code SH',         'Nations Unies',        'https://comtradeplus.un.org',              'annuelle',    'API + CSV',        'libre_quota', 'certifiee',   'N. Castillo', 'Quota sur l''API publique'),
 ('ocde',           'Principaux indicateurs économiques et CLI',                'OCDE',                 'https://data-explorer.oecd.org',           'mensuelle',   'API + CSV',        'libre',       'certifiee',   'N. Castillo', NULL),
 ('banque_mondiale','Séries macroéconomiques mondiales',                        'Banque mondiale',      'https://data.worldbank.org',               'annuelle',    'API + CSV',        'libre',       'certifiee',   'N. Castillo', NULL),
 ('ompi',           'Statistiques de propriété intellectuelle',                 'OMPI',                 'https://www.wipo.int/ipstats',             'annuelle',    'CSV',              'libre',       'certifiee',   'N. Castillo', 'Classification CIB'),
 ('sp_global_pmi',  'Indices PMI manufacturiers',                               'S&P Global',           'https://www.pmi.spglobal.com',             'mensuelle',   'Communiqués',      'payant',      'a_confirmer', 'N. Castillo', 'Indices détaillés payants ; valeurs de synthèse dans les communiqués'),
 ('fh',             'Statistiques d''exportation horlogère',                    'Fédération de l''industrie horlogère suisse', 'https://www.fhs.swiss', 'mensuelle', 'Web / PDF / CSV', 'libre',       'certifiee',   'N. Castillo', 'Détail par marché de destination'),
 ('deloitte',       'Swiss Watch Industry Study',                               'Deloitte',             'https://www.deloitte.com/ch',              'annuelle',    'PDF',              'libre',       'a_confirmer', 'N. Castillo', 'Étude annuelle, méthodologie déclarative'),
 ('oms_ghed',       'Global Health Expenditure Database',                       'OMS',                  'https://apps.who.int/nha/database',        'annuelle',    'API / CSV',        'libre',       'certifiee',   'N. Castillo', NULL),
 ('swiss_medtech',  'Swiss Medical Technology Industry report',                 'Swiss Medtech',        'https://www.swiss-medtech.ch',             'bisannuelle', 'PDF',              'libre',       'a_confirmer', 'N. Castillo', 'Publication bisannuelle, périodes non alignées sur la fenêtre 2023-2025'),
 ('oica',           'Statistiques de production automobile',                    'OICA',                 'https://www.oica.net/production-statistics','annuelle',   'Tableaux web',     'libre',       'certifiee',   'N. Castillo', NULL),
 ('acea',           'Immatriculations de véhicules neufs',                      'ACEA',                 'https://www.acea.auto',                    'mensuelle',   'PDF / communiqués','libre',       'certifiee',   'N. Castillo', 'Communiqués mensuels ; extraction nécessaire'),
 ('aie',            'Global EV Data Explorer',                                  'Agence internationale de l''énergie', 'https://www.iea.org',       'annuelle',    'CSV',              'libre',       'certifiee',   'N. Castillo', NULL),
 ('constructeurs',  'Commandes et livraisons d''avions commerciaux',            'Airbus, Boeing',       'https://www.airbus.com',                   'mensuelle',   'Web / Excel',      'libre',       'certifiee',   'N. Castillo', 'Deux producteurs à consolider'),
 ('iata',           'Air Passenger Market Analysis',                            'IATA',                 'https://www.iata.org',                     'mensuelle',   'PDF',              'libre',       'a_confirmer', 'N. Castillo', 'Séries détaillées réservées aux membres'),
 ('unoosa',         'Objets lancés dans l''espace',                             'UNOOSA / Our World in Data', 'https://ourworldindata.org/space-exploration-satellites', 'annuelle', 'CSV', 'libre', 'certifiee', 'N. Castillo', NULL),
 ('sipri',          'Military Expenditure Database',                            'SIPRI',                'https://milex.sipri.org',                  'annuelle',    'CSV',              'libre',       'certifiee',   'N. Castillo', NULL),
 ('esa',            'Budgets spatiaux publics',                                 'ESA et agences nationales', 'https://www.esa.int',                 'annuelle',    'PDF',              'libre',       'a_confirmer', 'N. Castillo', 'Formats hétérogènes selon les agences'),
 ('bns',            'Taux de change de référence',                              'Banque nationale suisse','https://data.snb.ch',                     'mensuelle',   'API / CSV',        'libre',       'certifiee',   'N. Castillo', NULL),
 ('cpb',            'World Trade Monitor',                                      'CPB Netherlands Bureau for Economic Policy Analysis', 'https://www.cpb.nl/en/worldtrademonitor', 'mensuelle', 'Excel', 'libre', 'certifiee', 'N. Castillo', NULL),
 ('fmi',            'World Economic Outlook',                                   'Fonds monétaire international', 'https://www.imf.org/en/Publications/WEO', 'semestrielle', 'CSV',    'libre',       'certifiee',   'N. Castillo', NULL);

-- ---------------------------------------------------------------------
-- Indicateurs
-- La contrainte différée trg_indicateur_sans_question impose que chaque
-- indicateur reçoive sa (ou ses) question(s) de veille dans la même
-- transaction : d'où le BEGIN/COMMIT explicite.
-- ---------------------------------------------------------------------

BEGIN;

INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency, unit, status, alert_threshold_pct) VALUES
 -- Socle transversal (QV0) — § 8.3.1
 ('T1','transversal','Indicateur composite avancé (CLI)',                                    'ocde',           'hard',      'mensuelle',    'indice',            'certifie',    2),
 ('T2','transversal','Taux de change CHF/USD et CHF/EUR',                                    'bns',            'hard',      'mensuelle',    'taux',              'certifie',    5),
 ('T3','transversal','Commerce mondial de marchandises (volume)',                            'cpb',            'hard',      'mensuelle',    'indice',            'certifie',    3),
 ('T4','transversal','Croissance du PIB mondial',                                            'fmi',            'hard',      'semestrielle', 'pourcentage',       'certifie',    NULL),

 -- Horlogerie — § 8.4.1
 ('H1','horlogerie','Exportations horlogères suisses par marché de destination',             'fh',             'hard',      'mensuelle',    'mio CHF',           'certifie',    5),
 ('H2','horlogerie','Emploi et établissements de la branche horlogère (NOGA 26.52)',         'ofs',            'hard',      'annuelle',     'nombre',            'certifie',    5),
 ('H3','horlogerie','Commerce mondial d''articles d''horlogerie (SH ch. 91), par pays',      'comtrade',       'hard',      'annuelle',     'USD',               'certifie',    5),
 ('H4','horlogerie','Dépôts de brevets en horlogerie (CIB G04)',                             'ompi',           'hard',      'annuelle',     'nombre',            'certifie',    10),
 ('H5','horlogerie','Climat de branche et perspectives',                                     'deloitte',       'composite', 'annuelle',     'qualitatif',        'a_confirmer', NULL),

 -- Médical — § 8.4.2
 ('M1','medical','Commerce mondial d''instruments médicaux (SH 9018-9022), par pays',        'comtrade',       'hard',      'annuelle',     'USD',               'certifie',    5),
 ('M2','medical','Production de l''industrie des instruments médicaux UE (NACE C32.5)',      'eurostat',       'hard',      'trimestrielle','indice',            'certifie',    5),
 ('M3','medical','Dépenses de santé par pays (part du PIB et par habitant)',                 'oms_ghed',       'hard',      'annuelle',     'pourcentage / USD', 'certifie',    3),
 ('M4','medical','Emploi et établissements medtech suisses (NOGA 32.5, 26.6)',               'ofs',            'hard',      'annuelle',     'nombre',            'certifie',    5),
 ('M5','medical','Panorama de la branche medtech suisse',                                    'swiss_medtech',  'composite', 'bisannuelle',  'mia CHF',           'a_confirmer', NULL),
 ('M6','medical','Dépôts de brevets en technologies médicales',                              'ompi',           'hard',      'annuelle',     'nombre',            'certifie',    10),

 -- Automobile — § 8.4.3
 ('A1','automobile','Production mondiale de véhicules par pays',                             'oica',           'hard',      'annuelle',     'unités',            'certifie',    5),
 ('A2','automobile','Immatriculations de véhicules neufs en Europe',                         'acea',           'composite', 'mensuelle',    'unités',            'certifie',    5),
 ('A3','automobile','Ventes mondiales de véhicules électriques par pays',                    'aie',            'hard',      'annuelle',     'unités',            'certifie',    10),
 ('A4','automobile','Commerce mondial de parties et accessoires automobiles (SH 8708)',      'comtrade',       'hard',      'annuelle',     'USD',               'certifie',    5),
 ('A5','automobile','Production industrielle automobile UE (NACE C29)',                      'eurostat',       'hard',      'mensuelle',    'indice',            'certifie',    5),

 -- Aérospatial — § 8.4.4
 ('S1','aerospatial','Commandes et livraisons d''avions commerciaux (Airbus, Boeing)',       'constructeurs',  'hard',      'mensuelle',    'appareils',         'certifie',    10),
 ('S2','aerospatial','Trafic aérien mondial de passagers (RPK)',                             'iata',           'composite', 'mensuelle',    'indice',            'a_confirmer', NULL),
 ('S3','aerospatial','Objets lancés dans l''espace par pays',                                'unoosa',         'hard',      'annuelle',     'nombre',            'certifie',    15),
 ('S4','aerospatial','Dépenses militaires par pays',                                         'sipri',          'hard',      'annuelle',     'mia USD',           'certifie',    5),
 ('S5','aerospatial','Budget de l''ESA et budgets spatiaux publics',                         'esa',            'composite', 'annuelle',     'mio EUR',           'a_confirmer', NULL),
 ('S6','aerospatial','Commerce mondial aéronautique et spatial (SH ch. 88)',                 'comtrade',       'hard',      'annuelle',     'USD',               'certifie',    5);

-- Rattachements. Reventilés le 07.08.2026 : les brevets (H4, M6) relèvent
-- de la dynamique technologique et non plus géographique ; A3 porte les
-- deux, l'électrification étant à la fois une substitution technique et un
-- phénomène géographiquement différencié ; les séries par pays (H3, M1,
-- A1, S3) restent géographiques.
INSERT INTO indicator_watch_questions (indicator_id, watch_question_code) VALUES
 ('T1','QV0'),('T2','QV0'),('T3','QV0'),('T4','QV0'),
 ('H1','QV2'),('H2','QV1'),('H3','QV2'),('H3','QV3'),('H4','QV4'),('H5','QV1'),('H5','QV5'),
 ('M1','QV2'),('M1','QV3'),('M2','QV1'),('M3','QV2'),('M3','QV5'),('M4','QV1'),('M5','QV1'),('M5','QV3'),('M6','QV4'),
 ('A1','QV1'),('A1','QV3'),('A2','QV2'),('A3','QV2'),('A3','QV3'),('A3','QV4'),('A4','QV2'),('A5','QV1'),
 ('S1','QV1'),('S1','QV2'),('S2','QV2'),('S3','QV3'),('S4','QV5'),('S5','QV5'),('S6','QV2');

-- ---------------------------------------------------------------------
-- Instanciation sectorielle (niveau 2) — § 8.1.2
--
-- Une ligne par couple secteur × question. Le champ mecanisme est le
-- coeur du dispositif : il énonce le rôle causal du phénomène dans ce
-- secteur précis. Sans lui, l'instanciation serait une paraphrase et la
-- table n'apporterait rien.
-- ---------------------------------------------------------------------

INSERT INTO sector_watch_questions (sector_code, watch_question_code, formulation, mecanisme, criticite) VALUES

 ('transversal','QV0',
  'Le mouvement observé sur un secteur est-il propre à ce secteur, ou porté par la conjoncture générale ?',
  'Sans référentiel commun, un recul sectoriel est ininterprétable : une baisse des exportations ne se lit pas de la même manière selon que le commerce mondial recule ou progresse. Le socle transversal fournit le dénominateur de l''attribution.',
  'dominante'),

 -- Horlogerie
 ('horlogerie','QV1',
  'L''appareil productif horloger suisse se maintient-il en emplois et en établissements, indépendamment du niveau des exportations en valeur ?',
  'La branche peut exporter davantage en valeur tout en perdant des établissements : la montée en gamme masque l''érosion du tissu de sous-traitance, qui est précisément le segment concerné par le cas d''illustration.',
  'dominante'),
 ('horlogerie','QV2',
  'Vers quels marchés de destination les exportations horlogères se déplacent-elles, et à quel rythme ?',
  'Demande finale de luxe, très concentrée géographiquement et sensible aux chocs de change et de droits de douane. Elle se transmet à la sous-traitance avec un décalage de quelques mois.',
  'dominante'),
 ('horlogerie','QV3',
  'La production horlogère reste-t-elle concentrée en Suisse, ou des pôles concurrents captent-ils des parts du commerce mondial d''articles d''horlogerie ?',
  'Concurrence de substitution par le milieu de gamme asiatique. Menace lente mais structurelle sur les volumes de sous-traitance, invisible dans les seules statistiques suisses.',
  'significative'),
 ('horlogerie','QV4',
  'La montre connectée et les nouveaux matériaux recomposent-ils la demande de composants mécaniques ?',
  'Substitution technologique partielle : le produit connecté ne remplace pas le luxe mécanique mais comprime l''entrée de gamme, segment à fort volume de pièces usinées.',
  'significative'),
 ('horlogerie','QV5',
  'Quelles décisions publiques — droits de douane, accords commerciaux, réglementation Swiss made — modifient les conditions d''accès aux marchés ?',
  'L''action publique n''est ici ni acheteuse ni finançante : elle agit sur les conditions d''accès et les règles d''origine, donc sur les prix relatifs et non sur le niveau de la demande. Le choc douanier de 2025 constitue l''exception qui rend la question observable.',
  'marginale'),

 -- Médical
 ('medical','QV1',
  'La base productive medtech européenne et suisse croît-elle en volume et en emplois ?',
  'Secteur défensif, peu cyclique : la production suit la demande démographique. Tout décrochage est donc un signal structurel et non une fluctuation conjoncturelle.',
  'significative'),
 ('medical','QV2',
  'Quels pays accroissent leurs importations d''instruments médicaux, et leurs dépenses de santé le confirment-elles ?',
  'Demande solvabilisée par les systèmes de santé : le budget public précède la commande hospitalière avec un décalage long. Le croisement des deux séries distingue la croissance financée de la croissance annoncée.',
  'dominante'),
 ('medical','QV3',
  'Où se localise la production d''instruments médicaux, et la position suisse s''y érode-t-elle ?',
  'Les barrières réglementaires (MDR européen, homologation FDA) freinent les délocalisations : la géographie bouge lentement, ce qui rend tout mouvement observé significatif.',
  'significative'),
 ('medical','QV4',
  'Quelles mutations techniques — chirurgie mini-invasive, robotique, implants personnalisés — recomposent la demande de pièces de précision ?',
  'Chaque génération d''instruments modifie les tolérances, les matériaux et les volumes demandés au sous-traitant. L''antériorité du signal se lit dans les dépôts de brevets, plusieurs années avant la commande.',
  'dominante'),
 ('medical','QV5',
  'Comment évoluent les dépenses publiques de santé, et quels programmes d''équipement en découlent ?',
  'Déterminant médiatisé : la dépense publique solvabilise la demande hospitalière sans être elle-même la commande. Décalage de plusieurs années entre arbitrage budgétaire et appel d''offres.',
  'significative'),

 -- Automobile
 ('automobile','QV1',
  'La production automobile européenne recule-t-elle plus vite que l''industrie manufacturière dans son ensemble ?',
  'Cyclicité forte, amplifiée en amont : une variation de production finale se répercute sur les carnets de la sous-traitance avec un effet d''accélérateur. La comparaison à la production manufacturière totale sépare le choc sectoriel du choc conjoncturel.',
  'dominante'),
 ('automobile','QV2',
  'Les immatriculations et les flux de pièces indiquent-ils une reprise ou une contraction de la demande adressable ?',
  'Les immatriculations mesurent la demande finale, le commerce de pièces mesure le marché directement adressable par la sous-traitance. Les deux peuvent diverger — un marché stable en véhicules peut se contracter en pièces si le contenu mécanique par véhicule diminue.',
  'dominante'),
 ('automobile','QV3',
  'Le centre de gravité de la production automobile se déplace-t-il hors d''Europe ?',
  'La délocalisation de l''assemblage final entraîne celle des chaînes d''approvisionnement de rang 1 et 2. Menace structurelle sur l''avantage de proximité géographique du sous-traitant européen.',
  'significative'),
 ('automobile','QV4',
  'L''électrification recompose-t-elle la demande de composants mécaniques, et à quel rythme selon les marchés ?',
  'Substitution technologique à effet asymétrique : disparition des familles de pièces liées à la motorisation thermique, apparition de familles nouvelles, et diminution du nombre total de pièces usinées par véhicule. C''est la mutation la plus déterminante du portefeuille pour un décolleteur.',
  'dominante'),
 ('automobile','QV5',
  'Quelles décisions réglementaires — normes d''émission, calendrier d''interdiction du thermique, dispositifs d''incitation — modifient la composition de la demande ?',
  'L''action publique ne finance ni n''achète : elle fixe le calendrier de la substitution technologique. Elle agit sur la composition de la demande, non sur son niveau — ce qui explique qu''aucune série statistique budgétaire ne la capte.',
  'dominante'),

 -- Aérospatial
 ('aerospatial','QV1',
  'Les carnets de commandes et les cadences de livraison des avionneurs assurent-ils une charge pluriannuelle à la chaîne de sous-traitance ?',
  'Cycle long : le carnet donne une visibilité de plusieurs années, ce qui inverse la logique de veille. On surveille les révisions de cadence annoncées, non les retournements de demande.',
  'dominante'),
 ('aerospatial','QV2',
  'La demande de transport aérien soutient-elle le renouvellement des flottes ?',
  'Le trafic passagers précède les commandes d''appareils de plusieurs trimestres : c''est l''indicateur avancé du cycle civil, en amont du carnet de commandes.',
  'significative'),
 ('aerospatial','QV3',
  'Quels États accèdent à une capacité spatiale autonome ?',
  'L''entrée de nouveaux acteurs nationaux ouvre des chaînes d''approvisionnement nouvelles, mais souvent captives pour raisons de souveraineté. L''opportunité est réelle et l''accès contraint.',
  'significative'),
 ('aerospatial','QV4',
  'Quelles ruptures techniques — lanceurs réutilisables, constellations, propulsion alternative — modifient les volumes et les tolérances demandés ?',
  'La réutilisabilité réduit le nombre de lanceurs produits tout en durcissant les exigences de qualification ; les constellations inversent la logique du secteur en demandant de la série là où le spatial était unitaire. Deux effets de sens opposé sur le volume de sous-traitance.',
  'dominante'),
 ('aerospatial','QV5',
  'Les budgets de défense et les budgets spatiaux publics progressent-ils, et sur quels programmes ?',
  'La dépense publique EST la demande : défense et spatial institutionnel sont des marchés budgétaires. Une décision budgétaire n''est pas un signal indirect, c''est une commande à venir.',
  'dominante');

COMMIT;

-- Vérifications immédiates après scission (07.08.2026). Deux lacunes de
-- couverture, à énoncer dans le rapport et non à masquer :
--   · automobile / QV5 — aucun indicateur. Les impulsions publiques
--     automobiles sont des actes réglementaires, pas des séries
--     statistiques : le terrain existe, il relève du composite
--     documentaire et n'a pas été instruit dans cette itération.
--   · aerospatial / QV4 — aucun indicateur. Lacune révélée par la
--     scission elle-même : elle était invisible tant que dynamique
--     géographique et dynamique technologique partageaient un libellé.
--     S3 (objets lancés par pays) couvre le géographique, rien ne couvre
--     le technologique. Piste identifiée : dépôts de brevets CIB B64
--     auprès de l'OMPI, source déjà certifiée au référentiel.
--   · horlogerie / QV5 — couverte par H5 seul, « à confirmer » :
--     couverture nominale et non opérationnelle.
-- La vue v_couverture_qv les constate. C'est le point I-9 de l'évaluation
-- critique, désormais énoncé plutôt que contredit.
