// =====================================================================
// MINI — micro-graphiques en SVG.
//
// Volontairement pas ECharts : à cette taille, une bibliothèque de tracé
// coûte plus qu'elle ne rend, et un SVG de vingt lignes reste net sur
// n'importe quel écran. ECharts continue de servir les grands graphiques.
// =====================================================================
import React from "react";
import { nb } from "./api.jsx";

// ---------------------------------------------------------------------
// Courbe de rappel — la forme de la série, pas ses valeurs. Elle répond à
// « ça monte ou ça descend ? » et à rien d'autre : ni axe, ni graduation,
// ce qui interdit de la lire pour ce qu'elle ne dit pas.
// ---------------------------------------------------------------------
export function Sparkline({ points, ton = "accent", hauteur = 34, largeur = 120 }) {
  const v = (points || []).map(p => Number(p.value)).filter(x => !isNaN(x));
  if (v.length < 2) return <div className="spark-vide" title="série trop courte pour être tracée">—</div>;
  const min = Math.min(...v), max = Math.max(...v);
  const etendue = max - min || 1;
  const pas = largeur / (v.length - 1);
  const y = x => hauteur - 3 - ((x - min) / etendue) * (hauteur - 6);
  const d = v.map((x, i) => `${i === 0 ? "M" : "L"}${(i * pas).toFixed(1)},${y(x).toFixed(1)}`).join(" ");
  const aire = `${d} L${largeur},${hauteur} L0,${hauteur} Z`;
  const dernier = v[v.length - 1];
  const couleur = { accent: "#0e7490", vert: "#0f766e", rouge: "#b42318", ambre: "#b54708", gris: "#7b8794" }[ton] || "#0e7490";
  return (
    <svg className="spark" width={largeur} height={hauteur} viewBox={`0 0 ${largeur} ${hauteur}`} aria-hidden="true">
      <path d={aire} fill={couleur} opacity="0.08" />
      <path d={d} fill="none" stroke={couleur} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round" />
      <circle cx={largeur} cy={y(dernier)} r="2.6" fill={couleur} />
    </svg>
  );
}

// ---------------------------------------------------------------------
// Règle de position — où se situe le marché sur l'échelle du score.
//
// Le nombre seul (« 1,20 ») ne dit pas s'il est grand. La règle porte les
// bornes d'interprétation du dispositif : la bande grise centrale est la
// zone « rien à signaler », et l'aiguille s'y place. C'est la seule façon
// honnête d'afficher un écart-type à quelqu'un qui n'en manipule pas.
// ---------------------------------------------------------------------
export function Regle({ score, ton = "gris" }) {
  if (score === null || score === undefined || isNaN(score))
    return <div className="jauge jauge-vide">base insuffisante</div>;
  const borne = 2.5;
  const x = Math.max(-borne, Math.min(borne, Number(score)));
  const pos = ((x + borne) / (2 * borne)) * 100;
  return (
    <div className="jauge" title={`score ${nb(score, 2)} écart-type`}>
      <div className="jauge-piste">
        <div className="jauge-norme" />
        <div className={"jauge-aiguille t-" + ton} style={{ left: pos + "%" }} />
      </div>
      <div className="jauge-bornes"><span>bas</span><span>habituel</span><span>haut</span></div>
    </div>
  );
}

// ---------------------------------------------------------------------
// Barre de proportion — pour les entonnoirs (le tamis des marchés publics),
// où la question est « combien reste-t-il à chaque étage ? ».
// ---------------------------------------------------------------------
export function Entonnoir({ etapes }) {
  const max = Math.max(...etapes.map(e => e.valeur), 1);
  return (
    <div className="entonnoir">
      {etapes.map((e, i) => (
        <div className="ent-ligne" key={i}>
          <div className="ent-lib">{e.libelle}</div>
          <div className="ent-piste">
            <div className={"ent-barre" + (i === etapes.length - 1 ? " ent-final" : "")}
                 style={{ width: Math.max(1.5, (e.valeur / max) * 100) + "%" }} />
          </div>
          <div className="ent-val">{nb(e.valeur)}</div>
        </div>
      ))}
    </div>
  );
}
