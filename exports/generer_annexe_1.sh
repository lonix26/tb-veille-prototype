#!/usr/bin/env bash
# =====================================================================
# Génération de l'annexe 1 — tableau de veille consolidé
# TB « Exploration de l'IA pour les entreprises industrielles »
#
# L'annexe est PRODUITE PAR REQUÊTE, jamais saisie à la main. C'est la
# condition pour qu'elle ne puisse pas contredire le référentiel : le
# rapport a porté jusqu'ici quatre décomptes différents (I-6), faute
# d'une source unique. Ici, la base est la source, et le document en
# est une projection datée.
#
# Usage (depuis prototype/) :
#   bash exports/generer_annexe_1.sh > "../annexes/1_tableau_de_veille.md"
# =====================================================================

set -u
Q=(docker compose exec -T db psql -U veille -d veille -t -A -X)

q() { "${Q[@]}" -c "$1" 2>/dev/null; }

GENERE_LE=$(q "SELECT to_char(now(), 'DD.MM.YYYY à HH24:MI');")

cat <<EOF
# Annexe 1 — Tableau de veille consolidé

*Document produit par requête sur la base consolidée du prototype, le ${GENERE_LE}.*

**Deux natures distinctes, à ne pas confondre.** Les qualifications consignées ici — statut de
chaque source, catégorie et criticité de chaque indicateur, formulation sectorielle de chaque
question de veille — résultent d'un **examen manuel, source par source**, dont l'auteur et la date
figurent en regard de chaque ligne. Aucun automatisme ne les produit : la base refuse toute source
dont le qualificateur n'est pas nommé. Le **document**, en revanche, est produit par requête : il
restitue le référentiel sans le ressaisir, et ne peut donc pas en diverger. Toute divergence entre
cette annexe et le corps du rapport signale une erreur du corps du rapport, non de l'annexe.

Le tableau se lit en trois temps, conformément à la structure défendue au chapitre 8 :
les **sources** sont qualifiées d'abord, les **indicateurs** en découlent, et chaque indicateur
est rattaché à au moins une **question de veille** — ce dernier point étant imposé par la base
elle-même, qui refuse l'insertion d'un indicateur orphelin.

---

## A1.1 Tableau de confiance des sources

Statuts de qualification : **certifiee** — source institutionnelle, accès vérifié, série exploitable ·
**a_confirmer** — pertinence établie mais accès, périodicité ou granularité à valider ·
**restreinte** — accès conditionné ou payant.

| Identifiant | Source | Organisme | Fréquence | Format | Accès | Statut | Qualifiée par | Le | Indicateurs | Remarque |
|---|---|---|---|---|---|---|---|---|---|---|
EOF

q "SELECT '| ' || s.source_id || ' | ' || s.name || ' | ' || s.organisation || ' | ' || s.frequency
   || ' | ' || s.format || ' | ' || s.access || ' | **' || s.qualification_status || '** | '
   || s.qualified_by || ' | ' || to_char(s.qualified_at,'DD.MM.YYYY') || ' | '
   || coalesce((SELECT string_agg(i.indicator_id, ', ' ORDER BY i.indicator_id)
                FROM indicators i WHERE i.source_id = s.source_id), '—')
   || ' | ' || coalesce(s.notes,'—') || ' |'
   FROM sources s ORDER BY s.source_id;"

cat <<'EOF'

---

## A1.2 Questions de veille — niveau 1, angles invariants

Ces angles sont communs aux quatre secteurs. Leur invariance est ce qui rend l'absence
calculable : le croisement de tous les secteurs par toutes les questions produit la matrice
de couverture de la section A1.5, dont les vides se constatent par requête.

| Code | Intitulé | Formulation |
|---|---|---|
EOF

q "SELECT '| **' || code || '** | ' || label || ' | ' || description || ' |'
   FROM watch_questions ORDER BY code;"

cat <<'EOF'

---

## A1.2bis Instanciation sectorielle — niveau 2

Un angle invariant n'est pas directement exploitable : le rôle causal du phénomène qu'il vise
diffère d'un secteur à l'autre. Le champ « mécanisme » est ce qui distingue une instanciation
d'une paraphrase ; la criticité pondère l'angle dans le secteur considéré.

EOF

for couple in "transversal|Socle transversal" "horlogerie|Horlogerie" "medical|Médical" "automobile|Automobile" "aerospatial|Aérospatial"; do
  code="${couple%%|*}"; libelle="${couple##*|}"
  echo ""
  echo "### ${libelle}"
  echo ""
  echo "| Code | Question telle qu'elle se pose | Mécanisme en jeu | Criticité | Indicateurs | dont certifiés |"
  echo "|---|---|---|---|---|---|"
  q "SELECT '| **' || watch_question_code || '** | ' || question_sectorielle || ' | ' || mecanisme
     || ' | ' || criticite || ' | ' || nb_indicateurs || ' | ' || nb_certifies || ' |'
     FROM v_instanciation_qv WHERE sector_code = '${code}' ORDER BY watch_question_code;"
done

