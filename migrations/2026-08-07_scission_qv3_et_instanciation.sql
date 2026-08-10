-- =====================================================================
-- Migration du 07.08.2026 — scission de QV3 et instanciation sectorielle
--
-- Objet. Deux corrections de cadrage métier appliquées à une base déjà
-- en service, sans toucher au registre des observations.
--
--   1. L'ancienne QV3 « dynamique géographique et innovation » confondait
--      deux interrogations distinctes. Où le centre de gravité d'un
--      secteur se déplace et quelle mutation technique recompose la
--      demande sont deux questions différentes, avec des indicateurs et
--      des horizons différents. En automobile, la montée de la Chine et
--      l'électrification sont deux phénomènes, pas un.
--      QV3 est ramenée au géographique, QV4 devient la dynamique
--      technologique, et « impulsions publiques » se décale en QV5.
--
--   2. Le § 8.1.2 annonçait depuis la phase 1 que les questions
--      génériques étaient « instanciées pour chacun des quatre
--      secteurs ». Cette instanciation n'était matérialisée nulle part.
--      La table sector_watch_questions la porte désormais, avec pour
--      chaque couple secteur × question sa formulation propre, le rôle
--      causal du phénomène dans ce secteur, et son poids.
--
-- Emplacement. Ce fichier est HORS de db/, donc hors du répertoire
-- d'initialisation automatique du conteneur : il ne doit pas être rejoué
-- sur une base neuve. Une base créée après cette date obtient le même
-- état par 02_referentiel.sql, mis à jour en conséquence.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-07_scission_qv3_et_instanciation.sql
--
-- Non destructif : aucune ligne de indicator_values n'est lue ni écrite.
-- Transactionnel : en cas d'erreur, rien n'est appliqué.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ---------------------------------------------------------------------
-- 0. Garde — refuser une seconde application
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM watch_questions WHERE code = 'QV5') THEN
        RAISE EXCEPTION
          'Migration déjà appliquée : QV5 existe. Rien n''a été modifié.';
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 1. Niveau 2 du cadre : table d'instanciation sectorielle
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sector_watch_questions (
    sector_code         TEXT NOT NULL REFERENCES sectors(code),
    watch_question_code TEXT NOT NULL REFERENCES watch_questions(code),
    formulation         TEXT NOT NULL,
    mecanisme           TEXT NOT NULL,
    criticite           TEXT NOT NULL CHECK (criticite IN ('dominante','significative','marginale')),
    PRIMARY KEY (sector_code, watch_question_code)
);

COMMENT ON TABLE sector_watch_questions IS
  'Instanciation sectorielle (§ 8.1.2). Le § 8.1.2 annonçait cette instanciation depuis la phase 1 sans la matérialiser : cette table clôt cet écart. Le champ mecanisme est ce qui distingue une instanciation d''une paraphrase.';

-- ---------------------------------------------------------------------
-- 2. Décalage : « impulsions publiques » passe de QV4 à QV5
--    L'ordre compte — les rattachements migrent avant que QV4 ne change
--    de sens, sans quoi ils désigneraient la mauvaise question.
-- ---------------------------------------------------------------------
INSERT INTO watch_questions (code, label, description) VALUES
 ('QV5','Impulsions publiques',
  'Quelle action publique — dépense, réglementation, condition d''accès — modifie le niveau ou la composition de la demande à moyen terme ?');

UPDATE indicator_watch_questions
   SET watch_question_code = 'QV5'
 WHERE watch_question_code = 'QV4';

-- ---------------------------------------------------------------------
-- 3. Scission : QV3 se restreint, QV4 prend la dynamique technologique
-- ---------------------------------------------------------------------
UPDATE watch_questions
   SET label       = 'Dynamique géographique',
       description = 'Où le centre de gravité du secteur se déplace-t-il : quels pays produisent, importent ou accèdent à une capacité nouvelle ?'
 WHERE code = 'QV3';

UPDATE watch_questions
   SET label       = 'Dynamique technologique',
       description = 'Quelle mutation technique recompose la demande de composants : quels procédés, matériaux ou architectures se substituent aux précédents ?'
 WHERE code = 'QV4';

