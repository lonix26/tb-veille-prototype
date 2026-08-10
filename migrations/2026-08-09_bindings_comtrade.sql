-- =====================================================================
-- Liaisons Comtrade — H1, H3, M1, A4, S6
--
-- PRÉREQUIS, à faire avant d'exécuter ce fichier :
--
--   1. Le décodeur `json_generique` doit accepter le mappage
--      `format_periode: "AAAAMM"` et transformer 202401 en 2024-01.
--      Sans cela, les contrôles qualité rejettent toute observation
--      mensuelle (format validé par ^\d{4}(-(\d{2}|T\d|S\d))?$).
--
--   2. Le nœud d'appel HTTP doit porter l'en-tête
--      `Ocp-Apim-Subscription-Key`, servi par une credential n8n.
--      LA CLÉ NE DOIT PAS FIGURER DANS `params` : cette table est
--      exportée vers les CSV, l'annexe 1 et le classeur.
--
-- ---------------------------------------------------------------------
-- SUR LES CODES PAYS — constat de qualification du 09.08.2026
--
-- Les codes ci-dessous sont relevés dans la liste de référence officielle
-- des zones partenaires, et non déduits de la nomenclature M49. Cette
-- précaution n'est pas de principe : la nomenclature M49 aurait produit
-- trois erreurs silencieuses.
--
--   · Suisse   — M49 756, Comtrade 757 (« Switzerland, Liechtenstein »)
--   · France   — M49 250, Comtrade 251 (« France, Monaco »)
--   · Inde     — M49 356, Comtrade 699
--
-- Le cas suisse mérite d'être consigné pour lui-même. La liste de
-- référence contient DEUX entrées : 756 « Switzerland » et 757
-- « Switzerland ». Même code ISO (CH/CHE), même date d'entrée en
-- vigueur (1900-01-01), aucune date d'expiration, aucun marqueur
-- d'obsolescence. Seul 757 porte une note de périmètre. Or 756 ne
-- renvoie AUCUNE donnée — sans erreur, sans avertissement, avec un
-- champ `error` vide et `count: 0`.
--
-- Conséquence méthodologique : consulter la documentation de référence
-- ne suffisait pas à choisir le bon code. Seule la confrontation à une
-- vue extérieure connue — l'interface web de la source — a permis de
-- trancher. C'est la hiérarchie de fiabilisation du § 6.3 appliquée à
-- la construction du dispositif lui-même : vérité terrain d'abord.
--
-- PÉRIMÈTRES À ÉNONCER AU RAPPORT. Trois des codes retenus ne désignent
-- pas le pays seul :
--   · 757 = Suisse ET Liechtenstein (union douanière)
--   · 251 = France ET Monaco
--   · 842 = États-Unis, Porto Rico ET Îles Vierges américaines
--
-- RÉSERVE. Les codes ci-dessous proviennent de la liste des zones
-- PARTENAIRES. La liste des DÉCLARANTS est distincte et n'a pas été
-- relevée. Les cinq codes déjà éprouvés en réponse réelle comme
-- déclarants sont 757, 276, 380, 156 et 392 ; les autres restent à
-- confirmer en tant que déclarants avant activation.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

DELETE FROM source_bindings WHERE url_base LIKE '%comtradeapi%';

-- ---------------------------------------------------------------------
-- H1 — Exportations horlogères suisses par marché de destination
--
-- Re-sourcé sur Comtrade. La Fédération de l'industrie horlogère, source
-- initialement qualifiée, ne publie que des PDF sous des noms de fichiers
-- à date encodée sans motif stable : elle relève du traitement composite
-- et n'est pas automatisable en l'état. Elle reste la référence de
-- branche, conservée comme telle au tableau de confiance.
--
-- Mensuel. La zone porte le PARTENAIRE — c'est le marché de destination
-- qui fait l'indicateur, conformément à sa définition au § 8.4.1.
--
-- Panier de destinations : les marchés que la branche suit elle-même.
-- 0 (Monde) est inclus pour disposer du total et pouvoir contrôler que
-- la somme des destinations retenues en représente une part cohérente.
-- ---------------------------------------------------------------------
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, verifie_par, verifie_le, note) VALUES
('H1', 'json_generique',
 'https://comtradeapi.un.org/data/v1/get/C/M/HS',
 '{"reporterCode":"757","period":"202401,202402,202403","cmdCode":"91","flowCode":"X","partnerCode":"0,842,344,156,392,826,702,276,251,380,784","breakdownMode":"classic","includeDesc":"true"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","format_periode":"AAAAMM","colonne_valeur":"primaryValue","colonne_geo":"partnerISO"}'::jsonb,
 'W00', 'a_verifier', NULL, NULL,
 'Série mensuelle vérifiée le 09.08.2026 sur le total Monde : 2,23 / 2,46 / 2,36 mia USD de janvier à mars 2024, cohérent avec l''annuel 2023 (29,76 mia USD). Destinations : Monde, USA, Hong Kong, Chine, Japon, Royaume-Uni, Singapour, Allemagne, France, Italie, Émirats — codes relevés dans la liste de référence. À VÉRIFIER AVANT ACTIVATION : le nombre de lignes renvoyées avec le panier de partenaires, et l''étendue de la période à porter à la fenêtre complète.'),

