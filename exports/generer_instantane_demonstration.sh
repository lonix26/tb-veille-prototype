#!/usr/bin/env bash
# =====================================================================
# Génération de db/03_donnees_demonstration.sql.gz — TB Castillo, 05.09.2026
#
# POURQUOI CE FICHIER EXISTE. `db/01_socle.sql` et `db/02_referentiel.sql`
# restaurent le schéma et le référentiel, mais volontairement AUCUNE
# observation : le registre est en ajout seul, et livrer des valeurs
# collectées comme si elles venaient d'être collectées serait une
# surdéclaration. Conséquence pratique : un tiers qui démarre le compose
# obtient une application propre et VIDE, et conclut qu'elle ne marche pas.
#
# Ce troisième fichier est un INSTANTANÉ DATÉ des exécutions de l'auteur,
# chargé automatiquement au premier démarrage (le dossier db/ est monté dans
# /docker-entrypoint-initdb.d, PostgreSQL y accepte les .sql comme les
# .sql.gz). Il rend le dispositif consultable sans clé d'API et sans
# collecte. Ce n'est pas une collecte fraîche, et le lisez-moi le dit.
#
# CE QU'IL NE CONTIENT PAS : les neuf tables du référentiel, déjà peuplées
# par 02_referentiel.sql — les y remettre provoquerait des doublons.
#
# LE CAS DE `commentaries`. La contrainte `chk_commentaire_rejet_trace` est
# posée NOT VALID dans le socle : cinq rejets saisis hors dépôt, sans auteur
# ni date, lui sont antérieurs (constat B-2 du 02.09.2026, limite (12) du
# § 12.5). NOT VALID exempte les lignes déjà présentes, jamais celles qu'on
# charge ensuite : sans précaution, le rechargement échoue sur ces cinq
# lignes. Le fichier produit reproduit donc l'histoire telle qu'elle est —
# contrainte retirée, données chargées, contrainte reposée NOT VALID —
# plutôt que de maquiller les cinq lignes ou de les taire.
#
# Usage (depuis prototype/) :
#   bash exports/generer_instantane_demonstration.sh
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

CONTENEUR=veille_db
U=$(grep '^POSTGRES_USER=' .env | cut -d= -f2)
D=$(grep '^POSTGRES_DB=' .env | cut -d= -f2)
CIBLE=db/03_donnees_demonstration.sql.gz
TMP=$(mktemp); TMP_INS=$(mktemp); trap 'rm -f "$TMP" "$TMP_INS" "$TMP_INS.brut"' EXIT

# Les neuf tables du référentiel, chargées par 02_referentiel.sql.
EXCLUES=(sources indicators sectors watch_questions sector_watch_questions
         indicator_watch_questions source_bindings flux_sources flux_filtrage_regles)
ARGS=()
for t in "${EXCLUES[@]}"; do ARGS+=(-T "public.$t"); done

CONTRAINTE=$(docker exec "$CONTENEUR" psql -U "$U" -d "$D" -Atc \
  "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'chk_commentaire_rejet_trace';")
[ -n "$CONTRAINTE" ] || { echo "Contrainte chk_commentaire_rejet_trace introuvable." >&2; exit 1; }

