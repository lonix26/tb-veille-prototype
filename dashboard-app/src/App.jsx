import React from "react";
import { Routes, Route, NavLink, Navigate } from "react-router-dom";
import { FournisseurDonnees, useDonnees, API_URL, heureCH, alertesSignificatives } from "./api.jsx";
import CeMatin from "./pages/CeMatin.jsx";
import AFaire from "./pages/AFaire.jsx";
import Dispositif from "./pages/Dispositif.jsx";
import SecteurQV from "./pages/SecteurQV.jsx";
import Radar from "./pages/Radar.jsx";
import Accueil from "./pages/Accueil.jsx";
import Secteur from "./pages/Secteur.jsx";

// =====================================================================
// v5 — LA NAVIGATION SE RÉDUIT À TROIS QUESTIONS.
//
// La v4 exposait dix entrées : quatre écrans, cinq marchés, deux pages de
// dispositif et une itération précédente conservée « parce que l'historique
// fait partie du résultat ». C'est un raisonnement d'auteur, pas d'usager :
// un dirigeant de PME qui ouvre l'outil ne choisit pas entre dix portes.
//
// Restent trois questions, dans l'ordre où on se les pose :
//   Ce matin      — qu'est-ce qui a changé ?
//   À faire       — sur quoi est-ce que je me positionne, et quand ?
//   Le dispositif — d'où sortent ces chiffres ?
// Les marchés sont un approfondissement, pas une entrée : on y arrive en
// cliquant sur le marché qui intrigue.
//
// Les écrans des itérations précédentes restent ATTEIGNABLES par leur
// adresse — l'historique de la restitution fait partie du résultat rendu —
// mais ils ne prennent plus de place dans le menu.
// =====================================================================

function Navigation() {
  const { D, A, S } = useDonnees();
  const r = D?.referentiel || [];
  const secteurs = [...new Map(r.map(i => [i.sector_code, i.sector_label])).entries()]
    .filter(([c]) => c !== "transversal");

  const retenues = alertesSignificatives(D).retenues;
  const nbMouvements = c => retenues.filter(a => a.sector_code === c).length;
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

      {lien("/ce-matin", "Ce matin")}
      {lien("/a-faire", "À faire", urgentes || null, "rouge")}
      {lien("/dispositif", "Le dispositif")}

      <div className="nav-titre">Approfondir un marché</div>
      {secteurs.map(([c, l]) => (
        <React.Fragment key={c}>{lien("/qv/" + c, l, nbMouvements(c) || null)}</React.Fragment>
      ))}
      {lien("/qv/transversal", "Socle transversal")}

      <div className="nav-pied">
        Prototype de travail de bachelor · HEG Arc<br />
        Scénario semi-automatisé — rien n'est diffusé sans relecture humaine<br />
        Sources ouvertes uniquement<br />
        <span className="nav-archives">
          Itérations précédentes : <a href="#/accueil">v3</a> · <a href="#/radar">radar v4</a>
        </span>
      </div>
    </aside>
  );
}

function Squelette() {
  return (
    <main>
      <div className="squelette" style={{ height: 40, width: 220, marginBottom: 8 }} />
      <div className="squelette" style={{ height: 60, marginBottom: 22 }} />
      <div className="grille g3">
        {[0, 1, 2].map(i => <div key={i} className="squelette" style={{ height: 120 }} />)}
      </div>
      <div className="grille g4" style={{ marginTop: 14 }}>
        {[0, 1, 2, 3].map(i => <div key={i} className="squelette" style={{ height: 190 }} />)}
      </div>
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
        rien — et le dit plutôt que de montrer un écran vide qui passerait pour un
        marché calme.<br />
        <span style={{ fontSize: 12, color: "var(--gris)" }}>{erreur} · {API_URL}</span><br /><br />
        <button className="rafraichir" onClick={recharger}>Réessayer</button>
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

function Coquille() {
  const { D, erreur, chargement, misAJour, recharger } = useDonnees();
  if (chargement && !D) return (<><Entete /><Squelette /></>);
  if (erreur && !D) return (<><Entete /><Erreur erreur={erreur} recharger={recharger} /></>);
  return (
    <>
      <Navigation />
      <main>
        <Routes>
          <Route path="/" element={<Navigate to="/ce-matin" replace />} />
          <Route path="/ce-matin" element={<CeMatin />} />
          <Route path="/a-faire" element={<AFaire />} />
          <Route path="/dispositif" element={<Dispositif />} />
          <Route path="/qv/:code" element={<SecteurQV />} />
          <Route path="/signaux" element={<Radar />} />

          {/* Adresses de la v4, conservées : un lien partagé ne doit pas mourir. */}
          <Route path="/cette-semaine" element={<Navigate to="/ce-matin" replace />} />
          <Route path="/actions" element={<Navigate to="/a-faire" replace />} />
          <Route path="/opportunites" element={<Navigate to="/a-faire" replace />} />
          <Route path="/referentiel" element={<Navigate to="/dispositif" replace />} />
          <Route path="/executions" element={<Navigate to="/dispositif" replace />} />
          <Route path="/radar" element={<Radar />} />

          {/* Itérations précédentes, hors menu mais atteignables. */}
          <Route path="/accueil" element={<Accueil />} />
          <Route path="/secteur/:code" element={<Secteur />} />

          <Route path="*" element={<Navigate to="/ce-matin" replace />} />
        </Routes>

        <footer className="pied">
          <button className="rafraichir" disabled={chargement} onClick={recharger}>
            {chargement ? "Actualisation…" : "Actualiser"}
          </button>
          {misAJour && (
            <span>
              Affichage rafraîchi à {heureCH(misAJour)} · données produites le{" "}
              {D?.genere_le ? new Date(D.genere_le).toLocaleString("fr-CH") : "—"}
            </span>
          )}
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