-- ---------------------------------------------------------------------
-- H3, M1, A4, S6 — Commerce mondial par chapitre, annuel
--
-- La zone porte ici le DÉCLARANT : la question est de savoir quels pays
-- pèsent dans le commerce mondial du secteur.
--
-- Sens de flux : exportations (X), décision du 09.08 — mesure de la
-- production vendue et de la compétitivité, non de la consommation.
-- ---------------------------------------------------------------------
('H3', 'json_generique',
 'https://comtradeapi.un.org/data/v1/get/C/A/HS',
 '{"reporterCode":"757,156,276,380,392,251,344","period":"2023,2024","cmdCode":"91","flowCode":"X","partnerCode":"0","breakdownMode":"classic","includeDesc":"true"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","colonne_valeur":"primaryValue","colonne_geo":"reporterISO"}'::jsonb,
 'WORLD', 'a_verifier', NULL, NULL,
 'Cinq déclarants éprouvés le 09.08 (757, 276, 380, 156, 392) ; France et Hong Kong ajoutés depuis la liste de référence, à confirmer en tant que déclarants. breakdownMode=classic est indispensable — sans lui la réponse est ventilée par mode de transport et régime douanier, et un usage naïf produirait un total faux d''apparence normale.'),

('M1', 'json_generique',
 'https://comtradeapi.un.org/data/v1/get/C/A/HS',
 '{"reporterCode":"276,842,156,392,528,372,484,757","period":"2023,2024","cmdCode":"9018,9019,9020,9021,9022","flowCode":"X","partnerCode":"0","breakdownMode":"classic","includeDesc":"true"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","colonne_valeur":"primaryValue","colonne_geo":"reporterISO","agreger":"somme"}'::jsonb,
 'WORLD', 'a_verifier', NULL, NULL,
 'Allemagne, USA, Chine, Japon, Pays-Bas, Irlande, Mexique, Suisse. VENTILATION CONSTATÉE le 09.08.2026 : la requête porte cinq positions SH et la réponse renvoie 80 lignes — 8 déclarants × 2 années × 5 positions —, une par position. Les cinq lignes d''un même déclarant et d''une même année partagent la clé (indicateur, run, période, zone) : sans agrégation, la contrainte d''unicité n''en conserverait qu''une, silencieusement, et M1 afficherait une position sur cinq avec une valeur d''apparence crédible. D''où `agreger: somme`, calculée dans le décodeur de manière déterministe et consignée au bilan du run. L''indicateur reste défini sur 9018-9022 comme au § 8.4.2 : c''est le dispositif qui s''adapte à l''indicateur, non l''inverse.'),

('A4', 'json_generique',
 'https://comtradeapi.un.org/data/v1/get/C/A/HS',
 '{"reporterCode":"276,156,842,392,484,410,203,616","period":"2023,2024","cmdCode":"8708","flowCode":"X","partnerCode":"0","breakdownMode":"classic","includeDesc":"true"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","colonne_valeur":"primaryValue","colonne_geo":"reporterISO"}'::jsonb,
 'WORLD', 'a_verifier', NULL, NULL,
 'Allemagne, Chine, USA, Japon, Mexique, Corée du Sud, Tchéquie, Pologne — les pays où se concentre la production de pièces automobiles. Panier volontairement large : c''est l''indicateur qui mesure le marché directement adressable par la sous-traitance de précision.'),

('S6', 'json_generique',
 'https://comtradeapi.un.org/data/v1/get/C/A/HS',
 '{"reporterCode":"842,251,276,826,124,380","period":"2023,2024","cmdCode":"88","flowCode":"X","partnerCode":"0","breakdownMode":"classic","includeDesc":"true"}'::jsonb,
 '{"chemin_donnees":"data","colonne_periode":"period","colonne_valeur":"primaryValue","colonne_geo":"reporterISO"}'::jsonb,
 'WORLD', 'a_verifier', NULL, NULL,
 'USA, France, Allemagne, Royaume-Uni, Canada, Italie — les pays qui concentrent l''assemblage aéronautique et spatial. Rappel de périmètre : 251 couvre France et Monaco, 842 couvre les États-Unis, Porto Rico et les Îles Vierges américaines.');

COMMIT;

-- =====================================================================
-- Vérifications
-- =====================================================================

\echo ''
\echo '--- Liaisons Comtrade semées, toutes au statut a_verifier'
\echo '    Attendu : 5 lignes, aucune active.'
SELECT indicator_id, statut,
       params->>'cmdCode'      AS chapitre,
       params->>'reporterCode' AS declarants,
       mapping->>'colonne_geo' AS zone
FROM source_bindings
WHERE url_base LIKE '%comtradeapi%'
ORDER BY indicator_id;

\echo ''
\echo '--- Aucune clé d''API ne doit figurer dans les paramètres'
\echo '    Attendu : 0 ligne.'
SELECT indicator_id, params
FROM source_bindings
WHERE params::text ILIKE '%subscription%' OR params::text ILIKE '%key%';
