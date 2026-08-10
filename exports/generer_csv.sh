#!/usr/bin/env bash
# =====================================================================
# Export CSV du référentiel — étape intermédiaire vers le classeur A1
# TB « Exploration de l'IA pour les entreprises industrielles »
#
# Usage (depuis prototype/) :
#   bash exports/generer_csv.sh
# =====================================================================

set -eu
mkdir -p exports/csv
P=(docker compose exec -T db psql -U veille -d veille -X --csv)

# --- Indicateurs, à plat, avec leur état d'instrumentation ------------
"${P[@]}" -c "
SELECT i.indicator_id                                    AS \"Code\",
       sec.label                                         AS \"Secteur\",
       i.label                                           AS \"Indicateur\",
       (SELECT string_agg(w.watch_question_code, ', ' ORDER BY w.watch_question_code)
          FROM indicator_watch_questions w WHERE w.indicator_id = i.indicator_id) AS \"Questions de veille\",
       s.name                                            AS \"Source\",
       s.organisation                                    AS \"Organisme\",
       i.category                                        AS \"Catégorie\",
       i.frequency                                       AS \"Fréquence\",
       i.unit                                            AS \"Unité\",
       i.status                                          AS \"Statut\",
       i.alert_threshold_pct                             AS \"Seuil d'alerte (%)\",
       s.access                                          AS \"Accès\",
       s.format                                          AS \"Format\",
       s.url                                             AS \"URL de la source\",
       coalesce(v.n, 0)                                  AS \"Observations en base\",
       coalesce(v.p_min || ' → ' || v.p_max, '')         AS \"Période couverte\",
       v.run_max                                         AS \"Dernier run\"
FROM indicators i
JOIN sectors sec ON sec.code = i.sector_code
JOIN sources s   ON s.source_id = i.source_id
LEFT JOIN (SELECT indicator_id, count(*) AS n, min(period) AS p_min,
                  max(period) AS p_max, max(run_id) AS run_max
           FROM indicator_values GROUP BY indicator_id) v ON v.indicator_id = i.indicator_id
ORDER BY sec.code, i.indicator_id;" > exports/csv/indicateurs.csv

# --- Tableau de confiance des sources ---------------------------------
"${P[@]}" -c "
SELECT s.source_id        AS \"Identifiant\",
       s.name             AS \"Source\",
       s.organisation     AS \"Organisme\",
       s.frequency        AS \"Fréquence\",
       s.format           AS \"Format\",
       s.access           AS \"Accès\",
       s.qualification_status AS \"Statut de qualification\",
       s.qualified_by     AS \"Qualifiée par\",
       to_char(s.qualified_at, 'DD.MM.YYYY') AS \"Le\",
       coalesce((SELECT string_agg(i.indicator_id, ', ' ORDER BY i.indicator_id)
                 FROM indicators i WHERE i.source_id = s.source_id), '') AS \"Indicateurs alimentés\",
       s.url              AS \"URL\",
       coalesce(s.notes, '') AS \"Remarque\"
FROM sources s ORDER BY s.source_id;" > exports/csv/sources.csv

# --- Questions de veille — niveau 1, angles invariants -----------------
"${P[@]}" -c "
SELECT code AS \"Code\", label AS \"Intitulé\", description AS \"Formulation générique\",
       CASE WHEN code = 'QV0' THEN 'transversal' ELSE 'sectoriel' END AS \"Portée\",
       (SELECT count(*) FROM indicator_watch_questions w WHERE w.watch_question_code = q.code) AS \"Indicateurs rattachés\"
FROM watch_questions q ORDER BY code;" > exports/csv/questions_de_veille.csv

# --- Instanciation sectorielle — niveau 2 ------------------------------
# C'est la feuille qui distingue le dispositif d'une simple liste : le
# mécanisme causal énonce POURQUOI la question se pose ainsi dans ce
# secteur, et la criticité pondère l'angle.
"${P[@]}" -c "
SELECT sector_label            AS \"Secteur\",
       watch_question_code     AS \"Code\",
       question_generique      AS \"Angle invariant\",
       question_sectorielle    AS \"Question telle qu'elle se pose\",
       mecanisme               AS \"Mécanisme causal en jeu\",
       criticite               AS \"Criticité\",
       nb_indicateurs          AS \"Indicateurs\",
       nb_certifies            AS \"dont certifiés\"
FROM v_instanciation_qv;" > exports/csv/instanciation_qv.csv

# --- Lacunes de couverture --------------------------------------------
# Extraction volontairement isolée : ce que le dispositif NE couvre pas
# doit se lire aussi facilement que ce qu'il couvre.
"${P[@]}" -c "
SELECT sector_label         AS \"Secteur\",
       watch_question_code  AS \"Question\",
       question_generique   AS \"Angle\",
       question_sectorielle AS \"Question non couverte\",
       criticite            AS \"Criticité\",
       nb_indicateurs       AS \"Indicateurs rattachés\",
       nb_certifies         AS \"dont certifiés\",
       CASE WHEN nb_indicateurs = 0 THEN 'lacune — aucun indicateur'
            ELSE 'couverture nominale — aucun indicateur certifié' END AS \"Nature\"
FROM v_instanciation_qv
WHERE nb_certifies = 0
ORDER BY CASE criticite WHEN 'dominante' THEN 1 WHEN 'significative' THEN 2 ELSE 3 END,
         sector_code;" > exports/csv/lacunes.csv

# --- Bilan du référentiel ---------------------------------------------
"${P[@]}" -c "
SELECT coalesce(sector_code, 'TOTAL') AS \"Secteur\", total AS \"Total\",
       certifies AS \"Certifiés\", certifies_hard AS \"dont hard data\",
       certifies_composite AS \"dont composites\", a_confirmer AS \"À confirmer\"
FROM v_bilan_referentiel;" > exports/csv/bilan.csv

# --- Couverture des questions de veille -------------------------------
"${P[@]}" -c "
SELECT sector_code AS \"Secteur\", watch_question_code AS \"Question\",
       nb_indicateurs AS \"Indicateurs\", nb_certifies AS \"dont certifiés\",
       replace(couverture, '_', ' ') AS \"Couverture\"
FROM v_couverture_qv;" > exports/csv/couverture_qv.csv

echo "CSV générés dans exports/csv/ :"
ls -1 exports/csv/
