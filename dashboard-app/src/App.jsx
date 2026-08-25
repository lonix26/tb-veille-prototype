import React from "react";
import { Routes, Route, NavLink, Navigate } from "react-router-dom";
import { FournisseurDonnees, useDonnees, API_URL, heureCH } from "./api.jsx";
import Aujourdhui from "./pages/Aujourdhui.jsx";
import AFaire from "./pages/AFaire.jsx";
import Marche from "./pages/Marche.jsx";
import Fiabilite from "./pages/Fiabilite.jsx";
import Anticiper from "./pages/Anticiper.jsx";

// =====================================================================
// v7 — QUATRE ÉCRANS, UNE FEUILLE DE STYLE, RIEN D'AUTRE DANS LE BUNDLE.
//
//   Aujourd'hui  — dois-je faire quelque chose ?
//   À faire      — sur quoi je me positionne, et quand ?
//   Un marché    — pourquoi ce marché est-il dans cet état ?
//   Fiabilité    — puis-je m'y fier, et que sait-on mal ?
//
// Les écrans des itérations précédentes ont été RETIRÉS du bundle. Ils
// mêlaient trois systèmes visuels et des attentes de données que l'API ne
// sert plus — d'où des pages cassées. Leur code reste dans git et leur
// histoire au rapport (§ 11) ; leurs adresses redirigent vers l'écran
// équivalent, un lien partagé ne meurt pas.
// =====================================================================

const SECTEURS = [
  ["horlogerie", "Horlogerie"], ["medical", "Médical"],
  ["automobile", "Automobile"], ["aerospatial", "Aérospatial"],
  ["transversal", "Métier et marge"]
];

function Navigation() {
  const { A } = useDonnees();
  const urgentes = (A?.actions || [])
    .filter(a => a.adressable >= 1 && a.jours_restants !== null && a.jours_restants <= 15).length;

  const lien = (vers, libelle, pastille, ton) => (
    <NavLink to={vers} className={({ isActive }) => "nav" + (isActive ? " actif" : "")}>
      <span>{libelle}</span>
      {pastille ? <span className={"pastille" + (ton ? " p-" + ton : "")}>{pastille}</span> : null}
    </NavLink>
  );

  return (
    <aside>
      <div className="logo">
        Veille économique
        <small>CODEC SA · cas d'illustration</small>
      </div>
      {lien("/aujourdhui", "Aujourd'hui")}
      {lien("/a-faire", "À faire", urgentes || null, "alerte")}
      {lien("/anticiper", "Anticiper")}
      {lien("/fiabilite", "Fiabilité")}
      <div className="nav-titre">Vos marchés</div>
      {SECTEURS.map(([c, l]) => (
        <React.Fragment key={c}>{lien("/marche/" + c, l)}</React.Fragment>
      ))}
      <div className="nav-pied">
        Prototype de travail de bachelor · HEG Arc<br />
        Semi-automatisé — rien n'est diffusé sans relecture humaine<br />
        Sources ouvertes uniquement
      </div>
    </aside>
  );
}

function Entete() {
  return (
    <aside>
      <div className="logo">Veille économique<small>CODEC SA · cas d'illustration</small></div>
    </aside>
  );
}

function Squelette() {
  return (
    <main>
      <div className="squelette" style={{ height: 16, width: 150, marginBottom: 22 }} />
      <div className="squelette" style={{ height: 66, width: 440, marginBottom: 30 }} />
      <div className="squelette" style={{ height: 130, marginBottom: 30 }} />
      <div className="squelette" style={{ height: 220 }} />
    </main>
  );
}

function Erreur({ erreur, recharger }) {
  return (
    <main>
      <div className="vide">
        <strong>La base ne répond pas.</strong><br />
        Cette application ne contient aucune donnée en dur : sans l'interface de lecture, elle
        n'affiche rien — et le dit, plutôt que de montrer un écran vide qui passerait pour un
        marché calme.<br />
        <span style={{ fontSize: 12, color: "var(--gris)" }}>{erreur} · {API_URL}</span><br /><br />
        <button className="rafraichir" onClick={recharger}>Réessayer</button>
      </div>
    </main>
  );
}

function Coquille() {
  const { D, erreur, chargement, misAJour, recharger } = useDonnees();
  if (chargement && !D) return (<><Entete /><Squelette /></>);
  if (erreur && !D) return (<><Entete /><Erreur erreur={erreur} recharger={recharger} /></>);
  return (
    <>
      <Navigation />
      <main>
        <Routes>
          <Route path="/" element={<Navigate to="/aujourdhui" replace />} />
          <Route path="/aujourdhui" element={<Aujourdhui />} />
          <Route path="/a-faire" element={<AFaire />} />
          <Route path="/anticiper" element={<Anticiper />} />
          <Route path="/fiabilite" element={<Fiabilite />} />
          <Route path="/marche/:code" element={<Marche />} />

          {/* Adresses des itérations précédentes. */}
          <Route path="/qv/:code" element={<Marche />} />
          <Route path="/secteur/:code" element={<Marche />} />
          <Route path="/ce-matin" element={<Navigate to="/aujourdhui" replace />} />
          <Route path="/cette-semaine" element={<Navigate to="/aujourdhui" replace />} />
          <Route path="/accueil" element={<Navigate to="/aujourdhui" replace />} />
          <Route path="/dispositif" element={<Navigate to="/fiabilite" replace />} />
          <Route path="/referentiel" element={<Navigate to="/fiabilite" replace />} />
          <Route path="/executions" element={<Navigate to="/fiabilite" replace />} />
          <Route path="/actions" element={<Navigate to="/a-faire" replace />} />
          <Route path="/opportunites" element={<Navigate to="/a-faire" replace />} />
          <Route path="/radar" element={<Navigate to="/aujourdhui" replace />} />
          <Route path="/signaux" element={<Navigate to="/aujourdhui" replace />} />

          <Route path="*" element={<Navigate to="/aujourdhui" replace />} />
        </Routes>
        <footer className="pied">
          <button className="rafraichir" disabled={chargement} onClick={recharger}>
            {chargement ? "Actualisation…" : "Actualiser"}
          </button>
          {misAJour && <span>Affichage rafraîchi à {heureCH(misAJour)}</span>}
        </footer>
      </main>
    </>
  );
}

export default function App() {
  return (
    <FournisseurDonnees>
      <Coquille />
    </FournisseurDonnees>
  );
}
