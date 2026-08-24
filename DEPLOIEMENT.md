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

## 2. Schéma et référentiel

Rejouer les migrations dans l'ordre chronologique de leur nom :

```bash
for f in migrations/*.sql; do
  docker exec -i veille_db psql -U veille -d veille -v ON_ERROR_STOP=1 < "$f" || echo "ÉCHEC : $f"
done
```

Elles créent le schéma, sèment le référentiel — indicateurs, sources, liaisons, questions de
veille — **et amorcent les seize flux de l'étage 2 avec leurs statuts de qualification**
(`2026-08-25_amorcage_flux.sql`). Une base neuve repart donc dans l'état qualifié, pas dans un
état par défaut qu'il faudrait requalifier.

## 3. Importer les workflows

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

## 4. Lancer la chaîne, dans cet ordre

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

## 5. Vérifier

```sql
-- Aucun run ne doit rester ouvert ni en échec.
SELECT run_id, status, left(note, 90) FROM runs ORDER BY run_id DESC LIMIT 12;

-- Le décompte fait foi ICI, jamais dans un texte.
SELECT * FROM v_bilan_referentiel;

-- Indicateurs certifiés sans aucune liaison active : ils ne collecteront jamais.
SELECT i.indicator_id, i.label FROM indicators i
WHERE i.status = 'certifie'
  AND NOT EXISTS (SELECT 1 FROM v_bindings_actifs b WHERE b.indicator_id = i.indicator_id);
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
