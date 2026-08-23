#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Collecte des indicateurs de comptage M8 (openFDA 510(k)) et S7 (TED CPV 347).

Écrit le 23.08.2026. Même doctrine que le reste de l'étage 1 : la collecte est du CODE,
chaque valeur porte son run, son statut et sa pièce brute (E6). Aucune IA ici — compter
est un calcul.

Usage (depuis prototype/etage2/, base démarrée) :
    python3 collecte_comptages.py --depuis 2025-09 --jusqu 2026-07
"""

import argparse
import calendar
import datetime as dt
import json
import os
import sys
from pathlib import Path

import psycopg2
import requests

AGENT = "veille-TB-HEG-Arc/1.0 (travail de bachelor, usage academique)"
BRUT = Path(__file__).resolve().parent.parent / "data" / "comptages"
TIMEOUT = 90


def mois_entre(debut, fin):
    a, m = map(int, debut.split("-")); af, mf = map(int, fin.split("-"))
    while (a, m) <= (af, mf):
        yield a, m
        m += 1
        if m == 13: a, m = a + 1, 1


def bornes(a, m):
    return f"{a}{m:02d}01", f"{a}{m:02d}{calendar.monthrange(a, m)[1]:02d}"


def deposer(nom, contenu):
    BRUT.mkdir(parents=True, exist_ok=True)
    c = BRUT / f"{nom}.json"
    c.write_text(json.dumps(contenu, ensure_ascii=False, indent=2))
    return str(c.relative_to(BRUT.parent.parent))


def compter_m8(a, m):
    """openFDA : somme des occurrences quotidiennes. Le + de +TO+ ne doit pas être encodé."""
    d, f = bornes(a, m)
    url = (f"https://api.fda.gov/device/510k.json?search=decision_date:[{d}+TO+{f}]"
           f"&count=decision_date")
    r = requests.get(url, headers={"User-Agent": AGENT}, timeout=TIMEOUT)
    if r.status_code == 404:      # recherche vide, pas une panne
        return 0, deposer(f"M8_{a}-{m:02d}", {"url": url, "resultat": "aucun (404 openFDA)"})
    r.raise_for_status()
    j = r.json()
    return (sum(x["count"] for x in j.get("results", [])),
            deposer(f"M8_{a}-{m:02d}", {"url": url, "reponse": j}))


def compter_s7(a, m):
    """TED : totalNoticeCount, méthode certifiée pour M7 le 20.08.2026."""
    d, f = bornes(a, m)
    corps = {"query": f"classification-cpv IN (34700000) AND publication-date >= {d} "
                      f"AND publication-date <= {f}",
             "limit": 1, "fields": ["publication-number"]}
    r = requests.post("https://api.ted.europa.eu/v3/notices/search", json=corps,
                      headers={"User-Agent": AGENT}, timeout=TIMEOUT)
    r.raise_for_status()
    j = r.json()
    return j.get("totalNoticeCount"), deposer(f"S7_{a}-{m:02d}", {"requete": corps, "reponse": j})


PLAN = {"M8": (compter_m8, "US"), "S7": (compter_s7, "EU")}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--depuis", default="2025-09")
    ap.add_argument("--jusqu", default="2026-07")
    args = ap.parse_args()

    conn = psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))
    with conn, conn.cursor() as cur:
        cur.execute("""INSERT INTO runs (trigger_type, scenario, status, note)
                       VALUES ('manual','B','en_cours','Comptages M8 (openFDA 510k) et S7 (TED CPV 347)')
                       RETURNING run_id""")
        run_id = cur.fetchone()[0]
    print(f"run {run_id} ouvert")

    ecrits = 0
    for ind, (fonction, geo) in PLAN.items():
        for a, m in mois_entre(args.depuis, args.jusqu):
            periode = f"{a}-{m:02d}"
            try:
                valeur, raw = fonction(a, m)
            except Exception as exc:
                print(f"  {ind} {periode} : ÉCHEC {exc}")
                continue
            if valeur is None:
                print(f"  {ind} {periode} : valeur absente, ignorée")
                continue
            with conn, conn.cursor() as cur:
                cur.execute("""INSERT INTO indicator_values
                    (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
                    VALUES (%s,%s,%s,%s,%s,'etl','valide_source',%s)
                    ON CONFLICT (indicator_id, run_id, period, geo) DO NOTHING""",
                    (ind, run_id, periode, geo, valeur, raw))
                ecrits += cur.rowcount
            print(f"  {ind} {periode} {geo} : {valeur}")

    with conn, conn.cursor() as cur:
        cur.execute("UPDATE runs SET status='ok' WHERE run_id=%s", (run_id,))
    conn.close()
    print(f"\n{ecrits} observations écrites sous le run {run_id}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
