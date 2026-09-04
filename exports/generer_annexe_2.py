#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génération de l'annexe 2 — prompts documentés. TB Castillo, 24.08.2026.

POURQUOI GÉNÉRER PLUTÔT QUE RECOPIER. Un prompt recopié à la main dans une
annexe diverge du prompt exécuté dès la première correction — et c'est
précisément ce que le travail reproche aux décomptes d'indicateurs. Ici les
prompts sont EXTRAITS des fichiers qui tournent : workflows n8n et scripts
Python. L'annexe ne peut donc pas mentir sur ce que le dispositif demande
réellement aux modèles.

Usage (depuis prototype/) :
    python3 exports/generer_annexe_2.py > ../annexes/2_prompts_documentes.md
"""

import ast
import datetime as dt
import json
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent

# Inventaire DÉCLARÉ, non deviné : chaque entrée dit où chercher et pourquoi
# ce prompt existe. Un prompt qu'on oublierait d'inscrire ici manquerait à
# l'annexe — la liste est donc à tenir, et c'est assumé.
#
# 03.09.2026 : inventaire réaligné sur les chaînes qui appellent un modèle
# (relevé par lecture des nœuds HTTP des 22 fichiers). Ajoutés : CP, A1 (CCFA),
# événements, lecture transversale, triage IA, attribution ancrée, lecture
# décisionnelle (portée du script au workflow le 25.08). `veille_documentaire_
# annuelle` n'appelle aucun modèle — détecter n'est pas lire — et n'a donc
# rien à donner ici ; il figure à l'annexe 4.
WORKFLOWS = [
    ("analyse_tendances_alertes.json", ["Préparer les charges"],
     "Commentaire exécutif",
     "Produit le texte affiché en tête de chaque vue sectorielle. Il porte les "
     "règles d'interprétation RI0 à RI10 et impose l'ordre « réponse d'abord, "
     "méthode en dernier ». Sortie stockée avec son statut ; depuis le 31.08.2026, "
     "servie avec ce statut et badgée à l'écran, la relecture humaine étant un "
     "audit a posteriori (§ 12.5)."),
    ("extraction_composite_A2.json", ["Consolider le contexte"],
     "Extraction composite (A2, immatriculations ACEA)",
     "Extrait une valeur chiffrée d'un communiqué PDF converti en texte. Trois "
     "modèles reçoivent le même prompt ; leur consensus exact route la valeur, leur "
     "désaccord la renvoie en validation humaine."),
    ("extraction_composite_CP.json", ["Préparer la charge"],
     "Extraction composite par la voie multimodale (H2 emplois, H11 entreprises ; "
     "Convention patronale)",
     "Le PDF est joint à la requête tel quel, sans conversion en texte : le "
     "tableau y est lu par le modèle. Trois modèles, consensus, file de validation "
     "humaine. Démontré sur le run 167 (§ 11.16)."),
    ("extraction_composite_A1_ccfa.json", ["Préparer la charge"],
     "Extraction composite A1 (annuaire CCFA, republication OICA)",
     "La section statistique est découpée par sentinelles avant l'envoi — environ "
     "1 % du document soumis (5 100 caractères sur ~530 000, mesuré sur les exécutions du "
     "31.08.2026 ; corrigé de 2,5 % le 04.09). Consensus à trois modèles, confrontation "
     "opportuniste à la source OICA, recouvrement entre éditions (§ 11.16)."),
    ("extraction_signal_qualitatif.json", ["Consolider le contexte"],
     "Extraction de signal qualitatif",
     "Qualifie un acte réglementaire ou un événement en signal daté et attribuable. "
     "Régime propre à cette table : la sortie n'atteint aucun écran sans validation "
     "humaine nominative (point de lecture `veille/signaux`)."),
    ("triage_ia_flux.json", ["Préparer les lots"],
     "Triage assisté par IA des items de flux (deux doctrines)",
     "Deux consignes coexistent, « événement » et « signal » ; chaque item est trié "
     "sous les deux et l'écart entre elles est lui-même une mesure. Le triage "
     "alimente le filtrage à seuil et la file d'examen humain."),
    ("extraction_evenements_flux.json", ["Mettre en lots"],
     "Événements typés depuis le titre des items",
     "Modèle unique, régime du triage, vocabulaire fermé — huit types, trois sens. "
     "Les événements sont écrits `non_relu` et servis avec ce statut ; l'éligibilité "
     "à cette lecture est déclarée par source."),
    ("lecture_transversale.json", ["Composer les faits"],
     "Lectures transversales sous génération contrainte",
     "Les faits sont composés par le code — le premier littéral est le gabarit "
     "d'un fait — et le modèle ne voit que cette liste numérotée : aucun chiffre "
     "autorisé dans l'énoncé, citation des faits obligatoire. Démontré sur le "
     "run 194 ; sorties servies avec leur statut."),
    ("lecture_decision_ted.json", ["Préparer les lots"],
     "Lecture décisionnelle des marchés publics",
     "Le profil déclare le métier de l'entreprise en clair ; la question, "
     "invariante, demande si l'appel est exécutable et quel geste faire. Consigne "
     "reprise mot pour mot du script `etage2/lecture_decision_ted.py` qu'elle "
     "remplace depuis le 25.08.2026 : la sensibilité du verdict au profil est "
     "mesurée au § 11.8, et toute retouche invaliderait cette mesure."),
    ("decouverte_sources_multi_ia.json", ["Cadrer le besoin de veille"],
     "Découverte de sources (couche 0)",
     "Cadre le besoin à partir d'une question de veille du référentiel, puis "
     "interroge quatre modèles avec recherche web. Le nœud concatène à l'envoi le "
     "besoin, le secteur, le périmètre et les critères d'admissibilité déclarés "
     "dans le même nœud. Les candidats sont déposés en file de qualification, "
     "jamais inscrits au référentiel."),
    ("attribution_ancree_medical.json", ["Préparer les charges"],
     "Attribution ancrée (démonstration, § 12.3)",
     "Variante du commentaire exécutif dont chaque phrase causale doit s'ancrer sur "
     "un fait fourni. Démonstration hors production : écrit dans le schéma de bac à "
     "sable, aucune sortie servie."),
]
# 02.09.2026 (A10) : le scénario C ne figure plus ici. La maquette n8n
# `scenario_c_agent_autonome.json` n'a jamais été importée ni exécutée (archivée
# sous n8n_workflows/archive/squelettes_2026-08-04/ le 02.09, A9) ; les prompts
# réellement envoyés lors de la confrontation B/C (§ 10.5) sont ceux du script
# scenario_c/agent_autonome.py, extraits ci-dessous avec les scripts.

# 03.09.2026 : `etage2/lecture_decision_ted.py` n'est plus au dépôt — porté en
# workflow le 25.08, sa consigne est extraite ci-dessus depuis le JSON.
SCRIPTS = [
    ("etage2/sensibilite_profil.py", ["PROFILS"],
     "Profils alternatifs (mesure de sensibilité)",
     "Deux profils dégradés — l'un sans liste d'exclusion, l'autre sans mise en "
     "situation — lus sur le même corpus avec la même question, pour chiffrer ce "
     "que le profil décide à lui seul."),
    ("scenario_c/agent_autonome.py", ["MISSION", "MESSAGE_SYSTEME", "CONSIGNE_AUTOCRITIQUE"],
     "Agent autonome (scénario C, confrontation expérimentale)",
     "Construit pour être CONFRONTÉ au scénario B, non pour être déployé. "
     "L'auto-critique y remplace la validation humaine — c'est le point exact que "
     "la confrontation devait mettre à l'épreuve. Prompts repris mot pour mot de "
     "la maquette n8n archivée, qui n'a elle-même jamais été exécutée."),
]

LONGUEUR_MIN = 200


def lisible(texte):
    """Un « \\n » écrit dans un littéral JavaScript se lit comme deux caractères,
    pas comme un saut de ligne : reproduit tel quel, le prompt devient illisible
    et l'annexe trahit sa propre exigence de lisibilité."""
    return (texte.replace("\\n", "\n").replace("\\t", "\t")
                 .replace('\\"', '"').replace("\\'", "'").replace("\\\\", "\\").strip())


