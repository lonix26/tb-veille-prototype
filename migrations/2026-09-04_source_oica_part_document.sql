-- =====================================================================
-- 2026-09-04 (soir) — LA NOTE DE LA SOURCE D'A1 DISAIT 2,5 %, LA PIÈCE DIT 1 %
--
-- La migration du matin (2026-09-04_source_oica_ccfa.sql) reprenait de la
-- passation du 31.08 « ~2,5 % du document » pour la part envoyée aux
-- modèles. Mesuré ce soir sur les exécutions n8n 1803-1806 du 31.08.2026
-- (données d'exécution conservées) : tranche de 5 100 caractères sur un
-- texte de 527 417, 550 155, 526 095 et 527 417 caractères selon
-- l'édition — 0,93 à 0,97 %. Le 2,5 % était une division fautive ; le
-- texte du rapport (§ 10.4) et les générateurs des annexes 2 et 4 sont
-- corrigés le même soir. Une note se corrige par migration, pas à la
-- main : la section « Sources de données » et l'annexe 1 en sont des
-- projections.
-- =====================================================================
BEGIN;
UPDATE sources
   SET notes = replace(notes,
       'Découpe par sentinelles avant envoi aux modèles (~2,5 % du document).',
       'Découpe par sentinelles avant envoi aux modèles (~1 % du document : 5 100 caractères sur ~530 000, mesuré sur les exécutions du 31.08.2026 ; corrigé de 2,5 % le 04.09).')
 WHERE source_id = 'oica';
COMMIT;
SELECT source_id, position('~1 % du document' in notes) > 0 AS corrige FROM sources WHERE source_id = 'oica';
