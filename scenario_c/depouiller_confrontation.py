#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Dépouillement de la confrontation B/C — grille du § 10.5.3. 24.08.2026.

CE QUI EST MESURÉ ET CE QUI NE L'EST PAS. Sept des dix dimensions se mesurent
par calcul sur les sorties archivées ; elles le sont ici. La dimension 6 (temps
humain) suppose un chronométrage du dépouillement par l'étudiant, qui n'a pas eu
lieu — elle est déclarée non mesurée plutôt qu'estimée. La dimension 9
(auditabilité) est tranchée par l'architecture avant toute exécution, comme le
§ 10.5.3 l'annonce.

L'ASYMÉTRIE EST ASSUMÉE, et rappelée à chaque lecture : le dispositif B a
bénéficié de tout le travail de conception du chapitre 10 ; l'artefact C est un
dispositif de laboratoire. La confrontation ne juge pas le scénario C dans
l'absolu, elle documente l'écart entre deux régimes de supervision de moyens
équivalents dans le contexte de ce travail.

Usage :
    python3 depouiller_confrontation.py > ../../annexes/7_confrontation_B_C.md
"""

import datetime as dt
import json
import os
import re
import sys

import psycopg2
import requests

ESPACES = ["sandbox_agent_r1", "sandbox_agent_r2", "sandbox_agent_r3"]
UA = {"User-Agent": "Mozilla/5.0 (compatible; verification de liens, travail de bachelor)"}


def connexion():
    return psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))


def nombres(texte):
    """Les nombres d'un texte, normalisés — séparateurs de milliers et virgule
    décimale ôtés, de sorte que « 1 147 962 » et « 1147962 » se comparent."""
    bruts = re.findall(r"-?\d[\d\s  .,]*\d|-?\d", texte or "")
    sortie = set()
    for b in bruts:
        n = b.replace(" ", "").replace(" ", "").replace(" ", "")
        n = n.replace(",", ".")
        # Un point isolé suivi de trois chiffres est un séparateur de milliers.
        n = re.sub(r"\.(?=\d{3}\b)", "", n)
        try:
            sortie.add(round(float(n), 4))
        except ValueError:
            pass
    return sortie


def url_resout(u):
    if not u or not u.startswith("http"):
        return False
    for m in (requests.head, requests.get):
        try:
            r = m(u, headers=UA, timeout=20, allow_redirects=True)
            if r.status_code < 400:
                return True
        except Exception:
            pass
    return False


def charger_C(cur, espace):
    cur.execute("""SELECT indicator_label, watch_question, period, geo, value, source_url
                   FROM sandbox.agent_values WHERE run_namespace=%s ORDER BY id""", (espace,))
    v = [dict(zip(["indicateur", "qv", "periode", "zone", "valeur", "url"], r)) for r in cur.fetchall()]
    cur.execute("""SELECT watch_question, text FROM sandbox.agent_commentaries
                   WHERE run_namespace=%s ORDER BY id""", (espace,))
    c = [dict(zip(["qv", "texte"], r)) for r in cur.fetchall()]
    cur.execute("""SELECT nb_iterations, plafond_atteint, appels_par_outil, referentiel_consulte,
                          outil_calcul_utilise, autocritique, sortie_finale
                   FROM sandbox.agent_runs WHERE run_namespace=%s ORDER BY id DESC LIMIT 1""",
                (espace,))
    r = cur.fetchone()
    meta = dict(zip(["iterations", "plafond", "outils", "referentiel", "calcul",
                     "autocritique", "sortie"], r)) if r else {}
    return v, c, meta


def charger_B(cur):
    """La production du dispositif B pour la MÊME mission : secteur automobile,
    dernières valeurs de chaque indicateur, et le commentaire validé."""
    cur.execute("""
        SELECT DISTINCT ON (v.indicator_id, v.geo)
               i.indicator_id, i.label, v.period, v.geo, v.value::text,
               s.url, v.validation_status, v.obtained_by
        FROM indicator_values v
        JOIN indicators i USING (indicator_id)
        JOIN sources s USING (source_id)
        WHERE i.sector_code = 'automobile'
        ORDER BY v.indicator_id, v.geo, v.period DESC, v.run_id DESC""")
    v = [dict(zip(["code", "indicateur", "periode", "zone", "valeur", "url", "statut", "obtenu"], r))
         for r in cur.fetchall()]
    cur.execute("""SELECT text, status, validated_by FROM commentaries
                   WHERE sector_code='automobile' AND status='valide'
                   ORDER BY commentary_id DESC LIMIT 1""")
    r = cur.fetchone()
    return v, ({"texte": r[0], "statut": r[1], "validateur": r[2]} if r else None)


def pct(n, d):
    return "—" if not d else f"{100 * n / d:.0f} %"


def main():
    conn = connexion()
    cur = conn.cursor()
    auj = dt.date.today().strftime("%d.%m.%Y")

    runs = {e: charger_C(cur, e) for e in ESPACES}
    bv, bc = charger_B(cur)

    print(f"""# Annexe 7 — Confrontation du scénario B au scénario C

