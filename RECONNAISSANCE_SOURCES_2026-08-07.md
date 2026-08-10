# Reconnaissance technique des sources — 7 août 2026

Vérification de l'accessibilité **réelle** des sources du référentiel, par appel effectif aux API et aux fichiers. Aucune conclusion n'est tirée d'une documentation : seules les réponses obtenues font foi.

Ce document est un **résultat de qualification**, au sens du § 8.2.1 : il constate ce que chaque source livre effectivement. La décision d'activer une liaison reste humaine, nominative et à porter en base.

---

## Constat de fond, à porter au rapport

**L'indicateur pivot du secteur horloger n'est pas collectable automatiquement.**

H1 — exportations horlogères suisses par marché de destination — est décrit au § 8.4.1 comme « l'indicateur pivot, publié chaque mois avec détail par marché ». Vérification faite, la Fédération de l'industrie horlogère ne publie **que des PDF** : communiqués mensuels et tableaux, servis sous des noms de fichiers portant une date encodée, sans motif stable, et sans aucun export CSV ou tabulaire.

Ce n'est pas un contretemps technique, c'est une **contrainte de fond** sur la déclinaison sectorielle horlogère : le secteur le mieux doté en appareil statistique du portefeuille est celui dont l'indicateur central relève du traitement non structuré. Le § 8.4.1 devra le dire, et cela renforce plutôt qu'il n'affaiblit l'argument du travail — c'est exactement ce qui justifie l'existence d'une catégorie composite et d'un pipeline d'extraction avec validation humaine.

Le domaine correct est `fhs.swiss`, non `fhs.ch`.

---

## Sources vérifiées et prêtes à être activées

### T2 — Taux de change CHF/USD et CHF/EUR (BNS) — ACTIVÉ le 09.08.2026

**La source la mieux vérifiée du lot**, de bout en bout, avec valeurs réelles obtenues. Liaison `csv_generique` créée et collectée le 09.08 (86 observations, deux séries CHF_USD/CHF_EUR distinguées par la zone). Migration `migrations/2026-08-09_bindings_T2_T4.sql`. Détail du filtrage validé : `filtres={"D0":["M0"]}`, `geo_depuis={"D1":{"USD1":"CHF_USD","EUR1":"CHF_EUR"}}`, `sauter_lignes=3`, `separateur=";"`.

```
https://data.snb.ch/api/cube/devkum/data/csv/fr?fromDate=2026-01&dimSel=D0(M0),D1(USD1,EUR1)
```

Structure constatée : BOM UTF-8, **deux lignes de métadonnées puis une ligne vide** — donc trois lignes à sauter —, séparateur **point-virgule**, valeurs entre guillemets. Colonnes `Date` (format `AAAA-MM`), `D0` (type de cours : `M0` moyenne mensuelle, `M1` fin de mois), `D1` (devise : `USD1`, `EUR1`), `Value` (décimale à point, cellule vide si absente).

Sans `fromDate` ni `dimSel`, l'appel renvoie le cube entier depuis 1914, plusieurs mégaoctets. **Toujours filtrer côté serveur.**

Attention : le cube empile plusieurs séries dans un même fichier. Il faut filtrer sur `D0 = M0` pour ne garder que les moyennes mensuelles, et distinguer les devises par `D1`.

### T4 — Croissance du PIB mondial (FMI) — ACTIVÉ le 09.08.2026

```
https://www.imf.org/external/datamapper/api/v1/NGDP_RPCH/WEOWORLD
```

JSON, sans clé. Structure : `values` → `NGDP_RPCH` → code économie → année (`"2023"`, `"2024"`…) → valeur. Série annuelle, projections incluses jusqu'en 2031.

