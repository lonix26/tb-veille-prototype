import React, { useEffect, useRef } from "react";
import * as echarts from "echarts";
import { nb, nomZone } from "./api.jsx";

// REVUE DU 02.09.2026 : l'instance ECharts n'est créée qu'UNE fois, au
// montage. Auparavant chaque effet faisait init() puis dispose() au nettoyage,
// et les appelants passant un littéral neuf à chaque rendu, le moindre
// re-rendu du parent (« voir toutes les zones », un rechargement) détruisait
// le graphique : zoom et sélection de légende perdus. L'option est désormais
// posée sur l'instance vivante ; `replaceMerge` remplace les séries sans
// toucher à l'état d'interaction.
function useInstance(ref) {
  const inst = useRef(null);
  useEffect(() => {
    if (!ref.current) return;
    const ch = echarts.init(ref.current);
    inst.current = ch;
    const ro = new ResizeObserver(() => ch.resize());
    ro.observe(ref.current);
    return () => { ro.disconnect(); ch.dispose(); inst.current = null; };
  }, [ref]);
  return inst;
}

// Format compact des axes : 180 000 000 000 se lit mal, « 180 mrd » se lit.
const fmtAxe = v => {
  const a = Math.abs(v);
  if (a >= 1e9) return (v / 1e9).toLocaleString("fr-CH", { maximumFractionDigits: 1 }) + " mrd";
  if (a >= 1e6) return (v / 1e6).toLocaleString("fr-CH", { maximumFractionDigits: 1 }) + " mio";
  if (a >= 1e4) return (v / 1e3).toLocaleString("fr-CH", { maximumFractionDigits: 0 }) + " k";
  return String(v);
};

// Graphique de séries temporelles — survol (valeurs exactes), zoom à la
// molette et par glissière, légende cliquable pour comparer les zones.
// props :
//   series   : { cle_zone: [{period, value}, …], … }
//   refLine  : niveau de référence (moyenne mobile) — série unique seulement
//   refLabel : libellé de la référence
//   zoom     : afficher la glissière de zoom
//   hauteur  : px (défaut 240)
// Treemap des parts — la lecture de concentration d'un marché en un
// coup d'œil : la surface EST la part. Survol : valeur, part, Δ part.
export function TreemapParts({ items, hauteur = 250 }) {
  const ref = useRef(null);
  const inst = useInstance(ref);
  useEffect(() => {
    const ch = inst.current;
    if (!ch) return;
    if (!items || !items.length) { ch.clear(); return; }
    ch.setOption({
      tooltip: {
        formatter: p => {
          const d = p.data || {};
          let t = "<b>" + p.name + "</b><br/>" + nb(d.value);
          if (d.part !== null && d.part !== undefined) t += "<br/>part : " + nb(d.part, 1) + " %";
          if (d.dPart !== null && d.dPart !== undefined) t += "<br/>Δ part : " + (d.dPart > 0 ? "+" : "") + nb(d.dPart, 1) + " pt";
          return t;
        }
      },
      series: [{
        type: "treemap", roam: false, nodeClick: false, width: "100%", height: "100%",
        breadcrumb: { show: false },
        itemStyle: { borderColor: "#fff", borderWidth: 2, gapWidth: 2, borderRadius: 4 },
        label: {
          formatter: p => (p.data.part !== null && p.data.part !== undefined)
            ? p.name + "\n" + nb(p.data.part, 1) + " %" : p.name,
          fontSize: 11, lineHeight: 15
        },
        levels: [{ color: ["#0e7490", "#155e75", "#0f766e", "#2286a5", "#b54708", "#5925dc", "#475467", "#7b8794", "#98a2b3"] }],
        data: items.map(i => ({ name: i.name, value: Math.max(i.value, 0), part: i.part, dPart: i.dPart }))
      }]
    }, { replaceMerge: ["series"] });
  }, [inst, items]);
  return <div ref={ref} style={{ height: hauteur, marginTop: 10 }} />;
}

export default function Chart({ series, refLine, refLabel, zoom, hauteur = 240 }) {
  const ref = useRef(null);
  const inst = useInstance(ref);

  useEffect(() => {
    const ch = inst.current;
    if (!ch) return;
    const noms = Object.keys(series || {}).filter(n => (series[n] || []).length >= 2);
    if (!noms.length) { ch.clear(); return; }
    const periodes = [...new Set(noms.flatMap(n => series[n].map(p => p.period)))].sort();
    const lignes = noms.map((n, i) => ({
      name: nomZone(n),
      type: "line",
      showSymbol: false,
      connectNulls: false,
      emphasis: { focus: noms.length > 1 ? "series" : "none" },
      data: periodes.map(p => {
        const x = series[n].find(q => q.period === p);
        // Un point présent mais NUL reste un trou (null * 100 vaudrait 0).
        return x && x.value !== null && x.value !== undefined ? Math.round(x.value * 100) / 100 : null;
      }),
      ...(i === 0 && refLine !== undefined && noms.length === 1
        ? {
            markLine: {
              silent: true, symbol: "none",
              lineStyle: { type: "dashed", color: "#98a2b3" },
              label: { formatter: refLabel || "moyenne mobile", position: "insideStartTop",
                       fontSize: 10, color: "#7b8794" },
              data: [{ yAxis: refLine }]
            }
          }
        : {})
    }));
    ch.setOption({
      color: ["#0e7490", "#b54708", "#5925dc", "#0f766e", "#b42318", "#475467"],
      grid: { left: 8, right: 14, top: noms.length > 1 ? 32 : 14, bottom: zoom ? 46 : 24, containLabel: true },
      tooltip: { trigger: "axis", valueFormatter: v => (v === null || v === undefined ? "—" : nb(v)) },
      // Toujours déclarée (show bascule) : en fusion d'option, `undefined`
      // ne retirerait pas une légende posée au rendu précédent.
      legend: { show: noms.length > 1, top: 0, left: 0, textStyle: { fontSize: 11, color: "#43505e" },
                icon: "roundRect", itemWidth: 12, itemHeight: 5 },
      xAxis: {
        type: "category", data: periodes,
        axisLabel: { fontSize: 10, color: "#7b8794" },
        axisLine: { lineStyle: { color: "#e4e8ee" } }, axisTick: { show: false }
      },
      yAxis: {
        type: "value", scale: true,
        axisLabel: { fontSize: 10, color: "#7b8794", formatter: fmtAxe },
        splitLine: { lineStyle: { color: "#eef1f4" } }
      },
      dataZoom: zoom
        ? [{ type: "inside" }, { type: "slider", height: 16, bottom: 8, borderColor: "#e4e8ee" }]
        : [{ type: "inside" }],
      series: lignes
    }, { replaceMerge: ["series"] });
  }, [inst, series, refLine, refLabel, zoom]);

  return <div ref={ref} style={{ height: hauteur, marginTop: 12 }} />;
}
