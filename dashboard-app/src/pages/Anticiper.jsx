import React, { useMemo } from "react";
import { useDonnees, nb, pct } from "../api.jsx";
import Chart from "../Chart.jsx";
import { enLettres, phrasePeriode } from "../phrases.jsx";

// =====================================================================
// ANTICIPER — les indicateurs dérivés : ce que la base sait dire de plus
// que ses séries brutes.
//
// Écran né d'une analyse des 122 000 observations conduite le 26.08, en
// réponse à la demande de la séance 4 (« développer de nouveaux
// indicateurs synthétiques ») restée sans suite. Trois dérivés retenus
// parce qu'ils DISCRIMINENT sur données réelles ; les candidats muets ont
// été écartés (l'effet de gamme horloger, sans tendance nette, reste en
// base sans écran).
//
//   1. L'indice de diffusion — la synthèse la plus honnête possible : on
//      compte des directions, jamais des grandeurs. Aucune unité mélangée,
//      aucune pondération : la critique qui a retiré le score de l'écran
//      ne s'applique pas ici.
//   2. La tension de chaîne — le § 8.6 transformé en série : l'amont
//      contre la production adressable, chacun face à sa propre moyenne.
//   3. L'exposition américaine horlogère — la série qui VALIDE le
//      dispositif : le choc douanier de 2025, événement fondateur de la
//      problématique, s'y lit intégralement.
// =====================================================================

const NOMS = { horlogerie: "Horlogerie", medical: "Médical",
               automobile: "Automobile", aerospatial: "Aérospatial" };
const COUPLES = {
  automobile: "immatriculations (A2) vs équipementiers (A6)",
  medical: "avis publics (M7) vs production C32 (M2)",
  aerospatial: "avis publics (S7) vs production C30.3 (S8)",
  horlogerie: "volume mécanique (H9) vs production UE C26.52 (H6)"
};

