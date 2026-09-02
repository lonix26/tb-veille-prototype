-- =====================================================================
-- A8 — LES LIBELLÉS DISENT CE QUE LA SÉRIE MESURE ; DEUX FILTRES DE
-- LIAISON CESSENT DE PASSER POUR DES LIMITES DE LA SOURCE — 02.09.2026
--
-- Item A8 du plan de correction (evaluation_critique_prototype_2026-09-02.md,
-- § 3.4 : DATA-1, DATA-3, DATA-8, DATA-9, DATA-10, DATA-11). Chaque
-- constat a été REVÉRIFIÉ avant d'écrire — sur le brut archivé, sur la
-- base ou sur la source — et le chiffre cité est celui de la
-- vérification, pas celui de l'audit.
--
-- 1. INDICATEUR SYNTHÉTIQUE (DATA-1). La vue calcule la part de la Suisse
--    dans la SOMME DES SEPT DÉCLARANTS de H3 (CHE, CHN, DEU, FRA, HKG,
--    ITA, JPN), pas dans le monde. Vérifié le 02.09.2026 par appel Comtrade
--    preview, tous déclarants, SH 91, exportations, 2023 (148 déclarants) :
--    monde 61,17 Mrd USD, Suisse 29,76 → 48,65 % ; panier des sept 48,51
--    Mrd (79,3 % du monde) → 61,35 %, identique à la vue. L'étiquette
--    « commerce mondial » sous un ratio de panier surdéclare de treize
--    points. Le calcul ne change pas : c'est l'étiquette qui devient
--    juste, en base (commentaire) et à l'écran.
--
-- 2. H7 (DATA-3). « Exportations horlogères suisses, valeur totale » ne
--    porte que les MONTRES-BRACELETS : le collecteur FH lit le tableau
--    « montres-bracelets » (total, électroniques, mécaniques) et son
--    contrôle de cohérence l'exige. Vérifié en base : H1 (Comtrade,
--    chapitre SH 91 entier, monde) converti en CHF par T2 dépasse H7 de
--    3,9 à 5,3 % sur les 19 mois de 2025-01 à 2026-07 (moyenne 4,7 %) —
--    écart régulier des autres positions du chapitre (mouvements,
--    composants, horloges), pas une contradiction entre sources.
--
-- 3. M4 (DATA-9). « Emploi et établissements » : la liaison ne demande
--    que les EMPLOIS (Beobachtungseinheit 2) et inclut deux activités
--    non industrielles. Vérifié sur M4_run212_b142.raw, 2024 : 266000 =
--    13 071, 325001 = 9 795, 325002 = 4 984, 325003 mécaniciens-dentistes
--    = 4 531, 325004 lunettes = 723 ; total 33 104, dont 15,9 % pour les
--    deux dernières. Le périmètre de la liaison n'est PAS changé — une
--    série qui change de définition sous le même identifiant est le
--    défaut de H2 (BD-11) ; l'exclure demanderait un nouvel identifiant,
--    à trancher en supervision. Le libellé dit le périmètre.
--
-- 4. M2 (DATA-11). Libellé « NACE C32, dont C32.5 » ; la liaison ne
--    demande que C32.5. Libellé aligné.
--
-- 5. A2 (DATA-10). « Véhicules neufs en Europe » : le communiqué ACEA lu
--    est « NEW CAR REGISTRATIONS, EUROPEAN UNION » (voitures
--    particulières), ligne EUROPEAN UNION, geo EU27 au registre. Vérifié
--    sur A2_run58.pdf. Le doublon 2025-11 a été rejeté à A4.
--
-- 6. M3 (DATA-8). La note imputait à la SOURCE le point unique (« ne
--    produira aucune lecture exploitable avant plusieurs exercices ») ;
--    c'est le filtre de la liaison (TimeDim ge 2023) qui le produit. La
--    série GHO existe depuis 2000. Filtre passé à 2014, note réécrite ;
--    la note de vitrine (moins de douze points) reste vraie jusqu'à la
--    prochaine collecte, qui est lancée juste après cette migration.
--
-- 7. T4 (DATA-8, à examiner). Même mécanisme : periode_min 2023 dans le
--    mappage, alors que le DataMapper du FMI publie NGDP_RPCH depuis
--    1980. Passé à 2014. La note disait « trois points SEMESTRIELS » et
--    la fréquence déclarée était « semestrielle » : les points sont des
--    années civiles (2023, 2024, 2025) ; c'est le WEO qui paraît deux
--    fois l'an, pas la série. Fréquence corrigée en « annuelle ».
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Indicateur synthétique
COMMENT ON VIEW v_indicateur_synthetique IS
'Indicateur synthétique (engagement de la ratification, séance 2) : part de la Suisse dans les exportations d''articles d''horlogerie (SH 91) d''un PANIER DE SEPT DÉCLARANTS (CHE, CHN, DEU, FRA, HKG, ITA, JPN — les déclarants de H3), PAS dans le commerce mondial. Vérifié le 02.09.2026 sur Comtrade, tous déclarants, 2023 : monde 61,17 Mrd USD → part suisse 48,65 % ; panier 48,51 Mrd (79,3 % du monde) → 61,35 %, identique à la vue. Calcul par vue, une seule source, part calculée uniquement à panier complet — sinon l''absence est énoncée avec les déclarants manquants (leçon Chine 2024, § 12.5).';

