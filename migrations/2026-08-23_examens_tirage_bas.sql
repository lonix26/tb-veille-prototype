-- =====================================================================
-- Examen du tirage bas — 23.08.2026
--
-- OBJET, et c'est ce qui distingue ce lot du précédent : mesurer le
-- RAPPEL du triage, pas sa précision. Les 21 examens du lot précédent
-- portaient sur des items notés 2 : ils disent si ce que le triage met en
-- tête est bon. Ils ne disent RIEN de ce qu'il a jeté. Sans échantillon
-- pris dans le bas de la file, le taux d'erreur mesuré serait borgne — et
-- l'IA se trouverait juge de son propre tri.
--
-- MÉTHODE : dix items tirés AU HASARD parmi ceux notés 0 ou 1 par la
-- doctrine « événement », graine fixée à 0.2308 pour que le tirage soit
-- reproductible et donc auditable. Aucun item n'a été choisi à la main :
-- un échantillon trié mesurerait le jugement de celui qui trie.
--
-- DÉCISIONS DE N. CASTILLO, prises en session terminale le 23.08.2026.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO flux_examens (item_id, decision, decide_par, note)
SELECT v.item_id, v.decision, 'N. Castillo', v.note
FROM (VALUES
  (146,  'contexte', 'Marché public croate de matériel d''implants orthopédiques. Retenu : même nature exactement que les quatre marchés d''implants retenus le même jour, que le triage avait notés 2. RATÉ DE RAPPEL du triage — noté 1 au lieu de 2.'),
  (722,  'contexte', 'Autorisation FDA 510(k), LumenCare Azure (Nucletron, curiethérapie). Retenu : la curiethérapie mobilise des composants mécaniques de précision. Le triage l''avait noté 1 en pertinence mais 2 en antériorité — sous-évalué sur l''axe pertinence.'),
  (1468, 'ecarte',   'Pneumatiques (Estonie). Hors du champ de l''usinage de précision. Rejet du triage justifié.'),
  (280,  'ecarte',   'Revue de titres pharmaceutiques. Aucun contenu de veille de marché. Rejet justifié.'),
  (433,  'ecarte',   'Refroidissement liquide et économie de basse altitude (Chine). Hors périmètre en l''état. Rejet justifié.'),
  (744,  'ecarte',   'Système d''évaluation vestibulaire (FDA). Dispositif sans composant mécanique usiné significatif. Rejet justifié.'),
  (446,  'ecarte',   'Retards du programme indien AMCA. Contexte géopolitique sans conséquence directe sur la sous-traitance suisse. Rejet justifié.'),
  (20,   'ecarte',   'Chute du titre Advance Auto Parts. Actualité boursière, pas de veille de marché. Rejet justifié.'),
  (24,   'ecarte',   'Indice Dow Jones. Aucun rapport avec les marchés cibles. Rejet justifié.'),
  (447,  'ecarte',   'Billet d''opinion sur un futur chasseur indien. Opinion, non fait. Rejet justifié.')
) AS v(item_id, decision, note)
JOIN flux_items fi ON fi.item_id = v.item_id
WHERE NOT EXISTS (SELECT 1 FROM flux_examens x WHERE x.item_id = v.item_id);

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V28 : 31 examens au total (21 du lot « haut » + 10 du tirage bas).
--   V29 : la matrice de v_triage_a_echantillonner est enfin peuplée dans
--         les DEUX sens — des items notés 2 et des items notés 0 ou 1.
--   V30 : le taux d'erreur se lit alors dans les deux directions.
-- ---------------------------------------------------------------------

SELECT 'V28' AS verif, decision, count(*) FROM flux_examens GROUP BY decision ORDER BY decision;

\echo ''
\echo '--- V29 : matrice décision humaine x pertinence IA (doctrine evenement) ---'
SELECT e.decision, t.pertinence, count(*) AS n
FROM flux_examens e
JOIN flux_triage_ia t ON t.item_id = e.item_id AND t.doctrine = 'evenement'
GROUP BY e.decision, t.pertinence ORDER BY e.decision, t.pertinence;

\echo ''
\echo '--- V30 : lecture du triage dans les deux sens ---'
WITH m AS (
  SELECT e.decision, t.pertinence
  FROM flux_examens e
  JOIN flux_triage_ia t ON t.item_id = e.item_id AND t.doctrine = 'evenement')
SELECT
  count(*) FILTER (WHERE pertinence = 2)                                AS notes_2,
  count(*) FILTER (WHERE pertinence = 2 AND decision <> 'ecarte')        AS notes_2_retenus,
  count(*) FILTER (WHERE pertinence < 2)                                AS notes_0_ou_1,
  count(*) FILTER (WHERE pertinence < 2 AND decision <> 'ecarte')        AS notes_bas_mais_retenus
FROM m;
