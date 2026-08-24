# Restitution v5 — conception

*Écrit le 25.08.2026, après une revue critique de la v4 conduite sur pièces.*

## Le défaut que la v5 corrige

La v4 était une application d'**analyste**. La v5 est une application de **décideur**. Le
diagnostic tient en cinq constats, tous mesurés avant d'être corrigés :

| Constat sur la v4 | Mesure |
|---|---|
| Trop de portes | **10 entrées de menu**, dont deux pages de marché qui se recouvraient et une « itération précédente » conservée dans le menu principal |
| L'écran d'accueil ouvrait sur la méthode | Le premier paragraphe expliquait les **écarts-types** et le détendancement avant d'avoir rien montré |
| Le score était présenté sans ses réserves | **3 à 4 séries par marché** sur 43 indicateurs, moyennées à égalité, sans que l'écran le dise |
| Redondance non signalée | H1 et H7 mesurent tous deux les exportations horlogères suisses et **corrèlent à 0,93** ; le score les compte deux fois |
| La couche d'alertes noyait le signal | **204 franchissements**, dont 123 sur le seul H1 — une alerte par pays destinataire |

## Ce que la v5 fait, et pourquoi

### Trois portes au lieu de dix

La navigation suit les trois questions qu'un dirigeant se pose, dans l'ordre :

1. **Ce matin** — qu'est-ce qui a changé ?
2. **À faire** — sur quoi est-ce que je me positionne, et quand ?
3. **Le dispositif** — d'où sortent ces chiffres ?

Les marchés ne sont plus une entrée mais un **approfondissement** : on y arrive en cliquant sur
le marché qui intrigue. Les adresses de la v4 sont conservées et redirigent — un lien partagé ne
doit pas mourir. Les itérations précédentes restent atteignables hors menu : l'historique de la
restitution fait partie du résultat rendu, il n'a pas à occuper l'écran de travail.

### La phrase avant le chiffre

Un module unique, `src/phrases.jsx`, traduit les grandeurs du dispositif en français. Il est
unique **par construction** : deux copies d'une même règle de formulation finissent toujours par
diverger, comme l'avaient fait les deux copies du filtre de matérialité en v4.

L'écran d'ouverture commence désormais par un **brief construit à partir des données** :

> L'horlogerie ressort nettement au-dessus de son niveau habituel, cinq appels d'offres à votre
> portée se closent d'ici quinze jours, le premier se clôt aujourd'hui, cinq commentaires à
> valider et 745 items de veille non examinés.

Aucune phrase du brief n'est écrite si la donnée qui la porte manque : un brief court vaut mieux
qu'un brief meublé.

### Le score dit sa faiblesse

Chaque carte de marché affiche, **avant** le nombre, l'état en mots (« nettement au-dessus »,
« dans sa norme »), une règle graduée où la zone grise centrale est le « rien à signaler », et le
décompte honnête des séries qui portent le score.

Surtout, l'écran calcule la **corrélation entre les séries d'un même score** et avertit quand
deux d'entre elles mesurent pratiquement la même grandeur :

> **Prudence.** Deux séries de ce score mesurent presque la même chose — *Exportations horlogères
> suisses par marché de destination* et *Exportations horlogères suisses, valeur totale (FH)*,
> qui évoluent ensemble (corrélation 0,93 sur 19 points communs). Le score les compte à égalité :
> il paraît donc plus assuré qu'il ne l'est.

**Le score n'est pas corrigé en silence.** Le corriger serait un choix de méthode, et il
appartient à l'auteur du travail, pas à l'interface. L'interface dit ce qu'elle sait.

Ce contrôle a exigé une correction de fond : la corrélation se calcule sur la série **agrégée**
de l'indicateur. Un premier jet retenait la zone la mieux fournie ; pour H1, ventilé sur
198 destinations, cela revenait à comparer **Aruba** au total suisse, et aucune redondance
n'était détectée. Les grandeurs additives sont donc sommées par période, les indices non — même
règle qu'en base.

### L'entonnoir plutôt que la liste

L'écran « À faire » montre d'abord **pourquoi le nombre final est petit** :

```
1 284 avis collectés → 561 appels d'offres → 114 encore ouverts → 12 à votre portée → 1 cœur de métier
```

Le petit nombre n'est pas une faiblesse de la collecte, c'est le résultat du tri, et le dire
change la lecture. Chaque fiche porte ensuite ce qui permet d'agir : l'échéance en langue
(« aujourd'hui », « dans 3 jours »), l'acheteur avec son courriel, le geste proposé, et un
dépliant « pourquoi cet avis ? » qui expose le raisonnement du modèle et le nomme.

Les avis **écartés** par la lecture restent affichables : un tri assisté par modèle doit pouvoir
être contredit, sinon il n'est pas contrôlable.

### Les limites sont un contenu, pas une note de bas de page

L'écran d'accueil se termine par « Ce que ce tableau ne sait pas » : les indicateurs certifiés
qui ne collectent rien, l'impossibilité de comparer deux marchés entre eux, le mélange des
périodicités, et la file d'examen qui ne se vide pas. Ce dernier point est énoncé comme ce qu'il
est — **la limite structurelle du scénario semi-automatisé**, qui se traite par un cadrage et non
par du temps supplémentaire.

La méthode complète reste disponible, **repliée** en bas de page. Elle intéresse le jury, pas le
décideur, et l'écran est fait pour le décideur.

## Vérification

`verification/executer.sh` rend **les huit écrans hors navigateur**, avec les données réelles de
l'API, et échoue si l'un d'eux lève une exception ou rend un contenu suspect. C'est ce qui a
permis de corriger avant livraison :

- une élision fautive — `L'${libelle.toLowerCase()}` produisait « L'médical » ;
- un accord impossible — « le marché ... orientée à la hausse » ;
- une date mal composée — « lundi, 24 août 2026 », virgule héritée de la locale ;
- une échéance incomposable — « le premier dernier jour » ;
- deux conventions numériques mêlées dans la même phrase.

Une application qui ne se vérifie qu'en l'ouvrant à la main n'est pas vérifiée : on regarde
l'écran qu'on vient d'écrire, jamais les sept autres.

## Ce qui n'a pas été fait, et pourquoi

- **Le point d'accès `/donnees` reste à 5,2 Mo**, dont 4,8 Mo de valeurs brutes. L'interface
  refait côté client une agrégation qui appartiendrait au SQL. À cette volumétrie l'effet est nul
  en local ; à 100 000 observations il ne le sera plus. Corriger demandait de modifier l'API de
  restitution, donc de rouvrir un workflow éprouvé à trois semaines du dépôt : le coût de
  régression dépassait le bénéfice.
- **Les pages de la v4 restent au dépôt** sans être importées. Elles sont citées au rapport comme
  itérations ; les supprimer effacerait la trace d'un travail réel.
- **Le score n'a pas été repondéré.** Voir plus haut : c'est une décision de méthode.
