import React, { useMemo, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  useDonnees, nb, pct, clsVar, dateCH, estAgregat, nomZone,
  serieDe, zonesDe, metrDe, BadgeStatut, MarkdownLeger, relu,
  sensMouvement, SENS_ETQ, QV_LIBELLES, qvDe, syntheseZones, SEUIL_POIDS_PCT,
  alertesSignificatives, TYPE_EVT, SENS_EVT, BadgeEvenement
} from "../api.jsx";
import Chart, { TreemapParts } from "../Chart.jsx";
import { phrasePeriode } from "../phrases.jsx";

/* ---------- bandeau de lecture calculée (aucun modèle n'écrit ceci) ---------- */
function Lecture({ code, inds }) {
  const { D } = useDonnees();
  const collectes = inds.filter(i => i.observations > 0);
  const ms = collectes.map(i => metrDe(D, i.indicator_id)).filter(Boolean);
  const varsOk = ms.filter(m => m.glissement_annuel_pct !== null);
  const hausses = varsOk.filter(m => m.glissement_annuel_pct > 0).length;
  const baisses = varsOk.filter(m => m.glissement_annuel_pct < 0).length;
  const franchis = (D.alertes || []).filter(a => a.sector_code === code && a.diffusable);
  const retenues = (D.alertes || []).filter(a => a.sector_code === code && !a.diffusable);
  return (
    <div className="lecture">
      <div className="l-t">
        <strong>{collectes.length} indicateur{collectes.length > 1 ? "s" : ""} suivi{collectes.length > 1 ? "s" : ""} sur {inds.length}.</strong>{" "}
        {varsOk.length > 0 && <>Sur un an : {hausses} en progression, {baisses} en recul.{" "}</>}
        {/* Compter des SÉRIES, pas des lignes de zones (27.08) : « 127 à
            examiner » quand 123 sont les destinations d'une seule série
            surdéclarait l'urgence. */}
        {franchis.length
          ? (() => {
              // 31.08.2026 : le compteur de signalements bruts (« 127 au
              // total ») était un artefact du p90 multiplié par les zones —
              // aucun gain d'information. On compte des SÉRIES, signées.
              const series = [...new Set(franchis.map(a => a.indicator_id))];
              // Le sens d'une série se juge sur ses zones PESANTES (même base
              // que le bloc détaillé) — sinon une zone marginale à −99 % sur
              // 32 USD suffirait à peindre la série en défavorable.
              const pesantes = alertesSignificatives(D).retenues.filter(a => a.sector_code === code);
              const defav = series.filter(id =>
                pesantes.some(a => a.indicator_id === id && sensMouvement(D, a) === "defavorable")).length;
              return <strong>{series.length} série{series.length > 1 ? "s" : ""} au comportement
                inhabituel{defav ? <>, dont {defav} en mouvement défavorable</> : ", aucune en mouvement défavorable"}. Le détail est plus bas.</strong>;
            })()
          : <>Aucun mouvement inhabituel : rien ne sort de l'ordinaire des séries suivies.</>}
        {retenues.length > 0 && <>{" "}{retenues.length} signal{retenues.length > 1 ? "s" : ""} retenu{retenues.length > 1 ? "s" : ""} (statut insuffisant), visible{retenues.length > 1 ? "s" : ""} plus bas.</>}
      </div>
    </div>
  );
}

/* ---------- commentaire exécutif, relu ou non ---------- */
function Commentaire({ code }) {
  const { D } = useDonnees();
  if (D.commentaires === undefined) return null;
  const c = (D.commentaires || []).find(k => k.sector_code === code);
  const att = Number(D.commentaires_en_attente || 0);
  if (!c) return att ? <div className="note">Commentaire exécutif : aucun pour ce secteur ; {att} en attente de relecture.</div> : null;
  return (
    <div className="carte commentaire">
      <div>
        <span className="etq e-violet">commentaire exécutif</span>
        <span className="etq e-gris">généré par {c.model} · règles RI0-RI10</span>
        {relu(c)
          ? <span className="etq e-vert">relu et validé par {c.validated_by || "?"} le {dateCH(c.validated_at)}</span>
          : <span className="etq e-ambre">rédigé le {dateCH(c.created_at)}, sans relecture humaine</span>}
      </div>
      <div className="c-corps"><MarkdownLeger texte={c.text} /></div>
      {att > 0 && <div className="note">{att} commentaire(s) en attente de relecture. Ils sont affichés, avec une étiquette orange, mais personne ne les a encore vérifiés.</div>}
    </div>
  );
}

/* ---------- mouvements inhabituels, retenues comprises ---------- */
// RÉFORME DU 31.08.2026 (décision de l'étudiant : « 127 signalements,
// aucun gain d'information »). Trois changements, mesurés avant d'être
// décidés (13 zones sur les 123 de H1 pèsent ≥ 1 % du flux et portent
// 87 % de la valeur ; en queue, Namibie −99 % sur 32 USD) :
//  1. chaque franchissement de série est SIGNÉ par sens_favorable et
//     rattaché à sa question de veille — une hausse d'exportations n'est
//     pas une anomalie rouge, c'est une bonne nouvelle pour QV2 ;
//  2. « (seuil 8 %) » devient « amplitude vue moins d'une fois sur dix » —
//     le sens réel du p90, dit en français ;
//  3. les franchissements de ZONES d'une même série sont UN fait : une
//     ligne pondérée, la zone la plus lourde citée, les < 1 % écartés et
//     COMPTÉS, le détail renvoyé à la dynamique géographique (QV3) où il
//     se lit en points de part. Repli du 27.08 conservé pour l'audit.
// REGROUPEMENT DU 01.09.2026 (décision de l'étudiant : « neuf des treize
// lignes sont le même signal »). Sur l'automobile, A3 2025 montait dans
// toutes ses zones et chaque zone faisait une ligne ; une dixième ligne
// résumait les mêmes zones. Règle de RESTITUTION, pas de détection : les
// mouvements restent tous détectés et dépliables, ils sont ÉNONCÉS par
// indicateur. Trois garde-fous, posés avant d'écrire le code :
//  a. la divergence reste visible : « généralisée » seulement si toutes
//     les zones vont dans le même sens ; sinon les zones à contre-courant
//     qui pèsent sont nommées, les marginales comptées ;
//  b. un agrégat (monde, UE…) n'est pas une zone : il ne compte pas dans
//     « n zones sur n », mais il n'est jamais retiré de l'écran ;
//  c. la pastille compte les SIGNAUX après regroupement et dit à côté le
//     nombre de mouvements détectés — les deux nombres, pas un seul.
const SEUIL_DOMINANTE = 0.8;   // part des zones dans le même sens pour dire « dominante »

const signe = a => Math.sign(Number(a.glissement_annuel_pct ?? a.variation_periode_pct ?? 0));

export function Alertes({ code }) {
  const { D } = useDonnees();
  const navigate = useNavigate();
  if (D.alertes === undefined)
    return <div className="note">Mouvements inhabituels : non interrogés (clé absente de la charge utile).</div>;
  const liste = (D.alertes || []).filter(a => code === undefined || a.sector_code === code);
  if (!liste.length) return null;

  const parIndicateur = new Map();
  for (const a of liste) {
    if (!parIndicateur.has(a.indicator_id)) parIndicateur.set(a.indicator_id, []);
    parIndicateur.get(a.indicator_id).push(a);
  }

  const PT = { favorable: "var(--vert)", defavorable: "var(--rouge)", neutre: "#98a2b3" };
  const chipsQV = (id) => {
    const qv = qvDe(D, id);
    return qv ? <span className="etq e-violet">{qv} · {QV_LIBELLES[qv] || ""}</span> : null;
  };
  const chipSens = (a) => {
    const [cls, lbl] = SENS_ETQ[sensMouvement(D, a)];
    return <span className={"etq " + cls}>{lbl}</span>;
  };
  const varDe = a => pct(a.glissement_annuel_pct ?? a.variation_periode_pct);

  const ligne = (a, i) => (
    <div className="alerte" key={i}>
      <span className="a-pt" style={{ background: a.diffusable ? PT[sensMouvement(D, a)] : "#98a2b3" }} />
      <div>
        <div>
          <strong>{a.indicator_id}</strong> · {a.indicator_label} · {nomZone(a.geo)}, {a.period} :{" "}
          <span className={clsVar(a.glissement_annuel_pct ?? a.variation_periode_pct)}>{varDe(a)}</span>{" "}
          {chipSens(a)} {chipsQV(a.indicator_id)}
        </div>
        <div className="a-m">variation rare pour cette série (moins d'une fois sur dix)</div>
        {!a.diffusable && <div className="a-m">{a.motif_de_retenue}</div>}
      </div>
    </div>
  );

  // Un signal par indicateur. Jusqu'à trois mouvements, ils se lisent tels
  // quels ; au-delà, une seule ligne d'ensemble, calculée.
  const simples = [], ensembles = [];
  for (const [, rows] of parIndicateur) {
    if (rows.length <= 3) { simples.push(...rows); continue; }
    // Période courante : celle du plus grand nombre de mouvements. Les
    // autres sont des zones dont la dernière observation est plus ancienne
    // (petites destinations qui n'exportent plus) : comptées à part.
    const freq = new Map();
    for (const a of rows) freq.set(a.period, (freq.get(a.period) || 0) + 1);
    const periode = [...freq.entries()].sort((x, y) => y[1] - x[1] || (y[0] > x[0] ? 1 : -1))[0][0];
    const cur = rows.filter(a => a.period === periode);
    const anciens = rows.filter(a => a.period !== periode);
    const agregats = cur.filter(a => estAgregat(a.geo));
    const zones = cur.filter(a => !estAgregat(a.geo));
    const { retenues, ecartees } = syntheseZones(D, zones);
    const hausses = zones.filter(a => signe(a) > 0).length;
    const baisses = zones.filter(a => signe(a) < 0).length;
    const nZ = hausses + baisses;
    const sensMajoritaire = hausses >= baisses ? 1 : -1;
    const mot = sensMajoritaire > 0 ? "hausse" : "baisse";
    let qualificatif;
    if (!nZ) qualificatif = "mouvement d'ensemble";
    else if (hausses === 0 || baisses === 0) qualificatif = `${mot} généralisée`;
    else if (Math.max(hausses, baisses) / nZ >= SEUIL_DOMINANTE) qualificatif = `${mot} dominante`;
    else qualificatif = "mouvements contrastés";
    const contreCourant = retenues.filter(a => signe(a) === -sensMajoritaire);
    const contreMarginales = zones.filter(a => signe(a) === -sensMajoritaire).length - contreCourant.length;
    // Le repère : la zone de référence déclarée si elle bouge, sinon le
    // premier agrégat, sinon la zone la plus lourde.
    const ref = (D.referentiel || []).find(r => r.indicator_id === rows[0].indicator_id);
    const repere = agregats.find(a => a.geo === ref?.geo_reference) || agregats[0] || retenues[0] || cur[0];
    // Le sens du signal est celui du mouvement majoritaire des zones
    // (ou du repère quand il n'y a pas de zones), signé par sens_favorable.
    const porteur = nZ ? { ...cur[0], glissement_annuel_pct: sensMajoritaire, variation_periode_pct: sensMajoritaire } : repere;
    // L'étendue se lit sur les zones qui PÈSENT : sur les marginales, elle
    // n'est qu'un palmarès de petits nombres (Laos +989 %, Algérie +23 200 %).
    const ampleur = a => Number(a.glissement_annuel_pct ?? a.variation_periode_pct ?? 0);
    const bornes = [...(retenues.length >= 2 ? retenues : zones)].sort((x, y) => ampleur(x) - ampleur(y));
    ensembles.push({ rows, periode, cur, anciens, agregats, zones, retenues, ecartees, hausses, baisses,
      qualificatif, contreCourant, contreMarginales, repere, porteur, min: bornes[0], max: bornes[bornes.length - 1] });
  }

  const nSignaux = simples.length + ensembles.length;
  const nDefav = [...simples, ...ensembles.map(e => e.porteur)]
    .filter(a => a && a.diffusable !== false && sensMouvement(D, a) === "defavorable").length;

  return (
    <div className="carte">
      <div style={{ fontSize: 12, fontWeight: 650, marginBottom: 4 }}>
        Mouvements inhabituels{" "}
        <span className="etq e-gris">
          {nSignaux} signa{nSignaux > 1 ? "ux" : "l"}{nDefav ? ` · ${nDefav} défavorable${nDefav > 1 ? "s" : ""}` : ""}
          {liste.length > nSignaux ? ` · ${liste.length} mouvements détectés` : ""}
        </span>
      </div>
      {simples.map(ligne)}
      {ensembles.map((e, gi) => {
        const r = e.repere;
        const lis = r ? valeurLisible(r.value, r.unit) : null;
        const sens = sensMouvement(D, e.porteur);
        return (
          <div className="alerte" key={"e" + gi}>
            <span className="a-pt" style={{ background: PT[sens] }} />
            <div>
              <div>
                <strong>{e.rows[0].indicator_id}</strong> · {e.rows[0].indicator_label} · {e.periode} :{" "}
                <strong>{e.qualificatif}</strong>
                {r && estAgregat(r.geo) && <>, {nomZone(r.geo)}{" "}
                  <span className={clsVar(r.glissement_annuel_pct ?? r.variation_periode_pct)}>{varDe(r)}</span>
                  {lis && lis.val ? <> ({lis.val} {lis.unit})</> : null}</>}{" "}
                <span className={"etq " + SENS_ETQ[sens][0]}>{SENS_ETQ[sens][1]}</span> {chipsQV(e.rows[0].indicator_id)}
              </div>
              <div className="a-m">
                {e.zones.length > 0 && <>
                  {e.hausses > 0 && `${e.hausses} zone${e.hausses > 1 ? "s" : ""} en hausse`}
                  {e.hausses > 0 && e.baisses > 0 && ", "}
                  {e.baisses > 0 && `${e.baisses} en baisse`}
                  {e.retenues.length > 0 && <> · {e.retenues.length} zone{e.retenues.length > 1 ? "s" : ""} pesant ≥ {SEUIL_POIDS_PCT} % du flux
                    {e.retenues[0] && <>, la plus lourde {nomZone(e.retenues[0].geo)} ({varDe(e.retenues[0])})</>}
                    {e.retenues.length > 1 && e.min && e.max && <>, de {varDe(e.min)} ({nomZone(e.min.geo)}) à {varDe(e.max)} ({nomZone(e.max.geo)})</>}</>}
                  {e.ecartees > 0 && <> · {e.ecartees} zone{e.ecartees > 1 ? "s" : ""} marginale{e.ecartees > 1 ? "s" : ""} (&lt; {SEUIL_POIDS_PCT} %) écartée{e.ecartees > 1 ? "s" : ""}, trop petite{e.ecartees > 1 ? "s" : ""} pour peser</>}
                  .
                </>}
                {e.agregats.length > 1 && <> {e.agregats.length} agrégats en mouvement (hors décompte des zones).</>}
                {e.anciens.length > 0 && <> {e.anciens.length} zone{e.anciens.length > 1 ? "s" : ""} dont la dernière observation est antérieure à {e.periode}, non comptée{e.anciens.length > 1 ? "s" : ""}.</>}
              </div>
              {(e.contreCourant.length > 0 || e.contreMarginales > 0) && (
                <div className="a-m" style={{ color: "var(--ambre)" }}>
                  À contre-courant :{" "}
                  {e.contreCourant.length > 0 && <>{e.contreCourant.map(a => `${nomZone(a.geo)} (${varDe(a)})`).join(", ")}, qui pèse{e.contreCourant.length > 1 ? "nt" : ""}</>}
                  {e.contreCourant.length > 0 && e.contreMarginales > 0 && " ; "}
                  {e.contreMarginales > 0 && <>{e.contreMarginales} zone{e.contreMarginales > 1 ? "s" : ""} marginale{e.contreMarginales > 1 ? "s" : ""} (&lt; {SEUIL_POIDS_PCT} %)</>}.
                </div>
              )}
              {e.zones.length > 0 && (
                <div className="a-m">
                  Le déplacement se lit en points de part dans la{" "}
                  <span className="src-inline" onClick={() => navigate("/qv/" + e.rows[0].sector_code)}>
                    dynamique géographique (QV3) ↗
                  </span>
                </div>
              )}
              <details style={{ marginTop: 4 }}>
                <summary style={{ cursor: "pointer", fontSize: 12, color: "var(--gris)" }}>
                  les {e.rows.length} mouvements détectés : agrégats, puis zones par poids décroissant
                </summary>
                <div style={{ marginTop: 6 }}>
                  {[...e.agregats, ...e.retenues, ...e.zones.filter(a => !e.retenues.includes(a)), ...e.anciens].map(ligne)}
                </div>
              </details>
            </div>
          </div>
        );
      })}
      <div className="note">
        Un mouvement est dit « inhabituel » quand il dépasse le seuil calibré sur l'historique
        de sa propre série. Vert : le mouvement est favorable ; rouge : défavorable. Au-delà de
        trois mouvements sur un même indicateur, ils sont énoncés en un signal, dépliable ; les
        zones à contre-courant sont nommées. Un mouvement « retenu » n'est pas caché, son motif
        est affiché. Les zones trop petites pour peser sont écartées et comptées.
      </div>
    </div>
  );
}

/* ---------- une question de veille, avec ses réponses ---------- */
// RÉORGANISATION DU 27.08.2026 (v9, décision de l'étudiant : « un tableau
// qu'un décideur peut lire »). La page était organisée par INDICATEURS — la
// structure des données ; le décideur, lui, pense par QUESTIONS. La thèse du
// travail (questions → indicateurs → lecture) devient la structure de
// l'écran : chaque question instanciée est une section, qui porte la
// question en toutes lettres, ses indicateurs, ses faits validés — ou son
// vide, déclaré. L'ancien panneau récapitulatif est absorbé ici.
const ORDRE_CRITICITE = { dominante: 0, significative: 1, marginale: 2 };
const CRITICITE_ETQ = {
  dominante: ["e-violet", "question dominante"],
  significative: ["e-gris", "question significative"],
  marginale: ["e-gris", "question marginale"]
};

// LA RÉPONSE CALCULÉE (28.08.2026). Le gabarit vit au référentiel
// (sector_watch_questions.reponse_gabarit) ; l'écran ne fait que résoudre
// ses jetons {ID.champ} avec les valeurs réelles (v_dernier_point, zone de
// référence). Un jeton irrésolu supprime la phrase entière — jamais de
// phrase à trous, jamais de valeur inventée. Aucun modèle n'écrit ni ne
// choisit un mot : c'est la doctrine du 12.08 (« la lecture est calculée,
// jamais rédigée ») appliquée à la réponse de chaque question.
function resoudreGabarit(gabarit, D) {
  if (!gabarit) return null;
  let ok = true;
  const texte = gabarit.replace(/\{([A-Z]+\d+)\.(val|unit|ga|vp|pt|per)\}/g, (_, id, champ) => {
    const ref = (D?.referentiel || []).find(r => r.indicator_id === id);
    const m = ref ? metrDe(D, id, ref.geo_reference) : metrDe(D, id);
    if (!m) { ok = false; return ""; }
    const lis = valeurLisible(m.value, ref?.unit || "");
    switch (champ) {
      case "val": return m.value === null ? (ok = false, "") : lis.val;
      case "unit": return lis.unit || "";
      case "ga": return m.glissement_annuel_pct === null || m.glissement_annuel_pct === undefined
        ? (ok = false, "") : pct(Number(m.glissement_annuel_pct));
      case "vp": return m.variation_periode_pct === null || m.variation_periode_pct === undefined
        ? (ok = false, "") : pct(Number(m.variation_periode_pct));
      case "pt": {
        const va = m.valeur_annee_precedente;
        if (va === null || va === undefined) { ok = false; return ""; }
        const d = Number(m.value) - Number(va);
        return (d > 0 ? "+" : "") + nb(d, 1);
      }
      case "per": return m.period ? phrasePeriode(m.period) : (ok = false, "");
      default: return (ok = false, "");
    }
  });
  return ok ? texte : null;
}

function SectionQuestion({ q, cartes, indsQuestion, deja, vide }) {
  const { D } = useDonnees();
  const reponse = resoudreGabarit(q.reponse_gabarit, D);
  const [clsCrit, lblCrit] = CRITICITE_ETQ[q.criticite] || ["e-gris", q.criticite];
  /* Trois états (27.08) : couverte par du certifié ; « à confirmer » avec
     porteurs vivants ; découverte. Un porteur sans observation ne compte
     pas — la couverture nominale est le défaut que le § 8.4.5 dénonce. */
  const vivants = indsQuestion.filter(i => i.observations > 0);
  const certifiee = indsQuestion.some(i => i.status === "certifie" && i.observations > 0);
  const aConfirmer = !certifiee && vivants.length > 0;
  // Quatrième état (même jour) : un porteur en vitrine SANS observation —
  // H10 en attente de corpus — n'est ni une couverture ni un vide muet.
  const enAttente = !certifiee && !aConfirmer && indsQuestion.length > 0;
  return (
    <section style={{ marginTop: 26 }}>
      <div style={{ borderLeft: "3px solid var(--violet, #7c5cd6)", paddingLeft: 12, marginBottom: 10 }}>
        <div style={{ fontSize: 11, color: "var(--gris)", textTransform: "uppercase", letterSpacing: ".06em" }}>
          {q.watch_question_code} · {q.question_generique}
          <span className={"etq " + clsCrit} style={{ marginLeft: 8 }}>{lblCrit}</span>
          {certifiee
            ? null
            : aConfirmer
              ? <span className="etq e-ambre" style={{ marginLeft: 6 }}>couverte « à confirmer »</span>
              : enAttente
                ? <span className="etq e-ambre" style={{ marginLeft: 6 }}>instrumentée · en attente de corpus</span>
                : <span className="etq e-rouge" style={{ marginLeft: 6 }}>non couverte</span>}
        </div>
        <div style={{ fontSize: 15.5, fontWeight: 650, marginTop: 3 }}>{q.question_sectorielle}</div>
        {reponse && (
          <div style={{ fontSize: 13.5, marginTop: 6, padding: "7px 10px", background: "#f2f6f4",
                        borderRadius: 8, lineHeight: 1.45 }}>
            <strong style={{ fontSize: 10.5, textTransform: "uppercase", letterSpacing: ".05em",
                             color: "var(--gris)", marginRight: 6 }}>Réponse</strong>
            {reponse}
            <span style={{ display: "block", fontSize: 10.5, color: "var(--gris)", marginTop: 3 }}>
            </span>
          </div>
        )}
        <details style={{ marginTop: 2 }}>
          <summary style={{ fontSize: 11.5, color: "var(--gris)", cursor: "pointer" }}>mécanisme causal</summary>
          <div className="q-m">{q.mecanisme}</div>
        </details>
        {deja.length > 0 && (
          <div style={{ fontSize: 11.5, color: "var(--gris)", marginTop: 4 }}>
            Instruite aussi par {deja.map(d => `${d.id} (→ ${d.sous})`).join(" · ")}, présenté plus haut.
          </div>
        )}
      </div>
      {vide && (
        <div className="carte">
          <div style={{ fontSize: 13 }}>
            <span className="etq e-rouge">lacune déclarée</span>{" "}
            Aucun indicateur ne porte cette question à l'écran. Le manque est affiché plutôt
            que caché : aucune série publique ne la mesure, et le motif de la lacune est
            documenté au rapport (§ 8.4.5).
          </div>
        </div>
      )}
      {cartes}
    </section>
  );
}

/* ---------- signaux qualitatifs validés ---------- */
// `qv` (27.08.2026) : restreint aux signaux d'une question de veille, pour
// l'affichage sous la section de la question qu'ils instruisent — un signal
// est rattaché à une question en base, l'écran respecte ce rattachement.
// `compact` : rendu sans carte englobante, pour vivre dans une section.
function Signaux({ code, qv, compact }) {
  const { D } = useDonnees();
  if (D.signaux === undefined) return null;
  const liste = (D.signaux || []).filter(s =>
    (!code || s.sector_code === code || s.secteur === code) &&
    (!qv || s.watch_question_code === qv));
  if (!liste.length) return null;
  const valides = liste.filter(s => (s.statut || s.status) === "valide");
  const enAttente = liste.filter(s => (s.statut || s.status) === "a_valider").length;
  if (!valides.length && !enAttente) return null;
  const corps = (
    <>
      <div style={{ fontSize: 12, fontWeight: 650 }}>
        {compact ? "Fait validé sur cette question" : "Signaux qualitatifs"}{" "}
        <span className="etq e-gris">{valides.length} validé(s){enAttente ? ` · ${enAttente} en attente` : ""}</span>
      </div>
      {valides.map((s, i) => (
        <div className="qv-item" key={i}>
          <div className="q-l">{s.evenement || s.titre || "Signal"}</div>
          <div className="q-q">
            {s.acteur ? `Acteur : ${s.acteur} · ` : ""}
            {s.echeance ? `Échéance : ${s.echeance} · ` : ""}
            {s.zone ? `Zone : ${s.zone}` : ""}
          </div>
        </div>
      ))}
      <div className="note">
        Document choisi par le veilleur, extraits par trois modèles avec passages source
        obligatoires, validation humaine. Rien n'est publié sans validation.
      </div>
    </>
  );
  return compact ? <div style={{ marginTop: 10 }}>{corps}</div> : <div className="carte">{corps}</div>;
}

/* ---------- motorisations automobile (dérivation SQL, § 8.4.3) ---------- */
// La décomposition que les séries seules ne montrent pas : le marché total
// retrouve son niveau PENDANT QUE le thermique décline — la recomposition,
// pas la contraction. Total et thermique sont DÉRIVÉS (total = EV / part) ;
// les valeurs source étant arrondies, ce sont des ordres de grandeur.
function Motorisations() {
  const { D } = useDonnees();
  const m = D?.motorisations || [];
  if (m.length < 2) return null;
  const en_M = v => v === null || v === undefined ? null : Number(v) / 1e6;
  const series = {
    "ventes totales (dérivé)": m.map(x => ({ period: x.period, value: en_M(x.ventes_totales) })),
    "thermique (dérivé)": m.map(x => ({ period: x.period, value: en_M(x.ventes_thermiques) })),
    "électrique (IEA)": m.map(x => ({ period: x.period, value: en_M(x.ventes_ev) }))
  };
  const dern = m[m.length - 1];
  const picTh = m.reduce((a, x) => Number(x.ventes_thermiques) > Number(a.ventes_thermiques) ? x : a, m[0]);
  return (
    <div className="carte ind pleine">
      <div className="i-code">DÉRIVATION · v_motorisations_automobile</div>
      <div className="i-titre">Le marché mondial par motorisation : où la demande se recompose</div>
      <div className="i-quoi">
        Le volume thermique mondial a passé son pic en {picTh.period}
        ({nb(en_M(picTh.ventes_thermiques), 1)} M de voitures) et n'est jamais remonté :
        {" "}{nb(en_M(dern.ventes_thermiques), 1)} M en {dern.period}, pendant que le marché
        total retrouvait ~{nb(en_M(dern.ventes_totales), 0)} M. La demande adressable par la
        sous-traitance ne se contracte pas : elle se déplace de motorisation.
      </div>
      <Chart series={series} hauteur={230} />
      <div className="note">
        Électrique collecté (A3, IEA) ; part collectée (A11) ; total et thermique <strong>dérivés
        par vue SQL</strong> (total = électrique ÷ part). Valeurs
        source en millions arrondis : lire des ordres de grandeur, pas des dénombrements.
      </div>
    </div>
  );
}

/* ---------- indicateur synthétique (Contexte) ---------- */
export function Synthetique({ pleine }) {
  const { D } = useDonnees();
  if (D.synthetique === undefined) return null;
  const s = D.synthetique || [];
  if (!s.length) return null;
  const calc = s.filter(x => x.part_suisse_pct !== null);
  const dern = calc[calc.length - 1];
  return (
    <div className={"carte ind" + (pleine ? " pleine" : "")}>
      <div className="i-code">INDICATEUR SYNTHÉTIQUE · engagement de la ratification</div>
      <div className="i-titre">Part suisse du commerce horloger mondial (SH 91)</div>
      <div>
        <span className="i-val">{dern ? nb(dern.part_suisse_pct) + " %" : "n.d."}</span>
        <span className="i-u">du panier de déclarants · {dern ? dern.period : ""}</span>
      </div>
      <table style={{ marginTop: 12 }}>
        <thead>
          <tr><th>Année</th><th>Part suisse</th><th>CHE (mia USD)</th><th>Panier (mia USD)</th><th>Déclarants</th></tr>
        </thead>
        <tbody>
          {s.map(x => (
            <React.Fragment key={x.period}>
              <tr>
                <td><strong>{x.period}</strong></td>
                <td>{x.part_suisse_pct !== null ? nb(x.part_suisse_pct) + " %" : "n.d."}</td>
                <td>{nb(x.che_mia_usd)}</td>
                <td>{nb(x.total_panier_mia_usd)}</td>
                <td>{x.nb_declarants}/{x.nb_declarants_attendus}</td>
              </tr>
              {x.completude && (
                <tr><td /><td colSpan={4} style={{ fontSize: 11.5, color: "var(--ambre)", fontStyle: "italic" }}>{x.completude}</td></tr>
              )}
            </React.Fragment>
          ))}
        </tbody>
      </table>
      <div className="note">
        Ratio calculé par requête sur les séries consolidées. Part du
        panier de déclarants Comtrade, non du marché mondial entier ; la part n'est calculée que si
        tous les déclarants ont soumis : la fraîcheur d'un panier est celle de son déclarant le plus lent.
      </div>
    </div>
  );
}

/* ---------- carte d'un indicateur ---------- */
// UN RATIO NE SE CLASSE PAS PAR NIVEAU (27.08.2026). Classer des parts par
// valeur donne le palmarès des pionniers — Norvège 97 %, Népal 68 % — vrai
// statistiquement, vide décisionnellement : quelques milliers de voitures.
// La question du décideur est « quelle est la part LÀ OÙ LES VOLUMES SONT ».
// Pour les indicateurs de part qui ont un compagnon de volume dans la même
// base, les zones sont donc classées par le volume du compagnon (Chine
// 53 %, Europe 28 %, USA 10 %) — leçon T2 du panneau de panier, appliquée
// jusqu'au classement. Constaté par l'étudiant sur la carte A11.
const VOLUMES_COMPAGNONS = {
  A11: { id: "A3", libelle: "zones classées par volume de ventes électriques (A3), part affichée (A11)" }
};

// Un montant en dollars ne se lit pas en dollars (27.08.2026, revue
// visuelle) : « 3 241 199 778 USD » se lit « 3,24 mia USD ». Réservé aux
// grandeurs monétaires — un compte d'unités reste un compte.
const MONETAIRE = /USD|CHF|EUR/i;
function valeurLisible(v, unit) {
  const x = Number(v);
  if (!MONETAIRE.test(unit || "") || !Number.isFinite(x) || Math.abs(x) < 1e6)
    return { val: nb(v), unit };
  if (Math.abs(x) >= 1e9) return { val: nb(x / 1e9, 2), unit: "mia " + unit.replace(/^(mio|mia)\s*/i, "") };
  return { val: nb(x / 1e6, 1), unit: "mio " + unit.replace(/^(mio|mia)\s*/i, "") };
}

function CarteIndicateur({ ind }) {
  const { D, S } = useDonnees();
  const [voirToutesZones, setVoirToutesZones] = useState(false);
  const zones = zonesDe(D, ind.indicator_id);
  const pays = zones.filter(g => !estAgregat(g));
  const agregats = zones.filter(g => estAgregat(g));
  /* La zone principale est la ZONE DE RÉFÉRENCE déclarée au référentiel —
     celle sur laquelle les métriques sont calculées (v_metriques) — quand
     ses valeurs existent. `agregats[0]` n'était qu'un heuristique : dès
     qu'un indicateur porte plusieurs agrégats (A11 : World ET Advanced
     Economies), il affichait le mauvais chiffre en gros. Constaté le
     27.08.2026 à l'arrivée d'A11. */
  const zonePrincipale =
    (ind.geo_reference && zones.includes(ind.geo_reference) ? ind.geo_reference : null)
    ?? agregats[0] ?? (pays.length === 1 ? pays[0] : null);

  const compagnon = VOLUMES_COMPAGNONS[ind.indicator_id];
  // Volume du compagnon par zone, à sa dernière période — la clé de tri
  // des indicateurs de part (voir le commentaire de VOLUMES_COMPAGNONS).
  const volumeDe = useMemo(() => {
    if (!compagnon) return null;
    const m = new Map();
    for (const v of (D?.valeurs || []).filter(x => x.indicator_id === compagnon.id)) {
      const prev = m.get(v.geo);
      if (!prev || String(v.period) > String(prev.period)) m.set(v.geo, { period: v.period, value: Number(v.value) });
    }
    return m;
  }, [D, compagnon]);

  const parZone = useMemo(() => pays.map(g => {
    const s = serieDe(D, ind.indicator_id, g);
    const d = s[s.length - 1];
    const mm = metrDe(D, ind.indicator_id, g);
    return d ? { g, v: d.value, p: d.period, variation: mm ? mm.glissement_annuel_pct : null } : null;
  }).filter(Boolean).sort((a, b) => volumeDe
    ? (volumeDe.get(b.g)?.value ?? 0) - (volumeDe.get(a.g)?.value ?? 0)
    : b.v - a.v), [D, ind.indicator_id, volumeDe]);

  if (!ind.observations) {
    /* Deux absences qui ne disent pas la même chose (27.08.2026) : la
       collecte jamais instrumentée, et l'indicateur d'intensité dont le
       corpus du mois est SOUS LE PLANCHER de calculabilité — une absence
       mesurée, que l'écran doit expliquer plutôt que taire. */
    const attente = (S?.intensite_attente || []).find(a => a.indicator_id === ind.indicator_id);
    return (
      <div className="carte ind">
        <div className="i-code">{ind.indicator_id} · {ind.category === "hard" ? "collecté par code" : "composite · IA + validation"}</div>
        <div className="i-titre">{ind.label}</div>
        {ind.description_metier && <div className="i-quoi">{ind.description_metier}</div>}
        <div className="i-val neutre">n.d.</div>
        {attente ? (
          <div className="i-seuil">
            Aucun point calculable à ce jour : {nb(attente.n_tries)} items triés sur ce marché
            en {attente.periode} pour un plancher de {nb(attente.plancher)} : en deçà, un seul
            article déplacerait la part de plus de cinq points. La série s'activera quand le
            corpus franchira le plancher, sans changement de définition.
          </div>
        ) : (
          <div className="i-seuil">
            Indicateur qualifié, collecte non instrumentée. La grille décrit ce que le dispositif est
            conçu pour suivre ; cette carte constate ce qu'il suit réellement.
          </div>
        )}
        <div className="i-pied">
          <span>{ind.source_organisation} · {ind.frequency}</span>
          {attente
            ? <span className="etq e-ambre">en attente de corpus</span>
            : <span className="etq e-gris">non instrumenté</span>}
        </div>
      </div>
    );
  }

  const m = zonePrincipale ? metrDe(D, ind.indicator_id, zonePrincipale) : null;
  const sPrincipale = zonePrincipale ? serieDe(D, ind.indicator_id, zonePrincipale) : [];
  const dern = sPrincipale[sPrincipale.length - 1];
  const g = m ? m.glissement_annuel_pct : null;
  const statut = m ? m.validation_status : (serieDe(D, ind.indicator_id)[0] || {}).validation_status;
  const top5 = parZone.slice(0, 5);
  const seriesTop = Object.fromEntries(top5.map(z => [z.g, serieDe(D, ind.indicator_id, z.g)]));
  const PLAF = 10;

  return (
    <div className="carte ind">
      <div className="i-code">
        {ind.indicator_id} · {ind.category === "hard" ? "collecté par code" : "composite · IA + validation"}
        {ind.questions && <span className="etq e-violet" style={{ marginLeft: 6 }}>{ind.questions}</span>}
      </div>
      <div className="i-titre">{ind.label}</div>
      {ind.description_metier && <div className="i-quoi">{ind.description_metier}</div>}

      {zonePrincipale && dern && (
        <>
          <div>
            <span className="i-val">{valeurLisible(dern.value, ind.unit).val}</span>
            <span className="i-u">{valeurLisible(dern.value, ind.unit).unit} · {nomZone(zonePrincipale)} · {dern.period}</span>
            {/* Deux corrections du 27.08 (constat de l'étudiant sur A11) :
                1. une PART varie en POINTS, pas en pourcentage d'elle-même —
                   « 21 → 25 » se lit « +4 pt », jamais « +19,1 % » ;
                2. un sens déclaré NEUTRE (0) ne se colore pas — une part
                   d'électrique qui monte n'est ni bonne ni mauvaise en soi. */}
            {(() => {
              const sens = ind.sens_favorable === null || ind.sens_favorable === undefined
                ? 1 : Number(ind.sens_favorable);
              const enPoints = ind.unit === "pourcentage";
              const vAvant = m ? m.valeur_annee_precedente : null;
              const dPt = enPoints && vAvant !== null && vAvant !== undefined
                ? Number(dern.value) - Number(vAvant) : null;
              const affiche = enPoints
                ? (dPt === null ? "n.d." : (dPt > 0 ? "+" : "") + nb(dPt, 1) + " pt")
                : pct(g);
              const signe = enPoints ? dPt : g;
              const cls = sens === 0 || signe === null || signe === 0 ? "e-gris"
                : signe * sens > 0 ? "e-vert" : "e-rouge";
              return (
                <span className={"etq " + cls} style={{ marginLeft: 8 }}>
                  {affiche} sur un an
                </span>
              );
            })()}
          </div>
          <Chart
            series={{ [zonePrincipale]: sPrincipale }}
            refLine={m?.moyenne_mobile_annuelle ? Number(m.moyenne_mobile_annuelle) : undefined}
            refLabel="moyenne mobile"
            zoom={sPrincipale.length > 18}
          />
          {m && m.franchissement === "franchi" && (
            <div className="i-seuil">
              <span className="etq e-rouge">seuil franchi</span>
              la variation annuelle ({pct(m.glissement_annuel_pct)}) dépasse le seuil de matérialité
              ({nb(m.seuil_materialite_pct, 1)} %) : ce mouvement sort de l'ordinaire pour cette série.
            </div>
          )}
          {m && String(m.franchissement || "").startsWith("sous") && (
            <div className="i-seuil">
              Sous le seuil de matérialité ({nb(m.seuil_materialite_pct, 1)} %) : variation dans
              l'ordinaire de la série.
            </div>
          )}
          {m?.completude && <div className="i-comp">{m.completude}</div>}
        </>
      )}

      {pays.length > 1 && (() => {
        /* Panneau de panier (21.08.2026). Parts et variation de PART en
           points — le déplacement de la demande que QV2/QV3 demandent de
           voir — calculées au titre de la dernière période COMMUNE (la
           fraîcheur d'un panier est celle de son déclarant le plus lent),
           et UNIQUEMENT pour les grandeurs additives : une part d'indices
           ou de taux ne signifie rien (leçon T2). */
        const additif = /USD|EUR|CHF|unité|appareil|nombre/i.test(ind.unit || "");
        const periodesParZone = new Map(pays.map(z0 => [z0, new Set(serieDe(D, ind.indicator_id, z0).map(p => p.period))]));
        const toutes = [...new Set(pays.flatMap(z0 => [...periodesParZone.get(z0)]))].sort();
        const communes = toutes.filter(p => pays.every(z0 => periodesParZone.get(z0).has(p)));
        const pRef = communes.length ? communes[communes.length - 1] : toutes[toutes.length - 1];
        const pRecente = toutes[toutes.length - 1];
        const pPrev = String(parseInt(pRef.slice(0, 4), 10) - 1) + pRef.slice(4);
        const lignesRef = pays.map(z0 => {
          const s = serieDe(D, ind.indicator_id, z0);
          const v = s.find(x => x.period === pRef);
          const vp = s.find(x => x.period === pPrev);
          return v ? { g: z0, v: v.value, vp: vp ? vp.value : null } : null;
        }).filter(Boolean).sort((a, b) => volumeDe
          ? (volumeDe.get(b.g)?.value ?? 0) - (volumeDe.get(a.g)?.value ?? 0)
          : b.v - a.v);
        if (!lignesRef.length) return null;
        const sommePanier = lignesRef.reduce((s, z) => s + z.v, 0);
        const sommePanierPrev = lignesRef.every(z => z.vp !== null)
          ? lignesRef.reduce((s, z) => s + z.vp, 0) : null;
        /* Dénominateur : le TOTAL MONDIAL publié par la source quand
           l'indicateur en porte une ligne (H1 -> W00, A3 -> World…) —
           avec un résidu « Autres marchés » ; sinon, le panier suivi,
           seul dénominateur honnête pour un panier de déclarants. */
        const serieMonde = additif && agregats.length ? serieDe(D, ind.indicator_id, agregats[0]) : [];
        const vMonde = serieMonde.find(x => x.period === pRef);
        const vMondePrev = serieMonde.find(x => x.period === pPrev);
        const mondeOk = vMonde && vMonde.value >= sommePanier;
        const total = mondeOk ? vMonde.value : sommePanier;
        /* Total de l'an passé : la ligne monde quand elle existe — chaque
           zone calcule alors son Δpart indépendamment des autres. Exiger
           que TOUS les partenaires aient une valeur homologue éteignait
           toute la colonne dès qu'un micro-partenaire manquait :
           l'unanimité au niveau de l'affichage, corrigée le 21.08. */
        const totalPrev = mondeOk
          ? (vMondePrev ? vMondePrev.value : null)
          : sommePanierPrev;
        const varTotal = totalPrev ? (total - totalPrev) / totalPrev * 100 : null;
        const reste = mondeOk ? {
          g: "__reste__", v: total - sommePanier, vp: null
        } : null;
        const manquants = pays.filter(z0 => !periodesParZone.get(z0).has(pRecente));
        // Le max sert l'échelle des barres — indépendant de l'ordre de tri
        // (avec un compagnon de volume, la première ligne n'est plus le max).
        const maxRef = Math.max(...lignesRef.map(z => z.v));
        /* Enrichissement en une passe, puis LECTURE D'ANALYSTE (21.08) :
           personne ne lit 99 lignes — on lit la concentration (treemap),
           les mouvements de part (gagnants/perdants), et le classement
           complet seulement sur demande, replié. */
        const lignes = lignesRef.map(z => {
          const part = additif && total > 0 ? z.v / total * 100 : null;
          const partPrev = additif && totalPrev && z.vp !== null ? z.vp / totalPrev * 100 : null;
          return {
            ...z, part,
            dPart: part !== null && partPrev !== null ? part - partPrev : null,
            varAn: z.vp ? (z.v - z.vp) / z.vp * 100 : null,
            nda: /^[SXF]\d/.test(String(z.g))
          };
        });
        const top3Part = additif && total > 0
          ? lignes.slice(0, 3).reduce((s, z) => s + (z.part || 0), 0) : null;
        const mouvants = lignes.filter(z => z.dPart !== null && !z.nda);
        const gagnants = [...mouvants].sort((a, b) => b.dPart - a.dPart).filter(z => z.dPart > 0.05).slice(0, 5);
        const perdants = [...mouvants].sort((a, b) => a.dPart - b.dPart).filter(z => z.dPart < -0.05).slice(0, 5);
        const resteTreemap = (reste && reste.v > 0 ? reste.v : 0) + lignes.slice(12).reduce((s, z) => s + z.v, 0);
        const treemapItems = additif && total > 0
          ? [...lignes.slice(0, 12).map(z => ({ name: nomZone(z.g), value: z.v, part: z.part, dPart: z.dPart })),
             ...(resteTreemap > 0 ? [{ name: "Autres", value: resteTreemap, part: resteTreemap / total * 100, dPart: null }] : [])]
          : null;
        const ligneBar = z => (
          <div className="zl" key={z.g}
               style={additif ? { gridTemplateColumns: "110px 1fr 90px 58px 62px 62px" } : undefined}>
            <span className="zn">{nomZone(z.g)}</span>
            <span className="zb"><i style={{ width: Math.max(2, (z.v / maxRef) * 100) + "%" }} /></span>
            <span className="zv">{nb(z.v)}</span>
            {additif && <span className="zp">{z.part !== null ? nb(z.part, 1) + " %" : "n.d."}</span>}
            {additif && (
              <span className={"zp " + clsVar(z.dPart)}>
                {z.dPart !== null ? (z.dPart > 0 ? "+" : "") + nb(z.dPart, 1) + " pt" : "n.d."}
              </span>
            )}
            {/* Pour une part, la variation par zone se lit en POINTS et sans
                couleur (sens neutre) — même règle que le badge de la carte. */}
            {compagnon && ind.unit === "pourcentage"
              ? <span className="zp">{z.vp !== null && z.vp !== undefined
                  ? ((z.v - z.vp > 0 ? "+" : "") + nb(z.v - z.vp, 1) + " pt") : "n.d."}</span>
              : <span className={"zp " + clsVar(z.varAn)}>{pct(z.varAn)}</span>}
          </div>
        );
        const mvt = z => (
          <div key={z.g} style={{ display: "flex", justifyContent: "space-between", gap: 8, fontSize: 12.5, padding: "3px 0" }}>
            <span style={{ fontWeight: 600 }}>{nomZone(z.g)}</span>
            <span>
              <span className={clsVar(z.dPart)}>{(z.dPart > 0 ? "+" : "") + nb(z.dPart, 1)} pt</span>
              <span style={{ color: "var(--gris)", marginLeft: 8 }}>{pct(z.varAn)}</span>
            </span>
          </div>
        );
        return (
          <div style={{ marginTop: zonePrincipale ? 14 : 4 }}>
            {Object.values(seriesTop).some(s => s.length >= 3) && <Chart series={seriesTop} zoom />}
            {additif && total > 0 && !mondeOk && (
              <div style={{ margin: "12px 0 2px" }}>
                <span className="i-val" style={{ fontSize: 21 }}>{valeurLisible(total, ind.unit).val}</span>
                <span className="i-u">{valeurLisible(total, ind.unit).unit} · marché du panier suivi · {pRef}</span>
                {varTotal !== null && (
                  <span className={"etq " + (varTotal > 0 ? "e-vert" : varTotal < 0 ? "e-rouge" : "e-gris")} style={{ marginLeft: 8 }}>
                    {pct(varTotal)} sur un an
                  </span>
                )}
              </div>
            )}

            {additif && treemapItems ? (
              <>
                {top3Part !== null && (
                  <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))", gap: 10, margin: "12px 0 2px" }}>
                    <div style={{ background: "#f6f8fa", borderRadius: 10, padding: "9px 12px" }}>
                      <div style={{ fontSize: 10.5, color: "var(--gris)", textTransform: "uppercase", letterSpacing: ".05em" }}>Concentration</div>
                      <div style={{ fontSize: 15, fontWeight: 700, marginTop: 2 }}>{nb(top3Part, 0)} %</div>
                      <div style={{ fontSize: 11, color: "var(--encre2)" }}>sur les 3 premières zones</div>
                    </div>
                    {gagnants[0] && (
                      <div style={{ background: "#f6f8fa", borderRadius: 10, padding: "9px 12px" }}>
                        <div style={{ fontSize: 10.5, color: "var(--gris)", textTransform: "uppercase", letterSpacing: ".05em" }}>Gagne du terrain</div>
                        <div style={{ fontSize: 15, fontWeight: 700, marginTop: 2 }}>{nomZone(gagnants[0].g)}</div>
                        <div style={{ fontSize: 11 }} className="hausse">+{nb(gagnants[0].dPart, 1)} pt de part sur un an</div>
                      </div>
                    )}
                    {perdants[0] && (
                      <div style={{ background: "#f6f8fa", borderRadius: 10, padding: "9px 12px" }}>
                        <div style={{ fontSize: 10.5, color: "var(--gris)", textTransform: "uppercase", letterSpacing: ".05em" }}>Cède du terrain</div>
                        <div style={{ fontSize: 15, fontWeight: 700, marginTop: 2 }}>{nomZone(perdants[0].g)}</div>
                        <div style={{ fontSize: 11 }} className="baisse">{nb(perdants[0].dPart, 1)} pt de part sur un an</div>
                      </div>
                    )}
                  </div>
                )}
                <TreemapParts items={treemapItems} />
                {(gagnants.length > 0 || perdants.length > 0) && (
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14, marginTop: 10 }}>
                    <div>
                      <div style={{ fontSize: 10.5, color: "var(--gris)", textTransform: "uppercase", letterSpacing: ".05em", marginBottom: 4 }}>
                        Gagnent du terrain · {pRef} vs {pPrev}
                      </div>
                      {gagnants.length ? gagnants.map(mvt) : <div className="note">aucun gain matériel</div>}
                    </div>
                    <div>
                      <div style={{ fontSize: 10.5, color: "var(--gris)", textTransform: "uppercase", letterSpacing: ".05em", marginBottom: 4 }}>
                        Cèdent du terrain · {pRef} vs {pPrev}
                      </div>
                      {perdants.length ? perdants.map(mvt) : <div className="note">aucun recul matériel</div>}
                    </div>
                  </div>
                )}
                <details style={{ marginTop: 10 }}>
                  <summary>Classement complet ({lignes.length} zones) · valeur, part, Δ part, variation</summary>
                  <div style={{ marginTop: 8 }}>{lignes.map(ligneBar)}</div>
                </details>
              </>
            ) : (
              <>
                <div style={{ fontSize: 11, color: "var(--gris)", textTransform: "uppercase", letterSpacing: ".05em", margin: "8px 0 6px" }}>
                  {compagnon
                    ? <>Les premiers marchés en volume, au titre de {pRef}</>
                    : <>Niveaux au titre de {pRef}, variation sur un an</>}
                </div>
                {(voirToutesZones ? lignes : lignes.slice(0, PLAF)).map(ligneBar)}
                {lignes.length > PLAF && (
                  <button className="rafraichir" style={{ marginTop: 8 }} onClick={() => setVoirToutesZones(v => !v)}>
                    {voirToutesZones ? "Réduire" : `Afficher les ${lignes.length - PLAF} autres zones`}
                  </button>
                )}
                {compagnon && (
                  <div className="note" style={{ marginTop: 8 }}>
                    Une part ne se classe pas par niveau : les records appartiennent aux petits
                    marchés pionniers, sans poids pour la décision. Ici, {compagnon.libelle} :
                    la part est lue là où les volumes sont.
                  </div>
                )}
              </>
            )}
            {pRecente !== pRef && manquants.length > 0 && (
              <div className="note">
                {pRecente} est encore incomplète ({manquants.slice(0, 6).map(nomZone).join(", ")}{manquants.length > 6 ? "…" : ""} sans soumission) :
                lecture au titre de {pRef}, la dernière période où tout le panier a déclaré. Classer sur
                l'année incomplète donnerait une part nulle aux retardataires.
              </div>
            )}
            {additif && (
              <div className="note">
                {mondeOk
                  ? `Parts du marché total tel que publié par la source (ligne monde). Les ${lignesRef.length} zones suivies en couvrent ${nb(sommePanier / total * 100, 1)} %, le reste est agrégé en « Autres ».`
                  : `Parts du panier suivi (${lignesRef.length} zones) : la source publie par déclarant, sans ligne monde. Le total mondial n'existe donc pas en une seule série, et le dire vaut mieux que l'estimer.`}
                {" "}« pt » = variation de la part en points de pourcentage : le déplacement de la demande
                entre zones, l'information que QV2 et QV3 demandent.
              </div>
            )}
          </div>
        );
      })()}

      <div className="i-pied">
        <span>{ind.source_organisation} · {ind.frequency}</span>
        <BadgeStatut statut={statut} />
      </div>
      <details>
        <summary>provenance et fraîcheur</summary>
        <div className="prov">
          {ind.observations} observation(s) · {ind.p_min} → {ind.p_max} · dernier run {ind.dernier_run}
          {m?.raw_ref && <> · pièce d'audit : <code>{m.raw_ref}</code></>}
          {ind.source_url && <> · <a href={ind.source_url} target="_blank" rel="noopener noreferrer">source</a></>}
        </div>
      </details>
    </div>
  );
}