-- ---------------------------------------------------------------------
-- 4. Reventilation des rattachements anciennement sous QV3
--
--    Critère appliqué : une série qui répond « quel pays » reste
--    géographique ; une série qui répond « quelle technique » devient
--    technologique. Les dépôts de brevets basculent — ils mesuraient
--    l'innovation, jamais la géographie. A3 porte les deux :
--    l'électrification est une substitution technique ET un phénomène
--    géographiquement différencié.
-- ---------------------------------------------------------------------
UPDATE indicator_watch_questions SET watch_question_code = 'QV4'
 WHERE indicator_id = 'H4' AND watch_question_code = 'QV3';   -- brevets horlogerie (CIB G04)

UPDATE indicator_watch_questions SET watch_question_code = 'QV4'
 WHERE indicator_id = 'M6' AND watch_question_code = 'QV3';   -- brevets technologies médicales

INSERT INTO indicator_watch_questions (indicator_id, watch_question_code)
VALUES ('A3','QV4')                                            -- ventes de véhicules électriques
ON CONFLICT DO NOTHING;

-- Inchangés, et c'est un choix : H3, M1, A1, S3 répondent « quel pays »
-- et restent géographiques ; M5 (panorama medtech suisse) documente le
-- positionnement de la Suisse, non une mutation technique.

-- ---------------------------------------------------------------------
-- 5. Instanciation sectorielle — 21 couples
-- ---------------------------------------------------------------------
INSERT INTO sector_watch_questions (sector_code, watch_question_code, formulation, mecanisme, criticite) VALUES

 ('transversal','QV0',
  'Le mouvement observé sur un secteur est-il propre à ce secteur, ou porté par la conjoncture générale ?',
  'Sans référentiel commun, un recul sectoriel est ininterprétable : une baisse des exportations ne se lit pas de la même manière selon que le commerce mondial recule ou progresse. Le socle transversal fournit le dénominateur de l''attribution.',
  'dominante'),

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

-- ---------------------------------------------------------------------
-- 6. Vue de restitution du niveau 2
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_instanciation_qv AS
SELECT swq.sector_code,
       s.label            AS sector_label,
       swq.watch_question_code,
       q.label            AS question_generique,
       swq.formulation    AS question_sectorielle,
       swq.mecanisme,
       swq.criticite,
       COUNT(iwq.indicator_id)                                     AS nb_indicateurs,
       COUNT(iwq.indicator_id) FILTER (WHERE i.status = 'certifie') AS nb_certifies
FROM sector_watch_questions swq
JOIN sectors        s ON s.code = swq.sector_code
JOIN watch_questions q ON q.code = swq.watch_question_code
LEFT JOIN indicators i ON i.sector_code = swq.sector_code
LEFT JOIN indicator_watch_questions iwq
       ON iwq.indicator_id = i.indicator_id
      AND iwq.watch_question_code = swq.watch_question_code
GROUP BY swq.sector_code, s.label, swq.watch_question_code, q.label,
         swq.formulation, swq.mecanisme, swq.criticite
ORDER BY swq.sector_code, swq.watch_question_code;

COMMENT ON VIEW v_instanciation_qv IS
  'Le cadre à deux niveaux, restitué. Une criticité « dominante » sans indicateur certifié est une lacune à énoncer au rapport, pas à masquer.';

COMMIT;

-- =====================================================================
-- Vérifications — à exécuter après la migration et à conserver comme
-- pièce. Attendus énoncés avant exécution, conformément au protocole
-- suivi pour les tests de contraintes.
-- =====================================================================

\echo ''
\echo '--- 1. Six questions génériques, QV5 = impulsions publiques'
SELECT code, label FROM watch_questions ORDER BY code;

\echo ''
\echo '--- 2. Rattachements par question (attendu : QV4 = H4, M6, A3)'
SELECT watch_question_code, string_agg(indicator_id, ', ' ORDER BY indicator_id) AS indicateurs
FROM indicator_watch_questions GROUP BY watch_question_code ORDER BY watch_question_code;

\echo ''
\echo '--- 3. Couverture après scission'
\echo '    Attendu : deux lacunes — automobile/QV5 et aerospatial/QV4 —'
\echo '    et horlogerie/QV5 couverte_a_confirmer.'
SELECT * FROM v_couverture_qv;

\echo ''
\echo '--- 4. Criticité dominante sans indicateur certifié : les lacunes qui comptent'
SELECT sector_code, watch_question_code, criticite, nb_certifies
FROM v_instanciation_qv
WHERE criticite = 'dominante' AND nb_certifies = 0;

\echo ''
\echo '--- 5. Registre intact (le décompte doit être inchangé par la migration)'
SELECT COUNT(*) AS observations_en_base FROM indicator_values;
