#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Veille du communiqué ACEA d'immatriculations — alimente A2 (composite).

Écrit le 23.08.2026. Objet : A2 compte SEPT périodes distinctes en base ; le seuil
d'éligibilité de v_sante_secteur est de HUIT points. Le communiqué de juillet 2026
donnerait le huitième — et donc le premier score de santé sectorielle réel du dispositif.

Rythme observé (plan du site ACEA, sitemap pr-pc) : publication le 23 de chaque mois,
portant sur le mois précédent. Dernière parution au 23.08.2026 : 23.07.2026, données de
juin (« H1 2026 »). Juillet est donc attendu.

CONFORMITÉ — vérifiée le 23.08.2026 sur https://www.acea.auto/robots.txt :
    User-agent: *   Content-Signal: search=yes, ai-train=no, use=reference   Allow: /
Les agents génériques sont autorisés et l'usage « reference » — citer la source, en
extraire un chiffre publié — est celui de ce travail. ACEA interdit en revanche NOMMÉMENT
plusieurs robots (ClaudeBot, GPTBot, CCBot, Google-Extended, Bytespider…). Ce script
s'identifie sous son propre nom, avec un contact : il n'usurpe aucune de ces identités et
n'en contourne aucune. Cadence volontairement basse (une vérification par jour suffit).

POINT OUVERT, à traiter au rapport et non ici : le pipeline A2 envoie le PDF à trois API
de modèles pour extraction. Le signal `ai-train=no` est respecté (l'inférence n'est pas de
l'entraînement), mais ACEA ne déclare aucun signal `ai-input` — et selon sa propre règle,
l'absence de signal « ne concède ni ne restreint ». Ce n'est donc ni autorisé ni interdit :
à énoncer dans la sous-section « frontière légale et déontologique », pas à trancher par
défaut.

Usage :
    python3 veille_acea_A2.py            # vérifie, signale, n'écrit rien
    python3 veille_acea_A2.py --inscrire # inscrit en composite_queue si le PDF répond

L'inscription dépose une ligne en statut `a_verifier` : la file attend une vérification
humaine, l'extraction ne part pas toute seule.
"""

import argparse
import datetime as dt
import os
import re
import sys

import requests

AGENT = ("veille-TB-HEG-Arc/1.0 (travail de bachelor, HEG Arc, usage academique et non "
         "commercial ; contact devlonix26@gmail.com)")
SITEMAP = "http://www.acea.auto/pr-pc-sitemap.xml"
GABARIT_PDF = "https://www.acea.auto/files/Press_release_car_registrations_{mois}_{annee}.pdf"
MOIS_EN = ["January", "February", "March", "April", "May", "June",
           "July", "August", "September", "October", "November", "December"]


def periode_attendue(aujourdhui=None):
    """Le communiqué du mois M porte sur le mois M-1."""
    a = aujourdhui or dt.date.today()
    precedent = (a.replace(day=1) - dt.timedelta(days=1))
    return precedent.year, precedent.month


def pdf_disponible(annee, mois_num):
    url = GABARIT_PDF.format(mois=MOIS_EN[mois_num - 1], annee=annee)
    r = requests.get(url, headers={"User-Agent": AGENT}, timeout=45, stream=True)
    ok = r.status_code == 200 and "pdf" in r.headers.get("Content-Type", "").lower()
    taille = r.headers.get("Content-Length", "?")
    r.close()
    return ok, url, r.status_code, taille


def derniere_parution():
    r = requests.get(SITEMAP, headers={"User-Agent": AGENT}, timeout=45)
    r.raise_for_status()
    couples = re.findall(r"<loc>(.*?)</loc>\s*<lastmod>(.*?)</lastmod>", r.text)
    return (couples[-1][1][:10], couples[-1][0]) if couples else ("?", "?")


def inscrire(periode, url):
    import psycopg2
    conn = psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))
    with conn, conn.cursor() as cur:
        cur.execute(
            """INSERT INTO composite_queue (indicator_id, period, geo, source_doc, statut, note)
               VALUES ('A2', %s, 'EU27', %s, 'a_verifier',
                       'Détecté par veille_acea_A2.py le ' || CURRENT_DATE ||
                       '. PDF joignable au moment de l''inscription. Vérification humaine requise avant extraction.')
               ON CONFLICT (indicator_id, period, source_doc) DO NOTHING
               RETURNING doc_id""", (periode, url))
        ligne = cur.fetchone()
    conn.close()
    return ligne[0] if ligne else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inscrire", action="store_true",
                    help="inscrire en composite_queue si le PDF répond (statut a_verifier)")
    args = ap.parse_args()

    annee, mois = periode_attendue()
    periode = f"{annee}-{mois:02d}"
    date_sitemap, lien = derniere_parution()
    ok, url, code, taille = pdf_disponible(annee, mois)

    print(f"Période attendue : {periode} ({MOIS_EN[mois - 1]} {annee})")
    print(f"Dernière parution au plan du site : {date_sitemap}")
    print(f"    {lien[:100]}")
    print(f"PDF {MOIS_EN[mois - 1]} : HTTP {code}" + (f", {taille} o" if ok else ""))

    if not ok:
        print("→ Pas encore publié. Rien à faire ; relancer demain.")
        return 1

    print(f"→ DISPONIBLE : {url}")
    if not args.inscrire:
        print("   (relancer avec --inscrire pour déposer en composite_queue)")
        return 0
    doc_id = inscrire(periode, url)
    print(f"   Inscrit en composite_queue, doc_id={doc_id}, statut a_verifier."
          if doc_id else "   Déjà en file — rien inséré.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
