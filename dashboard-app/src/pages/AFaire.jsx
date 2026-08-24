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

export default function AFaire() {
  const { A, O, erreursV4 } = useDonnees();
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