-- 2. H7
UPDATE indicators
   SET label = 'Exportations suisses de montres-bracelets, valeur (FH)',
       description_metier = 'La mesure de référence du débouché horloger, en francs — MONTRES-BRACELETS seulement : le tableau FH lu par le collecteur est celui des montres-bracelets (total, électroniques, mécaniques), non l''ensemble du chapitre SH 91 (mouvements, composants, horloges). H1 (Comtrade, chapitre entier) converti en francs lui est supérieur de 4 à 5 % chaque mois, écart régulier de périmètre et non contradiction entre sources. Remplace fonctionnellement la lecture en dollars de H1, dont la corrélation au taux CHF/USD a été mesurée à -0,40 : un sixième de sa variance était du change. Publiée à J+20 par la Fédération, à partir des statistiques douanières fédérales.'
 WHERE indicator_id = 'H7';

-- 3. M4
UPDATE indicators
   SET label = 'Emplois medtech et mécanique de précision en Suisse (NOGA 26.6, 32.5 — y c. mécaniciens-dentistes et lunetterie)',
       description_metier = 'Emplois (et non établissements) des cinq genres NOGA 266000, 325001, 325002, 325003 et 325004, Suisse entière, STATENT : la substance productive nationale du secteur. Le périmètre inclut deux activités non industrielles — mécaniciens-dentistes (325003) et fabrication de lunettes (325004), 15,9 % du total 2024 (5 254 sur 33 104, vérifié sur le brut du run 212) ; les exclure changerait la définition sous le même identifiant, ce qui se décide en supervision, pas dans un libellé.'
 WHERE indicator_id = 'M4';

-- 4. M2
UPDATE indicators
   SET label = 'Production d''instruments et fournitures médicales et dentaires UE (NACE C32.5)'
 WHERE indicator_id = 'M2';

-- 5. A2
UPDATE indicators
   SET label = 'Immatriculations de voitures particulières neuves, UE27 (ACEA)',
       description_metier = 'Immatriculations mensuelles de voitures particulières neuves dans l''Union européenne (ligne « EUROPEAN UNION » du communiqué ACEA, geo EU27) : la demande finale, en aval de la chaîne dont dépend un fournisseur de composants. Voitures particulières seulement — ni utilitaires, ni marchés hors UE.'
 WHERE indicator_id = 'A2';

-- 6. M3 — le filtre, puis la note
UPDATE source_bindings
   SET params  = jsonb_set(params::jsonb,  '{$filter}',    '"TimeDim ge 2014"'),
       mapping = jsonb_set(mapping::jsonb, '{periode_min}', '"2014"'),
       note = note || ' · 02.09.2026 (A8) : filtre TimeDim ge 2023 → ge 2014 ; le point unique au registre était l''effet de ce filtre, pas une limite de la source (GHO publie depuis 2000).'
 WHERE binding_id = 25 AND indicator_id = 'M3';

UPDATE indicators
   SET note_conception = 'ÉTAT AU 24.08.2026, corrigé le 02.09 : un seul point au registre — non parce que la source n''en publie qu''un, mais parce que la liaison filtrait TimeDim ge 2023. La série GHO (GHED_CHEGDP_SHA2011) est publiée depuis 2000. Filtre passé à 2014 le 02.09.2026 (A8) ; la profondeur se constate à la collecte suivante, pas dans cette note.

HORS VITRINE le 25.08.2026 — moins de douze points sur la zone de référence : la série ne se lit pas. Motif à réexaminer une fois la série recollectée.'
 WHERE indicator_id = 'M3';

