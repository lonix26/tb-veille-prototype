#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Étage 2 — collecte des flux de la vague A (TED, GDELT, marchés financiers).

Conception : prototype/CONCEPTION_ETAGE2.md. Écrit le 23.08.2026, NON EXÉCUTÉ.

Usage (session terminal, depuis prototype/etage2/) :
    python3 collecte_flux.py                 # collecte → staging JSONL + pièces brutes (E6)
    python3 collecte_flux.py --flux ted_medical gdelt_horlogerie   # sous-ensemble
    python3 collecte_flux.py --charger       # charge le staging en base (flux_sources + flux_items)

Doctrine :
  - La collecte est du CODE : aucune IA ici. Le triage IA vient après (triage_ia_flux.py),
    l'examen humain après encore (flux_examens).
  - Chaque réponse brute est déposée en staging (.raw.json) AVANT toute transformation — E6.
  - flux_items est en ajout seul, dédupliqué par empreinte sha256 : recollecter est sûr.
  - Les détails d'API (formats TED/GDELT/Stooq, symboles) datent du 23.08.2026 : à vérifier
    en réponse réelle ; un flux ne passe 'actif' qu'après vue humaine (chk_flux_qualifie_trace).

Dépendances : requests ; psycopg2-binary pour --charger.
Connexion base (--charger) : variables POSTGRES_DB/USER/PASSWORD (cf. prototype/.env),
hôte localhost:5432 par défaut (adapter PGHOST/PGPORT si besoin).
"""

import argparse
import csv
import datetime as dt
import hashlib
import io
import json
import os
import sys
import time
from pathlib import Path

import requests

ICI = Path(__file__).resolve().parent
STAGING = ICI.parent / "data" / "staging_flux"
CONFIG = ICI / "flux_vague_A.json"
TIMEOUT = 60
AGENT = "veille-TB-HEG-Arc/1.0 (travail de bachelor, usage academique)"
PAUSE_INTER_FLUX = 6  # secondes entre deux flux (limite de cadence GDELT)
AUJOURDHUI = dt.date.today()


def empreinte(*parts):
    return hashlib.sha256("|".join(str(p) for p in parts).encode()).hexdigest()


def deposer_brut(flux_id, contenu, extension="raw.json"):
    STAGING.mkdir(parents=True, exist_ok=True)
    chemin = STAGING / f"{flux_id}_{AUJOURDHUI.isoformat()}.{extension}"
    chemin.write_text(contenu if isinstance(contenu, str) else json.dumps(contenu, ensure_ascii=False, indent=2))
    return str(chemin.relative_to(ICI.parent))


# --- Collecteurs par famille --------------------------------------------------
# Chacun renvoie une liste d'items : {date_publication, titre, url, payload, empreinte}

def collecte_ted(flux):
    """API de recherche TED v3 — POST JSON, sans clé (vérifiée le 20.08.2026 pour le décompte M7).
    Le format de la LISTE d'avis (champs disponibles) est à vérifier en réponse réelle."""
    p = flux["parametres"]
    debut = (AUJOURDHUI - dt.timedelta(days=p["fenetre_jours"])).strftime("%Y%m%d")
    fin = AUJOURDHUI.strftime("%Y%m%d")
    corps = {
        "query": f"classification-cpv IN ({p['cpv']}) AND publication-date >= {debut} AND publication-date < {fin}",
        "limit": p.get("limite", 50),
        "fields": ["publication-number", "notice-title", "publication-date", "buyer-name"],
    }
    r = requests.post(flux["url_base"], json=corps, timeout=TIMEOUT)
    r.raise_for_status()
    brut = r.json()
    raw_ref = deposer_brut(flux["flux_id"], {"requete": corps, "reponse": brut})
    items = []
    for avis in brut.get("notices", []):
        num = avis.get("publication-number", "")
        titre = avis.get("notice-title", "")
        if isinstance(titre, dict):
            # Multilingue. CORRECTION DU 23.08.2026, vérifiée en réponse réelle : la clé
            # de langue française est « fra » (ISO 639-2/T), pas « fre ». Avec « fre », le
            # code retombait silencieusement sur l'anglais — non bloquant, mais la file de
            # lecture du veilleur et le triage doivent être en français.
            titre = titre.get("fra") or titre.get("eng") or next(iter(titre.values()), "")
        items.append({
            "date_publication": str(avis.get("publication-date", ""))[:10] or None,
            "titre": f"[TED {num}] {titre}"[:500],
            "url": f"https://ted.europa.eu/fr/notice/-/detail/{num}" if num else None,
            "payload": avis,
            "empreinte": empreinte(flux["flux_id"], num),
            "raw_ref": raw_ref,
        })
    return items


