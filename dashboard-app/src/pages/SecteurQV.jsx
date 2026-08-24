import React from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useDonnees, nb, pct, clsVar, dateCH, nomZone, estAgregat,
         BadgeStatut, MarkdownLeger, LienSource } from "../api.jsx";
import Chart from "../Chart.jsx";
import { Regle } from "../Mini.jsx";
import { etatMarche, directionLongue, redondances, avecArticle } from "../phrases.jsx";

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

  // ── Vue par marché ────────────────────────────────────────────────────
  // La carte ne traçait qu'UNE courbe, celle de la zone de référence, alors
  // que la charge contient toutes les zones collectées — 197 destinations
  // pour les exportations horlogères. Constater qu'un agrégat monte ne dit
  // pas OÙ il monte, et c'est cette question-là qui décide d'un effort
  // commercial. Les principaux marchés sont donc traçables ici, sur la même
  // carte et au même endroit du regard.
  //
  // Le repère de base disparaît en vue par marché, et c'est volontaire : une
  // moyenne mobile est calculée pour la zone de référence, la superposer à
  // cinq courbes d'autres zones inviterait à une comparaison qui n'a pas
  // lieu d'être.
  const [parMarche, setParMarche] = React.useState(false);
  const AGREGATS = new Set(["W00","WORLD","World","OWID_WRL","EU","EU27","EU27_2020","G20"]);
  const derniereP = points.length ? points[points.length - 1].period : null;
  const marches = [...new Set(serie.filter(v => !AGREGATS.has(v.geo)).map(v => v.geo))]
    .map(g => {
      const pts = serie.filter(v => v.geo === g);
      const dern = pts[pts.length - 1];
      return { geo: g, pts, poids: dern ? Math.abs(Number(dern.value) || 0) : 0,
               frais: dern && dern.period === derniereP };
    })
    .filter(x => x.pts.length > 2)
    .sort((a, b) => b.poids - a.poids);
  const top = marches.slice(0, 5);
  const multiZone = marches.length >= 2;
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
      {multiZone && (
        <div className="bascule">
          <button className={!parMarche ? "actif" : ""} onClick={() => setParMarche(false)}>
            {nomZone(zone)}
          </button>
          <button className={parMarche ? "actif" : ""} onClick={() => setParMarche(true)}>
            par marché ({marches.length})
          </button>
        </div>
      )}
      {points.length > 1 && !parMarche &&
        <Chart series={{ [zone]: points.map(p => ({ period: p.period, value: Number(p.value) })) }}
               refLine={m?.moyenne_mobile_annuelle ?? undefined}
               refLabel={m?.moyenne_mobile_annuelle != null
                 ? "base " + nb(m.moyenne_mobile_annuelle)
                 : undefined}
               hauteur={170} />}
      {parMarche && top.length > 0 && (
        <>
          <Chart hauteur={200}
                 series={Object.fromEntries(top.map(x =>
                   [x.geo, x.pts.map(p => ({ period: p.period, value: Number(p.value) }))]))} />
          <p className="base-note">
            Les {top.length} premiers marchés par dernière valeur, sur {marches.length} zones
            collectées. Les agrégats (monde, Union européenne) sont exclus de ce classement — les
            compter parmi les pays doublerait le total.
            {top.some(x => !x.frais) && <> Attention : {top.filter(x => !x.frais).map(x => nomZone(x.geo)).join(", ")}
              {" "}n'a pas de point sur la dernière période — la courbe s'y arrête plus tôt.</>}
          </p>
        </>
      )}
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

// =====================================================================
// ATTRIBUTION ANCRÉE — démonstration (§ 12.3), affichée à part du
// commentaire de production et jamais confondue avec lui.
//
// Le principe : le dispositif s'interdit d'attribuer une cause (RI9). La
// variante autorise l'attribution À CONDITION que le fait invoqué figure
// dans un contexte factuel fourni au modèle et soit cité par son ancre.
// L'affirmation ne devient pas plus certaine — elle devient VÉRIFIABLE.
// D'où l'exigence ici : chaque ancre doit être cliquable jusqu'à sa
// pièce, sinon l'écran affiche la promesse sans la tenir.
// =====================================================================

