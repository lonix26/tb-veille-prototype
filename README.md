# Prototype — système de veille économique semi-automatisée

Sous-projet technique du Travail de Bachelor. Autonome : un clone propre démarre avec Docker et rien d'autre.

## Ce que c'est

Un dispositif de veille *human-in-the-loop* (scénario B) qui collecte des indicateurs économiques sur quatre secteurs, les consolide en base avec leur statut de fiabilité, en tire des tendances calculées et des commentaires rédigés par un modèle de langage, et les restitue à un décideur avec la traçabilité de chaque valeur affichée.

Deux principes gouvernent l'implémentation :

**Usage différencié.** Les *hard data* passent par un ETL classique — aucun modèle de langage n'intervient là où la donnée existe déjà en format structuré. L'IA est réservée à l'extraction depuis le non structuré, à la synthèse et au qualitatif.

**La base fait respecter les règles.** Le schéma ne se contente pas de stocker ce que le rapport décrit, il rend impossible ce qu'il interdit : une valeur extraite par IA ne peut pas porter le statut d'une donnée de source, un consensus partiel n'est pas un consensus, une validation humaine sans validateur nommé est rejetée, et le registre est en ajout seul. Ces règles sont dans `db/01_schema.sql`, en contraintes et en déclencheurs — pas dans la discipline des workflows.

## Démarrage

```bash
cp .env.example .env      # renseigner POSTGRES_PASSWORD
mkdir -p data/staging
docker compose up -d
```

n8n sur http://localhost:5678. La suite — vérification des contraintes, connexion de n8n à la base, exécution du pilote — est détaillée dans **[RUNBOOK.md](RUNBOOK.md)**, qui est le document à dérouler.

## Contenu

| Chemin | Rôle |
|---|---|
| `docker-compose.yml` | PostgreSQL + n8n. Deux services : la contrainte de coût nul interdit d'en ajouter sans nécessité. |
| `db/01_schema.sql` | Schéma et règles métier tenues par la base |
| `db/02_referentiel.sql` | Grille d'indicateurs du ch. 8 — source de vérité du décompte |
| `db/03_vues.sql` | Vues de restitution et vues de contrôle |
| `n8n_workflows/` | Workflows importables — voir ci-dessous |
| `dashboard.html` | Tableau de bord décideur, autonome |
| `RUNBOOK.md` | Mise en service et tranche verticale, avec critères de réussite |

### Workflows

| Fichier | Rôle | État |
|---|---|---|
| `decouverte_sources_multi_ia.json` | Couche 0 : proposition multi-modèles, vérification objective des URL, file de qualification humaine | Squelette |
| `collecte_a5_eurostat_pilote.json` | Tranche verticale ETL de bout en bout sur l'indicateur A5 | Prêt à exécuter |
| `collecte_hard_data.json` | Collecte ETL généralisée | Squelette, à migrer vers Postgres |
| `extraction_composite_multi_ia.json` | Pipeline composite : consensus ou file de validation | Squelette, à migrer vers Postgres |
| `analyse_tendances_alertes.json` | Tendances déterministes, commentaire sous contrainte, alertes | Squelette, à migrer vers Postgres |
| `scenario_c_agent_autonome.json` | **Artefact expérimental, hors production.** Agent autonome confiné en bac à sable, pour la confrontation B/C | Spécifié, non exécuté |

`scenario_c_agent_autonome.json` publie sans validation humaine. Il n'écrit que dans le schéma `sandbox`. Ne jamais rediriger ses écritures vers les tables de production : la garantie qu'aucune valeur non validée n'atteint le décideur est le contenu même du travail.

## État

Le prototype est en cours de mise à l'épreuve. Ce qui est démontré et ce qui ne l'est pas est tenu à jour dans le journal d'exécution du RUNBOOK et reporté au chapitre 11 du rapport. Aucune affirmation de fonctionnement n'est portée ici avant d'avoir été observée.
