#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génération de l'annexe 4 — index des workflows d'orchestration. 24.08.2026.

L'annexe 4 est un INDEX, pas une reproduction : les fichiers JSON sont le
livrable, joints au dépôt. Ce que l'index ajoute, et qu'aucun JSON ne dit,
c'est l'ÉTAT de chaque workflow — spécifié, exécuté une fois, en service.
La distinction est celle que le travail s'impose partout : ce qui est montrable
et ce qui ne l'est pas.

Usage (depuis prototype/) :
    python3 exports/generer_annexe_4.py > ../annexes/4_workflows_orchestration.md
"""

import datetime as dt
import json
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
DOSSIER = RACINE / "n8n_workflows"

# État DÉCLARÉ, parce qu'il n'est pas lisible dans le fichier. Un JSON ne dit
# pas s'il a jamais tourné : l'affirmer sans le savoir serait surdéclarer.
ETATS = {
    "collecte_flux.json": (
        "En service", "Collecte des flux de l'étage 2",
        "Quatre familles en un seul workflow — avis de marchés publics, dépêches, actes "
        "réglementaires, fils de syndication. Porté depuis un script le 25.08.2026."),
    "collecte_ted_enrichi.json": (
        "En service", "Enrichissement des avis de marchés publics",
        "Quatorze champs par avis, dont l'échéance de remise, la valeur estimée et le contact "
        "acheteur. Alimente l'écran Actions. Porté depuis un script le 25.08.2026."),
    "triage_ia_flux.json": (
        "En service", "Triage assisté par IA des items de flux",
        "Deux doctrines coexistantes — « événement » et « signal » —, l'écart entre elles étant "
        "lui-même une mesure. Porté depuis un script le 25.08.2026."),
    "lecture_decision_ted.json": (
        "En service", "Lecture décisionnelle des marchés publics",
        "Profil métier déclaré en clair, repris mot pour mot du script qu'il remplace : sa "
        "sensibilité est mesurée au § 11.8 et toute retouche invaliderait cette mesure."),
    "collecte_fh_horlogerie.json": (
        "En service", "Collecteur de la Fédération horlogère (PDF tabulaire)",
        "Le nœud de lecture PDF ne préservant pas l'alignement des colonnes, l'analyse se fait "
        "en flux de jetons. Porté depuis un script le 25.08.2026."),
    "veille_acea_A2.json": (
        "En service", "Détection du communiqué ACEA",
        "Constate qu'un document existe et l'inscrit en file de VÉRIFICATION : il n'extrait rien "
        "et n'écrit aucune valeur. Porté depuis un script le 25.08.2026."),
    "attribution_ancree_medical.json": (
        "Démonstration, hors production", "Attribution ancrée (§ 12.3)",
        "Écrit dans le schéma de bac à sable ; ses sorties n'atteignent la restitution que "
        "validées, et sous une mention explicite."),
    "collecte_generique.json": (
        "En service", "Collecteur générique piloté par les liaisons du référentiel",
        "Le collecteur principal : il lit `source_bindings` et interroge chaque source active. "
        "Exécuté plus de nonante fois ; dernier run en date au § 11.8."),
    "collecte_xlsx_indexe.json": (
        "En service", "Collecteur de classeur derrière une page d'index",
        "Pour les producteurs qui publient un classeur dont l'URL change à chaque millésime "
        "(CPB, SIPRI) : la page d'index est lue, le lien du classeur courant en est extrait."),
    "analyse_tendances_alertes.json": (
        "En service", "Commentaire exécutif sous règles d'interprétation RI0-RI10",
        "Produit le texte de tête de chaque vue sectorielle. Aucune sortie n'est diffusée "
        "sans validation humaine nominative."),
    "api_restitution.json": (
        "En service", "Interface de lecture de la restitution (lecture seule)",
        "Cinq points de lecture servant l'application de tableau de bord. Aucune écriture."),
    "extraction_composite_A2.json": (
        "Démontré en série", "Extraction composite multi-IA (A2, communiqués ACEA)",
        "Sept périodes validées, six routages en validation humaine pour quatre motifs "
        "distincts. C'est le workflow qui démontre la hiérarchie de fiabilisation."),
    "extraction_signal_qualitatif.json": (
        "Démontré", "Extraction de signal qualitatif multi-IA",
        "Qualifie un acte réglementaire en signal daté et attribuable."),
    "decouverte_sources_multi_ia.json": (
        "Démontré sur un run", "Découverte de sources (couche 0)",
        "Un run complet le 22.08.2026 : 26 candidats, 19 déposés en file de qualification. "
        "Les candidats ne sont jamais inscrits au référentiel par le workflow."),
    "scenario_c_agent_autonome.json": (
        "Spécifié, non confronté", "Artefact agentique du scénario C",
        "Construit pour être confronté au scénario B (§ 10.5), non pour être déployé. "
        "La confrontation n'a pas été exécutée dans l'horizon du travail — cf. annexe 7."),
    "collecte_a5_eurostat_pilote.json": (
        "Superseded", "Pilote de la tranche verticale (A5, Eurostat)",
        "Premier collecteur, du 06.08.2026. Conservé comme pièce : c'est lui qui a démontré "
        "la chaîne de bout en bout avant que le collecteur générique ne le remplace."),
    "collecte_a5_multi_geo.json": (
        "Superseded", "Collecte A5 multi-zones (branches parallèles)",
        "Étape intermédiaire, conservée pour la traçabilité du chemin suivi."),
    "collecte_m2_eurostat.json": (
        "Superseded", "Collecte M2 (Eurostat)", "Remplacé par le collecteur générique."),
    "collecte_hard_data.json": (
        "Superseded", "Collecte des hard data (première forme)",
        "Remplacé par le collecteur générique piloté par liaisons."),
    "extraction_composite_multi_ia.json": (
        "Superseded", "Extraction composite (forme générique initiale)",
        "Remplacé par `extraction_composite_A2.json`, spécialisé et démontré en série."),
}

ORDRE = ["En service", "Démontré en série", "Démontré", "Démontré sur un run",
         "Spécifié, non confronté", "Superseded"]


def main():
    auj = dt.date.today().strftime("%d.%m.%Y")
    fichiers = sorted(p.name for p in DOSSIER.glob("*.json"))
    print(f"""# Annexe 4 — Workflows d'orchestration

