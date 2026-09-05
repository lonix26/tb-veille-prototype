#!/usr/bin/env bash
# =====================================================================
# preparer_archive.sh — constitue le ZIP du livrable technique. 05.09.2026
#
# À lancer APRÈS le dernier commit et APRÈS avoir régénéré l'instantané
# (exports/generer_instantane_demonstration.sh), au moment de figer.
#
#   bash preparer_archive.sh
#
# CE QUE L'ARCHIVE CONTIENT, et pourquoi : le dossier de travail moins ce
# qui ne se transmet pas.
#   - `dashboard-app/dist` EST inclus, alors qu'il est exclu du dépôt git :
#     c'est un produit de compilation, mais sans lui le lecteur n'a rien à
#     regarder et doit installer Node. Dans une archive de remise, il a sa
#     place.
#   - `.env` est exclu : mot de passe local, recréé par demarrer.sh.
#   - `data/` est exclu (201 Mo de réponses brutes) : les pièces d'audit du
#     run de référence sont archivées dans annexes/, hors de ce dossier.
#   - `node_modules/` est exclu : il se réinstalle, et pèse 149 Mo.
#   - `.git` est exclu par défaut (123 Mo) et remplacé par `historique_git.txt`,
#     qui donne le déroulé complet des actes. Pour l'inclure malgré tout :
#     `bash preparer_archive.sh --avec-historique`.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"

AVEC_GIT=0
[ "${1:-}" = "--avec-historique" ] && AVEC_GIT=1

DATE=$(date +%Y-%m-%d)
NOM="prototype_TB_Castillo_$DATE"
DEST="../$NOM"
ZIP="../$NOM.zip"

dire() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
alerte() { printf '  ! %s\n' "$*"; }

dire "Contrôles avant archive"
if [ -n "$(git status --short 2>/dev/null)" ]; then
  alerte "Le dépôt n'est pas propre : l'archive ne correspondra à aucun commit."
  git status --short | sed 's/^/      /'
else
  ok "dépôt propre sur $(git log --format='%h %s' -1 | cut -c1-70)"
fi
if [ -z "$(ls -A dashboard-app/dist 2>/dev/null)" ]; then
  alerte "dashboard-app/dist est vide — compilation…"
  (cd dashboard-app && npm run build)
fi
ok "interface compilée présente"
if [ db/03_donnees_demonstration.sql.gz -ot "$(git log -1 --format=%H >/dev/null 2>&1 && echo .git/HEAD || echo db/03_donnees_demonstration.sql.gz)" ]; then
  alerte "L'instantané est plus ancien que le dernier commit — le régénérer :"
  alerte "  bash exports/generer_instantane_demonstration.sh"
fi
ok "instantané : $(du -h db/03_donnees_demonstration.sql.gz | cut -f1)"

dire "Copie"
rm -rf "$DEST" "$ZIP"
mkdir -p "$DEST"
tar --exclude=./.env \
    --exclude=./data \
    --exclude='./**/node_modules' --exclude=node_modules \
    --exclude='*.tar.gz' \
    $([ "$AVEC_GIT" = 1 ] || echo --exclude=./.git) \
    -cf - . | (cd "$DEST" && tar xf -)
mkdir -p "$DEST/data/staging" && : > "$DEST/data/staging/.gitkeep"
ok "arborescence copiée"

git log --date=format:'%d.%m.%Y %H:%M' \
        --format='%ad  %h  %s' > "$DEST/historique_git.txt"
ok "historique_git.txt : $(wc -l < "$DEST/historique_git.txt" | tr -d ' ') actes datés"

dire "Archive"
(cd .. && zip -qr "$NOM.zip" "$NOM")
rm -rf "$DEST"
ok "$(cd .. && ls -lh "$NOM.zip" | awk '{print $9" — "$5}')"

dire "À vérifier avant de remettre"
cat <<TXT
  1. Décompresser l'archive AILLEURS et y lancer  bash demarrer.sh
  2. Ouvrir http://localhost:8080 et parcourir les six écrans
  3. Contrôler qu'aucun secret n'est parti :
       unzip -l $ZIP | grep -E '\.env$|cles|\.tar\.gz'      (doit ne rien rendre)
TXT
