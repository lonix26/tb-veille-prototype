import React, { useMemo, useState } from "react";
import { useParams } from "react-router-dom";
import {
  useDonnees, nb, pct, clsVar, dateCH, estAgregat, nomZone,
  serieDe, zonesDe, metrDe, BadgeStatut, MarkdownLeger
} from "../api.jsx";
import Chart from "../Chart.jsx";

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
        {franchis.length
          ? <strong>{franchis.length} franchissement{franchis.length > 1 ? "s" : ""} de seuil à examiner.</strong>
          : <>Aucun franchissement de seuil diffusable : rien ne sort de l'ordinaire des séries.</>}
        {retenues.length > 0 && <>{" "}{retenues.length} signal{retenues.length > 1 ? "s" : ""} retenu{retenues.length > 1 ? "s" : ""} (statut insuffisant), visible{retenues.length > 1 ? "s" : ""} plus bas.</>}
      </div>
      <div className="l-n">Lecture composée par calcul depuis la base — aucun modèle de langage n'écrit cette phrase.</div>
    </div>
  );
}

/* ---------- commentaire exécutif validé ---------- */
function Commentaire({ code }) {
  const { D } = useDonnees();
  if (D.commentaires === undefined) return null;
  const c = (D.commentaires || []).find(k => k.sector_code === code);
  const att = Number(D.commentaires_en_attente || 0);
  if (!c) return att ? <div className="note">Commentaire exécutif : aucun validé pour ce secteur — {att} en attente de validation humaine.</div> : null;
  return (
    <div className="carte commentaire">
      <div>
        <span className="etq e-violet">commentaire exécutif</span>
        <span className="etq e-gris">généré par {c.model} · règles RI0-RI10</span>
        <span className="etq e-vert">validé par {c.validated_by || "?"} le {dateCH(c.validated_at)}</span>
      </div>
      <div className="c-corps"><MarkdownLeger texte={c.text} /></div>
      {att > 0 && <div className="note">{att} commentaire(s) plus récent(s) en attente de validation.</div>}
    </div>
  );
}

/* ---------- franchissements de seuil, retenues comprises ---------- */
export function Alertes({ code }) {
  const { D } = useDonnees();
  if (D.alertes === undefined)
    return <div className="note">Franchissements de seuil : non interrogés (clé absente de la charge utile).</div>;
  const liste = (D.alertes || []).filter(a => code === undefined || a.sector_code === code);
  if (!liste.length) return null;
  return (
    <div className="carte">
      <div style={{ fontSize: 12, fontWeight: 650, marginBottom: 4 }}>
        Franchissements de seuil{" "}
        <span className="etq e-gris">
          {liste.filter(a => a.diffusable).length} diffusable(s) · {liste.filter(a => !a.diffusable).length} retenu(s)
        </span>
      </div>
      {liste.map((a, i) => (
        <div className="alerte" key={i}>
          <span className="a-pt" style={{ background: a.diffusable ? "var(--rouge)" : "#98a2b3" }} />
          <div>
            <div>
              <strong>{a.indicator_id}</strong> · {a.indicator_label} — {nomZone(a.geo)}, {a.period} :{" "}
              <span className={clsVar(a.glissement_annuel_pct ?? a.variation_periode_pct)}>
                {pct(a.glissement_annuel_pct ?? a.variation_periode_pct)}
              </span>{" "}
              (seuil {nb(a.seuil_materialite_pct, 1)} %)
            </div>
            {!a.diffusable && <div className="a-m">{a.motif_de_retenue}</div>}
          </div>
        </div>
      ))}
      <div className="note">
        Un franchissement « retenu » n'est pas caché : sa valeur n'a simplement pas le statut de
        validation requis pour une notification (RI5). Le motif est affiché.
      </div>
    </div>
  );
}

/* ---------- questions de veille en panneau compact ---------- */
function QuestionsVeille({ code, inds }) {
  const { D } = useDonnees();
  const qvs = (D.instanciation || [])
    .filter(q => q.sector_code === code)
    .sort((a, b) => a.watch_question_code.localeCompare(b.watch_question_code));
  if (!qvs.length) return null;
  return (
    <div className="carte">
      <div style={{ fontSize: 12, fontWeight: 650, marginBottom: 2 }}>Ce que ce secteur surveille, et pourquoi</div>
      {qvs.map(q => {
        const codes = inds
          .filter(i => (i.questions || "").split(",").includes(q.watch_question_code))
          .map(i => i.indicator_id);
        const lacune = Number(q.nb_certifies) === 0;
        return (
          <div className="qv-item" key={q.watch_question_code}>
            <div className="q-l">
              {q.watch_question_code} · {q.question_generique}{" "}
              {lacune
                ? <span className="etq e-rouge">non couverte</span>
                : <span className="etq e-gris">{codes.join(" · ")}</span>}
            </div>
            <div className="q-q">{q.question_sectorielle}</div>
            <details><summary>mécanisme causal</summary><div className="q-m">{q.mecanisme}</div></details>
          </div>
        );
      })}
      <div className="note">Une question « non couverte » est un manque affiché plutôt que caché.</div>
    </div>
  );
}