def litteraux_js(code):
    """Chaînes littérales d'un source JavaScript, dans l'ordre, commentaires et
    expressions régulières exclus.

    03.09.2026 — remplace l'extraction par expression régulière du 24.08. Celle-ci
    cherchait « une chaîne de 200 caractères ou plus entre deux guillemets » et
    attrapait, quand deux chaînes courtes se suivaient, LE CODE ENTRE ELLES :
    l'annexe du 02.09 reproduisait pour la couche 0 un fragment de nœud au lieu
    du prompt. Un accent grave dans un commentaire produisait le même artefact
    (CP). Ici le source est parcouru caractère par caractère : seuls les
    littéraux ouverts hors commentaire sont retenus, les `${…}` d'un gabarit
    restent dans leur littéral."""
    sorties, i, n, precedent = [], 0, len(code), ""
    while i < n:
        c = code[i]
        if c == "/" and code.startswith("//", i):
            j = code.find("\n", i); i = n if j < 0 else j; continue
        if c == "/" and code.startswith("/*", i):
            j = code.find("*/", i + 2); i = n if j < 0 else j + 2; continue
        if c == "/" and precedent in "(,=:[!&|?{};+-*%<>~^":
            # Littéral d'expression régulière : on le saute, il peut contenir
            # des guillemets ou des accents graves qui ne délimitent rien.
            j, classe = i + 1, False
            while j < n and code[j] != "\n":
                if code[j] == "\\": j += 2; continue
                if code[j] == "[": classe = True
                elif code[j] == "]": classe = False
                elif code[j] == "/" and not classe: break
                j += 1
            i, precedent = j + 1, "/"; continue
        if c in "\"'`":
            j, profondeur, tampon = i + 1, 0, []
            while j < n:
                ch = code[j]
                if ch == "\\":
                    tampon.append(code[j:j + 2]); j += 2; continue
                if c == "`":
                    if ch == "$" and code.startswith("${", j):
                        profondeur += 1; tampon.append("${"); j += 2; continue
                    if profondeur and ch == "{":
                        profondeur += 1
                    elif profondeur and ch == "}":
                        profondeur -= 1; tampon.append(ch); j += 1; continue
                if ch == c and profondeur == 0:
                    break
                tampon.append(ch); j += 1
            sorties.append("".join(tampon)); i, precedent = j + 1, c; continue
        if not c.isspace():
            precedent = c
        i += 1
    return sorties


