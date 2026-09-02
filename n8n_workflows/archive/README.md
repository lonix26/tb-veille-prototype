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
