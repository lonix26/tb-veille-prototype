import React, { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { useDonnees, nb, pct } from "../api.jsx";
import { phraseEcheance, phraseFraicheur, phrasePeriode, enLettres } from "../phrases.jsx";

// =====================================================================
// AUJOURD'HUI — treize indicateurs, et plus aucun score.
//
// TROIS ITÉRATIONS POUR EN ARRIVER LÀ, et l'erreur était toujours la même :
// je corrigeais la présentation d'une grille trop grosse au lieu de tailler
// la grille. Quarante-quatre indicateurs, dont huit sans aucune donnée, six
// trop courts pour être lus, deux arrêtés en 2022, et des paires corrélées
// à 0,99. Aucune mise en page ne rend cela lisible.
//
// LA DÉCISION. La grille passe à TREIZE indicateurs (§ 8.8), et le score
// sectoriel quitte cet écran. Avec deux séries par marché, « la moyenne des
// écarts détendancés » n'est plus une mesure : c'est la moyenne de deux
// nombres, et personne ne sait l'interpréter. Il reste calculé, documenté
// et visible sur l'écran Fiabilité comme ce qu'il est — une
// expérimentation méthodologique.
//
// À la place : les séries elles-mêmes. Chacune porte son rôle, sa dernière
// valeur, sa variation et sa position par rapport à sa propre moyenne. Plus
// long à lire qu'un nombre. Infiniment plus interprétable.
// =====================================================================

const ROLE = { avance: "annonce", coincident: "constate", retarde: "confirme" };

// Un nombre se lit mieux quand son ordre de grandeur est dit en mots.
function valeurLisible(v, unite) {
  if (v === null || v === undefined) return "—";
  const u = String(unite || "");
  const a = Math.abs(v);
  if (/unité|avis|autoris|pièce|objet/i.test(u)) {
    if (a >= 1e6) return `${nb(v / 1e6, 2)} mio`;
    if (a >= 1e4) return `${nb(v / 1e3, 0)} k`;
    return nb(v, 0);
  }
  return nb(v, a >= 100 ? 0 : 1);
}

function uniteCourte(u) {
  const c = {
    "nombre d'avis": "avis", "nombre d'autorisations": "autorisations",
    "milliers de pièces": "k pièces", "mio CHF": "mio CHF",
    indice: "", pourcentage: "%", solde: "solde", taux: "", unités: "immatric."
  };
  return c[u] ?? u ?? "";
}

function Ligne({ v }) {
  const sens = Number(v.sens_favorable) || 1;
  const dv = v.variation_periode_pct === null ? null : Number(v.variation_periode_pct);
  const ecart = v.ecart_a_la_moyenne_pct === null ? null : Number(v.ecart_a_la_moyenne_pct);
  // Une variation nulle n'est ni bonne ni mauvaise : la peindre en rouge
  // ferait passer une stabilité pour une dégradation.
  const bon = dv === null || dv === 0 ? null : dv * sens > 0;
  const trop_court = Number(v.n_periodes) < 8;

  return (
    <div className="ind">
      <span className={"ind-role r-" + (v.latence || "coincident")}>
        {ROLE[v.latence] || "—"}
      </span>

      <span className="ind-quoi">
        {v.label}
        <span className="ind-src">
          {v.source_organisation} · {phrasePeriode(v.period)}
          {trop_court && <> · <em>série courte, {v.n_periodes} points</em></>}
        </span>
      </span>

      <span className="ind-val">
        {valeurLisible(v.value, v.unit)}
        <span className="ind-u"> {uniteCourte(v.unit)}</span>
      </span>

      <span className={"ind-var " + (bon === null ? "nul" : bon ? "bon" : "mauvais")}>
        {dv === null ? "—" : <>{dv > 0 ? "▲" : dv < 0 ? "▼" : "="} {pct(dv)}</>}
      </span>

      <span className="ind-pos">
        {ecart === null ? "" :
         Math.abs(ecart) < 3 ? "à sa moyenne" :
         `${pct(ecart)} vs sa moyenne`}
      </span>
    </div>
  );
}

function Bloc({ titre, sous, lignes, onClic }) {
  if (!lignes.length) return null;
  return (
    <section className="bloc-ind">
      <header className="bloc-ind-tete" onClick={onClic} role={onClic ? "button" : undefined}>
        <h3>{titre}</h3>
        <span className="bloc-ind-sous">{sous}</span>
        {onClic && <span className="bloc-ind-plus">détail →</span>}
      </header>
      {lignes.map(v => <Ligne key={v.indicator_id} v={v} />)}
    </section>
  );
}

export default function Aujourdhui() {
  const { S, A, erreursV4 } = useDonnees();
  const navigate = useNavigate();

  const urgentes = useMemo(() => (A?.actions || [])
    .filter(a => a.adressable >= 1 && a.jours_restants !== null && a.jours_restants <= 15)
    .sort((x, y) => x.jours_restants - y.jours_restants), [A]);

  const vitrine = S?.vitrine || [];
  const parSecteur = useMemo(() => {
    const m = new Map();
    for (const v of vitrine) {
      if (!m.has(v.sector_code)) m.set(v.sector_code, []);
      m.get(v.sector_code).push(v);
    }
    return m;
  }, [vitrine]);

  if (!S) return (
    <div className="page">
      <div className="vide">
        <strong>La base ne répond pas.</strong><br />
        L'écran ne peut pas se peupler, et il ne l'invente pas.<br />
        <span style={{ fontSize: 12 }}>{erreursV4?.["/sante"]}</span>
      </div>
    </div>
  );

  const run = S.run_courant || {};
  const aValider = Number(S.commentaires_en_attente) || 0;
  const aExaminer = Number(S.items_en_attente_examen) || 0;
  const aujourdhui = new Date()
    .toLocaleDateString("fr-CH", { weekday: "long", day: "numeric", month: "long" })
    .replace(",", "");

  const titre = urgentes.length === 0 ? "Rien ne presse aujourd'hui."
    : urgentes.length === 1 ? `Un appel d'offres se clôt ${phraseEcheance(urgentes[0].jours_restants)}.`
    : `${enLettres(urgentes.length)} appels d'offres se closent d'ici quinze jours.`;

  const SECTEURS = [
    ["horlogerie", "Horlogerie"], ["medical", "Médical"],
    ["automobile", "Automobile"], ["aerospatial", "Aérospatial"]
  ];

  return (
    <div className="page">
      <header className="tete">
        <span className="tete-date">{aujourdhui}</span>
        <span className="tete-etat">
          {phraseFraicheur(run.executed_at)}<br />
          données jusqu'à {phrasePeriode(S.fraicheur?.point_le_plus_recent)}
        </span>
      </header>

      <h1 className="verdict">{titre.charAt(0).toUpperCase() + titre.slice(1)}</h1>

      {urgentes.length > 0 && (
        <div className="bande">
          <div className="bande-tete">À décider</div>
          {urgentes.slice(0, 3).map(a => (
            <a className="bande-ligne" key={a.publication_number}
               href={a.url} target="_blank" rel="noreferrer">
              <span className={"bande-delai" + (a.jours_restants > 7 ? " calme" : "")}>
                {phraseEcheance(a.jours_restants)}
              </span>
              <span className="bande-quoi">
                {a.piece_concernee || a.titre}
                <span className="bande-qui">{a.acheteur}</span>
              </span>
              <span className="bande-fleche">→</span>
            </a>
          ))}
          {urgentes.length > 3 && (
            <a className="bande-ligne" href="#/a-faire">
              <span className="bande-delai calme">et {urgentes.length - 3}</span>
              <span className="bande-quoi">autres appels d'offres à votre portée</span>
              <span className="bande-fleche">→</span>
            </a>
          )}
        </div>
      )}

      <h2 className="section">
        Ce que disent les chiffres · {enLettres(vitrine.length)} indicateurs suivis
      </h2>

      <Bloc titre="Votre métier et votre marge"
            sous="l'activité de la profession, le carnet qui l'annonce, et le change"
            lignes={parSecteur.get("transversal") || []}
            onClic={() => navigate("/marche/transversal")} />

      {SECTEURS.map(([code, nom]) => (
        <Bloc key={code} titre={nom} sous="marché client"
              lignes={parSecteur.get(code) || []}
              onClic={() => navigate("/marche/" + code)} />
      ))}

      <div className="attente">
        {aValider > 0 || aExaminer > 0 ? (
          <>
            <span>
              En attente de vous :{" "}
              {aValider > 0 && <><strong>{enLettres(aValider)} lecture{aValider > 1 ? "s" : ""}</strong> à valider</>}
              {aValider > 0 && aExaminer > 0 && " · "}
              {aExaminer > 0 && <><strong>{nb(aExaminer)} items</strong> de veille en file</>}
            </span>
            <a className="attente-lien" href="#/a-faire">Traiter les dix de la semaine →</a>
          </>
        ) : <span>Rien n'attend votre lecture.</span>}
      </div>

      <p className="pied-note">
        Trente et un autres indicateurs ont été qualifiés puis <strong>écartés de la grille</strong> —
        sans données, trop courts, périmés ou redondants. Le motif de chacun est sur l'écran{" "}
        <a href="#/fiabilite">Fiabilité</a>, avec les réserves qui pèsent sur ce qui reste.
      </p>
    </div>
  );
}
