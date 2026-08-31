// =====================================================================
// Captures d'écran de la restitution — pleine page, données réelles.
// Créé le 27.08.2026 : sert les figures du rapport (annexe 6) ET la revue
// visuelle. Reproductible : `node verification/captures.mjs [dossier]`.
// Le navigateur est le chrome-headless-shell de Puppeteer (dev-dependency,
// jamais dans l'image de production — la contrainte E5 n'est pas touchée).
// =====================================================================
import puppeteer from "puppeteer";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const BASE = process.env.BASE_URL || "http://localhost:8080";
const DOSSIER = resolve(process.argv[2] || "../../annexes/6_captures/v9");
mkdirSync(DOSSIER, { recursive: true });

const ECRANS = [
  ["accueil",        "/#/"],
  ["anticiper",      "/#/anticiper"],
  ["actions",        "/#/actions"],
  ["marche_horlogerie",  "/#/secteur/horlogerie"],
  ["marche_automobile",  "/#/secteur/automobile"],
  ["marche_medical",     "/#/secteur/medical"],
  ["marche_aerospatial", "/#/secteur/aerospatial"],
  ["socle_transversal",  "/#/secteur/transversal"],
  ["referentiel",    "/#/referentiel"],
  ["fiabilite",      "/#/fiabilite"],
  ["executions",     "/#/executions"],
];

const nav = await puppeteer.launch({
  headless: "shell",
  args: ["--no-sandbox", "--disable-gpu", "--force-device-scale-factor=1"]
});
const page = await nav.newPage();
await page.setViewport({ width: 1360, height: 900 });

for (const [nom, route] of ECRANS) {
  await page.goto(BASE + route, { waitUntil: "networkidle0", timeout: 60000 });
  // Les graphiques ECharts s'animent : petite stabilisation.
  await new Promise(r => setTimeout(r, 1800));
  const fichier = `${DOSSIER}/${nom}.png`;
  await page.screenshot({ path: fichier, fullPage: true });
  console.log(`  ok  ${nom.padEnd(22)} ${fichier}`);
}
await nav.close();
console.log("Captures terminées.");
