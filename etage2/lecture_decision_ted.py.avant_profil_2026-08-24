#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lecture décisionnelle des appels d'offres ouverts — 24.08.2026.

LA QUESTION POSÉE AU MODÈLE EST LE COEUR DE CE SCRIPT. Toute la journée du
23.08 a montré que ce qui limite un dispositif d'IA n'est presque jamais le
modèle, mais la question qu'on lui pose : la doctrine de triage cherchait des
« événements » et noyait les signaux ; la consigne ne distinguait pas une
pièce d'un appareil complet ; la règle de recoupement comparait des rédactions
au lieu de comparer des faits.

Ici la question n'est donc PAS « de quoi parle cet avis » — le code CPV le dit
déjà, et mieux. Elle est : **cet appel est-il exécutable par un atelier
d'usinage de précision, et que faut-il faire maintenant ?**

Le modèle ne décide pas : il ordonne 78 appels qu'un dirigeant ne lira jamais
en entier, et prépare le geste. L'avis officiel reste à un clic, l'échéance
est affichée, le jugement reste humain.

Usage :
    python3 lecture_decision_ted.py
    python3 lecture_decision_ted.py --limite 20
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

import psycopg2
import requests

FICHIER_CLES = Path(os.environ.get("CLES_API_FICHIER", Path.home() / ".config/veille_tb/cles.env"))
TIMEOUT = 120
TAILLE_LOT = 8

# Le profil est déclaré ici, en clair, parce que c'est LUI qui décide de tout.
# Un profil vague donnerait une lecture vague. Il est écrit à partir du cas
# d'illustration du travail (CODEC SA, mécanique de précision neuchâteloise) et
# doit être relu par l'étudiant : c'est une hypothèse métier, pas une donnée.
PROFIL = """Tu conseilles une PME suisse de MÉCANIQUE DE PRÉCISION (canton de Neuchâtel,
environ 50 personnes). Son métier : l'usinage de pièces métalliques à tolérances serrées —
tournage, fraisage, décolletage, rectification — en petites et moyennes séries, en
SOUS-TRAITANCE pour des donneurs d'ordre des secteurs horloger, médical (implants,
instruments), automobile et aérospatial.

Ce qu'elle SAIT faire : produire des pièces sur plan, des composants mécaniques, des
sous-ensembles usinés, de l'outillage, des prototypes et des séries.

Ce qu'elle NE FAIT PAS, et qu'il ne faut jamais lui proposer : vendre des appareils
complets (drones, hélicoptères, véhicules, machines finies), des consommables, des
logiciels, des prestations de service (maintenance, nettoyage, transport, conseil,
formation), du mobilier, des matières premières brutes, ou des équipements qu'elle
revendrait sans les produire."""

CONSIGNE = PROFIL + """

Pour CHAQUE avis de marché public de la liste, réponds à une seule question :
cet appel est-il exécutable par cet atelier, et que faut-il faire maintenant ?

Trois axes :

1. adressable (0-2)
   0 = hors du savoir-faire. Appareil complet, service, consommable, logiciel,
       matière brute, mobilier. C'est le cas le plus fréquent : n'hésite pas à
       mettre 0, une liste courte et juste vaut mieux qu'une liste longue.
   1 = périphérique. Des pièces sont impliquées mais l'objet principal est
       ailleurs, ou le lot devrait être décomposé pour être atteignable.
   2 = coeur de métier. L'avis porte sur des pièces usinées, des composants
       mécaniques, des sous-ensembles, de l'outillage ou des prototypes.

2. piece_concernee — ce qu'il faudrait produire, en quelques mots concrets et
   tirés de l'avis. Si rien n'est à produire, laisse vide.

3. action_proposee — le GESTE, pas un conseil général. Formule-le à l'impératif
   et rends-le exécutable : qui contacter, pour demander quoi. Exemple utile :
   « Demander le cahier des charges à l'acheteur pour vérifier les tolérances et
   les matières. » Exemple inutile, à ne jamais produire : « Étudier
   l'opportunité. » Si adressable vaut 0, laisse vide.

N'INVENTE RIEN. Ne suppose ni matière, ni tolérance, ni volume qui ne soit dans
l'intitulé. Si l'intitulé est trop vague pour trancher, mets adressable 1 et dis-le
dans la justification.

Réponds UNIQUEMENT par un JSON strict, sans texte autour :
{"lectures": [{"publication_number": "", "adressable": 0, "piece_concernee": "",
"action_proposee": "", "justification": ""}]}"""


