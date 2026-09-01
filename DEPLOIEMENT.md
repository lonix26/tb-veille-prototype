# Déploiement du dispositif — séquence complète

*Écrit le 25.08.2026, après le portage intégral de la collecte vers l'orchestrateur.*

**Ce document répond à une seule question : que faut-il faire pour que, dans trois mois, tous les
indicateurs se mettent à jour ?** Réponse courte — déployer le compose, rejouer les migrations,
importer les workflows, les lancer dans l'ordre. Aucun script n'intervient dans la collecte.

---

## 1. Prérequis

```bash
# Les clés vivent HORS du dossier du travail : il part chaque jour vers le Drive.
cat ~/.config/veille_tb/cles.env     # permissions 600
```

Le fichier doit porter au minimum `GOOGLE_API_KEY` et `MODELE_GOOGLE` (triage et lecture
décisionnelle), `ANTHROPIC_API_KEY` et `MODELE_ANTHROPIC` (commentaire exécutif), et le
mot de passe de la base. Le `docker-compose.yml` le lit ; **aucune clé n'est dans le dépôt**.

```bash
cd prototype
docker compose up -d          # base, orchestrateur, service statique de restitution
```

## 2. Schéma et référentiel — rien à lancer

**Le `docker compose up -d` de l'étape précédente a déjà tout fait.** Le service de base monte
`./db` sur `/docker-entrypoint-initdb.d` : au tout premier démarrage, sur un volume vide,
PostgreSQL exécute lui-même les deux fichiers, dans l'ordre de leur nom.

| Fichier | Ce qu'il pose |
|---|---|
| `db/01_socle.sql` | 31 tables (dont 4 du schéma `sandbox`), 44 vues, 4 déclencheurs, 44 fonctions, les contraintes métier et leurs commentaires |
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
npm ci            # ou npm install au premier jet
npm run build     # produit dashboard-app/dist, servi tel quel par nginx
cd ..
```

Puis, une fois l'API de restitution active (étape suivante), vérifier que les huit écrans se
rendent réellement — un écran qui plante ne se voit qu'en l'ouvrant, et on n'ouvre que celui
qu'on vient d'écrire :

```bash
bash dashboard-app/verification/executer.sh
```

Il rend chaque écran hors navigateur avec les données réelles de l'API et sort en erreur si
l'un d'eux lève une exception.

## 4. Importer les workflows

```bash
for f in n8n_workflows/*.json; do
  docker cp "$f" veille_n8n:/tmp/w.json
  docker exec veille_n8n n8n import:workflow --input=/tmp/w.json
done
docker exec veille_n8n n8n update:workflow --id=apiRestitutionV4 --active=true
docker compose restart n8n        # INDISPENSABLE : sans redémarrage, les webhooks
                                  # ne sont pas enregistrés et l'API répond 404
```

Chaque fichier porte son **identifiant épinglé** : l'import met à jour en place et ne crée pas de
copie. Sans cela, l'instance accumule des doublons et rien ne dit lequel s'exécute.

## 5. Lancer la chaîne, dans cet ordre

L'ordre compte : le triage a besoin des items, la lecture décisionnelle a besoin des avis
enrichis, le commentaire a besoin des indicateurs.

| # | Workflow | Ce qu'il alimente |
|---|---|---|
| 1 | `collecteGeneriqueV2` | 30 indicateurs — API et fichiers plats |
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
-- Au 25.08.2026, quatre sont attendus dans ce résultat, et aucun autre :
--   A2  composite ACEA — alimenté par `composite_queue`, pas par une liaison (doctrine)
--   A1  production mondiale de véhicules — source non encore liée
--   H4  brevets horlogers CIB G04 — en attente d'un accès OEB (portail OPS hors service)
--   S1  commandes et livraisons d'avions — requalification en composite à trancher
-- Tout autre indicateur qui apparaît ici est une régression.
SELECT i.indicator_id, i.label FROM indicators i
WHERE i.status = 'certifie'
  AND NOT EXISTS (SELECT 1 FROM v_bindings_actifs b WHERE b.indicator_id = i.indicator_id);

-- Liaisons actives à fenêtre FIGÉE : elles rapporteront toujours la même période.
-- Au 25.08.2026, DEUX sont attendues et aucune autre : les liaisons A3 24 et 27
-- (éditions IEA 2023 et 2024), qui portent des années closes et ne bougeront plus.
-- Toute autre ligne est une liaison qui a cessé d'avancer sans le dire — c'est
-- exactement le défaut trouvé le 25.08 sur H1, A3, H2 et M4.
SELECT binding_id, indicator_id, left(params::text, 70)
FROM source_bindings
WHERE statut = 'actif' AND params::text !~ '\{\{' AND params::text ~ '"(year|Jahr)"';

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
-- Attendu : A2 (composite, alimenté par composite_queue) et les indicateurs
-- écartés de la grille. Toute autre ligne est une régression à traiter.

-- Et le décompte de la grille, qui fait foi. `en_grille` = certifiés + à confirmer ;
-- `ecartes` = indicateurs restés au référentiel mais retirés de la grille.
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
2. **La validation des commentaires.** Ils sortent au statut `a_valider` ; seuls les validés sont
   servis par l'interface. Le rejet est un événement de l'historique, pas un effacement.
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
