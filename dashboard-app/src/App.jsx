import React from "react";
import { Routes, Route, NavLink, Navigate } from "react-router-dom";
import { FournisseurDonnees, useDonnees, API_URL, heureCH, alertesSignificatives } from "./api.jsx";
import Accueil from "./pages/Accueil.jsx";
import Secteur from "./pages/Secteur.jsx";
import Referentiel from "./pages/Referentiel.jsx";
import Executions from "./pages/Executions.jsx";
import AFaire from "./pages/AFaire.jsx";
import Anticiper from "./pages/Anticiper.jsx";
import Fiabilite from "./pages/Fiabilite.jsx";

// =====================================================================
// v8 — RETOUR À LA STRUCTURE V3, décision de l'étudiant du 26.08.2026.
//
// La v3 est la version qu'il a validée à l'écran le 17.08 : riche, une
// carte complète par indicateur — valeur, badge de statut, graphique,
// provenance — et les classements par pays. Les refontes v5-v7 ont gagné
// en calme et perdu en information ; c'était l'inverse de la demande.
//
// La v8 remet la v3 au centre, en conservant les acquis des itérations :
//   Vue d'ensemble  — l'accueil v3 (KPI, secteurs, commentaires)
//   Secteurs (×5)   — la page v3 complète : TOUS les indicateurs du
//                     référentiel, classements, gagnants/perdants
//   Actions         — les appels d'offres, le tamis, les dix items
//   Anticiper       — les indicateurs dérivés du 26.08
//   Référentiel · Exécutions — les preuves, comme en v3
//   Fiabilité       — les réserves calculées
// =====================================================================

function Navigation() {
  const { D, A } = useDonnees();
  const r = D?.referentiel || [];
  const secteurs = [...new Map(r.map(i => [i.sector_code, i.sector_label])).entries()]
    .filter(([c]) => c !== "transversal");
  const retenues = alertesSignificatives(D).retenues;
  const nbAlertes = c => retenues.filter(a => a.sector_code === c).length;
  const urgentes = (A?.actions || [])
    .filter(a => a.adressable >= 1 && a.jours_restants !== null && a.jours_restants <= 15).length;

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
      {lien("/", "Vue d'ensemble")}
      {lien("/actions", "Actions", urgentes || null)}
      {lien("/anticiper", "Anticiper")}
      <div className="nav-titre">Marchés</div>
      {secteurs.map(([c, l]) => (
        <React.Fragment key={c}>{lien("/secteur/" + c, l, nbAlertes(c) || null)}</React.Fragment>
      ))}
      {lien("/secteur/transversal", "Socle transversal")}
      <div className="nav-titre">Dispositif</div>
      {lien("/referentiel", "Référentiel")}
      {lien("/executions", "Exécutions")}
      {lien("/fiabilite", "Fiabilité")}
      <div className="nav-pied">
        Restitution v9 — structurée par questions de veille le 27.08<br />
        Scénario B · human-in-the-loop<br />
        Sources ouvertes uniquement<br />
        Prototype de travail de bachelor — HEG Arc
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
        Cette application ne contient aucune donnée en dur : sans l'interface de lecture,
        elle n'affiche rien — et le dit.<br />
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
          <Route path="/" element={<Accueil />} />
          <Route path="/secteur/:code" element={<Secteur />} />
          <Route path="/actions" element={<AFaire />} />
          <Route path="/anticiper" element={<Anticiper />} />
          <Route path="/referentiel" element={<Referentiel />} />
          <Route path="/executions" element={<Executions />} />
          <Route path="/fiabilite" element={<Fiabilite />} />

          {/* Adresses des itérations précédentes : un lien partagé ne meurt pas. */}
          <Route path="/accueil" element={<Navigate to="/" replace />} />
          <Route path="/aujourdhui" element={<Navigate to="/" replace />} />
          <Route path="/ce-matin" element={<Navigate to="/" replace />} />
          <Route path="/cette-semaine" element={<Navigate to="/" replace />} />
          <Route path="/marche/:code" element={<Secteur />} />
          <Route path="/qv/:code" element={<Secteur />} />
          <Route path="/a-faire" element={<Navigate to="/actions" replace />} />
          <Route path="/opportunites" element={<Navigate to="/actions" replace />} />
          <Route path="/dispositif" element={<Navigate to="/fiabilite" replace />} />
          <Route path="/radar" element={<Navigate to="/" replace />} />
          <Route path="/signaux" element={<Navigate to="/" replace />} />

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
        <div className="note" style={{ marginTop: 30, display: "flex", gap: 12, alignItems: "center" }}>
          <button className="rafraichir" disabled={chargement} onClick={recharger}>
            {chargement ? "Actualisation…" : "Actualiser les données"}
          </button>
          {misAJour && <span>Données rechargées à {heureCH(misAJour)}</span>}
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
