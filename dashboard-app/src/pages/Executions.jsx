import React from "react";
import { useDonnees, pct } from "../api.jsx";

export default function Executions() {
  const { D } = useDonnees();
  const rev = D.revisions || [];
  return (
    <div className="page">
      <div className="topbar"><h1>Exécutions</h1></div>
      <div className="note" style={{ marginBottom: 12 }}>
        Chaque collecte ajoute ses observations sans écraser les précédentes : c'est l'écart entre
        exécutions qui fait la tendance.
      </div>
      <div className="carte">
        <table>
          <thead>
            <tr><th>Run</th><th>Exécuté le</th><th>Statut</th><th>Valeurs écrites</th><th>Indicateurs couverts</th></tr>
          </thead>
          <tbody>
            {(D.sante_runs || []).map(s => (
              <tr key={s.run_id}>
                <td>{s.run_id}</td>
                <td>{new Date(s.executed_at).toLocaleString("fr-CH")}</td>
                <td>{s.status}</td>
                <td>{s.valeurs_ecrites}</td>
                <td>{s.indicateurs_couverts} / {s.indicateurs_certifies_attendus}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <h2>Révisions constatées par la source</h2>
      <div className="carte">
        {rev.length === 0 && (
          <div className="note">
            Aucune révision repérée sur {Number(D.comparaisons_runs || 0)} comparaison(s) : aucune
            source n'a corrigé une valeur déjà publiée entre deux collectes. Le mécanisme tourne, il
            n'a simplement encore rien attrapé.
          </div>
        )}
        {rev.length > 0 && (
          <table>
            <thead>
              <tr><th>Indicateur</th><th>Période</th><th>Zone</th><th>Run</th><th>Écart</th></tr>
            </thead>
            <tbody>
              {rev.map((e, i) => (
                <tr key={i}>
                  <td>{e.indicator_id}</td><td>{e.period}</td><td>{e.geo}</td>
                  <td>{e.run_id}</td><td>{pct(e.ecart_pct)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
