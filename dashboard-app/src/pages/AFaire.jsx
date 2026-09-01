import React, { useState } from "react";
import { useDonnees, nb, dateCH, nomZone } from "../api.jsx";
import { phraseEcheance, tonEcheance, enLettres } from "../phrases.jsx";

// =====================================================================
// À FAIRE — la question : sur quoi je me positionne, et quand ?
//
// Quatre blocs, dans l'ordre du geste :
//   1. les appels d'offres à portée, classés par échéance ;
//   2. le tamis, qui explique pourquoi ils sont si peu ;
//   3. les dix items de veille de la semaine ;
//   4. qui achète, tous marchés confondus.
// =====================================================================

function Entonnoir({ etapes }) {
  const max = Math.max(...etapes.map(e => e.valeur), 1);
  return (
    <div className="entonnoir">
      {etapes.map((e, i) => (
        <div className="ent-ligne" key={i}>
          <div className="ent-lib">{e.libelle}</div>
          <div className="ent-piste">
            <div className={"ent-barre" + (i === etapes.length - 1 ? " ent-final" : "")}
                 style={{ width: Math.max(1.5, (e.valeur / max) * 100) + "%" }} />
          </div>
          <div className="ent-val">{nb(e.valeur)}</div>
        </div>
      ))}
    </div>
  );
}

function Fiche({ a }) {
  const [ouvert, setOuvert] = useState(false);
  const ton = tonEcheance(a.jours_restants);
  return (
    <article className={"fiche t-" + ton}>
      <div className="fiche-bandeau">
        <span className="fiche-delai">{phraseEcheance(a.jours_restants)}</span>
        {a.adressable === 2 && <span className="etq e-violet">cœur de métier</span>}
        {a.acheteur_recurrent && <span className="etq e-gris">acheteur habitué</span>}
        <span className="fiche-ech">clôture le {dateCH(a.date_limite)}</span>
      </div>
      <h3 className="fiche-titre">{a.piece_concernee || a.titre}</h3>
      <p className="fiche-qui">
        <strong>{a.acheteur}</strong>
        {a.acheteur_ville ? `, ${a.acheteur_ville}` : ""}
        {a.acheteur_pays ? ` (${nomZone(a.acheteur_pays)})` : ""}
        {a.valeur_estimee ? ` · valeur annoncée ${nb(a.valeur_estimee)} ${a.devise || ""}` : " · valeur non publiée"}
      </p>
      {a.action_proposee && (
        <p className="fiche-geste"><span className="geste-puce">Geste proposé</span>{a.action_proposee}</p>
      )}
      <div className="fiche-pied">
        <a className="bouton-primaire" href={a.url} target="_blank" rel="noreferrer">Ouvrir l'avis ↗</a>
        {a.acheteur_courriel && (
          <a className="bouton-second" href={"mailto:" + a.acheteur_courriel}>Écrire à l'acheteur</a>
        )}
        <button className="bouton-lien" onClick={() => setOuvert(o => !o)}>
          {ouvert ? "Masquer le raisonnement" : "Pourquoi cet avis ?"}
        </button>
      </div>
      {ouvert && (
        <div className="fiche-raison">
          <p>{a.justification || "Aucune justification enregistrée."}</p>
          <p className="fiche-modele">
            Lecture d'adressabilité par <strong>{a.modele || "un modèle"}</strong> : elle ordonne
            votre lecture, elle ne décide rien. CPV {a.cpv || "non publié"} · publié le {dateCH(a.date_publication)}.
          </p>
        </div>
      )}
    </article>
  );
}