// =====================================================================
// DYNAMIQUE GÉOGRAPHIQUE — instrumente QV3, l'un des cinq angles
// invariants du cadre du chapitre 8.
//
// Constat à l'origine : le registre porte 88 destinations pour les
// exportations horlogères, 64 pays pour les ventes de véhicules
// électriques, 7 à 11 pour les flux de commerce — et la restitution
// n'en affichait qu'UNE par indicateur, la zone de référence déclarée.
// La question de veille était posée par la grille et répondue par
// personne, alors que la donnée était collectée depuis le premier jour.
// =====================================================================

// =====================================================================
// PART SUISSE DU COMMERCE MONDIAL D'HORLOGERIE — l'indicateur synthétique.
//
// Il était calculé par vue depuis le 17.08 et servi par l'interface, mais
// n'apparaissait que dans l'écran d'ensemble hérité de la v3 : en
// pratique, invisible. L'approfondissement des séries du 24.08 l'a par
// ailleurs étendu de deux à ONZE exercices sans que personne le
// remarque — c'est ce qui en fait aujourd'hui un fait de structure et
// non plus une photographie.
//
// Il répond directement au mécanisme de QV1 : le tissu de sous-traitance
// s'érode-t-il ? Une part qui progresse dit que le débouché domestique se
// concentre, ce qui n'est pas la même chose qu'un débouché qui grandit.
// =====================================================================

// =====================================================================
// LA CHAÎNE — du marché final à l'atelier (§ 5.5).
//
// Le dispositif mesurait presque exclusivement le MARCHÉ FINAL, alors que
// le destinataire vend des pièces à un donneur d'ordre. Entre les deux :
// trois étages, six à dix-huit mois, et une décision de faire ou faire
// faire qui domine le signal.
//
// Ce bloc superpose les étages sur un même graphique. C'est légitime
// parce que ce sont tous des INDICES DE PRODUCTION de même base (2021),
// même zone et même fréquence — trois conditions sans lesquelles la
// superposition serait une illusion d'optique.
//
// L'ÉCART entre deux étages est la lecture : il mesure la transmission.
// Un écart qui se creuse dit que le marché final ne se transmet plus.
// =====================================================================

const CHAINE = {
  automobile: [
    { code: "A5", role: "marché final",       aide: "fabrication de véhicules (NACE C29)" },
    { code: "A6", role: "demande adressable", aide: "fabrication d'équipements pour véhicules (NACE C29.3)" },
    { code: "T7", role: "votre branche",      aide: "traitement et usinage des métaux (NACE C25.6)" },
  ],
  horlogerie: [
    { code: "H6", role: "demande adressable", aide: "fabrication de montres et horloges (NACE C26.52)" },
    { code: "T7", role: "votre branche",      aide: "traitement et usinage des métaux (NACE C25.6)" },
  ],
  medical: [
    { code: "M2", role: "demande adressable", aide: "instruments et fournitures médicaux et dentaires (NACE C32.5)" },
    { code: "T7", role: "votre branche",      aide: "traitement et usinage des métaux (NACE C25.6)" },
  ],
  aerospatial: [
    { code: "S8", role: "demande adressable", aide: "construction aéronautique et spatiale (NACE C30.3)" },
    { code: "T7", role: "votre branche",      aide: "traitement et usinage des métaux (NACE C25.6)" },
  ],
};

// =====================================================================
// MIX HORLOGER — la valeur ne dit pas le volume.
//
// Le mécanisme de QV1 horlogère porte depuis le chapitre 8 un point de
// vigilance précis : « une montée en valeur qui masquerait l'érosion du
// tissu de sous-traitance ». Le commentaire exécutif du 24.08 l'a énoncé
// lui-même en constatant qu'il n'était PAS observable, faute de série de
// volume. Les données de la Fédération horlogère, en francs et avec la
// ventilation mécanique, le rendent observable.
//
// Un atelier facture des PIÈCES, pas des francs. C'est pourquoi les deux
// glissements sont affichés côte à côte : c'est leur ÉCART qui répond.
// =====================================================================

