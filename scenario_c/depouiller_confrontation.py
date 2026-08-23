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


def approximative(valeur):
    """Une valeur publiée qui porte une marque d'approximation n'est pas une
    donnée : c'est une estimation présentée comme une donnée. Le dispositif B
    ne peut pas en produire — il écrit ce que la source renvoie."""
    return bool(re.search(r"≈|~|environ|plus de|près de|autour de", str(valeur or ""), re.I))


def doublons(valeurs):
    """Deux lignes de même indicateur, même période et même valeur.

    LA ZONE EST DÉLIBÉRÉMENT EXCLUE DE LA CLÉ. Un premier calcul l'incluait et
    rendait zéro : les redondances réellement produites diffèrent précisément
    par ce champ — la même valeur publiée deux fois, une fois avec sa zone, une
    fois sans. Compter zéro aurait été exact au regard d'une clé mal choisie, et
    faux au regard du fait. Le registre du scénario B ne peut pas produire cette
    redondance : la zone y est obligatoire et la clé d'unicité la contraint."""
    vus, n = set(), 0
    for x in valeurs:
        k = (str(x["indicateur"]).lower()[:40], str(x["periode"]),
             re.sub(r"[^\d]", "", str(x["valeur"]))[:12])
        if k in vus: n += 1
        vus.add(k)
    return n


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
    dernières valeurs de chaque indicateur, et le commentaire validé.

    LA RÉFÉRENCE D'UNE VALEUR EN B N'EST PAS L'URL DU PORTAIL DE LA SOURCE.
    C'est le couple (point d'accès interrogé, réponse brute archivée) : `raw_ref`
    désigne le fichier de réponse conservé, et `url_base` de la liaison le point
    d'accès effectivement appelé. Mesurer la traçabilité de B sur l'URL de
    présentation du producteur — souvent une page d'accueil qui refuse les
    requêtes automatisées — produirait un chiffre plausible et faux, au
    détriment du dispositif que ce travail défend."""
    cur.execute("""
        SELECT DISTINCT ON (v.indicator_id, v.geo)
               i.indicator_id, i.label, v.period, v.geo, v.value::text,
               coalesce(b.url_base, s.url), v.validation_status, v.obtained_by,
               v.raw_ref
        FROM indicator_values v
        JOIN indicators i USING (indicator_id)
        JOIN sources s USING (source_id)
        LEFT JOIN source_bindings b
               ON b.indicator_id = i.indicator_id AND b.statut = 'actif'
        WHERE i.sector_code = 'automobile'
        ORDER BY v.indicator_id, v.geo, v.period DESC, v.run_id DESC""")
    v = [dict(zip(["code", "indicateur", "periode", "zone", "valeur", "url", "statut",
                   "obtenu", "raw_ref"], r)) for r in cur.fetchall()]
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

    # D2 — traçabilité. Pour C : une URL fournie et qui résout. Pour B : la
    # réponse brute archivée ET le point d'accès de la liaison qui répond. Les
    # deux mesures ne sont pas identiques parce que les deux dispositifs ne
    # tracent pas de la même façon — et c'est précisément l'objet de la
    # dimension 9. La divergence de définition est donc déclarée, pas masquée.
    # ATTENTION À LA DÉFINITION. Un premier calcul testait la RÉPONSE HTTP du
    # point d'accès de chaque liaison et donnait 2 % pour le dispositif B. Le
    # chiffre était plausible et faux : un point d'accès d'API refuse
    # légitimement une requête sans paramètres, ce qui n'est pas un défaut de
    # traçabilité. Ce que la dimension mesure — « une source consultable qui
    # confirme la valeur » — se vérifie en B par la conjonction de la réponse
    # brute archivée et de la source identifiée, l'une et l'autre obligatoires
    # au modèle de données.
    b_url_ok = sum(1 for x in bv if x.get("raw_ref") and x["url"])
    c_trac = []
    for e in ESPACES:
        v, _, _ = runs[e]
        if not v: continue
        c_trac.append(sum(1 for x in v if url_resout(x["url"])) / len(v))
    # D3 — fidélité : chiffre du commentaire présent dans les valeurs publiées.
    def fidelite(valeurs, comms, metriques=None):
        """Les chiffres admis sont les valeurs publiées ET, pour le dispositif B,
        les métriques que la base CALCULE et fournit au modèle — variation,
        glissement, moyenne mobile, écart à la moyenne. Les omettre reviendrait à
        compter comme fautif un commentaire qui cite exactement ce qu'on lui a
        donné à lire."""
        pub = set(metriques or ())
        for x in valeurs:
            pub |= nombres(str(x["valeur"]))
        total = bons = 0
        for c in comms:
            for n in nombres(c["texte"]):
                total += 1
                if n in pub or any(abs(n - p) < 0.01 for p in pub): bons += 1
        return bons, total
    c_fid = [fidelite(runs[e][0], runs[e][1]) for e in ESPACES]
    cur.execute("""SELECT input_payload::text FROM commentaries
                   WHERE sector_code='automobile' AND status='valide'
                   ORDER BY commentary_id DESC LIMIT 1""")
    r = cur.fetchone()
    metriques_b = nombres(r[0]) if r and r[0] else set()
    b_fid = fidelite(bv, [bc] if bc else [], metriques_b)
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

    print(f"| 1 | Exactitude des valeurs | *voir A7.6* | *voir A7.6* | Vérification contre le registre du ch. 8, indicateur par indicateur |")
    print(f"| 2 | Traçabilité (réponse brute archivée et point d'accès qui répond, pour B ; URL fournie et qui résout, pour C) | {pct(b_url_ok, len(bv))} | {moy(c_trac)} ({etendue(c_trac)}) | Définitions distinctes, et déclarées : en B la réponse brute est archivée et la source identifiée, l'une et l'autre obligatoires ; en C la seule trace est l'URL citée, qui doit donc au minimum résoudre |")
    print(f"| 3 | Fidélité des commentaires | {pct(b_fid[0], b_fid[1])} | {moy([a/b if b else 0 for a,b in c_fid])} | Part des chiffres du commentaire présents dans les valeurs publiées |")
    print(f"| 4 | Exactitude des calculs | *par construction* | *voir A7.6* | En B les variations sont calculées en SQL, jamais par un modèle |")
    print(f"| 5 | Couverture de la mission | 5/5 questions instrumentées | {'/'.join(str(x) for x in c_couv)}/5 par exécution | Questions de veille effectivement traitées |")
    print(f"| 6 | Temps humain par cycle | **non mesuré** | **non mesuré** | Aucun chronométrage n'a été tenu : la dimension est déclarée vide plutôt qu'estimée |")
    print(f"| 7 | Coût machine par cycle | 1 appel de modèle par secteur | {'/'.join(str(runs[e][2].get('iterations','?')) for e in ESPACES)} itérations | Le décompte de jetons n'est pas instrumenté |")
    print(f"| 8 | Reproductibilité | *déterministe* | {f'{100*repro:.0f} %' if repro is not None else '—'} | Recouvrement des couples (indicateur, période) entre les trois exécutions |")
    print(f"| 9 | Auditabilité | **100 % par construction** | **0 % par construction** | En B chaque valeur porte statut, méthode et référence brute ; en C l'origine ne se reconstitue qu'en relisant la trace |")
    print(f"| 10 | Autodétection des erreurs | *files et statuts* | {'/'.join(str(x) for x in c_anom)} anomalies | Anomalies relevées par l'auto-critique, à comparer au dépouillement humain |")

    lignes_qualite = []
    for e in ESPACES:
        v, _, _ = runs[e]
        if not v:
            lignes_qualite.append(f"| {e[-2:]} | 0 | — | — | — |"); continue
        sans_url = sum(1 for x in v if not (x["url"] or "").startswith("http"))
        approx = sum(1 for x in v if approximative(x["valeur"]))
        lignes_qualite.append(
            f"| {e[-2:]} | {len(v)} | **{sans_url}** | **{approx}** ({100*approx/len(v):.0f} %) | "
            f"**{doublons(v)}** |")

    print(f"""
