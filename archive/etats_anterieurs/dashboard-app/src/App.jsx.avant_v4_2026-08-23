import React from "react";
import { Routes, Route, NavLink, Navigate } from "react-router-dom";
import { FournisseurDonnees, useDonnees, API_URL, heureCH } from "./api.jsx";
import Accueil from "./pages/Accueil.jsx";
import Secteur from "./pages/Secteur.jsx";
import Referentiel from "./pages/Referentiel.jsx";
import Executions from "./pages/Executions.jsx";

function Navigation() {
  const { D } = useDonnees();
  const r = D?.referentiel || [];
  const secteurs = [...new Map(r.map(i => [i.sector_code, i.sector_label])).entries()]
    .filter(([c]) => c !== "transversal");
  const nbAlertes = c =>
    (D?.alertes || []).filter(a => a.sector_code === c && a.diffusable).length;

  const lien = (vers, libelle, pastille) => (
    <NavLink to={vers} className={({ isActive }) => "nav" + (isActive ? " actif" : "")}>
      {libelle}
      {pastille ? <span className="pastille">{pastille}</span> : null}
    </NavLink>
  );

  return (
    <aside>
      <div className="logo">
        Veille économique
        <small>CODEC SA · cas d'illustration</small>
      </div>
      {lien("/accueil", "Vue d'ensemble")}
      {lien("/secteur/transversal", "Contexte mondial")}
      <div className="nav-titre">Secteurs</div>
      {secteurs.map(([c, l]) => (
        <React.Fragment key={c}>{lien("/secteur/" + c, l, nbAlertes(c) || null)}</React.Fragment>
      ))}
      <div className="nav-titre">Dispositif</div>
      {lien("/referentiel", "Référentiel")}
      {lien("/executions", "Exécutions")}
      <div className="nav-pied">
        Scénario B · human-in-the-loop<br />
        Sources ouvertes uniquement<br />
        Prototype de travail de bachelor — HEG Arc
      </div>
    </aside>
  );
}

function Squelette() {
  return (
    <main>
      <div className="squelette" style={{ height: 34, width: 280, marginBottom: 20 }} />
      <div className="grille g4">
        {[0, 1, 2, 3].map(i => <div key={i} className="squelette" style={{ height: 110 }} />)}
      </div>
      <div className="squelette" style={{ height: 300, marginTop: 14 }} />
    </main>
  );
}

function Erreur({ erreur, recharger }) {
  return (
    <main>
      <div className="vide">
        <strong>La base ne répond pas.</strong><br />
        Cette application ne contient aucune donnée en dur : sans l'interface de lecture
        (workflow « API de restitution » actif dans n8n, base démarrée), elle n'affiche
        rien — et le dit.<br />
        <span style={{ fontSize: 12, color: "var(--gris)" }}>{erreur} · {API_URL}</span><br /><br />
        <button className="rafraichir" onClick={recharger}>Réessayer</button>
      </div>
    </main>
  );
}

function Coquille() {
  const { D, erreur, chargement, misAJour, recharger } = useDonnees();
  if (chargement && !D) return (<><aside><div className="logo">Veille économique<small>CODEC SA · cas d'illustration</small></div></aside><Squelette /></>);
  if (erreur && !D) return (<><aside><div className="logo">Veille économique<small>CODEC SA · cas d'illustration</small></div></aside><Erreur erreur={erreur} recharger={recharger} /></>);
  return (
    <>
      <Navigation />
      <main>
        <Routes>
          <Route path="/" element={<Navigate to="/accueil" replace />} />
          <Route path="/accueil" element={<Accueil />} />
          <Route path="/secteur/:code" element={<Secteur />} />
          <Route path="/referentiel" element={<Referentiel />} />
          <Route path="/executions" element={<Executions />} />
          <Route path="*" element={<Navigate to="/accueil" replace />} />
        </Routes>
        <div className="note" style={{ marginTop: 30, display: "flex", gap: 12, alignItems: "center" }}>
          <button className="rafraichir" disabled={chargement} onClick={recharger}>
            {chargement ? "Actualisation…" : "Actualiser les données"}
          </button>
          {misAJour && <span>Données rechargées à {heureCH(misAJour)} · générées le {D?.genere_le ? new Date(D.genere_le).toLocaleString("fr-CH") : "—"}</span>}
        </div>
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