function MixHorloger({ serie }) {
  const pts = (serie || []).filter(x => x.part_meca_valeur_pct != null);
  if (pts.length < 3) return null;
  const d = pts[pts.length - 1];
  const gv = d.meca_chf_ga_pct, gq = d.meca_pieces_ga_pct;
  const lisible = gv != null && gq != null;
  const ecart = lisible ? Number(gv) - Number(gq) : null;

  return (
    <div className="carte preuve mix">
      <div className="p-tete">
        <div>
          <div className="p-titre">Mix mécanique des exportations horlogères</div>
          <div className="p-meta">
            H7 · H8 · H9 — Fédération de l'industrie horlogère, en francs, {d.period}
          </div>
        </div>
        <div className="p-val">{nb(d.part_meca_valeur_pct, 1)} %</div>
      </div>

      <p className="mix-principe">
        Une montre mécanique mobilise des dizaines de pièces usinées à tolérances serrées ; une
        montre à quartz en mobilise peu. <strong>Le mécanique fait {nb(d.part_meca_valeur_pct, 1)} %
        de la valeur exportée</strong> — c'est la part du débouché horloger qui commande
        réellement une charge d'usinage.
      </p>

      {lisible && (
        <p className={"mix-constat " + (ecart > 3 ? "alerte" : "")}>
          Sur un an : la <strong>valeur</strong> mécanique fait {pct(gv)}, le
          {" "}<strong>volume</strong> {pct(gq)}.
          {ecart > 3
            ? <> La valeur croît plus vite que le nombre de montres :
                <strong> montée en gamme</strong>. Le chiffre d'affaires de la branche progresse
                sans que la charge d'usinage suive à la même vitesse — c'est exactement le point
                de vigilance que la question de veille énonce.</>
            : ecart < -3
            ? <> Le volume croît <strong>plus vite</strong> que la valeur : la branche exporte plus
                de montres à valeur unitaire plus basse. Pour un atelier, c'est
                <strong> davantage de pièces à produire</strong> — l'inverse de la crainte portée
                par la question de veille.</>
            : <> Les deux progressent au même rythme : le mix ne se déforme pas.</>}
          {" "}Valeur moyenne d'une montre mécanique exportée : {nb(d.valeur_moyenne_chf, 0)} CHF.
        </p>
      )}

      <Chart hauteur={175}
             series={{
               "valeur mécanique (mio CHF)": pts.map(x => ({ period: x.period, value: Number(x.meca_chf) })),
               "volume mécanique (milliers)": pts.map(x => ({ period: x.period, value: Number(x.meca_pieces) })),
             }} />

      <p className="base-note">
        {pts.length} mois collectés. <strong>La profondeur ne peut pas être téléchargée</strong> :
        la Fédération ne sert que le millésime courant — vérifié le 24.08.2026, les précédents
        renvoient la page d'accueil. Elle s'accumule donc mois après mois par la ré-exécution du
        dispositif, ce qui est la raison d'être du registre en ajout seul.
      </p>
    </div>
  );
}