# Les indicateurs sans question de veille rattachée sont écartés du socle par
# `regenerer_socle.sh` : le déclencheur `trg_indicateur_sans_question` les
# refuserait dans une base neuve, et il a raison. Ce sont les deux indicateurs
# retirés de la grille le 25.08.2026 (T12, T13, brevets OMPI), conservés en
# service au statut « restreint » parce que leurs 322 observations sont au
# registre, lequel est en ajout seul. Sans eux, la base restaurée porterait
# 51 indicateurs quand le rapport en cite 53, et leurs observations seraient
# orphelines. On les réinscrit donc ici, déclencheurs neutralisés le temps du
# chargement — même geste que pour toute restauration, et le seul qui rende la
# base livrée identique à la base en service.
ECARTES=$(docker exec "$CONTENEUR" psql -U "$U" -d "$D" -Atc \
  "SELECT string_agg(indicator_id, '|' ORDER BY indicator_id) FROM indicators i
    WHERE NOT EXISTS (SELECT 1 FROM indicator_watch_questions q
                       WHERE q.indicator_id = i.indicator_id);")

# Un INSERT produit par --column-inserts tient sur PLUSIEURS lignes dès qu'un
# champ de texte porte un saut de ligne — et les notes de conception en portent
# toutes. Un filtre ligne à ligne (grep) les tronquerait silencieusement : le
# découpage se fait donc par instruction, comme dans regenerer_socle.sh.
if [ -n "$ECARTES" ]; then
  docker exec "$CONTENEUR" pg_dump -U "$U" -d "$D" --data-only --no-owner \
    --column-inserts --table=public.indicators > "$TMP_INS.brut"
  python3 - "$TMP_INS.brut" "$ECARTES" > "$TMP_INS" <<'FILTRE'
import re, sys
chemin, ecartes = sys.argv[1], sys.argv[2].split('|')
motif = re.compile(r"^INSERT INTO public\.indicators .*?VALUES \('(" +
                   "|".join(map(re.escape, ecartes)) + r")',", re.S)
instructions = re.split(r'(?<=;)\n', open(chemin, encoding='utf-8').read())
gardees = [i.strip() for i in instructions if motif.match(i)]
assert len(gardees) == len(ecartes), f"{len(gardees)} instruction(s) pour {len(ecartes)} indicateur(s)"
print('\n'.join(gardees))
FILTRE
fi

{
  echo "-- Instantané de démonstration — données des exécutions de l'auteur."
  echo "-- Produit le $(date +%d.%m.%Y) par exports/generer_instantane_demonstration.sh."
  echo "-- Chargé au PREMIER démarrage seulement, après 01_socle.sql et 02_referentiel.sql."
  echo "-- Ce n'est pas une collecte fraîche : les dates sont celles des exécutions d'origine."
  echo ""
  echo "-- Cinq rejets de commentaires antérieurs à la contrainte (limite (12) du § 12.5) :"
  echo "-- elle est retirée le temps du chargement, puis reposée telle qu'elle est en service."
  echo "ALTER TABLE public.commentaries DROP CONSTRAINT chk_commentaire_rejet_trace;"
  echo ""
  if [ -n "$ECARTES" ]; then
    echo "-- Indicateurs présents en service mais écartés du socle faute de question de"
    echo "-- veille rattachée (${ECARTES//|/, }) : réinscrits pour que la base livrée porte"
    echo "-- le même référentiel que la base en service, et que leurs observations ne"
    echo "-- soient pas orphelines. Le déclencheur qui les refuserait est le même qui les"
    echo "-- a écartés de la grille ; il est neutralisé le temps du chargement."
    echo "ALTER TABLE public.indicators DISABLE TRIGGER ALL;"
    cat "$TMP_INS"
    echo "ALTER TABLE public.indicators ENABLE TRIGGER ALL;"
    echo ""
  fi
  docker exec "$CONTENEUR" pg_dump -U "$U" -d "$D" \
    --data-only --disable-triggers --no-owner --no-privileges \
    --schema=public --schema=sandbox "${ARGS[@]}"
  echo ""
  echo "ALTER TABLE public.commentaries ADD CONSTRAINT chk_commentaire_rejet_trace ${CONTRAINTE};"
} > "$TMP"

# pg_dump 16.10+ encadre sa sortie de directives `\restrict` : elles n'ont pas
# de sens hors du couple d'origine et cassent le rejeu — même correctif que
# dans regenerer_socle.sh, où le défaut avait déjà été rencontré le 01.09.2026.
sed -i '/^\\restrict/d; /^\\unrestrict/d' "$TMP"

gzip -9 -c "$TMP" > "$CIBLE"

echo "Écrit : $CIBLE ($(du -h "$CIBLE" | cut -f1))"
docker exec "$CONTENEUR" psql -U "$U" -d "$D" -Atc \
  "SELECT '  ' || count(*) || ' observations · ' ||
          (SELECT count(*) FROM runs) || ' exécutions · ' ||
          (SELECT count(*) FROM flux_items) || ' items de flux · ' ||
          (SELECT count(*) FROM flux_evenements) || ' événements · ' ||
          (SELECT count(*) FROM ted_avis) || ' avis' FROM indicator_values;"
