-- =====================================================================
-- Description métier des indicateurs — portage v2 de la restitution
--
-- PRÉPARÉE le 10.08.2026. La maquette v2 (validée le jour même) a montré
-- que les libellés techniques — « Indicateur composite avancé (CLI) »,
-- « NACE C29 » — ne parlent pas au destinataire. Chaque carte porte
-- désormais une ligne « ce qu'il indique » en langage métier.
--
-- Cette ligne est un ATTRIBUT DU RÉFÉRENTIEL, pas un texte d'affichage :
-- elle vit en base, la page ne fait que la projeter (même règle que le
-- tableau de confiance, § 8.2.1). Les textes ci-dessous sont un premier
-- jet rédigé sur la base des définitions du ch. 8 — À RELIRE indicateur
-- par indicateur avant exécution : la formulation engage la lecture que
-- le décideur fera de chaque carte.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-10_descriptions_metier.sql \
--     | tee ../annexe_5/descriptions_metier_2026-08-10.txt
--
-- ORDRE IMPORTANT : appliquer cette migration AVANT de réimporter
-- api_restitution.json (qui sélectionne la colonne) — sinon la requête
-- de l'API échoue sur colonne inconnue et le tableau de bord n'affiche
-- plus rien.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE indicators ADD COLUMN IF NOT EXISTS description_metier TEXT;

UPDATE indicators SET description_metier = v.d
FROM (VALUES
  ('T1','Indicateur avancé de l''OCDE (zone G20) : au-dessus de 100, l''activité des grandes économies tend à accélérer dans les six à neuf mois ; en dessous, à ralentir.'),
  ('T2','Taux de change moyens mensuels : un franc plus fort renchérit les exportations facturées en euros et en dollars — la variable la plus directe sur la marge d''un exportateur.'),
  ('T3','Volume du commerce mondial de marchandises (CPB) : le débit réel des flux dont dépendent les quatre secteurs.'),
  ('T4','Croissance annuelle du PIB mondial : le rythme d''ensemble de la demande adressée aux branches industrielles.'),
  ('H1','Exportations horlogères suisses par pays de destination, en valeur mensuelle : où la demande se porte, où elle se retire.'),
  ('H2','Emploi et établissements de la branche horlogère suisse : la substance productive du secteur, à évolution lente.'),
  ('H3','Exportations annuelles d''articles d''horlogerie par pays : la place de chaque économie dans le commerce horloger mondial, Suisse comprise.'),
  ('H4','Dépôts de brevets en horlogerie (CIB G04) : où l''effort d''innovation du secteur se localise.'),
  ('H5','Climat de branche et perspectives déclarées par les acteurs (étude annuelle) : le qualitatif qui précède parfois les chiffres.'),
  ('M1','Exportations annuelles d''instruments médicaux par pays (SH 9018-9022) : la géographie de l''offre mondiale en technologies médicales.'),
  ('M2','Production de l''industrie des instruments médicaux de l''UE (indice mensuel) : l''activité réelle des usines de la branche.'),
  ('M3','Dépenses de santé par pays, en part du PIB et par habitant : le financement qui conditionne la demande medtech, à décalage long.'),
  ('M4','Emploi et établissements medtech suisses : la substance productive nationale du secteur.'),
  ('M5','Panorama bisannuel de la branche medtech suisse : cadrage qualitatif et chiffres de référence.'),
  ('M6','Dépôts de brevets en technologies médicales : où l''innovation du secteur se localise.'),
  ('A1','Production mondiale de véhicules par pays : le volume et la géographie de l''assemblage automobile.'),
  ('A2','Immatriculations mensuelles de véhicules neufs en Europe : la demande finale, en aval de la chaîne dont dépend un fournisseur de composants.'),
  ('A3','Ventes de véhicules électriques par pays : la recomposition technologique et géographique de la demande automobile.'),
  ('A4','Exportations de parties et accessoires automobiles par pays (SH 8708) : qui fournit la chaîne mondiale, et où les flux se déplacent.'),
  ('A5','Indice mensuel de production automobile de l''UE (base 2021 = 100) : l''activité réelle des usines clientes.'),
  ('S1','Commandes et livraisons d''avions commerciaux (Airbus, Boeing) : le carnet qui engage la sous-traitance sur plusieurs années.'),
  ('S2','Trafic aérien mondial de passagers (RPK) : la demande de transport qui commande les cadences de production.'),
  ('S3','Objets lancés dans l''espace par pays : l''activité spatiale effective — série volatile par nature, à lire en tendance.'),
  ('S4','Dépenses militaires par pays : en aérospatial-défense, le budget public est la demande elle-même.'),
  ('S5','Budgets spatiaux publics (ESA et agences nationales) : l''impulsion publique qui finance les programmes.'),
  ('S6','Exportations aéronautiques et spatiales par pays (SH ch. 88) : la géographie du commerce du secteur.')
) AS v(id, d)
WHERE indicators.indicator_id = v.id;

COMMIT;

-- =====================================================================
-- Vérifications
-- =====================================================================

\echo ''
\echo '--- Couverture : chaque indicateur doit porter une description'
\echo '    Attendu : 0 ligne.'
SELECT indicator_id, label FROM indicators WHERE description_metier IS NULL ORDER BY indicator_id;

\echo ''
\echo '--- Aperçu'
SELECT indicator_id, left(description_metier, 70) || '…' AS description
FROM indicators ORDER BY indicator_id LIMIT 6;
