// =====================================================================
// PHRASES — la couche qui manquait.
//
// Un tableau de bord destiné à un dirigeant de PME ne peut pas ouvrir sur
// « score 1,20 · z détendancé · n = 4 ». Ce module traduit les grandeurs du
// dispositif en français lisible, et il le fait à UN SEUL endroit pour que
// les mêmes chiffres produisent partout les mêmes mots.
//
// Règle de rédaction tenue ici : on dit ce que la donnée montre, jamais plus.
// Quand la base est mince, la phrase le dit au lieu d'arrondir l'incertitude.
// =====================================================================
import { nb, pct, nomZone, estAgregat } from "./api.jsx";

// ---------------------------------------------------------------------
// 1. L'état d'un marché, en mots avant d'être en chiffres.
//
// Le score est un écart à la base de la série, tendance longue retirée,
// exprimé en écarts-types. Les bornes ci-dessous sont celles de la règle
// d'interprétation du dispositif ; elles ne sont pas choisies ici.
// ---------------------------------------------------------------------
export function etatMarche(score) {
  if (score === null || score === undefined || isNaN(score))
    return { mot: "base insuffisante", phrase: "trop peu de points pour se prononcer", ton: "gris" };
  const a = Math.abs(score);
  const sens = score > 0 ? "au-dessus" : "en dessous";
  if (a < 0.5) return {
    mot: "dans sa norme",
    phrase: "le marché se tient à son niveau habituel",
    ton: "gris"
  };
  if (a < 1) return {
    mot: `un peu ${sens}`,
    phrase: `le marché est un peu ${sens} de son niveau habituel, sans que ce soit marquant`,
    ton: score > 0 ? "vert" : "ambre"
  };
  if (a < 2) return {
    mot: `nettement ${sens}`,
    phrase: `le marché est nettement ${sens} de son niveau habituel`,
    ton: score > 0 ? "vert" : "rouge"
  };
  return {
    mot: `très ${sens}`,
    phrase: `le marché s'écarte fortement de son niveau habituel — situation rare`,
    ton: score > 0 ? "vert" : "rouge"
  };
}

// ---------------------------------------------------------------------
// 2. La direction longue — une autre question que la position dans le cycle,
//    et il faut le dire, sinon les deux se confondent à la lecture.
// ---------------------------------------------------------------------
export function directionLongue(t) {
  if (t === null || t === undefined || isNaN(t)) return null;
  const a = Math.abs(t);
  if (a < 0.2) return "sans direction nette sur la durée";
  const s = t > 0 ? "hausse" : "baisse";
  // Formulations sans accord : elles suivent « le marché » comme « la branche ».
  if (a < 0.5) return `légèrement en ${s} sur la durée`;
  return `nettement en ${s} sur la durée`;
}

// ---------------------------------------------------------------------
// 3. Les échéances — un dirigeant lit « dans 8 jours », pas « J-8 ».
// ---------------------------------------------------------------------
export function phraseEcheance(jours) {
  if (jours === null || jours === undefined || isNaN(jours)) return "sans échéance publiée";
  const j = Math.round(jours);
  if (j < 0) return "délai dépassé";
  if (j === 0) return "aujourd’hui";
  if (j === 1) return "demain";
  if (j <= 7) return `dans ${j} jours`;
  if (j <= 31) return `dans ${Math.round(j / 7)} semaines`;
  return `dans ${Math.round(j / 30)} mois`;
}

export function tonEcheance(jours) {
  if (jours === null || jours === undefined) return "gris";
  if (jours <= 7) return "rouge";
  if (jours <= 21) return "ambre";
  return "gris";
}

// ---------------------------------------------------------------------
// 4. Une variation, dite comme on la dirait à l'oral.
// ---------------------------------------------------------------------
export function phraseVariation(libelle, pourcent, horizon = "sur un an") {
  if (pourcent === null || pourcent === undefined || isNaN(pourcent)) return null;
  const a = Math.abs(pourcent);
  const verbe = pourcent > 0
    ? (a > 25 ? "bondissent de" : a > 8 ? "progressent de" : "gagnent")
    : (a > 25 ? "s'effondrent de" : a > 8 ? "reculent de" : "perdent");
  return `${libelle} ${verbe} ${nb(a, 1)} % ${horizon}`;
}

// ---------------------------------------------------------------------
// 5. Fraîcheur — « à jour » n'est pas une opinion, c'est une date.
// ---------------------------------------------------------------------
export function phraseFraicheur(execute_le) {
  if (!execute_le) return "date de collecte inconnue";
  const h = (Date.now() - new Date(execute_le)) / 3600000;
  if (h < 2) return "collecté à l'instant";
  if (h < 24) return `collecté il y a ${Math.round(h)} heures`;
  const j = Math.round(h / 24);
  if (j === 1) return "collecté hier";
  if (j <= 14) return `collecté il y a ${j} jours`;
  return `dernière collecte il y a ${Math.round(j / 7)} semaines`;
}