-- 7. T4 — le mappage, la fréquence, la note
UPDATE source_bindings
   SET mapping = jsonb_set(mapping::jsonb, '{periode_min}', '"2014"'),
       note = note || ' · 02.09.2026 (A8) : periode_min 2023 → 2014 ; les trois points au registre étaient l''effet de cette borne, pas une limite de la source.'
 WHERE binding_id = 13 AND indicator_id = 'T4';

UPDATE indicators
   SET frequency = 'annuelle',
       note_conception = 'ÉTAT AU 24.08.2026, corrigé le 02.09 : trois points ANNUELS (2023, 2024, 2025 — la fréquence « semestrielle » déclarée jusqu''au 02.09 était celle des parutions du WEO, pas de la série), valeur inchangée à 3,4 %. Trois points non parce que le FMI n''en publie que trois, mais parce que le mappage bornait la lecture à 2023 ; borne passée à 2014 le 02.09.2026 (A8), la profondeur se constate à la collecte suivante. Borné à 2025 : les années 2026+ sont des projections, écartées. N''est jamais entré dans le score (seuil de huit points) et n''a jamais rien signalé. Conservé comme toile de fond documentaire.

HORS VITRINE le 25.08.2026 — moins de douze points sur la zone de référence : la série ne se lit pas. Motif à réexaminer une fois la série recollectée.'
 WHERE indicator_id = 'T4';

COMMIT;

\echo '== Libellés après A8'
SELECT indicator_id, frequency, label FROM indicators
 WHERE indicator_id IN ('H7', 'M4', 'M2', 'A2', 'M3', 'T4') ORDER BY 1;

\echo '== Liaisons M3 et T4 après A8'
SELECT binding_id, indicator_id, params::text, mapping::text
  FROM source_bindings WHERE binding_id IN (13, 25);

\echo '== Points au registre AVANT la collecte suivante (M3 CHE, T4 WORLD)'
SELECT indicator_id, geo, count(*), min(period), max(period)
  FROM v_current WHERE (indicator_id, geo) IN (('M3', 'CHE'), ('T4', 'WORLD')) GROUP BY 1, 2;

-- ---------------------------------------------------------------------
-- COMPLÉMENT après le run 213 (02.09.2026, 07:24). T4 est passé de 3 à 10
-- points, pas 12 : 2020 (-2,7 %) a été écarté au motif « valeur négative »
-- et 2021 (+6,7 %) au motif « variation anormale » calculée contre -2,7
-- (+348 %). Un taux de croissance est une grandeur SIGNÉE, à zéro
-- significatif — même cas que les soldes d'opinion T5/T8 (17.08.2026) :
-- le drapeau admet_negatifs est déclaré sur la liaison. Déclaration
-- humaine, tracée ici ; effet constaté au run suivant.
-- ---------------------------------------------------------------------
\set ON_ERROR_STOP on
BEGIN;
UPDATE source_bindings
   SET mapping = jsonb_set(mapping::jsonb, '{admet_negatifs}', 'true'),
       note = note || ' · 02.09.2026 (A8, après run 213) : admet_negatifs déclaré — 2020 (-2,7 %) écarté comme « valeur négative », 2021 écarté par ricochet (+348 % contre -2,7).'
 WHERE binding_id = 13 AND indicator_id = 'T4';
COMMIT;
\echo '== T4 : liaison après déclaration'
SELECT binding_id, mapping::text FROM source_bindings WHERE binding_id = 13;

