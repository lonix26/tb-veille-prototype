#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Sensibilité de la lecture décisionnelle au profil métier — 24.08.2026.

POURQUOI CE SCRIPT EXISTE. Le profil métier de lecture_decision_ted.py a
motivé 74 des 77 exclusions du 24.08 et n'est pas ratifié. Deux réponses
étaient possibles : demander une ratification à l'aveugle, ou MESURER ce que
le profil décide réellement. Le travail ayant fait de « substituer une mesure
à une affirmation » sa méthode (§ 10.5), c'est la seconde.

CE QUI EST MESURÉ. La question posée au modèle est rigoureusement invariante ;
seul le profil change. L'écart entre les verdicts est donc imputable au profil
et à rien d'autre. Trois profils :

  A  référence — métier, secteurs clients, et liste explicite de ce que
     l'entreprise NE fait pas. C'est celui qui tourne en production.
  B  élargi — même métier, mais SANS liste d'exclusion et SANS secteurs
     clients. Mesure ce que la liste d'exclusion décide à elle seule.
  C  minimal — aucune narration d'entreprise, la seule question technique.
     Mesure ce que la mise en situation décide, par rapport à la question nue.

CE QUI N'EST PAS MESURÉ, et doit être dit : la justesse. Aucun de ces trois
profils n'est la vérité. Un écart faible signifie que le verdict est robuste
au profil, non qu'il est correct ; un écart fort signifie que le profil porte
la décision, ce qui est une information sur le dispositif, pas sur le marché.

Les lectures B et C sont écrites en base comme pièces de mesure. La vue
v_actions est ancrée sur le profil A : elles n'atteignent aucun écran.

Usage :
    python3 sensibilite_profil.py            # profils B et C
    python3 sensibilite_profil.py --rapport  # comparaison seule, sans appel
"""

import argparse
import os
import sys

import psycopg2

from lecture_decision_ted import PROFIL, TAILLE_LOT, appel, charger_cles, construire_consigne

PROFILS = {
    "B_elargi": """Tu conseilles une PME suisse de MÉCANIQUE DE PRÉCISION (canton de Neuchâtel,
environ 50 personnes). Son métier : l'usinage de pièces métalliques à tolérances serrées —
tournage, fraisage, décolletage, rectification — en petites et moyennes séries, en
SOUS-TRAITANCE.""",

    "C_minimal": """Tu analyses des avis de marchés publics pour un atelier d'usinage de pièces
métalliques.""",
}


def connexion():
    return psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))


def lire(cles, conn, profil_nom, profil_texte):
    modele = cles["MODELE_GOOGLE"]
    consigne = construire_consigne(profil_texte)
    with conn, conn.cursor() as cur:
        cur.execute("""
            SELECT a.publication_number, a.sector_code, a.acheteur_pays,
                   array_to_string(a.cpv, '/'), a.date_limite - CURRENT_DATE, a.titre
            FROM ted_avis a
            WHERE a.est_appel_ouvert AND a.date_limite >= CURRENT_DATE
              AND NOT EXISTS (SELECT 1 FROM ted_lecture_ia l
                              WHERE l.publication_number = a.publication_number
                                AND l.modele = %s AND l.profil = %s)
            ORDER BY a.date_limite""", (modele, profil_nom))
        attente = [{"num": r[0], "secteur": r[1], "pays": r[2], "cpv": r[3],
                    "jours": r[4], "titre": (r[5] or "")[:260]} for r in cur.fetchall()]
    print(f"\nProfil {profil_nom} — {len(attente)} avis à lire.")
    ecrits = echecs = 0
    for i in range(0, len(attente), TAILLE_LOT):
        lot = attente[i:i + TAILLE_LOT]
        rep = None
        for tentative in (1, 2):
            try:
                rep = appel(cles, lot, consigne)
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
                    INSERT INTO ted_lecture_ia (publication_number, modele, profil, adressable,
                        piece_concernee, action_proposee, justification)
                    VALUES (%s,%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (publication_number, modele, profil) DO NOTHING""",
                    (l["publication_number"], modele, profil_nom, l["adressable"],
                     (l.get("piece_concernee") or "")[:300] or None,
                     (l.get("action_proposee") or "")[:400] or None,
                     (l.get("justification") or "")[:400]))
                ecrits += cur.rowcount
    print(f"  {ecrits} lectures écrites, {echecs} en échec.")


