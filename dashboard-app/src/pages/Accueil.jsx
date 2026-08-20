import React from "react";
import { useNavigate } from "react-router-dom";
import { useDonnees, nb, pct, clsVar, nomZone } from "../api.jsx";
import { Synthetique } from "./Secteur.jsx";

export default function Accueil() {
  const { D } = useDonnees();
  const navigate = useNavigate();
  const r = D.referentiel || [];
  const certifies = r.filter(i => i.status === "certifie");
  const collectes = certifies.filter(i => i.observations > 0);
  const alertes = D.alertes || [];
  const diff = alertes.filter(a => a.diffusable);
  const run = D.run_courant || {};
  const totalObs = r.reduce((s, i) => s + Number(i.observations || 0), 0);
  const secteurs = [...new Map(r.map(i => [i.sector_code, i.sector_label])).entries()]
    .filter(([c]) => c !== "transversal");

  return (
    <div className="page">
      <div className="topbar">
        <h1>Vue d'ensemble</h1>
        <div className="meta">run {run.run_id ?? "—"} ({run.status ?? ""})</div>
      </div>

      <div className="grille g4">
        <div className="carte kpi">
          <div className="k-l">Indicateurs en collecte</div>
          <div className="k-v">{collectes.length}<small>/{certifies.length} certifiés</small></div>
          <div className="k-s">{Number(totalObs).toLocaleString("fr-CH")} observations au registre</div>
        </div>
        <div className="carte kpi">
          <div className="k-l">Franchissements diffusables</div>
          <div className="k-v">{diff.length}</div>
          <div className="k-s">{alertes.length - diff.length} retenus (statut insuffisant)</div>
        </div>
        <div className="carte kpi">
          <div className="k-l">Commentaires validés</div>
          <div className="k-v">{(D.commentaires || []).length}</div>
          <div className="k-s">{Number(D.commentaires_en_attente || 0)} en attente de validation</div>
        </div>
        <div className="carte kpi">
          <div className="k-l">Révisions constatées</div>
          <div className="k-v">{(D.revisions || []).length}</div>
          <div className="k-s">sur {Number(D.comparaisons_runs || 0)} comparaisons entre runs</div>
        </div>
      </div>

      <h2>Secteurs</h2>
      <div className="grille g4">
        {secteurs.map(([c, lbl]) => {
          const inds = r.filter(i => i.sector_code === c);
          const n = inds.filter(i => i.observations > 0).length;
          const al = alertes.filter(a => a.sector_code === c && a.diffusable).length;
          const com = (D.commentaires || []).find(k => k.sector_code === c);
          return (
            <div key={c} className="carte kpi cliquable" onClick={() => navigate("/secteur/" + c)}>
              <div className="k-l">{lbl}</div>
              <div className="k-v" style={{ fontSize: 22 }}>{n}<small>/{inds.length} suivis</small></div>
              <div className="k-s">
                {al
                  ? <span className="etq e-rouge">{al} franchissement{al > 1 ? "s" : ""}</span>
                  : <span className="etq e-gris">rien d'inhabituel</span>}
                {com && <span className="etq e-violet">commentaire validé</span>}
              </div>
            </div>
          );
        })}
      </div>

      <h2>À examiner</h2>
      <div className="grille g2">
        <div className="carte">
          <div style={{ fontSize: 12, fontWeight: 650, marginBottom: 4 }}>Franchissements de seuil</div>
          {diff.length === 0 && (
            <div className="note">Aucun franchissement diffusable : rien ne sort de l'ordinaire des séries suivies.</div>
          )}
          {diff.slice(0, 6).map((a, i) => (
            <div className="alerte" key={i}>
              <span className="a-pt" style={{ background: "var(--rouge)" }} />
              <div>
                <strong>{a.indicator_id}</strong> {a.indicator_label} — {nomZone(a.geo)}, {a.period} :{" "}
                <span className={clsVar(a.glissement_annuel_pct ?? a.variation_periode_pct)}>
                  {pct(a.glissement_annuel_pct ?? a.variation_periode_pct)}
                </span>{" "}
                (seuil {nb(a.seuil_materialite_pct, 1)} %)
              </div>
            </div>
          ))}
        </div>
        <Synthetique />
      </div>
    </div>
  );
}