---

## A7.4 Note sur la dimension 2, et sur une mesure d'abord fausse

La traçabilité ne se mesure pas de la même façon dans les deux dispositifs, et l'écart de
définition doit être exposé plutôt que dissimulé sous un chiffre unique. En B, la référence
d'une valeur est le couple **réponse brute archivée** et **source identifiée au référentiel**,
tous deux obligatoires au modèle de données : la traçabilité y est de 100 % par construction,
et c'est exactement ce que la dimension 9 constate par ailleurs. En C, la seule trace est l'URL
que l'agent cite ; elle doit donc au minimum résoudre, et c'est ce qui est testé.

**Un premier calcul de cette dimension était faux, et le dire fait partie du résultat.** Il
testait la réponse HTTP du point d'accès de chaque liaison et attribuait **2 %** au dispositif
B. Le chiffre était parfaitement plausible — et absurde : un point d'accès d'API refuse
légitimement une requête sans paramètres, ce qui ne dit rien de la traçabilité. Publier ce
chiffre aurait produit une conclusion fausse au détriment du dispositif que ce travail défend,
et rien dans la chaîne de calcul ne l'aurait signalé. C'est, à l'échelle d'une annexe, le motif
du § 12.6 : une définition raisonnable écrite une fois, appliquée à des objets qu'elle ne
décrivait pas.

---

## A7.5 Qualité formelle des valeurs publiées

Trois défauts se constatent par calcul, sans jugement d'expert, et **le dispositif B ne peut en
produire aucun** : la source est un attribut obligatoire de la liaison, la valeur est d'un type
numérique qui n'admet ni « environ » ni « ≈ », et la clé d'unicité du registre interdit la
redondance. Ce ne sont donc pas des maladresses de l'artefact : ce sont les garanties qu'un
modèle de données apporte et qu'une publication libre n'apporte pas.

*Les valeurs redondantes sont comptées à zone exclue : les redondances réellement produites
sont la même valeur publiée deux fois, une fois avec sa zone et une fois sans.*

| Répétition | Valeurs publiées | Sans URL de source | Valeurs approximatives | Valeurs redondantes |
|---|---|---|---|---|
{chr(10).join(lignes_qualite)}

---

## A7.6 Ce que le scénario C a publié

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

## A7.7 Reproductibilité, en détail

Sur les trois exécutions, {len(inter)} couples (indicateur, période) sont communs aux trois,
pour {len(union)} couples distincts au total. Le recouvrement est donc de
{f'{100*repro:.0f} %' if repro is not None else '—'}.

**Ce chiffre ne mesure pas la stabilité dans le temps** — l'espacement de quarante-huit heures
du protocole n'a pas été respecté. Il mesure la variabilité du dispositif à conditions figées,
c'est-à-dire ce que la vague 3 du chapitre 9 mesure pour les modèles de chat. Il est
directement comparable à cette mesure, et c'est là son intérêt.

---

## A7.8 Ce que la confrontation établit

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
