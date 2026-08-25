import React, { useMemo } from "react";
import { useParams } from "react-router-dom";
import { useDonnees, nb, pct, dateCH, LienSource, MarkdownLeger } from "../api.jsx";
import Chart from "../Chart.jsx";
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
