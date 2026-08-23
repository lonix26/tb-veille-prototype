-- =====================================================================
-- Regroupement des reprises syndiquées — 23.08.2026
--
-- CONSTAT : la file des signaux faibles présentait le communiqué Implantica
-- en quatre exemplaires à son sommet. L'empreinte de flux_items est un
-- sha256 de l'URL : deux reprises d'un même communiqué sur deux sites, ou
-- la même page en http et en https, produisent deux items distincts.
--
-- flux_items est en AJOUT SEUL : cela ne se corrige pas en réécrivant les
-- empreintes. Le regroupement est donc une couche de LECTURE.
--
-- CHOIX DE LA CLÉ — conservateur à dessein. Une première tentative de
-- regroupement (hors base, le 23.08) triait les mots du titre par ordre
-- alphabétique : elle a fusionné un article ukrainien sur la localisation
-- de production aéronautique, un article chinois sur un brevet de plaquettes
-- de frein et un troisième sur l'aviation légère — trois événements sans
-- aucun rapport. Un faux regroupement est PIRE qu'un doublon : le doublon
-- se voit, la fusion abusive fait disparaître un signal.
--
-- La clé retenue exige donc une correspondance EXACTE du titre normalisé :
--   * minuscules, ponctuation et espaces réduits à un espace simple ;
--   * les caractères non latins sont PRÉSERVÉS (pas de filtre alnum, qui
--     dépend de la locale et effacerait le chinois et le cyrillique) ;
--   * en dessous de 25 caractères, le titre est jugé trop court pour
--     identifier un événement : on retombe sur l'URL normalisée.
-- L'URL normalisée retire le protocole, le www, la chaîne de requête et le
-- fragment — ce qui suffit au cas http/https rencontré.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION cle_evenement(titre TEXT, url TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN length(t) >= 25 THEN 'T:' || t
    ELSE 'U:' || u
  END
  FROM (
    SELECT btrim(regexp_replace(lower(coalesce(titre, '')), '[[:space:][:punct:]]+', ' ', 'g')) AS t,
           btrim(regexp_replace(
                   regexp_replace(
                     regexp_replace(lower(coalesce(url, '')), '^https?://(www\.)?', ''),
                   '[?#].*$', ''),
                 '/+$', '')) AS u
  ) n;
$$;

COMMENT ON FUNCTION cle_evenement(TEXT, TEXT) IS
  'Clé de regroupement des reprises syndiquées. Correspondance EXACTE du titre normalisé (casse, ponctuation, espaces), repli sur l''URL normalisée pour les titres de moins de 25 caractères. Volontairement conservatrice : un faux regroupement fait disparaître un signal, un doublon se voit seulement.';

-- ---------------------------------------------------------------------
-- File des signaux faibles, une ligne par ÉVÉNEMENT.
-- Le représentant retenu est la reprise la PLUS ANCIENNE : c'est elle qui
-- porte l'antériorité réelle. Le nombre de reprises est conservé — l'écho
-- d'un événement dans plusieurs organes est une information, pas du bruit.
-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW v_signaux_faibles_groupes AS
WITH base AS (
    SELECT s.*, cle_evenement(s.titre, s.url) AS cle_evt
    FROM v_signaux_faibles s
),
classe AS (
    SELECT b.*,
           COUNT(*)      OVER (PARTITION BY b.cle_evt) AS n_reprises,
           MIN(b.date_publication) OVER (PARTITION BY b.cle_evt) AS premiere_parution,
           ROW_NUMBER()  OVER (PARTITION BY b.cle_evt
                               ORDER BY b.date_publication NULLS LAST, b.item_id) AS rang
    FROM base b
)
SELECT item_id, cle_evt, n_reprises, premiere_parution,
       famille, flux, sector_code, watch_question_code,
       anteriorite, portee, pertinence_doctrine_signal, pertinence_doctrine_evenement,
       titre, url, resume, justification
FROM classe WHERE rang = 1
ORDER BY anteriorite DESC, portee DESC, n_reprises DESC, premiere_parution DESC;

COMMENT ON VIEW v_signaux_faibles_groupes IS
  'File des signaux faibles dédoublonnée des reprises syndiquées, une ligne par événement. Représentant = la reprise la plus ancienne (elle porte l''antériorité réelle). n_reprises expose l''écho : un événement repris par quatre organes n''est pas équivalent à un événement isolé.';

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V13 : le nombre d'événements distincts est INFÉRIEUR au nombre d'items,
--         et supérieur au décompte erroné de 26 obtenu hors base par une
--         normalisation trop agressive.
--   V14 : aucun groupe ne mêle deux domaines de premier niveau différents
--         ET deux dates de parution écartées de plus de trois jours —
--         garde-fou contre une fusion abusive du type de celle du 23.08.
-- ---------------------------------------------------------------------

SELECT 'V13' AS verif,
       (SELECT COUNT(*) FROM v_signaux_faibles)         AS items,
       (SELECT COUNT(*) FROM v_signaux_faibles_groupes) AS evenements;

SELECT 'V14' AS verif, cle_evt, COUNT(*) AS reprises,
       MAX(date_publication) - MIN(date_publication) AS etalement_jours,
       string_agg(DISTINCT split_part(regexp_replace(url, '^https?://(www\.)?', ''), '/', 1), ' | ') AS domaines
FROM (SELECT s.*, cle_evenement(s.titre, s.url) AS cle_evt FROM v_signaux_faibles s) x
GROUP BY cle_evt HAVING COUNT(*) > 1
ORDER BY reprises DESC;
