# Étage 2 — flux, signaux et santé sectorielle : conception

**Statut : conçu le 22.08.2026, non exécuté.** Décision de l'étudiant du 22.08.2026 : levée du gel du 25.08 et priorité à la profondeur pratique — l'exécution du protocole d'exploration OSINT (04.08, jamais exécuté à pleine profondeur) et la construction de l'étage de flux passent devant les livrables de forme. Décision tracée en notes de rédaction, à déclarer au § 7.2.2 et à annoncer au directeur. Ce document porte la conception complète et son raisonnement ; il alimente directement le rapport (§ 10.7 et section de résultats OSINT).

---

## 1. Le diagnostic qui motive l'étage 2

Le dispositif actuel est un **étage structurel** : des séries officielles, mensuelles à annuelles, qui établissent *où en est* chaque marché. Il est nécessaire — un signal faible est par définition un écart à une base, et sans base rien n'est un signal — mais il est **rétrospectif par construction** : la statistique publique constate à un à six mois de latence ce que le terrain a déjà vécu. Le constat de l'étudiant du 22.08 est exact : ce que le tableau de bord ne fait pas, c'est **anticiper** — voir la demande se former (appels d'offres), les stratégies s'annoncer (communications des donneurs d'ordre), les règles se préparer (textes en négociation), le marché réagir (cours), l'activité s'ajuster (embauches).

Ce diagnostic n'invalide pas l'étage 1 : il révèle qu'il manque le second. La théorie de la partie B le disait déjà (cycle de veille, infobésité, signaux faibles) ; le protocole d'exploration OSINT du 04.08 en avait tiré les quatre familles F1–F4 ; la première brique existe depuis le 20.08 (M7, TED médical). L'étage 2 est l'exécution complète de cette intention.

**Décision de structure : on étend, on ne refait pas.** La grille de l'étage 1 est conservée : elle est la base de calcul des écarts, elle porte quinze mille observations auditées, et la refaire détruirait la preuve sans rien apporter à l'anticipation. Le cadre de questions de veille est conservé aussi : les flux ne posent pas de questions nouvelles, ils répondent *plus tôt* aux mêmes questions (QV2 demande, QV4 technologie, QV5 impulsions publiques…) — les rattacher au cadre existant préserve la calculabilité de l'absence, l'argument central du ch. 8. Ce qui change : la grille gagne une **dimension de latence** (indicateur retardé / coïncident / avancé / flux), un **sens favorable déclaré** par indicateur, et l'obligation pour chaque indicateur de nourrir au moins une lecture (santé, tendance ou signal) — critère d'utilité qui répond frontalement à « ils servent à quoi ? ».

## 2. Les deux vitesses

| | Étage 1 — structurel (existant) | Étage 2 — flux (cet ajout) |
|---|---|---|
| Répond à | Où en est le marché ? | Qu'est-ce qui vient de bouger ? |
| Latence | 1 à 6 mois | Heures à jours |
| Unité | Observation de série (`indicator_values`) | Item de flux → événement (`flux_items` → `signals`) |
| Traitement | ETL déterministe, contrôles | Collecte déterministe, **triage IA**, validation humaine |
| Lecture | Tendances, santé sectorielle | Carte de signaux par QV et secteur |