// ---------------------------------------------------------------------
// 6. REDONDANCE ENTRE SÉRIES — le contrôle honnête que le score n'avait pas.
//
// Trois des quatre séries qui portent le score horloger mesurent les
// exportations horlogères suisses : H1 par Comtrade, H7 par la Fédération
// de l'industrie horlogère, H3 sur zone de référence suisse. H1 et H7
// corrèlent à 0,93 sur leurs points communs. Un score qui les moyenne à
// égalité compte deux fois la même information et paraît plus assuré
// qu'il ne l'est.
//
// Plutôt que de corriger le score en silence — ce serait un choix de
// méthode, et il appartient à l'auteur du travail —, l'écran le DIT.
// ---------------------------------------------------------------------
// Une unité d'indice, un taux ou un solde d'opinion ne s'additionne pas :
// sommer les indices de production de trois pays ne produit rien de sensé.
// Une valeur monétaire ou un décompte, si. Même règle qu'en base.
const UNITE_NON_ADDITIVE = /indice|index|%|pourcent|taux|point|ratio|solde/i;

export function serieAgregee(D, id) {
  const pts = (D?.valeurs || []).filter(v => v.indicator_id === id);
  if (!pts.length) return null;
  const zones = new Set(pts.map(p => p.geo));
  const unite = pts[0].unit || "";

  // Mono-zone : la série est déjà la bonne.
  if (zones.size === 1) {
    const m = new Map();
    for (const p of pts) m.set(p.period, Number(p.value));
    return m;
  }
  // Multi-zones additives : la série de l'indicateur est la SOMME.
  // Sans cela, H1 — les exportations horlogères suisses, ventilées sur
  // 198 destinations — serait représenté par la première zone dans l'ordre
  // alphabétique, c'est-à-dire Aruba. Une comparaison faite sur Aruba ne dit
  // rien de la branche, et l'écran n'aurait signalé aucune redondance.
  if (!UNITE_NON_ADDITIVE.test(unite)) {
    const m = new Map();
    for (const p of pts) m.set(p.period, (m.get(p.period) || 0) + Number(p.value));
    return m;
  }
  // Multi-zones non additives : on retient la zone la mieux fournie, faute de mieux.
  const parGeo = new Map();
  for (const p of pts) parGeo.set(p.geo, (parGeo.get(p.geo) || 0) + 1);
  let meilleure = null, n = -1;
  for (const [g, c] of parGeo) if (c > n) { meilleure = g; n = c; }
  const m = new Map();
  for (const p of pts) if (p.geo === meilleure) m.set(p.period, Number(p.value));
  return m;
}

function pearson(a, b) {
  const communs = [...a.keys()].filter(k => b.has(k));
  if (communs.length < 6) return null;
  const x = communs.map(k => a.get(k)), y = communs.map(k => b.get(k));
  const mx = x.reduce((s, v) => s + v, 0) / x.length;
  const my = y.reduce((s, v) => s + v, 0) / y.length;
  let num = 0, dx = 0, dy = 0;
  for (let i = 0; i < x.length; i++) {
    num += (x[i] - mx) * (y[i] - my);
    dx += (x[i] - mx) ** 2;
    dy += (y[i] - my) ** 2;
  }
  if (!dx || !dy) return null;
  return { r: num / Math.sqrt(dx * dy), n: communs.length };
}

export const SEUIL_REDONDANCE = 0.9;

export function redondances(D, ids) {
  if (!D || !ids || ids.length < 2) return [];
  const nom = id => (D.referentiel || []).find(r => r.indicator_id === id)?.label || id;
  const series = new Map();
  for (const id of ids) { const s = serieAgregee(D, id); if (s) series.set(id, s); }
  const out = [];
  const liste = [...series.keys()];
  for (let i = 0; i < liste.length; i++)
    for (let j = i + 1; j < liste.length; j++) {
      const c = pearson(series.get(liste[i]), series.get(liste[j]));
      if (c && Math.abs(c.r) >= SEUIL_REDONDANCE)
        out.push({ a: liste[i], b: liste[j], r: c.r, n: c.n,
                   nomA: nom(liste[i]), nomB: nom(liste[j]) });
    }
  return out.sort((p, q) => Math.abs(q.r) - Math.abs(p.r));
}

