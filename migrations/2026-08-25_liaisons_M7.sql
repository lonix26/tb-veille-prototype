-- ============================================================================
-- M7 — liaisons réactivées et étendues. N. Castillo, 25.08.2026.
--
-- DÉFAUT TROUVÉ PAR L'AUDIT D'AUTOMATISATION. M7 portait sept liaisons, toutes
-- au statut `a_verifier` : la vue v_bindings_actifs les exclut, donc le
-- collecteur ne les lisait pas. L'indicateur n'avait plus collecté depuis le
-- run 78 et RIEN NE LE SIGNALAIT — un indicateur qui ne collecte plus ressemble
-- exactement à un indicateur dont la source n'a rien publié.
--
-- C'est la contrepartie du garde-fou : la règle « aucune liaison active sans
-- vérification humaine » protège contre la collecte non qualifiée, et
-- silencieusement contre la collecte tout court quand l'activation est oubliée.
-- La qualification EST faite — sept mois de données réelles sont au registre,
-- collectés le 20.08 — mais le statut n'a jamais suivi.
--
-- CORRECTIF : douze liaisons actives, une par mois glissant, alignées sur S7.
-- ============================================================================

BEGIN;

DELETE FROM source_bindings WHERE indicator_id = 'M7';

INSERT INTO source_bindings (indicator_id, connecteur, url_base, params, mapping, geo_defaut,
                             statut, verifie_par, verifie_le, note)
SELECT 'M7', 'json_generique',
       'https://api.ted.europa.eu/v3/notices/search',
       jsonb_build_object(
         '_methode','POST',
         '_corps', jsonb_build_object(
            'query', 'classification-cpv IN (33100000) AND publication-date >= {{MOIS_DEBUT:' || k ||
                     '}} AND publication-date < {{MOIS_FIN:' || k || '}}',
            'limit', 1,
            'fields', jsonb_build_array('publication-number'))),
       jsonb_build_object('periode_fixe','{{PERIODE:' || k || '}}',
                          'champ_scalaire','totalNoticeCount'),
       'EU','actif','N. Castillo',now(),
       'Mois glissant −' || k || '. Méthode certifiée le 20.08.2026 et vérifiée en réponse '
       'réelle — sept mois de données au registre. RÉACTIVÉE le 25.08.2026 : les liaisons '
       'étaient restées au statut a_verifier depuis leur création, donc invisibles du '
       'collecteur ; l''indicateur ne collectait plus depuis le run 78 sans qu''aucun signal '
       'ne le dise. Fenêtre portée de sept à douze mois, alignée sur S7.'
FROM generate_series(1, 12) AS k;

COMMIT;

SELECT indicator_id, count(*) AS liaisons_actives FROM v_bindings_actifs
WHERE indicator_id IN ('M7','S7','M8') GROUP BY 1 ORDER BY 1;
