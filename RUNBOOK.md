# Runbook — mise en service et tranche verticale

Document d'exécution. À dérouler dans un terminal, depuis `prototype/`. Tout ce qui est écrit ici a été **conçu mais pas exécuté** : chaque étape comporte un critère de réussite observable, et ce qui casse est à consigner (§ « Journal d'exécution » en fin de document) — c'est la matière du chapitre 11.

## 0. Prérequis

Docker et n8n déjà installés. Vérifier :

```bash
docker --version && docker compose version
```

## 1. Démarrer l'environnement

```bash
cd prototype
cp .env.example .env          # puis remplacer POSTGRES_PASSWORD
mkdir -p data/staging
docker compose up -d
docker compose ps             # les deux services doivent être "running", db "healthy"
```

Les trois scripts de `db/` sont joués automatiquement au **premier** démarrage seulement, dans l'ordre `01`, `02`, `03`.

**Critère de réussite.**

```bash
docker compose exec db psql -U veille -d veille -c "SELECT * FROM v_bilan_referentiel;"
```

Attendu : 26 indicateurs au total, dont 22 certifiés (21 *hard data*, 1 composite) et 4 « à confirmer ». **Ce résultat est la source de vérité du décompte** — le rapport en donne aujourd'hui trois valeurs contradictoires (I-6). Reporter ce que la requête retourne, pas l'inverse.

## 2. Vérifier que la base fait respecter la théorie

C'est le point le plus important de la mise en service, et il se teste en quelques secondes. Chacune de ces requêtes **doit échouer**. Si l'une passe, la contrainte correspondante est mal écrite et la réserve R-1 de l'évaluation critique reste entière.

```bash
docker compose exec db psql -U veille -d veille
```

```sql
-- Ouvrir un run de travail
INSERT INTO runs (trigger_type) VALUES ('manual') RETURNING run_id;   -- notez le run_id, ci-dessous : 1

-- (a) Une extraction par IA prétendant à la fiabilité d'une source
--     → doit violer chk_hierarchie_controle
INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
VALUES ('A5', 1, '2025-01', 'EU27_2020', 100, 'ia_extraction', 'valide_source', '/data/test');

-- (b) Un consensus partiel présenté comme un consensus
--     → doit violer chk_consensus_unanime
INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, consensus_score, raw_ref)
VALUES ('A2', 1, '2025-01', 'EU27_2020', 100, 'ia_extraction', 'pre_valide_consensus', 0.66, '/data/test');

-- (c) Une validation humaine sans validateur nommé
--     → doit violer chk_validation_humaine_tracee
INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
VALUES ('A2', 1, '2025-02', 'EU27_2020', 100, 'ia_extraction', 'valide_humain', '/data/test');

-- (d) Une valeur écrasée
--     → doit déclencher trg_registre_ajout_seul
INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
VALUES ('A5', 1, '2025-03', 'EU27_2020', 100, 'etl', 'valide_source', '/data/test');
UPDATE indicator_values SET value = 999 WHERE indicator_id = 'A5' AND period = '2025-03';

-- (e) Un indicateur sans question de veille
--     → doit déclencher trg_indicateur_sans_question à la validation
BEGIN;
INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency, unit, status)
VALUES ('X9', 'automobile', 'Indicateur sans question', 'eurostat', 'hard', 'mensuelle', 'indice', 'certifie');
COMMIT;

-- Nettoyage
DELETE FROM indicator_values WHERE raw_ref = '/data/test';   -- échouera aussi : c'est normal, le registre est en ajout seul.
-- Pour repartir propre : docker compose down -v puis up -d
```

Les cinq messages d'erreur sont à **capturer et conserver** : ce sont les preuves à produire au chapitre 11, et de bons candidats pour l'annexe 5. Une capture de `ERROR: new row for relation "indicator_values" violates check constraint "chk_hierarchie_controle"` démontre en une ligne ce que trois paragraphes affirment.

## 3. Connecter n8n à la base

Ouvrir http://localhost:5678, créer le compte local, puis **Credentials → New → Postgres** :

| Champ | Valeur |
|---|---|
| Host | `db` |
| Database | `veille` |
| User | `veille` |
| Password | celui du `.env` |
| Port | `5432` |