**Activé le 09.08** via un nouveau mode du connecteur `json_generique` — `objet_par_periode` — nécessaire parce que la structure est un dictionnaire `{année: valeur}` et non une liste (le connecteur ne savait pas la lire). Liaison bornée à **2023-2025** : les années 2026+ sont des **projections FMI**, écartées tant que leur statut (distinct de `valide_source`) n'est pas tranché — écrire une prévision en `valide_source` serait surdéclarer. Décision ouverte à porter au rapport : comment restituer les projections sans les confondre avec des réalisés. Migration `migrations/2026-08-09_bindings_T2_T4.sql`.

Deux réserves constatées : **le filtrage par l'URL ne fonctionne pas** — la réponse contient toutes les économies quelle que soit la clé demandée, le tri doit se faire à la réception ; et la voie `dataservices.imf.org` citée dans la documentation encore en ligne est **morte**, elle renvoie une réponse vide.

### M2 — Production industrielle, instruments médicaux (Eurostat)

Requête techniquement vérifiée, 41 valeurs retournées, série cohérente. **Décision à prendre avant activation** : la requête porte sur NACE `C32`, agrégat plus large que le `C32.5` spécifié au § 8.4.2. Tester `nace_r2=C32_5` ; si la série existe, corriger la liaison ; sinon requalifier l'indicateur et énoncer la limite. Noter aussi que la fréquence réelle est **mensuelle**, pas trimestrielle comme l'annonce le rapport.

---

## Sources accessibles, mais coûteuses

### H2, M4 — Emploi et établissements par branche NOGA (OFS, STATENT)

L'interface PX-Web de l'OFS est ouverte, sans clé :
`https://www.pxweb.bfs.admin.ch/api/v1/fr/`

Table identifiée : **`px-x-0602010000_103`**, « Établissements et emplois selon Année, Canton, Genre économique et Unité d'observation ». Les trois nomenclatures visées sont **confirmées présentes** dans les métadonnées : `265201` à `265205` (horlogerie), `266000` (NOGA 26.6), `325001` à `325004` (NOGA 32.5). Canton `999` = Suisse.

Deux obstacles : l'extraction des données exige une requête **POST** avec un corps JSON — le connecteur générique actuel n'émet que des GET, il faudra l'étendre ; et la série est **annuelle, dernier millésime 2023**, donc elle ne produira aucun écart entre exécutions rapprochées.

### T3 — Commerce mondial de marchandises (CPB)

Fichier accessible sans condition, mais en **Excel** :
`https://www.cpb.nl/system/files/cpbmedia/cpb-world-trade-monitor-april-2026_0.xlsx`

Deux coûts : un analyseur de classeur est nécessaire, et le nom du fichier change chaque mois avec un suffixe imprévisible — il faut donc gratter la page de publication pour retrouver le lien. Une page d'index stable existerait (`cpb.nl/en/worldtrademonitor/latest`), non testée.

---

## Sources non conclues

### T1 — Indicateur composite avancé (OCDE)

Le point d'accès public est confirmé et répond sans authentification. L'agence est `OECD.SDD.STES`, le flux `DSD_STES@DF_CLI`. Mais **la charge utile n'a jamais pu être lue** — limite d'outillage de la reconnaissance, non indisponibilité de la source. La clé de série pour l'agrégat OCDE et la structure des colonnes restent à confirmer.

**Trente secondes de `curl` sur ta machine trancheront.** Ne pas planifier cet indicateur comme acquis sans cette vérification.

### H3, M1, A4, S6 — UN Comtrade — VÉRIFIÉ le 09.08.2026

**Un accès sans clé subsiste : oui.** Le point `https://comtradeapi.un.org/public/v1/preview/C/A/HS` répond en HTTP 200 sans authentification et livre des données réelles (ex. USA import horlogerie SH 91 : 6,85 Mrd USD en 2022, 7,10 Mrd en 2023 ; Chine export : 4,82 Mrd en 2022). La clé de voûte tient — mais l'offre *preview* impose trois limites dures qui rendent le design actuel des bindings inopérant.

**Limites du point preview, constatées sur pièce :**