def collecte_gdelt(flux):
    """GDELT DOC 2.0 — GET, sans clé, format JSON. Couverture mondiale, latence ~15 min."""
    p = flux["parametres"]
    params = {"query": p["requete"], "mode": "ArtList", "format": "json",
              "maxrecords": p.get("limite", 50), "timespan": p.get("fenetre", "7d")}
    # CORRECTION DU 23.08.2026, constatée en réponse réelle : GDELT limite la cadence
    # (« Please limit requests to one every 5 seconds ») et renvoie 429 en texte brut, pas
    # en JSON. Une fois freiné, il faut attendre nettement plus que 5 s — 15 s suffisent.
    # Sans ce rejeu, les quatre flux GDELT échouaient tous.
    # Paliers progressifs : constaté le 23.08 que 3 tentatives à 15 s ne suffisent pas
    # une fois la limite atteinte — GDELT impose une accalmie plus longue que les 5 s
    # annoncées par son propre message.
    # Le refus de cadence de GDELT arrive sous DEUX formes, constatées le 23.08 :
    # un 429, et — plus traître — un HTTP 200 dont le corps est le message en clair
    # « Please limit requests to one every 5 seconds ». Ne tester que le code de statut
    # laissait passer la seconde forme : json() échouait sur « Expecting value », et le
    # flux était classé en échec de format alors qu'il s'agissait d'une cadence.
    attentes = (20, 40, 60, 90)
    for tentative, attente in enumerate(attentes, 1):
        r = requests.get(flux["url_base"], params=params, timeout=TIMEOUT)
        freine = r.status_code == 429 or not r.text.lstrip().startswith("{")
        if not freine:
            break
        print(f"    cadence GDELT (HTTP {r.status_code}), attente {attente} s "
              f"(tentative {tentative}/{len(attentes)})")
        time.sleep(attente)
    r.raise_for_status()
    brut = r.json()
    raw_ref = deposer_brut(flux["flux_id"], {"requete": params, "reponse": brut})
    items = []
    for art in brut.get("articles", []):
        url = art.get("url", "")
        date = (art.get("seendate", "") or "")[:8]
        items.append({
            "date_publication": f"{date[:4]}-{date[4:6]}-{date[6:8]}" if len(date) == 8 else None,
            "titre": (art.get("title") or "(sans titre)")[:500],
            "url": url,
            "payload": {k: art.get(k) for k in ("title", "url", "domain", "language", "seendate", "sourcecountry")},
            "empreinte": empreinte(flux["flux_id"], url),
            "raw_ref": raw_ref,
        })
    return items


def collecte_marches(flux):
    """Cours quotidiens (export CSV Stooq). AUCUNE IA : le collecteur n'émet un item QUE
    si la variation sur la fenêtre dépasse le seuil déclaré — l'événement est calculé.
    Symboles à vérifier ; un symbole muet est journalisé, jamais bloquant."""
    p = flux["parametres"]
    items = []
    for ticker in p["tickers"]:
        try:
            r = requests.get(flux["url_base"], params={"s": ticker, "i": "d"}, timeout=TIMEOUT)
            r.raise_for_status()
            lignes = list(csv.DictReader(io.StringIO(r.text)))
        except Exception as exc:
            print(f"    {ticker} : échec ({exc}) — à vérifier (symbole ? réseau ?)")
            continue
        if len(lignes) < p["fenetre_seances"] + 1 or "Close" not in (lignes[0] or {}):
            print(f"    {ticker} : réponse sans série exploitable — symbole à vérifier")
            continue
        raw_ref = deposer_brut(f"{flux['flux_id']}_{ticker}", r.text, "raw.csv")
        derniers = lignes[-(p["fenetre_seances"] + 1):]
        try:
            avant, apres = float(derniers[0]["Close"]), float(derniers[-1]["Close"])
        except (ValueError, KeyError):
            print(f"    {ticker} : clôtures non numériques — à vérifier")
            continue
        variation = (apres / avant - 1) * 100
        if abs(variation) >= p["seuil_variation_pct"]:
            date_fin = derniers[-1].get("Date", AUJOURDHUI.isoformat())
            items.append({
                "date_publication": date_fin,
                "titre": f"{ticker.upper()} : {variation:+.1f} % sur {p['fenetre_seances']} séances"
                         f" ({avant:.2f} → {apres:.2f})",
                "url": f"https://stooq.com/q/?s={ticker}",
                "payload": {"ticker": ticker, "variation_pct": round(variation, 2),
                            "cloture_debut": avant, "cloture_fin": apres,
                            "fenetre": p["fenetre_seances"], "seuil": p["seuil_variation_pct"]},
                "empreinte": empreinte(flux["flux_id"], ticker, date_fin),
                "raw_ref": raw_ref,
            })
        else:
            print(f"    {ticker} : {variation:+.1f} % — sous le seuil, aucun item (comportement attendu)")
    return items