# Un littéral long n'est pas forcément un prompt : un gabarit SQL, un message
# d'erreur composé, un objet sérialisé le sont aussi. On écarte ce qui porte
# les marques du code, jamais ce qui porte celles de la langue.
MARQUES_CODE = re.compile(
    r"\b(const|let|var|return|function|throw|await|typeof)\b|=>|\$input|\$\(|\bjson:|\.length\b|\bSELECT\b")


def est_prompt(texte):
    return len(texte) >= LONGUEUR_MIN and not MARQUES_CODE.search(texte)


def prompts_du_workflow(chemin, noms):
    d = json.loads(chemin.read_text(encoding="utf-8"))
    sorties = []
    for n in d.get("nodes", []):
        if n["name"] not in noms:
            continue
        p = n.get("parameters", {})
        source = p.get("jsCode") or json.dumps(p, ensure_ascii=False)
        # Les prompts sont portés par des littéraux des nœuds Code. On garde TOUS
        # les littéraux longs du nœud et non le premier : un prompt suivi d'un
        # schéma interpolé serait sinon tronqué à l'endroit exact où il devient
        # intéressant. 02.09.2026 (A10) : les échappements JSON sont résolus par
        # json.loads ; seuls les « \n » du source JavaScript restent, traités par
        # lisible() — l'ancien décodage unicode_escape produisait du mojibake.
        for b in litteraux_js(source):
            if est_prompt(b):
                sorties.append((n["name"], lisible(b)))
    return sorties


