# Mode opératoire — week-end du 8 au 10 août 2026

Objectif : présenter mardi 11.08 un tableau de bord affichant **les 26 indicateurs de la grille**, dont le plus grand nombre possible portant des données réelles collectées automatiquement.

Principe de conduite : **chaque étape se vérifie avant de passer à la suivante.** Une étape qui échoue s'arrête et se documente ; elle ne se contourne pas. Toutes les sorties d'exécution sont à conserver — elles constituent des pièces d'annexe 5.

---

## Étape 0 — Sauvegarde et versionnement (30 min, non négociable)

Rien de ce qui suit ne doit être entrepris avant cette étape. Les directives institutionnelles n'admettent pas la perte de données comme motif de retard.

```bash
cd "/home/nilo/Travail de bachelor"
git init
printf '.env\nprototype/data/\n' >> .gitignore
git add -A && git status --short | head -30      # vérifier qu'aucun .env n'apparaît
git commit -m "admin: état du dossier au 07.08.2026, avant extension du prototype"
```

Puis créer un dépôt privé sur GitHub et pousser. **Vérifier que `prototype/.env` n'est pas parti.**

---

## Étape 1 — Renommages, dans cet ordre impératif (10 min)

Les régénérations lancées avant ces renommages produisent des fichiers vides — c'est ce qui s'est produit le 07.08.

```bash
cd "/home/nilo/Travail de bachelor"
git mv annexe_A3 annexe_3
git mv annexe_A5 annexe_5
git mv annexes/A1_tableau_de_veille.md annexes/1_tableau_de_veille.md
git mv annexes/A1_tableau_de_veille.xlsx annexes/1_tableau_de_veille.xlsx
git mv prototype/exports/generer_annexe_A1.sh prototype/exports/generer_annexe_1.sh
git commit -m "pilotage: codification des annexes en chiffres arabes"
```

**Contrôle** : `ls prototype/exports/generer_annexe_1.sh` doit répondre.

---

## Étape 2 — Migrations restantes (20 min)

La migration de scission des questions de veille est déjà appliquée — les exports CSV en portent la preuve. Restent deux migrations, indépendantes l'une de l'autre.

```bash
cd "/home/nilo/Travail de bachelor/prototype"
docker compose up -d
docker compose exec -T db pg_isready -U veille -d veille

# Vérifier d'abord si la couche de métriques est déjà en place
docker compose exec -T db psql -U veille -d veille -c "SELECT to_regclass('public.v_metriques');"
```

Si la réponse est vide, appliquer :

```bash
docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
  < migrations/2026-08-07_metriques_derivees.sql 2>&1 | tee ../annexe_5/metriques_2026-08-08.txt
```

Puis, dans tous les cas :

```bash
docker compose exec -T db psql -U veille -d veille -v ON_ERROR_STOP=1 \
  < migrations/2026-08-07_socle_declaratif.sql 2>&1 | tee ../annexe_5/socle_declaratif_2026-08-08.txt
```

**Contrôles attendus.** La vérification n° 1 doit annoncer 2 liaisons actives (A5, S3) et 8 à vérifier. La vérification n° 3 doit **échouer volontairement** sur `chk_binding_verifie` — c'est la preuve qu'une liaison ne peut pas être activée sans vérification tracée. La dernière doit montrer le registre inchangé.

---

## Étape 3 — Premier tour du collecteur générique (45 min)

Importer `n8n_workflows/collecte_generique.json` dans l'orchestrateur, vérifier que les nœuds PostgreSQL pointent sur la bonne connexion, puis **exécuter manuellement**.

Deux liaisons sont actives et vérifiées : A5 (Eurostat, déjà connu) et S3 (Our World in Data, structure confirmée le 07.08). Le premier tour doit donc écrire A5 **et** S3 — c'est-à-dire faire passer l'aérospatial de zéro à un indicateur collecté.

```bash
docker compose exec -T db psql -U veille -d veille -c \
  "SELECT indicator_id, count(*) obs, min(period), max(period), max(run_id) FROM indicator_values GROUP BY 1 ORDER BY 1;"
```

