import React, { useState } from "react";
import { useDonnees, nb, dateCH, nomZone } from "../api.jsx";
import { Entonnoir } from "../Mini.jsx";
import { phraseEcheance, tonEcheance, enLettres } from "../phrases.jsx";

// =====================================================================
// À FAIRE — le seul écran du dispositif qui produise des gestes datés.
//
// Il réunit ce qui était séparé en deux pages (« Actions » et
// « Opportunités ») sans raison lisible pour l'utilisateur : dans les deux
// cas la question est « sur quoi est-ce que je me positionne, et quand ? ».
//
// Ordre de lecture imposé par l'urgence, pas par le secteur : ce qui se
// clôt demain passe devant ce qui se clôt dans deux mois, quel que soit le
// marché. C'est la seule hiérarchie qu'un dirigeant applique réellement.
// =====================================================================

function Fiche({ a }) {
  const [ouvert, setOuvert] = useState(false);
  const ton = tonEcheance(a.jours_restants);
  const coeur = a.adressable === 2;

  return (
    <article className={"fiche t-" + ton}>
      <div className="fiche-bandeau">
        <span className={"fiche-delai t-" + ton}>{phraseEcheance(a.jours_restants)}</span>
        {coeur && <span className="etq e-violet">cœur de métier</span>}
        {a.acheteur_recurrent && (
          <span className="etq e-bleu" title={`${a.acheteur_avis_publies} avis publiés par cet acheteur`}>
            acheteur habitué
          </span>
        )}
        <span className="fiche-ech">clôture le {dateCH(a.date_limite)}</span>
      </div>

      <h3 className="fiche-titre">{a.piece_concernee || a.titre}</h3>

      <p className="fiche-qui">
        <strong>{a.acheteur}</strong>
        {a.acheteur_ville ? `, ${a.acheteur_ville}` : ""}
        {a.acheteur_pays ? ` (${nomZone(a.acheteur_pays)})` : ""}
        {a.valeur_estimee
          ? <> · valeur annoncée {nb(a.valeur_estimee)} {a.devise || ""}</>
          : <> · valeur non publiée</>}
      </p>

      {a.action_proposee && (
        <p className="fiche-geste"><span className="geste-puce">Geste proposé</span> {a.action_proposee}</p>
      )}

      <div className="fiche-pied">
        <a className="bouton-primaire" href={a.url} target="_blank" rel="noreferrer">
          Ouvrir l'avis officiel ↗
        </a>
        {a.acheteur_courriel && (
          <a className="bouton-second" href={"mailto:" + a.acheteur_courriel}>
            Écrire à l'acheteur
          </a>
        )}
        <button className="bouton-lien" onClick={() => setOuvert(o => !o)}>
          {ouvert ? "Masquer le raisonnement" : "Pourquoi cet avis ?"}
        </button>
      </div>

      {ouvert && (
        <div className="fiche-raison">
          <p>{a.justification || "Aucune justification enregistrée."}</p>
          <p className="fiche-modele">
            Lecture d'adressabilité produite par <strong>{a.modele || "un modèle"}</strong>.
            Elle <strong>ordonne</strong> votre lecture ; elle ne décide rien, et l'avis officiel
            reste à un clic. Code CPV {a.cpv || "non publié"} · publié le {dateCH(a.date_publication)}.
          </p>
        </div>
      )}
    </article>
  );
}