function Chaine({ code, D }) {
  const plan = CHAINE[code];
  if (!plan) return null;
  const series = {}, derniers = {};
  plan.forEach(e => {
    const pts = (D.valeurs || [])
      .filter(v => v.indicator_id === e.code)
      .sort((a, b) => String(a.period).localeCompare(String(b.period)))
      .map(v => ({ period: v.period, value: Number(v.value) }));
    if (pts.length > 2) {
      series[e.role] = pts;
      derniers[e.role] = pts[pts.length - 1];
    }
  });
  const roles = Object.keys(series);
  if (roles.length < 2) return null;

  const adressable = derniers["demande adressable"];
  const final = derniers["marché final"];
  const atelier = derniers["votre branche"];
  const ecart = final && adressable ? Number(final.value) - Number(adressable.value) : null;

  return (
    <div className="chaine">
      <div className="ch-titre">La chaîne — du marché final à votre atelier</div>

      <p className="ch-principe">
        Ces courbes sont des <strong>indices de production</strong> de même base (2021), même zone
        et même fréquence : elles se superposent légitimement. Chacune est un étage de la chaîne.
        {" "}<strong>Ce qui décide, c'est l'écart entre les étages</strong> — il mesure ce qui se
        transmet réellement du marché final jusqu'à un atelier d'usinage.
      </p>

      {ecart != null && Math.abs(ecart) >= 3 && (
        <p className="ch-constat">
          <strong>{nb(Math.abs(ecart), 1)} points d'écart</strong> entre le marché final
          ({nb(final.value, 1)}) et la demande adressable ({nb(adressable.value, 1)}) en
          {" "}{adressable.period}.
          {ecart > 0
            ? <> Le marché final se tient au-dessus de la branche qui vous commande :
                <strong> la demande finale ne se transmet pas intégralement</strong> à la
                sous-traitance. Les explications compatibles sont le contenu mécanique par
                véhicule, l'internalisation chez le donneur d'ordre, ou un déstockage de la
                filière — le dispositif constate l'écart, il ne le tranche pas.</>
            : <> La branche qui vous commande produit au-dessus du marché final, configuration
                compatible avec un rattrapage de stocks ou une montée en contenu.</>}
        </p>
      )}

      <Chart series={series} hauteur={230} />

      <div className="ch-legende">
        {plan.filter(e => series[e.role]).map(e => (
          <div key={e.code} className="ch-ligne">
            <span className="etq e-gris">{e.code}</span>
            <span className="ch-role">{e.role}</span>
            <span className="ch-aide">{e.aide}</span>
            <b>{nb(derniers[e.role].value, 1)}</b>
            <span className="ch-per">{derniers[e.role].period}</span>
          </div>
        ))}
      </div>

      {atelier && (
        <p className="base-note">
          Base 100 = moyenne 2021. Un indice à {nb(atelier.value, 1)} signifie que la branche
          produit {nb(Math.abs(100 - Number(atelier.value)), 1)} %
          {Number(atelier.value) < 100 ? " en dessous" : " au-dessus"} de son niveau de 2021 —
          ce n'est pas une variation récente, c'est un niveau.
        </p>
      )}
    </div>
  );
}

function PartSuisse({ serie }) {
  const pts = (serie || []).filter(x => x.part_suisse_pct != null);
  if (pts.length < 3) return null;
  const a = pts[0], z = pts[pts.length - 1];
  const gain = Number(z.part_suisse_pct) - Number(a.part_suisse_pct);
  const nonCalc = (serie || []).filter(x => x.part_suisse_pct == null);

  return (
    <div className="carte preuve part-ch">
      <div className="p-tete">
        <div>
          <div className="p-titre">Part suisse du commerce mondial d'articles d'horlogerie</div>
          <div className="p-meta">indicateur synthétique · calculé par requête sur les séries consolidées</div>
        </div>
        <div className="p-val">{nb(z.part_suisse_pct, 1)} %</div>
      </div>

      <p className="pc-constat">
        <strong>{nb(a.part_suisse_pct, 1)} % en {a.period} → {nb(z.part_suisse_pct, 1)} % en {z.period}</strong>
        {" "}: {gain > 0 ? "gain" : "perte"} de {nb(Math.abs(gain), 1)} points en {pts.length - 1} exercices,
        sur un panier mondial passé de {nb(a.total_panier_mia_usd, 1)} à {nb(z.total_panier_mia_usd, 1)} milliards
        de dollars. La Suisse capte une part croissante d'un marché qui ne grandit pas.
        {" "}<strong>Pour un sous-traitant, ce n'est pas la même chose qu'un débouché qui s'élargit</strong> :
        c'est un débouché qui se concentre, et dont la santé tient à celle d'un petit nombre de donneurs
        d'ordre.
      </p>

      <Chart series={{ CHE: pts.map(x => ({ period: x.period, value: Number(x.part_suisse_pct) })) }}
             hauteur={150} />

      <p className="base-note">
        Panier de {z.nb_declarants_attendus} déclarants. La part n'est calculée que si tous ont
        soumis — c'est pourquoi {nonCalc.length > 0
          ? <>l'exercice {nonCalc.map(x => x.period).join(", ")} n'est pas calculable : la fraîcheur
             d'un panier est celle de son déclarant le plus lent.</>
          : "aucun exercice n'est écarté ici."}
      </p>
    </div>
  );
}

