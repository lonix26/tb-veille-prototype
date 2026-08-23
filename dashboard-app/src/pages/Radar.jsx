import React, { useState } from "react";
import { useDonnees, dateCH, nb, LienSource, MentionTriage } from "../api.jsx";

// =====================================================================
// ÉCRAN 3 — « Radar ». Question : qu'est-ce qui arrive, et quand le
// saura-t-on ? Ligne de temps des signaux VALIDÉS, positionnés par
// échéance. Le rattachement de confirmation — les indicateurs de l'étage 1
// portant la même question de veille — est l'argument central de l'étage 2 :
// c'est par eux qu'une statistique ultérieure confirmera ou infirmera.
// =====================================================================

const COULEURS = {
  horlogerie: "#5925dc", medical: "#0f766e",
  automobile: "#b54708", aerospatial: "#0e7490", transversal: "#43505e"
};

function Detail({ s, fermer }) {
  return (
    <div className="detail-signal">
      <button className="fermer" onClick={fermer}>×</button>
      <h3>{s.evenement}</h3>
      <div className="d-grille">
        <div><span>Secteur</span>{s.sector_label}</div>
        <div><span>Question de veille</span>{s.watch_question_code}</div>
        <div><span>Acteur</span>{s.acteur || "—"}</div>
        <div><span>Zone</span>{s.zone || "—"}</div>
        <div><span>Échéance</span>{s.echeance || "non datée"}</div>
        <div><span>Recoupement</span>{s.score_recoupement !== null && s.score_recoupement !== undefined
              ? nb(s.score_recoupement, 2) : "—"}</div>
        <div><span>Validé par</span>{s.validated_by || "—"}</div>
        <div><span>Validé le</span>{dateCH(s.validated_at)}</div>
      </div>
      {s.note_validation && <p className="d-note">« {s.note_validation} »</p>}

      {(s.anteriorite !== null && s.anteriorite !== undefined) && (
        <div className="d-triage">
          Triage à la promotion : antériorité {s.anteriorite}/2, portée {s.portee}/2. <MentionTriage />
          {s.item_titre && <div className="d-item">Item d'origine : {s.item_titre}</div>}
        </div>
      )}

      <div className="d-confirm">
        <strong>Ce qui confirmera ou infirmera ce signal</strong>
        {(s.confirmateurs || []).length === 0 ? (
          <div className="vide non-couvert" style={{ marginTop: 8 }}>
            Aucun indicateur certifié ne porte cette question de veille pour ce secteur.
            <br />Le signal est donc <strong>non confirmable par le dispositif en l'état</strong> —
            c'est une lacune de la grille, et elle se voit ici.
          </div>
        ) : (
          <ul className="d-liste">
            {(s.confirmateurs || []).map(c => (
              <li key={c.indicator_id}>
                <span className="etq e-gris">{c.indicator_id}</span> {c.label}
                {c.latence && <span className={"etq lat-" + c.latence}>{c.latence}</span>}
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="d-pied">
        <LienSource href={s.source_doc} titre="document source du signal">document source</LienSource>
        {s.item_url && <LienSource href={s.item_url} titre="item de flux d'origine">item d'origine</LienSource>}
        <span className="prov">pièce brute : {s.raw_ref || "—"}</span>
      </div>
    </div>
  );
}

export default function Radar() {
  const { G, erreursV4 } = useDonnees();
  const [ouvert, setOuvert] = useState(null);
  const [filtre, setFiltre] = useState("tous");

  if (!G) return (
    <div className="page"><div className="topbar"><h1>Radar</h1></div>
      <div className="vide"><strong>Le point de lecture « signaux » ne répond pas.</strong><br />
        <span style={{ fontSize: 12 }}>{erreursV4?.["/signaux"]}</span></div></div>
  );

  const tous = G.signaux || [];
  // Le statut de confirmation est une convention de saisie en note_validation
  // (aucun champ nouveau pour la v4).
  //
  // CONVENTION DURCIE LE 23.08.2026. La première version cherchait la
  // sous-chaîne « confirme » : une note disant « signal À CONFIRMER par M8 »
  // basculait donc en « confirmé » — le contraire de ce qu'elle dit. Le
  // marqueur est désormais EXPLICITE et en capitales, donc impossible à
  // déclencher par accident dans une phrase rédigée.
  //
  //   pour marquer un signal confirmé : écrire  [CONFIRME]  dans note_validation
  //   pour marquer un signal infirmé  : écrire  [INFIRME]
  //   absence de marqueur             : « à confirmer » (défaut)
  const statutDe = s => {
    const n = String(s.note_validation || "");
    if (/\[CONFIRME\]/.test(n)) return "confirmé";
    if (/\[INFIRME\]/.test(n)) return "infirmé";
    return "à confirmer";
  };
  const signaux = tous.filter(s => filtre === "tous" || statutDe(s) === filtre);

  // CORRECTION DU 23.08.2026 — la ligne de temps N'EN ÉTAIT PAS UNE. Les points
  // étaient répartis à intervalles égaux par leur RANG : un signal à échéance
  // 2026-07 et un autre à 2035-01 apparaissaient équidistants. L'écran annonce
  // « placés selon leur échéance » et ne le faisait pas — un axe qui ment.
  //
  // Les échéances sont du texte libre et parfois bavardes (« 2035-01-01
  // (application de l'objectif 100 % ; adoption le 19.04.2023) ») : on en
  // extrait la PREMIÈRE date, du plus précis au moins précis. Ce qui n'est pas
  // datable ne va pas sur l'axe — il est montré à part, et dit comme tel.
  const dateDe = s => {
    const e = String(s.echeance || "");
    let m = e.match(/(\d{4})-(\d{2})-(\d{2})/);
    if (m) return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
    m = e.match(/(\d{4})-(\d{2})/);
    if (m) return new Date(Date.UTC(+m[1], +m[2] - 1, 1));
    m = e.match(/(?:^|[^\d])(\d{4})(?:[^\d]|$)/);
    if (m) return new Date(Date.UTC(+m[1], 0, 1));
    return null;
  };
  const dates = signaux.map(s => ({ s, d: dateDe(s) }));
  const situes = dates.filter(x => x.d);
  const nonDates = dates.filter(x => !x.d).map(x => x.s);
  const bornes = situes.map(x => x.d.getTime());
  const tMin = bornes.length ? Math.min(...bornes) : 0;
  const tMax = bornes.length ? Math.max(...bornes) : 1;
  const etendue = Math.max(tMax - tMin, 1);
  // Marge de 6 % de chaque côté pour que les libellés extrêmes tiennent.
  const position = d => 6 + 88 * ((d.getTime() - tMin) / etendue);
  // Graduations annuelles, pour que l'échelle soit visible et non supposée.
  const anneeMin = new Date(tMin).getUTCFullYear();
  const anneeMax = new Date(tMax).getUTCFullYear();
  const graduations = [];
  const pas = Math.max(1, Math.ceil((anneeMax - anneeMin) / 8));
  for (let a = anneeMin; a <= anneeMax; a += pas) {
    graduations.push({ a, x: position(new Date(Date.UTC(a, 0, 1))) });
  }

  return (
    <div className="page">
      <div className="topbar">
        <h1>Radar</h1>
        <div className="meta">{tous.length} signal{tous.length > 1 ? "aux" : ""} validé{tous.length > 1 ? "s" : ""}
          {G.signaux_en_attente > 0 && <> · {G.signaux_en_attente} en attente</>}</div>
      </div>

      <p className="lecture">
        Les signaux validés, placés selon leur échéance. Au clic : l'événement, ses extraits,
        son validateur — et l'indicateur de l'étage 1 qui le confirmera. Rien ici n'a échappé
        à une validation humaine nominative.
      </p>

      <div className="filtres">
        {["tous", "à confirmer", "confirmé", "infirmé"].map(f => (
          <button key={f} className={"filtre" + (filtre === f ? " actif" : "")}
                  onClick={() => setFiltre(f)}>{f}</button>
        ))}
      </div>

      {signaux.length === 0 ? (
        <div className="vide">
          <strong>Aucun signal validé{filtre !== "tous" ? " dans ce filtre" : ""}.</strong><br />
          Le radar n'affiche que du validé : un signal en attente d'examen ou de validation
          n'y figure pas, et rien n'y est ajouté pour meubler.
          {G.signaux_en_attente > 0 && <><br />{G.signaux_en_attente} signal(aux) en attente de validation.</>}
        </div>
      ) : (
        <>
          <div className="ligne-temps">
            <div className="lt-axe" />
            {graduations.map(g => (
              <React.Fragment key={g.a}>
                <div className="lt-grad" style={{ left: g.x + "%" }} />
                <span className="lt-annee" style={{ left: g.x + "%" }}>{g.a}</span>
              </React.Fragment>
            ))}
            {situes.map(({ s, d }, i) => (
              <div key={s.signal_id} className="lt-point"
                   style={{ left: position(d) + "%",
                            top: i % 2 === 0 ? "18%" : "62%",
                            borderColor: COULEURS[s.sector_code] || "#43505e" }}
                   onClick={() => setOuvert(s.signal_id === ouvert ? null : s.signal_id)}
                   title={s.evenement}>
                <span className="lt-ech">{d.toISOString().slice(0, 10)}</span>
                <span className="lt-lib">{String(s.evenement).slice(0, 46)}</span>
                <span className="lt-stat">{statutDe(s)}</span>
              </div>
            ))}
          </div>
          <div className="note">
            Axe temporel réel, de {new Date(tMin).toISOString().slice(0, 10)} à
            {" " + new Date(tMax).toISOString().slice(0, 10)} — la distance entre deux points
            est proportionnelle au temps qui les sépare.
          </div>
          {nonDates.length > 0 && (
            <div className="hors-axe">
              <strong>{nonDates.length} signal(aux) sans échéance datable</strong> — hors de
              l'axe, parce qu'aucune position ne serait honnête :
              <ul className="d-liste" style={{ marginTop: 8 }}>
                {nonDates.map(s => (
                  <li key={s.signal_id}>
                    <span className="etq e-violet">{s.sector_label}</span>
                    <span className="src-inline" style={{ marginLeft: 0 }}
                          onClick={() => setOuvert(s.signal_id === ouvert ? null : s.signal_id)}>
                      {String(s.evenement).slice(0, 70)}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          )}
          {signaux.filter(s => s.signal_id === ouvert)
                  .map(s => <Detail key={s.signal_id} s={s} fermer={() => setOuvert(null)} />)}
        </>
      )}
    </div>
  );
}
