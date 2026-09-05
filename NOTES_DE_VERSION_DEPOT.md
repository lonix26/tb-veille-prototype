# Notes de version — remise du Travail de Bachelor (brouillon, à publier le jour du dépôt)

*Ce fichier est le texte à coller dans la publication GitHub (« Release ») au moment du dépôt.
Procédure en bas de page. Tant que le dépôt n'est pas fait, les valeurs marquées « au gel »
sont celles du 05.09.2026 et seront remplacées.*

---

## Prototype de veille économique semi-automatisée — remise du 13.09.2026

Livrable technique du Travail de Bachelor « Exploration de l'IA pour les entreprises
industrielles » (N. Castillo, HEG Arc, Informatique de gestion). Scénario B,
*human-in-the-loop* : les chiffres par le code, les mots par l'IA, la validation par l'humain.

**Pour l'ouvrir** : décompresser l'archive ci-jointe, puis `bash demarrer.sh` (seul Docker est
requis), puis <http://localhost:8080>. Le détail est dans `LISEZ-MOI.md` à la racine de
l'archive.

**Ce que l'archive contient** : le dossier technique complet — compose épinglé par empreintes,
schéma et référentiel (`db/`), 22 workflows d'orchestration, application de restitution
compilée, les deux harnais de vérification — et un **instantané daté** des exécutions de
l'auteur (203 176 observations, 216 exécutions au 05.09.2026), chargé au premier démarrage pour
que le dispositif soit consultable sans clé d'API. Ce n'est pas une collecte faite à l'instant ;
relancer une collecte réelle demande des clés (`DEPLOIEMENT.md` § 1.2).

**Ce qu'elle ne contient pas** : `.env` (recréé par le script), les 201 Mo de réponses brutes
(`data/`, dont les pièces du run de référence sont archivées avec le rapport), et l'historique
git — il est ce dépôt même ; `historique_git.txt` en donne le déroulé daté.

**Intégrité** — l'archive jointe est exactement celle-ci :

```
SHA-256 (au gel : valeur du 05.09.2026, à recalculer)
2a036a86147e18bf1ca81063f1e79cd4f162de5fd960ba498cec33625165e140  prototype_TB_Castillo_2026-09-05.zip
```

L'état du dépôt au moment de la remise porte la balise `depot-2026-09-13`. Les balises
antérieures jalonnent le projet : `gel-2026-09-01` (gel du prototype), `tour-jury-2026-09-02`
(revue critique complète et listes de correction).

---

## Procédure de publication, le jour du dépôt (13.09.2026)

```bash
cd prototype
git status                      # doit être propre
bash exports/generer_instantane_demonstration.sh
(cd dashboard-app && npm run build)
git add db/03_donnees_demonstration.sql.gz && git commit -m "prototype: instantané du gel"
bash preparer_archive.sh        # produit ../prototype_TB_Castillo_2026-09-13.zip
sha256sum ../prototype_TB_Castillo_2026-09-13.zip   # → remplacer l'empreinte ci-dessus
git tag -a depot-2026-09-13 -m "État remis au jury le 13.09.2026"
git push origin main --tags
```

Puis sur GitHub : *Releases → Draft a new release* → balise `depot-2026-09-13` → titre
« Remise du Travail de Bachelor — 13.09.2026 » → coller la section du haut (empreinte mise à
jour) → **joindre le ZIP** → *Publish release*. Enfin, *Settings → Collaborators* : inviter le
directeur et l'expert en lecture (« Read ») s'ils ne le sont pas déjà.
