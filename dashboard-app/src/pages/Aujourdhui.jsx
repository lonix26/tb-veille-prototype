import React, { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { useDonnees, nb, dateCH } from "../api.jsx";
import { Sparkline } from "../Mini.jsx";
import {
  etatMarche, phraseEcheance, phraseFraicheur, phrasePeriode,
  redondances, compositionLatence, enLettres, avecArticle
} from "../phrases.jsx";

// =====================================================================
// AUJOURD'HUI — l'écran unique, et il tient dans une hauteur d'écran.
//
// Ce qu'il remplace : un accueil de neuf sections empilées, où le verdict
// se trouvait quelque part entre un paragraphe de méthode, trois
// avertissements imbriqués et deux commentaires de modèle. Personne n'y
// comprenait rien, et c'était mérité — j'avais répondu à chacune de mes
// critiques par un bloc de plus.
//
// Il répond à UNE question : dois-je faire quelque chose ?
//   1. un verdict en une phrase ;
//   2. ce qui a une échéance, s'il y en a ;
//   3. l'état des quatre marchés, en un coup d'œil ;
//   4. ce qui attend un geste de ma part, sur une ligne.
//
// Tout le reste — méthode, réserves, séries, sources, limites — n'a pas
// disparu : il a un écran à lui. Voir `Fiabilite.jsx`.
// =====================================================================

function verdictDuJour({ urgentes, marches, ecarts }) {
  const horsNorme = marches.filter(m => m.score_sante !== null && Math.abs(Number(m.score_sante)) >= 1);
  // Le verdict ne parle QUE des marchés affichés. Le socle transversal a son
  // écran ; le nommer ici renvoyait le lecteur à une tuile qui n'existe pas.
  const codes = new Set(marches.map(m => m.sector_code));
  const bouges = (ecarts || [])
    .filter(e => codes.has(e.sector_code) && e.ecart !== null && Math.abs(Number(e.ecart)) >= 0.1);
  const comparables = (ecarts || []).filter(e => codes.has(e.sector_code) && e.ecart !== null);

  // 1. La phrase principale : ce qui presse, ou rien.
  let titre;
  if (urgentes.length === 0) titre = "Rien ne presse aujourd'hui.";
  else if (urgentes.length === 1)
    titre = `Un appel d'offres se clôt ${phraseEcheance(urgentes[0].jours_restants)}.`;
  else
    titre = `${enLettres(urgentes.length)} appels d'offres se closent d'ici quinze jours.`;
  titre = titre.charAt(0).toUpperCase() + titre.slice(1);

  // 2. La suite : l'état des marchés, en une phrase, sans chiffre.
  const bouts = [];
  if (horsNorme.length === 0) bouts.push("Vos quatre marchés se tiennent dans leur norme habituelle");
  else if (horsNorme.length === 1) {
    const m = horsNorme[0];
    const e = etatMarche(Number(m.score_sante));
    bouts.push(`${avecArticle(m.sector_label)} ressort ${e.mot} de son niveau habituel ; les trois autres sont dans leur norme`);
  } else {
    bouts.push(`${enLettres(horsNorme.length)} marchés s'écartent de leur norme habituelle`);
  }
  if (comparables.length === 0) { /* pas de comparaison : on n'invente pas de phrase */ }
  else if (bouges.length === 0) bouts.push("aucun n'a bougé depuis une semaine");
  else if (bouges.length === 1) {
    const b = bouges[0];
    const m = marches.find(x => x.sector_code === b.sector_code);
    bouts.push(`${(m?.sector_label || b.sector_code).toLowerCase()} ${Number(b.ecart) > 0 ? "remonte" : "recule"} depuis une semaine`);
  } else bouts.push(`${enLettres(bouges.length)} ont bougé depuis une semaine`);

  return { titre, suite: bouts.join(", ") + "." };
}

function Tuile({ m, D, ecart, onClic }) {
  const score = m.score_sante === null ? null : Number(m.score_sante);
  const e = etatMarche(score);
  const serie = useMemo(() => {
    // Une seule courbe par tuile, celle qui couvre le plus de périodes parmi
    // les séries qui portent le score. Elle donne la forme, pas la valeur.
    let best = null, n = -1;
    for (const id of m.indicateurs || []) {
      const pts = (D?.valeurs || []).filter(v => v.indicator_id === id);
      if (!pts.length) continue;
      const parGeo = new Map();
      for (const p of pts) parGeo.set(p.geo, [...(parGeo.get(p.geo) || []), p]);
      for (const [, arr] of parGeo) if (arr.length > n) { n = arr.length; best = arr; }
    }
    return best ? [...best].sort((a, b) => String(a.period).localeCompare(String(b.period))).slice(-48) : null;
  }, [D, m.indicateurs]);

  // Le nombre de réserves, pas leur contenu. Le contenu est sur Fiabilité.
  const reserves = useMemo(() => {
    const r = redondances(D, m.indicateurs).length;
    const c = compositionLatence(D, m.indicateurs);
    return r + (c.avance === 0 ? 1 : 0);
  }, [D, m.indicateurs]);

  const classeEtat = score === null ? "plat" : score >= 1 ? "haut" : score <= -1 ? "bas" : "plat";
  const d = ecart && ecart.ecart !== null ? Number(ecart.ecart) : null;

  return (
    <button className="tuile" onClick={onClic}>
      <span className="tuile-nom">{m.sector_label}</span>
      <span className={"tuile-etat " + classeEtat}>{e.mot}</span>
      {serie && <span className="tuile-spark"><Sparkline points={serie} ton={e.ton} largeur={170} hauteur={30} /></span>}
      <span className="tuile-pied">
        {d === null ? "" :
         Math.abs(d) < 0.1 ? "inchangé depuis 7 j" :
         `${d > 0 ? "+" : "−"}${nb(Math.abs(d), 2)} en 7 j`}
        {reserves > 0 && (
          <span className="tuile-reserve">
            {reserves} réserve{reserves > 1 ? "s" : ""}
          </span>
        )}
      </span>
    </button>
  );
}

export default function Aujourdhui() {
  const { D, S, A, erreursV4 } = useDonnees();
  const navigate = useNavigate();

  const marches = useMemo(
    () => (S?.sante || []).filter(x => x.sector_code !== "transversal"), [S]);
  const urgentes = useMemo(() => (A?.actions || [])
    .filter(a => a.adressable >= 1 && a.jours_restants !== null && a.jours_restants <= 15)
    .sort((x, y) => x.jours_restants - y.jours_restants), [A]);
  const v = useMemo(
    () => verdictDuJour({ urgentes, marches, ecarts: S?.ecart_7j }), [urgentes, marches, S]);

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

  return (
    <div className="page">
      <header className="jour-tete">
        <span className="jour-date">{aujourdhui}</span>
        <span className="jour-etat">
          {phraseFraicheur(run.executed_at)}<br />
          données jusqu'à {phrasePeriode(S.fraicheur?.point_le_plus_recent)}
        </span>
      </header>

      <h1 className="verdict">{v.titre}</h1>
      <p className="verdict-suite">{v.suite}</p>

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

      <h2 className="section-titre">Vos marchés</h2>
      {/* La phrase est dite UNE fois. Répétée sur les quatre tuiles, elle
          donnait l'application pour cassée alors qu'elle est exacte. */}
      {(S.ecart_7j || []).filter(e => e.ecart !== null && e.sector_code !== "transversal").length === 0 && (
        <p className="tuiles-note">
          Pas de comparaison hebdomadaire cette semaine : la fenêtre d'historique a été élargie le
          24 août, et les scores d'il y a sept jours portaient sur un autre périmètre. L'écart
          redeviendra lisible à la prochaine semaine pleine.
        </p>
      )}
      <div className="tuiles">
        {marches.map(m => (
          <Tuile key={m.sector_code} m={m} D={D}
                 ecart={(S.ecart_7j || []).find(e => e.sector_code === m.sector_code)}
                 onClic={() => navigate("/marche/" + m.sector_code)} />
        ))}
      </div>

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
        ) : (
          <span>Rien n'attend votre lecture.</span>
        )}
      </div>
    </div>
  );
}
