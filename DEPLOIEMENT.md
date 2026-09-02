# Déploiement du dispositif — séquence complète

*Écrit le 25.08.2026, après le portage intégral de la collecte vers l'orchestrateur. Révisé le
02.09.2026 (correction A2 du tour « jury ») : prérequis complétés, identifiants alignés sur
l'instance, valeurs attendues du § 6 recalculées par requête.*

**Ce document répond à une seule question : que faut-il faire pour que, dans trois mois, tous les
indicateurs se mettent à jour ?** Réponse courte — déployer le compose, rejouer les migrations,
importer les workflows, les lancer dans l'ordre. Aucun script n'intervient dans la collecte.

---

## 1. Prérequis

Ce qu'il faut sur le poste : **Docker** avec le greffon compose, et **Node.js 24** (v24.19.0 sur le
poste de développement ; `dashboard-app/.nvmrc` et le champ `engines` de `package.json` le disent
depuis le 02.09.2026) pour construire l'interface (§ 3). Les quatre images du compose sont
épinglées par empreinte dans `docker-compose.yml` (PostgreSQL 16.14, n8n 2.20.7-exp.0 sur
Node 24.14.1, nginx 1.27.5, Adminer 6.0.1) : un `docker compose pull` redonne exactement ce
qui a tourné. Rien d'autre n'est installé hors conteneur.

### 1.1 Le `.env` du compose — dans `prototype/`, jamais versionné

```bash
cd prototype
cp .env.example .env         # puis renseigner POSTGRES_PASSWORD et CLES_API_FICHIER
mkdir -p data/staging        # zone de dépôt brut montée sur /data (exclue du dépôt)
```

`.env` ne porte que **deux choses** : le mot de passe de la base (`POSTGRES_PASSWORD`, exigé par le
compose, sans valeur par défaut) et le **chemin** du fichier de clés (`CLES_API_FICHIER`). Le mot
de passe n'est pas dans le fichier de clés : il est lu par le service `db`, et ressaisi une fois
dans la *credential* Postgres de n8n (§ 1.3).

### 1.2 Le fichier de clés — HORS du dossier du travail

```bash
cat ~/.config/veille_tb/cles.env     # permissions 600 ; le dossier du TB part chaque jour vers le Drive
```

Le compose le monte en `env_file` du service n8n. Les workflows lisent **neuf** variables
d'environnement, toutes optionnelles au sens strict — un workflow dont la clé manque échoue à
l'appel, il ne se dégrade pas en silence :

| Variable | Lue par | Nécessaire pour |
|---|---|---|
| `GOOGLE_API_KEY`, `MODELE_GOOGLE` | triage, lecture décisionnelle, extraction composite, couche 0 | la chaîne quotidienne (§ 5, étapes 6-7) |
| `ANTHROPIC_API_KEY`, `MODELE_ANTHROPIC` | commentaire exécutif, lecture transversale, extraction composite, couche 0 | la chaîne quotidienne (étape 9) |
| `OPENAI_API_KEY`, `MODELE_OPENAI` | extraction composite (A1, A2, CP), signal qualitatif, couche 0 | le consensus multi-modèles seulement |
| `PERPLEXITY_API_KEY`, `MODELE_PERPLEXITY` | couche 0 (`decouverte_sources_multi_ia`) | la découverte de sources seulement |
| `TRIAGE_DOCTRINE` | triage (`triage_ia_flux`) | facultative : `evenement` ou, par défaut, `signal` |

Valeurs de modèle en service à la date de révision : préfixe `gemini` pour Google ; les autres
sont dans le fichier, pas ici. **Aucune clé n'est dans le dépôt** ; `.gitignore` exclut `.env`,
`data/` et les sauvegardes n8n (`*.tar.gz`, qui contiennent la clé de chiffrement des
*credentials*).

### 1.3 Les deux *credentials* n8n — à créer une fois, avec leur identifiant

Les fichiers de workflows référencent deux *credentials* **par identifiant**. Sans elles, l'import
passe mais chaque nœud Postgres ou Comtrade échoue à l'exécution :

