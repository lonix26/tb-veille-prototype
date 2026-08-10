# Plan de collecte — du 8 au 25 août 2026

Cible : **21 indicateurs *hard data* certifiés collectés automatiquement, plus le pipeline composite A2.**

Pas 26. Quatre indicateurs du référentiel — H5, M5, S2, S5 — sont au statut « à confirmer » : leurs sources ne sont pas certifiées, et les collecter contredirait la doctrine de qualification du § 8.2.1. Un cinquième, H1, est classé *hard* mais n'existe qu'en PDF : à reclasser en composite.

Le 25.08 est une **date d'arrêt ferme**. Ce qui n'est pas collecté ce jour-là est gelé et documenté comme limite. Les dix jours suivants vont au rapport, sans exception — c'est le livrable noté, et plusieurs de ses composants sont obligatoires au dépôt.

---

## Principe : le coût est par connecteur, pas par indicateur

Le socle déclaratif change l'économie du travail. Une fois qu'une famille de connecteur fonctionne, ajouter un indicateur du même type est une ligne en base et une demi-heure de vérification. Il reste six familles à faire fonctionner.

| Connecteur | Indicateurs débloqués | État au 07.08 |
|---|---|---|
| Eurostat JSON-stat | A5, M2 | **Fonctionne** |
| CSV paramétrable | S3, T2, peut-être A3 et S4 | **Écrit**, à éprouver sur T2 |
| JSON générique | T4, Comtrade | À adapter — le FMI renvoie un objet imbriqué, pas une liste |
| Comtrade | **H3, M1, A4, S6** | Répond sans clé — à confirmer |
| PX-Web en POST | H2, M4 | À écrire |
| SDMX | T1 | Point d'accès public, charge utile non lue |
| Classeur Excel | T3 | À écrire |
| Grattage de page | A1, S1, peut-être H4 et M6 | À écrire |

---

## Palier 1 — d'ici mardi 11.08 · objectif 9 indicateurs

**Comtrade d'abord.** C'est la clé de voûte : quatre indicateurs, un par secteur, une seule vérification. Le point d'accès de métadonnées répond en JSON valide sans clé, avec un champ d'erreur vide — aucun rejet d'authentification. Le point d'accès d'aperçu répond également mais en charge compressée.

```bash
curl -s --compressed "https://comtradeapi.un.org/public/v1/preview/C/A/HS?reporterCode=756&period=2023&cmdCode=91&flowCode=X&partnerCode=0" | head -c 800
```

À observer : le nom du tableau de données dans le JSON, et les colonnes de période, de valeur, de pays déclarant et de pays partenaire. Noter aussi le **quota** — l'aperçu public est généralement plafonné en nombre de lignes et en appels par heure. Si le plafond est bas, interroger par période et par code, pas en une requête.

Une fois la structure connue, les quatre liaisons se déduisent l'une de l'autre : seul `cmdCode` change — `91` horlogerie, `9018,9019,9020,9021,9022` médical, `8708` automobile, `88` aérospatial.

**Puis T2 et T4**, déjà vérifiés le 07.08. Les paramètres sont dans `RECONNAISSANCE_SOURCES_2026-08-07.md`. Écris les liaisons toi-même après avoir appelé les URL : c'est l'acte de qualification, et c'est ce qu'un jury te demandera d'expliquer.

Attention sur T4 : le connecteur `json_generique` actuel lit une **liste**, le FMI renvoie un **objet imbriqué par année**. Il ne conviendra pas tel quel — décision de conception à prendre.

**Puis M2**, une seule décision : tester `nace_r2=C32_5` ; si la série existe, corriger la liaison ; sinon requalifier l'indicateur sur C32 au § 8.4.2 et énoncer la limite de granularité.

À l'issue : **A5, S3, T2, T4, M2, H3, M1, A4, S6** — les quatre secteurs et le socle transversal. Le défaut I-5 est refermé, la vue « Contexte » ayant enfin un contenu.

---

## Palier 2 — du 12 au 18.08 · objectif 15 indicateurs

**T1, OCDE.** Le point d'accès public est confirmé, l'agence est `OECD.SDD.STES` et le flux `DSD_STES@DF_CLI`. La charge utile n'a jamais pu être lue par la reconnaissance — limite d'outillage, non indisponibilité. Un `curl` tranchera. Attention : `format=csv` et `format=csvfile` sont invalides, seul `csvfilewithlabels` a répondu.