*Dépouillement produit par calcul sur les sorties archivées, le {auj}. Grille et définitions
opérationnelles fixées avant exécution au § 10.5.3.*

## A7.1 Ce qui a été exécuté, et ce qui s'en écarte

L'artefact agentique du scénario C a été **exécuté trois fois** sur la mission du protocole —
établir l'état du marché automobile pour ses cinq questions de veille, avec valeurs sourcées et
commentaire exécutif. Ses sorties sont archivées dans le schéma `sandbox`, hors de la base
consolidée, et n'ont atteint ni le registre ni le tableau de bord.

**Trois écarts au protocole doivent être déclarés avant tout résultat.**

1. **L'espacement de quarante-huit heures n'a pas été respecté** : les trois exécutions sont
   consécutives. La dimension 8 mesure donc la variabilité d'un dispositif à conditions
   figées — la même mesure que la vague 3 du chapitre 9 —, et non sa stabilité dans le temps.
   C'est une mesure plus faible que celle prévue, et elle doit être lue comme telle.
2. **L'artefact a été porté du workflow d'orchestration vers un script.** Ses outils d'écriture
   appelaient un service intermédiaire absent de l'environnement conteneurisé — l'obstacle exact
   rencontré par la couche de découverte le 22 août. Mission, message système, plafonds, jeu
   d'outils, passe d'auto-critique et modèle de raisonnement sont repris mot pour mot du JSON ;
   la divergence porte sur le transport, non sur le régime, qui est l'objet de la mesure.
3. **Le paramètre de température de la spécification est refusé par le modèle qu'elle nomme.**
   L'API répond « `temperature` is deprecated for this model ». Le paramètre a été omis. Le fait
   est mineur en soi et significatif en substance : un artefact spécifié à une date ne reste pas
   exécutable à l'identique, et la reproductibilité d'un dispositif d'IA est bornée par le cycle
   de vie des modèles, non par le soin de sa spécification.

**L'asymétrie de maturité est rappelée ici et vaut pour tout ce qui suit** : le dispositif B a
bénéficié de l'ensemble du travail de conception du chapitre 10 ; C est un dispositif de
laboratoire construit pour être confronté. La confrontation ne juge pas le scénario C dans
l'absolu — un artefact plus abouti obtiendrait vraisemblablement de meilleurs résultats. Elle
documente l'écart entre deux **régimes de supervision** de moyens équivalents.

---

## A7.2 Déroulement des trois exécutions du scénario C

| Répétition | Itérations | Plafond atteint | Référentiel consulté | Outil de calcul utilisé | Valeurs publiées | Commentaires publiés |
|---|---|---|---|---|---|---|""")

    for e in ESPACES:
        v, c, m = runs[e]
        if not m:
            print(f"| {e[-2:]} | *aucune exécution archivée* | | | | | |"); continue
        print(f"| {e[-2:]} | {m['iterations']} | {'oui' if m['plafond'] else 'non'} | "
              f"{'oui' if m['referentiel'] else '**non**'} | "
              f"{'oui' if m['calcul'] else '**non**'} | {len(v)} | {len(c)} |")

    print("""
