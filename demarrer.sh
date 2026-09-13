#!/usr/bin/env bash
# =====================================================================
# demarrer.sh — met le prototype en marche en une commande. 05.09.2026
#
# POURQUOI CE SCRIPT. `DEPLOIEMENT.md` décrit la mise en service pas à pas,
# et c'est la référence : chaque étape y est expliquée et justifiée. Mais un
# lecteur qui veut simplement VOIR le dispositif ne devrait pas avoir à
# créer un justificatif d'accès à la main, relever son identifiant dans une
# URL et le substituer dans vingt-deux fichiers. Ce script fait cette
# séquence à sa place, et rien de plus : il n'invente aucune donnée et ne
# contourne aucun contrôle.
#
#   bash demarrer.sh
#
# Ce qu'il fait, dans l'ordre : le fichier d'environnement s'il manque, les
# quatre services, l'attente que la base soit prête, le justificatif d'accès
# à la base pour l'orchestrateur, l'import des workflows, la publication de
# l'interface de lecture et du workflow d'erreur, puis un contrôle de santé.
#
# CE QU'IL NE FAIT PAS : aucune collecte. Les données affichées sont
# l'instantané daté livré avec le dépôt (db/03_donnees_demonstration.sql.gz),
# chargé au premier démarrage. Relancer une collecte réelle demande des clés
# d'API — voir DEPLOIEMENT.md § 1.2 et § 5.
# =====================================================================
set -euo pipefail
# Sous Git Bash (Windows), MSYS réécrit un chemin comme /app en C:\Program Files\Git\app
# avant de le passer à docker : on le lui interdit. Sans effet sur Linux et macOS.
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")"

CRED_ID=QdVRYX9pjTj9C8G3          # identifiant référencé par les workflows
BASE=http://localhost:5678
APP=http://localhost:8080

dire() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
ko()   { printf '  ✗ %s\n' "$*" >&2; }

# --- 0. Prérequis ----------------------------------------------------
command -v docker >/dev/null 2>&1 || {
  ko "Docker est introuvable. Installer Docker Desktop (macOS, Windows) ou docker.io + docker-compose-plugin (Linux)."; exit 1; }
docker compose version >/dev/null 2>&1 || {
  ko "Le greffon « docker compose » est introuvable (Docker trop ancien ?)."; exit 1; }
docker info >/dev/null 2>&1 || { ko "Le service Docker ne répond pas. Le démarrer, puis relancer."; exit 1; }
ok "Docker répond"

# --- 1. Fichier d'environnement --------------------------------------
if [ ! -f .env ]; then
  # Le fichier d'exemple pointe le fichier de clés HORS du dossier, ce qui est
  # la règle en exploitation. Pour une simple consultation il n'y a pas de clé
  # à protéger : on replie le chemin sur ./.env, faute de quoi le compose
  # refuse de démarrer sur un fichier absent.
  sed 's|^CLES_API_FICHIER=.*|CLES_API_FICHIER=./.env|; s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=veille_demonstration|' \
      .env.example > .env
  ok ".env créé depuis .env.example (mot de passe local, aucune clé d'API)"
else
  ok ".env déjà présent, laissé tel quel"
fi
MDP=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
DB=$(grep '^POSTGRES_DB=' .env | cut -d= -f2-)
U=$(grep '^POSTGRES_USER=' .env | cut -d= -f2-)

# --- 2. Interface : le dossier compilé -------------------------------
if [ -z "$(ls -A dashboard-app/dist 2>/dev/null)" ]; then
  dire "L'interface n'est pas compilée. Compilation dans un conteneur Node (aucune installation sur le poste)."
  HOTE="$PWD"; command -v cygpath >/dev/null 2>&1 && HOTE="$(cygpath -w "$PWD")"   # chemin Windows sous Git Bash
  docker run --rm -v "$HOTE/dashboard-app:/app" -w /app node:24-alpine \
    sh -c "npm ci --no-audit --no-fund && npm run build" \
    || { ko "La compilation a échoué (réseau indisponible ?). Voir DEPLOIEMENT.md § 3."; exit 1; }
fi
ok "Interface compilée présente ($(ls dashboard-app/dist | wc -l | tr -d ' ') entrées dans dashboard-app/dist)"

# --- 3. Services ------------------------------------------------------
dire "Démarrage des services"
mkdir -p data/staging
docker compose up -d
ok "conteneurs lancés"

# Au premier démarrage, PostgreSQL joue les trois fichiers de db/ AVANT d'ouvrir
# son port réseau : il n'écoute alors que sur sa socket locale. Interroger la
# socket répondrait « prêt » pendant que l'instantané se charge encore, et le
# script lirait un registre vide. On attend donc la voie réseau, qui n'ouvre
# qu'une fois l'initialisation terminée. Le chargement prend une minute environ.
printf '  … attente de la base (chargement de l'"'"'instantané au premier démarrage)'
for _ in $(seq 1 150); do
  docker compose exec -T db pg_isready -h 127.0.0.1 -U "$U" -d "$DB" >/dev/null 2>&1 && break
  printf '.'; sleep 2
