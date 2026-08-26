-- =====================================================================
-- Séparer ce qu'un lecteur doit comprendre de ce qui trace une décision
-- 26.08.2026
--
-- LE DÉFAUT. `indicators.description_metier` s'était chargée de deux
-- textes de natures différentes. Le premier explique l'indicateur à qui
-- le lit : ce qu'il mesure, pourquoi il compte pour un atelier, comment
-- le lire sans se tromper. Le second est un JOURNAL DE DÉCISIONS —
-- « RETIRÉ DU SCORE le 24.08.2026 : corrélation des résidus de 0,910 »,
-- « seuil de matérialité nul à dessein (RI4 inapplicable) »,
-- « [HORS VITRINE le 25.08.2026 — …] ». Ce second texte est écrit pour
-- le jury et pour la personne qui reprendra le dispositif ; il n'a rien
-- à faire sur un écran de décision. Sur A7, il représentait mille
-- caractères posés entre le titre de l'indicateur et sa valeur.
--
-- Le symptôme était déjà visible dans le code : `Marche.jsx` coupait la
-- chaîne à « [HORS VITRINE » pour ne pas l'afficher. Rustine d'affichage
-- sur un défaut de modèle.
--
-- LE CHOIX : SÉPARER, PAS SUPPRIMER. La traçabilité est la thèse de ce
-- travail — effacer le journal des décisions serait la contredire.
-- `note_conception` le recueille intégralement : rien n'est perdu, le
-- rapport et l'annexe peuvent l'interroger, et l'écran de décision ne le
-- porte plus.
--
-- Les textes destinés au lecteur sont par ailleurs DÉMAJUSCULÉS. Un
-- tableau de bord qui ouvre ses cartes par « CE QUI RECOMPOSE LA DEMANDE
-- DE COMPOSANTS » crie ; les capitales d'insistance ne survivent que là
-- où elles portent une consigne de lecture (unités, sens inversé).
--
-- AUCUN CONTENU N'EST INVENTÉ : les deux champs sont issus du découpage
-- et de la réécriture des textes existants, à sens constant.
-- =====================================================================

BEGIN;

ALTER TABLE indicators ADD COLUMN IF NOT EXISTS note_conception text;

COMMENT ON COLUMN indicators.description_metier IS
  'Destiné au LECTEUR du tableau de bord : ce que l''indicateur mesure, pourquoi il compte '
  'pour un atelier, comment le lire sans se tromper. Ni date de décision, ni code de règle, '
  'ni mention de score ou de vitrine — cela relève de note_conception.';
COMMENT ON COLUMN indicators.note_conception IS
  'Destiné au JURY et à la reprise du dispositif : journal des décisions portant sur cet '
  'indicateur (retraits du score, redondances mesurées, changements de source, mises hors '
  'vitrine, inapplicabilité de règles). Jamais affiché sur un écran de décision.';

-- ---------------------------------------------------------------------
-- 1. Le journal de décisions, extrait tel quel
-- ---------------------------------------------------------------------
UPDATE indicators SET note_conception =
  'HORS VITRINE le 25.08.2026 — aucune observation collectée : la source est qualifiée, la liaison manque ou l''accès n''a pas été obtenu.'
WHERE indicator_id IN ('A1','A8','H4','H5','M5','S1','S2','S5');

UPDATE indicators SET note_conception =
  'HORS VITRINE le 25.08.2026 — moins de douze points sur la zone de référence : la série ne se lit pas.'
WHERE indicator_id = 'A3';

UPDATE indicators SET note_conception =
  'ÉTAT AU 24.08.2026 : un seul point au registre. L''indicateur ne produira aucune lecture exploitable avant plusieurs exercices, et n''entre dans aucun calcul. Conservé au référentiel parce que la grille décrit ce que le dispositif est conçu pour suivre ; son inactivité est une limite déclarée, non un oubli.

HORS VITRINE le 25.08.2026 — moins de douze points sur la zone de référence : la série ne se lit pas.'
WHERE indicator_id IN ('H2','M3','M4');

UPDATE indicators SET note_conception =
  'ÉTAT AU 24.08.2026 : trois points semestriels depuis 2023, et une valeur inchangée à 3,4 %. N''est jamais entré dans le score (seuil de huit points) et n''a jamais rien signalé. Conservé comme toile de fond documentaire.

HORS VITRINE le 25.08.2026 — moins de douze points sur la zone de référence : la série ne se lit pas.'
WHERE indicator_id = 'T4';

UPDATE indicators SET note_conception =
  'Zone de référence DEU — premier déposant européen et premier débouché de la sous-traitance automobile suisse. Seuil de matérialité laissé nul à dessein, ce qui rend la règle RI4 inapplicable et interdit au modèle de commenter la variation.

HORS SCORE DE SANTÉ, par construction et non par élagage : le dernier point disponible est 2022. Un score de position cyclique calculé au 25.08.2026 sur une série qui s''arrête quatre ans plus tôt figerait la position du secteur sur un état périmé. L''indicateur répond à QV4, question de dynamique technologique dont l''horizon est pluriannuel, et à elle seule.

HORS VITRINE le 25.08.2026 — dernier point en 2022 : la source publie avec un retard qui la rend inutilisable en conjoncture.'
WHERE indicator_id = 'A7';

UPDATE indicators SET note_conception =
  'Zone de référence CHE : ce qui intéresse un atelier neuchâtelois est la vitalité technologique de son écosystème. Seuil de matérialité laissé nul à dessein, ce qui rend RI4 inapplicable et interdit au modèle de commenter une variation.

CHANGEMENT DE SOURCE le 25.08.2026 : déclaré sur l''OMPI depuis le 06.08 et jamais collecté, faute de point d''accès programmable libre chez ce producteur. L''OCDE publie le même objet en API SDMX sans clé.

HORS SCORE DE SANTÉ, par construction et non par élagage : le dernier point disponible est 2022. Un score de position cyclique calculé sur une série qui s''arrête quatre ans plus tôt figerait la position du secteur sur un état périmé. L''indicateur répond à QV4 et à elle seule.

HORS VITRINE le 25.08.2026 — dernier point en 2022 : la source publie avec un retard qui la rend inutilisable en conjoncture.'
WHERE indicator_id = 'M6';

UPDATE indicators SET note_conception =
  'RETIRÉ DU SCORE le 24.08.2026 : corrélation des résidus détendancés de 0,993 avec H7 — c''est la même série, issue du même tableau. Le compter au score donnerait trois voix à une seule mesure. Reste lu par la vue v_mix_horloger, qui exploite son rapport à H7 et non son niveau.

HORS VITRINE le 25.08.2026 — redondant avec un indicateur retenu, corrélation supérieure ou égale à 0,90.'
WHERE indicator_id = 'H8';

UPDATE indicators SET note_conception =
  'RETIRÉ DU SCORE le 24.08.2026 : corrélation des résidus de 0,910 avec H7. Reste l''une des deux jambes du mix mécanique, où sa valeur est entière — c''est l''écart entre volume et valeur qui informe, pas le niveau du volume pris seul.'
WHERE indicator_id = 'H9';

UPDATE indicators SET note_conception =
  'RETIRÉ DU SCORE le 24.08.2026 : contribution mesurée de +1,98, la plus forte de la grille, pour une série qui compte des lancements de satellites. Un atelier d''usinage de précision suisse n''en usine pas : le nombre d''objets lancés ne commande aucune charge chez lui. L''indicateur pilotait le score aérospatial sans rapport avec ce que ce score prétend mesurer. Conservé pour QV3, où sa lecture géographique reste légitime.'
WHERE indicator_id = 'S3';

UPDATE indicators SET note_conception =
  'PIÈGE DE LECTURE, DÉCLARÉ : le carnet européen est passé de -26,7 à -17,5 entre juillet 2025 et juillet 2026 — une amélioration — que le calcul relatif exprime en -34,5 %. Le seuil de matérialité est laissé nul à dessein, ce qui rend la règle RI4 inapplicable et interdit au modèle de commenter la variation.'
WHERE indicator_id IN ('T8','T10');

UPDATE indicators SET note_conception =
  'RETIRÉ LE 25.08.2026, décision de l''étudiant. Ces deux indicateurs mesuraient les brevets du métier — technique de surface et machines-outils — mais ils ne comblaient pas le vide qu''ils visaient : l''horlogerie (CIB G04) et l''aérospatial (B64) sont noyés dans les domaines « Techniques de mesure » et « Transport » de la nomenclature de l''OMPI, et restent sans indicateur QV4. Ajouter à côté d''un vide ne le comble pas.

Liaisons supprimées : plus aucune collecte. Les 322 observations déjà écrites restent au registre — leur suppression a été refusée par le déclencheur d''ajout seul (D-18), ce qui est le comportement attendu.

RETIRÉ DE LA GRILLE le 26.08.2026 : sans question de veille rattachée, cet indicateur viole la règle « pas d''indicateur sans question ». Il ne collecte plus, n''entre dans aucun calcul, et le socle reconstruit ne le contient pas.'
WHERE indicator_id IN ('T12','T13');

-- ---------------------------------------------------------------------
-- 2. Le texte du lecteur — démajusculé, borné, sans date de décision
-- ---------------------------------------------------------------------
UPDATE indicators SET description_metier =
  'Production mondiale de véhicules par pays : le volume et la géographie de l''assemblage automobile.'
WHERE indicator_id = 'A1';

UPDATE indicators SET description_metier =
  'Ventes de véhicules électriques par pays : la recomposition technologique et géographique de la demande automobile.'
WHERE indicator_id = 'A3';

UPDATE indicators SET description_metier =
  'La demande adressable de la sous-traitance automobile, à l''étage où elle s''exprime. C29.3 est la fabrication d''équipements pour véhicules — le métier des donneurs d''ordre d''un atelier d''usinage. À comparer systématiquement à A5 (C29, fabrication de véhicules) : l''écart entre les deux mesure la transmission du marché final vers la sous-traitance, et un écart qui se creuse signale que le marché final ne se transmet plus.'
WHERE indicator_id = 'A6';

UPDATE indicators SET description_metier =
  'Ce qui recompose la demande de composants, à la racine. A3 mesure les ventes de véhicules électriques, c''est-à-dire le résultat, plusieurs années après la décision technique ; le comptage de brevets en technologies de transport bas carbone mesure la décision elle-même, au moment où elle est prise. Un basculement de l''effort de R&D précède de cinq à dix ans le changement des familles de pièces commandées. Ne se lit pas en conjoncture : le dernier point disponible est 2022.'
WHERE indicator_id = 'A7';

UPDATE indicators SET description_metier =
  'La demande publique adressée aux pièces mécaniques automobiles, comptée à la source : le nombre d''avis de marchés publiés chaque mois au journal des marchés publics européens pour des moteurs et des pièces de rechange. En amont des commandes et des flux commerciaux, à fraîcheur immédiate — un avis publié aujourd''hui concerne une production à six ou dix-huit mois. Ne mesure que la part publique de la demande automobile : se lit en tendance, jamais en volume.'
WHERE indicator_id = 'A8';

UPDATE indicators SET description_metier =
  'Emploi et établissements de la branche horlogère suisse : la substance productive du secteur, à évolution lente. Un seul point au registre à ce jour — la série ne se lit pas encore.'
WHERE indicator_id = 'H2';

UPDATE indicators SET description_metier =
  'Dépôts de brevets en horlogerie (CIB G04) : où l''effort d''innovation du secteur se localise.'
WHERE indicator_id = 'H4';

UPDATE indicators SET description_metier =
  'Climat de branche et perspectives déclarées par les acteurs (étude annuelle) : le qualitatif qui précède parfois les chiffres.'
WHERE indicator_id = 'H5';

UPDATE indicators SET description_metier =
  'La mesure de référence du débouché horloger, en francs. Remplace fonctionnellement la lecture en dollars de H1, dont la corrélation au taux CHF/USD a été mesurée à -0,40 : un sixième de sa variance était du change. Publiée à J+20 par la Fédération, à partir des statistiques douanières fédérales.'
WHERE indicator_id = 'H7';

UPDATE indicators SET description_metier =
  'La part usinée du débouché horloger. Une montre mécanique mobilise des dizaines de pièces usinées à tolérances serrées ; une montre à quartz en mobilise peu. C''est donc cette série, et non la valeur horlogère totale, qui commande la charge d''un atelier de décolletage. À lire avec H7 : leur rapport est le mix.'
WHERE indicator_id = 'H8';

UPDATE indicators SET description_metier =
  'Le volume mécanique, distinct de sa valeur. Un atelier facture des pièces, pas des francs : une montée en gamme peut accroître la valeur exportée sans accroître le nombre de montres produites, donc sans accroître la charge d''usinage. C''est le point de vigilance qu''énonce QV1 — une montée en valeur qui masquerait l''érosion du tissu de sous-traitance —, et H9 le rend observable.'
WHERE indicator_id = 'H9';

UPDATE indicators SET description_metier =
  'Dépenses de santé par pays, en part du PIB et par habitant : le financement qui conditionne la demande medtech, à décalage long. Un seul point au registre à ce jour — la série ne se lit pas encore.'
WHERE indicator_id = 'M3';

UPDATE indicators SET description_metier =
  'Emploi et établissements medtech suisses : la substance productive nationale du secteur. Un seul point au registre à ce jour — la série ne se lit pas encore.'
WHERE indicator_id = 'M4';

UPDATE indicators SET description_metier =
  'Panorama bisannuel de la branche medtech suisse : cadrage qualitatif et chiffres de référence.'
WHERE indicator_id = 'M5';

UPDATE indicators SET description_metier =
  'La position technologique de la branche médicale, et non son activité. Comptage des dépôts de brevets en technologie médicale, par pays du déposant. Un brevet précède le produit de plusieurs années : il renseigne sur ce qui se prépare, pas sur ce qui se vend — donc, pour un sous-traitant, sur le rythme auquel les plans, tolérances et matériaux qu''on lui demandera vont changer. Ne se lit pas en conjoncture : le dernier point disponible est 2022.'
WHERE indicator_id = 'M6';

UPDATE indicators SET description_metier =
  'Commandes et livraisons d''avions commerciaux (Airbus, Boeing) : le carnet qui engage la sous-traitance sur plusieurs années.'
WHERE indicator_id = 'S1';

UPDATE indicators SET description_metier =
  'Trafic aérien mondial de passagers (RPK) : la demande de transport qui commande les cadences de production.'
WHERE indicator_id = 'S2';

UPDATE indicators SET description_metier =
  'Objets lancés dans l''espace par pays : l''activité spatiale effective. Série volatile par nature, à lire en tendance.'
WHERE indicator_id = 'S3';

UPDATE indicators SET description_metier =
  'Budgets spatiaux publics (ESA et agences nationales) : l''impulsion publique qui finance les programmes.'
WHERE indicator_id = 'S5';

UPDATE indicators SET description_metier =
  'Croissance annuelle du PIB mondial : le rythme d''ensemble de la demande adressée aux branches industrielles. Trois points seulement au registre — toile de fond documentaire, sans lecture conjoncturelle.'
WHERE indicator_id = 'T4';

UPDATE indicators SET description_metier =
  'Le signal d''avance du carnet de commandes. Solde d''opinion des industriels sur l''état de leur carnet, publié à J+0 sans révision : un carnet qui se dégarnit précède la baisse de production de plusieurs mois — c''est la variable que lit un directeur d''atelier avant toute statistique. Grandeur intensive et légitimement négative : ne jamais la sommer. Se lit en POINTS et en niveau, jamais en pourcentage — le solde traverse zéro, et la variation relative y inverse le sens économique.'
WHERE indicator_id = 'T8';

UPDATE indicators SET description_metier =
  'Un signal précoce de retournement. Part des entreprises citant l''insuffisance de la demande parmi les freins à leur production : elle monte avant que les carnets ne se vident, et bien avant que la production ne recule. Sens inversé — une hausse est défavorable. Se lit en POINTS et en niveau, jamais en pourcentage — le solde traverse zéro, et la variation relative y inverse le sens économique.'
WHERE indicator_id = 'T10';

UPDATE indicators SET description_metier =
  'Brevets en technique de surface (T12) et en machines-outils (T13) : indicateurs abandonnés, sans question de veille rattachée. Ne collectent plus et n''entrent dans aucun calcul.'
WHERE indicator_id IN ('T12','T13');

COMMIT;

-- Complément : T11 portait une date de vérification dans le texte du lecteur.
-- Le fait (pas de ventilation par branche pour la Suisse) est utile ; la date
-- de sa vérification relève de la note de conception.
BEGIN;
UPDATE indicators SET
  description_metier = 'L''activité industrielle de l''écosystème du cas d''illustration. La ventilation par branche n''est pas disponible pour la Suisse dans cette source : la série existe pour l''ensemble manufacturier et pour lui seul. Sert de repère national face à l''agrégat européen.',
  note_conception = 'Absence de ventilation par branche pour la Suisse vérifiée le 24.08.2026 chez le producteur.'
WHERE indicator_id = 'T11';
COMMIT;
