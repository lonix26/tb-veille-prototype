import React, { createContext, useContext, useEffect, useState, useCallback } from "react";

// ---------------------------------------------------------------------
// Accès aux données — UNE interface : l'API de restitution n8n (lecture
// seule). Aucune donnée en dur ; base coupée, l'application l'affiche.
// ---------------------------------------------------------------------
export const API_BASE =
  import.meta.env.VITE_API_BASE || "http://localhost:5678/webhook/veille";
export const API_URL = API_BASE + "/donnees";

// Exporté — et pas seulement déclaré — pour que le rendu puisse être éprouvé
// hors navigateur (voir `verification/rendu.jsx`). Sans cela, un écran ne se
// teste qu'en l'ouvrant à la main, ce qui n'est pas une vérification.
export const Ctx = createContext(null);

// La v4 lit QUATRE points de lecture, tous en lecture seule :
//   /donnees      — la charge utile historique (v2/v3), conservée telle quelle
//   /sante        — santé sectorielle et compteurs (écran « Cette semaine »)
//   /signaux      — signaux VALIDÉS, axes du triage et confirmateurs (écran Radar)
//   /opportunites — items de marchés publics EXAMINÉS par un humain (écran 4)
// Les trois derniers échouent sans faire tomber l'application : un écran qui
// ne peut pas se peupler le dit, il ne disparaît pas.
export function FournisseurDonnees({ children }) {
  const [donnees, setDonnees] = useState(null);
  const [sante, setSante] = useState(null);
  const [signaux, setSignaux] = useState(null);
  const [opportunites, setOpportunites] = useState(null);
  const [actions, setActions] = useState(null);
  const [attribution, setAttribution] = useState(null);
  const [geographie, setGeographie] = useState(null);
  const [erreur, setErreur] = useState(null);
  const [erreursV4, setErreursV4] = useState({});
  const [chargement, setChargement] = useState(true);
  const [misAJour, setMisAJour] = useState(null);

  const recharger = useCallback(async () => {
    setChargement(true);
    setErreur(null);
    const secondaire = async (chemin, poser) => {
      try {
        const r = await fetch(API_BASE + chemin, { cache: "no-store" });
        if (!r.ok) throw new Error("HTTP " + r.status);
        poser(await r.json());
        setErreursV4(e => ({ ...e, [chemin]: null }));
      } catch (e) {
        poser(null);
        setErreursV4(er => ({ ...er, [chemin]: String(e) }));
      }
    };
    try {
      const r = await fetch(API_URL, { cache: "no-store" });
      if (!r.ok) throw new Error("HTTP " + r.status);
      setDonnees(await r.json());
      setMisAJour(new Date());
    } catch (e) {
      setErreur(String(e));
    }
    await Promise.all([
      secondaire("/sante", setSante),
      secondaire("/signaux", setSignaux),
      secondaire("/opportunites", setOpportunites),
      secondaire("/actions", setActions),
      secondaire("/attribution", setAttribution),
      secondaire("/geographie", setGeographie)
    ]);
    setChargement(false);
  }, []);

  useEffect(() => { recharger(); }, [recharger]);

  return (
    <Ctx.Provider value={{ D: donnees, S: sante, G: signaux, O: opportunites, A: actions, AT: attribution, GEO: geographie,
                           erreur, erreursV4, chargement, misAJour, recharger }}>
      {children}
    </Ctx.Provider>
  );
}

// ---------------------------------------------------------------------
// Bloc « source » — E6 en pixel. Chaque affirmation de la v4 en porte un :
// la conception l'exige, et c'est ce qui distingue une preuve d'un avis.
// ---------------------------------------------------------------------
export function LienSource({ href, children, titre }) {
  if (!href) return <span className="src-absente" title={titre || "aucune URL enregistrée"}>source non enregistrée</span>;
  return (
    <a className="src" href={href} target="_blank" rel="noreferrer" title={titre}>
      {children || "voir la source"} ↗
    </a>
  );
}

// Mention affichée partout où un score de triage IA apparaît : il ordonne
// une lecture, il ne vaut jamais validation (conception v4, règle 2).
export function MentionTriage() {
  return (
    <span className="mention-triage">
      score de triage : il ordonne la lecture, il ne vaut pas validation
    </span>
  );
}

export const useDonnees = () => useContext(Ctx);

// ---------------------------------------------------------------------
// Aides de formatage (fr-CH) et de lecture — mêmes conventions que la
// restitution précédente, garanties conservées.
// ---------------------------------------------------------------------
export const nb = (v, dMax) =>
  v === null || v === undefined || isNaN(v)
    ? "n.d."
    : new Intl.NumberFormat("fr-CH", {
        maximumFractionDigits: dMax ?? (Math.abs(v) >= 100 ? 0 : 2)
      }).format(v);

