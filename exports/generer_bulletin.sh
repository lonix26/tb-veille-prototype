#!/usr/bin/env bash
# =====================================================================
# BULLETIN HEBDOMADAIRE — le produit du dispositif, sur une page.
#
# La veille professionnelle diffuse en PUSH : un bulletin qui arrive,
# pas un écran qu'il faut penser à ouvrir. Ce script produit la note
# qu'un dirigeant lit le lundi matin, entièrement PAR REQUÊTE sur
# l'interface de lecture — rien n'est rédigé à la main, tout est daté,
# et le relancer la semaine suivante produit le bulletin suivant.
#
#   bash exports/generer_bulletin.sh > bulletin_$(date +%F).md
# =====================================================================
set -eu
API="${API_BASE:-http://localhost:5678/webhook/veille}"

python3 - "$API" <<'PY'
import json, sys, urllib.request
from datetime import date

API = sys.argv[1]
def lire(p):
    with urllib.request.urlopen(API + p, timeout=30) as r:
        return json.load(r)

S = lire("/sante"); A = lire("/actions"); D = lire("/donnees"); G = lire("/signaux")

MOIS = ["janvier","février","mars","avril","mai","juin","juillet","août",
        "septembre","octobre","novembre","décembre"]
def periode(p):
    p = str(p or "")
    # Le trimestre se teste AVANT le mensuel : « 2026-T3 » a aussi sept
    # caractères et un tiret en quatrième position.
    if "-T" in p:
        a, _, t = p.partition("-T")
        return f"{t}ᵉ trimestre {a}"
    if len(p) == 7 and p[4] == "-": return f"{MOIS[int(p[5:7])-1]} {p[:4]}"
    return p
def pct(v, d=1):
    if v is None: return "—"
    v = float(v)
    return f"{'+' if v > 0 else ''}{v:.{d}f} %".replace(".", ",")
def nb(v):
    if v is None: return "—"
    v = float(v)
    return f"{v:,.0f}".replace(",", " ") if abs(v) >= 1000 else (f"{v:.1f}".rstrip("0").rstrip(".").replace(".", ","))

ROLE = {"avance": "ANNONCE", "coincident": "constate", "retarde": "confirme"}
SECT = {"transversal": "Votre métier et votre marge", "horlogerie": "Horlogerie",
        "medical": "Médical", "automobile": "Automobile", "aerospatial": "Aérospatial"}

aujourdhui = date.today().strftime("%d.%m.%Y")
run = S.get("run_courant") or {}
print(f"# Note de veille hebdomadaire — {aujourdhui}")
print()
print(f"*Produite par requête sur le dispositif (collecte n° {run.get('run_id','—')}) — aucune ligne rédigée à la main. "
      f"Chaque chiffre est traçable jusqu'à sa source dans l'application.*")
print()

# ---------- 1. À décider ----------
urg = sorted([a for a in (A.get("actions") or []) if (a.get("adressable") or 0) >= 1
              and a.get("jours_restants") is not None],
             key=lambda a: a["jours_restants"])
print("## À décider cette semaine")
print()
if not urg:
    print("Aucun appel d'offres à votre portée n'est ouvert dans la fenêtre suivie.")
else:
    for a in urg[:5]:
        j = a["jours_restants"]
        ech = "AUJOURD'HUI" if j == 0 else ("demain" if j == 1 else f"dans {j} jours")
        print(f"- **{ech}** — {a.get('piece_concernee') or a.get('titre','')[:90]}")
        print(f"  {a.get('acheteur','')} ({a.get('acheteur_pays','')})"
              + (f" · {a.get('acheteur_courriel')}" if a.get('acheteur_courriel') else ""))
print()

