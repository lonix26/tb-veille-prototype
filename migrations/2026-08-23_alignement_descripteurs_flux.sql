-- =====================================================================
-- Alignement base ← descripteur, généré depuis etage2/flux_vague_A.json
--
-- collecte_flux.py --charger sème avec ON CONFLICT DO NOTHING : il crée les
-- flux nouveaux et ne met JAMAIS à jour ceux qui existent. Toute modification
-- de paramètre dans le descripteur doit donc être reportée par cette
-- migration, sans quoi la base et le descripteur divergent — ce que le § 7
-- interdit explicitement.
--
-- FICHIER GÉNÉRÉ. Ne pas l'éditer à la main : modifier flux_vague_A.json,
-- puis regénérer.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE flux_sources SET parametres = '{"cpv": "33100000", "cpv_statut": "verifie_20.08.2026_via_M7", "fenetre_jours": 30, "limite": 50, "_note": " | 23.08.2026 : fenêtre portée de 7 à 30 jours (décision de l''étudiant). L''API TED est libre et le volume mensuel reste modeste ; la fenêtre courte privait la file d''examen de matière. Limite maintenue à 50 : le volume mensuel de ce CPV se compte en centaines (automobile large) ou en milliers (médical), et la file d''examen humaine ne s''inonde pas — la limite mord donc avant la fenêtre, ce qui est assumé."}'::jsonb,
       libelle = 'Avis TED — équipements et fournitures médicaux (CPV 33)'
 WHERE flux_id = 'ted_medical';
UPDATE flux_sources SET parametres = '{"cpv": "34700000", "cpv_statut": "a_verifier", "fenetre_jours": 30, "limite": 100, "_note": " | 23.08.2026 : fenêtre portée de 7 à 30 jours (décision de l''étudiant). L''API TED est libre et le volume mensuel reste modeste ; la fenêtre courte privait la file d''examen de matière. Limite portée à 100 : le volume mensuel de ce CPV tient sous ce plafond, la fenêtre n''est donc pas tronquée par la limite."}'::jsonb,
       libelle = 'Avis TED — aéronefs, engins spatiaux et équipements associés'
 WHERE flux_id = 'ted_aerospatial';
UPDATE flux_sources SET parametres = '{"cpv": "34300000", "cpv_statut": "a_verifier", "fenetre_jours": 30, "limite": 50, "_note": "CONSERVÉ EN PREUVE (décision du 23.08.2026). Le CPV 34300000 capte l''ensemble de la branche « parties et accessoires », y compris les pneumatiques et — surtout — les marchés d''entretien de flottes où il n''est qu''un code secondaire derrière 50110000/50100000. Triage du 22.08 : 49 items sur 50 notés 0, taux de rétention 2 %. Ce flux n''est pas corrigé : il documente la vigilance F3 du protocole OSINT (« bruit élevé, tri indispensable ») confirmée sur pièces. Remplacé en exploitation par ted_automobile_v2. | 23.08.2026 : fenêtre portée de 7 à 30 jours (décision de l''étudiant). L''API TED est libre et le volume mensuel reste modeste ; la fenêtre courte privait la file d''examen de matière. Limite maintenue à 50 : le volume mensuel de ce CPV se compte en centaines (automobile large) ou en milliers (médical), et la file d''examen humaine ne s''inonde pas — la limite mord donc avant la fenêtre, ce qui est assumé."}'::jsonb,
       libelle = 'Avis TED — véhicules et pièces (division 34.3)'
 WHERE flux_id = 'ted_automobile';
