# Prototype : système de veille économique semi-automatisée

Sous-projet technique du Travail de Bachelor. Autonome : un clone propre démarre avec Docker et rien d'autre.

## Ce que c'est

Un dispositif de veille *human-in-the-loop* (scénario B) qui collecte des indicateurs économiques sur quatre secteurs industriels, les consolide en base avec leur statut de fiabilité, en tire des tendances calculées, des événements lus dans la presse professionnelle et des commentaires rédigés par un modèle de langage, et restitue le tout à un décideur avec la traçabilité de chaque valeur affichée.

Deux principes gouvernent l'implémentation :

**Usage différencié.** Les *hard data* passent par un ETL classique : aucun modèle de langage n'intervient là où la donnée existe en format structuré. L'IA est réservée à l'extraction depuis le non structuré (communiqués, tableaux illisibles par le code, flux de presse), à la synthèse et au qualitatif. Tout ce qu'un modèle écrit est étiqueté comme tel à l'écran, avec son statut de relecture.

**La base fait respecter les règles.** Le schéma rend impossible ce qu'il interdit : une valeur extraite par IA ne peut pas porter le statut d'une donnée de source, un consensus partiel n'est pas un consensus, une validation humaine sans validateur nommé est rejetée, et le registre est en ajout seul — chaque exécution est datée, rien n'est écrasé, c'est l'écart entre exécutions qui fait la tendance. Ces règles sont des contraintes SQL (`db/01_socle.sql`), pas de la discipline de workflow.

## Démarrage

```bash
cp .env.example .env      # renseigner POSTGRES_PASSWORD et CLES_API_FICHIER
mkdir -p data/staging
docker compose up -d
```

| service | adresse |
|---|---|
| n8n (orchestrateur) | http://localhost:5678 |
| tableau de bord | http://localhost:8080 |
| adminer (optionnel) | `--profile outils` → http://localhost:8081 |

Les clés d'API des modèles vivent **hors du dossier** (chemin déclaré par `CLES_API_FICHIER`) : ni dans le dépôt, ni dans les copies de sauvegarde. La mise en service pas à pas est dans **[DEPLOIEMENT.md](DEPLOIEMENT.md)**.

## Contenu

| Chemin | Rôle |
|---|---|
| `docker-compose.yml` | PostgreSQL, n8n, nginx (tableau de bord), adminer en option |
| `db/01_socle.sql` | Schéma, contraintes métier, vues de calcul et de restitution |
| `db/02_referentiel.sql` | Grille d'indicateurs et questions de veille (le décompte se cite depuis `v_bilan_referentiel`) |
| `migrations/` | Toute évolution du schéma ou du référentiel, datée — jamais d'UPDATE silencieux |
| `n8n_workflows/` | 26 workflows importables ; les fichiers `*.avant_*` sont les états antérieurs conservés |
| `dashboard-app/` | Application React/Vite/ECharts servie par nginx, lecture seule sur l'API n8n |
| `exports/` | Scripts de génération des annexes depuis la base |
| `DEPLOIEMENT.md` | Séquence complète de mise en service et d'exploitation |
| `PASSATION_PROTOTYPE.md` *(racine du TB)* | Journal d'état : ce qui est démontré, ce qui ne l'est pas, et les défauts trouvés |

### Les chaînes de traitement

| chaîne | workflows principaux | rythme |
|---|---|---|
| Collecte *hard data* (30 indicateurs) | `collecte_generique` (piloté par `source_bindings`, jetons de date), `collecte_fh_horlogerie`, `collecte_xlsx_indexe` | mensuel |
| Flux qualitatifs | `collecte_flux` → `triage_ia_flux` → `extraction_evenements_flux` → `derivation_intensite_signalement` | quotidien à mensuel |
| Composites (extraction IA multi-modèles + validation humaine) | `veille_acea_A2` et `veille_documentaire_annuelle` (semeurs) → `extraction_composite_A2` / `_CP` / `_A1_ccfa` | mensuel / annuel |
| Synthèse | `analyse_tendances_alertes` (commentaire exécutif), `lecture_transversale` (hypothèses citant leurs faits) | à la demande |
| Restitution | `api_restitution` (webhook, lecture seule) | permanent |

`scenario_c_agent_autonome.json` reste un **artefact expérimental hors production** : il publie sans validation humaine et n'écrit que dans le schéma `sandbox`. Ne jamais rediriger ses écritures vers les tables de production.

## État

L'état démontré fait foi par le journal (`PASSATION_PROTOTYPE.md`) et par la base elle-même (table `runs`, vues de bilan) — jamais par ce fichier. Aucune affirmation de fonctionnement n'est portée ici avant d'avoir été observée sur un run.
