# Passation — reprise du prototype en session terminal

Document de transmission rédigé le 07.08.2026. Il décrit l'état **réel** du prototype, ce qui est vérifié sur pièce, ce qui ne l'est pas, et ce qui reste à faire. À lire avant toute intervention technique.

Ce document est destiné à une session disposant d'un accès au shell. La session qui l'a rédigé n'en avait pas : tout ce qui suit a été établi par lecture de fichiers et par appels d'API, jamais par exécution locale. **Cette distinction est importante — plusieurs choses écrites ici n'ont pas pu être testées.**

---

## 1. Ce qui est acquis, vérifié sur pièce

| Élément | Preuve |
|---|---|
| Base PostgreSQL en service, schéma complet | Exports CSV cohérents, 123 lignes au registre |
| Six contrôles d'intégrité éprouvés le 06.08 | Sorties conservées en `annexe_A5/` |
| Indicateur A5 collecté de bout en bout | 41 périodes 2023-01 → 2026-05, 123 lignes sur 3 exécutions, dernier run 6 |
| Migration de scission des questions de veille **appliquée** | `questions_de_veille.csv` porte QV4 « dynamique technologique » et QV5 « impulsions publiques » ; `instanciation_qv.csv` et `lacunes.csv` peuplés |
| Décompte du référentiel | 26 indicateurs, 22 certifiés (21 *hard*, 1 composite), 4 à confirmer |
| URL de sources affinées par l'étudiant | `02_referentiel.sql` et les exports concordent |

---

## 2. Ce qui bloquait S3 — RÉSOLU le 09.08.2026

**`S3` affichait zéro observation.** Diagnostiqué et corrigé en session terminal le 09.08. La cause n'était aucune des trois pistes soupçonnées ci-dessous : elle était en amont, empilée en trois couches.

1. La vue `v_bindings_actifs` que lit le collecteur **n'existait pas** — la migration `socle_declaratif` n'avait jamais été appliquée (voir § 3). La liaison S3 y est définie ; sans la table, aucune liaison à lire.
2. Le workflow `collecte_generique.json` **n'était pas importé dans n8n** — il ne vivait que comme fichier monté en lecture seule. Il n'a donc jamais tourné.
3. Un bug propre : le nœud « Déposer en zone brute » lisait `fileName={{ $json.raw_ref }}`, mais `convertToFile` vide le `json` de l'item → `raw_ref` devenait `undefined` et l'écriture échouait. **Corrigé** par une référence de nœud stable, sur le modèle du pilote A5 (commit `prototype: corriger le dépôt brut du collecteur générique`).

**Résultat vérifié (run 8) :** S3 = 27 observations (OWID/UNOOSA, 9 zones × 2023-2025), A5 recollecté (41), 0 écartée par les contrôles, dépôts bruts `A5_run8.raw` et `S3_run8.raw`. Run 7 = tentative interrompue, marquée `echec` (aucune donnée).

*Note sur les trois pistes initialement soupçonnées, toutes écartées :* le `responseFormat: text` est correct (le CSV owid et le `JSON.parse` du décodage s'en accommodent) ; l'appariement par position fonctionne (les deux liaisons reviennent dans l'ordre) ; le sous-dossier `staging` existe et est accessible en écriture. Le workflow reste calqué sur `collecte_a5_eurostat_pilote.json`, la référence.

**Reste à faire côté import n8n :** l'import CLI exige un `id` et perd les credentials Postgres — la copie importée a reçu l'`id` `xwHxbBF1PbWRJZM7` et la credential `QdVRYX9pjTj9C8G3` (« postgres veille ») rattachée à ses 4 nœuds Postgres. À refaire si le workflow est réimporté à neuf.

---

## 3. Migrations écrites, état d'application

| Fichier | Appliquée ? |
|---|---|
| `migrations/2026-08-07_scission_qv3_et_instanciation.sql` | **Oui** — preuve dans les exports |
| `migrations/2026-08-07_metriques_derivees.sql` | **Oui — appliquée le 09.08** (`v_metriques` présente, registre intact à 123). Sortie en `annexe_5/migration_metriques_derivees_2026-08-09.txt` |
| `migrations/2026-08-07_socle_declaratif.sql` | **Oui — appliquée le 09.08** (`source_bindings` présente, 2 liaisons actives A5/S3, contrainte `chk_binding_verifie` éprouvée). Sortie en `annexe_5/migration_socle_declaratif_2026-08-09.txt` |

Les trois sont transactionnelles, gardées contre une seconde application, et n'écrivent rien dans `indicator_values`. Chacune se termine par des vérifications dont les attendus sont énoncés **avant** exécution — conserver les sorties, ce sont des pièces d'annexe 5.

---

## 4. Corrections — toutes résolues le 09.08.2026

Les trois écarts autrefois listés ici (H1, M2, dates de qualification) ont été **tranchés et appliqués le 09.08**. Section conservée pour la traçabilité.

**H1 — RÉSOLU le 09.08.2026, dans un autre sens que prévu.** Le plan initial (conservé ci-après pour mémoire) prévoyait de reclasser H1 en **composite** parce que la FH ne publie que des PDF non automatisables. La décision retenue est différente : plutôt que de subir la limite de la FH, H1 a été **re-sourcé sur UN Comtrade** (chapitre SH 91, déclarant Suisse, ventilé par marché partenaire, mensuel), ce qui le **garde hard et automatisable**. La FH est conservée comme référence de branche au tableau de confiance, mais n'est plus la source de H1.

Appliqué par `migrations/2026-08-09_reclassification_H1.sql` (sortie en `annexe_5/`) :
- `indicators.H1` : `source_id` fh → comtrade, `unit` mio CHF → USD ; reste `hard`, mensuel.
- `sources.fh` : `format` « Web / PDF / CSV » → « PDF / communiqués », désormais sans indicateur rattaché. Domaine `fhs.swiss` (déjà corrigé en base).

**Effet sur le décompte qui fait foi — INCHANGÉ.** H1 restant hard, le décompte demeure **21 hard / 1 composite**, et **A2 reste l'unique composite certifié**. Le tableau ci-dessous, qui annonçait 20 hard / 2 composites, est **caduc** — il décrivait le plan « H1 → composite » écarté :

| ~~Plan écarté~~ | ~~Avant~~ | ~~Après~~ |
|---|---|---|
| ~~dont *hard data*~~ | ~~21~~ | ~~20~~ |
| ~~dont composites~~ | ~~1~~ | ~~2~~ |

**À corriger au rapport** : tout passage qui annonce « H1 composite », « 20 hard / 2 composites » ou « A2 perd son unicité » reflète le plan écarté et doit être aligné sur 21 hard / 1 composite, H1 hard sur Comtrade.

**M2 — RÉSOLU le 09.08.2026.** Deux écarts corrigés par `migrations/2026-08-09_correction_M2.sql` (sortie en `annexe_5/`) :
- **Granularité.** La classe C32.5 spécifiée au § 8.4.2 existe bien dans `sts_inpr_m`, sous le code **`C325`** (et non `C32_5`) : 41 valeurs mensuelles 2023-01..2026-06. La liaison est recalée de l'agrégat large C32 vers C325 ; la réserve « agrégat trop large » est levée. Le label de l'indicateur, qui annonçait déjà « NACE C32.5 », était juste.
- **Fréquence.** `indicators.M2` passe de « trimestrielle » à « mensuelle ».

La liaison M2 reste `a_verifier` : son activation, après vue de la réponse réelle, appartient à l'étudiant.

**Dates de qualification — RÉSOLU le 09.08.2026.** Les 21 sources initiales portaient `qualified_at = 06.08.2026` (date de *seed* du référentiel) alors que l'acte humain de qualification — vérification et affinage des URL — a eu lieu le 07.08. Recalées sur le 07.08 par `migrations/2026-08-09_dates_qualification.sql` (sortie en `annexe_5/`) ; `fh` reste au 09.08 (reclassement, date propre). Date seule, l'heure exacte n'ayant pas été consignée n'a pas été reconstruite.

---

## 5. Reconnaissance des sources — ce qui est établi

Détail complet dans `prototype/RECONNAISSANCE_SOURCES_2026-08-07.md`.

**Vérifiées de bout en bout, activables immédiatement**

- **T2, BNS.** `https://data.snb.ch/api/cube/devkum/data/csv/fr?fromDate=2023-01&dimSel=D0(M0),D1(USD1,EUR1)` — CSV, BOM, **trois lignes à sauter**, séparateur point-virgule, colonnes `Date` / `D0` / `D1` / `Value`. Filtrer `D0 = M0`. Sans `fromDate` ni `dimSel`, le cube entier depuis 1914 est renvoyé.
- **T4, FMI.** `https://www.imf.org/external/datamapper/api/v1/NGDP_RPCH/WEOWORLD` — JSON. **Le filtrage par URL ne fonctionne pas** : la réponse contient toutes les économies. Structure `values → NGDP_RPCH → code → année → valeur`, donc **un objet imbriqué, pas une liste** : le connecteur `json_generique` actuel ne convient pas tel quel.
- **M2, Eurostat.** Requête vérifiée sur `nace_r2=C32`, 41 valeurs. **Décision à prendre** : tester `C32_5` ; si la série existe, corriger ; sinon requalifier l'indicateur sur C32 et énoncer la limite de granularité.

**Comtrade — la clé de voûte, à trancher en priorité**

Le point d'accès public **répond sans clé** : `getMetadata` renvoie du JSON valide avec un champ d'erreur vide. `preview` répond en charge compressée, non lisible par l'outillage de la session précédente.

```bash
curl -s --compressed "https://comtradeapi.un.org/public/v1/preview/C/A/HS?reporterCode=756&period=2023&cmdCode=91&flowCode=X&partnerCode=0" | head -c 800
```

Relever : nom du tableau de données, colonnes période / valeur / déclarant / partenaire, **et le quota**. Les quatre indicateurs H3, M1, A4, S6 se déduisent ensuite l'un de l'autre — seul `cmdCode` change : `91`, `9018,9019,9020,9021,9022`, `8708`, `88`.

**Accessibles mais coûteuses** — H2/M4 par l'interface PX-Web de l'OFS (table `px-x-0602010000_103`, nomenclatures `265201`–`265205`, `266000`, `325001`–`325004` confirmées présentes ; **extraction en POST**, série annuelle arrêtée à 2023) ; T3 par le CPB en Excel avec nom de fichier variable.

**Non conclues** — T1 (OCDE, point d'accès public confirmé, charge utile jamais lue), A3 (AIE), S4 (SIPRI), H4/M6 (OMPI), A1 (OICA), S1 (constructeurs).

---

## 6. Ordre de travail

Le plan complet est dans `prototype/PLAN_COLLECTE.md`. En résumé :

1. Diagnostiquer l'échec de S3.
2. Appliquer les migrations manquantes.
3. Trancher Comtrade — quatre indicateurs, quatre secteurs, une seule vérification.
4. Activer T2 et T4.
5. Trancher M2.
6. **A2, le pipeline composite** — prioritaire sur les paliers suivants : c'est le seul qui démontre la thèse, et sa branche de désaccord n'a jamais été vue se déclencher.
7. Paliers 2 et 3 selon `PLAN_COLLECTE.md`.

**Date d'arrêt ferme : 25.08.2026.** Ensuite, rapport exclusivement.

---

## 6 bis. Couche de lecture du tableau de bord — écrite le 10.08.2026, NON EXÉCUTÉE

Modifications faites en session Cowork, sans accès au bac à sable : **ni la base ni le rendu n'ont été vérifiés**. À reprendre en session terminal avant tout commit, et à ne mentionner nulle part au présent de réalisation tant que la page n'a pas été ouverte.

**Origine.** Revue de la restitution du point de vue du destinataire : la page affichait des mesures sans jamais donner de lecture, et le bandeau de tête ne portait que des compteurs de couverture du dispositif. Diagnostic complet dans `rapport/notes_de_redaction.md`, section du 10.08.

**`prototype/n8n_workflows/api_restitution.json`** — une clé ajoutée à la requête de lecture :

```
'alertes' → v_alertes_candidates JOIN v_dernier_point (indicator_id, geo, period)
```

Restreint les franchissements à la dernière observation de chaque couple indicateur/zone. **Le workflow doit être réimporté et réactivé dans n8n** — la modification du fichier ne suffit pas. Vérification : `curl -s localhost:5678/webhook/veille/donnees | python3 -m json.tool | grep -c alertes`.

**`prototype/tableau_de_bord.html`** — sept modifications :

1. `blocSignaux()` — franchissements de seuil en tête de page, diffusables et retenus séparés, motif de retenue affiché. **Trois états** et non deux : clé absente de la charge utile ⇒ « non interrogé », jamais « aucun signal ». C'est le garde-fou à ne pas retirer.
2. `lectureSecteur()` — phrase de synthèse en tête d'onglet, composée par gabarit depuis `v_dernier_point`. Aucun appel à un modèle.
3. `ligneSeuil()` — position au seuil de matérialité affichée en permanence, avec la distance au franchissement ; les trois cas indéterminables sont énoncés.
4. `nbAuto()` — précision d'affichage suivant l'ordre de grandeur. Corrige l'affichage « 1 » pour un taux de change de 0,93, produit par `nb(v, 0)`.
5. `estAdditive()` + `comparaisonNiveaux()` — les indicateurs multi-zones à unité non additive (indice, taux, pourcentage) ne passent plus par le classement en parts de panier. **Concerne T2 aujourd'hui**, et tout futur indice décliné par zone.
6. `mentionRun()` — révision constatée / aucune révision constatée / aucune comparaison possible, trois formulations distinctes selon `D.revisions` et `D.comparaisons_runs`.
7. `spark()` — ligne pointillée à la moyenne mobile annuelle, seul repère calculé disponible.

**À vérifier à l'ouverture** : la page se charge sans erreur de console ; l'onglet Contexte affiche T2 en comparaison de niveaux avec des taux lisibles ; la phrase de lecture donne des décomptes cohérents avec les cartes ; le bandeau n'affiche pas « aucun franchissement » si le workflow n'a pas été réimporté.

**Résultat de la première exécution (10.08, soir) : 33 franchissements, tous diffusables.** La chaîne fonctionne ; les seuils ne discriminent pas — ils ont été semés (5/10/15 %) sans confrontation aux données. Trois suites, par priorité :

1. **H1 s'arrête à 2024-03 — DIAGNOSTIQUÉ ET TRAITÉ le 10.08 en session terminal.** Cause : la liaison active ne demandait que `202401,202402,202403` — fenêtre de test jamais élargie, pas un défaut de source. Contrainte confirmée sur pièce : Comtrade plafonne à **12 périodes par requête mensuelle** (la 13e → HTTP 400). Migration `2026-08-10_H1_fenetre_complete.sql` **appliquée** (sortie en `annexe_5/`) : quatre liaisons par blocs annuels 2023→2026-05, semées `a_verifier`. **Reste à l'étudiant** : vérifier la réponse réelle de chaque fenêtre, activer nominativement, puis **retirer la liaison de test à trois mois** (elle recouvre la fenêtre 2024 — doublon de collecte sinon).
2. **Recalibrer les seuils — MATIÈRE PRÊTE, DÉCISION EN ATTENTE.** **[PÉRIMÉ, corrigé le 31.08.2026 : la migration a été EXÉCUTÉE le jour même de sa rédaction — sortie archivée en `annexe_5/calibrage_seuils_2026-08-10.txt`, horodatée du 10.08 à 16 h 06 — et H1 calibré séparément le 11.08. Cette ligne a laissé croire trois semaines durant qu'une décision restait ouverte, et elle a été citée comme telle dans un point d'avancement. La suite du calibrage a été arbitrée le 31.08 : voir l'entrée de ce jour.]** `annexe_5/reconnaissance_volatilites_2026-08-10.txt` porte σ, moyenne absolue, p90 et max des glissements par indicateur. Confirmation chiffrée du diagnostic : sur les flux commerciaux le seuil de 5 % est sous l'écart-type observé (A4 4,8 ; H3 6,5 ; M1 5,8 ; S6 11,9) — il alerte sur le bruit ; à l'inverse T1 (seuil 2 %, max observé 0,8 %) ne se déclencherait jamais. Règle candidate : **seuil ≈ p90 des glissements observés** (un franchissement ≈ 1 observation sur 10 dans l'historique). **Migration préparée** : `migrations/2026-08-10_calibrage_seuils.sql` — T1 0,5 · T2 7 · A4/A5/H3 10 · M1/M2 12 · S6 20 · S3 80 · T4 NULL, un motif par valeur en commentaire. **L'exécution vaut décision** : relire, corriger si besoin, exécuter, conserver la sortie en annexe 5. **H1 volontairement absent** : sa série s'arrête à 2024-03, aucune volatilité calculable — à calibrer une fois les quatre fenêtres activées et l'historique collecté ; d'ici là son seuil semé (5 %) reste marqué non calibré. Noter aussi que pour T1 (indice de tendance) la matérialité par glissement est un instrument imparfait — l'écart au seuil de 100 serait plus parlant, à trancher avec la colonne `niveau_reference`.
3. **OWID_WRL** exclu des classements côté page (liste en dur `estAgregatMonde`) — la résolution propre est la nomenclature géographique en base, déjà notée en limite § 10.6.

**Run 24 constaté sur pièces (staging)** : dix indicateurs collectés, dont T1 (CLI G20 réancré) et M2 (C325) pour la première fois.

Correctifs d'affichage du soir (dans `tableau_de_bord.html`, non vérifiés ensemble depuis) : pastilles regroupées par indicateur avec détail replié, `pctNu()` pour les pourcentages (« 5,000 % » se lisait cinq mille), agrégats monde exclus des classements et des comparaisons.

**Maquette v2 validée le 10.08.2026** (`prototype/maquette_v2_tableau_de_bord.html`, données fictives, aucune lecture de la base). Décision N. Castillo : la forme v2 remplace celle de `tableau_de_bord.html`. Le portage est un travail de gabarits, à faire en session terminal, **après** la vérification fonctionnelle du § ci-dessus et **sans priorité sur A2** — l'ordre du § 6 reste : H1, seuils, A2 d'abord.

**PORTAGE EFFECTUÉ le 10.08.2026 en session Cowork — NON VÉRIFIÉ à l'écran.** Quatre modifications dans `tableau_de_bord.html`, logique de données intacte :

1. Bloc `<style id="peau-v2">` ajouté après les styles d'origine : palette, cartes arrondies, navigation en pastilles, en-tête clair. Une couche de peau — retirer le bloc restaure l'ancien rendu.
2. `spark()` réécrit : grille avec niveaux, années aux janviers, dernier point annoté, ligne de référence pointillée avec étiquette. Même signature, appelants inchangés.
3. `chipVar()` : pastille de variation colorée à côté de la valeur.
4. Ligne « ce qu'il indique » projetée depuis `indicators.description_metier` — **nouvelle migration `2026-08-10_descriptions_metier.sql`** (26 premiers jets, à relire avant exécution) et colonne ajoutée à la requête d'`api_restitution.json`. **ORDRE STRICT : migration d'abord, réimport du workflow ensuite** — sinon la requête échoue sur colonne inconnue et la page n'affiche plus rien. Si la migration n'est pas passée et le workflow pas réimporté, la page fonctionne sans la ligne métier (dégradation propre).

À vérifier à l'ouverture : rendu v2 sur les six onglets, graphiques lisibles, aucune erreur de console, et les vues Référentiel/Exécutions (non maquettées) restent correctes sous la nouvelle peau.

Contraintes tenues : fichier unique, zéro dépendance, zéro build (E5). Aucune donnée embarquée dans `tableau_de_bord.html` — la maquette, elle, en embarque et le dit, c'est sa fonction.

**Limite assumée, à ne pas masquer.** Le repère tracé est la moyenne mobile, faute d'un niveau de référence propre à l'indicateur (100 pour un indice de tendance). Ce niveau relève d'un attribut du référentiel à saisir source par source — colonne à ajouter à `indicators` — et non d'une convention devinée dans la page.

---

## 6 ter. Signaux qualitatifs — tranche verticale écrite le 12.08.2026, NON EXÉCUTÉE

Décision de l'étudiant du 12.08 (à faire **tracer au PV n° 5** le 13.08 comme choix de périmètre) : exécuter le versant « signaux » du volet OSINT dans le prototype, en réutilisant la chaîne multi-modèles démontrée par A2 au run 28. Terrain choisi : **automobile / QV5** — la lacune typée du ch. 8 (actes réglementaires, pas séries) devient le premier cas instrumenté.

**Pièces écrites (session Cowork, non exécutées)** :

- `migrations/2026-08-12_signaux_qualitatifs.sql` — table `signals` (schéma d'événement : evenement, acteur, echeance, zone ; extraits par modèle en JSONB ; contrainte de validation tracée) + vue `v_signaux`. **À appliquer AVANT le réimport d'api_restitution.**
- `n8n_workflows/extraction_signal_qualitatif.json` — chaîne A2 adaptée : document choisi manuellement par le veilleur → dépôt brut → 3 modèles → extraits source obligatoires → **recoupement** (≥ 2 modèles d'accord par champ, sinon NULL) → écriture systématique en `a_valider`. Pas de branche « consensus suffit » : sur du qualitatif, la validation humaine est le chemin unique. Document de démonstration câblé : règlement (UE) 2023/851 via EUR-Lex (URL à remplacer si elle ne répond pas).
- `valider_signal.sql` — validation (ou rejet) nominative et datée ; la `note_validation` (portée pour un sous-traitant) est un jugement humain, volontairement exclu du schéma d'extraction.
- `api_restitution.json` — clé `signaux` ajoutée (v_signaux). `tableau_de_bord.html` — section « Signaux qualitatifs » par onglet : seuls les validés s'affichent, les `a_valider` remontent en compteur, trois états (non interrogé ≠ aucun signal).

**Séquence d'exécution** : migration → réimport des deux workflows → exécution du workflow signal → vérifier `SELECT * FROM signals;` → ouvrir le document déposé, vérifier les extraits, compléter les champs NULL le cas échéant → `valider_signal.sql` → recharger le tableau de bord.

**Bornes décidées** : sélection du document manuelle (pas de moissonnage autonome — scénario B) ; une famille de sources (réglementaire) dans cette itération ; **date de mort le 18.08** — si la tranche ne tourne pas, elle bascule au ch. 13 en perspective, le protocole OSINT prévoyant le droit de conclure « écarté ». Terminologie pour le rapport : « signaux qualitatifs » de préférence à « signaux faibles » tant que la seule famille instrumentée est le réglementaire — un règlement publié au JO est un signal précoce pour la filière, mais pas « faible » au sens d'Ansoff ; ne pas surdéclarer le concept.

---

## 6 quater. Lot 1 — reprise du développement, écrit le 17.08.2026, NON EXÉCUTÉ

**Décision de l'étudiant du 17.08.2026 : l'arrêt technique du 25.08 est levé, le développement reprend sous pilotage assisté ; le calendrier est porté par l'étudiant.** À tracer au registre des décisions de `synthese_consolidee_pilotage_TB.md`.

Objectif : instrumenter les dix indicateurs certifiés à zéro observation, puis exploiter le pipeline composite (A2 en série, S2 IATA), le commentaire exécutif LLM, l'indicateur synthétique et la vue QV0. Ordre et détail : tâches de session Cowork du 17.08.

**Pièces écrites (session Cowork, sans accès shell — rien de vérifié en réponse réelle) :**

- `prototype/RECONNAISSANCE_SOURCES_LOT1_2026-08-17.md` — reconnaissance des dix manquants en trois groupes : compatibles connecteurs existants (A3, M3, S4), évolutions de connecteur requises (`http_post` pour H2/M4, `xlsx` + `page_index` pour T3), sans point d'accès structuré (H4/M6 OMPI, A1 OICA, S1 Airbus/Boeing — pour S1, une requalification hard → composite est **signalée à trancher**, pas décidée). Commandes `curl` de vérification incluses.
- `prototype/migrations/2026-08-17_bindings_lot1.sql` — liaisons A3/M3/S4 semées `a_verifier`, sans `verifie_par` : aucune URL vue en réponse réelle depuis Cowork (AIE et SIPRI muets, CPB servi en cache 2021). H2/M4/T3 volontairement non semés — leurs connecteurs n'existent pas encore.

**Séquence terminal** : appliquer la migration → dérouler les `curl` du groupe 1 → corriger les mappings d'après les réponses réelles → activer nominativement ce qui répond → implémenter `http_post` (gain le plus sûr, reconnaissance OFS déjà faite le 07.08) → T3 en priorité du groupe 2 (il porte l'indicateur synthétique du lot 4). Une heure par source, sorties en `annexe_5/`.

**BILAN DU LOT 1 — exécuté le 17.08.2026, tout vérifié sur pièce en session terminal.** Six indicateurs instrumentés dans la journée : A3 (AIE, trois liaisons annuelles), M3 (OMS/GHO — incident du run 33 documenté : clé de mapping erronée, ligne fausse conservée à l'historique, correctif + `geo_renommage` au décodeur JSON), H2 et M4 (OFS STATENT en POST — troisième voie d'appel dédiée après l'échec des expressions sur champ booléen, runs 36-42, diagnostic complet dans les migrations), S4 (SIPRI) et T3 (CPB, page `/latest`, série par code stable `tgz_w1_qnmi_sn`) via le **nouveau workflow `collecte_xlsx_indexe.json`** (résolution de lien sur page d'index, extraction native, pivot large→long, contrôles dupliqués du générique — dette assumée). Sixième connecteur au socle (`xlsx_indexe`, CHECK étendu par migration après rejet constaté — pièce d'annexe 5). **18/22 certifiés en collecte, socle QV0 complet (T1-T4).** Restent : H4/M6 (OMPI, une heure au chrono, sinon dépôt manuel annuel ou lacune), A1 et S1 (pas de point d'accès structuré ; requalification S1 hard→composite **signalée, non décidée** — changerait le décompte 21/1, à porter en séance). Unité S4 corrigée (mia→mio USD) ; SIPRI : drapeaux de qualité portés par la couleur des cellules, quatrième occurrence du motif, structurellement inextractible — consigné pour le § 12.5.

---

## 6 quinquies. Bilan de la journée du 17.08.2026 — tout vérifié sur pièce

La plus grosse journée de développement du projet, conduite en session Cowork pilotée avec exécution terminal par l'étudiant. État en fin de journée :

- **Grille : 28 indicateurs, 24 certifiés (23 hard / 1 composite).** Ajouts du jour : T5 (attentes de production UE, BS-IPE — avancé à 3 mois) et T6 (baromètre KOF — avancé suisse), certifiés et collectés (43 obs chacun, 2023-01→2026-07).
- **Collecte : 19 indicateurs alimentent le registre** (~15 000 observations). Instrumentés dans la journée : A3, M3, H2, M4 (voie POST OFS), S4 et T3 (nouveau collecteur xlsx indexé), T5, T6. Restent non instrumentés : H4/M6 (OMPI, une heure à faire), A1, S1 (décision de qualification S1 hard→composite à porter en séance), H5/M5/S2/S5 (composites a_confirmer).
- **Composite A2 : série de 7 mois validés humainement** (2025-11→2026-06) via la file de documents `composite_queue` ; 6 extractions, 6 passages en validation, 4 modes de défaillance documentés ; garde de concordance de période ajoutée.
- **Commentaire exécutif : exécuté.** Fournée 1 : 3 rejets motivés sur 4 (calcul dérivé, affirmation contredite, arrondi) ; correctifs (consigne, arrondi SQL) ; fournée 2 : 4/4 validés. Servi par l'API, affiché par l'application.
- **Indicateur synthétique** (engagement de ratification) : part suisse du commerce horloger SH 91, vue SQL, 61,34 % (2023) / 61,74 % (2024) / non calculable 2025 (CHN manquant — règle du déclarant le plus lent exécutée).
- **Application de restitution v3** : conçue à neuf (navigation latérale, vue d'ensemble, graphiques interactifs ECharts incorporés au fichier). **E5 révisé** (dépendance libre incorporée, repli SVG) — décision documentée en notes de rédaction. **Bascule v2→v3 non faite** : en attente de validation à l'écran par l'étudiant (`tableau_de_bord_v3.html` à côté de l'actuel).
- **Contrôles qualité : deux hypothèses implicites corrigées par drapeau de liaison** (`admet_negatifs`) — négativité et variation relative, violées par les soldes d'opinion. Matériau § 12.5.

**File de demain, par ordre** : (1) bascule v3 si validée + panneau de fraîcheur (âge du dernier point par indicateur) ; (2) déclinaison sectorielle des avancés (fichiers NACE DG ECFIN, C29/C30/C32 — le site ne répondait pas le 17.08) ; (3) Comtrade mensuel médical et reconnaissance openFDA ; (4) OMPI (une heure) ; (5) régénérer l'annexe 1 et les exports (décomptes 26→28 à propager) ; (6) alignement du rapport sur l'état démontré (notes de rédaction du 17.08, nombreuses) ; (7) **copie Drive quotidienne — non faite pendant la session, à faire immédiatement**.

## 6 sexies. Vague 3 par API et portage couche 0 — écrit le 22.08.2026, NON EXÉCUTÉ

Décision tracée dans `rapport/notes_de_redaction.md` (22.08.2026), à joindre à l'inventaire du § 7.2.2. Deux objets distincts, à exécuter dans cet ordre — le second réutilise le travail du premier :

**A. Vague 3 du protocole multi-IA (ch. 9, annexe 3).** Tout est prêt dans `annexe_3/vague3/` : `PROTOCOLE_VAGUE3.md` (le protocole complet, à lire avant), `run_vague3.py`, `depouille_vague3.py`. Périmètre : T1a/T1b × 4 fournisseurs × 3 répétitions = 24 exécutions par API, sortie JSON contrainte.

1. Clés d'API des quatre fournisseurs dans `~/.config/veille_tb/cles.env` — **hors du dossier TB** (copie Drive quotidienne), jamais versionnées. Identifiants de modèles à vérifier contre la documentation du jour et à consigner dans le même fichier (`MODELE_OPENAI=`, etc.).
2. `python3 run_vague3.py --essai` — un appel par fournisseur, valide clés et parsing. **Les détails d'API codés dans le script (noms d'outils de recherche web, en-têtes) datent du 22.08 et sont à corriger sur place si un fournisseur a bougé.**
3. Série complète `python3 run_vague3.py` (fenêtre unique de 24 h), puis dépouillement en deux passages : `--normaliser`, correction manuelle de `normalisation.csv` (regroupement par organisme, convention vagues 1-2), puis passage final. Coût réel à consigner.
4. Le dépouillement humain (conformité « officielles ou institutionnelles », pertinence 0–2, lecture du contenu des URL) et la rédaction du § 9.4.3 se font ensuite en session Cowork — déposer les sorties, c'est la passation retour.

**B. Portage des appels dans la couche 0 n8n.** Le workflow `prototype/n8n_workflows/decouverte_sources_multi_ia.json` est spécifié mais n'a jamais tourné (routes `loader` manquantes, § 6 de ce document et notes du 04.08). Une fois les appels de la vague 3 testés en A, les porter tels quels dans les nœuds HTTP du workflow (mêmes points d'accès, mêmes corps de requête, même extraction JSON). Pour l'écriture : option de repli déjà actée — écritures de fichier datées si les routes `/source-qualification-queue` et `/discovery-log` ne sont pas créées. Objectif minimal : **un run de démonstration complet, capture à l'appui pour le ch. 11** — c'est la proposition initiale du directeur (séance 3 : orchestration multi-IA pour proposer des sources) qui passe de « spécifiée » à « démontrée ». Les credentials d'API dans n8n suivent la même règle que Postgres (§ 2) : à recréer dans l'interface, jamais exportées.

Garde-fous : les résultats de A se rédigent au passé seulement après exécution (règle anti-surdéclaration ci-dessous) ; A et B restent deux objets dans le rapport — l'instrument de mesure (ch. 9) et le dispositif (ch. 10-11) — à ne pas fusionner dans le texte ; la file du § 6 quinquies (bascule v3, annexe 1, alignement rapport) reste prioritaire si le temps manque — B est une démonstration à forte valeur mais courte, A la précède.

**État au 22.08.2026 en fin de journée — série exécutée à 23/24, dépouillement en attente.** Essai validé (4/4 fournisseurs, corrections d'API tracées dans `essai_2026-08-22.md`), série lancée 14 h 02–14 h 27 : **T1b/Claude/r3 en échec** (crédit Anthropic épuisé, 400 archivé). Deux décisions d'étudiant prises le 22.08 en session Cowork : **rejouer l'exécution manquante** (après recharge du crédit) et **normalisation (A)+(B)** (décision tracée dans `proposition_normalisation_2026-08-22.md`). Reste à faire, dans cet ordre strict :

1. **Rejouer T1b/Claude/r3 uniquement** — avant le 23.08 ~14 h (fenêtre de 24 h du § 2 du protocole, ouverte à 14 h 02 le 22.08). Auparavant, renommer l'archive de l'échec en `T1b_Claude_v3_r3_2026-08-22.brut.echec1.json` (toute sortie se conserve). Exécution ciblée : ne pas relancer la série (les fichiers du jour seraient écrasés) — utiliser/ajouter un filtrage tâche+répétition sur le modèle de l'option `--systemes`.
2. **Régénérer `normalisation.csv`** (`--normaliser` — il écrase le fichier, c'est pourquoi il précède les corrections) puis **appliquer (A)+(B)** selon `proposition_normalisation_2026-08-22.md`, y compris les non-fusions (C).
3. **Second passage** `python3 depouille_vague3.py` → `depouillement_vague3_auto.md` (indices + existence des URL).
4. **Consigner le coût réel** des consoles des quatre fournisseurs (essai + série + reprise) dans `essai_2026-08-22.md` ou un fichier de coût dédié.
5. Passation retour : le dépouillement humain (conformité, pertinence, lecture des URL discriminantes — dont les cas signalés « hors normalisation » de la proposition) et la rédaction du § 9.4.3 se font en session Cowork.

**Étapes 1 à 4 exécutées le 22.08.2026 à 15 h 14–15 h 20. La partie A est complète ; seule
l'étape 5 (dépouillement humain et rédaction du § 9.4.3, en session Cowork) reste ouverte.**

1. **T1b/Claude/r3 rejouée seule** — ok, 8 sources, `json_strict`. Archive de l'échec renommée
   au préalable en `.brut.echec1.json`. Filtres `--taches` et `--repetitions` ajoutés à
   `run_vague3.py` sur le modèle de `--systemes` (sauvegarde `.avant_filtres_tache_rep_2026-08-22`).
   **Série complète : 24 exécutions sur 24**, dans la fenêtre du § 2. Conformité de format
   finale : **21 `json_strict`, 3 `json_extrait`, aucun `non_parsable`** — l'unique non-parsable
   du décompte antérieur était l'échec de crédit, qui n'est pas un résultat de format.
2. **`normalisation.csv` régénéré** (192 lignes, +8 de la reprise ; aucun domaine nouveau) puis
   **(A)+(B) appliquée** : **17 groupes T1a, 16 groupes T1b**, exactement le décompte annoncé
   par la proposition. Sortie brute conservée en `normalisation.csv.brut_avant_decision_2026-08-22`.
   Le script d'application refuse tout domaine non prévu par la décision et l'aurait signalé :
   aucun ne l'a été, donc **aucun arbitrage implicite n'a été fait à votre place**.
3. **Second passage exécuté** → `depouillement_vague3_auto.md` (journal :
   `depouillement_second_passage_2026-08-22.log`). 116 URL vérifiées.
4. **Coût consigné** dans `cout_vague3_2026-08-22.md` : **≈ 8,49 USD** pour 29 appels facturés
   (essais, série et reprise), recherche web comprise. Estimation sur jetons archivés et tarifs
   publics du jour — **le relevé des consoles fait foi**, ce document sert de contrôle de
   vraisemblance.

**Résultats à porter au § 9.4.3 — chiffres établis, lecture à faire :**

*Variance intra-modèle à conditions figées (|∩| / |∪| sur 3 répétitions)* :

| | ChatGPT | Claude | Gemini | Perplexity |
|---|---|---|---|---|
| T1a | 0,86 | 0,78 | 0,78 | **0,08** |
| T1b | 0,56 | 0,60 | 0,50 | **0,20** |

*Recouvrement inter-modèles sur les unions* : T1a **7/17 ≈ 0,41** · T1b **8/16 ≈ 0,50**.
Par répétition, T1a oscille entre 0,29 et 0,50 — **le recouvrement d'un run unique varie du
simple au double d'une répétition à l'autre, à conditions strictement identiques**. C'est la
confirmation par API du constat des vagues 1-2 (« le consensus d'un run unique est fragile,
le cumul est robuste »), et cette fois la variance du dispositif est écartée par construction.

*Existence des URL* : sur 116 URL, **93 en 200, 13 en 404, 7 en 403, 1 en 500, 2 en échec
réseau** — soit **un cinquième d'URL non joignables**. Les 404 portent sur des organismes
parfaitement réels (Boeing, ESA, OACI, UNOOSA, OFS, douanes suisses) : c'est le motif
« source réelle, métadonnée fausse » de la vague 2, désormais **mesuré par API**. Les 403
(Espacenet, ILOSTAT, OCDE, UNIDO) sont des refus d'accès automatisé : **ne pas les compter
comme des inventions**.

**Trois points de vigilance pour la rédaction :**

- **L'écart Perplexity est le résultat le plus fort de la vague, et le plus fragile.** Une
  stabilité de 0,08 sur T1a signifie qu'une seule source est commune à ses trois répétitions.
  Avant d'en faire un enseignement, vérifier sur pièces que ce n'est pas un artefact de
  normalisation : la vague 2 avait relevé que les URL de Perplexity sont polluées d'artefacts
  de citation. Les domaines sont tous couverts par la décision, ce qui plaide pour une
  instabilité réelle — mais cela se vérifie en lisant, pas en calculant.
- Perplexity rend 8 sources par exécution mais seulement 5 à 6 groupes distincts : il propose
  plusieurs outils d'un même organisme. Fait de comptage à mentionner, sans en tirer de
  jugement de qualité.
- Le noyau consensuel de T1a (7 groupes) recoupe très largement la grille du ch. 8 : FH,
  douanes suisses, OMPI, Comtrade, Eurostat, OFS, CPIH. À rapprocher explicitement — c'est
  l'argument le plus direct en faveur de la couche 0 du dispositif.

### État au 22.08.2026 (seconde session) — partie A exécutée à 23/24, partie B démontrée

Traces : `annexe_3/vague3/essai_2026-08-22.md`, `journal_vague3.csv`,
`serie_vague3_2026-08-22.log`, `proposition_normalisation_2026-08-22.md`, et
`prototype/data/runs_couche0/` pour la partie B.

#### A. Vague 3 — série exécutée, dépouillement suspendu à une décision de l'étudiant

- **Blocage Gemini levé** côté compte Google entre les deux sessions. `sonde_gemini.py`
  renvoie 200 sur `gemini-3.7-flash`, avec et sans outil de recherche.
- **Identifiants de modèles revérifiés** contre la documentation du jour : aucun n'a bougé.
  `gpt-5.6` est confirmé sur pièce (le champ `model` de la réponse renvoie `gpt-5.6-sol`).
- **Essai rejoué pour Gemini seul**, via une option `--systemes` ajoutée à `run_vague3.py` —
  refacturer les trois fournisseurs déjà validés n'aurait rien appris. Deux tentatives ont
  été nécessaires : la première a rendu un JSON épissé (archive conservée en
  `.brut.essai2_tronque.json`), la seconde 8 sources valides mais encadrées d'une clôture
  markdown.
- **Série : 23 exécutions sur 24.** Conformité de format : 20 `json_strict`, 3 `json_extrait`
  (Gemini, les trois répétitions de T1a), 1 `non_parsable`. Le défaut de format de Gemini est
  **auto-consistant sur T1a et absent sur T1b** — même modèle, mêmes conditions, comportement
  de format dépendant de la tâche. C'est un résultat que les vagues 1-2 ne pouvaient pas
  produire.
- **L'exécution manquante est T1b/Claude/r3**, et la cause n'est pas technique : le crédit de
  l'API Anthropic s'est épuisé à 14:27:05, au 23ᵉ appel sur 24. **À trancher par l'étudiant** :
  recharger et rejouer cette seule exécution (elle tiendrait encore dans la fenêtre de 24 h
  du § 2), ou déclarer 23/24 en disant pourquoi. Ne pas rejouer la série entière.
- **Dépouillement, premier passage fait** : 184 lignes, 22 groupes bruts pour T1a, 24 pour
  T1b. **Le second passage attend la décision de l'étudiant sur les regroupements** —
  proposition argumentée en trois classes (mécaniques, conventionnelles, à ne pas fusionner)
  dans `proposition_normalisation_2026-08-22.md`. Recommandation : (A)+(B), soit 17 groupes
  T1a et 16 T1b, par fidélité à la convention des vagues 1-2. **Rien n'est appliqué à
  `normalisation.csv`.**
- **Coût réel — estimation, à remplacer par le relevé des consoles.** ≈ 5,80 USD : ChatGPT
  3,15 (jetons 2,48 + 67 recherches web) · Claude ≥ 2,43 (jetons ; supplément de recherche
  web non chiffré) · Gemini 0,08 · Perplexity 0,16 (coût déclaré par l'API). Les cinq appels
  d'essai ne sont pas comptés. Le § 9 du protocole demande le relevé des consoles : c'est lui
  qui fait foi, l'estimation ne donne que l'ordre de grandeur.

#### B. Couche 0 n8n — portée et **démontrée de bout en bout**

Le workflow `decouverte_sources_multi_ia.json` n'avait jamais tourné. Il tourne.
État antérieur conservé en `.avant_portage_2026-08-22`.

**Ce que la reconnaissance a établi, et qui change le périmètre annoncé** :

- **Le service `loader` n'existe pas dans le compose et n'a jamais existé.** Les trois nœuds
  qui lisaient et écrivaient pointaient vers un hôte inexistant. Mais les tables
  `discovery_log` et `source_qualification_queue` **existent en base** : le repli par fichiers
  datés était inutile, les nœuds Postgres natifs conviennent — et c'est la décision de
  persistance du projet.
- **Aucun des quatre nœuds de modèle n'activait la recherche web.** Le workflow tel qu'il
  était spécifié aurait interrogé la mémoire paramétrique des modèles, pas le web. Écart de
  fond avec la couche 0 telle que le rapport la décrit, corrigé au portage.

**Sept correctifs portés**, chacun constaté sur exécution réelle et non supposé :

1. OpenAI : `gpt-4o` sur `/v1/chat/completions` → `gpt-5.6` sur `/v1/responses`, outil `web_search`.
2. Anthropic : `claude-sonnet-5` / 2048 jetons → `claude-opus-5` / 16000, `web_search_20260209`.
3. Google : `gemini-2.5-pro` (404 « no longer available to new users », vérifié) → `gemini-3.7-flash`, `google_search`.
4. Perplexity : `/chat/completions` → `/v1/sonar`.
5. **Convergence des branches.** Quatre nœuds branchés sur la même entrée s'exécutent
   séparément : le nœud de normalisation ne voyait qu'une réponse à la fois. Nœud Merge à
   quatre entrées ajouté. L'attribution par modèle se fait désormais **par forme de réponse**
   et non par rang d'arrivée, qui dépend de la latence de chaque fournisseur.
6. **Extraction du texte.** Avec la recherche web active, le premier bloc de contenu n'est
   plus le texte mais un bloc d'appel d'outil. `content[0].text` et `parts[0].text` ne
   fonctionnent plus : il faut concaténer tous les blocs de texte. La forme de l'API
   Responses d'OpenAI n'était pas gérée du tout.
7. **`queryReplacement` Postgres.** La forme « chaîne séparée par des virgules » se casse sur
   toute valeur contenant une virgule (JSON, libellés). Forme tableau `={{ [ … ] }}`, validée
   sur banc d'essai avant portage.

**Le piège à retenir — `}}` ferme une expression n8n.** Le corps de requête Google contenait
`tools:[{google_search:{}}]`. La séquence `}}` de l'objet vide imbriqué **ferme prématurément
l'expression n8n**, dont les délimiteurs sont `{{ }}`. n8n rend alors `{"error":"invalid
syntax"}` **sans lever d'erreur** : le workflow poursuit, la réponse Google est remplacée par
un objet d'erreur, et le nœud de normalisation la classe en `modele_2`. Écrire
`google_search:new Object()`. Le run intermédiaire du 22.08 (`run_couche0_2026-08-22.log`) a
été affecté : son indice de recouvrement de 0,118 a été **calculé sur trois modèles divisés
par quatre** et ne doit pas être cité.

**Run de démonstration retenu — `run_couche0_2026-08-22_v2.log`**, statut *success* :

| | |
|---|---|
| Question de veille | QV5, secteur automobile, impulsions publiques à l'électrification |
| Modèles ayant répondu | **quatre sur quatre**, vérifié par `modeles_ayant_repondu` |
| Union des propositions | 26 candidats |
| Noyau (≥ 3 modèles) | **1** — indice de recouvrement 0,038 |
| Déposés en file de qualification humaine | **19** |
| Journalisés non vérifiables | **7** (six en 403, un en 404, un sans statut) |
| Doublons du référentiel | 0 sur les 24 sources déjà inscrites |

**Trois constats à exploiter au ch. 11, et deux réserves de méthode :**

- Le noyau consensuel de couche 0 est **d'un seul candidat sur 26**. Le recouvrement d'un run
  unique est encore plus fragile ici qu'aux vagues 1-2 — cohérent avec la décision acquise
  « le consensus est une heuristique de priorisation, jamais une preuve ».
- **La normalisation automatique par clé d'URL sous-fusionne.** Trois entrées ACEA distinctes
  coexistent (`…incentives-2025/`, `…purchase-incentives/`, `…incentives-2026/`) là où un œil
  humain voit une seule source. C'est le même besoin de passage humain que le § 7 du
  protocole impose au dépouillement — le dispositif reproduit la limite de l'instrument.
- Six des sept URL non vérifiables sont des **403 de l'IEA et de l'OCDE**, c'est-à-dire des
  refus d'accès automatisé, pas des inexistences. Le libellé du motif (« URL inatteignable
  **ou** inexistante ») est correctement prudent ; **ne pas le durcir** en rédigeant, et ne
  pas compter ces 403 comme des inventions de modèle.
- Une entrée ACEA porte l'année **2026** : à vérifier sur pièces avant toute exploitation.
- Réserve : les rangées écrites sont des **candidats**, pas des sources qualifiées. Aucune
  n'entre au référentiel sans l'acte humain nominatif et daté du § 7.

**Clés d'API — correctif de sécurité porté au compose.** `prototype/.env` contenait trois
clés (OpenAI, Anthropic, Google) **dans le dossier du TB**, donc recopiées chaque jour vers le
Drive : exactement ce que le § 6 du protocole vague 3 interdit. Le `.gitignore` protégeait du
dépôt git, pas de la copie Drive. Le compose lit désormais `${CLES_API_FICHIER:-./.env}`,
pointé sur `~/.config/veille_tb/cles.env` — hors dossier. n8n voit les quatre clés et les
quatre identifiants de modèles, vérifié dans le conteneur. **Reste à faire par l'étudiant :
purger les trois clés de `prototype/.env`** — je ne l'ai pas fait, ne sachant pas ce qui
d'autre les lit. Sauvegarde : `docker-compose.yml.avant_cles_2026-08-22`.

**Reste à faire sur B** : capture d'écran du run dans l'interface n8n pour le ch. 11 (la
démonstration est faite en CLI, la figure ne l'est pas) ; supprimer les deux workflows
jetables `bancEssaiSQL01` et `bancGoogle01` depuis l'interface (la CLI n8n n'a pas de
commande de suppression) ; rattacher la credential Postgres à la main si le workflow est
réimporté à neuf, l'export du dépôt ne la porte pas, conformément au § 2.

**Note d'exécution** : `n8n execute --id=…` entre en conflit de port avec l'instance qui
tourne (« Task Broker's port 5679 is already in use ») et **sort en code 0 malgré l'échec**.
Lancer avec `-e N8N_RUNNERS_BROKER_PORT=5699`. Ne jamais tronquer la sortie par `tail` : elle
porte le détail par nœud, et je l'ai perdue une fois en la tronquant.

## 6 septies. Signaux qualitatifs en série — écrit le 22.08.2026, NON EXÉCUTÉ

**Décision de l'étudiant du 22.08.2026** (tracée en notes de rédaction) : face au constat que la couche interprétative est la plus mince du dispositif, l'arbitrage retenu avant le gel du 25.08 est de **passer la chaîne de signaux qualitatifs en série** — un document réel par secteur, dans la chaîne déjà démontrée sur le règlement (UE) 2023/851 (document → trois modèles → extraits source obligatoires → validation humaine → rattachement à une question de veille). C'est de l'exécution, pas du développement. Les autres options (lectures croisées SQL, instruction de S1) ne sont pas retenues à ce stade.

**Documents candidats, vérifiés par recherche le 22.08.2026.** L'inscription d'un document dans la file reste l'acte humain de l'étudiant (vérification et téléchargement du document par lui, comme pour la `composite_queue`) — ceci est une proposition instruite, pas une inscription :

| Secteur | Document | QV | Mécanisme causal (à affiner à l'inscription) |
|---|---|---|---|
| Horlogerie | Déclaration d'intention Suisse–États-Unis du 14.11.2025 et abaissement des droits de 39 % à 15 % avec effet rétroactif — communiqué officiel admin.ch (« L'abaissement des droits de douane additionnels américains entre en vigueur avec effet rétroactif ») ; contexte SECO : page « Relations commerciales Suisse – États-Unis » | QV2/QV3 | Les États-Unis sont le premier marché de destination horloger (> 4,3 mia CHF, 17 % des exportations) : le niveau tarifaire conditionne directement la demande adressée aux sous-traitants |
| Médical | Règlement (UE) 2023/607 du 15.03.2023 — prolongation des périodes de transition du MDR jusqu'à fin 2027/2028 selon la classe de risque (EUR-Lex, texte français disponible) | QV5 | Le calendrier de certification MDR conditionne le maintien sur le marché des dispositifs existants, donc le plan de charge des sous-traitants medtech ; la prolongation est un signal de desserrement réglementaire daté |
| Aérospatial | Proposition de règlement « EU Space Act », COM(2025) 335 du 25.06.2025 (sécurité, résilience, durabilité des activités spatiales ; en négociation au Parlement et au Conseil) | QV5 | Signal pré-réglementaire par excellence : exigences nouvelles (débris, cybersécurité, cycle de vie) = coûts de conformité pour les opérateurs et opportunités pour la sous-traitance de précision ; statut « proposition » à porter tel quel, sans anticiper l'adoption |
| Automobile | — déjà démontré : règlement (UE) 2023/851, objectif 2035 (§ 12.3 du rapport) | QV5 | (acquis) |

**Exécution, dans l'ordre** : (1) l'étudiant vérifie et télécharge chaque document, l'inscrit dans la file des signaux avec sa QV ; (2) la session terminal exécute la chaîne trois-modèles sur chacun ; (3) l'étudiant valide ou rejette chaque extrait (validation nominative datée) ; (4) les signaux validés apparaissent au tableau de bord. Après exécution : amender le § 12.3 (de « démontré sur un cas » à « exécuté en série sur les quatre secteurs »), reporter les modes de défaillance observés, et ne rédiger au passé que ce qui a tourné. **Butoir : gel du 25.08** — ce qui n'est pas exécuté à cette date reste au futur et la série partielle se déclare telle quelle.

## 6 octies. Étage 2 — flux, triage IA, santé sectorielle : écrit le 23.08.2026, NON EXÉCUTÉ

**Décision de l'étudiant du 22.08.2026, prioritaire sur tout le reste du § 6 : levée du gel du 25.08, priorité à la profondeur pratique.** Tracée en notes de rédaction, à ratifier (§ 7.2.2). Le § 6 septies (signaux sur 3 documents statiques) est **absorbé** par le présent chantier : les trois documents vérifiés y restent valables comme premiers items promus manuellement.

Conception : `prototype/CONCEPTION_ETAGE2.md` (à lire d'abord). Livrables prêts : migration `migrations/2026-08-23_etage2_flux.sql`, descripteurs `etage2/flux_vague_A.json`, collecteurs `etage2/collecte_flux.py`, triage `etage2/triage_ia_flux.py`. Rapport : § 10.7 créé (conception, sans surdéclaration).

**Ordre d'exécution — chaque étape laisse le dossier déposable :**

1. **Migration** (sortie → annexe 5). Attendus V1–V4 énoncés en fin de fichier ; V4 = 0 ligne de santé tant que rien n'est déclaré, c'est normal.
2. **Vague A en staging** : `python3 etage2/collecte_flux.py` — TED (3 secteurs ; CPV 34700000/34300000 **à vérifier par décompte avant activation**, méthode M7), GDELT (4 secteurs), marchés (symboles Stooq **à vérifier** ; un symbole muet se journalise et se remplace, jamais bloquant). Pièces brutes en `data/staging_flux/`.
3. **Chargement** : `--charger` (psycopg2 ; identifiants du compose). Puis qualification humaine des flux vus en réponse réelle : `UPDATE flux_sources SET statut='actif', qualified_by='N. Castillo', qualified_at=... WHERE flux_id=...` — uniquement ceux dont la réponse a été vue.
4. **Triage IA** : `python3 etage2/triage_ia_flux.py` (Gemini Flash, température 0, lots de 10). Coût attendu : centimes.
5. **Examen humain (étudiant)** : lire `v_flux_a_examiner`, décider par `INSERT INTO flux_examens` ; promouvoir 1-3 items réels par la chaîne signals existante (les 3 documents du § 6 septies comptent). Après une session d'examen : lire `v_triage_a_echantillonner` — **c'est la mesure du taux d'erreur du triage**, à reporter au rapport.
6. **Déclarations de lecture (étudiant, revue indicateur par indicateur)** : écrire `2026-08-23_declarations_lecture.sql` semant `sens_favorable` et `latence` pour les indicateurs certifiés — proposer un tableau à l'étudiant, ne rien semer sans sa revue. Puis `SELECT * FROM v_sante_secteur` : premier score de santé par secteur.
7. **Restitution** : deux ajouts à l'application (vue « Signaux » servie par `v_signaux` + items en attente en compteur ; carte « Santé des secteurs » sur `v_sante_secteur` avec le nombre d'indicateurs couverts affiché). Captures pour le ch. 11.
8. **Mesures pour la section OSINT du rapport** : volume par famille et par semaine, taux de pertinence du triage, items promus, et **valeur d'antériorité** quand un item de flux précède une statistique de l'étage 1 (l'argument décisif). Grille des 9 critères du protocole OSINT remplie par famille exécutée.

### État au 22.08.2026 (fin de journée) — étapes 1 à 4 exécutées, étapes 5 et 6 en attente de vos décisions

Pièces : `annexe_5/migration_etage2_2026-08-23.txt` (migration + tests V1–V4),
`prototype/data/collecte_flux_vagueA_2026-08-23.log`, `prototype/data/triage_ia_flux_2026-08-23.log`,
`prototype/data/staging_flux/` (pièces brutes E6),
`annexe_5/qualification_flux_vagueA_2026-08-23.md` et
`annexe_5/proposition_declarations_lecture_2026-08-23.md` (les deux décisions qui vous reviennent).

**1. Migration : passée.** V1 = 7 tables et vues, V4 = 0 ligne de santé (attendu). **V2 et V3
ont été exécutés après le chargement, pas pendant la migration** : un trigger `FOR EACH ROW` et
une contrainte à clé étrangère ne se testent pas sur des tables vides — un test sur table vide
aurait été un faux positif. Les deux refusent ce qu'ils doivent refuser, sans laisser de ligne
parasite.

**2. Vérifications préalables — deux résultats opposés.**

- **CPV TED : les deux codes sont bons, et vérifiés en intitulés, pas seulement en décompte.**
  34700000 rend « Parts for aircraft, spacecraft and helicopters » ; 34300000 rend « Parts and
  accessories for vehicles and their engines ». Le témoin de contrôle est probant : CPV 33100000
  sur juillet 2026 redonne **6 239 avis, exactement le chiffre du 20.08** — l'API et la méthode
  sont reproductibles à trois jours.
- **Stooq : bloqué, et non contournable proprement.** Le site exige désormais une vérification
  de navigateur par **preuve de travail JavaScript**. Les neuf symboles renvoient 404 sans
  en-tête de navigateur, une page de défi avec. **Le blocage porte sur la source, pas sur les
  symboles** : aucun des neuf n'a pu être ni confirmé ni infirmé. Je n'ai pas contourné le
  dispositif — le protocole OSINT impose le respect des CGU, et une lacune documentée est un
  résultat. Repli examiné et écarté : l'API *chart* de Yahoo répond 429, CGU restrictives.
  **La famille `marches_financiers` reste entière à qualifier ou à écarter.**

**3. Collecte : 176 items sur 5 flux des 11 déclarés.** TED 3/3 (115 items), GDELT 2/4
(61 items), marchés 0/4.

**4. Trois corrections portées aux collecteurs** (sauvegarde `collecte_flux.py.avant_corrections_2026-08-23`) :

1. **Clé de langue TED : `fre` → `fra`.** La clé ISO 639-2/T est `fra` ; avec `fre`, le code
   retombait silencieusement sur l'anglais. Non bloquant, mais la file de lecture et le triage
   doivent être en français — et ils le sont désormais, visiblement.
2. **Cadence GDELT.** Sans temporisation, les quatre flux échouaient tous. Paliers 20/40/60/90 s
   et pause inter-flux.
3. **Le refus de cadence de GDELT arrive sous deux formes** : un 429, et — plus traître — un
   **HTTP 200 dont le corps est le message en clair** « Please limit requests to one every
   5 seconds ». Ne tester que le code de statut laissait passer la seconde : `json()` échouait
   sur « Expecting value » et le flux était classé en échec de *format* alors qu'il s'agissait
   d'une *cadence*. Diagnostic faux, cause réelle masquée.

**`gdelt_medical` et `gdelt_aerospatial` restent non collectés** après quatre tentatives à
paliers croissants. Ce sont les deux requêtes les plus complexes du lot ; le message de GDELT
vise explicitement les « larger queries », et une requête de test simple sur le même thème
médical a répondu 200. **Piste : simplifier les requêtes plutôt qu'attendre davantage.**

**5. Triage IA : 176 scores, aucun échec, aucun lot rejoué.** Modèle `gemini-3.7-flash`,
température 0, lots de 10. Répartition : **130 items à 0, 33 à 1, 13 à 2**. Le coût n'a pas été
instrumenté — le script ne journalise pas l'usage ; à l'échelle (18 appels sur un modèle Flash)
il est de l'ordre du dixième de franc, mais **ce n'est pas une mesure, c'est une estimation**.
Ajouter la consignation de l'usage au script si la mesure doit figurer au rapport.

**Le résultat le plus exploitable de la journée — la densité de signal varie d'un facteur trente
selon le flux :**

| flux | items | pertinence 2 | taux retenu (≥ 1) |
|---|---:|---:|---:|
| `ted_aerospatial` | 15 | **7** | **67 %** |
| `gdelt_horlogerie` | 11 | 5 | 91 % |
| `ted_medical` | 50 | 1 | 24 % |
| `gdelt_automobile` | 50 | 0 | 26 % |
| `ted_automobile` | 50 | **0** | **2 %** |

`ted_automobile` **confirme sur pièces la réserve posée avant la collecte** : le CPV 34300000
capte massivement des marchés d'entretien de flottes municipales, où il n'est qu'un code
secondaire derrière 50110000 / 50100000. 49 items sur 50 notés 0. À l'inverse, `ted_aerospatial`
est le flux le plus dense du lot avec le plus petit volume. **Le volume collecté n'est pas la
valeur collectée** — c'est l'argument central de l'étage 2, et il est mesuré, pas supposé.

**Attention avant d'exploiter ce tableau** : ces taux sont des scores **IA non encore relus**.
La mesure du taux d'erreur du triage passe par `v_triage_a_echantillonner`, qui exige d'abord une
session d'examen humain (étape 5). Écrire au rapport que le triage « a retenu 26 % » serait
prendre l'IA pour l'arbitre de sa propre performance.

**Ce qui vous attend, et que je n'ai pas fait :**

- **Étape 5 — qualification des flux** : `annexe_5/qualification_flux_vagueA_2026-08-23.md`.
  Les onze flux restent `a_verifier` ; aucun statut n'a été touché.
- **Étape 6 — déclarations de lecture** : `annexe_5/proposition_declarations_lecture_2026-08-23.md`.
  Rien n'est semé. **Trois constats y sont bloquants et doivent être lus avant tout affichage** :
  1. La grille compte **26 certifiés, pas 24** — `CLAUDE.md` n'a pas suivi l'ajout de M7 et T7 le 20.08.
  2. **Neuf indicateurs seulement** passent le filtre de `v_sante_secteur` ; l'aérospatial n'aura
     **aucun score**, et trois secteurs sur quatre auront un score adossé à **un seul indicateur**.
  3. **La série de référence de la vue est fausse par construction** : « zone la plus fournie,
     départage alphabétique » retient **l'Andorre** pour H1, où 42 zones sont à égalité et où les
     marchés principaux portent quinze fois plus d'observations. Même mécanisme pour M3 (Afghanistan),
     A4, S3, S6. **La santé de l'horlogerie serait calculée sur les exportations vers l'Andorre.**
     Trois corrections possibles sont proposées ; je n'ai rien modifié.

### État au 23.08.2026 — les cinq décisions de conception appliquées

Pièces : `annexe_5/migration_geo_reference_2026-08-23.txt`,
`annexe_5/ecartement_marches_financiers_2026-08-23.txt`,
`annexe_5/alignement_descripteurs_flux_2026-08-23.txt`,
`annexe_5/revue_declarations_lecture_2026-08-23.md` et
`annexe_5/qualification_flux_2026-08-23.md` (les deux revues qui vous reviennent).

**1 et 2 — `geo_reference` déclaré, seuil d'affichage à deux indicateurs.** Migration
`2026-08-23_geo_reference.sql`. V5 : 30 indicateurs sur 30 non déclarés. V6 : `v_sante_secteur`
rend **0 ligne** — c'est l'attendu et c'est le point : la vue ne calcule plus rien tant que rien
n'est déclaré, là où l'ancienne calculait déjà, sur l'Andorre. La vue gagne une colonne `etat`
(`calcule` / `base_insuffisante`) : en dessous de deux indicateurs orientables, elle **nomme** le
cas au lieu de rendre une moyenne d'un seul terme. Note d'exécution : `CREATE OR REPLACE VIEW`
refuse d'insérer une colonne en position médiane — il a fallu un `DROP` explicite, laissé **sans
`CASCADE`** pour qu'une dépendance éventuelle fasse échouer la migration plutôt que d'être
supprimée en silence.

**Ce que la correction a révélé, et qui vaut mieux qu'un correctif** : l'agrégat mondial `W00`
existait depuis toujours dans H1 — 41 périodes, moyenne 2,52 milliards. Le code n'avait pas
manqué de données, il avait manqué d'une déclaration : il départageait **142 zones à égalité**
par ordre alphabétique. Troisième occurrence du motif après `admet_negatifs` et `sens_favorable`,
et la plus grave des trois : les deux premières portaient sur une règle de calcul, celle-ci sur
**le choix de l'objet mesuré** — un score faux se lit exactement comme un score juste.

**3 — requêtes GDELT simplifiées.** Vérifiées en réponse réelle avant inscription (médical 50
articles, aérospatial 49). Anciennes requêtes conservées dans le descripteur sous
`requete_anterieure`. **Le compromis est subi, pas choisi** : la requête précise de l'aérospatial
était meilleure, elle était refusée en permanence par la limite de cadence.

**4 — `ted_automobile_v2` au CPV affiné**, `ted_automobile` conservé en preuve avec sa note.
Analyse préalable de 250 avis sur 30 jours : sous 34300000, les pneumatiques pèsent 82 avis et
l'entretien de flottes 38. Jeu retenu : 34310000 / 34312000 / 34320000. Volume divisé par six,
intitulés enfin dans le domaine.

**Mais le raffinement n'a pas résolu le problème, et l'échec est plus instructif que ne l'aurait
été la réussite.** Le triage note 10 items sur 11 à zéro : ce sont des achats de pièces pour
**bus municipaux et pelles mécaniques**. Des pièces mécaniques, mais achetées par des exploitants
de flottes publiques, pas par l'industrie automobile. D'où le verdict, à porter à la section
OSINT :

> La famille « marchés publics » convient à l'aérospatial et au médical, où **l'acheteur public
> est le marché** (armées, agences spatiales, hôpitaux), et ne peut structurellement pas convenir
> à l'automobile, dont le marché est fait de donneurs d'ordre privés. Aucun affinement de CPV n'y
> changera rien : le défaut n'est pas dans le code, il est dans la structure du marché.

**Réserve à ne pas escamoter** : 11 items, 1 retenu. L'écart 2 % → 9 % tient à un seul item. Le
verdict s'appuie sur la **lecture des intitulés**, pas sur le taux.

**5 — famille marchés financiers écartée**, motif inscrit en base, nominatif et daté. V7 : les
quatre flux sont `ecarte`. V8 : aucun item détruit (ils n'en avaient aucun).

**Alignement base / descripteur.** `--charger` sème avec `ON CONFLICT DO NOTHING` : il crée les
nouveaux flux mais ne met pas à jour ceux qui existent. Sans correctif, la base aurait gardé les
anciens paramètres GDELT pendant que le descripteur portait les nouveaux — la divergence entre
deux sources d'une même information, précisément ce que le § 7 interdit. La migration
`2026-08-23_alignement_descripteurs_flux.sql` est **générée depuis `flux_vague_A.json`**, qui
reste la source unique ; ne pas l'éditer à la main, la regénérer.

**État de la vague A après application** : **286 items, 8 flux collectés, 286 scores de triage,
aucun échec.**

| flux | items | prio. 2 | retenu |
|---|---:|---:|---:|
| `ted_aerospatial` | 15 | 7 | 67 % |
| `gdelt_medical` | 50 | 6 | 56 % |
| `gdelt_horlogerie` | 11 | 5 | 91 % |
| `gdelt_aerospatial` | 49 | 1 | 29 % |
| `ted_medical` | 50 | 1 | 24 % |
| `gdelt_automobile` | 50 | 0 | 26 % |
| `ted_automobile_v2` | 11 | 0 | 9 % |
| `ted_automobile` (preuve) | 50 | 0 | 2 % |

**Ce qui vous attend** — deux revues, aucune écriture faite :

- `annexe_5/revue_declarations_lecture_2026-08-23.md` : les 26 triplets
  `sens_favorable` / `geo_reference` / `latence`. **Avec les déclarations proposées, seul le
  pseudo-secteur `transversal` produirait un score** ; horlogerie, médical et automobile
  tomberaient en `base_insuffisante` (un indicateur chacun), l'aérospatial serait absent. Le
  seuil de deux fait son travail — il révèle que **c'est la profondeur de série, non le nombre
  d'indicateurs, qui manque à la santé sectorielle**. Cinq cas non tranchés (A3, T2, M3, M7, S4)
  et deux choix par défaut à valider (A4, S6, sans ligne suisse ni agrégat).
- `annexe_5/qualification_flux_2026-08-23.md` : les huit flux vus en réponse réelle, et trois
  suites possibles pour l'automobile.

**Rappel de méthode** : les taux ci-dessus sont des scores IA **non relus**. La mesure du taux
d'erreur du triage passe par `v_triage_a_echantillonner`, donc par votre session d'examen —
l'IA ne juge pas sa propre pertinence.

### 23.08.2026 — chantier « signaux faibles », première étape : la doctrine de triage

**Décision de l'étudiant du 23.08 (soir)** : ne pas geler le prototype, engager le chantier des
signaux. Recommandation contraire de la session terminale (le chemin critique est le rapport,
trois semaines avant dépôt) **exprimée puis écartée** — décision d'étudiant, à joindre au § 7.2.2.

**Constat qui motive le chantier**, établi pendant la session d'examen : sur les dix premiers
items notés 2 par la doctrine « événement », sept étaient des avis d'achat isolés (dont un drone
pour la police municipale de Jelgava) et deux étaient deux dépêches sur le **même** chiffre
d'exportations horlogères de juillet — c'est-à-dire l'indicateur H1 revenant par la presse.

**Piège d'antériorité identifié au passage, et à ne pas reproduire au rapport.** H1 s'arrête à
mai 2026 en base, les dépêches parlent de juillet : la « valeur d'antériorité » définie au
`CONCEPTION_ETAGE2.md` § 4 aurait mesuré deux mois d'avance. Ce serait faux. La FH publie une
vingtaine de jours après la fin du mois et les articles datent du lendemain de la publication :
**la presse relaie la statistique, elle ne la devance pas.** L'antériorité apparente ne mesurait
que le retard de notre propre collecte. Toute mesure d'antériorité doit se faire contre la
**date de publication de la source**, jamais contre le contenu de la base.

**Ce qui a été fait** : migration `2026-08-23_triage_doctrine_signal.sql` — trois axes séparés
(`pertinence`, `anteriorite`, `portee`), colonne `doctrine` distinguant les deux passes, vues
`v_signaux_faibles` et `v_ecart_doctrines`. Les 286 scores de la première passe sont
**conservés** : on ne réécrit pas l'histoire d'une mesure. Seconde passe exécutée sur le même
corpus, même modèle, même température — **seule la question change**.

**Résultat qualitatif : le renversement fonctionne.** Le haut de file passe des achats de drones
municipaux à : homologation FDA ouvrant le marché américain (précède la montée en cadence),
tension réglementaire sur l'étiquetage de stérilisation, consultations PFAS (matière et
traitement de surface — au cœur du métier), intention ukrainienne de localiser la production
d'avions occidentaux, premier pas d'un accord de libre-échange Suisse-Chine. Ce sont des
signaux au sens propre : en amont, ambigus, sans forme d'événement.

**Résultat quantitatif : la critique initiale est partiellement INFIRMÉE, et il faut le dire.**
J'avais annoncé que la doctrine événementielle enterrait les signaux dans son rebut. C'est faux :
sur les **197 items notés 0**, **un seul** remonte dans la file des signaux faibles. Le
réordonnancement se produit dans la **bande médiane** — 17 items notés 1 par la première
doctrine sont en antériorité 2 et portée 1. Et le reproche qui tient vraiment porte sur le
**haut** de l'ancienne file : sur ses 20 items notés 2, **cinq sont en antériorité 0**, donc de
pures reprises de statistiques déjà publiées, et **un seul** atteint 2/2/2.

Formulation juste pour le rapport : la doctrine événementielle ne **manquait** pas les signaux,
elle les **noyait** — elle les classait au même rang que des transactions, et promouvait des
reprises de presse au premier rang.

**Défaut nouveau, exposé par le chantier : la déduplication ne résiste pas à la syndication.**
La file compte 35 items pour **26 événements distincts** ; 5 groupes syndiqués, dont le
communiqué Implantica en **4 exemplaires** au sommet de la file. L'empreinte est un sha256 de
l'URL : deux reprises du même communiqué sur deux sites donnent deux items, et un cas ne diffère
que par `http` / `https`. Une file de signaux faibles dont le sommet est quadruplé est dégradée.
`flux_items` étant en ajout seul, cela **ne se corrige pas en réécrivant les empreintes** : il
faut une couche de regroupement à la lecture.

**Suite du chantier, par ordre de rendement** : (1) regroupement des reprises syndiquées ;
(2) déplacement des sources vers l'amont (consultations réglementaires, communiqués de
fournisseurs, normes) ; (3) détection de récurrence entre exécutions datées — la seule qui
exploite vraiment la décision acquise « c'est l'écart entre runs qui fait la tendance ».

### 23.08.2026 — chantier signaux, étape 2 : regroupement des reprises, et deux résultats non cherchés

**Correction d'une mesure que j'avais donnée.** Un premier regroupement fait hors base triait
les mots du titre par ordre alphabétique : il a fusionné un article ukrainien sur la
localisation de production aéronautique, un article chinois sur un brevet de plaquettes de frein
et un troisième sur l'aviation légère — trois événements sans rapport. **Le décompte de
« 26 événements distincts » annoncé plus haut est faux.** Un faux regroupement est plus grave
qu'un doublon : le doublon se voit, la fusion abusive fait disparaître un signal.

Migration `2026-08-23_regroupement_reprises.sql` : fonction `cle_evenement(titre, url)`,
conservatrice à dessein — correspondance **exacte** du titre normalisé (casse, ponctuation,
espaces), caractères non latins **préservés** (pas de filtre `alnum`, dépendant de la locale, qui
effacerait le chinois et le cyrillique), repli sur l'URL normalisée sous 25 caractères. Vue
`v_signaux_faibles_groupes` : un représentant par événement, **la reprise la plus ancienne**
(c'est elle qui porte l'antériorité), avec `n_reprises` conservé — l'écho d'un événement dans
plusieurs organes est une information, pas du bruit.

**Chiffres corrects** : corpus **286 items → 264 événements distincts** (22 items redondants,
7,7 %). File des signaux faibles : **35 items → 29 événements**. 19 groupes de reprises,
étalement de 0 à 1 jour, domaines cohérents — aucune fusion abusive (contrôle V14).

**Résultat non cherché n° 1 — les deux flux TED automobile se recouvrent.** Huit des dix-neuf
groupes sont **inter-flux** : `ted_automobile` et `ted_automobile_v2` ont collecté les mêmes
avis. L'empreinte étant `sha256(flux_id, numéro d'avis)`, un même avis capté par deux flux
produit deux items. C'est attendu — les CPV affinés sont inclus dans 34300000 — mais cela
**gonfle les décomptes** de la vague A. À dire si les volumes sont cités au rapport.

**Résultat non cherché n° 2 — la reproductibilité du triage se dégrade quand la question devient
interprétative.** La syndication fournit gratuitement un test : le même titre, présenté deux fois
au même modèle, à température 0, dans deux lots différents. Sur **18 groupes à entrée
strictement identique** (titre brut rigoureusement le même) :

| Doctrine | Axes notés | Groupes divergents | Taux |
|---|---|---|---|
| `evenement` | pertinence seule | **0 / 18** | **0 %** |
| `signal` | pertinence, antériorité, portée | **3 / 18** | **17 %** |

Les trois divergences portent toutes sur l'**antériorité** (0/0 contre 1/0), l'axe le plus
interprétatif. Le mécanisme n'est pas de l'aléa : à température 0, la seule chose qui diffère
entre les deux passages est **la composition du lot de dix items** dans lequel le titre est
présenté. C'est une sensibilité au contexte, et elle se mesure.

Énoncé défendable pour le rapport : **plus la question posée au modèle est interprétative, moins
sa réponse est reproductible — à modèle, température et entrée constants.** Demander « de quoi
ça parle » est stable ; demander « est-ce que cela devance la statistique » ne l'est pas. Cela
renforce, et ne nuance pas, la doctrine du projet : l'IA propose un ordre de lecture, elle ne
décide pas — car cet ordre de lecture n'est lui-même pas parfaitement reproductible.

**Réserve** : n = 18, et le cas Implantica est exclu du décompte (deux titres bruts distincts, le
symbole ® faisant la différence). C'est un ordre de grandeur, pas une estimation statistique —
même statut épistémique que le reste du protocole.

### 23.08.2026 — chantier signaux, étape 3 : les sources amont. Le résultat le plus fort du chantier.

**Hypothèse testée** : si les signaux faibles manquent, ce n'est pas seulement la doctrine de
triage qui est en cause, c'est le choix des sources — TED donne des transactions, GDELT donne de
la presse généraliste. Les signaux se logent en amont, dans l'acte administratif et la
communication d'entreprise.

**Deux familles ajoutées, l'une prévue et jamais faite, l'autre nouvelle :**

- **`communications`** (F2 du protocole OSINT) : la conception la plaçait en vague A, mais
  **aucun descripteur ne la portait** — elle n'avait jamais été implémentée. Collecteur RSS
  ajouté. Boeing retenu.
- **`reglementaire`** (nouvelle famille, migration `2026-08-23_famille_reglementaire.sql`) :
  aucune famille existante ne couvrait **l'acte administratif qui autorise**. Or c'est là que
  se loge l'antériorité — une autorisation de mise sur le marché précède la montée en cadence,
  donc la charge d'usinage, donc toute statistique qui la constatera. `registres` visait les
  registres d'entreprises et aurait été un abus de langage. Collecteur openFDA ajouté
  (510(k) et rappels de dispositifs), **API libre et sans clé**.

**Résultat — la densité de signal par famille, sur le corpus complet (344 items) :**

| Famille | Source | Items | Antériorité moyenne | Signaux faibles | Taux |
|---|---|---:|---:|---:|---:|
| `communications` | Boeing | 5 | **1,80** | 4 | **80 %** |
| `reglementaire` | openFDA | 53 | **1,30** | 30 | **57 %** |
| `marches_publics` | TED | 126 | 0,88 | 7 | 6 % |
| `actualite` | GDELT | 160 | 0,53 | 28 | 18 % |

**openFDA rend dix fois plus de signaux faibles que TED**, sur des volumes comparables (53
contre 126). L'hypothèse est confirmée : **le problème n'était pas seulement la question posée
au modèle, c'était l'endroit où l'on regardait.** Les deux corrections se cumulent — la doctrine
a réordonné, les sources ont changé la matière.

**Réserve de taille** : `communications` compte **5 items**. À 80 % sur cinq items, ce chiffre ne
vaut rien seul — il indique une piste, il ne mesure pas. Seul `reglementaire` (n = 53) supporte
une affirmation.

**Contre-épreuve du biais de format — indispensable, et concluante.** Le risque était que le
modèle récompense le préfixe « FDA » plutôt que le contenu. Vérification sur pièces : « BUM Oil —
Bumlicious, LLC » est noté 0/0 avec le motif « hors du champ de la mécanique de précision » ;
« mdprostate — Mediaire GmbH » est noté 0/0 avec « développement logiciel sans composant
mécanique » ; une unité dentaire est à 1/0. Pendant ce temps les cupules acétabulaires, les
systèmes de fixation et les plateformes robotiques chirurgicales sont à 2/2, justifiés par des
« commandes de sous-traitance » et une « montée en cadence de production ». **La discrimination
porte sur le contenu, et sur le bon critère : la présence de composants mécaniques usinés.**

**Trois défauts d'API corrigés en chemin, tous du même genre — une erreur qui ment sur sa cause :**

1. **openFDA, encodage.** La syntaxe d'intervalle est `champ:[debut+TO+fin]`. Passée par le
   paramètre `params` de requests, le `+` est encodé en `%2B` et l'API répond **500
   SERVER_ERROR** — ce qui ressemble à une panne du service alors que c'est une faute d'appel.
   URL construite à la main désormais, avec le commentaire qui l'explique.
2. **openFDA, 404.** Une recherche sans résultat répond **404**, pas 200 avec une liste vide.
   Le traiter comme une panne ferait passer une fenêtre vide pour un flux défaillant. La fenêtre
   du 510(k) a par ailleurs été portée à 30 jours : sur 7 jours elle est vide, les décisions
   étant publiées avec retard.
3. **openFDA, format de date.** Les dates arrivent en `AAAA-MM-JJ` selon le point d'accès, et
   mon découpage supposait `AAAAMMJJ` : il produisait `2026--0-8-` et faisait échouer **tout le
   chargement** sur un message « datestyle » incompréhensible. Normalisation sur les chiffres.

**Reconnaissance négative, à conserver comme résultat** : Airbus sert bien un `/rss.xml` qui
répond 200 — mais c'est un fil de navigation de site (« Environment », « Society »), pas les
communiqués. **Un flux qui répond n'est pas pour autant un flux exploitable**, et cette
vérification ne se délègue pas au code. Safran 403, Stryker 404, Medtronic sert du HTML, Swatch
Group en délai d'attente, ACEA rend un fil vide. Sur huit fils de presse sondés, **un seul est
exploitable** — ordre de grandeur utile pour la section OSINT sur la famille F2.

**Reste au chantier** : la détection de récurrence entre exécutions datées, seule étape qui
exploite vraiment la décision acquise « c'est l'écart entre runs qui fait la tendance ».

### 23.08.2026 — chantier signaux, étape 4 : récurrence. Deux résultats négatifs et un mécanisme en attente.

**Récurrence lexicale — ÉCARTÉE, et c'est un résultat.** L'idée était séduisante : un thème
mentionné par plusieurs sources indépendantes est un signal corroboré — l'analogue exact du
recoupement multi-modèles du § 6.3. Testée deux fois, prototypée avant toute migration :

- *sur les titres bruts* : ne remonte que des noms de pays (Pologne, Espagne, Italie) et le
  vocabulaire formulaire des avis TED (« dostawa », « suministro », « pièces détachées »). Les
  titres sont en une dizaine de langues et les avis TED sont standardisés : **le lexique commun
  est celui du formulaire, pas celui du marché.**
- *sur les résumés du triage*, tous en français, restreints aux seuls signaux : à peine mieux —
  « system », « nouveau », « accord », « autoris ». **Une seule entité réelle émerge : Boeing.**

Ce n'est pas un défaut d'implémentation, c'est la nature du corpus : 344 items sur une fenêtre de
sept jours, faits d'avis d'achat et d'autorisations portant chacun sur un dispositif différent.
**Il n'y a pas de thème récurrent à trouver.** Rien n'a été migré : un mécanisme qui produit du
bruit n'entre pas en base.

**Nouveauté entre exécutions — mécanisme POSÉ, mesure IMPOSSIBLE aujourd'hui.** Migration
`2026-08-23_nouveaute_entre_runs.sql`, vue `v_nouveaute_par_run`, exacte et non lexicale
(s'appuie sur `cle_evenement()`, déjà éprouvée pour les reprises syndiquées).

Le contrôle V17 de la migration énonce lui-même la limite : **les onze flux ont été collectés à
une seule date chacun.** Les deux journées du 22 et du 23.08 ont porté sur des flux *différents*
— la seconde a ajouté `ted_automobile_v2`, GDELT médical et aérospatial, openFDA et Boeing. Sur
160 événements du 23.08, 152 sont nouveaux : c'est une comparaison de **sources**, pas de
**dates**. Le taux de nouveauté est à 100 % par construction pour tous les flux, ce qui ne veut
rien dire.

**Conséquence opérationnelle, à faire si l'étage 2 doit produire cette mesure** : relancer la
collecte des **mêmes** flux à quelques jours d'intervalle. C'est du temps calendaire, pas du
développement — quelques minutes d'exécution par jour pendant une à deux semaines. C'est la
seule étape du chantier qui ne peut pas être accélérée.

---

## Bilan du chantier des signaux faibles — ce qui est établi et ce qui ne l'est pas

**Établi, mesuré, montrable :**

| | Résultat |
|---|---|
| Doctrine de triage | Le renversement fonctionne qualitativement. Le haut de file passe des achats de drones municipaux aux homologations FDA, consultations PFAS et négociations commerciales. |
| Écart entre doctrines | La doctrine événementielle ne **manquait** pas les signaux (1 seul sur 197 items rejetés remonte) : elle les **noyait** — 5 de ses 20 items de tête sont de pures reprises de statistiques. |
| Sources amont | **openFDA rend dix fois plus de signaux faibles que TED** (57 % contre 6 %) sur des volumes comparables. Contre-épreuve du biais de format faite et concluante. |
| Reproductibilité du triage | **0 % de divergence sur la pertinence, 17 % sur l'antériorité**, à entrée strictement identique et température 0 (n = 18). Plus la question est interprétative, moins la réponse est reproductible. |
| Déduplication | 286 items → 264 événements ; les deux flux TED automobile se recouvrent sur 8 groupes. |
| Familles F2 | **Un seul fil de presse exploitable sur huit sondés.** |

**Non établi, et à ne pas rédiger au présent :**

- La récurrence thématique — testée, négative sur ce corpus.
- La nouveauté entre runs — mécanisme posé, aucune profondeur temporelle.
- Le taux d'erreur du triage — exige la session d'examen humain (`v_triage_a_echantillonner`).
- La valeur d'antériorité en jours — exige de dater la publication de la source, jamais le
  contenu de la base (piège relevé le 23.08 sur les dépêches horlogères).

**Le dispositif n'est toujours pas un détecteur de signaux faibles.** Il est devenu un collecteur
et un trieur dont on sait **où il regarde bien** (l'amont réglementaire), **où il regarde mal**
(les marchés publics automobiles), **ce qu'il reproduit** (la pertinence) et **ce qu'il ne
reproduit pas** (l'antériorité). C'est cela qui est rédigeable — et c'est plus honnête, et plus
utile au jury, qu'un tableau de bord qui afficherait des signaux sans savoir ce qu'ils valent.

### 23.08.2026 (soir) — restitution v4, indicateurs de comptage, et la fenêtre de collecte

**Restitution v4 implémentée et servie.** Quatre écrans à `http://localhost:8080`, service
nginx du compose. Trois points de lecture ajoutés à l'API (`/veille/sante`, `/veille/signaux`,
`/veille/opportunites`), lecture seule. La v3 reste atteignable sous « Itération précédente ».
Captures des quatre écrans dans `prototype/exports/captures_v4/`.

**Deux défauts que seules les captures ont révélés** — la leçon vaut d'être écrite : un build
qui passe ne prouve pas qu'un écran est juste.
1. « Seuils franchis » déroulait **194 lignes vides** : champ `a.label` inexistant (c'est
   `indicator_label`) et aucun plafond. La page faisait 19 000 pixels. Corrigé : les six
   franchissements les plus marqués, **avec le total dit en clair** — plafonner en silence
   ferait passer un extrait pour un inventaire.
2. **Tous les graphiques de l'écran 2 étaient vides** : le composant `Chart` attend
   `series={{zone: [{period, value}]}}`, je lui passais un tableau de paires.

**28 déclarations de lecture semées** (migration `2026-08-23_declarations_lecture.sql`), dont
six arbitrages explicites de l'étudiant documentés en en-tête. `v_sante_secteur` rend enfin :
**médical +0,34** (M2, M8), **transversal +0,55** (six indicateurs), trois secteurs en
`base_insuffisante` avec leur décompte. **Aucun secteur absent de l'écran.**

**Deux indicateurs de comptage créés** (M8 openFDA 510(k), S7 TED CPV 347), onze mois chacun,
run 80. **L'automobile a été explicitement écarté** alors que sa série est aussi propre :
elle contredirait le verdict mesuré du matin. Le motif est inscrit dans la migration.
Décompte : **32 indicateurs, 28 certifiés.**

#### Le résultat de méthode de la soirée : la fenêtre de collecte est une condition de validité

La fenêtre TED est passée de 7 à 30 jours (décision de l'étudiant). L'effet attendu était un
volume plus grand ; l'effet réel est **un échantillon de nature différente** :

| | fenêtre 7 jours | fenêtre 30 jours |
|---|---|---|
| Avis aérospatiaux en pertinence 2 | 7, dont **4 drones** | **17**, dont **6 marchés de pièces détachées** d'aéronefs |
| Avis médicaux en pertinence 2 | 1 | 4, tous **implants et prothèses orthopédiques** |
| Avis automobiles en pertinence 2 | 0 sur 61 | **0 sur 170** |

À sept jours, la file ne contenait presque que des acquisitions d'appareils complets — drones,
et un pour une police municipale. À trente jours apparaissent six marchés de **pièces
détachées d'aéronefs** et quatre de **prothèses orthopédiques**, c'est-à-dire exactement le
métier de la PME. Ces avis n'étaient pas moins nombreux dans la fenêtre courte : **ils n'y
étaient pas du tout.**

Conséquence à écrire au rapport, et correction partielle du verdict du matin :

> Sur un flux à faible volume, une fenêtre courte ne donne pas un échantillon plus petit, elle
> donne un **échantillon faux**. Le jugement porté le matin sur la famille « marchés publics »
> reposait sur sept jours de collecte : il **tient pour l'automobile** — trente jours confirment
> zéro avis pertinent sur 170, et le verdict « l'acheteur public n'est pas le marché
> automobile » en sort renforcé — mais il était **trop sévère pour l'aérospatial**, où la
> densité passe de 7 à 17 avis pertinents. Le dimensionnement de la fenêtre n'est pas un
> réglage technique, c'est une condition de validité du constat.

**État du corpus** : 563 items, 563 scores par doctrine, 563 en file d'examen, 86 signaux
faibles après regroupement des reprises.

**Toujours en attente de l'étudiant** : les 21 verdicts d'examen des marchés publics (quatre
groupes proposés : pièces d'aéronefs, prothèses, satellite → `contexte` ; aéronefs complets →
`écarté`), les 7 verdicts sur les autorisations FDA, et le tirage bas de dix items qui seul
permettrait de mesurer le **rappel** du triage — la précision seule ne dit rien de ce qui a
été jeté. **Aucune décision n'a été prise à sa place ; `flux_examens` reste vide.**

**Rappel du chemin critique** : dix-neuf jours avant le dépôt, et le rapport n'a pas avancé
aujourd'hui. La recommandation de geler le prototype a été exprimée puis écartée — décision
d'étudiant, à joindre au § 7.2.2.

### 23.08.2026 — LE TAUX D'ERREUR DU TRIAGE EST MESURÉ. Résultat pour le rapport.

**31 examens humains inscrits**, nominatifs et datés (N. Castillo, 23.08.2026), en deux lots
construits pour mesurer deux choses différentes :

- **Lot « haut » — 21 avis de marchés publics notés 2** par la doctrine « événement ».
  Mesure la **précision** : ce que le triage met en tête est-il bon ?
- **Lot « bas » — 10 items tirés AU HASARD** parmi les notes 0 et 1, **graine fixée à 0.2308**
  pour que le tirage soit reproductible et auditable. Mesure le **rappel** : ce que le triage
  jette méritait-il de l'être ? Sans ce second lot, l'IA serait juge de son propre tri.

**Matrice décision humaine × pertinence IA :**

| | notés 2 | notés 0 ou 1 |
|---|---:|---:|
| retenus (`contexte`) | **11** | **2** |
| écartés | **10** | **8** |

**Deux chiffres, et leurs limites dites d'emblée :**

- **Précision du haut de file : 11 sur 21, soit 52 %.** Près de la moitié de ce que le triage
  classe au premier rang est rejeté à la lecture humaine.
- **Rappel : 2 items sur 10 tirés dans le bas méritaient d'être retenus, soit 20 %.**

**Limite de comparabilité, à ne pas escamoter** : les deux lots ne portent pas sur la même
population. Le lot haut est **exhaustif** sur les marchés publics en pertinence 2 ; le lot bas
est **aléatoire toutes familles confondues**. Les deux taux ne se soustraient pas et ne
composent pas un « taux d'erreur » unique. Et n = 10 pour le bas : c'est un ordre de grandeur,
pas une estimation statistique — même statut épistémique que le reste du protocole.

#### Le résultat le plus exploitable : l'erreur du triage est SYSTÉMATIQUE, pas aléatoire

**Les dix rejets sur des items notés 2 partagent un seul et même motif : « appareil complet ».**
Six drones, quatre hélicoptères — le triage n'a pas distingué **l'acquisition d'un appareil
complet** de **la fourniture de pièces**. Dix sur dix, sans exception.

Or c'est la distinction qui fait toute la différence pour une PME de mécanique de précision :
elle fournit des pièces, elle ne vend ni drone ni hélicoptère. Et la consigne de triage ne la
mentionne nulle part — elle demande un « événement susceptible d'affecter la demande », ce que
l'achat d'un drone est effectivement, du point de vue du secteur mais non du sous-traitant.

**L'erreur n'est donc pas dans le modèle, elle est dans la consigne** — troisième fois de la
journée que le diagnostic tombe ainsi, après la doctrine événement/signal et après la fenêtre
de collecte. C'est un motif à écrire au rapport : sur des tâches contraintes, **ce qui limite
l'IA est presque toujours la question qu'on lui pose**, rarement sa capacité à y répondre.

Correctif possible, non appliqué (il changerait la mesure qu'on vient d'établir) : ajouter à la
consigne la distinction pièce/appareil complet, rejouer le triage, et **comparer les deux
passes sur le même corpus** — exactement le dispositif employé pour la doctrine signal. Ce
serait une quatrième mesure, et elle est à portée.

#### Écran « Opportunités » peuplé

**11 avis** — 7 aérospatiaux, 4 médicaux — chacun avec son acheteur nommé (Bundesamt für
Ausrüstung der Bundeswehr ×3, Estado Maior da Força Aérea, Technische Universität Berlin ×2,
CHU Amiens-Picardie, Servicio Andaluz de Salud…), son motif d'examen et son lien vers l'avis
TED officiel. **Aucune promotion en signal : les 11 lignes n'ont coûté aucun appel d'API.**
C'est la première fois que le dispositif répond à l'objectif de la séance n° 1.

#### Workflow d'extraction porté (promotions débloquées)

`extraction_signal_qualitatif.json` portait `gpt-4o`, `claude-opus-4-8` et
`gemini-pro-latest` — ce dernier renvoie 404. Portage identique à celui de la couche 0
(sauvegarde `.avant_portage_2026-08-23`), plus **une correction de sécurité** : la clé Google
voyageait **dans la chaîne de requête**, donc dans les journaux de n8n et du serveur ; elle est
passée en en-tête `x-goog-api-key`. `max_tokens` Anthropic porté de 1024 à 16000, paramètre
`temperature` retiré des trois appels. **Non exécuté à ce jour** : aucune promotion n'a encore
été demandée.

### 23.08.2026 — première promotion flux → signal, et ce qu'elle a révélé de la règle de recoupement

**37 examens humains** inscrits : 18 `contexte`, 18 `ecarte`, **1 `promu_signal`**. La chaîne
complète — collecte, triage, examen humain, extraction multi-modèles, rattachement — a tourné
de bout en bout pour la première fois.

**Item promu** : 759, autorisation FDA 510(k) **K262290**, cupule acétabulaire REMEDY POLY+PLUS
(Osteoremedies). Implant articulaire, usinage de précision.

**Item 750 (Megalodon, K261121) NON promu, et le motif est un résultat** : la FDA n'a publié
aucun résumé 510(k) pour cette autorisation — vérifié deux fois, 404 sur le motif d'URL des deux
années possibles et aucun lien PDF sur la page. Or la chaîne `signals` exige des **extraits**
recopiés d'un document. Une fiche d'enregistrement de quatre champs n'en est pas un.
**La promotion en signal suppose un document substantiel, et un acte réglementaire n'en est pas
toujours un** : le registre dit qu'un événement a eu lieu, il ne le documente pas. Limite du
raccordement étage 2 → chaîne signals, à écrire au rapport. Décision de l'étudiant : laisser
l'item non examiné et le reprendre si la FDA publie.

#### Trois extractions successives sur le même document — toutes conservées

| signal | statut | recoupement | ce qu'il documente |
|---|---|---|---|
| 3 | **rejeté** | 0,25 | **Défaut de traçabilité** : l'archive nommait `gpt-4o`, `claude-opus-4-8`, `gemini-pro-latest` — trois identifiants **écrits en dur** dans le nœud de normalisation, dont **aucun n'avait tourné**. |
| 4 | **rejeté** | 0,25 | **Exécution dégradée** : deux modèles sur trois, appel OpenAI en 429. Le score ne mesurait pas un désaccord, il mesurait une **absence**. |
| 5 | `a_valider` | 0,50 | **Première exécution nominale** : `gpt-5.6-sol`, `claude-opus-5`, `gemini-3.7-flash`, aucun incident. |

Aucun n'est supprimé : la série documente la mise au point, et l'effacer effacerait la preuve
que les contrôles ont fonctionné.

**Correctif de traçabilité porté** : l'identifiant de modèle est désormais **lu dans la réponse
de l'API** — ce que le fournisseur déclare avoir exécuté, non ce qu'on lui a demandé. Les deux
diffèrent : `gpt-5.6` répond `gpt-5.6-sol`. Sur appel en échec, l'archive porte
« (aucun — appel en échec) » et ne nomme aucun modèle. **Une pièce d'audit ne doit jamais
désigner un modèle qui n'a pas tourné.**

**Correctif de sécurité porté au même workflow** : la clé Google voyageait **dans la chaîne de
requête**, donc dans les journaux de n8n et du serveur ; passée en en-tête `x-goog-api-key`.

#### Le résultat de fond : la règle de recoupement mesure la formulation, pas l'accord

Exécution nominale du signal 5, les quatre champs :

| Champ | Retenu | Les trois réponses |
|---|:--:|---|
| `echeance` | oui | `2026-07-24` × 3, identiques |
| `acteur` | oui | « U.S. Food & Drug Administration » × 2 identiques |
| `zone` | **non** | « Commerce inter-États des États-Unis » / « États-Unis (commerce inter-États) » / « États-Unis » |
| `evenement` | **non** | « La FDA **a déterminé** que… » / « La FDA **a déterminé** que… (K262290) d'Osteoremedies » / « La FDA **établit** que… » |

**Les trois modèles sont d'accord sur le fond dans les quatre cas.** Aucun ne se trompe, aucun
n'invente. La règle en rejette pourtant la moitié, parce qu'elle exige que deux **chaînes de
caractères** coïncident — ce que trois rédactions d'un même fait ne font jamais. « a déterminé »
contre « établit » suffit à faire échouer le champ le plus important.

La règle vient du **pipeline A2**, qui extrait des **nombres** d'un communiqué ACEA : là,
l'égalité au caractère près est le bon test — 1 147 962 est 1 147 962. Transposée au **texte
libre**, elle mesure la coïncidence de formulation et non l'accord factuel, et sanctionne
d'autant plus durement que le champ est riche.

> **Le score de 0,50 n'est pas un désaccord entre modèles : c'est le taux de champs assez
> pauvres pour que trois rédactions coïncident — une date et un nom propre. C'est une mesure de
> la règle, pas des modèles.**

**La règle n'est PAS modifiée** : l'assouplir maintenant effacerait la mesure. Elle est à
rapporter avant d'être corrigée. Piste, si correction il y a : comparer les **extraits_source**
(recopies littérales du document, qui coïncident souvent) plutôt que les valeurs rédigées.

#### Cinquième occurrence du même motif dans la journée

Doctrine de triage, fenêtre de collecte, consigne de triage, règle de recoupement, et avant
elles `geo_reference` : **cinq fois, ce qui limitait le dispositif n'était ni le modèle ni le
code, mais la question posée ou l'hypothèse implicite.** C'est le fil conducteur du § 12.5.

### 23.08.2026 (nuit) — bornes glissantes et corrections d'écran

**LE DISPOSITIF PEUT ENFIN AVANCER.** Constat déclenché par une question de l'étudiant :
« si je lance les flux chaque semaine, vont-ils chercher les nouveautés ? »

- **Étage 2 (flux) : OUI depuis toujours.** Fenêtre glissante calculée à l'exécution,
  déduplication par empreinte. Mais c'est `etage2/collecte_flux.py`, **pas un workflow n8n** :
  à lancer en ligne de commande ou par cron.
- **Étage 1 (indicateurs) : NON, pour sept d'entre eux.** H1, M1, A3, M7, A4, H3, S6
  énuméraient leurs périodes en clair : relancer recollectait les mêmes mois indéfiniment.
  H1 restait à 2026-05 alors que la source publie 2026-07.

**Un diagnostic d'abord trop large, corrigé** : j'avais annoncé huit indicateurs figés. Six ne
l'étaient pas — A5, M2, T1, T2, T5, T7 portent une borne de DÉBUT ouverte (`sinceTimePeriod`,
`startPeriod`, `fromDate`) à laquelle la source répond jusqu'à son dernier point. Ils étaient
déjà glissants.

**Et trois indicateurs manqués, rattrapés par un contrôle, pas par une relecture.** A4, H3 et
S6 portent une liste d'ANNÉES seules (« 2023,2024,2025 ») que ma requête de détection ne
reconnaissait pas. Le contrôle V41 — « aucune liaison active ne doit porter de période
littérale » — en a trouvé six au lieu des trois attendues. **C'est à cela que sert un attendu
chiffré énoncé avant l'exécution.**

**Mécanisme retenu : la liaison déclare une RÈGLE, pas un littéral.** Jetons résolus à
l'exécution dans `Préparer les appels` (`collecte_generique.json`, sauvegarde
`.avant_bornes_glissantes_2026-08-23`) :
`{{MOIS_GLISSANTS:N}}`, `{{MOIS_ANNEE_COURANTE}}`, `{{ANNEES_LISTE:N}}`, `{{ANNEE_COURANTE}}`,
`{{PERIODE:k}}`, `{{MOIS_DEBUT:k}}`, `{{MOIS_FIN:k}}`. Le mois courant n'est jamais collecté
(incomplet). Résolveur **testé hors n8n sur trois dates**, dont le 1er janvier — le passage
d'année est correct. L'auditabilité est préservée : le workflow archive l'URL exacte appelée et
le corps résolu. La liaison dit « les douze derniers mois » au lieu de « ces douze mois-là ».

**Les années révolues restent figées** (H1 2023, 2024, 2025) : une période close n'a pas à
rouler, et ses bornes font légitimement partie de l'audit. Le recouvrement de douze mois avec
l'historique est voulu — il revérifie les points récents à chaque exécution.

**13 liaisons repassées en `a_verifier`** : une liaison dont les paramètres changent n'est plus
la liaison qualifiée. Réactivées par l'étudiant après vérification en réponse réelle.

#### Trois défauts d'écran, dont deux trouvés par l'étudiant en regardant

1. **Le socle transversal était vide.** Ses sept indicateurs sont rattachés à **QV0**, et mon
   écran parcourait une liste `QV1…QV5` écrite en dur. La liste est désormais lue dans
   `sector_watch_questions` — c'est le **cadre à deux niveaux** du ch. 8, cinq angles sectoriels
   pour les marchés, QV0 pour le socle. Défaut présent depuis la première capture ; je n'avais
   jamais ouvert cette page.
2. **Le titre de section n'était jamais la formulation sectorielle.** La conception l'exige
   explicitement (« c'est elle le titre, pas QV2 ») ; j'employais des noms de champs
   inexistants, d'où le repli sur « Question de veille QV1 » — sur les **cinq** pages.
   Corrigé : `question_sectorielle`, avec la criticité affichée.
3. **Le bandeau annonçait « les cinq questions »** y compris sur le socle, qui n'en a qu'une.

**Ajout de ma propre initiative, à valider** : sous les graphiques de moins de cinq points, une
mention « la ligne relie des observations, elle ne décrit pas une trajectoire ». Motivée par T4
(PIB mondial), dont trois points annuels dessinent un plateau à 3,4 % qui se lit comme une
stabilité mesurée.

**Six captures** dans `prototype/exports/captures_v4/`, dont le socle transversal.

**Motif de la journée, sixième et septième occurrences** : le socle vide et le titre manquant
sont, comme les cinq précédents, des **hypothèses écrites en dur là où la donnée était
disponible**. Le fil du § 12.5 se confirme à chaque heure.

## 6 nonies. Restitution v5 — le tableau de bord devient actionnable — 24.08.2026

**DÉCISION DE L'ÉTUDIANT du 23.08 au soir, prioritaire sur le calendrier** : « c'est cool
d'avoir la théorie mais la pratique ne donne rien ». Constat exact et assumé — le risque de
délai a été exprimé, écarté, et l'étudiant en prend explicitement la responsabilité. À joindre
au § 7.2.2.

**LE DIAGNOSTIC.** Le tableau de bord décrivait l'état des DONNÉES et non celui des MARCHÉS.
Aucun écran ne déclenchait d'action. Deux causes, et aucune n'était dans les modèles :

1. **La collecte TED ne demandait que 5 champs sur les 1832 exposés par l'API.** Manquaient :
   `notice-type` (appel OUVERT vs ATTRIBUTION déjà décidée), `deadline-receipt-tender-date-lot`
   (la date limite), `buyer-email` (l'interlocuteur), `estimated-value-lot` (l'ordre de
   grandeur). L'écran « Opportunités » présentait donc comme prospects des marchés **déjà
   attribués**, sans dire si l'on pouvait encore soumissionner.
2. **Le commentaire exécutif recevait un filtre de zones ÉCRIT EN DUR** —
   `geo IN ('WORLD','EU27','EU','CH','G20')` — qui ne contenait ni `W00`, ni `EU27_2020`, ni
   `US` : **six indicateurs sur neuf ne lui parvenaient jamais**. L'horlogerie était commentée
   sur H2 seul, un point unique de 2023. Le commentaire décrivait la base parce qu'on ne lui
   montrait rien d'autre.

### Ce qui a été construit

**Table `ted_avis` + collecteur enrichi** (`etage2/collecte_ted_enrichi.py`) : 774 avis sur
60 jours, tous avec le courriel de l'acheteur. Table séparée de `flux_items`, qui est en ajout
seul et dédupliqué — une recollecte enrichie y aurait été rejetée comme doublon.

**Lecture décisionnelle** (`etage2/lecture_decision_ted.py`, table `ted_lecture_ia`). La
question posée au modèle n'est plus « de quoi parle cet avis » — le CPV le dit mieux — mais
**« cet appel est-il exécutable par un atelier d'usinage, et que faut-il faire maintenant ? »**.
Le profil métier est déclaré en clair dans le script : c'est une hypothèse à relire, pas une
donnée. Sortie : `adressable` 0-2, `piece_concernee`, `action_proposee` à l'impératif.

**Écran « Actions »** : le tamis affiché, pas subi —
**774 avis → 341 appels → 77 encore ouverts → 3 à examiner, dont 1 au cœur du métier**. Chaque
fiche porte l'échéance en jours, l'acheteur, son courriel, la valeur estimée, la pièce
concernée, le geste à faire, et « pourquoi ? » qui déplie le motif. Les 74 écartés sont
consultables avec leur justification : écarter n'est pas cacher.

**Vue `v_acheteurs_recurrents`** : un acheteur qui publie plusieurs avis n'est pas un
événement, c'est un compte à démarcher. Aucune IA — c'est un décompte, et il était invisible.

**Commentaire exécutif refondu.** Les règles RI0–RI10 sont **conservées mot pour mot** : elles
sont la rigueur du dispositif. Ce qui change : le destinataire est nommé (dirigeant de PME
d'usinage), le format met **la réponse d'abord et la méthode en dernier**, et le modèle reçoit
le **mécanisme causal déjà déclaré** dans `sector_watch_questions` — du savoir écrit, pas une
invention. La règle « aucune recommandation de décision » devient « décris l'implication, ne
prescris rien » : l'action concrète vient de l'écran Actions, adossée à des appels d'offres
réels, jamais d'une inférence sur trois points de série.

### Ce que cela produit

Avant : « Un point de donnée est fourni pour l'horlogerie suisse, indicateur H2, valeur 57 422,
statut valide_source. »

Après, socle transversal : **« Le retrait de l'usinage européen n'est pas porté par la
conjoncture générale (QV0) : il est propre au métier, ce qui signifie une charge d'atelier
encore contrainte malgré un environnement de demande favorable. »** C'est la question
d'attribution que QV0 porte, tranchée sur les données — et c'est la phrase la plus décisive du
tableau de bord.

### Découverte non anticipée

**Les trois seuls appels adressables sont des pièces de freins FERROVIAIRES** — Roumanie
(J-9, régulateur centrifuge AR11), Hongrie (J-18, freins à tambour), Italie (J-44, pièces en
tôle pour boîtes de manœuvre, 1 508 872 EUR). **Le ferroviaire n'est dans aucun des quatre
marchés de la grille.** Le dispositif désigne un débouché qu'il ne surveille pas. À porter au
ch. 13 (perspectives) : c'est un résultat, pas un défaut.

### Deux corrections de mes propres recommandations

- **Les six « pièces détachées d'aéronefs » que j'avais fait retenir le 23.08 sont écartées** :
  ce sont des achats de pièces d'origine constructeur, de la distribution Peugeot/Nissan, de la
  maintenance MRO. On ne sous-traite pas l'usinage d'une pièce certifiée Bombardier. Mon
  jugement reposait sur l'intitulé ; une question mieux posée l'a renversé.
- **Les quatre appels DG DEFIS que j'avais signalés comme prospects** sont des **services de
  conseil**, correctement notés 0.

### Défauts corrigés en chemin, tous déjà rencontrés

| Défaut | Occurrence |
|---|---|
| `max_tokens` 1500 sur `claude-opus-5` → « réponse sans texte » | le raisonnement adaptatif s'impute dessus |
| Extraction sur `content[0].text` | **même défaut que la couche 0 la veille** |
| Étiquette de modèle écrite en dur (`claude-opus-4-8`) | **même défaut que la chaîne d'extraction la veille** — commentaires régénérés, les 5 fautifs rejetés et conservés |
| Vue `v_acheteurs_recurrents` : `unnest(cpv)` gonflait le décompte | 833 avis affichés comme 1329 |
| Vue `v_actions` : doublon quand un acheteur a plusieurs lignes | MÁV affiché deux fois |
| Analyseur de sections : ne reconnaissait que `**titre**` | le socle employait `## 1. titre`, sa carte s'affichait brute |

### État

**Cinq écrans** : Actions · Cette semaine · Secteur par QV · Radar · Opportunités. Cinq points
de lecture à l'API. Captures à jour dans `prototype/exports/captures_v4/`.

**Ce qui reste faux ou faible, et doit être dit au rapport** : trois secteurs sur quatre restent
en « base insuffisante » ; le score de santé est un écart-type affiché brut, sans échelle
lisible ; le radar tient sur deux signaux ; et le profil métier de la lecture décisionnelle est
une **hypothèse écrite par l'assistant**, à relire et à ratifier par l'étudiant — c'est elle qui
décide de tout le tri.

**Vagues B et C** (Zefix, EUROCONTROL quotidien, SIMAP, OPS brevets — clés/vérifications) : seulement après la vague A complète et mesurée. **F4 (emploi)** : ne se collecte pas — l'instruction de l'écartement (lecture des CGU, sous-section frontière légale) se fait côté Cowork.

**Règle de repli inchangée** : si le calendrier casse, on fige l'état démontré, on documente, on dépose. Le dépôt ne se négocie pas.

**Ajout du 23.08.2026 — restitution v4 (écrans de décision).** Conception dans `prototype/CONCEPTION_RESTITUTION_V4.md` : quatre écrans organisés par questions de décision (Cette semaine / Secteur par QV / Radar / Opportunités), aucune donnée ni table nouvelle — réécriture des vues de l'application React sur les sources existantes (`v_sante_secteur`, `v_signaux`, `commentaries`, `alerts`, `flux_examens`). À implémenter **après** les étapes 1-8 ci-dessus (les écrans supposent des signaux validés et des déclarations de lecture faites) et après validation de la conception par l'étudiant. Trois points de lecture à ajouter à l'API de restitution (santé, signaux, opportunités), lecture seule. Captures des quatre écrans pour le ch. 11-12.

## 6 decies. Profondeur des séries — les cinq secteurs calculent — 24.08.2026

**RÉSULTAT** : `v_sante_secteur` rend **cinq scores sur cinq**. Plus aucun secteur en
« base insuffisante ».

| Secteur | Score | Indicateurs | Avant |
|---|---:|---|---|
| horlogerie | **+1,11** | H1, H3 | base insuffisante (H1 seul) |
| médical | **+0,86** | M1, M2, M8 | +0,34 (M2, M8) |
| aérospatial | **+0,60** | S3, S6, S7 | base insuffisante (S7 seul) |
| socle transversal | +0,55 | T1, T2, T3, T5, T6, T7 | inchangé |
| **automobile** | **−0,14** | A4, A5 | base insuffisante (A5 seul) |

**L'automobile est le seul secteur sous sa base** — et c'est le premier signal négatif que le
dispositif ait jamais produit.

### La cause, et c'est une INCOMPATIBILITÉ STRUCTURELLE, pas un réglage

Le nœud de contrôles qualité portait `const FENETRE_DEBUT = '2023'`, avec pour motif de rejet
« hors fenêtre d'historique de trois ans ». C'est l'application d'une **décision acquise du
projet** (« Historique 3 ans », `CLAUDE.md`) — donc pas une négligence.

Mais `v_sante_secteur` exige **huit points**. Une série ANNUELLE ne peut en produire que trois
en trois ans. Sur 28 indicateurs certifiés, **13 sont annuels et 1 semestriel : quatorze sur
vingt-huit étaient structurellement inéligibles au score de santé** — non par manque de données
(Comtrade renvoyait 2015-2025, Our World in Data 1985-2025) mais parce que les observations
étaient décodées puis écartées par ce contrôle.

Deux règles raisonnables isolément, incompatibles ensemble. **C'est le résultat de conception le
plus important de la journée**, et il doit figurer au § 12.5.

**RÉSOLUTION APPLIQUÉE, À RATIFIER** : la fenêtre est déclarée **par périodicité**, déduite du
format de la période — `2014` pour l'annuel (douze ans, limite de périodes par requête Comtrade),
`2023` inchangé pour l'infra-annuel. Cela retient l'INTENTION de la décision (donner une base de
comparaison) plutôt que sa lettre : trois ans font 36 points sur une série mensuelle et trois sur
une annuelle. **Si l'étudiant préfère la lettre, il faut remettre une constante unique et
déclarer au rapport que le score de santé ne couvre que les indicateurs infra-annuels.** Les deux
positions se défendent ; celle-ci est appliquée et tracée.

### Deux autres corrections de bornes

- **S3 et S4** portaient `periode_min: "2023"` dans leur MAPPING : le fichier source était
  téléchargé en entier puis tronqué à la lecture. Plancher abaissé à 2010. S3 passe à 12 points ;
  **S4 reste à 3 — non résolu**, la liaison SIPRI (`xlsx_indexe`, plage `A6:CA400`) n'a pas rendu
  d'années supplémentaires. À instruire.
- **H3, M1, A4, S6** demandaient `{{ANNEES_LISTE:4}}` à Comtrade → portées à 12. Toutes à
  11 points.

### Revient sur une décision du 23.08, et le dit

A4 et S6 avaient été laissés **sans zone de référence** par l'étudiant, au motif juste qu'avec
trois points « déclarer une référence arbitraire ne gagne rien et créerait un Andorre en
puissance ». **La prémisse a changé** : ils comptent onze points sur huit et six zones. Déclarés
— A4 → `DEU` (premier exportateur de la série et premier débouché européen), S6 → `FRA`.

**Le choix S6 → FRA est le plus discutable de la journée** : les États-Unis dominent la série
(124 mrd contre 45), mais l'écosystème accessible à un sous-traitant suisse est européen
(Airbus, Safran). Il privilégie la **pertinence** sur l'**ampleur**, et l'inverse se défend. À
ratifier.

### Ce que les commentaires disent maintenant

Automobile : « **Ce marché final porteur ne se retrouve pas dans la demande adressable** :
production UE et pièces allemandes restent atones, configuration compatible avec un contenu
mécanique par véhicule en recul. »

Horlogerie : « Le point de vigilance du cadre de veille — une montée en valeur qui masquerait
l'érosion du tissu de sous-traitance — **n'est pas observable ici, faute de comparaison possible
sur l'emploi de branche**. » Le modèle dit ce qu'il ne peut pas voir.

Ces phrases n'étaient pas atteignables avant, pour une raison unique : **on ne montrait presque
rien au modèle**.

## 6 undecies. Le ferroviaire, et la lisibilité du score — 24.08.2026

### Un marché découvert par le dispositif, pas par une hypothèse

La lecture décisionnelle du 24.08 avait produit un résultat inconfortable : sur **77 appels
d'offres ouverts** dans les trois secteurs collectés (automobile, médical, aérospatial),
**trois** relevaient de l'usinage de précision. Et les trois portaient sur des **pièces de
freins ferroviaires** — Roumanie, Hongrie, Italie.

Le ferroviaire n'appartient à aucun des quatre marchés de la grille du chapitre 8. Le
dispositif n'en collectait aucun avis. Il l'a désigné quand même, par la voie la plus solide
qui soit : non pas parce qu'on l'y cherchait, mais parce qu'**il restait quand tout le reste
avait été écarté**.

Vérification avant ajout, sur réponse réelle et non sur intuition de code :

| CPV | Libellé | Avis / 60 j |
|---|---|---|
| 34600000 | Locomotives et matériel roulant | 602 |
| **34630000** | **Pièces de locomotives ou matériel ferroviaire roulant** | **381** |
| 34940000 | Équipements ferroviaires (voie, aiguilles) | 382 |

`34630000` retenu : les intitulés sont des pièces, pas de la voie ni du matériel complet.

**Résultat** — la liste adressable passe de **3 à 12 appels**. Les neuf nouveaux sont des
disques de frein divisés (Euskotren, 300 pièces), des essieux de rames de métro (Metro
Warszawska, Metropolis 98B), des composants de systèmes de portes (POLREGIO), des pièces de
pantographes et de la visserie mécanique (Trenitalia, quatre marchés). Ce sont des pièces
usinées, avec plans, tolérances et valeurs estimées de 0,87 à 4,5 mio EUR.

### Ce qui n'a PAS été décidé, et pourquoi

Le flux `ted_ferroviaire` est déclaré **`sector_code = NULL`**. Ajouter un cinquième secteur à
la grille est une décision de l'étudiant : elle touche le chapitre 8, les questions de veille
sectorielles, la validité du cadre à deux niveaux. Un assistant qui l'aurait prise en silence
aurait fait exactement ce que le § 7.2.2 interdit. Les appels s'affichent donc sous une
pastille **« hors grille · ferroviaire »**, et l'écran porte le constat en toutes lettres.

**À ratifier en supervision** : étendre la grille au ferroviaire, ou maintenir ces appels en
marge comme découverte documentée. Les deux se défendent — le second a le mérite de montrer
que le dispositif sait signaler un angle mort de son propre cadre, ce qui est une réponse
directe à la question de recherche.

### Trois défauts de lisibilité corrigés

**1. Le score de santé n'avait pas d'échelle.** « +0,6 » ne dit rien à un décideur. Le score
est un écart-type : les paliers d'usage (0,5 · 1 · 2) sont désormais affichés — une règle
graduée de −2 à +2, une aiguille, une zone grise de normalité, et la lecture en toutes lettres
(« nettement au-dessus », « dans sa norme habituelle »). Les bornes sont à l'écran, donc
contestables.

**2. La couleur surdéclarait.** L'automobile à **−0,14** s'affichait en rouge alors que le
texte la qualifiait de normale. La couleur ne s'allume plus qu'au-delà de 0,5. Peindre en
alerte un écart que l'on décrit comme normal est la même faute qu'une phrase surdéclarée : la
couleur est une affirmation.

**3. La base était affirmée, jamais tracée.** Le score se lit « écart à la base » et aucun
graphique ne dessinait cette base — le lecteur devait croire l'écart sur parole. La moyenne
mobile (`moyenne_mobile_annuelle`, déjà en base) est désormais tracée en pointillé sur chaque
mini-graphique, avec sous la courbe : nombre de points réellement moyennés, nombre attendu,
mention explicite **« moyenne partielle »** le cas échéant, et l'écart chiffré.

**Et une case vide devenue une phrase.** A1 (production mondiale de véhicules, OICA) est
certifié dans la grille mais son connecteur n'est pas en service : la carte affichait « — ».
Elle dit maintenant qu'aucune observation n'est au registre, et que l'indicateur ne contribue
donc ni au score ni à la réponse de la question de veille. Un trou déclaré vaut mieux qu'une
case vide.

### Le motif, pour la neuvième fois

Le ferroviaire est absent de la grille pour la même raison que les fenêtres étaient à trois
ans, que le socle transversal était vide, que les libellés de modèles étaient en dur : **une
hypothèse écrite à l'avance a survécu à la donnée qui la contredisait.** Ici l'hypothèse était
« les marchés cibles de CODEC sont horlogerie, médical, automobile, aérospatial » — raisonnable,
héritée du cadrage, et démentie par les seuls appels d'offres réellement usinables que le
dispositif ait trouvés. Matière directe pour le § 12.5.


## 7. Règles à respecter, non négociables

**L'annexe et le classeur ne se saisissent jamais à la main.** Ils sont produits par requête sur la base. Corriger la base, puis régénérer — jamais l'inverse. Une information saisie deux fois en deux endroits finit toujours par diverger ; c'est ce mécanisme qui avait produit quatre décomptes d'indicateurs contradictoires dans le rapport.

**La qualification d'une source est un acte humain, nominatif et daté.** Aucune liaison ne passe au statut `actif` sans que ses paramètres aient été vus en réponse réelle par l'étudiant. La contrainte `chk_binding_verifie` l'impose en base ; la pratique doit l'imposer aussi. Un assistant peut faire la reconnaissance technique ; il ne décide pas de la qualification.

**Ne jamais écrire au présent ce qui n'est pas montrable.** Test de chaque phrase, dans le code comme dans le texte : *si le jury demande de le montrer maintenant, est-ce que je peux ?* Sinon : futur, conditionnel, ou section « limites ». Un commentaire de workflow qui affirme un contrôle non implémenté est la même faute qu'une phrase de rapport surdéclarée.

**Une heure par source, pas davantage.** Au-delà, la liaison reste `a_verifier` avec une note expliquant ce qui bloque. Une lacune documentée est un résultat ; un jour perdu sur une API récalcitrante n'en est pas un.

**Conserver toutes les sorties d'exécution.** Ce sont les pièces d'annexe 5 et la preuve d'audit exigée par E6.

**Renommages non encore passés.** `annexe_A3/`, `annexe_A5/` et `generer_annexe_A1.sh` portent encore leurs anciens noms alors que le rapport et les scripts référencent déjà les nouveaux. Les `git mv` doivent précéder toute régénération — lancée avant eux, la commande de régénération de l'annexe produit un fichier vide, ce qui s'est déjà produit le 07.08.

---

## 8. Où trouver le reste

| Document | Contenu |
|---|---|
| `CLAUDE.md` | Cadrage projet, décisions acquises, terminologie |
| `prototype/PLAN_COLLECTE.md` | Paliers datés jusqu'au 25.08 |
| `prototype/RUNBOOK_WEEKEND.md` | Séquence d'exécution pas à pas |
| `prototype/RECONNAISSANCE_SOURCES_2026-08-07.md` | Détail par source, avec URL et structures |
| `prototype/RUNBOOK.md` | Journal de la mise en service du 06.08 |
| `rapport/notes_de_redaction.md` | Décisions de rédaction, points de vigilance ouverts |
| `revue_complete_2026-08-07.md` | Revue en quatre volets, douze blocages classés |
| `preparation_seance_5_2026-08-11.md` | Ordre du jour de la séance du mardi 11.08 |

## 6 duodecies. Qualification des flux — et la contrainte que rien n'exerçait — 24.08.2026

### Ce qui a été régularisé

Migration `2026-08-24_qualification_flux.sql`, sortie en `annexe_5/qualification_flux_2026-08-24.txt`.
Les douze flux restés `a_verifier` sont qualifiés au nom de **N. Castillo, 24.08.2026**, chacun
avec une note portant **ce qui a été vu en réponse réelle** — décompte, date, particularités de
transport, et réserve quand il y en a une.

| Statut | Flux |
|---|---|
| `actif` (11) | ted_medical, ted_aerospatial, ted_automobile_v2, ted_ferroviaire, fda_510k_medical, fda_rappels_medical, gdelt_automobile, gdelt_horlogerie, gdelt_medical, gdelt_aerospatial, boeing_communiques |
| `ecarte` (5) | les 4 `marches_financiers` (Stooq, écartés le 23.08) + **ted_automobile** |

**`ted_automobile` est écarté, non activé** — application littérale de votre décision du 23.08
(« l'ancien reste en preuve »). Son CPV 34300000 rendait **un avis adressable sur trente-neuf** ;
il est remplacé par `ted_automobile_v2` aux CPV affinés. Ses 250 avis restent en base et
établissent la comparaison avant/après affinage. Pour le réactiver :
`UPDATE flux_sources SET statut='actif' WHERE flux_id='ted_automobile';`

Deux réserves sont inscrites dans les notes elles-mêmes, pas seulement ici :
`gdelt_medical` et `gdelt_aerospatial` portent des **requêtes simplifiées** — la version précise
à parenthèses imbriquées est refusée durablement par le service, et la simplification laisse
passer des articles hors sujet. `ted_aerospatial` porte le constat que sa lecture décisionnelle
n'a rendu **aucun** avis adressable.

### Le défaut trouvé en régularisant, plus grave que l'omission

**Aucun collecteur ne lisait `statut`.** La colonne existait, la contrainte
`chk_flux_qualifie_trace` en exigeait la traçabilité, et la chaîne de collecte l'ignorait
entièrement. La règle du § 10.4 — aucune activation sans qualification — était donc appliquée
par la discipline de l'opérateur, jamais par le dispositif. C'est la onzième occurrence du motif
du § 12.6, dans sa variante la plus embarrassante : non pas une hypothèse fausse, mais un
**contrôle déclaré et jamais exercé**.

Corrigé dans les deux collecteurs :

- `collecte_flux.py` — lit les statuts en base, ne collecte que `actif`, et **liste explicitement
  ce qu'il a ignoré et pourquoi** plutôt que de passer en silence. Nouveau drapeau
  `--reconnaissance` : interroge une liaison non qualifiée pour en voir la réponse réelle — la
  condition même de la qualification — sans rien écrire en base.
- `collecte_ted_enrichi.py` — la requête de sélection filtre sur `statut='actif'`.

Vérifié sur exécution : `--flux ted_automobile ted_medical` collecte le second et rend
« *1 flux non collectés, faute de qualification active : ted_automobile, statut « ecarte »* » ;
le collecteur enrichi est passé de 1 083 à 833 avis, la différence étant exactement
`ted_automobile`.

Sauvegardes : `collecte_flux.py.avant_statut_2026-08-24`, `collecte_ted_enrichi.py.avant_statut_2026-08-24`.

### Reste ouvert

Le **profil métier** de `lecture_decision_ted.py` — il a motivé 74 des 77 exclusions et n'est pas
ratifié. C'est la dernière réserve du § 11.8.

## 6 terdecies. Sensibilité du profil, S4 résolu, et le dépôt qui ne reproduisait pas l'instance — 24.08.2026

### Le profil métier : mesuré, pas ratifié à l'aveugle

`prototype/etage2/sensibilite_profil.py`. Même corpus (105 appels ouverts), même modèle, même
question — **seul le profil change**. Trois profils : A référence (métier + secteurs clients +
liste d'exclusion), B élargi (métier seul), C minimal (question technique nue).

| Profil | Écartés | Périph. | Cœur | Adressables | dont ferroviaires |
|---|---|---|---|---|---|
| A_metier_declare | 93 | 11 | 1 | **12** | 9 (75 %) |
| B_elargi | 88 | 14 | 3 | 17 | 13 (76 %) |
| C_minimal | 73 | 24 | 8 | 32 | 16 (50 %) |

Accord avec A : **B 95 % binaire / 93 % exact · C 81 % / 76 %**. Et le résultat le plus
important : **emboîtement strict** — sur 210 comparaisons, *aucun* avis retenu par A n'est
écarté par B ou C. Le profil règle la sévérité, pas la nature du jugement.

**Ce que ça vous donne.** La liste d'exclusion à elle seule écarte 5 appels ; toute la mise en
situation en écarte 20. Le constat ferroviaire tient sous les trois profils. Vous pouvez donc
ratifier le profil en connaissant son coût, ou décider de l'assouplir en sachant ce que ça
rapporte.

**Ce que ça ne dit pas** : la justesse. Aucun profil n'est la vérité. A est le plus sévère des
trois — le dispositif sous-propose. Les **20 appels que la question nue retenait et que A
écarte** sont l'échantillon naturel d'un contrôle humain, à faire.

Schéma : colonne `profil` sur `ted_lecture_ia`, clé d'unicité passée au triplet
`(publication_number, modele, profil)`. **`v_actions` ET `v_lecture_a_echantillonner` ancrées
sur `profil='A_metier_declare'`** — sans quoi trois profils auraient triplé l'écran et la mesure
du triage. Décompte vérifié inchangé après migration : 105 / 12 / 1.

### S4 résolu — et la douzième occurrence du motif

`S4` passe de **3 à 12 points (2014–2025)**. L'aérospatial gagne un quatrième indicateur
éligible, score **0,60 → 0,79**.

La cause : `const FENETRE_DEBUT = '2023';` figurait **aussi** dans `collecte_xlsx_indexe.json`.
Je l'avais corrigée dans `collecte_generique.json` le 24.08 et pas là — le collecteur écartait
143 observations sans que rien ne le signale. La même hypothèse écrite deux fois n'a été
corrigée qu'une. Fenêtre désormais fonction de la périodicité dans les deux collecteurs.

### Le dépôt ne reproduisait pas l'orchestrateur — treizième occurrence

**Aucun fichier de `n8n_workflows/` ne portait d'identifiant.** Conséquence : chaque
`n8n import:workflow` créait une **copie**. L'instance contenait 5 exemplaires du commentaire
exécutif, 7 du collecteur générique, 3 du collecteur xlsx — et rien ne disait lequel
s'exécutait. J'en ai fait la démonstration involontaire : j'ai exécuté une version périmée du
commentaire, qui a produit cinq commentaires dans un format abandonné.

Deux corrections :

1. **Identifiants canoniques épinglés** dans les fichiers du dépôt — `commentaireExecV2`,
   `apiRestitutionV4`, `collecteGeneriqueV2`, `collecteXlsxIndexeV1`, `decouverteMultiIA1`,
   `A2compositeWF01`, `extractionSignalV2`. L'import est désormais idempotent.
2. **Références de credential Postgres** (`QdVRYX9pjTj9C8G3`, « postgres veille ») posées sur
   les 25 nœuds qui en manquaient. Une référence n'est **pas** un secret : le secret est la clé
   de chiffrement, qui reste dans la sauvegarde n8n, jamais versionnée. Sans elle, un import
   rendait le workflow inexécutable (« Node does not have any credentials set »).

**PIÈGE À CONNAÎTRE — l'API de restitution retombe en 404 après tout import.**

Un `import:workflow` **désactive** le workflow importé. Et la réactivation en ligne de commande
ne suffit pas :

```
n8n update:workflow --id=apiRestitutionV4 --active=true
```

pose bien le drapeau `active=1` en base, mais **n'enregistre pas les webhooks** — la table
`webhook_entity` reste vide et les cinq points de lecture répondent 404 alors que tout paraît
en ordre. Le message « restart n8n for changes to take effect » que la commande affiche n'est
pas décoratif : je l'avais d'abord pris pour tel, l'API a semblé repartir, puis elle est
retombée. La séquence complète est :

```
docker cp <fichier> veille_n8n:/tmp/w.json
docker exec veille_n8n n8n import:workflow --input=/tmp/w.json
docker exec veille_n8n n8n update:workflow --id=apiRestitutionV4 --active=true
docker compose restart n8n                     # ← INDISPENSABLE
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:5678/webhook/veille/sante
```

Diagnostic en trois secondes quand l'application affiche des écrans vides : le conteneur
`dashboard` répond 200 (la page est servie) mais les points `/webhook/veille/*` répondent 404.
C'est toujours ce défaut-là, jamais l'application.

**Autre piège** : `n8n execute` en ligne de commande échoue sur « Task Broker's port 5679 is
already in use ». Contournement vérifié — passer **les deux** variables :
`docker exec -e N8N_RUNNERS_TASK_BROKER_PORT=5693 -e N8N_RUNNERS_BROKER_PORT=5693 veille_n8n n8n execute --id <id>`

### À votre main

- **5 commentaires en attente de validation** (run 97, format correct, `claude-opus-5`). L'écran
  sert toujours ceux du run 92, qui restent exacts.
- **Doublons de workflows à supprimer** dans l'interface — je ne les supprime pas, c'est
  irréversible. Les canoniques sont les sept identifiants ci-dessus ; tout le reste, plus les
  deux bancs d'essai `bancEssaiSQL01` et `bancGoogle01`, peut partir.
- **Le profil** : ratifier, ou assouplir au vu du chiffrage ci-dessus.

## 6 quaterdecies. La confrontation B/C exécutée — 24.08.2026

### Ce qui a été fait

`prototype/scenario_c/agent_autonome.py` — portage fidèle de
`n8n_workflows/scenario_c_agent_autonome.json` : mission, message système, plafonds (25
itérations / 40 appels), jeu d'outils, passe d'auto-critique et modèle repris **mot pour mot**.
Le portage était nécessaire : les outils d'écriture appelaient `loader:8080`, service absent du
compose — même obstacle que la couche 0.

**Trois exécutions** sur la mission du protocole (automobile, 5 QV, 3 exercices). Écriture
exclusive dans le schéma `sandbox`, aucune sortie n'atteint le registre ni l'écran.

| | itérations | valeurs | commentaires | anomalies auto-critique |
|---|---|---|---|---|
| r1 | 18 | 16 | 5 | 5 sur 21 |
| r2 | 16 | 20 | 5 | 7 sur 25 |
| r3 | 13 | 16 | 5 | 3 sur 21 |

Aucune n'a atteint son plafond — l'agent a décidé seul que la mission était finie.

### Les résultats

- **Reproductibilité : 17 %.** 6 couples (indicateur, période) communs aux trois exécutions sur
  35 distincts. Les exécutions ne traitent pas les mêmes objets : r1 couvre 2021-2023, r2
  2022-2024 ; leurs indicateurs QV5 n'ont aucun rapport (émissions CO2 / bonus écologique +
  droits de douane). **C'est le résultat décisif** — un dispositif dont les objets changent ne
  peut pas produire de tendance, et la tendance est ce que le § 7 pose comme fondateur.
- **Traçabilité : 64 %** des URL citées résolvent (44-80 % selon l'exécution). Contre 100 % en B,
  où la réponse brute archivée et la source identifiée sont obligatoires au modèle de données.
- **Fidélité des commentaires : 58 %** contre 91 % en B.
- **Auditabilité : 0 % contre 100 %, par construction** — tranchée avant toute exécution.
- **Valeurs approximatives : 12 à 31 %** (« environ 13,9 millions », « ≈ 10,6 millions »).
  Impossibles en B : la colonne est numérique.
- **Un point en faveur de C, à ne pas taire** : l'agent a publié des valeurs pour **A1**
  (production mondiale OICA), indicateur certifié que B n'a jamais instrumenté faute
  d'interface programmable. L'autonomie apporte quelque chose, et sur un terrain précis :
  l'accès aux sources qui ne s'exposent pas.
- **L'auto-critique fonctionne** — 3 à 7 anomalies par exécution, surtout des commentaires
  citant des chiffres absents des valeurs. Mais elle n'a signalé **ni** les valeurs
  approximatives **ni** les exercices périmés : elle trouve ce que sa consigne énumère.

### Deux erreurs de mesure commises et consignées

Le dépouillement est une pièce d'annexe, il devait être juste :

1. **La traçabilité de B mesurée à 2 %** — le calcul testait la réponse HTTP du point d'accès de
   chaque liaison. Un point d'accès d'API refuse légitimement une requête sans paramètres. Le
   chiffre était plausible et absurde, au détriment du dispositif défendu. Redéfini : réponse
   brute archivée + source identifiée, obligatoires au modèle de données.
2. **La fidélité de B mesurée à 14 %** — le calcul ignorait les métriques que la base
   **calcule** et fournit au modèle (variation, glissement, moyenne mobile). Corrigé : 91 %.

Les deux sont consignées dans l'annexe 7 elle-même, § A7.4, comme occurrences du motif du
§ 12.6 à l'échelle d'une mesure.

### Écrit au rapport

**§ 11.9** créé, **§ 13.3** réécrit sur la mesure au lieu de la perspective, ligne du tableau
§ 11.1 passée de « spécifié, non exécuté » à « exécutée, trois répétitions », limite (1) et
travaux futurs alignés. **Annexe 7** produite par calcul (`depouiller_confrontation.py`).

### À reprendre si le temps le permet

L'espacement de 48 h du protocole n'a pas été respecté — la mesure porte sur la variabilité à
conditions figées, pas sur la stabilité dans le temps. Un second secteur donnerait de la
robustesse. Ni l'un ni l'autre n'est nécessaire pour que le résultat tienne.

## 6 quindecies. Attribution ancrée — démonstration de faisabilité — 24.08.2026

### La question posée

« Peut-on faire expliquer par un LLM la raison d'une baisse ? » Réponse instruite plutôt que
doctrinale : **oui, à condition d'ancrer**. La démonstration est faite, hors production.

### Pourquoi lever RI9 seule ne marcherait pas

La charge d'entrée du commentaire exécutif contient `metriques`, `cadre_de_veille`, `sante` —
et **aucun fait**. Retirer RI9 du prompt (une ligne) donnerait une explication puisée dans la
mémoire paramétrique du modèle : sans source, sans date, et convaincante. Pire qu'aujourd'hui.

### Ce qui a été construit

- **Migration** `2026-08-24_attribution_ancree.sql` → table `sandbox.commentaires_attribution`.
  Bac à sable, comme le scénario C : aucune sortie n'atteint la restitution.
- **Workflow** `attribution_ancree_medical.json` (id `attributionAncreeD1`), dérivé de
  `analyse_tendances_alertes.json`. **Trois différences, et trois seulement** :
  1. La requête ajoute un bloc `contexte_factuel` — signaux **validés** et items de flux versés
     au contexte par **examen humain nominatif**. Un item non examiné n'y entre pas : autoriser
     l'attribution sur de la matière que personne n'a regardée serait pire que l'interdit levé.
  2. RI9 est **remplacée, pas supprimée** — l'attribution est permise si et seulement si elle
     cite l'ancre du fait, entre crochets. Formulations imposées : « composante identifiée de »,
     « hypothèse documentée par ». Jamais une cause suffisante.
  3. Le contrôle vérifie **par calcul** que les ancres citées existent et qu'aucune phrase
     causale ne subsiste sans ancre.

### Résultat (run 98)

**7 ancres citées sur 12, 0 ancre inexistante, 0 attribution non ancrée.** Les sept ancres ont
été vérifiées à la main : toutes exactes. CTX-1631, catalogué « consommables médicaux », porte
en réalité « dostawa implantów » — le modèle a lu le polonais plutôt que l'étiquette de
catégorie.

Le modèle a **déclaré de lui-même** les mouvements sans ancre : commerce suisse, production UE,
dépenses de santé, emploi de branche.

**Comparaison, mêmes chiffres :**

| | Production (RI9) | Ancrée |
|---|---|---|
| Formulation | « compatible avec un renouvellement de générations d'instruments » | « cinq avis européens portent sur prothèses et implants [CTX-146][CTX-161][CTX-1625][CTX-1626][CTX-1631], composante identifiée du niveau d'avis observé » |
| Vérifiable ? | non | oui, ancre par ancre |

L'affirmation n'est pas devenue plus certaine — elle est devenue **réfutable**.

### Les trois bornes, écrites au § 12.3

1. **Le contrôle établit la traçabilité, pas la justesse.** Une ancre valide peut être citée à
   tort ; seul l'humain juge. J'ai vérifié les sept à la main.
2. **La couverture dépend du stock de faits.** 5 mouvements sur 9 sans ancre. L'automobile en
   aurait eu **zéro** (1 signal, 0 item en contexte). Ce stock ne se constitue qu'à l'usage —
   taux de promotion mesuré : 1 item sur 37.
3. **L'ancrage ne fait pas la causalité.** Il établit qu'un fait a eu lieu et quand.

### Ce que ça vaut pour le rapport

§ 12.3 complété. Le message n'est pas « il faut lever RI9 » mais : **l'interdit est un choix
instruit et réversible**, et le dispositif porte déjà le mécanisme qui rendrait l'attribution
réfutable le jour où le stock le justifiera. C'est une meilleure section de perspectives qu'une
promesse.

### Si vous voulez aller plus loin

Le gain marginal est dans le **stock**, pas dans le code : plus de séances d'examen versant des
items au contexte. Chaque item versé est une ancre de plus.

## 6 sexdecies. Commentaires validés, attribution ancrée à l'écran — 24.08.2026

### Validation des dix commentaires en attente

Migration `2026-08-24_validation_commentaires_97.sql`, sortie en annexe 5.

**Run 95 — REJETÉ en bloc (5), sans examen du fond.** Deux motifs suffisent : format périmé
(« Constat / Neutralisations / Lecture ») et surtout **libellé de modèle `claude-opus-4-8` écrit
en dur** dans cette version du workflow — il n'atteste pas du modèle réellement interrogé. Une
sortie dont on ne peut pas nommer l'auteur n'est pas diffusable. Conservés au registre : le rejet
est un événement, pas un effacement.

**Run 97 — VALIDÉS (5), après vérification chiffre par chiffre contre `input_payload`.** Chaque
valeur, chaque seuil, chaque mention de complétude confrontée à la charge soumise. Tout exact.
Les motifs détaillés sont dans les commentaires SQL de la migration.

**Réserve portée, sans incidence sur la validité** : l'horlogerie conclut « routine » quand la
tuile affiche « nettement au-dessus » (+1,11). Les deux lectures sont justes et n'emploient pas
la même toise — le score est un écart-type, le commentaire raisonne en seuils de matérialité.
Tension d'affichage à instruire au § 12.2.

### Attribution ancrée servie à l'écran (médical seulement)

- **Migration** `2026-08-24_attribution_ancree_validation.sql` : colonnes `validated_by`,
  `validated_at`, `note_validation` + contrainte `chk_attribution_valide_trace`. La règle
  « rien de non validé à l'écran » vaut AUSSI pour une démonstration — sans quoi le caractère
  expérimental deviendrait une porte dérobée. La contrainte l'impose, pas la consigne.
- **Validation du run 98** : les sept ancres ouvertes une à une et confrontées à leur item.
  Toutes exactes. Note de validation détaillée en base, ancre par ancre.
- **Sixième point de lecture** `/veille/attribution` sur `apiRestitutionV4`. Ne sert que les
  lignes `statut='valide'`, et compte les autres.
- **Écran** : bloc `AttributionAncree` sur la vue secteur, **distinct** du commentaire de
  production, pastille « démonstration — hors production ». Chaque ancre est un lien cliquable
  vers sa pièce ; le dépliage montre les 12 faits fournis, ceux non cités en grisé avec la
  mention « non cité ».

**Observation notable** : le seul signal validé (SIG-5, autorisation FDA d'une cupule
acétabulaire) n'a PAS été cité par le modèle. L'écran le montre. Un contexte non utilisé se
voit — il ne se devine pas.

### Ce qui reste vrai

L'attribution ancrée n'apparaît que sur le **médical**. Automobile : 1 signal, 0 item en
contexte. Horlogerie et socle : rien. Le facteur limitant est le **stock de faits examinés**,
pas le mécanisme — et ce stock se constitue à raison d'un examen humain par item.

### Piège API confirmé une deuxième fois

Après tout `import:workflow`, la séquence complète est obligatoire — y compris
`docker compose restart n8n`. La première fois, j'avais noté à tort que le redémarrage était
superflu ; l'API est retombée en 404 et l'étudiant l'a constaté avant moi.

## 6 septendecies. Analyse complète du registre — ce qui y dormait — 24.08.2026

### Le constat central

**39 604 observations, dont une large part ventilée par pays — et la restitution n'en affichait
qu'UNE par indicateur.** H1 porte 88 destinations sur 41 mois, A3 en porte 64, les flux de
commerce 6 à 11. La question de veille **QV3, « dynamique géographique »**, l'un des cinq angles
invariants du cadre du ch. 8, était posée par la grille et répondue par aucun écran, alors que
la donnée était collectée depuis le premier jour.

### Ce qui a été ajouté

| Vue / bloc | Ce qu'il apporte |
|---|---|
| `v_dynamique_geographique` | Répartition et évolution par zone. Base **12 mois glissants** pour l'infra-annuel (neutralise la saisonnalité, RI2), **exercice contre exercice** pour l'annuel. Seuil de poids 1 %, affiché. |
| `v_divergence_geographique` | Le constat **calculé**, pas rédigé. Divergence quand les signes s'opposent et que l'écart atteint 5 points. |
| Bloc QV3 (écran secteur) | Le détail par marché, avec la zone de référence signalée. |
| Bloc « effet pays » (accueil) | Le croisement inter-secteurs. |
| Valeur en jeu (écran Actions) | 12,66 mio EUR sur 6 appels, **par devise, jamais convertie**. |
| Part suisse (écran horlogerie) | L'indicateur synthétique, enfin visible. |

### Les trois trouvailles

**1. Effet pays.** Deux divergences détectées, **toutes deux sur les États-Unis** : horlogerie
(−11,3 % contre +11,6 % pour les 20 autres marchés) et dépenses militaires (−5,0 % contre
+12,7 %). Le même pays décroche sur **deux secteurs sans rapport**. Aucun indicateur pris seul ne
le montre — c'est le croisement qui le produit, et c'est exactement la fonction que le ch. 8
assigne au socle d'attribution, transposée à l'axe géographique.

**2. Part suisse du commerce mondial d'horlogerie : 48,75 % (2015) → 61,74 % (2024).** Treize
points en dix ans, sur un panier mondial qui ne grandit pas (45,8 → 47,3 Md USD). L'indicateur
était calculé depuis le 17.08 mais n'apparaissait que dans l'écran d'ensemble hérité de la v3.
**L'approfondissement des séries du 24.08 l'a par ailleurs étendu de deux à onze exercices sans
que personne le remarque** — c'est ce qui en fait un fait de structure et non une photographie.
Lecture pour le sous-traitant : un débouché qui **se concentre** n'est pas un débouché qui
grandit ; sa santé tient à celle d'un petit nombre de donneurs d'ordre.

**3. Valeur en jeu : 12,66 mio EUR** sur 6 des 12 appels adressables, plus 0,87 mio RON, et
**5 appels ne publient aucune valeur** — l'enjeu réel est supérieur à l'affiché.

### Trois erreurs commises pendant l'analyse, et corrigées

Le registre est en **ajout seul** : ces trois fautes ne se voient pas dans le résultat, seulement
dans la requête.

1. **Somme sans déduplication.** Mon premier calcul sur H1 additionnait quinze exécutions de
   chaque période : montants quinze fois trop élevés, parts de marché toutes plausibles, et
   −18,2 % pour les États-Unis au lieu de −11,3 %. `DISTINCT ON (indicateur, zone, période)
   ORDER BY run_id DESC` est obligatoire, sans exception.
2. **Grandeurs intensives sommées.** Le premier jet de la vue incluait le taux de change CHF/EUR
   et le baromètre KOF : une « part de marché » du taux de change, parfaitement calculée et
   dépourvue de sens. Restreint aux unités additives.
3. **Devises additionnées.** Les valeurs estimées des avis TED sont libellées en **huit monnaies**.
   Mon total les traitait comme des euros. Vérifié ensuite : **l'application ne commettait pas
   cette faute** — chaque montant y est affiché avec sa devise. Le défaut n'était que dans ma
   requête, mais il justifie que le bloc « valeur en jeu » n'additionne jamais entre devises.

### Point d'hygiène à traiter

**19 runs au statut `en_cours`** n'ont jamais été clôturés. Sans incidence sur les données —
`v_dernier_point` et les vues prennent le run le plus récent —, mais `v_sante_des_runs` compte
des exécutions ouvertes qui ne le sont plus. À solder par une migration.


### Correctif du 24.08 au soir — les courbes ne traçaient qu'un pays

**Reproche de l'étudiant, fondé.** J'avais établi que le registre porte 197 destinations pour
H1, j'en avais fait un **tableau de barres** sous QV3 — part et variation par marché — et j'avais
laissé les **graphiques** de chaque carte d'indicateur tracer une seule courbe, celle de la zone
de référence. Un tableau de barres répond « qui pèse combien et qui a bougé » ; il ne répond pas
« comment » ni « depuis quand », et c'est précisément ce qu'on attend d'une courbe.

Les zones étaient **déjà servies à l'écran** — 4 679 points pour H1 dans la charge `/veille/donnees`.
Elles n'étaient jamais tracées. Le correctif est purement d'affichage : une bascule sur chaque
carte d'indicateur multi-zones, entre la zone de référence (avec son repère de base) et les cinq
premiers marchés en courbes superposées.

Le repère de base disparaît en vue par marché, volontairement : la moyenne mobile est calculée
pour la zone de référence, la superposer à cinq autres courbes inviterait à une comparaison sans
objet.

**Ce que la vue rend visible et que rien d'autre ne montrait** : le pic d'avril 2025 sur la
courbe américaine des exportations horlogères, suivi d'un creux — la signature d'anticipation que
la règle RI3 décrit et que le rapport cite comme motivation fondatrice (choc douanier de 2025).
Capture : `exports/captures_v4/2e_horlogerie_par_marche.png`.

Les deux vues sont complémentaires et le restent : les barres donnent 21 marchés avec leur poids,
la courbe en donne cinq avec leur trajectoire.

## 6 octodecies. REFONTE DE LA GRILLE SUR L'ÉTAGE ADRESSABLE — 24.08.2026

Mandat de l'étudiant : refaire la grille s'il le faut, pour que le tableau de bord fasse son
vrai travail. Fait. Quatre chantiers.

### 1. La théorie, d'abord — et elle était déjà en avance sur la grille

Vérification demandée : ce qu'on allait faire correspond-il à la théorie du rapport ? **En partie
seulement, et dans le mauvais sens** : le § 5.2 nommait déjà le « taux d'utilisation des
capacités » et citait la Fédération horlogère comme source. Ni l'un ni l'autre n'était
instrumenté — la source FH est au référentiel en « certifiée » et **ne porte aucun indicateur**.

Deux sections ajoutées, plus deux prescriptions au § 6.5 :
- **§ 5.5 — la chaîne de valeur** : la demande d'un sous-traitant n'est pas le marché final ;
  trois étages, six à dix-huit mois, et le « faire ou faire faire » qui domine. Référence
  Gereffi, Humphrey & Sturgeon (2005) ajoutée à la bibliographie.
- **§ 5.6 — position cyclique contre tendance** : justifie le détendancement.

### 2. Sept indicateurs, tous vérifiés en réponse réelle avant déclaration

| Code | Indicateur | Rôle | Profondeur |
|---|---|---|---|
| A6 | Production d'équipements automobiles UE (C29.3) | demande adressable | 150 |
| H6 | Production horlogère UE (C26.52) | demande adressable | 150 |
| S8 | Production aéronautique et spatiale UE (C30.3) | demande adressable | 150 |
| T8 | Carnet de commandes de l'industrie UE | **avancé** | 151 |
| T9 | Taux d'utilisation des capacités UE | socle | 51 |
| T10 | Demande citée comme frein à la production | **avancé** | 51 |
| T11 | Production manufacturière suisse | socle | 150 |

**Grille : 39 indicateurs, 35 certifiés, 31 instrumentés.** Aucune ligne ajoutée au collecteur —
sept liaisons sur `eurostat_jsonstat`, déjà en service. C'est la modularité du § 10.6 démontrée
en acte.

**Le résultat qui compte** : en juin 2026, assemblage automobile à **106,6**, équipements à
**91,6**, usinage à **91,0**. Quinze points entre le marché final et la demande adressable, sur
une mensuelle remontant à 2014. Le commentaire du 24.08 disait « le marché final ne se retrouve
pas dans la demande adressable » sans pouvoir le montrer ; c'est mesuré.

### 3. Le score détendancé

Diagnostic chiffré : **corrélation 0,64** entre la tendance d'une série et sa contribution au
score. Le score mesurait la pente. Un secteur qui croît affichait « nettement au-dessus » pour
toujours, et **aucun retournement n'était signalable** — la fonction même d'un outil de veille.

Correction : ajustement linéaire, standardisation du **résidu**. La tendance est conservée à
côté, jamais à la place. L'ancienne vue reste sous `v_sante_secteur_brut`.

| Secteur | Ancien | Détendancé | Tendance |
|---|---|---|---|
| Médical | **1,18** | **0,18** | 0,75 |
| Aérospatial | 1,03 | 0,65 | 0,39 |
| Automobile | −0,59 | −0,41 | −0,11 |
| Horlogerie | 0,50 | 0,39 | 0,17 |
| Transversal | 0,27 | 0,35 | 0,16 |

**Mesure de la correction : la corrélation passe de 0,606 à 0,329 — divisée par deux, pas
supprimée.** Un ajustement linéaire ne retire pas la courbure. Dit tel quel au § 11.10.

### 4. L'IA remise là où elle sert

La charge du commentaire portait des libellés et des nombres. Elle porte maintenant le
**sens métier déclaré** de chaque indicateur (`description_metier`) et la **tendance longue**.
Résultat mesurable sur la sortie : le commentaire automobile écrit désormais « *l'étage des
équipementiers reste en retrait (91,6 contre 106,6 pour l'assemblage)* » et propose la donnée qui
trancherait ; le transversal lit le « faire ou faire faire » depuis le taux d'utilisation.

**Deux fournées rejetées avant d'y arriver** (runs 101-102) : la première parce que la tendance
manquait à la charge — le modèle l'a signalé lui-même —, et parce qu'il qualifiait un score de
+0,35 de « position basse ». Échelle explicitée dans la consigne, fournée 103 validée.

### Corrections techniques au passage

- **Trimestriels rejetés en silence** : Eurostat renvoie « 2026-Q3 », le registre écrit
  « 2026-T3 ». Normalisation ajoutée au contrôle qualité — sans elle, T9 et T10 ne collectaient
  rien et le rejet était muet.
- **Fenêtre infra-annuelle portée de 2023 à 2014** : le § 5.6 exige d'estimer une tendance avant
  de la retirer. Sur trois ans de mensuel, le résidu est aussi incertain que la tendance.
- **Piège du solde d'opinion déclaré** : le carnet UE s'améliore de −26,7 à −17,5, ce que le
  calcul relatif exprime en **−34,5 %**. Sur un solde qui traverse zéro, la variation relative
  inverse le sens. Consigné dans `description_metier`, seuil laissé nul pour que RI4 interdise au
  modèle de commenter la variation.

### Ce qui reste ouvert, et que je n'ai pas pu faire

- **Pas de ventilation par branche pour la Suisse** dans cette source : C25, C25.6 et C25.62 sont
  vides, seul l'agrégat manufacturier répond. T11 est un repère national, pas une mesure de
  branche.
- **L'enquête de conjoncture UE n'est pas ventilée par branche** non plus : T8/T9/T10 portent sur
  l'industrie entière. Un carnet propre aux équipementiers serait plus juste.
- **KOF n'expose publiquement que le baromètre** — les séries d'enquête par branche demandent une
  authentification.
- **La FH reste non liée.** C'est le meilleur gain restant : mensuel, en francs (donc sans biais
  de change), à J+20, avec le mix de gamme. Format PDF/communiqués, donc chaîne composite.

## 6 novendecies. La Fédération horlogère, enfin liée — 24.08.2026

### Le cas, et pourquoi il est instructif

La FH était au référentiel en **« certifiée »** depuis le 07.08 et **ne portait aucun
indicateur**. Le § 5.2 la citait nommément. Les exportations horlogères venaient de Comtrade,
en dollars, avec une corrélation au taux CHF/USD mesurée à **−0,40** : un sixième de la variance
de l'indicateur phare du secteur était du change.

### Ce qui a été construit

- **Collecteur** `prototype/collecteurs/collecte_fh_horlogerie.py`. Lit le lien du document sur
  la page d'index (le nom change à chaque parution), télécharge, extrait par
  `pdftotext -layout`, **contrôle la cohérence AVANT d'écrire**, puis écrit.
- **H7** valeur totale (mio CHF) · **H8** valeur mécanique · **H9** volume mécanique
  (milliers de pièces). 19 mois, 2025-01 à 2026-07, 57 observations.
- **Vue `v_mix_horloger`** : part mécanique en valeur, valeur moyenne d'une montre exportée,
  et les deux glissements annuels côte à côte.
- **Bloc d'écran** sur l'horlogerie, sous QV1.

**Grille : 42 indicateurs, 38 certifiés, 34 instrumentés.**

### Le résultat qui compte

Le mécanisme de QV1 horlogère porte depuis le ch. 8 un point de vigilance : *une montée en valeur
qui masquerait l'érosion du tissu de sous-traitance*. Le commentaire du 24.08 constatait ne pas
pouvoir l'observer. **Il l'est maintenant, et la réponse est l'inverse de la crainte** :
valeur mécanique **+10,6 %** sur un an, volume **+20,0 %**. La branche exporte plus de montres à
valeur unitaire plus basse — pour un atelier qui facture des pièces, c'est plus de charge.

Au dernier point : mécaniques = **85,7 % de la valeur** exportée pour **38,6 % du volume**.

### Deux enseignements de méthode

**1. L'usage différencié de l'IA, démontré et non énoncé.** Le document FH contient un TABLEAU —
extraction déterministe. Le communiqué ACEA énonce ses chiffres EN PROSE — chaîne composite
multi-modèles. Deux PDF, deux traitements opposés, une seule règle. Le dispositif porte
désormais les deux cas côte à côte, ce qui rend la doctrine du § 6.5 démontrable.

**2. La profondeur ne se télécharge pas, elle s'accumule.** La FH ne sert que le millésime
courant — vérifié, les antérieurs renvoient la page d'accueil. 19 mois disponibles, et pas un de
plus. C'est le registre en ajout seul qui gagne ici sa raison d'être.

### Deux incidents, consignés

- **Regex de nombres trop permissive** : `[\d'’  ]{2,}` admettait les espaces et fusionnait les
  colonnes deux à deux — trois valeurs lues sur six. **Le contrôle de cohérence a refusé
  l'écriture**, ce pour quoi il précède l'écriture et ne la suit pas.
- **Le connecteur est un script**, faute de `pdftotext` dans l'image de l'orchestrateur (vérifié).
  Contrainte `source_bindings_connecteur_check` étendue à `pdf_tableau_script` : le référentiel
  doit décrire la réalité, pas la commodité.

### BLOQUÉ — à votre main

**Le crédit Anthropic est épuisé.** Les commentaires n'ont pas pu être régénérés après l'ajout de
H7/H8/H9. Conséquence à connaître : le commentaire horloger affiché (run 103) écrit encore que
« le tissu de sous-traitance n'est observé qu'au point 2023, alors qu'il peut s'éroder sans que
la valeur exportée le montre » — **ce qui est devenu FAUX**, H9 l'observe désormais. Rechargez,
puis :

```
docker exec -e N8N_RUNNERS_TASK_BROKER_PORT=5720 -e N8N_RUNNERS_BROKER_PORT=5720 \
  veille_n8n n8n execute --id commentaireExecV2
```

puis relire et valider la fournée.

### Commentaires régénérés sur la grille refondue — fournée 109, validée

Après recharge du crédit d'API. **Première fournée rédigée sur les 42 indicateurs**, avec le
score détendancé, le sens métier déclaré de chaque indicateur, et les séries de la Fédération
horlogère.

**Run 108 rejeté** : quatre appels sur cinq en échec de crédit — la recharge n'était pas encore
propagée. Le cinquième reste au registre, non servi.

**Run 109 validé (5/5)**, après vérification chiffre par chiffre : H7 2 522,7 mio CHF et
+9,78 %, H8 +10,55 %, H9 +20,00 % ; H6 +1,02 % pour un seuil de 6, H1 +6,06 % pour 25, H3
+5,73 % pour 10 — les trois derniers correctement déclarés non significatifs. A6 91,6 / −5,18 %,
A5 106,6 / −2,29 %. Tout exact.

**Ce que la fournée corrige, et qui compte.** Le commentaire horloger du run 103 écrivait que
« le tissu de sous-traitance n'est observé qu'au point 2023, alors qu'il peut s'éroder sans que
la valeur exportée le montre ». Vrai à sa date, **devenu faux** avec H9. La fournée 109 le lit
correctement :

> *Le volume mécanique croît plus vite que la valeur : la hausse n'est pas qu'une montée en
> gamme, elle porte sur des pièces réellement produites, donc sur de la charge d'usinage à
> tolérances serrées, transmise à la sous-traitance avec quelques mois de décalage.*

C'est la réponse au point de vigilance que le mécanisme de QV1 porte depuis le chapitre 8 — et
elle **contredit la crainte qu'il énonçait**. Le commentaire conserve par ailleurs la réserve
juste : « l'érosion éventuelle du tissu reste invisible », l'emploi de branche n'ayant toujours
qu'un point.

**Score horloger : 0,39 → 1,14** (six indicateurs orientés au lieu de trois), cohérent avec le
texte qui parle d'un débouché « nettement au-dessus de sa norme ».

Le commentaire automobile lit désormais la chaîne de bout en bout : *« la demande adressable se
tient à un étage plus bas que le marché final… la progression des VE est compatible avec une
recomposition des familles de pièces plutôt qu'avec un gain de volume mécanique par véhicule »*,
avec les données qui trancheraient (flux SH 8708 en volume, production par zone).

## 6 vicies. Élagage du score — « n'y a-t-il pas trop d'indicateurs ? » — 24.08.2026

### La réponse mesurée n'est pas celle attendue

Quarante-deux indicateurs, ce n'est pas trop. Ce qui l'était, c'est que **trois d'entre eux
pesaient sur le score sans y avoir droit**. Aucun indicateur n'est supprimé — la grille décrit ce
que le dispositif est *conçu* pour suivre, et l'élaguer effacerait la trace de ce qui a été
considéré. Ce qui leur est retiré, c'est leur **droit de vote** : `sens_favorable = 0`. Ils
restent collectés, affichés, rattachés à leur question de veille.

### Les trois retirés du score

| Ind. | Contribution | Motif |
|---|---|---|
| **H8** | +1,78 | **r = 0,993** avec H7 sur résidus détendancés. C'est la même série — 85,7 % de H7, même tableau, même document. |
| **H9** | +2,22 | r = 0,910 avec H7. |
| **S3** | **+1,98** | La plus forte contribution de toute la grille, pour une série qui compte des **lancements de satellites**. Un atelier suisse n'en usine pas. |

**Effet mesuré :** horlogerie **1,14 → 0,72** (quatre indicateurs indépendants au lieu de six),
aérospatial **0,65 → 0,32**.

**Le cas H7/H8/H9 est une faute que j'ai commise le jour même**, en liant la FH. Trois séries du
même tableau introduites d'un coup dans le score : trois voix pour une seule mesure. C'est ce qui
avait fait bondir l'horlogerie de 0,39 à 1,14 en début d'après-midi. H8 et H9 gardent tout leur
intérêt là où il est réel — la vue `v_mix_horloger`, qui lit leur **rapport** et non leur niveau.

### Ce qui n'est PAS retiré, et pourquoi c'est important

**T8, T9, T10 et T1 contribuent entre −0,10 et +0,03, c'est-à-dire rien.** Ce n'est pas une raison
de les retirer : un indicateur avancé à sa norme dit *que rien ne se prépare*, ce qui est une
information. Ne garder que les indicateurs qui bougent reviendrait à ne conserver que ceux qui
crient — l'inverse exact d'un dispositif de veille.

**A5 et A6 co-varient à 0,97 sur résidus et restent tous deux au score.** Leur redondance est
**économique** — même cycle industriel — et non **arithmétique** comme celle de H7/H8. Les
séparer ferait tomber l'automobile à deux indicateurs, le minimum de calculabilité.
**Limite déclarée** : le score automobile repose sur deux indices de production qui bougent
ensemble.

### Deux annotations plutôt que deux suppressions

**M3, M4, H2** (un seul point chacun) et **T4** (trois points semestriels, valeur inchangée à
3,4 %, jamais entré dans le score) sont **annotés en base** : leur inactivité est désormais une
limite déclarée dans `description_metier`, lisible à l'écran et à l'annexe 1, et non un oubli
qu'il faudrait deviner.

### La distinction méthodologique à retenir

Le premier test de redondance, sur les séries brutes, donnait seize paires au-dessus de 0,75 —
et il était **faux** : sur des séries tendancielles, tout corrèle avec tout. Seul le test sur les
**résidus détendancés** distingue une vraie redondance d'une tendance partagée. C'est la même
correction que celle appliquée au score lui-même (§ 5.6), transposée au diagnostic.

Commentaires régénérés (run 110) et validés après élagage.

## 6 unvicies. Combler les vides — recherche de sources — 25.08.2026

### Les vides, mesurés d'abord

Audit de couverture : onze couples secteur/question avec un indicateur ou moins. Les plus graves,
de criticité **dominante** :

| Secteur | QV | État avant |
|---|---|---|
| médical | QV4 dynamique technologique | 1 indicateur avec données |
| automobile | QV4 | 1 (A3, ventes de VE — le *résultat*, pas la décision) |
| aérospatial | QV4 | **0** |
| aérospatial | QV1 | 1 (S1 déclaré, jamais collecté) |
| automobile | QV5 | 0 indicateur |

### Ce qui a été mis en place

**Brevets par domaine technologique — OCDE, API SDMX, sans clé.** Le dispositif interrogeait déjà
l'OCDE pour T1 : aucun connecteur nouveau. Vérifié en réponse réelle : 13 points annuels
(2010-2022), 6 zones dont la Suisse.

- **M6** — technologie médicale. **Changement de source** : déclaré sur l'OMPI depuis le 06.08 et
  jamais collecté, faute de point d'accès programmable libre chez ce producteur.
  CHE 689,4 · DEU 1 093 · USA 4 381 (2022).
- **A7** — technologies de transport bas carbone, **nouveau**. QV4 automobile demande si
  l'électrification recompose la demande de composants ; A3 mesure les *ventes* de VE, soit le
  résultat plusieurs années après la décision technique. A7 mesure la décision au moment où elle
  est prise. DEU 132,8 · CHE 35,0 (2022).

**Grille : 43 indicateurs, 39 certifiés.** QV4 passe de 1 à 2 indicateurs pour l'automobile et
le médical, tous deux de criticité dominante.

### Deux décisions de méthode

**Les deux sont HORS SCORE (`sens_favorable = 0`), par construction et non par élagage.** Dernier
point 2022 : une position cyclique calculée en 2026 sur une série qui s'arrête quatre ans plus
tôt figerait le secteur sur un état périmé. Ils répondent à QV4 — horizon pluriannuel — et à elle
seule. Seuil de matérialité laissé nul, ce qui rend RI4 inapplicable et interdit au modèle de
commenter leurs variations.

**Valeurs fractionnaires assumées** : l'OCDE attribue les brevets co-déposés au prorata des
déposants. 689,4 n'est pas un artefact, c'est la convention du producteur.

### Incident consigné

La clé SDMX portait **douze segments au lieu de onze** — un point de trop après la liste de
zones. Le service répondait 404 et le collecteur l'a consigné comme tel, sans écrire. Corrigé.

### Ce que je n'ai PAS trouvé, et qu'il faut dire

- **Aérospatial QV4** (ruptures techniques : lanceurs réutilisables, constellations) : aucun
  domaine aérospatial dans la nomenclature OCDE. Reste à zéro indicateur.
- **Horlogerie QV4** (montre connectée, matériaux) : H4 visait la classe CIB G04, que l'OCDE
  n'expose pas. L'**Open Patent Services de l'OEB** le permettrait — recherche par code CPC — mais
  exige une inscription et une clé OAuth. Noté en perspective, non retenu ici.
- **Automobile QV5** (décisions réglementaires) : **ce n'est pas un vide à combler.** Le § 8.4.5
  l'a établi — les impulsions publiques automobiles sont des actes réglementaires, non des séries.
  La couche de signaux qualitatifs les traite déjà : le signal 1 du dispositif est le règlement
  (UE) 2023/851, rattaché à automobile/QV5. Un indicateur chiffré y serait une erreur de nature.
- **Airbus, carnets et livraisons** (aérospatial QV1, S1 jamais collecté) : la source est
  accessible — classeur mensuel, motif `xlsx_indexe` déjà en service, robots.txt vérifié et
  permissif pour un agent générique. **Non implémenté faute de temps** : la feuille « Historical
  Deliveries » empile des blocs annuels plutôt qu'une table, ce qui demande un analyseur propre.
  C'est le meilleur gain restant, et il est instruit.


## 6 duovicies. Le portail de l'OEB, et une piste abandonnée — 25.08.2026

### Ce qui a été cherché, et n'a pas abouti

L'Open Patent Services de l'Office européen des brevets aurait comblé les deux derniers vides
QV4 : l'horlogerie par la classe **CIB G04**, l'aérospatial par **B64**. Le portail
d'inscription n'a pas délivré de compte à l'étudiant.

### L'alternative examinée, essayée, puis ABANDONNÉE

L'OMPI publie une archive de comptages de brevets par domaine technologique, en téléchargement
direct et sans inscription. Elle a été implémentée puis **retirée le jour même, sur décision de
l'étudiant, et la décision est juste** : elle ne comblait pas le vide qu'elle visait.

La table de concordance officielle, consultée le 25.08, place la **CIB G04** (horlogerie) dans le
domaine « Techniques de mesure » et la **CIB B64** (aéronefs) dans « Transport ». L'OMPI classe en
35 domaines, l'OEB en milliers de codes : c'est une différence de nature. Elle apportait autre
chose — les brevets du métier lui-même — mais **ajouter à côté d'un vide ne le comble pas**, et
la grille n'a pas à porter une réponse à une question qui n'a pas été posée.

### Ce que le retrait a révélé, et qui vaut d'être noté

La suppression des 322 observations déjà écrites a été **refusée par la base** :

> `Le registre des valeurs est en ajout seul (D-18). Pour corriger une valeur, ajoutez-la dans un
> nouveau run : la correction fait partie de l'historique, elle ne l'efface pas.`

La clé étrangère a ensuite bloqué la suppression des indicateurs. La contrainte a fait exactement
ce pour quoi elle existe — et le contournement (désactiver le déclencheur) n'a pas été employé :
ce serait violer la décision D-18 pour effacer une erreur de quelques heures.

**Le retrait s'est donc fait par déclassement** : liaisons supprimées, donc plus aucune collecte ;
statut passé à `restreint`, donc hors grille certifiée et hors décomptes ; les 322 observations
restent au registre, comme D-18 l'exige. C'est une illustration utile pour le rapport : la base
a protégé la trace contre un retrait hâtif, y compris le mien.

### Ce qui reste ouvert

**Les vides QV4 horlogerie et aérospatial ne sont pas comblés**, et aucune source d'accès libre
ne les comble à la granularité requise. Il faut la clé de l'OEB. Les deux variables sont prêtes
dans `~/.config/veille_tb/cles.env` (`EPO_OPS_KEY`, `EPO_OPS_SECRET`) si le portail finit par
fonctionner.

Ce qui EST comblé, et reste en place : **QV4 médical (M6) et QV4 automobile (A7)**, tous deux de
criticité dominante, par les brevets de l'OCDE — API SDMX sans clé, sur un connecteur déjà en
service.

**Grille : 45 indicateurs déclarés, 39 certifiés** (T12 et T13 comptent au total mais plus aux
certifiés).

## 6 tervicies. TOUT SE COLLECTE PAR L'ORCHESTRATEUR — 25.08.2026

Exigence de l'étudiant : *dans trois mois, déployer les flux doit suffire à mettre à jour tous
les indicateurs.* Auditée, portée, vérifiée de bout en bout. Document de référence :
**`prototype/DEPLOIEMENT.md`**.

### L'audit d'abord

Sur 36 indicateurs instrumentés, **33 passaient déjà par l'orchestrateur**. Trois non — plus tout
l'étage 2, entièrement en scripts. Et deux défauts silencieux :

- **M7 ne collectait plus depuis le run 78.** Ses sept liaisons étaient restées au statut
  `a_verifier`, donc invisibles de la vue des liaisons actives. **Rien ne le signalait** : un
  indicateur qui ne collecte plus ressemble exactement à un indicateur dont la source n'a rien
  publié. C'est la contrepartie du garde-fou — la règle « pas d'activation sans qualification »
  protège contre la collecte non qualifiée, et silencieusement contre la collecte tout court.
- **`flux_sources` n'était semée nulle part** ailleurs que par un script. Un déploiement neuf
  serait parti avec une table vide, sans erreur.

### Sept workflows nouveaux ou portés

| Workflow | Remplace | Ce qu'il alimente |
|---|---|---|
| `collecteFhV1` | `collecte_fh_horlogerie.py` | H7, H8, H9 |
| `collecteFluxV1` | `collecte_flux.py` | `flux_items`, quatre familles |
| `tedEnrichiV1` | `collecte_ted_enrichi.py` | `ted_avis`, quatorze champs |
| `triageFluxV1` | `triage_ia_flux.py` | `flux_triage_ia`, deux doctrines |
| `lectureDecisionV1` | `lecture_decision_ted.py` | `ted_lecture_ia` |
| `veilleAceaV1` | `veille_acea_A2.py` | `composite_queue` |
| (liaisons) | `collecte_comptages.py` | S7, M8 par le collecteur générique |

**Chaîne complète rejouée en 2 min 16 s**, workflows seuls : 6 610 observations sur 30
indicateurs, 173 sur 2, 57 sur 3, 835 avis enrichis, 400 scores de triage.

### Ce qui a demandé de l'invention

**Le PDF de la Fédération horlogère.** Le nœud de lecture PDF de l'orchestrateur ne préserve
**pas** l'alignement des colonnes — vérifié en réponse réelle, un découpage par lignes ne rend que
deux ou trois valeurs sur six. Mais les nombres restent dans le BON ORDRE : l'analyse se fait donc
**en flux de jetons**, dès qu'un libellé de mois apparaît les six nombres suivants sont ses
colonnes. Résultat identique au script, contrôle de cohérence à 0,00 %.

**openFDA.** Deux extensions au collecteur générique : les jetons sont désormais résolus **dans
l'URL de base** (le signe + de `+TO+` ne doit pas être encodé, ce qui interdit de passer les
bornes en paramètres), et un mode `somme_champ` additionne une liste de comptages quotidiens.

### Trois défauts que j'ai introduits, et ce qu'ils enseignent

**1. L'empreinte de déduplication.** J'avais remplacé le condensé SHA-256 du script par un
condensé maison, au motif — FAUX — que les nœuds Code n'exposent pas `crypto`. Vérifié après
coup : `require('crypto')` y fonctionne. Conséquence : les 663 items déjà au registre ont reçu de
nouvelles empreintes, la déduplication n'a plus rien reconnu, et **509 lignes ont été écrites dont
390 sont des redites**. Le workflow annonçait « 1 item nouveau » pendant qu'il en insérait cinq
cents — le bilan portait sur les seuls items du dernier appel. **Empreinte SHA-256 rétablie.**

**TRANCHÉ LE 25.08.2026 — réparation exécutée sur décision de l'étudiant.** Les 509 lignes
étaient identifiables par `length(empreinte) <> 64`. Trois options avaient été exposées : ne rien
faire (file polluée de 391 redites), tout supprimer (perte de 118 items réels), ne supprimer que
les redites. La troisième a été retenue. Deux migrations, chacune en une transaction :

- `2026-08-25_retrait_redites_flux.sql` — **391 items retirés** (ceux dont l'URL, ou le titre à
  défaut d'URL, existe déjà avec une empreinte SHA-256 correcte) et **303 scores de triage**
  rattachés à eux. Les 118 items authentiquement nouveaux sont conservés.
- `2026-08-25_reparation_empreintes_flux.sql` — **empreintes des 118 recalculées** au SHA-256 que
  le collecteur corrigé produira, l'identifiant naturel étant relu dans le `payload` (numéro
  d'avis TED, URL GDELT, `champ_id` openFDA). Sans cela, le prochain passage ne les aurait pas
  reconnus et la fournée aurait été à nettoyer à chaque exécution.

**Sur la suspension de D-18.** Les deux migrations désarment `trg_flux_ajout_seul` le temps de
leur transaction, le réarment avant `COMMIT`, et **annulent tout si le réarmement échoue**. Chacune
vérifie son périmètre avant d'écrire (391 et 118 exactement, sinon exception) et refuse d'agir sur
un décompte inattendu. Ce n'est pas une réécriture de l'historique de collecte : aucune observation
réelle n'est perdue, les lignes retirées ont chacune un jumeau exact resté en base, et les
**391 lignes supprimées sont archivées avant suppression** dans
`annexe_5/redites_flux_supprimees_2026-08-25.csv`. La lettre de D-18 est levée ; son esprit — la
suppression reste vérifiable sur pièce — est tenu. La décision de lever est celle de l'étudiant,
prise après exposé des options ; je ne l'ai pas prise seul, pas même pour réparer ma propre faute.

**Vérifié sur pièce après réparation** : 781 items, 781 empreintes SHA-256, 781 distinctes. Puis
`collecteFluxV1` **rejoué** : le registre passe de 781 à **782**, un seul item réellement nouveau.
La déduplication reconnaît de nouveau le registre. Ce contrôle par le registre est le seul qui
vaille ici : le bilan du workflow annonçait déjà « 1 item nouveau » au moment où il en insérait
509, parce qu'il ne comptait que les items du dernier appel.

**2. Deux branches convergentes.** Les appels POST et GET arrivaient sur le même nœud de
normalisation, qui s'exécutait deux fois — la sortie de la première branche écrasée par la
seconde. Les quatre flux de marchés publics n'apparaissaient pas au bilan. Corrigé par un nœud de
fusion explicite.

**3. Un run ouvert à chaque rejeu à vide.** Les workflows ouvraient leur run AVANT de savoir s'il
y avait matière, puis levaient une exception quand il n'y en avait pas — interrompant le workflow
avant sa clôture. **Rien à traiter est le cas nominal d'un dispositif rejoué**, pas une erreur.
Le garde est désormais placé avant l'ouverture : un run qui n'a rien fait n'existe pas. Les
**39 exécutions restées ouvertes** ont été soldées en `echec` avec leur motif, jamais supprimées.

### Ce qui reste en script, et n'a pas à être automatisé

Aucun de ces fichiers n'alimente le tableau de bord : `exports/` (annexes et classeur, à la
demande), `scenario_c/` (artefact de laboratoire de la confrontation B/C, écrit en schéma séparé),
`etage2/sensibilite_profil.py` (mesure du § 11.8, exécutée une fois et publiée).

### Ce qui reste un acte HUMAIN, par doctrine et non par lacune

Qualification d'une source · validation des commentaires · examen des items de flux · validation
des extractions composites. Détaillé dans `DEPLOIEMENT.md`, § « Ce qui reste un acte humain ».

---

## 25.08.2026 — La base était-elle reconstructible ? Non. Elle l'est.

Question posée : *« est-ce que tout se collecte automatiquement, rien d'artisanal ni qui ne
fonctionne que maintenant ? »* Vérifié plutôt qu'affirmé. Deux réponses, opposées.

### Ce qui allait bien : la collecte

Sur les 43 indicateurs de la grille (hors T12/T13 abandonnés), **35 sont collectés par un
workflow n8n**, sans aucune intervention : 30 par `collecteGeneriqueV2` (run 132, 6 610
observations), 2 par `collecteXlsxIndexeV1` (run 133), 3 par `collecteFhV1` (run 134). Les huit
autres ne collectent pas, et chacun pour un motif connu :

| | Motif |
|---|---|
| A2 | Composite ACEA — alimenté par `composite_queue`, pas par une liaison. Doctrine, pas lacune. |
| A1, H4, S1 | Certifiés mais sans source liée. H4 attend un accès OEB (portail OPS hors service) ; S1 est à requalifier en composite. |
| H5, M5, S2, S5 | Statut `a_confirmer` — jamais qualifiés. |

**Un seul script Python subsiste dans la chaîne : aucun.** `etage2/sensibilite_profil.py`,
`exports/` et `scenario_c/` n'alimentent rien.

### Ce qui n'allait pas du tout : la base elle-même

**La base n'était pas reconstructible depuis le dépôt.** Elle ne tenait que par l'état accumulé
dans le conteneur en service. Trois défauts, tous vérifiés sur pièce le 25.08 :

1. **`DEPLOIEMENT.md` affirmait que les migrations créent le schéma.** Faux. Le schéma venait de
   `db/`, monté en `docker-entrypoint-initdb.d` et joué par PostgreSQL au premier démarrage.
2. **`schema.sql` à la racine était du SQLite** (`AUTOINCREMENT`) — vestige d'avant la bascule
   vers PostgreSQL du 04.08, laissé là où un lecteur pressé irait le chercher en premier.
   Déplacé en `db_origine_2026-08-04/00_schema_sqlite_perime.sql`.
3. **Le rejeu des 78 migrations sur base neuve échoue.** Essayé, mesuré : 69 passent, 9 non.
   Trois causes, dont une insoluble par simple réordonnancement — `2026-08-24_lecture_decision.sql`
   crée une vue qui référence une colonne ajoutée par `2026-08-24_profil_lecture.sql`, laquelle
   a besoin d'une table créée par la première. Dépendance circulaire. S'y ajoutent des migrations
   de données qui présupposent des observations collectées (`promotion_759`, et mes deux
   migrations de réparation des flux), et des migrations rendues caduques par le socle.

### Ce qui a été fait

**Socle consolidé.** `db/01_socle.sql` (structure : 22 tables, 31 vues, 3 déclencheurs, les
contraintes métier avec leurs `COMMENT ON`) et `db/02_referentiel.sql` (43 indicateurs,
75 liaisons dont 71 actives, 16 flux qualifiés, 27 sources, les questions de veille des deux
niveaux). Aucune observation : une base neuve est vide, ce sont les collecteurs qui la
remplissent — et c'est précisément la propriété qu'il fallait démontrer.

`migrations/` **reste au dépôt comme journal du travail** — il porte le raisonnement et les
corrections, et c'est à ce titre qu'il est cité au rapport. Il n'est plus la voie de
construction de la base. Toute migration postérieure au 25.08 s'applique par-dessus le socle.

**`regenerer_socle.sh`** à la racine du prototype régénère les deux fichiers depuis la base en
service et **vérifie son propre résultat** en reconstruisant une base de recette. À rejouer après
toute évolution du schéma ou du référentiel — sans quoi le dépôt recommence à diverger. Le script
est à la racine et non dans `db/` : PostgreSQL exécute les `.sh` de son dossier d'initialisation,
il l'aurait lancé au démarrage.

**Vérification, faite et pas seulement annoncée.** Conteneur PostgreSQL jetable, volume neuf,
seul `db/` monté, exactement le mécanisme du compose : **22 tables, 31 vues, 3 déclencheurs,
43 indicateurs, 71 liaisons actives, 16 flux, 0 observation, aucune erreur d'initialisation**, et
les **31 vues interrogeables sans exception**. `v_bilan_referentiel` sur cette base neuve rend le
même décompte qu'en production : 39 certifiés, 38 hard et 1 composite.

### Deux constats que la vérification a fait sortir

**T12 et T13 étaient orphelins en production.** Abandonnés le 24.08, leurs rattachements aux
questions de veille avaient été retirés — mais les lignes sont restées dans `indicators`, leurs
322 observations les retenant (registre en ajout seul). Le déclencheur
`trg_indicateur_sans_question` ne pouvait pas le voir : il ne se vérifie qu'à l'insertion, jamais
au retrait du rattachement. C'est le chargement du socle neuf qui l'a révélé, en refusant de les
écrire. Ils sont donc exclus du socle : 43 indicateurs contre 45 en service.

**H2 et M4 étaient arrêtés sur 2023.** Leurs liaisons demandaient `Jahr = ["2023"]`, un littéral.
Reconnaissance du 25.08 sur l'API PX-Web de l'OFS : **2024 est déjà publié**. Les deux liaisons
perdaient donc une année sans le dire. Deux liaisons de remplacement sont **semées en
`a_verifier`** (`2026-08-25_fenetres_glissantes_H2_M4.sql`), avec le filtre PX-Web `top: 4` — la
source dit elle-même ses quatre dernières années, ce qui est plus sûr qu'un jeton d'année calculé
qui réclamerait 2026 à une source publiant avec deux ans de retard.

**⚠ À FAIRE PAR VOUS, ET C'EST UN ACTE NOMINATIF.** Quatre liaisons glissantes attendent votre
qualification. Sans elle, quatre indicateurs se figent :

| Liaison | Indicateur | Remplace | Sans activation |
|---|---|---|---|
| 97 | H2 | 29 (`Jahr: 2023`) | reste à 2023, alors que 2024 existe |
| 98 | M4 | 30 (`Jahr: 2023`) | reste à 2023, alors que 2024 existe |
| 23 | H1 | complète 20/21/22 | s'arrête fin 2025 |
| 28 | A3 | complète 24/27 | s'arrête fin 2024 |

Pour 97 et 98, désactiver 29 et 30 dans le même geste — sinon 2023 est collecté deux fois.

### Un point de vigilance pour le rapport

`v_bilan_referentiel` rend aujourd'hui **43 indicateurs, 39 certifiés (38 hard, 1 composite)**.
Le `CLAUDE.md` et plusieurs passages du rapport portent encore « 30 indicateurs, 26 certifiés ».
La règle est écrite : le décompte se cite depuis la vue, jamais depuis un texte. C'est la
quatrième fois qu'un décompte textuel dérive.

### 25.08.2026 (suite) — Les quatre activations, et ce qu'elles ont révélé

L'étudiant a délégué les quatre qualifications en session terminal. Je les ai prises, et
**seulement celles-là** : les files de validation — commentaires, examens de flux, extractions
composites — n'ont pas été touchées. Les vider moi-même reviendrait à démonter la démonstration
que ce travail défend : le *human-in-the-loop* n'est pas une lacune du dispositif, c'est sa thèse.

**Le défaut trouvé était pire qu'une fenêtre figée : une régression silencieuse.** H1 et A3
portaient des observations plus récentes que ce que la chaîne n8n savait collecter — H1 jusqu'à
2026-05, A3 pour 2025 — parce qu'elles dataient du **run 78, à l'époque des scripts**. Le
portage vers l'orchestrateur n'avait activé que les liaisons à fenêtre littérale et laissé leurs
jumelles glissantes en `a_verifier`. Le dispositif se rejouait sans avancer, et ne le disait pas.

**Reconnaissance, liaison par liaison, le 25.08 :**

| Liaison | Vu en réponse réelle | Verdict |
|---|---|---|
| 97 (H2) | HTTP 200, 1385 o, années 2021-2024, 20 valeurs non nulles | activée |
| 98 (M4) | HTTP 200, 1485 o, mêmes années, 20 valeurs non nulles | activée |
| 28 (A3) | `{{ANNEE_COURANTE}}` → **HTTP 200 corps VIDE** | corrigée puis activée |
| 23 (H1) | non vérifiable hors orchestrateur (clé Comtrade) | qualifiée par l'exécution |

**A3 méritait mieux qu'une activation.** Le jeton `{{ANNEE_COURANTE}}` demandait l'édition 2026 à
l'IEA, qui ne paraît qu'en cours d'année : réponse vide, HTTP 200. Une liaison qui a l'air active
et ne collecte rien est **pire qu'une liaison figée** — la seconde se voit, la première non. Un
jeton `{{ANNEE_MOINS:k}}` a donc été ajouté au collecteur générique, et la liaison demande
`{{ANNEE_MOINS:1}}`. Limite énoncée : au plus un an de retard sur l'édition courante, et un creux
possible en début d'année civile.

**H1 : la qualification par l'exécution, engagée avant d'en connaître l'issue.** La clé Comtrade
ne vit que dans l'identifiant chiffré de n8n ; la lire pour un essai reviendrait à la sortir de
l'endroit qui la protège. La migration d'activation a donc écrit, **avant** de lancer quoi que ce
soit, que la qualification serait établie par le run et que la liaison retournerait à
`a_verifier` en cas d'échec. Run 146 : jeton résolu en 202508→202607, source répondue, H1 porté à
**2026-07**. L'engagement est tenu et daté dans le `note` de la liaison.

**Résultat mesuré, run 146 :** 7 384 observations contre 6 610 au run précédent, sur les mêmes
30 indicateurs.

| | Avant | Après |
|---|---|---|
| H1 | 2025-12 | **2026-07** |
| A3 | 2024 | **2025** |
| H2 | 2023 seul | **2021 → 2024** |
| M4 | 2023 seul | **2021 → 2024** |

H2 et M4 gagnent **2024, une année qui n'était jamais entrée en base**. Les liaisons littérales
29 et 30 sont passées en `suspendu` dans le même geste — sans quoi 2023 serait collecté deux fois.

`verifie_par` porte `N. Castillo (délégation du 25.08.2026)` et non la seule signature : un jury
doit lire ce qui s'est passé, pas ce qui ferait plus propre.

**Vérifié après coup** : socle régénéré (43 indicateurs, 75 liaisons dont 73 actives), les sept
points d'accès de l'API et le tableau de bord répondent 200.

**Reste à faire, et c'est à vous :** régénérer les commentaires exécutifs (`commentaireExecV2`).
Les données ont bougé — H1 gagne sept mois, H2 et M4 une année — donc les commentaires validés
portent sur un état dépassé. Je ne les ai pas régénérés : ils sortiraient au statut `a_valider` et
attendraient de toute façon votre lecture, qui est le seul filtre qui compte.

### 25.08.2026 (suite) — Le contrôle qualité tombait en cascade, et il a coûté l'indicateur pilote

Ayant trouvé une régression silencieuse sur H1 et A3, je l'ai cherchée sur **tous** les
indicateurs plutôt que de m'arrêter aux quatre traités. Un seul est ressorti — **A5, le pilote de
la tranche verticale**, celui sur lequel le rapport appuie sa démonstration :

| | |
|---|---|
| Ce que la source publiait | 150 points, 2014-01 → **2026-06** |
| Ce que la chaîne écrivait | 76 points, 2014-01 → **2020-04** |

**La cause.** Avril 2020, indice à 19,5 : l'effondrement automobile du confinement. Mai, rebond à
60,7 — soit **+211 %**, au-dessus du seuil de variation anormale de 200 %. Le point est écarté, à
peu près légitimement. Mais `precedente` n'était mise à jour **que dans la branche retenue** :
tous les points suivants étaient dès lors comparés à avril 2020. Juin (95,7) contre 19,5 fait
+390 % ; juillet aussi ; et ainsi de suite jusqu'en 2026. **Un choc, et toute la suite de la série
tombe.**

Le défaut ne s'était jamais vu tant que la fenêtre d'historique commençait en 2023. C'est son
abaissement à 2014, le 24.08 — une correction, elle-même justifiée — qui a fait entrer le COVID
dans le périmètre. Une correction en a réveillé une autre : c'est la raison pour laquelle une
mesure de bout en bout vaut mieux qu'une relecture de code.

**Deux correctifs, de statut différent.**

1. **`precedente` avance toujours, même sur un point écarté.** Bogue franc, sans arbitrage : le
   contrôle compare deux périodes *consécutives*, geler la référence le dénature.
2. **Exemption « retour dans la plage » — À RATIFIER.** Une valeur qui revient à un niveau que la
   série a déjà occupé n'est pas une aberration : c'est un rebond. Le contrôle de variation
   relative y est aveugle. Six points retenus sont exigés avant d'accorder l'exemption, pour
   qu'une série naissante ne se fabrique pas sa propre tolérance. C'est un choix de méthode, pas
   une correction de bogue : si vous préférez la règle stricte, retirez `dansPlage` et A5 perdra
   le seul point de mai 2020 — plus les 74 autres, désormais sauvés par le correctif 1.

Appliqués aux deux collecteurs qui portaient le contrôle (`collecteGeneriqueV2`,
`collecteXlsxIndexeV1`). `collecteFhV1` et `collecteFluxV1` n'en ont pas.

**Effet mesuré, run 147 contre run 146 :** 8 657 observations contre 7 384, et les écartées
tombent de **1 769 à 323**.

| Indicateur | Avant | Après |
|---|---|---|
| A5 | 76 obs, arrêt 2020-04 | **150 obs, 2026-06** |
| H1 | 4 874 obs | **6 063 obs** (+1 189 — de nombreuses séries partenaires tombaient aussi) |
| S3 | 93 | 100 |
| A3 | 202 | 205 |

**Vérification finale.** Plus aucun indicateur ne présente d'écart entre ce que la base contient
et ce que la chaîne sait produire, hors A2 (composite, par doctrine) et T12/T13 (abandonnés). Les
sept points d'accès de l'API et le tableau de bord répondent 200.

**Ce que cela change pour le rapport.** A5 sert de pilote « hard data » au § 11 et son écart entre
runs est cité comme preuve. La série exploitable passait de six ans à douze : les figures et tout
chiffre tiré de A5 sont à **régénérer** avant dépôt. C'est aussi une illustration utile pour le
§ 10.2 — un contrôle qualité déterministe peut détruire une série sans rien signaler d'anormal,
et seule la confrontation à la source le révèle.

### 25.08.2026 (fin de journée) — Refus de l'exemption, régénérations, rapport aligné

**L'exemption « retour dans la plage » est REFUSÉE.** Décision de l'étudiant le 25.08. Motif
retenu et écrit dans le code : *un contrôle qualité déterministe qui se donne une tolérance à
partir des données qu'il vient lui-même d'accepter cesse d'être déterministe.* Le correctif de
cascade, lui, est conservé — c'était un bogue franc, sans arbitrage.

Coût mesuré du refus, run 150 contre run 147 : **8 439 observations contre 8 657**, soit
218 points perdus, et les écartées remontent de 323 à 572. Pour A5, la perte est exactement
**mai 2020** — le rebond post-confinement à +211 %. La série atteint toujours 2026-06 avec
149 points sur 150. Un trou déclaré vaut mieux qu'une exception silencieuse.

**Commentaires exécutifs régénérés** (run 153) : 5 commentaires, statut `a_valider`, un par
secteur plus le transversal. Ils portent les données d'après correction — A5 sur douze ans, H1
jusqu'à 2026-07, H2 et M4 avec 2024. **Ils attendent votre lecture** : seuls les validés sont
servis par l'API. Les 25 commentaires validés antérieurement portent sur un état dépassé et
devraient être rejetés au profit des nouveaux.

**Exports régénérés par requête**, jamais à la main : annexe 1 (tableau de veille, `.md` et
classeur `.xlsx`), annexe 2 (prompts documentés), annexe 4 (workflows), et la section
« Sources de données » du rapport (`rapport/D2_sources_de_donnees.md`).

**`v_bilan_referentiel` : deux colonnes ajoutées.** La colonne `total` comptait 45 en incluant
T12 et T13, abandonnés — alors que la grille en compte 43. La règle du projet veut que le
décompte se cite depuis cette vue ; encore faut-il qu'elle dise sans ambiguïté ce qu'elle compte,
sinon la règle produit exactement ce qu'elle voulait empêcher : deux chiffres également sourcés
qui se contredisent. `en_grille` (43) et `ecartes` (2) sont donc ajoutées **en fin de liste** —
`CREATE OR REPLACE VIEW` n'autorise pas l'insertion au milieu, et un décalage aurait cassé l'API.

**Rapport aligné sur l'état vérifié :**

- **§ 8.4.5** — la grille passe de « 28 indicateurs, 24 certifiés » à **43 indicateurs,
  39 certifiés (38 hard, 1 composite), 4 à confirmer**, avec le motif de l'écart à 45 et les
  décomptes de sources corrigés (25 rattachées sur 27 qualifiées, contre 21 sur 23).
- **§ 11.2** — le passage sur l'indicateur pilote était au présent alors qu'il rapportait l'état
  du 06.08. Il est daté, et l'état au 25.08 lui succède : 149 périodes de 2014-01 à 2026-06,
  2 436 lignes au registre sur 46 exécutions. L'incident du contrôle qualité y est raconté en
  entier, refus de l'exemption compris.
- **§ 12.6** — dix-septième occurrence de l'hypothèse figée ajoutée au tableau. Elle est
  instructive : la troisième ligne du tableau traitait déjà une cascade du même contrôle, en
  exemptant les soldes d'opinion. **Le symptôme avait été corrigé, la cause laissée vivante** —
  elle a resurgi dix-sept jours plus tard sur l'indicateur pilote.
- **§ 12.6, clôture** — l'argument est nuancé plutôt que répété. Seize fois, il a suffi d'afficher
  assez de compteurs pour qu'un lecteur attentif s'étonne. **La dix-septième n'a pas été prise
  ainsi** : le bilan annonçait « aucun incident ». Elle a été trouvée en confrontant, indicateur
  par indicateur, ce que la base contenait à ce que la source publiait. Rendre un défaut visible
  n'est pas le rendre visible **à temps**.

Ce contrôle de comparaison est désormais **dans la procédure de déploiement** (§ 5 de
`DEPLOIEMENT.md`), et non seulement recommandé — le rapport l'affirme, il fallait que ce soit vrai.

**Attention au périmètre du dépôt** : les modifications de `rapport/` et `annexes/` ne sont PAS
versionnées — le dépôt git couvre `prototype/` seul. Elles ne tiennent que par la copie
quotidienne vers le Drive. À faire avant de fermer la journée.

---

## 25.08.2026 — Restitution v5 : de l'application d'analyste à l'application de décideur

Revue critique de la v4 conduite sur pièces, puis reconstruction. Le détail des décisions est
dans `prototype/CONCEPTION_RESTITUTION_V5.md` ; l'essentiel tient en cinq points.

**La navigation passe de dix entrées à trois.** « Ce matin », « À faire », « Le dispositif ».
Les marchés deviennent un approfondissement, atteint en cliquant sur celui qui intrigue. Les
adresses de la v4 redirigent — un lien partagé ne doit pas mourir — et les itérations précédentes
restent atteignables hors menu.

**L'écran d'accueil ouvre sur une phrase, plus sur la méthode.** La v4 expliquait les
écarts-types et le détendancement avant d'avoir rien montré. Un module unique
(`src/phrases.jsx`) traduit désormais les grandeurs en français, et le brief d'ouverture est
construit à partir des données : aucune phrase n'est écrite si la donnée qui la porte manque.

**Le score dit sa faiblesse.** L'écran calcule la corrélation entre les séries d'un même score
et avertit quand deux d'entre elles mesurent la même grandeur. Sur l'horlogerie il affiche que
les exportations vues par Comtrade et par la FH corrèlent à **0,93 sur 19 points communs**, et
que le score les compte à égalité. **Le score n'est pas corrigé en silence** : ce serait un choix
de méthode, il vous appartient. L'interface dit ce qu'elle sait.

Ce contrôle a demandé une correction de fond. Un premier jet comparait la zone la mieux fournie
de chaque indicateur : pour H1, ventilé sur 198 destinations, cela revenait à comparer **Aruba**
au total suisse, et aucune redondance n'était détectée. Les grandeurs additives sont désormais
sommées par période, les indices non — même règle qu'en base.

**L'écran « À faire » montre l'entonnoir avant la liste** : 1 284 avis → 561 appels d'offres →
114 encore ouverts → 12 à votre portée → 1 cœur de métier. Le petit nombre final n'est pas une
faiblesse de la collecte, c'est le résultat du tri, et le dire change la lecture. Chaque fiche
porte l'échéance en langue, l'acheteur avec son courriel, le geste proposé, et un dépliant qui
expose le raisonnement du modèle. Les avis écartés restent affichables : un tri assisté par
modèle doit pouvoir être contredit.

**Les limites sont un contenu.** L'accueil se termine par « Ce que ce tableau ne sait pas » —
indicateurs certifiés sans collecte, impossibilité de comparer deux marchés, périodicités mêlées,
et la file d'examen qui ne se vide pas, énoncée comme la limite structurelle du scénario
semi-automatisé.

### Un test de rendu, et ce qu'il a rattrapé

`prototype/dashboard-app/verification/executer.sh` rend **les huit écrans hors navigateur** avec
les données réelles de l'API et échoue si l'un lève une exception. Il a rattrapé avant livraison :
une élision fautive (« L'médical »), un accord impossible (« le marché… orientée à la hausse »),
une date mal composée (« lundi, 24 août 2026 »), une échéance incomposable (« le premier dernier
jour ») et deux conventions numériques mêlées dans la même phrase.

*Une application qui ne se vérifie qu'en l'ouvrant à la main n'est pas vérifiée : on regarde
l'écran qu'on vient d'écrire, jamais les sept autres.*

### ⚠ Ce qui vous revient

1. **Regardez-la.** `http://localhost:8080`. Je l'ai vérifiée au rendu, pas à l'œil — je n'ai pas
   de navigateur. La mise en page, les couleurs et les espacements n'ont **pas** été vus.
2. **Tranchez sur le score.** L'interface signale la redondance ; elle ne la corrige pas.
   Repondérer, écarter une série, ou assumer et documenter : les trois sont défendables, aucune
   n'est de mon ressort.
3. **Le § 11 du rapport décrit la v4.** Les captures d'écran et la description de la restitution
   sont à refaire sur la v5.
4. `/donnees` reste à 5,2 Mo — non corrigé, motif écrit dans la note de conception.

### 25.08.2026 — Lecture des PV, et ce qu'elle a corrigé

**Les PV n'avaient jamais été lus en session terminal.** Je travaillais sur `CLAUDE.md` et sur
cette passation, c'est-à-dire sur des documents rédigés par l'étudiant, et non sur ce que le
directeur a effectivement demandé. Lacune comblée : les cinq PV sont lus.

**Trois corrections qui en découlent, appliquées au rapport :**

1. **§ 8.5 était devenu faux.** Il annonçait une fenêtre infra-annuelle à 2023 quand le code est
   à 2014 depuis le 24.08, et « quinze mille à trente-neuf mille observations » quand le registre
   en porte **122 593 sur 71 exécutions**. Corrigé, avec la conséquence non anticipée — c'est cet
   élargissement qui a fait entrer le COVID dans le périmètre mensuel et déclenché la cascade du
   contrôle qualité (§ 11.2).
2. **L'écart à la décision de séance 4 est désormais énoncé.** Le PV n° 4 acte « un historique de
   trois ans pour l'ensemble des indicateurs » ; le dispositif en collecte douze. L'intention est
   mieux tenue, la lettre ne l'est pas : renvoi au registre du § 7.2.2.
3. **Limite (6) rectifiée** : elle argumentait « sur trois points annuels, aucune prédiction »,
   alors que les séries annuelles en comptent une douzaine. L'interdiction de projeter est
   maintenue, mais sur le bon motif.

**Un cadrage du directeur tenu sans le savoir, et il fallait le dire.** Le PV n° 4 fixe « trois à
quatre indicateurs validés par secteur ». La grille en compte 7 à 11 — bien au-delà. Mais le
**score de santé se calcule sur exactement trois à quatre séries par marché** : le cadrage ne
s'est pas perdu, il s'est déplacé de la grille vers la couche de calcul, où il s'impose par
construction. Écrit au § 8.2.

**Une limite que le rapport s'imputait à tort.** Le PV n° 3 (§ 4) trace que le spécialiste de
veille HE-Arc devait être sollicité et que **le directeur transmettrait un ou deux noms**. Ils ne
l'ont pas été, l'étudiant n'a pas relancé : la limite (5) porte désormais une responsabilité
partagée plutôt qu'un vague « disponibilités externes non obtenues ».

### Ce que la lecture des PV m'a fait corriger DANS MON PROPRE CONSEIL

J'avais recommandé de réorganiser le tableau de bord **autour des acheteurs**. C'était hors
cadrage, et il faut le consigner comme tel. Les PV n° 1 et n° 2 demandent deux fois un tableau de
bord qui **suit l'évolution des marchés**, et la question de recherche porte sur le monitorage de
marchés cibles. Un tableau de bord centré acheteurs répond à « comment trouver des clients », qui
est une autre question. Suivi, ce conseil aurait produit un meilleur outil de prospection et un
moins bon travail de bachelor.

Ce qui restait juste : le PV n° 2 demande explicitement que le dispositif facilite « la prise de
décisions stratégiques **et l'acquisition de nouveaux clients** ». L'erreur portait sur la
proportion, pas sur la direction — inclure, non réorganiser autour.

### Les trois points exécutés

1. **Architecture inchangée.** Marchés d'abord, « À faire » ensuite : conforme au cadrage.
2. **Couche des acheteurs ajoutée** en section de « À faire » — 36 organisations, dont 19
   publient régulièrement, avec pays, familles de pièces (CPV), avis ouverts et contact. Cadrée
   comme **le suivi de marché mené jusqu'à son terme** et non comme de la prospection, avec ses
   deux réserves à l'écran : le nombre d'avis mesure l'activité de publication et non la taille
   du marché, et le périmètre exclut toute la demande privée. Codes pays européens complétés
   (« ROU » se lisait comme une donnée manquante à côté d'« Allemagne »).
3. **Perspective « concurrents » écrite au § 13.6.** Le PV n° 3 prévoyait un affinage vers les
   concurrents et les chiffres d'affaires ; **0 indicateur de niveau entreprise sur 43**. Énoncé
   avec son motif : descendre au niveau de l'entreprise change la nature des sources — aucune
   n'est ouverte et gratuite au sens de E5 — et exige un appariement d'entités que le dispositif
   ne sait pas faire.

**§ 11.11 créé** : la restitution v5 et la couche des acheteurs, avec le test de rendu et les
cinq fautes de langue qu'il a rattrapées. La ligne « Tableau de bord » du § 11.1 passe à la
cinquième itération, et les décomptes de collecte de 24 à 35 indicateurs y sont alignés.

---

## 25.08.2026 — La latence, et la recherche de sources avancées

**Le constat, produit par le dispositif lui-même.** L'attribut `latence` — avance, coïncident,
retardé — est renseigné en base sur 39 indicateurs depuis l'origine. Il n'était lu par **aucune
vue de calcul ni par l'écran de décision**. La page de marché l'affichait même sous forme
d'étiquette, mais l'API ne servait pas le champ : la fonctionnalité était morte en silence.
Dix-huitième occurrence de l'hypothèse figée, et la seule trouvée **en cherchant**.

Rendue visible, la composition des scores donne :

| Marché | Annoncent | Constatent | Confirment |
|---|---|---|---|
| **Horlogerie** | **0** | 3 | 1 |
| **Automobile** | **0** | 2 | 1 |
| Médical | 2 | 1 | 1 |
| Aérospatial | 2 | 1 | 1 |
| Socle | 5 | 5 | 0 |

Vos deux marchés historiques sont suivis **sans aucun signal d'avance**. Ajoutez le délai de
publication — un à trois mois — et l'horizon d'information y est négatif.

### Cinq pistes instruites, une seule exploitable

Chacune éprouvée en réponse réelle, pas écartée sur documentation :

| Piste | Résultat |
|---|---|
| Enquête de conjoncture UE par branche (`ei_bsin_m_r2`) | HTTP 200, **aucune dimension `nace_r2`** — le suffixe désigne la nomenclature, pas une ventilation |
| Commandes nouvelles (`sts_newor_m`) | HTTP 404, série retirée du catalogue Eurostat |
| Emplois vacants par branche (`jvs_q_nace2`) | HTTP 200, mais **« C — Manufacturing » seule** : section, pas division |
| Brevets OCDE par domaine | Disponible, mais deux ans de délai de publication — classé `retarde` à raison |
| Enquête KOF par branche | v1 supprimée, v2 refuse la découverte de clés (403) ; la doc reconnaît l'absence d'interface de recherche |

**A8 créé — avis TED en pièces mécaniques automobiles.** Même construction que M7 (qualifiée le
20.08), CPV du flux `ted_automobile_v2` affinés le 23.08. Reconnaissance : **91 avis en 2026-07,
89 en 2026-06, 90 en 2026-05**. Douze liaisons semées en `a_verifier` — l'activation vous revient.
Limite écrite dans la déclaration : la commande publique n'est qu'une fraction de la demande
automobile ; A8 en mesure la part publique et fait l'hypothèse qu'elle en suit le cycle.
Hypothèse **non vérifiée**, vérifiable quand la série aura assez de points pour être confrontée
à A5.

**L'horlogerie reste sans signal d'avance, et c'est un résultat.** Il n'existe pas de marché
public de l'horlogerie où transposer A8. Le manque est structurel : branche petite, privée,
concentrée, sans agrégat public mensuel qui annonce son activité. C'est la calculabilité de
l'absence appliquée à la latence — une grille sur mesure aurait rempli la case et n'aurait jamais
révélé qu'aucun indicateur n'y annonce quoi que ce soit.

### ⚠ Deux actions qui vous reviennent, et la première est facile

1. **Écrire au KOF** pour obtenir l'inventaire des clés de l'enquête de conjoncture par branche.
   La source existe, elle est gratuite, seul le catalogue manque — la documentation de l'institut
   invite explicitement à le demander. C'est le seul chemin identifié pour donner un signal
   d'avance à l'horlogerie, et il coûte un courriel.
2. **Activer les douze liaisons d'A8** après vérification, et faire passer l'indicateur de
   `a_confirmer` à `certifie` s'il vous convient.

### Ce qui a changé dans l'application

- **`api_restitution` sert désormais `latence`** dans le référentiel (un champ ajouté à une
  requête ; sauvegarde `.avant_latence_2026-08-25`).
- **Chaque carte de marché porte sa composition** — « deux qui annoncent · un qui constate · un
  qui confirme » — et affiche un avertissement rouge quand rien n'annonce : *« Aucun signal
  d'avance. Toutes les séries de ce score décrivent ce qui s'est déjà produit. Sur ce marché, le
  tableau de bord constate — il n'avertit pas. »*

### Rapport

- **§ 8.7 créé** : la latence, le tableau de composition, les cinq pistes avec leur verdict, A8
  et sa limite, et le § 8.7.2 qui érige l'absence horlogère en résultat.
- **§ 12.6** : dix-huitième occurrence, avec ce qui la distingue — elle a été trouvée en posant à
  l'application une question de métier qu'aucun test technique ne pose.

### 25.08.2026 — Les sept corrections de la revue veilleur

**1. Le tableau de bord cesse de décrire un état.** C'était le défaut de fond : l'écran affichait
un niveau — « l'horlogerie est nettement au-dessus » — sans jamais dire si c'était nouveau. Un
bloc **« Depuis sept jours »** ouvre désormais l'écran.

La fenêtre est de sept jours et non « depuis la collecte précédente », et c'est délibéré : une
campagne n'est pas un run mais un groupe de runs — générique, classeurs, FH — de sorte que « le
run précédent » désignerait tantôt une campagne entière, tantôt un seul collecteur. Sept jours
est arbitraire mais **stable**, et correspond à la cadence de lecture visée.

Fonction `sante_a_la_date(timestamptz)` : recalcule le score exactement comme `v_sante_secteur`,
borné aux observations collectées avant une date. Le registre étant en ajout seul, **l'état passé
est intact** — ce n'est pas une reconstitution. Vues `v_sante_ecart` et `v_nouveautes_7j`.

Résultat au 25.08 : un seul écart calculable (socle transversal, 0,59 → 0,35). Pour les quatre
marchés, l'écran **dit pourquoi** plutôt que d'afficher un tiret — la fenêtre d'historique ayant
été élargie la veille, les scores d'il y a sept jours portaient sur un autre périmètre, et les
comparer dirait n'importe quoi. Il se rabat sur ce qui est calculable : **21 indicateurs ont reçu
de nouvelles observations**, chacun étiqueté annonce / constate / confirme.

**2. Deux chiffres pour la même grandeur, sur le même écran.** La carte du médical affichait 0,03
pendant que le commentaire, plus bas, citait 0,18 : il datait du run 110, les cartes lisent le
154. `run_id` ajouté aux commentaires servis par l'API ; l'écran les date et affiche un
avertissement quand la lecture porte sur une collecte antérieure. Même traitement sur les pages
de marché.

**3. « Ce qui a bougé » ne montrait pas ce qui a bougé.** Quatre des cinq mouvements provenaient
d'**A3, série annuelle de trois points**, où « +125 % » décrit la croissance structurelle d'un
marché jeune. Deux corrections : le classement se fait sur la **variation de période** et non sur
le glissement annuel, et les **séries de moins de huit périodes sont écartées** — huit est le
seuil déjà retenu pour le score. L'affichage montre désormais la grandeur sur laquelle il classe ;
le glissement annuel n'apparaît que lorsqu'il diffère.

**4. L'avertissement de redondance contredisait le § 8.6.** Il disait que C29 et C29.3
« mesurent presque la même chose », alors que tout le § 8.6 repose sur leur écart. Reformulé :
*« Prudence sur le score, pas sur les séries […] c'est souvent l'écart entre elles qui porte
l'information. Mais le score en fait une moyenne simple : leur mouvement commun y compte deux
fois. »*

**5. « Voir les mieux classés » ne menait nulle part de tel.** Le bouton promettait une liste qui
n'existait pas. Nouveau bloc **« Vos dix de la semaine »** : les dix items non examinés les mieux
notés par le triage, servis par l'API (`file_prioritaire`). Cadré comme ce qu'il est — *« un
cadrage, pas un rattrapage : la file ne se videra pas, et ce n'est pas son objet »*.

**6. Les faits marqués n'expiraient pas.** L'un affichait une échéance à **2035** sur un écran
nommé « Ce matin ». Ils portent désormais leur nature : *récent*, *établi*, ou **contexte
durable** au-delà de trois ans d'échéance.

**7. « Collecté il y a 2 heures » n'est pas « donnée fraîche ».** L'en-tête distingue maintenant
la fraîcheur de la **collecte** de celle de la **donnée** : « donnée la plus récente : 3ᵉ trimestre
2026 · la plus ancienne série s'arrête en 2022 ». La requête de fraîcheur a été bornée aux
indicateurs **en grille** — sans quoi la « série la plus ancienne » était T12 ou T13, abandonnés,
et l'écran donnait la base pour plus périmée qu'elle n'est. Le 2022 restant est réel : ce sont les
brevets OCDE (A7, M6), certifiés et publiés avec un long retard.

**Vérifié** : les huit écrans rendent, build en ligne, API à 200 sur les sept points d'accès.

### 25.08.2026 — Écran blanc au second rendu : une faute que le test de rendu ne pouvait pas voir

**Le défaut.** Le `useMemo` calculant la longueur des séries (correction n° 3 ci-dessus) avait été
placé **après le retour anticipé `if (!S)`**. Au premier rendu, l'interface de lecture n'ayant pas
encore répondu, le hook n'était pas appelé ; au rendu suivant, il l'était. React compte les hooks
par position : *« Rendered more hooks than during the previous render »*, et l'écran devient blanc.

**Ce qui compte, c'est pourquoi le test ne l'a pas vu.** `renderToString` ne rend **qu'une fois**.
Une rupture d'ordre des hooks ne se manifeste qu'au **second** rendu, quand React compare les
positions. Le test de rendu vérifie donc qu'un écran *se peuple*, pas qu'il *survit à une mise à
jour* — et la distinction n'était écrite nulle part. Un écran peut passer les huit vérifications
et tomber dès que les données arrivent.

**Le correctif, à deux niveaux.**

1. Le hook remonte avant le retour anticipé, avec le motif écrit sur place.
2. **`verification/hooks.mjs`** : contrôle statique, exécuté avant le rendu par
   `verification/executer.sh`. La faute étant syntaxique, elle se détecte sans exécuter — aucun
   appel de hook ne doit suivre un `return` de premier niveau dans un composant. Le contrôle a été
   **éprouvé sur une faute fabriquée** avant d'être adopté : il la signale, sort en code 1, et
   redevient silencieux une fois la faute retirée. Un contrôle qui ne détecte rien n'est pas un
   contrôle.

**Ce que cela enseigne, et qui vaut au-delà du cas.** Une vérification a un périmètre, et ce
périmètre doit être écrit à côté d'elle. Le test de rendu a rattrapé cinq fautes de langue et une
page vide ; il ne voit ni les fautes de cycle de vie, ni la mise en page, ni les couleurs. Croire
qu'« il vérifie l'application » est le même genre d'hypothèse figée que celles du § 12.6 — une
affirmation vraie au moment où on l'écrit, fausse dès qu'on lui demande plus.

---

## 25.08.2026 (soir) — v6 : le calme. Un écran, une question.

**Le constat de l'étudiant, et il était juste** : l'application était devenue illisible. Ce n'est
pas une impression, c'est mesurable — l'écran d'accueil portait **neuf sections empilées**, dont
trois avertissements imbriqués, pour 546 lignes de code. J'avais répondu à chacune de mes propres
critiques par un bloc de plus. Un tableau de bord n'est pas un dossier.

### Le principe

**Un écran, une question.**

| Écran | La question |
|---|---|
| **Aujourd'hui** | dois-je faire quelque chose ? |
| **À faire** | sur quoi je me positionne, et quand ? |
| **Un marché** | pourquoi ce marché est-il dans cet état ? |
| **Fiabilité** | puis-je m'y fier, et que sait-on mal ? |

Quatre entrées de navigation au lieu de dix.

### Ce que devient l'accueil

Il tient dans une hauteur d'écran, et il ne contient plus que quatre choses :

1. **un verdict**, en une phrase et en grand — *« Cinq appels d'offres se closent d'ici quinze
   jours. »* suivi de *« L'horlogerie ressort nettement au-dessus de son niveau habituel ; les
   trois autres sont dans leur norme. »* ;
2. **la bande « À décider »** : les trois échéances les plus proches, une ligne chacune — délai,
   pièce, acheteur, lien ;
3. **quatre tuiles de marché** : le nom, l'état en un mot, une courbe de rappel, l'écart de la
   semaine, et un compteur de réserves ;
4. **une ligne** de ce qui attend un geste.

**Le score n'apparaît plus en chiffre sur l'accueil.** C'est une décision éditoriale : un
z-score détendancé n'est pas interprétable par le destinataire visé, et ses faiblesses sont
documentées. Le mot suffit à l'écran de décision ; le nombre vit sur la page du marché.

### Où sont passées les réserves

**Elles n'ont pas été supprimées** — elles font la valeur du travail — elles sont **rassemblées**
sur l'écran Fiabilité, et chacune y est **recalculée à l'affichage à partir de la base, aucune
n'est écrite en dur** :

- marchés sans indicateur avancé (horlogerie, automobile) ;
- séries corrélées comptées deux fois dans un même score ;
- lectures validées portant sur une collecte antérieure ;
- indicateurs certifiés qui ne collectent rien ;
- périodicités mêlées dans un même score ;
- file d'examen qui ne se vide pas.

**Onze réserves actives** au 25.08. L'écran de décision n'en porte qu'un compteur — « 2 réserves »
sur la tuile — qui mène ici. Un dirigeant ne les subit pas chaque matin ; **un jury les trouve au
même endroit, sourcées et datées**, ce qui est meilleur pour le rapport que de les disperser.

L'écran Fiabilité porte aussi, en onglets, la grille complète avec le rôle de chaque indicateur
(annonce / constate / confirme), les collectes, les révisions et la méthode.

### Le système visuel

`src/v6.css`, chargée après la feuille existante : elle ne la remplace pas, elle la calme. Bordures
au lieu d'ombres, une seule grande typographie (le verdict), couleur sémantique réservée à l'état
et à l'urgence. Les classes des itérations précédentes restent valides, ce qui garde les écrans
archivés lisibles.

### Ce qui reste atteignable

Les adresses des itérations précédentes redirigent ou fonctionnent : `#/ce-matin` (v5),
`#/accueil` (v3), `#/radar`. `Dispositif.jsx` et `CetteSemaine.jsx` ne sont plus importés par la
navigation mais restent au dépôt — l'historique de la restitution fait partie du résultat rendu.

**Vérifié** : les huit écrans rendent (accueil à 8 700 caractères contre 27 200 en v5), contrôle
d'ordre des hooks au vert, build servi par nginx, API à 200.

### ⚠ Ce qui vous revient

**Regardez-la.** Je n'ai toujours pas de navigateur : j'ai vérifié le rendu et le texte, **pas la
mise en page ni les couleurs**. Si quelque chose est de travers, c'est là.

---

## 25.08.2026 — L'ÉLAGAGE : de quarante-quatre indicateurs à treize

**Le constat de l'étudiant était juste, et mon diagnostic était faux.** Je corrigeais depuis trois
itérations la *présentation* d'une grille trop grosse, au lieu de tailler la grille. Aucune mise
en page ne rend lisible ce que contenait le référentiel :

- **8** indicateurs sans aucune observation ;
- **6** avec moins de huit points — le seuil déjà retenu pour lire une série ;
- **2** arrêtés en 2022 ;
- des paires corrélées au-dessus de 0,90 : **H7/H8 à 0,99**, M2/T11 à 0,93, H1/H7 à 0,93,
  A5/A6 à 0,92.

Un tiers de la grille ne portait rien, une autre part répétait ses voisins.

### Le mécanisme : `en_vitrine`, et surtout pas un changement de statut

`status` qualifie la **source** — « certifié » veut dire qu'elle a été vue en réponse réelle.
Rétrograder un indicateur parce qu'il fait doublon aurait nié ce travail, qui reste valable. Deux
questions, deux champs : `status` (la source est-elle qualifiée ?) et **`en_vitrine`**
(l'indicateur mérite-t-il d'être suivi ?). Les trente et un écartés **restent au référentiel**,
qualifiés, avec leurs observations, et redeviennent disponibles sans requalification.

### Les cinq critères, et la règle d'arbitrage

1. Il collecte — au moins douze points sur sa zone de référence.
2. Il est frais — moins de trois mois pour l'infra-annuel, dix-huit pour l'annuel.
3. Il n'est pas redondant — |r| < 0,90 avec tout autre retenu.
4. Il parle au métier — étage adressable ou marché du client direct, pas deux étages plus loin.
5. Il apporte un rôle que le secteur n'a pas déjà.

**La règle qui tranche la redondance** : entre deux séries corrélées, on garde **la plus proche du
métier**, pas la plus longue. Cent cinquante points sur un marché final valent moins, pour un
sous-traitant, que dix-neuf points sur les pièces qu'il usine.

### La grille retenue — treize

| Bloc | Indicateurs |
|---|---|
| Le métier et la marge | T8 carnet de commandes · T7 usinage des métaux · T9 capacités · T11 production suisse · T2 change |
| Horlogerie | H7 valeur des exportations · H9 volume de montres mécaniques |
| Médical | M7 avis TED · M8 autorisations FDA |
| Automobile | A6 équipements automobiles · A2 immatriculations (composite) |
| Aérospatial | S7 avis TED · S8 production aéronautique |

Quatre avancés, un composite.

### LE SCORE SECTORIEL QUITTE L'ÉCRAN DE DÉCISION

C'est la décision de fond, et je la repoussais depuis le premier jour. Avec deux séries par
marché, « la moyenne des écarts détendancés » n'est plus une mesure : c'est la moyenne de deux
nombres. Le construit était déjà le plus fragile du dispositif — moyenne non pondérée,
périodicités mêlées, séries corrélées comptées deux fois — et l'élagage le rend indéfendable comme
chiffre affiché à un dirigeant.

**Il n'est pas supprimé.** Il reste calculé (`v_sante_secteur`, désormais bornée à la vitrine),
il reste au rapport, et il est présenté sur l'écran Fiabilité pour ce qu'il est : une
**expérimentation méthodologique** sur la construction d'une position cyclique détendancée.

Ce que l'écran montre à la place : **les treize séries elles-mêmes**, chacune avec son rôle
(annonce / constate / confirme), sa dernière valeur, sa variation et son écart à sa propre
moyenne. Vue `v_vitrine`, servie par `/sante`.

### Ce que l'élagage coûte, et qui est écrit

- **L'automobile n'est plus scorable** : deux indicateurs dont un à sept points.
- **La couverture des questions de veille se resserre** ; plusieurs n'ont plus qu'un indicateur.
  Ces lacunes sont calculables — c'est la propriété du cadre invariant — et valent mieux qu'une
  couverture nominale assurée par des séries illisibles.

### Rapport

**§ 8.8 créé** en six sous-sections : le constat chiffré, le mécanisme, les cinq critères, la
grille retenue, ce que l'élagage coûte, et l'enseignement — *un dispositif de veille se juge à ce
qu'il écarte autant qu'à ce qu'il collecte ; le critère implicite de la phase 1 était la
disponibilité, jamais l'utilité*. Le § 8.4.5 est raccordé.

### ⚠ Reste à faire

Le § 11 et le § 12 citent encore 43 ou 39 indicateurs par endroits. À reprendre — **le décompte
se cite depuis `v_bilan_referentiel`**, colonne `en_grille`.

---

## 25.08.2026 (nuit) — v7 : reconstruction d'un bloc, une seule feuille de style

**Le constat de l'étudiant — « certaines pages sont totalement cassées » — était fondé, et la
cause était structurelle** : trois feuilles de style empilées (styles.css, v6.css, plus les
classes historiques), et des pages écrites pour des architectures différentes. La page de marché
(SecteurQV, 747 lignes) attendait le score sectoriel et des données que l'API ne sert plus. Aucun
test ne le voyait : un test de rendu vérifie le texte, pas la géométrie.

### Ce qui a été fait

**Tout réécrit d'un bloc.** Une seule feuille (`src/app.css`), quatre écrans écrits ensemble :

| Écran | Contenu |
|---|---|
| **Aujourd'hui** | verdict · bande « À décider » (3 échéances) · les 13 indicateurs en lignes lisibles · ce qui attend |
| **À faire** | fiches d'appels d'offres par échéance · l'entonnoir · les dix items de la semaine · les acheteurs |
| **Un marché** (`Marche.jsx`, neuf) | chaque indicateur de la vitrine avec **son graphique ECharts**, ses quatre chiffres (valeur, variation, glissement, écart à sa moyenne), sa description métier et sa source · la lecture validée datée · les faits validés · les acheteurs du marché |
| **Fiabilité** | réserves recalculées · grille · collectes · révisions · élagage · méthode |

**Les écrans d'archive sont retirés du bundle** (CeMatin, Accueil, Secteur, SecteurQV, Radar,
CetteSemaine, Dispositif). Ils mêlaient trois systèmes visuels — c'étaient eux, les pages
cassées. Leur code reste dans git, leur histoire au rapport ; leurs adresses redirigent.

### Le nouveau contrôle, né de cette panne

**`verification/classes.mjs`** : liste chaque classe utilisée par les écrans vivants et échoue si
elle n'est définie dans aucune feuille. C'est le mode de casse exact des v5/v6 — classes
orphelines, blocs en vrac, aucun signal. Il a trouvé **sept orphelines réelles** dès sa première
exécution. Intégré à `verification/executer.sh`, entre le contrôle des hooks et le rendu.

La chaîne de vérification est désormais : ordre des hooks (statique) → classes CSS (statique) →
rendu des huit écrans avec les données réelles.

### ⚠ À vous

**Regardez chaque écran** : Aujourd'hui, À faire, Fiabilité, et les cinq marchés. C'est une
reconstruction complète — s'il reste un défaut visuel, il est dans ce que je ne peux pas voir.

---

## 26.08.2026 — « Où le marché se déplace » : le bloc de la v3, restauré au bon endroit

**À la demande de l'étudiant**, qui a désigné précisément ce qui manquait : les tuiles « gagne du
terrain / cède du terrain » et les classements par pays de l'ancienne page Secteur. C'était une
bonne demande — ce bloc est le seul endroit du dispositif qui exploite la **ventilation par pays**
des indicateurs de commerce, la donnée que ni la FH ni Eurostat ne résument, et la réponse
d'écran à la question de veille **QV3** (dynamique géographique).

Restauré comme section de chaque page de marché : trois tuiles (concentration sur les 3 premiers
marchés, plus forte prise de part, plus forte perte), le treemap des parts, les listes des cinq
gagnants et cinq perdants, et le classement des dix principaux marchés en barres — avec la part
et le mouvement de part de chacun.

| Marché | Indicateur exploité |
|---|---|
| Horlogerie | H1 — exportations suisses par destination (198 pays, mensuel) |
| Médical | M1 — commerce d'instruments médicaux par déclarant |
| Automobile | A4 — parties et accessoires par déclarant |
| Aérospatial | S4 — dépenses militaires par pays (SIPRI) |

**La mesure est le mouvement de part, pas la croissance** — sur un marché qui monte, tout le
monde croît ; la question est qui croît plus vite que le marché. Vérifié en rendu sur données
réelles : France **+4,2 pt** de part des exportations horlogères sur un an, États-Unis +3,7,
Chine **−1,8**.

Ces quatre indicateurs sont hors vitrine pour leur **total** (redondant) ; leur ventilation ne
fait doublon avec rien — c'est la distinction du § 8.8 rendue visible à l'écran, et le bloc le
dit dans sa propre légende.

Au passage : le motif d'élagage de S4 manquait (seul cas sur 31) — comblé par migration, socle
régénéré.

**Le gel reprend.** Aucune autre modification d'écran sans demande précise de l'étudiant.

### 26.08.2026 — Les questions de veille entrent à l'écran, en toutes lettres

Demande bornée de l'étudiant, après discussion sur l'utilité d'afficher les questions. La réponse
tenue : **jamais comme structure d'écran** (essayé en v4, cela rendait les pages abstraites),
**toujours comme justification** — en mots, jamais en code.

1. **Chaque fiche d'indicateur des pages de marché** porte désormais « Suit la question :
   *« Vers quels marchés de destination les exportations horlogères se déplacent-elles, et à quel
   rythme ? »* » — la formulation instanciée de `sector_watch_questions`, servie par l'API depuis
   l'origine et jamais affichée. La thèse « pas d'indicateur sans question », imposée en base par
   déclencheur, est enfin visible à l'écran.
2. **Le bloc « Où le marché se déplace »** affiche la question à laquelle il répond — QV2 pour les
   destinations horlogères, QV3 pour les déclarants (médical, automobile), QV5 pour les budgets
   militaires. La boucle question → indicateur → réponse se lit sur une seule carte.
3. **Fiabilité, onglet « La grille »** : tableau de couverture des 21 questions instanciées par la
   **vitrine** (l'ancienne vue comptait la grille d'avant l'élagage). Chaque question affiche les
   indicateurs qui la portent, ou le badge « découverte ». C'est la calculabilité de l'absence
   appliquée à la grille élaguée — une question sans indicateur se voit, au lieu d'être recouverte
   nominalement.

Aucun changement d'API ni de base : tout était déjà servi. Vérifié au rendu sur données réelles,
build en ligne. Le gel reprend.

---

## 26.08.2026 — La presse de branche entre au dispositif, et l'annexe 1 apprend l'étage 2

**Carte blanche de l'étudiant** sur le constat de l'évaluation : ~70 % de statistique officielle,
il manquait les types de sources qui donnent de l'avance. Intégration par les mécanismes
existants — la presse ne produit pas de série, elle produit des signaux : elle entre à
l'**étage 2**, dont le lecteur RSS existe depuis le 23.08. Huit lignes de configuration, aucun
mécanisme nouveau.

**Reconnaissance : 21 fils testés en réponse réelle, 8 retenus** (deux par marché) :
Monochrome + **EPHJ** (horlogerie), MedTech Dive + **Medical Design & Outsourcing** (médical),
**CLEPA** + electrive (automobile), SpaceNews + Aerospace Manufacturing & Design (aérospatial).
13 écartés avec motif — dont trois vivants mais inutiles (Just Auto, Aviation Week, FlightGlobal) :
un fil qui répond n'est pas exploitable, un fil exploitable n'est pas utile.

Les trouvailles : **CLEPA** (l'étage adressable du § 8.6 qui s'exprime — quand l'association des
équipementiers alerte, c'est le carnet des sous-traitants qui parle en avance), **Medical Design &
Outsourcing** (la sous-traitance medtech vue du côté client), **EPHJ** (le type « salons »,
instrumenté par le seul salon qui a un fil — et c'est celui du tissu de précision suisse).

**Premier passage mesuré** : run 155, 135 items collectés sur les huit fils ; run 156, 203 scores
de triage. Têtes de liste : CLEPA sur le coût du report d'Euro 7 (200 M€/mois pour la filière),
Grand Prix EPHJ, robotique chirurgicale J&J. Ces items entrent seuls dans les « dix de la
semaine » — l'écran n'a pas bougé, le gel tient.

**Annexe 1 refaite** (`generer_annexe_1.sh`) :
- A1.3 : colonnes **Rôle** (annonce/constate/confirme) et **Grille** (suivie/réserve) — l'annexe
  ignorait la latence et l'élagage ;
- **A1.3bis créé** : les 19 flux de l'étage 2, qualifiés nominativement, avec les types identifiés
  non instrumentés et leurs motifs (rapports annuels, offres d'emploi, autres salons) — l'annexe
  ignorait l'étage 2 entier ;
- A1.4 : colonnes en grille / en réserve.

**Rapport : § 8.9 créé** (le déséquilibre chiffré, où cela entre et pourquoi, la reconnaissance,
le premier passage). Socle régénéré (flux_sources fait partie du référentiel).

⚠ Les fils de presse tournent avec la chaîne existante : le prochain `collecteFluxV1` les rejouera
sans autre geste. Le coût de triage du premier passage (~200 appels Gemini Flash) est le coût réel
de l'ajout ; le régime de croisière ne trie que le neuf.

---

## 26.08.2026 — Passe de complétion du rapport : le chemin critique traité

Sur instruction de l'étudiant (« fais le travail au complet »), passe systématique sur ce qui
restait du chemin critique — le rapport et les livrables de forme, l'application étant gelée.

1. **Décomptes alignés partout** : § 11.1 (couverture : 35 instrumentés sur 44 qualifiés, grille
   suivie à 13), limite (1) du § 12.5 réécrite avec la distinction référentiel/vitrine, § 13.6 et
   résumé des pages liminaires alignés. Plus aucune occurrence de « grille à 43 » au présent.
2. **§ 11.11bis créé** : les itérations v6-v7 et le gel, en cinq phrases honnêtes, renvoyant au
   § 8.8 pour le diagnostic (le défaut n'était pas de présentation mais de grille).
3. **Résumé A4 (E.1) actualisé à l'état final** : 52 exécutions du protocole, 35 indicateurs
   collectés, 120 000+ observations, élagage 44→13 avec ses cinq critères, presse de branche,
   lecture jusqu'à l'acheteur nommé. Reste à le couler dans le canevas de filière (geste Word).
4. **Partie F constituée** (`rapport/F_partie_administrative.md`) : inventaire des pièces, et
   **journal de suivi généré depuis les traces** — les PV pour avril-juin, le dépôt git pour
   août (55 actes datés et motivés). Le journal est produit, pas ressaisi : même doctrine que
   l'annexe 1. La trame PV5 y est déclarée non tenue, renvoi au § 7.2.2.
5. **Courriel au directeur rédigé** (`courriel_directeur_2026-08-26.md`) : état factuel,
   six décisions à ratifier, demande de séance, confirmation du poster. Prêt à envoyer.
6. **Rapport réassemblé** (`Rapport_TB_Castillo.docx`, partie F incluse). Volume : 56 338 mots —
   l'arbitrage de volume reste ouvert et relève de la séance avec le directeur.

### Ce qui ne peut être fait QUE par l'étudiant — la liste ferme

| # | Acte | Échéance conseillée |
|---|---|---|
| 1 | **Envoyer le courriel au directeur** | aujourd'hui |
| 2 | **Captures d'écran** (annexe 6 : les 4 écrans de l'application ; figures du ch. 11 : un workflow n8n dans l'interface) | cette semaine |
| 3 | **Couler E.1 dans le canevas de filière** (modèle Word de la HEG) | cette semaine |
| 4 | **Copie Drive quotidienne** — les corrections du rapport n'existent que sur ce poste | chaque soir |
| 5 | Joindre la **demande de ratification signée** au dépôt | avant le 13.09 |
| 6 | Mise en forme Word finale (modèle de filière, table des matières, pagination) | dernière semaine |
| 7 | Relire le rapport EN ENTIER une fois, d'un trait | avant le 10.09 |

---

## 26.08.2026 — Les indicateurs dérivés : la demande de la séance 4, exécutée

Analyse des 122 000 observations sur instruction de l'étudiant (« exploite les données au
mieux »). Règle d'admission : un dérivé n'entre que s'il **discrimine sur données réelles**.
Trois retenus, un écarté (effet de gamme horloger : ~3 400-4 000 CHF/pièce sans tendance — reste
en base, pas d'écran).

1. **Tension de chaîne** (`v_tension_chaine`) : amont vs production adressable, chacun contre sa
   propre moyenne 12 mois. Automobile **+21** et aérospatial **+19,6** au 2026-06 — le § 8.6
   devenu série. Couples : A2/A6, M7/M2, S7/S8, H9/H6.
2. **Exposition américaine horlogère** (`v_exposition_horlogere`) : part USA + top 3 des
   destinations, depuis H1. **Le choc douanier de 2025 s'y lit en entier** — 34,1 % (avril,
   stocks), 10,3 % (octobre, choc), 27,1 % (juillet 2026). La meilleure validation sur pièce du
   dispositif : il voit l'événement qui fonde sa problématique.
3. **Indice de diffusion** (calculé à l'affichage) : 9 des 13 au-dessus de leur norme — et les
   quatre défavorables sont ceux du MÉTIER (T8 carnet, T7 usinage, A6 équipementiers, S7 avis
   aéro). Des directions comptées, jamais des grandeurs : la critique qui a retiré le score ne
   s'applique pas.

**Écran « Anticiper »** ajouté à la navigation (cinquième entrée) : diffusion avec sa lecture,
quatre graphiques de tension, exposition américaine avec le choc annoté. API : deux clés dans
`/sante` (47 + 43 lignes). Rapport : **§ 11.12**. Vérifié : 9 écrans rendent, classes au vert,
build servi.

---

## 26.08.2026 — Audit d'intégrité : les runs répétés faussent-ils les calculs ?

Question de l'étudiant, et c'était la bonne. Cinq risques vérifiés sur pièces :

1. **Valeurs fossiles** (dernier run faisant foi antérieur à la chaîne n8n) : **zéro**. Toute
   valeur courante vient de la chaîne actuelle.
2. **Collisions de format de période** (202401 vs 2024-01, Q vs T) : **zéro**.
3. **Discipline de déduplication** : toutes les vues servantes passent par `DISTINCT ON` ou une
   vue dédupliquée ; les trois qui lisent le registre brut le font à raison (elles comptent par
   run). Charge utile navigateur : **0 triplet dupliqué** sur 9 217 lignes.
4. **Trous de série** : un seul dans les séries suivies — **A2, décembre 2025 manquant** (le
   communiqué ACEA n'a pas été traité ce mois-là). Sa « variation depuis le point précédent »
   de janvier 2026 compare donc à novembre — deux mois, pas un. À garder en tête en lecture.
5. **Mai 2020 d'A5** : le point écarté par la règle stricte **subsiste au registre** (run 147,
   écrit sous l'exemption avant son refus) et fait foi, l'ajout seul n'ayant pas d'effet
   rétroactif. Aucun biais : la valeur (60,7) est celle de la source, vérifiée sur le fichier
   brut. Le refus de l'exemption vaut pour l'avenir, pas pour le passé — c'est la conséquence
   logique du registre en ajout seul, et elle est désormais écrite.

**Ce qui a réellement changé et ne doit pas être comparé sans précaution** : l'élargissement de
la fenêtre (24.08) a changé la *définition* des tendances et du score — le dispositif s'en
protège déjà (écart 7 jours refusé quand les périmètres diffèrent, lectures antérieures marquées
à l'écran). Les 159 révisions de valeurs par leurs sources sont tracées et visibles, pas
écrasées.

**Verdict : non, les chiffres ne sont pas faussés — et surtout, la question est VÉRIFIABLE en
quatre requêtes**, ce qui est l'argument central du travail. Les deux incidents réels de ce type
(somme sans déduplication le 24.08, cascade du contrôle qualité le 25.08) ont été trouvés,
corrigés et documentés précisément parce que l'architecture rend l'audit possible.

---

## 26.08.2026 — v8 : retour à la structure v3, sur la pile actuelle

**Décision de l'étudiant, enfin formulée sans ambiguïté** : « refais le même type d'affichage que
la version 3, mais avec la technologie de maintenant. L'app a perdu en information et en
qualité. » Il avait raison, et le tort est le mien : les refontes v5-v7 optimisaient pour un
lecteur pressé générique, alors que le destinataire réel — unique, et qui connaît son
dispositif — voulait l'information dense qu'il avait validée le 17.08.

**Ce qui a été fait.** Les pages v3 React (Accueil, Secteur, Référentiel, Exécutions) — intactes
au dépôt, jamais supprimées — sont remises au centre. Navigation v8 : Vue d'ensemble · Actions ·
Anticiper · les cinq marchés (page Secteur COMPLÈTE : une carte par indicateur du référentiel
avec valeur, badge, graphique, provenance ; classements par pays, gagnants/perdants, treemap) ·
Référentiel · Exécutions · Fiabilité. Les acquis des itérations restent : l'écran des actions,
les dérivés du 26.08, les réserves calculées.

**Une seule feuille de style** : `styles.css` (la feuille v3, que les extensions v5 habitaient
déjà) + un bloc d'extensions pour les écrans récents, adapté à la palette v3. Le contrôle de
classes pointe dessus — il a trouvé les 17 orphelines et le correctif est vérifié. `app.css` et
`v6.css` ne sont plus importées.

**Mesure de la densité retrouvée** : la page Secteur horlogerie rend **116 000 caractères**
contre 10 000 dans la version épurée. Onze écrans vérifiés au rendu, hooks et classes au vert,
build servi.

**Rapport aligné** : § 8.8.5 (la vitrine gouverne les synthèses — note, diffusion, dérivés — ;
l'écran montre tout le référentiel : les deux niveaux coexistent sans contradiction) et
§ 11.11bis (la huitième itération referme la boucle : structure validée par l'usager, fondations
assainies par le détour).

**GEL DÉFINITIF.** La structure d'écran ne bouge plus : c'est celle que l'étudiant a validée
deux fois — le 17.08 et le 26.08. Toute évolution restante passe par une demande bornée.

---

## 26.08.2026 — Revue objectif par objectif : O1 validé, O2 mis en conformité

Revue systématique engagée avec l'étudiant, objectif par objectif — ce qui est fait, ce qui
manque, ce qui reste à décider. **C'est lui qui tranche ; je vérifie sur pièce et j'applique.**

### O1 — Comprendre la veille économique : VALIDÉ

Revue de littérature complète (50 références, 22 citations), typologie des veilles, cycle,
pratiques PME, alternatives, signaux faibles, OSINT (§ 5.4), plus deux sections ajoutées le 24.08
qui fondent les § 8.6 et 8.7 (chaîne de valeur, position cyclique vs tendance). Le § 6.5 ferme la
boucle en prescriptions opposables au prototype — c'est le point fort du chapitre.

Corrigé : « six prescriptions » → **huit**, avec mention que les deux dernières sont nées de
l'exécution (24.08). Seul manque, déjà déclaré en limite (5) : aucune source professionnelle
suisse ni entretien praticien.

### O2 — Identifier les indicateurs : deux non-conformités tranchées

Vérifié : 27 sources qualifiées **nominativement** (auteur + date, sans exception), triptyque
fréquence/format/accès complet sur toutes, 44 indicateurs sur 46 rattachés à une question — le
rattachement étant imposé par déclencheur.

**Décision de l'étudiant n° 1 — S&P Global PMI retiré.** La source portait `access = payant` dans
un travail dont l'OSINT est la contrainte fondatrice. Zéro indicateur, zéro liaison, zéro
observation : suppression franche. **Le référentiel compte désormais 26 sources, toutes en accès
libre, sans exception.** Motivé au § 8.3, avec le point de méthode : fiabilité et conformité au
cadre sont deux jugements distincts, et une source excellente peut être écartée pour le second.

**Décision de l'étudiant n° 2 — T12/T13 retirés de la grille, pas du registre.** Ils violaient la
règle « pas d'indicateur sans question ». Mais ils portent 322 observations, et le registre est en
ajout seul : les supprimer aurait exigé de suspendre `trg_registre_ajout_seul` pour effacer des
mesures réellement collectées — la surdéclaration à l'envers, effacer une trace pour faire propre.
Traitement retenu, qui devient la **règle générale du dispositif** : *un indicateur sort de la
grille, jamais du registre.* Concrètement : statut `restreint`, hors vitrine, aucune liaison,
motif daté dans la description, **et le socle reconstruit ne les contient pas** — une base neuve
démarre sans eux. L'écart entre base en service et socle est la forme la plus complète du retrait
dans un dispositif à historique immuable ; il est expliqué au § 8.4.5.

**Reste ouvert sur O2, et cela dépend de l'étudiant** : l'analyse des besoins — étape que le
§ 4.3 désigne comme fondatrice — n'a jamais été confrontée à CODEC. Les 21 questions instanciées
sont validées par personne d'autre que leur auteur. Déclaré en limite (5).

Livrables régénérés : socle, annexe 1, sources de données (§ D2).

### O3 — Évaluer les approches d'IA : atteint, deux chaînons comblés

Vérifié : état de l'art complet (§ 6.1-6.4), protocole en **3 vagues / 4 éditeurs / 4 tâches /
52 exécutions** avec dépouillements en annexe 3 (74 fichiers de traces pour la seule vague 3),
architecture cible au ch. 10 (six couches, onze règles d'interprétation, confrontation B/C).

Trois éléments au-dessus de l'attendu : la **vague 3 par API** (résultat non trivial — la
variance intra-modèle dépend des conditions d'exécution, sauf chez un éditeur), la **vérité
terrain** sur T2/T4 qui permet des mesures et non des impressions, et la **construction du
scénario écarté** pour le confronter.

**Deux chaînons manquants, comblés le 26.08 :**

1. **§ 10.5.3 laissait le lecteur devant une grille de tirets.** Les dix dimensions étaient
   fixées *avant* exécution — ce qui est correct et fait la valeur du protocole — mais rien ne
   disait où trouver les résultats. Ajout d'un paragraphe qui explique pourquoi les colonnes
   sont vides (une grille renseignée après coup s'ajuste à ce qu'on a trouvé) et renvoie au
   § 11.9 et à l'annexe 7, avec les résultats saillants : traçabilité 100 % / 64 %, fidélité
   91 % / 58 %, reproductibilité déterministe / 17 %, auditabilité 100 % / 0 % — et deux
   dimensions déclarées **non mesurées** plutôt qu'estimées.
2. **§ 9.5.1 créé — « Du protocole aux modèles retenus ».** Le § 9.5 ne nommait aucun modèle : le
   lecteur ne pouvait pas relier 52 exécutions sur quatre éditeurs à un prototype qui en emploie
   deux. La section établit la logique : le triage et la lecture décisionnelle vont à un modèle
   rapide **parce que la mesure a établi l'unanimité sur cette tâche** (6/6, aucun chiffre
   inventé) — quand la qualité ne discrimine pas, le coût décide, et le volume est de milliers
   d'items ; le commentaire va à un modèle de raisonnement parce que c'est là que fidélité et
   traçabilité se séparent (5/5 à 2/5) et que le volume est faible. Et aucun modèle ne touche
   aux chiffres : conclusion expérimentale, pas précaution de principe. Réserve déclarée : les
   versions ont évolué entre l'expérimentation et l'implémentation — le protocole établit une
   répartition par type de tâche, non un classement de produits.

Corrigé aussi : le commentaire de `assembler_rapport.sh` citait encore § 9.4 et § 10.5.3 comme
« sections vides ».

### O4 — Concevoir et implémenter le prototype : atteint

Vérifié sur pièce le 26.08 :

| Livrable de O4 | Mesure |
|---|---|
| Collecte | 38 indicateurs, **122 593 observations**, 71 exécutions, 70 liaisons actives sur 6 connecteurs |
| Traitement | 36 vues de calcul, **43 contraintes** et 3 déclencheurs qui imposent les règles |
| Composants d'IA | extraction composite (7 périodes) · synthèse (68 commentaires, 25 validés / **38 rejetés**) · triage (1 526) · lecture décisionnelle (324) · signaux (5) · couche 0 (19 candidats) |
| Tableau de bord | servi, HTTP 200 |
| Contrainte E5 | **4 images publiques, zéro licence** — `docker compose up` suffit |

Trois points forts : les contrôles sont **exercés** et non déclarés (43 contraintes, cinq
écritures illicites refusées en démonstration) ; le **rejet est conservé** (38 commentaires
rejetés visibles) ; la reproductibilité est **testée** sur conteneur neuf, pas supposée.

Deux limites déjà déclarées, structurelles et non corrigeables avant dépôt : le pipeline
composite ne tourne que sur **un** indicateur (limite 2), la couche 0 sur **un** run.

**Corrigé au § 11.1** : la ligne « Tableau de bord » annonçait la cinquième itération (il y en a
eu huit, la dernière rétablissant la structure v3) ; la volumétrie citait « trente-neuf mille
observations sur nonante exécutions » au lieu de 122 593 sur 71.

### O5 — Appliquer aux marchés cibles et évaluer : deux volets sur trois

**Instanciation — atteinte, au-delà de la demande.** O5 exigeait « un historique de trois ans » ;
le dispositif en porte **douze**. Horlogerie 81 248 observations (2014-01 → 2026-07), automobile
11 253, médical 9 362, aérospatial 5 887. 21 questions instanciées avec mécanisme causal.

**Évaluation, critères 1 et 2 — atteints ET exercés.** L'exactitude contre vérité terrain : les
sept valeurs composites vérifiées une par une contre le document source, les commentaires
vérifiés ligne à ligne — avec **trois textes sur quatre rejetés** à la première fournée, pour des
violations qu'aucun contrôle automatique n'avait vues. La pertinence et la consistance : le
protocole du ch. 9 reporté dans le pipeline (trois modèles, consensus à l'unanimité, accord
partiel routant vers l'humain), règle exercée dès la première exécution réelle.

**Évaluation, critère 3 — NON EXÉCUTÉ.** L'utilité perçue. C'est le seul manque réel des cinq
objectifs, et il compte double : c'est le troisième critère nommé dans O5, et l'analyse des
besoins du § 4.3 souffre de la même racine — personne d'autre que l'étudiant n'a regardé ce
dispositif.

**Il est rattrapable, et le nécessaire est prêt.** `protocole_utilite_percue.md` créé : version
opératoire du protocole du § 12.4, conçue pour tenir en **quarante minutes avec un seul
interlocuteur** — dix minutes de lecture de la note de veille sans explication (la mesure la plus
honnête : ce qui doit être expliqué pour être compris ne l'est pas), quinze minutes
d'application, les quatre questions posées telles quelles et notées verbatim, plus la question
finale (« qu'est-ce qui vous manquerait le plus si on vous retirait cet outil demain ? »).

La note de veille hebdomadaire rend ce recueil praticable à distance : l'interlocuteur n'a rien à
installer. Un résultat négatif reste un résultat — un enseignement de conception vaut mieux
qu'une case cochée sans mesure. Et si le recueil n'a pas lieu, le protocole dit comment le
documenter : la cause factuelle, sans imputation.

---

## 26.08.2026 — Élagage RÉVISÉ : de treize à vingt-huit indicateurs

**Décision de l'étudiant après examen de la couverture des questions de veille.** L'élagage du
25.08 était nécessaire mais mal conduit ; trois erreurs reconnues sur pièces :

1. **Seuil arbitraire** — « treize » visait la lisibilité d'un écran, pas la validité d'une
   grille. L'écran se règle par la mise en page, la grille par des critères.
2. **Ordre de vérification inversé** — la coupe raisonnait indicateur par indicateur et ne
   contrôlait la couverture des questions qu'après. Trois questions horlogères ont perdu leur
   dernier porteur, alors que « pas d'indicateur sans question » est imposé en base à
   l'insertion : une règle qui gouverne l'écriture mais pas le retrait n'est appliquée qu'à moitié.
3. **Seuil de corrélation trop bas** — à 0,90, A5 était retiré alors que le § 8.6 entier est
   bâti sur l'ÉCART A5/A6. Recalcul : **une seule paire dépasse 0,95** dans tout le référentiel
   (H7/H8 à 0,992). Le seuil de 0,90 en condamnait cinq de plus.

**La révision** ne retire que l'indéfendable, recalculé depuis les données : 8 sans aucune
observation, 5 sous huit points, 2 arrêtés en 2022, 1 doublon à 0,992. **28 en grille**
(4-5 par marché + 10 au socle), 18 en réserve. **Les cinq marchés redeviennent scorables**, et
H1 revient — sa ventilation par pays redevient un indicateur de plein droit.

Deux décisions écrites plutôt que silencieuses : **A2 conservé** malgré ses 7 points (seul
composite, donc seul à démontrer la chaîne consensus/validation — le critère de rôle prime sur
celui de profondeur) ; **sixième critère ajouté** — ne priver aucune question de son dernier
porteur.

**Ce que la révision ne corrige pas, et c'est un résultat** : cinq questions restent découvertes
(aérospatial QV4 ; automobile QV3-QV4-QV5 ; horlogerie QV4-QV5). Le recalcul établit qu'elles
l'étaient AVANT tout élagage — lacunes de grille, non victimes de la coupe. La distinction
n'aurait pas été formulable sans cadre invariant.

**§ 8.8.7 créé** — « quand un critère se retourne contre sa thèse ». L'enseignement de conduite y
dépasse le cas : un critère quantitatif appliqué sans garde-fou produit des décisions défendables
une par une et absurdes ensemble ; et ce qui a protégé le dispositif n'est pas la finesse du
critère mais le fait que la coupe soit **rejouable** — recalculée par requête, la révision a coûté
une migration. Un élagage saisi à la main aurait été irréversible en pratique.

Décomptes alignés partout (13 → 28, cinq → six critères), socle, annexe 1 et bulletin régénérés,
onze écrans vérifiés, build servi.

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
n'était pas le garde-fou : celui-ci est structurel — `alert_threshold_pct` est **nul** sur T8 et
T10 (et l'était sur A7 et M6 jusqu'aux calibrages du 31.08 : 55 puis 38 % pour A7, 22 puis 20 %
pour M6 — phrase corrigée le 02.09, A7), et RI4 est appliquée par la consigne du workflow. La consigne de lecture utile
(lire en points, pas en pourcentage) est conservée côté lecteur.

**Où le journal reparaît** : onglet « La grille » de l'écran Fiabilité, servi par
`veille/donnees`. Rien n'est perdu, rien ne s'affiche là où cela gênait.

## 27.08.2026 — L'intensité de signalement : la grille apprend à fabriquer

**Décision de l'étudiant du 27.08.2026** (« carte blanche » sur la revue des questions de
veille — décision de conduite tracée, à ratifier avec les autres, § 7.2.2) : traiter les quatre
corrections en attente depuis le 26.08 ET combler les cases vides de la vitrine par des
indicateurs dérivés du triage IA. La QV6 (intensité concurrentielle) est arbitrée en
**perspective argumentée** (§ 13.6), pas en implémentation — le cadre à six angles du 07.08
reste intact.

### Les corrections du 26.08, exécutées

1. Horlogerie × QV5 : criticité `marginale` → `significative`
   (`2026-08-27_corrections_questions_veille.sql`). La contradiction avec le mécanisme
   instancié et le § 11.12 est résolue dans le sens qui AGGRAVE la lacune déclarée, et c'est
   assumé dans le § 8.4.5.
2. Matrice de couverture de la vitrine : vue `v_couverture_vitrine` créée, § 8.4.5 réécrit —
   l'écart référentiel/vitrine est promu au rang de résultat (6 cases sur 20 sans porteur au
   26.08, dont 3 dominantes, toutes en QV3/QV4/QV5).
3. QV0 assumé au § 8.3.1 : ~un indicateur sur trois au socle, décompte par requête.
4. Table décision → question ajoutée au § 8.1.2 (anticiper / prospecter / investir), avec la
   précision d'honnêteté : les questions INSTRUISENT la décision, elles ne la prennent pas.
   Plus : § 8.1.2 « barre » reformulé (le cadre précède l'instanciation — aucun test n'a eu
   lieu) ; « cinq questions découvertes » corrigé en « six » au § 8.8.7 (4e dérive de décompte
   textuel).

### La famille S9 / A9 / A10 / H10, exécutée de bout en bout

**Mesure** : part mensuelle des items triés d'un secteur attribués à la question (pertinence
>= 1, item compté une fois, tous doctrines). Une PART, pas un compte — le corpus grandit encore.
**Plancher de calculabilité : 20 items triés/secteur/mois** (résolution : 1 item <= 5 points).
**Conséquence assumée : H10 n'a AUCUN point calculable** (horlogerie, 16 items en août) — en
grille, à l'écran, avec sa raison chiffrée.

Chaîne exécutée et vérifiée sur pièce :
- Migration `2026-08-27_intensite_signalement.sql` : source interne `triage_flux` (27e entrée,
  étiquetée dérivation — le § 8.3 distingue désormais 26 externes + 1 interne), 4 indicateurs
  `composite` / `a_confirmer` / `en_vitrine` (critère de rôle, précédent A2), vue
  `v_intensite_signalement`. + correctif du même jour : geo_reference 'World' → 'WORLD'
  (v_vitrine joint sur l'égalité stricte ; détecté à la vérification d'écran).
- Workflow `derivation_intensite_signalement.json` (id `dN8uiR4bud4RopM6`) importé et exécuté —
  **run 158** : 5 points en `validation_queue`, extractions avec titres des items, n/d, et
  mention explicite « consensus non établi — modèle unique, routage humain systématique »
  (consensus_score = 0, précédent A2). Le NOT EXISTS protège contre la remise en file.
- **Validation humaine de l'étudiant, en session, sur pièces présentées** (les titres des items
  par point) : les 5 points acceptés, `decided_by = 'N. Castillo'`, écrits au registre en
  `ia_extraction` / `valide_humain` / consensus_score NULL (non mesurable — écrire 0 ou 1 aurait
  surdéclaré dans les deux sens).
- Restants en file, PAS À MOI : les 3 lignes A2 de 2025-11 (file 1-3), indécises depuis le
  12.08 — supersédées par la ligne 4 acceptée, à solder par l'étudiant.

**Séries** : S9 2026-08 = 16,9 % (21/124) · A9 2026-07 = 4,8 %, 2026-08 = 17,8 % (18/101) ·
A10 2026-07 = 9,5 %, 2026-08 = 16,8 % (17/101). Les items d'A10 d'août : escalade douanière
US/Canada, subventions (Rome, Californie, BNDES), Joint Undertaking — la mesure capte bien QV5.

### Écran — trois comportements vérifiés, deux corrigés (Secteur.jsx, Fiabilite.jsx)

1. `sens_favorable = 0` (neutre, déclaré) était écrasé en favorable par `Number(x) || 1` : le
   +270 % d'A9 (artefact de composition juillet/août) se serait affiché en vert. Corrigé : sens
   neutre = variation jamais colorée.
2. Carte sans valeur : « collecte non instrumentée » était faux pour H10 — affiche désormais la
   raison mesurée (« 16 items triés en 2026-08 pour un plancher de 20 »), servie par la clé
   `intensite_attente` ajoutée à l'API santé. ATTENTION : `Marche.jsx` est une page MORTE
   (v8 du 26.08 route `Secteur.jsx`) — première retouche faite au mauvais endroit, annulée par
   `git checkout`, leçon : vérifier `App.jsx` avant de toucher une page.
3. Panneau des questions : 3 états (couverte / à confirmer avec porteurs VIVANTS / non
   couverte) — un porteur sans observation ne compte pas (couverture nominale, § 8.4.5).
   Tuiles Fiabilité recalées (« choisis parmi N certifiés » devenu faux ; « sources
   institutionnelles » → « dont une dérivation interne »).

Vérifié : 17 écrans rendent (harnais `verification/executer.sh`), build servi (nginx, 200),
API réactivée après réimport — **l'import n8n DÉSACTIVE le workflow** (`update:workflow --id
apiRestitutionV4 --active=true` puis restart ; il existe des doublons historiques du workflow
API, seul `apiRestitutionV4` sert).

### Livrables réalignés

Annexe 1 et D2 régénérés par script. **Socle régénéré** (`regenerer_socle.sh`) et vérifié sur
base de recette : 25 tables, 40 vues, 48 indicateurs (50 moins T12/T13), 73 liaisons, 0
observation. Rapport : § 8.10 créé, § 8.4.5 réécrit, § 8.1.2/8.3/8.3.1/8.8.4/8.8.7 amendés,
§ 11.14 créé, § 12.2 et § 12.5 (1) recalés (41 collectés / 50 qualifiés / 32 en grille),
§ 13.6 : décomptes + « Une septième question, identifiée et volontairement non ajoutée » (QV6).
Docx réassemblé. **Décompte courant : 32 en grille (28 certifiés + 4 à confirmer), 39 certifiés
au référentiel sur 50 — par requête (`v_bilan_referentiel`), jamais depuis ce texte.**

### Reste à faire

- Captures d'écran pour les figures : carte S9/A9/A10 avec badge, carte H10 « en attente de
  corpus », panneau des questions à trois états, run 158 dans n8n.
- Prochain run de dérivation début septembre (point 2026-09 ; H10 s'activera si le corpus
  horloger franchit 20 — sinon, l'écart entre runs documentera la stagnation du corpus).
- Faire ratifier les décisions du 27.08 en supervision (§ 7.2.2).
- Les 3 lignes A2 indécises de la file (ci-dessus).

## 27.08.2026 (suite) — Motorisations automobile : A11, retour d'A3, dérivation thermique

**Proposition de l'étudiant** (« total mondial des ventes, thermique et électrique — possible ? »),
**exécutée après examen de l'existant** : A3 (IEA) était collecté mais hors vitrine, et la même
API publie « EV sales share ». Réponse réelle vue le 27.08 sur 2010/2015/2020/2024 (lignes
World, powertrain agrégé EV, unit percent ; recoupement 17 M / 21 % ≈ 81 M, plausible).

Migration `2026-08-27_motorisations_automobile.sql` :
- **A11** — part électrique des ventes mondiales (hard, annuelle, certifié, en vitrine, QV4,
  sens neutre 0). Collectée telle quelle — la part est calculée par la source.
- **A3 de retour en vitrine** ; liaisons étendues 2010-2025 (une par millésime, `year` exigé).
- **v_motorisations_automobile** : total = EV ÷ part, thermique = total − EV. SQL pur.
- 29 liaisons semées, statut actif, `verifie_par` en délégation datée.

**Collecte : run 159** (collecteur générique, exécution normale) — 9 364 obs sur 30 indicateurs,
1 071 écartées par contrôles qualité, **« partiel » pour un seul incident : M3 timeout 60 s
(OMS GHED, connu, sans lien)**. ATTENTION à la sortie CLI : ~20 Mo, tronquée — vérifier en base,
pas dans le JSON du CLI.

**Constat d'exécution, cause établie sur pièce** : 2010-2013 absents du registre — ce n'est pas
un défaut, c'est la **fenêtre d'historique des séries annuelles (2014**, règle du 24.08 « à
ratifier » dans `Contrôles qualité déterministes`) : décodés puis écartés « hors fenêtre »,
comptés dans les 1 071. Séries servies : **12 points (2014-2025)** sur World pour A3 et A11 —
le critère d'élagage des douze points est satisfait *au point près*. Notes de conception
corrigées en conséquence (j'avais écrit « ~16 points » avant l'exécution : faux, rectifié).

**Lecture produite** (v_motorisations_automobile) : thermique ~84,5 M (2017) → ~63 M (2025),
total revenu à ~84 M. Le recul du thermique est structurel — QV4 en chiffres. Réserve : valeurs
IEA en millions arrondis, le total dérivé est un ordre de grandeur (dit au § 11.14).

**Défaut d'écran débusqué par A11** : `CarteIndicateur` prenait `agregats[0]` comme zone
principale — avec plusieurs agrégats (World + Advanced Economies + Europe…), le mauvais chiffre
s'affichait en gros (16 au lieu de 25). Corrigé : l'API `/donnees` expose désormais
`geo_reference` (réimport → **réactiver `apiRestitutionV4` + restart**, toujours) et la carte
préfère la zone de référence déclarée. Vérifié : 17 écrans, A11 à « 25 · World », build servi.

**Couverture après la journée** (`v_couverture_vitrine`) : **une seule case découverte dans
toute la grille — horlogerie × QV5.** Automobile intégralement couverte (QV4 : A3+A11 certifiés
+ A9). Décomptes courants par requête : **34 en grille, 51 au référentiel, 40 certifiés,
42 collectés.** Rapport recalé (§ 8.4.3 complété, § 8.4.5, § 8.8.4, § 11.12, § 11.14 étendu,
§ 12.2, § 12.5 (1), § 13.6), annexe 1 + D2 + socle régénérés (recette : 49 indicateurs,
102 liaisons), docx réassemblé.

**Reste** : ratification (fenêtre 2014 comprise, elle était déjà en attente) ; figures ;
éventuelle restitution à l'écran de v_motorisations_automobile (vue requêtable, non affichée —
candidate pour l'écran « Anticiper » ou la page automobile, à décider).

## 27.08.2026 (fin) — La carte A11 relue par l'étudiant : un ratio ne se classe pas par niveau

Question de l'étudiant devant la capture d'écran : « sincèrement, un décideur comprend ?
pourquoi la Norvège, le Danemark, le Népal ? » — et il avait raison. Trois corrections
(`Secteur.jsx`, `api.jsx`, API `/donnees`), toutes généralisées :

1. **Classement par volume compagnon.** `VOLUMES_COMPAGNONS = { A11: { id: 'A3' } }` : les
   zones d'un indicateur de part sont classées par le volume du compagnon, pas par la part —
   Chine 53 % (+5 pt), USA 10 % (0 pt), Allemagne 30 % (+10 pt) remplacent Norvège/Népal.
   `maxRef` recalculé par Math.max (l'ordre de tri ne donne plus le max). Note d'écran
   explicative affichée. Extensible à tout futur couple part/volume.
2. **Variation en points.** Pour `unit = 'pourcentage'` : badge « +4 pt sur un an »
   (depuis `valeur_annee_precedente` de v_dernier_point) au lieu de « +19,1 % » ; idem par
   zone dans le panneau (Δ en pt, sans couleur).
3. **Sens neutre respecté aussi sur la carte** (le correctif du matin ne couvrait que
   FicheIndicateur/Marche — page morte — et fi-chiffres ; `CarteIndicateur` colorait encore).
   L'API `/donnees` expose désormais `sens_favorable` (réimport + réactivation
   apiRestitutionV4 + restart, comme toujours).
   + `Southeast Asia` ajouté aux AGREGATS (se mêlait aux pays).

Vérifié : 17 écrans, build servi. Rapport : bloc « troisième temps » ajouté au § 11.14, avec la
précaution de statut — revue de l'auteur en position d'usager, PAS l'évaluation d'utilité
perçue du § 12.4 (regard tiers, toujours non exécutée). Docx à réassembler faisait partie du
lot ; fait.

## 27.08.2026 (soir) — v9 : la page marché réorganisée par questions de veille

**Décision de l'étudiant, carte blanche explicite** (« je ne suis pas okay avec mon tableau de
bord... un tableau qu'un décideur peut lire ») : neuvième itération de la restitution. Aucun
contenu nouveau — une RÉORGANISATION : la thèse questions → indicateurs → lecture devient la
structure de l'écran. `Secteur.jsx` réécrit (page assembly + SectionQuestion), `Signaux` prend
`qv`/`compact`, composant `Motorisations` créé (v_motorisations_automobile à l'écran, sous
auto × QV4).

Structure v9 d'une page marché :
1. Lecture calculée + commentaire validé + alertes (inchangé).
2. **Une section par question instanciée, criticité d'abord** : question en toutes lettres,
   mécanisme repliable, badge d'état à QUATRE valeurs (couverte / à confirmer / instrumentée ·
   en attente de corpus [H10] / non couverte), indicateurs de la question, signaux qualitatifs
   de la question (rattachement en base respecté).
3. **Un indicateur = une carte**, sous sa question la plus critique ; les autres sections y
   renvoient (« Instruite aussi par H3 (→ QV2) »).
4. Question découverte (horlo QV5) : bloc « lacune déclarée » en toutes lettres.
5. **Vitrine seulement** : la réserve sort de la page décideur (les cartes vides « non
   instrumenté » polluaient — médical passe de 33k à 23k caractères rendus), comptée en pied
   de page, consultable dans Fiabilité · grille. Distinction § 8.8 appliquée à l'écran.

API `/donnees` : + `en_vitrine`, + clé `motorisations` (12 lignes). Toujours le rituel
réimport → `update:workflow --id apiRestitutionV4 --active=true` → restart.

Garde-fou d'affichage conservé : si `en_vitrine` absent de la charge (cache), repli sur
`observations > 0`.

Vérifié : 17 écrans rendent, build servi (nginx 200). Rapport : **§ 11.15 créé**, § 12.2
réécrit (l'affirmation « organisée pour répondre aux questions » est enfin littérale). Même
statut que la carte A11 : revue de l'auteur en position d'usager, PAS l'évaluation d'utilité
perçue — dit au § 11.15.

**Reste / figures** : les captures du rapport doivent être REFAITES sur la v9 (les anciennes
montrent la structure par indicateurs) ; candidates : automobile (sections QV1→QV5 + panneau
motorisations), horlogerie QV5 (lacune déclarée), carte A11 corrigée.

## 27.08.2026 (soir, 2) — FH : provenance précisée, étiquette d'écran corrigée

Question de l'étudiant : « pourquoi la FH est marquée source officielle alors qu'elle se base
sur des statistiques publiques ? pour moi c'est du composite. » Réponse en deux temps, tracée :

1. **Non, pas composite** : hard/composite = mode d'obtention de la valeur (code déterministe
   vs jugement d'IA + validation), jamais autorité du producteur. H7/H8/H9 = tableau PDF lu par
   code (`etl`, 95 obs chacun) — la règle du § 8.6.4 (« la donnée y est structurée, seule son
   enveloppe ne l'est pas »). Précision factuelle : la FH rediffuse la statistique DOUANIÈRE
   (OFDF), pas l'OFS (l'OFS, c'est H2/STATENT).
2. **Mais l'œil avait raison sur l'écran** : l'étiquette « donnée officielle » pour la
   catégorie hard confondait traitement et autorité — faux pour la FH (fédération
   professionnelle, source secondaire d'un chiffre officiel). Corrigé dans `Secteur.jsx`
   (2 occurrences) : hard → « collecté par code », composite → « composite · IA + validation ».

Appliqué : note de provenance datée sur `sources.fh`, paragraphe de provenance au § 8.6.4
(+ « la source institutionnelle nationale » → « la statistique nationale »), annexe 1 et D2
régénérées, 17 écrans vérifiés, build servi.

## 27.08.2026 (nuit) — Revue visuelle sur captures réelles, et l'outillage qui la permet

Question de l'étudiant : « peux-tu voir tout mon tableau de bord ? » Réponse construite :
**oui, désormais** — le harnais textuel ne montre ni mise en page ni graphiques, l'extension
Chrome n'est pas installée, le Brave flatpak refuse le headless. Solution retenue :
`verification/captures.mjs` + puppeteer (devDependency, chrome-headless-shell dans
~/.cache/puppeteer — JAMAIS dans l'image de production, E5 intact, dit dans l'en-tête du
script). `node verification/captures.mjs` capture les **11 écrans en pleine page** vers
`annexes/6_captures/v9/` (hors dépôt, couvert par la copie Drive). Reproductible → les figures
de l'annexe 6 se régénèrent en une commande.

**Ce que la revue sur pixels a attrapé (invisible au rendu textuel) :**
1. **Mur d'alertes zone par zone** — H1 : 123 franchissements (destinations), A3 : 63 (pays,
   depuis l'extension du jour) servis ligne à ligne ; la page horlogerie ouvrait sur un écran
   entier de lignes rouges. Règle d'écran : une alerte de ZONE ne vaut pas une alerte de
   SÉRIE — au-delà de 3 sur un même indicateur : une ligne repliable (`Alertes`), bandeau
   `Lecture` et Accueil comptent des séries (« 2 séries en franchissement (64 signalements) »),
   « À examiner » de l'Accueil : une ligne par série. Détail replié PAS classé par variation
   (piège du palmarès des petites zones, cf. A11).
2. **Montants bruts illisibles** : « 3 241 199 778 USD » → `valeurLisible()` : « 3,24 mia
   USD » ; réservé aux unités monétaires (USD/CHF/EUR ≥ 1 mio) — un compte d'unités reste un
   compte (21 000 000 de VE reste tel quel).
3. **Pied de barre latérale mensonger** : « Restitution v8 » → « v9 — structurée par questions
   de veille le 27.08 ». Tuiles secteurs de l'Accueil passées à la vitrine (elles comptaient le
   référentiel entier).

Vérifié après correctifs : 17 écrans (harnais), build servi, captures régénérées. § 11.15
complété (revue visuelle + outil). Fichiers : `Secteur.jsx`, `Accueil.jsx`, `App.jsx`,
`package.json` (+puppeteer dev), `verification/captures.mjs` (nouveau).

## 28.08.2026 — Les deux gestes de la v9 : la réponse calculée, l'accueil retourné

Décision de l'étudiant (« fais les deux gestes ! ») après ma critique sincère de la v9 : (1) les
questions n'avaient pas de RÉPONSE, (2) l'accueil parlait du dispositif, pas des marchés.

**Geste 1 — la réponse calculée** (`2026-08-28_reponses_par_gabarit.sql`) :
- Colonne `sector_watch_questions.reponse_gabarit` + 18 gabarits (les 3 questions sans porteur
  vivant restent NULL — un vide ne se paraphrase pas). Exposée par `v_instanciation_qv`
  (colonne ajoutée en queue, CREATE OR REPLACE légal).
- Jetons `{ID.val|unit|ga|vp|pt|per}` résolus dans `Secteur.jsx` (`resoudreGabarit`) depuis
  v_dernier_point SUR LA ZONE DE RÉFÉRENCE (metrDe avec geo explicite — sans geo, la première
  ligne servie est arbitraire). **Un jeton irrésolu supprime la phrase entière** — jamais de
  phrase à trous. Chaque gabarit n'emploie que des jetons vérifiés disponibles au 27.08
  (requête préalable sur v_dernier_point) ; ATTENTION aux zones de référence Comtrade
  (A4 = Allemagne, S6 = France, M1/H3 = Suisse) : les gabarits les nomment explicitement pour
  ne pas faire passer un déclarant pour un monde. Les gabarits des intensités portent leur
  réserve (« série jeune, à confirmer ») dans leur propre texte.
- Affiché sous la question avec la signature « composée par gabarit depuis la base — aucun
  modèle de langage n'écrit cette phrase ». Doctrine du 12.08 appliquée.

**Geste 2 — l'accueil vers les marchés** (`Accueil.jsx`, `Fiabilite.jsx`) :
- 4 tuiles marché (g2) : extrait « Ce qu'il faut retenir » du commentaire exécutif VALIDÉ
  (fonction `retenir()` — texte repris tel quel, coupé en fin de phrase, jamais reformulé ;
  seul le validé s'affiche), n/vitrine suivis, franchissements en séries.
- Compteurs de dispositif (observations au registre, révisions/comparaisons) rapatriés dans le
  sommaire de Fiabilité.
- « À examiner » : une ligne PAR SÉRIE, en préférant la zone de référence puis la période la
  plus récente, suffixe « · N zones en franchissement » — fini le « A3 — Seychelles, 2023 » en
  tête d'accueil.

Vérifié : 17 écrans (harnais), build servi, captures v9 régénérées (annexes/6_captures/v9/),
socle régénéré (recette : 25 tables, 41 vues, 49 indicateurs, 102 liaisons). § 11.15 complété.
Nouvelle migration au dépôt : `2026-08-28_reponses_par_gabarit.sql`.

## 28.08.2026 (suite) — QV1 : la question reçoit son porteur littéral (H2, M4)

Question de l'étudiant : « les deux indicateurs reliés à QV1 horlogerie répondent-ils à la
question ? » Analyse sur pièces : **partiellement** — H9 répond au MÉCANISME (valeur vs pièces,
§ 8.6.4), H6 est un proxy d'activité au périmètre UE (Eurostat ne couvre pas la Suisse), et le
porteur LITTÉRAL (« emplois et établissements... suisses ») était H2, en réserve avec 4 points.

**La profondeur était un paramètre, pas une limite** (même leçon qu'A3) : le cube PX-Web
px-x-0602010000_103 porte 2011-2024 (vérifié sur métadonnées, GET sans corps) ; la liaison du
25.08 demandait « top: 4 ». Exécuté :
- `2026-08-28_profondeur_H2_M4.sql` : nouvelles liaisons top:14 (142/143), anciennes (97/98)
  **suspendues** — ATTENTION, le vocabulaire de `source_bindings.statut` est
  a_verifier/actif/suspendu, PAS « ecarte » (première tentative refusée par la contrainte).
  M4 traité dans le même geste : critique identique pour médical × QV1 (seul proxy M2/UE).
- Collecte run 160 (statut ok — M3 a répondu cette fois) : H2 et M4 à **11 points (2014-2024)**,
  la fenêtre annuelle (2014) écartant 2011-2013.
- **Critère d'admission, précision importante** : les notes du 25.08 disaient « moins de douze
  points » — c'était le seuil de la PREMIÈRE coupe ; le seuil en vigueur depuis la révision du
  26.08 (§ 8.8.7) est HUIT points. Onze ≥ huit : retour en vitrine réglementaire, rien n'est
  plié. Dit dans les notes de conception et au § 11.15.
- `2026-08-28_retour_H2_M4_vitrine.sql` : en_vitrine + gabarits QV1 réécrits (les emplois EN
  PREMIER — « le tissu se lit dans les pièces » contournait le manque, le manque comblé
  l'élégance tombe).

Premières lectures : H2 = 56 866 emplois horlogers (2024, −1,0 % sur un an — l'érosion que la
question guette, première mesure) ; M4 = 33 104 emplois medtech (+0,2 %). Couverture QV1 :
quatre secteurs couverts en certifié, horlogerie = H2+H6+H9. **Grille : 36** (42 collectés /
51 au référentiel — inchangés). Rapport réaligné (§ 8.4.5, § 8.8.4, § 11.12 daté au lieu de
recalculé, § 11.15 complété, § 12.5 (1), § 13.6). Socle et annexe 1 régénérés, 17 écrans,
build servi, captures régénérées.

Volet « établissements » du même cube (Beobachtungseinheit=1) : extension identifiée, non
instrumentée — un indicateur, une grandeur.

## 30.08.2026 — File A2 soldée : rejet des trois lignes du débogage

**Décision de l'étudiant, prise en session après examen sur pièces.** Les items 1-3 de
`validation_queue` (A2, 2025-11, EU27, consensus 0 — en attente depuis les 09-12.08) sont
passés à `decision='rejete'` (decided_by N. Castillo, 30.08). Motif : les trois runs
d'extraction (10, 26, 27) sont des échecs **techniques complets** — aucun des trois appels
n'a abouti dans aucun des trois runs (credentials n8n non branchés pour le run 10 ; 429 /
`temperature` dépréciée / modèle retiré pour le 26 ; clés d'API invalides pour le 27). Les
extractions sont `[null, null, null]` sur les trois champs : rien à arbitrer.

Ce que le rejet ne touche pas : **2025-11 n'a jamais été un trou** — 887 491 immatriculations,
`valide_humain` (runs 29-30, une fois le pipeline réparé). Les lignes rejetées restent en base
avec signature et date (l'outil n'écrase jamais) ; elles documentent un mode de défaillance
distinct de la divergence de consensus : l'échec technique amont, que la file a correctement
retenu sans rien écrire en base. La file `validation_queue` est à **zéro en attente**.

À ratifier en supervision avec les autres décisions d'étudiant (§ 7.2.2).

## 30.08.2026 — La source OFS citée à son adresse réelle, et le générateur qui mentait

**Point de départ** : demande de l'étudiant — « donne-moi le lien exact d'où viennent les
données de H2 ». La réponse n'était pas dans le rapport : l'entrée « Office fédéral de la
statistique » de la section « Sources de données » portait `https://www.bfs.admin.ch` et le
format « CSV / Excel ». Les liaisons actives (142 pour M4, 143 pour H2) appellent en réalité
l'API PX-Web en POST, JSON-stat2, sur la table `px-x-0602010000_103` :
`https://www.pxweb.bfs.admin.ch/api/v1/fr/px-x-0602010000_103/px-x-0602010000_103.px`.
Vérifié en réponse réelle le 30.08 (GET, HTTP 200, 51 166 octets de métadonnées, titre officiel
« Etablissements et emplois selon Année, Canton, Genre économique et Unité d'observation »,
millésimes 2011-2024). Corrigé EN BASE — `2026-08-30_source_ofs_url_reelle.sql` — parce que D2
est produit par requête : une correction dans le texte aurait sauté à la génération suivante.
Contrôle inclus dans la migration : l'URL de `sources` concorde avec l'`url_base` des liaisons
actives.

**Ce que la vérification a découvert au passage, et qui comptait davantage.** Le générateur
`exports/generer_sources_donnees.sh` affirmait « les vingt-cinq URL ont été testées le
${GENERE_LE} » — deux défauts en une phrase :
1. **Le décompte était en toutes lettres et avait dérivé** (27 sources en base, dont 26 à URL
   externe). Cinquième dérive de décompte textuel du projet. Corrigé : `N_URL` par requête.
2. **La date de test était celle de la GÉNÉRATION**, pas d'une campagne réelle : régénérer le
   fichier faisait affirmer au rapport une vérification qui n'avait pas eu lieu. C'est
   exactement la surdéclaration que le travail s'interdit, et elle était automatisée. Corrigé :
   `VERIF_LE` en variable distincte, avec consigne de ne l'avancer qu'après une campagne réelle.

**Campagne réellement exécutée le 30.08** (26 URL externes ; sortie brute archivée dans
`annexes/verif_urls_2026-08-30.txt`) : aucun lien mort. AIE et FMI confirment leur 403.
**L'ACEA ne reproduit plus son refus** — 200 sur la page d'accueil comme sur un communiqué PDF,
avec ou sans en-tête de navigateur ; la note du rapport disait « trois producteurs », elle dit
désormais deux et consigne l'intermittence. Note technique : `ocde_brevets` exige `--globoff`
(crochets dans l'URL), et `triage_flux` n'est pas une URL (source interne au dispositif) — d'où
26 et non 27.

**Correctif annexe** : tri secondaire `s.source_id` ajouté au `ORDER BY` — les deux entrées OMPI
permutaient d'une génération à l'autre. Génération vérifiée idempotente (deux passes, diff nul).

**Tension laissée ouverte, non corrigée ici** : le libellé de H2 annonce « Emploi ET
établissements » alors que la collecte ne porte que les emplois (`Beobachtungseinheit = 2`) ;
la modalité « établissements » (= 1) est identifiée, non instrumentée. C'est une question de
libellé d'indicateur, pas de source. À trancher : soit le libellé se restreint aux emplois, soit
le second volet s'instrumente.

## 30.08.2026 — La Convention patronale : une source meilleure que STATENT, illisible par le code

**Piste ouverte par l'étudiant** : la Convention patronale de l'industrie horlogère suisse (CP)
publie un *Recensement du personnel et des entreprises* — effectifs ET entreprises, 2005-2025
en un seul tableau (Tb. 1e), au 30 septembre, publié en décembre. Sur le papier, supérieure à
STATENT sur quatre axes : fraîcheur (3 mois contre ~20), profondeur (21 points contre 11), les
deux grandeurs au lieu d'une, périmètre « horloger ET microtechnique » plus proche de CODEC.

**Comparaison des deux séries** (voir `annexes/sources_candidates/`) : la CP est
systématiquement au-dessus de STATENT, de +9,5 % à +15,4 %, et le **signe du glissement annuel
diverge 3 fois sur 10** — dont 2024, où STATENT lit −1,0 % et la CP +0,9 %. Conséquence
indépendante de toute décision d'indicateur : la phrase du § C4 « −1,0 % — l'érosion que la
question guette » ne peut plus être présentée comme LA mesure. Sous CP, l'érosion apparaît en
2025 (−1,3 %).

**Pourquoi la piste est refermée : le document n'est pas lisible par du code déterministe.**
Deux vérifications, l'une après l'autre :

1. **Aucun format structuré chez le producteur.** Page `cpih.ch/statistiques/` et pages de
   rapport annuel balayées : que des PDF, aucun xlsx/csv/json.
2. **Le nœud PDF de n8n ne peut pas rendre ce tableau.** `n8n-nodes-base.readPDF` n'expose que
   `binaryPropertyName`, `encrypted`, `password` — **aucune option de disposition** ; et
   `extractFromFile` appelle la même fonction `extractDataFromPDF`, donc changer de nœud ne
   change rien. Cause racine lue dans le code (`dist/utils/binary.js`, fonction `parseText`) :
   elle parcourt les items **dans l'ordre du flux de contenu du PDF**, se sert de Y
   (`transform[5]`) uniquement pour insérer des sauts de ligne, et **jette purement et
   simplement X**. Aucun tri par position. Or le PDF de la CP est composé **colonne par
   colonne** : la sortie est donc mélangée.

**Mesuré, pas supposé** (fichiers témoins archivés) : sur la colonne « de direction »,
concordance positionnelle **2/14** — le flux rend `1433, 1594, 8810, 9272, 1536, 10305, 1589,
10893, 1661, …`, où 8810 et 9272 appartiennent à une autre colonne et où **2009 sort avant
2008**. Sur « Total (a-d) » : **0/7**. Sur « Entreprises » : **0/1**. L'hypothèse qui fait
marcher le connecteur FH — « les nombres restent dans le BON ORDRE, seuls les sauts de ligne
sont arbitraires » — **est fausse pour ce document**. `pdftotext -layout` le rend parfaitement,
parce qu'il trie par coordonnées ; n8n ne trie pas.

**Conséquence de classement.** Par le critère retenu (« un code déterministe peut-il atteindre
la valeur de façon reproductible ? »), le recensement CP est **composite**, pas *hard* — malgré
son tableau. C'est le pendant exact du couple FH/ACEA, avec une troisième position : un document
tabulaire que l'outillage disponible ne sait pas lire. À rapprocher du motif des drapeaux perdus
(§ 12.5, couleurs de cellules SIPRI) : information structurellement présente, non extractible
par la chaîne en place.

**Décisions.** H2 **reste sur STATENT** — c'est l'exemple même donné par le directeur pour
définir *hard data* (D-19, séance 3 du 28.05), et l'ancrage officiel est une des trois lignes de
défense du projet. La CP n'est pas instrumentée dans le temps du travail ; elle est documentée
comme source identifiée, meilleure sur quatre axes, non exploitable par la chaîne — ce qui est
un résultat, pas un renoncement.

**Piste non testée, si le temps le permettait** : nœud Code chargeant `pdfjs-dist` et triant les
items par (Y, X) reconstituerait les lignes. n8n restreint les modules externes dans les nœuds
Code (`NODE_FUNCTION_ALLOW_EXTERNAL`) ; faisable en auto-hébergé, non vérifié. Ne violerait pas
la décision du 25.08 (« plus aucun script »), un nœud Code restant dans le workflow.

### 30.08.2026 (correctif) — « non exploitable » est trop large : c'est le mode TEXTE qui échoue

L'entrée ci-dessus conclut que le recensement CP n'est pas exploitable. **À corriger : il ne
l'est pas EN MODE TEXTE**, seul mode dont la chaîne dispose aujourd'hui. Vérifié dans
`extraction_composite_A2.json`, nœud « Consolider le contexte » : `const doc =
$input.first().json.text` — la chaîne composite soumet aux trois modèles la sortie de `readPDF`,
celle mesurée à 2/14. L'IA ne restitue pas ce que l'extracteur a détruit : le lien année↔valeur
vivait dans les coordonnées, jetées par `parseText`. Et la défaillance serait SILENCIEUSE — un
tableau plausible et faux, là où le parseur déterministe échoue visiblement.

**Par la vision, le document est lisible.** Lecture de la page 10 en image : les 21 lignes
sorties satisfont les identités internes du tableau (a+b+c = sous-total ; sous-total + d = total)
sur **20 lignes sur 21**, et coïncident exactement avec l'extraction indépendante
`pdftotext -layout`. Deux chemins sans communication, même résultat — la 21e ligne (2025) échoue
parce que **le document publié est faux** (sous-total surévalué de 5), pas la lecture.

**Enseignement qui dépasse ce cas, à porter au rapport** : le plafond de la chaîne composite est
fixé par son étape d'extraction de texte, pas par les modèles. ACEA (prose) → texte intact,
chaîne au niveau des modèles. Tableau en PDF composé colonne par colonne → texte détruit en
amont, aucun modèle ne rattrape. C'est une limite de l'IMPLÉMENTATION, pas de l'IA : la
distinction doit être explicite, sous peine de surdéclarer une limite de l'outil en limite de
la technologie.

**Décision inchangée** : H2 reste sur STATENT, la CP n'est pas instrumentée dans le temps du
travail. Ce qui change est le motif à écrire — non pas « illisible », mais « lisible seulement
par une voie multimodale que la chaîne n'implémente pas encore ». Extension identifiée, chiffrée
(conversion page→image, envoi multimodal aux trois modèles déjà compatibles, consensus,
validation humaine, contrôle arithmétique avant écriture), non conduite.

## 30.08.2026 — H2 bascule sur la Convention patronale : le DEUXIÈME composite instrumenté

**Décision de l'étudiant**, prise en session après la démonstration que la voie déterministe
était fermée, et en connaissance de la tension : le directeur avait pris « l'OFS quand il sort
le chiffre de la STATENT » comme EXEMPLE FONDATEUR de *hard data* (D-19, séance 3 du 28.05).
Faire passer l'emploi horloger au composite révise cet exemple. **À ratifier (§ 7.2.2).**
Bénéfice explicitement recherché par l'étudiant : un second composite instrumenté, là où le
§ 8.8 ne pouvait en déclarer qu'un.

### La voie multimodale, validée en réponse réelle avant d'être adoptée

Six appels d'API, deux tours. **Tour 1, transport** : les trois éditeurs acceptent le PDF entier
— Anthropic en bloc `document` base64, OpenAI en `input_file` (API Responses), Google en
`inline_data` `application/pdf`. Les trois rendent la valeur de contrôle (Total 2024 = 65 642).
**Tour 2, extraction complète** du tableau Tb. 1e, même consigne aux trois :

- **154 cellules, 154 unanimes, 0 divergente** — consensus parfait ;
- **154/154 exactes** confrontées à la vérité terrain (`pdftotext -layout`, chemin indépendant) ;
- **le contrôle arithmétique isole une seule anomalie, 2025** : direction + administratif +
  production = 64 727 alors que le sous-total imprimé dit 64 732. Le Total imprimé (64 807),
  lui, vaut bien 64 727 + 80. **C'est le document publié qui se trompe**, pas la lecture — et
  trois modèles unanimes ne pouvaient pas le voir. Le contrôle arithmétique attrape ce que le
  consensus ne peut pas : c'est l'argument du rang 1 de la cascade, démontré.

### Une leçon reçue de la base, à raconter telle quelle

La première version de la migration RÉATTRIBUAIT à H12 les 56 observations STATENT portées par
H2. **Le déclencheur `interdire_modification_du_registre` l'a refusée** : « le registre des
valeurs est en ajout seul (D-18) ». Le garde-fou a joué contre l'auteur de la migration, ce qui
est sa raison d'être. Rien n'a été déplacé : les valeurs STATENT restent sous H2 comme histoire
d'avant la redéfinition, les valeurs CP sont ajoutées dans un nouveau run, et `v_current`
(dernier run par période) sert une série homogène sans qu'aucune ligne n'ait été touchée.

Effet de bord vérifié AVANT d'être accepté : `v_ecart_entre_runs` montrera ~+13 % au run de
bascule sur les onze périodes communes. Aucune vue ne consomme cette vue (vérifié sur
`pg_views`), et les alertes passent par `v_metriques` → `v_current`, donc sur série homogène.
**Aucune alerte fausse.** L'écart visible au run de bascule est une trace, et vaut mieux qu'un
silence.

### Ce qui est en base (run 163)

- **H2 redéfini** : recensement CP, `composite`, périmètre horlogerie ET microtechnique, latence
  passée de `retarde` à `coincident` (enquête au 30.09, publication en décembre — ~3 mois contre
  ~20 pour STATENT ; c'était l'argument décisif pour un dispositif de VEILLE). **20 points,
  2005-2024**, `pre_valide_consensus`.
- **H11 créé** : entreprises de la branche, même tableau, même extraction, aucun appel
  supplémentaire. **12 points, 2013-2024.** Série commencée à 2013 variante 2 (avec succursales,
  seule à faire foi dès 2014, note (2) du tableau) : écrire 2005-2012 aurait fabriqué un saut de
  ~17 % sans réalité économique.
- **H12 créé** : la série STATENT sous son propre nom, `hard`, hors vitrine (doublon de grandeur
  avec H2 — critère d'élagage du 26.08). Liaison 143 transférée (nouvelle liaison 144, active) ;
  **aucune observation encore** : se remplira à la prochaine collecte générique.
- **2 items en file de validation humaine** (16 et 17) : H2 et H11 pour 2025, retenus par le
  contrôle arithmétique. **Rien n'a été écrit au registre pour 2025** — c'est à Nilo d'arbitrer.
- **Gabarit QV1 horloger réécrit** (migration dédiée) : répond désormais aux DEUX moitiés de la
  question (« emplois et établissements ») et nomme le périmètre exact — l'ancien texte disait
  « branche horlogère suisse » pour un chiffre qui compte aussi la microtechnique.

**Décomptes par requête** (`v_bilan_referentiel`) : **53 au référentiel / 41 certifiés /
39 hard + 2 COMPOSITES certifiés / 37 en grille**. Couverture horlogerie × QV1 : quatre porteurs
(H2, H6, H9, H11).

### Ce qui reste à faire, et par qui

1. **Nilo** : vérifier nominativement le document en `composite_queue` (`a_verifier` →
   `a_traiter`) — le workflow ne traite QUE les documents vérifiés, premier rang de l'humain.
2. **Nilo** : arbitrer les items 16 et 17 (2025).
3. **Nilo** : importer et exécuter `n8n_workflows/extraction_composite_CP.json`. Le workflow est
   écrit et structurellement validé, **il n'a PAS été exécuté dans n8n** — l'API répond 401, je
   n'ai pas les identifiants. Les données ont été chargées par script, comme la FH l'avait été
   avant son portage du 25.08. Tant que le workflow n'a pas tourné, dire « chargé par script,
   workflow écrit », jamais « le workflow produit la série ».
4. Lancer une collecte générique pour remplir H12.
5. Cascade de rédaction : voir `rapport/notes_de_redaction.md`, entrée du 30.08.

## 30.08.2026 (suite) — Le seuil de consensus sort du code et entre au référentiel

**Demande de l'étudiant** : ne pas faire passer toute extraction composite par l'humain ;
au-dessus d'un seuil de consensus, la valeur rejoint directement le tableau de bord.

**Constat préalable, à dire avant tout le reste : le mécanisme existait déjà et fonctionnait.**
Au chargement CP du 30.08, **32 valeurs sur 34 sont parties au registre sans aucune intervention
humaine** (`pre_valide_consensus`), l'humain n'étant sollicité que sur 6 % d'entre elles.
L'honnêteté était tenue par l'affichage : l'écran badge ces valeurs en **ambre, « pré-validé
(consensus) »**, contre **vert, « validé humainement »** — le lecteur voit toujours par quel
chemin la valeur est arrivée (`api.jsx`).

**Ce que la session ajoute n'est donc pas le routage, c'est sa DÉCLARATION.**
`indicators.seuil_consensus` (migration `2026-08-30_seuil_consensus_declare.sql`) : proportion
minimale de modèles d'accord, bornée par contrainte à ]0, 1], **obligatoire pour tout composite**
(`chk_seuil_consensus_composite`) et nulle pour les hard. Un indicateur dont les valeurs peuvent
entrer au registre sans humain ne peut pas laisser tacite la règle qui le permet. Défaut : 1.0.

Le workflow ne porte plus le seuil : nouveau nœud « Lire les seuils de consensus », une requête,
une ligne, `jsonb_object_agg`. Et le consensus n'est plus un booléen d'unanimité mais une **part
d'accord calculée par valeur modale** — 1 (3/3), 0,67 (2/3), 0,33 (tous différents) ; en cas
d'égalité parfaite aucune valeur ne se dégage et le routage bascule en file, jamais de tirage
au sort. Si le référentiel ne rend pas de seuil, on retombe sur l'unanimité, jamais sur
« pas de contrainte ».

**Vue `v_seuils_consensus`** : le seuil ET ce qu'il a produit, par composite. Sans le second, le
seuil n'est qu'une intention. Premier relevé — **A2 : 0 % d'écriture directe** (les 8 valeurs ont
toutes vu un humain) contre **H2 et H11 : 100 %**. Le contraste se raconte : le composite en
PROSE (communiqué ACEA) réclame l'humain à chaque fois, le composite TABULAIRE lu en vision ne
le réclame presque jamais.

**Pourquoi 1.0 et non 0,67, argumenté et non décrété.** Avec trois modèles, descendre sous
l'unanimité signifie « deux sur trois suffisent » — or les erreurs de lecture d'un tableau sont
CORRÉLÉES : deux modèles qui lisent mal la même cellule se donnent raison, et la majorité écrit
une valeur fausse que personne ne voit. L'historique d'A2 va dans ce sens (six routages, quatre
modes de défaillance typés, dont une omission attrapée par le désaccord).

**Simulation sur les données réelles, à trois seuils** (script archivé) :

| seuil | écriture directe | file | motif du routage |
|---|---|---|---|
| 1,00 | 32 | 2 | contrôle arithmétique |
| 0,67 | 32 | 2 | contrôle arithmétique |
| 0,34 | 32 | 2 | contrôle arithmétique |

**Le seuil ne change rien ici, et c'est le résultat.** Les deux lignes retenues le sont par le
contrôle DÉTERMINISTE, pas par le consensus — les trois modèles étaient unanimes ET exacts sur
2025. Abaisser le seuil ne les aurait pas libérées ; un dispositif qui n'aurait eu QUE le seuil
de consensus les aurait publiées sans broncher. C'est la démonstration, sur pièce, que la règle
d'écriture doit rester **« consensus >= seuil ET contrôles satisfaits »**, et que le second
facteur est ce qui empêche le consensus de valoir preuve — la doctrine du projet, vérifiée
plutôt qu'affirmée.

## 30.08.2026 (nuit) — `URL` n'existe pas dans le bac à sable : trois appels, dont un muet

**Déclencheur** : première exécution réelle de `extraction_composite_CP` dans n8n (le point 3 du
« reste à faire » de la journée). Échec immédiat, `ReferenceError: URL is not defined` au nœud
« Extraire l'URL du PDF ». La réserve écrite ce matin — « écrit et structurellement validé,
il n'a PAS été exécuté dans n8n » — vient d'être payée par un défaut d'exécution.

**Cause, établie sur pièce et non supposée.** Le `getNativeVariables()` du *task runner*
(`@n8n/task-runner/dist/js-task-runner/js-task-runner.js`, l. 158) énumère les globales injectées
dans le contexte des nœuds Code : `Buffer`, `setTimeout`/`setInterval`/`setImmediate` et leurs
`clear*`, `btoa`, `atob`, `TextDecoder`/`TextEncoder` (+ variantes `*Stream`), `FormData`.
**`URL` n'y est pas, `URLSearchParams` non plus** — ce que `collecte_flux` avait déjà constaté
empiriquement le 23.08 pour `URLSearchParams`, sans en tirer la règle générale. La règle est
maintenant écrite : *dans un nœud Code, aucune globale hors de cette liste, `require` limité à
`crypto` par `NODE_FUNCTION_ALLOW_BUILTIN`.*

**Trois appels concernés, dont deux qui ne levaient rien.**

| workflow | nœud | comportement observé |
|---|---|---|
| `extraction_composite_CP` | Extraire l'URL du PDF | **erreur franche**, workflow arrêté |
| `decouverte_sources_multi_ia` | Normaliser et recouper les propositions | `ReferenceError` **avalée par un `catch`** |
| `decouverte_sources_multi_ia` | Fiche de qualification pré-remplie | idem |

Les deux derniers sont le cas le plus gênant : le `try/catch` retombait sur
`String(u).toLowerCase().trim()`, donc la normalisation des URL (retrait du schéma, du `www.`,
du slash final, de la requête) **n'a jamais tourné**, y compris au run de la couche 0 du 22.08.
Deux modèles proposant la même adresse sous deux écritures comptaient pour deux sources.
Un échec silencieux qui dégrade un résultat sans le signaler est exactement ce que le § 7.2.2
s'engage à ne pas laisser passer.

**Effet mesuré sur le chiffre publié : nul, et c'est vérifié, pas supposé.** La normalisation
corrigée a été rejouée sur les 26 candidats réels du run, repris du vidage d'exécution
(`data/runs_couche0/run_couche0_2026-08-22_v2.log`, nœud « Normaliser et recouper les
propositions ») : **26 clés distinctes, aucune fusion, noyau 1/26 inchangé**, répartition
identique (1 candidat à 3 modèles, 2 à 2, 23 à 1). **Le § 11.7 tient tel quel** — ni révision
du texte, ni nouveau run. Le défaut était réel, sa portée sur ce run est nulle : les deux
affirmations doivent être écrites ensemble.

**Correctif.** Résolution et normalisation refaites à la main, sans dépendance : schémas absolu,
protocole-relatif, racine-relatif et chemin-relatif, décodage de `&amp;`, réduction des segments
`.` et `..`, retrait du port, des identifiants et du `www.`. Vérifié par comparaison à `URL`
natif — concordance sur tous les cas bien formés, et les formes sans schéma (`www.x.org/a`),
que l'ancienne version rejetait vers la chaîne brute, sont désormais normalisées. Sauvegardes
`*.json.avant_url_2026-08-30`.

**Balayage de contrôle** : les trois appels étaient les seuls usages de globale non exposée dans
les workflows vivants (les occurrences de `document` relevées dans `collecte_fh_horlogerie` et
`extraction_composite_multi_ia` sont dans des commentaires et des chaînes de prompt).

**Deux constats d'état de l'orchestrateur, à traiter par Nilo.**

1. **Doublon de workflow.** n8n porte DEUX copies de l'extraction CP : `PNd16YrFSehKUDIR`
   (16 nœuds, courante, corrigée et réimportée) et `WwensrpUT8Nz7ELB` (**15 nœuds, version
   d'AVANT le refactor des seuils du 30.08 — il lui manque « Lire les seuils de consensus »**).
   La périmée a été laissée intacte, non corrigée, à dessein : la supprimer est une décision
   d'étudiant. **Tant qu'elle existe, exécuter la mauvaise copie écrit au registre sans que le
   seuil déclaré au référentiel s'applique.** À supprimer dans l'interface.
2. **L'export sur disque n'était pas la copie vivante.** Écarts constatés, tous deux artefacts de
   normalisation de n8n et non retouches d'interface (`outputPropertyName: "data"` omis car
   valeur par défaut ; `version: 1` ajouté au nœud If). Rien n'a été perdu, mais la vérification
   a été faite AVANT réimportation et doit le rester : réimporter sans comparer écrase.
   Sauvegarde de l'état antérieur : `prototype/data/backup_n8n_2026-08-30/tous.json`.

**Reste à faire** : relancer `extraction_composite_CP` (`doc_id=8`, H2, période 2025, remis en
`a_traiter` avec son empreinte de vérification), puis rendre au point 3 du reste-à-faire de la
journée son statut réel — « le workflow produit la série » ne pourra s'écrire qu'après un run vert.

## 31.08.2026 — Le binaire n'est pas inline : `filesystem-v2` et la charge qui partait vide

**Symptôme** : deuxième échec de `extraction_composite_CP`, cette fois côté OpenAI —
`400 invalid_request_error`, `param: input[0].content[0].file_data`, « got an invalid
base64-encoded value ». Le nœud « Extraire l'URL du PDF » corrigé la veille passe désormais ;
c'est « Préparer la charge » qui rend un contenu inexploitable.

**Cause, établie par sonde et non déduite.** Un workflow jetable (téléchargement du même PDF,
nœud Code d'inspection, exécuté par `n8n execute` sur un port de courtier distinct, aucune
écriture en base, supprimé depuis) a rendu ceci :

```
binary.data.data    = "filesystem-v2"   (13 caractères)
binary.data.id      = "filesystem-v2:workflows/.../binary_data/57ac39fc-…"
getBinaryDataBuffer = 1 042 607 octets, en-tête "%PDF-"
```

L'instance stocke les binaires en mode **`filesystem-v2`** : le PDF vit sur disque et
`binary.data.data` ne contient que le nom du mode. Le commentaire du nœud — « n8n stocke déjà
le binaire en base64 » — était **faux**, et c'est lui qui a porté l'erreur. La charge partait
donc avec `data:application/pdf;base64,filesystem-v2`. Le PDF source, lui, était sain
(vérifié à la main : 1 042 607 o, `application/pdf`, `%PDF-1.7`).

**Correctif** : lecture par l'appel RPC `this.helpers.getBinaryDataBuffer(0, 'data')` — la voie
supportée sous *task runner*, listée dans `EXPOSED_RPC_METHODS` — puis `toString('base64')`.
S'y ajoute un **contrôle d'entrée qui échoue bruyamment** : taille plancher et en-tête `%PDF-`
vérifiés avant l'envoi. Un contenu muet expédié aux trois éditeurs coûte trois appels et rend
un résultat faux sans rien signaler ; c'est le mode de défaillance que ce workflow doit
justement savoir éviter. Sauvegarde `extraction_composite_CP.json.avant_binaire_2026-08-31`.

**Balayage** : `.binary` n'est lu dans aucun autre nœud Code des workflows vivants — les autres
collecteurs (A2, xlsx indexé, FH) passent leurs binaires sans transiter par du code.

**Note d'état, à traiter par Nilo.** L'inventaire des workflows a changé PENDANT la session :
la copie périmée à 15 nœuds (`WwensrpUT8Nz7ELB`) a disparu — supprimée dans l'interface, ce qui
lève le risque signalé la veille — mais une **nouvelle copie à 16 nœuds** est apparue
(`0SafOaJGAoaz5zEx`, créée vers 22 h 14), vraisemblablement par duplication dans l'interface.
Il y a donc toujours **deux entrées de même nom**. Les deux ont reçu les deux correctifs, de
sorte qu'aucune exécution ne peut plus échouer sur ces deux points, mais le doublon reste à
résoudre : deux workflows homonymes écrivant au même registre, c'est une ambiguïté d'audit.

**Deux règles de méthode que la session impose, et qui valent au-delà de ce workflow.**

1. **Ne jamais réimporter sans comparer d'abord.** L'interface et le dépôt divergent en
   permanence ; deux écarts constatés se sont révélés être des artefacts de normalisation de
   n8n (`outputPropertyName: "data"` omis car valeur par défaut, `version: 1` ajouté au nœud If)
   et non des retouches — mais cela s'est **vérifié**, pas supposé.
2. **Un workflow ouvert dans le navigateur pendant une correction en ligne de commande est un
   piège** : l'onglet garde l'ancienne version en mémoire et un « Save » la réécrirait par-dessus
   le correctif. Recharger la page avant toute action.

**Reste à faire** : relancer `extraction_composite_CP` sur `doc_id=8` (H2, 2025, en `a_traiter`
avec son empreinte). Le point 3 du reste-à-faire du 30.08 ne pourra passer à « le workflow
produit la série » qu'après un run vert de bout en bout.

## 31.08.2026 (suite) — Trois branches, trois exécutions : la file triplée

**Constat, trouvé en base et non signalé par le workflow.** Le run 167 (première exécution
réelle de `extraction_composite_CP` dans n8n) a déposé **six lignes** en `validation_queue`
là où il en fallait deux : trois paires H2/H11 identiques, à la même seconde.

**Cause** : les trois nœuds « Modèle A/B/C » entraient tous sur la MÊME entrée de « Consensus
et contrôles ». n8n exécute alors le nœud **une fois par branche entrante** — trois fois — et
chaque exécution repousse sa paire dans la file. C'est un piège de câblage, pas de code.

**Ce que le défaut n'est PAS, vérifié avant d'écrire quoi que ce soit.** Le consensus n'est pas
faussé : chaque exécution voit bien les trois modèles (`valeurs_par_modele` = google, openai,
anthropic, valeurs identiques), parce que le code lit par référence de nœud (`$('Modèle A…')`)
et non par son entrée. Le calcul est juste, il est seulement fait trois fois. Et le registre a
été **protégé par la base** : la contrainte `UNIQUE (indicator_id, run_id, period, geo)` a
absorbé les écritures redondantes — 32 lignes pour le run 167, **identiques aux 32 du run 163**
(chargement par script), zéro écart sur les valeurs. La `validation_queue` n'a pas d'unicité
équivalente : c'est elle qui a encaissé la redondance.

**Correctif** : nœud **« Rassembler les trois réponses »** (`n8n-nodes-base.merge`,
typeVersion 3, `numberInputs: 3`), inséré entre les modèles et le consensus. Motif **repris de
`decouverte_sources_multi_ia`** (« Rassembler les quatre réponses »), où il fonctionne depuis le
portage du 22.08 — on ne réinvente pas un patron que le dépôt possède déjà. Appliqué aux deux
copies (`PNd16YrFSehKUDIR`, `0SafOaJGAoaz5zEx`). Sauvegarde
`extraction_composite_CP.json.avant_merge_2026-08-31`.

**Purge** : les six lignes du run 167 (item_id 18 à 23) supprimées. La file revient aux deux
lignes du run 163 (item 16 H2 2025, item 17 H11 2025) — les deux vraies décisions, celles qui
portent l'écart arithmétique de 5 imputable au producteur. Le run 167 garde sa trace là où elle
compte : ses 32 valeurs au registre.

**Proposition non appliquée, à trancher par Nilo.** Le registre s'est défendu tout seul, la file
non. Un **index unique partiel** sur `validation_queue (indicator_id, run_id, period, geo)
WHERE decision IS NULL` donnerait à la file la même défense en profondeur, sans empêcher
l'accumulation entre runs — ce que la doctrine de l'outil vivant exige. C'est une migration :
elle n'a pas été écrite sans arbitrage, et elle relève du matériau de l'annexe 5.

**Leçon de méthode, la troisième de la série.** Trois défauts en deux jours sur ce workflow —
`URL` absent, binaire non inline, branches non rassemblées — et **aucun des trois n'était
visible à la lecture du JSON**. La validation structurelle ne remplace pas l'exécution : c'est
l'argument à faire valoir au § 7.2.2 plutôt qu'à taire.

## 31.08.2026 (suite 2) — Calibrage des seuils, deuxième vague : trois familles, pas une

**Point de départ, et il commence par une correction.** Le point 2 du § « Ce qui reste
atteignable » annonçait depuis le 10.08 une décision de calibrage « en attente ». **Elle ne
l'était pas** : la migration `2026-08-10_calibrage_seuils.sql` a été exécutée le jour même
(sortie en `annexe_5/calibrage_seuils_2026-08-10.txt`, 10.08 à 16 h 06) et H1 calibré le 11.08.
La ligne a été marquée périmée sur place. C'est le troisième document de pilotage à dériver
de l'état réel — après les décomptes textuels, et pour la même raison : **une affirmation d'état
qui n'est pas relue contre la base vieillit sans prévenir.**

**Ce qui restait vraiment ouvert** : treize indicateurs certifiés sans seuil, créés ou alimentés
APRÈS la vague du 10.08 (A11, et la famille transversale T5-T10). Volatilités recalculées le
31.08 sur `v_metriques` — et elles montrent que le pourcentage de variation n'est pas partout
le bon instrument. Trois familles, arbitrées en session avec Nilo.

| famille | indicateurs | matière | décision |
|---|---|---|---|
| calibrables | A7 · M6 · T6 · T7 · T9 | p90 57,1 · 22,4 · 14,7 · 10,1 · 4,4 | **seuils 55 · 22 · 15 · 10 · 4,5** |
| soldes d'opinion | T5 · T8 | max 19 300 % et 18 200 % ; 119 valeurs négatives sur 139 pour T8 | **pas de seuil, absence ÉNONCÉE** |
| parts à effet de base | A11 · T10 | p90 118 % et 53 % | **pas de seuil, absence ÉNONCÉE** |
| sans historique | M7 · M8 · S7 | aucun glissement calculable (pas d'homologue à 12 mois) | **pas de seuil, absence ÉNONCÉE** |

**Le raisonnement des deux familles sans seuil, parce qu'il vaut mieux qu'un tableau.** Un solde
d'opinion passe par zéro : un glissement de 18 200 % n'y décrit pas une volatilité mais le
franchissement de zéro. C'est la conséquence arithmétique du drapeau `admet_negatifs` déjà
déclaré sur ces liaisons — le projet avait identifié la cause, il en tire ici l'effet sur RI4.
Une part, elle, souffre de l'effet de base : la part électrique croît d'une base très faible,
son p90 de 118 % décrit une croissance saine et non un événement. Dans les deux cas l'instrument
juste est l'écart **en points** ; il est documenté comme perspective et **non implémenté** —
ce serait une colonne, une vue, une règle d'écran et une reprise du rapport, à treize jours du
dépôt. La décision est donc de ne pas poser de seuil ET de le dire.

**« Le dire » n'est pas une figure de style : c'est un mécanisme.** L'énoncé est porté par
`indicators.note_conception`, servi par l'API de restitution et affiché sur la page Fiabilité —
le mécanisme que T4 utilise déjà depuis le 10.08. Aucune colonne ni vue nouvelle. Une
**vérification de complétude** est incluse dans la migration : *tout indicateur certifié sans
seuil ET sans énoncé* est listé — attendu, et obtenu, **zéro ligne**. Un seuil absent mais tu
serait une surdéclaration par omission ; la requête interdit désormais qu'il en reste un.

**Migration** `migrations/2026-08-31_calibrage_seuils_suite.sql`, exécutée, sortie archivée en
`annexe_5/calibrage_seuils_suite_2026-08-31.txt` (258 lignes).

**Effet mesuré** : **3 franchissements** seulement proviennent des cinq indicateurs calibrés ce
jour, sur 2 indicateurs — la proportion qu'annonce la règle du p90 (≈ 1 observation sur 10).
Les 206 autres franchissements sont antérieurs et connus : c'est le **mur d'alertes zone par
zone** (A3 par pays, H1 par destination) déjà relevé le 27.08, dont la règle d'écran est posée
mais dont le traitement de fond reste ouvert.

**Reste ouvert sur ce sujet** : le seuil en points (perspective documentée) ; le `niveau_reference`
de T1, toujours pendant depuis le 10.08 ; T6 calibré sur 32 points seulement, à revoir quand
l'historique s'allonge.

## 31.08.2026 (suite 3) — Le commentaire exécutif se diffuse sans relecture, et le dit

**Demande de l'étudiant** : le commentaire exécutif ne doit plus dépendre d'une validation
humaine pour s'afficher.

**Constat préalable, à dire avant tout le reste : le pipeline n'était pas en panne.** L'écran
affichait le 24.08 alors que le **run 174 avait produit cinq commentaires le 31.08 à 07 h 46**
(`claude-opus-5`). Ce n'est pas la génération qui manquait, c'est la file : l'API ne servait que
`status = 'valide'`, et personne n'avait relu. **Une file qu'on ne vide pas transforme la
validation en panne d'affichage** — c'est le vrai défaut, et il était invisible depuis l'écran.

**Tension signalée avant d'agir, chiffres en main.** Sur 63 commentaires décidés à ce jour :
**25 validés, 38 rejetés — 60 % de rejet**. La première fournée du 17.08 a été rejetée en
totalité (12/12) ; la dernière série décidée, le 24.08, tient encore 15 validés pour 6 rejetés
(29 %). Les motifs consignés sont **factuels** : calcul dérivé, affirmation contredite par les
données, arrondi. Diffuser sans relecture fait du scénario C — écarté comme option
d'implémentation, traité en perspective au § 10.5 — l'implémentation réelle.

**Arbitrage retenu, et il n'est pas binaire.** Ni statu quo, ni autonomie opaque :
**diffusion d'office SOUS ÉTIQUETTE**. Le régime est exactement celui déjà appliqué aux
VALEURS — `pre_valide_consensus` en ambre contre `valide_humain` en vert. Le lecteur voit
toujours par quel chemin le texte est arrivé ; l'autonomie ne se paie pas en opacité.

**Ce qui a été fait.**

- **API** (`api_restitution`, nœud « Lire la base consolidée ») : `WHERE status IN ('valide',
  'a_valider')`, et `status` exposé au client. Le `DISTINCT ON (sector_code) ... ORDER BY
  commentary_id DESC` fait que le plus récent gagne, quel que soit son statut. Réimportée après
  comparaison à la copie vivante (aucun écart), n8n redémarré, webhook vérifié : **5 commentaires
  servis, tous du run 174, tous `a_valider`**.
- **Restitution** : helpers `relu()`, `BadgeCommentaire`, `signatureCommentaire` dans `api.jsx` ;
  six écrans repris (`Accueil`, `CeMatin`, `CetteSemaine`, `Marche`, `Secteur`, plus la note de
  pied de l'accueil). **Les affirmations devenues fausses ont été corrigées, pas seulement
  complétées** : « seul le validé s'affiche » (accueil), « validée par vous — seul le validé
  s'affiche » (CeMatin), « autres lectures validées », « aucun validé pour ce secteur ».
  Une étiquette qui ment est pire qu'une étiquette absente.
- **Build Vite refait** et servi par nginx (vérifié : l'empreinte du bundle servi correspond au
  build). **Rendu vérifié sur captures réelles**, pas affirmé : accueil (les quatre cartes
  portent « rédigé par un modèle, non relu », run 174 en tête) et page horlogerie (« rédigé le
  31.08.2026 — aucune relecture humaine » à côté de « généré par claude-opus-5 · règles
  RI0-RI10 »).

**Sauvegardes** : `api_restitution.json.avant_commentaire_autonome_2026-08-31` et
`*.jsx.avant_commentaire_autonome_2026-08-31` pour les six écrans.

**À ratifier en supervision (§ 7.2.2).** C'est une **révision d'une décision acquise** : le
commentaire exécutif quitte le human-in-the-loop strict. Décision d'étudiant, tracée, motivée,
et bornée — elle ne touche NI les valeurs du registre, NI la file composite, NI la cascade de
fiabilisation. Le rang 3 (validation humaine) reste entier là où il porte sur des chiffres ;
il devient facultatif là où il porte sur de la prose, et l'écran le déclare.

## 31.08.2026 (suite 4) — Les seuils apprennent à parler : signe, phrase, et les zones à leur place

**Demande de l'étudiant** : « les seuils, c'est illisible et ça ne porte pas de valeur —
127 signalements en horlogerie, aucun gain d'information. »

**Le diagnostic lui donne raison, et il est mesuré.** Un seuil calibré au p90 fait franchir
~1 observation sur 10 PAR CONSTRUCTION ; appliqué aux ~190 destinations de H1, il fabrique
mécaniquement 123 « signalements » — dont Namibie −99 % sur **32 USD** d'exportations, Féroé
−100 % sur 56 USD. Poids réel : 2 zones seulement pèsent ≥ 1 % du flux total de la série.
« 127 signalements » était un artefact arithmétique, pas une information.

**Trois réformes, toutes côté écran** — l'API servait déjà tout (`sens_favorable` et le
rattachement `questions` sont au référentiel depuis leurs migrations) :

1. **Le signe.** Chaque franchissement est signé par `sens_favorable` : point et étiquette
   verts (favorable), rouges (défavorable), gris (« à interpréter », sens déclaré neutre).
   Une hausse d'exportations cesse d'être une anomalie rouge.
2. **La phrase.** « (seuil 8 %) » devient « amplitude vue moins d'une fois sur dix sur cette
   série » — le sens réel du p90 en français — et chaque ligne porte sa question de veille
   (« QV2 · demande et débouchés »). Le bloc s'intitule « Mouvements inhabituels ».
3. **Les zones ne sont plus des alertes.** Une série multi-zones en franchissement devient
   UNE ligne pondérée : « H1 — géographie en mouvement : 2 zones pesant ≥ 1 % du flux, la plus
   lourde France (+101,3 %, 289,2 mio USD) », les 121 marginales écartées ET comptées (« artefact
   de petits nombres, pas un signal »), renvoi vers la dynamique géographique (QV3) où le
   déplacement se lit en points de part. Détail par poids décroissant sous repli, pour l'audit.

Le bandeau de tête suit : « 5 séries au comportement inhabituel, aucune en mouvement
défavorable » remplace « (127 signalements au total) ». **Cohérence de base de comptage** : le
sens d'une série se juge sur ses zones PESANTES (même filtre que le bloc) — corrigé après
capture, la première version laissait une zone marginale à −99 % peindre H1 en défavorable.

**Où c'est écrit** : helpers partagés dans `api.jsx` (`sensMouvement`, `SENS_ETQ`,
`QV_LIBELLES`, `qvDe`, `syntheseZones`) — règle unique, un seul endroit, comme le filtre de
poids du 23.08 ; écrans `Secteur.jsx` (bloc réécrit + bandeau), `Accueil.jsx` (« À examiner »
signé), `CetteSemaine.jsx` (« Mouvements inhabituels », mention du poids conservée).
Sauvegardes `*.avant_lecture_seuils_2026-08-31`. Build refait, **vérifié sur captures**
(bandeau horlogerie, bloc alertes, « À examiner » de l'accueil).

**Découverte au passage, décision de référentiel à trancher par Nilo** : `sens_favorable = 0`
est déclaré pour A3, A7 et S3 — l'écran affiche donc « à interpréter » sur A7 à −74,7 % de
dépôts de brevets. Si une chute de brevets est défavorable, c'est un UPDATE du référentiel à
arbitrer (et à tracer), pas un correctif d'écran.

**Note pour les figures** : les captures officielles d'annexe 6 (v9) sont doublement périmées
(commentaire non relu du 31.08, nouveau bloc de mouvements). À régénérer par
`node verification/captures.mjs` une fois l'état stabilisé (run CP vert, H12 collecté).

## 31.08.2026 (suite 5) — A1 instrumenté : le composite dont la vérité terrain est gratuite

**Point de départ** : l'étudiant signale l'annuaire CCFA (« Analyses et statistiques »,
ccfa.fr) et demande comment extraire la partie statistique d'un PDF de plus de 100 pages
sans l'ingérer en entier.

**Instruction sur pièces, dans l'ordre.**
1. **CCFA, édition 2025** : 102 pages, InDesign. Le tableau « La production mondiale de
   véhicules » par pays (p. 8, en milliers, 2023/2024, base 100 = 2019) est EXACTEMENT le
   périmètre d'A1 — certifié, zéro observation, zéro liaison. La couche texte est PROPRE
   (`pdftotext -layout` : colonnes alignées) — cas FH, pas cas CP.
2. **Les tableaux CCFA impriment « Source : OICA »** — or l'OICA est la source déclarée d'A1
   au référentiel depuis toujours. Le CCFA est une republication.
3. **OICA direct sondé** : refonte WordPress 2026, sélecteur 1999-2026, Mais la page ne sert
   que des classements top-10 (9-10 blocs de graphiques, données incorporées en JSON lisible,
   attributs data-data). La France (1 358 k) n'est plus au top-10 : disqualifiant comme source
   unique d'un indicateur dont l'objet est la géographie de l'assemblage.
4. **Test décisif côté n8n** (pdf-parse 1.1.1, le moteur du nœud « Lire le PDF ») : les lignes
   du tableau sortent INTACTES et dans l'ordre (« Allemagne*4 1094 069-1,0 82 »), colonnes
   concaténées sans séparateur — ambigu pour du code, lisible par un modèle.

**Décision de l'étudiant, et la tension déclarée avec elle.** Extraction PAR IA, périmètre
top-10 accepté (« Le top 10 c'est très bien »). Cela contredit « les chiffres par le code, les
mots par l'IA » ET le critère du § 8.6.4 : la source est lisible par le code, testé des deux
côtés — A1 passe par l'IA **par choix d'expérimentation, non par nécessité**. La tension a été
signalée avant d'agir, la décision maintenue : elle est tracée ici, dans la migration, et dans
`note_conception`. Le rapport ne devra JAMAIS laisser croire que la chaîne ne savait pas lire ce
document. À ratifier en supervision (même famille que la requalification S1, pendante).

**La contrepartie qui rend ce choix expérimentalement précieux** : l'OICA publie sa vérité en
JSON lisible par machine. A1 devient le seul composite de la grille où CHAQUE valeur extraite
par les modèles est confrontable à un contrôle déterministe de rang 1 à coût nul — la cascade
entière (terrain → consensus → humain) devient MESURABLE sur ce cas.

**Réponse à la question posée (« ne pas ingérer tout le PDF ») — nœud « Découper la section
statistique »** : le texte est extrait par le nœud PDF natif (gratuit), puis DÉCOUPÉ PAR
SENTINELLES DE CONTENU (« PRODUCTION MONDIALE DE V », noms de zones et de pays), jamais par
numéro de page — même principe que la résolution de lien FH/CP : on déclare ce qu'on cherche,
pas où il se trouve. Seule la tranche (~10-14 k caractères, ~2 % du document) part vers les
trois modèles. Nécessité et pas seulement économie : Anthropic et OpenAI plafonnent vers
100 pages, le document en fait 102.

**Livré.**
- `n8n_workflows/extraction_composite_A1_ccfa.json` (20 nœuds), importé dans n8n
  (`extraction-composite-a1`). Structure CP reprise : portillon composite_queue, seuils lus au
  référentiel, 3 modèles, **Merge dès la conception** (leçon de la veille), consensus par valeur
  modale PAR PAYS ET PAR ANNÉE, écriture registre / file selon « consensus ≥ seuil ET contrôles ».
  Nouveautés : nœud « Lire la vérité OICA » (la page top-10), contrôle par pays
  (concorde / discorde / non_verifiable) — une DISCORDE route en file quelle que soit
  l'unanimité ; un pays hors top-10 est « non vérifiable », le consensus seul décide (comme la
  CP hors contrôle arithmétique) et la trace le dit. Valeurs écrites en UNITÉS (milliers × 1000,
  l'unité du référentiel).
- `migrations/2026-08-31_a1_requalification_composite.sql`, exécutée : A1 hard → composite,
  seuil_consensus 1.0 (unanimité, comme A2 et H2), note_conception complète, document CCFA 2024
  semé en composite_queue. Sortie en `annexe_5/a1_requalification_2026-08-31.txt`.
- **Décomptes après requalification (par requête)** : 41 certifiés = **38 hard / 3 composites**.
  Toute mention de 39/2 est périmée.

**Ce qui reste, et à qui.**
1. **Nilo** : vérifier nominativement `doc_id 9` (`a_verifier` → `a_traiter` + `verifie_par`,
   `verifie_le`) — le workflow ne traite que le vérifié.
2. **Nilo** : exécuter le workflow dans n8n. Il n'a PAS tourné : « écrit et importé, jamais
   exécuté » est la seule formule permise tant qu'un run vert n'existe pas — la leçon des trois
   défauts invisibles du 30-31.08 vaut d'autant plus ici.
3. Après le run : arbitrer les éventuelles lignes en file, et la cascade de rédaction
   (§ 8.6.4 : quatrième position dans le tableau FH/ACEA/CP — « lisible par code mais traité
   par IA, par choix » ; § 8.8 décomptes ; § 7.2.2 ratification).

### 31.08.2026 (complément A1) — La tendance exige des éditions, pas une

Objection de l'étudiant, fondée : une édition = deux points, pas de tendance. Réponse
instruite sur pièces : **le CCFA archive toutes ses éditions depuis 2014**
(`ccfa.fr/analyse-statistiques/`, l'ancienne adresse). Vérifié : éditions 2023 (2021/2022,
100 p.) et 2024 (2022/2023) téléchargées, sentinelles de découpe présentes dans les deux.
Trois éditions ⇒ **série 2021→2024, quatre points par pays** — l'historique de 3 ans du cadre.
Chaque année figure dans DEUX éditions : le recouvrement rend les révisions du producteur
visibles — même motif que les sept communiqués ACEA de la série A2.

Fait : (1) le nœud « Extraire le lien du PDF » honore désormais une URL directe de PDF portée
par `composite_queue.source_doc` (les archives), la résolution par page d'accueil ne valant que
pour l'édition courante ; (2) documents 10 (2022, éd. 2023) et 11 (2023, éd. 2024) semés en
`a_verifier` ; (3) **défaut corrigé avant premier run** : le workflow ne clôturait jamais son
document (`ORDER BY period DESC` aurait repris l'édition 2024 à chaque exécution) — nœud
« Clore le document traité » ajouté (21 nœuds). La CP a la même lacune, sans conséquence tant
qu'elle n'a qu'un document — à reporter si H2/H11 passent en pluri-éditions.

Reste pour Nilo : vérifier nominativement les TROIS documents (9, 10, 11) — un coup d'œil à
chaque PDF —, puis TROIS exécutions du workflow (une par document, il prend le plus récent
non traité à chaque fois).

### 31.08.2026 (complément A1, 2) — L'OICA a bien des fichiers ; ils ne portent pas la série annuelle

**Correction d'un constat de la session, sur signalement de l'étudiant.** « L'OICA ne propose
plus aucun fichier » était FAUX : les boutons PDF/XLSX existent, dans une fenêtre surgissante
chargée en AJAX, invisible à une lecture HTTP brute. Vu et vérifié au navigateur headless
(l'outillage de la revue visuelle). Leçon de méthode : sur un site à rendu JavaScript, une
absence constatée au HTML brut n'est pas une absence — la vérification se fait page RENDUE.

**Ce que les fichiers contiennent, sur pièces** (`Total-2026.xlsx`, 58 Ko, onglet TOTAL) :
tous les pays avec colonne Sources (France : CCFA), MAIS en **cumuls T1** comparés aux T1 de
2019/2021→2025 — pas les années pleines. Et quel que soit le millésime cliqué (2024, 2022…),
le popup sert LE MÊME fichier vivant du trimestre. Trois limites pour A1 (fréquence annuelle) :
1. la série annuelle par pays n'y est pas ;
2. l'URL change à chaque mise à jour (uploads/AAAA/MM/) et ne se résout qu'en exécutant le
   JavaScript du popup (AJAX + jeton) — collecte automatisée fragile ;
3. **mur tarifaire** : le téléchargement passe par l'acceptation des « Commercial Use Pricing
   Terms » (`Commercial-Use-of-OICA-World-Sales-and-Production-Statistics.pdf`, févr. 2025) —
   usage interne 7 500 €/an, publication 22 000 €/an, redistribution 35 000 €/an. L'usage
   académique du TB est défendable (fichier public, travail non commercial) ; mais pour la
   contrainte fondatrice « une PME sans budget doit pouvoir reproduire », c'est un mur —
   la voie sans coût pour une PME est la REPUBLICATION LIBRE du CCFA, qui a les droits.

**Conclusion d'instruction : les deux sources sont complémentaires, pas concurrentes.**
- Série ANNUELLE complète par pays (l'objet d'A1) → CCFA, gratuit, éditions archivées : le
  pipeline construit aujourd'hui reste le bon porteur.
- Fraîcheur INFRA-annuelle (cumuls trimestriels, source primaire) → xlsx OICA : documenté
  comme complément possible (perspective), non instrumenté — URL instable, mur tarifaire,
  et hors de l'objet annuel d'A1.
- Le contrôle de vérité OICA (top-10 JSON de la page) reste dans le workflow tel quel.

Matériau rapport : le mur tarifaire OICA vs la republication libre CCFA est un argument
DIRECT pour le critère de coût (E5 étendu aux données) — à placer au § 8.6.4 ou en limites.

## 31.08.2026 (nuit) — A1 : la série est en base, par trois runs verts et deux défauts mesurés

**L'étudiant a délégué l'exécution** (vérification nominative des trois documents par
délégation, tracée `N. Castillo (délégation du 31.08.2026)` — le contrôle matériel des trois
tableaux avait été fait sur pièces en session). Exécutions par la CLI n8n, port de courtier
alternatif — la méthode de la sonde du 31.08 au matin.

**Résultat : la série A1 est constituée.** Runs verts 185 et 186 (0 nœud en erreur, 21/21),
plus les runs 181-184 d'apprentissage. En base : **2021 (17 pays) · 2022 (18) · 2023 (20) ·
2024 (20)**, consensus **unanime sur 150 lignes extraites** (aucun désaccord inter-modèles sur
tout le chantier), zéro ligne en file. Vérifié sur échantillon contre le tableau lu à la main :
FRA 1 505/1 358, CHN 30 161/31 282 — exact.

**Trois défauts trouvés par l'exécution, tous invisibles à la lecture (la série continue) :**
1. **Découpe v1 fausse** (run 181-bis) : sentinelles sur noms seuls → tranche de prose, liste
   vide unanime des trois modèles — un refus HONNÊTE qui a révélé le défaut. v2 (grappe la plus
   dense) atterrissait dans les annexes de tonnage. **v3 retenue : appariement titre
   « PRODUCTION MONDIALE » → ligne agrégat EUROPE chiffrée la plus proche** (< 6 000 car.),
   vérifiée sur les trois éditions (~5 100 car., 2,5 % du document envoyé aux modèles).
2. **Contrôle OICA v1 trop sévère** (run 181) : « discorde » quand l'OICA n'avait pas publié
   l'année — 23 valeurs unanimes et justes routées en file pour rien. Une valeur INTROUVABLE
   n'est pas une valeur CONTREDITE. v2 : contrôle par année (chaque bloc de la page est titré).
3. **Clôture fragile** (runs 182-184) : `$('File de validation humaine').all()` plante quand
   AUCUNE valeur ne va en file — le cas du succès total ! Corrigé par `isExecuted`.
   **Le pipeline CP porte le même bogue latent** (jamais déclenché : ses runs ont toujours eu
   les deux branches actives) — à corriger à la prochaine retouche de la CP.

**Limite mesurée du contrôle OICA, assumée** : le site OICA filtre les années EN JAVASCRIPT
CLIENT ; le serveur rend un lot arbitraire de graphiques (demander 2023 peut servir 1999-2026
sans 2023). Le contrôle est donc OPPORTUNISTE : 9 concordances au run 182 (année 2024 servie),
0 aux runs 185-186 (années absentes du lot) — `non_verifiable`, jamais un faux verdict.

**Le vrai contrôle de rang 1 d'A1 est ailleurs, et il est déterministe : le RECOUVREMENT
INTER-ÉDITIONS.** Chaque année est lue par deux éditions indépendantes du CCFA. Vue
`v_a1_recouvrement_editions` (migration `2026-08-31_a1_recouvrement_editions.sql`, sortie en
annexe 5) : **26 concordances chiffre à chiffre, 9 révisions du producteur rendues visibles**
(USA 2023 : 10 612 → 10 639 milliers entre l'édition 2024 et la 2025 ; ITA 2023 : 880 → 873 ;
BEL 2022 : 277 → 285). C'est « l'écart entre runs fait la tendance » appliqué aux révisions —
et une pièce de premier ordre pour le § 10.4.

**Points d'attention restants** : (1) A1 est hors vitrine (`en_vitrine=false`,
`geo_reference` vide) — décision d'écran à prendre par Nilo ; (2) les réponses brutes des
modèles ne vivent que dans les exécutions n8n, pas dans `/data` (E6 : la CP a la même
pratique) — à trancher au moment de figer le run de référence ; (3) runs 182-184 = triple
lecture du même document (bogue de clôture d'alors), assumés en base, dédupliqués par la vue.

## 31.08.2026 (nuit, fin) — A1 en vitrine : la carte, la ligne World, et QV3 servi

**Validation de l'étudiant** (« je valide, tu peux continuer »). Trois gestes :

1. **La ligne World, extraite et non calculée.** La consigne excluait tous les agrégats, TOTAL
   compris — la carte n'aurait pas eu de valeur de tête (A3 et A11, les autres mondiaux de la
   grille, référencent World). La consigne admet désormais LA SEULE ligne TOTAL (`iso3: WLD`,
   portée en zone World). Documents 9-11 remis en file (empreintes conservées), **trois
   nouveaux runs verts (187-189)** : World 2021-2024 = 80,2 / 85,0 / 93,5 / 92,5 M — le 92,5 M
   de 2024 concorde avec la prose de l'annuaire, et le recouvrement ajoute DEUX révisions
   mondiales visibles (2022 : 85 029→85 030 milliers ; 2023 : 93 472→93 547).
2. **Migration `2026-08-31_a1_vitrine.sql`** (exécutée, annexe 5) : `en_vitrine`,
   `geo_reference='World'`, note de conception (dont : seuil 5 % semé NON CALIBRÉ — quatre
   points annuels ne portent pas de p90, même statut que H1). **Gabarit QV3 automobile
   réécrit** : A1 est le porteur littéral de la géographie de l'assemblage, A3 y reste pour le
   segment électrique — même geste que H2/M4 le 28.08 (le manque comblé, le gabarit suit).
3. **Vérifié sur pixels** (capture de la page automobile) : carte A1 complète — 92 522 000 ·
   World · 2024 · −1,1 %, badge ambre pré-validé (consensus), courbe mondiale, détail par
   pays, et le panneau QV3 branché d'office : concentration 54 %, Chine +1,6 pt, Japon
   −0,7 pt, treemap des parts. L'API sert 323 observations A1.

**Décomptes après la journée (par requête)** : 41 certifiés = 38 hard / 3 composites ;
vitrine : aérospatial 5 · automobile 7 · horlogerie 6 · médical 5 · transversal 10 = **33**.
Toute mention antérieure est périmée.

**Registre des runs A1** : 181 (partiel, apprentissage), 182-184 (triples, bogue de clôture),
185-186 (verts, série sans World), 187-189 (verts, série complète). L'historique se lit tel
quel : c'est le déroulé réel de la mise au point, il fait partie de la démonstration.

## 31.08.2026 (clôture) — Le reste-à-faire exécuté : CP durcie, doublon marqué, captures figées, historique poussé

1. **La CP reçoit les leçons d'A1** (18 nœuds) : garde `isExecuted` sur la clôture (le bogue
   qui plantait au succès total) et nœud « Clore le document traité » (la lacune qui
   condamnait le pluri-éditions). Réimportée. `doc_id 8` (H2, 2025) clos en `traite` — il
   avait été traité par les runs 163/167. **Les items 16/17 de la validation_queue restent à
   l'arbitrage de Nilo — intouchés, c'est un acte humain.**
2. **Doublon CP marqué sans ambiguïté** : la copie excédentaire renommée
   « [DOUBLON — À SUPPRIMER] … » (la CLI n8n ne supprime pas ; un clic dans l'interface,
   désormais sans risque de se tromper de copie). La copie de travail reste
   `PNd16YrFSehKUDIR`.
3. **Captures d'annexe 6 figées** : 11 écrans pleine page dans
   `annexes/6_captures/2026-08-31/`, jeux antérieurs (v9…) préservés.
4. **Historique versionné et poussé** : huit commits par unités de sens (outillage de revue
   visuelle · corrections QV du 27.08 · retour H2/M4 · bascule CP + seuil déclaré + OFS ·
   quatre défauts d'exécution CP · calibrage seconde vague · réformes de restitution ·
   A1 instrumenté), poussés sur le distant privé (`1662067..25510b3`). Aucun fichier sensible
   (contrôle avant poussée : ni .env, ni data/, ni archive n8n).

**Il ne reste à Nilo que les actes humains** : arbitrer les items 16/17 (H2/H11 2025, l'écart
producteur de 5), supprimer le doublon d'un clic, ratifier le lot du § 7.2.2 en supervision —
et la copie Drive quotidienne du dossier.

## 31.08.2026 (arbitrages) — La file soldée à zéro : l'érosion validée, H10 activé

**Arbitrages rendus par Nilo en session, sur pièces présentées.**

1. **Items 16/17 ACCEPTÉS** (H2 = 64 807 emplois, H11 = 685 entreprises, 2025). L'analyse qui
   a emporté la décision : le total imprimé est COHÉRENT avec la somme réelle des composantes
   (1 985 + 17 590 + 45 152 = 64 727 ; + 80 à domicile = 64 807 ✓) — la coquille du producteur
   ne loge que dans la cellule intermédiaire « sous-total » (64 732, écart de 5), que personne
   ne retient. Écrits au registre en `valide_humain`. **L'érosion 2025 (−1,3 %) est désormais
   citable au présent** — la phrase du § C4 qui attendait « sous réserve de validation » peut
   tomber au fait établi. Le gabarit QV1 la sert déjà, vérifié sur capture : « 64 807 emplois
   et 685 entreprises […] (−1,3 % et +0,4 % sur un an) ».
2. **Items 24/25 REJETÉS comme doublons techniques** (run 168, troisième exécution CP du 30.08
   au soir, antérieure au correctif de clôture) — le geste des trois lignes A2 du 30.08 :
   la décision de fond vit sur les items 16/17, aucune valeur redondante n'entre.
3. **Item 26 ACCEPTÉ : H10 REÇOIT SON PREMIER POINT.** Le corpus horloger d'août a franchi le
   plancher (31 items triés ≥ 20), part signalée **25,8 %** (8 pertinents/31, triage
   gemini-3.7-flash, routage humain systématique — modèle unique, § 9.5.1). La famille
   d'intensité est complète sur août : S9 16,9 · A9 17,8 · A10 16,8 · **H10 25,8** — la valeur
   horlogère la plus haute, cohérente avec un mois de rentrée (Geneva Watch Days). Vérifié sur
   capture : la carte QV4 est passée de « en attente de corpus » à « couverte, à confirmer »,
   badge vert, réserves affichées (1 point sur 12, seuil non configuré RI4).

**La validation_queue est à ZÉRO** — première fois depuis sa création. Toute décision passée
est tracée (25 accepte/corrige · 41 rejete + les 3 rejets de doublons du jour... décompte par
requête). Matériau § 11.14 : le franchissement du plancher H10 est exactement l'événement que
le dispositif promettait de détecter — prévu « début septembre », survenu le 31.08 au matin.

## 31.08.2026 (soir) — Deux étages nouveaux : les événements typés et la lecture transversale

**Décision de périmètre de l'étudiant, réaffirmée après signalement du coût calendaire**
(l'expert-externe recommandait le gel ; proposition d'expériences bornées déclinée : « je veux
que tu intègres les 2 dans le prototype »). Décision tracée, à ratifier — § 7.2.2.

**Étage 1 — Événements typés** (`flux_evenements`, workflow `extraction_evenements_flux`).
Constat fondateur : l'intensité de signalement COMPTE des items ; un décideur veut savoir CE
QUI S'EST PASSÉ. Chaque item pertinent au triage reçoit une lecture par modèle UNIQUE (le
régime du triage, § 9.5.1) : type fermé (investissement, fermeture_reduction, rachat_fusion,
reglementation, lancement_produit, resultat_financier, partenariat, autre), acteur, zone, sens
pour un sous-traitant, résumé d'une phrase. Contrôles déterministes en sortie (item_id
inventés jetés et comptés, vocabulaire forcé). **Run 193 vert : 603 événements sur le corpus
pertinent existant.** Première lecture qui compte : le médical est dominé par la
RÉGLEMENTATION (116) et l'INVESTISSEMENT (89 — les marchés publics d'équipement) ; « 26 items
triés » ne disait rien de tel. Diffusion sous étiquette « lu par un modèle, non relu »
(le régime du commentaire du 31.08) ; statut validable, contrainte d'empreinte.

**Étage 2 — Lecture transversale** (`lectures_transversales`, workflow `lecture_transversale`).
Le dispositif collectait 42 indicateurs sans RIEN relier. Génération CONTRAINTE — la leçon des
38 rejets : le modèle ne reçoit que des FAITS CALCULÉS par le code (F1..Fn, indicateurs en
vitrine + décomptes d'événements du mois), n'écrit AUCUN chiffre, cite ses faits par code ;
les faits cités sont FIGÉS en base (audit possible quand le registre avance) ; tout chiffre
étranger dans un énoncé est un incident. **Run 194 vert : 7 hypothèses, ZÉRO incident — la
contrainte a tenu au premier run.** Qualité réelle (« la chaîne automobile paraît se
scinder » ; « rebond horloger absorbé par des gains de productivité, ce qui limiterait la
répercussion en carnets pour les sous-traitants ») avec, pour chacune, « se vérifiera par — »
(la donnée future qui l'infirmerait). Statut a_valider ; l'arbitrage des 7 est À NILO.

**Restitution** : API enrichie (evenements_types, evenements_recents, lectures_transversales),
section « Ce qui s'est passé » sur les pages de marché, « Lectures transversales » sur
l'accueil — hypothèses badgées (violet « hypothèse », confiance, « non arbitrée » en ambre),
faits cités dépliables avec leurs valeurs. Vérifié dans le DOM rendu et sur captures ;
jeu officiel d'annexe 6 régénéré.

**Deux défauts d'exécution trouvés (la série continue)** : (1) appariement lot↔réponse par
index dans les contrôles — 757 lectures jetées à tort au premier run ; remplacé par une
admission globale par item_id ; (2) **la section événements posée d'abord dans `Marche.jsx`…
qui n'est plus routée depuis la v9** — tout `/#/secteur/…` sert `Secteur.jsx` ; `Marche.jsx`,
`CeMatin.jsx`, `CetteSemaine.jsx` sont des pages HÉRITÉES non montées (leurs retouches du
31.08 au matin étaient donc à blanc — sans dommage, les pages vivantes avaient les leurs).
À élaguer un jour ; consigné pour éviter la rechute.

**Reste à Nilo** : arbitrer les 7 hypothèses (écran ou table `lectures_transversales`),
relire un échantillon d'événements (statut `valide` à poser avec empreinte), ratifier la
décision de périmètre avec le lot § 7.2.2.

## 01.09.2026 — Les hypothèses restent non arbitrées : le siège de l'expert est vacant, et c'est dit

**Décision de l'étudiant, après discussion critique.** Les 7 lectures transversales du run 194
restent en `a_valider`, et les événements en `non_relu` — ce n'est pas un retard de traitement,
c'est un ÉTAT ASSUMÉ, et voici pourquoi.

La discussion a stratifié la validation humaine du dispositif en deux natures :
1. **La vérification factuelle** — comparer une valeur au document, contrôler une somme, une
   fidélité de lecture. L'étudiant y est pleinement compétent ; c'est ~90 % de ce que les files
   ont demandé, et toutes les validations passées (érosion H2 2025, H10, série A2) sont de
   cette nature. Les 60 % de rejet du commentaire ont été attrapés par elle.
2. **Le jugement analytique** — la plausibilité industrielle d'une hypothèse de liaison.
   L'étudiant N'EST PAS cet expert (ni analyste, ni veilleur, ni décideur — son mot), et
   valider en le sachant serait la surdéclaration que le travail s'interdit. Ce rôle revient
   au décideur de la PME ; il est resté VACANT par construction du cas d'illustration
   (CODEC : illustration, jamais mandat).

Conséquence : les hypothèses vivent badgées « non arbitrée — n'engage personne », et cette
vacance est un RÉSULTAT à écrire au § 12 (limites), pas un défaut à masquer. Formulation
retenue : « la validation humaine a été exercée par l'étudiant : pleinement compétente pour la
vérification factuelle, elle ne l'était pas pour le jugement analytique — ce rôle, réservé au
décideur de la PME, est resté vacant ; la couche des lectures transversales est démontrée dans
sa mécanique, non dans son arbitrage. »

Au passage, deux corrections de trajectoire actées dans la même discussion : (1) la proposition
« pas besoin de validation humaine » (31.08 au soir) est retirée — fausse pour la vérification
factuelle, où la compétence existe et où les rejets ont été attrapés ; la validation graduée
par le risque reste un matériau de PERSPECTIVE (§ 13), pas d'implémentation ; (2) le régime de
travail passe au GEL : plus aucun pivot de doctrine ni de périmètre avant le dépôt — le chemin
critique est le rapport.

## 01.09.2026 — Audit de véracité des écrans : quatre fautes trouvées, quatre corrigées

Balayage complet du TEXTE RENDU des onze écrans (vidage DOM par navigateur headless, détails
dépliés), confronté à la base. La règle auditée est celle du projet : un texte d'écran qui
affirme ce que la base ne prouve pas est une faute.

**Fautes trouvées et corrigées (commit du 01.09) :**
1. **Anticiper, chiffres en dur** : « constitution de stocks à 34,1 %… effondrement à 10,3 % »
   étaient écrits dans le code (26.08) et avaient dérivé (base au 01.09 : 33,4-33,7 / 10,1
   selon dénominateur). Le troisième chiffre de la même phrase était, lui, calculé — preuve
   que la règle était connue et applicable. La phrase dit désormais la forme, la courbe les
   valeurs.
2. **Référentiel, « dont officielles »** : la colonne compte les hard — dont H7/H8/H9
   (Fédération horlogère, association) : le mot même que la décision du 27.08 interdit,
   affiché en tête de tableau depuis des semaines. Renommé « dont hard (par code) »,
   la distinction réelle du § 8.6.4.
3. **Pastilles latérales** : elles comptaient des lignes (17 pour l'automobile) quand le
   bandeau du même écran compte des séries (3) — deux chiffres contradictoires à trois
   centimètres. La réforme du 31.08 est finie jusqu'au bout : les deux comptent des séries.
4. **Onze runs « en_cours » fantômes** (tentatives interrompues des 30-31.08, dont celles de
   la mise au point A1) : clos en `echec` avec note d'hygiène — l'écran Exécutions les
   montrait vivants.

**Vérifié sans faute** : les références de paragraphes citées à l'écran (§ 5.5, 5.6, 8.4.5,
8.6, 8.10) existent toutes dans les sources du rapport ; les réserves de Fiabilité sont
CALCULÉES (`reservesDuDispositif`), donc insensibles à la dérive ; la provenance d'A1 expose
sa pièce d'audit (le PDF CCFA) dans le dépliant ; « RI4 inapplicable » est un constat calculé
par `v_metriques`, vrai par construction ; le « 19 des 26 » de l'Anticiper est calculé (26 =
indicateurs à écart calculable, pas un décompte de grille).

**Leçon transversale pour le § 12** : les quatre fautes ont la même origine — du TEXTE RÉDIGÉ
là où la doctrine exige du calculé. Les deux phrases fautives dataient d'écrans écrits vite
(26.08) ; tout ce qui était calculé a traversé trois semaines de churn sans mentir. C'est la
doctrine « la lecture est calculée, jamais rédigée » validée par l'épreuve inverse.

## 01.09.2026 (suite) — Audit des calculs : l'inventaire complet, deux bogues réels, corrigés

**Demande de l'étudiant** : énumérer TOUS les calculs du prototype, leur méthodologie, vérifier
qu'ils sont justes et employés au bon endroit. Fait — 44 vues SQL et les calculs d'écran,
vérifiés par RECALCUL INDÉPENDANT sur échantillon.

**L'inventaire des calculs et leur verdict :**

| calcul | méthode | verdict |
|---|---|---|
| glissement annuel (`v_metriques`) | (v − v_n-1) / dénominateur × 100, homologue par `periode_annee_precedente` | **BOGUE corrigé** (signe, cf. infra) |
| variation de période | idem sur période précédente | idem |
| écart à la moyenne | (v − MM12) / dénominateur | idem |
| moyenne mobile annuelle | 12 derniers points (fenêtre par fréquence), complétude affichée | sain |
| homologue (`periode_annee_precedente`) | AAAA→AAAA-1, AAAA-MM, AAAA-Tn ; sinon NULL (« pas de rapprochement inventé ») | sain |
| franchissement (RI4) | \|glissement\| ≥ seuil déclaré ; NULL ⇒ inapplicable dit | sain |
| score de santé (`v_sante_secteur_brut`) | moyenne des z-scores (v−m)/σ × sens, ≥ 8 points, σ > 0 | sain (σ > 0 : insensible au piège des soldes) |
| tension de chaîne | écart-à-moyenne(amont) − écart-à-moyenne(production), paires déclarées | sain (paires toutes positives ; protégé par le correctif) |
| indice de diffusion (Anticiper) | # (écart × sens > 0) sur indicateurs à écart calculable | **faussé par le bogue de signe — juste depuis le correctif** |
| exposition US (`v_exposition_horlogere`) | part USA / somme des pays (W00 et codes S/X/F exclus), DISTINCT ON dernier run | sain — le 27,1 % est juste par sa méthode déclarée |
| indicateur synthétique | CHE/panier, calcul refusé si un déclarant manque | sain (61,74 % vérifié) |
| intensité de signalement | pertinents/triés, plancher 20 | sain (25,8 = 8/31 vérifié) |
| poids d'alerte (écran) | \|v\| / Σ\|v\| des zones non agrégées, même période | sain |
| synthèse de zones (écran) | tri par poids, ≥ 1 % retenues | **BOGUE corrigé** (agrégats, cf. infra) |
| recouvrement A1, événements/mois, décomptes | vus les 31.08 | sains |

**Bogue n° 1 — le signe des ratios sur séries négatives.** Les trois ratios divisaient par la
valeur BRUTE : dénominateur négatif ⇒ signe inversé. Constaté sur T8 : valeur −19,7, moyenne
−22,09 — le carnet S'AMÉLIORE au-dessus de sa moyenne, affiché « −10,83 % », classé DÉFAVORABLE
par l'indice de diffusion (« 19 des 26 » au lieu de 20 ; « les cinq défavorables » dont T8 à
tort ; narration « le carnet… la profession, moins » partiellement fondée sur un signe inversé).
Le projet connaissait le piège (notes T8/T10, admet_negatifs, seuils NULL) mais ne l'avait
neutralisé que pour la RÈGLE D'ALERTE — pas pour le signe que l'écran consomme. Correctif :
dénominateurs en VALEUR ABSOLUE (migration `2026-09-01_denominateurs_valeur_absolue.sql`,
annexe 5 ; `db/01_socle.sql` corrigé aussi) — direction exacte partout, séries positives
inchangées (non-régression vérifiée), notes T8/T10 mises à jour (le « −34,5 % » cité est
devenu faux). Vérifié à l'écran : « 20 des 26 », « quatre défavorables », T8 sorti.

**Bogue n° 2 — les agrégats déguisés en zones.** La synthèse pondérée d'A3 titrait « la plus
lourde : World (+23,5 %) » et comptait Asia Pacific, Europe… parmi les « 15 zones pesantes » —
le mouvement d'ensemble de la série présenté comme un déplacement géographique. Correctif :
`syntheseZones` ne reçoit que les vraies zones ; dans le bloc des mouvements, la ligne d'un
agrégat se lit en ligne SIMPLE de série. Vérifié : « 7 zones pesantes, la plus lourde China
(+18,2 %) ».

**Et une rechute attrapée dans la foulée** : la phrase de l'Anticiper « les défavorables sont
ceux du métier — le carnet, l'usinage… » était RÉDIGÉE — elle a menti à la seconde où T8 a
changé de camp. L'énumération est désormais calculée depuis la liste elle-même. Troisième
occurrence du même motif en deux jours : TOUT texte d'écran qui énumère des faits doit être
calculé — la prose ne survit pas aux données.

**Cascade rapport (pour la session Cowork, notes du 01.09)** : le § théorique définit les hard
data comme « données OFFICIELLES » — la confusion que l'écran vient de corriger (« hard » =
collecté par code, § 8.6.4 : FH, CP, CCFA sont des associations) ; le résumé liminaire porte
des décomptes périmés (44/39/28). Aucun « −34,5 % » ni « 19 des 26 » dans le rapport — rien
d'autre à rattraper de ce chef.

## 01.09.2026 (fin) — Humanisation du texte : 82 tirets cadratins affichés, 2 restants (des citations)

**Demande de l'étudiant** : texte humain et compréhensible partout, plus de tiret cadratin
(« — »), plus de notes méta (« aucun modèle de langage n'écrit cette phrase »), et AUCUN texte
en dur qui pourrait devenir faux quand une nouvelle collecte tourne.

**Fait, en trois couches, mesuré au DOM rendu (82 lignes fautives → 2) :**
1. **Interface** (JSX des 8 écrans vivants) : ponctuation ordinaire, notes méta supprimées ou
   raccourcies en langage courant (« amplitude vue moins d'une fois sur dix » → « variation
   rare pour cette série »), placeholders « — » → « n.d. », pied de barre latérale rendu
   générique (« Restitution v9 — … le 27.08 » → « Tableau de bord organisé par questions de
   veille »).
2. **Textes stockés en base et affichés** (migrations `2026-09-01_texte_humanise[_2].sql`,
   annexe 5) : libellés d'indicateurs, noms et organisations de sources, libellés de flux,
   formulations et mécanismes des questions, les 14 gabarits de réponse réécrits un à un
   (toujours à jetons : les valeurs restent calculées à l'affichage), fiches métier.
   **Le journal des décisions (`note_conception`) n'est PAS touché** : texte d'archive daté,
   le retoucher serait falsifier la trace.
3. **Prose générée** : consignes de style ajoutées aux trois workflows producteurs de texte
   ET normalisation DÉTERMINISTE à l'écriture (replace SQL/JS) — la leçon du jour : une
   consigne de style ne suffit pas toujours, le déterministe si. Commentaires et lectures
   régénérés (runs 199, 200) sur les données du jour.

**Deux défauts d'exécution attrapés en chemin** : (1) au 1er du mois, la requête des faits
d'événements (mois courant) rendait zéro ligne et n8n arrêtait la chaîne SANS erreur — runs
196/198 restés ouverts ; fenêtre glissante + `alwaysOutputData` + garde dans le composeur ;
(2) ma normalisation SQL avait d'abord enveloppé la colonne `model` au lieu de `text` —
attrapé à la relecture du JSON avant tout run.

**Les 2 lignes restantes sont des TITRES D'ARTICLES cités** (FDA 510(k) « Dexter L6 System —
Distalmotion SA ») : de la citation de source, qui ne se retouche pas — c'est même la règle
d'extraction (« recopié à l'identique »).

## 01.09.2026 (audit de fraîcheur) — Chaque indicateur ira-t-il chercher les nouveautés ? Inventaire complet

**Demande de l'étudiant** : garantir qu'aucune collecte n'est figée sur un millésime en dur —
que tout ira chercher les données NOUVELLES à chaque exécution. Audit exhaustif : les 102
liaisons actives, le code des workflows vivants, les résolveurs de documents, les flux.

**La mécanique, saine dans son principe.** Le collecteur générique porte des JETONS DE DATE
résolus à l'exécution ({{MOIS_ANNEE_COURANTE}}, {{ANNEE_COURANTE}}, {{ANNEE_MOINS:k}},
{{ANNEES_LISTE:N}}) ; les liaisons Eurostat/OCDE/BNS/OMS travaillent en FENÊTRE OUVERTE
(« depuis 2014 », toujours à jour) ; l'OFS PX-Web en « top 14 » (les 14 dernières années,
dynamique) ; TED en fenêtre glissante de 30 jours ; les flux RSS/FDA sont frais par nature.
Les années en dur restantes (Comtrade 2023/2024, IEA 2010-2025) sont de l'HISTORIQUE :
recollectées à chaque run (les révisions du producteur sont donc captées), le présent étant
porté par les jetons.

**Classement des 36 indicateurs collectés** : 9 sans date (toujours frais) · 8 à jeton
dynamique · 18 à fenêtre ouverte · **1 FIGÉ : A11**. Ses 16 liaisons portaient toutes une
année en dur — l'historique couvert jusqu'à 2025, mais rien n'irait chercher 2026 : créé le
27.08 sans recevoir le jeton {{ANNEE_MOINS:1}} que son frère A3 (même API) porte depuis
l'origine. **Corrigé** : liaison 145 au jeton, perpétuelle (migration
`2026-09-01_a11_jeton_annee.sql`, annexe 5).

**Résolveurs de documents, tous dynamiques, vérifiés sur code** : FH (page d'index stable,
nom de fichier résolu à chaque parution) ; CP (index + millésime maximal du nom) ; CCFA/A1
(page d'accueil → PDF le plus récent, ou URL directe pour les archives) ; OICA (page de
l'année du document traité) ; classeurs xlsx indexés (S4, T3 : lien résolu derrière la page).
**ACEA est le modèle du genre** : il calcule le mois révolu depuis la date du jour, sonde le
communiqué attendu et SÈME LUI-MÊME la file composite.

**Deux correctifs de code** : (1) la consigne d'extraction A1 donnait « 2024 » en exemple de
format — biais possible sur une édition future ; l'exemple cite désormais l'année du document
en file, calculée ; (2) le vieux workflow de démonstration multi-IA (H1, période 2025 en dur)
est un ARTEFACT D'EXPÉRIMENTATION, hors production — laissé tel quel, c'est une pièce datée.

**L'angle mort restant est HUMAIN, pas technique, et il est déclaré : l'amorçage annuel des
composites documentaires.** La CP et le CCFA publient UNE édition par an ; le pipeline résout
toujours la plus récente, mais il ne traite que les documents présents en `composite_queue` —
et personne ne sème automatiquement la ligne de l'édition suivante (ACEA le fait ; CP et CCFA
non). PROCÉDURE D'EXPLOITATION, une ligne par an et par source :

    INSERT INTO composite_queue (indicator_id, period, geo, source_doc, statut) VALUES
      ('H2', '<année>', 'CH', 'https://cpih.ch/statistiques/', 'a_verifier'),
      ('A1', '<année>', 'WORLD', 'https://ccfa.fr/analyses-et-statistiques/', 'a_verifier');

puis vérification nominative et exécution du workflow. Un détecteur à la ACEA serait la suite
naturelle (§ 13) — non construit, gel oblige.

## 01.09.2026 (suite) — Le semeur d'éditions annuelles : l'angle mort de l'amorçage est comblé

**Décision de l'étudiant** (« si on le fait pour l'ACEA, pourquoi pas pour ceux-ci ») : le
dernier maillon manuel de la fraîcheur est automatisé. Nouveau workflow
`veille_documentaire_annuelle` (9 nœuds), copie assumée du motif ACEA, couvrant les DEUX
sources documentaires annuelles en une exécution :

| source | page sondée | règle édition → période |
|---|---|---|
| Convention patronale (H2, l'extraction sert aussi H11) | cpih.ch/statistiques/ | édition N = période N |
| CCFA (A1) | ccfa.fr/analyses-et-statistiques/ | édition N = période N-1 |

Même doctrine qu'ACEA, reprise mot à mot : DÉTECTER N'EST PAS LIRE. Le veilleur constate
qu'une édition nouvelle existe et l'inscrit en file au statut `a_verifier` — la vérification
nominative et l'extraction multi-modèles restent en aval. Idempotent (une période déjà en
file n'est jamais réinscrite), User-Agent académique déclaré, conforme au précédent.

**Deux défauts au premier run — la série "invisible à la lecture" continue (10e et 11e) :**
1. le millésime était lu dans l'URL ENTIÈRE : le répertoire de téléversement du CCFA
   (/2026/06/…) a fait naître une fausse « édition 2026 » aussitôt inscrite en file.
   Millésime désormais lu dans le NOM DE FICHIER seul ; fausse ligne purgée (doc 12).
   Le même motif Max-année existe dans les résolveurs CP et A1 : sans danger là-bas
   (l'URL CP n'a pas de répertoire daté ; A1 n'utilise pas le millésime pour la période),
   mais consigné ;
2. la clôture du run n'était pas raccordée (run 201 resté ouvert) — câblée.

**Run 202, vert, comportement de référence** : « H2 : édition 2025 vue (période 2025) ;
A1 : édition 2025 vue (période 2024). 0 inscription(s) nouvelle(s). » Les trois pipelines
composites sont désormais AUTO-AMORCÉS : ACEA (mensuel), CP et CCFA (annuels). Le § 13
n'a plus à porter ce détecteur en perspective — il est construit ; la perspective restante
est son passage en déclencheur PLANIFIÉ (aujourd'hui manuel, comme les autres workflows).

## 01.09.2026 (épreuve du feu) — Toutes les chaînes exécutées avant gel : trois défauts critiques de plus

**Demande de l'étudiant** : ne pas geler avec de grosses erreurs cachées. Méthode retenue : ne
plus rien vérifier SUR PAPIER — tout EXÉCUTER sur données fraîches, puisque onze défauts sur
onze n'étaient visibles qu'à l'exécution.

**Défaut n° 12, le plus grave du lot : la collecte des flux mourait de sa source la plus
fragile.** Le nœud d'appel tolérait les erreurs HTTP (neverError) mais pas les CONNEXIONS
AVORTÉES : une seule source injoignable (GDELT, TLS coupé) tuait le run entier — et le corpus
était de fait arrêté au 25.08. Correctif : continuité par source (onError:
continueRegularOutput + garde dans le normaliseur, la panne consignée en incident). Au
passage, n° 13 : ma propre garde a d'abord redéclaré une variable existante — même famille,
attrapée au run suivant. **Run 206 vert-partiel : 124 items nouveaux, 16 flux servis, 3 GDELT
en panne SIGNALÉS sans rien casser.** Triage (207 : 124 scores) et événements (208 : 87
nouveaux) verts derrière — la chaîne quotidienne entière revalidée.

**Collecteur générique, run 209 : 9 580 observations sur 30 indicateurs** — dont **666 pour
A11 par la liaison à jeton créée à l'audit de fraîcheur** (preuve d'exécution, pas d'intention).
Incident isolé et propre : T4 (IMF en 503, panne externe, l'indicateur est hors vitrine).
**Veille ACEA, run 210 : « communiqué 2026-08 pas encore publié, rien à faire »** — le
comportement de référence.

**Infrastructure** : la base interne n8n atteignait 1,8 Go (chaque exécution archivée sans
borne) — élagage à 60 jours configuré dans le compose, avec le rappel E6 : le run de référence
cité au rapport s'archive dans annexes/ au moment de figer, les traces durables vivent dans
`runs` et `/data`. Adminer vérifié : profil optionnel, lié à 127.0.0.1.

**Livrables du dépôt** : README réécrit à l'état vrai — il décrivait le début août
(`dashboard.html` disparu, `01_schema.sql` renommé, « deux services », six workflows
« squelettes » là où vingt tournent). L'ancien `deploiement.md` (04.08) marqué REMPLACÉ,
conservé comme trace.

**Intégrité finale, par requête : zéro run ouvert · zéro file en attente · zéro valeur
orpheline · zéro certifié sans seuil ni énoncé.** L'API sert le run 210, 120 événements
récents, 6 lectures. Captures d'annexe 6 régénérées sur cet état.

## 01.09.2026 (suite) — Treize lignes, quatre signaux : restitution regroupée, et une règle de détection déclarée

**Constat de l'étudiant, sur capture** : « des signaux qui se répètent ou presque ». Exact :
neuf des treize lignes de l'automobile étaient A3 2025 en hausse dans chacune de ses zones
(la règle « variation rare » s'évalue par couple indicateur × zone), plus une dixième ligne
qui résumait les mêmes zones. Le contenu réel tenait en quatre signaux.

**Question posée avant d'agir : « est-ce juste ? »** Réponse écrite avant le code, et qui
sépare deux natures de règle :

1. **Règle de RESTITUTION** (`Secteur.jsx`, bloc « Mouvements inhabituels ») — légitime par
   construction : la détection ne change pas, les mouvements restent tous détectés,
   dépliables, comptés (« 3 signaux · 75 mouvements détectés »). Au-delà de trois
   mouvements sur un indicateur, une ligne d'ensemble calculée : qualificatif (généralisée
   si toutes les zones vont dans le même sens ; dominante si ≥ 80 % ; contrastés sinon),
   décompte hausses/baisses, zones qui pèsent et leur étendue, marginales comptées, agrégats
   hors décompte mais jamais hors écran, zones dont la dernière observation est antérieure
   comptées à part. **Garde-fou central : la divergence reste visible** — les zones à
   contre-courant qui pèsent sont nommées en ambre (S4 : « la plus lourde États-Unis −5 % »
   sous un titre « hausse dominante »), les marginales comptées. L'étendue se lit sur les
   zones qui pèsent, pas sur les marginales (sinon : Laos +989 %, Algérie +23 200 % — le
   palmarès des petits nombres déjà documenté sur A11).
   Ce qui aurait été injuste, et n'a pas été fait : relever les seuils parce que la liste
   était longue.

2. **Règle de DÉTECTION** — A7 France 2022 « −74,7 % ». Vérifié en base, pas supposé : les
   six pays de la série chutent ensemble de 35 % puis 45 % sur 2021-2022 (moyenne des six :
   534 → 535 → 347 → 190), 2020 plat. Troncature des comptages OCDE par date de priorité,
   pas une conjoncture. Quatorze runs ne pouvaient pas le montrer (même instantané annuel) ;
   la structure de la série le prouve. Règle admise aux trois conditions posées d'avance :
   **déclarée** (colonne `indicators.periodes_incompletes_source`, humaine, quatrième cas de
   la doctrine admet_negatifs), **visible** (`v_metriques.periode_en_consolidation`,
   `franchissement` = « non signalé : période en consolidation », `completude` l'énonce, la
   note de conception le dit), **conservatrice** (la valeur reste au registre, seul le
   signalement RI4 est différé). Déclaré à DEUX périodes, pas trois : 2020 ne le justifie
   pas. Seuil recalibré sur les périodes complètes (p90 38 %, n = 36) — le 55 % du 31.08
   incluait l'artefact lui-même. Migration `2026-09-01_periodes_en_consolidation.sql`,
   sortie en annexe 5 ; socle patché (colonne, commentaire, vue).
   **Dérive relevée au passage** : la note de conception d'A7 affirmait « seuil laissé nul
   à dessein » alors que la base portait 55 depuis le 31.08 — un texte en base contredisait
   une valeur en base. Réécrite.

**Coïncidence vérifiée, pas un bogue** : M1 Mexique +14,8 % et Allemagne +14,8 % sur 2025
sont deux glissements réels (14,81 et 14,79).

**Limite de fond, à écrire au § 12, que le regroupement ne règle pas** : « moins d'une fois
sur dix » sur une série annuelle de dix points se calibre sur neuf variations ; le plus grand
mouvement de la série y est *toujours* rare par construction. Sur séries courtes le signal
est fragile ; A3 l'illustre. Ce n'est pas une raison de le retirer, c'est une raison de le
dire.

**Constat annexe, non traité, à traiter avant gel** : `db/02_referentiel.sql` porte 49
indicateurs et 118 liaisons quand la base en compte 53 et 120 ; `01_socle.sql` 41 vues
contre 44. La procédure (« migrations postérieures au 25.08 à la main ») reste vraie, mais
une base neuve construite depuis le dépôt ne serait pas celle du rapport. **Reconsolider les
deux fichiers depuis la base au moment de figer**, comme le 25.08.

## 01.09.2026 (suite 2) — Socle et référentiel reconsolidés depuis la base : la reproductibilité redevient vraie

**Constat** : `db/01_socle.sql` (25.08) portait 41 vues contre 44 en base, sans les colonnes
et tables créées depuis ; `db/02_referentiel.sql` 49 indicateurs et 118 liaisons contre 53 et
120. Une base neuve construite depuis le dépôt n'aurait pas été celle du rapport — la
procédure « migrations postérieures à la main » restait vraie, mais c'est une procédure, pas
une garantie.

**Fait** : `pg_dump --schema-only` et `--data-only --column-inserts` sur les neuf tables de
référence (les huit du 25.08 + `flux_filtrage_regles`, née le 26.08), mêmes post-traitements
que le 25.08 (en-têtes manuscrits conservés et datés, `\restrict` retirés, `CREATE SCHEMA IF
NOT EXISTS`, T12/T13 retirés — le déclencheur `trg_indicateur_sans_question` les refuserait,
et il a raison —, `setval` sur `max(binding_id)`). **Un piège au premier essai** : le dump
pose lui-même `set_config('search_path', '')`, qui annulait le `SET search_path = public`
manuscrit ; les fonctions de contrôle ne trouvaient plus leurs tables et l'import échouait
sur la 494e ligne. Le 25.08 l'avait retiré sans le noter ; c'est noté maintenant.

**Vérifié par construction** : base `veille_neuve` créée, les deux fichiers appliqués, puis
comparaison à la base en service — 31 tables, 44 vues, 4 déclencheurs, 44 fonctions, 137
contraintes, 808 colonnes, 70 commentaires : identiques ; référentiel identique **par
empreinte md5** des lignes (indicateurs hors T12/T13, liaisons, flux, questions) ;
`v_bilan_referentiel` sur la base neuve : 51 · 41 certifiés · 38 hard · 3 composites. Base
d'essai supprimée. `DEPLOIEMENT.md` mis à jour avec la règle : **à chaque gel, reconsolider**.

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

## 02.09.2026 (suite 6) — A7 : les textes portés par la base alignés sur la base

Migration `migrations/2026-09-02_a7_notes_et_commentaires.sql`, sortie dans
`annexe_5/2026-09-02_a7_notes_et_commentaires.txt` (BD-2, BD-3, BD-7, BD-11).

- **M6** (BD-3) : la note disait « seuil laissé nul à dessein, RI4 inapplicable » ; la base
  portait 22 depuis le 31.08. M6 est lu sur le **même jeu OCDE qu'A7** (DSD_PATENTS, dimension
  PRIORITY), donc `periodes_incompletes_source = 2` est posé comme sur A7 et le seuil est
  **recalibré sur les périodes complètes** (≤ 2020, méthode du 10.08 : n = 36, p90 20,7 %)
  → **20 %**. Contrôle de méthode : la même requête redonne les chiffres d'A7 du 01.09
  (n = 36, p90 38,1). Effet vérifié : les deux « franchi » de M6 (CHE et FRA 2022, −31,6 % et
  −25,9 %) passent à « non signalé : période en consolidation » ; `alertes` de l'API ne
  contient plus M6. **À dire honnêtement** : la série de M6 prouve nettement 2022 (les six pays
  baissent ensemble, −19 % en moyenne) et faiblement 2021 (−7 %, trois hausses, trois
  baisses) ; la déclaration « deux périodes » suit le mécanisme de la source, identique à
  celui d'A7, plus que la seule lecture de la série — **décision d'étudiant, à ratifier**.
- **H2 / H12** (BD-11) : H2 affirmait que les observations STATENT « ont été réattribuées à
  H12 » ; H12 disait qu'elles « n'ont PAS été déplacées ». Tranché par requête : 56 lignes
  `etl/valide_source`, runs 43-161, restent sous H2 ; H12 en porte 33 (runs 173-212). La note
  de H2 est corrigée, celle de H12 inchangée. Le premier contrôle de la migration comptait la
  citation « réattribuées à H12 » reprise entre guillemets par la correction (1 au lieu de 0) ;
  contrôle refait sur l'affirmation « ont été réattribuées » (0), complément en fin de
  sortie, requête corrigée dans le fichier.
- **`sante_a_la_date()`** (BD-7) : la fonction filtrait `status = 'certifie'` quand
  `v_sante_secteur` filtre `en_vitrine` ; horlogerie 0,93 contre 0,71, les deux servis
  (`/veille/sante` : `sante` et `ecart_7j`). Prédicat aligné sur `en_vitrine`, commentaire
  réécrit ; contrôle après : cinq secteurs, même score par les deux objets. La colonne
  `indicateurs_certifies` de `v_sante_secteur` compte les indicateurs **en vitrine** ; elle
  n'est pas renommée (l'écran la lit) mais commentée, et `CetteSemaine.jsx` dit désormais
  « sur n en vitrine ». Conséquence sur `ecart_7j` : l'écart à sept jours de l'horlogerie
  se lit maintenant 1,20 → 0,71 (le « précédent » est calculé par la fonction corrigée).
- **`v_ecart_entre_runs`** (BD-2) : le commentaire attribuait tout écart à « une révision par
  la source ». Vérifié ligne à ligne sur les 241 écarts non nuls : H2 ×11 = changement de
  source sous le même identifiant, A1 ×28 = ré-extractions par modèle, M3 ×1 = valeur rejetée
  (A4), 201 (A5, M2, H1, T6, T8, …, même collecteur, écarts de l'ordre du pour-cent)
  compatibles avec une révision **présumée**. La vue reçoit `nature_ecart` (quatre cas, par
  ce que le registre sait) ; `v_run_history` expose `obtained_by`. Colonnes ajoutées en fin
  de liste, aucun consommateur ne change de forme. Écran : onglet « Révisions » →
  « Écarts entre collectes », colonne « Nature », phrase « corrigées par leur source »
  retirée (`Fiabilite.jsx`, `Executions.jsx`). `Dispositif.jsx` porte le même texte mais n'est
  pas routé (UI-30, A9).
- **PASSATION** : la phrase « `alert_threshold_pct` est nul sur A7, M6, T8 et T10 » (entrée du
  26.08) était fausse pour A7 et M6 depuis le 31.08 ; corrigée sur place, avec la date.
- **A7 (indicateur)** : le « 57,1 → 55 » relevé par l'audit est dans le commentaire de la
  migration du 31.08, pas en base ; la note d'A7 dit 38 % depuis le 01.09. Rien à changer.
- API republiée (`publish:workflow` + `restart`), build refait, `verification/executer.sh` :
  17 rendus sans exception. `db/01_socle.sql` non touché — reconsolidation à A10.

## 02.09.2026 (suite 7) — A8 : les libellés disent ce que la série mesure ; filtres M3 et T4

Migration `migrations/2026-09-02_a8_libelles_et_filtres.sql` (corps + trois compléments datés,
exécutés dans l'ordre), sortie dans `annexe_5/2026-09-02_a8_libelles_et_filtres.txt`. Runs
**213** (07:24, 11 436 obs) et **214** (11 438 obs), collecteur générique complet — il n'a pas
de filtre par liaison. Chaque chiffre ci-dessous a été revérifié sur pièce avant d'être écrit.

- **Indicateur synthétique** : le titre « part suisse du commerce horloger mondial » était
  faux. Le dénominateur est le **panier des sept déclarants de H3**, pas le monde. Vérifié le
  02.09 sur Comtrade, tous déclarants, SH 91, 2023 : monde 61,17 Mrd USD → part suisse
  **48,65 %** ; panier 48,51 Mrd (79,3 % du monde) → 61,35 %. Treize points d'écart.
  `COMMENT ON VIEW v_indicateur_synthetique` réécrit ; bloc `Synthetique` de `Secteur.jsx`
  retitré « Part suisse des exportations d'horlogerie (SH 91) d'un panier de n exportateurs »,
  unité « du panier de n déclarants, non du monde », note explicite. Rendu contrôlé sur
  « Vue d'ensemble » et « Socle transversal ». **Reste faux ailleurs** : `SecteurQV.jsx` l. 395
  (non routé, UI-30 → A9) et le rapport C4 l. 16 (liste C, Cowork).
- **Libellés** : H7 « Exportations suisses de montres-bracelets, valeur (FH) » — le tableau FH lu
  est celui des montres-bracelets, non du chapitre entier ; H1 (Comtrade, chapitre) converti en
  francs par T2 (CHF par USD, donc H1 × T2) lui est supérieur de 3,9 à 5,3 %, moyenne 4,7 % sur
  19 mois. M4 « Emplois medtech et mécanique de précision en Suisse (NOGA 26.6, 32.5 — y c.
  mécaniciens-dentistes et lunetterie) » — 15,9 % du total 2024 (5 254/33 104, brut
  `M4_run212_b142.raw`) ; le périmètre de la liaison n'est **pas** changé, cela se décide en
  supervision. M2 « … instruments et fournitures médicales et dentaires UE (NACE C32.5) ».
  A2 « Immatriculations de voitures particulières neuves, UE27 (ACEA) » (PDF `A2_run58.pdf`).
- **M3** (liaison 25, OMS GHED) : `$filter` « TimeDim ge 2014 » et `periode_min` 2014 au lieu
  d'un seul millésime. Run 213 : CHE **10 points** 2014-2023 (10,68 → 11,69 % du PIB), 2 051 obs
  sur 205 zones.
- **T4** (liaison 13, FMI WEO) : `periode_min` 2014, `frequency` « annuelle » (la source publie
  des points annuels, deux fois l'an). Run 213 : 10 points, **sans 2020 ni 2021** — le brut
  (`T4_run213_b13.raw`) les contient ; −2,7 écarté par le contrôle « valeur négative », 6,7 par
  ricochet (+348 % contre −2,7, seuil de variation 200 %). Un taux de croissance est une
  grandeur signée : `admet_negatifs` déclaré sur la liaison (doctrine T5/T8), run 214 →
  **12 points** 2014-2025 avec 2020 : −2,7 et 2021 : 6,7. Aucune trace en base des observations
  écartées, seul le compteur de `runs.note` (1 079 → 1 077) — limite connue.
- **Retour en vitrine de M3 et T4** (complément 2) : écartés le 26.08 pour série courte (1 et
  3 points) ; c'était le filtre, pas la source. Seuil en vigueur huit points (§ 8.8.7), même
  forme que le retour H2/M4 du 28.08. Effet sur le score : médical −0,44 → **−0,55**
  ({M1,M2,M3,M4,M7,M8}), transversal 0,51 → **0,47** (onze indicateurs, profondeur 12).
  `v_bilan_referentiel` total : en_grille 38 → **40**, écartés 15 → **13** (certifiés 41
  inchangés). **Décision d'étudiant, à ratifier.**
- **Seuil M3** (complément 3) : le 3 % semé a priori le 06.08 sur registre vide produisait, une
  fois M3 en vitrine, **132 mouvements** sur 205 zones en 2023. Recalibré par la méthode du
  10.08 (p90 de |glissement| toutes zones, n = 1 845, p90 19,9 %) → **19 %** ; 24 zones
  franchissent en 2023 (écran médical : 132 → 26 mouvements). Hors 2020-2022 le p90 vaut
  15,1 % ; la méthode ne trie pas les années, elle est appliquée telle quelle — dit dans la
  note. **T4 reste « seuil non configuré »** : le glissement relatif d'un taux de croissance
  n'a pas de sens (2021 : +348 %) ; un seuil en points demanderait une règle que RI4 n'a pas.
- **À savoir** : le commentaire exécutif validé servi sur le socle dit encore « série
  semestrielle » pour T4 — c'est le texte validé humainement avant le changement, il n'est pas
  modifié à la main ; la prochaine fournée portera « annuelle ». M3 CHE 2020 (+4,9 %) et 2022
  (−3,0 %) sont « sous le seuil » à 19 % (ils étaient « franchi » à 3 %).
- Build refait, `dashboard-app/verification/executer.sh` : 17 rendus sans exception (le script
  se lance depuis `dashboard-app/`, pas depuis `prototype/`). API non republiée (rien de
  structurel : elle lit les vues). `db/02_referentiel.sql` (libellés, seuils, liaisons, vitrine)
  n'est pas régénéré → A10.

## 02.09.2026 (suite 8) — A9 : dépôt, historique et hygiène

Section 3.8 du tour « jury » (DOC-8, DOC-11, DOC-13, DOC-15, DOC-16, UI-30). Rien de
l'historique n'est réécrit.

- **Journal fusionné.** Du 26.08 au 02.09, treize entrées n'existaient que dans le fragment
  versionné (`prototype/PASSATION_PROTOTYPE.md`, 13 entrées) et les 79 autres seulement dans le
  fichier racine, hors dépôt. Fusion en ordre chronologique (les deux entrées du 26.08 insérées
  à leur date, les onze autres à la suite) : **92 entrées dans le dépôt**, le fichier racine
  n'est plus qu'un renvoi de six lignes ; `CLAUDE.md` et le `README` pointent sur le dépôt.
- **Deux lots commis en retard, dits ici** (l'historique se lit autrement sinon) : le commit
  `1264bf5` du 23.08 (73 fichiers, +9 080 lignes) porte le travail du 20 au 23.08 ; les neuf
  commits du 31.08 entre 15:53 et 17:23 portent le travail des 27-30.08, que le journal date
  jour par jour (quatorze entrées du 27 au 30.08) — aucun commit du 26 au 30.08. Les copies
  `*.avant_*` prises sur cette période tenaient lieu d'historique ; c'est pourquoi elles sont
  archivées et non supprimées.
- **Balises.** `gel-2026-09-01` (sur `9728ae0`, dernier commit du gel) et `tour-jury-2026-09-02`
  (sur `0b4d56e`, A1), annotées, posées aujourd'hui sur des commits existants et le disant.
  **Aucune balise `seance-N`** : les quatre séances tenues (16.04, 13.05, 28.05, 15.06)
  précèdent le premier commit (10.08) et aucune n'a eu lieu depuis — en baliser une serait
  fabriquer une antériorité.
- **Versions épinglées** par empreinte dans `docker-compose.yml`, relevées sur les images qui
  tournent : PostgreSQL 16.14, n8n 2.20.7-exp.0 (Node 24.14.1, image du 13.05.2026),
  nginx 1.27.5, Adminer 6.0.1. `docker compose up -d` rejoué sur le compose épinglé : trois
  services sains, 8080 et `/healthz` à 200. Node de construction : `dashboard-app/.nvmrc`
  (24.19.0) et `engines` (`>=24 <25`). `DEPLOIEMENT.md` § 1 mis à jour.
- **`regenerer_socle.sh`** dumpe désormais `flux_filtrage_regles` (la ligne était dans
  `db/02_referentiel.sql` depuis la reconsolidation manuelle du 01.09 ; le script, lui, l'aurait
  perdue au prochain rejeu). Script non rejoué ici : reconsolidation à A10.
- **Cinq squelettes du 04.08** (`collecte_hard_data`, `collecte_a5_multi_geo`,
  `collecte_m2_eurostat`, `extraction_composite_multi_ia`, `scenario_c_agent_autonome`) déplacés
  dans `n8n_workflows/archive/squelettes_2026-08-04/`, tableau « ce qu'il était / ce qui l'a
  remplacé » dans le `README` de l'archive. La racine compte **21 fichiers = 21 workflows** de
  l'instance. Le `README` attribuait l'expérience B/C au fichier n8n : c'est
  `scenario_c/agent_autonome.py` qui l'a portée, corrigé. Les deux mentions restantes de
  `loader:8080` (`analyse_tendances_alertes`, `attribution_ancree_medical`) sont des
  descriptions qui racontent le remplacement du squelette, pas des appels.
- **Courriel des acheteurs TED** (migration `2026-09-02_a9_courriel_hors_restitution.sql`,
  sortie en annexe 5) : 1 284 avis en portent un, 442 de forme prénom.nom@. Il ne sort plus par
  `v_actions` ni `v_acheteurs_recurrents` (DROP + CREATE, commentaires réécrits) ; il reste dans
  `ted_avis`, pièce d'audit, et dans l'avis TED où l'écran renvoie. `AFaire.jsx` : bouton
  « Écrire à l'acheteur » retiré, colonne « Contact » → « Site ». API vérifiée : aucun
  `courriel` dans `/veille/actions`. **Effet de bord** : la vue des acheteurs récurrents groupait
  aussi par courriel ; sans lui, 205 → **213** organismes (des organismes à deux contacts,
  1 + 1 avis, passent le seuil de deux), 46 → 48 actions marquées récurrentes. `v_appels_ouverts`
  porte encore la colonne : vue de travail, servie par aucune API ni aucun écran.
- **UI-30.** Fermeture des imports calculée depuis `main.jsx` : 13 fichiers vivants. Les 48
  copies `*.avant_*` (22 workflows, 22 application, 3 étage 2, 1 compose) → `archive/etats_
  anterieurs/` à leur chemin relatif ; neuf pages non routées + `Mini.jsx`, `app.css`, `v6.css`
  → `archive/dashboard-app_pages_non_routees/`, `README` d'archive. **Correction d'A7** : la
  retouche « sur n en vitrine » de `CetteSemaine.jsx` portait sur une page non montée — sans
  effet à l'écran ; aucune page vivante ne lit `v_sante_secteur.indicateurs_certifies`.
  `verification/classes.mjs` ne liste plus `Mini.jsx`. Favicon SVG incorporé dans `index.html`
  (plus de 404). Build refait, 17 rendus sans exception.
- **Non fait** : pas d'`errorWorkflow` n8n (les 59 runs `echec` restent tels quels, statuts non
  comparables — constat DOC-16 laissé ouvert, dit en limites) ; `.git` de 115 Mo inchangé.

## 02.09.2026 (suite 9) — A10 : socle, référentiel et exports reconsolidés après la liste A

Dernier item de la liste A du tour jury (règle « à chaque gel » : la base en service et les
fichiers `db/` doivent redire la même chose). Tout ce qui suit est vérifié sur pièce.

- **`db/01_socle.sql` et `db/02_referentiel.sql` régénérés** par `./regenerer_socle.sh`
  (la boucle des tables inclut désormais `flux_filtrage_regles`, ajoutée en A9). Base en service :
  27 tables · 44 vues · 53 indicateurs · 103 liaisons actives · 24 flux. Base de recette
  reconstruite depuis les fichiers : **51 indicateurs** (T12/T13, orphelins, retirés à la
  régénération) ; empreintes md5 identiques sur les neuf tables déclaratives (indicators hors
  T12/T13, source_bindings, flux_sources, sector_watch_questions, indicator_watch_questions,
  flux_filtrage_regles, sources, watch_questions, sectors) ; 44 vues / 44 fonctions /
  4 déclencheurs / 818 colonnes / 143 contraintes identiques. `veille_recette` supprimée après
  comparaison. En-têtes des deux fichiers complétés à la main (mention du 02.09 et de A3-A9).
  Bilan `v_bilan_referentiel` total en service : `|53|41|38|3|10|40|13` ; en recette
  `|51|41|38|3|10|40|11` (l'écart de deux est T12/T13, écartés, sans observation).
- **Exports régénérés** : `exports/csv/*.csv` (7 fichiers) et `exports/1_tableau_de_veille.xlsx`
  par `generer_classeur.sh` ; `annexes/1_tableau_de_veille.md` (394 lignes) et `.xlsx` ;
  `annexes/4_workflows_orchestration.md` (186 lignes). **Les heures que ces fichiers citent depuis
  la base sont en UTC** (« produit le 02.09.2026 à 07:55 » = 09:55 locale) — le conteneur
  PostgreSQL n'a pas de fuseau ; à savoir avant de citer une heure de run dans le rapport.
- **D2 (section « Sources de données ») régénéré, après une vraie campagne.** Le générateur
  porte `VERIF_LE` en dur (règle du 30.08 : ne l'avancer qu'après une campagne réelle). Les
  **27 URL externes** (26 au 30.08 + `cp`, Convention patronale, qualifiée le 30.08) ont été
  testées par curl le 02.09, sortie brute dans `annexes/verif_urls_2026-09-02.txt` : aucun lien
  mort ; AIE et FMI toujours en 403 ; `ocde_brevets` en `ERR(3)` sous curl à cause des crochets
  non encodés de l'URL (200 avec `-g`, même profil qu'au 30.08 — défaut de forme de l'outil, pas
  de la source) ; ACEA en 200 sur l'accueil comme sur un communiqué PDF, avec et sans en-tête de
  navigateur (complément journalisé dans le même fichier, parce que la note du rapport l'affirme).
  **Défaut de gabarit corrigé au passage** : le paragraphe OFS du générateur attribuait la
  découverte de l'adresse inexacte à « la campagne du ${VERIF_LE} » — une régénération aurait
  déplacé un fait du 30.08 au 02.09. Date historique codée en dur, commentaire dans le script.
  Autres différences visibles du D2 régénéré par rapport au fichier du 30.08 : source `cp`
  ajoutée (23 sources exploitables au lieu de 22), H2 rattaché à `cp` et H12 à l'OFS (migration
  du 30.08), tirets cadratins des titres devenus deux-points (choix du générateur, non retouché).
- **Annexe 2 (prompts) régénérée, deux défauts du générateur corrigés.** (1) L'entrée scénario C
  pointait sur `n8n_workflows/scenario_c_agent_autonome.json`, archivé en A9 — l'annexe aurait
  dit « fichier absent du dépôt ». Déplacée vers les scripts : `scenario_c/agent_autonome.py`,
  constantes `MESSAGE_SYSTEME` et `CONSIGNE_AUTOCRITIQUE`, qui sont les prompts réellement
  envoyés lors de la confrontation B/C (la maquette n8n n'a jamais été exécutée). (2) Les accents
  des prompts extraits des nœuds Code sortaient en mojibake (« Ã© », déjà dans l'annexe du
  24.08) : `b.encode().decode("unicode_escape")` réencodait en UTF-8 puis décodait en latin-1.
  Supprimé — `json.loads` résout déjà les échappements. Annexe sans « Ã » (158 lignes).
- **Captures régénérées** dans `annexes/6_captures/2026-09-02/` (11 écrans, build du 02.09 servi
  par nginx). Contrôle visuel du socle transversal (titre « Part suisse … d'un panier de
  7 exportateurs », 11 indicateurs suivis) et des actions (colonne « Site », plus de courriel).
  Vu sur capture et corrigé : « dans 1 semaines » — accord du pluriel dans `phrases.jsx`
  (échéance et ancienneté de collecte). Build refait, 17 rendus sans exception, captures reprises.
- **Contrôle avant commit** : aucun `.env`, `data/`, `*.tar.gz` dans `git status`.
- **Non fait / restes signalés** : le commentaire exécutif validé sur le socle (01.09) dit encore
  « série semestrielle » pour T4 (à réviser à la prochaine fournée, pas à la main) ; `errorWorkflow`
  n8n et statuts d'échec (DOC-16) non traités ; `.git` de 115 Mo ; annexes et D2 sont hors dépôt
  (copie Drive). **La liste A est close** ; les listes B (actes humains) et C (rapport) restent à
  l'étudiant.

## 02.09.2026 (suite 10) — Liste B, acte 1 : la couche 0 décidée

Premier des quatre « jamais » relevés par le tour jury (IA-20) : la file de la couche 0
(`source_qualification_queue`, 19 candidats du run du 22.08, QV5 automobile) avait été
alimentée et jamais décidée. Décidée ce jour, migration
`2026-09-02_b1_couche0_decisions.sql` (sortie en annexe 5).

- **Résultat : 1 inscrite · 5 différées · 13 écartées**, chaque décision avec son motif —
  la colonne `motif` n'existait pas sur cette file (A3 l'avait ajoutée aux autres) ; ajoutée.
  `decided_by = 'N. Castillo'`, décision d'étudiant sur proposition motivée de la session.
- **Raisonnement appliqué dans l'ordre** : (1) jeu de données ou simple page (avis MIIT, page
  ICCT, programme FHWA, boîte à outils DOT → écartés : matière à flux, pas au référentiel) ;
  (2) réponse à la question posée (EPA → QV4, CAAM → QV2 : différés avec réorientation) ;
  (3) les quatre critères d'admissibilité du cadrage (Tax Foundation, AEE non identifiable :
  écartés) ; (4) redondance (ACEA proposée sous trois éditions, AFDC sous quatre entrées,
  EAFO sous deux : une entrée gardée par série).
- **Le consensus a priorisé, il n'a pas décidé** : le seul candidat à 3 modèles sur 4 est le
  seul inscrit ; deux candidats à un seul modèle (EAFO, State aid scoreboard) sont différés
  sur le fond.
- **L'inscription est réelle** : ligne `acea_incitations` dans `sources` (ACEA, « Electric
  cars: tax benefits and incentives », annuelle, PDF tabulaire par pays, libre),
  `a_confirmer` — accès vérifié (200 les 22.08 et 02.09), granularité d'extraction non
  validée, **aucune liaison ni indicateur rattaché**. « Inscrite » sans cette ligne aurait été
  une surdéclaration. Sources : 23 certifiées + 6 à confirmer = 29, dont 28 à URL externe.
- **Effets** : D2 régénéré (28 URL testées le 02.09 — la 28e ajoutée au fichier
  `annexes/verif_urls_2026-09-02.txt` ; 6 sources à confirmer). `v_bilan_referentiel` inchangé
  (compte les indicateurs, pas les sources). Ni l'API ni les écrans ne servent la file : l'acte
  est visible par requête (`SELECT decision, count(*) FROM source_qualification_queue GROUP BY 1`).
- **Limites à dire dans le rapport** (session Cowork) : la couche 0 a été exécutée sur **une
  seule question de veille** (QV5 automobile) — son comportement sur d'autres questions n'est
  pas établi ; l'appréciation des candidats s'est fondée sur les fiches des modèles, le titre
  réel des pages relevé le 02.09 et la connaissance des producteurs, sans ouverture détaillée
  de chaque jeu, d'où une seule inscription en `a_confirmer`. Deux pages ont répondu « Access
  Denied » le 02.09 (FHWA, DOT) alors que la file les avait vues en 200 le 22.08.
- **Socle** : la colonne `motif` et la ligne `acea_incitations` seront reprises dans `db/` à la
  prochaine régénération (règle « à chaque gel »), pas fichier par fichier.

## 02.09.2026 (suite 11) — Liste B, acte 2 : les textes servis relus

Deuxième « jamais » du tour jury : les textes de modèle servis avec badge « non relu »
n'avaient jamais été relus depuis le régime de diffusion du 31.08. Relus ce jour, migration
`2026-09-02_b2_relecture_textes_servis.sql` (sortie en annexe 5). Décisions de l'étudiant
sur proposition motivée ; `validated_by = 'N. Castillo'`.

- **Contrôle préalable, automatisé** : chaque nombre des 5 commentaires servis (run 199) a été
  cherché dans la charge d'entrée que le modèle avait reçue (`input_payload`) — **91/91
  retrouvés**, aucun chiffre inventé ni calcul dérivé (les défauts de la fournée 1 du 24.08 ne
  se reproduisent pas). Pour les 13 lectures transversales, les références `[Fn]` de
  l'hypothèse ont été confrontées aux faits joints (`faits_cites`).
- **Commentaires : 4 validés (85, 86, 88, 89), 1 rejeté (87, horlogerie)** — « les reculs
  d'emploi et d'établissements » alors que H11 est à +0,44 %, ce que le § 5 du même texte dit.
  Famille : affirmation contredite.
- **Lectures : 7 validées (1, 2, 4, 8, 9, 12, 13), 6 rejetées.** Deux familles : *affirmation
  contredite ou non fondée* (5 : un dénombrement mensuel ne fonde pas une « progression » ;
  6 : « les plus nourris de tous les secteurs », 29 contre 34 en médical le même mois ; 10 :
  dominance non lisible dans un seul type dénombré) et *référence invérifiable* (3 : [F7] ;
  7 : [F29] ; 11 : [F59] [F60] absents des faits joints) — cette seconde famille est
  **nouvelle** pour les lectures, à écrire au ch. 12. La 12 porte un incident « chiffre
  étranger » du pipeline : faux positif (le « 20 » de « G20 »), consigné dans le motif.
  Colonne `motif` ajoutée à `lectures_transversales` (absente jusqu'ici).
- **Effet à l'écran, vérifié sur `/veille/donnees`** : quatre commentaires servis sans badge ;
  pour l'horlogerie, l'API sert désormais le **82** (run 197, `a_valider`, badge) — repli
  conçu sur le dernier texte non rejeté, à relire à son tour. Lectures servies : 8, 9, 12, 13
  (les deux rejetées du run 200 ne sont plus servies).
- **À dire dans le rapport** : la validation porte sur *le texte face à sa charge du jour*,
  pas face à la base d'aujourd'hui — les dénombrements d'événements cités le 31.08 (F39 = 29)
  ne sont plus ceux de la vue (9), les événements ayant bougé depuis. Taux mesurés une fois :
  commentaires 1 rejet / 5, lectures 6 / 13.

## 02.09.2026 (suite 12) — Liste B, acte 3 : trente événements relus au hasard

Troisième « jamais » : aucun des 690 événements extraits par le modèle n'avait été relu par un
humain (`flux_evenements.statut = 'non_relu'` partout). Plutôt que les 69 servis, un
**échantillon aléatoire reproductible** (`setseed(0.42)`, `ORDER BY random() LIMIT 30`, les
30 identifiants figés dans la migration `2026-09-02_b3_evenements_echantillon.sql`, sortie en
annexe 5) — pour obtenir un taux d'erreur mesuré, pas une relecture de convenance. Décisions de
l'étudiant sur proposition motivée ; `verifie_par = 'N. Castillo'` ; colonne `motif` ajoutée.

- **Critère** : fidélité de l'extraction (type, sens, acteur, zone, résumé) au **titre, seule
  charge transmise au modèle** (vérifié dans `extraction_evenements_flux.json` : `item_id |
  [secteur] titre`, ni description ni nom d'acheteur). La pertinence de l'item n'est pas jugée
  ici, c'est l'objet de l'audit du filtrage (B4).
- **Population** : 690 = 309 presse + 287 avis TED + 94 FDA. Les TED/FDA sont du régime
  antérieur au 01.09 (depuis, seules les sources `lecture_evenementielle` sont lues et servies) ;
  ils restent au registre, l'échantillon en a tiré 17 sur 30.
- **Résultat : 24 validés, 6 rejetés — taux mesuré 20 %.** Trois défauts typés :
  1. `acteur = « TED »` (42, 46, 57, 65) : la plateforme de publication prise pour l'acheteur,
     alors que l'attendu était « non précisé » (ce que le modèle a fait ailleurs : 244, 207,
     286). Le nom réel figurait dans la charge collectée (`payload->'buyer-name'` : Fraport AG,
     hôpital de Prievidza…) mais **n'était pas transmis au modèle**. 27 autres `non_relu`
     portent ce même acteur — défaut corrigeable (transmettre `buyer-name`, ou consigne
     « acteur absent ⇒ non précisé ») mais sur un régime que le workflow n'exécute plus.
  2. Type forcé (364) : `lancement_produit` pour une démonstration technologique.
  3. Acteur mal identifié (529) : une personne (ministre) au lieu de l'organisation ; objet de
     défense classé automobile par le flux.
- **Observation pour C.8, pas une erreur individuelle** : typage instable des avis TED — même
  genre d'avis tantôt `autre` (244, 57) tantôt `investissement` (207) ; tantôt `neutre` (262,
  65) tantôt `opportunite` (93, 308). Limite de reproductibilité de la typologie, à écrire.
- **Commentaire 82** (horlogerie, run 197), servi depuis le rejet du 87 : contrôlé cohérent
  avec sa charge en B2, `valide` confirmé ici. L'horlogerie est servie sans badge.
- **Effet vérifié sur `/veille/donnees`** : 364 et 529 ne sont plus servis (`statut <> 'rejete'`),
  les événements validés apparaissent avec leur statut ; les 4 TED rejetés n'étaient de toute
  façon plus servis. État : `flux_evenements` 660 non_relu / 24 valide / 6 rejete ;
  `commentaries` 19 a_valider / 30 valide / 39 rejete.
- **Limite à écrire** : 30 sur 690 tirés une fois ; l'intervalle de confiance d'un taux de 20 %
  sur n = 30 est large (≈ 8–39 % à 95 %), à présenter comme un ordre de grandeur.

## 02.09.2026 (suite 13) — Liste B, acte 4 : le filtrage audité, la liste B close

Quatrième et dernier « jamais » : la règle `seuil_v1` avait écarté 964 items depuis le 26.08
sans qu'un seul ait été audité — l'écran disait « taux de faux négatifs inconnu ». Le dispositif
d'audit existait (vue `v_filtrage_echantillon` à tirage déterministe, table
`flux_filtrage_audit`, restitution par ajout) ; il n'avait jamais servi. Migration
`2026-09-02_b4_audit_filtrage.sql`, sortie en annexe 5. Décisions de l'étudiant sur proposition
motivée ; `audite_par = 'N. Castillo'`, échantillon `2026-09`.

- **Échantillon** : les 40 premiers rangs de la vue pour septembre (les 10 de l'écran inclus),
  identifiants figés dans la migration — la vue exclut ensuite les items audités du mois, son
  résultat a donc changé (924 restants).
- **Critère** : l'écart était-il fondé ? Faux négatif si un décideur de PME de mécanique de
  précision devait voir l'item dans sa file de signaux.
- **Résultat : 39 `confirme`, 1 `faux_negatif` — taux mesuré 2,5 %.** Les 39 se répartissent en
  cinq familles (avis TED hors champ 14 ; avis TED médicaux courants comptés par M7 12 ;
  actualité sans contenu industriel 7 ; FDA logiciel ou rappel déjà compté 3 ; communiqués
  produit/infrastructure 3). Le faux négatif, item 23 (« Consumo de vehículos chinos en México
  crece y producción se estanca », note 2/6, antériorité 0), est une dynamique géographique
  QV3 que la règle sous-pondère face à l'antériorité : **angle mort typé** — la doctrine
  « signal » privilégie l'anticipation, une observation de marché établie mais portante passe
  sous le seuil. L'item est **revenu dans la file humaine** (415 items, était 414), sans
  effacement.
- **Énoncé du bilan reformulé** (`v_bilan_filtrage`, décision d'étudiant) : l'ancien texte
  exigeait une révision de règle dès le premier faux négatif — écrit en attendant zéro. Nouveau :
  taux mesuré, item restitué, règle maintenue sous une **tolérance de 5 % fixée a posteriori, après
  le premier audit** ; au-delà, « la règle doit être révisée ». Le caractère a posteriori du seuil
  est dit dans la vue elle-même et ici. Vérifié servi par `/veille/sante`.
- **Constat pour le rapport** : 352 items écartés de la file « signal » ont néanmoins une lecture
  événementielle (ex. item 175 = événement 93 validé en B3). C'est le fonctionnement voulu des
  deux doctrines (le filtrage porte sur la file humaine de signaux, l'extraction lit tout item de
  pertinence ≥ 1) — à écrire pour prévenir le reproche d'incohérence. Le flux ferroviaire
  (CPV 34630000) n'a pas de secteur rattaché : 5 de ses avis dans l'échantillon, tous hors champ.
- **`db/` à régénérer** au prochain gel : `v_bilan_filtrage` reformulée, colonnes `motif`
  (B1, B2, B3), ligne `acea_incitations`.

**Liste B close.** Quatre taux mesurés une fois, jamais auparavant : commentaires 1 rejet / 5
(puis 82 validé) ; lectures 6 / 13 ; événements 6 / 30 (20 %) ; filtrage 1 / 40 (2,5 %). Aucun
de ces chiffres ne se cite depuis un texte : `commentaries.status`,
`lectures_transversales.statut`, `flux_evenements.statut`, `v_bilan_filtrage`.

## 02.09.2026 (suite 14) — Revue de code de l'application : douze constats, corrections

Revue demandée après la clôture des listes A et B (« code review » de `dashboard-app/`). La revue
déléguée a été coupée par la limite de session ; ses douze candidats ont été **vérifiés un à un
sur le code et sur la charge `/veille/donnees` du jour**, puis corrigés à la demande de
l'étudiant (« toutes les corrections, en étant certain que l'application ne casse pas »).
Aucune donnée ni vue de base touchée ; commit unique. Les comptes ci-dessous sont lus sur les
textes rendus avant/après (`verification/rendu.jsx`, `TEXTE=…`) et sur les captures.

**Corrigé, visible à l'écran aujourd'hui :**

1. **Troisième copie de la règle des franchissements** (`Accueil.jsx`) : les vignettes de
   l'accueil comptaient les alertes `diffusable` sans le seuil de poids — aérospatial **3 à
   l'accueil, 2 dans la navigation** (S3 Allemagne, 0,47 % du flux). L'accueil lit
   `alertesSignificatives`, comme la navigation et les pages secteur ; sa liste « À examiner »
   aussi (« zones pesantes concernées »). Après : 2/2/5/2 partout. Note datée ajoutée sous le
   commentaire du 23.08 dans `api.jsx`, sans le réécrire.
2. **Période de référence des paniers** (`Secteur.jsx`) : la période commune était exigée de
   toutes les zones, marginales comprises — un micro-déclarant en retard figeait le panier :
   **A3 lu au titre de 2023, M3 de 2021**. Règle : exigée des zones **pesantes** (≥ 1 % de la
   somme des dernières valeurs, même seuil que les mouvements) ; une grandeur non additive n'a
   pas de panier, elle se lit à la période la plus récente. Après : A3 → **2025** (3 marginales
   sans valeur, dites), M3 → **2023** (Ukraine sans valeur, dite), M1/H3 restent à 2024 (la Chine,
   pesante, n'a pas déclaré 2025 — c'est le bon comportement). Deux notes distinctes : les
   pesantes en retard qui justifient le recul, les zones absentes de la période retenue.
3. **Franchissement non strict** (`Secteur.jsx`) : la vue sert « franchi (variation de periode,
   faute de glissement) » pour 42 métriques, dont **A2/EU27** listée en tête de page comme
   mouvement mais carte muette (`=== "franchi"`). Test préfixé comme le cas « sous », et la
   phrase cite la variation effectivement jugée (« depuis le point précédent (+20,2 %), faute de
   glissement annuel »).
4. **Doublons** dans le détail des mouvements : `retenues` sont des copies (`syntheseZones`),
   `includes` par référence ne les excluait jamais → comparaison par `geo`.
5. **Lien QV3 circulaire** : « dynamique géographique (QV3) ↗ » renvoyait vers `/qv/<secteur>`,
   c'est-à-dire la page courante rechargée en tête. Il descend vers la carte de l'indicateur
   (`id="ind-<ID>"`, « carte A1 ci-dessous ↓ »). La route `/qv/:code` est conservée (redirection
   inoffensive). `useNavigate` retiré de `Secteur.jsx`.

**Corrigé, latent (ne se voyait pas sur les données du jour) :**

6. **Rechargement en échec silencieux** : un échec après une charge réussie laissait les
   anciennes données sans le dire, et un point secondaire en échec repassait à `null` (écran
   vidé sans mot). `api.jsx` conserve la valeur précédente et consigne l'erreur ;
   `App.jsx` affiche un bandeau `.bandeau-echec` (« Le rechargement a échoué : … — données
   affichées : celles chargées à HH:MM », points secondaires nommés, bouton Réessayer).
7. **Points de lecture et code mort** : l'en-tête annonçait quatre points, le code en lisait
   sept, dont quatre sans consommateur (`/signaux`, `/opportunites`, `/attribution`,
   `/geographie`). Trois restent lus (`/donnees`, `/sante`, `/actions`) ; les quatre autres
   restent **servis** par l'API (DEPLOIEMENT § 6 le dit). Retirés : `MentionTriage`,
   `signatureCommentaire` (`api.jsx`) et huit sections de `phrases.jsx` sans appelant depuis la
   refonte de l'accueil du 28.08 (état du marché, direction longue, variation, brief,
   mouvement, article, écart/nouveauté, nature du fait) — note datée en tête, numérotation des
   sections restantes conservée. `verification/rendu.jsx` adapté (trois points).
8. **Instance ECharts** (`Chart.jsx`) : `init`/`dispose` à chaque rendu → instance persistante
   par `useInstance` (ResizeObserver, `dispose` au démontage), `setOption` avec
   `replaceMerge: ["series"]`, légende toujours déclarée (sinon une ancienne légende survivait à
   la fusion). Vérifié aux captures : courbes, légende, zoom, treemap rendent.
9. **Valeurs nulles** dans les séries : `Math.round(null * 100)` donnait 0 (un trou devenait un
   zéro tracé) → `null` conservé.
10. **Gabarits sans zone de référence** : `metrDe(D, id, null)` ne trouvait jamais rien (8
    indicateurs sans `geo_reference`). `metrReference` (api.jsx) accepte une métrique **unique** ;
    plusieurs métriques sans référence restent un échec silencieux — jamais une zone au hasard
    (UI-1). Appliqué à `resoudreGabarit` et à la lecture calculée.
11. **Réserve « aucun signal d'avance »** sur un marché sans série : aurait écrit « les zéro
    séries qui portent ce score » → marché sauté (`Fiabilite.jsx`).

**Documenté seulement (conception, pas défaut) :**

12. **Adresse de l'API compilée** (`VITE_API_BASE` sinon `localhost:5678`) : application locale
    par conception, compose sur `127.0.0.1`. `DEPLOIEMENT.md` § 3.1 le dit et donne les deux voies
    pour un serveur (variable au build ; `proxy_pass` nginx vers `n8n:5678`) — **documentées,
    pas démontrées**.

**Ce qui a cassé pendant la revue, et ce qui l'a attrapé.** En retirant `misAJour` de la
destructuration de la coquille (n° 6), j'ai laissé le pied de page l'utiliser : `npm run build`
passait, **le harnais `rendu.jsx` passait (17 écrans)**, et l'application était **blanche dans le
navigateur** (`ReferenceError: misAJour is not defined`). Le harnais ne rend que les pages, pas la
coquille ni ECharts. Correctif immédiat, et **nouvelle passe `verification/console.mjs`**
(Puppeteer : erreurs de page, de console, de requête, écran vide sur les onze routes), intégrée
à `executer.sh` en troisième passe — elle suppose l'application servie sur 8080. Résultat :
« Aucune erreur de navigateur sur les onze écrans. » À dire dans le rapport : c'est exactement
la faute que le seul rendu serveur ne voit pas.

**Preuves** : `bash verification/executer.sh` (hooks, classes, 17 rendus, sonde navigateur, tout
vert) ; `npm run build` (bundle `index-*.js`, servi par nginx, vérifié par `curl`) ; captures
`annexes/6_captures/2026-09-02_revue/` (11 écrans, pleine page — un premier jeu à 900 px de haut
était le symptôme de l'écran blanc, écrasé). Non couvert : le bandeau de rechargement (n° 6) n'a
pas été vu à l'écran — il faudrait couper n8n pendant un rechargement ; le code est relu, pas
démontré.

## 02.09.2026 (suite 15) — Workflow d'erreur commun : les runs en échec se ferment seuls

**Constat de départ** (WF-4/DOC-16 de la revue, et faiblesse n° 4 du bloc « limites
d'architecture ») : quand un workflow plante après avoir ouvert son run, la ligne `runs` restait
en `en_cours`, sans `closed_at` — l'écran des exécutions montrait un run « en cours » pour toujours
et la statistique ok/échec/partiel se biaisait. Aucun des 21 workflows ne déclarait
`settings.errorWorkflow`.

**Ce qui est fait.**

- `n8n_workflows/erreur_commune.json` (id `erreurCommuneV1`, « Veille - Erreur commune (clôture
  des runs en échec) ») : déclencheur d'erreur natif → un `UPDATE runs SET status='echec',
  closed_at=now(), note = note || ' — ÉCHEC (clôture automatique) : …' WHERE status='en_cours'
  AND closed_at IS NULL`. La note reçoit le nom du workflow fautif, le nœud, l'identifiant
  d'exécution n8n et le message (600 caractères au plus). **Hypothèse dite dans le fichier** : une
  seule exécution à la fois — le `UPDATE` clôt *tous* les runs ouverts, pas celui de l'exécution
  fautive (la table `runs` n'a pas de colonne reliant un run à une exécution n8n). Un échec
  survenu avant l'ouverture du run ne touche aucune ligne.
- Les 21 autres fichiers reçoivent `settings.errorWorkflow: "erreurCommuneV1"` (diff limité au
  réglage, formatage conservé). Tous réimportés, `apiRestitutionV4` et `erreurCommuneV1`
  publiés, n8n redémarré : 7 points d'API en 200, sonde navigateur verte sur les onze écrans.

**Ce qui a coincé, et pourquoi.** Premier essai par `n8n execute --id` (CLI) : exécution 2654 en
`error`, run 215 resté `en_cours`. Deux causes, établies dans le code de n8n 2.20.7
(`workflows/workflow-execution.service.js`, l. 252) : **le workflow d'erreur doit être publié**
(« is not active and cannot be executed »), ce que `import:workflow` ne fait pas ; et le
déclenchement est asynchrone, le processus CLI sort avant. Second essai dans le serveur, par un
banc d'essai à webhook (`bancEssaiErreur01` : ouvre un run, puis un nœud Code lève une erreur) :
exécution 2656 en `error`, **run 216 clos en `echec` avec la note complète** (workflow, nœud
« Échouer », exécution 2656, message). Le run 215 a été clos par la même exécution — c'est
l'hypothèse « tous les runs ouverts » à l'œuvre ; sa note porte une précision manuelle qui le dit.
Après coup : `runs` ne compte plus aucun `en_cours` ; restent les runs 79 et 80, anciens, à
`closed_at` nul avec un statut final — laissés tels quels, ce sont des faits d'époque.

**Règle de procédure, ajoutée à celle du 02.09** : après tout réimport, publier *deux* workflows —
`apiRestitutionV4` et `erreurCommuneV1` — avant le redémarrage ; un workflow d'erreur importé
mais non publié ne tourne pas, silencieusement.

**Reste à faire dans l'interface n8n** (pas de commande CLI de suppression) : supprimer
`bancEssaiErreur01` — désactivé par CLI (webhook en 404), mais encore présent en base n8n. Il
n'est pas dans `n8n_workflows/`.

**Non démontré** : le mécanisme sur un vrai workflow de collecte (seul le banc l'a exercé) ; le
comportement si deux exécutions se chevauchent (hypothèse énoncée, pas testée).

## 02.09.2026 (suite 16) — Harnais de la base : treize invariants et six faits figés

**Pourquoi.** Le harnais de l'application relit les écrans ; rien ne relisait la base, alors que
c'est elle que le rapport cite — et le décompte d'indicateurs a dérivé trois fois dans le texte
(règle CLAUDE.md : citer depuis `v_bilan_referentiel`). `verification/base.sh` (lecture seule,
`docker compose exec db`) rend ce contrôle exécutable.

**Ce qu'il contrôle.**

1. *Invariants structurels, attendu zéro* : indicateur certifié sans question de veille, sans
   source, dont la `geo_reference` n'a aucune métrique dans `v_metriques`, ou hard en vitrine
   sans liaison active ; liaison ou instanciation vers un code de question inconnu ; observation
   sans indicateur, sans run, à valeur nulle, ou en doublon (indicateur, run, période, zone) ;
   run `en_cours` depuis plus d'une heure (ce que le workflow d'erreur commun de la suite 15
   doit empêcher) ; run clos sans `closed_at` hors 79 et 80 (faits d'époque, exclus par
   commentaire daté) ; chaque vue du schéma se laisse lire (`SELECT … LIMIT 1` sur les 44).
2. *Faits cités par le rapport*, comparés à `verification/base_attendu.txt`, relevé **figé par
   requête** le 02.09.2026 : `v_bilan_referentiel` total `53/41/38/3/10/40/13` et par secteur ;
   6 questions de veille ; 21 instanciations sectorielles ; 27 tables / 44 vues / 44 fonctions ;
   filtrage `1415/964/415/40/1`. `--figer` régénère le relevé (à dater ici).
3. *Pour information, non contrôlé* : runs par statut, observations, statuts de validation.

**Ce qui n'est pas un invariant, et que j'ai écarté après l'avoir testé** : 8 indicateurs
certifiés sans seuil d'alerte (M8, T5, T8, A11, M7, S7, T10, T4) ; 6 certifiés hors vitrine et
5 en vitrine à confirmer ; `items_collectes ≠ items_filtres + file_humaine` dans
`v_bilan_filtrage` (36 items ni filtrés ni en file) ; 45 runs `ok` sans observation (flux et
textes). Ce sont des états, pas des règles — à relire au moment de figer, pas à asserter.

**Résultat ce soir** : 13 invariants à zéro, 6 faits conformes, code de sortie 0 ; un écart
provoqué (relevé altéré à la main) sort bien en `KO … attendu 7, relevé 6`, code 1. Défaut
attrapé en route : `docker compose exec` lit l'entrée standard et vidait le fichier lu par la
boucle `read` — relevé calculé une fois, hors boucle, commentaire dans le script.

**Tension signalée** : CLAUDE.md (état au 22.08) dit encore « 30 indicateurs, 26 certifiés » ; la
base et la passation disent 53 / 41 depuis la famille d'intensité et le socle transversal (suite
9). Le relevé figé fait foi ; CLAUDE.md est à mettre à jour côté Cowork.
