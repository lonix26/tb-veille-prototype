#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Étage 2 — triage IA des items de flux. Écrit le 23.08.2026, NON EXÉCUTÉ.

Rôle : ordonner la lecture du veilleur, RIEN D'AUTRE. Le script écrit des scores
(flux_triage_ia) ; il n'écrit aucun statut, ne promeut rien, ne valide rien —
la seule porte de sortie des items est flux_examens (décision humaine nominative).

Choix documentés (CONCEPTION_ETAGE2.md § 2, à reporter au rapport) :
  - MODÈLE UNIQUE ET ÉCONOMIQUE (Gemini Flash, MODELE_GOOGLE de cles.env) : le triage
    est une tâche contrainte et réversible ; le § 9.4.2 établit que sur les tâches
    contraintes les quatre systèmes sont équivalents — le coût décide. Le consensus
    multi-modèles reste réservé à l'extraction d'événements (chaîne signals).
  - TEMPÉRATURE 0 : contrairement à la vague 3, la variance n'est pas l'objet mesuré ;
    on veut le triage le plus reproductible possible.
  - TAUX D'ERREUR MESURÉ, PAS SUPPOSÉ : la vue v_triage_a_echantillonner croise les
    décisions humaines et les scores IA ; le taux se lit après une session d'examen.
  - Lots de 10 items par appel, sortie JSON stricte ; un lot non parsable est rejoué
    une fois puis journalisé en échec — jamais de score par défaut.

Usage (depuis prototype/etage2/, base démarrée) :
    python3 triage_ia_flux.py             # trie tous les items sans score
    python3 triage_ia_flux.py --limite 50