**T3, CPB.** Fichier Excel, nom variable chaque mois avec un suffixe imprévisible. Deux coûts : un analyseur de classeur, et le grattage de la page de publication pour retrouver le lien. Tester d'abord si `cpb.nl/en/worldtrademonitor/latest` est une page d'index stable — cela éviterait le grattage.

**H2 et M4, OFS.** Table `px-x-0602010000_103`, nomenclatures confirmées présentes : `265201`–`265205` horlogerie, `266000`, `325001`–`325004` medtech. Canton `999` = Suisse. L'extraction exige un **POST** avec un corps JSON — le connecteur générique n'émet que des GET, à étendre. Série annuelle arrêtée à 2023 : ne produira aucun écart entre exécutions rapprochées, à ne pas présenter comme une série vivante.

**A3 et S4.** Relever l'URL de téléchargement direct. Si la source ne diffuse qu'en Excel derrière une page de présentation, l'indicateur bascule en composite et sort du palier.

---

## Palier 3 — du 19 au 25.08 · objectif 21 indicateurs

**H4 et M6, OMPI.** Brevets par domaine technologique. Vérifier l'existence d'une API ou d'un export au centre de données statistiques de l'OMPI. Ces deux indicateurs portent à eux seuls la question QV4, dynamique technologique, sur l'horlogerie et le médical.

**A1, OICA.** Tableaux web à gratter. Série annuelle.

**S1, constructeurs.** Commandes et livraisons Airbus et Boeing, deux producteurs à consolider, formats hétérogènes.

**Si l'un résiste plus d'une journée, il est gelé et documenté.** Une lacune expliquée est un résultat ; un jour perdu sur une page récalcitrante n'en est pas un.

---

## En parallèle et prioritaire : A2, le pipeline composite

**À traiter dès que le palier 1 est acquis, sans attendre les paliers suivants.**

A2 — immatriculations de véhicules neufs en Europe, communiqués ACEA en PDF — est le **seul composite certifié du référentiel**. C'est lui, et lui seul, qui démontre la chaîne extraction par IA → contrôle de consistance multi-modèles → bifurcation vers la validation humaine. C'est-à-dire le cœur de la réponse à la question de recherche.

Devant un jury, **un composite qui fonctionne vaut plus que six *hard data* supplémentaires**. Les *hard data* démontrent un ETL ; A2 démontre la thèse.

Point de vigilance repris du RUNBOOK : la **branche de désaccord n'a jamais été vue se déclencher**. Un pipeline de validation dont on n'a pas observé le chemin d'exception n'est pas éprouvé. Au besoin, dégrader volontairement le prompt d'un des modèles pour la provoquer, et conserver la trace.

---

## Règles de conduite

**Une heure par source, pas davantage.** Au-delà, la liaison reste `a_verifier` avec une note expliquant ce qui bloque, et l'on passe à la suivante.

**Ne jamais activer une liaison sans avoir vu la réponse.** La contrainte `chk_binding_verifie` l'impose en base ; qu'elle l'impose aussi dans la pratique.

**Conserver toutes les sorties d'exécution.** Ce sont des pièces d'annexe 5, et elles constituent la preuve d'audit exigée par E6.

**Après chaque palier**, régénérer l'annexe 1 et le classeur, et vérifier que le tableau de bord reflète le nouvel état. Un palier non restitué n'est pas un palier acquis.

---

## Ce qui reste hors périmètre, et pourquoi

**H1, exportations horlogères FH.** PDF uniquement, noms de fichiers à date encodée sans motif stable. Relève du composite documentaire. À reclasser au § 8.4.1 — et c'est un constat qui renforce l'argumentation plutôt qu'il ne l'affaiblit : le secteur le mieux doté en appareil statistique du portefeuille est celui dont l'indicateur pivot n'est pas structuré.

**H5, M5, S2, S5.** Statut « à confirmer ». Les collecter contredirait la doctrine de qualification.

**La confrontation B/C du § 10.5.3.** Le protocole et la grille écrits suffisent ; l'annexe 7 sera requalifiée en « grille spécifiée, non renseignée ».

---

## Le 25 août

Arrêt ferme. Bilan honnête de ce qui est collecté, mise à jour de l'annexe 1 et du classeur, et bascule intégrale sur le rapport.

Le test reste le même à chaque phrase écrite ensuite : *si le jury demande de le montrer maintenant, est-ce que je peux ?*
