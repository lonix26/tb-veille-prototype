import React, { useState } from "react";
import { useDonnees, nb, dateCH, LienSource } from "../api.jsx";

// =====================================================================
// ÉCRAN « ACTIONS » — 24.08.2026.
//
// POURQUOI CET ÉCRAN EXISTE. Le constat de l'étudiant, le 23.08 au soir :
// « c'est cool d'avoir la théorie mais la pratique ne donne rien ». Il était
// juste. Les quatre écrans précédents décrivaient l'état des DONNÉES ; aucun
// ne disait quoi faire. L'écran « Opportunités » listait onze avis sans dire
// s'ils étaient encore ouverts — dont plusieurs déjà attribués.
//
// CE QUI CHANGE : quatre champs collectés en plus (type d'avis, date limite,
// courriel de l'acheteur, valeur estimée) et une question posée autrement au
// modèle — non plus « de quoi parle cet avis » mais « puis-je le faire, et
// que dois-je faire maintenant ». Le reste suit.
//
// LE TAMIS EST AFFICHÉ, pas caché : de 833 avis collectés à 3 à lire. Un
// dirigeant doit pouvoir vérifier ce qu'on a écarté pour lui, et pourquoi.
// =====================================================================

const URGENCE = { urgent: "e-rouge", proche: "e-ambre", confortable: "e-gris" };

