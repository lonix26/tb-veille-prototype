-- =====================================================================
-- 2026-08-30 — H2 PASSE AU RECENSEMENT DE LA CONVENTION PATRONALE,
-- EN TRAITEMENT COMPOSITE
--
-- DÉCISION DE L'ÉTUDIANT, prise en session le 30.08.2026, en connaissance
-- de la tension : le directeur avait pris « l'OFS quand il sort le chiffre
-- de la STATENT » comme EXEMPLE FONDATEUR de hard data (D-19, séance 3 du
-- 28.05.2026). Faire passer l'emploi horloger au traitement composite
-- révise donc un exemple posé en séance. À RATIFIER (§ 7.2.2).
--
-- MOTIF. Le recensement CP est supérieur à STATENT sur quatre axes
-- mesurés : fraîcheur (enquête au 30.09, publication en décembre, soit
-- ~3 mois, contre ~20 mois pour STATENT), profondeur (2005-2025, 21 points
-- contre 11), grandeurs portées (effectifs ET entreprises, ce que le
-- libellé de H2 promettait sans le tenir), et périmètre (« horlogère et
-- microtechnique », plus proche du cas CODEC que la seule NOGA 26.52).
-- Bénéfice secondaire assumé par l'étudiant : un DEUXIÈME composite
-- instrumenté, là où le § 8.8 ne pouvait en déclarer qu'un seul.
--
-- POURQUOI COMPOSITE ET NON HARD. Le document contient un tableau, mais
-- le nœud PDF de n8n ne le rend pas : `parseText` parcourt les fragments
-- dans l'ordre du flux de contenu, ne se sert de Y que pour couper les
-- lignes et JETTE X. Le PDF de la CP étant composé colonne par colonne,
-- la sortie est mélangée — mesuré le 30.08 : concordance 2/14 sur la
-- colonne « de direction », 0/7 sur « Total », 0/1 sur « Entreprises ».
-- La voie déterministe est donc fermée AVEC L'OUTILLAGE EN PLACE, et la
-- lecture passe par la voie multimodale : le PDF entier est soumis aux
-- trois éditeurs, qui le lisent en vision.
--
-- CE QUI N'EST PAS ÉCRASÉ — ET UNE LEÇON REÇUE DE LA BASE. La première
-- version de cette migration RÉATTRIBUAIT à H12 les 56 observations
-- STATENT portées par H2. Le déclencheur `interdire_modification_du_registre`
-- l'a refusée : « le registre des valeurs est en ajout seul (D-18) ». Le
-- garde-fou a joué son rôle contre l'auteur de la migration, ce qui est
-- exactement sa raison d'être. Rien n'est donc déplacé :
--   · les observations STATENT RESTENT sous H2, comme histoire d'avant la
--     redéfinition — elles sont datées, tracées, et le registre les garde ;
--   · les valeurs CP sont ajoutées dans un NOUVEAU run. `v_current` retenant
--     le run le plus récent par période, la série servie devient homogène
--     et entièrement CP, sans qu'aucune ligne n'ait été touchée ;
--   · H12 ne reçoit pas d'ancien : la liaison STATENT lui est transférée et
--     une collecte le remplira, sous son propre nom.
--
-- EFFET DE BORD VÉRIFIÉ AVANT D'ÊTRE ACCEPTÉ. Pour les onze périodes
-- couvertes par les deux sources, `v_ecart_entre_runs` affichera un écart
-- d'environ +13 % au run de bascule. Ce n'est pas un mouvement du réel,
-- c'est le changement d'instrument — et c'est une vue d'AUDIT : aucune
-- autre vue ne la consomme (vérifié sur `pg_views`), et les alertes se
-- calculent sur `v_metriques`, bâtie sur `v_current`, donc sur une série
-- homogène. Aucune alerte fausse n'en découle. L'écart visible au run de
-- bascule est une trace, et il vaut mieux qu'un silence.
-- =====================================================================

BEGIN;

-- 1. La source -------------------------------------------------------
INSERT INTO sources (source_id, name, organisation, url, frequency, format,
                     access, qualification_status, qualified_by, qualified_at, notes)
