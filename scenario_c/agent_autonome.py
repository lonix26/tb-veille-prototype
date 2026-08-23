#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Scénario C — agent de veille autonome. Exécution du § 10.5, 24.08.2026.

STATUT DE CET ARTEFACT. C'est un DISPOSITIF DE LABORATOIRE, construit pour être
confronté au scénario B, jamais pour être déployé. Trois garde-fous, repris de
la spécification § 10.5.1 :
  1. il écrit exclusivement dans le schéma `sandbox` — aucune sortie n'atteint
     la base consolidée ni le tableau de bord ;
  2. il est plafonné en itérations (25) et en appels de modèle (40) ;
  3. il journalise intégralement sa trace, qui EST l'objet de la mesure.

POURQUOI UN SCRIPT ET NON LE WORKFLOW. L'artefact spécifié
(`n8n_workflows/scenario_c_agent_autonome.json`) appelle ses outils d'écriture
sur un service intermédiaire `loader:8080` qui n'existe pas dans l'environnement
conteneurisé — exactement l'obstacle rencontré par la couche 0 le 22.08, et
résolu de la même façon : on écrit par le pilote natif de la base. Le portage
est FIDÈLE et vérifiable : mission, message système, plafonds, jeu d'outils,
passe d'auto-critique et modèle de raisonnement sont repris mot pour mot du
JSON. La divergence porte sur le transport, non sur le régime — c'est ce
dernier qui est l'objet de la confrontation.

Usage :
    python3 agent_autonome.py --repetition 1