`db` et non `localhost` : les conteneurs se joignent par leur nom de service sur le réseau Docker.

**Critère de réussite** : le bouton « Test connection » renvoie un succès.

## 4. Importer et exécuter le pilote

Importer `n8n_workflows/collecte_a5_eurostat_pilote.json` (Workflows → Import from File), puis sélectionner la credential Postgres sur les trois nœuds concernés — l'import ne la rattache pas automatiquement.

Avant d'exécuter, **vérifier la requête Eurostat**, qui est l'inconnue principale de cette étape :

```bash
curl -s "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/sts_inpr_m?format=JSON&nace_r2=C29&unit=I21&s_adj=SCA&geo=EU27_2020&sinceTimePeriod=2023-01" | head -c 2000
```

Le jeu de données, la nomenclature, l'unité et le code géographique ont été retenus par raisonnement, **pas par test** : Eurostat renomme périodiquement ses jeux de données et ses codes d'unité. Si la réponse est une erreur ou un objet vide, corriger les paramètres du nœud à partir de la table réelle (l'explorateur Eurostat donne l'URL de l'API pour toute sélection). Consigner la correction : un écart entre la spécification et la réalité de la source est exactement le type d'enseignement que le chapitre 11 doit rapporter.

Exécuter ensuite le workflow manuellement (« Test workflow »).

**Critères de réussite.**

```sql
SELECT * FROM v_sante_des_runs LIMIT 3;
SELECT indicator_id, period, geo, value, validation_status, raw_ref
FROM v_current WHERE indicator_id = 'A5' ORDER BY period;
```

Attendu : un run au statut `ok` avec sa note de bilan, **environ 41 observations** mensuelles depuis 2023-01 (relevé du 06.08.2026 : 42 périodes annoncées, 41 valeurs publiées), toutes en `valide_source`, chacune portant sa référence de dépôt brut. Et le fichier correspondant présent dans `data/staging/`.

## 5. Démontrer l'outil vivant

Ré-exécuter le même workflow. Un second run est créé ; aucune valeur n'est écrasée.

```sql
-- Toutes les périodes comparées entre les deux derniers runs (écart nul inclus)
SELECT * FROM v_ecart_entre_runs WHERE indicator_id = 'A5';

-- Les seules révisions effectives
SELECT * FROM v_ecart_entre_runs WHERE indicator_id = 'A5' AND ecart_pct <> 0;
```

**Correction du 06.08.2026** : la première requête portait `ecart_pct IS NOT NULL`, filtre inopérant — deux valeurs identiques produisent un écart de `0.00`, non `NULL`. Le critère de révision est `ecart_pct <> 0`.

La première requête doit retourner autant de lignes que de périodes appariées : elle démontre que la vue apparie correctement deux runs. La seconde est vide tant qu'aucune révision n'est survenue — c'est le cas normal à quelques minutes d'intervalle, et cela ne remet rien en cause. Des lignes non vides signalent une révision de la donnée à la source, ce qui est en soi une information de veille qu'un dispositif écrasant ses valeurs perdrait. **C'est ici que « l'outil vivant » cesse d'être une intention pour devenir une propriété observable** : la formulation du § 11.2 peut alors passer au présent.

## 6. Enchaîner sur le composite (A2, ACEA)

Une fois la chaîne hard data démontrée, adapter `extraction_composite_multi_ia.json` :

1. Remplacer les appels `http://loader:8080/...` par des nœuds Postgres (`INSERT INTO indicator_values` pour le consensus unanime, `INSERT INTO validation_queue` pour le désaccord).
2. Cibler A2 : communiqué mensuel ACEA en PDF, extraction des immatriculations par pays.
3. Vérifier que le chemin « désaccord » fonctionne — au besoin en dégradant volontairement le prompt d'un des modèles. **Un pipeline de validation dont on n'a jamais vu la branche d'exception se déclencher n'est pas démontré.**

Métriques à relever pour le rapport : taux de consensus unanime, taux de correction humaine (`v_taux_correction_humaine`), temps de traitement d'un item en file.

## 7. Journal d'exécution

À tenir au fil de l'eau — c'est la matière première du chapitre 11 et de la discussion en soutenance.

| Date | Étape | Ce qui était prévu | Ce qui s'est passé | Correction apportée |
|---|---|---|---|---|
| 06.08.2026 | 0 — Prérequis | Docker et Compose disponibles | Docker 29.7.1, Compose v5.1.4 | — |
| 06.08.2026 | 1 — Démarrage | Deux services actifs, `db` *healthy*, trois scripts SQL joués au premier démarrage | Conforme. Images tirées, volumes créés, `db` *healthy* en ~7 s. Deux avertissements à l'initialisation, tous deux propres à l'image officielle `postgres:16-alpine` et sans effet ici : absence de locales système (aucun tri linguistique dans le schéma) et authentification `trust` pour les connexions locales **internes au conteneur** (port lié à `127.0.0.1`) | Aucune. Le `trust` local est à mentionner comme point de durcissement en cas d'industrialisation (limites du rapport) |
| 06.08.2026 | 2 — Contraintes | Cinq requêtes illicites refusées par la base, une requête licite acceptée | **Conforme sur les six contrôles.** (a) `chk_hierarchie_controle`, (b) `chk_consensus_unanime`, (c) `chk_validation_humaine_tracee`, (d) `trg_registre_ajout_seul` sur UPDATE, (e) `trg_indicateur_sans_question` **au COMMIT** (la contrainte différée se comporte comme spécifié), (f) `trg_registre_ajout_seul` sur DELETE. L'insertion licite (ETL + `valide_source`) passe. État final : une seule ligne au registre, `X9` non créé | Aucune correction fonctionnelle. **Défaut de forme corrigé** : en script SQL unique redirigé vers un fichier, `stdout` (libellés) et `stderr` (erreurs) s'entrelacent et les erreurs apparaissent décalées d'une section — contenu exact, ordre trompeur. Ajout de `tests/run_tests_contraintes.sh`, qui exécute chaque test par un appel `psql` distinct et garantit l'ordre. C'est cette sortie qui constitue la pièce de l'annexe 5. **Les deux fichiers sont à conserver** : la version en script SQL, moins lisible, montre la séquence `BEGIN` → `INSERT 0 1` → `ERROR` qui prouve que le refus de X9 intervient au COMMIT et non à l'insertion — preuve du comportement différé que la version en appels `psql -c` séparés, chacun en transaction implicite, ne laisse plus voir |
| 06.08.2026 | 4 — Vérification de la requête Eurostat (avant exécution) | Confirmer les paramètres du pilote, retenus par raisonnement et jamais testés | **Les cinq paramètres sont confirmés par l'API** (`sts_inpr_m`, `nace_r2=C29`, `unit=I21`, `s_adj=SCA`, `geo=EU27_2020`), libellés à l'appui : C29 = *Manufacture of motor vehicles, trailers and semi-trailers*, I21 = *Index, 2021=100*, SCA = *Seasonally and calendar adjusted*. Jeu de données mis à jour le 06.08.2026. **Trois écarts relevés** : (i) `size` = 42 périodes depuis 2023-01 mais 41 valeurs — la période la plus récente n'est pas encore publiée, le décodeur doit tolérer l'index manquant ; (ii) les deux dernières observations portent un drapeau `status: "i"` — **signification à vérifier dans la documentation Eurostat des *flags*, non supposée** ; (iii) le nœud de décodage ne lit que `value` et **ignore `status`** : la réserve de qualité émise par la source est perdue à l'ingestion | Aucune correction au pilote à ce stade — la tranche verticale passe d'abord. La réserve « plausibles mais non testés » des notes de rédaction est levée. Le critère de réussite de l'étape 4 est corrigé ci-dessus : ~41 observations, non « une trentaine ». Le point (iii) est à traiter après la tranche verticale (voir notes de rédaction) |
| 06.08.2026 | 4 — Rattachement des credentials | Sélectionner la credential Postgres sur les trois nœuds après import | Le fichier JSON ne contient volontairement aucun bloc `credentials` (aucun secret versionné) : le rattachement est manuel, nœud par nœud, sur « Ouvrir le run », « Écrire au registre » et « Clôturer le run ». Oubli sur un nœud ⇒ `NodeOperationError: Node does not have any credentials set`. Enregistrer le workflow avant de relancer | Aucune correction de fond. **Effet de bord à noter** : le premier nœud ayant réussi, chaque tentative interrompue laisse un run au statut `en_cours` jamais clôturé. Le dispositif ne distingue pas aujourd'hui un run interrompu d'un run en cours — à traiter après la tranche verticale ou à documenter comme limite |
| 06.08.2026 | 4 — Dépôt en zone brute | Écriture de la réponse d'API dans `data/staging/` (exigence E6, audit) | `NodeApiError: The file "/data/staging/A5_eurostat_2026-08-06_run4.json" is not writable`. **Fausse piste écartée par le diagnostic** : les droits POSIX sont corrects (hôte et conteneur partagent l'UID 1000, dossier en écriture) et un `touch` depuis le conteneur réussit. La cause est la couche de contrôle d'accès aux fichiers de n8n, non le système de fichiers | Ajout de `N8N_RESTRICT_FILE_ACCESS_TO: "/data"` au service n8n du `docker-compose.yml`, puis `docker compose up -d n8n` (les volumes, donc workflows et credentials, sont préservés). **À présenter comme un choix et non comme un contournement** : l'accès disque des workflows est désormais borné à la seule zone d'audit |
| 06.08.2026 | 4 et 5 — Exécution du pilote | Un run `ok`, ~41 observations en `valide_source`, fichier brut déposé, puis ré-exécution faisant apparaître l'écart entre runs | **Chaîne collecte → base démontrée.** Runs 4 et 5 au statut `ok`, 41 observations chacun, 0 écartée par les contrôles qualité, série de 2023-01 à 2026-05. Décodage JSON-stat vérifié valeur par valeur contre la réponse d'API : concordance exacte. `v_current` expose bien le run 5 et non le run 4 — la supersession fonctionne, rien n'est écrasé. Les trois runs antérieurs restent à `en_cours` (tentatives interrompues) | — |
| 06.08.2026 | 5 — Écart entre runs | Vue `v_ecart_entre_runs` opérante | 41 lignes appariées entre les runs 5 et 4, toutes à `ecart_pct = 0.00` : Eurostat n'a rien révisé en six minutes. **Le mécanisme est démontré, un écart non nul ne l'est pas encore.** Le critère du RUNBOOK était erroné (`ecart_pct IS NOT NULL` ne filtre pas les écarts nuls) — corrigé en `ecart_pct <> 0` | Deux voies retenues : (a) ré-exécuter début septembre, après la prochaine publication mensuelle Eurostat, pour capter une **révision réelle** — les périodes 2026-04 et 2026-05 portent déjà un drapeau de statut, ce sont les candidates ; (b) en attendant, démonstration contrôlée explicitement étiquetée comme simulation, jamais présentée comme une révision observée |
| 06.08.2026 | 4 — **Rupture d'audit détectée** | Toute valeur au registre référence une pièce brute existante (E6) | **Les 41 valeurs du run 4 référencent `A5_eurostat_2026-08-06_run4.json`, qui n'existe pas.** Le run est pourtant marqué `ok`. Cause : les branches « dépôt brut » et « décodage → écriture en base » étaient **parallèles** ; au run 4 la branche base a réussi et clôturé le run avant que la branche fichier n'échoue sur le blocage d'accès. Le dispositif a donc affirmé une traçabilité que rien ne soutenait, sans qu'aucune alerte ne se déclenche — exactement le défaut que le travail dénonce, reproduit par lui-même. Découvert uniquement par l'exécution | **Workflow corrigé** : séquence rendue obligatoire — API → sérialisation → dépôt brut → décodage → contrôles → écriture → clôture. Tant que le dépôt échoue, aucune valeur n'entre au registre : l'ordre devient une contrainte et non une commodité. **Défaut latent supprimé au passage** : la référence d'audit était construite deux fois avec deux fuseaux (UTC dans le nœud Code, Europe/Zurich dans le nœud fichier), divergentes au passage de minuit ; le nom ne porte plus que le `run_id`, la date étant dans `runs.executed_at`. Les runs 4 et 5 sont à considérer comme des runs de mise au point, non comme le run de référence du rapport |
| 06.08.2026 | 4 — Correction vérifiée | Chaque `raw_ref` correspond à un fichier réellement déposé | Run 6 : 41 observations, `raw_ref` = `/data/staging/A5_eurostat_run6.json`, fichier présent (5558 o, identique en taille à celui du run 5). La séquence obligatoire tient. Le run 4 conserve définitivement sa référence orpheline — le registre est en ajout seul, le défaut fait partie de la trace d'audit et ne s'efface pas | Aucune. Le caractère indélébile du défaut est à revendiquer, non à masquer : c'est la cohérence du principe d'ajout seul |
| 06.08.2026 | Restitution | Brancher le tableau de bord sur la base sans introduire de composant supplémentaire (E5) | **Interface de lecture créée** : `n8n_workflows/api_restitution.json` expose un webhook GET `/webhook/veille/donnees` qui renvoie en une requête l'état de `v_current`, les révisions constatées, le nombre de comparaisons entre runs, le bilan du référentiel et la couverture des questions de veille. L'orchestrateur fait office d'interface de lecture : aucun serveur applicatif ajouté. **Tableau de bord `tableau_de_bord.html` créé et vérifié à l'écran** — run 6 affiché, A5 avec badges HARD DATA et VALIDÉ SOURCE, source cliquable, pièce d'audit visible, 41 observations tracées, décompte du référentiel calculé par la base | **Critère de réussite de la tranche verticale atteint intégralement.** Trois partis pris à défendre : aucune donnée codée dans la page (base injoignable ⇒ la page n'affiche rien et le dit) ; la liste de révisions vide affiche son dénominateur (« aucune révision sur N comparaisons » ≠ « aucune comparaison possible ») ; la variation entre deux périodes consécutives est affichée avec sa mise en garde, application de la règle RI2 dans l'interface et pas seulement dans le prompt |
| 06.08.2026 | 1 — Critère de réussite | `v_bilan_referentiel` retourne 26 / 22 (21 hard + 1 composite) / 4 | **Conforme exactement.** Ventilation : aérospatial 6/4, automobile 5/5 (dont le composite A2), horlogerie 5/4, médical 6/5, transversal 4/4 | Aucune. **Cette sortie fait foi pour le décompte** : elle tranche l'incohérence I-6 (le rapport en donne aujourd'hui quatre valeurs contradictoires — 17, 19, 23, 26). Valeur à propager au résumé, au poster et aux § 8.4.5, 8.5, 10.1, 12.5, 13.6 |

