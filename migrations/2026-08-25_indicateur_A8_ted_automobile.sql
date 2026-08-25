-- 2026-08-25 — A8 : la demande publique adressée aux pièces mécaniques automobiles
--
-- POURQUOI. Le score de santé automobile se calcule sur trois séries — A4, A5, A6 —
-- dont AUCUNE n'est avancée : deux coïncidentes et une retardée. Même constat pour
-- l'horlogerie. Les deux marchés historiques de l'entreprise sont donc surveillés
-- dans le rétroviseur, et le dispositif portait déjà l'information qui le dit :
-- l'attribut `latence`, renseigné sur 39 indicateurs, n'était lu par aucune vue.
--
-- Pire, du point de vue d'un sous-traitant : A5 (production de véhicules) et A2
-- (immatriculations) sont en AVAL de lui dans la chaîne. La pièce est usinée des mois
-- avant que la voiture ne soit assemblée, et plus longtemps encore avant qu'elle ne
-- soit immatriculée. Ces indicateurs ne l'avertissent pas, ils le confirment.
--
-- CE QUE FAIT A8. Il compte, chaque mois, les avis de marchés publics européens
-- portant sur des moteurs et pièces mécaniques automobiles. Un avis publié aujourd'hui
-- concerne une production à six ou dix-huit mois : c'est de l'amont au sens strict, et
-- à fraîcheur immédiate — TED publie le jour même, là où Eurostat publie à deux mois.
--
-- CONSTRUCTION. Strictement celle de M7 (médical, CPV 33100000), qualifiée le
-- 20.08.2026 : douze liaisons, une par mois révolu, comptage `totalNoticeCount` sur
-- une fenêtre mensuelle fermée. Les codes CPV sont ceux du flux `ted_automobile_v2`,
-- affinés le 23.08 après analyse de 250 avis — 34310000 (moteurs), 34312000 (pièces
-- de moteurs), 34320000 (pièces mécaniques de rechange). Aucune source nouvelle n'est
-- introduite : le point d'accès, le transport et les codes sont déjà éprouvés.
--
-- RECONNAISSANCE, le 25.08.2026, en réponse réelle : 91 avis (2026-07), 89 (2026-06),
-- 90 (2026-05). Série d'un ordre de grandeur comparable à M7, donc lisible en tendance.
--
-- LA LIMITE, ÉNONCÉE AVANT D'ÊTRE DÉCOUVERTE. La commande publique ne représente
-- qu'une fraction de la demande automobile — flottes municipales, transports publics,
-- services de l'État. A8 ne mesure PAS la demande automobile ; il mesure la part
-- publique de cette demande, et fait l'hypothèse qu'elle en suit le cycle. Cette
-- hypothèse est plausible et n'est pas vérifiée. Elle le sera quand la série aura
-- assez de points pour être confrontée à A5 : c'est le genre de contrôle que le
-- dispositif rend possible et qu'il faut inscrire au calendrier plutôt que promettre.
--
-- STATUT `a_verifier` : la qualification d'une source est un acte humain nominatif.
-- Les liaisons sont SEMÉES, pas activées.

BEGIN;

INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency,
                        unit, status, description_metier, sens_favorable, latence, geo_reference)
VALUES ('A8', 'automobile',
        'Avis de marchés publics UE en pièces mécaniques automobiles (TED, CPV 34.31/34.32)',
        'ted', 'hard', 'mensuelle', 'nombre d''avis', 'a_confirmer',
        'La demande publique adressée aux pièces mécaniques automobiles, comptée à la source : le nombre d''avis de marchés publiés chaque mois au journal des marchés publics européens pour des moteurs et des pièces de rechange. En amont des commandes et des flux commerciaux, à fraîcheur immédiate — un avis publié aujourd''hui concerne une production à six ou dix-huit mois. Ne mesure que la part publique de la demande automobile : se lit en tendance, jamais en volume.',
        1, 'avance', 'EU');

-- Sans rattachement, le déclencheur `trg_indicateur_sans_question` refuse l'écriture —
-- et il a raison : un indicateur sans question de veille ne permet aucune analyse.
INSERT INTO indicator_watch_questions (indicator_id, watch_question_code)
VALUES ('A8', 'QV2'),   -- demande et débouchés
       ('A8', 'QV5');   -- impulsions publiques

-- Douze liaisons, une par mois révolu. Même patron que M7 : la fenêtre est fermée
-- (borne haute exclusive), donc le mois courant, incomplet, n'est jamais compté.
INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut, statut, note)
SELECT 'A8', 'json_generique', 'https://api.ted.europa.eu/v3/notices/search',
       jsonb_build_object(
         '_methode', 'POST',
         '_corps', jsonb_build_object(
           'limit', 1,
           'fields', jsonb_build_array('publication-number'),
           'query', 'classification-cpv IN (34310000, 34312000, 34320000) AND publication-date >= {{MOIS_DEBUT:' || k || '}} AND publication-date < {{MOIS_FIN:' || k || '}}')),
       jsonb_build_object('periode_fixe', '{{PERIODE:' || k || '}}', 'champ_scalaire', 'totalNoticeCount'),
       'EU', 'a_verifier',
       'Comptage mensuel des avis TED en pièces mécaniques automobiles, mois révolu n-' || k ||
       '. Patron de M7, qualifié le 20.08.2026. CPV repris du flux ted_automobile_v2, affinés le 23.08 après analyse de 250 avis. Reconnaissance du 25.08.2026 : 91 avis en 2026-07, 89 en 2026-06, 90 en 2026-05.'
FROM generate_series(1, 12) AS k;

COMMIT;