function DynamiqueGeo({ zones, divergences }) {
  const [tout, setTout] = React.useState({});
  const parIndicateur = {};
  zones.forEach(z => { (parIndicateur[z.indicator_id] ||= []).push(z); });
  const codes = Object.keys(parIndicateur);
  if (!codes.length) return null;

  return (
    <div className="geo">
      {codes.map(code => {
        const liste = parIndicateur[code];
        const div = divergences.find(d => d.indicator_id === code);
        const ouvert = !!tout[code];
        const visibles = ouvert ? liste : liste.slice(0, 8);
        const maxPart = Math.max(...liste.map(z => Number(z.part_pct) || 0));
        return (
          <div key={code} className="geo-bloc">
            <div className="geo-tete">
              <span className="etq e-gris">{code}</span>
              <span className="geo-lib">{liste[0].label}</span>
              <span className="geo-base">{liste[0].base_comparaison}</span>
            </div>

            {div && div.divergence && (
              <p className="geo-divergence">
                <strong>{div.premier_marche} — premier débouché avec {nb(div.premier_part_pct, 1)} % —
                évolue à {pct(div.premier_variation_pct)} quand la moyenne pondérée des
                {" "}{div.n_autres} autres marchés fait {pct(div.var_moy_ponderee)}.</strong> Soit un
                écart de {nb(Math.abs(div.ecart_points), 1)} points, de sens opposé. Le constat est
                calculé, non rédigé : il y a divergence quand les signes s'opposent et que l'écart
                atteint 5 points — seuil affiché pour être contesté, non pour être cru.
              </p>
            )}

            <div className="geo-liste">
              {visibles.map(z => {
                const v = Number(z.variation_pct);
                return (
                  <div key={z.geo} className={"geo-ligne" + (z.est_zone_de_reference ? " ref" : "")}>
                    <span className="geo-zone">{nomZone(z.geo)}</span>
                    <div className="geo-piste">
                      <div className="geo-jauge" style={{ width: (100 * (Number(z.part_pct) || 0) / maxPart) + "%" }} />
                    </div>
                    <span className="geo-part">{nb(z.part_pct, 1)} %</span>
                    <span className={"geo-var " + (v > 0 ? "hausse" : v < 0 ? "baisse" : "")}>
                      {pct(z.variation_pct)}
                    </span>
                    {z.est_zone_de_reference && <span className="geo-ref">zone de référence</span>}
                  </div>
                );
              })}
            </div>

            {liste.length > 8 && (
              <span className="src-inline" onClick={() => setTout(t => ({ ...t, [code]: !t[code] }))}>
                {ouvert ? "réduire" : `voir les ${liste.length} marchés`}
              </span>
            )}
          </div>
        );
      })}
    </div>
  );
}

function TexteAncre({ texte, index }) {
  // Découpe le texte sur les ancres [CTX-146] / [SIG-5] et rend chacune
  // comme un lien vers la pièce qu'elle désigne.
  const morceaux = String(texte || "").split(/(\[(?:SIG|CTX)-\d+\])/g);
  return (
    <>
      {morceaux.map((m, i) => {
        const ancre = /^\[((?:SIG|CTX)-\d+)\]$/.exec(m);
        if (!ancre) return <span key={i}>{m}</span>;
        const fait = index[ancre[1]];
        if (!fait) return <span key={i} className="ancre ancre-inconnue" title="ancre absente du contexte fourni">{m}</span>;
        const contenu = <>{ancre[1]}</>;
        return fait.source
          ? <a key={i} className="ancre" href={fait.source} target="_blank" rel="noopener noreferrer"
               title={`${fait.date || ""} — ${fait.fait || ""}`}>{contenu}</a>
          : <span key={i} className="ancre" title={fait.fait || ""}>{contenu}</span>;
      })}
    </>
  );
}