**Si le collecteur échoue**, ne pas s'acharner sur le mode générique : dégrader proprement. Passer une seule liaison à `actif` à la fois et relancer — le workflow traite alors un indicateur unique, exactement comme le pilote A5 qui fonctionne. Un collecteur qui traite deux sources l'une après l'autre vaut mieux qu'un collecteur générique cassé.

**Point de vigilance connu** : le nœud d'appel HTTP demande la réponse en texte pour traiter JSON et CSV par le même chemin. Si le décodage Eurostat échoue, c'est probablement que la réponse arrive déjà désérialisée — dans ce cas, remplacer `JSON.parse(l.corps)` par une garde : `typeof l.corps === 'string' ? JSON.parse(l.corps) : l.corps`.

---

## Étape 4 — Élargir la couverture (2 à 4 h, cœur du week-end)

Chaque liaison `a_verifier` se traite selon le même protocole en trois temps. **Ne jamais activer une liaison sans avoir vu la réponse de la source.**

1. **Appeler la source à la main** (navigateur ou `curl`) avec les paramètres semés.
2. **Constater** : la réponse existe-t-elle ? contient-elle la série attendue ? sur quelle profondeur ? avec quels libellés ?
3. **Activer**, en consignant qui a vérifié et quand :

```sql
UPDATE source_bindings
   SET statut = 'actif', verifie_par = 'N. Castillo', verifie_le = now(),
       note = note || ' | Vérifié le 08.08.2026 : <ce que la réponse contient réellement>'
 WHERE indicator_id = 'XX' AND statut = 'a_verifier';
```

### Deux liaisons sont prêtes — c'est à toi de les écrire

La reconnaissance du 07.08 (`RECONNAISSANCE_SOURCES_2026-08-07.md`) a vérifié T2 et T4 de bout en bout. Les paramètres sont établis ; **l'acte de qualification t'appartient**. Appelle chaque URL toi-même, regarde la réponse, puis écris la liaison. Ne recopie pas sans avoir vu.

T2, taux de change BNS. Appelle d'abord :
`https://data.snb.ch/api/cube/devkum/data/csv/fr?fromDate=2023-01&dimSel=D0(M0),D1(USD1,EUR1)`

Observe : le BOM, les deux lignes de métadonnées, la ligne vide, le point-virgule, et le fait que le fichier empile deux devises. Le mappage doit donc porter `separateur`, `sauter_lignes`, un filtre sur `D0` et un étiquetage de zone depuis `D1` — le décodeur du collecteur générique accepte ces quatre réglages. À toi d'écrire l'insertion.

T4, PIB mondial FMI. Appelle :
`https://www.imf.org/external/datamapper/api/v1/NGDP_RPCH/WEOWORLD`

Observe surtout que **le filtrage par l'URL ne fonctionne pas** : la réponse contient toutes les économies. C'est une décision de conception à prendre — filtrer à la réception, sur la clé `WEOWORLD`. Le connecteur `json_generique` actuel lit une liste ; cette réponse est un objet imbriqué par année. **Il ne conviendra pas tel quel.** Soit tu ajoutes un connecteur, soit tu tranches autrement. C'est exactement le genre de choix qu'un jury te demandera d'expliquer.

Ces deux indicateurs referment le défaut I-5 : la vue « Contexte » et la question d'attribution QV0, décrites depuis longtemps comme existantes sans l'être, auront enfin un contenu.

### Ordre de traitement recommandé, du meilleur rendement au plus incertain