def collecte_rss(flux):
    """Communications des donneurs d'ordre (famille F2 du protocole OSINT) — fil RSS.

    Vérifié le 23.08.2026 : Boeing sert un vrai fil de communiqués. Airbus a été écarté à
    la reconnaissance — son /rss.xml ne sert que la navigation du site (« Environment »,
    « Society »), pas les communiqués : un flux qui répond 200 n'est pas pour autant un flux
    exploitable, et c'est le genre de vérification qui ne se délègue pas au code.
    """
    import xml.etree.ElementTree as ET
    r = requests.get(flux["url_base"], headers={"User-Agent": AGENT}, timeout=TIMEOUT)
    r.raise_for_status()
    raw_ref = deposer_brut(flux["flux_id"], r.text, "raw.xml")
    racine = ET.fromstring(r.text)
    items = []
    for it in racine.iter("item"):
        titre = (it.findtext("title") or "").strip()
        lien = (it.findtext("link") or "").strip()
        pub = (it.findtext("pubDate") or "").strip()
        date = None
        if pub:
            try:
                from email.utils import parsedate_to_datetime
                date = parsedate_to_datetime(pub).date().isoformat()
            except Exception:
                date = None
        if not titre:
            continue
        items.append({
            "date_publication": date,
            "titre": titre[:500],
            "url": lien or None,
            "payload": {"titre": titre, "lien": lien, "pubDate": pub,
                        "description": (it.findtext("description") or "")[:2000]},
            "empreinte": empreinte(flux["flux_id"], lien or titre),
            "raw_ref": raw_ref,
        })
    return items


def collecte_openfda(flux):
    """Actes réglementaires (famille « reglementaire ») — API openFDA, libre et sans clé.

    C'est de l'amont au sens strict : une autorisation de mise sur le marché précède la
    montée en cadence de production, donc la charge d'usinage, donc toute statistique.

    PIÈGE D'ENCODAGE, constaté le 23.08.2026 : la syntaxe d'intervalle d'openFDA est
    `champ:[debut+TO+fin]`. Passée par le paramètre `params` de requests, le `+` est encodé
    en `%2B` et l'API répond 500 SERVER_ERROR — diagnostic trompeur, qui ressemble à une
    panne du service. L'URL est donc construite à la main, à dessein.
    """
    p = flux["parametres"]
    fin = AUJOURDHUI.strftime("%Y%m%d")
    debut = (AUJOURDHUI - dt.timedelta(days=p["fenetre_jours"])).strftime("%Y%m%d")
    url = (f"{flux['url_base']}?search={p['champ_date']}:[{debut}+TO+{fin}]"
           f"&limit={p.get('limite', 50)}")
    r = requests.get(url, headers={"User-Agent": AGENT}, timeout=TIMEOUT)
    # openFDA répond 404 quand la recherche ne ramène RIEN — ce n'est pas une panne, et le
    # traiter comme telle ferait passer une fenêtre vide pour un flux défaillant. Constaté
    # le 23.08.2026 sur une fenêtre de 7 jours du 510(k), vide car les décisions sont
    # publiées avec retard.
    if r.status_code == 404:
        print("    aucun résultat sur la fenêtre (404 openFDA = recherche vide, pas une panne)")
        deposer_brut(flux["flux_id"], {"url": url, "reponse_vide": r.json() if r.text.strip().startswith("{") else r.text[:500]})
        return []
    r.raise_for_status()
    brut = r.json()
    raw_ref = deposer_brut(flux["flux_id"], {"url": url, "reponse": brut})
    def date_iso(brute):
        """openFDA sert ses dates tantôt en AAAAMMJJ, tantôt en AAAA-MM-JJ selon le point
        d'accès. Normaliser sur les chiffres évite de découper une chaîne déjà ponctuée —
        ce qui produisait « 2026--0-8- » et faisait échouer tout le chargement sur un
        « datestyle » incompréhensible (constaté le 23.08.2026)."""
        chiffres = "".join(ch for ch in str(brute or "") if ch.isdigit())
        return f"{chiffres[:4]}-{chiffres[4:6]}-{chiffres[6:8]}" if len(chiffres) >= 8 else None

    items = []
    for res in brut.get("results", []):
        ident = res.get(p["champ_id"], "")
        libelle = res.get(p["champ_libelle"], "") or ""
        acteur = res.get(p.get("champ_acteur", ""), "") or ""
        titre = f"[{p['prefixe']} {ident}] {libelle}" + (f" — {acteur}" if acteur else "")
        items.append({
            "date_publication": date_iso(res.get(p["champ_date"])),
            "titre": titre[:500],
            "url": p.get("url_detail", "").format(ident=ident) or None,
            "payload": res,
            "empreinte": empreinte(flux["flux_id"], ident),
            "raw_ref": raw_ref,
        })
    return items


