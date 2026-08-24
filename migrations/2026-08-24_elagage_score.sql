-- ============================================================================
-- ÉLAGAGE DU SCORE — N. Castillo, 24.08.2026.
--
-- QUESTION POSÉE : quarante-deux indicateurs, n'est-ce pas trop ?
--
-- RÉPONSE MESURÉE, et elle n'est pas « il y en a trop » mais « trois d'entre
-- eux pèsent sur le score sans y avoir droit ». Aucun indicateur n'est
-- supprimé : la grille décrit ce que le dispositif est conçu pour suivre, et
-- l'élaguer effacerait la trace de ce qui a été considéré. Ce qui est retiré,
-- c'est leur DROIT DE VOTE au score — `sens_favorable` passe à 0. Ils restent
-- collectés, affichés, et rattachés à leur question de veille.
--
-- ── H8 et H9 : redondance ARITHMÉTIQUE, et c'est ma faute du jour ───────────
-- H7 (valeur horlogère totale), H8 (valeur mécanique) et H9 (volume mécanique)
-- proviennent du MÊME tableau, du même document, de la même parution. H8
-- représente 85,7 % de H7 et la corrélation de leurs résidus détendancés est de
-- 0,993 : ce n'est pas un mouvement commun, c'est la même série. H9 suit à
-- 0,910. Les compter tous les trois revenait à donner trois voix à une seule
-- mesure — et c'est ce qui a fait passer le score horloger de 0,39 à 1,14 cet
-- après-midi. Corrigé : 1,14 → 0,72, sur quatre indicateurs indépendants.
-- H8 et H9 gardent tout leur intérêt là où il est réel : la vue v_mix_horloger,
-- qui lit leur RAPPORT et non leur niveau.
--
-- ── S3 : influence maximale, pertinence nulle ───────────────────────────────
-- « Objets lancés dans l'espace », douze points annuels, volatilité de 94 %.
-- Contribution mesurée : +1,98, la plus forte de toute la grille. Or un
-- atelier d'usinage de précision suisse n'usine pas de satellites : le nombre
-- de lancements ne commande aucune charge chez lui. L'indicateur pilotait le
-- score aérospatial sans rapport avec ce que le score prétend mesurer.
-- Aérospatial : 0,65 → 0,32. Conservé pour la question de veille QV3, dont il
-- reste une lecture géographique légitime.
--
-- ── CE QUI N'EST PAS RETIRÉ, ET POURQUOI ───────────────────────────────────
-- T8, T9, T10 et T1 contribuent aujourd'hui entre -0,10 et +0,03, c'est-à-dire
-- rien. Ce n'est PAS une raison de les retirer : un indicateur avancé à sa
-- norme dit que rien ne se prépare, ce qui est une information. Retirer les
-- indicateurs calmes reviendrait à ne garder que ceux qui crient — l'inverse
-- exact d'un dispositif de veille.
--
-- A5 et A6 co-varient fortement (résidus à 0,97) et restent tous deux au score.
-- Leur redondance est ÉCONOMIQUE — même cycle industriel — et non arithmétique
-- comme celle de H7/H8. Les séparer ferait tomber l'automobile à deux
-- indicateurs, soit le minimum de calculabilité. LIMITE DÉCLARÉE : le score
-- automobile repose sur deux indices de production qui bougent ensemble.
-- ============================================================================

BEGIN;

UPDATE indicators SET sens_favorable = 0,
  description_metier = description_metier || E'\n\nRETIRÉ DU SCORE le 24.08.2026 : '
    'corrélation des résidus détendancés de 0,993 avec H7 — c''est la même série, issue du '
    'même tableau. Le compter au score donnerait trois voix à une seule mesure. Reste lu par '
    'la vue v_mix_horloger, qui exploite son RAPPORT à H7 et non son niveau.'
 WHERE indicator_id = 'H8';

UPDATE indicators SET sens_favorable = 0,
  description_metier = description_metier || E'\n\nRETIRÉ DU SCORE le 24.08.2026 : '
    'corrélation des résidus de 0,910 avec H7. Reste l''une des deux jambes du mix mécanique, '
    'où sa valeur est entière — c''est l''écart entre volume et valeur qui informe, pas le '
    'niveau du volume pris seul.'
 WHERE indicator_id = 'H9';

UPDATE indicators SET sens_favorable = 0,
  description_metier = coalesce(description_metier,'') || E'\n\nRETIRÉ DU SCORE le 24.08.2026 : '
    'contribution mesurée de +1,98, la plus forte de la grille, pour une série qui compte des '
    'LANCEMENTS DE SATELLITES. Un atelier d''usinage de précision suisse n''en usine pas : le '
    'nombre d''objets lancés ne commande aucune charge chez lui. L''indicateur pilotait le score '
    'aérospatial sans rapport avec ce que ce score prétend mesurer. Conservé pour QV3, où sa '
    'lecture géographique reste légitime.'
 WHERE indicator_id = 'S3';

-- Deux indicateurs qui ne diront rien avant des années : le dire plutôt que de
-- laisser croire qu'ils sont suivis. Ni supprimés ni dégradés — annotés.
UPDATE indicators SET
  description_metier = coalesce(description_metier,'') || E'\n\nÉTAT AU 24.08.2026 : '
    'un seul point au registre. L''indicateur ne produira aucune lecture exploitable avant '
    'plusieurs exercices, et n''entre dans aucun calcul. Conservé au référentiel parce que la '
    'grille décrit ce que le dispositif est CONÇU pour suivre ; son inactivité est une limite '
    'déclarée, non un oubli.'
 WHERE indicator_id IN ('M3','M4','H2');

UPDATE indicators SET
  description_metier = coalesce(description_metier,'') || E'\n\nÉTAT AU 24.08.2026 : '
    'trois points semestriels depuis 2023, et une valeur inchangée à 3,4 %. N''est jamais entré '
    'dans le score (seuil de huit points) et n''a jamais rien signalé. Conservé comme toile de '
    'fond documentaire ; ne pas en attendre de lecture conjoncturelle.'
 WHERE indicator_id = 'T4';

COMMIT;

SELECT sector_code, score_sante, tendance_moyenne, n_indicateurs_orientables, indicateurs
FROM v_sante_secteur ORDER BY 1;
