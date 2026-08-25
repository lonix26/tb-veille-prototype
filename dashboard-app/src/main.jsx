import React from "react";
import { createRoot } from "react-dom/client";
import { HashRouter } from "react-router-dom";
import App from "./App.jsx";
// UNE seule feuille de style. Les itérations précédentes en empilaient
// trois, et des écrans entiers étaient cassés sans qu'aucun test ne le
// voie — un test de rendu vérifie le texte, pas la géométrie.
import "./app.css";

createRoot(document.getElementById("racine")).render(
  <HashRouter>
    <App />
  </HashRouter>
);