1. **`reporterCode=all` → « Invalid parameter value ».** Non supporté (il l'était sur l'endpoint payant `/data/v1/get/`). Il faut interroger **un pays déclarant par requête**.
2. **Une seule période par requête** : `period=2023,2024` → « Maximum number of periods for preview is 1 ». Une année par appel.
3. **Colonnes descriptives toutes nulles** : `reporterISO`, `reporterDesc`, `cmdDesc`, `flowDesc`, `partnerISO` reviennent à `null` ; seuls les **codes** sont peuplés. Le mapping `colonne_geo` doit viser **`reporterCode`** (numérique), non `reporterISO`.
4. **Quota** : HTTP 429 « Rate limit is exceeded. Try again in 2 seconds. » — de l'ordre d'**une requête toutes les 1 à 2 secondes**. Le collecteur générique, qui déclenche les appels sans throttling, dépassera ce quota s'il porte plusieurs liaisons Comtrade.

**Forme d'une requête qui aboutit** : `?reporterCode=<code>&period=<AAAA>&cmdCode=<code SH>&flowCode=M|X&partnerCode=0`. Avec `partnerCode=0` (Monde), elle renvoie **exactement une ligne agrégée** portant `primaryValue` (USD). Structure de réponse : `{elapsedTime, count, data:[…], error}` — `chemin_donnees="data"` reste correct.

**Lacune de données** : le déclarant **Suisse (756) ne renvoie rien** pour 2022 ni 2023 dans le jeu preview (testé en export et en TOTAL), alors que la Chine et les États-Unis répondent. H3, s'il devait reposer sur les exportations horlogères suisses, ne serait pas alimentable par cette voie.

**Conséquence — décision de qualification en attente (revient à l'étudiant).** Le référentiel définit H3, M1, A4, S6 comme « commerce mondial… **par pays** ». Le preview ne permettant ni `all` ni plusieurs périodes, il faut :
- arrêter une **liste de pays déclarants** représentant chaque indicateur (un panier, puisque « tous » est impossible et que la Suisse est absente) ;
- choisir le **sens de flux** (import `M` ou export `X`) porteur de sens par indicateur ;
- adapter le connecteur / le workflow pour **boucler (pays × année)** en **respectant le quota** (throttling), et mapper la zone sur `reporterCode`.

Tant que le panier de pays et le sens de flux ne sont pas fixés, les liaisons restent `a_verifier`. L'accès est acquis ; le design ne l'est pas encore.

**Décision prise le 09.08 (étudiant)** : le sens de flux retenu pour le redesign sera **exportations (`X`)** — mesure de la production vendue et de la compétitivité. Reste à arrêter le panier de pays déclarants par indicateur, en tenant compte de la lacune suisse. Priorité reséquencée : T2/T4 activés d'abord (fait), redesign Comtrade ensuite.

### A3 — Ventes de véhicules électriques (AIE), S4 — Dépenses militaires (SIPRI), H4/M6 — Brevets (OMPI)

Non conclues. À vérifier selon le protocole en trois temps du mode opératoire.

---

## Ce que cela change pour le week-end

Le **socle transversal** peut passer de zéro à deux indicateurs collectés (T2 et T4), tous deux vérifiés. C'est plus important qu'il n'y paraît : il alimente la vue « Contexte » et la question d'attribution QV0, que le rapport décrit depuis longtemps comme existante sans qu'elle le soit — le défaut I-5 de l'évaluation critique. Deux liaisons le referment.

Bilan réaliste des indicateurs instrumentables d'ici mardi : **A5 et S3** (déjà acquis), **T2 et T4** (vérifiés, à activer), **M2** (une décision à prendre), et potentiellement **quatre de plus** si Comtrade s'ouvre sans clé. Soit cinq à neuf indicateurs sur vingt-deux certifiés, couvrant l'automobile, l'aérospatial, le médical et le socle transversal.

L'horlogerie restera le secteur non instrumenté, pour une raison qui s'explique et se défend.
