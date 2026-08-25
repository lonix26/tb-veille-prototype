#!/usr/bin/env bash
# Vérifie l'application sans navigateur, en deux passes complémentaires :
#   1. ordre des hooks, par analyse statique — le rendu ne peut pas le voir ;
#   2. rendu de chaque écran avec les données réelles de l'API.
set -e
cd "$(dirname "$0")/.."

node verification/hooks.mjs
node verification/classes.mjs
echo
./node_modules/.bin/esbuild verification/rendu.jsx \
  --bundle --platform=node --format=esm --loader:.jsx=jsx \
  --external:react --external:react-dom --external:react-router-dom \
  --outfile=node_modules/.cache/rendu_veille.mjs --log-level=error --define:import.meta.env='{}'
node node_modules/.cache/rendu_veille.mjs
