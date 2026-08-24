-- ============================================================================
-- Dynamique géographique — QV3 instrumentée. N. Castillo, 24.08.2026.
--
-- CONSTAT À L'ORIGINE. Le registre compte 39 604 observations, dont une part
-- considérable ventilée par pays : 88 destinations pour les exportations
-- horlogères suisses, 65 pays pour les ventes de véhicules électriques, 7 à 11
-- pour les flux de commerce. La restitution n'en affichait qu'UNE par
-- indicateur — la zone de référence déclarée. Autrement dit, la question de
-- veille QV3, « dynamique géographique », l'un des cinq angles invariants du
-- cadre du chapitre 8, n'était instrumentée par aucun écran alors que les
-- données pour y répondre étaient collectées depuis le premier jour.
--
-- BASE DE COMPARAISON, ET POURQUOI ELLE N'EST PAS LA MÊME PARTOUT.
-- La règle RI2 interdit de lire une variation entre périodes consécutives sur
-- une série brute : la saisonnalité l'emporte sur le signal. La vue applique
-- donc deux bases selon la périodicité :
--   · séries annuelles      → dernier exercice contre le précédent ;
--   · séries infra-annuelles → douze mois glissants contre les douze
--     précédents, ce qui neutralise la saisonnalité par construction.
-- La base employée est portée par la colonne `base_comparaison` et doit être
-- affichée : une variation dont on ignore la base ne se lit pas.
--
-- DÉDUPLICATION OBLIGATOIRE. Le registre est en AJOUT SEUL : une même période
-- y figure autant de fois qu'il y a eu d'exécutions. Une somme sans
-- `DISTINCT ON` multiplie les montants par le nombre de runs — l'erreur a été
-- commise puis corrigée à la conception de cette vue, sur H1 : quinze runs,
-- des montants quinze fois trop élevés, et des parts de marché toutes
-- plausibles. Le défaut ne se voit pas dans le résultat, seulement dans la
-- requête. C'est le motif du § 12.6 dans sa forme la plus discrète.
-- ============================================================================

BEGIN;

DROP VIEW IF EXISTS v_dynamique_geographique;