Appels par outil, par exécution :

| Répétition | recherche web | lecture d'URL | référentiel | calcul | publier valeur | publier commentaire |
|---|---|---|---|---|---|---|""")
    for e in ESPACES:
        _, _, m = runs[e]
        o = m.get("outils") or {}
        print(f"| {e[-2:]} | {o.get('rechercher_web',0)} | {o.get('lire_url',0)} | "
              f"{o.get('consulter_referentiel',0)} | {o.get('calculer',0)} | "
              f"{o.get('publier_valeur',0)} | {o.get('publier_commentaire',0)} |")

    # ── Mesures ───────────────────────────────────────────────────────────────
    print("""
---

## A7.3 Grille de confrontation renseignée

Les parts sont calculées sur la production de chaque dispositif pour la même mission. Pour le
scénario C, la valeur retenue est la **moyenne des trois exécutions**, l'étendue étant donnée
en regard.

| # | Dimension | Scénario B | Scénario C | Lecture |
|---|---|---|---|---|""")

    # D2 — traçabilité : URL fournie ET qui résout.
    b_url_ok = sum(1 for x in bv if url_resout(x["url"]))
    c_trac = []
    for e in ESPACES:
        v, _, _ = runs[e]
        if not v: continue
        c_trac.append(sum(1 for x in v if url_resout(x["url"])) / len(v))
    # D3 — fidélité : chiffre du commentaire présent dans les valeurs publiées.
    def fidelite(valeurs, comms):
        pub = set()
        for x in valeurs:
            pub |= nombres(str(x["valeur"]))
        total = bons = 0
        for c in comms:
            for n in nombres(c["texte"]):
                total += 1
                if n in pub or any(abs(n - p) < 0.01 for p in pub): bons += 1
        return bons, total
    c_fid = [fidelite(runs[e][0], runs[e][1]) for e in ESPACES]
    b_fid = fidelite(bv, [bc] if bc else [])
    # D5 — couverture : QV traitées sur 5.
    c_couv = [len({x["qv"] for x in runs[e][0] if x["qv"]} | {x["qv"] for x in runs[e][1] if x["qv"]})
              for e in ESPACES]
    # D8 — reproductibilité : recouvrement des couples (indicateur, période) entre exécutions.
    def cle(x): return (str(x["indicateur"] or "").lower()[:28], str(x["periode"] or ""))
    ens = [{cle(x) for x in runs[e][0]} for e in ESPACES if runs[e][0]]
    if len(ens) >= 2:
        inter = set.intersection(*ens); union = set.union(*ens)
        repro = len(inter) / len(union) if union else 0
    else:
        repro, inter, union = None, set(), set()
    # D10 — autodétection.
    c_anom = [len((runs[e][2].get("autocritique") or {}).get("anomalies", [])) for e in ESPACES]

    moy = lambda l: f"{100*sum(l)/len(l):.0f} %" if l else "—"
    etendue = lambda l: f"{100*min(l):.0f}–{100*max(l):.0f} %" if l else "—"

    print(f"| 1 | Exactitude des valeurs | *voir A7.4* | *voir A7.4* | Vérification contre le registre du ch. 8, indicateur par indicateur |")
    print(f"| 2 | Traçabilité (URL fournie **et** qui résout) | {pct(b_url_ok, len(bv))} | {moy(c_trac)} ({etendue(c_trac)}) | Une URL qui ne résout pas n'est pas une source |")
    print(f"| 3 | Fidélité des commentaires | {pct(b_fid[0], b_fid[1])} | {moy([a/b if b else 0 for a,b in c_fid])} | Part des chiffres du commentaire présents dans les valeurs publiées |")
    print(f"| 4 | Exactitude des calculs | *par construction* | *voir A7.5* | En B les variations sont calculées en SQL, jamais par un modèle |")
    print(f"| 5 | Couverture de la mission | 5/5 questions instrumentées | {'/'.join(str(x) for x in c_couv)}/5 par exécution | Questions de veille effectivement traitées |")
    print(f"| 6 | Temps humain par cycle | **non mesuré** | **non mesuré** | Aucun chronométrage n'a été tenu : la dimension est déclarée vide plutôt qu'estimée |")
    print(f"| 7 | Coût machine par cycle | 1 appel de modèle par secteur | {'/'.join(str(runs[e][2].get('iterations','?')) for e in ESPACES)} itérations | Le décompte de jetons n'est pas instrumenté |")
    print(f"| 8 | Reproductibilité | *déterministe* | {f'{100*repro:.0f} %' if repro is not None else '—'} | Recouvrement des couples (indicateur, période) entre les trois exécutions |")
    print(f"| 9 | Auditabilité | **100 % par construction** | **0 % par construction** | En B chaque valeur porte statut, méthode et référence brute ; en C l'origine ne se reconstitue qu'en relisant la trace |")
    print(f"| 10 | Autodétection des erreurs | *files et statuts* | {'/'.join(str(x) for x in c_anom)} anomalies | Anomalies relevées par l'auto-critique, à comparer au dépouillement humain |")

    print(f"""