export const pct = v =>
  v === null || v === undefined || isNaN(v)
    ? "n.d."
    : (v > 0 ? "+" : "") +
      new Intl.NumberFormat("fr-CH", { maximumFractionDigits: 1 }).format(v) + " %";

export const clsVar = v =>
  v === null || v === undefined || isNaN(v) ? "neutre" : v > 0 ? "hausse" : v < 0 ? "baisse" : "neutre";

export const dateCH = s => (s ? new Date(s).toLocaleDateString("fr-CH") : "");
export const heureCH = d => (d ? d.toLocaleTimeString("fr-CH", { hour: "2-digit", minute: "2-digit" }) : "");

// Markdown minimal des commentaires exécutifs (gras + sauts de ligne).
export function MarkdownLeger({ texte }) {
  const morceaux = String(texte ?? "").split(/\*\*(.+?)\*\*/g);
  return (
    <>
      {morceaux.map((m, i) =>
        i % 2 === 1 ? <strong key={i}>{m}</strong> :
          m.split("\n").map((l, j, arr) => (
            <React.Fragment key={i + "-" + j}>{l}{j < arr.length - 1 && <br />}</React.Fragment>
          ))
      )}
    </>
  );
}

// ---------------------------------------------------------------------
// Agrégats hors classements — convention héritée de la restitution v2/v3 ;
// la résolution propre reste la nomenclature géographique en base (§ 10.6).
// ---------------------------------------------------------------------
const AGREGATS = new Set([
  "WORLD", "W00", "OWID_WRL", "GLOBAL",
  "AFR", "AMR", "EMR", "EUR", "SEAR", "WPR",
  "World", "Europe", "European Union", "Advanced Economies",
  "Developing Economies excl. China", "Africa", "Asia Pacific",
  "Latin America", "Middle East", "Oceania", "Rest of the world",
  "Southeast Asia", "Middle East and Caspian",
  "EU27", "EU27_2020", "G20", "CH"
]);
export const estAgregat = g => AGREGATS.has(String(g)) || String(g).startsWith("WB_");

const NOMS_ZONES = {
  WORLD: "monde", W00: "monde", World: "monde", "European Union": "Union européenne", EU: "Union européenne", EU27: "UE-27", EU27_2020: "UE-27",
  CH: "Suisse", G20: "G20", CHF_USD: "CHF/USD", CHF_EUR: "CHF/EUR", OWID_WRL: "monde",
  // Les pays qui pèsent effectivement dans les séries collectées. La liste est
  // volontairement courte : un code ISO non traduit s'affiche tel quel, ce qui
  // est lisible ; une traduction approximative ne le serait pas.
  USA: "États-Unis", US: "États-Unis", CHN: "Chine", JPN: "Japon", DEU: "Allemagne",
  FRA: "France", GBR: "Royaume-Uni", ITA: "Italie", ESP: "Espagne", NLD: "Pays-Bas",
  CHE: "Suisse", HKG: "Hong Kong", SGP: "Singapour", KOR: "Corée du Sud", IND: "Inde",
  ARE: "Émirats arabes unis", SAU: "Arabie saoudite", QAT: "Qatar", TUR: "Turquie",
  MEX: "Mexique", CAN: "Canada", BRA: "Brésil", AUS: "Australie", POL: "Pologne",
  CZE: "Tchéquie", IRL: "Irlande", RUS: "Russie", BEL: "Belgique", AUT: "Autriche",
  SWE: "Suède", THA: "Thaïlande", VNM: "Viêt Nam", MYS: "Malaisie", IDN: "Indonésie",
  ZAF: "Afrique du Sud", ISR: "Israël", NOR: "Norvège", DNK: "Danemark", PRT: "Portugal",
  // Ajout du 25.08 : les pays des acheteurs publics européens. Un code ISO
  // non traduit reste lisible, mais « ROU » dans une colonne « pays » à côté
  // de « Allemagne » et « Pologne » se lit comme une donnée manquante.
  ROU: "Roumanie", HUN: "Hongrie", BGR: "Bulgarie", SVK: "Slovaquie",
  SVN: "Slovénie", HRV: "Croatie", LTU: "Lituanie", LVA: "Lettonie",
  EST: "Estonie", GRC: "Grèce", FIN: "Finlande", LUX: "Luxembourg",
  CYP: "Chypre", MLT: "Malte", ISL: "Islande", SRB: "Serbie", UKR: "Ukraine"
};
export const nomZone = g => {
  if (NOMS_ZONES[g]) return NOMS_ZONES[g];
  // Codes spéciaux Comtrade (S19 « autres Asie n.d.a. », X* zones non
  // spécifiées…) : du commerce réel, pas des destinations nommées.
  if (/^[SXF]\d/.test(String(g))) return "n.d.a. (" + g + ")";
  return g;
};

