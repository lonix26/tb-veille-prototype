import React from "react";
import { createRoot } from "react-dom/client";
import { HashRouter } from "react-router-dom";
import App from "./App.jsx";
// LA FEUILLE DE LA V3 — le système visuel que l'étudiant a validé à l'écran
// le 17.08 et redemandé le 26.08, après que trois refontes « épurées » ont
// appauvri l'affichage. Les écrans postérieurs (Actions, Anticiper,
// Fiabilité) sont raccordés à cette même feuille par le bloc d'extensions
// en fin de fichier : UNE feuille, vérifiée par le contrôle de classes.
import "./styles.css";

createRoot(document.getElementById("racine")).render(
  <HashRouter>
    <App />
  </HashRouter>
);