Clés : ~/.config/veille_tb/cles.env (GOOGLE_API_KEY, MODELE_GOOGLE).
Dépendances : requests, psycopg2-binary.
"""

import argparse
import json
import os
import re
from pathlib import Path

import psycopg2
import requests

FICHIER_CLES = Path(os.environ.get("CLES_API_FICHIER", Path.home() / ".config/veille_tb/cles.env"))
TIMEOUT = 120
TAILLE_LOT = 10

CADRE_QV = """Questions de veille (cadre invariant du dispositif) :
- QV1 (santé structurelle) : la solidité du tissu du secteur — activité, emploi, démographie d'entreprises, situation des donneurs d'ordre.
- QV2 (demande et débouchés) : la demande adressée au secteur — commandes, ventes, exportations, appels d'offres, trafic.
- QV3 (dynamique géographique) : les déplacements de la demande et de l'offre entre zones.
- QV4 (dynamique technologique) : les évolutions techniques qui changent ce qui est produit ou comment — brevets, nouveaux procédés, transitions.
- QV5 (impulsions publiques) : ce que les pouvoirs publics injectent ou imposent — budgets, réglementations, subventions, droits de douane.
Secteurs : horlogerie, medical, automobile, aerospatial (contexte : PME suisse de mécanique de précision, sous-traitante de ces quatre marchés)."""

CONSIGNE = (
    "Tu tries des items de veille économique pour un veilleur de PME industrielle suisse. "
    + CADRE_QV +
    "\nPour CHAQUE item de la liste, attribue : pertinence (0 = sans intérêt pour la veille de ces secteurs, "
    "1 = contexte utile, 2 = à examiner en priorité — événement susceptible d'affecter la demande, la "
    "réglementation ou la structure d'un des quatre marchés), secteur (un des quatre codes, ou null), "
    "qv (QV1..QV5, ou null), resume (une phrase factuelle en français), justification (une phrase). "
    "N'invente rien : si l'item est ambigu, pertinence 1 au plus. Réponds UNIQUEMENT par un JSON strict : "
    '{"triages": [{"item_id": 0, "pertinence": 0, "secteur": null, "qv": null, "resume": "", "justification": ""}]} '
    "— un objet par item, item_id repris tel quel, sans aucun texte hors du JSON."
)


# ---------------------------------------------------------------------------
# DOCTRINE « SIGNAL » — écrite le 23.08.2026 après le constat de la session
# d'examen. La doctrine « événement » ci-dessus note la pertinence : elle
# récompense la nouvelle claire et bien cadrée. Un signal faible est l'inverse
# — fragmentaire, ambigu, périphérique — et se trouvait donc pénalisé par
# construction. Sur les dix premiers items notés 2, sept étaient des avis
# d'achat isolés et deux relayaient un chiffre déjà publié.
#
# La consigne ci-dessous change la QUESTION, pas le modèle. Elle sépare
# explicitement trois choses que la première confondait : de quoi ça parle
# (pertinence), quand ça arrive par rapport à la statistique (antériorité),
# et ce que ça changerait si c'était vrai (portée).
# ---------------------------------------------------------------------------

CONSIGNE_SIGNAL = (
    "Tu assistes une veille ANTICIPATIVE pour une PME suisse de mécanique de précision, "
    "sous-traitante des marchés horloger, médical, automobile et aérospatial. "
    + CADRE_QV +
    "\n\nTa tâche n'est pas de repérer les nouvelles importantes : elle est de repérer ce qui "
    "ANNONCE quelque chose. Un signal faible est fragmentaire, ambigu, souvent périphérique, et "
    "il n'a pas encore la forme d'un événement — c'est précisément pour cela qu'il passe inaperçu. "
    "Note CHAQUE item sur trois axes INDÉPENDANTS. N'aligne pas les trois : un item peut être peu "
    "pertinent et très antérieur, et c'est exactement ce que l'on cherche."
    "\n\n1. pertinence (0-2) : de quoi ça parle. 0 = hors des quatre marchés ; 1 = en rapport ; "
    "2 = au cœur d'un des quatre marchés."
    "\n\n2. anteriorite (0-2) : QUAND l'information arrive par rapport à la statistique officielle. "
    "0 = elle RELAIE un chiffre ou un fait déjà publié — un article de presse rapportant les "
    "exportations horlogères du mois que la fédération vient de publier vaut 0, même s'il est "
    "parfaitement pertinent, car la statistique le contient déjà. "
    "1 = simultané, ou fait non encore repris par une statistique. "
    "2 = EN AMONT : décision, intention, contrainte, projet ou tension qui ne figurera dans aucune "
    "statistique avant plusieurs mois — investissement annoncé, capacité en construction, texte en "
    "négociation, norme en préparation, tension d'approvisionnement, réorientation de programme."
    "\n\n3. portee (0-2) : si l'information se confirmait, changerait-elle quelque chose pour CETTE "
    "PME ? 0 = non ; 1 = indirectement (climat du secteur) ; 2 = directement — charge d'usinage, "
    "accès à une matière, exigence technique nouvelle, ouverture ou fermeture d'un débouché."
    "\n\nN'invente rien. Si tu ne peux pas justifier une note d'antériorité par un élément présent "
    "dans l'item, mets 0. Réponds UNIQUEMENT par un JSON strict : "
    '{"triages": [{"item_id": 0, "pertinence": 0, "anteriorite": 0, "portee": 0, "secteur": null, '
    '"qv": null, "resume": "", "justification": ""}]} '
    "— un objet par item, item_id repris tel quel, sans aucun texte hors du JSON. "
    "La justification doit dire EN QUOI l'item devance ou non la statistique."
)

CONSIGNES = {"evenement": CONSIGNE, "signal": CONSIGNE_SIGNAL}


def charger_cles():
    cles = {}
    for ligne in FICHIER_CLES.read_text().splitlines():
        if "=" in ligne and not ligne.strip().startswith("#"):
            k, v = ligne.split("=", 1)
            cles[k.strip()] = v.strip()
    return cles


def connexion():
    return psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))


def appel_modele(cles, lot, doctrine):
    """Un appel Gemini par lot. Détails d'API du 23.08.2026 — à vérifier au jour J."""
    contenu = CONSIGNES[doctrine] + "\n\nItems :\n" + "\n".join(
        f'- item_id {it["item_id"]} [{it["famille"]}/{it["secteur_flux"] or "transversal"}] : {it["titre"]}'
        for it in lot)
    corps = {"contents": [{"parts": [{"text": contenu}]}],
             "generationConfig": {"temperature": 0}}
    url = (f"https://generativelanguage.googleapis.com/v1beta/models/"
           f"{cles['MODELE_GOOGLE']}:generateContent")
    r = requests.post(url, headers={"x-goog-api-key": cles["GOOGLE_API_KEY"]}, json=corps, timeout=TIMEOUT)
    r.raise_for_status()
    parts = r.json().get("candidates", [{}])[0].get("content", {}).get("parts", [])
    texte = "\n".join(p.get("text", "") for p in parts if "text" in p).strip()
    m = re.search(r"```(?:json)?\s*(\{.*\})\s*```", texte, re.DOTALL)
    return json.loads(m.group(1) if m else texte)


