#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Collecte des exportations horlogères suisses — Fédération horlogère (FH).
N. Castillo, 24.08.2026.

POURQUOI CETTE SOURCE, ET POURQUOI SI TARD.
La FH figurait au référentiel avec le statut « certifiée » depuis le 07.08.2026
et ne portait AUCUN indicateur : les exportations horlogères étaient collectées
chez Comtrade, en dollars. Le § 5.2 de la partie théorique la citait pourtant
nommément comme source de commerce extérieur pour l'horlogerie. L'écart entre
la théorie du travail et sa grille est le motif de la révision du 24.08 (§ 8.6).

CE QUE LA FH APPORTE ET QUE COMTRADE NE DONNE PAS :
  · les montants sont en FRANCS SUISSES — la mesure Comtrade en dollars
    incorpore le change, dont la corrélation avec la série a été mesurée à
    -0,40 : un sixième de la variance de l'indicateur horloger phare était du
    taux de change et non de la demande ;
  · la publication intervient à J+20 environ, contre plusieurs mois pour la
    statistique consolidée du commerce international ;
  · et surtout, la ventilation MÉCANIQUE / ÉLECTRONIQUE, qui est LA distinction
    pertinente pour un atelier d'usinage : une montre mécanique mobilise des
    dizaines de pièces usinées à tolérances serrées, une montre à quartz en
    mobilise peu. Deux marchés horlogers de même valeur n'appellent pas la même
    charge d'atelier selon leur mix.

POURQUOI PAR EXTRACTION DÉTERMINISTE ET NON PAR IA.
C'est un choix de doctrine, pas de commodité (§ 6.5, prescription 3). Le PDF de
la FH contient un TABLEAU dont `pdftotext -layout` restitue la structure
colonne par colonne : la donnée y est structurée, seul son emballage ne l'est
pas. Le communiqué de l'ACEA, à l'inverse, énonce ses chiffres en prose, au
milieu d'un texte, et c'est ce qui justifie la chaîne composite multi-modèles
pour A2. Deux documents PDF, deux traitements, une seule règle : l'IA là où la
donnée n'est pas structurée, le code partout ailleurs. Le dispositif porte
désormais les deux cas côte à côte, ce qui rend la règle démontrable et non
seulement énoncée.

POURQUOI UN SCRIPT ET NON UN NŒUD D'ORCHESTRATION.
`pdftotext` n'est pas présent dans l'image de l'orchestrateur — vérifié le
24.08.2026. Même raison, même solution que pour la couche 0 et l'artefact du
scénario C : le traitement est porté par un script, l'écriture reste en base.

Usage :
    python3 collecte_fh_horlogerie.py            # collecte et écrit
    python3 collecte_fh_horlogerie.py --essai    # extrait et affiche, n'écrit rien
"""

import argparse
import datetime as dt
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import psycopg2
import requests

PAGE = "https://www.fhs.swiss/fre/statistics.html"
BASE = "https://www.fhs.swiss"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36",
      "Accept-Language": "fr-CH,fr;q=0.9"}
TIMEOUT = 90

# Le classeur change de nom à chaque parution : on lit le lien sur la page
# d'index plutôt que de reconstruire l'URL — même principe que le connecteur
# `xlsx_indexe`, dont c'est la raison d'être.
MOTIF_LIEN = re.compile(r'(?:href=")?(/scripts/getstat\.php\?file=histo_elec-meca_(\d{6})_f\.pdf)')

MOIS = {"jan": "01", "fév": "02", "fev": "02", "mar": "03", "avr": "04", "mai": "05",
        "jun": "06", "jui": "07", "aou": "08", "aoû": "08", "sep": "09",
        "oct": "10", "nov": "11", "déc": "12", "dec": "12"}

# Ce que l'on extrait, colonne par colonne, du tableau « électroniques et
# mécaniques ». L'ordre des colonnes est celui du document et il est vérifié
# par un contrôle de cohérence avant toute écriture.
COLONNES = ["total_pieces", "total_chf", "elec_pieces", "elec_chf", "meca_pieces", "meca_chf"]

INDICATEURS = {
    "H7": ("total_chf",  "Exportations horlogères suisses, valeur totale"),
    "H8": ("meca_chf",   "Exportations de montres mécaniques, valeur"),
    "H9": ("meca_pieces","Exportations de montres mécaniques, volume"),
}


def nombre(t):
    """« 2'011,7 » → 2011.7. Apostrophe suisse de milliers, virgule décimale."""
    t = t.replace("'", "").replace("’", "").replace(" ", "").replace(" ", "")
    t = t.replace(",", ".")
    try:
        return float(t)
    except ValueError:
        return None


def telecharger():
    r = requests.get(PAGE, headers=UA, timeout=TIMEOUT)
    r.raise_for_status()
    page = r.content.decode("windows-1252", errors="replace")
    m = MOTIF_LIEN.search(page)
    if not m:
        raise RuntimeError("lien histo_elec-meca introuvable sur la page d'index — "
                           "structure de la page modifiée, à instruire")
    url, millesime = BASE + m.group(1).replace("&amp;", "&"), m.group(2)
    p = requests.get(url, headers=UA, timeout=TIMEOUT)
    p.raise_for_status()
    if "pdf" not in p.headers.get("content-type", "").lower():
        raise RuntimeError(f"réponse non-PDF pour {url}")
    return p.content, url, millesime


