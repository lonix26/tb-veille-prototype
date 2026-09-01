> **DOCUMENT REMPLACÉ le 25.08.2026** par [DEPLOIEMENT.md](DEPLOIEMENT.md), qui décrit la
> séquence complète actuelle. Celui-ci est conservé comme trace de l'état du 04.08.2026
> (avant le portage de la collecte vers l'orchestrateur) — ne pas s'en servir pour déployer.

# Prototype — mode d'emploi

## Contenu

| Fichier | Rôle |
|---|---|
| `schema.sql` | Base consolidée SQLite (tables runs, indicators, indicator_values, alerts, validation_queue + vues) |
| `n8n_workflows/decouverte_sources_multi_ia.json` | Couche 0 (amont, apériodique) : 4 modèles proposent des sources → normalisation et recoupement → vérification objective des URL → dédoublonnage → file de qualification humaine + journal des propositions non vérifiables |
| `n8n_workflows/collecte_hard_data.json` | Workflow ETL : APIs Banque mondiale / Comtrade / Eurostat → normalisation → contrôles → dépôt brut → chargement |
| `n8n_workflows/extraction_composite_multi_ia.json` | Pipeline composite : extraction parallèle 3 LLM → contrôle de consistance → consensus ou file de validation humaine |
| `n8n_workflows/analyse_tendances_alertes.json` | Calculs déterministes de tendance → commentaire exécutif LLM (données fournies uniquement) → alertes à valider |
| `n8n_workflows/scenario_c_agent_autonome.json` | **Artefact expérimental — hors dispositif de production.** Agent autonome (scénario C) confiné en espace `sandbox_agent`, plafonné en itérations et en appels de modèle, trace intégralement journalisée. Sert exclusivement à la confrontation B/C du § 10.5 |
| `dashboard.html` | Tableau de bord décideur — autonome, s'ouvre dans un navigateur, données réelles embarquées (run #1, 04.08.2026) |

## Démarrage rapide

1. **Dashboard** : double-cliquer `dashboard.html` (aucune installation).
2. **n8n** : `docker run -it --rm -p 5678:5678 -v n8n_data:/home/node/.n8n n8nio/n8n` puis importer les JSON (menu Workflows → Import from file). Renseigner les credentials API (OpenAI/Anthropic/Google/Perplexity) dans n8n avant activation. Le workflow agentique requiert en outre les nœuds LangChain (inclus dans l'image n8n depuis la version 1.x).
3. **Base** : `sqlite3 veille.db < schema.sql`. Les workflows postent vers un service `loader` (HTTP → SQLite) ; en attendant son implémentation, les nœuds « Charger » peuvent être remplacés par des nœuds d'écriture de fichier.

## Précaution d'usage du workflow agentique

`scenario_c_agent_autonome.json` publie **sans validation humaine**. Il n'écrit que sur les routes `/sandbox/*` du service `loader`, qui doivent être servies par un espace de données distinct de la base de production. Ne jamais rediriger ses nœuds d'écriture vers `/load` ou `/commentaries` : le dispositif du scénario B garantit qu'aucune valeur non validée n'atteint le décideur, et cette garantie est le contenu même du travail.

## État et limites (honnêtes)

- Les workflows sont des squelettes importables : la logique de mappage par API (nœud « Normaliser ») est à compléter source par source.
- Le workflow de découverte de sources suppose une route `loader` `/source-qualification-queue` et un journal `/discovery-log`, non encore implémentés.
- Le workflow agentique n'a pas été exécuté : le protocole de confrontation (§ 10.5.2) et la grille (§ 10.5.3) restent à remplir.
- Le dashboard embarque le run #1 en dur ; le branchement sur la base (vue `v_current`) est l'étape suivante.
- Données embarquées : collectées et vérifiées le 04.08.2026, sources citées sur chaque carte.