function Fiche({ a }) {
  const [ouvert, setOuvert] = useState(false);
  return (
    <div className={"carte action a-" + a.adressable}>
      <div className="a-tete">
        <div className="a-gauche">
          <span className={"etq " + (a.adressable === 2 ? "e-vert" : "e-ambre")}>
            {a.adressable === 2 ? "cœur de métier" : "périphérique"}
          </span>
          <span className={"etq " + URGENCE[a.urgence]}>
            {a.jours_restants} jour{a.jours_restants > 1 ? "s" : ""} restant{a.jours_restants > 1 ? "s" : ""}
          </span>
          {a.sector_code
            ? <span className="etq e-gris">{a.sector_code}</span>
            : <span className="etq e-bleu" title="marché hors des quatre secteurs de la grille du ch. 8 — ajouté le 24.08.2026 parce que la lecture décisionnelle n'a trouvé d'appels adressables que là">
                hors grille · ferroviaire
              </span>}
          {a.acheteur_recurrent && (
            <span className="etq e-violet" title="cet acheteur a publié plusieurs avis sur la période">
              acheteur récurrent · {a.acheteur_avis_publies} avis
            </span>
          )}
        </div>
        <div className="a-echeance">
          <strong>{dateCH(a.date_limite)}</strong>
          <small>date limite de dépôt</small>
        </div>
      </div>

      <div className="a-titre">{a.titre}</div>

      {a.action_proposee && (
        <div className="a-action">
          <span className="a-action-l">À faire</span>
          {a.action_proposee}
        </div>
      )}

      <div className="a-grille">
        <div><span>Acheteur</span>{a.acheteur || "—"}</div>
        <div><span>Où</span>{[a.acheteur_ville, a.acheteur_pays].filter(Boolean).join(", ") || "—"}</div>
        <div><span>Pièce concernée</span>{a.piece_concernee || "—"}</div>
        <div><span>Valeur estimée</span>
          {a.valeur_estimee ? `${nb(a.valeur_estimee, 0)} ${a.devise || ""}` : "non publiée"}</div>
      </div>

      <div className="a-pied">
        {a.acheteur_courriel && (
          <a className="src" href={"mailto:" + a.acheteur_courriel}>{a.acheteur_courriel}</a>)}
        {a.acheteur_site && <LienSource href={a.acheteur_site}>site de l'acheteur</LienSource>}
        <LienSource href={a.url}>avis officiel TED</LienSource>
        <button className="filtre" onClick={() => setOuvert(!ouvert)}>
          {ouvert ? "masquer" : "pourquoi ?"}
        </button>
      </div>

      {ouvert && (
        <div className="a-justif">
          « {a.justification} »
          <div className="prov">
            Lecture proposée par {a.modele} — elle ordonne la lecture, elle ne décide pas.
            CPV {(a.cpv || []).join(", ")} · publié le {dateCH(a.date_publication)} ·
            avis n° {a.publication_number}
          </div>
        </div>
      )}
    </div>
  );
}

export default function Actions() {
  const { A, erreursV4 } = useDonnees();
  const [voirEcartes, setVoirEcartes] = useState(false);

  if (!A) return (
    <div className="page"><div className="topbar"><h1>Actions</h1></div>
      <div className="vide"><strong>Le point de lecture « actions » ne répond pas.</strong><br />
        <span style={{ fontSize: 12 }}>{erreursV4?.["/actions"]}</span></div></div>
  );

  const t = A.tamis || {};
  const toutes = A.actions || [];
  const retenues = toutes.filter(a => a.adressable >= 1);
  // OÙ sont les appels adressables, par marché. Ce décompte n'est pas décoratif :
  // c'est lui qui a fait ajouter le ferroviaire le 24.08.2026.
  const parMarche = {};
  retenues.forEach(a => {
    const cle = a.sector_code || "ferroviaire (hors grille)";
    parMarche[cle] = (parMarche[cle] || 0) + 1;
  });
  const marches = Object.entries(parMarche).sort((x, y) => y[1] - x[1]);
  const horsGrille = parMarche["ferroviaire (hors grille)"] || 0;
  const ecartees = toutes.filter(a => a.adressable === 0);

  return (
    <div className="page">
      <div className="topbar">
        <h1>Actions</h1>
        <div className="meta">{retenues.length} appel{retenues.length > 1 ? "s" : ""} à examiner
          · {toutes.length} ouverts au total</div>
      </div>

      {/* Le tamis, montré et non subi : le dirigeant voit ce qu'on a écarté
          pour lui, et de combien. C'est ce qui rend le tri contestable. */}
      <div className="tamis">
        <div className="t-etape"><b>{nb(t.avis_collectes, 0)}</b><span>avis collectés<small>60 derniers jours</small></span></div>
        <div className="t-fleche">→</div>
        <div className="t-etape"><b>{nb(t.appels_ouverts, 0)}</b><span>appels d'offres<small>{nb(t.attributions, 0)} attributions écartées</small></span></div>
        <div className="t-fleche">→</div>
        <div className="t-etape"><b>{nb(t.non_expires, 0)}</b><span>encore ouverts<small>échéance non passée</small></span></div>
        <div className="t-fleche">→</div>
        <div className="t-etape fort"><b>{nb(t.adressables, 0)}</b><span>à examiner<small>dont {nb(t.coeur_de_metier, 0)} au cœur du métier</small></span></div>
      </div>

      {/* VALEUR EN JEU — par devise, jamais convertie. Les avis européens sont
          libellés en huit monnaies ; les additionner comme des euros donnerait
          un total plausible et faux. Le nombre d'appels sans valeur publiée est
          affiché avec, sans quoi le total passerait pour exhaustif. */}
      {(A.valeur_en_jeu || []).length > 0 && (
        <div className="enjeu">
          <div className="en-titre">Valeur en jeu sur les appels adressables</div>
          <div className="en-lignes">
            {A.valeur_en_jeu.map(v => (
              <div key={v.devise} className="en-ligne">
                <b>{nb(v.montant, 0)}</b> <span className="en-dev">{v.devise}</span>
                <span className="en-n">sur {v.appels} appel{v.appels > 1 ? "s" : ""}</span>
              </div>
            ))}
          </div>
          <p className="en-note">
            Montants <strong>non convertis</strong> : les avis européens sont libellés en huit
            monnaies et le dispositif ne dispose d'aucune table de change pour la plupart d'entre
            elles. Les additionner donnerait un total faux d'apparence juste.
            {A.sans_valeur_publiee > 0 && <> {A.sans_valeur_publiee} des {retenues.length} appels
              adressables ne publient <strong>aucune valeur estimée</strong> — l'enjeu réel est
              donc supérieur à ce qui est affiché ici.</>}
          </p>
        </div>
      )}

      {marches.length > 0 && (
        <div className="repartition">
          <div className="r-titre">Où sont les appels adressables</div>
          <div className="r-barres">
            {marches.map(([m, n]) => (
              <div key={m} className="r-ligne">
                <span className={"etq " + (m.startsWith("ferroviaire") ? "e-bleu" : "e-gris")}>{m}</span>
                <div className="r-piste">
                  <div className="r-jauge" style={{ width: (100 * n / retenues.length) + "%" }} />
                </div>
                <b>{n}</b>
              </div>
            ))}
          </div>
          {horsGrille > 0 && (
            <p className="r-constat">
              <strong>{horsGrille} des {retenues.length} appels adressables relèvent du ferroviaire</strong>,
              qui n'est pas l'un des quatre marchés surveillés par la grille du chapitre 8. Le dispositif
              n'en surveillait aucun avis avant le 24.08.2026 : le flux <code>ted_ferroviaire</code>
              (CPV 34630000) a été ajouté <em>après</em> que la lecture décisionnelle des appels
              automobile, médical et aérospatial eut conclu que presque rien n'y était usinable.
              Étendre la grille à un cinquième secteur est une décision de l'étudiant, non une
              conséquence technique : elle n'a pas été prise, et ces appels s'affichent donc
              hors grille.
            </p>
          )}
        </div>
      )}

      {retenues.length === 0 ? (
        <div className="vide">
          <strong>Aucun appel adressable cette semaine.</strong><br />
          Sur {toutes.length} appels encore ouverts, aucun ne relève de l'usinage de précision.
          C'est un résultat, pas une panne : la plupart des marchés publics de ces secteurs
          portent sur des appareils complets, des pièces d'origine constructeur ou des services.
        </div>
      ) : (
        <div className="liste-actions">
          {retenues.map(a => <Fiche key={a.publication_number} a={a} />)}
        </div>
      )}

      <div className="a-ecartes">
        <button className="filtre" onClick={() => setVoirEcartes(!voirEcartes)}>
          {voirEcartes ? "masquer" : "voir"} les {ecartees.length} appels écartés
        </button>
        <span className="prov">
          Écarter n'est pas cacher : chaque motif est consultable, et l'avis officiel reste à un clic.
        </span>
        {voirEcartes && (
          <table className="tableau" style={{ marginTop: 12 }}>
            <thead><tr><th>Limite</th><th>Acheteur</th><th>Avis</th><th>Motif de l'écartement</th><th></th></tr></thead>
            <tbody>
              {ecartees.map(a => (
                <tr key={a.publication_number}>
                  <td className="nowrap">{dateCH(a.date_limite)}</td>
                  <td>{a.acheteur}</td>
                  <td className="td-titre">{a.titre}</td>
                  <td className="td-note">{a.justification}</td>
                  <td><LienSource href={a.url}>avis</LienSource></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {(A.acheteurs || []).length > 0 && (
        <>
          <h2 className="s-titre">Acheteurs à démarcher</h2>
          <p className="lecture">
            Ceux qui ont publié plusieurs avis sur la période et ont au moins un appel ouvert.
            Un acheteur qui revient n'est pas un événement, c'est un compte.
          </p>
          <table className="tableau">
            <thead><tr><th>Acheteur</th><th>Pays</th><th>Secteur</th><th>Avis</th><th>Ouverts</th><th>Contact</th></tr></thead>
            <tbody>
              {A.acheteurs.slice(0, 12).map((b, i) => (
                <tr key={i}>
                  <td className="td-titre">{b.acheteur}</td>
                  <td className="nowrap">{b.acheteur_pays}</td>
                  <td><span className={"etq " + (b.sector_code ? "e-gris" : "e-bleu")}>{b.sector_code || "hors grille"}</span></td>
                  <td>{b.avis_publies}</td>
                  <td><strong>{b.dont_encore_ouverts}</strong></td>
                  <td>{b.acheteur_courriel &&
                    <a className="src" href={"mailto:" + b.acheteur_courriel}>écrire</a>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      <div className="mention-permanente">
        Source : TED, avis de marchés publics de l'Union européenne, {A.fenetre_jours} derniers jours.
        Les avis <strong>déjà attribués</strong> et ceux dont <strong>l'échéance est passée</strong> sont
        exclus. L'adressabilité est une <strong>lecture proposée par un modèle</strong>, jamais une
        décision : chaque ligne porte son motif et mène à l'avis officiel.
      </div>
    </div>
  );
}