| Rang | Indicateurs | Pourquoi en premier | Difficulté |
|---|---|---|---|
| 1 | **M2** | Requête déjà vérifiée techniquement. Une seule décision à prendre : tester `nace_r2=C32_5` ; si la série existe, corriger la liaison ; sinon requalifier M2 sur C32 au § 8.4.2 et énoncer la limite. Débloque le médical. | Faible |
| 2 | **H3, M1, A4, S6** | Quatre indicateurs, un seul connecteur, les quatre secteurs d'un coup. **À traiter en premier.** Le point d'accès public répond **sans clé** : `getMetadata` renvoie du JSON valide avec un champ d'erreur vide, et `preview` renvoie une charge compressée. Commande de confirmation : `curl -s --compressed "https://comtradeapi.un.org/public/v1/preview/C/A/HS?reporterCode=756&period=2023&cmdCode=91&flowCode=X&partnerCode=0" \| head -c 800`. Relever le nom du tableau de données et les colonnes période / valeur / déclarant / partenaire, **ainsi que le quota** — l'aperçu public est généralement plafonné. Ensuite les quatre liaisons se déduisent l'une de l'autre, seul `cmdCode` change : `91`, `9018,9019,9020,9021,9022`, `8708`, `88`. | Faible à moyenne |
| 3 | **M3** | Techniquement simple, mais **exige une décision de requalification de source** : le § 8.4.2 qualifie l'OMS, la Banque mondiale rediffuse la même donnée plus simplement. Cette décision est humaine et doit être portée au tableau de confiance avant activation. | Faible, mais décision requise |
| 4 | **A3, S4** | Relever l'URL de téléchargement direct. Si la source ne diffuse qu'en Excel derrière une page de présentation, l'indicateur relève du traitement composite et sort du périmètre du week-end. | Incertaine |

**Règle d'arrêt : une heure par source.** Au-delà, la source est déclarée non instrumentable dans cette itération, la liaison reste `a_verifier` avec une note expliquant ce qui bloque, et l'on passe à la suivante. Une lacune documentée est un résultat ; un week-end passé sur une seule API ne l'est pas.

---

## Étape 5 — Restitution (30 min)

Réimporter `n8n_workflows/api_restitution.json` — sa requête a été étendue au référentiel complet, aux métriques et à l'instanciation sectorielle. Vérifier que le workflow est **actif**.

```bash
curl -s http://localhost:5678/webhook/veille/donnees | head -c 600
```

Puis ouvrir `prototype/tableau_de_bord.html`. La page affiche les 26 indicateurs, regroupés par question de veille dans leur formulation sectorielle, avec pour chacun soit ses données, soit la mention « qualifié, non instrumenté ».

**Contrôle de la doctrine** : arrêter la base (`docker compose stop db`) et recharger la page. Elle doit afficher un message d'erreur explicite et **aucune valeur**. Si elle affiche encore des chiffres, c'est qu'une donnée est embarquée quelque part — à corriger avant mardi.

Enfin, régénérer les pièces :

```bash
bash exports/generer_annexe_1.sh > "../annexes/1_tableau_de_veille.md"
wc -c "../annexes/1_tableau_de_veille.md"      # doit être très supérieur à 0
bash exports/generer_classeur.sh
```

---

## Étape 6 — Archiver `dashboard.html` (5 min)

Ce fichier est une maquette à données figées, contredite par la base sur trois points. Un jury qui ouvre le mauvais fichier verra la faute que la thèse dénonce.

```bash
git mv prototype/dashboard.html prototype/maquette_run1_2026-08-04.html
```

---

## Ce qu'il faut dire mardi, et ne pas dire

**Dire** : « le référentiel compte 26 indicateurs, le tableau de bord les affiche tous, N sont collectés automatiquement, et la page dit elle-même lesquels ne le sont pas ».

**Ne pas dire** : « le prototype est instancié sur les quatre secteurs ». Il affiche les quatre secteurs ; il en collecte une partie.

Le test reste le même à chaque phrase : *si le directeur demande de le montrer maintenant, est-ce que je peux ?*

---

## Position de repli si le week-end tourne court

Ordre de renoncement, du moins coûteux au plus coûteux :

1. Abandonner A3 et S4 — deux indicateurs, sources incertaines.
2. Abandonner Comtrade si la clé bloque — quatre indicateurs, mais un seul obstacle, à documenter comme limite d'accès.
3. Se limiter à A5, S3 et M2 — trois indicateurs, trois secteurs représentés, et un tableau de bord complet dans sa structure.

**Même dans le scénario le plus dégradé, le tableau de bord affiche les 26 indicateurs et leur état réel.** C'est cela qui est démontrable mardi, et c'est déjà une réponse à la question de recherche : le dispositif sait dire ce qu'il ne sait pas.
