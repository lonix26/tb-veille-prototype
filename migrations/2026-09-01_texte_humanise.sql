-- =====================================================================
-- Humanisation des textes affichés stockés en base (demande de
-- l'étudiant du 01.09.2026) : les tirets cadratins « — » sortent des
-- libellés, noms de sources, formulations et gabarits de réponse.
-- La ponctuation devient ordinaire ; aucun contenu ne change de sens.
-- Chaque gabarit reste un modèle à jetons : les valeurs sont toujours
-- calculées à l'affichage, jamais écrites.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Libellés d'indicateurs : « Intensité de signalement — X » devient « : »
UPDATE indicators SET label = replace(label, ' — ', ' : ') WHERE label LIKE '%—%';

-- Noms de sources
UPDATE sources SET name = replace(name, ' — ', ' : ') WHERE name LIKE '%—%';

-- Formulations de questions
UPDATE sector_watch_questions SET formulation = replace(formulation, ' — ', ', ')
 WHERE formulation LIKE '%—%';

-- Gabarits de réponse : réécrits un à un (une virgule ou un point selon la phrase)
UPDATE sector_watch_questions SET reponse_gabarit =
 '{H7.val} {H7.unit} exportés en {H7.per} ({H7.ga} sur un an, en francs, le change neutralisé) ; qui gagne et qui cède du terrain parmi les destinations se lit dans la carte H1.'
 WHERE sector_code='horlogerie' AND watch_question_code='QV2';

UPDATE sector_watch_questions SET reponse_gabarit =
 'La demande s''observe en amont : {M7.val} avis de marchés publics UE en {M7.per} ({M7.vp} depuis le mois précédent) et {M8.val} autorisations FDA 510(k) en {M8.per} ({M8.vp}) : deux signaux qui précèdent la production.'
 WHERE sector_code='medical' AND watch_question_code='QV2';

UPDATE sector_watch_questions SET reponse_gabarit =
 '{M8.val} autorisations FDA 510(k) en {M8.per} ({M8.vp} depuis le mois précédent) : le flux d''entrée des nouveaux dispositifs, l''acte réglementaire qui précède la mise en production.'
 WHERE sector_code='medical' AND watch_question_code='QV4';

UPDATE sector_watch_questions SET reponse_gabarit =
 '{M7.val} avis de marchés publics médicaux UE en {M7.per} : la dépense publique de santé au moment précis où elle devient demande adressable.'
 WHERE sector_code='medical' AND watch_question_code='QV5';

UPDATE sector_watch_questions SET reponse_gabarit =
 'La production automobile UE varie de {A5.ga} sur un an, celle des équipementiers (l''étage que la sous-traitance peut viser) de {A6.ga} : l''écart entre les deux dit si le marché final se découple de la chaîne.'
 WHERE sector_code='automobile' AND watch_question_code='QV1';

UPDATE sector_watch_questions SET reponse_gabarit =
 'Une voiture neuve sur quatre est électrique : {A11.val} % des ventes mondiales en {A11.per} ({A11.pt} pt sur un an) ; le signalement technologique du mois est à {A9.val} % (série jeune, à confirmer). Le thermique décline pendant que le marché total se maintient ; voir le panneau motorisations.'
 WHERE sector_code='automobile' AND watch_question_code='QV4';

UPDATE sector_watch_questions SET reponse_gabarit =
 '{A10.val} % du signalement automobile du mois porte sur l''action publique (série jeune, à confirmer) ; l''acte réglementaire lui-même est porté par le fait validé ci-dessous.'
 WHERE sector_code='automobile' AND watch_question_code='QV5';

UPDATE sector_watch_questions SET reponse_gabarit =
 '{A1.val} véhicules produits dans le monde en {A1.per} ({A1.ga} sur un an) : la carte A1 dit où l''assemblage se déplace, tous véhicules confondus ; le segment électrique ({A3.val} VE vendus, {A3.ga}) dit vers quoi il bascule.'
 WHERE sector_code='automobile' AND watch_question_code='QV3';

UPDATE sector_watch_questions SET reponse_gabarit =
 'La production aéronautique et spatiale UE varie de {S8.ga} sur un an : le constat ; l''annonce se lit dans la demande publique (QV5).'
 WHERE sector_code='aerospatial' AND watch_question_code='QV1';

UPDATE sector_watch_questions SET reponse_gabarit =
 '{S3.val} objets lancés dans l''espace en {S3.per} ({S3.ga} sur un an) : la carte dit quels États accèdent à une capacité autonome.'
 WHERE sector_code='aerospatial' AND watch_question_code='QV3';

UPDATE sector_watch_questions SET reponse_gabarit =
 '{S9.val} % du signalement aérospatial du mois porte sur la mutation technique : réutilisable, constellations, fabrication additive. Série d''un point, à confirmer : elle dit le présent du discours, pas encore une tendance.'
 WHERE sector_code='aerospatial' AND watch_question_code='QV4';

UPDATE sector_watch_questions SET reponse_gabarit =
 '{M4.val} emplois medtech suisses en {M4.per} ({M4.ga} sur un an) : la base productive nationale, comptée ; la production manufacturière diverse UE, proxy de branche, varie de {M2.ga} sur un an.'
 WHERE sector_code='medical' AND watch_question_code='QV1';

UPDATE sector_watch_questions SET reponse_gabarit =
 'L''appareil productif se compte deux fois : {H2.val} emplois et {H11.val} entreprises dans les industries horlogère et microtechnique suisses en {H2.per} ({H2.ga} et {H11.ga} sur un an) ; le volume de montres mécaniques exportées fait {H9.ga} sur un an, la production horlogère UE {H6.ga}. Si la valeur montait sans les pièces, sans les emplois ni les ateliers, l''érosion serait masquée : les quatre se lisent ici.'
 WHERE sector_code='horlogerie' AND watch_question_code='QV1';

COMMIT;

\echo '--- Vérification : plus aucun tiret cadratin dans les textes affichés'
SELECT 'labels' AS champ, count(*) FROM indicators WHERE label LIKE '%—%'
UNION ALL SELECT 'sources', count(*) FROM sources WHERE name LIKE '%—%'
UNION ALL SELECT 'formulations', count(*) FROM sector_watch_questions WHERE formulation LIKE '%—%'
UNION ALL SELECT 'gabarits', count(*) FROM sector_watch_questions WHERE reponse_gabarit LIKE '%—%';
