#!/usr/bin/env bash
# =====================================================================
# Tests de contraintes — exécution ordonnée, pièce de l'annexe 5
# TB « Exploration de l'IA pour les entreprises industrielles »
#
# Chaque test est exécuté par un appel psql distinct : l'ordre des
# libellés et des messages d'erreur est ainsi garanti par le shell.
# La variante en script SQL unique (tests_contraintes.sql) entrelace
# stdout et stderr de façon trompeuse lorsque la sortie est redirigée
# vers un fichier — contenu identique, ordre illisible.
#
# Usage (depuis prototype/) :
#   bash tests/run_tests_contraintes.sh > ../annexe_5/tests_contraintes_AAAA-MM-JJ.txt 2>&1
#
# Les cinq tests (a), (b), (c), (d 2/2), (e) et (f) DOIVENT échouer.
# Seul (d 1/2) doit réussir.
# =====================================================================

set -u
PSQL=(docker compose exec -T db psql -U veille -d veille)

req() {           # req "<libellé>" "<attendu>" "<sql>"
  echo ""
  echo "=== $1 ==="
  echo "--- attendu : $2"
  "${PSQL[@]}" -c "$3" 2>&1
}

echo "=== Contexte d'exécution ==="
"${PSQL[@]}" -c "SELECT now() AS horodatage, current_database() AS base, version() AS version_postgres;" 2>&1

echo ""
echo "=== Ouverture d'un run de travail ==="
"${PSQL[@]}" -c "INSERT INTO runs (trigger_type, note) VALUES ('manual', 'Run de test des contraintes — annexe 5') RETURNING run_id;" 2>&1

RUN="(SELECT max(run_id) FROM runs)"

req "(a) Extraction IA prétendant à la fiabilité d'une source" \
    "violation de chk_hierarchie_controle" \
    "INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
     VALUES ('A5', $RUN, '2025-01', 'EU27_2020', 100, 'ia_extraction', 'valide_source', '/data/test');"

req "(b) Consensus partiel présenté comme un consensus" \
    "violation de chk_consensus_unanime" \
    "INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, consensus_score, raw_ref)
     VALUES ('A2', $RUN, '2025-01', 'EU27_2020', 100, 'ia_extraction', 'pre_valide_consensus', 0.66, '/data/test');"

req "(c) Validation humaine sans validateur nommé ni daté" \
    "violation de chk_validation_humaine_tracee" \
    "INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
     VALUES ('A2', $RUN, '2025-02', 'EU27_2020', 100, 'ia_extraction', 'valide_humain', '/data/test');"

req "(d) Écrasement d'une valeur du registre — 1/2 : insertion licite" \
    "SUCCÈS (etl + valide_source est un cas autorisé)" \
    "INSERT INTO indicator_values (indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref)
     VALUES ('A5', $RUN, '2025-03', 'EU27_2020', 100, 'etl', 'valide_source', '/data/test');"

req "(d) Écrasement d'une valeur du registre — 2/2 : tentative de modification" \
    "déclenchement de trg_registre_ajout_seul" \
    "UPDATE indicator_values SET value = 999 WHERE indicator_id = 'A5' AND period = '2025-03';"

req "(e) Indicateur sans question de veille rattachée" \
    "déclenchement de trg_indicateur_sans_question au COMMIT" \
    "INSERT INTO indicators (indicator_id, sector_code, label, source_id, category, frequency, unit, status)
     VALUES ('X9', 'automobile', 'Indicateur sans question de veille',
             (SELECT source_id FROM sources ORDER BY source_id LIMIT 1),
             'hard', 'mensuelle', 'indice', 'certifie');"

req "(f) Suppression au registre (contrôle complémentaire)" \
    "déclenchement de trg_registre_ajout_seul" \
    "DELETE FROM indicator_values WHERE raw_ref = '/data/test';"

echo ""
echo "=== État final : ce qui a effectivement été écrit ==="
echo "--- attendu : uniquement les lignes issues de (d) 1/2, une par exécution du script"
"${PSQL[@]}" -c "SELECT indicator_id, run_id, period, geo, value, obtained_by, validation_status, raw_ref
                 FROM indicator_values WHERE raw_ref = '/data/test' ORDER BY value_id;" 2>&1

echo ""
echo "=== Vérification que X9 n'a pas été créé ==="
echo "--- attendu : 0"
"${PSQL[@]}" -c "SELECT count(*) AS nb_x9 FROM indicators WHERE indicator_id = 'X9';" 2>&1
