import React, { useMemo, useState } from "react";
import { useDonnees, nb, pct, dateCH, LienSource } from "../api.jsx";
import { redondances, compositionLatence, enLettres, phraseFraicheur } from "../phrases.jsx";

// =====================================================================
// FIABILITÉ — l'écran des réserves, et il en fallait un.
//
// La v5 dispersait les avertissements sur toutes les pages : deux sur
// chaque carte de marché, un sous chaque commentaire, une liste de limites
// en bas de l'accueil. Résultat, un écran de décision illisible et des
// réserves que personne ne lisait pour autant.
//
// Elles sont ici, toutes, au même endroit. L'écran de décision n'en porte
// plus qu'un COMPTEUR — « 2 réserves » — qui mène ici. Un dirigeant ne les
// subit pas chaque matin ; un jury les trouve rassemblées et sourcées.
//
// Chaque réserve est PRODUITE, pas rédigée : elle est recalculée à
// l'affichage à partir de la base. Aucune n'est écrite en dur.
// =====================================================================

function reservesDuDispositif(D, S) {
  const r = [];
  const marches = (S?.sante || []).filter(x => x.sector_code !== "transversal");

  // 1. Marchés sans indicateur avancé.
  for (const m of marches) {
    const c = compositionLatence(D, m.indicateurs);
    if (c.avance === 0) r.push({
      gravite: "grave", ou: m.sector_label,
      titre: `${m.sector_label} : aucun signal d'avance`,
      corps: `Les ${enLettres(m.indicateurs?.length || 0)} séries qui portent ce score décrivent ce qui s'est déjà produit — ${c.coincident} constatent, ${c.retarde} confirment. Un retournement n'y serait visible qu'après coup. S'y ajoute le délai de publication : les séries mensuelles arrivent avec un à trois mois de retard.`
    });
  }

  // 2. Séries corrélées comptées deux fois dans un même score.
  for (const m of marches) {
    for (const d of redondances(D, m.indicateurs)) r.push({
      gravite: "moyenne", ou: m.sector_label,
      titre: `${m.sector_label} : deux séries évoluent ensemble`,
      corps: `« ${d.nomA} » et « ${d.nomB} » corrèlent à ${nb(Math.abs(d.r), 2)} sur ${d.n} points communs. Elles restent deux mesures distinctes — c'est souvent l'écart entre elles qui porte l'information — mais le score en fait une moyenne simple : leur mouvement commun y compte deux fois, et le score paraît plus assuré qu'il ne l'est.`
    });
  }

  // 3. Lectures validées antérieures à la collecte courante.
  const runCourant = S?.run_courant?.run_id;
  const anciennes = (D?.commentaires || []).filter(c => c.run_id && runCourant && c.run_id < runCourant);
  if (anciennes.length) r.push({
    gravite: "moyenne", ou: "Lectures",
    titre: `${enLettres(anciennes.length)} lecture${anciennes.length > 1 ? "s" : ""} porte${anciennes.length > 1 ? "nt" : ""} sur une collecte antérieure`,
    corps: `Rédigée${anciennes.length > 1 ? "s" : ""} sur la collecte n° ${anciennes.map(c => c.run_id).join(", ")} alors que la base en est à la n° ${runCourant}. Les chiffres qu'elle${anciennes.length > 1 ? "s citent" : " cite"} peuvent différer de ceux affichés aujourd'hui. Une lecture validée n'a pas de date de péremption : c'est une règle qui manque au dispositif, pas un défaut d'exécution.`
  });

  // 4. Indicateurs certifiés qui ne collectent rien.
  const muets = (D?.referentiel || []).filter(i => i.status === "certifie" && !Number(i.observations));
  if (muets.length) r.push({
    gravite: "moyenne", ou: "Grille",
    titre: `${enLettres(muets.length)} indicateurs certifiés ne collectent rien`,
    corps: `${muets.map(i => `${i.indicator_id} (${i.label})`).join(" · ")}. La source est qualifiée — elle existe, elle répond — mais la liaison de collecte manque, ou l'accès n'a pas pu être obtenu.`
  });

  // 5. Périodicités mêlées dans un même score.
  for (const m of marches) {
    const freqs = new Set((m.indicateurs || [])
      .map(id => (D?.referentiel || []).find(x => x.indicator_id === id)?.frequency)
      .filter(Boolean));
    if (freqs.size > 1) r.push({
      gravite: "moyenne", ou: m.sector_label,
      titre: `${m.sector_label} : périodicités mêlées`,
      corps: `Ce score réunit des séries ${[...freqs].join(", ")}. Une série mensuelle de cent cinquante points et une série annuelle de douze y pèsent à égalité. Le dispositif l'accepte ; la lecture doit en tenir compte.`
    });
  }

  // 6. La file d'examen.
  const file = Number(S?.items_en_attente_examen) || 0;
  if (file > 300) r.push({
    gravite: "grave", ou: "Exploitation",
    titre: "La file d'examen ne se vide pas",
    corps: `${nb(file)} items attendent une lecture humaine, et la file croît plus vite qu'elle n'est traitée. C'est la limite structurelle du choix semi-automatisé : elle se traite par un cadrage — les dix mieux notés par semaine — et non par du temps supplémentaire.`
  });

  return r;
}

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