UPDATE flux_sources SET parametres = '{"cpv": "34310000, 34312000, 34320000", "cpv_statut": "affine_23.08.2026_verifie_en_intitules", "fenetre_jours": 30, "limite": 100, "_note": "CPV affiné le 23.08.2026 (décision d''étudiant). Analyse de 250 avis sur 30 jours : sous 34300000, les pneumatiques (34350/34351/34352) pèsent 82 avis et l''entretien de flottes 38 — ni l''un ni l''autre ne relève de l''usinage de précision. Le jeu retenu cible les pièces mécaniques usinées : 34310000 moteurs et pièces de moteurs, 34312000 pièces de moteurs, 34320000 pièces de rechange mécaniques hors moteurs. Volume divisé par six (11 avis sur 7 jours contre 70) et intitulés vérifiés en réponse réelle : « Moteurs et pièces de moteurs (véhicules) », « Pièces de moteurs », « Pièces de rechange mécaniques, excepté moteurs et parties de moteurs ». LEVIER LAISSÉ OUVERT : ajouter 34330000 (pièces de rechange pour véhicules) porterait le volume à 20 avis sur 7 jours, au prix d''un élargissement générique — non retenu, à rouvrir si le flux se révèle trop maigre. | 23.08.2026 : fenêtre portée de 7 à 30 jours (décision de l''étudiant). L''API TED est libre et le volume mensuel reste modeste ; la fenêtre courte privait la file d''examen de matière. Limite portée à 100 : le volume mensuel de ce CPV tient sous ce plafond, la fenêtre n''est donc pas tronquée par la limite."}'::jsonb,
       libelle = 'Avis TED — moteurs et pièces mécaniques automobiles (CPV 34310/34312/34320)'
 WHERE flux_id = 'ted_automobile_v2';
UPDATE flux_sources SET parametres = '{"requete": "(\"swiss watch industry\" OR \"watch exports\" OR \"horlogerie suisse\")", "fenetre": "7d", "limite": 50}'::jsonb,
       libelle = 'GDELT — actualité mondiale de l''industrie horlogère'
 WHERE flux_id = 'gdelt_horlogerie';
UPDATE flux_sources SET parametres = '{"requete": "(\"medical device\" OR \"medical devices\" OR medtech)", "fenetre": "7d", "limite": 50, "requete_statut": "simplifiee_23.08.2026", "requete_anterieure": "(\"medical device\" (regulation OR investment OR manufacturing OR recall))", "_note": "Requête simplifiée le 23.08.2026 (décision d''étudiant, notes de rédaction). L''ancienne, à parenthèses imbriquées, était refusée en permanence par la limite de cadence de GDELT (« larger queries »), après quatre paliers d''attente 20/40/60/90 s. La simplifiée répond 200 avec 50 articles, vérifié en réponse réelle le 23.08.2026."}'::jsonb,
       libelle = 'GDELT — actualité medtech (réglementation, investissements)'
 WHERE flux_id = 'gdelt_medical';
UPDATE flux_sources SET parametres = '{"requete": "(\"car production\" OR \"auto parts\" OR \"vehicle manufacturing\" OR \"EV production\")", "fenetre": "7d", "limite": 50}'::jsonb,
       libelle = 'GDELT — actualité de la filière automobile (production, électrification)'
 WHERE flux_id = 'gdelt_automobile';
UPDATE flux_sources SET parametres = '{"requete": "(\"aircraft orders\" OR \"aerospace supplier\" OR \"aircraft production\")", "fenetre": "7d", "limite": 50, "requete_statut": "simplifiee_23.08.2026", "requete_anterieure": "(aerospace (orders OR \"production rate\" OR supplier) OR \"aircraft orders\")", "_note": "Requête simplifiée le 23.08.2026, même motif que gdelt_medical. Répond 200 avec 49 articles, vérifié en réponse réelle le 23.08.2026. Bruit visible dans les intitulés (aviation de loisir, analyse boursière) : c''est au triage de le trancher, et le taux constaté sera une mesure."}'::jsonb,
       libelle = 'GDELT — actualité aérospatiale (commandes, cadences, lancements)'
 WHERE flux_id = 'gdelt_aerospatial';
UPDATE flux_sources SET parametres = '{"tickers": ["uhr.sw", "cfr.sw"], "tickers_statut": "a_verifier_symboles_stooq", "seuil_variation_pct": 5.0, "fenetre_seances": 5}'::jsonb,
       libelle = 'Cours des donneurs d''ordre horlogers — variation hebdomadaire'
 WHERE flux_id = 'marches_horlogerie';
