-- =====================================================================
-- SOCLE — structure de la base de veille (PostgreSQL 16)
-- TB « Exploration de l'IA pour les entreprises industrielles »
--
-- PROVENANCE. Ce fichier est CONSOLIDÉ : il est produit par `pg_dump
-- --schema-only` de la base en service au 25.08.2026, après application des
-- 78 migrations du dossier `migrations/`. Il remplace le socle écrit à la main
-- du 04.08 (conservé tel quel dans `db_origine_2026-08-04/`, et dans git).
--
-- POURQUOI CONSOLIDER. Le rejeu des 78 migrations sur une base neuve a été
-- essayé le 25.08 : 69 passent, 9 échouent — dépendances circulaires entre
-- migrations d'un même jour (une vue référence une colonne ajoutée par une
-- migration postérieure), migrations de données qui présupposent des
-- observations collectées, migrations rendues caduques par le socle lui-même.
-- La base n'était donc PAS reconstructible depuis le dépôt : elle ne tenait
-- que par l'état accumulé dans le conteneur en service. Le socle consolidé
-- rétablit la reproductibilité, qui est la condition de l'auditabilité.
--
-- CE QUE DEVIENT `migrations/`. Le dossier reste au dépôt comme JOURNAL du
-- travail — il porte le raisonnement, les corrections et leurs motifs, et
-- c'est à ce titre qu'il est cité au rapport. Il n'est plus la voie de
-- construction de la base. Toute migration POSTÉRIEURE au 25.08 s'applique
-- normalement par-dessus ce socle.
--
-- LES COMMENTAIRES MÉTIER SONT PRÉSERVÉS : ils sont portés par des
-- `COMMENT ON` en base, que le dump restitue. Chaque contrainte continue de
-- porter la règle métier qu'elle fait respecter — le schéma ne se contente
-- pas de stocker ce que le rapport décrit, il rend impossible ce qu'il
-- interdit (réserve R-1 de l'évaluation critique).
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

--
-- PostgreSQL database dump
--


-- Dumped from database version 16.14
-- Dumped by pg_dump version 16.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: sandbox; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS sandbox;


--
-- Name: SCHEMA sandbox; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA sandbox IS 'Espace de l''artefact agentique du scénario C (§ 10.5). DÉLIBÉRÉMENT SANS CONTRAINTES : l''agent publie sans validation, et cette absence de garde-fou est l''objet même de la comparaison. Aucune vue du tableau de bord ne lit ce schéma.';


--
-- Name: appliquer_filtrage_flux(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.appliquer_filtrage_flux() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE r record; n integer := 0;
BEGIN
  FOR r IN
    SELECT rg.regle_code, rg.seuil,
           t.item_id,
           t.anteriorite + t.portee + t.pertinence AS note,
           t.anteriorite
      FROM flux_filtrage_regles rg
      JOIN flux_triage_ia t ON t.doctrine = 'signal'
     WHERE rg.active
       AND rg.regle_code = 'seuil_v1'
       AND t.anteriorite + t.portee + t.pertinence < rg.seuil
       AND t.anteriorite < 2                                   -- garde-fou
       AND NOT EXISTS (SELECT 1 FROM flux_filtrage f WHERE f.item_id = t.item_id)
       AND NOT EXISTS (SELECT 1 FROM flux_examens x WHERE x.item_id = t.item_id)
  LOOP
    INSERT INTO flux_filtrage (item_id, regle_code, note_ia, anteriorite, motif)
    VALUES (r.item_id, r.regle_code, r.note, r.anteriorite,
            format('Note %s/6 (< %s), antériorité %s : écarté par règle %s.',
                   r.note, r.seuil, r.anteriorite, r.regle_code));
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;


--
-- Name: cle_evenement(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cle_evenement(titre text, url text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT CASE
    WHEN length(t) >= 25 THEN 'T:' || t
    ELSE 'U:' || u
  END
  FROM (
    SELECT btrim(regexp_replace(lower(coalesce(titre, '')), '[[:space:][:punct:]]+', ' ', 'g')) AS t,
           btrim(regexp_replace(
                   regexp_replace(
                     regexp_replace(lower(coalesce(url, '')), '^https?://(www\.)?', ''),
                   '[?#].*$', ''),
                 '/+$', '')) AS u
  ) n;
$_$;


--
-- Name: FUNCTION cle_evenement(titre text, url text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.cle_evenement(titre text, url text) IS 'Clé de regroupement des reprises syndiquées. Correspondance EXACTE du titre normalisé (casse, ponctuation, espaces), repli sur l''URL normalisée pour les titres de moins de 25 caractères. Volontairement conservatrice : un faux regroupement fait disparaître un signal, un doublon se voit seulement.';


--
-- Name: exiger_question_de_veille(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.exiger_question_de_veille() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM indicator_watch_questions WHERE indicator_id = NEW.indicator_id) THEN
        RAISE EXCEPTION
          'Indicateur % sans question de veille rattachée. Un indicateur sans question ne permet aucune analyse (§ 8.1.2) : il est écarté quelle que soit la qualité de sa source.',
          NEW.indicator_id;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: f_filtrage_ajout_seul(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.f_filtrage_ajout_seul() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'flux_filtrage est en ajout seul (D-18) : un filtrage ne se '
                  'corrige pas par écrasement mais par un verdict d''audit.';
END $$;


--
-- Name: interdire_modification_du_registre(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.interdire_modification_du_registre() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION
      'Le registre des valeurs est en ajout seul (D-18). Pour corriger une valeur, ajoutez-la dans un nouveau run : la correction fait partie de l''historique, elle ne l''efface pas.';
END;
$$;


--
-- Name: interdire_modification_flux(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.interdire_modification_flux() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION
      'flux_items est en ajout seul : un item se corrige par une nouvelle collecte, jamais par modification — l''historique du flux fait partie de la preuve.';
END;
$$;


--
-- Name: periode_annee_precedente(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.periode_annee_precedente(p text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
BEGIN
    IF p ~ '^\d{4}$' THEN
        RETURN (p::int - 1)::text;
    ELSIF p ~ '^\d{4}-.+$' THEN
        RETURN (left(p, 4)::int - 1)::text || substr(p, 5);
    ELSE
        RETURN NULL;   -- format non reconnu : pas de rapprochement inventé
    END IF;
END;
$_$;


--
-- Name: FUNCTION periode_annee_precedente(p text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.periode_annee_precedente(p text) IS 'Étiquette de la période homologue de l''année précédente. Renvoie NULL sur un format non reconnu plutôt que de deviner.';


--
-- Name: sante_a_la_date(timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sante_a_la_date(p_limite timestamp with time zone) RETURNS TABLE(sector_code text, n_series bigint, score numeric)
    LANGUAGE sql STABLE
    AS $$
  WITH courant AS (
    SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo)
           iv.indicator_id, iv.period, iv.geo, iv.value
      FROM indicator_values iv
     WHERE iv.validation_status = ANY (ARRAY['valide_source','pre_valide_consensus','valide_humain'])
       AND iv.collected_at <= p_limite
     ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC
  ), rang AS (
    SELECT c.indicator_id, c.period, c.value,
           row_number() OVER (PARTITION BY c.indicator_id ORDER BY c.period)::numeric AS t
      FROM courant c
      JOIN indicators i ON i.indicator_id = c.indicator_id
                       AND i.geo_reference IS NOT NULL AND c.geo = i.geo_reference
  ), droite AS (
    SELECT rang.indicator_id,
           regr_slope(rang.value::double precision, rang.t::double precision)     AS pente,
           regr_intercept(rang.value::double precision, rang.t::double precision) AS ordonnee,
           count(*) AS n_points
      FROM rang GROUP BY rang.indicator_id
  ), residus AS (
    SELECT r.indicator_id, r.t,
           r.value::double precision - (d.ordonnee + d.pente * r.t::double precision) AS residu
      FROM rang r JOIN droite d USING (indicator_id)
  ), resume AS (
    SELECT re.indicator_id,
           stddev_samp(re.residu)::numeric AS sd_residu,
           (array_agg(re.residu ORDER BY re.t DESC))[1]::numeric AS dernier_residu
      FROM residus re GROUP BY re.indicator_id
  ), par_indicateur AS (
    SELECT i.sector_code, i.indicator_id,
           r.dernier_residu / NULLIF(r.sd_residu, 0) * i.sens_favorable::numeric AS z
      FROM resume r JOIN droite d USING (indicator_id) JOIN indicators i USING (indicator_id)
     WHERE i.sens_favorable IN (-1, 1) AND i.status = 'certifie'
       AND r.sd_residu IS NOT NULL AND r.sd_residu > 0 AND d.n_points >= 8
  )
  SELECT p.sector_code, count(*),
         CASE WHEN count(*) >= 2 THEN round(avg(p.z), 2) END
    FROM par_indicateur p GROUP BY p.sector_code;
$$;


--
-- Name: FUNCTION sante_a_la_date(p_limite timestamp with time zone); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.sante_a_la_date(p_limite timestamp with time zone) IS 'Score de santé sectorielle tel qu''il était à une date donnée. Identique à v_sante_secteur, borné aux observations collectées avant cette date. Le registre étant en ajout seul, l''état passé est intact : ce n''est pas une reconstitution.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alerts (
    alert_id bigint NOT NULL,
    indicator_id text NOT NULL,
    run_id bigint NOT NULL,
    rule text NOT NULL,
    observed_value numeric NOT NULL,
    variation_pct numeric,
    message text,
    triggered_at timestamp with time zone DEFAULT now() NOT NULL,
    validated_by text,
    validated_at timestamp with time zone,
    CONSTRAINT chk_alerte_validee_tracee CHECK (((validated_by IS NULL) OR (validated_at IS NOT NULL)))
);


--
-- Name: alerts_alert_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.alerts_alert_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: alerts_alert_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.alerts_alert_id_seq OWNED BY public.alerts.alert_id;


--
-- Name: commentaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commentaries (
    commentary_id bigint NOT NULL,
    run_id bigint NOT NULL,
    sector_code text NOT NULL,
    watch_question_code text,
    input_payload jsonb NOT NULL,
    model text NOT NULL,
    text text NOT NULL,
    status text DEFAULT 'a_valider'::text NOT NULL,
    validated_by text,
    validated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_commentaire_valide_trace CHECK (((status <> 'valide'::text) OR ((validated_by IS NOT NULL) AND (validated_at IS NOT NULL)))),
    CONSTRAINT commentaries_status_check CHECK ((status = ANY (ARRAY['a_valider'::text, 'valide'::text, 'rejete'::text])))
);


--
-- Name: COLUMN commentaries.input_payload; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.commentaries.input_payload IS 'Conservation du contexte exact fourni au modèle. Sans lui, la fidélité du commentaire (« aucun chiffre absent des données fournies ») est invérifiable a posteriori — l''affirmation du § 11.2 deviendrait indémontrable.';


--
-- Name: commentaries_commentary_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.commentaries_commentary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: commentaries_commentary_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.commentaries_commentary_id_seq OWNED BY public.commentaries.commentary_id;


--
-- Name: composite_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.composite_queue (
    doc_id bigint NOT NULL,
    indicator_id text NOT NULL,
    period text NOT NULL,
    geo text DEFAULT 'EU27'::text NOT NULL,
    source_doc text NOT NULL,
    statut text DEFAULT 'a_verifier'::text NOT NULL,
    verifie_par text,
    verifie_le date,
    run_id bigint,
    traite_le timestamp with time zone,
    note text,
    CONSTRAINT chk_doc_verifie CHECK (((statut <> ALL (ARRAY['a_traiter'::text, 'traite'::text])) OR ((verifie_par IS NOT NULL) AND (verifie_le IS NOT NULL)))),
    CONSTRAINT composite_queue_statut_check CHECK ((statut = ANY (ARRAY['a_verifier'::text, 'a_traiter'::text, 'traite'::text, 'ecarte'::text])))
);


--
-- Name: TABLE composite_queue; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.composite_queue IS 'File de documents du pipeline composite (mise en série du 17.08.2026). Le veilleur inscrit et vérifie les documents ; le workflow consomme le plus ancien a_traiter. L''inscription est l''acte humain de sélection du scénario B.';


--
-- Name: composite_queue_doc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.composite_queue_doc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: composite_queue_doc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.composite_queue_doc_id_seq OWNED BY public.composite_queue.doc_id;


--
-- Name: discovery_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discovery_log (
    log_id bigint NOT NULL,
    source_url text NOT NULL,
    statut_traitement text NOT NULL,
    motif text NOT NULL,
    modeles_proposants jsonb NOT NULL,
    nb_modeles integer,
    http_status integer,
    constate_le timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT discovery_log_statut_traitement_check CHECK ((statut_traitement = ANY (ARRAY['non_verifiable'::text, 'doublon_referentiel'::text])))
);


--
-- Name: TABLE discovery_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.discovery_log IS 'Journal des propositions écartées. Mesure continue du taux d''invention par modèle sur la tâche d''identification de sources, en régime d''exploitation et non en laboratoire.';


--
-- Name: discovery_log_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discovery_log_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discovery_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discovery_log_log_id_seq OWNED BY public.discovery_log.log_id;


--
-- Name: flux_examens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flux_examens (
    examen_id bigint NOT NULL,
    item_id bigint NOT NULL,
    decision text NOT NULL,
    signal_id bigint,
    decide_par text NOT NULL,
    decide_le timestamp with time zone DEFAULT now() NOT NULL,
    note text,
    CONSTRAINT chk_promotion_rattachee CHECK (((decision <> 'promu_signal'::text) OR (signal_id IS NOT NULL))),
    CONSTRAINT flux_examens_decision_check CHECK ((decision = ANY (ARRAY['promu_signal'::text, 'ecarte'::text, 'contexte'::text])))
);


--
-- Name: TABLE flux_examens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.flux_examens IS 'Décisions humaines sur les items de flux, nominatives et datées. C''est la seule porte entre le flux et le décideur : l''IA trie, l''humain décide, la chaîne signals valide.';


--
-- Name: flux_examens_examen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flux_examens_examen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flux_examens_examen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flux_examens_examen_id_seq OWNED BY public.flux_examens.examen_id;


--
-- Name: flux_filtrage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flux_filtrage (
    item_id bigint NOT NULL,
    regle_code text NOT NULL,
    note_ia smallint NOT NULL,
    anteriorite smallint,
    motif text NOT NULL,
    filtre_le timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: flux_filtrage_audit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flux_filtrage_audit (
    audit_id bigint NOT NULL,
    item_id bigint NOT NULL,
    echantillon text NOT NULL,
    verdict text NOT NULL,
    audite_par text NOT NULL,
    audite_le timestamp with time zone DEFAULT now() NOT NULL,
    note text,
    CONSTRAINT flux_filtrage_audit_verdict_check CHECK ((verdict = ANY (ARRAY['confirme'::text, 'faux_negatif'::text])))
);


--
-- Name: flux_filtrage_audit_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flux_filtrage_audit_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flux_filtrage_audit_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flux_filtrage_audit_audit_id_seq OWNED BY public.flux_filtrage_audit.audit_id;


--
-- Name: flux_filtrage_regles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flux_filtrage_regles (
    regle_code text NOT NULL,
    libelle text NOT NULL,
    enonce text NOT NULL,
    seuil smallint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    cree_le timestamp with time zone DEFAULT now() NOT NULL,
    fondement text NOT NULL
);


--
-- Name: flux_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flux_items (
    item_id bigint NOT NULL,
    flux_id text NOT NULL,
    run_id bigint,
    date_publication date,
    titre text NOT NULL,
    url text,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    empreinte text NOT NULL,
    raw_ref text NOT NULL,
    collecte_le timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE flux_items; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.flux_items IS 'Items collectés par l''étage 2, en AJOUT SEUL. Un item n''est ni une observation de série ni un signal : c''est un candidat brut, qui n''atteint jamais le décideur sans examen humain (flux_examens) puis chaîne signals.';


--
-- Name: flux_items_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flux_items_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flux_items_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flux_items_item_id_seq OWNED BY public.flux_items.item_id;


--
-- Name: flux_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flux_sources (
    flux_id text NOT NULL,
    famille text NOT NULL,
    sector_code text,
    libelle text NOT NULL,
    url_base text NOT NULL,
    parametres jsonb DEFAULT '{}'::jsonb NOT NULL,
    statut text DEFAULT 'a_verifier'::text NOT NULL,
    qualified_by text,
    qualified_at date,
    note text,
    CONSTRAINT chk_flux_qualifie_trace CHECK (((statut = 'a_verifier'::text) OR ((qualified_by IS NOT NULL) AND (qualified_at IS NOT NULL)))),
    CONSTRAINT flux_sources_famille_check CHECK ((famille = ANY (ARRAY['marches_publics'::text, 'communications'::text, 'actualite'::text, 'marches_financiers'::text, 'registres'::text, 'trafic'::text, 'brevets_flux'::text, 'emploi'::text, 'reglementaire'::text]))),
    CONSTRAINT flux_sources_statut_check CHECK ((statut = ANY (ARRAY['a_verifier'::text, 'actif'::text, 'ecarte'::text])))
);


--
-- Name: TABLE flux_sources; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.flux_sources IS 'Descripteurs déclaratifs des flux de l''étage 2 (CONCEPTION_ETAGE2.md). Même principe que source_bindings : ajouter un flux est une déclaration, pas un développement. Un flux écarté avec motif est un résultat (protocole OSINT).';


--
-- Name: flux_triage_ia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flux_triage_ia (
    triage_id bigint NOT NULL,
    item_id bigint NOT NULL,
    modele text NOT NULL,
    pertinence smallint NOT NULL,
    sector_code text,
    watch_question_code text,
    resume text,
    justification text,
    horodatage timestamp with time zone DEFAULT now() NOT NULL,
    doctrine text DEFAULT 'evenement'::text NOT NULL,
    anteriorite smallint,
    portee smallint,
    CONSTRAINT flux_triage_ia_anteriorite_check CHECK (((anteriorite >= 0) AND (anteriorite <= 2))),
    CONSTRAINT flux_triage_ia_doctrine_check CHECK ((doctrine = ANY (ARRAY['evenement'::text, 'signal'::text]))),
    CONSTRAINT flux_triage_ia_pertinence_check CHECK (((pertinence >= 0) AND (pertinence <= 2))),
    CONSTRAINT flux_triage_ia_portee_check CHECK (((portee >= 0) AND (portee <= 2)))
);


--
-- Name: TABLE flux_triage_ia; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.flux_triage_ia IS 'Scores de triage produits par modèle sur les items de flux. Le triage ordonne la lecture du veilleur, il ne valide rien : aucune colonne de statut, à dessein. Tâche réversible → un modèle unique et économique suffit (§ 9.4.2 : sur tâche contrainte, le coût décide). Le taux d''erreur se mesure par échantillon relu (v_triage_a_echantillonner).';


--
-- Name: COLUMN flux_triage_ia.doctrine; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.flux_triage_ia.doctrine IS 'Doctrine de triage appliquée. « evenement » : première passe du 22-23.08, score de pertinence seul. « signal » : seconde passe du 23.08, qui score en plus l''antériorité et la portée. Les deux coexistent sur le même corpus — l''écart entre elles est une mesure, pas une correction.';


--
-- Name: COLUMN flux_triage_ia.anteriorite; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.flux_triage_ia.anteriorite IS '0 = relaie une information déjà publiée par la statistique officielle (revue de presse) ; 1 = simultané ou non encore statistique ; 2 = en amont, ne figurera dans aucune statistique avant plusieurs mois. C''est l''axe qui sépare la veille anticipative de la revue de presse.';


--
-- Name: COLUMN flux_triage_ia.portee; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.flux_triage_ia.portee IS 'Si l''information se confirmait, changerait-elle quelque chose pour une PME suisse de mécanique de précision sous-traitante ? 0 = non ; 1 = indirectement ; 2 = directement (charge d''usinage, matière, accès au marché, exigence technique).';


--
-- Name: flux_triage_ia_triage_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flux_triage_ia_triage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flux_triage_ia_triage_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flux_triage_ia_triage_id_seq OWNED BY public.flux_triage_ia.triage_id;


--
-- Name: indicator_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.indicator_values (
    value_id bigint NOT NULL,
    indicator_id text NOT NULL,
    run_id bigint NOT NULL,
    period text NOT NULL,
    geo text DEFAULT 'WORLD'::text NOT NULL,
    value numeric NOT NULL,
    obtained_by text NOT NULL,
    validation_status text NOT NULL,
    consensus_score numeric,
    validated_by text,
    validated_at timestamp with time zone,
    raw_ref text NOT NULL,
    collected_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_consensus_reserve_ia CHECK (((consensus_score IS NULL) OR (obtained_by = 'ia_extraction'::text))),
    CONSTRAINT chk_consensus_unanime CHECK (((validation_status <> 'pre_valide_consensus'::text) OR (consensus_score = (1)::numeric))),
    CONSTRAINT chk_hierarchie_controle CHECK ((((obtained_by = 'etl'::text) AND (validation_status = ANY (ARRAY['valide_source'::text, 'rejete'::text]))) OR ((obtained_by = 'ia_extraction'::text) AND (validation_status = ANY (ARRAY['pre_valide_consensus'::text, 'valide_humain'::text, 'rejete'::text]))))),
    CONSTRAINT chk_validation_humaine_tracee CHECK (((validation_status <> 'valide_humain'::text) OR ((validated_by IS NOT NULL) AND (validated_at IS NOT NULL)))),
    CONSTRAINT indicator_values_consensus_score_check CHECK (((consensus_score IS NULL) OR ((consensus_score >= (0)::numeric) AND (consensus_score <= (1)::numeric)))),
    CONSTRAINT indicator_values_obtained_by_check CHECK ((obtained_by = ANY (ARRAY['etl'::text, 'ia_extraction'::text]))),
    CONSTRAINT indicator_values_validation_status_check CHECK ((validation_status = ANY (ARRAY['valide_source'::text, 'pre_valide_consensus'::text, 'valide_humain'::text, 'rejete'::text])))
);


--
-- Name: TABLE indicator_values; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.indicator_values IS 'Registre des valeurs. En AJOUT SEUL : une valeur n''est jamais modifiée ni supprimée, chaque exécution ajoute ses observations. C''est l''implémentation de l''outil vivant (D-18) — l''écart entre runs est la tendance.';


--
-- Name: COLUMN indicator_values.validation_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.indicator_values.validation_status IS 'Aucun statut « en attente » ici : une valeur non tranchée n''entre pas au registre, elle attend dans validation_queue. Le registre ne contient que du décidé.';


--
-- Name: indicator_values_value_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.indicator_values_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: indicator_values_value_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.indicator_values_value_id_seq OWNED BY public.indicator_values.value_id;


--
-- Name: indicator_watch_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.indicator_watch_questions (
    indicator_id text NOT NULL,
    watch_question_code text NOT NULL
);


--
-- Name: TABLE indicator_watch_questions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.indicator_watch_questions IS 'Relation multiple : un indicateur peut répondre à plusieurs questions (ex. H3 → QV2 et QV3).';


--
-- Name: indicators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.indicators (
    indicator_id text NOT NULL,
    sector_code text NOT NULL,
    label text NOT NULL,
    source_id text NOT NULL,
    category text NOT NULL,
    frequency text NOT NULL,
    unit text NOT NULL,
    status text NOT NULL,
    alert_threshold_pct numeric,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    description_metier text,
    sens_favorable smallint,
    latence text,
    geo_reference text,
    en_vitrine boolean DEFAULT false NOT NULL,
    note_conception text,
    CONSTRAINT indicators_category_check CHECK ((category = ANY (ARRAY['hard'::text, 'composite'::text]))),
    CONSTRAINT indicators_frequency_check CHECK ((frequency = ANY (ARRAY['mensuelle'::text, 'trimestrielle'::text, 'semestrielle'::text, 'annuelle'::text, 'bisannuelle'::text]))),
    CONSTRAINT indicators_latence_check CHECK ((latence = ANY (ARRAY['retarde'::text, 'coincident'::text, 'avance'::text, 'flux'::text]))),
    CONSTRAINT indicators_sens_favorable_check CHECK ((sens_favorable = ANY (ARRAY['-1'::integer, 0, 1]))),
    CONSTRAINT indicators_status_check CHECK ((status = ANY (ARRAY['certifie'::text, 'a_confirmer'::text, 'restreint'::text])))
);


--
-- Name: COLUMN indicators.description_metier; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.indicators.description_metier IS 'Destiné au LECTEUR du tableau de bord : ce que l''indicateur mesure, pourquoi il compte pour un atelier, comment le lire sans se tromper. Ni date de décision, ni code de règle, ni mention de score ou de vitrine — cela relève de note_conception.';


--
-- Name: COLUMN indicators.sens_favorable; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.indicators.sens_favorable IS 'Orientation de lecture : +1 = une hausse est favorable au secteur, -1 = défavorable, 0 = non orientable. NULL = non déclaré — l''indicateur n''entre pas dans v_sante_secteur. Déclaration humaine par indicateur, jamais présumée (doctrine admet_negatifs).';


--
-- Name: COLUMN indicators.latence; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.indicators.latence IS 'Position temporelle de l''indicateur par rapport au cycle réel du marché : retardé, coïncident, avancé, ou flux (étage 2). Sert le critère d''utilité de la grille (CONCEPTION_ETAGE2.md § 5).';


--
-- Name: COLUMN indicators.geo_reference; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.indicators.geo_reference IS 'Zone de la série retenue pour le calcul de la santé sectorielle. DÉCLARATION HUMAINE : NULL = non déclaré, l''indicateur n''entre pas dans v_sante_secteur. Remplace l''heuristique « zone la plus fournie » du 23.08, qui désignait l''Andorre pour H1 (42 zones à égalité, départage alphabétique). Troisième application de la doctrine admet_negatifs / sens_favorable : ce que le code présumerait, la base l''exige écrit.';


--
-- Name: COLUMN indicators.en_vitrine; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.indicators.en_vitrine IS 'L''indicateur fait-il partie de la grille suivie et affichée ? Distinct de `status`, qui qualifie la source. Un indicateur écarté de la vitrine reste au référentiel avec ses observations et redevient disponible sans requalification.';


--
-- Name: COLUMN indicators.note_conception; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.indicators.note_conception IS 'Destiné au JURY et à la reprise du dispositif : journal des décisions portant sur cet indicateur (retraits du score, redondances mesurées, changements de source, mises hors vitrine, inapplicabilité de règles). Jamais affiché sur un écran de décision.';


--
-- Name: runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.runs (
    run_id bigint NOT NULL,
    executed_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone,
    trigger_type text NOT NULL,
    scenario text DEFAULT 'B'::text NOT NULL,
    status text DEFAULT 'en_cours'::text NOT NULL,
    note text,
    CONSTRAINT runs_scenario_check CHECK ((scenario = 'B'::text)),
    CONSTRAINT runs_status_check CHECK ((status = ANY (ARRAY['en_cours'::text, 'ok'::text, 'partiel'::text, 'echec'::text]))),
    CONSTRAINT runs_trigger_type_check CHECK ((trigger_type = ANY (ARRAY['schedule'::text, 'manual'::text])))
);


--
-- Name: COLUMN runs.scenario; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.runs.scenario IS 'Le schéma de production n''accepte que le scénario B. Les exécutions du scénario C vivent dans le schéma sandbox, sans contact avec ces données.';


--
-- Name: runs_run_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.runs_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: runs_run_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.runs_run_id_seq OWNED BY public.runs.run_id;


--
-- Name: sector_watch_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sector_watch_questions (
    sector_code text NOT NULL,
    watch_question_code text NOT NULL,
    formulation text NOT NULL,
    mecanisme text NOT NULL,
    criticite text NOT NULL,
    reponse_gabarit text,
    CONSTRAINT sector_watch_questions_criticite_check CHECK ((criticite = ANY (ARRAY['dominante'::text, 'significative'::text, 'marginale'::text])))
);


--
-- Name: TABLE sector_watch_questions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.sector_watch_questions IS 'Instanciation sectorielle (§ 8.1.2). Le § 8.1.2 annonçait cette instanciation depuis la phase 1 sans la matérialiser : cette table clôt cet écart. Le champ mecanisme est ce qui distingue une instanciation d''une paraphrase.';


--
-- Name: COLUMN sector_watch_questions.reponse_gabarit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sector_watch_questions.reponse_gabarit IS 'Gabarit de la réponse calculée affichée sous la question (jetons {ID.champ} résolus à l''écran depuis v_dernier_point). NULL = pas de réponse composable (question découverte ou porteur sans point). Créé le 28.08.2026.';


--
-- Name: sectors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sectors (
    code text NOT NULL,
    label text NOT NULL
);


--
-- Name: signals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.signals (
    signal_id bigint NOT NULL,
    run_id bigint NOT NULL,
    sector_code text NOT NULL,
    watch_question_code text NOT NULL,
    source_doc text NOT NULL,
    raw_ref text NOT NULL,
    evenement text,
    acteur text,
    echeance text,
    zone text,
    extraits jsonb NOT NULL,
    score_recoupement numeric,
    statut text DEFAULT 'a_valider'::text NOT NULL,
    validated_by text,
    validated_at timestamp with time zone,
    note_validation text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_signal_decide_trace CHECK (((statut = 'a_valider'::text) OR ((validated_by IS NOT NULL) AND (validated_at IS NOT NULL)))),
    CONSTRAINT signals_score_recoupement_check CHECK (((score_recoupement >= (0)::numeric) AND (score_recoupement <= (1)::numeric))),
    CONSTRAINT signals_statut_check CHECK ((statut = ANY (ARRAY['a_valider'::text, 'valide'::text, 'rejete'::text])))
);


--
-- Name: TABLE signals; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.signals IS 'Signaux qualitatifs extraits de documents non périodiques par la chaîne multi-modèles (workflow extraction_signal_qualitatif). Distinct du registre des valeurs : un signal est un événement, pas une observation de série. Validation humaine systématique — le recoupement inter-modèles est indicatif, jamais suffisant sur du qualitatif.';


--
-- Name: COLUMN signals.note_validation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.signals.note_validation IS 'Portée du signal pour un sous-traitant, rédigée par le validateur humain. Volontairement absente du schéma d''extraction : c''est une interprétation, pas un fait du document — la faire produire par les modèles reviendrait à déléguer la lecture stratégique.';


--
-- Name: signals_signal_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.signals_signal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: signals_signal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.signals_signal_id_seq OWNED BY public.signals.signal_id;


--
-- Name: source_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_bindings (
    binding_id bigint NOT NULL,
    indicator_id text NOT NULL,
    connecteur text NOT NULL,
    url_base text NOT NULL,
    params jsonb DEFAULT '{}'::jsonb NOT NULL,
    mapping jsonb DEFAULT '{}'::jsonb NOT NULL,
    geo_defaut text DEFAULT 'WORLD'::text NOT NULL,
    statut text DEFAULT 'a_verifier'::text NOT NULL,
    verifie_par text,
    verifie_le timestamp with time zone,
    note text,
    CONSTRAINT chk_binding_verifie CHECK (((statut <> 'actif'::text) OR ((verifie_par IS NOT NULL) AND (verifie_le IS NOT NULL)))),
    CONSTRAINT source_bindings_connecteur_check CHECK ((connecteur = ANY (ARRAY['eurostat_jsonstat'::text, 'owid_csv'::text, 'csv_generique'::text, 'json_generique'::text, 'xlsx_indexe'::text, 'pdf_tabulaire_indexe'::text]))),
    CONSTRAINT source_bindings_statut_check CHECK ((statut = ANY (ARRAY['a_verifier'::text, 'actif'::text, 'suspendu'::text])))
);


--
-- Name: TABLE source_bindings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.source_bindings IS 'Socle déclaratif de collecte (§ 10.6). Ajouter un indicateur au flux est une configuration, non un développement. Aucune liaison n''est active sans vérification nominative de ses paramètres contre l''API réelle.';


--
-- Name: COLUMN source_bindings.statut; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.source_bindings.statut IS 'a_verifier : paramètres plausibles, jamais testés — le collecteur les ignore. actif : vérifiés sur pièce par la personne nommée. suspendu : source devenue inatteignable, conservée pour trace.';


--
-- Name: source_bindings_binding_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.source_bindings_binding_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_bindings_binding_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.source_bindings_binding_id_seq OWNED BY public.source_bindings.binding_id;


--
-- Name: source_qualification_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_qualification_queue (
    item_id bigint NOT NULL,
    source_url text NOT NULL,
    source_name text,
    sector_code text,
    watch_question_code text,
    besoin text,
    propositions jsonb NOT NULL,
    nb_modeles integer NOT NULL,
    indice_recouvrement numeric NOT NULL,
    http_status integer NOT NULL,
    verifiee_le timestamp with time zone NOT NULL,
    decision text,
    decided_by text,
    decided_at timestamp with time zone,
    CONSTRAINT source_qualification_queue_decision_check CHECK (((decision IS NULL) OR (decision = ANY (ARRAY['inscrite'::text, 'ecartee'::text, 'differee'::text]))))
);


--
-- Name: source_qualification_queue_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.source_qualification_queue_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_qualification_queue_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.source_qualification_queue_item_id_seq OWNED BY public.source_qualification_queue.item_id;


--
-- Name: sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sources (
    source_id text NOT NULL,
    name text NOT NULL,
    organisation text NOT NULL,
    url text NOT NULL,
    frequency text NOT NULL,
    format text NOT NULL,
    access text NOT NULL,
    qualification_status text NOT NULL,
    qualified_by text NOT NULL,
    qualified_at timestamp with time zone DEFAULT now() NOT NULL,
    notes text,
    CONSTRAINT sources_access_check CHECK ((access = ANY (ARRAY['libre'::text, 'libre_quota'::text, 'inscription'::text, 'payant'::text]))),
    CONSTRAINT sources_qualification_status_check CHECK ((qualification_status = ANY (ARRAY['certifiee'::text, 'a_confirmer'::text, 'restreinte'::text])))
);


--
-- Name: COLUMN sources.qualified_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sources.qualified_by IS 'Qualification manuelle obligatoire. Aucune source n''entre au référentiel sans décision humaine tracée (§ 10.4.2).';


--
-- Name: ted_avis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ted_avis (
    publication_number text NOT NULL,
    item_id bigint,
    flux_id text,
    sector_code text,
    notice_type text,
    est_appel_ouvert boolean,
    date_publication date,
    date_limite date,
    titre text,
    acheteur text,
    acheteur_pays text,
    acheteur_ville text,
    acheteur_courriel text,
    acheteur_site text,
    valeur_estimee numeric,
    devise text,
    cpv text[],
    nature_contrat text,
    url text,
    raw_ref text NOT NULL,
    collecte_le timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE ted_avis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ted_avis IS 'Avis TED enrichis des champs qui rendent la restitution actionnable : type d''avis (ouvert / attribué), date limite de dépôt, contact de l''acheteur, valeur estimée. Table séparée de flux_items, qui est en ajout seul et dédupliqué : la recollecte enrichie y serait rejetée comme doublon.';


--
-- Name: COLUMN ted_avis.est_appel_ouvert; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ted_avis.est_appel_ouvert IS 'Vrai si l''avis est un appel à candidature (cn-*). Un avis d''attribution (can-*) n''est PAS une opportunité de soumission : c''est du renseignement de marché — qui achète, combien, à quelle fréquence.';


--
-- Name: COLUMN ted_avis.date_limite; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ted_avis.date_limite IS 'Date limite de réception des offres. NULL sur un avis d''ATTRIBUTION — c''est normal et non un manque : un marché attribué n''a plus d''échéance.';


--
-- Name: ted_lecture_ia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ted_lecture_ia (
    lecture_id bigint NOT NULL,
    publication_number text NOT NULL,
    modele text NOT NULL,
    adressable smallint NOT NULL,
    piece_concernee text,
    action_proposee text,
    justification text,
    horodatage timestamp with time zone DEFAULT now() NOT NULL,
    profil text DEFAULT 'A_metier_declare'::text NOT NULL,
    CONSTRAINT ted_lecture_ia_adressable_check CHECK (((adressable >= 0) AND (adressable <= 2)))
);


--
-- Name: TABLE ted_lecture_ia; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ted_lecture_ia IS 'Lecture décisionnelle des appels d''offres ouverts par un modèle unique. « adressable » : 0 = hors du savoir-faire d''un usineur de précision, 1 = périphérique, 2 = cœur de métier. Ce n''est PAS une décision : aucun statut n''est modifié, l''avis officiel reste à un clic. Confrontable au jugement humain, donc mesurable.';


--
-- Name: COLUMN ted_lecture_ia.profil; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ted_lecture_ia.profil IS 'Profil métier ayant produit la lecture. A_metier_declare est le profil de référence, seul servi à la restitution ; les autres n''existent que pour la mesure de sensibilité et ne doivent jamais atteindre un écran.';


--
-- Name: ted_lecture_ia_lecture_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ted_lecture_ia_lecture_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ted_lecture_ia_lecture_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ted_lecture_ia_lecture_id_seq OWNED BY public.ted_lecture_ia.lecture_id;


--
-- Name: v_acheteurs_recurrents; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_acheteurs_recurrents AS
 SELECT acheteur,
    acheteur_pays,
    acheteur_courriel,
    acheteur_site,
    sector_code,
    count(*) AS avis_publies,
    count(*) FILTER (WHERE est_appel_ouvert) AS dont_appels,
    count(*) FILTER (WHERE (NOT est_appel_ouvert)) AS dont_attributions,
    count(*) FILTER (WHERE (date_limite >= CURRENT_DATE)) AS dont_encore_ouverts,
    min(date_publication) AS premier_avis,
    max(date_publication) AS dernier_avis,
    sum(valeur_estimee) FILTER (WHERE (devise = 'EUR'::text)) AS valeur_eur_connue,
    ( SELECT array_agg(DISTINCT c.c ORDER BY c.c) AS array_agg
           FROM public.ted_avis b,
            LATERAL unnest(b.cpv) c(c)
          WHERE ((b.acheteur = a.acheteur) AND (NOT (b.sector_code IS DISTINCT FROM a.sector_code)))) AS cpv_distincts
   FROM public.ted_avis a
  WHERE (acheteur IS NOT NULL)
  GROUP BY acheteur, acheteur_pays, acheteur_courriel, acheteur_site, sector_code
 HAVING (count(*) >= 2)
  ORDER BY (count(*)) DESC, (max(date_publication)) DESC;


--
-- Name: VIEW v_acheteurs_recurrents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_acheteurs_recurrents IS 'Acheteurs publics ayant publié au moins deux avis sur la période. Un acheteur récurrent est un compte à démarcher, pas un événement. Corrigé le 24.08.2026 : la jointure LATERAL sur les CPV multipliait le décompte des avis.';


--
-- Name: v_actions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_actions AS
 WITH recurrence AS (
         SELECT v_acheteurs_recurrents.acheteur,
            sum(v_acheteurs_recurrents.avis_publies) AS avis_publies,
            sum(v_acheteurs_recurrents.dont_encore_ouverts) AS dont_encore_ouverts
           FROM public.v_acheteurs_recurrents
          GROUP BY v_acheteurs_recurrents.acheteur
        )
 SELECT a.publication_number,
    a.sector_code,
    a.titre,
    a.url,
    a.acheteur,
    a.acheteur_pays,
    a.acheteur_ville,
    a.acheteur_courriel,
    a.acheteur_site,
    a.valeur_estimee,
    a.devise,
    a.cpv,
    a.nature_contrat,
    a.date_publication,
    a.date_limite,
    (a.date_limite - CURRENT_DATE) AS jours_restants,
        CASE
            WHEN ((a.date_limite - CURRENT_DATE) <= 7) THEN 'urgent'::text
            WHEN ((a.date_limite - CURRENT_DATE) <= 21) THEN 'proche'::text
            ELSE 'confortable'::text
        END AS urgence,
    l.adressable,
    l.piece_concernee,
    l.action_proposee,
    l.justification,
    l.modele,
    r.avis_publies AS acheteur_avis_publies,
    r.dont_encore_ouverts AS acheteur_appels_ouverts,
    (r.acheteur IS NOT NULL) AS acheteur_recurrent
   FROM ((public.ted_avis a
     LEFT JOIN public.ted_lecture_ia l ON (((l.publication_number = a.publication_number) AND (l.profil = 'A_metier_declare'::text))))
     LEFT JOIN recurrence r ON ((r.acheteur = a.acheteur)))
  WHERE (a.est_appel_ouvert AND (a.date_limite IS NOT NULL) AND (a.date_limite >= CURRENT_DATE));


--
-- Name: v_current; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_current AS
 SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo) iv.indicator_id,
    i.label AS indicator_label,
    i.sector_code,
    i.category,
    i.unit,
    iv.period,
    iv.geo,
    iv.value,
    iv.validation_status,
    iv.obtained_by,
    iv.consensus_score,
    iv.raw_ref,
    s.organisation AS source_organisation,
    s.url AS source_url,
    iv.run_id,
    r.executed_at
   FROM (((public.indicator_values iv
     JOIN public.indicators i ON ((i.indicator_id = iv.indicator_id)))
     JOIN public.sources s ON ((s.source_id = i.source_id)))
     JOIN public.runs r ON ((r.run_id = iv.run_id)))
  WHERE (iv.validation_status <> 'rejete'::text)
  ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC;


--
-- Name: VIEW v_current; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_current IS 'Ce que le tableau de bord affiche. Toute ligne porte son statut de validation et sa source : le décideur sait toujours ce qu''il regarde et d''où cela vient (E6).';


--
-- Name: v_metriques; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_metriques AS
 WITH base AS (
         SELECT c_1.indicator_id,
            c_1.indicator_label,
            c_1.sector_code,
            c_1.category,
            c_1.unit,
            c_1.period,
            c_1.geo,
            c_1.value,
            c_1.validation_status,
            c_1.obtained_by,
            c_1.source_organisation,
            c_1.source_url,
            c_1.raw_ref,
            c_1.run_id,
            c_1.executed_at,
            i.frequency,
            i.alert_threshold_pct
           FROM (public.v_current c_1
             JOIN public.indicators i ON ((i.indicator_id = c_1.indicator_id)))
        ), fenetres AS (
         SELECT b.indicator_id,
            b.indicator_label,
            b.sector_code,
            b.category,
            b.unit,
            b.period,
            b.geo,
            b.value,
            b.validation_status,
            b.obtained_by,
            b.source_organisation,
            b.source_url,
            b.raw_ref,
            b.run_id,
            b.executed_at,
            b.frequency,
            b.alert_threshold_pct,
            lag(b.value) OVER w AS valeur_periode_precedente,
            lag(b.period) OVER w AS periode_precedente,
            avg(b.value) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS mm_12,
            count(b.value) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS n_12,
            min(b.period) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS debut_12,
            avg(b.value) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mm_4,
            count(b.value) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS n_4,
            min(b.period) OVER (PARTITION BY b.indicator_id, b.geo ORDER BY b.period ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS debut_4
           FROM base b
          WINDOW w AS (PARTITION BY b.indicator_id, b.geo ORDER BY b.period)
        ), rapproche AS (
         SELECT f.indicator_id,
            f.indicator_label,
            f.sector_code,
            f.category,
            f.unit,
            f.period,
            f.geo,
            f.value,
            f.validation_status,
            f.obtained_by,
            f.source_organisation,
            f.source_url,
            f.raw_ref,
            f.run_id,
            f.executed_at,
            f.frequency,
            f.alert_threshold_pct,
            f.valeur_periode_precedente,
            f.periode_precedente,
            f.mm_12,
            f.n_12,
            f.debut_12,
            f.mm_4,
            f.n_4,
            f.debut_4,
            public.periode_annee_precedente(f.period) AS periode_homologue,
            a.value AS valeur_annee_precedente,
                CASE f.frequency
                    WHEN 'mensuelle'::text THEN f.mm_12
                    WHEN 'trimestrielle'::text THEN f.mm_4
                    ELSE NULL::numeric
                END AS moyenne_mobile_annuelle,
                CASE f.frequency
                    WHEN 'mensuelle'::text THEN f.n_12
                    WHEN 'trimestrielle'::text THEN f.n_4
                    ELSE NULL::bigint
                END AS nb_points_moyenne,
                CASE f.frequency
                    WHEN 'mensuelle'::text THEN 12
                    WHEN 'trimestrielle'::text THEN 4
                    ELSE NULL::integer
                END AS nb_points_attendus,
                CASE f.frequency
                    WHEN 'mensuelle'::text THEN f.debut_12
                    WHEN 'trimestrielle'::text THEN f.debut_4
                    ELSE NULL::text
                END AS debut_fenetre
           FROM (fenetres f
             LEFT JOIN base a ON (((a.indicator_id = f.indicator_id) AND (a.geo = f.geo) AND (a.period = public.periode_annee_precedente(f.period)))))
        ), calcule AS (
         SELECT r.indicator_id,
            r.indicator_label,
            r.sector_code,
            r.category,
            r.unit,
            r.period,
            r.geo,
            r.value,
            r.validation_status,
            r.obtained_by,
            r.source_organisation,
            r.source_url,
            r.raw_ref,
            r.run_id,
            r.executed_at,
            r.frequency,
            r.alert_threshold_pct,
            r.valeur_periode_precedente,
            r.periode_precedente,
            r.mm_12,
            r.n_12,
            r.debut_12,
            r.mm_4,
            r.n_4,
            r.debut_4,
            r.periode_homologue,
            r.valeur_annee_precedente,
            r.moyenne_mobile_annuelle,
            r.nb_points_moyenne,
            r.nb_points_attendus,
            r.debut_fenetre,
                CASE
                    WHEN ((r.valeur_periode_precedente IS NULL) OR (r.valeur_periode_precedente = (0)::numeric)) THEN NULL::numeric
                    ELSE round((((r.value - r.valeur_periode_precedente) / r.valeur_periode_precedente) * (100)::numeric), 2)
                END AS variation_periode_pct,
                CASE
                    WHEN ((r.valeur_annee_precedente IS NULL) OR (r.valeur_annee_precedente = (0)::numeric)) THEN NULL::numeric
                    ELSE round((((r.value - r.valeur_annee_precedente) / r.valeur_annee_precedente) * (100)::numeric), 2)
                END AS glissement_annuel_pct,
                CASE
                    WHEN ((r.moyenne_mobile_annuelle IS NULL) OR (r.moyenne_mobile_annuelle = (0)::numeric)) THEN NULL::numeric
                    ELSE round((((r.value - r.moyenne_mobile_annuelle) / r.moyenne_mobile_annuelle) * (100)::numeric), 2)
                END AS ecart_a_la_moyenne_pct
           FROM rapproche r
        )
 SELECT indicator_id,
    indicator_label,
    sector_code,
    category,
    frequency,
    unit,
    period,
    geo,
    value,
    periode_precedente,
    valeur_periode_precedente,
    variation_periode_pct,
    periode_homologue,
    valeur_annee_precedente,
    glissement_annuel_pct,
    round(moyenne_mobile_annuelle, 2) AS moyenne_mobile_annuelle,
    nb_points_moyenne,
    nb_points_attendus,
    debut_fenetre,
    ecart_a_la_moyenne_pct,
    alert_threshold_pct AS seuil_materialite_pct,
        CASE
            WHEN (alert_threshold_pct IS NULL) THEN 'seuil non configure'::text
            WHEN (glissement_annuel_pct IS NOT NULL) THEN
            CASE
                WHEN (abs(glissement_annuel_pct) >= alert_threshold_pct) THEN 'franchi'::text
                ELSE 'sous le seuil'::text
            END
            WHEN (variation_periode_pct IS NOT NULL) THEN
            CASE
                WHEN (abs(variation_periode_pct) >= alert_threshold_pct) THEN 'franchi (variation de periode, faute de glissement)'::text
                ELSE 'sous le seuil (variation de periode, faute de glissement)'::text
            END
            ELSE 'indeterminable'::text
        END AS franchissement,
    validation_status,
    obtained_by,
    source_organisation,
    source_url,
    raw_ref,
    run_id,
    executed_at,
    TRIM(BOTH ' '::text FROM concat_ws(' · '::text,
        CASE
            WHEN (periode_homologue IS NULL) THEN 'glissement annuel impossible : format de periode non reconnu'::text
            ELSE NULL::text
        END,
        CASE
            WHEN ((periode_homologue IS NOT NULL) AND (valeur_annee_precedente IS NULL)) THEN (('glissement annuel indisponible : periode '::text || periode_homologue) || ' absente du registre'::text)
            ELSE NULL::text
        END,
        CASE
            WHEN (nb_points_attendus IS NULL) THEN ('moyenne mobile annuelle non applicable : serie '::text || frequency)
            ELSE NULL::text
        END,
        CASE
            WHEN ((nb_points_attendus IS NOT NULL) AND (nb_points_moyenne < nb_points_attendus)) THEN ((((('moyenne mobile partielle : '::text || nb_points_moyenne) || ' point(s) sur '::text) || nb_points_attendus) || ', depuis '::text) || debut_fenetre)
            ELSE NULL::text
        END,
        CASE
            WHEN (alert_threshold_pct IS NULL) THEN 'seuil de materialite non configure (RI4 inapplicable)'::text
            ELSE NULL::text
        END)) AS completude
   FROM calcule c;


--
-- Name: VIEW v_metriques; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_metriques IS 'Métriques exigées par RI2, RI4 et RI5, calculées de manière déterministe. Aucune valeur n''est écrite au registre : la vue hérite de la provenance de ses entrants. La colonne completude énonce toute métrique manquante et sa raison — l''absence se dit, elle ne se comble pas.';


--
-- Name: v_alertes_candidates; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_alertes_candidates AS
 SELECT indicator_id,
    indicator_label,
    sector_code,
    period,
    geo,
    value,
    unit,
    glissement_annuel_pct,
    variation_periode_pct,
    seuil_materialite_pct,
    franchissement,
    validation_status,
        CASE
            WHEN (validation_status = ANY (ARRAY['valide_source'::text, 'valide_humain'::text])) THEN true
            ELSE false
        END AS diffusable,
        CASE
            WHEN (validation_status = ANY (ARRAY['valide_source'::text, 'valide_humain'::text])) THEN ''::text
            ELSE (('retenue : statut '::text || validation_status) || ' insuffisant pour une notification au decideur'::text)
        END AS motif_de_retenue,
    source_organisation,
    source_url,
    raw_ref,
    completude
   FROM public.v_metriques
  WHERE (franchissement ~~ 'franchi%'::text)
  ORDER BY sector_code, indicator_id, period DESC;


--
-- Name: VIEW v_alertes_candidates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_alertes_candidates IS 'Franchissements de seuil. « Candidates » et non « alertes » : la colonne diffusable applique RI5 — une valeur non validée ne remonte pas au décideur, mais reste visible ici avec son motif de retenue.';


--
-- Name: v_appels_ouverts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_appels_ouverts AS
 SELECT publication_number,
    item_id,
    flux_id,
    sector_code,
    notice_type,
    est_appel_ouvert,
    date_publication,
    date_limite,
    titre,
    acheteur,
    acheteur_pays,
    acheteur_ville,
    acheteur_courriel,
    acheteur_site,
    valeur_estimee,
    devise,
    cpv,
    nature_contrat,
    url,
    raw_ref,
    collecte_le,
    (date_limite - CURRENT_DATE) AS jours_restants,
        CASE
            WHEN ((date_limite - CURRENT_DATE) <= 7) THEN 'urgent'::text
            WHEN ((date_limite - CURRENT_DATE) <= 21) THEN 'proche'::text
            ELSE 'confortable'::text
        END AS urgence
   FROM public.ted_avis a
  WHERE (est_appel_ouvert AND (date_limite IS NOT NULL) AND (date_limite >= CURRENT_DATE))
  ORDER BY date_limite;


--
-- Name: VIEW v_appels_ouverts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_appels_ouverts IS 'Appels d''offres dont la date limite n''est pas passée. Un avis expiré ou déjà attribué n''y figure pas : le proposer serait faire perdre son temps au décideur.';


--
-- Name: v_flux_a_examiner; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_flux_a_examiner AS
 SELECT fi.item_id,
    fs.famille,
    fs.libelle AS flux,
    COALESCE(s.sector_code, e.sector_code) AS sector_code,
    COALESCE(s.watch_question_code, e.watch_question_code) AS watch_question_code,
    e.pertinence,
    s.anteriorite,
    s.portee,
    s.pertinence AS pertinence_signal,
    COALESCE(s.resume, e.resume) AS resume,
    fi.titre,
    fi.url,
    fi.date_publication,
    fi.collecte_le
   FROM (((public.flux_items fi
     JOIN public.flux_sources fs ON ((fs.flux_id = fi.flux_id)))
     LEFT JOIN public.flux_triage_ia e ON (((e.item_id = fi.item_id) AND (e.doctrine = 'evenement'::text))))
     LEFT JOIN public.flux_triage_ia s ON (((s.item_id = fi.item_id) AND (s.doctrine = 'signal'::text))))
  WHERE ((NOT (EXISTS ( SELECT 1
           FROM public.flux_examens x
          WHERE (x.item_id = fi.item_id)))) AND ((NOT (EXISTS ( SELECT 1
           FROM public.flux_filtrage f
          WHERE (f.item_id = fi.item_id)))) OR (EXISTS ( SELECT 1
           FROM public.flux_filtrage_audit a
          WHERE ((a.item_id = fi.item_id) AND (a.verdict = 'faux_negatif'::text))))))
  ORDER BY s.anteriorite DESC NULLS LAST, s.portee DESC NULLS LAST, e.pertinence DESC NULLS LAST, fi.date_publication DESC;


--
-- Name: VIEW v_flux_a_examiner; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_flux_a_examiner IS 'File de lecture du veilleur, UNE ligne par item. Porte les scores des deux doctrines côte à côte ; l''ordre suit la doctrine « signal » (antériorité, puis portée) avec repli sur la pertinence événementielle. Corrigée le 23.08.2026 : la version précédente joignait flux_triage_ia sans filtrer la doctrine et doublait chaque item.';


--
-- Name: v_bilan_filtrage; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_bilan_filtrage AS
 WITH b AS (
         SELECT ( SELECT count(*) AS count
                   FROM public.flux_items) AS items_collectes,
            ( SELECT count(*) AS count
                   FROM public.flux_filtrage) AS items_filtres,
            ( SELECT count(*) AS count
                   FROM public.v_flux_a_examiner) AS file_humaine,
            ( SELECT count(*) AS count
                   FROM public.flux_examens) AS examens_humains,
            ( SELECT count(*) AS count
                   FROM public.flux_filtrage_audit) AS items_audites,
            ( SELECT count(*) AS count
                   FROM public.flux_filtrage_audit
                  WHERE (flux_filtrage_audit.verdict = 'faux_negatif'::text)) AS faux_negatifs
        )
 SELECT items_collectes,
    items_filtres,
    file_humaine,
    examens_humains,
    items_audites,
    faux_negatifs,
        CASE
            WHEN ((items_filtres + file_humaine) > 0) THEN round(((100.0 * (items_filtres)::numeric) / ((items_filtres + file_humaine))::numeric), 1)
            ELSE NULL::numeric
        END AS part_filtree_pct,
        CASE
            WHEN (items_audites > 0) THEN round(((100.0 * (faux_negatifs)::numeric) / (items_audites)::numeric), 1)
            ELSE NULL::numeric
        END AS taux_faux_negatifs_pct,
        CASE
            WHEN (items_audites = 0) THEN 'Règle appliquée, jamais auditée : le taux de faux négatifs est inconnu.'::text
            WHEN (faux_negatifs = 0) THEN format('Aucun faux négatif sur %s items audités.'::text, items_audites)
            ELSE format('%s faux négatifs sur %s items audités — la règle doit être révisée.'::text, faux_negatifs, items_audites)
        END AS enonce_audit
   FROM b;


--
-- Name: v_bilan_referentiel; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_bilan_referentiel AS
 SELECT sector_code,
    count(*) AS total,
    count(*) FILTER (WHERE (status = 'certifie'::text)) AS certifies,
    count(*) FILTER (WHERE ((status = 'certifie'::text) AND (category = 'hard'::text))) AS certifies_hard,
    count(*) FILTER (WHERE ((status = 'certifie'::text) AND (category = 'composite'::text))) AS certifies_composite,
    count(*) FILTER (WHERE (status = 'a_confirmer'::text)) AS a_confirmer,
    count(*) FILTER (WHERE en_vitrine) AS en_grille,
    count(*) FILTER (WHERE (NOT en_vitrine)) AS ecartes
   FROM public.indicators
  GROUP BY ROLLUP(sector_code)
  ORDER BY sector_code;


--
-- Name: VIEW v_bilan_referentiel; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_bilan_referentiel IS 'Décompte faisant foi (§ 8.4.5). `en_grille` = indicateurs en vitrine, c''est-à-dire suivis et affichés. `ecartes` = qualifiés et conservés au référentiel, hors grille. `certifies` reste le décompte de qualification des SOURCES, qui ne se perd pas.';


--
-- Name: v_bindings_actifs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_bindings_actifs AS
 SELECT b.binding_id,
    b.indicator_id,
    i.label AS indicator_label,
    i.sector_code,
    i.frequency,
    i.unit,
    b.connecteur,
    b.url_base,
    b.params,
    b.mapping,
    b.geo_defaut,
    b.verifie_par,
    b.verifie_le
   FROM (public.source_bindings b
     JOIN public.indicators i ON ((i.indicator_id = b.indicator_id)))
  WHERE (b.statut = 'actif'::text)
  ORDER BY i.sector_code, b.indicator_id;


--
-- Name: VIEW v_bindings_actifs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_bindings_actifs IS 'Le collecteur générique ne lit que cette vue. Une liaison non vérifiée n''est pas collectée — l''absence de donnée est préférable à une donnée dont on ignore d''où elle vient.';


--
-- Name: v_contexte; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_contexte AS
 SELECT indicator_id,
    indicator_label,
    sector_code,
    category,
    unit,
    period,
    geo,
    value,
    validation_status,
    obtained_by,
    consensus_score,
    raw_ref,
    source_organisation,
    source_url,
    run_id,
    executed_at
   FROM public.v_current
  WHERE (sector_code = 'transversal'::text);


--
-- Name: watch_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watch_questions (
    code text NOT NULL,
    label text NOT NULL,
    description text NOT NULL
);


--
-- Name: TABLE watch_questions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.watch_questions IS 'Questions de veille (§ 8.1.2). Prescription théorique du § 4.3 : pas d''indicateur sans question explicite.';


--
-- Name: v_couverture_qv; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_couverture_qv AS
 SELECT s.code AS sector_code,
    q.code AS watch_question_code,
    count(iwq.indicator_id) AS nb_indicateurs,
    count(iwq.indicator_id) FILTER (WHERE (i.status = 'certifie'::text)) AS nb_certifies,
        CASE
            WHEN (count(iwq.indicator_id) FILTER (WHERE (i.status = 'certifie'::text)) > 0) THEN 'couverte'::text
            WHEN (count(iwq.indicator_id) > 0) THEN 'couverte_a_confirmer'::text
            ELSE 'non_couverte'::text
        END AS couverture
   FROM (((public.sectors s
     CROSS JOIN public.watch_questions q)
     LEFT JOIN public.indicators i ON ((i.sector_code = s.code)))
     LEFT JOIN public.indicator_watch_questions iwq ON (((iwq.indicator_id = i.indicator_id) AND (iwq.watch_question_code = q.code))))
  WHERE ((s.code = 'transversal'::text) = (q.code = 'QV0'::text))
  GROUP BY s.code, q.code
  ORDER BY s.code, q.code;


--
-- Name: v_couverture_vitrine; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_couverture_vitrine AS
 SELECT s.code AS sector_code,
    q.code AS watch_question_code,
    sw.criticite,
    count(i.indicator_id) AS nb_en_vitrine,
    count(i.indicator_id) FILTER (WHERE (i.status = 'certifie'::text)) AS nb_certifies,
    count(i.indicator_id) FILTER (WHERE (i.status = 'a_confirmer'::text)) AS nb_a_confirmer,
    string_agg(i.indicator_id, ', '::text ORDER BY i.indicator_id) AS porteurs,
        CASE
            WHEN (count(i.indicator_id) FILTER (WHERE (i.status = 'certifie'::text)) > 0) THEN 'couverte'::text
            WHEN (count(i.indicator_id) > 0) THEN 'couverte_a_confirmer'::text
            ELSE 'non_couverte'::text
        END AS couverture
   FROM ((((public.sectors s
     CROSS JOIN public.watch_questions q)
     JOIN public.sector_watch_questions sw ON (((sw.sector_code = s.code) AND (sw.watch_question_code = q.code))))
     LEFT JOIN public.indicator_watch_questions iwq ON ((iwq.watch_question_code = q.code)))
     LEFT JOIN public.indicators i ON (((i.indicator_id = iwq.indicator_id) AND (i.sector_code = s.code) AND i.en_vitrine)))
  GROUP BY s.code, q.code, sw.criticite
  ORDER BY s.code, q.code;


--
-- Name: VIEW v_couverture_vitrine; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_couverture_vitrine IS 'Couverture des questions de veille par les indicateurs EN VITRINE (ce que le décideur voit). À confronter à v_couverture_qv (référentiel complet) : l''écart entre les deux est un résultat du § 8. Créée le 27.08.2026.';


--
-- Name: v_dernier_point; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_dernier_point AS
 SELECT DISTINCT ON (indicator_id, geo) indicator_id,
    indicator_label,
    sector_code,
    category,
    frequency,
    unit,
    period,
    geo,
    value,
    periode_precedente,
    valeur_periode_precedente,
    variation_periode_pct,
    periode_homologue,
    valeur_annee_precedente,
    glissement_annuel_pct,
    moyenne_mobile_annuelle,
    nb_points_moyenne,
    nb_points_attendus,
    debut_fenetre,
    ecart_a_la_moyenne_pct,
    seuil_materialite_pct,
    franchissement,
    validation_status,
    obtained_by,
    source_organisation,
    source_url,
    raw_ref,
    run_id,
    executed_at,
    completude
   FROM public.v_metriques
  ORDER BY indicator_id, geo, period DESC;


--
-- Name: VIEW v_dernier_point; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_dernier_point IS 'Dernière observation par indicateur et zone, avec ses métriques. C''est l''objet compact que la couche d''analyse transmet au modèle pour le commentaire exécutif (§ 10.4.3).';


--
-- Name: v_dynamique_geographique; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_dynamique_geographique AS
 WITH pts AS (
         SELECT DISTINCT ON (iv.indicator_id, iv.geo, iv.period) iv.indicator_id,
            iv.geo,
            iv.period,
            iv.value,
            iv.validation_status
           FROM public.indicator_values iv
          WHERE (iv.validation_status = ANY (ARRAY['valide_source'::text, 'pre_valide_consensus'::text, 'valide_humain'::text]))
          ORDER BY iv.indicator_id, iv.geo, iv.period, iv.run_id DESC
        ), cadre AS (
         SELECT p.indicator_id,
            i.sector_code,
            i.label,
            i.unit,
            i.frequency,
            i.geo_reference,
            ((i.frequency = 'annuelle'::text) OR (i.frequency = 'semestrielle'::text)) AS annuelle,
            max(p.period) AS p_max
           FROM (pts p
             JOIN public.indicators i USING (indicator_id))
          WHERE (i.unit = ANY (ARRAY['USD'::text, 'mio USD'::text, 'unités'::text, 'nombre'::text, 'nombre d''avis'::text, 'nombre d''autorisations'::text]))
          GROUP BY p.indicator_id, i.sector_code, i.label, i.unit, i.frequency, i.geo_reference, ((i.frequency = 'annuelle'::text) OR (i.frequency = 'semestrielle'::text))
        ), annuel AS (
         SELECT c_1.indicator_id,
            p.geo,
            sum(p.value) FILTER (WHERE (p.period = c_1.p_max)) AS recent,
            sum(p.value) FILTER (WHERE (p.period = ( SELECT max(q.period) AS max
                   FROM pts q
                  WHERE ((q.indicator_id = c_1.indicator_id) AND (q.period < c_1.p_max))))) AS anterieur,
            c_1.p_max AS periode_ref,
            ('exercice '::text || c_1.p_max) AS base_comparaison
           FROM (cadre c_1
             JOIN pts p ON ((p.indicator_id = c_1.indicator_id)))
          WHERE c_1.annuelle
          GROUP BY c_1.indicator_id, p.geo, c_1.p_max
        ), glissant AS (
         SELECT c_1.indicator_id,
            p.geo,
            sum(p.value) FILTER (WHERE (p.period > to_char((to_date(c_1.p_max, 'YYYY-MM'::text) - '1 year'::interval), 'YYYY-MM'::text))) AS recent,
            sum(p.value) FILTER (WHERE ((p.period > to_char((to_date(c_1.p_max, 'YYYY-MM'::text) - '2 years'::interval), 'YYYY-MM'::text)) AND (p.period <= to_char((to_date(c_1.p_max, 'YYYY-MM'::text) - '1 year'::interval), 'YYYY-MM'::text)))) AS anterieur,
            c_1.p_max AS periode_ref,
            ('12 mois glissants au '::text || c_1.p_max) AS base_comparaison
           FROM (cadre c_1
             JOIN pts p ON ((p.indicator_id = c_1.indicator_id)))
          WHERE (NOT c_1.annuelle)
          GROUP BY c_1.indicator_id, p.geo, c_1.p_max
        ), tout AS (
         SELECT annuel.indicator_id,
            annuel.geo,
            annuel.recent,
            annuel.anterieur,
            annuel.periode_ref,
            annuel.base_comparaison
           FROM annuel
        UNION ALL
         SELECT glissant.indicator_id,
            glissant.geo,
            glissant.recent,
            glissant.anterieur,
            glissant.periode_ref,
            glissant.base_comparaison
           FROM glissant
        ), totaux AS (
         SELECT tout.indicator_id,
            sum(tout.recent) AS total_recent
           FROM tout
          WHERE ((tout.recent > (0)::numeric) AND (tout.geo <> ALL (ARRAY['W00'::text, 'WORLD'::text, 'World'::text, 'OWID_WRL'::text, 'EU'::text, 'EU27'::text, 'EU27_2020'::text, 'G20'::text])))
          GROUP BY tout.indicator_id
        )
 SELECT t.indicator_id,
    c.sector_code,
    c.label,
    c.unit,
    c.frequency,
    t.geo,
    (t.geo = c.geo_reference) AS est_zone_de_reference,
    t.recent AS valeur_recente,
    t.anterieur AS valeur_anterieure,
    round(((100.0 * t.recent) / NULLIF(x.total_recent, (0)::numeric)), 2) AS part_pct,
    round(((100.0 * (t.recent - t.anterieur)) / NULLIF(abs(t.anterieur), (0)::numeric)), 1) AS variation_pct,
    t.periode_ref,
    t.base_comparaison,
    (((100.0 * t.recent) / NULLIF(x.total_recent, (0)::numeric)) >= 1.0) AS poids_significatif
   FROM ((tout t
     JOIN cadre c ON ((c.indicator_id = t.indicator_id)))
     JOIN totaux x ON ((x.indicator_id = t.indicator_id)))
  WHERE ((t.recent > (0)::numeric) AND (t.anterieur > (0)::numeric) AND (t.geo <> ALL (ARRAY['W00'::text, 'WORLD'::text, 'World'::text, 'OWID_WRL'::text, 'EU'::text, 'EU27'::text, 'EU27_2020'::text, 'G20'::text])));


--
-- Name: VIEW v_dynamique_geographique; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_dynamique_geographique IS 'Répartition et évolution par zone, indicateur par indicateur — instrumente la question de veille QV3. Comparaison à douze mois glissants pour les séries infra-annuelles (neutralisation de la saisonnalité, RI2), à exercice contre exercice pour les annuelles. Les agrégats mondiaux et européens sont exclus du calcul des parts. Déduplication par run obligatoire : le registre est en ajout seul.';


--
-- Name: v_divergence_geographique; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_divergence_geographique AS
 WITH classe AS (
         SELECT g.indicator_id,
            g.sector_code,
            g.label,
            g.unit,
            g.frequency,
            g.geo,
            g.est_zone_de_reference,
            g.valeur_recente,
            g.valeur_anterieure,
            g.part_pct,
            g.variation_pct,
            g.periode_ref,
            g.base_comparaison,
            g.poids_significatif,
            row_number() OVER (PARTITION BY g.indicator_id ORDER BY g.part_pct DESC) AS rang
           FROM public.v_dynamique_geographique g
          WHERE g.poids_significatif
        ), premier AS (
         SELECT classe.indicator_id,
            classe.sector_code,
            classe.label,
            classe.unit,
            classe.frequency,
            classe.geo,
            classe.est_zone_de_reference,
            classe.valeur_recente,
            classe.valeur_anterieure,
            classe.part_pct,
            classe.variation_pct,
            classe.periode_ref,
            classe.base_comparaison,
            classe.poids_significatif,
            classe.rang
           FROM classe
          WHERE (classe.rang = 1)
        ), autres AS (
         SELECT classe.indicator_id,
            count(*) AS n_autres,
            round((sum((classe.variation_pct * classe.part_pct)) / NULLIF(sum(classe.part_pct), (0)::numeric)), 1) AS var_moy_ponderee,
            count(*) FILTER (WHERE (classe.variation_pct > (0)::numeric)) AS n_en_hausse,
            count(*) FILTER (WHERE (classe.variation_pct < (0)::numeric)) AS n_en_recul
           FROM classe
          WHERE (classe.rang > 1)
          GROUP BY classe.indicator_id
        )
 SELECT p.indicator_id,
    p.sector_code,
    p.label,
    p.unit,
    p.geo AS premier_marche,
    p.part_pct AS premier_part_pct,
    p.variation_pct AS premier_variation_pct,
    a.n_autres,
    a.var_moy_ponderee,
    a.n_en_hausse,
    a.n_en_recul,
    p.base_comparaison,
    p.periode_ref,
    ((sign(p.variation_pct) <> sign(a.var_moy_ponderee)) AND (abs((p.variation_pct - a.var_moy_ponderee)) >= (5)::numeric)) AS divergence,
    round((p.variation_pct - a.var_moy_ponderee), 1) AS ecart_points
   FROM (premier p
     JOIN autres a USING (indicator_id));


--
-- Name: VIEW v_divergence_geographique; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_divergence_geographique IS 'Écart entre le premier débouché d''un indicateur et la moyenne pondérée des autres. Divergence déclarée quand les signes s''opposent et que l''écart atteint 5 points. Le seuil est un choix affiché, pas une vérité.';


--
-- Name: v_ecart_doctrines; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ecart_doctrines AS
 SELECT e.pertinence AS pertinence_evenement,
    t.anteriorite,
    t.portee,
    count(*) AS n
   FROM (public.flux_triage_ia e
     JOIN public.flux_triage_ia t ON ((t.item_id = e.item_id)))
  WHERE ((e.doctrine = 'evenement'::text) AND (t.doctrine = 'signal'::text))
  GROUP BY e.pertinence, t.anteriorite, t.portee
  ORDER BY e.pertinence, t.anteriorite, t.portee;


--
-- Name: VIEW v_ecart_doctrines; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ecart_doctrines IS 'Croisement des deux doctrines sur le même corpus. La case qui compte : pertinence_evenement = 0 avec anteriorite = 2 — les items que la doctrine événementielle a jetés et que la doctrine signal remonte. S''ils existent, la critique du 23.08 est démontrée ; s''ils sont absents, elle est infirmée. Dans les deux cas, c''est un résultat.';


--
-- Name: v_run_history; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_run_history AS
 SELECT iv.indicator_id,
    iv.period,
    iv.geo,
    iv.run_id,
    r.executed_at,
    iv.value,
    iv.validation_status
   FROM (public.indicator_values iv
     JOIN public.runs r ON ((r.run_id = iv.run_id)))
  ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id;


--
-- Name: v_ecart_entre_runs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ecart_entre_runs AS
 SELECT indicator_id,
    period,
    geo,
    run_id,
    executed_at,
    value,
    lag(value) OVER w AS value_run_precedent,
    lag(run_id) OVER w AS run_precedent,
        CASE
            WHEN ((lag(value) OVER w IS NULL) OR (lag(value) OVER w = (0)::numeric)) THEN NULL::numeric
            ELSE round((((value - lag(value) OVER w) / lag(value) OVER w) * (100)::numeric), 2)
        END AS ecart_pct
   FROM public.v_run_history
  WINDOW w AS (PARTITION BY indicator_id, period, geo ORDER BY run_id);


--
-- Name: VIEW v_ecart_entre_runs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ecart_entre_runs IS 'Un écart non nul signale une révision de la donnée par sa source entre deux collectes — information de veille en soi, invisible d''un dispositif qui écraserait ses valeurs.';


--
-- Name: v_exposition_horlogere; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_exposition_horlogere AS
 WITH h AS (
         SELECT DISTINCT ON (indicator_values.period, indicator_values.geo) indicator_values.period,
            indicator_values.geo,
            indicator_values.value
           FROM public.indicator_values
          WHERE ((indicator_values.indicator_id = 'H1'::text) AND (indicator_values.geo <> ALL (ARRAY['W00'::text, 'WORLD'::text])) AND (indicator_values.geo !~ '^[SXF][0-9]'::text))
          ORDER BY indicator_values.period, indicator_values.geo, indicator_values.run_id DESC
        ), tot AS (
         SELECT h.period,
            sum(h.value) AS t
           FROM h
          GROUP BY h.period
        ), parts AS (
         SELECT h.period,
            h.geo,
            ((h.value / t.t) * (100)::numeric) AS part
           FROM (h
             JOIN tot t USING (period))
        )
 SELECT period,
    round(max(part) FILTER (WHERE (geo = 'USA'::text)), 1) AS part_usa_pct,
    round(sum(part) FILTER (WHERE (rn <= 3)), 1) AS top3_pct
   FROM ( SELECT parts.period,
            parts.geo,
            parts.part,
            row_number() OVER (PARTITION BY parts.period ORDER BY parts.part DESC) AS rn
           FROM parts) p
  GROUP BY period
  ORDER BY period;


--
-- Name: VIEW v_exposition_horlogere; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_exposition_horlogere IS 'Part des États-Unis dans les exportations horlogères suisses et concentration des trois premiers débouchés, par mois. Le choc douanier de 2025 s''y lit intégralement : 34,1 % en avril 2025 (stocks), 10,3 % en octobre (choc), 27,1 % en juillet 2026 (remontée) — le dispositif voit l''événement qui fonde la problématique du travail.';


--
-- Name: v_fiabilite_decouverte; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_fiabilite_decouverte AS
 SELECT modele.value AS modele,
    count(*) AS propositions_ecartees,
    count(*) FILTER (WHERE (discovery_log.statut_traitement = 'non_verifiable'::text)) AS urls_inexistantes
   FROM public.discovery_log,
    LATERAL jsonb_array_elements_text(discovery_log.modeles_proposants) modele(value)
  GROUP BY modele.value
  ORDER BY (count(*) FILTER (WHERE (discovery_log.statut_traitement = 'non_verifiable'::text))) DESC;


--
-- Name: v_filtrage_echantillon; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_filtrage_echantillon AS
 SELECT to_char(now(), 'YYYY-MM'::text) AS echantillon,
    row_number() OVER (ORDER BY (md5(((f.item_id)::text || to_char(now(), 'YYYY-MM'::text))))) AS rang,
    f.item_id,
    f.note_ia,
    f.anteriorite,
    f.regle_code,
    fs.famille,
    fi.titre,
    fi.url,
    fi.date_publication,
    s.resume
   FROM (((public.flux_filtrage f
     JOIN public.flux_items fi ON ((fi.item_id = f.item_id)))
     JOIN public.flux_sources fs ON ((fs.flux_id = fi.flux_id)))
     LEFT JOIN public.flux_triage_ia s ON (((s.item_id = f.item_id) AND (s.doctrine = 'signal'::text))))
  WHERE (NOT (EXISTS ( SELECT 1
           FROM public.flux_filtrage_audit a
          WHERE ((a.item_id = f.item_id) AND (a.echantillon = to_char(now(), 'YYYY-MM'::text))))));


--
-- Name: v_indicateur_synthetique; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_indicateur_synthetique AS
 WITH h3 AS (
         SELECT v_current.period,
            v_current.geo,
            v_current.value,
            v_current.validation_status
           FROM public.v_current
          WHERE (v_current.indicator_id = 'H3'::text)
        ), attendus AS (
         SELECT DISTINCT h3.geo
           FROM h3
        ), par_annee AS (
         SELECT h.period,
            count(*) AS nb_declarants,
            sum(h.value) AS total_panier_usd,
            sum(h.value) FILTER (WHERE (h.geo = 'CHE'::text)) AS che_usd,
            bool_and((h.validation_status = ANY (ARRAY['valide_source'::text, 'valide_humain'::text]))) AS tous_valides
           FROM h3 h
          GROUP BY h.period
        ), manquants AS (
         SELECT p_1.period,
            string_agg(a.geo, ', '::text ORDER BY a.geo) FILTER (WHERE (NOT (a.geo IN ( SELECT h3.geo
                   FROM h3
                  WHERE (h3.period = p_1.period))))) AS declarants_manquants
           FROM (par_annee p_1
             CROSS JOIN attendus a)
          GROUP BY p_1.period
        )
 SELECT p.period,
    ( SELECT count(*) AS count
           FROM attendus) AS nb_declarants_attendus,
    p.nb_declarants,
    round((p.total_panier_usd / '1000000000'::numeric), 2) AS total_panier_mia_usd,
    round((p.che_usd / '1000000000'::numeric), 2) AS che_mia_usd,
        CASE
            WHEN ((p.nb_declarants = ( SELECT count(*) AS count
               FROM attendus)) AND (p.che_usd IS NOT NULL) AND (p.total_panier_usd > (0)::numeric)) THEN round(((p.che_usd / p.total_panier_usd) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS part_suisse_pct,
        CASE
            WHEN (p.nb_declarants < ( SELECT count(*) AS count
               FROM attendus)) THEN (((('part non calculable : déclarant(s) sans soumission pour '::text || p.period) || ' — '::text) || COALESCE(m.declarants_manquants, '?'::text)) || '. La fraîcheur d''un panier est celle de son déclarant le plus lent.'::text)
            ELSE ''::text
        END AS completude,
    p.tous_valides
   FROM (par_annee p
     JOIN manquants m USING (period))
  ORDER BY p.period;


--
-- Name: VIEW v_indicateur_synthetique; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_indicateur_synthetique IS 'Indicateur synthétique (engagement de la ratification, séance 2) : part de la Suisse dans le commerce d''articles d''horlogerie (SH 91) du panier de déclarants H3. Calcul par vue, une seule source, part calculée uniquement à panier complet — sinon l''absence est énoncée avec les déclarants manquants (leçon Chine 2024, § 12.5).';


--
-- Name: v_instanciation_qv; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_instanciation_qv AS
 SELECT swq.sector_code,
    s.label AS sector_label,
    swq.watch_question_code,
    q.label AS question_generique,
    swq.formulation AS question_sectorielle,
    swq.mecanisme,
    swq.criticite,
    count(iwq.indicator_id) AS nb_indicateurs,
    count(iwq.indicator_id) FILTER (WHERE (i.status = 'certifie'::text)) AS nb_certifies,
    swq.reponse_gabarit
   FROM ((((public.sector_watch_questions swq
     JOIN public.sectors s ON ((s.code = swq.sector_code)))
     JOIN public.watch_questions q ON ((q.code = swq.watch_question_code)))
     LEFT JOIN public.indicators i ON ((i.sector_code = swq.sector_code)))
     LEFT JOIN public.indicator_watch_questions iwq ON (((iwq.indicator_id = i.indicator_id) AND (iwq.watch_question_code = swq.watch_question_code))))
  GROUP BY swq.sector_code, s.label, swq.watch_question_code, q.label, swq.formulation, swq.mecanisme, swq.criticite, swq.reponse_gabarit
  ORDER BY swq.sector_code, swq.watch_question_code;


--
-- Name: VIEW v_instanciation_qv; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_instanciation_qv IS 'Le cadre à deux niveaux, restitué. Une criticité « dominante » sans indicateur certifié est une lacune à énoncer au rapport, pas à masquer.';


--
-- Name: v_intensite_signalement; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_intensite_signalement AS
 WITH attribue AS (
         SELECT DISTINCT t.item_id,
            to_char((fi.date_publication)::timestamp with time zone, 'YYYY-MM'::text) AS periode,
            t.sector_code,
            t.watch_question_code,
            t.pertinence
           FROM (public.flux_triage_ia t
             JOIN public.flux_items fi USING (item_id))
          WHERE ((fi.date_publication IS NOT NULL) AND (t.sector_code IS NOT NULL))
        ), denominateur AS (
         SELECT attribue.periode,
            attribue.sector_code,
            count(DISTINCT attribue.item_id) AS n_tries
           FROM attribue
          GROUP BY attribue.periode, attribue.sector_code
        ), numerateur AS (
         SELECT attribue.periode,
            attribue.sector_code,
            attribue.watch_question_code,
            count(DISTINCT attribue.item_id) AS n_pertinents
           FROM attribue
          WHERE (attribue.pertinence >= 1)
          GROUP BY attribue.periode, attribue.sector_code, attribue.watch_question_code
        )
 SELECT n.periode,
    n.sector_code,
    n.watch_question_code,
    n.n_pertinents,
    d.n_tries,
    round(((100.0 * (n.n_pertinents)::numeric) / (d.n_tries)::numeric), 1) AS part_pct,
    (d.n_tries >= 20) AS calculable,
    i.indicator_id
   FROM (((numerateur n
     JOIN denominateur d USING (periode, sector_code))
     LEFT JOIN public.indicator_watch_questions iwq ON ((iwq.watch_question_code = n.watch_question_code)))
     LEFT JOIN public.indicators i ON (((i.indicator_id = iwq.indicator_id) AND (i.sector_code = n.sector_code) AND (i.source_id = 'triage_flux'::text))))
  ORDER BY n.sector_code, n.watch_question_code, n.periode;


--
-- Name: VIEW v_intensite_signalement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_intensite_signalement IS 'Part mensuelle des items triés attribués à chaque couple secteur × question (pertinence >= 1, item compté une fois). Plancher de calculabilité : 20 items triés/secteur/mois (résolution : 1 item <= 5 points de part). indicator_id non nul = case instrumentée. Créée le 27.08.2026.';


--
-- Name: v_lecture_a_echantillonner; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_lecture_a_echantillonner AS
 SELECT l.adressable,
    e.decision,
    count(*) AS n
   FROM ((public.ted_lecture_ia l
     JOIN public.flux_items fi ON ((fi.titre ~~ (('[TED '::text || l.publication_number) || ']%'::text))))
     JOIN public.flux_examens e ON ((e.item_id = fi.item_id)))
  WHERE (l.profil = 'A_metier_declare'::text)
  GROUP BY l.adressable, e.decision
  ORDER BY l.adressable DESC, e.decision;


--
-- Name: v_mix_horloger; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_mix_horloger AS
 WITH pts AS (
         SELECT DISTINCT ON (indicator_values.indicator_id, indicator_values.period) indicator_values.indicator_id,
            indicator_values.period,
            indicator_values.value
           FROM public.indicator_values
          WHERE (indicator_values.indicator_id = ANY (ARRAY['H7'::text, 'H8'::text, 'H9'::text]))
          ORDER BY indicator_values.indicator_id, indicator_values.period, indicator_values.run_id DESC
        ), larges AS (
         SELECT pts.period,
            max(pts.value) FILTER (WHERE (pts.indicator_id = 'H7'::text)) AS total_chf,
            max(pts.value) FILTER (WHERE (pts.indicator_id = 'H8'::text)) AS meca_chf,
            max(pts.value) FILTER (WHERE (pts.indicator_id = 'H9'::text)) AS meca_pieces
           FROM pts
          GROUP BY pts.period
        )
 SELECT period,
    total_chf,
    meca_chf,
    meca_pieces,
    round(((100.0 * meca_chf) / NULLIF(total_chf, (0)::numeric)), 1) AS part_meca_valeur_pct,
    round(((meca_chf * 1000.0) / NULLIF(meca_pieces, (0)::numeric)), 0) AS valeur_moyenne_chf,
    round(((100.0 * (meca_chf - lag(meca_chf, 12) OVER (ORDER BY period))) / NULLIF(lag(meca_chf, 12) OVER (ORDER BY period), (0)::numeric)), 1) AS meca_chf_ga_pct,
    round(((100.0 * (meca_pieces - lag(meca_pieces, 12) OVER (ORDER BY period))) / NULLIF(lag(meca_pieces, 12) OVER (ORDER BY period), (0)::numeric)), 1) AS meca_pieces_ga_pct
   FROM larges
  WHERE (total_chf IS NOT NULL);


--
-- Name: VIEW v_mix_horloger; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_mix_horloger IS 'Mix mécanique des exportations horlogères suisses (source FH, en francs). Rend observable le point de vigilance du mécanisme QV1 horloger : une montée en valeur qui masquerait l''érosion du tissu de sous-traitance. Un atelier facture des pièces, pas des francs.';


--
-- Name: v_motorisations_automobile; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_motorisations_automobile AS
 SELECT ev.period,
    ev.value AS ventes_ev,
    part.value AS part_ev_pct,
    round(((ev.value / NULLIF(part.value, (0)::numeric)) * 100.0), 0) AS ventes_totales,
    round((((ev.value / NULLIF(part.value, (0)::numeric)) * 100.0) - ev.value), 0) AS ventes_thermiques
   FROM (public.v_current ev
     JOIN public.v_current part ON (((part.indicator_id = 'A11'::text) AND (part.period = ev.period) AND (part.geo = ev.geo))))
  WHERE ((ev.indicator_id = 'A3'::text) AND (ev.geo = 'World'::text))
  ORDER BY ev.period;


--
-- Name: VIEW v_motorisations_automobile; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_motorisations_automobile IS 'Ventes mondiales de voitures décomposées par motorisation : EV collecté (A3), part collectée (A11), total et thermique DÉRIVÉS (total = EV / part). Part d''une motorisation, jamais « part de marché » d''un acteur. Créée le 27.08.2026.';


--
-- Name: v_nouveaute_par_run; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_nouveaute_par_run AS
 WITH evt AS (
         SELECT fi.flux_id,
            (fi.collecte_le)::date AS jour,
            public.cle_evenement(fi.titre, fi.url) AS cle
           FROM public.flux_items fi
        ), premiere AS (
         SELECT evt.cle,
            min(evt.jour) AS premiere_vue
           FROM evt
          GROUP BY evt.cle
        )
 SELECT e.flux_id,
    e.jour,
    count(DISTINCT e.cle) AS evenements,
    count(DISTINCT e.cle) FILTER (WHERE (p.premiere_vue = e.jour)) AS nouveaux,
    count(DISTINCT e.cle) FILTER (WHERE (p.premiere_vue < e.jour)) AS deja_vus,
    round(((100.0 * (count(DISTINCT e.cle) FILTER (WHERE (p.premiere_vue = e.jour)))::numeric) / (NULLIF(count(DISTINCT e.cle), 0))::numeric)) AS taux_nouveaute_pct
   FROM (evt e
     JOIN premiere p ON ((p.cle = e.cle)))
  GROUP BY e.flux_id, e.jour
  ORDER BY e.jour DESC, e.flux_id;


--
-- Name: VIEW v_nouveaute_par_run; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_nouveaute_par_run IS 'Écart entre exécutions datées, par flux : combien d''événements sont apparus pour la première fois ce jour-là. Exacte (clé d''événement), non lexicale. ATTENTION : n''a de sens qu''entre collectes des MÊMES flux à des dates différentes ; comparer deux jours qui ont collecté des flux différents mesure la nouveauté des sources, pas celle du marché. Au 23.08.2026 le dispositif n''a pas encore la profondeur nécessaire.';


--
-- Name: v_nouveautes_7j; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_nouveautes_7j AS
 WITH avant AS (
         SELECT indicator_values.indicator_id,
            max(indicator_values.period) AS p_max,
            count(DISTINCT indicator_values.period) AS n_periodes
           FROM public.indicator_values
          WHERE (indicator_values.collected_at <= (now() - '7 days'::interval))
          GROUP BY indicator_values.indicator_id
        ), maintenant AS (
         SELECT indicator_values.indicator_id,
            max(indicator_values.period) AS p_max,
            count(DISTINCT indicator_values.period) AS n_periodes
           FROM public.indicator_values
          GROUP BY indicator_values.indicator_id
        )
 SELECT m.indicator_id,
    i.sector_code,
    i.label,
    i.latence,
    i.unit,
    a.p_max AS periode_avant,
    m.p_max AS periode_maintenant,
    COALESCE(a.n_periodes, (0)::bigint) AS periodes_avant,
    m.n_periodes AS periodes_maintenant,
    (m.n_periodes - COALESCE(a.n_periodes, (0)::bigint)) AS periodes_gagnees,
    (a.indicator_id IS NULL) AS entierement_nouveau
   FROM ((maintenant m
     JOIN public.indicators i USING (indicator_id))
     LEFT JOIN avant a USING (indicator_id))
  WHERE ((a.indicator_id IS NULL) OR (m.p_max > a.p_max) OR (m.n_periodes > a.n_periodes));


--
-- Name: VIEW v_nouveautes_7j; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_nouveautes_7j IS 'Indicateurs ayant gagné des périodes depuis sept jours. Répond à « qu''est-ce qui est arrivé ? » quand l''écart de score n''est pas calculable — par exemple après un changement de périmètre.';


--
-- Name: v_sante_des_runs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_sante_des_runs AS
 SELECT r.run_id,
    r.executed_at,
    r.status,
    count(iv.value_id) AS valeurs_ecrites,
    count(DISTINCT iv.indicator_id) AS indicateurs_couverts,
    ( SELECT count(*) AS count
           FROM public.indicators
          WHERE (indicators.status = 'certifie'::text)) AS indicateurs_certifies_attendus,
    count(iv.value_id) FILTER (WHERE (iv.validation_status = 'valide_source'::text)) AS issues_de_source,
    count(iv.value_id) FILTER (WHERE (iv.obtained_by = 'ia_extraction'::text)) AS issues_d_extraction_ia
   FROM (public.runs r
     LEFT JOIN public.indicator_values iv ON ((iv.run_id = r.run_id)))
  GROUP BY r.run_id, r.executed_at, r.status
  ORDER BY r.run_id DESC;


--
-- Name: v_sante_ecart; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_sante_ecart AS
 WITH avant AS (
         SELECT sante_a_la_date.sector_code,
            sante_a_la_date.n_series,
            sante_a_la_date.score
           FROM public.sante_a_la_date((now() - '7 days'::interval)) sante_a_la_date(sector_code, n_series, score)
        ), maintenant AS (
         SELECT sante_a_la_date.sector_code,
            sante_a_la_date.n_series,
            sante_a_la_date.score
           FROM public.sante_a_la_date(now()) sante_a_la_date(sector_code, n_series, score)
        )
 SELECT COALESCE(m.sector_code, a.sector_code) AS sector_code,
    7 AS jours,
    m.score AS score_courant,
    a.score AS score_precedent,
        CASE
            WHEN ((m.score IS NOT NULL) AND (a.score IS NOT NULL)) THEN round((m.score - a.score), 2)
            ELSE NULL::numeric
        END AS ecart,
    m.n_series AS series_courantes,
    a.n_series AS series_precedentes
   FROM (maintenant m
     FULL JOIN avant a USING (sector_code));


--
-- Name: VIEW v_sante_ecart; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_sante_ecart IS 'Écart du score de santé sur sept jours, par secteur. Répond à la seule question qu''on pose vraiment à un dispositif de veille : qu''est-ce qui a changé depuis la dernière fois ?';


--
-- Name: v_sante_secteur; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_sante_secteur AS
 WITH courant AS (
         SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo) iv.indicator_id,
            iv.period,
            iv.geo,
            iv.value
           FROM public.indicator_values iv
          WHERE (iv.validation_status = ANY (ARRAY['valide_source'::text, 'pre_valide_consensus'::text, 'valide_humain'::text]))
          ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC
        ), rang AS (
         SELECT c.indicator_id,
            c.period,
            c.value,
            (row_number() OVER (PARTITION BY c.indicator_id ORDER BY c.period))::numeric AS t
           FROM (courant c
             JOIN public.indicators i ON (((i.indicator_id = c.indicator_id) AND (i.geo_reference IS NOT NULL) AND (c.geo = i.geo_reference))))
        ), droite AS (
         SELECT rang.indicator_id,
            regr_slope((rang.value)::double precision, (rang.t)::double precision) AS pente,
            regr_intercept((rang.value)::double precision, (rang.t)::double precision) AS ordonnee,
            (corr((rang.value)::double precision, (rang.t)::double precision))::numeric AS tendance,
            count(*) AS n_points
           FROM rang
          GROUP BY rang.indicator_id
        ), residus AS (
         SELECT r.indicator_id,
            r.t,
            ((r.value)::double precision - (d.ordonnee + (d.pente * (r.t)::double precision))) AS residu
           FROM (rang r
             JOIN droite d USING (indicator_id))
        ), resume AS (
         SELECT re.indicator_id,
            (stddev_samp(re.residu))::numeric AS sd_residu,
            ((array_agg(re.residu ORDER BY re.t DESC))[1])::numeric AS dernier_residu
           FROM residus re
          GROUP BY re.indicator_id
        ), par_indicateur AS (
         SELECT i.sector_code,
            i.indicator_id,
            d.n_points,
            d.tendance,
            ((r.dernier_residu / NULLIF(r.sd_residu, (0)::numeric)) * (i.sens_favorable)::numeric) AS z_detendance,
            d.pente AS pente_par_periode
           FROM ((resume r
             JOIN droite d USING (indicator_id))
             JOIN public.indicators i USING (indicator_id))
          WHERE (i.en_vitrine AND (i.sens_favorable = ANY (ARRAY['-1'::integer, 1])) AND (r.sd_residu IS NOT NULL) AND (r.sd_residu > (0)::numeric) AND (d.n_points >= 8))
        )
 SELECT sector_code,
    count(*) AS n_indicateurs_orientables,
        CASE
            WHEN (count(*) >= 2) THEN round(avg(z_detendance), 2)
            ELSE NULL::numeric
        END AS score_sante,
        CASE
            WHEN (count(*) >= 2) THEN 'calcule'::text
            ELSE 'base_insuffisante'::text
        END AS etat,
    min(n_points) AS profondeur_min,
    array_agg(indicator_id ORDER BY indicator_id) AS indicateurs,
    round(avg(tendance), 2) AS tendance_moyenne,
    ( SELECT count(*) AS count
           FROM public.indicators x
          WHERE ((x.sector_code = p.sector_code) AND x.en_vitrine)) AS indicateurs_certifies
   FROM par_indicateur p
  GROUP BY sector_code;


--
-- Name: VIEW v_sante_secteur; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_sante_secteur IS 'Score de santé DÉTENDANCÉ (§ 5.6, 24.08.2026) : résidu d''un ajustement linéaire, standardisé, orienté par sens_favorable. Mesure la position dans le cycle, non la pente — la pente est fournie séparément en tendance_moyenne. La définition antérieure reste consultable en v_sante_secteur_brut.';


--
-- Name: v_sante_secteur_brut; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_sante_secteur_brut AS
 WITH courant AS (
         SELECT DISTINCT ON (iv.indicator_id, iv.period, iv.geo) iv.indicator_id,
            iv.period,
            iv.geo,
            iv.value
           FROM public.indicator_values iv
          WHERE (iv.validation_status = ANY (ARRAY['valide_source'::text, 'pre_valide_consensus'::text, 'valide_humain'::text]))
          ORDER BY iv.indicator_id, iv.period, iv.geo, iv.run_id DESC
        ), stats AS (
         SELECT c.indicator_id,
            avg(c.value) AS moyenne,
            stddev_samp(c.value) AS ecart_type,
            count(*) AS n_points,
            (array_agg(c.value ORDER BY c.period DESC))[1] AS derniere_valeur
           FROM (courant c
             JOIN public.indicators i_1 ON (((i_1.indicator_id = c.indicator_id) AND (i_1.geo_reference IS NOT NULL) AND (c.geo = i_1.geo_reference))))
          GROUP BY c.indicator_id
        )
 SELECT i.sector_code,
    count(*) AS n_indicateurs,
        CASE
            WHEN (count(*) >= 2) THEN round(avg((((st.derniere_valeur - st.moyenne) / NULLIF(st.ecart_type, (0)::numeric)) * (i.sens_favorable)::numeric)), 2)
            ELSE NULL::numeric
        END AS score_brut
   FROM (stats st
     JOIN public.indicators i USING (indicator_id))
  WHERE ((i.sens_favorable = ANY (ARRAY['-1'::integer, 1])) AND (i.status = 'certifie'::text) AND (st.ecart_type IS NOT NULL) AND (st.ecart_type > (0)::numeric) AND (st.n_points >= 8))
  GROUP BY i.sector_code;


--
-- Name: VIEW v_sante_secteur_brut; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_sante_secteur_brut IS 'Définition ANTÉRIEURE au 24.08.2026 : écart standardisé sur série brute. Conservée pour documenter l''écart avec la définition détendancée — elle mesure la pente autant que la position (corrélation 0,64 à la tendance).';


--
-- Name: v_signaux; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_signaux AS
 SELECT s.signal_id,
    s.sector_code,
    sec.label AS sector_label,
    s.watch_question_code,
    s.evenement,
    s.acteur,
    s.echeance,
    s.zone,
    s.source_doc,
    s.raw_ref,
    s.score_recoupement,
    s.statut,
    s.validated_by,
    s.validated_at,
    s.note_validation,
    s.run_id,
    s.created_at
   FROM (public.signals s
     JOIN public.sectors sec ON ((sec.code = s.sector_code)));


--
-- Name: VIEW v_signaux; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_signaux IS 'Signaux pour la restitution. Le tableau de bord n''affiche en clair que les validés ; les « à valider » remontent en compteur (analogue de RI5 pour le qualitatif).';


--
-- Name: v_signaux_faibles; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_signaux_faibles AS
 SELECT fi.item_id,
    fs.famille,
    fs.libelle AS flux,
    t.sector_code,
    t.watch_question_code,
    t.anteriorite,
    t.portee,
    t.pertinence AS pertinence_doctrine_signal,
    e.pertinence AS pertinence_doctrine_evenement,
    t.resume,
    t.justification,
    fi.titre,
    fi.url,
    fi.date_publication
   FROM (((public.flux_items fi
     JOIN public.flux_sources fs ON ((fs.flux_id = fi.flux_id)))
     JOIN public.flux_triage_ia t ON (((t.item_id = fi.item_id) AND (t.doctrine = 'signal'::text))))
     LEFT JOIN public.flux_triage_ia e ON (((e.item_id = fi.item_id) AND (e.doctrine = 'evenement'::text))))
  WHERE ((NOT (EXISTS ( SELECT 1
           FROM public.flux_examens x
          WHERE (x.item_id = fi.item_id)))) AND (t.anteriorite >= 1) AND (t.portee >= 1))
  ORDER BY t.anteriorite DESC, t.portee DESC, fi.date_publication DESC;


--
-- Name: VIEW v_signaux_faibles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_signaux_faibles IS 'File de lecture des signaux faibles : items que la seconde doctrine juge antérieurs à la statistique ET porteurs pour une PME de mécanique de précision. Volontairement SANS filtre de pertinence — un signal faible n''a pas encore la forme d''un événement, et l''exiger reviendrait à le manquer. La colonne pertinence_doctrine_evenement montre ce que la première passe en avait fait.';


--
-- Name: v_signaux_faibles_groupes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_signaux_faibles_groupes AS
 WITH base AS (
         SELECT s.item_id,
            s.famille,
            s.flux,
            s.sector_code,
            s.watch_question_code,
            s.anteriorite,
            s.portee,
            s.pertinence_doctrine_signal,
            s.pertinence_doctrine_evenement,
            s.resume,
            s.justification,
            s.titre,
            s.url,
            s.date_publication,
            public.cle_evenement(s.titre, s.url) AS cle_evt
           FROM public.v_signaux_faibles s
        ), classe AS (
         SELECT b.item_id,
            b.famille,
            b.flux,
            b.sector_code,
            b.watch_question_code,
            b.anteriorite,
            b.portee,
            b.pertinence_doctrine_signal,
            b.pertinence_doctrine_evenement,
            b.resume,
            b.justification,
            b.titre,
            b.url,
            b.date_publication,
            b.cle_evt,
            count(*) OVER (PARTITION BY b.cle_evt) AS n_reprises,
            min(b.date_publication) OVER (PARTITION BY b.cle_evt) AS premiere_parution,
            row_number() OVER (PARTITION BY b.cle_evt ORDER BY b.date_publication, b.item_id) AS rang
           FROM base b
        )
 SELECT item_id,
    cle_evt,
    n_reprises,
    premiere_parution,
    famille,
    flux,
    sector_code,
    watch_question_code,
    anteriorite,
    portee,
    pertinence_doctrine_signal,
    pertinence_doctrine_evenement,
    titre,
    url,
    resume,
    justification
   FROM classe
  WHERE (rang = 1)
  ORDER BY anteriorite DESC, portee DESC, n_reprises DESC, premiere_parution DESC;


--
-- Name: VIEW v_signaux_faibles_groupes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_signaux_faibles_groupes IS 'File des signaux faibles dédoublonnée des reprises syndiquées, une ligne par événement. Représentant = la reprise la plus ancienne (elle porte l''antériorité réelle). n_reprises expose l''écho : un événement repris par quatre organes n''est pas équivalent à un événement isolé.';


--
-- Name: validation_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.validation_queue (
    item_id bigint NOT NULL,
    indicator_id text NOT NULL,
    run_id bigint NOT NULL,
    period text NOT NULL,
    geo text DEFAULT 'WORLD'::text NOT NULL,
    extractions jsonb NOT NULL,
    consensus_score numeric NOT NULL,
    source_doc text NOT NULL,
    raw_ref text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    decided_value numeric,
    decision text,
    decided_by text,
    decided_at timestamp with time zone,
    CONSTRAINT chk_decision_complete CHECK (((decision IS NULL) OR ((decided_by IS NOT NULL) AND (decided_at IS NOT NULL)))),
    CONSTRAINT validation_queue_decision_check CHECK (((decision IS NULL) OR (decision = ANY (ARRAY['accepte'::text, 'corrige'::text, 'rejete'::text]))))
);


--
-- Name: TABLE validation_queue; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.validation_queue IS 'Sas entre l''extraction par IA et le registre. Tout désaccord entre modèles, toute valeur aberrante y transite. Le taux de correction observé ici est la métrique de preuve qui conditionne le passage en supervision par exception (§ 10.4.2).';


--
-- Name: v_taux_correction_humaine; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_taux_correction_humaine AS
 SELECT indicator_id,
    count(*) AS items_traites,
    count(*) FILTER (WHERE (decision = 'accepte'::text)) AS acceptes,
    count(*) FILTER (WHERE (decision = 'corrige'::text)) AS corriges,
    count(*) FILTER (WHERE (decision = 'rejete'::text)) AS rejetes,
    count(*) FILTER (WHERE (decision IS NULL)) AS en_attente,
    round((((count(*) FILTER (WHERE (decision = ANY (ARRAY['corrige'::text, 'rejete'::text]))))::numeric / (NULLIF(count(*) FILTER (WHERE (decision IS NOT NULL)), 0))::numeric) * (100)::numeric), 2) AS taux_correction_pct
   FROM public.validation_queue
  GROUP BY indicator_id;


--
-- Name: v_tension_chaine; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_tension_chaine AS
 WITH m AS (
         SELECT mm.indicator_id,
            mm.period,
            mm.ecart_a_la_moyenne_pct AS e
           FROM (public.v_metriques mm
             JOIN public.indicators i USING (indicator_id))
          WHERE ((mm.geo = i.geo_reference) AND (mm.ecart_a_la_moyenne_pct IS NOT NULL))
        )
 SELECT c.marche,
    am.period,
    round(am.e, 1) AS amont_vs_moyenne,
    round(av.e, 1) AS production_vs_moyenne,
    round((am.e - av.e), 1) AS tension
   FROM ((( VALUES ('automobile'::text,'A2'::text,'A6'::text), ('medical'::text,'M7'::text,'M2'::text), ('aerospatial'::text,'S7'::text,'S8'::text), ('horlogerie'::text,'H9'::text,'H6'::text)) c(marche, amont, aval)
     JOIN m am ON ((am.indicator_id = c.amont)))
     JOIN m av ON (((av.indicator_id = c.aval) AND (av.period = am.period))))
  ORDER BY c.marche, am.period;


--
-- Name: VIEW v_tension_chaine; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_tension_chaine IS 'Écart entre la position de l''amont d''un marché et celle de sa production adressable, chacune contre sa propre moyenne douze mois. Tension positive = l''amont tire, la production ne suit pas encore : charge à venir pour la sous-traitance. Le § 8.6 transformé en série. Couples : A2/A6, M7/M2, S7/S8, H9/H6.';


--
-- Name: v_triage_a_echantillonner; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_triage_a_echantillonner AS
 SELECT e.decision,
    t.pertinence,
    count(*) AS n
   FROM (public.flux_examens e
     JOIN public.flux_triage_ia t ON ((t.item_id = e.item_id)))
  GROUP BY e.decision, t.pertinence
  ORDER BY e.decision, t.pertinence;


--
-- Name: v_vitrine; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_vitrine AS
 SELECT DISTINCT ON (i.indicator_id) i.indicator_id,
    i.sector_code,
    sec.label AS sector_label,
    i.label,
    i.description_metier,
    i.unit,
    i.frequency,
    i.latence,
    i.category,
    i.sens_favorable,
    i.geo_reference,
    m.period,
    m.value,
    m.variation_periode_pct,
    m.glissement_annuel_pct,
    m.moyenne_mobile_annuelle,
    m.ecart_a_la_moyenne_pct,
    m.nb_points_moyenne,
    m.seuil_materialite_pct,
    m.franchissement,
    s.organisation AS source_organisation,
    s.url AS source_url,
    ( SELECT count(DISTINCT v.period) AS count
           FROM public.indicator_values v
          WHERE ((v.indicator_id = i.indicator_id) AND (v.geo = i.geo_reference))) AS n_periodes
   FROM (((public.indicators i
     JOIN public.sectors sec ON ((sec.code = i.sector_code)))
     LEFT JOIN public.sources s ON ((s.source_id = i.source_id)))
     LEFT JOIN public.v_metriques m ON (((m.indicator_id = i.indicator_id) AND (m.geo = i.geo_reference))))
  WHERE i.en_vitrine
  ORDER BY i.indicator_id, m.period DESC NULLS LAST;


--
-- Name: VIEW v_vitrine; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_vitrine IS 'Les indicateurs suivis, prêts à l''affichage : dernière valeur, variation, écart à leur propre moyenne, rôle (annonce/constate/confirme) et source. Remplace le score sectoriel sur l''écran de décision — treize séries nommées sont plus interprétables qu''un nombre agrégé.';


--
-- Name: validation_queue_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.validation_queue_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: validation_queue_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.validation_queue_item_id_seq OWNED BY public.validation_queue.item_id;


--
-- Name: agent_commentaries; Type: TABLE; Schema: sandbox; Owner: -
--

CREATE TABLE sandbox.agent_commentaries (
    id bigint NOT NULL,
    run_namespace text DEFAULT 'sandbox_agent'::text NOT NULL,
    sector text,
    watch_question text,
    text text,
    status text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: agent_commentaries_id_seq; Type: SEQUENCE; Schema: sandbox; Owner: -
--

CREATE SEQUENCE sandbox.agent_commentaries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_commentaries_id_seq; Type: SEQUENCE OWNED BY; Schema: sandbox; Owner: -
--

ALTER SEQUENCE sandbox.agent_commentaries_id_seq OWNED BY sandbox.agent_commentaries.id;


--
-- Name: agent_runs; Type: TABLE; Schema: sandbox; Owner: -
--

CREATE TABLE sandbox.agent_runs (
    id bigint NOT NULL,
    run_namespace text DEFAULT 'sandbox_agent'::text NOT NULL,
    scenario text DEFAULT 'C'::text NOT NULL,
    clos_le timestamp with time zone,
    nb_iterations integer,
    plafond_atteint boolean,
    appels_par_outil jsonb,
    referentiel_consulte boolean,
    outil_calcul_utilise boolean,
    sortie_finale text,
    trace_complete jsonb,
    autocritique jsonb
);


--
-- Name: agent_runs_id_seq; Type: SEQUENCE; Schema: sandbox; Owner: -
--

CREATE SEQUENCE sandbox.agent_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: sandbox; Owner: -
--

ALTER SEQUENCE sandbox.agent_runs_id_seq OWNED BY sandbox.agent_runs.id;


--
-- Name: agent_values; Type: TABLE; Schema: sandbox; Owner: -
--

CREATE TABLE sandbox.agent_values (
    id bigint NOT NULL,
    run_namespace text DEFAULT 'sandbox_agent'::text NOT NULL,
    indicator_label text,
    sector text,
    watch_question text,
    period text,
    geo text,
    value text,
    source_url text,
    obtained_by text,
    validation_status text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: agent_values_id_seq; Type: SEQUENCE; Schema: sandbox; Owner: -
--

CREATE SEQUENCE sandbox.agent_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_values_id_seq; Type: SEQUENCE OWNED BY; Schema: sandbox; Owner: -
--

ALTER SEQUENCE sandbox.agent_values_id_seq OWNED BY sandbox.agent_values.id;


--
-- Name: commentaires_attribution; Type: TABLE; Schema: sandbox; Owner: -
--

CREATE TABLE sandbox.commentaires_attribution (
    id bigint NOT NULL,
    run_id integer,
    sector_code text NOT NULL,
    variante text DEFAULT 'attribution_ancree'::text NOT NULL,
    input_payload jsonb,
    contexte_fourni jsonb,
    model text,
    text text,
    ancres_citees text[],
    ancres_disponibles integer,
    statut text DEFAULT 'demonstration'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    validated_by text,
    validated_at timestamp with time zone,
    note_validation text,
    CONSTRAINT chk_attribution_statut CHECK ((statut = ANY (ARRAY['demonstration'::text, 'valide'::text, 'rejete'::text]))),
    CONSTRAINT chk_attribution_valide_trace CHECK (((statut <> 'valide'::text) OR ((validated_by IS NOT NULL) AND (validated_at IS NOT NULL))))
);


--
-- Name: TABLE commentaires_attribution; Type: COMMENT; Schema: sandbox; Owner: -
--

COMMENT ON TABLE sandbox.commentaires_attribution IS 'Démonstration de faisabilité de l''attribution ancrée (24.08.2026). Hors production : aucune ligne n''est servie par l''interface de restitution. La comparaison se fait contre le commentaire de production du même secteur, rédigé sous RI9 et sans contexte factuel.';


--
-- Name: commentaires_attribution_id_seq; Type: SEQUENCE; Schema: sandbox; Owner: -
--

CREATE SEQUENCE sandbox.commentaires_attribution_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: commentaires_attribution_id_seq; Type: SEQUENCE OWNED BY; Schema: sandbox; Owner: -
--

ALTER SEQUENCE sandbox.commentaires_attribution_id_seq OWNED BY sandbox.commentaires_attribution.id;


--
-- Name: alerts alert_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alerts ALTER COLUMN alert_id SET DEFAULT nextval('public.alerts_alert_id_seq'::regclass);


--
-- Name: commentaries commentary_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commentaries ALTER COLUMN commentary_id SET DEFAULT nextval('public.commentaries_commentary_id_seq'::regclass);


--
-- Name: composite_queue doc_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.composite_queue ALTER COLUMN doc_id SET DEFAULT nextval('public.composite_queue_doc_id_seq'::regclass);


--
-- Name: discovery_log log_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discovery_log ALTER COLUMN log_id SET DEFAULT nextval('public.discovery_log_log_id_seq'::regclass);


--
-- Name: flux_examens examen_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_examens ALTER COLUMN examen_id SET DEFAULT nextval('public.flux_examens_examen_id_seq'::regclass);


--
-- Name: flux_filtrage_audit audit_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_filtrage_audit ALTER COLUMN audit_id SET DEFAULT nextval('public.flux_filtrage_audit_audit_id_seq'::regclass);


--
-- Name: flux_items item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_items ALTER COLUMN item_id SET DEFAULT nextval('public.flux_items_item_id_seq'::regclass);


--
-- Name: flux_triage_ia triage_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_triage_ia ALTER COLUMN triage_id SET DEFAULT nextval('public.flux_triage_ia_triage_id_seq'::regclass);


--
-- Name: indicator_values value_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicator_values ALTER COLUMN value_id SET DEFAULT nextval('public.indicator_values_value_id_seq'::regclass);


--
-- Name: runs run_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.runs ALTER COLUMN run_id SET DEFAULT nextval('public.runs_run_id_seq'::regclass);


--
-- Name: signals signal_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signals ALTER COLUMN signal_id SET DEFAULT nextval('public.signals_signal_id_seq'::regclass);


--
-- Name: source_bindings binding_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_bindings ALTER COLUMN binding_id SET DEFAULT nextval('public.source_bindings_binding_id_seq'::regclass);


--
-- Name: source_qualification_queue item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_qualification_queue ALTER COLUMN item_id SET DEFAULT nextval('public.source_qualification_queue_item_id_seq'::regclass);


--
-- Name: ted_lecture_ia lecture_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ted_lecture_ia ALTER COLUMN lecture_id SET DEFAULT nextval('public.ted_lecture_ia_lecture_id_seq'::regclass);


--
-- Name: validation_queue item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.validation_queue ALTER COLUMN item_id SET DEFAULT nextval('public.validation_queue_item_id_seq'::regclass);


--
-- Name: agent_commentaries id; Type: DEFAULT; Schema: sandbox; Owner: -
--

ALTER TABLE ONLY sandbox.agent_commentaries ALTER COLUMN id SET DEFAULT nextval('sandbox.agent_commentaries_id_seq'::regclass);


--
-- Name: agent_runs id; Type: DEFAULT; Schema: sandbox; Owner: -
--

ALTER TABLE ONLY sandbox.agent_runs ALTER COLUMN id SET DEFAULT nextval('sandbox.agent_runs_id_seq'::regclass);


--
-- Name: agent_values id; Type: DEFAULT; Schema: sandbox; Owner: -
--

ALTER TABLE ONLY sandbox.agent_values ALTER COLUMN id SET DEFAULT nextval('sandbox.agent_values_id_seq'::regclass);


--
-- Name: commentaires_attribution id; Type: DEFAULT; Schema: sandbox; Owner: -
--

ALTER TABLE ONLY sandbox.commentaires_attribution ALTER COLUMN id SET DEFAULT nextval('sandbox.commentaires_attribution_id_seq'::regclass);


--
-- Name: alerts alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alerts
    ADD CONSTRAINT alerts_pkey PRIMARY KEY (alert_id);


--
-- Name: commentaries commentaries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commentaries
    ADD CONSTRAINT commentaries_pkey PRIMARY KEY (commentary_id);


--
-- Name: composite_queue composite_queue_indicator_id_period_source_doc_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.composite_queue
    ADD CONSTRAINT composite_queue_indicator_id_period_source_doc_key UNIQUE (indicator_id, period, source_doc);


--
-- Name: composite_queue composite_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.composite_queue
    ADD CONSTRAINT composite_queue_pkey PRIMARY KEY (doc_id);


--
-- Name: discovery_log discovery_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discovery_log
    ADD CONSTRAINT discovery_log_pkey PRIMARY KEY (log_id);


--
-- Name: flux_examens flux_examens_item_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_examens
    ADD CONSTRAINT flux_examens_item_id_key UNIQUE (item_id);


--
-- Name: flux_examens flux_examens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_examens
    ADD CONSTRAINT flux_examens_pkey PRIMARY KEY (examen_id);


--
-- Name: flux_filtrage_audit flux_filtrage_audit_item_id_echantillon_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_filtrage_audit
    ADD CONSTRAINT flux_filtrage_audit_item_id_echantillon_key UNIQUE (item_id, echantillon);


--
-- Name: flux_filtrage_audit flux_filtrage_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_filtrage_audit
    ADD CONSTRAINT flux_filtrage_audit_pkey PRIMARY KEY (audit_id);


--
-- Name: flux_filtrage flux_filtrage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_filtrage
    ADD CONSTRAINT flux_filtrage_pkey PRIMARY KEY (item_id);


--
-- Name: flux_filtrage_regles flux_filtrage_regles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_filtrage_regles
    ADD CONSTRAINT flux_filtrage_regles_pkey PRIMARY KEY (regle_code);


--
-- Name: flux_items flux_items_empreinte_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_items
    ADD CONSTRAINT flux_items_empreinte_key UNIQUE (empreinte);


--
-- Name: flux_items flux_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_items
    ADD CONSTRAINT flux_items_pkey PRIMARY KEY (item_id);


--
-- Name: flux_sources flux_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_sources
    ADD CONSTRAINT flux_sources_pkey PRIMARY KEY (flux_id);


--
-- Name: flux_triage_ia flux_triage_ia_item_modele_doctrine_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_triage_ia
    ADD CONSTRAINT flux_triage_ia_item_modele_doctrine_key UNIQUE (item_id, modele, doctrine);


--
-- Name: flux_triage_ia flux_triage_ia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_triage_ia
    ADD CONSTRAINT flux_triage_ia_pkey PRIMARY KEY (triage_id);


--
-- Name: indicator_values indicator_values_indicator_id_run_id_period_geo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicator_values
    ADD CONSTRAINT indicator_values_indicator_id_run_id_period_geo_key UNIQUE (indicator_id, run_id, period, geo);


--
-- Name: indicator_values indicator_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicator_values
    ADD CONSTRAINT indicator_values_pkey PRIMARY KEY (value_id);


--
-- Name: indicator_watch_questions indicator_watch_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicator_watch_questions
    ADD CONSTRAINT indicator_watch_questions_pkey PRIMARY KEY (indicator_id, watch_question_code);


--
-- Name: indicators indicators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicators
    ADD CONSTRAINT indicators_pkey PRIMARY KEY (indicator_id);


--
-- Name: runs runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.runs
    ADD CONSTRAINT runs_pkey PRIMARY KEY (run_id);


--
-- Name: sector_watch_questions sector_watch_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sector_watch_questions
    ADD CONSTRAINT sector_watch_questions_pkey PRIMARY KEY (sector_code, watch_question_code);


--
-- Name: sectors sectors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sectors
    ADD CONSTRAINT sectors_pkey PRIMARY KEY (code);


--
-- Name: signals signals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signals
    ADD CONSTRAINT signals_pkey PRIMARY KEY (signal_id);


--
-- Name: source_bindings source_bindings_indicator_id_connecteur_url_base_params_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_bindings
    ADD CONSTRAINT source_bindings_indicator_id_connecteur_url_base_params_key UNIQUE (indicator_id, connecteur, url_base, params);


--
-- Name: source_bindings source_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_bindings
    ADD CONSTRAINT source_bindings_pkey PRIMARY KEY (binding_id);


--
-- Name: source_qualification_queue source_qualification_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_qualification_queue
    ADD CONSTRAINT source_qualification_queue_pkey PRIMARY KEY (item_id);


--
-- Name: sources sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sources
    ADD CONSTRAINT sources_pkey PRIMARY KEY (source_id);


--
-- Name: ted_avis ted_avis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ted_avis
    ADD CONSTRAINT ted_avis_pkey PRIMARY KEY (publication_number);


--
-- Name: ted_lecture_ia ted_lecture_ia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ted_lecture_ia
    ADD CONSTRAINT ted_lecture_ia_pkey PRIMARY KEY (lecture_id);


--
-- Name: validation_queue validation_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.validation_queue
    ADD CONSTRAINT validation_queue_pkey PRIMARY KEY (item_id);


--
-- Name: watch_questions watch_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watch_questions
    ADD CONSTRAINT watch_questions_pkey PRIMARY KEY (code);


--
-- Name: agent_commentaries agent_commentaries_pkey; Type: CONSTRAINT; Schema: sandbox; Owner: -
--

ALTER TABLE ONLY sandbox.agent_commentaries
    ADD CONSTRAINT agent_commentaries_pkey PRIMARY KEY (id);


--
-- Name: agent_runs agent_runs_pkey; Type: CONSTRAINT; Schema: sandbox; Owner: -
--

ALTER TABLE ONLY sandbox.agent_runs
    ADD CONSTRAINT agent_runs_pkey PRIMARY KEY (id);


--
-- Name: agent_values agent_values_pkey; Type: CONSTRAINT; Schema: sandbox; Owner: -
--

ALTER TABLE ONLY sandbox.agent_values
    ADD CONSTRAINT agent_values_pkey PRIMARY KEY (id);


--
-- Name: commentaires_attribution commentaires_attribution_pkey; Type: CONSTRAINT; Schema: sandbox; Owner: -
--

ALTER TABLE ONLY sandbox.commentaires_attribution
    ADD CONSTRAINT commentaires_attribution_pkey PRIMARY KEY (id);


--
-- Name: idx_flux_items_lecture; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flux_items_lecture ON public.flux_items USING btree (flux_id, date_publication DESC);


--
-- Name: idx_ted_avis_acheteur; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ted_avis_acheteur ON public.ted_avis USING btree (acheteur, sector_code);


--
-- Name: idx_ted_avis_lecture; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ted_avis_lecture ON public.ted_avis USING btree (est_appel_ouvert, date_limite);


--
-- Name: idx_values_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_values_lookup ON public.indicator_values USING btree (indicator_id, period, geo, run_id DESC);


--
-- Name: ted_lecture_ia_cle; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ted_lecture_ia_cle ON public.ted_lecture_ia USING btree (publication_number, modele, profil);


--
-- Name: flux_filtrage trg_filtrage_ajout_seul; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_filtrage_ajout_seul BEFORE DELETE OR UPDATE ON public.flux_filtrage FOR EACH ROW EXECUTE FUNCTION public.f_filtrage_ajout_seul();


--
-- Name: flux_items trg_flux_ajout_seul; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_flux_ajout_seul BEFORE DELETE OR UPDATE ON public.flux_items FOR EACH ROW EXECUTE FUNCTION public.interdire_modification_flux();


--
-- Name: indicators trg_indicateur_sans_question; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_indicateur_sans_question AFTER INSERT ON public.indicators DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.exiger_question_de_veille();


--
-- Name: indicator_values trg_registre_ajout_seul; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_registre_ajout_seul BEFORE DELETE OR UPDATE ON public.indicator_values FOR EACH ROW EXECUTE FUNCTION public.interdire_modification_du_registre();


--
-- Name: alerts alerts_indicator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alerts
    ADD CONSTRAINT alerts_indicator_id_fkey FOREIGN KEY (indicator_id) REFERENCES public.indicators(indicator_id);


--
-- Name: alerts alerts_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alerts
    ADD CONSTRAINT alerts_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.runs(run_id);


--
-- Name: commentaries commentaries_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commentaries
    ADD CONSTRAINT commentaries_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.runs(run_id);


--
-- Name: commentaries commentaries_sector_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commentaries
    ADD CONSTRAINT commentaries_sector_code_fkey FOREIGN KEY (sector_code) REFERENCES public.sectors(code);


--
-- Name: commentaries commentaries_watch_question_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commentaries
    ADD CONSTRAINT commentaries_watch_question_code_fkey FOREIGN KEY (watch_question_code) REFERENCES public.watch_questions(code);


--
-- Name: composite_queue composite_queue_indicator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.composite_queue
    ADD CONSTRAINT composite_queue_indicator_id_fkey FOREIGN KEY (indicator_id) REFERENCES public.indicators(indicator_id);


--
-- Name: composite_queue composite_queue_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.composite_queue
    ADD CONSTRAINT composite_queue_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.runs(run_id);


--
-- Name: flux_examens flux_examens_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_examens
    ADD CONSTRAINT flux_examens_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.flux_items(item_id);


--
-- Name: flux_examens flux_examens_signal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_examens
    ADD CONSTRAINT flux_examens_signal_id_fkey FOREIGN KEY (signal_id) REFERENCES public.signals(signal_id);


--
-- Name: flux_filtrage_audit flux_filtrage_audit_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_filtrage_audit
    ADD CONSTRAINT flux_filtrage_audit_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.flux_items(item_id);


--
-- Name: flux_filtrage flux_filtrage_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_filtrage
    ADD CONSTRAINT flux_filtrage_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.flux_items(item_id);


--
-- Name: flux_filtrage flux_filtrage_regle_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_filtrage
    ADD CONSTRAINT flux_filtrage_regle_code_fkey FOREIGN KEY (regle_code) REFERENCES public.flux_filtrage_regles(regle_code);


--
-- Name: flux_items flux_items_flux_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_items
    ADD CONSTRAINT flux_items_flux_id_fkey FOREIGN KEY (flux_id) REFERENCES public.flux_sources(flux_id);


--
-- Name: flux_items flux_items_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_items
    ADD CONSTRAINT flux_items_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.runs(run_id);


--
-- Name: flux_sources flux_sources_sector_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_sources
    ADD CONSTRAINT flux_sources_sector_code_fkey FOREIGN KEY (sector_code) REFERENCES public.sectors(code);


--
-- Name: flux_triage_ia flux_triage_ia_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_triage_ia
    ADD CONSTRAINT flux_triage_ia_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.flux_items(item_id);


--
-- Name: flux_triage_ia flux_triage_ia_sector_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_triage_ia
    ADD CONSTRAINT flux_triage_ia_sector_code_fkey FOREIGN KEY (sector_code) REFERENCES public.sectors(code);


--
-- Name: flux_triage_ia flux_triage_ia_watch_question_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flux_triage_ia
    ADD CONSTRAINT flux_triage_ia_watch_question_code_fkey FOREIGN KEY (watch_question_code) REFERENCES public.watch_questions(code);


--
-- Name: indicator_values indicator_values_indicator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicator_values
    ADD CONSTRAINT indicator_values_indicator_id_fkey FOREIGN KEY (indicator_id) REFERENCES public.indicators(indicator_id);


--
-- Name: indicator_values indicator_values_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicator_values
    ADD CONSTRAINT indicator_values_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.runs(run_id);


--
-- Name: indicator_watch_questions indicator_watch_questions_indicator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicator_watch_questions
    ADD CONSTRAINT indicator_watch_questions_indicator_id_fkey FOREIGN KEY (indicator_id) REFERENCES public.indicators(indicator_id) ON DELETE CASCADE;


--
-- Name: indicator_watch_questions indicator_watch_questions_watch_question_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicator_watch_questions
    ADD CONSTRAINT indicator_watch_questions_watch_question_code_fkey FOREIGN KEY (watch_question_code) REFERENCES public.watch_questions(code);


--
-- Name: indicators indicators_sector_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicators
    ADD CONSTRAINT indicators_sector_code_fkey FOREIGN KEY (sector_code) REFERENCES public.sectors(code);


--
-- Name: indicators indicators_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicators
    ADD CONSTRAINT indicators_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.sources(source_id);


--
-- Name: sector_watch_questions sector_watch_questions_sector_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sector_watch_questions
    ADD CONSTRAINT sector_watch_questions_sector_code_fkey FOREIGN KEY (sector_code) REFERENCES public.sectors(code);


--
-- Name: sector_watch_questions sector_watch_questions_watch_question_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sector_watch_questions
    ADD CONSTRAINT sector_watch_questions_watch_question_code_fkey FOREIGN KEY (watch_question_code) REFERENCES public.watch_questions(code);


--
-- Name: signals signals_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signals
    ADD CONSTRAINT signals_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.runs(run_id);


--
-- Name: signals signals_sector_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signals
    ADD CONSTRAINT signals_sector_code_fkey FOREIGN KEY (sector_code) REFERENCES public.sectors(code);


--
-- Name: signals signals_watch_question_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signals
    ADD CONSTRAINT signals_watch_question_code_fkey FOREIGN KEY (watch_question_code) REFERENCES public.watch_questions(code);


--
-- Name: source_bindings source_bindings_indicator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_bindings
    ADD CONSTRAINT source_bindings_indicator_id_fkey FOREIGN KEY (indicator_id) REFERENCES public.indicators(indicator_id);


--
-- Name: source_qualification_queue source_qualification_queue_sector_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_qualification_queue
    ADD CONSTRAINT source_qualification_queue_sector_code_fkey FOREIGN KEY (sector_code) REFERENCES public.sectors(code);


--
-- Name: source_qualification_queue source_qualification_queue_watch_question_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_qualification_queue
    ADD CONSTRAINT source_qualification_queue_watch_question_code_fkey FOREIGN KEY (watch_question_code) REFERENCES public.watch_questions(code);


--
-- Name: ted_avis ted_avis_flux_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ted_avis
    ADD CONSTRAINT ted_avis_flux_id_fkey FOREIGN KEY (flux_id) REFERENCES public.flux_sources(flux_id);


--
-- Name: ted_avis ted_avis_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ted_avis
    ADD CONSTRAINT ted_avis_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.flux_items(item_id);


--
-- Name: ted_avis ted_avis_sector_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ted_avis
    ADD CONSTRAINT ted_avis_sector_code_fkey FOREIGN KEY (sector_code) REFERENCES public.sectors(code);


--
-- Name: ted_lecture_ia ted_lecture_ia_publication_number_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ted_lecture_ia
    ADD CONSTRAINT ted_lecture_ia_publication_number_fkey FOREIGN KEY (publication_number) REFERENCES public.ted_avis(publication_number);


--
-- Name: validation_queue validation_queue_indicator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.validation_queue
    ADD CONSTRAINT validation_queue_indicator_id_fkey FOREIGN KEY (indicator_id) REFERENCES public.indicators(indicator_id);


--
-- Name: validation_queue validation_queue_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.validation_queue
    ADD CONSTRAINT validation_queue_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.runs(run_id);


--
-- PostgreSQL database dump complete
--


