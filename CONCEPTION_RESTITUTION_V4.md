# Restitution v4 — le tableau de bord organisé par décisions

**Statut : conception VALIDÉE par l'étudiant le 23.08.2026, implémentation à faire.** Proposition de l'assistant à la demande de l'étudiant (« propose le tableau de bord que tu aurais fait »), validée telle quelle. Note d'actualisation : depuis la rédaction, le triage a gagné la doctrine « signal » à trois axes (pertinence, antériorité, portée — `triage_ia_flux.py`) ; l'écran 3 (Radar) utilise ces trois axes directement quand ils existent, la portée du validateur en repli. Révision de la restitution v3 (application React/Vite/ECharts existante) : **aucune donnée nouvelle, aucune table nouvelle** — une réorganisation des vues autour des questions du décideur. La doctrine est inchangée : rien n'atteint l'écran sans statut de validation, chaque affirmation est cliquable jusqu'à sa source (E6 comme principe d'interface).

**Le renversement.** La v3 est construite de bas en haut : des données, puis des graphiques pour les montrer. La v4 est construite de haut en bas : quatre questions de dirigeant, et les données comme preuves. La courbe devient pièce justificative ; la réponse devient le titre.

---

## Écran 1 — « Cette semaine » (ouverture)

*Question : dois-je m'inquiéter, et de quoi ?* — Zéro graphique sur cet écran.

| Zone | Contenu | Source (existante) |
|---|---|---|
| 4 tuiles secteur | Score de santé + flèche (écart au run précédent) + « n indicateurs » affiché ; si < 2 orientables : **« base insuffisante »** en toutes lettres | `v_sante_secteur` |
| Une phrase par secteur | Le commentaire exécutif **validé** le plus récent, tronqué à une phrase, badge de statut | `commentaries` (statut validé seulement) |
| « Ce qui a bougé » | Les signaux **validés** des 14 derniers jours, triés par portée puis antériorité, avec échéance et lien source | `v_signaux` |
| « Seuils franchis » | Alertes actives | `alerts` |
| Compteur discret | « n items en attente d'examen » — jamais leur contenu (analogue RI5 : le non-validé ne s'affiche pas, il se compte) | `v_flux_a_examiner` (COUNT) |
| **Zone « Transversal »** (ajout du 23.08, validé) | Les facteurs qui touchent **plusieurs secteurs à la fois**, affichés une seule fois en tête plutôt que répétés dans chaque tuile : signaux validés à secteur multiple ou nul (socle QV0), et indicateurs transversaux (T) en franchissement de seuil. Motif : un même facteur à fort impact dans trois secteurs sur quatre est une priorité de direction, pas quatre alertes noyées — le cas d'école du corpus est la décision tarifaire américaine. | `v_signaux` (sector_code NULL ou multiple), `alerts` sur indicateurs T |
| Pied de page | Date et numéro du dernier run, fraîcheur du point le plus ancien | `runs` |

## Écran 2 — Secteur : la question avant la courbe

*Question : où en est ce marché — et comment le sait-on ?*

Pour chaque secteur, les **questions de veille sont les titres de sections**, dans l'ordre QV1→QV5, chaque section contenant :

1. **La formulation sectorielle de la question** (existante : `sector_watch_questions`) — c'est elle le titre, pas « QV2 ».
2. **La réponse en une phrase** : commentaire exécutif validé du secteur, partie afférente à la QV quand elle existe, sinon la tendance calculée énoncée par gabarit déterministe (v2) — jamais de texte non validé.
3. **Les preuves** : les courbes des indicateurs rattachés à la QV (`indicator_watch_questions`), avec badge de fiabilité, statut, source et date — présentation actuelle de la v3, déplacée sous la réponse.
4. **Les signaux rattachés à la QV** : liste courte, mêlée aux preuves — un signal validé est une preuve au même titre qu'une courbe.
5. Si la QV n'a ni indicateur ni signal : la section s'affiche quand même, avec **« non couvert »** — c'est la calculabilité de l'absence rendue visible (`v_couverture_qv` ; correction du 23.08 : la table `lacunes` citée initialement n'existe pas, la vue fait foi).

## Écran 3 — « Radar » (anticipation)

*Question : qu'est-ce qui arrive, et quand le saura-t-on ?*

Ligne de temps horizontale des **signaux validés**, tous secteurs, positionnés par échéance (`signals.echeance`), avec :

- couleur = secteur ; taille = portée (axe du triage-signal quand disponible, sinon jugement du validateur en `note_validation`) ;
- au clic : événement, acteur, zone, extraits par modèle, score de recoupement, lien vers le document source, nom et date du validateur ;
- **le rattachement de confirmation** : l'indicateur de l'étage 1 qui confirmera ou infirmera le signal (déductible du couple secteur×QV : les indicateurs de la même QV). Quand une statistique ultérieure confirme un signal antérieur, le lien s'affiche — c'est la **valeur d'antériorité rendue visible**, l'argument central de l'étage 2 ;
- filtre par statut : « à confirmer » / « confirmé » / « infirmé » (le statut de confirmation est un jugement humain saisi en `note_validation` — pas de champ nouveau pour la v4, convention de saisie documentée).

## Écran 4 — « Opportunités »

*Question : où prospecter cette semaine ?* — La réponse à l'objectif de la séance n° 1 (« identifier de nouvelles opportunités commerciales »).

Tableau des items **promus** issus des marchés publics : titre de l'avis, acheteur, date de publication, lien TED direct, secteur, note d'examen. Source : `flux_examens` (decision `promu_signal` ou `contexte`) joint à `flux_items` où famille = marches_publics. Tri par date de publication décroissante. Mention permanente : « source : TED, avis publics ; sélection triée par IA, examinée humainement » — l'honnêteté du pipeline comme argument commercial.

---

## Règles d'implémentation

1. **Aucune donnée codée en dur** — la v3 le garantit déjà, la v4 en hérite (base coupée : la page le dit).
2. **Rien de non validé à l'écran** en dehors des compteurs. Les scores de triage IA ne s'affichent jamais comme des faits — ils ordonnent la file d'examen, qui n'est pas une vue de décideur.
3. Chaque bloc porte son lien « voir la source » : URL de l'avis, du document, de la série — E6 en pixel.
4. L'API de restitution existante s'étend de trois points de lecture (santé, signaux, opportunités) — lecture seule, mêmes principes que les points actuels.
5. Capture de chaque écran pour le ch. 11 après implémentation ; la v3 reste dans l'historique de l'application (itération documentée au § 12.2 — la v4 est la **quatrième itération tranchée sur constat d'usage**, et le constat est celui de l'étudiant du 22-23.08 : « des courbes, pas des réponses »).

## Ce que la v4 apporte au rapport

- § 12.2 : quatrième itération de restitution, motivée par le constat d'usage de l'étudiant — la série des quatre itérations (gabarits → interactif → application → décisionnel) est en soi un résultat de conception centrée décideur.
- § 12.5 : la réponse frontale à « des indicateurs, pour quoi faire ? » — chaque écran répond à une question de décision nommée.
- Figures du ch. 11-12 : les quatre écrans.
