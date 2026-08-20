import React, { createContext, useContext, useEffect, useState, useCallback } from "react";

// ---------------------------------------------------------------------
// Accès aux données — UNE interface : l'API de restitution n8n (lecture
// seule). Aucune donnée en dur ; base coupée, l'application l'affiche.
// ---------------------------------------------------------------------
export const API_URL =
  import.meta.env.VITE_API_URL || "http://localhost:5678/webhook/veille/donnees";

const Ctx = createContext(null);

export function FournisseurDonnees({ children }) {
  const [donnees, setDonnees] = useState(null);
  const [erreur, setErreur] = useState(null);
  const [chargement, setChargement] = useState(true);
  const [misAJour, setMisAJour] = useState(null);

  const recharger = useCallback(async () => {
    setChargement(true);
    setErreur(null);
    try {
      const r = await fetch(API_URL, { cache: "no-store" });
      if (!r.ok) throw new Error("HTTP " + r.status);
      setDonnees(await r.json());
      setMisAJour(new Date());
    } catch (e) {
      setErreur(String(e));
    } finally {
      setChargement(false);
    }
  }, []);

  useEffect(() => { recharger(); }, [recharger]);

  return (
    <Ctx.Provider value={{ D: donnees, erreur, chargement, misAJour, recharger }}>
      {children}
    </Ctx.Provider>
  );
}

export const useDonnees = () => useContext(Ctx);

// ---------------------------------------------------------------------
// Aides de formatage (fr-CH) et de lecture — mêmes conventions que la
// restitution précédente, garanties conservées.
// ---------------------------------------------------------------------
export const nb = (v, dMax) =>
  v === null || v === undefined || isNaN(v)
    ? "—"
    : new Intl.NumberFormat("fr-CH", {
        maximumFractionDigits: dMax ?? (Math.abs(v) >= 100 ? 0 : 2)
      }).format(v);

export const pct = v =>
  v === null || v === undefined || isNaN(v)
    ? "—"
    : (v > 0 ? "+" : "") +
      new Intl.NumberFormat("fr-CH", { maximumFractionDigits: 1 }).format(v) + " %";

export const clsVar = v =>
  v === null || v === undefined || isNaN(v) ? "neutre" : v > 0 ? "hausse" : v < 0 ? "baisse" : "neutre";

export const dateCH = s => (s ? new Date(s).toLocaleDateString("fr-CH") : "");
export const heureCH = d => (d ? d.toLocaleTimeString("fr-CH", { hour: "2-digit", minute: "2-digit" }) : "");

// Markdown minimal des commentaires exécutifs (gras + sauts de ligne).
export function MarkdownLeger({ texte }) {
  const morceaux = String(texte ?? "").split(/\*\*(.+?)\*\*/g);
  return (
    <>
      {morceaux.map((m, i) =>
        i % 2 === 1 ? <strong key={i}>{m}</strong> :
          m.split("\n").map((l, j, arr) => (
            <React.Fragment key={i + "-" + j}>{l}{j < arr.length - 1 && <br />}</React.Fragment>
          ))
      )}
    </>
  );
}

// ---------------------------------------------------------------------
// Agrégats hors classements — convention héritée de la restitution v2/v3 ;
// la résolution propre reste la nomenclature géographique en base (§ 10.6).
// ---------------------------------------------------------------------
const AGREGATS = new Set([
  "WORLD", "W00", "OWID_WRL", "GLOBAL",
  "AFR", "AMR", "EMR", "EUR", "SEAR", "WPR",
  "World", "Europe", "European Union", "Advanced Economies",
  "Developing Economies excl. China", "Africa", "Asia Pacific",
  "Latin America", "Middle East", "Oceania", "Rest of the world",
  "EU27", "EU27_2020", "G20", "CH"
]);
export const estAgregat = g => AGREGATS.has(String(g)) || String(g).startsWith("WB_");

const NOMS_ZONES = {
  WORLD: "monde", W00: "monde", EU27: "UE-27", EU27_2020: "UE-27",
  CH: "Suisse", G20: "G20", CHF_USD: "CHF/USD", CHF_EUR: "CHF/EUR"
};
export const nomZone = g => NOMS_ZONES[g] || g;

// Lectures dérivées de la charge utile.
export const serieDe = (D, id, geo) =>
  (D?.valeurs || [])
    .filter(v => v.indicator_id === id && (geo === undefined || v.geo === geo))
    .sort((a, b) => String(a.period).localeCompare(String(b.period)));

export const zonesDe = (D, id) => [...new Set(serieDe(D, id).map(v => v.geo))];

export const metrDe = (D, id, geo) =>
  (D?.metriques || []).find(m => m.indicator_id === id && (geo === undefined || m.geo === geo));

export function BadgeStatut({ statut }) {
  if (!statut) return null;
  const carte = {
    valide_source: ["e-vert", "validé par la source"],
    valide_humain: ["e-vert", "validé humainement"],
    pre_valide_consensus: ["e-ambre", "pré-validé (consensus)"]
  };
  const [cls, lbl] = carte[statut] || ["e-gris", statut];
  return <span className={"etq " + cls}>{lbl}</span>;
}
