-- =====================================================================
-- A1 : requalification hard -> composite (décision de l'étudiant, 31.08.2026)
--
-- CONTEXTE. A1 (production mondiale de véhicules par pays) était certifié
-- hard, sans liaison ni observation. Deux sources instruites sur pièces le
-- 31.08.2026 : l'annuaire CCFA (PDF 102 p., tableau complet par pays,
-- couche texte lisible — testé) et la page OICA (source primaire déclarée,
-- refonte 2026 : classements top-10 seulement, données incorporées en JSON).
--
-- DÉCISION DE L'ÉTUDIANT : extraction PAR IA (périmètre top-10 accepté),
-- alors que la source est lisible par le code. TENSION DÉCLARÉE, non tue :
-- cela contredit « les chiffres par le code, les mots par l'IA » et le
-- critère du § 8.6.4 (hard/composite jugé sur l'accessibilité réelle au
-- code). A1 passe par l'IA PAR CHOIX D'EXPÉRIMENTATION, non par nécessité —
-- le rapport doit l'écrire tel quel. Contrepartie expérimentale : l'OICA
-- publie la vérité terrain lisible par machine, donc CHAQUE extraction IA
-- est confrontable à un contrôle déterministe de rang 1 — le seul composite
-- de la grille où la cascade entière est mesurable à coût nul.
--
-- À RATIFIER EN SUPERVISION avec le lot § 7.2.2 (même famille que la
-- requalification de S1, pendante).
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-31_a1_requalification_composite.sql \
--     | tee "../annexe_5/a1_requalification_2026-08-31.txt"
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE indicators
   SET category = 'composite',
       seuil_consensus = 1.0,   -- unanimité, comme A2 et H2 : trois modèles, erreurs corrélées
       note_conception = trim(both E'\n' from coalesce(note_conception, '') || E'\n\n' || $txt$REQUALIFIÉ COMPOSITE le 31.08.2026 (décision de l'étudiant, à ratifier — § 7.2.2). Source d'extraction : annuaire CCFA (republication, « Source : OICA » imprimé), tableau « La production mondiale de véhicules » par pays, en milliers. La couche texte du PDF est LISIBLE PAR LE CODE (testé sur l'édition 2025) : le passage par l'IA est un choix d'expérimentation, non une nécessité — assumé comme tel. Contrôle de rang 1 : les classements top-10 de la page OICA (JSON incorporé) servent de vérité terrain déterministe ; une valeur discordante va en file quelle que soit l'unanimité des modèles. Périmètre accepté : les pays du tableau CCFA, vérifiables sur le top-10 OICA pour les plus gros producteurs.$txt$)
 WHERE indicator_id = 'A1';

-- Le document à traiter entre en file, NON VÉRIFIÉ : la vérification
-- nominative (a_verifier -> a_traiter) est l'acte de l'étudiant, premier
-- rang de l'humain — même portillon que la CP.
INSERT INTO composite_queue (indicator_id, period, geo, source_doc, statut)
SELECT 'A1', '2024', 'WORLD', 'https://ccfa.fr/analyses-et-statistiques/', 'a_verifier'
 WHERE NOT EXISTS (SELECT 1 FROM composite_queue WHERE indicator_id = 'A1' AND period = '2024');

COMMIT;

\echo ''
\echo '--- Vérifications'
SELECT indicator_id, category, status, seuil_consensus FROM indicators WHERE indicator_id = 'A1';
SELECT doc_id, indicator_id, period, statut, verifie_par FROM composite_queue WHERE indicator_id = 'A1';
\echo ''
\echo '--- Décompte de la grille après requalification (v_bilan_referentiel fait foi)'
SELECT * FROM v_bilan_referentiel;
