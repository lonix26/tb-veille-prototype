
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