// Lectures dérivées de la charge utile.
export const serieDe = (D, id, geo) =>
  (D?.valeurs || [])
    .filter(v => v.indicator_id === id && (geo === undefined || v.geo === geo))
    .sort((a, b) => String(a.period).localeCompare(String(b.period)));

export const zonesDe = (D, id) => [...new Set(serieDe(D, id).map(v => v.geo))];

export const metrDe = (D, id, geo) =>
  (D?.metriques || []).find(m => m.indicator_id === id && (geo === undefined || m.geo === geo));

// ---------------------------------------------------------------------
// FRANCHISSEMENTS SIGNIFICATIFS — règle UNIQUE, partagée par l'écran
// « Cette semaine » et par les pastilles de la navigation.
//
// Elle vivait en double le 23.08.2026 : l'écran écartait les marchés
// pesant moins de 1 % de leur indicateur, la pastille les comptait tous.
// La navigation annonçait donc 121 franchissements en horlogerie quand
// l'écran en retenait une poignée — deux copies d'un même filtre finissent
// toujours par diverger. Une seule règle, un seul endroit.
//
// Motif : sur une série à longue traîne (H1, 197 destinations), une
// variation relative énorme sur un marché minuscule est un artefact de
// petits nombres, pas un signal. Constaté sur pièces — Congo +938 %,
// Nicaragua +810 %, pour 0,000 % des exportations.
// ---------------------------------------------------------------------
export const SEUIL_POIDS_PCT = 1;

export function poidsAlerte(D, a) {
  const memePeriode = (D?.valeurs || []).filter(
    v => v.indicator_id === a.indicator_id && v.period === a.period && !estAgregat(v.geo));
  const total = memePeriode.reduce((s, v) => s + Math.abs(Number(v.value) || 0), 0);
  if (!total) return null;   // indicateur mono-zone : poids de 100 % par construction
  return 100 * Math.abs(Number(a.value) || 0) / total;
}

export function alertesSignificatives(D) {
  const toutes = (D?.alertes || []).filter(a => a.diffusable)
    .map(a => ({ ...a, poids_pct: poidsAlerte(D, a) }));
  const retenues = toutes.filter(a => a.poids_pct === null || a.poids_pct >= SEUIL_POIDS_PCT);
  return { toutes, retenues, ecartees: toutes.length - retenues.length };
}

export function BadgeStatut({ statut }) {
  if (!statut) return null;
  const carte = {
    valide_source: ["e-vert", "validé par la source"],
    valide_humain: ["e-vert", "validé humainement"],
    pre_valide_consensus: ["e-ambre", "pré-validé (consensus)"]
  };
  const [cls, lbl] = carte[statut] || ["e-gris", statut];
  return <span className={"etq " + cls}>{lbl}</span>;
}

// ---------------------------------------------------------------------------
// Commentaire exécutif : relu ou non — CHANGEMENT DU 31.08.2026.
//
// L'API sert désormais AUSSI les commentaires que personne n'a relus (décision
// de l'étudiant, tracée). Le régime est celui déjà appliqué aux VALEURS par
// BadgeStatut : ce qui n'a pas vu d'humain se diffuse, mais se signale. Sans
// cette distinction à l'écran, l'autonomie deviendrait de l'opacité — et le
// dispositif servirait comme lecture établie un texte dont 60 % des
// prédécesseurs ont été rejetés en relecture (25 validés, 38 rejetés au 31.08).
export function relu(c) {
  return (c?.status ?? "valide") === "valide";
}

export function BadgeCommentaire({ c }) {
  return relu(c)
    ? <span className="etq e-vert">relu et validé</span>
    : <span className="etq e-ambre">rédigé par un modèle, non relu</span>;
}

// Mention de pied : qui répond du texte, et depuis quand.
export function signatureCommentaire(c, dateCH) {
  return relu(c)
    ? [c.validated_by, dateCH(c.validated_at), c.model].filter(Boolean).join(" · ")
    : ["aucune relecture humaine", dateCH(c.created_at), c.model].filter(Boolean).join(" · ");
}

