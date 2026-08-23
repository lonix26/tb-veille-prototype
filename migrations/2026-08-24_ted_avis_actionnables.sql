-- =====================================================================
-- Avis TED enrichis — rendre la restitution ACTIONNABLE — 24.08.2026
--
-- DÉCISION DE L'ÉTUDIANT du 23.08.2026 (soir) : le tableau de bord décrit
-- l'état des DONNÉES au lieu de l'état du MARCHÉ, et rien n'y déclenche
-- d'action. Priorité absolue à l'utilité pratique, délai assumé.
--
-- CE QUI MANQUAIT, et qui était disponible depuis le début : la collecte TED
-- ne demandait que cinq champs. L'API en expose 1832. Quatre changent tout :
--
--   * notice-type : « cn-standard » = APPEL D'OFFRES OUVERT (on peut
--     soumissionner) ; « can-standard » = ATTRIBUTION (déjà décidé). Les
--     confondre, c'est présenter comme prospect un marché déjà attribué —
--     ce que faisait l'écran « Opportunités » sur ses onze lignes.
--   * deadline-receipt-tender-date-lot : la date limite de dépôt. Sans elle,
--     une liste de prospection ne dit pas si l'on peut encore agir.
--   * buyer-email / buyer-internet-address : le contact direct. Une
--     opportunité sans interlocuteur n'est pas une opportunité.
--   * estimated-value-lot : l'ordre de grandeur, qui décide si cela vaut le
--     déplacement.
--
-- POURQUOI UNE TABLE SÉPARÉE plutôt qu'un enrichissement de flux_items :
-- flux_items est en AJOUT SEUL et dédupliqué par empreinte. Recollecter les
-- mêmes avis avec plus de champs serait rejeté comme doublon. La table
-- ci-dessous porte les spécificités « marchés publics » sans toucher au
-- registre générique des items, et se rattache par le numéro de publication.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS ted_avis (
    publication_number  TEXT PRIMARY KEY,
    item_id             BIGINT REFERENCES flux_items(item_id),
    flux_id             TEXT REFERENCES flux_sources(flux_id),
    sector_code         TEXT REFERENCES sectors(code),
    notice_type         TEXT,          -- cn-standard = ouvert, can-standard = attribué
    est_appel_ouvert    BOOLEAN,       -- dérivé, pour la lecture
    date_publication    DATE,
    date_limite         DATE,          -- NULL sur une attribution : normal, pas manquant
    titre               TEXT,
    acheteur            TEXT,
    acheteur_pays       TEXT,
    acheteur_ville      TEXT,
    acheteur_courriel   TEXT,
    acheteur_site       TEXT,
    valeur_estimee      NUMERIC,
    devise              TEXT,
    cpv                 TEXT[],
    nature_contrat      TEXT,
    url                 TEXT,
    raw_ref             TEXT NOT NULL,  -- pièce brute (E6)
    collecte_le         TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE ted_avis IS
  'Avis TED enrichis des champs qui rendent la restitution actionnable : type d''avis (ouvert / attribué), date limite de dépôt, contact de l''acheteur, valeur estimée. Table séparée de flux_items, qui est en ajout seul et dédupliqué : la recollecte enrichie y serait rejetée comme doublon.';
COMMENT ON COLUMN ted_avis.date_limite IS
  'Date limite de réception des offres. NULL sur un avis d''ATTRIBUTION — c''est normal et non un manque : un marché attribué n''a plus d''échéance.';
COMMENT ON COLUMN ted_avis.est_appel_ouvert IS
  'Vrai si l''avis est un appel à candidature (cn-*). Un avis d''attribution (can-*) n''est PAS une opportunité de soumission : c''est du renseignement de marché — qui achète, combien, à quelle fréquence.';

CREATE INDEX IF NOT EXISTS idx_ted_avis_lecture ON ted_avis (est_appel_ouvert, date_limite);
CREATE INDEX IF NOT EXISTS idx_ted_avis_acheteur ON ted_avis (acheteur, sector_code);

-- ---------------------------------------------------------------------
-- Vue 1 — LES APPELS ENCORE OUVERTS. C'est la seule liste sur laquelle un
-- dirigeant peut agir aujourd'hui.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_appels_ouverts AS
SELECT a.*,
       (a.date_limite - CURRENT_DATE) AS jours_restants,
       CASE WHEN a.date_limite - CURRENT_DATE <= 7  THEN 'urgent'
            WHEN a.date_limite - CURRENT_DATE <= 21 THEN 'proche'
            ELSE 'confortable' END AS urgence
FROM ted_avis a
WHERE a.est_appel_ouvert
  AND a.date_limite IS NOT NULL
  AND a.date_limite >= CURRENT_DATE
ORDER BY a.date_limite;

COMMENT ON VIEW v_appels_ouverts IS
  'Appels d''offres dont la date limite n''est pas passée. Un avis expiré ou déjà attribué n''y figure pas : le proposer serait faire perdre son temps au décideur.';

-- ---------------------------------------------------------------------
-- Vue 2 — LES ACHETEURS RÉCURRENTS. Le renseignement le plus directement
-- exploitable du corpus, et il était invisible : un acheteur qui publie
-- plusieurs marchés de pièces en un mois n'est pas un coup isolé, c'est un
-- compte à démarcher. Aucune IA ici — c'est un décompte.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_acheteurs_recurrents AS
SELECT a.acheteur, a.acheteur_pays, a.acheteur_courriel, a.acheteur_site, a.sector_code,
       count(*)                                          AS avis_publies,
       count(*) FILTER (WHERE a.est_appel_ouvert)        AS dont_appels,
       count(*) FILTER (WHERE NOT a.est_appel_ouvert)    AS dont_attributions,
       min(a.date_publication)                           AS premier_avis,
       max(a.date_publication)                           AS dernier_avis,
       sum(a.valeur_estimee) FILTER (WHERE a.devise = 'EUR') AS valeur_eur_connue,
       array_agg(DISTINCT c ORDER BY c) FILTER (WHERE c IS NOT NULL) AS cpv_distincts
FROM ted_avis a
LEFT JOIN LATERAL unnest(a.cpv) AS c ON TRUE
WHERE a.acheteur IS NOT NULL
GROUP BY a.acheteur, a.acheteur_pays, a.acheteur_courriel, a.acheteur_site, a.sector_code
HAVING count(*) >= 2
ORDER BY count(*) DESC, max(a.date_publication) DESC;

COMMENT ON VIEW v_acheteurs_recurrents IS
  'Acheteurs publics ayant publié au moins deux avis sur la période collectée. Un acheteur récurrent est un compte à démarcher, pas un événement — c''est le renseignement que la liste d''avis, prise ligne à ligne, ne donne jamais.';

COMMIT;

-- ---------------------------------------------------------------------
-- Vérifications — attendus AVANT exécution :
--   V46 : la table et les deux vues existent, la table est vide.
--   V47 : les vues rendent 0 ligne — rien n'est encore collecté.
-- ---------------------------------------------------------------------
SELECT 'V46' AS verif,
       (SELECT count(*) FROM information_schema.tables
         WHERE table_name IN ('ted_avis','v_appels_ouverts','v_acheteurs_recurrents')) AS objets,
       (SELECT count(*) FROM ted_avis) AS lignes;
SELECT 'V47' AS verif, (SELECT count(*) FROM v_appels_ouverts) AS appels_ouverts,
       (SELECT count(*) FROM v_acheteurs_recurrents) AS acheteurs_recurrents;
