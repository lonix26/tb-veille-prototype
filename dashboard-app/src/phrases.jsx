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
//
// Revue du 02.09.2026 : les sections 1, 2, 4, 7, 8, 10, 12 et 14 (état du
// marché, direction longue, variation, brief, mouvement, article, écart et
// nouveauté, nature du fait) n'avaient plus aucun appelant après la refonte
// de l'accueil du 28.08 ; elles sont retirées, l'historique git les garde.
// La numérotation des sections restantes est conservée pour les renvois.
// =====================================================================
import { nb } from "./api.jsx";

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
  // 02.09.2026 (A10, vu sur capture) : « dans 1 semaines » — accord du pluriel.
  if (j <= 31) { const s = Math.round(j / 7); return `dans ${s} semaine${s > 1 ? "s" : ""}`; }
  return `dans ${Math.round(j / 30)} mois`;
}

export function tonEcheance(jours) {
  if (jours === null || jours === undefined) return "gris";
  if (jours <= 7) return "rouge";
  if (jours <= 21) return "ambre";
  return "gris";
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
  const s = Math.round(j / 7);
  return `dernière collecte il y a ${s} semaine${s > 1 ? "s" : ""}`;
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
// 9. Nombres écrits en toutes lettres jusqu'à seize — un texte destiné à
//    être lu, pas parcouru, écrit « quatre marchés » et non « 4 marchés ».
// ---------------------------------------------------------------------
const LETTRES = ["zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit",
                 "neuf", "dix", "onze", "douze", "treize", "quatorze", "quinze", "seize"];
export const enLettres = n =>
  Number.isInteger(n) && n >= 0 && n <= 16 ? LETTRES[n] : nb(n);

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
