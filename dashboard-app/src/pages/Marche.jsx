import React, { useMemo } from "react";
import { useParams } from "react-router-dom";
import { useDonnees, nb, pct, dateCH, LienSource, MarkdownLeger, estAgregat, nomZone } from "../api.jsx";
import Chart, { TreemapParts } from "../Chart.jsx";
import { phrasePeriode, enLettres } from "../phrases.jsx";

// =====================================================================
// UN MARCHÉ — la question : pourquoi ce marché est-il dans cet état ?
//
// Page NEUVE. L'ancienne (SecteurQV, 747 lignes) datait de deux
// architectures : elle attendait le score sectoriel, la structure par
// questions de veille et des données que l'API ne sert plus telles
// quelles — d'où des blocs cassés à l'écran.
//
// Celle-ci ne montre que ce qui existe, dans l'ordre où on le lit :
//   1. les indicateurs suivis du marché, chacun avec SON GRAPHIQUE ;
//   2. la lecture validée (commentaire exécutif), datée ;
//   3. les faits validés du marché ;
//   4. qui achète, quand le marché a des acheteurs publics.
// =====================================================================

const ROLE = { avance: "annonce", coincident: "constate", retarde: "confirme" };
const NOMS = {
  horlogerie: "Horlogerie", medical: "Médical", automobile: "Automobile",
  aerospatial: "Aérospatial", transversal: "Votre métier et votre marge"
};
const SOUS = {
  horlogerie: "la valeur et le volume des exportations — deux lectures qui ne disent pas la même chose",
  medical: "deux signaux d'amont : ce qui est autorisé et ce qui est acheté précède ce qui sera produit",
  automobile: "l'étage adressable par un sous-traitant, et le marché final",
  aerospatial: "la demande publique qui annonce, la production qui constate",
  transversal: "l'activité de la profession, le carnet qui l'annonce, l'écosystème suisse et le change"
};

function FicheIndicateur({ v, serie }) {
  const sens = Number(v.sens_favorable) || 1;
  const dv = v.variation_periode_pct === null ? null : Number(v.variation_periode_pct);
  const ga = v.glissement_annuel_pct === null ? null : Number(v.glissement_annuel_pct);
  const ecart = v.ecart_a_la_moyenne_pct === null ? null : Number(v.ecart_a_la_moyenne_pct);
  const cls = x => (x === null || x === 0 ? "" : x * sens > 0 ? "bon" : "mauvais");

  return (
    <article className="fiche-ind">
      <div className="fi-tete">
        <span className={"etq lat-" + (v.latence || "coincident")}>{ROLE[v.latence] || "—"}</span>
        <h3>{v.label}</h3>
      </div>
      {v.description_metier && (
        <p className="fi-desc">{String(v.description_metier).split(" [HORS VITRINE")[0]}</p>
      )}

      <div className="fi-chiffres">
        <div className="fi-c">
          <span className="fi-c-v">{nb(v.value, Math.abs(v.value) >= 100 ? 0 : 2)}
            <span className="ind-u"> {v.unit}</span></span>
          <span className="fi-c-l">{phrasePeriode(v.period)}</span>
        </div>
        {dv !== null && (
          <div className="fi-c">
            <span className={"fi-c-v " + cls(dv)}>{pct(dv)}</span>
            <span className="fi-c-l">depuis le point précédent</span>
          </div>
        )}
        {ga !== null && (
          <div className="fi-c">
            <span className={"fi-c-v " + cls(ga)}>{pct(ga)}</span>
            <span className="fi-c-l">sur un an</span>
          </div>
        )}
        {ecart !== null && (
          <div className="fi-c">
            <span className={"fi-c-v " + cls(ecart)}>{pct(ecart)}</span>
            <span className="fi-c-l">vs sa moyenne sur douze mois</span>
          </div>
        )}
      </div>

      {serie && serie.length >= 2 ? (
        <Chart series={{ [v.geo_reference || "ref"]: serie }}
               refLine={v.moyenne_mobile_annuelle ?? undefined}
               refLabel="moyenne 12 mois" zoom={serie.length > 60} hauteur={210} />
      ) : (
        <p className="note" style={{ marginTop: 8 }}>
          Série trop courte pour être tracée ({(serie || []).length} point{(serie || []).length > 1 ? "s" : ""}).
        </p>
      )}

      <p className="fi-src">
        {v.source_organisation} · {v.frequency} · {nb(v.n_periodes)} périodes en base
        {v.source_url && <> · <LienSource href={v.source_url}>source</LienSource></>}
      </p>
    </article>
  );
}

