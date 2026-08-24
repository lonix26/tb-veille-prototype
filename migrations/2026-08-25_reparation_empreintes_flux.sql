-- 2026-08-25 — Réparation des empreintes des 118 items authentiquement nouveaux
--
-- SUITE de `2026-08-25_retrait_redites_flux.sql`, qui a retiré les 391 redites de la
-- même fournée. Le retrait ne suffit pas : les 118 items conservés — ceux que la
-- fournée avait réellement apportés — portent encore le condensé maison. Au prochain
-- passage de `collecteFluxV1`, désormais corrigé, leur SHA-256 ne correspondra à
-- aucune empreinte au registre : `ON CONFLICT (empreinte)` ne les reconnaîtra pas et
-- ils seront réinsérés. La suppression des redites serait à refaire à chaque
-- exécution. On recalcule donc l'empreinte que le collecteur corrigé produira.
--
-- FORMULE. Identique au nœud « Normaliser les items » : sha256(flux_id | identifiant
-- naturel), parties jointes par « | ». L'identifiant naturel dépend de la famille et
-- se relit dans le `payload` conservé à la collecte — on ne le reconstruit pas depuis
-- l'URL, qui est un affichage, pas une clé :
--   marches_publics : payload->>'publication-number'          (numéro d'avis TED)
--   actualite       : payload->>'url'                          (adresse de l'article)
--   reglementaire   : payload->>(parametres->>'champ_id')      (K-number openFDA, générique)
--
-- CE QUE CETTE MIGRATION NE FAIT PAS. Elle ne touche à aucune valeur collectée :
-- ni titre, ni date, ni URL, ni payload. Seule change la clé technique de
-- déduplication, et elle change vers la valeur que le collecteur aurait écrite si
-- l'empreinte avait été correcte dès le départ. La suspension de D-18 est de même
-- nature et de même portée que dans la migration précédente : bornée à cette
-- transaction, à cette table, et réarmée avant COMMIT sous peine d'annulation.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TEMP TABLE empreintes_reparees ON COMMIT DROP AS
SELECT fi.item_id,
       fi.empreinte AS ancienne,
       encode(digest(fi.flux_id || '|' || CASE fs.famille
                WHEN 'marches_publics' THEN fi.payload->>'publication-number'
                WHEN 'actualite'       THEN fi.payload->>'url'
                WHEN 'reglementaire'   THEN fi.payload->>(fs.parametres->>'champ_id')
              END, 'sha256'), 'hex') AS nouvelle
  FROM flux_items fi
  JOIN flux_sources fs USING (flux_id)
 WHERE length(fi.empreinte) <> 64;

-- Trois garde-fous avant d'écrire : périmètre attendu, identifiant naturel toujours
-- trouvé, et aucune collision — ni entre les nouvelles empreintes, ni avec le registre.
DO $$
DECLARE n integer; nuls integer; doublons integer; collisions integer;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE nouvelle IS NULL) INTO n, nuls FROM empreintes_reparees;
  IF n <> 118 THEN
    RAISE EXCEPTION 'Périmètre inattendu : % items à réparer au lieu de 118.', n;
  END IF;
  IF nuls > 0 THEN
    RAISE EXCEPTION '% item(s) sans identifiant naturel dans le payload — famille non couverte.', nuls;
  END IF;
  SELECT count(*) INTO doublons FROM (
    SELECT nouvelle FROM empreintes_reparees GROUP BY nouvelle HAVING count(*) > 1) d;
  IF doublons > 0 THEN
    RAISE EXCEPTION '% empreinte(s) recalculée(s) en double — la fournée contenait des redites internes.', doublons;
  END IF;
  SELECT count(*) INTO collisions
    FROM empreintes_reparees r
   WHERE EXISTS (SELECT 1 FROM flux_items f
                  WHERE f.empreinte = r.nouvelle AND f.item_id <> r.item_id);
  IF collisions > 0 THEN
    RAISE EXCEPTION '% collision(s) avec le registre — ces items ne sont pas nouveaux.', collisions;
  END IF;
END $$;

ALTER TABLE flux_items DISABLE TRIGGER trg_flux_ajout_seul;
UPDATE flux_items fi
   SET empreinte = r.nouvelle
  FROM empreintes_reparees r
 WHERE fi.item_id = r.item_id;
ALTER TABLE flux_items ENABLE TRIGGER trg_flux_ajout_seul;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgrelid = 'flux_items'::regclass
                    AND tgname  = 'trg_flux_ajout_seul'
                    AND tgenabled <> 'D') THEN
    RAISE EXCEPTION 'Le déclencheur trg_flux_ajout_seul n''a pas été réarmé — annulation.';
  END IF;
  IF EXISTS (SELECT 1 FROM flux_items WHERE length(empreinte) <> 64) THEN
    RAISE EXCEPTION 'Des empreintes fautives subsistent — annulation.';
  END IF;
END $$;

COMMIT;
