-- ============================================================================
-- FÉDÉRATION HORLOGÈRE — la source certifiée qui ne portait aucun indicateur.
-- N. Castillo, 24.08.2026.
--
-- La FH figurait au référentiel en « certifiée » depuis le 07.08.2026 et ne
-- portait AUCUN indicateur : les exportations horlogères étaient collectées
-- chez Comtrade, en dollars, alors que le § 5.2 de la partie théorique citait
-- nommément la FH comme source de commerce extérieur pour l'horlogerie.
--
-- CE QUE LA FH APPORTE :
--   1. les montants sont en FRANCS. La corrélation entre l'indicateur horloger
--      en dollars (H1) et le taux CHF/USD a été mesurée à -0,40 : un sixième de
--      la variance de la série phare du secteur était du change, pas de la
--      demande. H7 supprime ce biais.
--   2. la publication intervient à J+20 environ, contre plusieurs mois pour la
--      statistique consolidée du commerce international.
--   3. la ventilation MÉCANIQUE / ÉLECTRONIQUE, qui est LA distinction utile à
--      un atelier d'usinage : une montre mécanique mobilise des dizaines de
--      pièces usinées à tolérances serrées, une montre à quartz très peu. Au
--      dernier point, les mécaniques font 85,7 % de la VALEUR exportée pour
--      38,6 % du VOLUME — deux marchés de même valeur n'appellent donc pas la
--      même charge d'atelier selon leur mix.
--
-- PROFONDEUR, ET CE QU'ELLE ENSEIGNE. Le document ne porte que dix-neuf mois de
-- détail mensuel, et les millésimes antérieurs ne sont plus servis — vérifié le
-- 24.08.2026, ils renvoient la page d'accueil. La profondeur ne peut donc pas
-- être téléchargée : elle doit être ACCUMULÉE par le dispositif, mois après
-- mois. C'est le registre en ajout seul qui gagne ici sa raison d'être, et
-- l'illustration la plus nette de la thèse du § 7 : ce n'est pas la collecte
-- qui fait la tendance, c'est la ré-exécution datée.
-- ============================================================================

BEGIN;

-- Le connecteur est un script, faute de `pdftotext` dans l'image de
-- l'orchestrateur (vérifié le 24.08.2026). Le référentiel doit décrire la
-- réalité, pas la commodité : on déclare le connecteur tel qu'il est.
ALTER TABLE source_bindings DROP CONSTRAINT IF EXISTS source_bindings_connecteur_check;
ALTER TABLE source_bindings ADD CONSTRAINT source_bindings_connecteur_check
  CHECK (connecteur IN ('eurostat_jsonstat','owid_csv','csv_generique','json_generique',
                        'xlsx_indexe','pdf_tableau_script'));

INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency,
                        unit, status, alert_threshold_pct, description_metier,
                        sens_favorable, latence, geo_reference)
VALUES
('H7','horlogerie','Exportations horlogères suisses, valeur totale (FH)','fh','hard','mensuelle',
 'mio CHF','certifie',8,
 'La mesure de référence du débouché horloger, EN FRANCS. Remplace fonctionnellement '
 'la lecture en dollars de H1, dont la corrélation au taux CHF/USD a été mesurée à '
 '-0,40 : un sixième de sa variance était du change. Publiée à J+20 par la '
 'Fédération, à partir des statistiques douanières fédérales.',
 1,'coincident','CH'),

('H8','horlogerie','Exportations de montres mécaniques, valeur (FH)','fh','hard','mensuelle',
 'mio CHF','certifie',8,
 'LA PART USINÉE DU DÉBOUCHÉ HORLOGER. Une montre mécanique mobilise des dizaines de '
 'pièces usinées à tolérances serrées ; une montre à quartz en mobilise peu. C''est '
 'donc cette série, et non la valeur horlogère totale, qui commande la charge d''un '
 'atelier de décolletage. À lire avec H7 : leur rapport est le mix.',
 1,'coincident','CH'),

('H9','horlogerie','Exportations de montres mécaniques, volume (FH)','fh','hard','mensuelle',
 'milliers de pièces','certifie',8,
 'Le VOLUME mécanique, distinct de sa valeur. Un atelier facture des pièces, pas des '
 'francs : une montée en gamme peut accroître la valeur exportée sans accroître le '
 'nombre de montres produites, donc sans accroître la charge d''usinage. C''est '
 'précisément le point de vigilance que le mécanisme de QV1 énonce — une montée en '
 'valeur qui masquerait l''érosion du tissu de sous-traitance — et H9 le rend '
 'observable pour la première fois.',
 1,'coincident','CH')
ON CONFLICT (indicator_id) DO NOTHING;

INSERT INTO indicator_watch_questions (indicator_id, watch_question_code) VALUES
('H7','QV2'), ('H8','QV1'), ('H8','QV2'), ('H9','QV1')
ON CONFLICT DO NOTHING;

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut,
                             statut, verifie_par, verifie_le, note)
SELECT c.code, 'pdf_tableau_script',
       'https://www.fhs.swiss/fre/statistics.html',
       '{"document":"histo_elec-meca","langue":"f","format":"PDF"}'::jsonb,
       jsonb_build_object('colonne', c.colonne,
                          'extraction', 'pdftotext -layout',
                          'lien_depuis_index', '/scripts/getstat.php?file=histo_elec-meca_<millesime>_f.pdf'),
       'CH','actif','N. Castillo',now(),
       'Vu en réponse réelle le 24.08.2026 : 19 lignes mensuelles, 2025-01 à 2026-07. '
       'Contrôle de cohérence avant écriture — électroniques + mécaniques contre total : '
       'écart moyen 0,00 %, maximum 0,01 %, ordre des colonnes confirmé. Collecteur : '
       'prototype/collecteurs/collecte_fh_horlogerie.py. Extraction DÉTERMINISTE et non '
       'par IA : le document contient un tableau, seule son enveloppe est non structurée — '
       'à la différence du communiqué ACEA, dont les chiffres sont en prose, ce qui '
       'justifie là une chaîne composite multi-modèles.'
FROM (VALUES ('H7','total_chf'), ('H8','meca_chf'), ('H9','meca_pieces')) AS c(code, colonne)
ON CONFLICT DO NOTHING;

COMMIT;

SELECT indicator_id, unit, frequency, geo_reference FROM indicators
WHERE indicator_id IN ('H7','H8','H9') ORDER BY 1;
