-- =====================================================================
-- 2026-08-28 — LA RÉPONSE CALCULÉE : chaque question reçoit son gabarit
--
-- Constat de la revue v9 (27.08) : les sections de l'écran posaient la
-- question puis montraient des cartes — au lecteur de synthétiser. Le
-- chaînon manquant est LA RÉPONSE, une ligne sous la question. Doctrine
-- inchangée depuis la refonte du 12.08 : « la lecture est calculée,
-- jamais rédigée » — la phrase est un GABARIT stocké au référentiel,
-- résolu à l'affichage avec les valeurs réelles de la base. Aucun modèle
-- n'écrit ni ne choisit un mot.
--
-- Jetons : {ID.val} valeur (montants monétaires humanisés à l'écran),
-- {ID.unit} unité résolue, {ID.ga} glissement annuel, {ID.vp} variation
-- depuis le point précédent, {ID.pt} écart sur un an en points (parts),
-- {ID.per} période en toutes lettres. Règle de résolution : un jeton
-- irrésolu (métrique absente) SUPPRIME la phrase entière — jamais de
-- phrase à trous, jamais de valeur inventée.
--
-- Chaque gabarit n'emploie que des jetons vérifiés disponibles sur la
-- zone de référence au 27.08 (v_dernier_point) ; les formulations des
-- séries jeunes (intensités) portent leur réserve dans le gabarit même.
-- Les questions sans porteur vivant restent SANS gabarit : leur vide est
-- déclaré par ailleurs, il ne se paraphrase pas.
-- =====================================================================

BEGIN;

ALTER TABLE sector_watch_questions ADD COLUMN IF NOT EXISTS reponse_gabarit text;

COMMENT ON COLUMN sector_watch_questions.reponse_gabarit IS
  'Gabarit de la réponse calculée affichée sous la question (jetons {ID.champ} résolus à l''écran depuis v_dernier_point). NULL = pas de réponse composable (question découverte ou porteur sans point). Créé le 28.08.2026.';

UPDATE sector_watch_questions SET reponse_gabarit = v.g
FROM (VALUES
('horlogerie','QV1','Le tissu se lit dans les pièces : {H9.val} milliers de montres mécaniques exportées en {H9.per} ({H9.ga} sur un an) — davantage de montres à valeur unitaire plus basse, donc davantage de charge d''usinage ; la production horlogère UE varie de {H6.ga} sur un an.'),
('horlogerie','QV2','{H7.val} {H7.unit} exportés en {H7.per} ({H7.ga} sur un an, en francs — le change neutralisé) ; qui gagne et qui cède du terrain parmi les destinations se lit dans la carte H1.'),
('horlogerie','QV3','Les exportations suisses d''articles d''horlogerie (SH 91) varient de {H3.ga} sur un an ; la part suisse du panier mondial se lit dans l''indicateur synthétique (Contexte), les pôles concurrents dans la carte H3.'),
('automobile','QV1','La production automobile UE varie de {A5.ga} sur un an, celle des équipementiers — l''étage adressable par la sous-traitance — de {A6.ga} : l''écart entre les deux dit si le marché final se découple de la chaîne.'),
('automobile','QV2','{A2.val} immatriculations en Europe en {A2.per} ({A2.vp} depuis le point précédent) ; les ventes électriques mondiales font {A3.ga} sur un an, le flux de pièces du premier déclarant (Allemagne) {A4.ga}.'),
('automobile','QV3','{A3.val} véhicules électriques vendus dans le monde en {A3.per} ({A3.ga} sur un an) : la carte A3 dit qui les vend — le classement par volume situe le centre de gravité.'),
('automobile','QV4','Une voiture neuve sur quatre est électrique : {A11.val} % des ventes mondiales en {A11.per} ({A11.pt} pt sur un an) ; le signalement technologique du mois est à {A9.val} % (série jeune, à confirmer). Le thermique décline pendant que le marché total se maintient — panneau motorisations.'),
('automobile','QV5','{A10.val} % du signalement automobile du mois porte sur l''action publique — série jeune, à confirmer ; l''acte réglementaire lui-même est porté par le fait validé ci-dessous.'),
('medical','QV1','La production manufacturière diverse UE — le proxy de branche disponible, la nomenclature n''isole pas le medtech — varie de {M2.ga} sur un an.'),
('medical','QV2','La demande s''observe en amont : {M7.val} avis de marchés publics UE en {M7.per} ({M7.vp} depuis le mois précédent) et {M8.val} autorisations FDA 510(k) en {M8.per} ({M8.vp}) — deux signaux qui précèdent la production.'),
('medical','QV3','Les exportations suisses d''instruments médicaux varient de {M1.ga} sur un an ; les pôles et les mouvements de part se lisent dans la carte M1.'),
('medical','QV4','{M8.val} autorisations FDA 510(k) en {M8.per} ({M8.vp} depuis le mois précédent) — le flux d''entrée des nouveaux dispositifs, l''acte réglementaire qui précède la mise en production.'),
('medical','QV5','{M7.val} avis de marchés publics médicaux UE en {M7.per} — la dépense publique de santé au moment précis où elle devient demande adressable.'),
('aerospatial','QV1','La production aéronautique et spatiale UE varie de {S8.ga} sur un an — le constat ; l''annonce se lit dans la demande publique (QV5).'),
('aerospatial','QV2','{S7.val} avis de marchés publics aérospatiaux en {S7.per} ({S7.vp} depuis le mois précédent) ; le commerce du premier déclarant (France) varie de {S6.ga} sur un an.'),
('aerospatial','QV3','{S3.val} objets lancés dans l''espace en {S3.per} ({S3.ga} sur un an) — la carte dit quels États accèdent à une capacité autonome.'),
('aerospatial','QV4','{S9.val} % du signalement aérospatial du mois porte sur la mutation technique — réutilisable, constellations, fabrication additive. Série d''un point, à confirmer : elle dit le présent du discours, pas encore une tendance.'),
('aerospatial','QV5','Le premier budget militaire (États-Unis) varie de {S4.ga} sur un an ({S4.per}) ; la demande publique adressée au secteur se compte en avis : {S7.val} en {S7.per}.')
) AS v(s,q,g)
WHERE sector_watch_questions.sector_code = v.s
  AND sector_watch_questions.watch_question_code = v.q;

-- La vue d'instanciation expose le gabarit (colonne ajoutée en queue).
CREATE OR REPLACE VIEW v_instanciation_qv AS
SELECT swq.sector_code,
       s.label AS sector_label,
       swq.watch_question_code,
       q.label AS question_generique,
       swq.formulation AS question_sectorielle,
       swq.mecanisme,
       swq.criticite,
       count(iwq.indicator_id) AS nb_indicateurs,
       count(iwq.indicator_id) FILTER (WHERE i.status = 'certifie') AS nb_certifies,
       swq.reponse_gabarit
  FROM sector_watch_questions swq
  JOIN sectors s ON s.code = swq.sector_code
  JOIN watch_questions q ON q.code = swq.watch_question_code
  LEFT JOIN indicators i ON i.sector_code = swq.sector_code
  LEFT JOIN indicator_watch_questions iwq ON iwq.indicator_id = i.indicator_id AND iwq.watch_question_code = swq.watch_question_code
 GROUP BY swq.sector_code, s.label, swq.watch_question_code, q.label, swq.formulation, swq.mecanisme, swq.criticite, swq.reponse_gabarit
 ORDER BY swq.sector_code, swq.watch_question_code;

COMMIT;
