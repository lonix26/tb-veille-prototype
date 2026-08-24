import React from "react";
import { useNavigate } from "react-router-dom";
import { useDonnees, nb, pct, clsVar, nomZone, dateCH, MarkdownLeger, LienSource,
         alertesSignificatives, SEUIL_POIDS_PCT } from "../api.jsx";

// =====================================================================
// ÉCRAN 1 — « Cette semaine ». Question : dois-je m'inquiéter, et de quoi ?
// ZÉRO GRAPHIQUE, à dessein (conception v4). La réponse est le titre ;
// la courbe, quand elle vient, est une pièce justificative — et elle vit
// à l'écran 2.
// =====================================================================

// Le score est un écart-type. « +0,6 » ne dit rien à un décideur ; « légèrement
// au-dessus de sa base » le dit. Les bornes ne sont pas inventées : ce sont les
// paliers d'usage de l'écart standardisé (0,5 · 1 · 2), et ils sont affichés à
// l'écran pour être contestables. Le sens (au-dessus = favorable) vient des
// déclarations sens_favorable, pas du signe brut.
const PALIERS = [
  { seuil: 0.5, mot: "dans sa norme habituelle",   ton: "t-neutre" },
  { seuil: 1.0, mot: "légèrement au-dessus",       ton: "t-bon",   negatif: "légèrement en dessous",       tonNeg: "t-faible" },
  { seuil: 2.0, mot: "nettement au-dessus",        ton: "t-bon",   negatif: "nettement en dessous",        tonNeg: "t-faible" },
  { seuil: Infinity, mot: "très au-dessus de sa base", ton: "t-bon", negatif: "très en dessous de sa base", tonNeg: "t-faible" },
];
function lireScore(score) {
  const a = Math.abs(score);
  const p = PALIERS.find(x => a < x.seuil) || PALIERS[PALIERS.length - 1];
  if (a < 0.5) return { mot: p.mot, ton: p.ton };
  return score >= 0 ? { mot: p.mot, ton: p.ton } : { mot: p.negatif, ton: p.tonNeg };
}

// Position de l'aiguille sur une règle bornée à ±2 écarts-types.
function positionAiguille(score) {
  const borne = 2;
  const clamp = Math.max(-borne, Math.min(borne, score));
  return (50 + 50 * clamp / borne);
}


// =====================================================================
// EFFET PAYS — le croisement que le socle transversal rend possible.
//
// Le cadre du chapitre 8 pose un socle d'attribution dont la fonction est
// de distinguer un choc PROPRE à un marché d'un mouvement général. Ce
// bloc en fait la même chose sur l'axe géographique : quand un pays
// diverge de la même façon sur DEUX secteurs sans rapport, ce n'est plus
// une nouvelle sectorielle, c'est un effet pays. Aucun indicateur pris
// isolément ne le montre — c'est le croisement qui le produit.
// =====================================================================

function EffetPays({ divergences }) {
  const reelles = (divergences || []).filter(d => d.divergence);
  if (!reelles.length) return null;

  // Un pays qui diverge sur plusieurs secteurs : le regroupement EST le constat.
  const parPays = {};
  reelles.forEach(d => { (parPays[d.premier_marche] ||= []).push(d); });
  const croises = Object.entries(parPays).filter(([, l]) =>
    new Set(l.map(d => d.sector_code)).size >= 2);

  return (
    <div className="effet">
      <div className="ef-titre">Ce qui traverse les marchés</div>
      {croises.map(([pays, liste]) => (
        <p key={pays} className="ef-constat">
          <strong>{nomZone(pays)} diverge sur {liste.length} secteurs sans rapport entre eux</strong>
          {" — "}
          {liste.map((d, i) => (
            <span key={d.indicator_id}>
              {i > 0 ? ", " : ""}{d.sector_code} ({d.indicator_id}) : {pct(d.premier_variation_pct)}
              {" "}contre {pct(d.var_moy_ponderee)} pour les autres marchés
            </span>
          ))}
          . Un mouvement qui se répète sur des marchés indépendants ne se lit pas comme une
          nouvelle sectorielle : c'est un <strong>effet pays</strong>, et il appelle une
          explication d'un autre ordre — politique commerciale, change, demande intérieure.
          Le dispositif le constate ; il ne le tranche pas.
        </p>
      ))}
      {!croises.length && reelles.map(d => (
        <p key={d.indicator_id} className="ef-constat">
          <strong>{nomZone(d.premier_marche)}</strong>, premier débouché de {d.sector_code}
          {" "}({nb(d.premier_part_pct, 1)} %), évolue à {pct(d.premier_variation_pct)} quand la
          moyenne pondérée des {d.n_autres} autres fait {pct(d.var_moy_ponderee)}.
        </p>
      ))}
      <p className="ef-pied">
        Constat calculé, non rédigé. Divergence déclarée quand les signes s'opposent et que
        l'écart atteint 5 points, sur les marchés pesant au moins 1 % de leur indicateur —
        les deux seuils sont affichés pour être contestés. Le détail par marché figure sous la
        question de veille « dynamique géographique » de chaque secteur.
      </p>
    </div>
  );
}

