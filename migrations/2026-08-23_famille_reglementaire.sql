-- =====================================================================
-- Nouvelle famille de flux « reglementaire » — 23.08.2026
--
-- Chantier des signaux faibles, étape 3 : déplacement des sources vers
-- l'amont. Les familles existantes couvrent la transaction (marchés
-- publics), la nouvelle (actualité) et le cours (marchés financiers).
-- Aucune ne couvre l'ACTE ADMINISTRATIF QUI AUTORISE — or c'est
-- précisément là que se loge l'antériorité : une autorisation de mise sur
-- le marché précède la montée en cadence de production, donc la charge
-- d'usinage, donc toute statistique qui la constatera.
--
-- La famille `registres` visait les registres d'entreprises (Zefix, vague B)
-- et aurait été un abus de langage ici. Une famille se déclare, elle ne
-- se bricole pas — même doctrine que le reste du dispositif.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

ALTER TABLE flux_sources DROP CONSTRAINT IF EXISTS flux_sources_famille_check;
ALTER TABLE flux_sources ADD CONSTRAINT flux_sources_famille_check
    CHECK (famille IN ('marches_publics','communications','actualite','marches_financiers',
                       'registres','trafic','brevets_flux','emploi','reglementaire'));

COMMIT;

-- Vérification : V15 — la contrainte accepte la nouvelle valeur et refuse
-- toujours une valeur inventée.
SELECT 'V15' AS verif, pg_get_constraintdef(oid) AS contrainte
FROM pg_constraint WHERE conname = 'flux_sources_famille_check';
