-- =====================================================================
-- 2026-08-27 — INTENSITÉ DE SIGNALEMENT : LA GRILLE APPREND À FABRIQUER
--
-- LE CONSTAT QUI FONDE LA FAMILLE. La matrice de couverture de la vitrine
-- (v_couverture_vitrine, 27.08) montre six cases sans porteur, dont trois
-- de criticité dominante — toutes en QV3/QV4/QV5. Le motif est structurel :
-- QV1/QV2 se moulent sur la statistique publique, QV4/QV5 non. Or le
-- dispositif possède déjà la matière qui répond à ces questions : les flux
-- qualifiés (presse de branche, actualité, marchés publics) triés par IA,
-- chaque item étant attribué à un couple secteur × question avec un score
-- de pertinence. Cette attribution produisait des commentaires, jamais des
-- indicateurs. La présente migration en dérive une SÉRIE.
--
-- LA MESURE. Part mensuelle des items admis au triage d'un secteur qui
-- sont attribués à la question avec pertinence >= 1 (tous doctrines
-- confondues, item compté une fois). Une PART et non un compte : le corpus
-- de flux grandit encore (sources ajoutées les 23-26.08), un compte brut
-- confondrait l'intensité du signal avec la croissance du corpus.
--
-- LE PLANCHER DE CALCULABILITÉ : 20 items triés par secteur et par mois.
-- En deçà, le point est NON CALCULABLE et déclaré tel (précédent : le
-- 2025 de l'indicateur synthétique, « non calculable, énoncé »).
-- Justification du seuil par la résolution : à n = 20, un item déplace la
-- part de 5 points au plus. Leçon du § 8.8.7 appliquée : le critère
-- quantitatif est accompagné de son garde-fou — il est déclaré, calculé
-- par vue, et sa première victime est assumée (l'horlogerie, 16 items en
-- août, n'a AUCUN point calculable : sa case reste vide avec une raison
-- mesurée — le corpus horloger est mince, et cela se voit).
--
-- CE QUE LA FAMILLE N'EST PAS. La migration du 26.08 (presse de branche)
-- posait : « un flux n'est pas un indicateur, il ne produit pas de série ».
-- Ce constat tient. Ce n'est pas le flux qui fait série ici, c'est le taux
-- d'attribution du triage — un dérivé du jugement de l'IA, pas du fil.
-- D'où la catégorie « composite » : la valeur repose sur un jugement d'IA
-- (obtained_by = ia_extraction) et passe par la file de validation
-- humaine. Le triage n'ayant qu'UN modèle (choix mesuré du § 9.5.1),
-- aucun consensus n'est établi : consensus_score = 0 en file — précédent
-- A2, périodes 2025-11 et 2026-01/03/04/06 — et routage humain
-- SYSTÉMATIQUE. Prétendre un consensus à modèle unique serait la
-- surdéclaration exacte que le travail s'interdit.
--
-- ADMISSION EN VITRINE. Statut a_confirmer (série d'un à deux points ;
-- l'élagage du 26.08 a retiré des certifiés sous huit points — certifier
-- ici serait incohérent). L'admission en vitrine se fait par le critère
-- de RÔLE (précédent A2, écrit le 26.08) : ces indicateurs sont les seuls
-- porteurs possibles de quatre cases dont trois dominantes, et les seuls
-- à démontrer que l'IA peut FABRIQUER un indicateur là où la statistique
-- publique s'arrête — ce qui est la question de recherche même.
--
-- TENSION DÉCLARÉE. Le § 8.3 énonce « 26 sources, toutes en accès
-- libre ». La famille exige une 27e entrée dans `sources` — une
-- DÉRIVATION INTERNE, non une source externe : le décompte du rapport
-- devient « 26 sources externes + 1 dérivation interne ». À répercuter
-- au § 8.3 et dans D2 (fait le 27.08).
-- =====================================================================

BEGIN;

-- 1. La « source » : dérivation interne, déclarée comme telle.
INSERT INTO sources (source_id, name, organisation, url, frequency, format, access,
                     qualification_status, qualified_by, notes)
VALUES ('triage_flux',
        'Intensité de signalement dans les flux qualifiés (dérivation interne)',
        'Dispositif de veille — dérivation du triage IA (v_intensite_signalement)',
        'interne : flux_sources → flux_items → flux_triage_ia → v_intensite_signalement',
        'mensuelle', 'sql', 'libre',
        'a_confirmer', 'N. Castillo (délégation du 27.08.2026)',
        'Non pas une source externe mais une dérivation : part mensuelle des items triés attribués à une question de veille. Hérite de la qualification des flux sous-jacents (tous en accès libre). a_confirmer tant que le corpus est jeune (démarré fin 07.2026) et sa composition mouvante.');

-- 2. Les quatre indicateurs. Sens favorable neutre (0) : une dynamique
-- technologique qui s'intensifie n'est ni bonne ni mauvaise en soi pour un
-- sous-traitant — elle recompose la demande (cf. réutilisabilité des
-- lanceurs : moins d'appareils, exigences durcies).
INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency,
                        unit, status, en_vitrine, sens_favorable, latence, geo_reference,
                        description_metier, note_conception)
VALUES
('S9', 'aerospatial',
 'Intensité de signalement — dynamique technologique (triage IA des flux)',
 'triage_flux', 'composite', 'mensuelle', 'pourcentage', 'a_confirmer', true, 0, 'avance', 'World',
 'Part des signaux du mois (presse spécialisée, actualité, marchés publics) que l''IA de triage rattache à la dynamique technologique du secteur : procédés, matériaux, architectures en substitution. Une part qui monte signale une recomposition technique en cours — celle que les statistiques de production ne montrent qu''après coup.',
 'Créé le 27.08.2026 (décision de l''étudiant, revue du 26-27.08). Premier porteur de la case aérospatial × QV4 (dominante), vide en vitrine depuis la scission de QV3. Admission par critère de rôle, statut a_confirmer : série d''un point (2026-08 : 21/124 items). Plancher de calculabilité 20 items/mois, part et non compte (corpus en croissance). Modèle de triage unique → consensus non établi → validation humaine systématique.'),
('A9', 'automobile',
 'Intensité de signalement — dynamique technologique (triage IA des flux)',
 'triage_flux', 'composite', 'mensuelle', 'pourcentage', 'a_confirmer', true, 0, 'avance', 'World',
 'Part des signaux du mois que l''IA de triage rattache à la dynamique technologique automobile : électrification, batteries, procédés de fabrication. Pour un fournisseur de composants mécaniques, c''est la question vitale — l''électrification supprime des familles entières de pièces usinées.',
 'Créé le 27.08.2026. Premier porteur de la case automobile × QV4 (dominante). Mêmes règles que S9. Série : 2026-07 (1/21), 2026-08 (18/101). Complète A7 (brevets bas carbone, certifié, hors vitrine) : A7 mesure l''amont long des dépôts, A9 le présent du signalement.'),
('A10', 'automobile',
 'Intensité de signalement — impulsions publiques (triage IA des flux)',
 'triage_flux', 'composite', 'mensuelle', 'pourcentage', 'a_confirmer', true, 0, 'avance', 'World',
 'Part des signaux du mois que l''IA de triage rattache à l''action publique sur l''automobile : normes d''émissions, subventions à l''achat, droits de douane, plans de soutien. L''action publique y déplace la demande à moyen terme plus sûrement que la conjoncture.',
 'Créé le 27.08.2026. Premier porteur de la case automobile × QV5 (dominante). Mêmes règles que S9. Série : 2026-07 (2/21), 2026-08 (17/101).'),
('H10', 'horlogerie',
 'Intensité de signalement — dynamique technologique (triage IA des flux)',
 'triage_flux', 'composite', 'mensuelle', 'pourcentage', 'a_confirmer', true, 0, 'avance', 'World',
 'Part des signaux du mois que l''IA de triage rattache à la dynamique technologique horlogère : matériaux, procédés, complications, fabrication additive.',
 'Créé le 27.08.2026. Porteur DÉCLARÉ SANS POINT CALCULABLE de la case horlogerie × QV4 : le corpus horloger d''août 2026 compte 16 items triés, sous le plancher de 20. La case reste vide avec une raison mesurée — le corpus de flux horloger est mince (2 fils de presse + actualité) — et l''indicateur s''activera quand le corpus franchira le plancher, sans changement de définition. Distinct du cas H5 (couverture nominale, § 8.4.5) : ici la machinerie tourne et la raison du vide est chiffrée.');

-- 3. Rattachement aux questions (le déclencheur l'exige, à raison).
INSERT INTO indicator_watch_questions (indicator_id, watch_question_code) VALUES
('S9', 'QV4'), ('A9', 'QV4'), ('A10', 'QV5'), ('H10', 'QV4');

-- 4. La vue de dérivation — générique (toutes cases, tous mois), le
-- plancher étant porté par la colonne `calculable` et non par un filtre :
-- ce que le plancher écarte doit rester visible.
CREATE OR REPLACE VIEW v_intensite_signalement AS
WITH attribue AS (
  SELECT DISTINCT t.item_id,
         to_char(fi.date_publication, 'YYYY-MM') AS periode,
         t.sector_code,
         t.watch_question_code,
         t.pertinence
    FROM flux_triage_ia t
    JOIN flux_items fi USING (item_id)
   WHERE fi.date_publication IS NOT NULL
     AND t.sector_code IS NOT NULL
), denominateur AS (
  SELECT periode, sector_code, count(DISTINCT item_id) AS n_tries
    FROM attribue GROUP BY 1, 2
), numerateur AS (
  SELECT periode, sector_code, watch_question_code,
         count(DISTINCT item_id) AS n_pertinents
    FROM attribue WHERE pertinence >= 1 GROUP BY 1, 2, 3
)
SELECT n.periode,
       n.sector_code,
       n.watch_question_code,
       n.n_pertinents,
       d.n_tries,
       round(100.0 * n.n_pertinents / d.n_tries, 1) AS part_pct,
       d.n_tries >= 20                              AS calculable,
       i.indicator_id
  FROM numerateur n
  JOIN denominateur d USING (periode, sector_code)
  LEFT JOIN indicator_watch_questions iwq
    ON iwq.watch_question_code = n.watch_question_code
  LEFT JOIN indicators i
    ON i.indicator_id = iwq.indicator_id
   AND i.sector_code = n.sector_code
   AND i.source_id = 'triage_flux'
 ORDER BY n.sector_code, n.watch_question_code, n.periode;

COMMENT ON VIEW v_intensite_signalement IS
  'Part mensuelle des items triés attribués à chaque couple secteur × question (pertinence >= 1, item compté une fois). Plancher de calculabilité : 20 items triés/secteur/mois (résolution : 1 item <= 5 points de part). indicator_id non nul = case instrumentée. Créée le 27.08.2026.';

COMMIT;

-- ---------------------------------------------------------------------
-- CORRECTIF DU MÊME JOUR (27.08, détecté à la vérification d'écran).
-- Les quatre indicateurs déclaraient geo_reference = 'World' alors que
-- les valeurs sont écrites en geo = 'WORLD' (défaut de la file). v_vitrine
-- joignant les métriques sur l'égalité stricte, les fiches sortaient sans
-- série. Harmonisation sur 'WORLD' (la graphie des valeurs, immuables).
-- ---------------------------------------------------------------------
UPDATE indicators SET geo_reference = 'WORLD'
 WHERE source_id = 'triage_flux' AND geo_reference = 'World';
