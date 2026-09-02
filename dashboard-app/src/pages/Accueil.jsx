import React from "react";
import { useNavigate } from "react-router-dom";
import { useDonnees, nb, pct, clsVar, nomZone, relu, BadgeCommentaire,
         sensMouvement, SENS_ETQ, alertesSignificatives } from "../api.jsx";
import { MarkdownLeger } from "../api.jsx";
import { Synthetique } from "./Secteur.jsx";

// Extrait « Ce qu'il faut retenir » du commentaire VALIDÉ — texte repris
// tel quel, coupé en fin de phrase, jamais reformulé.
function retenir(texte) {
  if (!texte) return null;
  const m = /\*\*\s*(?:\d+\.\s*)?Ce qu'il faut retenir\s*\*\*\s*[—:–-]?\s*([\s\S]{0,420}?)(?=\n\s*\n|\*\*|$)/.exec(texte);
  if (!m) return null;
  let t = m[1].replace(/\s+/g, " ").trim();
  if (t.length > 270) {
    const coupe = t.slice(0, 270), fin = coupe.lastIndexOf(". ");
    t = fin > 100 ? coupe.slice(0, fin + 1) : coupe + "…";
  }
  return t || null;
}

export default function Accueil() {
  const { D } = useDonnees();
  const navigate = useNavigate();
  const r = D.referentiel || [];
  const certifies = r.filter(i => i.status === "certifie");
  const collectes = certifies.filter(i => i.observations > 0);
  // Revue du 02.09.2026 : même règle que la navigation et les pages
  // secteur (diffusable ET poids ≥ SEUIL_POIDS_PCT %) — la liste « À
  // examiner » ne doit pas montrer une série que les vignettes ne comptent pas.
  const diff = alertesSignificatives(D).retenues;
  const run = D.run_courant || {};
  const totalObs = r.reduce((s, i) => s + Number(i.observations || 0), 0);
  const secteurs = [...new Map(r.map(i => [i.sector_code, i.sector_label])).entries()]
    .filter(([c]) => c !== "transversal");

  return (
    <div className="page">
      <div className="topbar">
        <h1>Vue d'ensemble</h1>
        <div className="meta">run {run.run_id ?? "n.d."} ({run.status ?? ""})</div>
      </div>

      {/* ACCUEIL RETOURNÉ VERS LES MARCHÉS (28.08.2026, revue v9). Les
          compteurs de dispositif — observations, révisions — parlent au
          constructeur, pas au décideur : ils sont partis dans Fiabilité.
          Chaque marché ouvre sur l'extrait de SON commentaire exécutif
          validé : du texte déjà passé par la validation humaine, jamais un
          résumé recalculé ici. */}
      <h2 style={{ marginTop: 4 }}>Les marchés</h2>
      <div className="grille g2">
        {secteurs.map(([c, lbl]) => {
          const inds = r.filter(i => i.sector_code === c &&
            (i.en_vitrine === undefined ? i.observations > 0 : i.en_vitrine));
          const n = inds.filter(i => i.observations > 0).length;
          // Revue du 02.09.2026 : compter avec la règle UNIQUE (seuil de
          // poids compris), comme la navigation — l'accueil disait 3 en
          // aérospatial quand la navigation disait 2 (S3 Allemagne, 0,47 %).
          const al = new Set(diff.filter(a => a.sector_code === c).map(a => a.indicator_id)).size;
          const com = (D.commentaires || []).find(k => k.sector_code === c);
          const extrait = retenir(com?.text);
          return (
            <div key={c} className="carte kpi cliquable" onClick={() => navigate("/secteur/" + c)}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
                <div className="k-l" style={{ fontSize: 13, fontWeight: 700 }}>{lbl}</div>
                <div style={{ fontSize: 11, color: "var(--gris)" }}>{n}/{inds.length} indicateurs suivis</div>
              </div>
              {extrait
                ? <div style={{ fontSize: 13, lineHeight: 1.45, margin: "6px 0" }}>{extrait}</div>
                : <div className="note" style={{ margin: "6px 0" }}>Aucun commentaire pour ce marché.</div>}
              <div className="k-s">
                {al
                  ? <span className="etq e-rouge">{al} série{al > 1 ? "s" : ""} en franchissement</span>
                  : <span className="etq e-gris">rien d'inhabituel</span>}
                {com && <BadgeCommentaire c={com} />}
              </div>
            </div>
          );
        })}
      </div>
      <div className="note" style={{ marginTop: 6 }}>
        Chaque marché affiche l'extrait de son commentaire le plus récent. Un commentaire
        que personne n'a encore relu est affiché quand même, avec une étiquette orange qui le
        signale. Les compteurs techniques (observations, révisions, exécutions) se trouvent
        dans la page Fiabilité.
      </div>

      <LecturesTransversales D={D} />

      <h2>À examiner</h2>
      <div className="grille g2">
        <div className="carte">
          <div style={{ fontSize: 12, fontWeight: 650, marginBottom: 4 }}>Mouvements inhabituels</div>
          {diff.length === 0 && (
            <div className="note">Aucun franchissement diffusable : rien ne sort de l'ordinaire des séries suivies.</div>
          )}
          {/* Une ligne par série (28.08) : la zone de RÉFÉRENCE d'abord,
              sinon le franchissement le plus récent — jamais une zone
              arbitraire ni un millésime ancien en tête d'accueil. */}
          {[...diff.reduce((m, a) => {
            const ref = (r.find(x => x.indicator_id === a.indicator_id) || {}).geo_reference;
            const prev = m.get(a.indicator_id);
            const mieux = !prev
              || (a.geo === ref && prev.geo !== ref)
              || (prev.geo !== ref && String(a.period) > String(prev.period));
            if (mieux) m.set(a.indicator_id, { ...a, _n: (prev?._n || 0) + 1 });
            else prev._n += 1;
            return m;
          }, new Map()).values()].slice(0, 6).map((a, i) => (
            <div className="alerte" key={i}>
              {/* 31.08 : le point se signe par sens_favorable — tout n'est plus rouge. */}
              <span className="a-pt" style={{ background:
                { favorable: "var(--vert)", defavorable: "var(--rouge)", neutre: "#98a2b3" }[sensMouvement(D, a)] }} />
              <div>
                <strong>{a.indicator_id}</strong> {a.indicator_label} · {nomZone(a.geo)}, {a.period} :{" "}
                <span className={clsVar(a.glissement_annuel_pct ?? a.variation_periode_pct)}>
                  {pct(a.glissement_annuel_pct ?? a.variation_periode_pct)}
                </span>{" "}
                <span className={"etq " + SENS_ETQ[sensMouvement(D, a)][0]}>{SENS_ETQ[sensMouvement(D, a)][1]}</span>{a._n > 1 && <span style={{ color: "var(--gris)" }}> · {a._n} zones pesantes concernées</span>}
              </div>
            </div>
          ))}
        </div>
        <Synthetique />
      </div>
    </div>
  );
}


/* ---------- lectures transversales (31.08.2026) ---------- */
// L'étage où le modèle produit ce que ni le code ni un humain pressé ne
// produiraient : des HYPOTHÈSES de liaison inter-signaux. Génération
// CONTRAINTE — le modèle ne reçoit que des faits calculés (F1..Fn) et
// n'écrit aucun chiffre : les valeurs vivent dans les faits cités,
// dépliables sous chaque hypothèse. Une hypothèse n'est jamais un fait :
// l'étiquette et le conditionnel le rappellent, la validation tranche.
function LecturesTransversales({ D }) {
  const lectures = D?.lectures_transversales || [];
  if (!lectures.length) return null;
  const CONF = { haute: "e-vert", moyenne: "e-gris", basse: "e-ambre" };
  return (
    <>
      <h2>Lectures transversales <span style={{ fontSize: 12, fontWeight: 400, color: "var(--gris)" }}>
        des pistes de lecture, pas des faits : chaque liaison cite les séries qui la portent</span></h2>
      <div className="grille g2">
        {lectures.map(l => {
          const faits = Object.entries(l.faits_cites || {});
          return (
            <div className="carte" key={l.lecture_id}>
              <div style={{ marginBottom: 6 }}>
                <span className="etq e-violet">hypothèse</span>{" "}
                <span className={"etq " + (CONF[l.confiance] || "e-gris")}>confiance {l.confiance}</span>{" "}
                {l.statut === "valide"
                  ? <span className="etq e-vert">validée par {l.validated_by}</span>
                  : <span className="etq e-ambre">non arbitrée</span>}
              </div>
              <div style={{ fontSize: 13.5, lineHeight: 1.5 }}>
                {String(l.hypothese).replace(/\[?(F\d+)\]?/g, "")}
              </div>
              {l.infirmable_par && (
                <div className="a-m" style={{ marginTop: 6 }}><strong>Se vérifiera par :</strong> {l.infirmable_par}</div>
              )}
              <details style={{ marginTop: 6 }}>
                <summary style={{ cursor: "pointer", fontSize: 12, color: "var(--gris)" }}>
                  les {faits.length} faits cités, avec leurs valeurs
                </summary>
                <div style={{ marginTop: 6 }}>
                  {faits.map(([c, f]) => (
                    <div key={c} className="a-m" style={{ marginBottom: 4 }}><strong>{c}</strong> · {f.texte}</div>
                  ))}
                </div>
              </details>
            </div>
          );
        })}
      </div>
      <div className="note" style={{ marginTop: 6 }}>
        Ces pistes de lecture sont proposées par un modèle à partir des chiffres du registre,
        visibles sous chaque carte. Une piste non arbitrée n'engage personne ; une piste validée
        porte le nom de la personne qui l'a jugée.
      </div>
    </>
  );
}
