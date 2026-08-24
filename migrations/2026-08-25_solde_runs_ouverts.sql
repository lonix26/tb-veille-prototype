-- ============================================================================
-- SOLDE DES EXÉCUTIONS RESTÉES OUVERTES — N. Castillo, 25.08.2026.
--
-- CONSTAT. Trente-six exécutions portaient encore le statut `en_cours` alors
-- qu'aucune ne tournait. Elles proviennent de workflows interrompus avant leur
-- nœud de clôture : appel d'API en échec, délai d'attente dépassé, ou — cause la
-- plus fréquente pendant le portage du 25.08 — exception levée parce qu'il n'y
-- avait RIEN à traiter, ce qui est le cas nominal d'un dispositif rejoué.
--
-- Sans incidence sur les données : les vues lisent toujours le run le plus
-- récent par période. Mais `v_sante_des_runs` comptait des exécutions ouvertes
-- qui ne l'étaient plus, ce qui rend la vue de santé inutilisable — et une vue
-- de santé à laquelle on ne peut pas se fier est pire que pas de vue du tout.
--
-- CORRECTIF DE FOND, appliqué le même jour aux workflows concernés : le garde
-- « y a-t-il quelque chose à faire ? » est placé AVANT l'ouverture du run, et
-- non après. Un run qui n'a rien fait n'existe désormais pas.
--
-- Les exécutions sont soldées en `echec` avec leur motif, non supprimées : la
-- trace de ce qui a été tenté fait partie de l'historique.
-- ============================================================================

BEGIN;

UPDATE runs
   SET status = 'echec',
       closed_at = now(),
       note = coalesce(note, '(sans note)')
            || ' · SOLDÉE LE 25.08.2026 : exécution interrompue avant son nœud de clôture, '
            || 'jamais reprise. Statut mis à jour pour que v_sante_des_runs cesse de compter '
            || 'des exécutions ouvertes qui ne le sont plus. Le correctif de fond — ouvrir le '
            || 'run seulement s''il y a matière — a été appliqué aux workflows le même jour.'
 WHERE status = 'en_cours'
   AND executed_at < now() - interval '10 minutes';

COMMIT;

SELECT status, count(*) FROM runs GROUP BY status ORDER BY 2 DESC;
