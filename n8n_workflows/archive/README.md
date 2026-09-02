# Archive des workflows

Pièces conservées pour l'audit (E6), **hors de la boucle d'import** de `DEPLOIEMENT.md`
(qui ne parcourt que `n8n_workflows/*.json`).

- `extraction_composite_A2_en_service_2026-08-17.json` — export, le 02.09.2026, de la version
  de l'instance (`updatedAt` 17.08.2026 13:45) qui a produit les runs 51 à 58 (extractions A2)
  dont sont issues les sept valeurs validées humainement (runs 59-64). Cette version ne
  correspond à aucun commit : les correctifs du 17.08 (normalisation du `%`, délais 180 s,
  consigne « pas le cumul annuel ») avaient été écrits dans le fichier du dépôt sans être
  réimportés. Le fichier corrigé a été importé le 02.09.2026 ; il n'a produit aucun run à cette
  date.

## `squelettes_2026-08-04/` — cinq états antérieurs, jamais importés dans l'instance en service

Déplacés le 02.09.2026 (correction A9 du tour « jury ») ; ils s'importaient avec les autres et
un lecteur ne distinguait pas le vivant du mort. Aucun des cinq n'est dans l'instance (21
workflows, liste par `n8n list:workflow`), aucun n'a produit de run.

| Fichier | Ce qu'il était | Ce qui l'a remplacé |
|---|---|---|
| `collecte_hard_data.json` (`collecteHardDataV0`) | Squelette ETL du 04.08 parlant à un service `loader:8080` qui n'a jamais existé | `collecte_generique.json`, piloté par `source_bindings` |
| `collecte_a5_multi_geo.json` (`collecteA5MultiGeoV0`) | Déclinaison géographique d'A5 écrite avant le collecteur générique | la liaison A5 du collecteur générique (multi-zones par `params`) |
| `collecte_m2_eurostat.json` (`collecteM2V0`) | Collecteur M2 dédié | la liaison M2 du collecteur générique |
| `extraction_composite_multi_ia.json` (`extractionCompositeV0`) | Squelette générique d'extraction composite, `loader:8080` | `extraction_composite_A2.json`, `_CP`, `_A1_ccfa` |
| `scenario_c_agent_autonome.json` (`scenarioCAgentV1`) | Maquette n8n du scénario C, `loader:8080`, jamais exécutée | **`scenario_c/agent_autonome.py`** — c'est le script Python qui a porté la confrontation B/C (§ 10.5), pas ce fichier |

Ils restent lisibles : la conduite du projet et l'exploration des pistes font partie de ce
que le jury apprécie, et l'historique git seul ne les montre qu'à qui sait chercher.
