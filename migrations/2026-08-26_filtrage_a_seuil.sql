-- =====================================================================
-- Filtrage à seuil de la file d'examen — 26.08.2026
--
-- LE PROBLÈME. Le triage IA ORDONNE la file mais ne la FILTRE jamais :
-- 926 items attendaient un examen humain, dont 75 % notés 2 ou moins sur
-- 6. Un dispositif semi-automatisé qui laisse à l'humain une file qu'il
-- ne peut pas épuiser ne lui fait pas gagner de temps — il déplace le
-- goulot de la collecte vers la validation, sans le résoudre.
--
-- LE DÉPLACEMENT DU CONTRÔLE. La doctrine « la validation par l'humain »
-- porte sur ce qui ATTEINT LE DÉCIDEUR. Un item écarté ne l'atteint
-- jamais. Le contrôle humain se déplace donc de l'item vers LA RÈGLE :
-- l'humain ne valide plus 926 items un par un, il valide un énoncé et en
-- vérifie l'application sur un échantillon tiré au sort. C'est le
-- contrôle statistique de processus, et il a une propriété que
-- l'examen exhaustif n'a pas : IL PRODUIT UNE MESURE. « Taux de faux
-- négatifs de 0/10 sur l'échantillon d'août » est un résultat ;
-- « 926 items non examinés » est un aveu.
--
-- CE QUI FONDE LA RÈGLE, ET SA FAIBLESSE. Sur les 37 items examinés à ce
-- jour, aucun de ceux notés 2 ou moins n'a produit de signal (14
-- examinés, 13 écartés, 1 retenu en contexte) ; le seul signal promu
-- venait d'un item noté 6. Les deux doctrines de triage convergent sur
-- ces items : aucun item faible en « signal » n'est fort en
-- « evenement ». MAIS QUATORZE OBSERVATIONS NE FONDENT PAS UNE LOI. La
-- règle est donc déclarée provisoire, et l'échantillon d'audit est sa
-- validation permanente, pas une formalité.
--
-- LE GARDE-FOU N'EST PAS DÉCORATIF. 19 items notés 2 ou moins portent
-- une antériorité maximale — le modèle les juge fortement anticipateurs
-- tout en les trouvant peu pertinents ou peu portants. L'anticipation
-- étant l'objet même du dispositif, et le coût d'un faux négatif étant
-- très supérieur à celui d'un faux positif, ces items ne sont jamais
-- filtrés.
--
-- AJOUT SEUL (D-18). flux_filtrage est en ajout seul comme le registre.
-- Un faux négatif détecté à l'audit ne s'y efface pas : il se répare par
-- un SECOND ajout, dans flux_filtrage_audit, que la vue de file relit
-- pour restituer l'item. Rien n'est réécrit, tout est traçable.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. La règle, énoncée, versionnée, datée
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS flux_filtrage_regles (
  regle_code    text PRIMARY KEY,
  libelle       text NOT NULL,
  enonce        text NOT NULL,     -- la règle en français, lisible par un humain
  seuil         smallint NOT NULL, -- note strictement inférieure = écartée
  active        boolean NOT NULL DEFAULT true,
  cree_le       timestamptz NOT NULL DEFAULT now(),
  fondement     text NOT NULL      -- sur quoi elle repose, y compris ses limites
);

INSERT INTO flux_filtrage_regles (regle_code, libelle, enonce, seuil, fondement)
VALUES (
  'seuil_v1',
  'Seuil de triage à 3, avec garde-fou d''antériorité',
  'Un item est écarté sans examen humain si sa note de triage sous la doctrine « signal » '
  '(antériorité + portée + pertinence, sur 6) est strictement inférieure à 3, '
  'SAUF si son antériorité vaut 2 — un item jugé fortement anticipateur est toujours soumis '
  'à l''humain, quelle que soit sa note globale. Les items non triés ne sont jamais filtrés.',
  3,
  'Sur 37 items examinés au 26.08.2026, aucun item noté 2 ou moins n''a produit de signal '
  '(14 examinés : 13 écartés, 1 retenu en contexte). Le seul signal promu venait d''un item '
  'noté 6. Les deux doctrines de triage convergent : aucun item faible en « signal » n''est '
  'fort en « evenement ». LIMITE ASSUMÉE : quatorze observations ne fondent pas une loi. '
  'La règle est provisoire et sa validation permanente est l''échantillon d''audit mensuel.'
) ON CONFLICT (regle_code) DO NOTHING;

