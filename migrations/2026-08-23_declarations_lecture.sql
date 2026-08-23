-- =====================================================================
-- Déclarations de lecture — 23.08.2026
--
-- REVUE HUMAINE, indicateur par indicateur, par N. Castillo le 23.08.2026,
-- sur le tableau soumis en session terminale. Ces déclarations sont des
-- ACTES DE QUALIFICATION : elles inscrivent une hypothèse de lecture que
-- le code ne doit jamais présumer. Troisième application de la doctrine,
-- après `admet_negatifs` et le correctif `geo_reference`.
--
-- SIX ARBITRAGES EXPLICITES, tous tranchés par l'étudiant :
--
--  * A3 (véhicules électriques) : sens_favorable = 0, NON ORIENTABLE.
--    Pour un constructeur une hausse est bonne ; pour un SOUS-TRAITANT DE
--    MÉCANIQUE DE PRÉCISION elle est ambiguë — un groupe motopropulseur
--    électrique compte nettement moins de pièces usinées qu'un thermique.
--    Orienter cet indicateur inscrirait un pari économique contestable
--    dans le dispositif. Le 0 dit « je mesure, je n'oriente pas » :
--    l'indicateur reste lisible en tendance, il n'entre pas dans le score.
--
--  * T2 (change) : CHF_EUR retenu plutôt que CHF_USD. L'Europe est le
--    premier débouché industriel, et H1 porte déjà le périmètre mondial
--    via W00. `geo_reference` étant unique par indicateur, les deux paires
--    ne peuvent pas coexister — il faudrait deux indicateurs.
--    Convention de cotation VÉRIFIÉE À LA SOURCE (cube BNS `devkum`) :
--    la devise étrangère est cotée EN FRANCS, donc une hausse = franc plus
--    faible = favorable à l'exportateur. Sans cette vérification le signe
--    eût été inversé.
--
--  * M3 (dépenses de santé) : `retarde`. En tant que moteur de la demande
--    d'équipement la dépense de santé est avancée ; en tant que série
--    publiée avec un à deux ans de retard elle est retardée. C'est la
--    latence SUBIE PAR LE VEILLEUR qui est retenue.
--
--  * M7 (avis TED) : `avance` plutôt que `flux`. La latence est
--    descriptive et n'entre dans aucun calcul ; `avance` dit ce que
--    l'indicateur fait, `flux` dirait seulement d'où il vient.
--
--  * S4 (dépenses militaires) : +1 ASSUMÉ. L'écrire, c'est inscrire « la
--    hausse des dépenses militaires est favorable » dans un travail
--    académique. C'est le point de vue du donneur d'ordre, et le
--    dispositif l'adopte : les budgets de défense sont un moteur réel de
--    la sous-traitance aéronautique. Mettre 0 pour éviter la gêne serait
--    une distorsion. À énoncer explicitement au rapport.
--
--  * A4 et S6 : geo_reference LAISSÉE VIDE, à dessein. Ni ligne suisse ni
--    agrégat mondial n'existent dans ces deux séries ; `DEU` avait été
--    proposé par défaut et a été REFUSÉ. Ils ont trois points et ne seront
--    pas éligibles avant longtemps : déclarer une référence arbitraire ne
--    gagnerait rien et créerait un « Andorre » en puissance. Le sens et la
--    latence sont déclarés — on sait dans quel sens lire ces séries — mais
--    la série de référence reste à établir. NULL est ici la réponse
--    honnête, pas une omission.
--
-- Exécution (depuis prototype/) :
--   docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
--     < migrations/2026-08-23_declarations_lecture.sql \
--     | tee ../annexe_5/declarations_lecture_2026-08-23.txt
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE indicators i SET sens_favorable = d.sens, geo_reference = d.geo, latence = d.lat
FROM (VALUES
  -- horlogerie
  ('H1',  1, 'W00',        'coincident'),
  ('H2',  1, 'CH',         'retarde'),
  ('H3',  1, 'CHE',        'retarde'),
  ('H4',  1, NULL,         'avance'),      -- aucune donnée collectée à ce jour
  -- medical
  ('M1',  1, 'CHE',        'retarde'),
  ('M2',  1, 'EU27_2020',  'coincident'),
  ('M3',  1, 'CHE',        'retarde'),
  ('M4',  1, 'CH',         'retarde'),
  ('M6',  1, NULL,         'avance'),      -- aucune donnée collectée à ce jour
  ('M7',  1, 'EU',         'avance'),
  ('M8',  1, 'US',         'avance'),
  -- automobile
  ('A1',  1, NULL,         'retarde'),     -- aucune donnée collectée à ce jour
  ('A2',  1, 'EU27',       'coincident'),
  ('A3',  0, 'World',      'coincident'),  -- NON ORIENTABLE, voir en-tête
  ('A4',  1, NULL,         'retarde'),     -- référence non déterminable, voir en-tête
  ('A5',  1, 'EU27_2020',  'coincident'),
  -- aerospatial
  ('S1',  1, NULL,         'avance'),      -- aucune donnée collectée à ce jour
  ('S3',  1, 'OWID_WRL',   'retarde'),
  ('S4',  1, 'USA',        'avance'),      -- +1 assumé, voir en-tête
  ('S6',  1, NULL,         'retarde'),     -- référence non déterminable, voir en-tête
  ('S7',  1, 'EU',         'avance'),
  -- transversal
  ('T1',  1, 'G20',        'avance'),
  ('T2',  1, 'CHF_EUR',    'coincident'),  -- cotation vérifiée à la source, voir en-tête
  ('T3',  1, 'WORLD',      'coincident'),
  ('T4',  1, 'WORLD',      'coincident'),
  ('T5',  1, 'EU27_2020',  'avance'),
  ('T6',  1, 'CH',         'avance'),
  ('T7',  1, 'EU27_2020',  'coincident')
) AS d(ind, sens, geo, lat)
WHERE i.indicator_id = d.ind;

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V22 : 28 indicateurs certifiés portent un sens_favorable ; 24 portent
--         une geo_reference (4 sans série collectée + 2 sans référence
--         déterminable = 6 à NULL... soit 22). Le décompte exact est
--         affiché, pas supposé.
--   V23 : v_sante_secteur rend enfin des lignes. Attendu : le médical et
--         le transversal en `calcule`, les trois autres secteurs en
--         `base_insuffisante`. AUCUN secteur absent.
-- ---------------------------------------------------------------------

SELECT 'V22' AS verif,
       count(*) FILTER (WHERE sens_favorable IS NOT NULL) AS avec_sens,
       count(*) FILTER (WHERE geo_reference IS NOT NULL)  AS avec_geo_reference,
       count(*) FILTER (WHERE latence IS NOT NULL)        AS avec_latence,
       count(*) FILTER (WHERE sens_favorable = 0)         AS non_orientables
FROM indicators WHERE status = 'certifie';

SELECT 'V23' AS verif, sector_code, n_indicateurs_orientables, score_sante, etat, indicateurs
FROM v_sante_secteur ORDER BY etat, sector_code;
