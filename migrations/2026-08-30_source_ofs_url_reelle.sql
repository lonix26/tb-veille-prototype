-- =====================================================================
-- 2026-08-30 — LA SOURCE OFS CITÉE À SON ADRESSE RÉELLE
--
-- Constat : l'entrée « Office fédéral de la statistique » du référentiel
-- portait l'URL générique https://www.bfs.admin.ch et le format
-- « CSV / Excel ». Ni l'une ni l'autre ne décrit ce que le dispositif
-- interroge réellement pour H2 et M4 — les deux seuls indicateurs
-- rattachés à cette source. Les liaisons actives (142 pour M4, 143 pour
-- H2) appellent l'API PX-Web de l'OFS en POST, format JSON-stat2 :
--
--   https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px
--
-- La section « Sources de données » du rapport étant PRODUITE PAR
-- REQUÊTE sur cette table (exports/generer_sources_donnees.sh), la
-- correction ne peut pas se faire dans le texte : elle se fait ici, ou
-- elle est écrasée à la prochaine génération. C'est le même geste que
-- celui déjà consigné pour le CPB et le SIPRI le 27.08 — la source de
-- vérité existait dans la base, à un autre endroit que celui où la
-- bibliographie allait la chercher.
--
-- VÉRIFIÉ EN RÉPONSE RÉELLE le 30.08.2026 : GET sur l'endpoint, HTTP 200,
-- 51 166 octets de métadonnées, titre officiel « Etablissements et
-- emplois selon Année, Canton, Genre économique et Unité d'observation »,
-- millésimes 2011-2024. La date de qualification est donc reprise à ce
-- jour, conformément à la règle énoncée en tête de la section : la date
-- indiquée est celle où l'accès a été vérifié en réponse réelle.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS : elle ne touche ni aux liaisons,
-- ni aux valeurs collectées, ni au libellé des indicateurs. En
-- particulier, l'écart entre le libellé de H2 (« Emploi ET
-- établissements ») et la grandeur réellement collectée (les seuls
-- emplois, Beobachtungseinheit = 2) reste ouvert : c'est une question de
-- libellé d'indicateur, tracée dans note_conception le 28.08, pas une
-- question de source.
-- =====================================================================

BEGIN;

UPDATE sources SET
  name = 'STATENT — Etablissements et emplois selon année, canton, genre économique et unité d''observation (table px-x-0602010000_103)',
  url = 'https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px',
  format = 'API PX-Web (JSON-stat2, requête POST)',
  qualified_by = 'N. Castillo',
  qualified_at = '2026-08-30 00:00:00+00',
  notes = 'Nomenclature NOGA. Cube STATENT interrogé en POST : le seul URL ne rend pas la donnée, le corps de requête fait partie de la référence (voir source_bindings 142 et 143). H2 = cinq classes NOGA 2652 sommées ; M4 = NOGA 266000 et 3250xx. Unité d''observation 2 (emplois) ; la modalité 1 (établissements) est identifiée, non instrumentée. Consultation à l''écran de la même table : https://www.pxweb.bfs.admin.ch/pxweb/fr/px-x-0602010000_103/px-x-0602010000_103/px-x-0602010000_103.px'
WHERE source_id = 'ofs';

COMMIT;

-- Contrôle : l'entrée doit désormais porter l'adresse des liaisons actives.
SELECT s.source_id, s.url, s.format, s.qualified_at::date,
       (SELECT string_agg(i.indicator_id, ', ' ORDER BY i.indicator_id)
          FROM indicators i WHERE i.source_id = s.source_id) AS indicateurs,
       (SELECT count(DISTINCT b.url_base) FROM source_bindings b
         WHERE b.indicator_id IN ('H2','M4') AND b.statut = 'actif'
           AND b.url_base = s.url) AS concordance_liaisons
  FROM sources s WHERE s.source_id = 'ofs';
