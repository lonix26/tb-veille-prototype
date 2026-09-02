#!/usr/bin/env bash
# =====================================================================
# Génération de la section « Sources de données » — TB Castillo
#
# Les sources de données relèvent d'une section DISTINCTE de la
# bibliographie académique (règle du cadrage) : ce ne sont pas des
# travaux mais des jeux de données, et leur citation obéit à d'autres
# conventions — producteur, jeu, format d'accès, date de consultation.
#
# PRODUITE PAR REQUÊTE, jamais saisie. Le référentiel est la source :
# la section ne peut donc pas contredire l'annexe 1 ni la grille du
# chapitre 8, ce qui est exactement le défaut I-6 qu'on cherche à ne
# pas reproduire une fois de plus.
#
# Usage (depuis prototype/) :
#   bash exports/generer_sources_donnees.sh > ../rapport/D2_sources_de_donnees.md
# =====================================================================

set -u
Q=(docker compose exec -T db psql -U veille -d veille -t -A -X)
q() { "${Q[@]}" -c "$1" 2>/dev/null; }

GENERE_LE=$(q "SELECT to_char(now(), 'DD.MM.YYYY');")

# Date de la DERNIÈRE campagne de test des URL, réellement exécutée.
# À ne mettre à jour qu'après avoir relancé la vérification — elle était
# auparavant confondue avec la date de génération, ce qui faisait affirmer
# au texte une campagne qui n'avait pas eu lieu.
VERIF_LE="02.09.2026"
# Les dates de campagnes ANTÉRIEURES citées dans les notes (27.08, 30.08) sont des faits
# historiques codés en dur : elles ne doivent pas suivre VERIF_LE (02.09.2026 : le
# paragraphe OFS attribuait la découverte du 30.08 à la campagne courante).

# Décompte des URL externes : par requête, jamais en toutes lettres.
# La mention « vingt-cinq » codée en dur ici avait dérivé (27 sources au
# 30.08.2026, dont 26 portent une URL externe) — cinquième dérive de
# décompte textuel du projet.
N_URL=$(q "SELECT count(*) FROM sources WHERE url LIKE 'http%';")

cat <<EOF
# Sources de données

*Section produite par requête sur le référentiel du prototype le ${GENERE_LE}, et distincte de
la bibliographie académique : les entrées qui suivent ne sont pas des travaux mais des jeux de
données, cités par producteur, jeu, mode d'accès et date de qualification.*

**La date indiquée est celle de la qualification**, c'est-à-dire du jour où la source a été
examinée nominativement et son accès vérifié en réponse réelle — non la date d'une simple
consultation. Les indicateurs rattachés sont ceux de la grille du chapitre 8 ; le détail figure
en annexe 1. Les ${N_URL} URL externes du référentiel ont été testées le ${VERIF_LE} ; les refus
d'accès automatisé constatés sont signalés en regard, car ils sont eux-mêmes un résultat du
travail (§ 11.7).

EOF

# Certifiées d'abord : ce sont celles sur lesquelles le dispositif s'appuie.
for bloc in "certifiee|Sources certifiées|accès vérifié en réponse réelle, série exploitable" \
            "a_confirmer|Sources à confirmer|pertinence établie, accès ou granularité non validés" \
            "restreinte|Sources restreintes|accès conditionné ou payant"; do
  st="${bloc%%|*}"; reste="${bloc#*|}"; titre="${reste%%|*}"; sous="${reste##*|}"
  n=$(q "SELECT count(*) FROM sources WHERE qualification_status = '${st}';")
  [ "${n:-0}" -eq 0 ] && continue
  echo ""
  echo "## ${titre}"
  echo ""
  echo "*${sous} — ${n} sources.*"
  echo ""
  q "SELECT s.organisation || '. (' || to_char(s.qualified_at,'YYYY') || '). *' || s.name
     || '* [Jeu de données]. ' || s.url || ' — accès ' || s.access || ', format ' || s.format
     || ', fréquence ' || lower(s.frequency) || '. Consulté le '
     || to_char(s.qualified_at,'DD.MM.YYYY') || '. Indicateur(s) : '
     || coalesce((SELECT string_agg(i.indicator_id, ', ' ORDER BY i.indicator_id)
                  FROM indicators i WHERE i.source_id = s.source_id), 'aucun') || '.'
     || E'\n'
     FROM sources s WHERE s.qualification_status = '${st}'
     ORDER BY s.organisation, s.source_id;"
  # Tri secondaire indispensable : deux sources de la même organisation
  # (les deux entrées OMPI) permutaient d'une génération à l'autre,
  # produisant un diff parasite sans changement de fond.
done

cat <<EOF

## Note sur les refus d'accès automatisé

Deux producteurs — l'Agence internationale de l'énergie et le Fonds monétaire international —
refusent les requêtes automatisées par un code 403 alors que leurs pages sont publiques ; le
constat est reproduit à la campagne du ${VERIF_LE}. L'ACEA figurait dans cette liste lors des
campagnes antérieures, selon l'en-tête employé ; le refus **ne s'est pas reproduit** le
${VERIF_LE}, ni sur la page d'accueil ni sur un communiqué PDF, avec ou sans en-tête de
navigateur. Le fait est consigné dans les deux sens plutôt que figé : un refus d'accès
automatisé peut être intermittent, ce qui est en soi une contrainte d'exploitation. Il rejoint
le constat de la couche de découverte, où six candidats sur vingt-six ont été journalisés comme
non vérifiables pour la même raison — un refus d'accès automatisé n'est ni une inexistence, ni
une invention.

## Note sur la vérification des liens

La campagne du 27.08.2026 avait rendu **deux liens morts** au référentiel : celui du CPB
Netherlands Bureau for Economic Policy Analysis (404) et celui de la base des dépenses
militaires du SIPRI (échec de négociation TLS). Les deux ont été corrigés en base — et non dans
le seul texte — au moyen des adresses que les liaisons de collecte utilisaient déjà et qui
répondent ; ils répondent toujours à la campagne du ${VERIF_LE}.

La campagne du ${VERIF_LE} n'a relevé **aucun lien mort**. Celle du 30.08.2026 n'en avait pas
relevé non plus, mais une inexactitude de nature différente : l'entrée de l'Office fédéral de la
statistique portait une adresse générique et un format (« CSV / Excel ») qui ne décrivaient pas
l'accès réellement pratiqué — les liaisons qui la consomment interrogent l'API PX-Web en POST,
format JSON-stat2. L'entrée a été corrigée en base
(migration \`2026-08-30_source_ofs_url_reelle.sql\`). Le fait mérite d'être noté pour lui-même,
et pour la même raison que les deux liens morts : la source de vérité existait dans la base, à
un autre endroit que celui où la bibliographie allait la chercher. Un lien qui répond n'est pas
pour autant le bon lien.
EOF