// ---------------------------------------------------------------------------
// LECTURE DES FRANCHISSEMENTS — RÉFORME DU 31.08.2026 (décision de l'étudiant).
//
// Constat mesuré : un seuil calibré au p90 fait franchir ~1 observation sur 10
// PAR CONSTRUCTION ; appliqué aux 190 destinations de H1, il fabriquait 123
// « signalements » dont Namibie −99 %… sur 32 USD. Le compteur « 127
// signalements » était un artefact arithmétique, pas une information.
// Trois réponses, portées ici pour que tous les écrans lisent la même règle :
//  1. le SENS — `sens_favorable` est déclaré au référentiel pour chaque
//     certifié ; un franchissement se signe (favorable/défavorable), il ne
//     s'affiche plus uniformément en rouge ;
//  2. la PHRASE — « (seuil 8 %) » devient « amplitude vue moins d'une fois
//     sur dix sur cette série », le sens réel du p90 dit en français ;
//  3. les ZONES ne sont pas des alertes — 123 franchissements de zones sont
//     UN fait (la géographie bouge), résumé en une ligne pondérée ; le
//     détail vit à QV3, en points de part, où il se lit mieux.
export function sensMouvement(D, a) {
  const ref = (D?.referentiel || []).find(r => r.indicator_id === a.indicator_id);
  const s = Number(ref?.sens_favorable ?? 0);
  const g = Number(a.glissement_annuel_pct ?? a.variation_periode_pct ?? 0);
  if (!s || !g) return "neutre";
  return (g > 0) === (s > 0) ? "favorable" : "defavorable";
}

export const SENS_ETQ = {
  favorable:   ["e-vert",  "favorable"],
  defavorable: ["e-rouge", "défavorable"],
  neutre:      ["e-gris",  "à interpréter"]
};

// Libellés des six angles invariants (décision du 07.08.2026) — le code QV
// seul est un jargon, le couple code + angle se lit.
export const QV_LIBELLES = {
  QV0: "attribution", QV1: "santé structurelle", QV2: "demande et débouchés",
  QV3: "dynamique géographique", QV4: "dynamique technologique", QV5: "impulsions publiques"
};

export function qvDe(D, indicator_id) {
  const q = (D?.referentiel || []).find(r => r.indicator_id === indicator_id)?.questions;
  return q ? String(q).split(/[,\s]+/)[0] : null;
}

// Synthèse d'un paquet de franchissements de ZONES d'une même série :
// zones pesant ≥ SEUIL_POIDS_PCT du flux (triées par poids), zones écartées
// comptées — jamais tues. Le tri par poids et non par variation évite le
// palmarès des petites zones (piège documenté sur A11).
export function syntheseZones(D, rows) {
  // AUDIT DU 01.09.2026 : un agrégat (World, Asia Pacific…) n'est PAS une
  // zone — la synthèse A3 titrait « la plus lourde World » : le mouvement
  // d'ensemble de la série déguisé en déplacement géographique. Seules les
  // vraies zones entrent ici ; l'agrégat se lit en ligne de série.
  const pesees = rows.filter(a => !estAgregat(a.geo)).map(a => ({ ...a, poids_pct: poidsAlerte(D, a) }))
    .sort((x, y) => (y.poids_pct ?? 0) - (x.poids_pct ?? 0));
  const retenues = pesees.filter(a => a.poids_pct === null || a.poids_pct >= SEUIL_POIDS_PCT);
  return { retenues, ecartees: pesees.length - retenues.length, laPlusLourde: retenues[0] || null };
}

// ---------------------------------------------------------------------------
// ÉVÉNEMENTS TYPÉS ET LECTURES TRANSVERSALES — 31.08.2026 (décision de
// l'étudiant, réaffirmée). Deux étages nouveaux, même régime d'honnêteté :
// ce qu'aucun humain n'a relu se voit, en ambre.
export const TYPE_EVT = {
  investissement:      ["e-vert",  "investissement"],
  fermeture_reduction: ["e-rouge", "fermeture / réduction"],
  rachat_fusion:       ["e-violet","rachat / fusion"],
  reglementation:      ["e-bleu",  "réglementation"],
  lancement_produit:   ["e-gris",  "lancement produit"],
  resultat_financier:  ["e-gris",  "résultats financiers"],
  partenariat:         ["e-vert",  "partenariat"],
  autre:               ["e-gris",  "autre"]
};
export const SENS_EVT = {
  opportunite: ["e-vert",  "opportunité"],
  menace:      ["e-rouge", "menace"],
  neutre:      ["e-gris",  "neutre"]
};
export function BadgeEvenement({ e }) {
  return e.statut === "valide"
    ? <span className="etq e-vert">relu et validé</span>
    : <span className="etq e-ambre">lu par un modèle, non relu</span>;
}
