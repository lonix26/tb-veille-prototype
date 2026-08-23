-- ============================================================================
-- Qualification humaine des flux de l'étage 2 — N. Castillo, 24.08.2026
--
-- Régularise l'écart relevé au § 11.8 : la chaîne a collecté sur des liaisons
-- restées `a_verifier`, contrairement à la règle du § 10.4. La qualification
-- est ici portée nominativement, avec pour chaque flux ce qui a été VU EN
-- RÉPONSE RÉELLE — jamais ce qui était supposé.
--
-- Les quatre flux `marches_financiers` ne figurent pas ici : ils ont été
-- écartés à ce même nom le 23.08.2026 (symboles Stooq inaccessibles).
-- ============================================================================

BEGIN;

-- --- Marchés publics -------------------------------------------------------

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='CPV 33100000 (équipements médicaux). Décompte vérifié en réponse réelle TED v3 le 23.08.2026 : 11 752 avis sur 60 jours, 250 enrichis en base. Alimente M7 (comptage mensuel) et l''écran Actions.'
WHERE flux_id='ted_medical';

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='CPV 34700000 (aéronefs et engins spatiaux). Décompte vérifié en réponse réelle le 23.08.2026, 75 items. Alimente S7 (comptage mensuel). Réserve : la lecture décisionnelle du 24.08 n''y a trouvé aucun avis adressable — les avis relèvent d''achat d''appareils complets, de MRO et de distribution, non de sous-traitance d''usinage.'
WHERE flux_id='ted_aerospatial';

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='CPV affinés 34310000, 34312000, 34320000 (moteurs, pièces de moteurs, pièces mécaniques). Vérifiés en réponse réelle le 23.08.2026 : 163 avis sur 60 jours, tous enrichis. Remplace ted_automobile, dont le CPV 34300000 était trop large.'
WHERE flux_id='ted_automobile_v2';

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='CPV 34630000 (pièces de locomotives et matériel ferroviaire roulant). Vérifié en intitulés sur réponse réelle le 24.08.2026 : 381 avis sur 60 jours, intitulés confirmés comme pièces et non voie ni matériel complet. Ajouté sur découverte du dispositif, non sur hypothèse — les seuls avis usinables des trois autres secteurs étaient ferroviaires. SECTEUR NUL À DESSEIN : l''extension de la grille du ch. 8 à un cinquième marché reste à trancher en supervision.'
WHERE flux_id='ted_ferroviaire';

-- Conservé, mais non réactivé : décision de l'étudiant du 23.08.2026,
-- « l'ancien reste en preuve ». Les 250 avis déjà collectés restent en base et
-- documentent l'affinage du CPV ; la liaison ne collecte plus.
UPDATE flux_sources SET statut='ecarte', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='CPV 34300000 (pièces et accessoires pour véhicules), trop large : la lecture décisionnelle y a trouvé un avis adressable sur 39. Remplacé par ted_automobile_v2 aux CPV affinés le 23.08.2026. Écarté de la collecte, CONSERVÉ EN PREUVE : les 250 avis déjà en base établissent la comparaison avant/après affinage.'
WHERE flux_id='ted_automobile';

-- --- Réglementaire ---------------------------------------------------------

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='openFDA, point d''accès 510(k), sans clé d''API. Vu en réponse réelle le 23.08.2026, 50 items. Deux particularités de transport documentées et traitées : le séparateur +TO+ des bornes de date ne doit pas être encodé, et un code 404 signifie « aucun résultat », non une erreur. Alimente M8 (comptage mensuel) et la file d''examen.'
WHERE flux_id='fda_510k_medical';

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='openFDA, point d''accès des rappels de dispositifs. Vu en réponse réelle le 23.08.2026, 3 items sur la fenêtre. Volume faible assumé : un rappel est un événement rare, et c''est précisément sa rareté qui en fait un signal.'
WHERE flux_id='fda_rappels_medical';

-- --- Actualité -------------------------------------------------------------

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='GDELT DOC 2.0, requête sectorielle. Vue en réponse réelle le 22.08.2026, 50 articles.'
WHERE flux_id='gdelt_automobile';

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='GDELT DOC 2.0. Vue en réponse réelle le 22.08.2026, 11 articles seulement — le vocabulaire horloger est peu représenté dans le corpus de presse indexé. Retenu malgré le faible rendement : une absence mesurée vaut mieux qu''une absence supposée.'
WHERE flux_id='gdelt_horlogerie';

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='GDELT DOC 2.0, requête SIMPLIFIÉE. Vue en réponse réelle le 23.08.2026, 50 articles. Réserve à porter au rapport : la requête précise, à parenthèses imbriquées, a été refusée durablement par le service (limitation de débit renvoyée en HTTP 200 avec corps non-JSON) ; la version simplifiée est un compromis dont la précision est moindre — les articles rendus ne sont pas tous pertinents.'
WHERE flux_id='gdelt_medical';

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='GDELT DOC 2.0, requête SIMPLIFIÉE, même réserve que gdelt_medical. Vue en réponse réelle le 23.08.2026, 49 articles, dont plusieurs manifestement hors sujet (aéroports, titres boursiers) — la charge de tri retombe sur le triage IA et l''examen humain.'
WHERE flux_id='gdelt_aerospatial';

-- --- Communications --------------------------------------------------------

UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=DATE '2026-08-24',
  note='Fil de syndication des communiqués Boeing. Vu en réponse réelle le 23.08.2026, 5 items. Source primaire de constructeur : ce qu''elle publie est daté et attribuable, ce qui la distingue des reprises de presse.'
WHERE flux_id='boeing_communiques';

COMMIT;

-- Contrôle : aucun flux ne doit rester sans trace de qualification.
SELECT statut, count(*) AS flux,
       count(*) FILTER (WHERE qualified_by IS NULL) AS sans_trace
FROM flux_sources GROUP BY 1 ORDER BY 1;