done; printf '\n'
docker compose exec -T db pg_isready -h 127.0.0.1 -U "$U" -d "$DB" >/dev/null 2>&1 || { ko "La base ne répond pas."; exit 1; }
OBS=$(docker compose exec -T db psql -U "$U" -d "$DB" -Atc "SELECT count(*) FROM indicator_values;")
IND=$(docker compose exec -T db psql -U "$U" -d "$DB" -Atc "SELECT count(*) FROM indicators;")
ok "base prête — $IND indicateurs au référentiel, $OBS observations"
[ "${OBS:-0}" -gt 0 ] || ko "Registre vide : l'instantané n'a pas été chargé (il ne l'est qu'au PREMIER démarrage ; « docker compose down -v » puis relancer)."

# Le contrôle de santé de l'orchestrateur répond avant que son outil en ligne de
# commande soit utilisable : c'est ce dernier qui importe les workflows et les
# justificatifs. On attend donc que la commande de listage réponde, pas la santé.
printf '  … attente de l'"'"'orchestrateur'
for _ in $(seq 1 90); do
  docker exec veille_n8n n8n list:workflow >/dev/null 2>&1 && break
  printf '.'; sleep 2
done; printf '\n'
docker exec veille_n8n n8n list:workflow >/dev/null 2>&1 || { ko "L'orchestrateur ne répond pas."; exit 1; }

# --- 4. Justificatif d'accès à la base -------------------------------
# Les workflows référencent ce justificatif PAR IDENTIFIANT ; sans lui, chaque
# nœud Postgres échoue. Le contenu n'est pas un secret d'affaires : c'est le
# mot de passe local du conteneur, celui du .env.
dire "Justificatif d'accès à la base"
# Écrit dans ./data, que le compose monte dans l'orchestrateur sous /data : aucun
# « docker cp », dont le chemin local ne survivrait pas à Git Bash sous Windows.
cat > data/cred_veille.json <<CRED
[{"id":"$CRED_ID","name":"postgres veille","type":"postgres",
  "data":{"host":"db","port":5432,"database":"$DB","user":"$U","password":"$MDP","ssl":"disable","allowUnauthorizedCerts":false,"sshTunnel":false}}]
CRED
IMPORTE=0
for _ in 1 2 3 4 5; do
  docker exec veille_n8n n8n import:credentials --input=/data/cred_veille.json >/dev/null 2>&1 && { IMPORTE=1; break; }
  sleep 3
done
rm -f data/cred_veille.json
[ "$IMPORTE" = 1 ] \
  && ok "justificatif « postgres veille » créé (identifiant $CRED_ID)" \
  || { ko "Import du justificatif refusé — créer les deux justificatifs à la main, DEPLOIEMENT.md § 1.3."; exit 1; }

# --- 5. Workflows -----------------------------------------------------
dire "Import des workflows"
N=0
for f in n8n_workflows/*.json; do
  docker exec veille_n8n n8n import:workflow --input="/workflows/$(basename "$f")" >/dev/null 2>&1 && N=$((N+1)) || ko "import refusé : $(basename "$f")"
done
ok "$N workflows importés"

# L'import ne publie jamais : sans publication, l'interface de lecture répond 404
# et le workflow d'erreur reste muet. Ces deux-là seulement sont publiés — les
# collecteurs portent leur cadence mais restent inactifs (§ 5.1 de DEPLOIEMENT.md).
for w in apiRestitutionV4 erreurCommuneV1 veille-documentaire-annuelle; do
  docker exec veille_n8n n8n publish:workflow --id="$w" >/dev/null 2>&1 || ko "publication refusée : $w"
done
ok "interface de lecture, workflow d'erreur et veille documentaire publiés"

dire "Redémarrage de l'orchestrateur (sans quoi les points de lecture répondent 404)"
docker compose restart n8n >/dev/null
# L'orchestrateur répond à son contrôle de santé AVANT d'avoir publié ses points
# de lecture : attendre la santé seule donnerait des 404 sur un dispositif sain.
# On attend donc le premier point de lecture lui-même.
printf '  … attente de la publication des points de lecture'
for _ in $(seq 1 60); do
  [ "$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$BASE/webhook/veille/sante" 2>/dev/null)" = 200 ] && break
  printf '.'; sleep 2
done; printf '\n'

# --- 6. Contrôle ------------------------------------------------------
dire "Contrôle"
ECHECS=0
for p in sante donnees signaux opportunites actions attribution geographie; do
  C=$(curl -s -o /dev/null -m 120 -w '%{http_code}' "$BASE/webhook/veille/$p" || echo 000)
  [ "$C" = 200 ] && ok "point de lecture /$p : $C" || { ko "point de lecture /$p : $C"; ECHECS=$((ECHECS+1)); }
done
C=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$APP" || echo 000)
[ "$C" = 200 ] && ok "interface servie : $C" || { ko "interface : $C"; ECHECS=$((ECHECS+1)); }

if [ "$ECHECS" -eq 0 ]; then
  dire "Le prototype est en marche."
  cat <<TXT
  Tableau de bord      $APP
  Orchestrateur        $BASE          (workflows, exécutions)
  Base (optionnel)     docker compose --profile outils up -d  puis  http://localhost:8081

  Les données affichées sont l'instantané daté livré avec le dépôt : ce sont les
  exécutions réelles de l'auteur, pas une collecte faite à l'instant. Le détail
  de ce que le dispositif fait, et de ce qu'il ne fait pas, est au rapport ;
  la mise en service pas à pas est dans DEPLOIEMENT.md.

  Pour tout arrêter :            docker compose down
  Pour repartir de zéro :        docker compose down -v   (efface la base, l'instantané sera rechargé)
TXT
else
  dire "$ECHECS contrôle(s) en échec — voir DEPLOIEMENT.md § 6."
  exit 1
fi