*Index produit par lecture des fichiers du dépôt, le {auj}.*

Les workflows eux-mêmes sont joints au dépôt sous `prototype/n8n_workflows/` au format JSON,
importables tels quels dans une instance n8n. **Cet index ajoute ce qu'aucun fichier JSON ne
dit : l'état de chaque workflow.** Un fichier ne porte pas la trace de ses exécutions, et
affirmer qu'un workflow fonctionne parce qu'il est écrit serait exactement la surdéclaration
que ce travail s'interdit. Les états sont donc déclarés, et chacun renvoie à la pièce qui
l'établit.

**Les identifiants sont épinglés dans les fichiers depuis le 24.08.2026.** Sans eux, chaque
import créait une copie : l'instance de développement a compté jusqu'à cinq exemplaires d'un
même workflow, et une version périmée a effectivement été exécutée (§ 12.6). Un import
reproduit désormais l'instance au lieu de la dupliquer.

**Ce que les fichiers ne contiennent pas, volontairement** : aucune valeur d'authentification.
Les nœuds portent une *référence* de justificatif — un identifiant et un nom —, jamais son
contenu. Le secret est la clé de chiffrement de l'orchestrateur, qui reste dans sa sauvegarde
locale et n'est versionnée nulle part. Reconstituer l'environnement suppose donc de recréer les
justificatifs dans l'interface, ce qui est documenté au fichier de passation.

| Fichier | Identifiant | Objet | Nœuds | État |
|---|---|---|---|---|""")

    lignes = []
    for f in fichiers:
        d = json.loads((DOSSIER / f).read_text())
        wid = d.get("id", "—")
        etat, objet, _ = ETATS.get(f, ("Non inventorié", "—", ""))
        lignes.append((ORDRE.index(etat) if etat in ORDRE else 99, f, wid, objet,
                       len(d.get("nodes", [])), etat))
    for _, f, wid, objet, n, etat in sorted(lignes):
        print(f"| `{f}` | `{wid}` | {objet} | {n} | **{etat}** |")

    print("""
---

## Détail par workflow
""")
    for _, f, wid, objet, n, etat in sorted(lignes):
        _, _, motif = ETATS.get(f, ("", "", "Workflow non inventorié — à documenter."))
        print(f"### `{f}`\n")
        print(f"**{objet}** — {n} nœuds · identifiant `{wid}` · état : **{etat}**.\n")
        print(f"{motif}\n")

    print("""---

## Lecture de l'état « Superseded »

Cinq workflows sont conservés au dépôt alors qu'ils ne sont plus exécutés. Ce n'est pas de la
négligence : ce sont les étapes réelles du chemin suivi, et l'historique du dépôt doit se lire
comme le déroulé du projet. Le premier d'entre eux — le pilote de la tranche verticale du
6 août — est la pièce qui établit que la chaîne de bout en bout a fonctionné avant d'être
généralisée. Les supprimer rendrait le dossier plus propre et moins vrai.
""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