VALUES ('cp',
        'Recensement du personnel et des entreprises des industries horlogère et microtechnique suisses',
        'Convention patronale de l''industrie horlogère suisse',
        'https://cpih.ch/statistiques/',
        'annuelle', 'PDF (lecture multimodale)', 'libre', 'certifiee',
        'N. Castillo', '2026-08-30 00:00:00+00',
        'Association patronale, PAS une statistique publique — provenance à déclarer comme pour la FH (§ 8.6.4) ; ne jamais étiqueter « donnée officielle ». Recensement au 30 septembre, publication en décembre. La page d''index est STABLE, le nom du PDF change chaque année : le lien se résout depuis l''index, comme pour la FH et le classeur SIPRI. Tableau Tb. 1e = série 2005-2025, effectifs et entreprises.')
ON CONFLICT (source_id) DO NOTHING;

-- 2. H12 : la série STATENT reçoit son propre indicateur --------------
INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency,
                        unit, status, alert_threshold_pct, description_metier,
                        sens_favorable, latence, geo_reference, en_vitrine, note_conception)
VALUES ('H12', 'horlogerie',
        'Emplois horlogers suisses (STATENT, NOGA 26.52)',
        'ofs', 'hard', 'annuelle', 'nombre', 'certifie', 5,
        'Emploi de la seule fabrication de montres et d''horloges (NOGA 26.52), mesuré par la statistique publique. Série de COMPARAISON DE PÉRIMÈTRE face à H2 : même grandeur, périmètre plus étroit.',
        1, 'retarde', 'CH', false,
        'Créé le 30.08.2026 pour porter la collecte STATENT sous son propre nom, quand H2 est passé au recensement de la Convention patronale. Les 56 observations STATENT antérieures n''ont PAS été déplacées : le registre est en ajout seul (D-18) et le déclencheur a refusé la réattribution. Elles restent sous H2 comme histoire d''avant la redéfinition ; H12 se remplit par collecte, la liaison lui ayant été transférée.

HORS VITRINE, motif explicite : doublon de grandeur avec H2 — c''est le critère de doublon déjà employé à l''élagage du 26.08. Conservé au référentiel parce que l''écart entre les deux mesures EST un résultat : de +9,5 % à +15,4 % selon l''année, et un signe de glissement annuel qui diverge trois fois sur dix. Ancrage officiel de la mesure, invocable en supervision.')
ON CONFLICT (indicator_id) DO NOTHING;

-- Aucune réattribution : le registre est en ajout seul (D-18). H12 sera
-- rempli par une collecte à son nom, la liaison lui étant transférée.

-- La liaison STATENT suit son indicateur ; l'ancienne est suspendue.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping,
                             geo_defaut, statut, verifie_par, verifie_le, note)
SELECT 'H12', connecteur, url_base, params, mapping, geo_defaut, 'actif',
       'N. Castillo (délégation du 30.08.2026)', now(),
       'Reprise à l''identique de la liaison 143, transférée de H2 à H12 le 30.08.2026 — même cube STATENT, mêmes cinq classes NOGA 2652, même profondeur (top: 14). Seul l''indicateur porteur change.'
  FROM source_bindings WHERE binding_id = 143;

UPDATE source_bindings
   SET statut = 'suspendu',
       note = note || ' — SUSPENDUE le 30.08.2026 : H2 est passé au recensement CP ; la collecte STATENT continue sous H12.'
 WHERE binding_id = 143;

-- 3. H2 redéfini ------------------------------------------------------
UPDATE indicators SET
  label = 'Emploi de la branche horlogère et microtechnique suisse (recensement CP)',
  source_id = 'cp',
  category = 'composite',
  latence = 'coincident',
  description_metier = 'Effectifs occupés par les industries horlogère et microtechnique suisses, recensés chaque année au 30 septembre par la Convention patronale. Le périmètre inclut la microtechnique, donc les ateliers de mécanique de précision qui travaillent pour l''horlogerie sans être classés en NOGA 26.52 — la réalité d''un sous-traitant comme le cas d''illustration.',
  note_conception = 'REDÉFINI le 30.08.2026 : source OFS/STATENT → recensement de la Convention patronale ; catégorie hard → composite ; périmètre NOGA 26.52 → horlogerie et microtechnique. Les observations STATENT antérieures ont été réattribuées à H12, jamais supprimées.

