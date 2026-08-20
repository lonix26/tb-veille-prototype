import React, { useEffect, useRef } from "react";
import * as echarts from "echarts";
import { nb, nomZone } from "./api.jsx";

// Graphique de séries temporelles — survol (valeurs exactes), zoom à la
// molette et par glissière, légende cliquable pour comparer les zones.
// props :
//   series   : { cle_zone: [{period, value}, …], … }
//   refLine  : niveau de référence (moyenne mobile) — série unique seulement
//   refLabel : libellé de la référence
//   zoom     : afficher la glissière de zoom
//   hauteur  : px (défaut 240)
export default function Chart({ series, refLine, refLabel, zoom, hauteur = 240 }) {
  const ref = useRef(null);

  useEffect(() => {
    const noms = Object.keys(series || {}).filter(n => (series[n] || []).length >= 2);
    if (!ref.current || !noms.length) return;
    const ch = echarts.init(ref.current);
    const periodes = [...new Set(noms.flatMap(n => series[n].map(p => p.period)))].sort();
    const lignes = noms.map((n, i) => ({
      name: nomZone(n),
      type: "line",
      showSymbol: false,
      connectNulls: false,
      emphasis: { focus: noms.length > 1 ? "series" : "none" },
      data: periodes.map(p => {
        const x = series[n].find(q => q.period === p);
        return x ? Math.round(x.value * 100) / 100 : null;
      }),
      ...(i === 0 && refLine !== undefined && noms.length === 1
        ? {
            markLine: {
              silent: true, symbol: "none",
              lineStyle: { type: "dashed", color: "#98a2b3" },
              label: { formatter: refLabel || "moyenne mobile", fontSize: 10, color: "#7b8794" },
              data: [{ yAxis: refLine }]
            }
          }
        : {})
    }));
    ch.setOption({
      color: ["#0e7490", "#b54708", "#5925dc", "#0f766e", "#b42318", "#475467"],
      grid: { left: 8, right: 14, top: noms.length > 1 ? 32 : 14, bottom: zoom ? 46 : 24, containLabel: true },
      tooltip: { trigger: "axis", valueFormatter: v => (v === null || v === undefined ? "—" : nb(v)) },
      legend: noms.length > 1
        ? { top: 0, left: 0, textStyle: { fontSize: 11, color: "#43505e" }, icon: "roundRect", itemWidth: 12, itemHeight: 5 }
        : undefined,
      xAxis: {
        type: "category", data: periodes,
        axisLabel: { fontSize: 10, color: "#7b8794" },
        axisLine: { lineStyle: { color: "#e4e8ee" } }, axisTick: { show: false }
      },
      yAxis: {
        type: "value", scale: true,
        axisLabel: { fontSize: 10, color: "#7b8794" },
        splitLine: { lineStyle: { color: "#eef1f4" } }
      },
      dataZoom: zoom
        ? [{ type: "inside" }, { type: "slider", height: 16, bottom: 8, borderColor: "#e4e8ee" }]
        : [{ type: "inside" }],
      series: lignes
    });
    const ro = new ResizeObserver(() => ch.resize());
    ro.observe(ref.current);
    return () => { ro.disconnect(); ch.dispose(); };
  }, [series, refLine, refLabel, zoom]);

  return <div ref={ref} style={{ height: hauteur, marginTop: 12 }} />;
}