def charger_cles():
    c = {}
    for l in FICHIER_CLES.read_text().splitlines():
        if "=" in l and not l.strip().startswith("#"):
            k, v = l.split("=", 1)
            c[k.strip()] = v.strip()
    return c


def appel(cles, lot):
    contenu = CONSIGNE + "\n\nAvis :\n" + "\n".join(
        f'- {a["num"]} [{a["secteur"]}, {a["pays"]}, CPV {a["cpv"]}, '
        f'{a["jours"]} jours restants] : {a["titre"]}' for a in lot)
    corps = {"contents": [{"parts": [{"text": contenu}]}],
             "generationConfig": {"temperature": 0, "responseMimeType": "application/json"}}
    url = (f"https://generativelanguage.googleapis.com/v1beta/models/"
           f"{cles['MODELE_GOOGLE']}:generateContent")
    r = requests.post(url, headers={"x-goog-api-key": cles["GOOGLE_API_KEY"]},
                      json=corps, timeout=TIMEOUT)
    r.raise_for_status()
    parts = r.json().get("candidates", [{}])[0].get("content", {}).get("parts", [])
    txt = "\n".join(p.get("text", "") for p in parts if "text" in p).strip()
    m = re.search(r"```(?:json)?\s*(\{.*\})\s*```", txt, re.DOTALL)
    return json.loads(m.group(1) if m else txt)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limite", type=int, default=200)
    args = ap.parse_args()
    cles = charger_cles()
    modele = cles["MODELE_GOOGLE"]
    conn = psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))
    with conn, conn.cursor() as cur:
        cur.execute("""
            SELECT a.publication_number, a.sector_code, a.acheteur_pays,
                   array_to_string(a.cpv, '/'), a.date_limite - CURRENT_DATE, a.titre
            FROM ted_avis a
            WHERE a.est_appel_ouvert AND a.date_limite >= CURRENT_DATE
              AND NOT EXISTS (SELECT 1 FROM ted_lecture_ia l
                              WHERE l.publication_number = a.publication_number
                                AND l.modele = %s)
            ORDER BY a.date_limite LIMIT %s""", (modele, args.limite))
        attente = [{"num": r[0], "secteur": r[1], "pays": r[2], "cpv": r[3],
                    "jours": r[4], "titre": (r[5] or "")[:260]} for r in cur.fetchall()]
    print(f"{len(attente)} appels ouverts sans lecture pour {modele}.")

    ecrits = echecs = 0
    for i in range(0, len(attente), TAILLE_LOT):
        lot = attente[i:i + TAILLE_LOT]
        rep = None
        for tentative in (1, 2):
            try:
                rep = appel(cles, lot)
                break
            except Exception as exc:
                print(f"  lot {i // TAILLE_LOT + 1}, tentative {tentative} : {exc}")
        if not rep:
            echecs += len(lot)
            continue
        valides = {a["num"] for a in lot}
        with conn, conn.cursor() as cur:
            for l in rep.get("lectures", []):
                if l.get("publication_number") not in valides: continue
                if l.get("adressable") not in (0, 1, 2): continue
                cur.execute("""
                    INSERT INTO ted_lecture_ia (publication_number, modele, adressable,
                        piece_concernee, action_proposee, justification)
                    VALUES (%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (publication_number, modele) DO NOTHING""",
                    (l["publication_number"], modele, l["adressable"],
                     (l.get("piece_concernee") or "")[:300] or None,
                     (l.get("action_proposee") or "")[:400] or None,
                     (l.get("justification") or "")[:400]))
                ecrits += cur.rowcount
        print(f"  lot {i // TAILLE_LOT + 1}/{-(-len(attente)//TAILLE_LOT)} — {ecrits} lectures")
    conn.close()
    print(f"\n{ecrits} lectures écrites, {echecs} en échec.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
