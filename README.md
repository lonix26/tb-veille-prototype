# Prototype : système de veille économique semi-automatisée

Sous-projet technique du Travail de Bachelor. Autonome : un clone propre démarre avec Docker, Node.js pour construire l'interface, un fichier de clés d'API hors dossier et deux *credentials* n8n — la séquence complète est dans `DEPLOIEMENT.md`.

## Ce que c'est

Un dispositif de veille *human-in-the-loop* (scénario B) qui collecte des indicateurs économiques sur quatre secteurs industriels, les consolide en base avec leur statut de fiabilité, en tire des tendances calculées, des événements lus dans la presse professionnelle et des commentaires rédigés par un modèle de langage, et restitue le tout à un décideur avec la traçabilité de chaque valeur affichée.

Deux principes gouvernent l'implémentation :

**Usage différencié.** Les *hard data* passent par un ETL classique : aucun modèle de langage n'intervient là où la donnée existe en format structuré. L'IA est réservée à l'extraction depuis le non structuré (communiqués, tableaux illisibles par le code, flux de presse), à la synthèse et au qualitatif. Tout ce qu'un modèle écrit est étiqueté comme tel à l'écran, avec son statut de relecture.

**La base fait respecter les règles.** Le schéma rend impossible ce qu'il interdit : une valeur extraite par IA ne peut pas porter le statut d'une donnée de source, un consensus partiel n'est pas un consensus, une validation humaine sans validateur nommé est rejetée, et le registre est en ajout seul — chaque exécution est datée, rien n'est écrasé, c'est l'écart entre exécutions qui fait la tendance. Ces règles sont des contraintes SQL (`db/01_socle.sql`), pas de la discipline de workflow.

## Démarrage

```bash
bash demarrer.sh
```

Une commande, rien à installer d'autre que Docker : services, base chargée, justificatif d'accès,
workflows importés, interface de lecture publiée, contrôle de santé. Puis <http://localhost:8080>.
Le pas à pas expliqué reste **[DEPLOIEMENT.md](DEPLOIEMENT.md)**, dont ce script n'est que le
raccourci ; **[LISEZ-MOI.md](LISEZ-MOI.md)** dit quoi regarder une fois l'application ouverte.

Les données affichées sont un **instantané daté** des exécutions de l'auteur
(`db/03_donnees_demonstration.sql.gz`), chargé au premier démarrage : le dispositif est donc
consultable sans clé d'API. Ce n'est pas une collecte faite à l'instant, et relancer une collecte
réelle demande les clés (§ 1.2 du déploiement).

À la main, si l'on préfère :

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
| `n8n_workflows/` | 22 workflows importables ; `archive/` conserve les états antérieurs, hors boucle d'import |
| `dashboard-app/` | Application React/Vite/ECharts servie par nginx, lecture seule sur l'API n8n |
| `verification/` | Harnais de vérification de la base : invariants structurels et faits figés, comparés au relevé |
| `tests/` | Tests de contraintes : cinq écritures qui doivent échouer, pièce de l'annexe 5 |
| `etage2/` | Analyse de sensibilité de la lecture décisionnelle au profil métier |
| `exports/` | Scripts de génération des annexes depuis la base |
| `demarrer.sh` | Mise en marche en une commande : compose, import des workflows, contrôle des points de lecture |
| `regenerer_socle.sh` | Régénère `db/01_socle.sql` et `db/02_referentiel.sql` depuis l'instance en service |
| `preparer_archive.sh` | Constitue l'archive de remise, clés et données exclues |
| `DEPLOIEMENT.md` | Séquence complète de mise en service et d'exploitation |
| `PASSATION_PROTOTYPE.md` | Journal d'état : ce qui est démontré, ce qui ne l'est pas, et les défauts trouvés |
| `CONCEPTION_ETAGE2.md` | Conception de l'étage de flux : familles de sources, chaîne, schéma de données |
| `NOTES_DE_VERSION_DEPOT.md` | Ce que porte l'état déposé, et ce qu'il ne porte pas |

### Les chaînes de traitement

| chaîne | workflows principaux | rythme |
|---|---|---|
| Collecte *hard data* (le décompte fait foi par `v_bindings_actifs`) | `collecte_generique` (piloté par `source_bindings`, jetons de date), `collecte_fh_horlogerie`, `collecte_xlsx_indexe` | mensuel |
| Flux qualitatifs | `collecte_flux` → `triage_ia_flux` → `extraction_evenements_flux` → `derivation_intensite_signalement` | quotidien à mensuel |
| Composites (extraction IA multi-modèles + validation humaine) | `veille_acea_A2` et `veille_documentaire_annuelle` (semeurs) → `extraction_composite_A2` / `_CP` / `_A1_ccfa` | mensuel / annuel |
| Synthèse | `analyse_tendances_alertes` (commentaire exécutif), `lecture_transversale` (hypothèses citant leurs faits) | à la demande |
| Restitution | `api_restitution` (webhook, lecture seule) | permanent |

La confrontation B/C (§ 10.5) a été portée par le script **`scenario_c/agent_autonome.py`**, qui écrit dans le schéma `sandbox` et publie sans validation humaine : artefact expérimental, hors production, à ne jamais rediriger vers les tables de production. La maquette n8n `scenario_c_agent_autonome.json` n'a jamais été importée ni exécutée ; elle est archivée dans `n8n_workflows/archive/squelettes_2026-08-04/` (jusqu'au 02.09.2026, ce paragraphe lui attribuait à tort l'expérience).

## État

L'état démontré fait foi par le journal (`PASSATION_PROTOTYPE.md`) et par la base elle-même (table `runs`, vues de bilan) — jamais par ce fichier. Aucune affirmation de fonctionnement n'est portée ici avant d'avoir été observée sur un run.