Consigner en particulier : les codes Eurostat effectivement retenus, les erreurs de contrainte rencontrées (y compris celles provoquées volontairement à l'étape 2), les écarts entre le schéma spécifié et ce que les workflows ont réellement pu écrire, et le temps passé à chaque étape — la mesure du temps humain est une des dimensions de la grille du § 10.5.

## Remise à zéro

```bash
docker compose down -v && docker compose up -d
```

Destructif : supprime **tous** les volumes et rejoue `db/`.

**À n'utiliser librement qu'avant l'étape 3.** `down -v` supprime aussi le volume `n8n_data` : compte local, credentials et workflows importés sont perdus avec la base. Une fois la credential Postgres créée et le pilote importé, cette commande fait perdre un travail d'interface que rien ne restaure automatiquement — les fichiers `n8n_workflows/*.json` sont réimportables, mais la credential et son rattachement aux nœuds sont à refaire à la main.

Pour repartir d'une base propre **sans toucher à n8n** :

```bash
docker compose down            # sans -v : les volumes survivent
docker volume rm prototype_db_data
docker compose up -d           # db réinitialisée, n8n intact
```

Et pour vider les seules données de test en conservant le référentiel, sans réinitialiser quoi que ce soit — le registre étant en ajout seul, la suppression passe par une désactivation temporaire du déclencheur, opération à ne pratiquer que sur des données de test et à consigner :

```sql
ALTER TABLE indicator_values DISABLE TRIGGER trg_registre_ajout_seul;
DELETE FROM indicator_values WHERE raw_ref = '/data/test';
ALTER TABLE indicator_values ENABLE TRIGGER trg_registre_ajout_seul;
```
