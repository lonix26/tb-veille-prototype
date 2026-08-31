import React, { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  useDonnees, nb, pct, dateCH, alertesSignificatives, LienSource, MarkdownLeger
} from "../api.jsx";
import { Sparkline, Regle } from "../Mini.jsx";
import {
  etatMarche, directionLongue, phraseEcheance, tonEcheance, phraseFraicheur,
  construireBrief, phraseMouvement, redondances, enLettres, serieAgregee,
  compositionLatence, phraseComposition, phraseEcart, phraseNouveaute,
  phrasePeriode, natureDuFait
} from "../phrases.jsx";

// =====================================================================
// CE MATIN — l'écran unique qu'un dirigeant ouvre.
//
// Il répond à quatre questions, dans cet ordre, et refuse d'en traiter une
// cinquième :
//   1. Que s'est-il passé ?          → le brief, en français
//   2. Qu'est-ce qui demande une décision AUJOURD'HUI ?  → les échéances
//   3. Où en sont mes marchés ?      → quatre cartes, mot avant chiffre
//   4. Puis-je m'y fier ?            → ce que le dispositif ne sait pas
//
// Ce que cet écran ne fait PLUS : ouvrir sur un paragraphe expliquant les
// écarts-types. La méthode reste accessible, repliée en bas de page. Elle
// intéresse le jury, pas le décideur, et l'écran est fait pour le décideur.
// =====================================================================

function serieRepresentative(D, ids) {
  // Une carte de marché porte UNE courbe de rappel, et elle est NOMMÉE — sans
  // quoi le lecteur croit voir « le marché » là où il voit une série parmi
  // d'autres. On retient celle qui couvre le plus de périodes parmi les séries
  // qui portent réellement le score, et on l'agrège comme la base le ferait
  // (somme des destinations pour une grandeur monétaire, zone unique pour un
  // indice). Aucune moyenne de séries hétérogènes : elle ne voudrait rien dire.
  let meilleur = null, meilleureSerie = null, n = -1;
  for (const id of ids || []) {
    const m = serieAgregee(D, id);
    if (m && m.size > n) { n = m.size; meilleur = id; meilleureSerie = m; }
  }
  if (!meilleur) return null;
  const points = [...meilleureSerie.entries()]
    .sort((a, b) => String(a[0]).localeCompare(String(b[0])))
    .map(([period, value]) => ({ period, value }));
  const ref = (D?.referentiel || []).find(r => r.indicator_id === meilleur);
  return { id: meilleur, points: points.slice(-60), label: ref?.label || meilleur };
}

