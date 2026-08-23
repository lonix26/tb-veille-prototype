import React from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useDonnees, nb, pct, clsVar, dateCH, nomZone, estAgregat,
         BadgeStatut, MarkdownLeger, LienSource } from "../api.jsx";
import Chart from "../Chart.jsx";

// =====================================================================
// ÉCRAN 2 — Secteur : la question avant la courbe.
// Les questions de veille sont les TITRES DE SECTION, dans l'ordre.
// Sous chaque question : la réponse, puis les preuves. Une question sans
// indicateur ni signal s'affiche quand même, marquée « non couvert » —
// c'est la calculabilité de l'absence rendue visible.
// =====================================================================

// CORRECTION DU 23.08.2026 — la liste des questions était écrite en dur
// (QV1..QV5). Le socle transversal, dont les sept indicateurs sont rattachés
// à QV0, n'avait donc AUCUNE section correspondante : ses cinq sections
// s'affichaient « non couvert » et ses indicateurs n'apparaissaient nulle
// part. La liste est désormais lue dans `sector_watch_questions` via
// v_instanciation_qv — c'est le cadre à deux niveaux du ch. 8 : cinq angles
// sectoriels pour les quatre marchés, QV0 pour le socle transversal.

function Preuve({ ind, D, navigate }) {
  const serie = (D.valeurs || [])
    .filter(v => v.indicator_id === ind.indicator_id)
    .sort((a, b) => String(a.period).localeCompare(String(b.period)));
  const zones = [...new Set(serie.map(v => v.geo))];
  const zone = zones.find(estAgregat) || zones[0];
  const points = serie.filter(v => v.geo === zone);
  const m = (D.metriques || []).find(x => x.indicator_id === ind.indicator_id && x.geo === zone);
  const dernier = points[points.length - 1];

  return (
    <div className="carte preuve">
      <div className="p-tete">
        <div>
          <div className="p-titre">{ind.label}</div>
          <div className="p-meta">
            {ind.indicator_id} · {ind.unit} · {ind.frequency} · zone {nomZone(zone)}
            {ind.latence && <span className={"etq lat-" + ind.latence}>{ind.latence}</span>}
          </div>
        </div>
        <div className="p-val">
          {dernier ? nb(dernier.value) : "—"}
          {m?.variation_pct !== undefined && m?.variation_pct !== null &&
            <span className={"p-var " + clsVar(m.variation_pct)}>{pct(m.variation_pct)}</span>}
        </div>
      </div>
      {/* La base est TRACÉE, pas seulement affirmée. Le score de santé se lit
          « écart à la base » : sans cette ligne, le graphique ne permet pas de
          vérifier l'écart annoncé. Elle n'est dessinée que si le calcul a
          réellement eu lieu — une moyenne partielle est signalée sous la courbe. */}
      {points.length > 1 &&
        <Chart series={{ [zone]: points.map(p => ({ period: p.period, value: Number(p.value) })) }}
               refLine={m?.moyenne_mobile_annuelle ?? undefined}
               refLabel={m?.moyenne_mobile_annuelle != null
                 ? "base " + nb(m.moyenne_mobile_annuelle)
                 : undefined}
               hauteur={170} />}
      {points.length > 1 && m?.moyenne_mobile_annuelle != null && (
        <p className="base-note">
          Base tracée : moyenne mobile sur {m.nb_points_moyenne} point
          {m.nb_points_moyenne > 1 ? "s" : ""}
          {m.nb_points_attendus && m.nb_points_moyenne < m.nb_points_attendus
            ? " des " + m.nb_points_attendus + " attendus — moyenne partielle"
            : ""}
          {m.debut_fenetre ? ", depuis " + m.debut_fenetre : ""}.
          {m.ecart_a_la_moyenne_pct != null &&
            <> Dernière valeur à <strong>{pct(m.ecart_a_la_moyenne_pct)}</strong> de cette base.</>}
        </p>
      )}
      {/* Une ligne tracée sur trois points annuels se lit comme une trajectoire alors
          qu'elle ne relie que trois observations. Le dire sous le graphique coûte une
          phrase et évite une lecture fausse — cf. T4, PIB mondial, plat à 3,4 %. */}
      {points.length > 1 && points.length < 5 && (
        <p className="avert-serie">
          {points.length} points seulement : la ligne relie des observations, elle ne décrit
          pas une trajectoire.
        </p>
      )}
      {/* Un indicateur certifié mais jamais collecté n'est pas une case vide :
          c'est un trou déclaré de la grille. Le dire, plutôt que d'afficher « — ». */}
      {points.length === 0 && (
        <p className="non-collecte">
          <strong>Aucune observation au registre.</strong> Cet indicateur est certifié dans la
          grille du chapitre 8, mais son connecteur n'a pas encore été mis en service — il ne
          contribue donc ni au score de santé du marché, ni à la réponse portée par la question
          de veille ci-dessus.
        </p>
      )}
      <div className="p-pied">
        <BadgeStatut statut={dernier?.validation_status} />
        <span>{ind.source_organisation}</span>
        {dernier && <span>dernier point {dernier.period}</span>}
        <LienSource href={ind.source_url} titre={ind.source_organisation} />
        <span className="src-inline" onClick={() => navigate("/secteur/" + ind.sector_code)}>
          série complète ↗
        </span>
      </div>
    </div>
  );
}

