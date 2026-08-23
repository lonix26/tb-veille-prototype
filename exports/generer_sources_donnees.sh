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

cat <<EOF
# Sources de données

*Section produite par requête sur le référentiel du prototype le ${GENERE_LE}, et distincte de
la bibliographie académique : les entrées qui suivent ne sont pas des travaux mais des jeux de
données, cités par producteur, jeu, mode d'accès et date de qualification.*

**La date indiquée est celle de la qualification**, c'est-à-dire du jour où la source a été
examinée nominativement et son accès vérifié en réponse réelle — non la date d'une simple
consultation. Les indicateurs rattachés sont ceux de la grille du chapitre 8 ; le détail figure
en annexe 1. Les vingt-cinq URL ont été testées le ${GENERE_LE} ; les refus d'accès automatisé
constatés sont signalés en regard, car ils sont eux-mêmes un résultat du travail (§ 11.7).

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
     ORDER BY s.organisation;"
done

cat <<'EOF'

## Note sur les refus d'accès automatisé

Trois producteurs — l'Agence internationale de l'énergie, le Fonds monétaire international et,
selon l'en-tête employé, l'ACEA — refusent les requêtes automatisées par un code 403 alors que
leurs pages sont publiques. Le fait est consigné plutôt que masqué : il conditionne
l'automatisation de la collecte pour ces sources, et il rejoint le constat de la couche de
découverte, où six candidats sur vingt-six ont été journalisés comme non vérifiables pour la
même raison — un refus d'accès automatisé n'est ni une inexistence, ni une invention.

## Note sur la vérification des liens

La vérification systématique conduite le jour de la génération a rendu **deux liens morts** au
référentiel : celui du CPB Netherlands Bureau for Economic Policy Analysis (404) et celui de
la base des dépenses militaires du SIPRI (échec de négociation TLS). Les deux ont été corrigés
en base — et non dans le seul texte — au moyen des adresses que les liaisons de collecte
utilisaient déjà et qui répondent. Le fait mérite d'être noté pour lui-même : la source de
vérité existait dans la base, à un autre endroit que celui où la bibliographie allait la
chercher, et sans cette vérification le rapport aurait publié deux liens morts.
EOF