| Identifiant dans les fichiers | Nom | Type | Fichiers | Contenu |
|---|---|---|---|---|
| `QdVRYX9pjTj9C8G3` | `postgres veille` | Postgres | 23 workflows | hôte `db`, port 5432, base/utilisateur/mot de passe du `.env` |
| `comtradeKeyCred1` | `comtrade subscription` | *Header Auth* | `collecte_generique` (A4, H1, H3, M1, S6) | en-tête `Ocp-Apim-Subscription-Key`, clé gratuite du portail UN Comtrade |

Deux voies. **Voie testée sur l'instance en service** : créer les deux *credentials* dans
l'interface n8n (`http://127.0.0.1:5678`), relever leurs identifiants dans l'URL, puis les
substituer dans les fichiers avant l'import (`sed -i 's/QdVRYX9pjTj9C8G3/<id>/' n8n_workflows/*.json`).
**Voie non testée sur instance neuve** : `n8n import:credentials --input=<fichier>` accepte un
JSON portant `id`, `name`, `type` et `data` en clair, qu'il chiffre à l'import — elle
préserverait les identifiants tels quels ; elle n'a pas été rejouée ici, faute d'instance vierge.

```bash
docker compose up -d          # base, orchestrateur, service statique de restitution, adminer
```

## 2. Schéma et référentiel — rien à lancer

**Le `docker compose up -d` de l'étape précédente a déjà tout fait.** Le service de base monte
`./db` sur `/docker-entrypoint-initdb.d` : au tout premier démarrage, sur un volume vide,
PostgreSQL exécute lui-même les deux fichiers, dans l'ordre de leur nom.