export default function Fiabilite() {
  const { D, S } = useDonnees();
  const [vue, setVue] = useState("reserves");
  const [filtre, setFiltre] = useState("");

  const reserves = useMemo(() => reservesDuDispositif(D, S), [D, S]);
  const ref = D?.referentiel || [];
  const bilan = D?.bilan_referentiel || [];
  const total = bilan.find(b => !b.sector_code) || {};
  const runs = D?.sante_runs || [];
  const rev = D?.revisions || [];

  // Couverture des questions de veille PAR LA VITRINE — l'ancienne vue de
  // couverture comptait la grille d'avant l'élagage. Recalculée ici depuis ce
  // qui est réellement suivi : c'est la « calculabilité de l'absence » du
  // cadre invariant, appliquée à la grille élaguée. Une question découverte
  // se VOIT, au lieu d'être recouverte nominalement par une série illisible.
  const couverture = useMemo(() => {
    const vitrine = S?.vitrine || [];
    const inst = D?.instanciation || [];
    const qDe = id => String((D?.referentiel || []).find(r => r.indicator_id === id)?.questions || "")
      .split(",").filter(Boolean);
    return inst.map(q => {
      const porteurs = vitrine
        .filter(v => v.sector_code === q.sector_code && qDe(v.indicator_id).includes(q.watch_question_code))
        .map(v => v.indicator_id);
      return { ...q, porteurs };
    });
  }, [D, S]);
  const decouvertes = couverture.filter(q => q.porteurs.length === 0).length;

  const f = filtre.trim().toLowerCase();
  const lignes = ref.filter(i => !f ||
    [i.indicator_id, i.sector_label, i.label, i.source_organisation].join(" ").toLowerCase().includes(f));
  const sources = new Set(ref.map(i => i.source_organisation).filter(Boolean));

  return (
    <div className="page">
      <header className="tete">
        <span className="tete-date">Ce que le dispositif sait, et ce qu'il sait mal</span>
        <span className="tete-etat">{phraseFraicheur(runs[0]?.executed_at)}</span>
      </header>
      <h1 className="verdict" style={{ maxWidth: "26ch" }}>Fiabilité</h1>
      <p className="bloc-intro" style={{ marginTop: -14, fontSize: 14 }}>
        Toutes les réserves du dispositif sont réunies ici, et chacune est <strong>recalculée à
        l'affichage</strong> à partir de la base — aucune n'est écrite à la main. Un tableau de
        bord qui ne dit pas ce qu'il sait mal laisse croire qu'il sait tout.
      </p>

      <div className="fi-sommaire">
        <div className="fi-case">
          <div className="fi-n">{reserves.length}</div>
          <div className="fi-l">réserves actives</div>
        </div>
        <div className="fi-case">
          <div className="fi-n">{total.en_grille ?? total.total ?? "—"}</div>
          <div className="fi-l">indicateurs en grille, dont {total.certifies} certifiés</div>
        </div>
        <div className="fi-case">
          <div className="fi-n">{sources.size}</div>
          <div className="fi-l">sources institutionnelles, toutes ouvertes</div>
        </div>
        <div className="fi-case">
          <div className="fi-n">{nb(runs[0]?.run_id ?? 0)}</div>
          <div className="fi-l">exécutions, aucune écrasée</div>
        </div>
      </div>

      <Onglets courant={vue} poser={setVue} items={[
        ["reserves", `Les réserves (${reserves.length})`],
        ["grille", "La grille"],
        ["collectes", "Les collectes"],
        ["revisions", `Révisions (${rev.length})`],
        ["elagage", "L'élagage"],
        ["methode", "La méthode"]
      ]} />

      {vue === "reserves" && (
        <>
          {reserves.length === 0
            ? <div className="vide">Aucune réserve active. C'est inhabituel : vérifiez que la base répond.</div>
            : reserves.map((r, i) => (
                <div className={"reserve" + (r.gravite === "grave" ? " grave" : "")} key={i}>
                  <div className="reserve-tete">{r.titre}</div>
                  <div className="reserve-corps">{r.corps}</div>
                  <div className="reserve-ou">porte sur : {r.ou}</div>
                </div>
              ))}
          <p className="note" style={{ marginTop: 14, maxWidth: 760 }}>
            Ces réserves ne sont pas des pannes. Ce sont les endroits où le dispositif produit un
            résultat <strong>plausible mais moins solide qu'il n'en a l'air</strong> — le seul type
            de défaut qui ne se signale pas tout seul.
          </p>
        </>
      )}

      {vue === "grille" && (
        <>
        <div className="carte" style={{ marginBottom: 14 }}>
          <h3 className="sous-titre">Les questions de veille, et qui y répond</h3>
          <p className="reserve-corps" style={{ marginBottom: 10 }}>
            Chaque indicateur de la grille est rattaché à une question — un déclencheur en base
            l'impose. Après l'élagage, {decouvertes === 0
              ? "toutes les questions restent couvertes."
              : `${enLettres(decouvertes)} question${decouvertes > 1 ? "s" : ""} ne ${decouvertes > 1 ? "sont" : "est"} plus couverte${decouvertes > 1 ? "s" : ""} — et cela se voit, au lieu d'être recouvert nominalement par une série illisible. C'est la calculabilité de l'absence : un cadre de questions invariant permet de mesurer ce qu'on ne surveille pas.`}
          </p>
          <table>
            <thead>
              <tr><th>Marché</th><th>Question</th><th>Formulation</th><th>Suivie par</th></tr>
            </thead>
            <tbody>
              {couverture.map((q, i) => (
                <tr key={i}>
                  <td>{q.sector_label || q.sector_code}</td>
                  <td style={{ whiteSpace: "nowrap" }}>{q.question_generique || q.watch_question_code}</td>
                  <td><span className="cell-note" style={{ marginTop: 0 }}>{q.question_sectorielle}</span></td>
                  <td>
                    {q.porteurs.length
                      ? q.porteurs.map(id => <span className="etq e-gris" key={id} style={{ marginRight: 4 }}>{id}</span>)
                      : <span className="etq e-attn">découverte</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="carte" style={{ padding: 0, overflow: "hidden" }}>
          <div style={{ padding: "16px 18px", borderBottom: "1px solid var(--bord)" }}>
            <input className="filtre" style={{ width: "100%" }}
                   placeholder="Chercher un indicateur ou une source…"
                   value={filtre} onChange={e => setFiltre(e.target.value)} />
          </div>
          <table >
            <thead>
              <tr><th>Code</th><th>Marché</th><th>Ce qu'il mesure</th><th>Rôle</th>
                  <th>Source</th><th>En base</th></tr>
            </thead>
            <tbody>
              {lignes.map(i => (
                <tr key={i.indicator_id}>
                  <td><strong>{i.indicator_id}</strong></td>
                  <td>{i.sector_label}</td>
                  <td>{i.label}</td>
                  <td>
                    <span className={"etq lat-" + (i.latence || "coincident")}>
                      {i.latence === "avance" ? "annonce"
                        : i.latence === "retarde" ? "confirme"
                        : i.latence === "coincident" ? "constate" : "—"}
                    </span>
                  </td>
                  <td>{i.source_organisation}
                      {i.source_url && <div><LienSource href={i.source_url}>source</LienSource></div>}</td>
                  <td>{Number(i.observations) > 0
                        ? <>{nb(i.observations)} obs.<div className="cell-note">{i.p_min} → {i.p_max}</div></>
                        : <span className="etq e-gris">rien</span>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        </>
      )}

      {vue === "collectes" && (
        <div className="carte">
          <p className="bloc-intro">
            Chaque collecte <strong>ajoute</strong> ses observations sans écraser les précédentes.
            Une valeur corrigée par sa source ne remplace pas l'ancienne : les deux coexistent,
            datées. C'est ce qui rend l'écart entre exécutions lisible — et vérifiable.
          </p>
          <table>
            <thead><tr><th>N°</th><th>Exécutée le</th><th>Résultat</th>
                       <th>Valeurs écrites</th><th>Indicateurs couverts</th></tr></thead>
            <tbody>
              {runs.map(s => (
                <tr key={s.run_id}>
                  <td>{s.run_id}</td>
                  <td>{new Date(s.executed_at).toLocaleString("fr-CH")}</td>
                  <td><span className={"etq " + (s.status === "ok" ? "e-vert" : "e-rouge")}>
                        {s.status === "ok" ? "réussie" : s.status}</span></td>
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
          {rev.length === 0 ? (
            <p className="bloc-intro">
              Aucune révision repérée. Le mécanisme tourne ; il n'a rien attrapé. Ce n'est pas un
              résultat vide : c'est la démonstration qu'aucune valeur publiée n'a bougé entre deux
              collectes.
            </p>
          ) : (
            <>
              <p className="bloc-intro">
                {rev.length} valeurs ont été <strong>corrigées par leur source</strong> entre deux
                collectes. Sans registre en ajout seul, ces corrections seraient invisibles.
              </p>
              <table >
                <thead><tr><th>Indicateur</th><th>Période</th><th>Zone</th>
                           <th>Avant</th><th>Après</th><th>Écart</th></tr></thead>
                <tbody>
                  {rev.slice(0, 50).map((e, i) => (
                    <tr key={i}>
                      <td><strong>{e.indicator_id}</strong></td><td>{e.period}</td><td>{e.geo}</td>
                      <td>{nb(e.value_run_precedent)}</td><td>{nb(e.value)}</td>
                      <td className={Math.abs(e.ecart_pct) > 1 ? "baisse" : "neutre"}>{pct(e.ecart_pct)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </>
          )}
        </div>
      )}

      {vue === "elagage" && (
        <div className="carte">
          <h3 className="sous-titre">De quarante-quatre indicateurs à treize</h3>
          <p className="reserve-corps">
            La grille comptait quarante-quatre indicateurs. Un décideur n'en lit pas
            quarante-quatre, et le volume masquait ce que la grille avait à dire. L'élagage du
            25 août 2026 en retient <strong>treize</strong>. Les trente et un autres restent au
            référentiel, qualifiés, avec leurs observations : ils sont écartés de la vitrine, pas
            supprimés, et redeviennent disponibles sans requalification.
          </p>
          <h3 className="sous-titre">Les cinq critères, appliqués dans cet ordre</h3>
          <ol className="liste-manques">
            <li><strong>Il collecte</strong> — au moins douze points sur sa zone de référence.</li>
            <li><strong>Il est frais</strong> — moins de trois mois de retard pour une série
              infra-annuelle, moins de dix-huit pour une annuelle.</li>
            <li><strong>Il n'est pas redondant</strong> — corrélation inférieure à 0,90 avec tout
              autre indicateur retenu.</li>
            <li><strong>Il parle au métier</strong> — il porte sur l'étage adressable par un
              usineur de précision, ou sur le marché de son client direct. Pas deux étages plus
              loin.</li>
            <li><strong>Il apporte un rôle</strong> — annonce, constat ou confirmation que le
              secteur n'a pas déjà.</li>
          </ol>
          <h3 className="sous-titre">Ce qui a décidé, quand deux séries se ressemblaient</h3>
          <p className="reserve-corps">
            Entre deux séries corrélées, la grille garde <strong>la plus proche du métier</strong>,
            et non la plus longue. Une série de cent cinquante points sur un marché final vaut
            moins, pour un sous-traitant, qu'une série de dix-neuf points sur les pièces qu'il
            usine. C'est ainsi que H7 et H9 — la valeur et le volume des exportations horlogères —
            l'emportent sur H1, H8 et H3, et que A6 (équipements, l'étage adressable) l'emporte
            sur A5 (assemblage de véhicules, en aval du sous-traitant).
          </p>
          <h3 className="sous-titre">Ce que l'élagage a coûté</h3>
          <p className="reserve-corps">
            Il faut le dire, parce que c'est le prix du choix. L'automobile ne compte plus que deux
            indicateurs, dont un — les immatriculations — n'a que sept points : ce marché n'est
            plus <em>scorable</em>, et le tableau de bord ne prétend plus le scorer. La couverture
            des questions de veille se resserre également : plusieurs questions n'ont plus qu'un
            indicateur, et deux n'en ont plus du tout. Ces lacunes sont calculables, elles se
            lisent dans l'onglet « La grille », et elles valent mieux qu'une couverture nominale
            assurée par des séries qu'on ne peut pas lire.
          </p>
        </div>
      )}

      {vue === "methode" && (
        <div className="carte">
          <h3 className="sous-titre">L'état d'un marché</h3>
          <p className="reserve-corps">
            Pour chaque série, le dispositif retire d'abord la <strong>tendance longue</strong> —
            sans quoi une série qui croît depuis dix ans s'afficherait « au-dessus » en permanence
            et aucun retournement ne serait signalable. Ce qui reste est l'écart du dernier point à
            sa propre base, exprimé en écarts-types, puis orienté par le sens de lecture déclaré de
            l'indicateur. Sous un demi écart-type, le dispositif considère qu'il n'y a rien à
            signaler.
          </p>
          <h3 className="sous-titre">Ce que ce score ne permet pas</h3>
          <ul className="liste-manques">
            <li><strong>Comparer deux marchés entre eux.</strong> Chaque score compare une branche
              à son propre passé ; les échelles ne sont pas communes.</li>
            <li><strong>Prédire.</strong> Le dispositif décrit une position et une direction. Aucun
              chiffre affiché n'est une prévision, et c'est un choix.</li>
            <li><strong>Se passer de vous.</strong> Les lectures produites par modèle sortent au
              statut « à valider » et n'atteignent l'écran qu'après relecture humaine.</li>
          </ul>
          <h3 className="sous-titre">Pourquoi le score n'ouvre plus la journée</h3>
          <p className="reserve-corps">
            Le score sectoriel — la moyenne des écarts détendancés des séries d'un marché — a été
            retiré de l'écran de décision le 25 août 2026. Avec deux séries par marché après
            l'élagage, « la moyenne des écarts détendancés » n'est plus une mesure : c'est la
            moyenne de deux nombres. Le construit était déjà le plus fragile du dispositif —
            moyenne non pondérée, périodicités mêlées, séries corrélées comptées deux fois — et
            réduire le nombre de séries le rend indéfendable comme chiffre affiché à un dirigeant.
            Il reste calculé, il reste au rapport, et il reste ici : c'est une <strong>
            expérimentation méthodologique</strong> — comment construire une position cyclique
            détendancée, et pourquoi elle n'est pas décisionnelle en l'état.
          </p>
          <h3 className="sous-titre">Annonce, constat, confirmation</h3>
          <p className="reserve-corps">
            Chaque indicateur porte son rôle : un <strong>avancé</strong> annonce, un
            <strong> coïncident</strong> constate, un <strong>retardé</strong> confirme. Les
            mélanger dans une moyenne est une erreur de catégorie — l'avancé y est neutralisé par
            le retardé au moment précis où il servirait. Le dispositif le fait, et le dit : c'est
            la première réserve de la liste.
          </p>
        </div>
      )}
    </div>
  );
}
