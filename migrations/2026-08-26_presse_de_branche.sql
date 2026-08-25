-- =====================================================================
-- 2026-08-26 — LA PRESSE DE BRANCHE ENTRE AU DISPOSITIF (étage 2)
--
-- LE CONSTAT QUI FONDE L'AJOUT. L'évaluation du tableau de veille consolidé
-- (26.08) a chiffré un déséquilibre : ~70 % du portefeuille est de la
-- statistique officielle — irréprochable pièce par pièce, mais composée
-- comme le portefeuille d'un économiste, pas d'un veilleur. Il y manquait
-- les types de sources qui donnent de l'AVANCE : presse professionnelle de
-- branche, salons, rapports des donneurs d'ordre, offres d'emploi. Décision
-- de l'étudiant du 26.08.2026 (carte blanche explicite) : intégrer ce qui
-- est intégrable en réponse réelle, documenter le reste.
--
-- OÙ CELA ENTRE, ET POURQUOI LÀ. La presse de branche N'EST PAS un
-- indicateur : elle ne produit pas de série. C'est un flux de SIGNAUX, et
-- le dispositif possède déjà l'étage qui les traite — flux_sources →
-- collecte (le lecteur RSS de la famille « communications » existe depuis
-- le 23.08) → triage IA → examen humain → « dix de la semaine ». Aucun
-- nouveau mécanisme : huit lignes de configuration dans un étage éprouvé.
-- C'est la doctrine appliquée : les chiffres par le code, les mots par
-- l'IA, la validation par l'humain.
--
-- RECONNAISSANCE DU 26.08.2026 — vingt et un fils testés en réponse réelle.
-- Huit retenus (deux par marché). Écartés, avec leur motif :
--   Europa Star (200 mais HTML, pas de fil), WatchPro (403), WorldTempus
--   (404), Journal FHH (503), Hodinkee (fil vide), MassDevice (403),
--   aero-mag (403), MSM (404) ;
--   Just Auto (retenu vivant mais ÉCARTÉ : généraliste, recouvre CLEPA et
--   electrive), FlightGlobal et Aviation Week (fils vivants mais contenu
--   d'exploitation aérienne civile, payant au clic — loin de l'usinage).
-- Un fil qui répond n'est pas pour autant un fil exploitable ; et un fil
-- exploitable n'est pas pour autant utile — les deux tris sont distincts.
--
-- LE COÛT DU TRIAGE EST LE COÛT RÉEL DE CET AJOUT : chaque item collecté
-- passe au triage IA. Huit fils × 10-30 items initiaux ≈ 100-150 items au
-- premier passage, puis le régime de croisière ne trie que le neuf
-- (déduplication par empreinte). À consigner après exécution.
-- =====================================================================

BEGIN;

INSERT INTO flux_sources (flux_id, famille, sector_code, libelle, url_base, parametres, statut, qualified_by, qualified_at, note) VALUES

-- ---------- HORLOGERIE — le marché sans signal d'avance (§ 8.7.2) ----------
('presse_horlogerie_monochrome', 'communications', 'horlogerie',
 'Monochrome Watches — presse horlogère (fil RSS)',
 'https://monochrome-watches.com/feed/',
 '{"_note": "Presse de marché : nouveautés produits, tendances de gamme, mouvements de manufacture. Lecture pour QV2 (où va la demande) et QV4 (montre connectée, matériaux). Vu en réponse réelle le 26.08.2026 : 10 items datés."}',
 'actif', 'N. Castillo (délégation du 26.08.2026)', '2026-08-26',
 'Le seul fil horloger exploitable trouvé sur huit testés : Europa Star sert du HTML, WatchPro et le Journal FHH refusent (403/503), WorldTempus 404, Hodinkee un fil vide. La rareté des fils horlogers est elle-même une information sur la branche.'),

('salon_ephj', 'communications', 'horlogerie',
 'EPHJ — actualités du salon (fil RSS)',
 'https://www.ephj.ch/feed/',
 '{"_note": "LE salon de la haute précision suisse (horlogerie-joaillerie, microtechnique, medtech) — exposants, tendances, lauréats. Un salon est un capteur d''écosystème : ce qui s''y annonce précède ce qui se produit. Couvre aussi le médical et la microtechnique. Vu en réponse réelle le 26.08.2026 : 10 items."}',
 'actif', 'N. Castillo (délégation du 26.08.2026)', '2026-08-26',
 'Type de source « salons » identifié à l''évaluation du 26.08 comme absent du portefeuille. EPHJ est le seul salon du périmètre avec un fil exploitable — et c''est le plus pertinent : c''est celui du tissu de sous-traitance de précision lui-même.'),

