#!/usr/bin/env bash
# Vérifie l'application en trois passes complémentaires (la troisième dans le navigateur) :
#   1. ordre des hooks, par analyse statique — le rendu ne peut pas le voir ;
#   2. rendu de chaque écran avec les données réelles de l'API ;
#   3. sonde du navigateur (erreurs et écrans vides), voir console.mjs.
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

# 3. (02.09.2026) Le navigateur : erreurs de page, de console, de requête,
#    et écran vide — ce que le rendu serveur ne voit pas (coquille, ECharts).
#    Suppose l'application servie sur http://localhost:8080 (ou BASE_URL).
node verification/console.mjs
