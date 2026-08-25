// =====================================================================
// TEST DE RENDU — hors navigateur.
//
// Une application qui ne se vérifie qu'en l'ouvrant à la main n'est pas
// vérifiée : on regarde l'écran qu'on vient d'écrire, pas les autres.
// Ce fichier rend CHAQUE écran avec les données RÉELLES de l'API et
// échoue si l'un d'eux lève une exception.
//
//   node --experimental-default-type=module verification/executer.mjs
//   (ou : bash verification/executer.sh)
// =====================================================================
import React from "react";
import { renderToString } from "react-dom/server";
import { MemoryRouter, Routes, Route } from "react-router-dom";
import { Ctx } from "../src/api.jsx";
import Aujourdhui from "../src/pages/Aujourdhui.jsx";
import AFaire from "../src/pages/AFaire.jsx";
import Fiabilite from "../src/pages/Fiabilite.jsx";
import Marche from "../src/pages/Marche.jsx";

const BASE = process.env.API_BASE || "http://localhost:5678/webhook/veille";

async function lire(chemin) {
  const r = await fetch(BASE + chemin);
  if (!r.ok) throw new Error(chemin + " → HTTP " + r.status);
  return r.json();
}

// Chaque écran est rendu DANS SA ROUTE : une page qui lit ses paramètres
// d'URL (les marchés lisent `:code`) ne se teste pas hors de son routage,
// sinon elle rend son état vide et le test passe en croyant vérifier.
const ECRANS = [
  ["Aujourd'hui", Aujourdhui, "/aujourdhui", "/aujourdhui"],
  ["À faire", AFaire, "/a-faire", "/a-faire"],
  ["Fiabilité", Fiabilite, "/fiabilite", "/fiabilite"],
  ["Marché — horlogerie", Marche, "/marche/horlogerie", "/marche/:code"],
  ["Marché — automobile", Marche, "/marche/automobile", "/marche/:code"],
  ["Marché — médical", Marche, "/marche/medical", "/marche/:code"],
  ["Marché — aérospatial", Marche, "/marche/aerospatial", "/marche/:code"],
  ["Socle transversal", Marche, "/marche/transversal", "/marche/:code"]
];

// react-dom/server avertit sur useLayoutEffect à chaque écran ; l'avertissement
// est attendu hors navigateur et noie le résultat. On ne masque que celui-là.
const avert = console.error;
console.error = (...a) => { if (!String(a[0] ?? "").includes("useLayoutEffect")) avert(...a); };

const [D, S, G, O, A, AT, GEO] = await Promise.all(
  ["/donnees", "/sante", "/signaux", "/opportunites", "/actions", "/attribution", "/geographie"].map(lire)
);
const valeur = { D, S, G, O, A, AT, GEO, erreur: null, erreursV4: {}, chargement: false,
                 misAJour: new Date(), recharger: () => {} };

let echecs = 0;
for (const [nom, Page, route, motif] of ECRANS) {
  try {
    const html = renderToString(
      React.createElement(Ctx.Provider, { value: valeur },
        React.createElement(MemoryRouter, { initialEntries: [route] },
          React.createElement(Routes, null,
            React.createElement(Route, { path: motif, element: React.createElement(Page) })))));
    if (process.env.TEXTE && nom.includes(process.env.TEXTE)) {
      // Le texte tel qu'un lecteur le verra : c'est lui qu'on relit, pas le balisage.
      console.log("\n──────── " + nom + " ────────");
      console.log(html.replace(/<style[\s\S]*?<\/style>/g, "")
                      .replace(/<[^>]+>/g, "\n").replace(/&#x27;/g, "'")
                      .replace(/&quot;/g, '"').replace(/&amp;/g, "&").replace(/&#(\d+);/g, (_, c) => String.fromCharCode(c))
                      .split("\n").map(x => x.trim()).filter(Boolean).join("\n"));
      console.log("──────── fin ────────\n");
    }
    const taille = html.length;
    if (taille < 800) throw new Error("rendu suspect : " + taille + " caractères");
    console.log(`  ok    ${nom.padEnd(24)} ${taille.toLocaleString("fr-CH")} caractères`);
  } catch (e) {
    echecs++;
    console.log(`  ÉCHEC ${nom.padEnd(24)} ${e.message}`);
    if (process.env.TRACE) console.log(e.stack);
  }
}
console.log(echecs ? `\n${echecs} écran(s) en échec.` : "\nTous les écrans rendent sans exception.");
process.exit(echecs ? 1 : 0);
