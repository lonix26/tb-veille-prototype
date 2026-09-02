// =====================================================================
// Sonde de console — créé le 02.09.2026, après qu'une variable retirée de
// la coquille (`misAJour`) a rendu l'application blanche dans le navigateur
// alors que le harnais de rendu (rendu.jsx) passait : il ne rend que les
// PAGES, pas la coquille ni les graphiques ECharts. Cette sonde ouvre chaque
// écran dans le navigateur de Puppeteer et échoue à la première erreur de
// page, de console ou de requête. `node verification/console.mjs`.
// =====================================================================
import puppeteer from "puppeteer";

const BASE = process.env.BASE_URL || "http://localhost:8080";
const ECRANS = ["/#/", "/#/anticiper", "/#/actions", "/#/secteur/horlogerie", "/#/secteur/automobile",
  "/#/secteur/medical", "/#/secteur/aerospatial", "/#/secteur/transversal", "/#/referentiel",
  "/#/fiabilite", "/#/executions"];

const nav = await puppeteer.launch({ headless: "shell", args: ["--no-sandbox", "--disable-gpu"] });
const page = await nav.newPage();
await page.setViewport({ width: 1360, height: 900 });
let defauts = 0;
const noter = (route, genre, txt) => { defauts++; console.log(`  ${genre.padEnd(14)} ${route.padEnd(24)} ${txt}`); };
let route = "";
page.on("pageerror", e => noter(route, "page", e.message));
page.on("console", m => { if (m.type() === "error" || m.type() === "warning") noter(route, "console." + m.type(), m.text()); });
page.on("requestfailed", r => noter(route, "requête", r.url() + " " + (r.failure()?.errorText || "")));

for (route of ECRANS) {
  await page.goto(BASE + route, { waitUntil: "networkidle0", timeout: 60000 });
  await new Promise(r => setTimeout(r, 1500));
  const texte = await page.evaluate(() => document.body.innerText.trim().length);
  if (texte < 200) noter(route, "vide", `${texte} caractères visibles`);
  else console.log(`  ok             ${route.padEnd(24)} ${texte} caractères visibles`);
}
await nav.close();
if (defauts) { console.log(`\n${defauts} défaut(s) dans le navigateur.`); process.exit(1); }
console.log("\nAucune erreur de navigateur sur les onze écrans.");
