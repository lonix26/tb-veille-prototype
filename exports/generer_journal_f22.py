#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génération du tableau F.2.2 du rapport — journal de la phase de construction,
établi par le dépôt. TB Castillo, 04.09.2026.

POURQUOI GÉNÉRER. Le tableau tenu à la main s'était arrêté au 26.08 au matin
(55 actes) alors que le dépôt en comptait 63 le soir même : un journal recopié
diverge de son journal dès le commit suivant. Ici chaque ligne est projetée de
`git log` — une ligne par jour (date d'auteur), les trois premiers actes du jour
dans l'ordre chronologique, puis « et n autre(s) acte(s) ». Les préfixes
(`prototype:`, `pilotage:`…) sont retirés, le reste du message est reproduit
tel quel, coquilles comprises : ce sont les actes, pas leur relecture.

Usage (depuis prototype/) :
    python3 exports/generer_journal_f22.py            # tableau + décompte, à coller dans F.2.2
"""
import collections
import subprocess
import sys

journal = subprocess.run(
    ["git", "log", "--reverse", "--date=format:%d.%m.%Y", "--format=%ad|%s"],
    capture_output=True, text=True, check=True).stdout

jours = collections.OrderedDict()
for ligne in journal.strip().splitlines():
    date, sujet = ligne.split("|", 1)
    prefixe, sep, reste = sujet.partition(": ")
    if sep and " " not in prefixe:
        sujet = reste
    actes = jours.setdefault(date, [])
    # Deux commits d'un même jour peuvent porter un sujet identique (constaté le
    # 17.08) : l'acte est compté, mais son libellé n'est pas répété à l'affichage.
    if sujet not in actes:
        actes.append(sujet)
    else:
        actes.append("")

print("| Date | Actes tracés (commits du jour) |")
print("|---|---|")
for date, actes in jours.items():
    visibles = [x for x in actes if x]
    tete = " · ".join(visibles[:3])
    reste = len(actes) - len(visibles[:3])
    suffixe = f" — et {reste} autre(s) acte(s)" if reste > 0 else ""
    print(f"| {date} | {tete}{suffixe} |")

total = sum(len(a) for a in jours.values())
derniere = list(jours)[-1]
print(f"\n*{total} actes tracés sur le dépôt au {derniere}, chacun daté et motivé dans son message de "
      "commit ; l'historique complet est consultable par `git log` et fait partie des livrables "
      "techniques. Aucun commit du 27 au 30.08.2026 : les neuf commits du 31.08 portent le "
      "travail de ces quatre jours, journalisé jour par jour dans la passation du prototype "
      "(fait d'historique codé en dur ici, il ne se lit pas dans `git log`). Les balises du dépôt (`gel-2026-09-01`, `tour-jury-2026-09-02`) y repèrent le "
      "gel du prototype et le début du tour « jury » ; aucune séance de supervision n'a eu lieu "
      "pendant la phase de construction, aucune n'est donc balisée. Tableau produit par "
      "`exports/generer_journal_f22.py` ; à régénérer avant l'assemblage.*")
sys.exit(0)