/* ---------- signaux qualitatifs validés ---------- */
function Signaux({ code }) {
  const { D } = useDonnees();
  if (D.signaux === undefined) return null;
  const liste = (D.signaux || []).filter(s => !code || s.sector_code === code || s.secteur === code);
  if (!liste.length) return null;
  const valides = liste.filter(s => (s.statut || s.status) === "valide");
  const enAttente = liste.length - valides.length;
  if (!valides.length && !enAttente) return null;
  return (
    <div className="carte">
      <div style={{ fontSize: 12, fontWeight: 650 }}>
        Signaux qualitatifs{" "}
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
        Documents choisis par le veilleur, extraits par trois modèles avec passages source
        obligatoires, validés humainement — jamais publiés sans validation.
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
        <span className="i-val">{dern ? nb(dern.part_suisse_pct) + " %" : "—"}</span>
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
                <td>{x.part_suisse_pct !== null ? nb(x.part_suisse_pct) + " %" : "—"}</td>
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
        Ratio calculé par requête sur les séries consolidées — aucun modèle n'intervient. Part du
        panier de déclarants Comtrade, non du marché mondial entier ; la part n'est calculée que si
        tous les déclarants ont soumis : la fraîcheur d'un panier est celle de son déclarant le plus lent.
      </div>
    </div>
  );
}

/* ---------- carte d'un indicateur ---------- */
function CarteIndicateur({ ind }) {
  const { D } = useDonnees();
  const [voirToutesZones, setVoirToutesZones] = useState(false);
  const zones = zonesDe(D, ind.indicator_id);
  const pays = zones.filter(g => !estAgregat(g));
  const agregats = zones.filter(g => estAgregat(g));
  const zonePrincipale = agregats[0] ?? (pays.length === 1 ? pays[0] : null);

  const parZone = useMemo(() => pays.map(g => {
    const s = serieDe(D, ind.indicator_id, g);
    const d = s[s.length - 1];
    const mm = metrDe(D, ind.indicator_id, g);
    return d ? { g, v: d.value, p: d.period, variation: mm ? mm.glissement_annuel_pct : null } : null;
  }).filter(Boolean).sort((a, b) => b.v - a.v), [D, ind.indicator_id]);

  if (!ind.observations) {
    return (
      <div className="carte ind">
        <div className="i-code">{ind.indicator_id} · {ind.category === "hard" ? "donnée officielle" : "composite"}</div>
        <div className="i-titre">{ind.label}</div>
        {ind.description_metier && <div className="i-quoi">{ind.description_metier}</div>}
        <div className="i-val neutre">—</div>
        <div className="i-seuil">
          Indicateur qualifié, collecte non instrumentée. La grille décrit ce que le dispositif est
          conçu pour suivre ; cette carte constate ce qu'il suit réellement.
        </div>
        <div className="i-pied">
          <span>{ind.source_organisation} · {ind.frequency}</span>
          <span className="etq e-gris">non instrumenté</span>
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
  const PLAF = 8;
  const zonesVisibles = voirToutesZones ? parZone : parZone.slice(0, PLAF);
  const maxV = parZone[0]?.v ?? 1;

  return (
    <div className="carte ind">
      <div className="i-code">
        {ind.indicator_id} · {ind.category === "hard" ? "donnée officielle" : "composite"}
        {ind.questions && <span className="etq e-violet" style={{ marginLeft: 6 }}>{ind.questions}</span>}
      </div>
      <div className="i-titre">{ind.label}</div>
      {ind.description_metier && <div className="i-quoi">{ind.description_metier}</div>}

      {zonePrincipale && dern && (
        <>
          <div>
            <span className="i-val">{nb(dern.value)}</span>
            <span className="i-u">{ind.unit} · {nomZone(zonePrincipale)} · {dern.period}</span>
            <span className={"etq " + (g > 0 ? "e-vert" : g < 0 ? "e-rouge" : "e-gris")} style={{ marginLeft: 8 }}>
              {pct(g)} sur un an
            </span>
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

      {pays.length > 1 && (
        <div style={{ marginTop: zonePrincipale ? 14 : 4 }}>
          {Object.values(seriesTop).some(s => s.length >= 3) && <Chart series={seriesTop} zoom />}
          <div style={{ fontSize: 11, color: "var(--gris)", textTransform: "uppercase", letterSpacing: ".05em", margin: "10px 0 6px" }}>
            Principales zones · dernière période, variation sur un an
          </div>
          {zonesVisibles.map(z => (
            <div className="zl" key={z.g}>
              <span className="zn">{nomZone(z.g)}</span>
              <span className="zb"><i style={{ width: Math.max(2, (z.v / maxV) * 100) + "%" }} /></span>
              <span className="zv">{nb(z.v)}</span>
              <span className={"zp " + clsVar(z.variation)}>{pct(z.variation)}</span>
            </div>
          ))}
          {parZone.length > PLAF && (
            <button className="rafraichir" style={{ marginTop: 8 }} onClick={() => setVoirToutesZones(v => !v)}>
              {voirToutesZones ? "Réduire" : `Afficher les ${parZone.length - PLAF} autres zones`}
            </button>
          )}
        </div>
      )}

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
export default function Secteur() {
  const { code } = useParams();
  const { D } = useDonnees();
  const inds = (D.referentiel || []).filter(i => i.sector_code === code);
  if (!inds.length) return <div className="vide">Aucun indicateur pour ce secteur.</div>;
  const lbl = inds[0].sector_label || code;
  const contexte = code === "transversal";
  const ordonnes = [...inds].sort(
    (a, b) => (b.observations > 0) - (a.observations > 0) ||
      String(a.indicator_id).localeCompare(String(b.indicator_id))
  );
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
      </div>
      <h2>Indicateurs</h2>
      <div className="grille g2">
        {ordonnes.map(i => <CarteIndicateur key={i.indicator_id} ind={i} />)}
      </div>
      <div className="grille" style={{ marginTop: 14 }}>
        <QuestionsVeille code={code} inds={inds} />
        <Signaux code={code} />
      </div>
    </div>
  );
}
