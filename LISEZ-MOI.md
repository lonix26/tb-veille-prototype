# Prototype de veille économique — pour l'ouvrir en une commande

Travail de Bachelor, N. Castillo (HEG Arc). Ce dossier est le livrable technique.
Il n'y a rien à installer d'autre que **Docker** — et, sous Windows, Git pour Windows.

```bash
bash demarrer.sh
```

Sous **Windows** : Docker Desktop lancé, puis double-clic sur `demarrer.cmd`. Il exécute le même
script par Git Bash, livré avec [Git pour Windows](https://git-scm.com), ou à défaut par WSL.
Docker Desktop seul ne suffit pas : le script est écrit pour bash.

Puis ouvrir **<http://localhost:8080>**.

La commande met en marche les trois services (la console d'inspection de la base est optionnelle), charge la base, crée le justificatif d'accès dont
l'orchestrateur a besoin, importe les vingt-deux workflows, publie l'interface de lecture et
vérifie que tout répond. Comptez deux à trois minutes au premier lancement, le temps que la base
se charge. Le script dit ce qu'il fait à chaque étape, et s'arrête en nommant la cause s'il
échoue.

Pour tout arrêter : `docker compose down`. Pour repartir de zéro : `docker compose down -v`.

## Ce que vous voyez, et ce que c'est

Le tableau de bord affiche **les données réelles du travail** : 53 indicateurs au référentiel,
203 176 observations, 216 exécutions datées, 1 415 items de presse et de marchés publics, les
commentaires et les lectures produits par les modèles avec leur statut de relecture.

**Ce sont les exécutions de l'auteur, pas une collecte faite à l'instant.** Elles sont livrées
sous la forme d'un instantané daté (`db/03_donnees_demonstration.sql.gz`), chargé automatiquement
au premier démarrage. Sans lui, l'application serait juste et vide, et vous n'auriez rien à
regarder : lancer une collecte réelle suppose des clés d'API que ce dossier ne contient pas, et
ne doit pas contenir.

Le registre est en **ajout seul** : chaque valeur porte l'exécution qui l'a écrite, son statut de
validation et sa source. C'est ce que l'écran *Exécutions* donne à lire, et c'est vérifiable à la
requête.

## Par où commencer

| Écran | Ce qu'il montre |
|---|---|
| **Vue d'ensemble** | l'état des quatre marchés, les mouvements inhabituels, l'indicateur synthétique |
| **Actions** | les marchés publics adressables, jusqu'à l'acheteur nommé |
| **Anticiper** | ce que les indicateurs avancés disent avant les séries de constat |
| **Marché** (un par secteur, plus le socle) | le commentaire sous statut, les cartes d'indicateurs, les mouvements et les paniers |
| **Référentiel** | les 53 indicateurs, leur source, leur statut, leur question de veille |
| **Exécutions** | l'historique daté, et l'écart entre deux exécutions |
| **Fiabilité** | ce qui est validé par un humain, ce qui ne l'est pas, et ce qui manque |

Ce qu'un modèle a écrit est étiqueté comme tel à l'écran, avec son statut de relecture. Rien de
ce que vous lisez n'est présenté comme vérifié si personne ne l'a vérifié.

## Aller plus loin

- **`DEPLOIEMENT.md`** — la mise en service pas à pas, expliquée et justifiée. C'est la référence ;
  `demarrer.sh` n'en est que le raccourci. Le § 1.2 dit quelles clés d'API servent à quoi, le § 5
  comment relancer une collecte, le § 5.1 comment activer les cadences d'exécution.
- **`PASSATION_PROTOTYPE.md`** — le journal technique complet, jour par jour : ce qui a été
  démontré, ce qui a échoué, et ce qui reste ouvert.
- **`n8n_workflows/`** — les vingt-deux workflows, importables tels quels. L'orchestrateur est sur
  <http://localhost:5678> une fois le script passé.
- **`db/01_socle.sql`** — le schéma. Les règles du dispositif y sont des contraintes SQL : un
  consensus partiel n'est pas un consensus, une validation sans validateur nommé est refusée,
  et rien ne s'écrase.
- **`verification/base.sh`** et **`dashboard-app/verification/executer.sh`** — les deux harnais de
  vérification, à lancer pour constater par vous-même.

## Si quelque chose ne va pas

| Symptôme | Cause probable |
|---|---|
| L'application s'affiche mais reste vide | l'orchestrateur n'a pas publié ses points de lecture : relancer `bash demarrer.sh` |
| « Registre vide » au démarrage | l'instantané ne se charge qu'au **premier** démarrage : `docker compose down -v` puis relancer |
| Le port 8080 ou 5678 est déjà pris | un autre service local les occupe ; les changer dans `docker-compose.yml` |
| Une collecte échoue | c'est attendu sans clés d'API (`DEPLOIEMENT.md` § 1.2) ; la consultation, elle, n'en demande aucune |
