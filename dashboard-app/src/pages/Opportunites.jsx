import React from "react";
import { useDonnees, dateCH, nb, LienSource } from "../api.jsx";

// =====================================================================
// ÉCRAN 4 — « Opportunités ». Question : où prospecter cette semaine ?
// C'est la réponse à l'objectif posé en séance n° 1 (« identifier de
// nouvelles opportunités commerciales »).
// N'affiche QUE des items examinés par un humain : un item non examiné
// n'est pas une opportunité, c'est une ligne de file d'attente.
// =====================================================================

export default function Opportunites() {
  const { O, erreursV4 } = useDonnees();

  if (!O) return (
    <div className="page"><div className="topbar"><h1>Opportunités</h1></div>
      <div className="vide"><strong>Le point de lecture « opportunités » ne répond pas.</strong><br />
        <span style={{ fontSize: 12 }}>{erreursV4?.["/opportunites"]}</span></div></div>
  );

  const items = O.opportunites || [];
  const acheteur = o => {
    const a = o.acheteur;
    if (!a) return "—";
    if (typeof a === "string") return a;
    const v = Object.values(a);
    return Array.isArray(v[0]) ? v[0][0] : (v[0] || "—");
  };

  return (
    <div className="page">
      <div className="topbar">
        <h1>Opportunités</h1>
        <div className="meta">{items.length} avis retenu{items.length > 1 ? "s" : ""} · {nb(O.examines_total, 0)} item(s) examiné(s)</div>
      </div>

      <p className="lecture">
        Les avis de marchés publics retenus à l'examen. Chaque ligne mène à l'avis officiel :
        ce n'est pas une recommandation, c'est une piste vérifiable.
      </p>

      {items.length === 0 ? (
        <div className="vide">
          <strong>Aucun avis examiné à ce jour.</strong><br />
          {nb(O.en_attente, 0)} item(s) de flux attendent l'examen humain. Tant qu'un avis n'a
          pas été lu et qualifié par le veilleur, il ne figure pas ici — l'écran ne présente
          pas une sélection automatique comme une opportunité.
        </div>
      ) : (
        <table className="tableau">
          <thead>
            <tr>
              <th>Publié</th><th>Secteur</th><th>Avis</th><th>Acheteur</th>
              <th>Décision</th><th>Examiné par</th><th>Source</th>
            </tr>
          </thead>
          <tbody>
            {items.map(o => (
              <tr key={o.item_id}>
                <td className="nowrap">{dateCH(o.date_publication)}</td>
                <td><span className="etq e-gris">{o.sector_label || o.sector_code}</span></td>
                <td className="td-titre">{o.titre}</td>
                <td>{acheteur(o)}</td>
                <td>
                  <span className={"etq " + (o.decision === "promu_signal" ? "e-violet" : "e-ambre")}>
                    {o.decision === "promu_signal" ? "promu en signal" : "contexte"}
                  </span>
                  {o.note_examen && <div className="td-note">« {o.note_examen} »</div>}
                </td>
                <td className="nowrap">{o.decide_par}<br /><small>{dateCH(o.decide_le)}</small></td>
                <td><LienSource href={o.url}>avis</LienSource></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <div className="mention-permanente">
        Source : TED, avis de marchés publics de l'Union européenne. Sélection ordonnée par
        triage automatique, <strong>examinée et qualifiée humainement</strong> avant affichage.
        Aucun avis n'atteint cet écran sans décision nominative et datée.
      </div>
    </div>
  );
}
