-- =====================================================================
-- 02.09.2026 — Liste B, acte 1 : décision des 19 candidats de la couche 0
-- (run de découverte du 22.08.2026, QV5 automobile). Jusqu'ici la file
-- source_qualification_queue avait été alimentée et jamais décidée (IA-20).
-- Décisions de l'étudiant, une par candidat, chacune avec son motif.
-- Raisonnement appliqué dans l'ordre : (1) jeu de données ou simple page ;
-- (2) réponse à la question de veille posée ; (3) quatre critères
-- d'admissibilité du cadrage ; (4) redondance. Le consensus a priorisé
-- (le seul candidat à 3 modèles est le seul inscrit), il n'a pas décidé.
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

-- La file n'avait pas de colonne de motif (A3 l'avait ajoutée aux autres
-- files) : une décision sans motif n'est pas auditable.
ALTER TABLE source_qualification_queue ADD COLUMN IF NOT EXISTS motif text;
COMMENT ON COLUMN source_qualification_queue.motif IS
  'Motif de la décision humaine, obligatoire dès qu''une décision est posée (02.09.2026).';

CREATE TEMP TABLE d (item_id int, decision text, motif text);
INSERT INTO d VALUES
 (2,'inscrite','Série annuelle ACEA « Electric cars: tax benefits and incentives » : 3 modèles sur 4, gratuit, PDF tabulaire comparatif par pays, éditions 2023-2026 constatées ; répond exactement à QV5. Inscrite sous acea_incitations, statut a_confirmer (accès vérifié, granularité d''extraction non validée), sans liaison de collecte.'),
 (12,'ecartee','Doublon du candidat 2 : même série ACEA, édition 2023.'),
 (14,'ecartee','Doublon du candidat 2 : même série ACEA, édition 2026.'),
 (18,'differee','European Alternative Fuels Observatory (DG MOVE) : gratuit, chiffré, tenu à jour, répond à QV5 ; jeu précis, fréquence et format non identifiés sans ouverture détaillée — à qualifier après le gel.'),
 (10,'ecartee','Sous-page « Road » du candidat 18 (EAFO).'),
 (9,'differee','State aid scoreboard (DG Concurrence) : annuel, gratuit, aides d''État par État membre et objectif ; pas de ventilation automobile directe — à qualifier après le gel.'),
 (3,'differee','AFDC (DOE) Federal and state laws and incentives : répertoire qualitatif de lois et d''incitations US, gratuit, tenu à jour ; pas de série chiffrée — relèverait d''une source de flux (étage 2), non d''un indicateur.'),
 (15,'ecartee','Sous-page cartographique du candidat 3 (AFDC).'),
 (16,'ecartee','Sous-page « State laws » du candidat 3 (AFDC).'),
 (17,'ecartee','Outil de recherche DOE, doublon fonctionnel du candidat 3 ; pas de série.'),
 (20,'ecartee','Page d''orientation DOT renvoyant vers l''AFDC (candidat 3) ; « Access Denied » le 02.09 avec en-tête navigateur.'),
 (6,'differee','US EPA Automotive Trends : base libre et profonde, mais mesure l''efficacité énergétique des véhicules, non les impulsions publiques — à réorienter vers QV4 (dynamique technologique).'),
 (11,'differee','CAAM (Chine) : production et ventes mensuelles, gratuit ; répond à QV2 (demande), non à QV5 ; recouvrement partiel avec l''OICA déjà au référentiel ; http non sécurisé.'),
 (7,'ecartee','Avis administratif ponctuel du MIIT (lot d''homologation n° 404) : pas une source périodique ; matière à flux événementiel, pas au référentiel.'),
 (8,'ecartee','Avis interministériel ponctuel (MIIT, Commerce, Douanes, SAMR) : pas une source périodique ; matière à flux événementiel.'),
 (4,'ecartee','Jeu du datahub AEE non identifiable (page applicative sans titre ni description lisible) ; un seul modèle, indice 0,25.'),
 (5,'ecartee','FHWA, financement IIJA : page de programme d''infrastructure US, non périodique, sans série ; « Access Denied » le 02.09.'),
 (13,'ecartee','ICCT : page de publications d''un centre de recherche, pas un jeu de données ; source de flux éventuelle.'),
 (19,'ecartee','Tax Foundation : groupe de réflexion, taxes par État américain ; un seul modèle ; pertinence faible pour une PME suisse.');

UPDATE source_qualification_queue q
   SET decision = d.decision, motif = d.motif,
       decided_by = 'N. Castillo', decided_at = now()
  FROM d WHERE q.item_id = d.item_id AND q.decision IS NULL;

-- L'inscription est réelle, sinon « inscrite » serait une surdéclaration.
INSERT INTO sources (source_id, name, organisation, url, frequency, format, access,
                     qualification_status, qualified_by, qualified_at, notes)
VALUES ('acea_incitations',
        'Electric cars: tax benefits and incentives (fiscalité et aides à l''achat, par pays)',
        'ACEA',
        'https://www.acea.auto/fact/electric-cars-tax-benefits-and-incentives-2025/',
        'annuelle', 'PDF tabulaire (tableau comparatif par pays)', 'libre',
        'a_confirmer', 'N. Castillo', now(),
        'Issue de la couche 0 (run du 22.08.2026, QV5 automobile, candidat 2, 3 modèles sur 4). Inscrite le 02.09.2026 sans liaison de collecte : accès vérifié en réponse réelle (HTTP 200 les 22.08 et 02.09), granularité d''extraction non validée. Pas d''indicateur rattaché à ce jour.');

-- Contrôles
SELECT decision, count(*) FROM source_qualification_queue GROUP BY 1 ORDER BY 1;
SELECT count(*) AS sans_motif FROM source_qualification_queue WHERE decision IS NOT NULL AND motif IS NULL;
SELECT source_id, qualification_status, qualified_at::date FROM sources WHERE source_id = 'acea_incitations';
SELECT qualification_status, count(*) FROM sources GROUP BY 1;
COMMIT;