-- ---------------------------------------------------------------------
-- COMPLÉMENT 2 après le run 214 : RETOUR EN VITRINE de M3 et T4.
-- Les deux avaient été écartés le 26.08 (§ 8.8.7) pour série courte sur
-- la zone de référence — 1 point (M3, CHE) et 3 points (T4, WORLD). Ce
-- n'était pas la source, c'était le filtre. Filtres corrigés ci-dessus,
-- runs 213 et 214 : M3 CHE = 10 points (2014-2023), T4 WORLD = 12 points
-- (2014-2025). Le seuil en vigueur est HUIT points : le motif d'exclusion
-- est tombé, l'indicateur « redevient disponible sans requalification »
-- (commentaire de la colonne en_vitrine). Même forme que le retour de
-- H2/M4 du 28.08. Les deux entrent au score de santé (sens_favorable
-- déclaré, n ≥ 8) : scores AVANT relevés dans la sortie, APRÈS ci-dessous.
-- T4 reste « seuil non configuré » : le glissement relatif d'un taux de
-- croissance n'a pas de sens (2021 : +348 %) — un seuil en points de
-- pourcentage demanderait une règle que RI4 n'a pas ; limite dite, non
-- résolue ici.
-- ---------------------------------------------------------------------
BEGIN;
UPDATE indicators
   SET en_vitrine = true,
       description_metier = replace(replace(description_metier,
         'Un seul point au registre à ce jour, la série ne se lit pas encore.',
         'Dix points annuels sur la Suisse depuis le run 213 (02.09.2026), après correction du filtre de période de la liaison.'),
         'Trois points seulement au registre, toile de fond documentaire, sans lecture conjoncturelle.',
         'Douze points annuels 2014-2025 depuis le run 214 (02.09.2026), après correction du filtre de période et déclaration des valeurs négatives (2020 : -2,7 %). Toile de fond, sans seuil de matérialité : le glissement relatif d''un taux de croissance ne se lit pas.'),
       note_conception = coalesce(note_conception || E'\n', '')
         || 'RETOUR EN VITRINE le 02.09.2026 (A8) : l''exclusion du 26.08 tenait au filtre de la liaison, pas à la source — dix points (M3, CHE) et douze points (T4, WORLD) après les runs 213-214, au-dessus du seuil de huit points (§ 8.8.7). Décision d''étudiant, à ratifier.'
 WHERE indicator_id IN ('M3', 'T4') AND NOT en_vitrine;
COMMIT;
\echo '== vitrine après'
SELECT indicator_id, en_vitrine, substr(description_metier, position('point' in description_metier) - 5, 90) FROM indicators WHERE indicator_id IN ('M3','T4');
\echo '== santé après (avant : medical -0,44 {M1,M2,M4,M7,M8} · transversal 0,51 dix indicateurs)'
SELECT sector_code, score_sante, etat, profondeur_min, indicateurs FROM v_sante_secteur ORDER BY 1;
\echo '== bilan référentiel'
SELECT * FROM v_bilan_referentiel;

-- ---------------------------------------------------------------------
-- COMPLÉMENT 3 : SEUIL DE MATÉRIALITÉ DE M3. Le seuil de 3 % a été semé
-- le 06.08 A PRIORI, sur un registre alors vide. Rendu en vitrine, M3
-- produit 132 « mouvements détectés » sur 205 zones en 2023 — un écran
-- illisible. Méthode du 10.08, celle des calibrages A7/M6 : p90 de
-- |glissement annuel| sur toutes les zones et périodes complètes (M3
-- n'en déclare aucune incomplète), arrondi vers le bas.
--   n = 1 845 · p90 19,9 % · médiane 4,7 % → 19.
-- Hors 2020-2022 (n = 1 023, ≤ 2019) le p90 vaut 15,1 % : la pandémie
-- pèse, mais la méthode ne trie pas les années, et elle est appliquée
-- telle quelle. À 19 %, 24 zones franchissent en 2023 (32 à 15 %).
-- ---------------------------------------------------------------------
\echo '== M3 : calibrage (méthode du 10.08)'
SELECT indicator_id, count(*) AS n,
       round(avg(abs(glissement_annuel_pct)), 1) AS moyenne,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY abs(glissement_annuel_pct))::numeric, 1) AS mediane,
       round(percentile_cont(0.9) WITHIN GROUP (ORDER BY abs(glissement_annuel_pct))::numeric, 1) AS p90,
       round(max(abs(glissement_annuel_pct)), 1) AS max
  FROM v_metriques
 WHERE indicator_id = 'M3' AND glissement_annuel_pct IS NOT NULL
 GROUP BY indicator_id;
BEGIN;
UPDATE indicators
   SET alert_threshold_pct = 19,
       note_conception = note_conception || E'\n'
         || 'SEUIL DE MATÉRIALITÉ 19 % (calibré le 02.09.2026, A8 : p90 de |glissement annuel| sur toutes les zones, n = 1 845, p90 19,9 %, méthode du 10.08). Le 3 % antérieur avait été semé a priori le 06.08 sur un registre vide ; il produisait 132 mouvements sur 205 zones en 2023. Hors 2020-2022 le p90 vaut 15,1 % — la méthode ne trie pas les années.'
 WHERE indicator_id = 'M3';
COMMIT;
\echo '== M3 : franchissements 2023 après'
SELECT franchissement, count(*) FROM v_metriques WHERE indicator_id='M3' AND period='2023' GROUP BY 1 ORDER BY 1;
