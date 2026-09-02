
---

## 26.08.2026 — Filtrage à seuil de la file d'examen

**Le défaut corrigé.** Le triage IA ordonnait la file sans jamais la réduire : 926 items en
attente d'examen humain pour 37 examens rendus. Le goulot du semi-automatisé n'est pas la
collecte, c'est la validation.

**Ce qui a été semé** (`migrations/2026-08-26_filtrage_a_seuil.sql`, appliquée) :

| Objet | Rôle |
|---|---|
| `flux_filtrage_regles` | La règle, son énoncé en français, son seuil, **son fondement limite comprise** |
| `flux_filtrage` | Ce qu'elle a écarté — **en ajout seul** (`trg_filtrage_ajout_seul`, D-18) |
| `flux_filtrage_audit` | Les verdicts humains sur l'échantillon mensuel |
| `appliquer_filtrage_flux()` | Application idempotente ; appelée par le workflow de triage |
| `v_flux_a_examiner` | Redéfinie : exclut le filtré, **sauf faux négatif reconnu à l'audit** |
| `v_filtrage_echantillon` | Tirage reproductible (sel mensuel), dix items |
| `v_bilan_filtrage` | Le bilan, taux de faux négatifs compris — « inconnu » tant qu'aucun audit |

**Règle `seuil_v1`** : note (antériorité + portée + pertinence, doctrine `signal`) < 3 ⇒ écarté,
**sauf antériorité = 2**. Garde-fou vérifié sur pièce : 19 items faiblement notés portent une
antériorité maximale, aucun n'a été filtré.

**Effet mesuré** : 689 écartés (74,4 % du triable), file **926 → 237**. Second appel de la
fonction : 0 (idempotence vérifiée). Suppression dans `flux_filtrage` : refusée par le
déclencheur (vérifié). Restitution d'un faux négatif : testée en transaction annulée, l'item
revient bien dans la file.

**Portage.** Nœud « Appliquer le filtrage a seuil » ajouté à `triage_ia_flux.json` entre
l'écriture des scores et la clôture du run ; la note de clôture mentionne désormais le nombre
d'items écartés. Sauvegardes : `*.avant_filtrage_2026-08-26`.

**Restitution.** `veille/sante` expose `filtrage`, `filtrage_regle`, `filtrage_echantillon`.
Nouvel onglet « Le filtrage » dans l'écran Fiabilité ; la réserve « la file ne se vide pas » est
remplacée par « le filtrage automatique n'a jamais été audité » (gravité grave, levée
automatiquement tant que `items_audites = 0`).

**Ce qui reste à faire, et qui n'est pas cosmétique.** L'audit n'a jamais été exercé : le taux
de faux négatifs est **inconnu**. Relire les dix items de `v_filtrage_echantillon` et inscrire
les verdicts dans `flux_filtrage_audit` transformerait une limite en résultat. C'est
probablement le meilleur rapport valeur/temps qui reste avant le dépôt.

**Pièges rencontrés, à ne pas réapprendre.**
- Le chemin des webhooks de l'API est `veille/<vue>`, **pas** `v4/<vue>`.
- `n8n import:workflow` **désactive** le workflow. Il faut ensuite
  `n8n publish:workflow --id=<id>` **puis redémarrer le conteneur** — `update:workflow` est
  déprécié en 2.20 et ne suffit pas seul.
