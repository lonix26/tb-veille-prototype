-- 2026-08-25 — Activation des quatre liaisons glissantes
--
-- POURQUOI MAINTENANT. Le portage de la collecte vers n8n a laissé quatre liaisons
-- glissantes au statut `a_verifier`, et n'a activé que leurs jumelles à fenêtre
-- littérale. Conséquence mesurée le 25.08 : H1 et A3 ont RÉGRESSÉ. Leurs observations
-- les plus récentes — H1 jusqu'à 2026-05, A3 pour 2025 — datent du run 78, à l'époque
-- des scripts. Depuis le portage, H1 ne collecte plus que 2023-2025 et A3 que
-- 2023-2024. Le dispositif se rejouait sans avancer : le défaut le plus coûteux, parce
-- qu'il est silencieux.
--
-- QUI DÉCIDE. La qualification d'une source est un acte humain nominatif (§ 10.4),
-- imposé en base par `chk_binding_verifie`. L'étudiant a délégué ces quatre
-- activations en session terminal le 25.08.2026. Le champ `verifie_par` porte cette
-- délégation en toutes lettres plutôt que la seule signature : un jury doit pouvoir
-- lire ce qui s'est réellement passé, pas ce qui aurait fait plus propre.
--
-- CE QUI A ÉTÉ VU EN RÉPONSE RÉELLE, LE 25.08.2026 :
--   97 (H2) · PX-Web OFS, POST, filtre `top: 4` → HTTP 200, 1385 o, années 2021-2024,
--             20 valeurs, aucune nulle. La liaison 29 demandait `Jahr: ["2023"]` alors
--             que 2024 EST publié : elle perdait déjà une année.
--   98 (M4) · même table, codes Wirtschaftsart médicaux → HTTP 200, 1485 o, années
--             2021-2024, 20 valeurs, aucune nulle. Même constat pour la liaison 30.
--   28 (A3) · IEA. `{{ANNEE_COURANTE}}` (2026) rend HTTP 200 avec un corps VIDE —
--             l'édition de l'année n ne paraît qu'en cours d'année n. Une liaison qui
--             a l'air active et ne collecte rien est pire qu'une liaison figée. Le
--             jeton est donc changé pour `{{ANNEE_MOINS:1}}`, ajouté au collecteur
--             dans le même geste : `year=2025` rend 604 lignes, dont 70 régions
--             utiles. Limite assumée et énoncée : au plus un an de retard sur
--             l'édition courante, et un creux possible en début d'année civile.
--   23 (H1) · NON vérifiable ici. Comtrade exige une clé d'abonnement, qui ne vit que
--             dans l'identifiant chiffré de l'orchestrateur ; la lire pour un essai
--             reviendrait à la sortir de l'endroit où elle est protégée. La
--             qualification de cette liaison est donc établie PAR L'EXÉCUTION, et le
--             `note` est complété après coup avec le run qui l'a démontrée. Si
--             l'exécution échoue, la liaison retourne à `a_verifier` — c'est écrit ici
--             avant de savoir, pour que l'engagement soit vérifiable.
--
-- LES JUMELLES LITTÉRALES PASSENT EN `suspendu` DANS LE MÊME GESTE (29 et 30), faute de
-- quoi 2023 serait collecté deux fois. Les liaisons A3 24 et 27 (2023, 2024) restent
-- actives : ce sont des éditions closes, qui ne bougeront plus.

BEGIN;

UPDATE source_bindings
   SET params = jsonb_set(params, '{year}', '"{{ANNEE_MOINS:1}}"'::jsonb)
 WHERE binding_id = 28;

UPDATE source_bindings
   SET statut      = 'actif',
       verifie_par = 'N. Castillo (délégation du 25.08.2026)',
       verifie_le  = DATE '2026-08-25'
 WHERE binding_id IN (97, 98, 28, 23);

UPDATE source_bindings
   SET statut = 'suspendu',
       note   = note || ' — DÉSACTIVÉE le 25.08.2026 : fenêtre littérale figée sur 2023, remplacée par la liaison glissante (filtre PX-Web top: 4).'
 WHERE binding_id IN (29, 30);

COMMIT;