COLLECTEURS = {"marches_publics": collecte_ted, "actualite": collecte_gdelt,
               "marches_financiers": collecte_marches,
               "communications": collecte_rss, "reglementaire": collecte_openfda}


def charger_en_base(config):
    import psycopg2  # dépendance de --charger uniquement
    conn = psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))
    inseres = doublons = 0
    with conn, conn.cursor() as cur:
        for flux in config["flux"]:
            cur.execute(
                """INSERT INTO flux_sources (flux_id, famille, sector_code, libelle, url_base, parametres, note)
                   VALUES (%s,%s,%s,%s,%s,%s,'Semé par collecte_flux.py --charger (vague A) ; qualification humaine requise avant activation')
                   ON CONFLICT (flux_id) DO NOTHING""",
                (flux["flux_id"], flux["famille"], flux.get("sector_code"), flux["libelle"],
                 flux["url_base"], json.dumps(flux["parametres"])))
        for chemin in sorted(STAGING.glob("*.items.jsonl")):
            for ligne in chemin.read_text().splitlines():
                it = json.loads(ligne)
                cur.execute(
                    """INSERT INTO flux_items (flux_id, date_publication, titre, url, payload, empreinte, raw_ref)
                       VALUES (%s,%s,%s,%s,%s,%s,%s) ON CONFLICT (empreinte) DO NOTHING""",
                    (it["flux_id"], it["date_publication"] or None, it["titre"], it["url"],
                     json.dumps(it["payload"], ensure_ascii=False), it["empreinte"], it["raw_ref"]))
                inseres += cur.rowcount
                doublons += (1 - cur.rowcount)
    print(f"Chargement : {inseres} items insérés, {doublons} doublons ignorés (déduplication par empreinte).")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flux", nargs="*", help="restreindre à certains flux_id")
    ap.add_argument("--charger", action="store_true", help="charger le staging en base")
    args = ap.parse_args()
    config = json.loads(CONFIG.read_text())
    if args.charger:
        charger_en_base(config)
        return
    for flux in config["flux"]:
        if args.flux and flux["flux_id"] not in args.flux:
            continue
        print(f"{flux['flux_id']} ({flux['famille']})")
        try:
            items = COLLECTEURS[flux["famille"]](flux)
        except Exception as exc:
            print(f"    ÉCHEC : {exc} — flux à vérifier, la collecte continue")
            continue
        for it in items:
            it["flux_id"] = flux["flux_id"]
        STAGING.mkdir(parents=True, exist_ok=True)
        sortie = STAGING / f"{flux['flux_id']}_{AUJOURDHUI.isoformat()}.items.jsonl"
        sortie.write_text("\n".join(json.dumps(it, ensure_ascii=False) for it in items))
        print(f"    {len(items)} items → {sortie.name}")
        time.sleep(PAUSE_INTER_FLUX)  # courtoisie : voir la limite de cadence GDELT


if __name__ == "__main__":
    main()