- `~/.n8n/database.sqlite` fait **1,1 Go** (historique d'exécutions). Un `grep` sur le fichier
  principal ne trouve rien tant que les écritures sont dans le `-wal`. À purger avant de figer.
- `dashboard-app/verification/rendu.jsx` ne visitait que l'onglet par défaut de Fiabilité.
  Corrigé : `Fiabilite` accepte `vueInitiale`, et les sept onglets sont désormais rendus.

## 26.08.2026 — `description_metier` scindée : le lecteur d'un côté, le journal de décisions de l'autre

**Le défaut.** Le champ s'était chargé de deux textes de natures différentes. Le premier
explique l'indicateur à qui le lit. Le second est un **journal de décisions** — « RETIRÉ DU
SCORE le 24.08.2026 : corrélation des résidus de 0,910 », « seuil de matérialité nul à dessein
(RI4 inapplicable) », « [HORS VITRINE le 25.08.2026 — …] ». Le second était affiché sur les
écrans de décision, entre le titre d'un indicateur et sa valeur : jusqu'à **1 572 caractères**
de prose méthodologique (M6), 1 273 sur A7.

Le symptôme était déjà dans le code : `Marche.jsx` coupait la chaîne à `" [HORS VITRINE"` pour
ne pas l'afficher. Rustine d'affichage sur un défaut de modèle — retirée.

**Le choix : séparer, pas supprimer.** Effacer le journal contredirait la thèse du travail.
Nouvelle colonne `indicators.note_conception`, avec `COMMENT ON COLUMN` sur les deux champs pour
que la frontière ne se redissolve pas. Migration `2026-08-26_description_lecteur.sql`, rédigée
indicateur par indicateur — **aucun contenu inventé**, découpage et réécriture à sens constant.

| | Avant | Après |
|---|---|---|
| Longueur moyenne | 401 car. | **222 car.** |
| Maximum | 1 572 car. | **483 car.** |
| Descriptions portant de la prose de rapport | 24 / 46 | **0** |
| Journaux conservés en base | — | 23 |

Les ouvertures en capitales sont démajusculées (« CE QUI RECOMPOSE LA DEMANDE DE COMPOSANTS »
→ « Ce qui recompose la demande de composants »). Les capitales d'insistance ne survivent que là
où elles portent une consigne de lecture — T8 et T10 : « se lit en POINTS, jamais en
pourcentage ».

**Vérifié avant de retirer** : le workflow `analyse_tendances_alertes` nourrit le modèle avec
`description_metier`. La phrase supprimée (« interdit au modèle de commenter la variation »)
n'était pas le garde-fou : celui-ci est structurel — `alert_threshold_pct` est **nul** sur A7,
M6, T8 et T10, et RI4 est appliquée par la consigne du workflow. La consigne de lecture utile
(lire en points, pas en pourcentage) est conservée côté lecteur.

**Où le journal reparaît** : onglet « La grille » de l'écran Fiabilité, servi par
`veille/donnees`. Rien n'est perdu, rien ne s'affiche là où cela gênait.

## 01.09.2026 (suite 3) — Événements : un commentaire affirmait un contrôle non implémenté

En relisant `extraction_evenements_flux` nœud par nœud pour l'expliquer, constat : l'en-tête du
nœud « Contrôles et mise en forme » affirmait qu'« un resume porteur de chiffres absents du titre
est signalé (incident) ». **Le code ne le fait pas** — la règle des chiffres n'existe que dans la
consigne au modèle ; les contrôles déterministes portent sur le JSON, l'admission des `item_id`,
`est_evenement` et le vocabulaire fermé, rien d'autre. C'est le cas visé par la règle
« un commentaire qui affirme un contrôle non implémenté est la même faute qu'une phrase
surdéclarée ».

Correction retenue : **le commentaire dit désormais ce qui est vrai** (règle portée par la
consigne, aucun contrôle déterministe, date du constat). Le contrôle lui-même — extraction des
nombres du résumé et du titre, compteur `chiffres_hors_titre` au bilan — est noté en
perspective, pas implémenté : le gel est fait, le rapport est le chemin critique. Workflow
réimporté dans n8n (il est inactif par nature, appelé en fin de chaîne : aucun `publish` requis).

État de la table relu à cette occasion, à citer tel quel : **690 événements, 690 `non_relu`,
0 validé, 0 rejeté** ; modèle unique `gemini-3.7-flash` ; type « autre » = 273 (40 %), exclu
de l'écran par `evenements_recents`. La validation humaine est possible par construction et
n'a jamais été exercée.

## 01.09.2026 (suite 4) — Éligibilité des sources à la lecture événementielle

**Constat** (question de l'étudiant : « quelles sources, quels critères ? »). Il n'existait
aucun critère d'éligibilité de source propre aux événements : `extraction_evenements_flux`
lisait tout item pertinent porteur d'un secteur. Décompte des 690 événements par famille :
TED 287 (42 %, dont 183 « autre » et 103 « investissement » — des appels d'offres relus comme
des investissements), GDELT 159, presse/communiqués 150, FDA 94 (chaque 510(k) devenue un
événement alors que M8 les compte déjà). La consigne commence par « Tu lis des titres
d'articles de presse professionnelle » : écrite pour la presse, appliquée à des
enregistrements structurés.

**Règle de détection, aux trois conditions** (migration
`2026-09-01_eligibilite_lecture_evenementielle.sql`, sortie en annexe 5) :
- déclarée : `flux_sources.lecture_evenementielle` (défaut `false`, COMMENT), vrai pour les
  13 flux presse/communiqués/actualité, faux pour TED et FDA avec motif ajouté à `note` ;
- visible : lue par la requête du workflow (`AND s.lecture_evenementielle`), par
  `v_evenements_mois` et par `evenements_recents` dans l'API ;
- conservatrice : les 381 événements TED/FDA restent au registre (preuve du constat), ils ne
  sont plus servis. TED/FDA restent collectés, triés, comptés (M7/M8/S7), en file d'examen.

**Après** : 309 événements éligibles (90 « autre », 36 « investissement ») ; API vérifiée
(`veille/donnees` : 120 récents, 302 sur 60 jours, aucun TED/FDA) ; captures régénérées ;
`db/` reconsolidé et vérifié par base neuve (empreintes identiques, 51 indicateurs). Workflows
réimportés, API republiée, conteneur redémarré.

**Constat annexe, non traité** : les items jugés `est_evenement:false` ne sont pas écrits, donc
**relus à chaque run** (161 items éligibles en attente au 01.09, dont ceux déjà lus par le run
193 puis 208). Coût marginal à cette échelle (4 lots), mais c'est une lecture payée deux fois —
perspective : écrire les non-événements (statut `non_evenement`) pour que le filtre
`e.evenement_id IS NULL` les exclue.

**Critères de sélection des sources, pour mémoire** (déjà en base et au § 8.9) : grille des
neuf critères du protocole OSINT ; pour la presse, deux tris (exploitable en réponse réelle,
puis utile : parle de l'étage adressable, non recouverte), deux fils par marché ; 21 testés,
8 retenus le 26.08 ; écartés motivés dans `flux_sources.note`. À dire honnêtement au rapport :
la reconnaissance a porté sur des fils connus et testés, pas sur un recensement exhaustif.

## 01.09.2026 (suite 5) — Le lien vers l'article, absent de l'écran des événements

Question de l'étudiant sur capture : « je n'ai aucun moyen de remonter à la source pour lire
l'article ». Exact : l'API servait déjà `titre` et `url` de l'item (`evenements_recents`),
le composant `Evenements` de `Secteur.jsx` ne les affichait pas — et sa note disait « chaque
événement reste rattaché à son article source ». Vrai en base, faux à l'écran : même famille
de défaut que le commentaire du nœud de contrôles (suite 3). Corrigé : titre de l'article en
lien (nouvel onglet), domaine de la source ; note réécrite (« lecture sur le titre seul ; le
résumé est celui du modèle, l'article lié est la source et fait foi »). 309/309 événements
éligibles ont une URL. Reconstruit, captures régénérées.

---

## 02.09.2026 — Tour complet « jury » et plan de correction A1

Six examens indépendants (base, workflows, application, documentation, chaîne IA, données) : 3
bloquants, 55 majeurs, 56 mineurs, 18 remarques — synthèse et rapports dans
`../evaluation_critique_prototype_2026-09-02.md` (racine, hors dépôt). Le plan de correction y
figure au § 5 ; les corrections du prototype (liste A) sont exécutées dans l'ordre, une entrée
ici par item.

**A1 — la doctrine de diffusion écrite est celle d'avant le 31.08 (B-1).** Deux notes de
`api_restitution.json` (« la doctrine v4 interdit d'afficher du non validé », « rien de non
validé à l'écran ») et l'onglet Méthode de l'application (« n'atteignent l'écran qu'après
relecture humaine ») contredisaient le nœud d'à côté, qui sert `a_valider`. Pire : les 82
actions TED viennent de `ted_lecture_ia`, table sans colonne de statut — la validation n'y était
pas « non exercée », elle était impossible.

- Migration `2026-09-02_a1_statut_lecture_ted.sql` (sortie en annexe 5) : `statut` (défaut
  `non_relu`, jamais modifié par un workflow), `valide_par`, `valide_le`, contrainte de
  traçabilité ; `v_actions` recréée (DROP/CREATE, aucune dépendance) avec `lecture_statut` et
  `lecture_valide_par`. État : 324 lectures `non_relu`, 78 servies.
- API : les trois notes réécrites au régime réel (« servi avec son statut, badgé ») ; le filtre
  `valide` est **maintenu** sur les signaux (régime propre à la table) et sur l'attribution
  ancrée (variante expérimentale) — mais présenté comme tel, pas comme règle générale.
- Application : fiche d'action badgée « lecture par un modèle, non relue » et raisonnement
  explicite (« aucun humain ne l'a relue ») ; onglet Méthode réécrit ; note du tamis complétée.
- `CLAUDE.md` : phrase « seuls les validés sont servis » remplacée par le régime du 31.08.
- Reste au rapport (§ 5.C.1 de l'évaluation) : C4 l. 94 et § 12.5, inventaire § 7.2.2.

## 02.09.2026 (suite) — A2 : le déploiement décrit doit être celui qui marche

**A2 — `DEPLOIEMENT.md` omettait ce qu'un clone neuf ne peut pas deviner, et cinq fichiers de
workflows ne portaient pas l'identifiant de l'instance (B-2, B-3 du tour « jury »).**

- **Pièce d'audit avant réimport.** La version d'`extraction_composite_A2` en service
  (`updatedAt 2026-08-17T13:45:15`, celle qui a produit les runs 51-58) ne correspondait à
  **aucun commit** : sept nœuds diffèrent même de `8f69aa0`. Les correctifs du 17.08 n'avaient
  jamais été importés, et le fichier corrigé n'a produit aucun run. Elle est exportée telle quelle
  dans `n8n_workflows/archive/extraction_composite_A2_en_service_2026-08-17.json` (README à côté ;
  dossier hors boucle d'import par construction, la boucle prenant `n8n_workflows/*.json`).
- **Identifiants alignés sur l'instance**, pas l'inverse — la CLI n8n ne supprime pas de
  workflow et l'historique d'exécution est attaché à l'identifiant : `extraction_composite_A2`
  → `0ay3mDuTGTSporSW`, `extraction_composite_A1_ccfa` → `QSCRx2ogbAts5eVZ`,
  `extraction_composite_CP` → `PNd16YrFSehKUDIR`, `extraction_signal_qualitatif` →
  `VoDfbXcbAS4JoNxf`, `collecte_a5_eurostat_pilote` → `wI6EHIFdDk4lMpKl`. Les cinq réimportés :
  toujours 21 workflows dans l'instance (aucun doublon) ; A2 comparée nœud par nœud entre le
  fichier et l'instance après import : 0 différence.
- **`DEPLOIEMENT.md` réécrit** aux endroits faux ou muets : § 1 en trois sous-sections (`.env`
  du compose avec `cp .env.example .env` et `mkdir -p data/staging` ; fichier de clés avec les
  **neuf** variables lues par les workflows et ce que chacune conditionne ; les **deux
  *credentials*** n8n par identifiant, `QdVRYX9pjTj9C8G3` Postgres dans 23 fichiers et
  `comtradeKeyCred1` pour A4/H1/H3/M1/S6 — voie testée : création à l'interface puis `sed` ;
  voie `import:credentials` signalée **non testée**, faute d'instance vierge). § 2 : 8 fonctions
  propres, pas 44 (36 sont celles de `pgcrypto`). § 3 : `npm ci` justifié par le verrou, sept
  écrans (dix-sept rendus par onglet et par secteur) et non huit, Node non épinglé (v24.19.0 sur le poste). § 4 : import par le
  volume `/workflows` en lecture seule, `publish:workflow` à la place d'`update:workflow
  --active` (procédure réellement employée), et l'écart 26 fichiers / 21 importés nommé —
  renvoyé à A9. § 5 : « 30 indicateurs » remplacé par un renvoi à `v_bindings_actifs`. § 6
  recalculé par requête : certifiés sans liaison = **cinq** (A1, A2, **H2** requalifié composite
  le 30.08, H4, S1) ; fenêtre figée = **31 lignes par construction** (A3 ×15, A11 ×16, un
  millésime IEA chacune) une fois exclus les faux positifs `"filter": "top"` de M4 (142) et H12
  (144) ; fraîcheur = A2, T12, T13 ; `en_grille` = en vitrine (38), non « certifiés + à confirmer »
  (51). Acte humain 2 mis au régime du 31.08.
- `.env.example` : ne prétend plus que les clés vivent « dans n8n » ni que la collecte hard data
  « n'en requiert aucune » (Comtrade en exige une) ; documente `CLES_API_FICHIER` et le contenu
  attendu du fichier de clés. `README.md` : « Docker et rien d'autre » corrigé.
- **Non fait, et dit** : aucune reconstruction sur poste vierge n'a été rejouée pour valider la
  séquence de bout en bout ; ce que le document affirme comme vérifié l'est sur l'instance en
  service (import, publication, requêtes), pas sur un clone neuf.

## 02.09.2026 (suite 2) — A3 : le motif d'une décision humaine est une colonne

**A3 — aucune table de décision n'avait de colonne `motif`, et un rejet pouvait rester anonyme
(B-2).** Migration `2026-09-02_a3_motif_des_decisions.sql`, sortie en annexe 5.

- `motif text` sur `validation_queue`, `composite_queue`, `commentaries`. Contraintes : un rejet
  de la file exige un motif (`chk_vq_rejet_motive`, l'auteur étant déjà exigé) ; un document
  écarté exige motif, auteur et date (`chk_cq_ecart_motive`) ; un commentaire rejeté exige
  auteur, date et motif (`chk_commentaire_rejet_trace`) — celle-ci posée **`NOT VALID`** : elle
  s'applique à toute ligne écrite ou modifiée désormais, pas aux cinq rejets du run 101, qui
  n'ont ni migration, ni auteur, ni date, et que la migration n'invente pas (motif « AUCUNE
  TRACE »). Les rejets restent sans auteur : 30 lignes, dont 25 `a_valider` (normal) et ces 5.
- Motifs rapatriés **sur pièces seulement** : fournée 1 (run 69) — chaque motif vérifié dans le
  texte du commentaire (`5 points` → calcul dérivé ; `non document` → affirmation contredite ;
  `114,57` → arrondi) ; run 70 — fournée intermédiaire obsolète (C4 § 11.6) ; runs 95 et 108 —
  motif et auteur pris dans les en-têtes des migrations du 24.08, date à la précision du jour ;
  24 lignes dont l'auteur portait le motif entre parenthèses (« archive de modele erronee »,
  « donnees superseded ») — motif déplacé, auteur ramené à `N. Castillo` ; file de validation —
  items 1-3 (A2 2025-11, consensus 0, trois valeurs nulles) et 24-25 (H2/H11 run 168, mêmes
  valeurs que 16-17 acceptés) ; `composite_queue` doc 1 — auteur et date pris dans sa `note`.
- État : 38/38 rejets de commentaires motivés (33 avec auteur), 5/5 rejets de file motivés,
  1/1 écart motivé.
- **Reste, hors A3** : le motif n'est pas encore exposé par l'API ni par l'écran ; `signals`
  et `flux_evenements` n'ont pas été traités (hors périmètre du plan). Les mentions
  « N. Castillo (délégation du JJ.MM.2026) » dans `verifie_par` (liaisons, `composite_queue`
  9-11) ne sont **pas** de ce défaut : elles sont voulues et justifiées dans la migration du
  25.08 — l'acte a été délégué en session terminal et le champ le dit en toutes lettres.

## 02.09.2026 (suite 3) — A4 : deux observations fausses ou doublées passent à `rejete`

**A4 — M3 WORLD run 33 (valeur de l'Éthiopie sous la zone monde) et A2 2025-11 run 30 (même
validation rejouée) étaient servies sans marque (DATA-5, DATA-10).** Migration
`2026-09-02_a4_rejets_du_registre.sql`, sortie en annexe 5.

- Le registre est en ajout seul (D-18, déclencheur `trg_registre_ajout_seul`) et le statut
  `rejete`, prévu par les contraintes, n'était atteignable par aucun chemin pour une ligne déjà
  écrite. **Le déclencheur admet désormais une transition, et une seule** : `validation_status`
  → `rejete` avec `rejet_motif` (colonne ajoutée), `validated_by` et `validated_at`, toutes les
  autres colonnes devant rester identiques (comparées une à une dans le déclencheur). Trois
  contrôles rejoués dans la migration : modification de valeur refusée, suppression refusée,
  rejet sans motif refusé. **Tension signalée** : D-18 est précisée, non révisée — décision
  d'étudiant du 02.09.2026, à inscrire à l'inventaire § 7.2.2.
- Rejetés : `value_id` 4249 (M3 WORLD run 33, 2,803 = ETH, première ligne du brut ; valeur
  mondiale 6,828 portée par les runs 34 → 209) et 3400 (A2 2025-11 run 30, rejeu à 50 min de la
  validation du run 29 ; la période reste portée par 3399). `v_current` sert M3 WORLD 2023 =
  6,828 (run 209) et une seule ligne A2 2025-11 (run 29, 887 491) — vérifié.
- Le mappage géographique GHO, second correctif proposé par DATA-5, était **déjà corrigé le
  17.08** (note de la liaison 25, `SpatialDim`) : rien à faire.
- Non traité, et dit : les 1 077 valeurs « écartées par contrôles qualité » du run 209 (BD-5)
  n'ont jamais été écrites ; leur persistance ligne à ligne reste une perspective (liste D).

## 02.09.2026 (suite 4) — A5 : un fichier brut par liaison, et le run sur chaque item de flux

**A5 — le brut du collecteur générique était nommé `{indicateur}_run{run}.raw` : pour un
indicateur à plusieurs liaisons, chaque appel écrasait le précédent (H1 run 209 : 5 839
observations citaient un fichier qui ne contenait que 2024) ; et `flux_items.run_id` était NULL
sur 1 407 lignes (§ 3.1 de l'évaluation).**

- `collecte_generique` (« Préparer les appels ») et `collecte_xlsx_indexe` (« Résoudre le lien
  du classeur ») : suffixe `_b{binding_id}` — `H1_run212_b20.raw`. `collecte_flux` (« Normaliser
  les items », « Écrire les items ») : `run_id` porté par chaque item et inséré.
- Réimportés (21 workflows, aucun doublon) et **exécutés** : run 211 (`collecte_flux`, 8 items
  nouveaux, tous avec `run_id = 211`) ; run 212 (`collecte_generique`, `ok`, 9 583
  observations sur 31 indicateurs, 1 077 écartées) — 98 fichiers `*_run212_b*.raw` déposés ;
  H1 cite désormais quatre fichiers distincts (b20 : 1 652 obs, b21 : 1 608, b22 : 1 610,
  b23 : 969), A3 douze, A11 treize (trois liaisons sans observation ce jour).
- Les fichiers antérieurs gardent leur nom : pour un run < 212, un `raw_ref` d'indicateur
  multi-liaisons ne désigne que la dernière réponse écrite — ce que le rapport doit dire
  (§ 12.5, liste C). Non traité ici : dépôt d'un fichier brut pour les flux et les avis TED
  (`raw_ref = 'run N · flux'`), A1 et CP qui citent une URL distante, la couche 0 sans run —
  E6 reste **tenue pour les hard data, A2 et le signal ; non tenue ailleurs**.

## 02.09.2026 (suite 5) — A6 : six corrections d'interface (UI-1, 2, 4, 5, 6, 9)

- **UI-1** `Secteur.jsx`, bandeau de lecture : « Sur un an : n en progression » était calculé
  sur la *première* métrique servie par indicateur (Aruba pour H1, Afghanistan pour M3).
  Désormais sur `geo_reference` du référentiel ; un indicateur sans métrique sur cette zone est
  compté à part (« 1 sans glissement annuel sur cette zone »). Horlogerie : 6 / 1 / 1.
- **UI-2** « variation rare pour cette série (moins d'une fois sur dix) » → « dépasse le seuil de
  l'indicateur, calibré sur l'ensemble de ses zones (p90 de l'historique) » ; note de bas de
  section corrigée dans le même sens (le seuil n'est pas calibré zone par zone).
- **UI-4** `Anticiper.jsx` : `sens ?? 1 || 1` comptait les sens nuls comme favorables. Les cinq
  indicateurs sans sens déclaré (S9, A10, A9, H10, H9) sont exclus et nommés ; verdict passé de
  « 19 des 26 » à **« Seize des 21 »**, avec les non-comptés énoncés.
- **UI-5** `Fiabilite.jsx`, échantillon d'audit : `<LienSource url= libelle=>` appelait une
  signature `{href, children, titre}` — dix « source non enregistrée ». Corrigé : 9 liens, 1
  item réellement sans URL.
- **UI-6** bannière « chacune est recalculée à l'affichage » et « aucun chiffre de cet écran
  n'est écrit à la main » retirées ; les récits de l'élagage (25.08) et du filtrage (24.08)
  sont **datés comme récits**, et l'onglet Élagage affiche l'état courant calculé
  (`en_grille` / `total` du bilan). « Zéro faux négatif sur dix items audités » est passé au
  conditionnel : l'audit n'a pas eu lieu.
- **UI-9** `Referentiel.jsx` : « officielle » (41 occurrences, faux pour H7/H8/H9, S1) → « hard
  (par code) » / « composite », comme l'en-tête « Catégorie » le disait déjà.
- Build refait ; `verification/executer.sh` : 17 rendus sans exception. Captures pour les
  figures du rapport **non régénérées** (à faire une fois la liste A close).