function CarteMarche({ s, D, onClic }) {
  const score = s.score_sante === null ? null : Number(s.score_sante);
  const e = etatMarche(score);
  const dir = directionLongue(Number(s.tendance_moyenne));
  const serie = useMemo(() => serieRepresentative(D, s.indicateurs), [D, s.indicateurs]);
  const doublons = useMemo(() => redondances(D, s.indicateurs), [D, s.indicateurs]);
  const compo = useMemo(() => compositionLatence(D, s.indicateurs), [D, s.indicateurs]);

  return (
    <div className="carte marche cliquable" onClick={onClic} role="button" tabIndex={0}
         onKeyDown={ev => (ev.key === "Enter" || ev.key === " ") && onClic()}>
      <div className="marche-tete">
        <h3>{s.sector_label}</h3>
        {serie && <Sparkline points={serie.points} ton={e.ton} />}
      </div>

      <p className={"marche-etat t-" + e.ton}>{e.mot}</p>
      <p className="marche-phrase">{e.phrase}{dir ? `, ${dir}` : ""}.</p>

      <Regle score={score} ton={e.ton} />

      <div className="marche-pied">
        <span>
          {s.n_indicateurs_orientables === null
            ? "aucune série exploitable"
            : `score calculé sur ${enLettres(s.n_indicateurs_orientables)} série${s.n_indicateurs_orientables > 1 ? "s" : ""}, sur ${enLettres(s.indicateurs_certifies)} certifiées`}
        </span>
        {serie && <span className="marche-serie" title={serie.label}>courbe : {serie.label}</span>}
        <span className="marche-compo">{phraseComposition(compo)}</span>
      </div>

      {compo.avance === 0 && (
        <div className="avert avert-fort" onClick={ev => ev.stopPropagation()}>
          <strong>Aucun signal d'avance.</strong> Toutes les séries de ce score décrivent ce qui
          s'est déjà produit. Sur ce marché, le tableau de bord <em>constate</em> — il n'avertit
          pas. Un retournement n'y serait visible qu'après coup.
        </div>
      )}

      {doublons.length > 0 && (
        <div className="avert" onClick={ev => ev.stopPropagation()}>
          <strong>Prudence sur le score, pas sur les séries.</strong>{" "}
          <em>{doublons[0].nomA}</em> et <em>{doublons[0].nomB}</em> évoluent ensemble
          (corrélation {nb(Math.abs(doublons[0].r), 2)} sur {doublons[0].n} points communs).
          Elles restent deux mesures distinctes — c'est souvent l'<strong>écart entre elles</strong>{" "}
          qui porte l'information. Mais le score en fait une moyenne simple : leur mouvement commun
          y compte deux fois, et il paraît donc plus assuré qu'il ne l'est.
          {doublons.length > 1 && ` ${enLettres(doublons.length)} paires sont dans ce cas.`}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------
// DEPUIS LA DERNIÈRE FOIS — le bloc qui manquait, et c'était le principal.
//
// L'écran affichait un NIVEAU sans jamais dire s'il était nouveau. Un
// dirigeant qui ouvre l'outil chaque lundi ne pouvait pas distinguer une
// nouveauté d'une permanence, alors que le § 5 du rapport pose que « c'est
// l'écart entre exécutions qui fait la tendance ».
//
// Quand l'écart de score n'est pas calculable — c'est le cas après un
// changement de périmètre —, le bloc le DIT et se rabat sur ce qui l'est :
// quels indicateurs ont avancé, et jusqu'où. Un bloc honnête vaut mieux
// qu'un bloc vide, et mieux encore qu'un bloc qui compare deux grandeurs
// qui ne portent pas sur le même périmètre.
// ---------------------------------------------------------------------
function Depuis({ S, sante }) {
  const ecarts = (S?.ecart_7j || []).filter(e => e.ecart !== null && e.ecart !== undefined);
  const nouveautes = S?.nouveautes_7j || [];
  const nom = code => sante.find(x => x.sector_code === code)?.sector_label || code;

  if (!ecarts.length && !nouveautes.length) return null;

  const bouges = ecarts.filter(e => Math.abs(Number(e.ecart)) >= 0.1);
  const avancees = nouveautes.filter(n => n.periode_maintenant !== n.periode_avant || n.entierement_nouveau);

  return (
    <section className="depuis">
      <h2 className="depuis-titre">Depuis sept jours</h2>

      {ecarts.length > 0 ? (
        bouges.length === 0 ? (
          <p className="depuis-rien">
            Aucun marché n'a bougé de plus d'un dixième de point. Les positions tiennent.
          </p>
        ) : (
          <ul className="depuis-liste">
            {bouges.map(e => {
              const d = Number(e.ecart);
              return (
                <li key={e.sector_code} className={d > 0 ? "hausse" : "baisse"}>
                  {d > 0 ? "↗" : "↘"} {phraseEcart(e, nom(e.sector_code))}
                  <span className="depuis-detail">
                    {nb(e.score_precedent, 2)} → {nb(e.score_courant, 2)}
                  </span>
                </li>
              );
            })}
          </ul>
        )
      ) : (
        <p className="depuis-rien">
          <strong>Pas de comparaison possible cette semaine.</strong> Il y a sept jours, la
          fenêtre d'historique était plus courte et la plupart des séries n'atteignaient pas la
          profondeur exigée pour qu'un score soit calculé. Comparer deux scores portant sur des
          périmètres différents dirait n'importe quoi ; l'écart redeviendra lisible à la
          prochaine semaine pleine.
        </p>
      )}

      {avancees.length > 0 && (
        <>
          <p className="depuis-sous">
            {enLettres(avancees.length)} indicateur{avancees.length > 1 ? "s ont" : " a"} reçu de
            nouvelles observations :
          </p>
          <ul className="depuis-liste depuis-donnees">
            {avancees.slice(0, 6).map(n => (
              <li key={n.indicator_id}>
                <span className={"etq lat-" + (n.latence || "coincident")}>
                  {n.latence === "avance" ? "annonce" : n.latence === "retarde" ? "confirme" : "constate"}
                </span>
                {phraseNouveaute(n)}
              </li>
            ))}
          </ul>
          {avancees.length > 6 && (
            <p className="depuis-detail">et {avancees.length - 6} autres.</p>
          )}
        </>
      )}
    </section>
  );
}

function CarteDecision({ titre, valeur, phrase, ton, action, onClic }) {
  return (
    <div className={"carte decision t-" + ton + (onClic ? " cliquable" : "")}
         onClick={onClic} role={onClic ? "button" : undefined} tabIndex={onClic ? 0 : undefined}
         onKeyDown={ev => onClic && (ev.key === "Enter" || ev.key === " ") && onClic()}>
      <div className="dec-titre">{titre}</div>
      <div className="dec-valeur">{valeur}</div>
      <div className="dec-phrase">{phrase}</div>
      {action && <div className="dec-action">{action} →</div>}
    </div>
  );
}

function Repliable({ titre, children, ouvertParDefaut = false }) {
  const [ouvert, setOuvert] = useState(ouvertParDefaut);
  return (
    <div className="repliable">
      <button className="rep-tete" onClick={() => setOuvert(o => !o)} aria-expanded={ouvert}>
        <span className={"rep-fleche" + (ouvert ? " ouvert" : "")}>›</span>{titre}
      </button>
      {ouvert && <div className="rep-corps">{children}</div>}
    </div>
  );
}

export default function CeMatin() {
  const { D, S, A, G, erreursV4 } = useDonnees();
  const navigate = useNavigate();

  // TOUS LES HOOKS AVANT LE PREMIER RETOUR — et pas seulement par convention.
  // Ce `useMemo` était placé plus bas, après le retour anticipé `if (!S)` :
  // au premier rendu, l'interface de lecture n'ayant pas encore répondu, il
  // n'était pas appelé ; au rendu suivant, il l'était. React compte les hooks
  // par position et lève « Rendered more hooks than during the previous
  // render » — l'écran devient blanc.
  //
  // À NOTER pour le test de rendu (`verification/`) : il n'a pas attrapé ce
  // défaut, et ne pouvait pas. `renderToString` ne rend QU'UNE FOIS ; une
  // rupture d'ordre des hooks ne se manifeste qu'au second rendu. Le test
  // vérifie qu'un écran se peuple, pas qu'il survit à une mise à jour.
  const longueurs = useMemo(() => {
    const m = new Map();
    for (const v of (D?.valeurs || [])) {
      if (!m.has(v.indicator_id)) m.set(v.indicator_id, new Set());
      m.get(v.indicator_id).add(v.period);
    }
    return m;
  }, [D]);

  if (!S) return (
    <div className="page">
      <div className="vide">
        <strong>La lecture « santé » ne répond pas.</strong><br />
        L'écran ne peut pas se peupler, et il ne l'invente pas.<br />
        <span style={{ fontSize: 12 }}>{erreursV4?.["/sante"]}</span>
      </div>
    </div>
  );

  const sante = S.sante || [];
  const marches = sante.filter(s => s.sector_code !== "transversal");
  const socle = sante.find(s => s.sector_code === "transversal");
  const run = S.run_courant || {};
  const actions = A?.actions || [];
  const adressables = actions.filter(a => a.adressable >= 1);
  const urgentes = adressables.filter(a => a.jours_restants !== null && a.jours_restants <= 15)
                              .sort((x, y) => x.jours_restants - y.jours_restants);
  const aValider = Number(S.commentaires_en_attente) || 0;
  const aExaminer = Number(S.items_en_attente_examen) || 0;

  const { retenues: significatives, ecartees } = alertesSignificatives(D);

  // « Ce qui a bougé » doit montrer ce qui a bougé, pas les plus grosses
  // croissances annuelles. Deux corrections, constatées sur pièce le 25.08 :
  //   — le classement se fait sur la variation DE PÉRIODE et non sur le
  //     glissement annuel : la question est « qu'est-ce qui a changé depuis la
  //     dernière observation ? » ;
  //   — les séries de moins de huit périodes sont écartées. Quatre des cinq
  //     mouvements affichés provenaient d'une série ANNUELLE de trois points,
  //     où « +125 % » décrit la croissance structurelle d'un marché jeune et
  //     non un mouvement. Huit est le seuil déjà retenu pour le score.
  const assezLongue = id => (longueurs.get(id)?.size ?? 0) >= 8;
  const variation = a => Math.abs(Number(a.variation_periode_pct ?? a.glissement_annuel_pct) || 0);
  const eligibles = significatives.filter(a => assezLongue(a.indicator_id));
  const ecarteesCourtes = significatives.length - eligibles.length;
  const mouvements = [...eligibles].sort((x, y) => variation(y) - variation(x)).slice(0, 5);

  const brief = construireBrief({ sante, actions, alertes: significatives, aValider, aExaminer, D });

  // Ce que le dispositif ne sait pas — inventaire produit, pas rédigé.
  const ref = D?.referentiel || [];
  const sansCollecte = ref.filter(r => r.status === "certifie" && !Number(r.observations));
  const commentaires = D?.commentaires || [];

  // « lundi, 24 août 2026 » n'est pas du français : la virgule est un
  // artefact de la locale. On la retire plutôt que de composer la date à la main.
  const aujourdhui = new Date()
    .toLocaleDateString("fr-CH", { weekday: "long", day: "numeric", month: "long", year: "numeric" })
    .replace(",", "");

  return (
    <div className="page">
      {/* ---------- 1. Ouverture ---------- */}
      <header className="ouverture">
        <div>
          <p className="ouv-date">{aujourdhui}</p>
          <h1 className="ouv-titre">Ce matin</h1>
        </div>
        <div className="ouv-etat">
          <span className="puce-fraicheur">{phraseFraicheur(run.executed_at)}</span>
          {/* La fraîcheur de la COLLECTE n'est pas celle de la DONNÉE. « Collecté il
              y a deux heures » se lit comme « information fraîche » ; si le point le
              plus récent date de juillet, c'est faux. Les deux sont affichées. */}
          <span className="ouv-run">
            donnée la plus récente : {phrasePeriode(S.fraicheur?.point_le_plus_recent)}
            {S.fraicheur?.point_le_plus_ancien &&
              ` · la plus ancienne série s'arrête en ${phrasePeriode(S.fraicheur.point_le_plus_ancien)}`}
          </span>
          <span className="ouv-run">exécution n° {run.run_id ?? "—"} · {dateCH(run.executed_at)}</span>
        </div>
      </header>

      <p className="brief">{brief}</p>

      {/* ---------- 1 bis. Ce qui a changé depuis la dernière fois ---------- */}
      <Depuis S={S} sante={sante} />

      {/* ---------- 2. Ce qui demande une décision ---------- */}
      <h2 className="s-titre">Ce qui demande une décision</h2>
      <div className="grille g3">
        <CarteDecision
          titre="Appels d'offres à votre portée"
          valeur={urgentes.length || adressables.length || "—"}
          ton={urgentes.length ? "rouge" : adressables.length ? "ambre" : "gris"}
          phrase={
            urgentes.length
              ? `se closent d'ici quinze jours — le premier se clôt ${phraseEcheance(urgentes[0].jours_restants)}`
              : adressables.length
                ? `ouverts, aucun ne se clôt dans les quinze jours`
                : "aucun marché adressable ouvert dans la fenêtre suivie"
          }
          action={adressables.length ? "Voir la liste" : null}
          onClic={adressables.length ? () => navigate("/a-faire") : null}
        />
        <CarteDecision
          titre="Commentaires à valider"
          valeur={aValider || "0"}
          ton={aValider ? "ambre" : "vert"}
          phrase={aValider
            ? "rédigés par le modèle, en attente de votre lecture — rien n'est diffusé sans elle"
            : "tout ce qui est rédigé a été relu"}
          action={aValider ? "Les relire" : null}
          onClic={aValider ? () => navigate("/dispositif") : null}
        />
        <CarteDecision
          titre="Veille non examinée"
          valeur={nb(aExaminer)}
          ton={aExaminer > 300 ? "rouge" : aExaminer ? "ambre" : "vert"}
          phrase={aExaminer > 300
            ? "la file croît plus vite qu'elle n'est traitée — à trancher par un cadrage, pas par du temps"
            : "items collectés et triés, en attente de lecture humaine"}
          action="Voir les dix mieux classés"
          onClic={() => navigate("/a-faire#file")}
        />
      </div>

      {/* ---------- 3. Les marchés ---------- */}
      <h2 className="s-titre">
        Vos marchés
        <span className="s-sous">position du moment, tendance longue retirée</span>
      </h2>
      <div className="grille g4">
        {marches.map(s => (
          <CarteMarche key={s.sector_code} s={s} D={D}
                       onClic={() => navigate("/qv/" + s.sector_code)} />
        ))}
      </div>
      {socle && (
        <div className="grille g4" style={{ marginTop: 14 }}>
          <CarteMarche s={socle} D={D} onClic={() => navigate("/qv/transversal")} />
        </div>
      )}

      {/* ---------- 4. Ce qui a bougé ---------- */}
      <h2 className="s-titre">
        Ce qui a bougé
        <span className="s-sous">
          les cinq écarts les plus marqués d'une période à la suivante
        </span>
      </h2>
      {mouvements.length === 0 ? (
        <div className="vide">Aucun mouvement au-delà des seuils de matérialité.</div>
      ) : (
        <div className="mouvements">
          {mouvements.map((a, i) => (
            <div className="mvt" key={i}>
              <span className={"mvt-fleche " + (Number(a.glissement_annuel_pct) > 0 ? "haut" : "bas")}>
                {Number(a.glissement_annuel_pct) > 0 ? "↗" : "↘"}
              </span>
              <span className="mvt-texte">{phraseMouvement(a)}</span>
              <span className="mvt-poids">
                {a.poids_pct !== null && a.poids_pct !== undefined
                  ? `${nb(a.poids_pct, 1)} % de l'indicateur`
                  : "indicateur mono-zone"}
              </span>
            </div>
          ))}
          {(ecartees > 0 || ecarteesCourtes > 0) && (
            <p className="mvt-note">
              {ecartees > 0 && <>{nb(ecartees)} franchissements ne sont pas montrés : ils portent
              sur des marchés pesant moins de 1 % de leur indicateur, où une forte variation
              relative est un artefact de petits nombres et non un signal.</>}
              {ecarteesCourtes > 0 && <> {nb(ecarteesCourtes)} autres proviennent de séries de
              moins de huit périodes, où une variation ne se distingue pas de la croissance
              structurelle de la série.</>}
            </p>
          )}
        </div>
      )}

      {/* ---------- 4 bis. Les faits établis ---------- */}
      {(G?.signaux || []).length > 0 && (
        <>
          <h2 className="s-titre">
            Faits marqués
            <span className="s-sous">
              événements extraits de documents, puis validés nominativement — ce ne sont pas des séries
            </span>
          </h2>
          <div className="faits">
            {(G.signaux || []).slice(0, 4).map(s => (
              <div className={"fait fait-" + natureDuFait(s).replace(/ /g, "-")} key={s.signal_id}>
                <div className="fait-tete">
                  <span className="etq e-violet">{s.sector_label}</span>
                  {/* Un fait dont l'échéance est à neuf ans n'est pas une actualité :
                      il se présente comme du contexte, sinon il occupe indéfiniment
                      un écran qui s'appelle « Ce matin ». */}
                  <span className={"etq " + (natureDuFait(s) === "récent" ? "e-vert" : "e-gris")}>
                    {natureDuFait(s)}
                  </span>
                  {s.echeance && <span className="fait-ech">échéance {s.echeance}</span>}
                </div>
                <p className="fait-txt">{s.evenement}</p>
                <p className="fait-qui">
                  {s.acteur ? s.acteur + " · " : ""}
                  <LienSource href={s.source_doc}>document d'origine</LienSource>
                </p>
              </div>
            ))}
          </div>
          {(G.signaux || []).length > 4 && (
            <p className="note" style={{ marginTop: 8 }}>
              <button className="bouton-lien" onClick={() => navigate("/signaux")}>
                Voir les {G.signaux.length} faits validés →
              </button>
            </p>
          )}
        </>
      )}

      {/* ---------- 5. La lecture du moment ---------- */}
      {commentaires.length > 0 && (
        <>
          <h2 className="s-titre">
            La lecture du moment
            <span className="s-sous">rédigée par un modèle, validée par vous — seul le validé s'affiche</span>
          </h2>
          <div className="grille g2">
            {commentaires.slice(0, 2).map(c => {
              const sec = sante.find(s => s.sector_code === c.sector_code);
              return (
                <div className="carte commentaire" key={c.commentary_id}>
                  <div className="com-tete">
                    <strong>{sec?.sector_label || c.sector_code}</strong>
                    <span className="etq e-gris">{c.model}</span>
                    <span className="com-date">
                      collecte n° {c.run_id ?? "—"} · validée le {dateCH(c.validated_at)}
                    </span>
                  </div>
                  {c.run_id && run.run_id && c.run_id < run.run_id && (
                    <div className="avert" onClick={ev => ev.stopPropagation()}>
                      <strong>Lecture antérieure.</strong> Elle a été rédigée sur la collecte
                      n° {c.run_id} ; la base en est à la n° {run.run_id}. Les chiffres qu'elle
                      cite peuvent différer de ceux affichés plus haut — c'est le cas, et il vaut
                      mieux le voir écrit que le découvrir en comparant.
                    </div>
                  )}
                  <div className="c-corps"><MarkdownLeger texte={c.text} /></div>
                </div>
              );
            })}
          </div>
          {commentaires.length > 2 && (
            <p className="note" style={{ marginTop: 8 }}>
              {commentaires.length - 2} autres lectures validées, une par marché, sur les pages de marché.
            </p>
          )}
        </>
      )}

      {/* ---------- 6. Les limites, dites ---------- */}
      <h2 className="s-titre">Ce que ce tableau ne sait pas</h2>
      <div className="carte limites">
        <ul>
          {sansCollecte.length > 0 && (
            <li>
              <strong>{enLettres(sansCollecte.length)} indicateurs certifiés ne collectent rien</strong> —{" "}
              {sansCollecte.map(r => r.indicator_id).join(", ")}. La source est qualifiée, la
              liaison de collecte ne l'est pas encore.
            </li>
          )}
          <li>
            <strong>Le score compare un marché à lui-même</strong>, jamais à un autre. Un
            « nettement au-dessus » en horlogerie et en automobile ne se comparent pas :
            les échelles sont propres à chaque série.
          </li>
          <li>
            <strong>Les périodicités sont mélangées.</strong> Un score peut réunir une série
            mensuelle de 150 points et une série annuelle de 11. Le dispositif l'accepte ;
            la lecture doit en tenir compte.
          </li>
          {aExaminer > 300 && (
            <li>
              <strong>La file d'examen ne se vide pas.</strong> {nb(aExaminer)} items attendent
              une lecture humaine. C'est la limite structurelle du choix semi-automatisé :
              elle se traite par un cadrage — les dix meilleurs par semaine — et non par du
              temps supplémentaire.
            </li>
          )}
        </ul>
      </div>

      {/* ---------- 7. La méthode, disponible et non imposée ---------- */}
      <Repliable titre="Comment ces chiffres sont construits">
        <p>
          <strong>La position du moment.</strong> Pour chaque série, le dispositif retire d'abord
          la <em>tendance longue</em> — sans quoi une série qui croît depuis dix ans s'afficherait
          « au-dessus » en permanence et aucun retournement ne serait signalable. Ce qui reste est
          l'écart du dernier point à sa propre base, exprimé en écarts-types, puis orienté par le
          sens de lecture déclaré de l'indicateur (une hausse du chômage n'est pas une bonne
          nouvelle). Sous 0,5 écart-type, le dispositif considère qu'il n'y a rien à signaler.
        </p>
        <p>
          <strong>La direction longue</strong> est indiquée séparément, parce qu'elle répond à une
          autre question : « où va cette branche ? » et non « où en est-elle aujourd'hui ? ».
        </p>
        <p>
          <strong>Le score d'un marché</strong> est la moyenne non pondérée des positions de ses
          séries. C'est sa faiblesse connue : deux séries qui mesurent la même grandeur y pèsent
          deux fois. Quand c'est le cas, la carte du marché le dit.
        </p>
        <p>
          <strong>Les mouvements</strong> sont des franchissements de seuil de matérialité,
          déclarés par indicateur. Ceux qui portent sur des marchés pesant moins de 1 % de leur
          indicateur sont écartés : sur une série à longue traîne, une variation de +900 % sur
          une destination minuscule est un artefact, pas une information.
        </p>
      </Repliable>
    </div>
  );
}
