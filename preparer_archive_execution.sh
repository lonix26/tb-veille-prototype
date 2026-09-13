#!/usr/bin/env bash
# =====================================================================
# Archive d'exécution — le strict nécessaire pour faire tourner le prototype
# TB « Exploration de l'IA pour les entreprises industrielles »
#
# Usage (depuis prototype/) :   bash preparer_archive_execution.sh
# Produit : ../tb-veille-prototype_execution_<date>.zip
#
# Ne contient que ce que docker-compose.yml monte et ce que demarrer.sh
# lit, plus les deux documents qui expliquent comment l'exécuter et les
# deux harnais qui permettent de constater que ça tourne. Ni journal,
# ni migrations, ni scripts d'export, ni analyses : tout cela reste sur
# le dépôt GitHub, dont l'adresse est ajoutée en tête du LISEZ-MOI.
# =====================================================================
set -eu
cd "$(dirname "$0")"
NOM="tb-veille-prototype_execution_$(date +%Y-%m-%d)"
DEST="../$NOM"
DEPOT="https://github.com/lonix26/tb-veille-prototype"
rm -rf "$DEST" "../$NOM.zip"
mkdir -p "$DEST"

copier() { mkdir -p "$DEST/$(dirname "$1")"; cp -p "$1" "$DEST/$1"; }

# Exécution
for f in docker-compose.yml demarrer.sh demarrer.cmd .env.example \
         db/01_socle.sql db/02_referentiel.sql db/03_donnees_demonstration.sql.gz \
         dashboard-app/index.html dashboard-app/package.json dashboard-app/package-lock.json \
         dashboard-app/vite.config.js dashboard-app/.nvmrc dashboard-app/.gitignore; do
  copier "$f"
done
for f in n8n_workflows/*.json; do copier "$f"; done          # la racine seulement, archive/ exclu
mkdir -p "$DEST/dashboard-app/src" && cp -rp dashboard-app/src/. "$DEST/dashboard-app/src/"
mkdir -p "$DEST/data" && touch "$DEST/data/.gitkeep"

# Constater que ça tourne
mkdir -p "$DEST/dashboard-app/verification" && cp -p dashboard-app/verification/* "$DEST/dashboard-app/verification/"
copier verification/base.sh; copier verification/base_attendu.txt

# Comprendre comment l'exécuter
copier DEPLOIEMENT.md
{ printf '> **Archive d'"'"'exécution, réduite au nécessaire.** Le journal technique, les migrations, les\n'
  printf '> scripts d'"'"'export et les analyses cités dans ces deux documents sont sur le dépôt :\n'
  printf '> <%s>.\n\n' "$DEPOT"
  cat LISEZ-MOI.md; } > "$DEST/LISEZ-MOI.md"

(cd .. && zip -qr "$NOM.zip" "$NOM" && rm -rf "$NOM")
echo "Archive : $(cd .. && pwd)/$NOM.zip ($(du -h "../$NOM.zip" | cut -f1))"
unzip -l "../$NOM.zip" | tail -1