TRAITEMENT COMPOSITE, et le motif est mesuré, non supposé : le tableau existe dans le document, mais le nœud PDF de l''orchestrateur ne le restitue pas (il jette la coordonnée X ; le PDF est composé colonne par colonne). Concordance mesurée le 30.08 : 2/14, 0/7, 0/1 selon la colonne. La lecture passe donc par la voie MULTIMODALE — PDF entier soumis aux trois éditeurs.

LATENCE relevée de « retardé » à « coïncident » : l''enquête du 30 septembre est publiée en décembre. C''était l''argument décisif du changement de source pour un dispositif de VEILLE.

PROVENANCE : association patronale, source secondaire ; ne jamais écrire « donnée officielle » (règle du § 8.6.4, précédent FH). L''ancrage en statistique publique demeure disponible sous H12.'
WHERE indicator_id = 'H2';

-- 4. H11 : les entreprises, promesse enfin tenue -----------------------
INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency,
                        unit, status, alert_threshold_pct, description_metier,
                        sens_favorable, latence, geo_reference, en_vitrine, note_conception)
VALUES ('H11', 'horlogerie',
        'Entreprises de la branche horlogère et microtechnique suisse (recensement CP)',
        'cp', 'composite', 'annuelle', 'nombre', 'a_confirmer', 5,
        'Nombre d''entités locales exerçant une activité horlogère ou microtechnique en Suisse, recensées au 30 septembre. Le tissu lui-même, et non son volume d''emploi : une branche peut gagner des emplois en perdant des ateliers — c''est exactement le mécanisme que la question de veille QV1 surveille.',
        1, 'coincident', 'CH', true,
        'Créé le 30.08.2026, extrait du MÊME tableau et de la MÊME extraction que H2 (colonne « Entreprises » de Tb. 1e) : aucun appel supplémentaire.

Comble la moitié de la question QV1 horlogère (« emplois ET établissements ») que la grille promettait depuis l''origine sans la porter — le volet « établissements » de STATENT (Beobachtungseinheit = 1) était identifié et non instrumenté depuis le 28.08.

RUPTURE DE DÉFINITION à respecter : la note (2) du tableau indique deux variantes pour 2013 — sans succursales (fait foi pour les comparaisons antérieures) et avec succursales, seule retenue dès le recensement 2014. La série homogène commence donc en 2013 variante 2. Mêler les deux fabriquerait un saut d''environ 15 % sans réalité économique.

Statut « à confirmer » : premier chargement, pas encore de ré-exécution datée qui confirmerait la stabilité de la lecture.')
ON CONFLICT (indicator_id) DO NOTHING;

INSERT INTO indicator_watch_questions (indicator_id, watch_question_code)
VALUES ('H11', 'QV1'), ('H12', 'QV1')
ON CONFLICT DO NOTHING;

-- 5. Le document entre en file composite ------------------------------
INSERT INTO composite_queue (indicator_id, period, geo, source_doc, statut, note)
VALUES ('H2', '2025', 'CH',
        'https://cpih.ch/wp-content/uploads/Recensement-2025-du-personnel-et-des-entreprises-des-industries-horlogere-et-microtechnique-suisses.pdf',
        'a_verifier',
        'Recensement au 30.09.2025, publié en décembre 2025. Un seul document porte toute la série (Tb. 1e, 2005-2025) pour H2 ET H11. Accès vérifié en réponse réelle le 30.08.2026 (HTTP 200, 1 042 607 octets, 13 pages). À VÉRIFIER NOMINATIVEMENT par l''étudiant avant traitement.')
ON CONFLICT (indicator_id, period, source_doc) DO NOTHING;

COMMIT;

-- Contrôles ----------------------------------------------------------
SELECT indicator_id, label, category, source_id, latence, en_vitrine, status
  FROM indicators WHERE indicator_id IN ('H2','H11','H12') ORDER BY indicator_id;

SELECT indicator_id, count(*) AS observations, min(period) AS du, max(period) AS au
  FROM indicator_values WHERE indicator_id IN ('H2','H12') GROUP BY 1 ORDER BY 1;

SELECT indicator_id, binding_id, statut FROM source_bindings
 WHERE indicator_id IN ('H2','H12') ORDER BY indicator_id, binding_id;