| Fichier | Ce qu'il pose |
|---|---|
| `db/01_socle.sql` | 31 tables (27 en `public`, 4 en `sandbox`), 44 vues, 4 déclencheurs, 8 fonctions propres (les 36 autres du schéma sont celles de l'extension `pgcrypto`), les contraintes métier et leurs commentaires |
| `db/02_referentiel.sql` | 5 secteurs, 6 questions de veille + 21 instanciations, 28 sources, 51 indicateurs, 120 liaisons dont 103 actives, 24 flux avec leur statut, 1 règle de filtrage du triage |

Une base neuve repart donc dans l'**état qualifié** — pas dans un état par défaut qu'il faudrait
requalifier source par source. Elle est en revanche **vide d'observations**, et c'est voulu :
ce sont les collecteurs de l'étape 4 qui la remplissent.

> **Vérifié, et pas seulement affirmé** — le 25.08.2026, puis à nouveau le **01.09.2026** après
> reconsolidation des deux fichiers (ils avaient dérivé de la base : 49 indicateurs contre 53,
> 41 vues contre 44) : base neuve créée, les deux fichiers appliqués, comparaison faite avec la
> base en service — mêmes tables, vues, déclencheurs, fonctions, contraintes, colonnes et
> commentaires ; référentiel identique **par empreinte** (md5 des lignes d'indicateurs, de
> liaisons, de flux et de questions). Seul écart : 51 indicateurs contre 53, les deux manquants
> étant T12 et T13, abandonnés le 24.08 (motif dans l'en-tête de `db/02_referentiel.sql`).
> Reconsolidé une troisième fois le **01.09.2026 (soir)** après la migration d'éligibilité des
> sources à la lecture événementielle (`flux_sources.lecture_evenementielle`, vue
> `v_evenements_mois`) : même procédure, mêmes empreintes.
> **Règle** : à chaque gel, reconsolider — un socle qui ne suit pas la base n'est plus une
> reproductibilité, c'est une affirmation.

### Ce que devient `migrations/`

Le dossier reste au dépôt comme **journal du travail** : il porte le raisonnement, les
corrections et leurs motifs, et c'est à ce titre qu'il est cité au rapport. **Il n'est plus la
voie de construction de la base, et ne doit pas être rejoué sur une base neuve.**

Le rejeu a été essayé le 25.08 avant d'écrire ceci : sur 78 migrations, 69 passent et 9 échouent
— dépendances circulaires entre migrations d'un même jour (une vue référence une colonne ajoutée
par une migration postérieure), migrations de données qui présupposent des observations
collectées, migrations rendues caduques par le socle lui-même. La base ne tenait donc que par
l'état accumulé dans le conteneur en service : elle n'était **pas** reconstructible depuis le
dépôt. Le socle consolidé rétablit cette reproductibilité, qui est la condition de
l'auditabilité que ce travail revendique.

Toute migration **postérieure au 25.08** s'applique normalement par-dessus le socle, à la main.

## 3. Construire l'interface de restitution

**Étape indispensable, et facile à oublier** : le service `dashboard` sert `dashboard-app/dist`,
un dossier **exclu du dépôt** (c'est un produit de compilation, pas une source). Sans cette
étape, nginx répond 200 sur un dossier vide et l'application paraît cassée sans l'être.

```bash
cd dashboard-app
npm ci            # installe exactement package-lock.json ; npm install seulement si le verrou est absent
npm run build     # produit dashboard-app/dist, servi tel quel par nginx
cd ..
```

Puis, une fois l'API de restitution active (étape suivante), vérifier que les **sept écrans**
(vue d'ensemble, actions, anticiper, secteur — instancié pour les quatre secteurs et le socle
transversal —, référentiel, exécutions, fiabilité) se rendent réellement — un écran qui plante ne
se voit qu'en l'ouvrant, et on n'ouvre que celui qu'on vient d'écrire :

```bash
bash dashboard-app/verification/executer.sh
```

Il rend chaque écran hors navigateur avec les données réelles de l'API (dix-sept rendus :
l'écran secteur compte cinq fois, l'écran fiabilité une fois par onglet) et sort en erreur si
l'un d'eux lève une exception.

## 4. Importer les workflows

```bash
for f in n8n_workflows/*.json; do            # la racine seulement : archive/ est exclu par construction
  docker exec veille_n8n n8n import:workflow --input="/workflows/$(basename "$f")"
done                                          # ./n8n_workflows est monté en lecture seule sur /workflows
docker exec veille_n8n n8n publish:workflow --id=apiRestitutionV4
docker compose restart n8n        # INDISPENSABLE : sans redémarrage, les webhooks
                                  # ne sont pas enregistrés et l'API répond 404
```

Chaque fichier porte son **identifiant épinglé** : l'import met à jour en place et ne crée pas de
copie. Sans cela, l'instance accumule des doublons et rien ne dit lequel s'exécute. Cette
promesse n'était tenue qu'en partie jusqu'au 02.09.2026 : cinq fichiers (`extraction_composite_A2`,
`extraction_composite_A1_ccfa`, `extraction_composite_CP`, `extraction_signal_qualitatif`,
`collecte_a5_eurostat_pilote`) portaient un identifiant différent de celui de l'instance, si
bien qu'un réimport aurait créé un doublon — ou, pour A2, ne l'a jamais été : la version qui a
produit les runs 51-58 ne correspondait à aucun commit. Elle est archivée telle quelle dans
`n8n_workflows/archive/` (pièce d'audit, hors boucle d'import) ; les cinq identifiants sont
alignés sur l'instance depuis le 02.09 et le réimport a été vérifié (21 workflows, aucun doublon,
A2 identique nœud pour nœud entre le fichier et l'instance).

Les 21 fichiers de la racine s'importent et sont exactement les 21 workflows de l'instance en
service. Cinq états antérieurs jamais importés (`collecte_a5_multi_geo`, `collecte_hard_data`,
`collecte_m2_eurostat`, `extraction_composite_multi_ia`, `scenario_c_agent_autonome`) ont été
déplacés le 02.09.2026 dans `n8n_workflows/archive/squelettes_2026-08-04/` (correction A9 du tour
« jury ») ; le `README` de l'archive dit ce que chacun était et ce qui l'a remplacé.

## 5. Lancer la chaîne, dans cet ordre