# ---------- 2. Les chiffres ----------
print("## Ce que disent les chiffres")
print()
vit = S.get("vitrine") or []
for code, nom in SECT.items():
    lignes = [v for v in vit if v["sector_code"] == code]
    if not lignes: continue
    print(f"**{nom}**")
    for v in sorted(lignes, key=lambda x: (x.get("latence") != "avance", x["indicator_id"])):
        var = v.get("variation_periode_pct"); ecart = v.get("ecart_a_la_moyenne_pct")
        pos = ""
        if ecart is not None and abs(float(ecart)) >= 3:
            pos = f" · {pct(ecart)} vs sa moyenne"
        print(f"- {ROLE.get(v.get('latence'),'—'):8s} {v['label']} : "
              f"**{nb(v.get('value'))} {v.get('unit','')}** ({periode(v.get('period'))}, {pct(var)}{pos})")
    print()

# ---------- 3. Où les marchés se déplacent (H1) ----------
pts = [x for x in (D.get("valeurs") or []) if x["indicator_id"] == "H1"
       and not str(x["geo"]).startswith(("S", "X", "F")) and x["geo"] not in ("W00", "WORLD", "EU27", "CH")]
if pts:
    par = {}
    for x in pts: par.setdefault(x["geo"], {})[x["period"]] = float(x["value"])
    dern = max(p for g in par.values() for p in g)
    avant = f"{int(dern[:4])-1}{dern[4:]}"
    tot = sum(g.get(dern, 0) for g in par.values()); totp = sum(g.get(avant, 0) for g in par.values())
    mv = []
    for g, s_ in par.items():
        if dern in s_ and avant in s_ and tot and totp:
            mv.append((g, s_[dern]/tot*100 - s_[avant]/totp*100))
    mv.sort(key=lambda t: -t[1])
    NOMS = {"FRA":"France","USA":"États-Unis","CHN":"Chine","HKG":"Hong Kong","JPN":"Japon",
            "GBR":"Royaume-Uni","DEU":"Allemagne","ITA":"Italie","ESP":"Espagne","SGP":"Singapour",
            "ARE":"Émirats","KOR":"Corée du Sud","MEX":"Mexique","IND":"Inde","IDN":"Indonésie"}
    n = lambda g: NOMS.get(g, g)
    print("## Où le marché horloger se déplace (parts de destination, sur un an)")
    print()
    gagn = [f"{n(g)} {'+' if d>0 else ''}{d:.1f} pt".replace(".", ",") for g, d in mv[:3] if d > 0.05]
    perd = [f"{n(g)} {d:.1f} pt".replace(".", ",") for g, d in mv[::-1][:3] if d < -0.05]
    if gagn: print(f"- Gagnent du terrain : **{' · '.join(gagn)}**")
    if perd: print(f"- Cèdent du terrain : **{' · '.join(perd)}**")
    print()

# ---------- 4. Les signaux ----------
file_ = S.get("file_prioritaire") or []
print("## Dix items de veille à examiner (les mieux notés par le triage)")
print()
for i, it in enumerate(file_[:10], 1):
    print(f"{i}. {it.get('titre','')[:110]}")
    if it.get("resume"): print(f"   — {it['resume'][:140]}")
print()

faits = G.get("signaux") or []
if faits:
    print("## Faits validés au registre")
    print()
    for s_ in faits[:4]:
        print(f"- **[{s_.get('sector_label','')}]** {s_.get('evenement','')[:170]}")
    print()

# ---------- 5. Ce qui attend ----------
av = S.get("commentaires_en_attente") or 0
ax = S.get("items_en_attente_examen") or 0
print("## En attente de votre lecture")
print()
print(f"- {av} lecture(s) rédigée(s) par modèle à valider — rien n'est diffusé sans validation")
print(f"- {ax} items de veille en file (traiter les dix ci-dessus suffit à tenir le dispositif)")
print()
print("---")
print(f"*Sources ouvertes uniquement · registre en ajout seul · {aujourdhui}. "
      "Relancer `bash exports/generer_bulletin.sh` produit la note de la semaine suivante.*")
PY