// =====================================================================
// OÙ LE MARCHÉ SE DÉPLACE — le bloc de la v3, restauré à la demande de
// l'étudiant, et c'était une bonne demande : c'est le seul endroit du
// dispositif qui exploite la ventilation PAR PAYS des indicateurs de
// commerce — la donnée que ni la FH ni Eurostat ne résument, et la
// réponse d'écran à la question de veille QV3 (dynamique géographique).
//
// Ces indicateurs sont hors vitrine pour leur TOTAL, redondant avec les
// séries retenues ; leur ventilation, elle, ne fait doublon avec rien.
// C'est exactement la distinction du § 8.8 : hors de la liste de
// surveillance ne veut pas dire hors d'usage.
//
// La mesure est le MOUVEMENT DE PART, pas la croissance : sur un marché
// qui monte, tout le monde croît — la question est qui croît plus vite
// que le marché. Les points de part le disent, les pourcentages non.
// =====================================================================
const GEO_IND = {
  horlogerie:  { id: "H1", note: "exportations horlogères suisses par destination — Comtrade, USD" },
  medical:     { id: "M1", note: "commerce mondial d'instruments médicaux par déclarant — Comtrade, USD" },
  automobile:  { id: "A4", note: "commerce de parties et accessoires automobiles par déclarant — Comtrade, USD" },
  aerospatial: { id: "S4", note: "dépenses militaires par pays — SIPRI, USD courants" }
};

function homologue(p) {
  const m = String(p).match(/^(\d{4})-(\d{2})$/);
  if (m) return `${Number(m[1]) - 1}-${m[2]}`;
  const a = String(p).match(/^(\d{4})$/);
  if (a) return String(Number(a[1]) - 1);
  return null;
}