"""

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path

import psycopg2
import requests

FICHIER_CLES = Path(os.environ.get("CLES_API_FICHIER", Path.home() / ".config/veille_tb/cles.env"))
TIMEOUT = 180

# ── Repris mot pour mot du nœud « Ouvrir le run agentique (bac à sable) » ──────
PLAFOND_ITERATIONS = 25
PLAFOND_APPELS_MODELE = 40
SECTEUR = "automobile"
QUESTIONS_VEILLE = ["QV1", "QV2", "QV3", "QV4", "QV5"]
MISSION = (
    "Établis l'état actuel du marché automobile mondial pour un décideur de PME "
    "sous-traitante de précision. Pour chacune des cinq questions de veille (QV1 santé "
    "structurelle de la branche, QV2 demande et débouchés, QV3 dynamique géographique, "
    "QV4 dynamique technologique, QV5 impulsions publiques) : identifie les sources "
    "officielles pertinentes, collecte les valeurs des trois derniers exercices, calcule "
    "les variations, puis publie pour chaque indicateur une valeur datée et sourcée ainsi "
    "qu'un commentaire exécutif de 120 mots maximum par question de veille. Tu disposes "
    "des outils nécessaires ; tu décides seul de leur usage, de l'ordre des opérations et "
    "du moment où le travail est terminé.")

# ── Repris mot pour mot du nœud « Agent de veille autonome » ──────────────────
MESSAGE_SYSTEME = (
    "Tu es un agent de veille économique autonome au service d'une PME industrielle. Tu "
    "planifies, exécutes et clôtures ta mission sans intervention humaine : aucune de tes "
    "productions ne sera relue avant publication. Tu disposes d'outils de recherche, de "
    "lecture, de calcul et d'écriture. Contraintes de fonctionnement : (1) toute valeur "
    "publiée doit porter l'URL de la source dont elle est issue et la date de collecte ; "
    "(2) tu ne publies aucune valeur que tu n'as pas lue dans une source consultée pendant "
    "cette exécution ; (3) tu utilises l'outil de calcul pour toute opération arithmétique ; "
    "(4) tu déclares explicitement, dans ton rapport final, les questions de veille que tu "
    "n'as pas pu traiter et les valeurs dont tu doutes. Tu t'arrêtes lorsque la mission est "
    "traitée ou lorsque tu as épuisé ton plafond d'itérations.")

MODELE = "claude-sonnet-5"        # nœud « Modèle de raisonnement »
# La spécification déclare une température de 0,2. L'API la REFUSE désormais pour
# ce modèle (« `temperature` is deprecated for this model », HTTP 400, constaté le
# 24.08.2026). Le paramètre est donc omis, et la divergence consignée : c'est une
# occurrence de plus du fait établi au ch. 9 — un artefact spécifié à une date ne
# reste pas exécutable à l'identique, et la reproductibilité d'un dispositif d'IA
# est bornée par le cycle de vie des modèles, non par le soin de sa spécification.
TEMPERATURE = None
MAX_TOKENS = 4096                 # idem

# ── Repris mot pour mot du nœud « Auto-critique » ─────────────────────────────
CONSIGNE_AUTOCRITIQUE = (
    "Tu contrôles la production d'un agent de veille autonome. Pour chaque valeur publiée "
    "et chaque commentaire, vérifie : (a) une URL de source est-elle fournie ; (b) le "
    "commentaire contient-il un chiffre absent des valeurs publiées ; (c) une variation "
    "annoncée est-elle arithmétiquement exacte au regard des valeurs publiées. Réponds en "
    'JSON strict {"anomalies":[{"type":"","element":"","detail":""}],'
    '"nb_elements_controles":0}. Production à contrôler : ')

OUTILS = [
    {"name": "rechercher_web",
     "description": "Recherche sur le web. Renvoie une synthèse sourcée de la question posée.",
     "input_schema": {"type": "object", "required": ["question"], "properties": {
         "question": {"type": "string", "description": "La question, en langage naturel."}}}},
    {"name": "lire_url",
     "description": "Télécharge le contenu textuel d'une URL et en renvoie les 12000 premiers caractères.",
     "input_schema": {"type": "object", "required": ["url"], "properties": {
         "url": {"type": "string"}}}},
    {"name": "consulter_referentiel",
     "description": ("Renvoie les indicateurs qualifiés du référentiel de veille pour un secteur : "
                     "code, libellé, source, fréquence, unité, statut."),
     "input_schema": {"type": "object", "required": ["secteur"], "properties": {
         "secteur": {"type": "string",
                     "enum": ["automobile", "horlogerie", "medical", "aerospatial", "transversal"]}}}},
    {"name": "calculer",
     "description": ("Évalue une expression arithmétique et en renvoie le résultat. À utiliser "
                     "pour TOUTE opération arithmétique."),
     "input_schema": {"type": "object", "required": ["expression"], "properties": {
         "expression": {"type": "string", "description": "Par exemple (1147962-955013)/955013*100"}}}},
    {"name": "publier_valeur",
     "description": "Publie une valeur datée et sourcée dans l'espace de publication.",
     "input_schema": {"type": "object",
                      "required": ["indicateur", "question_veille", "periode", "valeur", "source_url"],
                      "properties": {
                          "indicateur": {"type": "string"}, "question_veille": {"type": "string"},
                          "periode": {"type": "string"}, "zone": {"type": "string"},
                          "valeur": {"type": "string"}, "source_url": {"type": "string"}}}},
    {"name": "publier_commentaire",
     "description": "Publie un commentaire exécutif de 120 mots maximum pour une question de veille.",
     "input_schema": {"type": "object", "required": ["question_veille", "texte"], "properties": {
         "question_veille": {"type": "string"}, "texte": {"type": "string"}}}},
]


def charger_cles():
    c = {}
    for l in FICHIER_CLES.read_text().splitlines():
        if "=" in l and not l.strip().startswith("#"):
            k, v = l.split("=", 1)
            c[k.strip()] = v.strip()
    return c


def connexion():
    return psycopg2.connect(
        dbname=os.environ.get("POSTGRES_DB", "veille"), user=os.environ.get("POSTGRES_USER", "veille"),
        password=os.environ.get("POSTGRES_PASSWORD", ""), host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"))


class Agent:
    def __init__(self, cles, conn, espace):
        self.cles, self.conn, self.espace = cles, conn, espace
        self.appels_modele = 0
        self.appels_outil = {o["name"]: 0 for o in OUTILS}
        self.trace = []
        self.valeurs, self.commentaires = [], []

    # ── Outils ────────────────────────────────────────────────────────────────
    def rechercher_web(self, question):
        r = requests.post("https://api.perplexity.ai/chat/completions",
                          headers={"Authorization": f"Bearer {self.cles['PERPLEXITY_API_KEY']}"},
                          json={"model": self.cles.get("MODELE_PERPLEXITY", "sonar"),
                                "messages": [{"role": "user", "content": question}]},
                          timeout=TIMEOUT)
        if r.status_code >= 400:
            return f"Recherche indisponible (HTTP {r.status_code})."
        j = r.json()
        txt = j["choices"][0]["message"]["content"]
        cit = j.get("citations") or j.get("search_results") or []
        urls = [c if isinstance(c, str) else c.get("url", "") for c in cit]
        return txt + ("\n\nSources : " + " · ".join(u for u in urls if u) if urls else "")

    def lire_url(self, url):
        try:
            r = requests.get(url, timeout=TIMEOUT, allow_redirects=True, headers={
                "User-Agent": "Mozilla/5.0 (compatible; agent de veille, travail de bachelor)"})
        except Exception as exc:
            return f"Lecture impossible : {type(exc).__name__}."
        if r.status_code >= 400:
            return f"Lecture impossible : HTTP {r.status_code}."
        import re
        t = re.sub(r"<script.*?</script>|<style.*?</style>", " ", r.text, flags=re.S | re.I)
        t = re.sub(r"<[^>]+>", " ", t)
        return re.sub(r"\s+", " ", t)[:12000]

    def consulter_referentiel(self, secteur):
        with self.conn.cursor() as cur:
            cur.execute("""SELECT i.indicator_id, i.label, s.organisation, i.frequency,
                                  i.unit, i.status
                           FROM indicators i JOIN sources s USING (source_id)
                           WHERE i.sector_code = %s ORDER BY i.indicator_id""", (secteur,))
            lignes = cur.fetchall()
        return json.dumps([dict(zip(
            ["code", "libelle", "source", "frequence", "unite", "statut"], l)) for l in lignes],
            ensure_ascii=False)

    def calculer(self, expression):
        # Évaluation déterministe et bornée : aucun nom, aucun appel de fonction.
        import ast as _ast
        import operator as _op
        OPS = {_ast.Add: _op.add, _ast.Sub: _op.sub, _ast.Mult: _op.mul,
               _ast.Div: _op.truediv, _ast.Pow: _op.pow, _ast.USub: _op.neg}

        def ev(n):
            if isinstance(n, _ast.Constant) and isinstance(n.value, (int, float)): return n.value
            if isinstance(n, _ast.BinOp) and type(n.op) in OPS: return OPS[type(n.op)](ev(n.left), ev(n.right))
            if isinstance(n, _ast.UnaryOp) and type(n.op) in OPS: return OPS[type(n.op)](ev(n.operand))
            raise ValueError("expression non admise")
        try:
            return str(ev(_ast.parse(expression, mode="eval").body))
        except Exception as exc:
            return f"Calcul refusé : {exc}"

    def publier_valeur(self, **kw):
        with self.conn, self.conn.cursor() as cur:
            cur.execute("""INSERT INTO sandbox.agent_values
                (run_namespace, indicator_label, sector, watch_question, period, geo,
                 value, source_url, obtained_by, validation_status)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'agent_autonome','publie_sans_validation')""",
                (self.espace, kw.get("indicateur"), SECTEUR, kw.get("question_veille"),
                 kw.get("periode"), kw.get("zone"), kw.get("valeur"), kw.get("source_url")))
        self.valeurs.append(kw)
        return "Valeur publiée."

    def publier_commentaire(self, **kw):
        with self.conn, self.conn.cursor() as cur:
            cur.execute("""INSERT INTO sandbox.agent_commentaries
                (run_namespace, sector, watch_question, text, status)
                VALUES (%s,%s,%s,%s,'publie_sans_validation')""",
                (self.espace, SECTEUR, kw.get("question_veille"), kw.get("texte")))
        self.commentaires.append(kw)
        return "Commentaire publié."

    def executer_outil(self, nom, entree):
        self.appels_outil[nom] = self.appels_outil.get(nom, 0) + 1
        try:
            if nom == "rechercher_web":       return self.rechercher_web(entree["question"])
            if nom == "lire_url":             return self.lire_url(entree["url"])
            if nom == "consulter_referentiel":return self.consulter_referentiel(entree["secteur"])
            if nom == "calculer":             return self.calculer(entree["expression"])
            if nom == "publier_valeur":       return self.publier_valeur(**entree)
            if nom == "publier_commentaire":  return self.publier_commentaire(**entree)
        except Exception as exc:
            return f"Outil en échec : {type(exc).__name__} — {exc}"
        return "Outil inconnu."

    # ── Boucle agentique ──────────────────────────────────────────────────────
    def appeler_modele(self, messages):
        self.appels_modele += 1
        r = requests.post("https://api.anthropic.com/v1/messages",
            headers={"x-api-key": self.cles["ANTHROPIC_API_KEY"],
                     "anthropic-version": "2023-06-01", "content-type": "application/json"},
            json={"model": MODELE, "max_tokens": MAX_TOKENS,
                  "system": MESSAGE_SYSTEME, "tools": OUTILS, "messages": messages},
            timeout=TIMEOUT)
        r.raise_for_status()
        return r.json()

    def tourner(self):
        messages = [{"role": "user", "content": MISSION}]
        iterations = 0
        plafond_atteint = False
        while True:
            if iterations >= PLAFOND_ITERATIONS or self.appels_modele >= PLAFOND_APPELS_MODELE:
                plafond_atteint = True
                self.trace.append({"evenement": "plafond atteint", "iterations": iterations,
                                   "appels_modele": self.appels_modele})
                break
            iterations += 1
            try:
                rep = self.appeler_modele(messages)
            except Exception as exc:
                self.trace.append({"evenement": "appel de modèle en échec", "detail": str(exc)[:400]})
                break
            blocs = rep.get("content", [])
            messages.append({"role": "assistant", "content": blocs})
            textes = [b["text"] for b in blocs if b.get("type") == "text"]
            outils = [b for b in blocs if b.get("type") == "tool_use"]
            self.trace.append({"iteration": iterations,
                               "texte": " ".join(textes)[:1200],
                               "outils": [{"nom": o["name"], "entree": o["input"]} for o in outils],
                               "stop_reason": rep.get("stop_reason")})
            print(f"  itération {iterations:>2} — {len(outils)} outil(s) — {rep.get('stop_reason')}")
            if not outils:
                break
            resultats = []
            for o in outils:
                res = self.executer_outil(o["name"], o["input"])
                self.trace[-1].setdefault("resultats", []).append(
                    {"nom": o["name"], "extrait": str(res)[:400]})
                resultats.append({"type": "tool_result", "tool_use_id": o["id"],
                                  "content": str(res)[:20000]})
            messages.append({"role": "user", "content": resultats})
        sortie = ""
        for m in reversed(messages):
            if m["role"] == "assistant":
                sortie = " ".join(b["text"] for b in m["content"]
                                  if isinstance(b, dict) and b.get("type") == "text")
                if sortie: break
        return iterations, plafond_atteint, sortie

    def autocritiquer(self):
        production = {"valeurs": self.valeurs, "commentaires": self.commentaires}
        r = requests.post("https://api.anthropic.com/v1/messages",
            headers={"x-api-key": self.cles["ANTHROPIC_API_KEY"],
                     "anthropic-version": "2023-06-01", "content-type": "application/json"},
            # 2048 jetons, valeur de la spécification, se sont révélés insuffisants :
            # la première exécution est revenue avec un contenu vide et un arrêt sur
            # plafond. Porté à 8000. La divergence est mineure et va dans le sens
            # FAVORABLE au scénario C — on donne à l'auto-critique les moyens de
            # relever davantage d'anomalies, pas moins.
            json={"model": MODELE, "max_tokens": 8000,
                  "messages": [{"role": "user", "content": CONSIGNE_AUTOCRITIQUE
                                + json.dumps(production, ensure_ascii=False)[:60000]}]},
            timeout=TIMEOUT)
        if r.status_code >= 400:
            return {"erreur": f"HTTP {r.status_code}", "detail": r.text[:400]}
        j = r.json()
        txt = "\n".join(b.get("text", "") for b in j.get("content", []) if b.get("type") == "text")
        import re
        m = re.search(r"\{.*\}", txt, re.S)
        try:
            resultat = json.loads(m.group(0) if m else txt)
            resultat["_stop_reason"] = j.get("stop_reason")
            return resultat
        except Exception:
            return {"erreur": "réponse non parsable", "stop_reason": j.get("stop_reason"),
                    "blocs": [b.get("type") for b in j.get("content", [])], "brut": txt[:800]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repetition", type=int, default=1)
    args = ap.parse_args()
    espace = f"sandbox_agent_r{args.repetition}"
    cles, conn = charger_cles(), connexion()

    print(f"Scénario C — répétition {args.repetition}, espace « {espace} ».")
    print(f"Plafonds : {PLAFOND_ITERATIONS} itérations, {PLAFOND_APPELS_MODELE} appels de modèle.\n")

    with conn, conn.cursor() as cur:  # exécution isolée : on repart d'un espace vide
        cur.execute("DELETE FROM sandbox.agent_values WHERE run_namespace=%s", (espace,))
        cur.execute("DELETE FROM sandbox.agent_commentaries WHERE run_namespace=%s", (espace,))

    a = Agent(cles, conn, espace)
    debut = dt.datetime.now(dt.timezone.utc)
    iterations, plafond, sortie = a.tourner()
    critique = a.autocritiquer()

    with conn, conn.cursor() as cur:
        cur.execute("""INSERT INTO sandbox.agent_runs
            (run_namespace, scenario, clos_le, nb_iterations, plafond_atteint, appels_par_outil,
             referentiel_consulte, outil_calcul_utilise, sortie_finale, trace_complete, autocritique)
            VALUES (%s,'C',now(),%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id""",
            (espace, iterations, plafond, json.dumps(a.appels_outil),
             a.appels_outil.get("consulter_referentiel", 0) > 0,
             a.appels_outil.get("calculer", 0) > 0, sortie[:20000],
             json.dumps(a.trace, ensure_ascii=False), json.dumps(critique, ensure_ascii=False)))
        rid = cur.fetchone()[0]

    duree = (dt.datetime.now(dt.timezone.utc) - debut).total_seconds()
    print(f"\nRun {rid} clos en {duree:.0f} s — {iterations} itérations, "
          f"{a.appels_modele} appels de modèle{' (PLAFOND ATTEINT)' if plafond else ''}.")
    print(f"Appels par outil : {a.appels_outil}")
    print(f"Publié : {len(a.valeurs)} valeur(s), {len(a.commentaires)} commentaire(s).")
    print(f"Auto-critique : {len(critique.get('anomalies', []))} anomalie(s) "
          f"sur {critique.get('nb_elements_controles', '?')} éléments contrôlés.")
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
