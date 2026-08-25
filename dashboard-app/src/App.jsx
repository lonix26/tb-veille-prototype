import React from "react";
import { Routes, Route, NavLink, Navigate } from "react-router-dom";
import { FournisseurDonnees, useDonnees, API_URL, heureCH } from "./api.jsx";
import { redondances, compositionLatence } from "./phrases.jsx";
import Aujourdhui from "./pages/Aujourdhui.jsx";
import AFaire from "./pages/AFaire.jsx";
import Fiabilite from "./pages/Fiabilite.jsx";
import SecteurQV from "./pages/SecteurQV.jsx";
import Radar from "./pages/Radar.jsx";
import CeMatin from "./pages/CeMatin.jsx";
import Accueil from "./pages/Accueil.jsx";
import Secteur from "./pages/Secteur.jsx";

// =====================================================================
// v6 — QUATRE ENTRÉES, ET CHACUNE RÉPOND À UNE SEULE QUESTION.
//
//   Aujourd'hui  — dois-je faire quelque chose ?
//   À faire      — sur quoi je me positionne, et quand ?
//   Un marché    — pourquoi ce marché est-il dans cet état ?
//   Fiabilité    — puis-je m'y fier, et que sait-on mal ?
//
// La v5 avait dix entrées et un écran d'accueil de neuf sections. Elle
// était juste sur le fond et illisible dans la forme : à chaque réserve
// j'ajoutais un bloc, jusqu'à ce que le verdict disparaisse au milieu des
// avertissements. Les réserves n'ont pas été supprimées — elles auraient
// été perdues, et elles font la valeur du travail. Elles sont réunies sur
// l'écran Fiabilité, avec un compteur là où elles s'appliquent.
//
// Les itérations précédentes restent atteignables par leur adresse.
// =====================================================================

function Navigation() {
  const { D, S, A } = useDonnees();
  const secteurs = (S?.sante || []).filter(s => s.sector_code !== "transversal");
  const urgentes = (A?.actions || [])
    .filter(a => a.adressable >= 1 && a.jours_restants !== null && a.jours_restants <= 15).length;

  // Le compteur de réserves suit la même règle que l'écran Fiabilité.
  let reserves = 0;
  for (const m of secteurs) {
    reserves += redondances(D, m.indicateurs).length;
    if (compositionLatence(D, m.indicateurs).avance === 0) reserves++;
  }

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
      {lien("/a-faire", "À faire", urgentes || null, "rouge")}
      {lien("/fiabilite", "Fiabilité", reserves || null)}

      <div className="nav-titre">Vos marchés</div>
      {secteurs.map(s => (
        <React.Fragment key={s.sector_code}>
          {lien("/marche/" + s.sector_code, s.sector_label)}
        </React.Fragment>
      ))}
      {lien("/marche/transversal", "Socle transversal")}

      <div className="nav-pied">
        Prototype de travail de bachelor · HEG Arc<br />
        Semi-automatisé — rien n'est diffusé sans relecture humaine<br />
        Sources ouvertes uniquement<br />
        <span className="nav-archives">
          Itérations : <a href="#/ce-matin">v5</a> · <a href="#/accueil">v3</a> · <a href="#/radar">radar</a>
        </span>
      </div>
    </aside>
  );
}

function Squelette() {
  return (
    <main>
      <div className="squelette" style={{ height: 18, width: 160, marginBottom: 24 }} />
      <div className="squelette" style={{ height: 76, width: 460, marginBottom: 34 }} />
      <div className="squelette" style={{ height: 120, marginBottom: 34 }} />
      <div className="tuiles">
        {[0, 1, 2, 3].map(i => <div key={i} className="squelette" style={{ height: 150 }} />)}
      </div>
    </main>
  );
}

function Entete() {
  return (
    <aside>
      <div className="logo">Veille économique<small>CODEC SA · cas d'illustration</small></div>
    </aside>
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
          <Route path="/fiabilite" element={<Fiabilite />} />
          <Route path="/marche/:code" element={<SecteurQV />} />

          {/* Adresses des itérations précédentes : un lien partagé ne meurt pas. */}
          <Route path="/qv/:code" element={<SecteurQV />} />
          <Route path="/ce-matin" element={<CeMatin />} />
          <Route path="/cette-semaine" element={<Navigate to="/aujourdhui" replace />} />
          <Route path="/dispositif" element={<Navigate to="/fiabilite" replace />} />
          <Route path="/actions" element={<Navigate to="/a-faire" replace />} />
          <Route path="/opportunites" element={<Navigate to="/a-faire" replace />} />
          <Route path="/referentiel" element={<Navigate to="/fiabilite" replace />} />
          <Route path="/executions" element={<Navigate to="/fiabilite" replace />} />
          <Route path="/signaux" element={<Radar />} />
          <Route path="/radar" element={<Radar />} />
          <Route path="/accueil" element={<Accueil />} />
          <Route path="/secteur/:code" element={<Secteur />} />

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