-- ---------------------------------------------------------------------
-- 2. Ce que la règle a écarté — en ajout seul
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS flux_filtrage (
  item_id     bigint PRIMARY KEY REFERENCES flux_items(item_id),
  regle_code  text NOT NULL REFERENCES flux_filtrage_regles(regle_code),
  note_ia     smallint NOT NULL,
  anteriorite smallint,
  motif       text NOT NULL,
  filtre_le   timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION f_filtrage_ajout_seul() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'flux_filtrage est en ajout seul (D-18) : un filtrage ne se '
                  'corrige pas par écrasement mais par un verdict d''audit.';
END $$;

DROP TRIGGER IF EXISTS trg_filtrage_ajout_seul ON flux_filtrage;
CREATE TRIGGER trg_filtrage_ajout_seul
  BEFORE UPDATE OR DELETE ON flux_filtrage
  FOR EACH ROW EXECUTE FUNCTION f_filtrage_ajout_seul();

-- ---------------------------------------------------------------------
-- 3. L'audit humain — le contrôle qui a remplacé l'examen exhaustif
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS flux_filtrage_audit (
  audit_id    bigserial PRIMARY KEY,
  item_id     bigint NOT NULL REFERENCES flux_items(item_id),
  echantillon text NOT NULL,          -- 'YYYY-MM' du tirage
  verdict     text NOT NULL CHECK (verdict IN ('confirme','faux_negatif')),
  audite_par  text NOT NULL,
  audite_le   timestamptz NOT NULL DEFAULT now(),
  note        text,
  UNIQUE (item_id, echantillon)
);

-- ---------------------------------------------------------------------
-- 4. Application de la règle — idempotente, appelable à chaque triage
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION appliquer_filtrage_flux() RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE r record; n integer := 0;
BEGIN
  FOR r IN
    SELECT rg.regle_code, rg.seuil,
           t.item_id,
           t.anteriorite + t.portee + t.pertinence AS note,
           t.anteriorite
      FROM flux_filtrage_regles rg
      JOIN flux_triage_ia t ON t.doctrine = 'signal'
     WHERE rg.active
       AND rg.regle_code = 'seuil_v1'
       AND t.anteriorite + t.portee + t.pertinence < rg.seuil
       AND t.anteriorite < 2                                   -- garde-fou
       AND NOT EXISTS (SELECT 1 FROM flux_filtrage f WHERE f.item_id = t.item_id)
       AND NOT EXISTS (SELECT 1 FROM flux_examens x WHERE x.item_id = t.item_id)
  LOOP
    INSERT INTO flux_filtrage (item_id, regle_code, note_ia, anteriorite, motif)
    VALUES (r.item_id, r.regle_code, r.note, r.anteriorite,
            format('Note %s/6 (< %s), antériorité %s : écarté par règle %s.',
                   r.note, r.seuil, r.anteriorite, r.regle_code));
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;

-- ---------------------------------------------------------------------
-- 5. La file d'examen — désormais filtrée, avec restitution des faux négatifs
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_flux_a_examiner AS
 SELECT fi.item_id,
    fs.famille,
    fs.libelle AS flux,
    COALESCE(s.sector_code, e.sector_code) AS sector_code,
    COALESCE(s.watch_question_code, e.watch_question_code) AS watch_question_code,
    e.pertinence,
    s.anteriorite,
    s.portee,
    s.pertinence AS pertinence_signal,
    COALESCE(s.resume, e.resume) AS resume,
    fi.titre,
    fi.url,
    fi.date_publication,
    fi.collecte_le
   FROM flux_items fi
     JOIN flux_sources fs ON fs.flux_id = fi.flux_id
     LEFT JOIN flux_triage_ia e ON e.item_id = fi.item_id AND e.doctrine = 'evenement'
     LEFT JOIN flux_triage_ia s ON s.item_id = fi.item_id AND s.doctrine = 'signal'
  WHERE NOT EXISTS (SELECT 1 FROM flux_examens x WHERE x.item_id = fi.item_id)
    -- Filtré par règle, SAUF si l'audit humain l'a reconnu faux négatif :
    -- la réparation se fait par ajout, jamais par effacement.
    AND (NOT EXISTS (SELECT 1 FROM flux_filtrage f WHERE f.item_id = fi.item_id)
         OR EXISTS (SELECT 1 FROM flux_filtrage_audit a
                     WHERE a.item_id = fi.item_id AND a.verdict = 'faux_negatif'))
  ORDER BY s.anteriorite DESC NULLS LAST, s.portee DESC NULLS LAST,
           e.pertinence DESC NULLS LAST, fi.date_publication DESC;

-- ---------------------------------------------------------------------
-- 6. L'échantillon d'audit — tirage reproductible, dix items par mois
--
-- Le rang est déterministe : même mois, même tirage, quel que soit le
-- nombre de fois où la vue est interrogée. Le sel mensuel fait tourner
-- l'échantillon d'un mois à l'autre. Aucun aléa non reproductible : le
-- dispositif doit pouvoir rejouer son propre contrôle.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_filtrage_echantillon AS
SELECT to_char(now(), 'YYYY-MM') AS echantillon,
       row_number() OVER (ORDER BY md5(f.item_id::text || to_char(now(), 'YYYY-MM'))) AS rang,
       f.item_id, f.note_ia, f.anteriorite, f.regle_code,
       fs.famille, fi.titre, fi.url, fi.date_publication,
       s.resume
  FROM flux_filtrage f
  JOIN flux_items fi ON fi.item_id = f.item_id
  JOIN flux_sources fs ON fs.flux_id = fi.flux_id
  LEFT JOIN flux_triage_ia s ON s.item_id = f.item_id AND s.doctrine = 'signal'
 WHERE NOT EXISTS (SELECT 1 FROM flux_filtrage_audit a
                    WHERE a.item_id = f.item_id
                      AND a.echantillon = to_char(now(), 'YYYY-MM'));

-- ---------------------------------------------------------------------
-- 7. Le bilan — ce que le filtrage a fait, et ce que l'audit en dit
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_bilan_filtrage AS
WITH b AS (
  SELECT (SELECT count(*) FROM flux_items)                        AS items_collectes,
         (SELECT count(*) FROM flux_filtrage)                     AS items_filtres,
         (SELECT count(*) FROM v_flux_a_examiner)                 AS file_humaine,
         (SELECT count(*) FROM flux_examens)                      AS examens_humains,
         (SELECT count(*) FROM flux_filtrage_audit)               AS items_audites,
         (SELECT count(*) FROM flux_filtrage_audit
           WHERE verdict = 'faux_negatif')                        AS faux_negatifs
)
SELECT b.*,
       CASE WHEN b.items_filtres + b.file_humaine > 0
            THEN round(100.0 * b.items_filtres / (b.items_filtres + b.file_humaine), 1)
       END AS part_filtree_pct,
       CASE WHEN b.items_audites > 0
            THEN round(100.0 * b.faux_negatifs / b.items_audites, 1)
       END AS taux_faux_negatifs_pct,
       CASE WHEN b.items_audites = 0
            THEN 'Règle appliquée, jamais auditée : le taux de faux négatifs est inconnu.'
            WHEN b.faux_negatifs = 0
            THEN format('Aucun faux négatif sur %s items audités.', b.items_audites)
            ELSE format('%s faux négatifs sur %s items audités — la règle doit être révisée.',
                        b.faux_negatifs, b.items_audites)
       END AS enonce_audit
  FROM b;

COMMIT;