export default function AFaire() {
  const { A, S, erreursV4 } = useDonnees();
  const [tout, setTout] = useState(false);

  if (!A) return (
    <div className="page"><div className="vide">
      <strong>La lecture « actions » ne répond pas.</strong><br />
      <span style={{ fontSize: 12 }}>{erreursV4?.["/actions"]}</span>
    </div></div>
  );

  const t = A.tamis || {};
  const actions = A.actions || [];
  const adressables = actions.filter(a => a.adressable >= 1)
    .sort((x, y) => (x.jours_restants ?? 9999) - (y.jours_restants ?? 9999));
  const autres = actions.filter(a => !(a.adressable >= 1));
  const file = S?.file_prioritaire || [];
  const enAttente = Number(S?.items_en_attente_examen) || 0;
  const acheteurs = [...(A.acheteurs || [])].sort((x, y) => (y.avis_publies || 0) - (x.avis_publies || 0));
  const note = i => (i.anteriorite || 0) + (i.portee || 0) + (i.pertinence_signal || 0);
  const majuscule = s => s.charAt(0).toUpperCase() + s.slice(1);

  return (
    <div className="page">
      <header className="tete">
        <span className="tete-date">Marchés publics européens · fenêtre de {A.fenetre_jours || 60} jours</span>
      </header>
      <h1 className="verdict">
        {adressables.length === 0
          ? "Rien à votre portée dans la fenêtre suivie."
          : `${majuscule(enLettres(adressables.length))} appels d'offres à votre portée.`}
      </h1>

      {adressables.map(a => <Fiche key={a.publication_number} a={a} />)}

      <h2 className="section">D'où viennent-ils</h2>
      <div className="carte">
        <p className="bloc-intro">
          Le dispositif n'a pas sélectionné {enLettres(adressables.length)} avis : il en a éliminé,
          étage par étage, {nb((t.avis_collectes || 0) - (t.adressables || 0))}. Le petit nombre
          est le résultat du tri, pas une faiblesse de la collecte.
        </p>
        <Entonnoir etapes={[
          { libelle: "avis collectés", valeur: t.avis_collectes || 0 },
          { libelle: "appels d'offres (hors attributions)", valeur: t.appels_ouverts || 0 },
          { libelle: "encore ouverts", valeur: t.non_expires || 0 },
          { libelle: "à votre portée", valeur: t.adressables || 0 },
          { libelle: "cœur de métier", valeur: t.coeur_de_metier || 0 }
        ]} />
        <p className="bloc-note">
          Le passage à « à votre portée » est une lecture de <strong>{t.modele_lecture || "modèle"}</strong>,
          fondée sur le profil métier déclaré. Chaque fiche porte son raisonnement et le lien vers
          l'avis officiel. Un tri assisté doit pouvoir être contredit.
        </p>
      </div>

      {file.length > 0 && (
        <>
          <h2 className="section">
            Vos dix items de veille de la semaine · {nb(enAttente)} en file
          </h2>
          <div className="file-liste">
            {file.map(i => (
              <div className="file-item" key={i.item_id}>
                <span className="file-note" title="antériorité + portée + pertinence">{note(i)}</span>
                <div className="file-corps">
                  <a href={i.url} target="_blank" rel="noreferrer">{i.titre}</a>
                  {i.resume && <p className="file-resume">{i.resume}</p>}
                  <p className="file-meta">
                    {i.flux}{i.sector_code ? ` · ${i.sector_code}` : ""}
                    {i.date_publication ? ` · ${dateCH(i.date_publication)}` : ""}
                  </p>
                </div>
              </div>
            ))}
          </div>
          <p className="note" style={{ marginTop: 9, maxWidth: "76ch" }}>
            Les dix mieux notés par le triage. Les examiner chaque semaine suffit à tenir le
            dispositif : c'est un cadrage, pas un rattrapage. La file ne se videra pas, et ce
            n'est pas son objet. La promotion en signal reste un acte nominatif.
          </p>
        </>
      )}

      {acheteurs.length > 0 && (
        <>
          <h2 className="section">Qui achète, tous marchés confondus</h2>
          <div className="carte" style={{ padding: 0, overflow: "hidden" }}>
            <table>
              <thead>
                <tr><th>Organisation</th><th>Marché</th>
                    <th style={{ textAlign: "right" }}>Avis</th>
                    <th style={{ textAlign: "right" }}>dont ouverts</th>
                    <th>Actif depuis</th><th>Contact</th></tr>
              </thead>
              <tbody>
                {(tout ? acheteurs : acheteurs.slice(0, 10)).map((a, i) => (
                  <tr key={i}>
                    <td><strong>{a.acheteur}</strong>
                        <div className="cell-note">{nomZone(a.acheteur_pays)}</div></td>
                    <td>{a.sector_code
                          ? <span className="etq e-gris">{a.sector_code}</span>
                          : <span className="etq e-attn">hors grille</span>}</td>
                    <td style={{ textAlign: "right", fontWeight: 650 }}>{a.avis_publies}</td>
                    <td style={{ textAlign: "right" }}>
                      {a.dont_encore_ouverts
                        ? <strong className="hausse">{a.dont_encore_ouverts}</strong>
                        : <span className="neutre">n.d.</span>}
                    </td>
                    <td className="cell-note">{dateCH(a.premier_avis)}</td>
                    <td>{a.acheteur_courriel
                          ? <a href={"mailto:" + a.acheteur_courriel}>écrire</a>
                          : <span className="neutre">n.d.</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {acheteurs.length > 10 && (
            <button className="bouton-second" style={{ marginTop: 10 }} onClick={() => setTout(x => !x)}>
              {tout ? "Réduire" : `Montrer les ${acheteurs.length - 10} autres`}
            </button>
          )}
          <p className="note" style={{ marginTop: 9, maxWidth: "76ch" }}>
            Un acheteur qui publie régulièrement sur une même famille de pièces renseigne sur la
            structure d'un marché mieux qu'une série macroéconomique. Le nombre d'avis mesure son
            activité de publication, pas la taille de son marché. La demande privée, qui est
            l'essentiel du carnet d'un sous-traitant, n'apparaît pas ici.
          </p>
        </>
      )}

      {autres.length > 0 && (
        <p className="note" style={{ marginTop: 18 }}>
          {autres.length} autres avis ouverts ont été jugés hors du savoir-faire par la lecture.
        </p>
      )}
    </div>
  );
}
