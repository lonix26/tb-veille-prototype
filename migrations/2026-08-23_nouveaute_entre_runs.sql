-- =====================================================================
-- Nouveauté entre exécutions datées — 23.08.2026
--
-- Chantier des signaux faibles, étape 4. Décision acquise du projet :
-- « le dispositif accumule des exécutions datées, il n'écrase jamais ;
-- c'est l'écart entre runs qui fait la tendance ». L'étage 2 ne
-- l'exploitait pas : il triait item par item, sans jamais comparer une
-- collecte à la précédente.
--
-- DEUX MÉCANISMES ONT ÉTÉ TESTÉS LE 23.08. UN SEUL EST RETENU.
--
-- ÉCARTÉ — la récurrence lexicale. L'idée : un thème mentionné par
-- plusieurs sources indépendantes est un signal corroboré, ce qui est
-- l'analogue exact du recoupement multi-modèles du § 6.3. Testé deux fois :
--   * sur les titres bruts : ne remonte que des noms de pays (Pologne,
--     Espagne, Italie) et le vocabulaire formulaire des avis TED
--     (« dostawa », « suministro », « pièces détachées »). Les titres sont
--     en une dizaine de langues et les avis TED sont standardisés : le
--     lexique commun est celui du formulaire, pas celui du marché.
--   * sur les résumés produits par le triage, tous en français, restreints
--     aux seuls signaux : à peine mieux — « system », « nouveau »,
--     « accord », « autoris ». Une seule entité réelle émerge, « boeing ».
-- Conclusion : sur ce corpus, la récurrence lexicale ne produit pas de
-- thèmes. Ce n'est pas un défaut d'implémentation, c'est la nature du
-- corpus — 344 items sur une fenêtre de sept jours, faits d'avis d'achat
-- et d'autorisations portant chacun sur un dispositif différent. Il n'y a
-- pas de thème récurrent à trouver. Résultat négatif, conservé comme tel.
--
-- RETENU — la nouveauté par clé d'événement. Exacte et non lexicale :
-- elle s'appuie sur cle_evenement(), déjà éprouvée pour le regroupement
-- des reprises syndiquées.
--
-- CE QUE CETTE VUE NE PEUT PAS ENCORE MONTRER, et il faut le dire : au
-- 23.08 le dispositif compte deux journées de collecte, mais la seconde a
-- porté sur des flux NOUVEAUX (ted_automobile_v2, gdelt médical et
-- aérospatial, openFDA, Boeing). Sur 160 événements du 23.08, 152 sont
-- nouveaux — c'est une comparaison de SOURCES, pas de DATES. La mesure
-- n'aura de sens qu'après plusieurs collectes des MÊMES flux. Le mécanisme
-- est posé pour accumuler ; il ne mesure rien aujourd'hui, et prétendre le
-- contraire serait la surdéclaration type.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW v_nouveaute_par_run AS
WITH evt AS (
    SELECT fi.flux_id, fi.collecte_le::date AS jour,
           cle_evenement(fi.titre, fi.url) AS cle
    FROM flux_items fi
),
premiere AS (
    SELECT cle, MIN(jour) AS premiere_vue FROM evt GROUP BY cle
)
SELECT e.flux_id, e.jour,
       COUNT(DISTINCT e.cle)                                              AS evenements,
       COUNT(DISTINCT e.cle) FILTER (WHERE p.premiere_vue = e.jour)       AS nouveaux,
       COUNT(DISTINCT e.cle) FILTER (WHERE p.premiere_vue < e.jour)       AS deja_vus,
       ROUND(100.0 * COUNT(DISTINCT e.cle) FILTER (WHERE p.premiere_vue = e.jour)
             / NULLIF(COUNT(DISTINCT e.cle), 0)) AS taux_nouveaute_pct
FROM evt e JOIN premiere p ON p.cle = e.cle
GROUP BY e.flux_id, e.jour
ORDER BY e.jour DESC, e.flux_id;

COMMENT ON VIEW v_nouveaute_par_run IS
  'Écart entre exécutions datées, par flux : combien d''événements sont apparus pour la première fois ce jour-là. Exacte (clé d''événement), non lexicale. ATTENTION : n''a de sens qu''entre collectes des MÊMES flux à des dates différentes ; comparer deux jours qui ont collecté des flux différents mesure la nouveauté des sources, pas celle du marché. Au 23.08.2026 le dispositif n''a pas encore la profondeur nécessaire.';

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus énoncés AVANT exécution :
--   V16 : la vue rend une ligne par (flux, jour) collecté.
--   V17 : les flux collectés AUX DEUX dates sont les seuls à pouvoir
--         afficher un taux de nouveauté interprétable ; les autres sont
--         à 100 % par construction, ce qui ne veut rien dire.
-- ---------------------------------------------------------------------

SELECT 'V16' AS verif, COUNT(*) AS lignes, COUNT(DISTINCT flux_id) AS flux, COUNT(DISTINCT jour) AS jours
FROM v_nouveaute_par_run;

SELECT 'V17' AS verif, flux_id, COUNT(*) AS jours_de_collecte,
       CASE WHEN COUNT(*) > 1 THEN 'comparable' ELSE 'une seule date — taux non interprétable' END AS lecture
FROM v_nouveaute_par_run GROUP BY flux_id ORDER BY jours_de_collecte DESC, flux_id;
