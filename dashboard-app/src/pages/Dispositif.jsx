import React, { useState } from "react";
import { useDonnees, nb, pct, dateCH, LienSource } from "../api.jsx";
import { phraseFraicheur, enLettres } from "../phrases.jsx";

// =====================================================================
// LE DISPOSITIF — ce qui était réparti entre « Référentiel » et
// « Exécutions », deux entrées de menu qui ne voulaient rien dire pour un
// dirigeant. Une seule page, quatre questions de confiance :
//
//   Sur quoi je m'appuie ?     → la grille et ses sources
//   Est-ce que ça tourne ?     → les dernières exécutions
//   La source s'est-elle corrigée ? → les révisions
//   Qu'est-ce qui n'est pas encore là ? → les manques, nommés
//
// C'est l'écran de la preuve. Il n'est pas fait pour être ouvert tous les
// jours — il est fait pour que la question « d'où sort ce chiffre ? »
// trouve toujours une réponse à un clic.
// =====================================================================

function Onglets({ courant, poser, items }) {
  return (
    <div className="onglets">
      {items.map(([cle, lib]) => (
        <button key={cle} className={"onglet" + (courant === cle ? " actif" : "")}
                onClick={() => poser(cle)}>{lib}</button>
      ))}
    </div>
  );
}

