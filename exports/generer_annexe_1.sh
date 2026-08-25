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
Le **rôle** est la latence déclarée de l'indicateur — un indicateur **annonce** (avancé),
constate (coïncident) ou confirme (retardé) : c'est la distinction la plus utile du métier, et
mélanger les trois dans une même moyenne est une erreur de catégorie (§ 8.7).
La colonne **Grille** distingue les indicateurs **suivis** — la vitrine issue de l'élagage du
25.08.2026 (§ 8.8), treize indicateurs sélectionnés par cinq critères d'utilité — des indicateurs
en **réserve** : qualifiés, conservés au référentiel avec leurs observations, requalifiables sans
nouvel examen. Le statut de la source ne se perd pas quand l'indicateur sort de la grille — ce
sont deux jugements distincts.

EOF

for couple in "transversal|Socle transversal (QV0)" "horlogerie|Horlogerie" "medical|Médical" "automobile|Automobile" "aerospatial|Aérospatial"; do
  code="${couple%%|*}"; libelle="${couple##*|}"
  echo ""
  echo "#### ${libelle}"
  echo ""
  echo "| Code | Indicateur | Questions | Source | Catégorie | Fréquence | Rôle | Statut source | Grille |"
  echo "|---|---|---|---|---|---|---|---|---|"
  q "SELECT '| **' || i.indicator_id || '** | ' || i.label || ' | '
     || (SELECT string_agg(w.watch_question_code, ', ' ORDER BY w.watch_question_code)
         FROM indicator_watch_questions w WHERE w.indicator_id = i.indicator_id)
     || ' | ' || s.organisation || ' | ' || i.category || ' | ' || i.frequency
     || ' | ' || CASE i.latence WHEN 'avance' THEN '**annonce**' WHEN 'coincident' THEN 'constate'
                 WHEN 'retarde' THEN 'confirme' ELSE '—' END
     || ' | ' || i.status || ' | '
     || CASE WHEN i.en_vitrine THEN '**suivie**' ELSE 'réserve' END || ' |'
     FROM indicators i JOIN sources s ON s.source_id = i.source_id
     WHERE i.sector_code = '${code}' ORDER BY i.en_vitrine DESC, i.indicator_id;"
done

cat <<'EOF'

---

## A1.3bis Sources de flux — l'étage des signaux

Le tableau de confiance de la section A1.1 porte les sources d'**indicateurs** — celles qui
produisent des séries chiffrées. Le dispositif surveille aussi des **flux** : marchés publics,
actualité, communiqués, réglementaire et, depuis le 26.08.2026, la **presse professionnelle de
branche** — le type de source qui donne de l'avance, identifié comme absent du portefeuille à
l'évaluation du même jour. Un flux ne produit pas de série : il produit des **items**, qui passent
au triage assisté par IA puis à l'examen humain. Les mêmes exigences s'appliquent : chaque flux
est qualifié nominativement, et sa reconnaissance en réponse réelle est datée.

| Flux | Famille | Secteur | Libellé | Statut | Qualifié par | Le |
|---|---|---|---|---|---|---|
EOF

q "SELECT '| ' || flux_id || ' | ' || famille || ' | ' || coalesce(sector_code, '—') || ' | '
   || libelle || ' | ' || statut || ' | ' || coalesce(qualified_by, '—') || ' | '
   || coalesce(to_char(qualified_at, 'DD.MM.YYYY'), '—') || ' |'
   FROM flux_sources ORDER BY famille, sector_code NULLS LAST, flux_id;"

cat <<'EOF'

Types de sources identifiés à l'évaluation du 26.08.2026 et **non instrumentés**, avec leur motif —
les nommer vaut mieux que les laisser croire couverts : les **rapports annuels des donneurs
d'ordre** (publication apériodique, pas de point d'accès structuré — relèveraient du traitement
composite) ; les **offres d'emploi** des donneurs d'ordre (aucune API ouverte sans clé identifiée ;
Adzuna exigerait une clé, à instruire) ; les autres **salons** du périmètre (pas de fil
exploitable — EPHJ, qui en a un, est instrumenté ci-dessus).

EOF

cat <<'EOF'

---

## A1.4 Bilan du référentiel

**Ce décompte fait foi.** Il est calculé par la vue `v_bilan_referentiel` et doit être reporté tel quel
dans le résumé, le poster et le corps du rapport — jamais l'inverse.

| Secteur | Référentiel | Certifiés | dont hard | dont composites | À confirmer | **En grille** | En réserve |
|---|---|---|---|---|---|---|---|
EOF

q "SELECT '| ' || coalesce(initcap(sector_code), '**Total**') || ' | ' || total || ' | ' || certifies
   || ' | ' || certifies_hard || ' | ' || certifies_composite || ' | ' || a_confirmer
   || ' | **' || en_grille || '** | ' || ecartes || ' |'
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
