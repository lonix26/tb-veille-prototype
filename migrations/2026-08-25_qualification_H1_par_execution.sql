-- 2026-08-25 — Liaison 23 (H1) : qualification établie par l'exécution
--
-- La migration `2026-08-25_activation_fenetres_glissantes.sql` s'était engagée par
-- écrit, AVANT de connaître le résultat : la liaison 23 ne pouvant pas être éprouvée
-- hors de l'orchestrateur — Comtrade exige une clé qui ne vit que dans l'identifiant
-- chiffré de n8n —, sa qualification serait établie par l'exécution, et la liaison
-- retournerait à `a_verifier` en cas d'échec.
--
-- Résultat du run 146 (`collecteGeneriqueV2`, 25.08.2026) : le jeton
-- `{{MOIS_GLISSANTS:12}}` a été résolu en 202508→202607 et la source a répondu.
-- H1 atteint **2026-07**, avec 12 mois collectés au-delà de ce que rapportaient les
-- trois liaisons littérales (arrêtées à 2025-12) : 104 partenaires en 2026-01,
-- 95 en 2026-07. La liaison est donc qualifiée, et le reste.
--
-- À noter pour la lecture de la série : avant ce run, les observations 2026 de H1
-- dataient du run 78, à l'époque des scripts. Le portage vers l'orchestrateur avait
-- fait perdre l'année courante sans rien signaler. C'est ce run qui la rétablit.

UPDATE source_bindings
   SET note = note || ' — QUALIFIÉE PAR L''EXÉCUTION, run 146 du 25.08.2026 : jeton résolu en 202508→202607, H1 porté à 2026-07 (les liaisons littérales s''arrêtaient à 2025-12).'
 WHERE binding_id = 23;