function DynamiqueGeo({ D, code }) {
  const conf = GEO_IND[code];
  const calc = useMemo(() => {
    if (!conf) return null;
    const pts = (D?.valeurs || []).filter(v =>
      v.indicator_id === conf.id && !estAgregat(v.geo) && !/^[SXF]\d/.test(String(v.geo)));
    if (!pts.length) return null;
    const parCle = new Map();
    for (const v of pts) parCle.set(v.geo + "|" + v.period, Number(v.value));
    const dernier = [...new Set(pts.map(v => v.period))].sort().pop();
    const avant = homologue(dernier);
    const geos = [...new Set(pts.map(v => v.geo))];
    let total = 0, totalPrev = 0;
    const lignes = [];
    for (const g of geos) {
      const v = parCle.get(g + "|" + dernier);
      if (v === undefined) continue;
      const vp = avant ? parCle.get(g + "|" + avant) : undefined;
      total += v;
      if (vp !== undefined) totalPrev += vp;
      lignes.push({ g, v, vp });
    }
    if (!total || lignes.length < 4) return null;
    for (const l of lignes) {
      l.part = l.v / total * 100;
      l.partPrev = (l.vp !== undefined && totalPrev) ? l.vp / totalPrev * 100 : null;
      l.dPart = l.partPrev !== null ? l.part - l.partPrev : null;
    }
    lignes.sort((a, b) => b.v - a.v);
    const mouvants = lignes.filter(l => l.dPart !== null);
    const gagnants = [...mouvants].sort((a, b) => b.dPart - a.dPart).filter(l => l.dPart > 0.05).slice(0, 5);
    const perdants = [...mouvants].sort((a, b) => a.dPart - b.dPart).filter(l => l.dPart < -0.05).slice(0, 5);
    const top3 = lignes.slice(0, 3).reduce((s, l) => s + l.part, 0);
    const reste = lignes.slice(12).reduce((s, l) => s + l.v, 0);
    const treemap = [
      ...lignes.slice(0, 12).map(l => ({ name: nomZone(l.g), value: l.v, part: l.part, dPart: l.dPart })),
      ...(reste > 0 ? [{ name: "Autres", value: reste, part: reste / total * 100, dPart: null }] : [])
    ];
    return { dernier, avant, lignes, gagnants, perdants, top3, treemap };
  }, [D, conf]);

  if (!conf || !calc) return null;
  const maxV = calc.lignes[0].v;

  return (
    <>
      <h2 className="section">Où le marché se déplace</h2>
      <div className="carte">
        <div className="geo-tuiles">
          <div className="geo-tuile">
            <span className="geo-tuile-l">Concentration</span>
            <span className="geo-tuile-v">{nb(calc.top3, 0)} %</span>
            <span className="geo-tuile-s">sur les 3 premiers marchés</span>
          </div>
          {calc.gagnants[0] && (
            <div className="geo-tuile">
              <span className="geo-tuile-l">Gagne du terrain</span>
              <span className="geo-tuile-v">{nomZone(calc.gagnants[0].g)}</span>
              <span className="geo-tuile-s hausse">+{nb(calc.gagnants[0].dPart, 1)} pt de part sur un an</span>
            </div>
          )}
          {calc.perdants[0] && (
            <div className="geo-tuile">
              <span className="geo-tuile-l">Cède du terrain</span>
              <span className="geo-tuile-v">{nomZone(calc.perdants[0].g)}</span>
              <span className="geo-tuile-s baisse">{nb(calc.perdants[0].dPart, 1)} pt de part sur un an</span>
            </div>
          )}
        </div>

        <TreemapParts items={calc.treemap} hauteur={230} />

        {(calc.gagnants.length > 0 || calc.perdants.length > 0) && (
          <div className="geo-listes">
            <div>
              <div className="geo-liste-titre">Gagnent du terrain</div>
              {calc.gagnants.length === 0 && <p className="note">aucun mouvement au-delà de 0,05 pt</p>}
              {calc.gagnants.map(l => (
                <div className="geo-mvt" key={l.g}>
                  <span>{nomZone(l.g)}</span>
                  <span className="hausse">+{nb(l.dPart, 1)} pt</span>
                </div>
              ))}
            </div>
            <div>
              <div className="geo-liste-titre">Cèdent du terrain</div>
              {calc.perdants.length === 0 && <p className="note">aucun mouvement au-delà de 0,05 pt</p>}
              {calc.perdants.map(l => (
                <div className="geo-mvt" key={l.g}>
                  <span>{nomZone(l.g)}</span>
                  <span className="baisse">{nb(l.dPart, 1)} pt</span>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="geo-classement">
          <div className="geo-liste-titre">Les principaux marchés · {calc.dernier}</div>
          {calc.lignes.slice(0, 10).map(l => (
            <div className="pays-ligne" key={l.g}>
              <span className="pays-nom">{nomZone(l.g)}</span>
              <span className="pays-piste"><i style={{ width: Math.max(2, l.v / maxV * 100) + "%" }} /></span>
              <span className="pays-part">{nb(l.part, 1)} %</span>
              <span className={"pays-d " + (l.dPart === null ? "neutre" : l.dPart > 0.05 ? "hausse" : l.dPart < -0.05 ? "baisse" : "neutre")}>
                {l.dPart === null ? "—" : (l.dPart > 0 ? "+" : "") + nb(l.dPart, 1) + " pt"}
              </span>
            </div>
          ))}
        </div>

        <p className="bloc-note">
          {conf.note}. Les mouvements sont des <strong>points de part</strong>, comparés à{" "}
          {calc.avant} : sur un marché qui monte, tout le monde croît — la question est qui croît
          plus vite que le marché. Indicateur hors vitrine pour son total (redondant avec les
          séries suivies) ; sa ventilation par pays ne fait doublon avec rien.
        </p>
      </div>
    </>
  );
}

export default function Marche() {
  const { code } = useParams();
  const { D, S, G, A } = useDonnees();

  const vitrine = useMemo(
    () => (S?.vitrine || []).filter(v => v.sector_code === code), [S, code]);

  // La série de chaque indicateur, sur SA zone de référence — celle sur
  // laquelle toutes les métriques affichées sont calculées.
  const series = useMemo(() => {
    const m = {};
    for (const v of vitrine) {
      m[v.indicator_id] = (D?.valeurs || [])
        .filter(x => x.indicator_id === v.indicator_id && x.geo === v.geo_reference)
        .sort((a, b) => String(a.period).localeCompare(String(b.period)))
        .map(x => ({ period: x.period, value: Number(x.value) }));
    }
    return m;
  }, [D, vitrine]);

  const commentaire = (D?.commentaires || []).find(c => c.sector_code === code);
  const runCourant = S?.run_courant?.run_id ?? null;
  const faits = (G?.signaux || []).filter(s => s.sector_code === code);
  const acheteurs = (A?.acheteurs || []).filter(a => a.sector_code === code)
    .sort((x, y) => (y.avis_publies || 0) - (x.avis_publies || 0));
  const ecartes = (D?.referentiel || [])
    .filter(i => i.sector_code === code && !vitrine.some(v => v.indicator_id === i.indicator_id))
    .length;

  if (!S) return <div className="page"><div className="vide">Chargement…</div></div>;
  if (!vitrine.length) return (
    <div className="page">
      <h1 className="verdict">{NOMS[code] || code}</h1>
      <div className="vide">Aucun indicateur en vitrine pour ce marché.</div>
    </div>
  );

  return (
    <div className="page">
      <header className="tete">
        <span className="tete-date">
          {vitrine.length > 1 ? `${enLettres(vitrine.length)} indicateurs suivis` : "un indicateur suivi"}
          {ecartes > 0 && ` · ${ecartes} écartés de la grille (voir Fiabilité)`}
        </span>
      </header>
      <h1 className="verdict">{NOMS[code] || code}</h1>
      <p className="bloc-intro" style={{ marginTop: -14 }}>{SOUS[code] || ""}</p>

      {vitrine.map(v => (
        <FicheIndicateur key={v.indicator_id} v={v} serie={series[v.indicator_id]} />
      ))}

      <DynamiqueGeo D={D} code={code} />

      {commentaire && (
        <>
          <h2 className="section">La lecture validée</h2>
          <div className="commentaire">
            <div className="com-tete">
              <span className="etq e-ok">validée</span>
              <span>{commentaire.validated_by}</span>
              <span className="com-date">
                collecte n° {commentaire.run_id ?? "—"} · {dateCH(commentaire.validated_at)}
              </span>
            </div>
            {commentaire.run_id && runCourant && commentaire.run_id < runCourant && (
              <div className="avert">
                <strong>Lecture antérieure.</strong> Rédigée sur la collecte
                n° {commentaire.run_id} ; la base en est à la n° {runCourant}. Les chiffres cités
                peuvent différer de ceux affichés plus haut.
              </div>
            )}
            <div className="com-corps"><MarkdownLeger texte={commentaire.text} /></div>
          </div>
        </>
      )}

      {faits.length > 0 && (
        <>
          <h2 className="section">Faits validés</h2>
          {faits.map(s => (
            <div className="fait" key={s.signal_id}>
              <p className="fait-txt">{s.evenement}</p>
              <p className="fait-qui">
                {s.acteur ? s.acteur + " · " : ""}
                {s.echeance ? "échéance " + s.echeance + " · " : ""}
                <LienSource href={s.source_doc}>document d'origine</LienSource>
              </p>
            </div>
          ))}
        </>
      )}

      {acheteurs.length > 0 && (
        <>
          <h2 className="section">Qui achète sur ce marché</h2>
          <div className="carte" style={{ padding: 0, overflow: "hidden" }}>
            <table>
              <thead>
                <tr><th>Organisation</th><th style={{ textAlign: "right" }}>Avis</th>
                    <th style={{ textAlign: "right" }}>dont ouverts</th><th>Contact</th></tr>
              </thead>
              <tbody>
                {acheteurs.slice(0, 8).map((a, i) => (
                  <tr key={i}>
                    <td><strong>{a.acheteur}</strong>
                        <div className="cell-note">{a.acheteur_pays}</div></td>
                    <td style={{ textAlign: "right" }}>{a.avis_publies}</td>
                    <td style={{ textAlign: "right" }}>
                      {a.dont_encore_ouverts
                        ? <strong className="hausse">{a.dont_encore_ouverts}</strong>
                        : <span className="neutre">—</span>}
                    </td>
                    <td>{a.acheteur_courriel
                          ? <a href={"mailto:" + a.acheteur_courriel}>écrire</a>
                          : <span className="neutre">—</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="note" style={{ marginTop: 8 }}>
            Marchés publics européens uniquement — la demande privée n'y figure pas.
          </p>
        </>
      )}
    </div>
  );
}