export default function SecteurQV() {
  const { code } = useParams();
  const { D, S, G } = useDonnees();
  const navigate = useNavigate();
  if (!D) return <div className="page"><div className="vide">Chargement…</div></div>;

  const referentiel = (D.referentiel || []).filter(i => i.sector_code === code);
  const secteur = S?.sante?.find(x => x.sector_code === code);
  const libelle = secteur?.sector_label || referentiel[0]?.sector_label || code;
  const instanciation = (D.instanciation || []).filter(q => q.sector_code === code);
  const couverture = (D.couverture_qv || []).filter(c => c.sector_code === code);
  const commentaire = (D.commentaires || []).find(c => c.sector_code === code);
  // Les questions applicables au secteur, dans l'ordre, telles que déclarées.
  const questionsDuSecteur = [...new Set(instanciation.map(q => q.watch_question_code))].sort();
  const signaux = (G?.signaux || []).filter(s => s.sector_code === code);

  return (
    <div className="page">
      <div className="topbar">
        <h1>{libelle}</h1>
        <div className="meta">
          {secteur?.etat === "calcule"
            ? <>santé {secteur.score_sante > 0 ? "+" : ""}{nb(secteur.score_sante, 2)}</>
            : <>santé : base insuffisante</>}
        </div>
      </div>

      {/* Texte piloté par les données : le socle transversal n'a qu'une question
          (QV0, attribution), les quatre marchés en ont cinq. Écrire « les cinq
          questions » en dur donnait un bandeau faux sur le socle. */}
      <p className="lecture">
        {questionsDuSecteur.length > 1 ? (
          <>Les {questionsDuSecteur.length} questions de veille structurent la lecture. Sous
          chacune : ce que l'on peut en dire, puis les séries et les signaux qui l'établissent.
          Une question sans matière reste affichée — savoir ce qu'on ne mesure pas fait partie
          du dispositif.</>
        ) : (
          <>Le socle transversal ne répond pas aux questions sectorielles : il porte la question
          d'attribution, qui sert de dénominateur commun aux quatre marchés. Sous elle, les
          séries qui l'établissent.</>
        )}
      </p>

      {questionsDuSecteur.map(qv => {
        const inst = instanciation.find(q => q.watch_question_code === qv);
        const inds = referentiel.filter(i => String(i.questions || "").split(",").includes(qv));
        const sigs = signaux.filter(s => s.watch_question_code === qv);
        const cov = couverture.find(c => c.watch_question_code === qv);
        const vide = inds.length === 0 && sigs.length === 0;
        return (
          <section key={qv} className="qv-section">
            {/* La conception l'exige : le titre est la FORMULATION SECTORIELLE,
                pas le code. Les noms de champs viennent de v_instanciation_qv —
                question_sectorielle, à défaut question_generique. */}
            <h2 className="qv-titre">
              <span className="qv-code">{qv}</span>
              {inst?.question_sectorielle || inst?.question_generique || "Question de veille " + qv}
              {inst?.criticite && <span className={"etq crit-" + String(inst.criticite).toLowerCase()}>
                criticité {inst.criticite}</span>}
            </h2>
            {inst?.mecanisme && <p className="qv-mecanisme">{inst.mecanisme}</p>}

            {vide ? (
              <div className="vide non-couvert">
                <strong>Non couvert.</strong> Aucun indicateur certifié ni signal validé n'est
                rattaché à cette question pour ce secteur
                {cov ? <> ({cov.nb_indicateurs || 0} indicateur(s) rattaché(s), {cov.nb_certifies || 0} certifié(s))</> : null}.
                La lacune est calculable parce que le cadre de questions est invariant.
              </div>
            ) : (
              <>
                {qv === "QV1" && commentaire && (
                  <div className="qv-reponse">
                    <MarkdownLeger texte={String(commentaire.text || "").replace(/\*\*/g, "")} />
                    <div className="c-pied">
                      <span className="etq e-vert">validé</span>
                      {commentaire.validated_by} · {dateCH(commentaire.validated_at)}
                    </div>
                  </div>
                )}
                {sigs.length > 0 && (
                  <div className="liste-signaux">
                    {sigs.map(s => (
                      <div key={s.signal_id} className="ligne-signal">
                        <span className="etq e-violet">signal validé</span>
                        <span className="sig-evt">{s.evenement}</span>
                        {s.acteur && <span className="sig-act">{s.acteur}</span>}
                        {s.echeance && <span className="sig-ech">échéance {s.echeance}</span>}
                        <LienSource href={s.source_doc} />
                      </div>
                    ))}
                  </div>
                )}
                <div className="grille g2">
                  {inds.map(i => <Preuve key={i.indicator_id} ind={i} D={D} navigate={navigate} />)}
                </div>
              </>
            )}
          </section>
        );
      })}
    </div>
  );
}
