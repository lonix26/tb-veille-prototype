import React, { useState } from "react";
import { useDonnees } from "../api.jsx";

export default function Referentiel() {
  const { D } = useDonnees();
  const [filtre, setFiltre] = useState("");
  const r = D.referentiel || [];
  const f = filtre.trim().toLowerCase();
  const lignes = r.filter(i =>
    !f ||
    [i.indicator_id, i.sector_label, i.label, i.questions, i.source_organisation]
      .join(" ").toLowerCase().includes(f)
  );

  return (
    <div className="page">
      <div className="topbar">
        <h1>Référentiel</h1>
        <input
          className="filtre"
          placeholder="Filtrer (code, libellé, source, question…)"
          value={filtre}
          onChange={e => setFiltre(e.target.value)}
        />
      </div>

      <div className="carte">
        <div style={{ fontSize: 12, fontWeight: 650, marginBottom: 8 }}>
          Bilan. Ces décomptes viennent directement de la base : ce sont eux qui font référence.
        </div>
        <table>
          <thead>
            {/* AUDIT DU 01.09.2026 : « officielles » était FAUX — la colonne compte les
                hard, dont H7/H8/H9 (Fédération horlogère, une association) et d'autres
                sources professionnelles. « Hard » = collecté par code, sans jugement
                sur le statut du producteur — la distinction du § 8.6.4. */}
            <tr><th>Secteur</th><th>Total</th><th>Certifiés</th><th>dont hard (par code)</th><th>dont composites</th><th>À confirmer</th></tr>
          </thead>
          <tbody>
            {(D.bilan_referentiel || []).map((b, i) => (
              <tr key={i}>
                <td>{b.sector_code ? b.sector_code : <strong>Total</strong>}</td>
                <td>{b.total}</td><td>{b.certifies}</td><td>{b.certifies_hard}</td>
                <td>{b.certifies_composite}</td><td>{b.a_confirmer}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="carte" style={{ marginTop: 14 }}>
        <div style={{ fontSize: 12, fontWeight: 650, marginBottom: 8 }}>
          {lignes.length} indicateur{lignes.length > 1 ? "s" : ""}{f ? ` (filtre : « ${filtre} »)` : ""}
        </div>
        <table>
          <thead>
            <tr><th>Code</th><th>Secteur</th><th>Indicateur</th><th>Questions</th><th>Source</th><th>Catégorie</th><th>Instrumentation</th></tr>
          </thead>
          <tbody>
            {lignes.map(i => (
              <tr key={i.indicator_id}>
                <td><strong>{i.indicator_id}</strong></td>
                <td>{i.sector_label}</td>
                <td>{i.label}</td>
                <td>{i.questions || "n.d."}</td>
                <td>{i.source_organisation}</td>
                <td>{i.category === "hard" ? "hard (par code)" : i.category === "composite" ? "composite" : (i.category || "n.d.")}</td>
                <td>
                  {i.observations > 0
                    ? `${i.observations} obs. · ${i.p_min} → ${i.p_max}`
                    : <span className="etq e-gris">non instrumenté</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