L'ordre compte : le triage a besoin des items, la lecture décisionnelle a besoin des avis
enrichis, le commentaire a besoin des indicateurs.

| # | Workflow | Ce qu'il alimente |
|---|---|---|
| 1 | `collecteGeneriqueV2` | les indicateurs à liaison active — API et fichiers plats (le décompte fait foi par `v_bindings_actifs`, pas ici) |
| 2 | `collecteXlsxIndexeV1` | S4, T3 — classeurs derrière une page d'index |
| 3 | `collecteFhV1` | H7, H8, H9 — document tabulaire de la Fédération horlogère |
| 4 | `collecteFluxV1` | `flux_items` — quatre familles de flux |
| 5 | `tedEnrichiV1` | `ted_avis` — quatorze champs par avis |
| 6 | `triageFluxV1` | `flux_triage_ia` — scores de triage |
| 7 | `lectureDecisionV1` | `ted_lecture_ia` — adressabilité et geste proposé |
| 8 | `veilleAceaV1` | `composite_queue` — détection du communiqué ACEA |
| 9 | `commentaireExecV2` | `commentaries` — statut `a_valider` |

```bash
for wf in collecteGeneriqueV2 collecteXlsxIndexeV1 collecteFhV1 collecteFluxV1 \
          tedEnrichiV1 triageFluxV1 lectureDecisionV1 veilleAceaV1 commentaireExecV2; do
  docker exec -e N8N_RUNNERS_TASK_BROKER_PORT=5801 -e N8N_RUNNERS_BROKER_PORT=5801 \
    veille_n8n n8n execute --id "$wf"
done
```

> **Piège connu** : `n8n execute` en ligne de commande échoue sur « Task Broker's port 5679 is
> already in use ». Passer **les deux** variables de port ci-dessus le contourne.

## 6. Vérifier

```sql
-- Aucun run ne doit rester ouvert ni en échec.
SELECT run_id, status, left(note, 90) FROM runs ORDER BY run_id DESC LIMIT 12;

-- Le décompte fait foi ICI, jamais dans un texte.
SELECT * FROM v_bilan_referentiel;

-- Indicateurs certifiés sans aucune liaison active : ils ne collecteront jamais.
-- Au 02.09.2026 (recalculé par cette requête), CINQ sont attendus, et aucun autre :
--   A1  production mondiale de véhicules — source non encore liée
--   A2  composite ACEA — alimenté par `composite_queue`, pas par une liaison (doctrine)
--   H2  exportations horlogères — requalifié composite le 30.08 (lecture du document FH),
--       ses liaisons STATENT (runs 43-161) sont closes
--   H4  brevets horlogers CIB G04 — en attente d'un accès OEB (portail OPS hors service)
--   S1  commandes et livraisons d'avions — requalification en composite à trancher
-- Tout autre indicateur qui apparaît ici est une régression.
SELECT i.indicator_id, i.label FROM indicators i
WHERE i.status = 'certifie'
  AND NOT EXISTS (SELECT 1 FROM v_bindings_actifs b WHERE b.indicator_id = i.indicator_id);

-- Liaisons actives à fenêtre FIGÉE : elles rapporteront toujours la même période.
-- Au 02.09.2026 (recalculé), 31 lignes sont attendues, toutes par construction :
--   A3   15 liaisons (24 à 123) — une par millésime de l'IEA Global EV Data Explorer
--   A11  16 liaisons (124 à 139) — idem, part électrique des ventes, 2010 à 2025
-- Ces éditions portent des années closes et ne bougeront plus ; c'est le millésime
-- suivant qu'il faut AJOUTER, pas ces lignes qu'il faut corriger.
-- Le filtre sur "top" écarte deux faux positifs : M4 (142) et H12 (144) portent
-- `"filter": "top"` (paramètre OFS PX-Web), pas une année figée.
-- Toute autre ligne est une liaison qui a cessé d'avancer sans le dire — c'est
-- exactement le défaut trouvé le 25.08 sur H1, A3, H2 et M4.
SELECT binding_id, indicator_id, left(params::text, 70)
FROM source_bindings
WHERE statut = 'actif' AND params::text !~ '\{\{' AND params::text ~ '"(year|Jahr)"'
  AND params::text !~ '"filter": *"top"'
ORDER BY indicator_id, binding_id;

-- LE CONTRÔLE QUI COMPTE VRAIMENT : la chaîne produit-elle tout ce que la base
-- contient déjà ? Un indicateur dont la chaîne rend une période plus ancienne que
-- ce qui figure au registre a CESSÉ D'AVANCER — fenêtre figée, liaison non
-- qualifiée, ou contrôle qualité qui tronque. Aucun de ces cas ne lève d'incident :
-- c'est ainsi que A5 est resté arrêté à 2020-04 pendant dix jours (§ 12.6).
-- Remplacer 150 par le premier run de la campagne en cours.
WITH tout AS (SELECT indicator_id, max(period) p FROM indicator_values GROUP BY 1),
     chaine AS (SELECT indicator_id, max(period) p FROM indicator_values WHERE run_id >= 150 GROUP BY 1)
SELECT t.indicator_id, t.p AS jamais_atteint, coalesce(c.p, '—') AS par_la_chaine
FROM tout t LEFT JOIN chaine c USING (indicator_id)
WHERE c.indicator_id IS NULL OR c.p < t.p
ORDER BY 1;
-- Attendu au 02.09.2026 (campagne depuis le run 150) : A2 (composite, alimenté par
-- composite_queue) et T12, T13 (statut `restreint`, abandonnés le 24.08, observations
-- conservées). Toute autre ligne est une régression à traiter.

-- Et le décompte de la grille, qui fait foi. `en_grille` = indicateurs en vitrine
-- (suivis et affichés, 38 au 02.09), ce qui n'est PAS certifiés + à confirmer (41 + 10) ;
-- `ecartes` = indicateurs restés au référentiel mais hors vitrine (15).
SELECT * FROM v_bilan_referentiel;
```