export default function Anticiper() {
  const { S, D, erreursV4 } = useDonnees();

  // ---------- 1. Diffusion : compté à l'affichage depuis la vitrine ----------
  const diffusion = useMemo(() => {
    const ref = D?.referentiel || [];
    // CORRECTION DU 02.09.2026 (UI-4) : un sens NUL n'est pas un sens favorable.
    // `?? 1 || 1` comptait A9, A10, H9 (sens 0, « à interpréter » sur les pages
    // Secteur) comme favorables. Les indicateurs sans sens déclaré sont exclus
    // du décompte et comptés à part.
    const sens = id => Number(ref.find(r => r.indicator_id === id)?.sens_favorable ?? 0) || 0;
    const tous = (S?.vitrine || []).filter(v => v.ecart_a_la_moyenne_pct !== null);
    const neutres = tous.filter(v => sens(v.indicator_id) === 0);
    const rows = tous.filter(v => sens(v.indicator_id) !== 0);
    const fav = rows.filter(v => Number(v.ecart_a_la_moyenne_pct) * sens(v.indicator_id) > 0);
    const defav = rows.filter(v => Number(v.ecart_a_la_moyenne_pct) * sens(v.indicator_id) < 0);
    const nuls = rows.length - fav.length - defav.length;
    return { n: rows.length, fav, defav, neutres, nuls };
  }, [S, D]);

  // ---------- 2. Tension : séries par marché ----------
  const tensions = useMemo(() => {
    const m = new Map();
    for (const t of S?.tension_chaine || []) {
      if (!m.has(t.marche)) m.set(t.marche, []);
      m.get(t.marche).push({ period: t.period, value: Number(t.tension) });
    }
    for (const v of m.values()) v.sort((a, b) => String(a.period).localeCompare(String(b.period)));
    return m;
  }, [S]);

  // ---------- 3. Exposition américaine ----------
  const expo = useMemo(() => {
    const e = S?.exposition_horlogere || [];
    return {
      usa: e.map(x => ({ period: x.period, value: Number(x.part_usa_pct) })),
      top3: e.map(x => ({ period: x.period, value: Number(x.top3_pct) })),
      dernier: e[e.length - 1]
    };
  }, [S]);

  if (!S) return (
    <div className="page"><div className="vide">
      <strong>La lecture « santé » ne répond pas.</strong><br />
      <span style={{ fontSize: 12 }}>{erreursV4?.["/sante"]}</span>
    </div></div>
  );

  const metier = new Set(["T7", "T8", "A6", "S7"]);
  const defavMetier = diffusion.defav.filter(v => metier.has(v.indicator_id));

  return (
    <div className="page">
      <header className="tete">
        <span className="tete-date">Indicateurs dérivés · calculés depuis le registre, jamais saisis</span>
      </header>
      <h1 className="verdict">
        {diffusion.n
          ? `${enLettres(diffusion.fav.length).charAt(0).toUpperCase() + enLettres(diffusion.fav.length).slice(1)} des ${enLettres(diffusion.n)} indicateurs sont au-dessus de leur norme.`
          : "Anticiper"}
      </h1>

      {/* ---------- 1. Diffusion ---------- */}
      <div className="carte" style={{ marginBottom: 16 }}>
        <h3 className="bloc-titre">L'indice de diffusion, et ce qu'il cache</h3>
        <p className="bloc-intro">
          On compte des <strong>directions</strong>, jamais des grandeurs : combien d'indicateurs
          suivis sont au-dessus de leur propre moyenne, dans leur sens favorable. Aucune unité
          mélangée, aucune pondération.
          {(diffusion.neutres.length > 0 || diffusion.nuls > 0) && (
            <> Non comptés : {diffusion.neutres.length > 0 && <>{diffusion.neutres.length} indicateur{diffusion.neutres.length > 1 ? "s" : ""} sans
            sens déclaré ({diffusion.neutres.map(v => v.indicator_id).join(", ")}), à interpréter</>}
            {diffusion.neutres.length > 0 && diffusion.nuls > 0 && " ; "}
            {diffusion.nuls > 0 && <>{diffusion.nuls} à écart nul</>}.</>
          )}
        </p>
        {diffusion.defav.length > 0 && (
          <p className="bloc-intro" style={{ marginBottom: 0 }}>
            Les {enLettres(diffusion.defav.length)} défavorables :{" "}
            {diffusion.defav.map((v, i) => (
              <React.Fragment key={v.indicator_id}>
                {i > 0 && " · "}<strong>{v.indicator_id}</strong> ({v.label.split("(")[0].trim().toLowerCase()}, {pct(v.ecart_a_la_moyenne_pct)})
              </React.Fragment>
            ))}.
            {/* AUDIT DU 01.09.2026 : l'énumération était RÉDIGÉE (« le carnet,
                l'usinage… ») et a menti dès que T8 a changé de camp — elle est
                désormais calculée depuis la liste elle-même. */}
            {defavMetier.length >= 3 && (
              <> <strong>Et c'est la lecture qui compte : {defavMetier.length} des{" "}
              {diffusion.defav.length} défavorables touchent le métier</strong>{" "}
              ({defavMetier.map(v => v.indicator_id).join(", ")}), c'est-à-dire l'étage que la
              sous-traitance peut réellement viser. Un écart durable entre cet étage et les
              marchés finaux précède les retournements de charge, dans un sens comme dans
              l'autre.</>
            )}
          </p>
        )}
      </div>

      {/* ---------- 2. Tension de chaîne ---------- */}
      <h2 className="section">La tension de chaîne : l'amont tire-t-il plus vite que la production ?</h2>
      <p className="bloc-intro">
        Pour chaque marché : la position de l'<strong>amont</strong> (demande finale ou signaux
        d'avance) moins celle de la <strong>production adressable</strong>, chacune mesurée contre
        sa propre moyenne douze mois. <strong>Tension positive = l'amont tire, la production ne
        suit pas encore : de la charge à venir pour la sous-traitance.</strong> C'est le constat
        fondateur de la grille adressable (§ 8.6), transformé en série.
      </p>
      <div className="tuiles" style={{ gridTemplateColumns: "repeat(auto-fit,minmax(320px,1fr))", marginBottom: 8 }}>
        {[...tensions.entries()].map(([marche, serie]) => {
          const d = serie[serie.length - 1];
          return (
            <div className="fiche-ind" key={marche} style={{ marginBottom: 0 }}>
              <div className="fi-tete">
                <h3>{NOMS[marche] || marche}</h3>
                <span className={"etq " + (d && d.value > 5 ? "e-ok" : d && d.value < -5 ? "e-attn" : "e-gris")}>
                  {d ? `${d.value > 0 ? "+" : ""}${nb(d.value)} pt (${phrasePeriode(d.period)})` : "n.d."}
                </span>
              </div>
              <Chart series={{ tension: serie }} hauteur={140} />
              <p className="fi-src">{COUPLES[marche]}</p>
            </div>
          );
        })}
      </div>

      {/* ---------- 3. Exposition américaine ---------- */}
      <h2 className="section">L'exposition américaine du débouché horloger</h2>
      <div className="carte">
        <p className="bloc-intro">
          La part des États-Unis dans les exportations horlogères suisses, et le poids des trois
          premiers débouchés. <strong>Le choc douanier de 2025, l'événement qui a motivé ce
          travail, se lit intégralement dans cette série</strong> :
          {/* AUDIT DU 01.09.2026 : les chiffres étaient EN DUR (34,1/10,3/27,1) et
              avaient dérivé de la base (33,7/10,1/26,7 après les runs suivants) —
              la faute exacte que « la lecture est calculée » interdit. La phrase
              raconte désormais la forme ; la courbe ci-dessous porte les valeurs. */}
          constitution de stocks au printemps 2025, effondrement à l'automne,
          remontée à {expo.dernier ? nb(expo.dernier.part_usa_pct) : "n.d."} % en{" "}
          {expo.dernier ? phrasePeriode(expo.dernier.period) : "n.d."}. Un dispositif de veille qui
          voit l'événement qui l'a motivé : c'est sa meilleure validation sur pièce.
        </p>
        <Chart series={{ "part des États-Unis (%)": expo.usa, "trois premiers débouchés (%)": expo.top3 }}
               zoom hauteur={230} />
        <p className="fi-src">
          Calculé depuis H1 (Comtrade). La concentration à{" "}
          {expo.dernier ? nb(expo.dernier.top3_pct) : "—"} % sur trois débouchés est un risque en
          soi : ce qui s'est fermé en 2025 peut se refermer.
        </p>
      </div>
    </div>
  );
}
