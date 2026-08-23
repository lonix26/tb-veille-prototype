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
WORKFLOWS = [
    ("analyse_tendances_alertes.json", ["Préparer les charges"],
     "Commentaire exécutif",
     "Produit le texte affiché en tête de chaque vue sectorielle. C'est le seul "
     "prompt dont la sortie atteint le décideur en langage naturel ; il porte les "
     "règles d'interprétation RI0 à RI10 et impose l'ordre « réponse d'abord, "
     "méthode en dernier »."),
    ("extraction_composite_A2.json", ["Consolider le contexte"],
     "Extraction composite (A2, immatriculations ACEA)",
     "Extrait une valeur chiffrée d'un communiqué PDF. Trois modèles reçoivent le "
     "même prompt ; leur consensus exact route la valeur, leur désaccord la renvoie "
     "en validation humaine."),
    ("extraction_signal_qualitatif.json", ["Consolider le contexte"],
     "Extraction de signal qualitatif",
     "Qualifie un acte réglementaire ou un événement en signal daté et attribuable. "
     "La sortie n'atteint aucun écran sans validation humaine nominative."),
    ("decouverte_sources_multi_ia.json", ["Cadrer le besoin de veille"],
     "Découverte de sources (couche 0)",
     "Cadre le besoin à partir d'une question de veille du référentiel, puis "
     "interroge quatre modèles avec recherche web. Les candidats sont déposés en "
     "file de qualification, jamais inscrits au référentiel."),
    ("scenario_c_agent_autonome.json", ["Agent de veille autonome",
                                        "Auto-critique (substitut de la validation humaine)"],
     "Artefact agentique (scénario C, non retenu)",
     "Construit pour être CONFRONTÉ au scénario B, non pour être déployé. "
     "L'auto-critique y remplace la validation humaine — c'est le point exact que "
     "la confrontation devait mettre à l'épreuve."),
]

SCRIPTS = [
    ("etage2/lecture_decision_ted.py", ["PROFIL", "QUESTION"],
     "Lecture décisionnelle des marchés publics",
     "Le profil déclare le métier de l'entreprise en clair ; la question, "
     "invariante, demande si l'appel est exécutable et quel geste faire. La "
     "sensibilité du verdict au profil est mesurée au § 11.8."),
    ("etage2/sensibilite_profil.py", ["PROFILS"],
     "Profils alternatifs (mesure de sensibilité)",
     "Deux profils dégradés — l'un sans liste d'exclusion, l'autre sans mise en "
     "situation — lus sur le même corpus avec la même question, pour chiffrer ce "
     "que le profil décide à lui seul."),
]


def lisible(texte):
    """Un « \\n » écrit dans un littéral JSON se lit comme deux caractères, pas
    comme un saut de ligne : reproduit tel quel, le prompt devient illisible et
    l'annexe trahit sa propre exigence de lisibilité."""
    return (texte.replace("\\n", "\n").replace("\\t", "\t")
                 .replace('\\"', '"').replace("\\\\", "\\").strip())


def prompts_du_workflow(chemin, noms):
    d = json.loads(chemin.read_text())
    sorties = []
    for n in d.get("nodes", []):
        if n["name"] not in noms:
            continue
        p = n.get("parameters", {})
        brut = p.get("jsCode") or json.dumps(p, ensure_ascii=False)
        # Les prompts sont portés par des littéraux de gabarit dans les nœuds Code.
        # On prend TOUS les blocs longs et non le premier : un prompt suivi d'un
        # schéma interpolé serait sinon tronqué à l'endroit exact où il devient
        # intéressant.
        blocs = re.findall(r"`((?:[^`\\]|\\.){200,})`", brut)
        if not blocs:
            blocs = re.findall(r'"((?:[^"\\]|\\.){200,})"', brut)
            blocs = [b.encode().decode("unicode_escape") for b in blocs]
        for b in blocs:
            sorties.append((n["name"], lisible(b)))
    return sorties


def prompts_du_script(chemin, noms):
    arbre = ast.parse(chemin.read_text())
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
une projection des fichiers `n8n_workflows/*.json` et `etage2/*.py` du dépôt, régénérable par
`python3 exports/generer_annexe_2.py`. Toute divergence entre cette annexe et le dispositif
signale une annexe périmée, jamais un prompt inconnu.

**Les expressions entre doubles accolades** sont des interpolations de l'orchestrateur ou du
script : elles sont remplacées à l'exécution par les valeurs lues en base — libellé de
l'indicateur, période, mécanisme causal de la question de veille. Le prompt réellement envoyé
au modèle est donc toujours plus long que le gabarit reproduit ici, et son contenu variable est
tracé dans la charge d'entrée conservée avec chaque sortie.
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

    print("\n---\n\n## A2.2 Prompts portés par les scripts de l'étage 2\n")
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