```bash
for e in sante donnees actions signaux opportunites attribution geographie; do
  printf "%-14s " $e
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:5678/webhook/veille/$e"
done
```

Les sept doivent répondre 200. Puis la restitution : **http://localhost:8080**

---

## Ce qui reste un acte HUMAIN, et le restera

L'automatisation s'arrête là où le jugement commence. Quatre actes ne sont pas automatisables, et
ce n'est pas une lacune du dispositif mais sa doctrine (§ 10.4).

1. **La qualification d'une source.** Aucune liaison ne passe au statut `actif` sans que ses
   paramètres aient été vus en réponse réelle. La contrainte `chk_binding_verifie` l'impose en
   base, et les collecteurs lisent désormais ce statut — un flux non qualifié n'est pas collecté,
   et le workflow dit lequel et pourquoi.
2. **La validation des commentaires.** Ils sortent au statut `a_valider` ; depuis le 31.08.2026
   l'interface les sert **avec leur statut** et badge en ambre ce qu'aucun humain n'a relu — la
   règle antérieure « seuls les validés sont servis » n'est plus ce que l'API fait. Le rejet est
   un événement de l'historique, pas un effacement.
3. **L'examen des items de flux.** Le triage assisté par IA ordonne ; il ne décide pas. La
   promotion en signal est un acte nominatif et daté.
4. **La validation des extractions composites.** La file `composite_queue` est alimentée par la
   détection ; l'extraction et la validation restent conditionnées à la chaîne multi-modèles et à
   la relecture humaine.

## Ce qui n'est PAS de la collecte, et reste en script

Trois familles de fichiers Python subsistent au dépôt. **Aucune n'alimente le tableau de bord**,
et aucune n'a à être exécutée pour que les indicateurs se mettent à jour :

- `exports/` — génération des annexes et du classeur, à la demande ;
- `scenario_c/` — artefact de laboratoire de la confrontation B/C (§ 11.9), qui écrit dans un
  schéma séparé ;
- `etage2/sensibilite_profil.py` — mesure de sensibilité du profil métier (§ 11.8), exécutée une
  fois et dont le résultat est publié.
