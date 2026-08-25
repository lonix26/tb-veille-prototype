// =====================================================================
// CONTRÔLE STATIQUE DE L'ORDRE DES HOOKS
//
// Le test de rendu ne peut pas attraper cette faute, et il faut le dire :
// `renderToString` ne rend QU'UNE FOIS, or une rupture d'ordre des hooks ne
// se manifeste qu'au second rendu, quand React compare les positions. Un
// écran peut donc passer le test de rendu et devenir blanc dès que les
// données arrivent — c'est exactement ce qui est arrivé le 25.08.2026 à
// l'écran « Ce matin », un `useMemo` ayant été placé après le retour
// anticipé `if (!S)`.
//
// La faute étant syntaxique, elle se détecte sans exécuter : dans un
// composant, aucun appel de hook ne doit suivre une instruction `return`
// de premier niveau.
// =====================================================================
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const HOOK = /\b(use[A-Z]\w*)\s*\(/;
const DEBUT_COMPOSANT = /^(export default )?function [A-Z]\w*\s*\(/;
const RETOUR_NIVEAU_UN = /^ {2}return\b|^ {2}if \([^)]*\) return\b/;

const fichiers = [];
for (const d of ["src", "src/pages"]) {
  for (const f of readdirSync(d)) if (f.endsWith(".jsx")) fichiers.push(join(d, f));
}

let fautes = 0;
for (const f of fichiers) {
  const lignes = readFileSync(f, "utf8").split("\n");
  let dansComposant = false, retourVu = 0;
  lignes.forEach((l, i) => {
    if (DEBUT_COMPOSANT.test(l)) { dansComposant = true; retourVu = 0; return; }
    if (!dansComposant) return;
    if (/^}/.test(l)) { dansComposant = false; return; }
    if (RETOUR_NIVEAU_UN.test(l)) { retourVu = i + 1; return; }
    // Un hook au premier niveau d'indentation du composant, après un return.
    if (retourVu && /^ {2}(const|let|var)?\s*[\w{[\], ]*=?\s*use[A-Z]/.test(l) && HOOK.test(l)) {
      console.log(`  FAUTE ${f}:${i + 1} — hook après le retour de la ligne ${retourVu}`);
      console.log(`         ${l.trim().slice(0, 90)}`);
      fautes++;
    }
  });
}
console.log(fautes
  ? `\n${fautes} hook(s) appelé(s) après un retour anticipé — l'écran deviendra blanc au second rendu.`
  : "Ordre des hooks : aucun hook après un retour anticipé.");
process.exit(fautes ? 1 : 0);
