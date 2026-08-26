// =====================================================================
// CONTRÔLE DES CLASSES CSS — la vérification que les pages cassées
// réclamaient. Le test de rendu vérifie le texte ; il ne voit pas qu'une
// classe n'existe dans aucune feuille et que le bloc s'affiche en vrac.
// C'est exactement ainsi que les écrans des itérations v5/v6 se sont
// cassés : trois feuilles empilées, des classes orphelines, et aucun
// signal. Ce contrôle liste les classes utilisées par les écrans VIVANTS
// et échoue si l'une d'elles n'est définie nulle part.
// =====================================================================
import { readFileSync } from "node:fs";

const VIVANTS = [
  "src/App.jsx", "src/pages/Accueil.jsx", "src/pages/Secteur.jsx",
  "src/pages/Referentiel.jsx", "src/pages/Executions.jsx",
  "src/pages/AFaire.jsx", "src/pages/Anticiper.jsx", "src/pages/Fiabilite.jsx",
  "src/api.jsx", "src/Mini.jsx", "src/Chart.jsx"
];
const FEUILLE = readFileSync("src/styles.css", "utf8");
const definies = new Set([...FEUILLE.matchAll(/\.([a-z][a-z0-9_-]*)/gi)].map(m => m[1]));

// Classes produites dynamiquement par concaténation — la base est déclarée,
// les suffixes viennent des données. On vérifie la base.
const DYNAMIQUES = new Set(["t-", "r-", "lat-", "p-", "e-"]);

let manquantes = 0;
for (const f of VIVANTS) {
  const src = readFileSync(f, "utf8");
  const classes = new Set();
  for (const m of src.matchAll(/className=\{?"([^"]+)"/g))
    for (const c of m[1].split(/\s+/)) if (c) classes.add(c);
  for (const m of src.matchAll(/className=\{"([^"]+)"\s*\+/g))
    for (const c of m[1].trim().split(/\s+/)) if (c) classes.add(c);
  for (const c of classes) {
    if (definies.has(c)) continue;
    if ([...DYNAMIQUES].some(d => c === d.slice(0, -1) || c.startsWith(d))) continue;
    console.log(`  ORPHELINE ${f} → .${c}`);
    manquantes++;
  }
}
console.log(manquantes
  ? `\n${manquantes} classe(s) sans définition — l'écran s'affichera en vrac.`
  : "Classes CSS : toutes les classes des écrans vivants sont définies.");
process.exit(manquantes ? 1 : 0);
