-- =====================================================================
-- 2026-08-25 — L'ÉLAGAGE : de quarante-quatre indicateurs à treize
--
-- LE CONSTAT. La grille comptait 44 indicateurs. Un décideur ne lit pas
-- 44 séries, et le tableau de bord était devenu illisible — non par défaut
-- de présentation, mais parce qu'il n'y avait rien à présenter de lisible.
-- Mesuré avant d'être décidé :
--     8 indicateurs n'ont AUCUNE observation ;
--     6 en ont moins de huit, seuil déjà retenu pour lire une série ;
--     2 s'arrêtent en 2022 ;
--     plusieurs paires corrèlent au-dessus de 0,90 — H7/H8 à 0,99,
--     M2/T11 à 0,93, A5/A6 à 0,92, H1/H7 à 0,93.
-- La grille se répétait, et son volume masquait ce qu'elle avait à dire.
--
-- CE QUI EST INTRODUIT, ET POURQUOI PAS UN CHANGEMENT DE STATUT. Le champ
-- `status` qualifie la SOURCE : « certifié » signifie qu'elle a été vue en
-- réponse réelle. Rétrograder un indicateur parce qu'il fait doublon
-- reviendrait à nier ce travail de qualification, qui reste valable. Deux
-- questions distinctes méritent deux champs :
--     `status`      — la source est-elle qualifiée ?
--     `en_vitrine`  — l'indicateur mérite-t-il d'être suivi ?
-- Un indicateur écarté de la vitrine reste au référentiel, qualifié, avec
-- ses observations. Il redevient disponible sans requalification.
--
-- LES CINQ CRITÈRES, appliqués dans cet ordre :
--   1. IL COLLECTE           — au moins douze points sur sa zone de référence ;
--   2. IL EST FRAIS          — dernier point à moins de trois mois pour une
--                              série infra-annuelle, moins de dix-huit pour
--                              une annuelle ;
--   3. IL N'EST PAS REDONDANT — |r| < 0,90 avec tout autre indicateur retenu ;
--   4. IL PARLE AU MÉTIER    — il porte sur l'étage adressable par un usineur
--                              de précision, ou sur le marché de son client
--                              direct — pas deux étages plus loin ;
--   5. IL APPORTE UN RÔLE    — annonce, constat ou confirmation que le secteur
--                              n'a pas déjà.
--
-- L'ARBITRAGE DE LA REDONDANCE. Entre deux séries corrélées, on garde celle
-- qui est la plus PROCHE DU MÉTIER, et non la plus longue. C'est le seul
-- critère qui ne se retourne pas contre l'usager : une série de cent
-- cinquante points sur un marché final vaut moins, pour un sous-traitant,
-- qu'une série de dix-neuf points sur les pièces qu'il usine.
-- =====================================================================

BEGIN;

ALTER TABLE indicators ADD COLUMN IF NOT EXISTS en_vitrine boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN indicators.en_vitrine IS
  'L''indicateur fait-il partie de la grille suivie et affichée ? Distinct de `status`, qui qualifie la source. Un indicateur écarté de la vitrine reste au référentiel avec ses observations et redevient disponible sans requalification.';

-- ---------------------------------------------------------------------
-- LES TREIZE RETENUS
-- ---------------------------------------------------------------------

-- LE MÉTIER — ce que l'entreprise fait réellement, et ce qui l'annonce.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'T8';
--   Carnet de commandes de l'industrie UE. AVANCÉ, 151 points, un mois de
--   retard. C'est le meilleur signal d'avance de toute la grille : un carnet
--   qui se dégarnit précède la baisse de charge de la sous-traitance.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'T7';
--   Production d'usinage et traitement des métaux UE (NACE C25.6). C'EST LE
--   MÉTIER. Aucun autre indicateur ne mesure l'activité de la profession
--   elle-même. 150 points.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'T9';
--   Taux d'utilisation des capacités de l'industrie UE. Répond à la question
--   « faire ou faire faire » : un donneur d'ordre sous-utilisé internalise.
--   T10 (demande comme facteur limitant) est son miroir — r = −0,84 — et est
--   écarté à ce titre.

-- LE CONTEXTE SUISSE — l'écosystème et la marge.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'T11';
--   Production manufacturière suisse. L'écosystème national du destinataire.
--   Écarte M2 (production UE « industries diverses »), qui corrèle à 0,93.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'T2';
--   Change CHF/EUR et CHF/USD. Pour un exportateur suisse, le change n'est pas
--   du contexte : c'est la marge. Aucun autre indicateur ne le porte.

-- HORLOGERIE — la valeur et le volume, qui ne disent pas la même chose.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'H9';
--   Volume de montres mécaniques exportées (FH). DES PIÈCES, pas des francs :
--   c'est la grandeur qui commande la charge d'usinage. Corrèle à 0,88 avec
--   la valeur, donc pas au-delà du seuil — l'écart entre les deux est l'effet
--   de mix, et il s'agit d'une information à part entière.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'H7';
--   Valeur totale des exportations horlogères (FH). Le niveau de la branche,
--   référence de place. Écarte H8 (r = 0,99, même communiqué), H1 (r = 0,93,
--   même grandeur vue par Comtrade) et H3 (commerce SH 91 sur zone suisse).

