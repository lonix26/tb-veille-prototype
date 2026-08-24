#!/usr/bin/env bash
# Rend tous les écrans hors navigateur, avec les données réelles de l'API.
set -e
cd "$(dirname "$0")/.."
./node_modules/.bin/esbuild verification/rendu.jsx \
  --bundle --platform=node --format=esm --loader:.jsx=jsx \
  --external:react --external:react-dom --external:react-router-dom \
  --outfile=node_modules/.cache/rendu_veille.mjs --log-level=error --define:import.meta.env='{}'
node node_modules/.cache/rendu_veille.mjs
