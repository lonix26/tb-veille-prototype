#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Collecte enrichie des avis TED — rendre la restitution actionnable.

Écrit le 24.08.2026. La collecte de l'étage 2 ne demandait que cinq champs à TED.
L'API en expose 1832. Quatre changent la nature de ce qu'on peut montrer :

    notice-type                       appel OUVERT (cn-*) ou ATTRIBUTION (can-*)
    deadline-receipt-tender-date-lot  date limite de dépôt
    buyer-email / buyer-internet-address   l'interlocuteur
    estimated-value-lot               l'ordre de grandeur

Sans le premier, on présente comme prospect un marché déjà attribué. Sans le
deuxième, on ne sait pas si l'on peut encore agir. Sans le troisième, il n'y a
personne à contacter. Sans le quatrième, on ne sait pas si cela vaut le
déplacement.

Écrit dans `ted_avis` (table dédiée) et non dans flux_items, qui est en ajout
seul et dédupliqué : une recollecte enrichie y serait rejetée comme doublon.

Usage :
    python3 collecte_ted_enrichi.py                 # les CPV des flux TED déclarés
    python3 collecte_ted_enrichi.py --jours 60
"""

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path

import psycopg2
import requests

AGENT = "veille-TB-HEG-Arc/1.0 (travail de bachelor, usage academique)"
URL = "https://api.ted.europa.eu/v3/notices/search"
BRUT = Path(__file__).resolve().parent.parent / "data" / "ted_enrichi"
TIMEOUT = 120

CHAMPS = ["publication-number", "notice-title", "publication-date", "notice-type",
          "buyer-name", "buyer-country", "buyer-city", "buyer-email",
          "buyer-internet-address", "deadline-receipt-tender-date-lot",
          "estimated-value-lot", "estimated-value-cur-lot",
          "classification-cpv", "contract-nature"]


def txt(v, langues=("fra", "eng", "deu", "mul")):
    """TED rend beaucoup de champs en dictionnaire de langues ou en liste."""
    if v is None:
        return None
    if isinstance(v, str):
        return v
    if isinstance(v, list):
        return txt(v[0]) if v else None
    if isinstance(v, dict):
        for lg in langues:
            if v.get(lg):
                return txt(v[lg])
        for x in v.values():
            r = txt(x)
            if r:
                return r
    return str(v)


def date_de(v):
    s = txt(v)
    return s[:10] if s and len(s) >= 10 else None


def nombre(v):
    s = txt(v)
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def collecter(cpv, jours, flux_id, secteur, cur):
    fin = dt.date.today()
    debut = fin - dt.timedelta(days=jours)
    corps = {"query": f"classification-cpv IN ({cpv}) AND publication-date >= "
                      f"{debut:%Y%m%d} AND publication-date <= {fin:%Y%m%d}",
             "limit": 250, "fields": CHAMPS}
    r = requests.post(URL, json=corps, headers={"User-Agent": AGENT}, timeout=TIMEOUT)
    r.raise_for_status()
    brut = r.json()
    BRUT.mkdir(parents=True, exist_ok=True)
    chemin = BRUT / f"{flux_id}_{fin.isoformat()}.raw.json"
    chemin.write_text(json.dumps({"requete": corps, "reponse": brut}, ensure_ascii=False, indent=2))
    raw_ref = str(chemin.relative_to(BRUT.parent.parent))

    ecrits = 0
    for a in brut.get("notices", []):
        num = a.get("publication-number")
        if not num:
            continue
        ntype = txt(a.get("notice-type")) or ""
        # cn-* = appel à candidature ; can-* = avis d'ATTRIBUTION, déjà décidé.
        ouvert = ntype.startswith("cn")
        cpvs = a.get("classification-cpv") or []
        cpvs = sorted({str(c) for c in cpvs}) if isinstance(cpvs, list) else None
        cur.execute("""
            INSERT INTO ted_avis (publication_number, item_id, flux_id, sector_code,
                notice_type, est_appel_ouvert, date_publication, date_limite, titre,
                acheteur, acheteur_pays, acheteur_ville, acheteur_courriel, acheteur_site,
                valeur_estimee, devise, cpv, nature_contrat, url, raw_ref)
            VALUES (%s,
                    (SELECT item_id FROM flux_items WHERE titre LIKE %s LIMIT 1),
                    %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (publication_number) DO UPDATE SET
                notice_type = EXCLUDED.notice_type,
                est_appel_ouvert = EXCLUDED.est_appel_ouvert,
                date_limite = EXCLUDED.date_limite,
                acheteur_courriel = EXCLUDED.acheteur_courriel,
                valeur_estimee = EXCLUDED.valeur_estimee,
                collecte_le = now()""",
            (num, f"[TED {num}]%", flux_id, secteur, ntype, ouvert,
             date_de(a.get("publication-date")),
             date_de(a.get("deadline-receipt-tender-date-lot")),
             (txt(a.get("notice-title")) or "")[:600],
             txt(a.get("buyer-name")), txt(a.get("buyer-country")), txt(a.get("buyer-city")),
             txt(a.get("buyer-email")), txt(a.get("buyer-internet-address")),
             nombre(a.get("estimated-value-lot")), txt(a.get("estimated-value-cur-lot")),
             cpvs, txt(a.get("contract-nature")),
             f"https://ted.europa.eu/fr/notice/-/detail/{num}", raw_ref))
        ecrits += 1
    return ecrits, brut.get("totalNoticeCount")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jours", type=int, default=60,
                    help="profondeur de collecte. 60 par défaut : un appel d'offres court "
                         "typiquement 30 à 45 jours, une fenêtre plus étroite manquerait des "
                         "appels encore ouverts publiés le mois précédent.")
    args = ap.parse_args()

    conn = psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))
    with conn, conn.cursor() as cur:
        cur.execute("""SELECT flux_id, sector_code, parametres->>'cpv'
                       FROM flux_sources WHERE famille='marches_publics'
                       ORDER BY flux_id""")
        flux = cur.fetchall()

    total = 0
    for flux_id, secteur, cpv in flux:
        if not cpv:
            continue
        try:
            with conn, conn.cursor() as cur:
                n, dispo = collecter(cpv, args.jours, flux_id, secteur, cur)
            print(f"  {flux_id:<20} CPV {cpv:<34} {n} avis écrits (sur {dispo} disponibles)")
            total += n
        except Exception as exc:
            print(f"  {flux_id:<20} ÉCHEC : {exc}")
    conn.close()
    print(f"\n{total} avis enrichis en base.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
