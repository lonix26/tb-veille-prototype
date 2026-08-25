import React from "react";
import { createRoot } from "react-dom/client";
import { HashRouter } from "react-router-dom";
import App from "./App.jsx";
import "./styles.css";
// v6 chargée APRÈS le socle : elle ne remplace pas la feuille précédente,
// elle la calme. Les classes des itérations antérieures restent valides,
// ce qui garde les écrans archivés lisibles.
import "./v6.css";

// Routage par fragment (#/…) : l'application est servie en statique par
// nginx sans réécriture d'URL — le fragment évite toute configuration
// serveur, fidèle à l'esprit « distribuer des fichiers, rien de plus ».
createRoot(document.getElementById("racine")).render(
  <HashRouter>
    <App />
  </HashRouter>
);