/* ---------- page secteur ---------- */
// V9 (27.08.2026) — la page est structurée par QUESTIONS DE VEILLE, dans
// l'ordre de leur criticité : la thèse du travail (questions → indicateurs
// → lecture) devient la structure de l'écran. Seule la GRILLE SUIVIE est
// montrée au décideur ; la réserve qualifiée se compte en pied de page et
// se consulte dans Fiabilité — c'est la distinction vitrine/référentiel du
// § 8.8, appliquée à l'écran qui la motivait.
export default function Secteur() {
  const { code } = useParams();
  const { D } = useDonnees();
  const tous = (D.referentiel || []).filter(i => i.sector_code === code);
  if (!tous.length) return <div className="vide">Aucun indicateur pour ce secteur.</div>;
  const enVitrine = i => i.en_vitrine === undefined ? i.observations > 0 : !!i.en_vitrine;
  const inds = tous.filter(enVitrine);
  const reserve = tous.length - inds.length;
  const lbl = tous[0].sector_label || code;
  const contexte = code === "transversal";

  // Les questions instanciées du marché, criticité d'abord — le décideur
  // lit d'abord ce qui compte le plus.
  const questions = (D.instanciation || [])
    .filter(q => q.sector_code === code)
    .sort((a, b) =>
      (ORDRE_CRITICITE[a.criticite] ?? 9) - (ORDRE_CRITICITE[b.criticite] ?? 9) ||
      a.watch_question_code.localeCompare(b.watch_question_code));

  // Chaque indicateur est présenté UNE fois, sous la question la plus
  // critique qu'il sert ; les questions suivantes y renvoient au lieu de
  // dupliquer la carte.
  const sertQ = (i, qv) => String(i.questions || "").split(",").includes(qv);
  const attribution = new Map(); // indicator_id -> qv d'affichage
  for (const q of questions)
    for (const i of inds)
      if (sertQ(i, q.watch_question_code) && !attribution.has(i.indicator_id))
        attribution.set(i.indicator_id, q.watch_question_code);
  const ordonne = liste => [...liste].sort(
    (a, b) => (b.observations > 0) - (a.observations > 0) ||
      String(a.indicator_id).localeCompare(String(b.indicator_id)));
  // Indicateurs en vitrine qu'aucune question instanciée ne rattache — ne
  // doit pas exister (le déclencheur l'impose), mais l'écran ne cache rien.
  const orphelins = ordonne(inds.filter(i => !attribution.has(i.indicator_id)));

  return (
    <div className="page" key={code}>
      <div className="topbar"><h1>{lbl}</h1></div>
      {contexte && (
        <div className="note" style={{ marginBottom: 12 }}>
          Cette page ne décrit pas un secteur : elle donne le contexte général. Quand un secteur
          bouge, est-ce lui qui bouge, ou toute l'économie ?
        </div>
      )}
      <div className="grille">
        <Lecture code={code} inds={inds} />
        <Commentaire code={code} />
        {contexte && <Synthetique />}
        <Alertes code={code} />
        <Evenements code={code} />
      </div>

      {questions.map(q => {
        const qv = q.watch_question_code;
        const indsQuestion = inds.filter(i => sertQ(i, qv));
        const ici = ordonne(indsQuestion.filter(i => attribution.get(i.indicator_id) === qv));
        const deja = indsQuestion
          .filter(i => attribution.get(i.indicator_id) !== qv)
          .map(i => ({ id: i.indicator_id, sous: attribution.get(i.indicator_id) }));
        const cartes = [
          ...ici.map(i => <CarteIndicateur key={i.indicator_id} ind={i} />),
          ...(code === "automobile" && qv === "QV4" ? [<Motorisations key="motorisations" />] : [])
        ];
        return (
          <SectionQuestion key={qv} q={q} indsQuestion={indsQuestion} deja={deja}
            vide={cartes.length === 0 && deja.length === 0}
            cartes={[
              <div className="grille g2" key="g">{cartes}</div>,
              <Signaux key="s" code={code} qv={qv} compact />
            ]} />
        );
      })}

      {orphelins.length > 0 && (
        <section style={{ marginTop: 26 }}>
          <h2>Autres indicateurs suivis</h2>
          <div className="grille g2">
            {orphelins.map(i => <CarteIndicateur key={i.indicator_id} ind={i} />)}
          </div>
        </section>
      )}

      {reserve > 0 && (
        <div className="note" style={{ marginTop: 22 }}>
          {reserve} indicateur{reserve > 1 ? "s" : ""} qualifié{reserve > 1 ? "s" : ""} en
          réserve pour ce marché, hors de la grille suivie, consultable{reserve > 1 ? "s" : ""} dans
          Fiabilité · grille. La grille montre ce que le dispositif suit ; la réserve, ce qu'il
          sait suivre.
        </div>
      )}
    </div>
  );
}