export default function Dispositif() {
  const { D, S } = useDonnees();
  const [vue, setVue] = useState("grille");
  const [filtre, setFiltre] = useState("");

  const ref = D?.referentiel || [];
  const bilan = D?.bilan_referentiel || [];
  const total = bilan.find(b => !b.sector_code) || {};
  const runs = D?.sante_runs || [];
  const rev = D?.revisions || [];
  const dernier = runs[0] || {};

  const f = filtre.trim().toLowerCase();
  const lignes = ref.filter(i => !f ||
    [i.indicator_id, i.sector_label, i.label, i.questions, i.source_organisation]
      .join(" ").toLowerCase().includes(f));

  const nonInstrumentes = ref.filter(i => i.status === "certifie" && !Number(i.observations));
  const aConfirmer = ref.filter(i => i.status === "a_confirmer");

  return (
    <div className="page">
      <header className="ouverture">
        <div>
          <p className="ouv-date">La preuve derrière les chiffres</p>
          <h1 className="ouv-titre">Le dispositif</h1>
        </div>
        <div className="ouv-etat">
          <span className="puce-fraicheur">{phraseFraicheur(dernier.executed_at)}</span>
        </div>
      </header>

      <p className="brief">
        {total.en_grille ?? total.total} indicateurs suivis, dont {total.certifies} certifiés
        {total.ecartes ? ` (${enLettres(total.ecartes)} écartés de la grille et conservés au référentiel)` : ""}.
        Toutes les sources sont ouvertes et citées. Aucun chiffre de ce tableau de bord n'est saisi
        à la main : chacun vient d'une collecte datée, et cette page dit laquelle.
      </p>

      <Onglets courant={vue} poser={setVue} items={[
        ["grille", "La grille"],
        ["executions", "Les exécutions"],
        ["revisions", `Révisions (${rev.length})`],
        ["manques", `Ce qui manque (${nonInstrumentes.length + aConfirmer.length})`]
      ]} />

      {vue === "grille" && (
        <>
          <div className="carte">
            <h2 className="bloc-titre">Décompte — il vient de la base, il fait référence</h2>
            <p className="bloc-intro">
              Ce tableau est produit par requête à chaque affichage. Si un chiffre du rapport
              diffère de celui-ci, c'est le rapport qui a tort.
            </p>
            <table>
              <thead>
                <tr><th>Marché</th><th>Dans la grille</th><th>Certifiés</th><th>dont officiels</th>
                    <th>dont composites</th><th>À confirmer</th><th>Écartés</th></tr>
              </thead>
              <tbody>
                {bilan.map((b, i) => (
                  <tr key={i} className={b.sector_code ? "" : "ligne-total"}>
                    <td>{b.sector_code || <strong>Ensemble</strong>}</td>
                    <td>{b.en_grille ?? b.total}</td>
                    <td>{b.certifies}</td><td>{b.certifies_hard}</td>
                    <td>{b.certifies_composite}</td><td>{b.a_confirmer}</td>
                    <td>{b.ecartes ?? 0}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="carte" style={{ marginTop: 14 }}>
            <div className="carte-tete">
              <h2 className="bloc-titre">
                {lignes.length} indicateur{lignes.length > 1 ? "s" : ""}
                {f ? ` correspondant à « ${filtre} »` : ""}
              </h2>
              <input className="filtre" placeholder="Chercher un indicateur, une source, une question…"
                     value={filtre} onChange={e => setFiltre(e.target.value)} />
            </div>
            <table className="t-compacte">
              <thead>
                <tr><th>Code</th><th>Marché</th><th>Ce qu'il mesure</th><th>Source</th>
                    <th>Nature</th><th>Ce qui est en base</th></tr>
              </thead>
              <tbody>
                {lignes.map(i => (
                  <tr key={i.indicator_id}>
                    <td><strong>{i.indicator_id}</strong></td>
                    <td>{i.sector_label}</td>
                    <td>
                      {i.label}
                      {i.description_metier && <div className="cell-note">{i.description_metier}</div>}
                    </td>
                    <td>
                      {i.source_organisation}
                      {i.source_url && <div><LienSource href={i.source_url}>source</LienSource></div>}
                    </td>
                    <td>{i.category === "hard" ? "officiel" : "composite"}</td>
                    <td>
                      {Number(i.observations) > 0
                        ? <>{nb(i.observations)} observations<div className="cell-note">{i.p_min} → {i.p_max}</div></>
                        : <span className="etq e-gris">rien collecté</span>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}

      {vue === "executions" && (
        <div className="carte">
          <h2 className="bloc-titre">Les dernières collectes</h2>
          <p className="bloc-intro">
            Chaque collecte <strong>ajoute</strong> ses observations sans écraser les précédentes.
            Une valeur corrigée par sa source ne remplace donc pas l'ancienne : les deux coexistent,
            datées, et c'est l'écart entre exécutions qui fait la tendance.
          </p>
          <table>
            <thead>
              <tr><th>N°</th><th>Exécutée le</th><th>Résultat</th><th>Valeurs écrites</th>
                  <th>Indicateurs couverts</th></tr>
            </thead>
            <tbody>
              {runs.map(s => (
                <tr key={s.run_id}>
                  <td>{s.run_id}</td>
                  <td>{new Date(s.executed_at).toLocaleString("fr-CH")}</td>
                  <td>
                    <span className={"etq " + (s.status === "ok" ? "e-vert" : "e-rouge")}>
                      {s.status === "ok" ? "réussie" : s.status}
                    </span>
                  </td>
                  <td>{nb(s.valeurs_ecrites)}</td>
                  <td>{s.indicateurs_couverts} sur {s.indicateurs_certifies_attendus}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {vue === "revisions" && (
        <div className="carte">
          <h2 className="bloc-titre">Quand la source se corrige elle-même</h2>
          {rev.length === 0 ? (
            <p className="bloc-intro">
              Aucune révision repérée. Le mécanisme tourne ; il n'a simplement encore rien attrapé.
              Ce n'est pas un résultat vide : c'est la démonstration qu'une valeur déjà publiée
              n'a pas bougé entre deux collectes.
            </p>
          ) : (
            <>
              <p className="bloc-intro">
                {rev.length} valeurs ont été <strong>corrigées par leur source</strong> entre deux
                collectes. Sans registre en ajout seul, ces corrections seraient invisibles :
                l'ancienne valeur aurait été écrasée et personne ne saurait qu'elle a existé.
              </p>
              <table className="t-compacte">
                <thead><tr><th>Indicateur</th><th>Période</th><th>Zone</th><th>Collecte</th>
                           <th>Avant</th><th>Après</th><th>Écart</th></tr></thead>
                <tbody>
                  {rev.slice(0, 60).map((e, i) => (
                    <tr key={i}>
                      <td><strong>{e.indicator_id}</strong></td><td>{e.period}</td><td>{e.geo}</td>
                      <td>{e.run_precedent} → {e.run_id}</td>
                      <td>{nb(e.value_run_precedent)}</td><td>{nb(e.value)}</td>
                      <td className={Math.abs(e.ecart_pct) > 1 ? "baisse" : "neutre"}>{pct(e.ecart_pct)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {rev.length > 60 && <p className="note">…et {rev.length - 60} autres.</p>}
            </>
          )}
        </div>
      )}

      {vue === "manques" && (
        <div className="carte">
          <h2 className="bloc-titre">Ce qui n'est pas encore là</h2>
          <p className="bloc-intro">
            Un tableau de bord qui ne dit pas ce qui lui manque laisse croire qu'il est complet.
            Voici la liste, produite par requête et non rédigée.
          </p>

          {nonInstrumentes.length > 0 && (
            <>
              <h3 className="sous-titre">
                Certifiés mais non collectés — {enLettres(nonInstrumentes.length)}
              </h3>
              <p className="cell-note" style={{ marginBottom: 8 }}>
                La source est qualifiée : elle existe, elle a été vue, elle répond. Ce qui manque
                est la liaison de collecte, ou un accès qui n'a pas pu être obtenu.
              </p>
              <ul className="liste-manques">
                {nonInstrumentes.map(i => (
                  <li key={i.indicator_id}>
                    <strong>{i.indicator_id}</strong> — {i.label}
                    <span className="cell-note"> · {i.sector_label} · {i.source_organisation}</span>
                  </li>
                ))}
              </ul>
            </>
          )}

          {aConfirmer.length > 0 && (
            <>
              <h3 className="sous-titre">
                À confirmer — {enLettres(aConfirmer.length)}
              </h3>
              <p className="cell-note" style={{ marginBottom: 8 }}>
                Identifiés comme utiles, mais dont la source n'a pas été qualifiée. Ils ne
                comptent dans aucun score.
              </p>
              <ul className="liste-manques">
                {aConfirmer.map(i => (
                  <li key={i.indicator_id}>
                    <strong>{i.indicator_id}</strong> — {i.label}
                    <span className="cell-note"> · {i.sector_label}</span>
                  </li>
                ))}
              </ul>
            </>
          )}

          <h3 className="sous-titre">Ce que la méthode ne peut pas faire</h3>
          <ul className="liste-manques">
            <li>
              <strong>Comparer deux marchés entre eux.</strong> Chaque score compare une branche à
              son propre passé. Les échelles ne sont pas communes.
            </li>
            <li>
              <strong>Prédire.</strong> Le dispositif décrit une position et une direction ; il ne
              projette rien, et aucun chiffre affiché n'est une prévision.
            </li>
            <li>
              <strong>Se passer de vous.</strong> Les lectures produites par modèle sortent au
              statut « à valider » et n'atteignent ce tableau qu'après relecture humaine.
            </li>
          </ul>
        </div>
      )}
    </div>
  );
}