CREATE VIEW v_dynamique_geographique AS
WITH pts AS (
  -- Une valeur par (indicateur, zone, période) : celle du run le plus récent.
  SELECT DISTINCT ON (iv.indicator_id, iv.geo, iv.period)
         iv.indicator_id, iv.geo, iv.period, iv.value, iv.validation_status
  FROM indicator_values iv
  WHERE iv.validation_status IN ('valide_source','pre_valide_consensus','valide_humain')
  ORDER BY iv.indicator_id, iv.geo, iv.period, iv.run_id DESC
),
cadre AS (
  SELECT p.indicator_id,
         i.sector_code, i.label, i.unit, i.frequency, i.geo_reference,
         (i.frequency = 'annuelle' OR i.frequency = 'semestrielle') AS annuelle,
         max(p.period) AS p_max
  FROM pts p JOIN indicators i USING (indicator_id)
  -- SEULES LES GRANDEURS ADDITIVES. Sommer douze mois n'a de sens que pour un
  -- flux — une valeur exportée, un nombre d'unités vendues. Un indice, un taux
  -- de change ou un solde d'opinion sont des grandeurs INTENSIVES : leur somme
  -- sur douze mois ne veut rien dire, et leur « part de marché » encore moins.
  -- Le premier jet de cette vue incluait le taux CHF/EUR et le baromètre KOF,
  -- avec des parts et des variations parfaitement calculées et dépourvues de
  -- sens. C'est la même faute que les contrôles qualité présumant une grandeur
  -- positive (§ 12.6) : une opération arithmétique valide appliquée à un objet
  -- qu'elle ne décrit pas.
  WHERE i.unit IN ('USD','mio USD','unités','nombre',
                   'nombre d''avis','nombre d''autorisations')
  GROUP BY 1,2,3,4,5,6,7
),
-- Séries annuelles : dernier exercice contre le précédent.
annuel AS (
  SELECT c.indicator_id, p.geo,
         sum(p.value) FILTER (WHERE p.period = c.p_max) AS recent,
         sum(p.value) FILTER (WHERE p.period = (
             SELECT max(period) FROM pts q
             WHERE q.indicator_id = c.indicator_id AND q.period < c.p_max)) AS anterieur,
         c.p_max AS periode_ref,
         'exercice ' || c.p_max AS base_comparaison
  FROM cadre c JOIN pts p ON p.indicator_id = c.indicator_id
  WHERE c.annuelle
  GROUP BY c.indicator_id, p.geo, c.p_max
),
-- Séries infra-annuelles : douze mois glissants contre les douze précédents.
glissant AS (
  SELECT c.indicator_id, p.geo,
         sum(p.value) FILTER (WHERE p.period > to_char((to_date(c.p_max,'YYYY-MM') - interval '12 months'),'YYYY-MM')) AS recent,
         sum(p.value) FILTER (WHERE p.period > to_char((to_date(c.p_max,'YYYY-MM') - interval '24 months'),'YYYY-MM')
                                AND p.period <= to_char((to_date(c.p_max,'YYYY-MM') - interval '12 months'),'YYYY-MM')) AS anterieur,
         c.p_max AS periode_ref,
         '12 mois glissants au ' || c.p_max AS base_comparaison
  FROM cadre c JOIN pts p ON p.indicator_id = c.indicator_id
  WHERE NOT c.annuelle
  GROUP BY c.indicator_id, p.geo, c.p_max
),
tout AS (SELECT * FROM annuel UNION ALL SELECT * FROM glissant),
totaux AS (
  -- Le total exclut les agrégats déjà présents comme zones (monde, UE…),
  -- sans quoi la part de marché serait divisée par deux.
  SELECT indicator_id, sum(recent) AS total_recent
  FROM tout
  WHERE recent > 0 AND geo NOT IN ('W00','WORLD','World','OWID_WRL','EU','EU27','EU27_2020','G20')
  GROUP BY indicator_id
)
SELECT t.indicator_id,
       c.sector_code, c.label, c.unit, c.frequency,
       t.geo,
       (t.geo = c.geo_reference) AS est_zone_de_reference,
       t.recent      AS valeur_recente,
       t.anterieur   AS valeur_anterieure,
       round(100.0 * t.recent / nullif(x.total_recent,0), 2) AS part_pct,
       round(100.0 * (t.recent - t.anterieur) / nullif(abs(t.anterieur),0), 1) AS variation_pct,
       t.periode_ref,
       t.base_comparaison,
       -- Un poids plancher : une variation relative énorme sur un marché
       -- minuscule est un artefact, pas un signal. Le seuil est déclaré ici
       -- et doit être affiché à l'écran pour rester contestable.
       (100.0 * t.recent / nullif(x.total_recent,0) >= 1.0) AS poids_significatif
FROM tout t
JOIN cadre c ON c.indicator_id = t.indicator_id
JOIN totaux x ON x.indicator_id = t.indicator_id
WHERE t.recent > 0 AND t.anterieur > 0
  AND t.geo NOT IN ('W00','WORLD','World','OWID_WRL','EU','EU27','EU27_2020','G20');

COMMENT ON VIEW v_dynamique_geographique IS
  'Répartition et évolution par zone, indicateur par indicateur — instrumente '
  'la question de veille QV3. Comparaison à douze mois glissants pour les '
  'séries infra-annuelles (neutralisation de la saisonnalité, RI2), à exercice '
  'contre exercice pour les annuelles. Les agrégats mondiaux et européens sont '
  'exclus du calcul des parts. Déduplication par run obligatoire : le registre '
  'est en ajout seul.';

COMMIT;

-- Contrôle : combien d'indicateurs, combien de zones, et le poids retenu.
SELECT indicator_id, sector_code, count(*) AS zones,
       count(*) FILTER (WHERE poids_significatif) AS zones_pesantes,
       max(base_comparaison) AS base
FROM v_dynamique_geographique
GROUP BY 1,2 ORDER BY 2,1;
