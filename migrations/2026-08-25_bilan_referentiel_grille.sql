-- 2026-08-25 — `v_bilan_referentiel` : distinguer la grille des indicateurs écartés
--
-- PROBLÈME. La colonne `total` compte TOUS les indicateurs du référentiel, y compris
-- ceux qui en ont été retirés. Depuis l'abandon de T12 et T13 le 24.08 — au statut
-- `restreint` —, elle rend 45 quand la grille en compte 43. La règle du projet veut
-- que le décompte se cite depuis cette vue et jamais depuis un texte ; encore faut-il
-- que la vue dise sans ambiguïté ce qu'elle compte. Sinon la règle produit exactement
-- ce qu'elle voulait empêcher : deux chiffres également « sourcés » qui se contredisent.
--
-- CHOIX. Les colonnes existantes ne bougent pas — l'API de restitution lit cette vue,
-- et un renommage silencieux casserait la restitution. Deux colonnes sont AJOUTÉES :
--   `en_grille`  = certifiés + à confirmer, soit ce que « la grille » désigne au rapport ;
--   `ecartes`    = les indicateurs présents au référentiel mais retirés de la grille.
-- `total` reste la somme des deux, et c'est désormais lisible.
--
-- POURQUOI NE PAS SUPPRIMER T12 ET T13. Leurs 322 observations sont au registre, qui
-- est en ajout seul. Les effacer reviendrait à nier qu'ils ont été collectés — alors
-- que le fait qu'un indicateur ait été essayé puis écarté fait partie du déroulé du
-- travail, et se lit.

-- Les colonnes nouvelles sont AJOUTÉES EN FIN DE LISTE, et pas ailleurs :
-- `CREATE OR REPLACE VIEW` n'autorise pas l'insertion d'une colonne au milieu,
-- ce qui reviendrait à renommer les suivantes et casserait l'API de restitution.
CREATE OR REPLACE VIEW v_bilan_referentiel AS
SELECT sector_code,
       count(*) AS total,
       count(*) FILTER (WHERE status = 'certifie')                              AS certifies,
       count(*) FILTER (WHERE status = 'certifie' AND category = 'hard')        AS certifies_hard,
       count(*) FILTER (WHERE status = 'certifie' AND category = 'composite')   AS certifies_composite,
       count(*) FILTER (WHERE status = 'a_confirmer')                           AS a_confirmer,
       count(*) FILTER (WHERE status IN ('certifie', 'a_confirmer'))            AS en_grille,
       count(*) FILTER (WHERE status NOT IN ('certifie', 'a_confirmer'))        AS ecartes
  FROM indicators
 GROUP BY ROLLUP (sector_code)
 ORDER BY sector_code;

COMMENT ON VIEW v_bilan_referentiel IS
  'Décompte de la grille, produit par requête et faisant foi (§ 8.4.5). `en_grille` = certifiés + à confirmer, ce que le rapport appelle « la grille ». `ecartes` = indicateurs restés au référentiel mais retirés de la grille, leurs observations étant au registre en ajout seul. `total` = somme des deux.';
