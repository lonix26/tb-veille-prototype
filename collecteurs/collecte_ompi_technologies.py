#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Brevets par domaine technologique — OMPI. N. Castillo, 25.08.2026.

POURQUOI CETTE SOURCE, APRÈS L'ÉCHEC DU PORTAIL DE L'OEB.
L'interface Open Patent Services de l'Office européen des brevets aurait permis
la recherche par code de classification — donc l'horlogerie (CIB G04) et
l'aérospatial (B64) isolés. Son portail d'inscription n'a pas délivré de compte.
L'OMPI publie une alternative en accès direct, sans inscription : une archive
des comptages de brevets par domaine technologique, pays d'origine et année.

CE QUE CETTE SOURCE PERMET, ET CE QU'ELLE NE PERMET PAS — à dire ensemble.
L'OMPI classe en TRENTE-CINQ domaines, l'OEB en milliers de codes. La table de
concordance officielle, vérifiée le 25.08.2026, place :
  · la CIB G04 (horlogerie) dans le domaine 10, « Techniques de mesure »,
    noyée avec toute la métrologie — INEXPLOITABLE pour l'horlogerie seule ;
  · la CIB B64 (aéronefs et engins spatiaux) dans le domaine 32, « Transport »,
    avec l'automobile, le ferroviaire et le maritime — INEXPLOITABLE de même.
Les deux vides QV4 que l'OEB aurait comblés restent donc ouverts, et le dire
importe autant que de livrer ce qui suit.

CE QU'ELLE APPORTE QUE PERSONNE D'AUTRE NE DONNE ICI : les domaines qui sont
ceux du MÉTIER LUI-MÊME. Le domaine 21, « Technique de surface, revêtement »,
recouvre exactement la nomenclature d'activité du destinataire (NACE C25.6,
traitement et revêtement des métaux, usinage) ; le domaine 26, « Machines-outils »,
mesure la technologie de ses moyens de production. Aucune autre source de la
grille ne descend à cet étage.

PROFONDEUR : 23 points annuels, 2000 à 2022, pour la Suisse et 100 pays.

Usage :
    python3 collecte_ompi_technologies.py --essai
    python3 collecte_ompi_technologies.py
"""

import argparse
import csv
import io
import os
import sys
import zipfile

import psycopg2
import requests

ARCHIVE = "https://www.wipo.int/documents/d/ip-statistics/wipo-data-patent-indicators.zip"
FICHIER = "dc_indicator_patent_4_publication_by_technology.csv"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36"}
TIMEOUT = 300

# Le code d'office « ** » agrège tous les offices : ce sont les dépôts d'un pays
# d'origine PARTOUT dans le monde, et non ses dépôts chez lui. C'est la bonne
# lecture pour mesurer la vitalité technologique d'un écosystème.
OFFICE = "**"
ZONES = ["CH", "DE", "FR", "IT", "JP", "US", "CN"]

INDICATEURS = {
    "T12": ("21", "Technique de surface et revêtement"),
    "T13": ("26", "Machines-outils"),
}


def telecharger():
    r = requests.get(ARCHIVE, headers=UA, timeout=TIMEOUT)
    r.raise_for_status()
    if r.content[:2] != b"PK":
        raise RuntimeError("la réponse n'est pas une archive ZIP")
    z = zipfile.ZipFile(io.BytesIO(r.content))
    if FICHIER not in z.namelist():
        raise RuntimeError(f"{FICHIER} absent de l'archive — contenu : {z.namelist()}")
    return z.read(FICHIER).decode("utf-8", "replace"), len(r.content)


def extraire(texte):
    lignes = list(csv.DictReader(io.StringIO(texte)))
    attendues = {"year", "office", "origin", "tec_id", "count"}
    if not attendues.issubset(set(lignes[0].keys())):
        raise RuntimeError(f"colonnes inattendues : {list(lignes[0].keys())}")
    sortie = {}
    for code, (tec, _) in INDICATEURS.items():
        for l in lignes:
            if l["office"] != OFFICE or l["tec_id"] != tec or l["origin"] not in ZONES:
                continue
            try:
                v = float(l["count"])
            except (TypeError, ValueError):
                continue
            sortie.setdefault(code, []).append((l["year"], l["origin"], v))
    return sortie


def connexion():
    return psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--essai", action="store_true")
    args = ap.parse_args()

    texte, taille = telecharger()
    print(f"Archive : {taille} octets · {FICHIER}")
    series = extraire(texte)
    for code, (tec, lib) in INDICATEURS.items():
        pts = series.get(code, [])
        ans = sorted({a for a, _, _ in pts})
        ch = sorted([(a, v) for a, z, v in pts if z == "CH"])
        print(f"  {code} — domaine {tec} · {lib}")
        print(f"      {len(pts)} points, {len(ZONES)} zones, {ans[0]}→{ans[-1]}"
              f" · Suisse {ch[0][1]:.0f} ({ch[0][0]}) → {ch[-1][1]:.0f} ({ch[-1][0]})")

    if args.essai:
        print("\n(--essai : rien n'a été écrit)")
        return 0

    conn = connexion()
    with conn, conn.cursor() as cur:
        cur.execute("""INSERT INTO runs (trigger_type, scenario, status, note)
                       VALUES ('manual','B','en_cours','Collecteur OMPI — brevets par domaine technologique')
                       RETURNING run_id""")
        run_id = cur.fetchone()[0]
    ecrits = 0
    with conn, conn.cursor() as cur:
        for code, pts in series.items():
            for annee, zone, valeur in pts:
                cur.execute("""INSERT INTO indicator_values
                    (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
                    VALUES (%s,%s,%s,%s,%s,'etl','valide_source',%s)""",
                    (code, run_id, annee, zone, valeur, ARCHIVE))
                ecrits += cur.rowcount
    with conn, conn.cursor() as cur:
        cur.execute("""UPDATE runs SET status='ok', closed_at=now(), note=%s WHERE run_id=%s""",
                    (f"Collecteur OMPI — {ecrits} observation(s) sur {len(series)} indicateur(s) "
                     f"{sorted(series)}, {len(ZONES)} zones.", run_id))
    conn.close()
    print(f"\nRun {run_id} — {ecrits} observations écrites.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