UPDATE flux_sources SET parametres = '{"tickers": ["syk.us", "mdt.us"], "tickers_statut": "a_verifier_symboles_stooq", "seuil_variation_pct": 5.0, "fenetre_seances": 5}'::jsonb,
       libelle = 'Cours des donneurs d''ordre medtech — variation hebdomadaire'
 WHERE flux_id = 'marches_medical';
UPDATE flux_sources SET parametres = '{"tickers": ["vow3.de", "stla.us"], "tickers_statut": "a_verifier_symboles_stooq", "seuil_variation_pct": 5.0, "fenetre_seances": 5}'::jsonb,
       libelle = 'Cours des donneurs d''ordre automobiles — variation hebdomadaire'
 WHERE flux_id = 'marches_automobile';
UPDATE flux_sources SET parametres = '{"tickers": ["air.fr", "saf.fr", "ba.us"], "tickers_statut": "a_verifier_symboles_stooq", "seuil_variation_pct": 5.0, "fenetre_seances": 5}'::jsonb,
       libelle = 'Cours des donneurs d''ordre aérospatiaux — variation hebdomadaire'
 WHERE flux_id = 'marches_aerospatial';
UPDATE flux_sources SET parametres = '{"champ_date": "decision_date", "champ_id": "k_number", "champ_libelle": "device_name", "champ_acteur": "applicant", "prefixe": "FDA 510(k)", "fenetre_jours": 30, "limite": 50, "url_detail": "https://www.accessdata.fda.gov/scripts/cdrh/cfdocs/cfpmn/pmn.cfm?ID={ident}", "_note": "Ajouté le 23.08.2026, chantier des signaux faibles. AMONT AU SENS STRICT : une autorisation de mise sur le marché précède la montée en cadence de production, donc la charge d''usinage, donc toute statistique qui la constatera. Vérifié en réponse réelle le 23.08 : 161 autorisations sur 30 jours, API libre et sans clé. Fenêtre portée de 7 à 30 jours le 23.08 : sur 7 jours la recherche est vide, les décisions étant publiées avec retard."}'::jsonb,
       libelle = 'openFDA — autorisations 510(k) de dispositifs médicaux'
 WHERE flux_id = 'fda_510k_medical';
UPDATE flux_sources SET parametres = '{"champ_date": "event_date_initiated", "champ_id": "product_res_number", "champ_libelle": "product_description", "champ_acteur": "recalling_firm", "prefixe": "FDA rappel", "fenetre_jours": 30, "limite": 50, "url_detail": "", "_note": "Ajouté le 23.08.2026. Un rappel signale une défaillance de conception ou de fabrication : c''est un signal de contrainte technique en amont des exigences qui se répercuteront sur les sous-traitants. Volume faible (3 sur 30 jours au 23.08) : fenêtre portée à 30 jours à dessein."}'::jsonb,
       libelle = 'openFDA — rappels de dispositifs médicaux'
 WHERE flux_id = 'fda_rappels_medical';
UPDATE flux_sources SET parametres = '{"_note": "Ajouté le 23.08.2026 — famille F2 du protocole OSINT, prévue en vague A par CONCEPTION_ETAGE2.md mais jamais implémentée : aucun descripteur ne la portait. Vérifié en réponse réelle le 23.08 (fil RSS valide, communiqués datés). AIRBUS ÉCARTÉ à la reconnaissance : son /rss.xml répond 200 mais ne sert que la navigation du site (« Environment », « Society »), pas les communiqués — un flux qui répond n''est pas pour autant un flux exploitable. Safran 403, Stryker 404, Medtronic sert du HTML, Swatch Group en délai d''attente, ACEA rend un fil vide."}'::jsonb,
       libelle = 'Boeing — communiqués de presse (fil RSS)'
 WHERE flux_id = 'boeing_communiques';

COMMIT;

-- Vérification V24 : tous les flux du descripteur existent en base et
-- portent la fenêtre déclarée.
SELECT 'V24' AS verif, flux_id, famille,
       parametres->>'fenetre_jours' AS fenetre_jours,
       parametres->>'limite' AS limite, statut
FROM flux_sources ORDER BY famille, flux_id;