function AttributionAncree({ bloc }) {
  const [ouvert, setOuvert] = React.useState(false);
  const contexte = bloc.contexte_fourni || [];
  const index = Object.fromEntries(contexte.map(a => [a.ancre, a]));
  const citees = new Set(bloc.ancres_citees || []);
  const inutilisees = contexte.filter(a => !citees.has(a.ancre));

  return (
    <div className="attribution">
      <div className="at-tete">
        <span className="etq e-bleu">démonstration — hors production</span>
        <span className="at-titre">Attribution ancrée</span>
        <span className="at-compte">{citees.size} ancre{citees.size > 1 ? "s" : ""} citée
          {citees.size > 1 ? "s" : ""} sur {bloc.ancres_disponibles} disponibles</span>
      </div>

      <p className="at-principe">
        Le commentaire ci-dessus s'interdit d'attribuer une cause. Cette variante l'autorise à une
        condition : le fait invoqué doit figurer dans un contexte de faits <strong>validés ou
        examinés nominativement</strong>, et être cité. <strong>L'affirmation n'en devient pas plus
        certaine — elle devient vérifiable.</strong> Chaque ancre ci-dessous ouvre sa pièce.
      </p>

      <div className="at-texte">
        {/* Les en-têtes de section sont en gras dans la sortie du modèle. Les
            effacer avec le reste du balisage collait le titre au corps du texte
            (« qu'il faut retenir Le marché medtech… ») — on les isole. */}
        {String(bloc.text || "").split(/\n{2,}/).map((par, i) => {
          const m = /^\*\*(.+?)\*\*\s*(?:—\s*)?([\s\S]*)$/.exec(par.trim());
          const titre = m ? m[1].replace(/^\d+\.\s*/, "") : null;
          const corps = (m ? m[2] : par).replace(/\*\*/g, "").trim();
          return (
            <p key={i}>
              {titre && <strong className="at-h">{titre}</strong>}
              {corps && <TexteAncre texte={corps} index={index} />}
            </p>
          );
        })}
      </div>

      <div className="at-pied">
        <span className="etq e-vert">validé</span>
        {bloc.validated_by} · {dateCH(bloc.validated_at)} · {bloc.model}
        <span className="at-lien" onClick={() => setOuvert(o => !o)}>
          {ouvert ? "masquer le contexte" : `voir les ${contexte.length} faits fournis`}
        </span>
      </div>

      {ouvert && (
        <div className="at-contexte">
          <div className="at-sous">
            Ce que le modèle avait sous les yeux. Les {inutilisees.length} faits qu'il n'a pas cités
            sont indiqués : un contexte non utilisé se voit, il ne se devine pas.
          </div>
          {contexte.map(a => (
            <div key={a.ancre} className={"at-fait" + (citees.has(a.ancre) ? " cite" : "")}>
              <span className="etq e-gris">{a.ancre}</span>
              <span className="at-date">{a.date}</span>
              <span className="at-lib">{a.fait}</span>
              {a.source && <LienSource href={a.source} />}
              {!citees.has(a.ancre) && <span className="at-nc">non cité</span>}
            </div>
          ))}
        </div>
      )}

      <p className="at-reserve">
        <strong>Portée de la validation</strong> — elle établit que chaque fait cité existe et
        correspond à ce qui en est dit ; elle n'établit pas qu'il explique le mouvement observé.
        C'est pourquoi le texte écrit « composante identifiée » et « hypothèse documentée », jamais
        une cause. La couverture dépend du stock de faits examinés, non du mécanisme : les secteurs
        sans examens versés au contexte n'affichent rien ici, et c'est un constat, pas une panne.
      </p>
    </div>
  );
}