// ---------------------------------------------------------------------
// 7. LE BRIEF — deux à quatre phrases, en tête d'écran, construites à
//    partir de ce qui est réellement en base. Aucune phrase n'est écrite
//    si la donnée qui la porte manque : mieux vaut un brief court.
// ---------------------------------------------------------------------
export function construireBrief({ sante, actions, alertes, aValider, aExaminer, D }) {
  const phrases = [];

  // a. Le marché le plus écarté de sa norme, s'il l'est assez pour valoir d'être dit.
  const marches = (sante || []).filter(s => s.sector_code !== "transversal" && s.score_sante !== null);
  const extreme = [...marches].sort((a, b) => Math.abs(b.score_sante) - Math.abs(a.score_sante))[0];
  if (extreme && Math.abs(extreme.score_sante) >= 0.5) {
    const e = etatMarche(Number(extreme.score_sante));
    phrases.push(`${avecArticle(extreme.sector_label)} ressort ${e.mot} de son niveau habituel`);
  } else if (marches.length) {
    phrases.push("Aucun des quatre marchés ne s'écarte nettement de son niveau habituel");
  }

  // b. Ce qui expire — la seule information réellement datée du dispositif.
  const adressables = (actions || []).filter(a => a.adressable >= 1);
  const urgentes = adressables.filter(a => a.jours_restants !== null && a.jours_restants <= 15);
  if (urgentes.length === 1) {
    const u = urgentes[0];
    phrases.push(`un appel d'offres à votre portée se clôt ${phraseEcheance(u.jours_restants)}`);
  } else if (urgentes.length > 1) {
    const plusProche = Math.min(...urgentes.map(u => u.jours_restants));
    phrases.push(`${enLettres(urgentes.length)} appels d'offres à votre portée se closent d'ici quinze jours, le premier se clôt ${phraseEcheance(plusProche)}`);
  } else if (adressables.length) {
    phrases.push(`${adressables.length} appels d'offres restent à votre portée, sans urgence immédiate`);
  }

  // c. Ce qui attend une décision humaine — c'est un fait d'exploitation,
  //    pas un défaut, et le taire donnerait à croire que tout est traité.
  const enAttente = [];
  if (aValider) enAttente.push(`${enLettres(aValider)} commentaire${aValider > 1 ? "s" : ""} à valider`);
  if (aExaminer) enAttente.push(`${nb(aExaminer)} items de veille non examinés`);
  if (enAttente.length) phrases.push(enAttente.join(" et "));

  if (!phrases.length) return "Rien à signaler dans les données disponibles.";
  const t = phrases.join(", ") + ".";
  return t.charAt(0).toUpperCase() + t.slice(1);
}

// ---------------------------------------------------------------------
// 8. Mouvements — une alerte de seuil dite en langue, pas en colonne.
// ---------------------------------------------------------------------
export function phraseMouvement(a) {
  const zone = estAgregat(a.geo) ? "" : ` vers ${nomZone(a.geo)}`;
  const libelle = (a.indicator_label || a.indicator_id) + zone;
  // On AFFICHE ce sur quoi on CLASSE. Le bloc triait sur la variation d'une
  // période à la suivante et montrait le glissement annuel : deux grandeurs
  // différentes dans le même bloc, dont l'une justifiait un rang que l'autre
  // ne montrait pas. Le glissement reste indiqué en second, quand il existe.
  const dPeriode = Number(a.variation_periode_pct);
  const dAnnuel = Number(a.glissement_annuel_pct);
  const base = phraseVariation(libelle, dPeriode, "depuis le point précédent");
  if (!base) return phraseVariation(libelle, dAnnuel) || `${libelle} : variation non calculable`;
  // Sur une série annuelle, « depuis le point précédent » EST le glissement annuel :
  // afficher les deux répète le même chiffre. On ne montre le second que lorsqu'il
  // apporte quelque chose.
  const memeChiffre = !isNaN(dAnnuel) && Math.abs(dAnnuel - dPeriode) < 0.05;
  return (isNaN(dAnnuel) || memeChiffre) ? base : `${base} (${pct(dAnnuel)} sur un an)`;
}

// ---------------------------------------------------------------------
// 9. Nombres écrits en toutes lettres jusqu'à seize — un texte destiné à
//    être lu, pas parcouru, écrit « quatre marchés » et non « 4 marchés ».
// ---------------------------------------------------------------------
const LETTRES = ["zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit",
                 "neuf", "dix", "onze", "douze", "treize", "quatorze", "quinze", "seize"];
export const enLettres = n =>
  Number.isInteger(n) && n >= 0 && n <= 16 ? LETTRES[n] : nb(n);

// ---------------------------------------------------------------------
// 10. L'article défini, élidé quand il doit l'être. Écrire
// `L'${libelle.toLowerCase()}` produit « L'médical » : l'élision dépend de la
// PREMIÈRE LETTRE, pas du fait qu'on ait affaire à un nom de marché.
// ---------------------------------------------------------------------
export function avecArticle(libelle) {
  const l = String(libelle || "").toLowerCase();
  return /^[aeiouyâàéèêëîïôöûü]|^h/.test(l) ? `L'${l}` : `Le ${l}`;
}