SECTEURS = {"horlogerie", "medical", "automobile", "aerospatial"}
QVS = {"QV1", "QV2", "QV3", "QV4", "QV5"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limite", type=int, default=400)
    ap.add_argument("--doctrine", choices=("evenement","signal"), default="evenement",
                    help="doctrine de triage. « evenement » : pertinence seule (première passe). "
                         "« signal » : ajoute antériorité et portée (chantier du 23.08).")
    args = ap.parse_args()
    cles = charger_cles()
    modele = cles["MODELE_GOOGLE"]
    doctrine = args.doctrine
    conn = connexion()
    with conn, conn.cursor() as cur:
        cur.execute("""
            SELECT fi.item_id, fi.titre, fs.famille, fs.sector_code
            FROM flux_items fi
            JOIN flux_sources fs ON fs.flux_id = fi.flux_id
            WHERE NOT EXISTS (SELECT 1 FROM flux_triage_ia t
                              WHERE t.item_id = fi.item_id AND t.modele = %s
                                AND t.doctrine = %s)
            ORDER BY fi.item_id LIMIT %s""", (modele, doctrine, args.limite))
        attente = [{"item_id": r[0], "titre": r[1], "famille": r[2], "secteur_flux": r[3]}
                   for r in cur.fetchall()]
    print(f"{len(attente)} items sans score pour {modele} en doctrine « {doctrine} ».")
    ecrits = echecs = 0
    for i in range(0, len(attente), TAILLE_LOT):
        lot = attente[i:i + TAILLE_LOT]
        reponse = None
        for tentative in (1, 2):  # un rejeu, puis échec journalisé — jamais de score par défaut
            try:
                reponse = appel_modele(cles, lot, doctrine)
                break
            except Exception as exc:
                print(f"  lot {i // TAILLE_LOT + 1}, tentative {tentative} : {exc}")
        if not reponse:
            echecs += len(lot)
            continue
        valides = {it["item_id"] for it in lot}
        with conn, conn.cursor() as cur:
            for t in reponse.get("triages", []):
                if t.get("item_id") not in valides or t.get("pertinence") not in (0, 1, 2):
                    continue
                secteur = t.get("secteur") if t.get("secteur") in SECTEURS else None
                qv = t.get("qv") if t.get("qv") in QVS else None
                borne = lambda v: v if v in (0, 1, 2) else None
                cur.execute("""
                    INSERT INTO flux_triage_ia
                      (item_id, modele, doctrine, pertinence, anteriorite, portee,
                       sector_code, watch_question_code, resume, justification)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (item_id, modele, doctrine) DO NOTHING""",
                    (t["item_id"], modele, doctrine, t["pertinence"],
                     borne(t.get("anteriorite")) if doctrine == "signal" else None,
                     borne(t.get("portee")) if doctrine == "signal" else None,
                     secteur, qv,
                     (t.get("resume") or "")[:500], (t.get("justification") or "")[:500]))
                ecrits += cur.rowcount
    print(f"Triage : {ecrits} scores écrits, {echecs} items en échec (à rejouer). "
          f"File de lecture : SELECT * FROM v_flux_a_examiner;")


if __name__ == "__main__":
    main()