export default function SecteurQV() {
  const { code } = useParams();
  const { D, S, G, AT, GEO } = useDonnees();
  const navigate = useNavigate();
  if (!D) return <div className="page"><div className="vide">Chargement…</div></div>;

  const referentiel = (D.referentiel || []).filter(i => i.sector_code === code);
  const secteur = S?.sante?.find(x => x.sector_code === code);
  const libelle = secteur?.sector_label || referentiel[0]?.sector_label || code;
  const instanciation = (D.instanciation || []).filter(q => q.sector_code === code);
  const couverture = (D.couverture_qv || []).filter(c => c.sector_code === code);
  const commentaire = (D.commentaires || []).find(c => c.sector_code === code);
  const attribution = ((AT && AT.attribution) || []).find(a => a.sector_code === code);
  // QV3 : les zones du secteur, et le constat de divergence s'il y en a un.
  const zonesGeo = ((GEO && GEO.zones) || []).filter(z => z.sector_code === code);
  const divergencesGeo = ((GEO && GEO.divergences) || []).filter(d => d.sector_code === code);
  const ecarteesGeo = (GEO && GEO.ecartees) || 0;
  const seuilGeo = (GEO && GEO.seuil_poids_pct) || 1;
  // Les questions applicables au secteur, dans l'ordre, telles que déclarées.
  const questionsDuSecteur = [...new Set(instanciation.map(q => q.watch_question_code))].sort();
  const signaux = (G?.signaux || []).filter(s => s.sector_code === code);

  // L'état du marché en mots — même règle et mêmes bornes que l'écran d'accueil,
  // pour qu'un lecteur qui passe de l'un à l'autre lise la même chose.
  const score = (secteur?.score_sante === null || secteur?.score_sante === undefined)
    ? null : Number(secteur.score_sante);
  const etat = etatMarche(score);
  const direction = directionLongue(Number(secteur?.tendance_moyenne));
  const doublons = redondances(D, secteur?.indicateurs || []);

  return (
    <div className="page">
      <header className="ouverture">
        <div>
          <p className="ouv-date">
            {questionsDuSecteur.length > 1
              ? `Marché suivi · ${questionsDuSecteur.length} questions de veille`
              : "Socle commun aux quatre marchés"}
          </p>
          <h1 className="ouv-titre">{libelle}</h1>
        </div>
        <div className="ouv-etat" style={{ minWidth: 190 }}>
          <span className={"marche-etat t-" + etat.ton} style={{ fontSize: 19 }}>{etat.mot}</span>
          <Regle score={score} ton={etat.ton} />
        </div>
      </header>

      <p className="brief">
        {etat.phrase}{direction ? `, ${direction}` : ""}.{" "}
        {questionsDuSecteur.length > 1 ? (
          <>Ce qui suit répond, question par question, à ce qu'un sous-traitant a besoin de
          savoir de ce marché. Une question sans matière reste affichée : savoir ce qu'on ne
          mesure pas fait partie du dispositif.</>
        ) : (
          <>Le socle ne répond pas aux questions sectorielles : il porte la question
          d'attribution, qui sert de dénominateur commun aux quatre marchés.</>
        )}
      </p>

      {doublons.length > 0 && (
        <div className="carte avert" style={{ marginBottom: 22 }}>
          <strong>Prudence sur le score de ce marché.</strong>{" "}
          <em>{doublons[0].nomA}</em> et <em>{doublons[0].nomB}</em> évoluent ensemble
          (corrélation {nb(Math.abs(doublons[0].r), 2)} sur {doublons[0].n} points communs) :
          elles mesurent pratiquement la même grandeur, et le score les compte à égalité.
          Il est donc plus assuré qu'il ne devrait l'être. Les séries elles-mêmes, ci-dessous,
          ne sont pas en cause — c'est leur moyenne qui l'est.
        </div>
      )}

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
                {qv === "QV1" && attribution && <AttributionAncree bloc={attribution} />}
                {qv === "QV1" && <Chaine code={code} D={D} />}
                {qv === "QV1" && code === "horlogerie" && D.synthetique &&
                  <PartSuisse serie={D.synthetique} />}
                {qv === "QV1" && code === "horlogerie" && D.mix_horloger &&
                  <MixHorloger serie={D.mix_horloger} />}
                {qv === "QV3" && zonesGeo.length > 0 && (
                  <>
                    <DynamiqueGeo zones={zonesGeo} divergences={divergencesGeo} />
                    <p className="geo-tamis">
                      Marchés pesant au moins {nb(seuilGeo, 0)} % de leur indicateur. Une variation
                      relative énorme sur un marché minuscule est un artefact, pas un signal :
                      {" "}{ecarteesGeo} zones sont écartées à ce titre, tous indicateurs confondus,
                      et restent lisibles au registre.
                    </p>
                  </>
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