/* ---------- événements typés du marché (31.08.2026) ---------- */
// « 26 items triés » ne dit rien ; « 3 fermetures ce mois » dit tout.
// Lecture par modèle UNIQUE (le régime du triage, § 9.5.1) : tout est
// badgé « non relu » tant qu'aucun humain n'a tranché — jamais servi
// comme fait établi. Route réelle : cette page (Secteur), pas Marche —
// leçon du 31.08 : Marche.jsx n'est plus routée depuis la v9.
const domaine = u => { try { return new URL(u).hostname.replace(/^www\./, ""); } catch { return null; } };

function Evenements({ code }) {
  const { D } = useDonnees();
  const types = (D?.evenements_types || []).filter(v => v.sector_code === code);
  const recents = (D?.evenements_recents || []).filter(e => e.sector_code === code);
  if (!types.length && !recents.length) return null;
  const parType = new Map();
  for (const v of types) parType.set(v.type_evenement, (parType.get(v.type_evenement) || 0) + v.n);
  return (
    <div className="carte">
      <div style={{ fontSize: 12, fontWeight: 650, marginBottom: 6 }}>
        Ce qui s'est passé : événements lus dans les flux
      </div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 8 }}>
        {/* « autre » est écarté des puces : un type qui ne type pas n'informe pas —
            il reste compté dans la note et consultable en base. */}
        {[...parType.entries()].filter(([ty]) => ty !== "autre").sort((a, b) => b[1] - a[1]).map(([ty, n]) => (
          <span key={ty} className={"etq " + (TYPE_EVT[ty] || TYPE_EVT.autre)[0]}>
            {n} · {(TYPE_EVT[ty] || TYPE_EVT.autre)[1]}
          </span>
        ))}
        <span className="etq e-gris">deux derniers mois{parType.has("autre") ? ` · ${parType.get("autre")} sans type` : ""}</span>
      </div>
      {recents.slice(0, 6).map(e => (
        <div className="alerte" key={e.evenement_id}>
          <span className="a-pt" style={{ background:
            { opportunite: "var(--vert)", menace: "var(--rouge)", neutre: "#98a2b3" }[e.sens_sous_traitance] }} />
          <div>
            <div>
              <span className={"etq " + (TYPE_EVT[e.type_evenement] || TYPE_EVT.autre)[0]}>{(TYPE_EVT[e.type_evenement] || TYPE_EVT.autre)[1]}</span>{" "}
              <span className={"etq " + (SENS_EVT[e.sens_sous_traitance] || SENS_EVT.neutre)[0]}>{(SENS_EVT[e.sens_sous_traitance] || SENS_EVT.neutre)[1]}</span>{" "}
              <strong>{e.acteur || "acteur non précisé"}</strong>{e.zone ? <> · {e.zone}</> : null} · {dateCH(e.date_publication)}
            </div>
            <div className="a-m">{e.resume} <BadgeEvenement e={e} /></div>
            {/* Le lien vers l'article est ce qui permet de juger sur pièce : le résumé
                est celui d'un modèle non relu, l'article est la source. Sans ce lien,
                « rattaché à son article » n'était vrai qu'en base (constat du 01.09). */}
            {e.url && (
              <div className="a-m" style={{ marginTop: 2 }}>
                <a href={e.url} target="_blank" rel="noopener noreferrer">{e.titre || "ouvrir l'article"} ↗</a>
                {domaine(e.url) && <span style={{ color: "var(--gris)" }}> · {domaine(e.url)}</span>}
              </div>
            )}
          </div>
        </div>
      ))}
      <div className="note">
        Événements extraits des items de flux jugés pertinents au triage, par un modèle de
        lecture unique, sur le titre seul. Le résumé est celui du modèle ; l'article lié
        est la source, et c'est lui qui fait foi. Chaque événement porte son statut de
        relecture. Un décompte d'événements n'est pas une statistique officielle :
        c'est ce que la presse professionnelle a rapporté.
      </div>
    </div>
  );
}
