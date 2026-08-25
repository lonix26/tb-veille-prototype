-- 2026-08-26 — S4 : le motif d'élagage manquait
--
-- L'élagage du 25.08 a écarté S4 (dépenses militaires par pays) sans écrire son
-- motif — seul cas sur les trente et un. Le motif est le critère 5 : l'aérospatial
-- possède déjà son signal d'avance (S7, avis TED), et S4, annuel, n'apporte pas de
-- rôle que le secteur n'ait pas. Sa ventilation par pays reste exploitée par le
-- bloc « Où le marché se déplace » de la page Aérospatial.
UPDATE indicators SET description_metier = description_metier ||
  ' [HORS VITRINE le 25.08.2026 — l''aérospatial possède déjà son signal d''avance (S7) ; la ventilation par pays reste exploitée à l''écran.]'
 WHERE indicator_id = 'S4' AND description_metier NOT LIKE '%HORS VITRINE%';