function TuileSante({ s, onClic }) {
  const calcule = s.etat === "calcule";
  const score = s.score_sante;
  // La couleur ne s'allume qu'au-delà du palier de 0,5 : peindre en rouge un
  // écart que le texte qualifie de « normal » serait surdéclarer par la couleur.
  const cls = !calcule ? "neutre"
    : Math.abs(score) < 0.5 ? "neutre"
    : score > 0 ? "hausse" : "baisse";
  return (
    <div className="carte kpi cliquable" onClick={onClic} role="button" tabIndex={0}
         onKeyDown={e => e.key === "Enter" && onClic()}>
      <div className="k-l">{s.sector_label}</div>
      {calcule ? (
        <>
          <div className={"k-v " + cls}>{score > 0 ? "+" : ""}{nb(score, 2)}</div>
          <div className={"k-mot " + lireScore(score).ton}>{lireScore(score).mot}</div>
          {/* La règle : elle rend le chiffre comparable d'un marché à l'autre. */}
          <div className="regle" title="échelle en écarts-types, bornée à ±2">
            <div className="r-zone-norme" />
            <div className="r-zero" />
            <div className="r-aiguille" style={{ left: positionAiguille(score) + "%" }} />
          </div>
          <div className="regle-bornes"><span>−2</span><span>norme</span><span>+2</span></div>
          <div className="k-s">
            écart standardisé, {s.n_indicateurs_orientables} indicateur
            {s.n_indicateurs_orientables > 1 ? "s" : ""} orienté
            {s.n_indicateurs_orientables > 1 ? "s" : ""} · base {s.profondeur_min} points
          </div>
        </>
      ) : (
        <>
          {/* La conception l'exige en TOUTES LETTRES : pas d'icône, pas de tiret,
              pas de case vide — la phrase, pour que la limite se lise. */}
          <div className="k-v base-insuffisante">base insuffisante</div>
          <div className="k-s">
            {s.n_indicateurs_orientables || 0} indicateur orientable sur {s.indicateurs_certifies} certifiés —
            il en faut au moins deux pour qu'une moyenne ait un sens
          </div>
        </>
      )}
      <div className="k-t">
        {s.indicateurs ? String(s.indicateurs).replace(/[{}]/g, "").split(",").filter(Boolean).join(" · ") : "—"}
      </div>
    </div>
  );
}