// ---------------------------------------------------------------------
// 11. AVANCE, PRÉSENT, CONFIRMATION — la distinction la plus utile du métier.
//
// Un indicateur avancé annonce, un coïncident constate, un retardé confirme.
// Les mélanger dans une même moyenne est une erreur de catégorie : l'avancé
// est neutralisé par le retardé au moment précis où il servirait.
//
// Le dispositif porte cet attribut en base depuis l'origine et ne s'en
// servait nulle part. C'est lui qui révèle que l'horlogerie et l'automobile
// — les deux marchés historiques de l'entreprise — étaient suivis sans
// aucun signal d'avance.
// ---------------------------------------------------------------------
export function compositionLatence(D, ids) {
  const ref = D?.referentiel || [];
  const c = { avance: 0, coincident: 0, retarde: 0, inconnue: 0 };
  for (const id of ids || []) {
    const l = ref.find(r => r.indicator_id === id)?.latence;
    if (l === "avance" || l === "coincident" || l === "retarde") c[l]++;
    else c.inconnue++;
  }
  return c;
}

export function phraseComposition(c) {
  const bouts = [];
  if (c.avance) bouts.push(`${enLettres(c.avance)} qui annonce${c.avance > 1 ? "nt" : ""}`);
  if (c.coincident) bouts.push(`${enLettres(c.coincident)} qui constate${c.coincident > 1 ? "nt" : ""}`);
  if (c.retarde) bouts.push(`${enLettres(c.retarde)} qui confirme${c.retarde > 1 ? "nt" : ""}`);
  return bouts.join(" · ");
}

// ---------------------------------------------------------------------
// 12. CE QUI A CHANGÉ — la question qu'on pose vraiment à un dispositif de
// veille, et à laquelle l'écran ne répondait pas.
// ---------------------------------------------------------------------
export function phraseEcart(e, libelle) {
  if (!e || e.ecart === null || e.ecart === undefined) return null;
  const d = Number(e.ecart);
  if (Math.abs(d) < 0.1) return `${libelle} : inchangé`;
  const sens = d > 0 ? "remonte" : "recule";
  return `${libelle} ${sens} de ${nb(Math.abs(d), 2)} point${Math.abs(d) >= 2 ? "s" : ""}`;
}

// Un indicateur qui gagne des périodes est une information : la source a
// publié. Un indicateur qui n'en gagne aucune depuis longtemps en est une
// autre, et moins bonne.
export function phraseNouveaute(n) {
  if (n.entierement_nouveau)
    return `${n.label} entre au registre — ${n.periodes_maintenant} périodes, jusqu'à ${n.periode_maintenant}`;
  if (n.periode_maintenant !== n.periode_avant)
    return `${n.label} avance jusqu'à ${n.periode_maintenant}`;
  return `${n.label} s'approfondit — ${n.periodes_gagnees} périodes de plus`;
}

// ---------------------------------------------------------------------
// 13. Fraîcheur de la DONNÉE, distincte de la fraîcheur de la COLLECTE.
// « Collecté il y a deux heures » se lit comme « information fraîche » ; si
// le point le plus récent date de juillet, c'est faux. Un veilleur distingue
// toujours quand il a regardé de la date de ce qu'il regarde.
// ---------------------------------------------------------------------
export function phrasePeriode(p) {
  if (!p) return "période inconnue";
  const MOIS = ["janvier","février","mars","avril","mai","juin","juillet",
                "août","septembre","octobre","novembre","décembre"];
  const m = String(p).match(/^(\d{4})-(\d{2})$/);
  if (m) return `${MOIS[Number(m[2]) - 1]} ${m[1]}`;
  const t = String(p).match(/^(\d{4})-T([1-4])$/);
  if (t) return `${t[2]}ᵉ trimestre ${t[1]}`;
  return String(p);
}

// ---------------------------------------------------------------------
// 14. Vieillissement des faits. Un fait dont l'échéance est à neuf ans n'est
// pas une actualité : c'est du contexte durable, et il doit se présenter
// comme tel plutôt que d'occuper indéfiniment un écran nommé « Ce matin ».
// ---------------------------------------------------------------------
export function natureDuFait(s) {
  const an = (txt) => { const m = String(txt || "").match(/(20\d{2})/); return m ? Number(m[1]) : null; };
  const echeance = an(s.echeance);
  const anneeCourante = new Date().getFullYear();
  if (echeance && echeance - anneeCourante >= 3) return "contexte durable";
  const j = s.validated_at ? (Date.now() - new Date(s.validated_at)) / 86400000 : null;
  if (j !== null && j <= 30) return "récent";
  return "établi";
}
