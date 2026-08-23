#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rejoue la seule passe d'auto-critique d'un run agentique archivé.

La première exécution est revenue avec une auto-critique vide : le plafond de
jetons de la spécification (2048) ne suffisait pas. Rejouer la passe seule évite
de relancer l'agent — ce qui produirait une AUTRE production et rendrait la
comparaison entre exécutions inutilisable.

Usage : python3 rejouer_autocritique.py sandbox_agent_r1
"""
import json, sys
from agent_autonome import Agent, charger_cles, connexion

espace = sys.argv[1]
conn = connexion()
with conn.cursor() as cur:
    cur.execute("""SELECT indicator_label, watch_question, period, geo, value, source_url
                   FROM sandbox.agent_values WHERE run_namespace=%s ORDER BY id""", (espace,))
    valeurs = [dict(zip(["indicateur","question_veille","periode","zone","valeur","source_url"], r))
               for r in cur.fetchall()]
    cur.execute("""SELECT watch_question, text FROM sandbox.agent_commentaries
                   WHERE run_namespace=%s ORDER BY id""", (espace,))
    comms = [dict(zip(["question_veille","texte"], r)) for r in cur.fetchall()]

a = Agent(charger_cles(), conn, espace)
a.valeurs, a.commentaires = valeurs, comms
res = a.autocritiquer()
with conn, conn.cursor() as cur:
    cur.execute("""UPDATE sandbox.agent_runs SET autocritique=%s
                   WHERE run_namespace=%s""", (json.dumps(res, ensure_ascii=False), espace))
print(f"{espace} — {len(res.get('anomalies', []))} anomalie(s) sur "
      f"{res.get('nb_elements_controles','?')} éléments contrôlés.")
if res.get("erreur"): print("  ", res)
