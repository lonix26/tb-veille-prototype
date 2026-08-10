#!/usr/bin/env bash
# =====================================================================
# Génération du classeur consolidé — annexe 1 au format Excel
# TB « Exploration de l'IA pour les entreprises industrielles »
#
# Enchaîne les deux étapes : export CSV depuis la base, puis assemblage
# en classeur. Rien n'est installé sur le poste — la conversion tourne
# dans un conteneur jetable, conformément à la contrainte E5 (coût de
# licence nul, reproductible par une PME).
#
# Prérequis : les services démarrés (docker compose up -d) et la
# migration du 07.08.2026 appliquée.
#
# Usage (depuis prototype/) :
#   bash exports/generer_classeur.sh
# =====================================================================

set -eu

cd "$(dirname "$0")/.."

echo "1/2 — export CSV depuis la base consolidée"
bash exports/generer_csv.sh

echo ""
echo "2/2 — assemblage du classeur"
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD/exports:/w" -w /w python:3.12-slim \
  sh -c "pip install -q --target /tmp/libs openpyxl && PYTHONPATH=/tmp/libs python csv_vers_xlsx.py"

echo ""
echo "Classeur disponible : prototype/exports/1_tableau_de_veille.xlsx"
echo "Copie vers les annexes :"
echo "  cp exports/1_tableau_de_veille.xlsx ../annexes/1_tableau_de_veille.xlsx"
