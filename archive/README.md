# Archive du dépôt

Ce dossier est hors de toute boucle d'exécution : rien ici n'est importé dans n8n, construit
par Vite ni lu par le compose. Il a été constitué le 02.09.2026 (correction A9 du tour « jury »,
constat UI-30 : « un lecteur du dépôt ne distingue pas le vivant du mort »).

- `etats_anterieurs/` — les 48 copies `*.avant_<motif>_<date>` prises avant chaque modification
  sensible entre le 22.08 et le 01.09, à l'emplacement relatif d'origine. Elles ont été faites
  parce que les commits étaient rares sur cette période (aucun du 26 au 30.08) : certaines
  portent un état qui n'a jamais été commis, c'est pourquoi elles sont déplacées et non
  supprimées. Le nom dit le motif de la modification qui a suivi.
- `dashboard-app_pages_non_routees/` — neuf pages React et trois fichiers (`Mini.jsx`, `app.css`,
  `v6.css`) qu'aucune route de `App.jsx` n'atteignait (calcul par la fermeture des imports depuis
  `main.jsx`, le 02.09) : itérations v5 à v9 de la restitution du 25 au 28.08, remplacées par
  les sept pages vivantes. `SecteurQV.jsx` et `Dispositif.jsx` portent encore des textes
  corrigés ailleurs (« commerce mondial », « révision par la source ») : ils ne sont plus servis.

Les workflows n8n archivés ont leur propre dossier : `n8n_workflows/archive/`.
