#!/usr/bin/env bash
# =====================================================================
# Régénère `db/01_socle.sql` et `db/02_referentiel.sql` depuis la base en
# service. À rejouer chaque fois que le schéma ou le référentiel change —
# sans quoi le dépôt cesse de savoir reconstruire la base, ce qui est
# exactement le défaut constaté le 25.08.2026.
#
#   ./regenerer_socle.sh               depuis prototype/
#
# Le script ne touche PAS à la base : il lit et écrit deux fichiers.
# Il vérifie son propre résultat en reconstruisant une base de recette.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"

U=$(grep '^POSTGRES_USER=' .env | cut -d= -f2)
D=$(grep '^POSTGRES_DB=' .env | cut -d= -f2)
CONTENEUR=veille_db
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# --- 1. Structure -----------------------------------------------------
docker exec "$CONTENEUR" pg_dump -U "$U" -d "$D" \
  --schema-only --no-owner --no-privileges --schema=public --schema=sandbox \
  > "$TMP/schema.sql"
# pg_dump 16.10+ encadre sa sortie de directives `\restrict` : elles
# n'ont pas de sens hors du couple d'origine et cassent le rejeu.
sed -i '/^\\restrict/d; /^\\unrestrict/d' "$TMP/schema.sql"
sed -i 's/^CREATE SCHEMA public;$/CREATE SCHEMA IF NOT EXISTS public;/; s/^CREATE SCHEMA sandbox;$/CREATE SCHEMA IF NOT EXISTS sandbox;/' "$TMP/schema.sql"

# --- 2. Référentiel, table par table, DANS L'ORDRE DES DÉPENDANCES ----
# pg_dump ordonne alphabétiquement, ce qui violerait les clés étrangères.
: > "$TMP/ref.sql"
for t in sectors watch_questions sector_watch_questions sources \
         indicators indicator_watch_questions source_bindings flux_sources; do
  docker exec "$CONTENEUR" pg_dump -U "$U" -d "$D" \
    --data-only --no-owner --column-inserts --table="public.$t" >> "$TMP/ref.sql"
done
sed -i '/^\\restrict/d; /^\\unrestrict/d' "$TMP/ref.sql"
# Le `search_path` vide posé par pg_dump ferait échouer les fonctions de
# contrôle du socle, qui ne qualifient pas leurs tables.
sed -i "/^SELECT pg_catalog.set_config('search_path', '', false);$/d" "$TMP/ref.sql"

# Les indicateurs sans question de veille rattachée ne peuvent pas entrer
# dans un socle neuf : `trg_indicateur_sans_question` les refuse, et il a
# raison — son propre message énonce qu'un tel indicateur est écarté.
ORPHELINS=$(docker exec "$CONTENEUR" psql -U "$U" -d "$D" -t -A -c \
  "SELECT string_agg(indicator_id, '|') FROM indicators i
    WHERE NOT EXISTS (SELECT 1 FROM indicator_watch_questions q
                       WHERE q.indicator_id = i.indicator_id);")
if [ -n "$ORPHELINS" ]; then
  echo "Indicateurs écartés du socle (sans question de veille) : ${ORPHELINS//|/, }"
  python3 - "$TMP/ref.sql" "$ORPHELINS" <<'PY'
import sys, re
chemin, orphelins = sys.argv[1], sys.argv[2].split('|')
motif = re.compile(r"^INSERT INTO public\.indicators .*?VALUES \('(" + "|".join(map(re.escape, orphelins)) + r")',", re.S)
gardees = [s for s in re.split(r'(?<=;)\n', open(chemin, encoding='utf-8').read()) if not motif.match(s)]
open(chemin, 'w', encoding='utf-8').write('\n'.join(gardees))
PY
fi

# --- 3. Assemblage ----------------------------------------------------
{ sed -n '1,/^-- =\{20,\}$/p' db/01_socle.sql | head -n -1
  echo "-- ====================================================================="
  echo
  echo "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
  echo
  cat "$TMP/schema.sql"; } > "$TMP/01.sql"

{ sed -n '1,/^-- =\{20,\}$/p' db/02_referentiel.sql | head -n -1
  echo "-- ====================================================================="
  echo
  echo "BEGIN;"
  echo
  echo "-- Le chemin de recherche est fixé ICI et pas ailleurs : les fonctions de"
  echo "-- contrôle du socle (dont \`exiger_question_de_veille\`) référencent leurs"
  echo "-- tables sans les qualifier. Avec le chemin vide que pose pg_dump, elles échouent."
  echo "SET search_path = public;"
  echo
  cat "$TMP/ref.sql"
  echo
  echo "SELECT pg_catalog.setval('public.source_bindings_binding_id_seq', (SELECT max(binding_id) FROM public.source_bindings));"
  echo "COMMIT;"; } > "$TMP/02.sql"

mv "$TMP/01.sql" db/01_socle.sql
mv "$TMP/02.sql" db/02_referentiel.sql

# --- 4. Vérification : le socle reconstruit-il vraiment la base ? -----
docker exec "$CONTENEUR" psql -U "$U" -d postgres -q \
  -c "DROP DATABASE IF EXISTS veille_recette;" -c "CREATE DATABASE veille_recette;"
for f in db/01_socle.sql db/02_referentiel.sql; do
  docker exec -i "$CONTENEUR" psql -U "$U" -d veille_recette -v ON_ERROR_STOP=1 -q < "$f" \
    || { echo "ÉCHEC de rejeu : $f"; exit 1; }
done
echo
printf '%-16s %s\n' "en service" "$(docker exec "$CONTENEUR" psql -U "$U" -d "$D" -t -A -c "SELECT (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE')||' tables · '||(SELECT count(*) FROM pg_views WHERE schemaname='public')||' vues · '||(SELECT count(*) FROM indicators)||' indicateurs · '||(SELECT count(*) FROM source_bindings WHERE statut='actif')||' liaisons actives · '||(SELECT count(*) FROM flux_sources)||' flux';")"
printf '%-16s %s\n' "recette" "$(docker exec "$CONTENEUR" psql -U "$U" -d veille_recette -t -A -c "SELECT (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE')||' tables · '||(SELECT count(*) FROM pg_views WHERE schemaname='public')||' vues · '||(SELECT count(*) FROM indicators)||' indicateurs · '||(SELECT count(*) FROM source_bindings WHERE statut='actif')||' liaisons actives · '||(SELECT count(*) FROM flux_sources)||' flux';")"
echo
echo "Socle régénéré et rejoué avec succès."
