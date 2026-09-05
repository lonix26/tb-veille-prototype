#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génération de l'annexe 4 — index des workflows d'orchestration. 24.08.2026.

03.09.2026 : sept descripteurs ajoutés (CP, A1, événements, lecture transversale,
dérivation des intensités, veille documentaire, erreur commune) ; fiche du
commentaire exécutif alignée sur le régime de diffusion du 31.08 ; les cinq
squelettes archivés le 02.09 (A9) ne sont plus inventoriés ici, ils ont leur
README sous n8n_workflows/archive/.

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
        "58 runs à son nom au 03.09.2026, dont 28 clos en `ok` du 09.08 au 02.09 (par "
        "requête sur `runs`)."),
    "collecte_xlsx_indexe.json": (
        "En service", "Collecteur de classeur derrière une page d'index",
        "Pour les producteurs qui publient un classeur dont l'URL change à chaque millésime "
        "(CPB, SIPRI) : la page d'index est lue, le lien du classeur courant en est extrait."),
    "analyse_tendances_alertes.json": (
        "En service", "Commentaire exécutif sous règles d'interprétation RI0-RI10",
        "Produit le texte de tête de chaque vue sectorielle. Sorties stockées avec leur "
        "statut ; depuis le 31.08.2026, servies avec ce statut et badgées à l'écran — la "
        "relecture humaine est un audit a posteriori (§ 12.5)."),
    "api_restitution.json": (
        "En service", "Interface de lecture de la restitution (lecture seule)",
        "Sept points de lecture servant l'application de tableau de bord (trois lus par "
        "l'application, § 6 de DEPLOIEMENT.md). Aucune écriture."),
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
    # 03.09.2026 — sept descripteurs, notices rédigées sur pièces (passation, suites
    # du 30.08 au 02.09 ; notes de rédaction du 03.09, suite 12).
    "extraction_composite_CP.json": (
        "Démontré sur un run", "Extraction composite par la voie multimodale (H2 emplois, "
        "H11 entreprises ; Convention patronale)",
        "Run 167 : 32 valeurs identiques au chargement par script (run 163) ; trois défauts "
        "de câblage corrigés, aucun visible à la lecture du JSON (§ 11.16)."),
    "extraction_composite_A1_ccfa.json": (
        "Démontré", "Extraction composite A1 (annuaire CCFA, republication OICA) — découpe "
        "par sentinelles (~1 % du document soumis : 5 100 caractères sur ~530 000, mesuré sur "
        "les exécutions du 31.08.2026, corrigé de 2,5 % le 04.09), consensus, confrontation OICA "
        "opportuniste, recouvrement inter-éditions",
        "Série 2021-2024, trois éditions traitées (§ 11.16)."),
    "extraction_evenements_flux.json": (
        "En service", "Événements typés depuis le titre seul des items — modèle unique, "
        "vocabulaire fermé (huit types, trois sens), non_relu par défaut, éligibilité "
        "déclarée par source",
        "690 événements au registre au 02.09.2026, 309 servis."),
    "lecture_transversale.json": (
        "Démontré sur un run", "Lectures transversales sous génération contrainte (faits "
        "calculés fournis, aucun chiffre autorisé, citations obligatoires)",
        "Run 194 : 7 hypothèses, zéro incident de format ; servies avec statut."),
    "derivation_intensite_signalement.json": (
        "En service", "Dérivation des intensités (S9, A9, A10, H10) depuis le triage — la vue "
        "calcule, le workflow ouvre le run et écrit en file de validation",
        "Premiers points validés le 27.08.2026, H10 activé le 31.08."),
    "veille_documentaire_annuelle.json": (
        "En service, cadence activée", "Détection des éditions annuelles CP et CCFA — détecter "
        "n'est pas lire : inscription en file a_verifier, idempotente",
        "Run 202 vert, comportement de référence ; les trois pipelines composites sont "
        "auto-amorcés. Seul workflow dont le déclencheur horaire est publié (hebdomadaire, lundi "
        "05:00) : il a produit une exécution planifiée réelle le 05.09.2026, et son nœud "
        "d'ouverture constate le type de déclenchement au lieu de l'écrire en dur."),
    "erreur_commune.json": (
        "En service", "Clôture automatique des runs en échec — errorWorkflow commun aux 21 "
        "autres workflows",
        "Démontré au banc d'essai le 02.09.2026 (run 216) ; hypothèse « une exécution à la "
        "fois » déclarée dans le fichier ; à publier après tout réimport, sinon muet."),
}

ORDRE = ["En service, cadence activée", "En service", "Démontré en série", "Démontré", "Démontré sur un run",
         "Démonstration, hors production", "Superseded"]


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

**Les cadences sont déclarées dans les fichiers, l'activation ne l'est pas.** Depuis le
05.09.2026, seize collecteurs portent un déclencheur horaire à côté de leur déclencheur manuel —
quotidien pour les flux, hebdomadaire pour les lectures, mensuel pour les séries conjoncturelles
et les composites —, chaque nœud portant en note le motif de sa cadence. Un seul est publié et a
produit une exécution planifiée réelle : la détection des éditions annuelles, choisie parce
qu'elle est idempotente et n'appelle aucun modèle. Les autres sont déclarés et inactifs :
pendant la construction, les exécutions ont été lancées à la main pour garder le registre stable
et maîtriser les appels de modèles payants. La procédure d'activation, et la correction qu'elle
suppose, figurent au § 5.1 du dossier de déploiement.

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

## Lecture de l'état « Superseded », et l'archive

Un workflow est conservé au dépôt alors qu'il n'est plus exécuté : le pilote de la tranche
verticale du 6 août, la pièce qui établit que la chaîne de bout en bout a fonctionné avant d'être
généralisée. Cinq autres états antérieurs — collecte A5 multi-zones, collecte M2, collecte des
hard data (première forme), extraction composite générique, maquette du scénario C — ont été
déplacés le 02.09.2026 sous `n8n_workflows/archive/squelettes_2026-08-04/`, hors de la boucle
d'import : ils s'importaient avec les autres et un lecteur ne distinguait pas le vivant du mort.
Aucun des cinq n'a produit de run ; la maquette du scénario C n'a jamais été exécutée, la
confrontation du § 10.5 ayant été menée par le script `scenario_c/agent_autonome.py` (annexe 7).
L'archive contient aussi l'export de la version d'`extraction_composite_A2` qui a réellement
produit les runs 51 à 58, et un README qui dit pourquoi. Supprimer tout cela rendrait le dossier
plus propre et moins vrai.
""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