cat <<'EOF'

---

## A1.3 Grille d'indicateurs par secteur

Catégorie : **hard** — donnée officielle structurée, reprise telle quelle ·
**composite** — extraite ou synthétisée depuis un document non structuré, soumise au contrôle de consistance.
Le seuil d'alerte est la variation au-delà de laquelle une notification est déclenchée ; « — » signale
un indicateur sans alerte configurée, généralement parce que sa périodicité rend la variation peu significative.

EOF

for couple in "transversal|Socle transversal (QV0)" "horlogerie|Horlogerie" "medical|Médical" "automobile|Automobile" "aerospatial|Aérospatial"; do
  code="${couple%%|*}"; libelle="${couple##*|}"
  echo ""
  echo "#### ${libelle}"
  echo ""
  echo "| Code | Indicateur | Questions de veille | Source | Catégorie | Fréquence | Unité | Statut | Seuil d'alerte |"
  echo "|---|---|---|---|---|---|---|---|---|"
  q "SELECT '| **' || i.indicator_id || '** | ' || i.label || ' | '
     || (SELECT string_agg(w.watch_question_code, ', ' ORDER BY w.watch_question_code)
         FROM indicator_watch_questions w WHERE w.indicator_id = i.indicator_id)
     || ' | ' || s.organisation || ' | ' || i.category || ' | ' || i.frequency
     || ' | ' || i.unit || ' | ' || i.status || ' | '
     || coalesce(i.alert_threshold_pct::text || ' %', '—') || ' |'
     FROM indicators i JOIN sources s ON s.source_id = i.source_id
     WHERE i.sector_code = '${code}' ORDER BY i.indicator_id;"
done

cat <<'EOF'

---

## A1.4 Bilan du référentiel

**Ce décompte fait foi.** Il est calculé par la vue `v_bilan_referentiel` et doit être reporté tel quel
dans le résumé, le poster et le corps du rapport — jamais l'inverse.

| Secteur | Total | Certifiés | dont hard data | dont composites | À confirmer |
|---|---|---|---|---|---|
EOF

q "SELECT '| ' || coalesce(initcap(sector_code), '**Total**') || ' | ' || total || ' | ' || certifies
   || ' | ' || certifies_hard || ' | ' || certifies_composite || ' | ' || a_confirmer || ' |'
   FROM v_bilan_referentiel;"

cat <<'EOF'

---

## A1.5 Couverture des questions de veille

Une question de veille sans indicateur certifié rattaché constitue une lacune assumée, non un oubli :
le dispositif ne prétend pas couvrir ce qu'il ne couvre pas. Cette matrice est le produit direct du
cadre invariant — c'est parce que les mêmes angles s'appliquent partout que l'absence est calculable.

| Secteur | Question | Indicateurs rattachés | dont certifiés | Couverture |
|---|---|---|---|---|
EOF

q "SELECT '| ' || initcap(sector_code) || ' | ' || watch_question_code || ' | ' || nb_indicateurs
   || ' | ' || nb_certifies || ' | ' || replace(couverture, '_', ' ') || ' |'
   FROM v_couverture_qv;"

cat <<'EOF'

Les lacunes qui pèsent le plus sont celles qui portent sur un angle de criticité **dominante** dans
le secteur concerné : c'est la conjonction des deux tables qui la révèle, non la matrice seule.

| Secteur | Question | Criticité | Indicateurs certifiés |
|---|---|---|---|
EOF

q "SELECT '| ' || initcap(sector_code) || ' | ' || watch_question_code || ' | **' || criticite
   || '** | ' || nb_certifies || ' |'
   FROM v_instanciation_qv WHERE nb_certifies = 0 ORDER BY sector_code, watch_question_code;"

cat <<'EOF'

---

## A1.6 État d'instrumentation

Distinction essentielle, et volontairement exposée ici : un indicateur **qualifié** n'est pas un indicateur
**collecté**. La grille du chapitre 8 décrit ce que le dispositif est conçu pour suivre ; cette section
constate ce qu'il suit effectivement à la date de génération. L'écart entre les deux est une limite du
travail, pas une omission de l'annexe.

| Code | Indicateur | Observations en base | Période couverte | Dernier run |
|---|---|---|---|---|
EOF

q "SELECT '| ' || i.indicator_id || ' | ' || i.label || ' | '
   || coalesce(v.n::text, '**aucune collecte**') || ' | '
   || coalesce(v.p_min || ' → ' || v.p_max, '—') || ' | '
   || coalesce(v.run_max::text, '—') || ' |'
   FROM indicators i
   LEFT JOIN (SELECT indicator_id, count(*) AS n, min(period) AS p_min,
                     max(period) AS p_max, max(run_id) AS run_max
              FROM indicator_values GROUP BY indicator_id) v
     ON v.indicator_id = i.indicator_id
   ORDER BY (v.n IS NULL), i.indicator_id;"

cat <<EOF

---

*Fin de l'annexe 1. Régénérable à tout moment par \`bash exports/generer_annexe_1.sh\`.*
EOF