def prompts_du_script(chemin, noms):
    arbre = ast.parse(chemin.read_text(encoding="utf-8"))
    sorties = []
    for n in ast.walk(arbre):
        if not isinstance(n, ast.Assign):
            continue
        for c in n.targets:
            if isinstance(c, ast.Name) and c.id in noms:
                v = n.value
                if isinstance(v, ast.Constant) and isinstance(v.value, str):
                    sorties.append((c.id, v.value.strip()))
                elif isinstance(v, ast.Dict):
                    for k, val in zip(v.keys, v.values):
                        if isinstance(val, ast.Constant) and isinstance(val.value, str):
                            cle = k.value if isinstance(k, ast.Constant) else "?"
                            sorties.append((f"{c.id}[{cle}]", val.value.strip()))
    return sorties


def main():
    auj = dt.date.today().strftime("%d.%m.%Y")
    print(f"""# Annexe 2 — Prompts documentés

*Annexe produite par extraction directe des fichiers en service, le {auj}.*

**Les prompts ne sont pas recopiés ici, ils en sont extraits.** Un prompt recopié à la main
diverge du prompt exécuté dès la première correction ; c'est le mécanisme même qui avait produit
quatre décomptes d'indicateurs contradictoires dans le corps du rapport. Cette annexe est donc
une projection des fichiers `n8n_workflows/*.json`, `etage2/*.py` et `scenario_c/*.py` du dépôt,
régénérable par `python3 exports/generer_annexe_2.py`. Toute divergence entre cette annexe et le
dispositif signale une annexe périmée, jamais un prompt inconnu.

**Les expressions entre doubles accolades, ou de la forme `${{…}}`**, sont des interpolations de
l'orchestrateur ou du script : elles sont remplacées à l'exécution par les valeurs lues en base —
libellé de l'indicateur, période, mécanisme causal de la question de veille, faits calculés. Le
prompt réellement envoyé au modèle est donc toujours plus long que le gabarit reproduit ici, et
son contenu variable est tracé dans la charge d'entrée conservée avec chaque sortie.

**Périmètre.** Sont inventoriés les workflows dont un nœud appelle un fournisseur de modèle ;
les workflows sans appel de modèle — collecte, détection d'éditions, dérivation, clôture des
erreurs — n'ont pas de prompt et figurent à l'annexe 4 seulement.
""")

    print("\n---\n\n## A2.1 Prompts portés par les workflows d'orchestration\n")
    for fichier, noeuds, titre, motif in WORKFLOWS:
        chemin = RACINE / "n8n_workflows" / fichier
        if not chemin.exists():
            print(f"### {titre}\n\n*Fichier `{fichier}` absent du dépôt.*\n"); continue
        blocs = prompts_du_workflow(chemin, noeuds)
        print(f"### {titre}\n")
        print(f"*Fichier : `n8n_workflows/{fichier}`. {motif}*\n")
        if not blocs:
            print("*Aucun littéral de prompt extrait — nœud à inscrire dans l'inventaire.*\n")
        for nom, texte in blocs:
            print(f"**Nœud « {nom} »**\n")
            print("```text")
            print(texte)
            print("```\n")

    print("\n---\n\n## A2.2 Prompts portés par les scripts hors orchestrateur (mesure de sensibilité, scénario C)\n")
    for fichier, noms, titre, motif in SCRIPTS:
        chemin = RACINE / fichier
        if not chemin.exists():
            print(f"### {titre}\n\n*Fichier `{fichier}` absent du dépôt.*\n"); continue
        print(f"### {titre}\n")
        print(f"*Fichier : `{fichier}`. {motif}*\n")
        for nom, texte in prompts_du_script(chemin, noms):
            print(f"**Constante `{nom}`**\n")
            print("```text")
            print(texte)
            print("```\n")

    print("""
---

## A2.3 Ce que cette annexe ne contient pas

Les prompts du **protocole multi-IA** (chapitre 9) ne figurent pas ici : ils appartiennent au
protocole expérimental et non au dispositif, et sont reproduits avec leurs conditions
d'exécution en annexe 3, où ils sont indissociables des grilles de dépouillement qu'ils ont
produites.

Les **consignes système** implicites des fournisseurs — celles que chaque éditeur applique en
amont sans les publier — ne sont par définition pas extractibles. Leur existence est une limite
de reproductibilité du travail : deux exécutions identiques à des dates différentes peuvent
diverger sans que rien dans cette annexe n'ait changé. Le chapitre 9 en fait la mesure.
""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