**Place de l'IA — le point doctrinal.** Dans l'étage 2, la collecte reste du code (API, flux structurés) : l'IA n'y a rien à faire. Là où elle devient irremplaçable, c'est le **triage de l'infobésité** : des centaines d'items par semaine, dont quelques-uns méritent les dix minutes du veilleur. Le triage IA (pertinence par rapport aux QV, secteur, résumé d'une ligne) est une tâche **réversible** — un item mal classé se rattrape, contrairement à une valeur fausse en base — donc un modèle unique et économique suffit, conformément au résultat du § 9.4.2 (sur tâches contraintes, les modèles sont équivalents : le coût décide). Le consensus multi-modèles reste réservé à l'extraction d'événements (chaîne `signals` existante), et **la validation reste humaine, nominative et datée** : l'IA propose un ordre de lecture, elle ne décide jamais de ce qui atteint le décideur. Le taux d'erreur du triage se **mesure** (relecture humaine d'un échantillon), il ne se suppose pas — exigence posée par le protocole OSINT (F3, vigilance).

## 3. Les familles de flux, avec leur raccordement

Reprise des familles du protocole du 04.08, complétées de trois familles à flux structuré. Chaque ligne applique la grille des neuf critères du protocole ; les verdicts définitifs se prononcent **sur exécution**, pas ici.

| Famille | Source primaire | Accès | Fraîcheur | QV | Vague |
|---|---|---|---|---|---|
| **F3 — Marchés publics** (entamée : M7) | TED, API de recherche v3 (POST JSON, sans clé — vérifiée le 20.08) ; SIMAP (CH) à instruire | API libre | Quotidien | QV2, QV5 | **A** |
| **F2 — Communications des donneurs d'ordre** | Communiqués et rapports des pivots (Airbus, Boeing, ACEA, FH, Swatch, Richemont, Stryker, Medtronic…) — flux RSS/pages presse | RSS / pages publiques | Quotidien | QV2, QV4 | **A** (flux) ; extraction profonde en **B** |
| **Actualité structurée** (extension F2) | GDELT DOC 2.0 (API libre, monde, 15 min) — requêtes par secteur | API libre | 15 min | Toutes | **A** |
| **Marchés financiers** (nouvelle) | Cours de clôture des donneurs d'ordre cotés — panel par secteur : Swatch UHR/Richemont CFR (H), Stryker SYK/Medtronic MDT (M), VW VOW3/Stellantis STLA (A), Airbus AIR/Safran SAF/Boeing BA (S) | Export CSV libre (source à qualifier : Stooq ou équivalent) | Quotidien | QV1 | **A** |
| **F1 — Registres du commerce** | Zefix (CH) — API à vérifier ; démographie par NACE | API à vérifier | Quotidien | QV1 | **B** |
| **Trafic quotidien** (issue de la vague 3 !) | EUROCONTROL / ansperformance.eu — données quotidiennes ouvertes | Export libre | Quotidien | QV2 (S) | **B** |
| **Brevets en flux** | OPS de l'OEB (publications récentes par CPC) — clé gratuite, quota | API + clé | Hebdo | QV4 | **C** |
| **F4 — Offres d'emploi** | Plateformes d'emploi | CGU restrictives | — | QV1 | **Instruction de l'écartement** (frontière légale — le verdict motivé est le livrable, conformément au protocole) |

Vague **A** = sans clé ni obstacle, exécutable immédiatement. **B** = une vérification d'accès chacune. **C** = clé/quota à obtenir. F4 ne se collecte pas : elle s'instruit sur pièces (CGU) pour la sous-section « frontière légale et déontologique » — l'écartement motivé est un résultat de recherche.

**Web scraping** : légitime uniquement en repli, pour les pages publiques sans flux (communiqués), dans le respect des CGU et de robots.txt, sans données personnelles — le cadre est celui du § OSINT du rapport. Tout ce qui a une API passe par l'API.

## 4. Chaîne de traitement de l'étage 2

```
collecte (code, par famille)            → flux_items      (ajout seul, hash de déduplication, pièce brute E6)
triage IA (1 modèle, JSON contraint)    → flux_triage_ia  (pertinence 0–2 + QV + résumé ; jamais un statut)
examen humain (vue triée par score)     → promotion des items retenus vers la chaîne signals existante
                                          (3 modèles, extraits obligatoires, validation nominative)
restitution                             → carte des signaux par secteur/QV + compteur d'items en attente
```

Ce qui est **mesuré** et rapporté : volume collecté par famille et par semaine, taux de pertinence du triage (échantillon relu), taux de promotion en signal, **valeur d'antériorité** quand elle est constatable (de combien l'item précède la statistique officielle — l'argument décisif de l'étage 2, posé par F2/F3 du protocole).

## 5. Santé sectorielle et critère d'utilité (révision de la grille)

Deux ajouts à l'étage 1, pour répondre à « voir la santé de chaque secteur » :

1. **`sens_favorable`** déclaré par indicateur (+1 hausse favorable, −1 hausse défavorable, 0 non orientable) — déclaration par liaison, même doctrine qu'`admet_negatifs` : une hypothèse de lecture s'écrit, ne se présume pas. La déclaration est un acte de qualification humaine.
2. **`v_sante_secteur`** : score par secteur calculé **par le code** — moyenne des écarts standardisés (z) des dernières valeurs de chaque indicateur orientable contre sa propre base trois ans, orientés par `sens_favorable`. Lecture : > 0 au-dessus de la base, < 0 en dessous ; le détail par indicateur reste à un clic. Aucune IA : c'est un calcul, donc du code.

**Critère d'utilité** : après exécution, tout indicateur de la grille doit nourrir au moins l'une des trois lectures (santé, tendance, base de signal). Ceux qui n'en nourrissent aucune sont **déclassés en « contexte »** — documentés, jamais supprimés (registre en ajout seul) — et le déclassement motivé figure au rapport. C'est la réponse méthodologique à « des indicateurs faciles à trouver qui n'apportent pas grand-chose » : l'utilité se juge à la lecture produite, et elle se juge sur pièces.

## 6. Ce que l'étage 2 change au rapport

- **§ 10.7 (nouveau)** : conception de l'étage de flux (le présent document, condensé).
- **Section de résultats OSINT** (prévue par le protocole du 04.08) : grille des neuf critères remplie par famille, verdicts motivés, frontière légale (F4), valeur d'antériorité mesurée.
- **Reformulation de la contribution** (§ 4 du protocole, à porter en conclusion) : « l'IA rend accessible à une PME une pratique de recherche en sources ouvertes réservée à des spécialistes — et voici précisément jusqu'où ».
- **§ 12.5** : le diagnostic du 22.08 (étage interprétatif mince, dispositif rétrospectif) posé frontalement, avec l'étage 2 comme réponse — dans l'état d'exécution réel au moment du dépôt, sans surdéclaration : ce qui aura tourné au passé, le reste en conception.
- **§ 7.2.2** : la levée du gel du 25.08 rejoint l'inventaire des décisions d'étudiant à ratifier.

## 7. Risque assumé

La levée du gel consomme la marge des semaines 5-6. Le risque est connu et accepté par l'étudiant : si l'exécution de l'étage 2 déborde, ce sont les vagues B et C qui se replient en conception documentée — jamais le dépôt. L'ordre d'exécution (vague A d'abord, mesures immédiates) est construit pour que chaque jour de travail laisse le dossier dans un état déposable.