-- MÉDICAL — deux signaux d'amont, et c'est le secteur le mieux servi.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'M8';
--   Autorisations FDA 510(k). AVANCÉ au sens strict : une autorisation de mise
--   sur le marché précède la montée en cadence, donc la charge d'usinage.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'M7';
--   Avis de marchés publics UE en équipements médicaux. AVANCÉ, fraîcheur
--   immédiate — TED publie le jour même.

-- AUTOMOBILE — l'étage adressable, et le marché final.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'A6';
--   Production d'équipements automobiles UE (NACE C29.3). L'ÉTAGE ADRESSABLE
--   (§ 8.6). Écarte A5 (assemblage de véhicules, r = 0,92) : pour un
--   sous-traitant, l'assemblage est en aval de lui, il confirme au lieu
--   d'annoncer.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'A2';
--   Immatriculations de véhicules neufs en Europe. Le marché final, et le SEUL
--   COMPOSITE de la grille : c'est lui qui démontre la chaîne extraction
--   multi-modèles / validation humaine. Sept points seulement — il entre à la
--   grille et pas au score, ce que l'écran dit.

-- AÉROSPATIAL — un signal d'amont, une mesure d'activité.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'S7';
--   Avis de marchés publics UE en aéronefs et engins spatiaux. AVANCÉ.
UPDATE indicators SET en_vitrine = true WHERE indicator_id = 'S8';
--   Production aéronautique et spatiale UE (NACE C30.3). 150 points.

-- ---------------------------------------------------------------------
-- CE QUI SORT DE LA VITRINE, ET POURQUOI — trente et un indicateurs.
-- Chaque motif est écrit dans la note, pour que l'écart soit relisible.
-- ---------------------------------------------------------------------
UPDATE indicators SET description_metier = description_metier ||
  ' [HORS VITRINE le 25.08.2026 — aucune observation collectée : la source est qualifiée, la liaison manque ou l''accès n''a pas été obtenu.]'
 WHERE indicator_id IN ('S1','S2','S5','A1','A8','H4','H5','M5') AND NOT en_vitrine;

UPDATE indicators SET description_metier = description_metier ||
  ' [HORS VITRINE le 25.08.2026 — moins de douze points sur la zone de référence : la série ne se lit pas.]'
 WHERE indicator_id IN ('A3','H2','M3','M4','T4') AND NOT en_vitrine;

UPDATE indicators SET description_metier = description_metier ||
  ' [HORS VITRINE le 25.08.2026 — dernier point en 2022 : la source publie avec un retard qui la rend inutilisable en conjoncture.]'
 WHERE indicator_id IN ('A7','M6') AND NOT en_vitrine;

UPDATE indicators SET description_metier = description_metier ||
  ' [HORS VITRINE le 25.08.2026 — redondant avec un indicateur retenu, corrélation supérieure ou égale à 0,90.]'
 WHERE indicator_id IN ('H8','H1','M2','A5') AND NOT en_vitrine;

UPDATE indicators SET description_metier = description_metier ||
  ' [HORS VITRINE le 25.08.2026 — agrégat macroéconomique trop éloigné du métier : il décrit un contexte mondial que rien ne relie à la charge d''atelier.]'
 WHERE indicator_id IN ('T1','T3','T10','S3','S6','H3','H6','M1','A4') AND NOT en_vitrine;

-- ---------------------------------------------------------------------
-- LES VUES SUIVENT. Le score et le décompte portent désormais sur la
-- vitrine, non sur l'ensemble du référentiel.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_bilan_referentiel AS
SELECT sector_code,
       count(*) AS total,
       count(*) FILTER (WHERE status = 'certifie')                              AS certifies,
       count(*) FILTER (WHERE status = 'certifie' AND category = 'hard')        AS certifies_hard,
       count(*) FILTER (WHERE status = 'certifie' AND category = 'composite')   AS certifies_composite,
       count(*) FILTER (WHERE status = 'a_confirmer')                           AS a_confirmer,
       count(*) FILTER (WHERE en_vitrine)                                       AS en_grille,
       count(*) FILTER (WHERE NOT en_vitrine)                                   AS ecartes
  FROM indicators
 GROUP BY ROLLUP (sector_code)
 ORDER BY sector_code;

COMMENT ON VIEW v_bilan_referentiel IS
  'Décompte faisant foi (§ 8.4.5). `en_grille` = indicateurs en vitrine, c''est-à-dire suivis et affichés. `ecartes` = qualifiés et conservés au référentiel, hors grille. `certifies` reste le décompte de qualification des SOURCES, qui ne se perd pas.';

COMMIT;