// ---------------------------------------------------------------------
// QUI ACHÈTE — la demande publique ramenée à ses acteurs nommés.
//
// Ce n'est PAS une liste de prospection. C'est le monitoring de marché mené
// jusqu'à son terme : un avis d'appel d'offres est un signal de demande, et
// quand on cesse de l'agréger on découvre que cette demande a un nom, une
// récurrence et une spécialité. Un acheteur qui publie onze avis en un mois
// sur une seule famille de pièces dit quelque chose de la structure du
// marché que nulle série macroéconomique ne dira.
//
// La récurrence est la grandeur qui compte : un avis isolé est un accident,
// une série d'avis est un débouché.
// ---------------------------------------------------------------------
function Acheteurs({ acheteurs }) {
  const [tout, setTout] = useState(false);
  const liste = [...(acheteurs || [])].sort(
    (a, b) => (b.avis_publies || 0) - (a.avis_publies || 0));
  if (!liste.length) return null;
  const recurrents = liste.filter(a => (a.avis_publies || 0) >= 3);
  const montres = tout ? liste : liste.slice(0, 12);

  return (
    <>
      <h2 className="s-titre">
        Qui achète, dans ces marchés
        <span className="s-sous">
          {liste.length} organisations identifiées · {recurrents.length} publient régulièrement
        </span>
      </h2>

      <p className="bloc-intro" style={{ maxWidth: 780 }}>
        Les avis collectés ne sont pas seulement des occasions : agrégés par émetteur, ils
        dessinent <strong>qui achète quoi, et à quelle fréquence</strong>. Un acheteur qui publie
        onze avis en un mois sur une seule famille de pièces renseigne sur la structure d'un
        marché mieux qu'une série macroéconomique. C'est la demande publique ramenée à ses
        acteurs nommés — le suivi de marché mené jusqu'au bout.
      </p>

      <div className="carte" style={{ padding: 0, overflow: "hidden" }}>
        <table className="t-compacte t-acheteurs">
          <thead>
            <tr>
              <th>Organisation</th><th>Marché</th>
              <th style={{ textAlign: "right" }}>Avis</th>
              <th style={{ textAlign: "right" }}>dont ouverts</th>
              <th style={{ textAlign: "right" }}>Familles de pièces</th>
              <th>Actif depuis</th><th>Contact</th>
            </tr>
          </thead>
          <tbody>
            {montres.map((a, i) => (
              <tr key={i}>
                <td>
                  <strong>{a.acheteur}</strong>
                  <div className="cell-note">{nomZone(a.acheteur_pays)}</div>
                </td>
                <td>
                  {a.sector_code
                    ? <span className="etq e-gris">{a.sector_code}</span>
                    : <span className="etq e-ambre" title="marché hors des quatre secteurs suivis">hors grille</span>}
                </td>
                <td style={{ textAlign: "right", fontWeight: 650 }}>{a.avis_publies}</td>
                <td style={{ textAlign: "right" }}>
                  {a.dont_encore_ouverts
                    ? <strong className="hausse">{a.dont_encore_ouverts}</strong>
                    : <span className="neutre">—</span>}
                </td>
                <td style={{ textAlign: "right" }}
                    title={(a.cpv_distincts || []).join(", ")}>
                  {(a.cpv_distincts || []).length}
                </td>
                <td className="cell-note">{dateCH(a.premier_avis)}</td>
                <td>
                  {a.acheteur_courriel
                    ? <a href={"mailto:" + a.acheteur_courriel}>écrire</a>
                    : <span className="neutre">—</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {liste.length > 12 && (
        <button className="bouton-second" style={{ marginTop: 12 }} onClick={() => setTout(t => !t)}>
          {tout ? "Réduire la liste" : `Montrer les ${liste.length - 12} autres organisations`}
        </button>
      )}

      <p className="note" style={{ marginTop: 12, maxWidth: 780 }}>
        <strong>Une lecture, deux prudences.</strong> Le nombre d'avis mesure l'activité de
        publication de l'acheteur, pas la taille de son marché : une centrale d'achat publie
        beaucoup et un donneur d'ordre privé ne publie rien. Et le périmètre est celui des
        <strong> marchés publics européens</strong> uniquement — la demande privée, qui est
        l'essentiel du carnet d'un sous-traitant, reste hors de portée du dispositif.
      </p>
    </>
  );
}

// ---------------------------------------------------------------------
// LES DIX MIEUX CLASSÉS — le cadrage qui rend la file traitable.
//
// La file d'examen compte 745 items et croît plus vite qu'elle n'est
// traitée. Le compteur seul renvoyait vers un écran qui n'existait pas :
// le bouton promettait « les mieux classés » et livrait autre chose.
//
// Une file de sept cent quarante-cinq ne se traite pas par du temps
// supplémentaire, elle se traite par un CADRAGE : dix items par semaine,
// les mieux notés par le triage, et le reste attend. C'est la seule
// discipline qui tienne pour un dirigeant de PME, et elle rend la limite
// structurelle du scénario semi-automatisé praticable au lieu de la subir.
// ---------------------------------------------------------------------
function FilePrioritaire({ items, enAttente }) {
  if (!items || !items.length) return null;
  const note = i => (i.anteriorite || 0) + (i.portee || 0) + (i.pertinence_signal || 0);
  return (
    <>
      <h2 className="s-titre" id="file">
        Vos dix de la semaine
        <span className="s-sous">
          les mieux notés par le triage, sur {nb(enAttente)} en attente — le reste peut attendre
        </span>
      </h2>
      <p className="bloc-intro" style={{ maxWidth: 780 }}>
        Le triage assisté ordonne, il ne décide pas. Ces dix items sont ceux dont la note
        d'antériorité, de portée et de pertinence est la plus élevée. Les examiner tous les dix
        chaque semaine suffit à tenir le dispositif : c'est un <strong>cadrage</strong>, pas un
        rattrapage — la file ne se videra pas, et ce n'est pas son objet.
      </p>
      <div className="file-liste">
        {items.map(i => (
          <div className="file-item" key={i.item_id}>
            <span className="file-note" title="antériorité + portée + pertinence">{note(i)}</span>
            <div className="file-corps">
              <a href={i.url} target="_blank" rel="noreferrer">{i.titre}</a>
              {i.resume && <p className="file-resume">{i.resume}</p>}
              <p className="file-meta">
                {i.flux}
                {i.sector_code ? ` · ${i.sector_code}` : ""}
                {i.watch_question_code ? ` · ${i.watch_question_code}` : ""}
                {i.date_publication ? ` · ${dateCH(i.date_publication)}` : ""}
              </p>
            </div>
          </div>
        ))}
      </div>
      <p className="note" style={{ marginTop: 10, maxWidth: 780 }}>
        La note vient d'un modèle et <strong>ordonne la lecture</strong> ; elle ne vaut pas
        validation. La promotion d'un item en signal reste un acte nominatif et daté.
      </p>
    </>
  );
}

export default function AFaire() {
  const { A, O, S, erreursV4 } = useDonnees();
  const [tout, setTout] = useState(false);

  if (!A) return (
    <div className="page">
      <div className="vide">
        <strong>La lecture « actions » ne répond pas.</strong><br />
        <span style={{ fontSize: 12 }}>{erreursV4?.["/actions"]}</span>
      </div>
    </div>
  );

  const actions = A.actions || [];
  const t = A.tamis || {};
  const adressables = actions.filter(a => a.adressable >= 1)
    .sort((x, y) => (x.jours_restants ?? 9999) - (y.jours_restants ?? 9999));
  const autres = actions.filter(a => !(a.adressable >= 1))
    .sort((x, y) => (x.jours_restants ?? 9999) - (y.jours_restants ?? 9999));
  const examinees = O?.opportunites || [];

  return (
    <div className="page">
      <header className="ouverture">
        <div>
          <p className="ouv-date">Marchés publics européens · fenêtre de {A.fenetre_jours || 60} jours</p>
          <h1 className="ouv-titre">À faire</h1>
        </div>
      </header>

      <p className="brief">
        {adressables.length === 0
          ? "Aucun appel d'offres à votre portée n'est ouvert dans la fenêtre suivie."
          : <>Sur {nb(t.avis_collectes)} avis collectés, <strong>{enLettres(adressables.length)} sont
            à votre portée</strong> et encore ouverts. Ils sont classés par échéance : le premier
            se clôt {phraseEcheance(adressables[0].jours_restants)}.</>}
      </p>

      {/* ---------- Le tamis, qui explique le petit nombre ---------- */}
      <div className="carte bloc-tamis">
        <h2 className="bloc-titre">D'où viennent ces {enLettres(adressables.length)} avis</h2>
        <p className="bloc-intro">
          Le dispositif ne sélectionne pas : il élimine, à chaque étage, ce qui ne peut pas
          concerner un usineur de précision. Le petit nombre final n'est pas une faiblesse de
          la collecte — c'est le résultat du tri.
        </p>
        <Entonnoir etapes={[
          { libelle: "avis collectés", valeur: t.avis_collectes || 0 },
          { libelle: "appels d'offres (hors attributions)", valeur: t.appels_ouverts || 0 },
          { libelle: "encore ouverts aujourd'hui", valeur: t.non_expires || 0 },
          { libelle: "à votre portée", valeur: t.adressables || 0 },
          { libelle: "cœur de métier", valeur: t.coeur_de_metier || 0 }
        ]} />
        <p className="bloc-note">
          Le passage de « encore ouverts » à « à votre portée » est fait par{" "}
          <strong>{t.modele_lecture || "un modèle"}</strong>, à partir du profil métier déclaré.
          C'est une lecture assistée, pas une décision : chaque fiche porte son raisonnement et
          le lien vers l'avis officiel.
        </p>
      </div>

      {/* ---------- Les fiches ---------- */}
      <h2 className="s-titre">
        À votre portée
        <span className="s-sous">classés par échéance, le plus urgent d'abord</span>
      </h2>
      {adressables.length === 0 ? (
        <div className="vide">
          Aucun avis adressable ouvert. Ce n'est pas une panne : sur la fenêtre suivie, le tri
          n'a rien retenu.
        </div>
      ) : (
        <div className="fiches">{adressables.map(a => <Fiche key={a.publication_number} a={a} />)}</div>
      )}

      {/* ---------- Les dix de la semaine ---------- */}
      <FilePrioritaire items={S?.file_prioritaire} enAttente={S?.items_en_attente_examen || 0} />

      {/* ---------- Qui achète ---------- */}
      <Acheteurs acheteurs={A.acheteurs} />

      {/* ---------- Ce qui a déjà été examiné ---------- */}
      {examinees.length > 0 && (
        <>
          <h2 className="s-titre">
            Déjà passé en revue
            <span className="s-sous">
              {O.examines_total} items examinés à ce jour · {nb(O.en_attente)} en attente
            </span>
          </h2>
          <div className="revues">
            {examinees.slice(0, 8).map(o => (
              <div className="revue" key={o.item_id}>
                <span className={"etq " + (o.decision === "signal" ? "e-violet" : "e-gris")}>
                  {o.decision}
                </span>
                <div className="revue-corps">
                  <a href={o.url} target="_blank" rel="noreferrer">{o.titre}</a>
                  {o.note_examen && <p className="revue-note">{o.note_examen}</p>}
                  <p className="revue-qui">
                    {o.sector_label} · examiné par {o.decide_par || "—"} le {dateCH(o.decide_le)}
                  </p>
                </div>
              </div>
            ))}
          </div>
          <p className="note" style={{ marginTop: 10 }}>
            <strong>{nb(O.en_attente)} items restent non examinés.</strong> À la cadence observée,
            cette file ne se videra pas : elle se traite par un cadrage — les mieux classés d'une
            semaine — et non par du temps supplémentaire. La limite est structurelle au choix
            semi-automatisé, et elle est mesurée plutôt que masquée.
          </p>
        </>
      )}

      {/* ---------- Le reste, replié ---------- */}
      {autres.length > 0 && (
        <>
          <h2 className="s-titre">
            Écartés par la lecture
            <span className="s-sous">{autres.length} avis ouverts, jugés hors du savoir-faire</span>
          </h2>
          {!tout ? (
            <button className="bouton-second" onClick={() => setTout(true)}>
              Montrer les {autres.length} avis écartés
            </button>
          ) : (
            <div className="ecartes">
              {autres.map(a => (
                <div className="ecarte" key={a.publication_number}>
                  <span className="ecarte-delai">{phraseEcheance(a.jours_restants)}</span>
                  <a href={a.url} target="_blank" rel="noreferrer">{a.titre}</a>
                  <span className="ecarte-qui">{a.acheteur}</span>
                </div>
              ))}
            </div>
          )}
          <p className="note" style={{ marginTop: 10 }}>
            Ils restent affichables : un tri assisté par modèle doit pouvoir être contredit,
            sinon il n'est pas contrôlable.
          </p>
        </>
      )}
    </div>
  );
}