def rapport(conn):
    with conn, conn.cursor() as cur:
        print("\n═══ Verdicts par profil (appels ouverts non expirés) ═══")
        cur.execute("""
            SELECT l.profil,
                   count(*) AS lus,
                   count(*) FILTER (WHERE l.adressable = 0) AS ecartes,
                   count(*) FILTER (WHERE l.adressable = 1) AS peripheriques,
                   count(*) FILTER (WHERE l.adressable = 2) AS coeur
            FROM ted_lecture_ia l JOIN ted_avis a USING (publication_number)
            WHERE a.est_appel_ouvert AND a.date_limite >= CURRENT_DATE
            GROUP BY 1 ORDER BY 1""")
        print(f"{'profil':<18}{'lus':>6}{'écartés':>10}{'périph.':>10}{'cœur':>7}")
        for r in cur.fetchall():
            print(f"{r[0]:<18}{r[1]:>6}{r[2]:>10}{r[3]:>10}{r[4]:>7}")

        print("\n═══ Accord avec le profil de référence A ═══")
        for autre in PROFILS:
            cur.execute("""
                SELECT count(*) AS communs,
                       count(*) FILTER (WHERE (a.adressable>=1) = (b.adressable>=1)) AS accord_binaire,
                       count(*) FILTER (WHERE a.adressable = b.adressable) AS accord_exact,
                       count(*) FILTER (WHERE a.adressable=0 AND b.adressable>=1) AS retenus_par_autre,
                       count(*) FILTER (WHERE a.adressable>=1 AND b.adressable=0) AS ecartes_par_autre
                FROM ted_lecture_ia a
                JOIN ted_lecture_ia b USING (publication_number, modele)
                JOIN ted_avis v USING (publication_number)
                WHERE a.profil='A_metier_declare' AND b.profil=%s
                  AND v.est_appel_ouvert AND v.date_limite >= CURRENT_DATE""", (autre,))
            n, bin_, exact, pris, perdus = cur.fetchone()
            if not n:
                print(f"  {autre} : aucune lecture comparable."); continue
            print(f"  {autre:<12} {n} avis comparés · accord binaire {bin_}/{n} "
                  f"({100*bin_/n:.0f} %) · accord exact {exact}/{n} ({100*exact/n:.0f} %)")
            print(f"  {'':<12} retenus par {autre} et non par A : {pris} · "
                  f"écartés par {autre} et retenus par A : {perdus}")

        print("\n═══ Le constat ferroviaire tient-il sous chaque profil ? ═══")
        cur.execute("""
            SELECT l.profil,
                   count(*) FILTER (WHERE l.adressable>=1) AS adressables,
                   count(*) FILTER (WHERE l.adressable>=1 AND a.sector_code IS NULL) AS dont_ferroviaire
            FROM ted_lecture_ia l JOIN ted_avis a USING (publication_number)
            WHERE a.est_appel_ouvert AND a.date_limite >= CURRENT_DATE
            GROUP BY 1 ORDER BY 1""")
        for prof, adr, ferro in cur.fetchall():
            part = f"{100*ferro/adr:.0f} %" if adr else "—"
            print(f"  {prof:<18} {adr:>3} adressables, dont {ferro:>3} ferroviaires ({part})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rapport", action="store_true", help="comparaison seule, aucun appel d'API")
    args = ap.parse_args()
    conn = connexion()
    if not args.rapport:
        cles = charger_cles()
        for nom, texte in PROFILS.items():
            lire(cles, conn, nom, texte)
    rapport(conn)
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
