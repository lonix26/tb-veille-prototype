# Reconnaissance des sources — lot 1, 17.08.2026

Reprise du développement décidée le 17.08.2026 (décision N. Castillo : levée de l'arrêt technique du 25.08, calendrier porté par l'étudiant). Objectif du lot 1 : instrumenter les dix indicateurs certifiés à zéro observation.

**État de cette reconnaissance : écrite en session Cowork, SANS accès shell.** Les appels tentés d'ici (AIE, SIPRI : réponse vide ; CPB : cache périmé de 2021) n'ont rien établi. **Aucune URL ci-dessous n'est vérifiée en réponse réelle.** Toute liaison est semée `a_verifier` ; l'activation suit la règle habituelle : réponse réelle vue par l'étudiant, nominative, datée. Règle d'une heure par source maintenue — au-delà, lacune documentée.

Migration associée : `migrations/2026-08-17_bindings_lot1.sql` (A3, M3, S4 uniquement — les autres exigent une évolution de connecteur ou n'ont pas de point d'accès candidat).

---

## Groupe 1 — candidats compatibles avec les connecteurs existants

### A3 — Ventes mondiales de VE (AIE, Global EV Data Explorer)

- **URL candidate** : `https://api.iea.org/evs?parameters=EV%20sales&category=Historical&mode=Cars&csv=true`
- Point d'accès documenté du Global EV Data Explorer, réputé sans clé. Réponse vide depuis Cowork — à retester en terminal :

```bash
curl -s --compressed -A "Mozilla/5.0" "https://api.iea.org/evs?parameters=EV%20sales&category=Historical&mode=Cars&csv=true" | head -20
```

- Relever : colonnes exactes (attendues : region, year, value…), unité, granularité géographique. Filtrer sur les années 2023+ au mapping.
- Connecteur : `csv_generique`. Liaison semée.

### M3 — Dépenses de santé par pays (OMS)

- **URL candidate** : `https://ghoapi.azureedge.net/api/GHED_CHEGDP_SHA2011` (OData JSON, part du PIB). Le code d'indicateur GHO est **à confirmer** — ne pas le tenir pour acquis, lister d'abord :

```bash
curl -s "https://ghoapi.azureedge.net/api/Indicator?\$filter=contains(IndicatorName,'health%20expenditure')" | python3 -m json.tool | head -60
curl -s "https://ghoapi.azureedge.net/api/GHED_CHEGDP_SHA2011?\$filter=TimeDim%20ge%202023" | head -c 800
```

- Structure attendue : liste sous `value`, champs `SpatialDim` (ISO3), `TimeDim`, `NumericValue`. Si le code diffère, corriger `url_base` avant activation.
- Connecteur : `json_generique` (mode liste). Liaison semée avec le code candidat.
- Repli si l'API GHO ne porte pas GHED : fichier Excel GHED (`apps.who.int/nha/database`) — bascule groupe 2 (xlsx).

### S4 — Dépenses militaires (SIPRI)

- `milex.sipri.org` : application interactive, réponse vide depuis Cowork. SIPRI distribue le jeu complet en **xlsx** (page « SIPRI Military Expenditure Database », fichier du type `SIPRI-Milex-data-…xlsx`, nom exact à relever sur la page). Pas de CSV direct connu.
- **Vérifier d'abord s'il existe un export CSV** ; sinon S4 bascule au groupe 2 (xlsx). Liaison semée `a_verifier` avec URL de la page comme repère, note explicite « format à confirmer ».
- Périmètre au mapping : mia USD courants, années 2023+, pays du panier (à restreindre pour ne pas ingérer 170 pays sans besoin).

---

## Groupe 2 — évolutions de connecteur requises (à faire en session terminal)

Trois besoins, chacun petit, à implémenter dans `collecte_generique.json` sur le modèle des modes existants :

1. **`http_post`** (H2, M4 — OFS PX-Web). La reconnaissance du 07.08 a déjà confirmé la table `px-x-0602010000_103` et les nomenclatures (`265201`–`265205`, `266000`, `325001`–`325004`). Extraction en POST avec corps JSON. Point d'accès : `https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px`. Série annuelle arrêtée à 2023 — le dire au mapping (`periode_max`), et au rapport (fraîcheur STATENT). Corps de requête à construire après `GET …/api/v1/fr/px-x-0602010000_103` (métadonnées).
2. **`xlsx`** (T3 CPB ; S4 si pas de CSV ; repli M3). Lecture d'un classeur via SheetJS en nœud Code n8n — pas de dépendance nouvelle si la bibliothèque est déjà disponible dans l'image ; sinon, conversion en amont par un nœud dédié. À trancher en terminal.
3. **`page_index`** (T3 CPB). Le nom du fichier change chaque mois : lire la page `https://www.cpb.nl/en/worldtrademonitor`, extraire le premier lien `*.xlsx` correspondant à « World Trade Monitor », puis le télécharger. Deux étapes, un nœud Code. La page servie à Cowork était un cache de 2021 : vérifier la structure réelle en terminal avant d'écrire l'extraction.

Aucune liaison semée pour ces quatre indicateurs tant que le connecteur n'existe pas — une liaison qui référence un connecteur absent serait une surdéclaration en base.

---

## Groupe 3 — pas de point d'accès structuré connu

### H4 / M6 — Brevets (OMPI)

Le Data Center OMPI (`www3.wipo.int/ipstats`) est interactif ; l'export CSV passe par l'interface. Vérifier en terminal s'il expose des requêtes GET construisibles (observer l'URL d'export depuis le navigateur). Une heure maximum. Sinon : **dépôt manuel annuel** — un CSV exporté à la main, déposé dans un répertoire surveillé par n8n, reste conforme au scénario B (l'acte humain est la sélection, la chaîne reste tracée) ; à documenter comme mode de collecte « semi-automatisé » assumé, distinct d'une lacune.

### A1 — Production mondiale (OICA) · S1 — Commandes/livraisons (Airbus, Boeing)

Tableaux HTML (OICA) et pages investisseurs (Airbus/Boeing). Pas d'API connue. Options par ordre de préférence, décision à l'étudiant :

1. OICA publie des tableaux HTML réguliers → extraction table HTML (variante de `page_index`), fragile mais annuelle donc supportable.
2. S1 : les communiqués mensuels Airbus/Boeing sont des documents non structurés → candidats naturels au **pipeline composite** (chaîne A2), pas au connecteur hard. Requalifier S1 hard → composite serait cohérent avec la règle « les chiffres par le code, les mots par l'IA » quand il n'y a pas de chiffre accessible au code. **Décision de qualification, pas technique — à trancher explicitement et à tracer** (le décompte 21 hard / 1 composite changerait : signalé, pas décidé ici).

---

## Ordre d'exécution conseillé en session terminal

1. Groupe 1 : trois `curl`, activation de ce qui répond (A3, M3, S4) — une heure chacun max.
2. `http_post` pour H2/M4 — la reconnaissance amont est déjà faite, c'est le gain le plus sûr.
3. T3 (`page_index` + xlsx) — indicateur du socle QV0, il porte l'indicateur synthétique du lot 4 (ratio sur commerce mondial) : **prioritaire dans le groupe 2**.
4. OMPI (1 h max), puis A1/S1 selon décision de qualification.

Chaque activation : sortie conservée en `annexe_5/`, note nominative datée dans la liaison.