-- ---------- MÉDICAL ----------
('presse_medtech_dive', 'communications', 'medical',
 'MedTech Dive — presse medtech (fil RSS)',
 'https://www.medtechdive.com/feeds/news/',
 '{"_note": "Presse professionnelle medtech : autorisations, rappels, stratégie des fabricants, chaînes d''approvisionnement. Complète M8 (510k) par le contexte que le décompte ne porte pas. Vu en réponse réelle le 26.08.2026 : 10 items."}',
 'actif', 'N. Castillo (délégation du 26.08.2026)', '2026-08-26',
 'Presse spécialisée de premier rang, gratuite, quotidienne.'),

('presse_medical_outsourcing', 'communications', 'medical',
 'Medical Design & Outsourcing — sous-traitance medtech (fil RSS)',
 'https://www.medicaldesignandoutsourcing.com/feed/',
 '{"_note": "LA presse de la sous-traitance médicale — littéralement le métier du destinataire vu du côté client : externalisation, choix de fournisseurs, usinage de précision, matériaux. Vu en réponse réelle le 26.08.2026 : 25 items."}',
 'actif', 'N. Castillo (délégation du 26.08.2026)', '2026-08-26',
 'La trouvaille de la reconnaissance : une source qui parle de l''étage adressable lui-même, pas du marché final.'),

-- ---------- AUTOMOBILE ----------
('presse_equipementiers_clepa', 'communications', 'automobile',
 'CLEPA — association des équipementiers européens (fil RSS)',
 'https://clepa.eu/feed/',
 '{"_note": "La voix officielle des équipementiers automobiles européens — l''ÉTAGE ADRESSABLE du § 8.6, qui s''exprime : positions réglementaires, alertes de filière, emploi. Source primaire d''association, pas une reprise de presse. Vu en réponse réelle le 26.08.2026 : 10 items."}',
 'actif', 'N. Castillo (délégation du 26.08.2026)', '2026-08-26',
 'Quand la CLEPA alerte sur la filière, c''est le carnet de commandes des sous-traitants qui parle avec six mois d''avance sur les statistiques.'),

('presse_auto_electrive', 'communications', 'automobile',
 'electrive — transition électrique de l''automobile (fil RSS)',
 'https://www.electrive.com/feed/',
 '{"_note": "Presse spécialisée de la transition électrique : investissements d''usines, annonces de capacité, choix technologiques. C''est QV4 (dynamique technologique) en flux — la recomposition des familles de pièces qui touche directement un usineur. Vu en réponse réelle le 26.08.2026 : 30 items."}',
 'actif', 'N. Castillo (délégation du 26.08.2026)', '2026-08-26',
 'Just Auto, vivant, a été écarté : généraliste, il recouvre CLEPA et electrive sans leur angle.'),

-- ---------- AÉROSPATIAL ----------
('presse_spatial_spacenews', 'communications', 'aerospatial',
 'SpaceNews — industrie spatiale (fil RSS)',
 'https://spacenews.com/feed/',
 '{"_note": "Presse de référence du spatial : contrats, constellations, lanceurs, budgets. Les constellations demandent de la série là où le spatial était unitaire — l''effet sur la sous-traitance identifié au § 8.4.5. Vu en réponse réelle le 26.08.2026 : 20 items."}',
 'actif', 'N. Castillo (délégation du 26.08.2026)', '2026-08-26',
 'FlightGlobal et Aviation Week, vivants, ont été écartés : exploitation aérienne civile, payant au clic — loin de l''usinage.'),

('presse_aero_manufacturing', 'communications', 'aerospatial',
 'Aerospace Manufacturing & Design — production aéronautique (fil RSS)',
 'https://www.aerospacemanufacturinganddesign.com/rss/',
 '{"_note": "Presse de la PRODUCTION aéronautique : extensions d''usines, machines-outils, certifications, chaînes de fournisseurs. L''étage adressable du secteur, vu du côté industriel. Vu en réponse réelle le 26.08.2026 : 20 items."}',
 'actif', 'N. Castillo (délégation du 26.08.2026)', '2026-08-26',
 'Avec Medical Design & Outsourcing, l''autre source qui parle du métier et non du marché final.');

COMMIT;