def extraire(pdf_octets):
    """Rend {periode: {colonne: valeur}} pour les lignes MENSUELLES.

    Les lignes annuelles (2000, 2005, 2010, 2015, 2020-2025) sont ignorées : le
    registre les recevrait comme des périodes « AAAA » et elles feraient double
    emploi avec les mois qu'elles agrègent."""
    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as f:
        f.write(pdf_octets); chemin = f.name
    try:
        texte = subprocess.run(["pdftotext", "-layout", chemin, "-"],
                               capture_output=True, timeout=120).stdout.decode("utf-8", "replace")
    finally:
        os.unlink(chemin)

    sortie, incidents = {}, []
    annee_courante = None
    for ligne in texte.splitlines():
        l = ligne.strip()
        if not l:
            continue
        m = re.match(r"^(jan|fév|fev|mar|avr|mai|jun|jui|aou|aoû|sep|oct|nov|déc|dec)\s+(\d{2})\s+(.*)$", l)
        if not m:
            continue
        mois, an, reste = m.group(1), m.group(2), m.group(3)
        # Un nombre suisse : chiffres, apostrophes de milliers, virgule décimale —
        # et AUCUN espace. Le motif d'origine en admettait, ce qui fusionnait les
        # colonnes deux à deux : trois valeurs lues sur six. Le contrôle de
        # cohérence a refusé l'écriture, ce pour quoi il la précède.
        valeurs = [nombre(x) for x in re.findall(r"[\d']+(?:,\d+)?", reste)]
        valeurs = [v for v in valeurs if v is not None]
        if len(valeurs) < len(COLONNES):
            incidents.append(f"{mois} {an} : {len(valeurs)} colonnes lues sur {len(COLONNES)}")
            continue
        periode = f"20{an}-{MOIS[mois]}"
        sortie[periode] = dict(zip(COLONNES, valeurs[:len(COLONNES)]))
    return sortie, incidents


def coherence(lignes):
    """CONTRÔLE AVANT ÉCRITURE, et non après. L'ordre des colonnes du document
    est une hypothèse : on la teste. Électroniques + mécaniques doivent
    reconstituer le total des montres-bracelets à quelques pour cent près — le
    total du tableau inclut la seule catégorie montres-bracelets, la somme doit
    donc être proche. Un écart important signale que les colonnes ont bougé."""
    ecarts = []
    for p, v in sorted(lignes.items()):
        somme = (v["elec_chf"] or 0) + (v["meca_chf"] or 0)
        tot = v["total_chf"] or 0
        if tot > 0:
            e = abs(somme - tot) / tot * 100
            ecarts.append((p, e))
    if not ecarts:
        return False, "aucune ligne à contrôler"
    pire = max(ecarts, key=lambda x: x[1])
    moy = sum(e for _, e in ecarts) / len(ecarts)
    ok = pire[1] < 8.0
    return ok, (f"écart élec+méca contre total : moyen {moy:.2f} %, "
                f"maximum {pire[1]:.2f} % ({pire[0]}) — "
                f"{'ordre des colonnes confirmé' if ok else 'ORDRE DES COLONNES SUSPECT'}")


def connexion():
    return psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--essai", action="store_true", help="extrait et affiche, n'écrit rien")
    args = ap.parse_args()

    pdf, url, millesime = telecharger()
    print(f"Document : {url}\nMillésime : {millesime} · {len(pdf)} octets")
    lignes, incidents = extraire(pdf)
    print(f"{len(lignes)} lignes mensuelles extraites"
          + (f", {len(incidents)} incident(s)" if incidents else ""))
    for i in incidents[:5]:
        print(f"    {i}")

    ok, message = coherence(lignes)
    print(f"Contrôle de cohérence : {message}")
    if not ok:
        print("ÉCRITURE REFUSÉE — le contrôle de cohérence n'est pas passé.")
        return 1

    ks = sorted(lignes)
    print(f"Période : {ks[0]} → {ks[-1]}")
    d = lignes[ks[-1]]
    part = 100 * d["meca_chf"] / d["total_chf"] if d["total_chf"] else 0
    partv = 100 * d["meca_pieces"] / d["total_pieces"] if d["total_pieces"] else 0
    print(f"Dernier point — total {d['total_chf']:.1f} mio CHF, "
          f"mécaniques {d['meca_chf']:.1f} mio ({part:.1f} % de la valeur, "
          f"{partv:.1f} % du volume)")

    if args.essai:
        print("\n(--essai : rien n'a été écrit)")
        return 0

    conn = connexion()
    with conn, conn.cursor() as cur:
        cur.execute("""INSERT INTO runs (trigger_type, scenario, status, note)
                       VALUES ('manual','B','en_cours','Collecteur FH — exportations horlogères (CHF)')
                       RETURNING run_id""")
        run_id = cur.fetchone()[0]
    ecrits = 0
    with conn, conn.cursor() as cur:
        for periode in ks:
            v = lignes[periode]
            for code, (colonne, _) in INDICATEURS.items():
                val = v.get(colonne)
                if val is None:
                    continue
                cur.execute("""INSERT INTO indicator_values
                    (indicator_id, run_id, period, geo, value, obtained_by,
                     validation_status, raw_ref)
                    VALUES (%s,%s,%s,'CH',%s,'etl','valide_source',%s)""",
                    (code, run_id, periode, val, url))
                ecrits += cur.rowcount
    with conn, conn.cursor() as cur:
        cur.execute("""UPDATE runs SET status='ok', closed_at=now(),
                       note = %s WHERE run_id=%s""",
                    (f"Collecteur FH — {ecrits} observation(s) sur 3 indicateurs "
                     f"[H7, H8, H9], {ks[0]} à {ks[-1]}. {message}", run_id))
    conn.close()
    print(f"\nRun {run_id} — {ecrits} observations écrites.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