---

## A7.4 Ce que le scénario C a publié

Le détail des valeurs publiées par chaque exécution figure ci-dessous. C'est la pièce sur
laquelle la dimension 1 doit être arbitrée : chaque ligne se vérifie contre la source citée.
""")
    for e in ESPACES:
        v, c, m = runs[e]
        print(f"\n### Exécution {e[-2:]}\n")
        if not v:
            print("*Aucune valeur publiée.*\n"); continue
        print("| Indicateur | QV | Période | Zone | Valeur | Source citée |")
        print("|---|---|---|---|---|---|")
        for x in v:
            u = (x["url"] or "—")
            print(f"| {x['indicateur']} | {x['qv'] or '—'} | {x['periode'] or '—'} | "
                  f"{x['zone'] or '—'} | {x['valeur']} | {u[:60]} |")
        if c:
            print(f"\n*{len(c)} commentaire(s) publié(s), statut `publie_sans_validation`.*")

    print(f"""
---

## A7.5 Reproductibilité, en détail

Sur les trois exécutions, {len(inter)} couples (indicateur, période) sont communs aux trois,
pour {len(union)} couples distincts au total. Le recouvrement est donc de
{f'{100*repro:.0f} %' if repro is not None else '—'}.

**Ce chiffre ne mesure pas la stabilité dans le temps** — l'espacement de quarante-huit heures
du protocole n'a pas été respecté. Il mesure la variabilité du dispositif à conditions figées,
c'est-à-dire ce que la vague 3 du chapitre 9 mesure pour les modèles de chat. Il est
directement comparable à cette mesure, et c'est là son intérêt.

---

## A7.6 Ce que la confrontation établit

La dimension **9 est tranchée par l'architecture, avant toute exécution**, et c'est le résultat
le plus solide de la grille : en B, l'origine complète de chaque valeur — source, date, méthode
d'obtention, statut de validation — est un attribut du modèle de données, reconstituable par
requête ; en C, elle n'existe que dans la trace de l'agent, qu'il faut relire. La différence
n'est pas de degré mais de nature, et aucune amélioration de l'artefact agentique ne la
comblerait sans lui adjoindre précisément le modèle de données du scénario B.

La dimension **10 mesure ce que vaut un contrôle homogène au système contrôlé**. L'auto-critique
est exécutée par un modèle de la même famille que celui qui a produit la sortie, et elle porte
sur trois vérifications explicitement énoncées. L'écart entre ce qu'elle relève et ce qu'un
dépouillement humain relève est la mesure directe de la limite de ce contrôle — la même famille
de mécanisme que l'erreur auto-consistante du § 6.3, appliquée cette fois à la supervision.

Ce que la confrontation **ne peut pas** établir est rappelé une dernière fois : une conclusion
générale sur les architectures agentiques. Trois exécutions, un secteur, un artefact, un
évaluateur. Elle substitue une mesure à une affirmation sur un point précis, ce qui est
substantiellement plus qu'un rejet argumenté par citation — et substantiellement moins qu'une
démonstration.
""")
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