// Le commentaire exécutif est désormais SECTIONNÉ (refonte du 24.08.2026) :
// la réponse d'abord, la méthode ensuite. L'écran exploite cette structure —
// la lecture du marché et sa conséquence pour un sous-traitant sont montrées,
// le reste se déplie. Tronquer à la première phrase, comme le faisait la
// version précédente, jetait précisément la partie décisionnelle.
function sections(texte) {
  const brut = String(texte || "");
  // Le modèle titre ses sections de plusieurs façons selon les exécutions :
  // « **Ce qu'il faut retenir** », « **1. Ce qu'il faut retenir** », ou encore
  // « ## 1. Ce qu'il faut retenir ». Constaté le 24.08 : le socle transversal
  // employait la troisième forme et sa carte s'affichait brute. On accepte les
  // trois plutôt que d'imposer une forme au modèle — la consigne porte sur le
  // CONTENU, contraindre le balisage n'ajouterait rien et casserait au premier
  // écart de rédaction.
  const trouve = titre => {
    const marque = "(?:\\*\\*|#{1,4}\\s*)?\\s*(?:\\d\\.\\s*)?";
    const re = new RegExp(marque + titre + "\\s*(?:\\*\\*)?\\s*[—:-]?\\s*([\\s\\S]*?)(?=(?:\\*\\*|#{1,4}\\s*)?\\s*(?:\\d\\.\\s*)?(?:Ce que cela change|À surveiller|Fiabilité|Réserves de méthode)|$)", "i");
    const m = brut.match(re);
    if (!m) return null;
    // Nettoie un éventuel reste de balisage en tête ou en queue de section.
    return m[1].replace(/^\s*[*#\s—:-]+/, "").replace(/[*#\s]+$/, "").trim() || null;
  };
  return {
    retenir: trouve("Ce qu'il faut retenir"),
    consequence: trouve("Ce que cela change pour un sous-traitant"),
    surveiller: trouve("À surveiller"),
    fiabilite: trouve("Fiabilité"),
    reserves: trouve("Réserves de méthode"),
    brut
  };
}

function CarteCommentaire({ c, secteur, navigate }) {
  const [deplie, setDeplie] = React.useState(false);
  const s = sections(c.text);
  return (
    <div className="carte commentaire">
      <div className="c-sec">{secteur?.sector_label || c.sector_code}</div>
      <div className="c-txt">
        <MarkdownLeger texte={s.retenir || s.brut.replace(/\*\*/g, "").slice(0, 240)} />
      </div>
      {s.consequence && (
        <div className="c-consequence">
          <span className="c-cons-l">Pour un sous-traitant</span>
          <MarkdownLeger texte={s.consequence} />
        </div>
      )}
      {s.surveiller && (
        <div className="c-surveiller"><strong>À surveiller —</strong> {s.surveiller}</div>
      )}
      <div className="c-pied">
        <span className="etq e-vert">validé</span>
        {c.validated_by} · {dateCH(c.validated_at)} · {c.model}
        <button className="filtre" style={{ padding: "2px 9px", fontSize: 11 }}
                onClick={() => setDeplie(!deplie)}>
          {deplie ? "masquer" : "fiabilité et réserves"}
        </button>
        <span className="src-inline" onClick={() => navigate("/qv/" + c.sector_code)}>
          voir les séries ↗
        </span>
      </div>
      {deplie && (
        <div className="c-reserves">
          {s.fiabilite && <p><strong>Fiabilité —</strong> {s.fiabilite}</p>}
          {s.reserves && <p><strong>Réserves de méthode —</strong> {s.reserves}</p>}
          {!s.fiabilite && !s.reserves && <p className="prov">Aucune réserve consignée.</p>}
        </div>
      )}
    </div>
  );
}

export default function CetteSemaine() {
  const { D, S, G, erreursV4, GEO } = useDonnees();
  const navigate = useNavigate();

  if (!S) return (
    <div className="page"><div className="topbar"><h1>Cette semaine</h1></div>
      <div className="vide"><strong>Le point de lecture « santé » ne répond pas.</strong><br />
        L'écran ne peut pas se peupler et ne l'invente pas.<br />
        <span style={{ fontSize: 12 }}>{erreursV4?.["/sante"]}</span></div>
    </div>
  );

  const sante = S.sante || [];
  const commentaires = D?.commentaires || [];
  // Règle partagée avec les pastilles de navigation — voir api.jsx.
  const { toutes: alertes, retenues: significatives, ecartees } = alertesSignificatives(D);
  const majeures = [...significatives]
    .sort((x, y) => Math.abs(Number(y.glissement_annuel_pct) || 0)
                  - Math.abs(Number(x.glissement_annuel_pct) || 0))
    .slice(0, 6);
  const signaux = (G?.signaux || []);
  const recents = signaux.filter(s => {
    if (!s.validated_at) return false;
    const j = (Date.now() - new Date(s.validated_at)) / 86400000;
    return j <= 14;
  });
  const run = S.run_courant || {};

  return (
    <div className="page">
      <div className="topbar">
        <h1>Cette semaine</h1>
        <div className="meta">run {run.run_id ?? "—"} · {dateCH(run.executed_at)}</div>
      </div>

      <p className="lecture">
        Quatre marchés et un socle transversal. Le score est l'écart de la dernière valeur
        à la base de sa propre série, orienté par le sens de lecture déclaré — au-dessus de
        zéro, le secteur est au-dessus de sa base. Il s'exprime en écarts-types : sous 0,5
        le marché est <strong>dans sa norme habituelle</strong> (zone grise de la règle),
        au-delà de 1 l'écart est <strong>net</strong>, au-delà de 2 il est rare. Un score
        n'est pas une prévision : c'est la position d'aujourd'hui par rapport au passé
        collecté, rien de plus.
      </p>

      {GEO && <EffetPays divergences={GEO.divergences} />}

      <div className="grille g4">
        {sante.filter(s => s.sector_code !== "transversal")
              .map(s => <TuileSante key={s.sector_code} s={s} onClic={() => navigate("/qv/" + s.sector_code)} />)}
      </div>
      <div className="grille g4" style={{ marginTop: 12 }}>
        {sante.filter(s => s.sector_code === "transversal")
              .map(s => <TuileSante key={s.sector_code} s={s} onClic={() => navigate("/qv/" + s.sector_code)} />)}
      </div>

      <h2 className="s-titre">Ce que disent les marchés</h2>
      {commentaires.length === 0 ? (
        <div className="vide">Aucun commentaire exécutif validé. Le non-validé ne s'affiche pas.</div>
      ) : (
        <div className="grille g2">
          {commentaires.map(c => (
            <CarteCommentaire key={c.commentary_id} c={c}
              secteur={sante.find(s => s.sector_code === c.sector_code)}
              navigate={navigate} />
          ))}
        </div>
      )}

      <h2 className="s-titre">Ce qui a bougé — signaux validés des 14 derniers jours</h2>
      {recents.length === 0 ? (
        <div className="vide">
          Aucun signal validé sur les quatorze derniers jours.
          {signaux.length > 0 && <> {signaux.length} signal{signaux.length > 1 ? "aux" : ""} validé{signaux.length > 1 ? "s" : ""} plus ancien{signaux.length > 1 ? "s" : ""} — voir le radar.</>}
        </div>
      ) : (
        <div className="liste-signaux">
          {recents.map(s => (
            <div key={s.signal_id} className="ligne-signal">
              <span className="etq e-violet">{s.sector_label}</span>
              <span className="etq e-gris">{s.watch_question_code}</span>
              <span className="sig-evt">{s.evenement}</span>
              {s.echeance && <span className="sig-ech">échéance {s.echeance}</span>}
              <LienSource href={s.source_doc} />
            </div>
          ))}
        </div>
      )}

      <h2 className="s-titre">Seuils franchis</h2>
      {alertes.length === 0 ? (
        <div className="vide">Aucun franchissement de seuil diffusable.</div>
      ) : (
        <>
          {/* Un écran d'ouverture ne déroule pas 194 lignes : les plus marqués,
              puis le décompte. Le reste se lit au niveau du secteur, là où il a
              du sens. Le nombre total est TOUJOURS dit — plafonner en silence
              ferait passer un extrait pour un inventaire. */}
          <div className="liste-signaux">
            {majeures.map((a, i) => (
              <div key={i} className="ligne-signal">
                <span className="etq e-rouge">{a.indicator_id}</span>
                <span className="sig-evt">{a.indicator_label}</span>
                <span className="sig-act">{nomZone(a.geo)} · {a.period}</span>
                <span className={"sig-ech " + clsVar(a.glissement_annuel_pct)}>
                  {pct(a.glissement_annuel_pct)} sur un an
                </span>
                <span className="prov">
                  seuil {nb(a.seuil_materialite_pct, 0)} %
                  {a.poids_pct !== null && <> · poids {nb(a.poids_pct, 1)} %</>}
                </span>
                <LienSource href={a.source_url} titre={a.source_organisation} />
              </div>
            ))}
          </div>
          <div className="note" style={{ marginTop: 8 }}>
            {alertes.length} franchissements diffusables au total.
            {ecartees > 0 && <> <strong>{ecartees}</strong> portent sur des marchés pesant moins
              de {SEUIL_POIDS_PCT} % de leur indicateur et sont écartés de cet écran : sur une
              série à longue traîne, une variation relative énorme sur un marché minuscule est
              un artefact, pas un signal. Ils restent lisibles au niveau du secteur.</>}
            {" "}Les {majeures.length} plus marqués parmi les {significatives.length} retenus
            sont affichés.
          </div>
        </>
      )}

      {/* Compteur, jamais le contenu — analogue de la règle RI5 : ce qui n'est
          pas validé se compte, il ne s'affiche pas. */}
      <div className="compteur-attente">
        {nb(S.items_en_attente_examen, 0)} items de flux en attente d'examen humain
        {S.commentaires_en_attente > 0 && <> · {S.commentaires_en_attente} commentaire(s) en attente de validation</>}
        <small>Leur contenu n'est pas affiché : il n'a pas été examiné.</small>
      </div>

      <div className="note" style={{ marginTop: 18 }}>
        Fraîcheur du registre : point le plus récent {S.fraicheur?.point_le_plus_recent ?? "—"},
        le plus ancien des derniers points {S.fraicheur?.point_le_plus_ancien ?? "—"}.
        Run {run.run_id ?? "—"} ({run.status ?? "—"}).
      </div>
    </div>
  );
}
