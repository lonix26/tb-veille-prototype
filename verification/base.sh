#!/usr/bin/env bash
# verification/base.sh — invariants de la base de veille (02.09.2026). Lecture seule.
#
# Deux familles de contrôles :
#   1. des invariants structurels, qui doivent valoir zéro quel que soit l'état de la
#      collecte (un indicateur certifié sans question de veille, une observation
#      orpheline, un run resté ouvert…) ;
#   2. des faits que le rapport cite, comparés à un relevé figé par requête dans
#      base_attendu.txt — le texte ne fait jamais foi, c'est la base qui est relue.
#      `bash verification/base.sh --figer` régénère ce relevé (à ne faire qu'après
#      avoir compris l'écart, et à dater en passation).
# Ce que le script ne fait pas : juger la justesse des valeurs collectées (validation
# humaine) ni remplacer la requête au moment de citer un chiffre.
set -u
cd "$(dirname "$0")/.."
ATTENDU=verification/base_attendu.txt

Q() { docker compose exec -T db psql -U veille -d veille -Atc "$1"; }
ko=0
verdict() { # verdict <ok|KO> <libellé> [détail]
  if [ "$1" = ok ]; then printf '  ok   %s\n' "$2"; else printf '  KO   %s — %s\n' "$2" "${3:-}"; ko=$((ko+1)); fi
}
zero() { # zero <libellé> <requête renvoyant un compte>
  local n; n=$(Q "$2") || { verdict KO "$1" "requête en erreur"; return; }
  [ "$n" = 0 ] && verdict ok "$1" || verdict KO "$1" "$n cas"
}

Q "select 1" >/dev/null 2>&1 || { echo "Base injoignable (docker compose exec db)."; exit 2; }

echo "1. Invariants structurels (attendu : zéro cas)"
zero "indicateur certifié sans question de veille rattachée" \
  "select count(*) from indicators i where status='certifie' and not exists (select 1 from indicator_watch_questions q where q.indicator_id=i.indicator_id)"
zero "liaison indicateur–question vers un code de question inconnu" \
  "select count(*) from indicator_watch_questions q where not exists (select 1 from watch_questions w where w.code=q.watch_question_code)"
zero "instanciation sectorielle vers un code de question inconnu" \
  "select count(*) from sector_watch_questions s where not exists (select 1 from watch_questions w where w.code=s.watch_question_code)"
zero "indicateur certifié sans source au référentiel" \
  "select count(*) from indicators i where status='certifie' and not exists (select 1 from sources s where s.source_id=i.source_id)"
zero "indicateur certifié dont la zone de référence n'a aucune métrique" \
  "select count(*) from indicators i where status='certifie' and geo_reference is not null and not exists (select 1 from v_metriques m where m.indicator_id=i.indicator_id and m.geo=i.geo_reference)"
zero "indicateur hard certifié en vitrine sans liaison de source active" \
  "select count(*) from indicators i where status='certifie' and en_vitrine and category='hard' and not exists (select 1 from source_bindings b where b.indicator_id=i.indicator_id and b.statut='actif')"
zero "observation sans indicateur au référentiel" \
  "select count(*) from indicator_values v where not exists (select 1 from indicators i where i.indicator_id=v.indicator_id)"
zero "observation sans run" \
  "select count(*) from indicator_values v where not exists (select 1 from runs r where r.run_id=v.run_id)"
zero "observation à valeur nulle" \
  "select count(*) from indicator_values where value is null"
zero "observation en doublon (indicateur, run, période, zone)" \
  "select count(*) from (select 1 from indicator_values group by indicator_id,run_id,period,geo having count(*)>1) d"
zero "run en cours depuis plus d'une heure (le workflow d'erreur commun devrait l'avoir clos)" \
  "select count(*) from runs where status='en_cours' and executed_at < now() - interval '1 hour'"
zero "run clos sans date de clôture, hors runs 79 et 80 (faits d'époque, avant closed_at)" \
  "select count(*) from runs where status<>'en_cours' and closed_at is null and run_id not in (79,80)"

# Chaque vue doit se laisser lire : une vue cassée par une migration se voit ici,
# pas dans l'application, qui n'en lit que quelques-unes.
cassees=""
for v in $(Q "select table_name from information_schema.views where table_schema='public' order by 1"); do
  Q "select 1 from $v limit 1" >/dev/null 2>&1 || cassees="$cassees $v"
done
[ -z "$cassees" ] && verdict ok "toutes les vues se laissent lire" || verdict KO "vues illisibles" "$cassees"

echo
echo "2. Faits cités par le rapport (comparés au relevé figé)"
releve() {
  echo "referentiel_total=$(Q "select total||'/'||certifies||'/'||certifies_hard||'/'||certifies_composite||'/'||a_confirmer||'/'||en_grille||'/'||ecartes from v_bilan_referentiel where sector_code is null")"
  echo "referentiel_par_secteur=$(Q "select string_agg(sector_code||':'||certifies||'/'||total, ' ' order by sector_code) from v_bilan_referentiel where sector_code is not null")"
  echo "questions_de_veille=$(Q "select count(*) from watch_questions")"
  echo "instanciations_sectorielles=$(Q "select count(*) from sector_watch_questions")"
  echo "objets=tables:$(Q "select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE'") vues:$(Q "select count(*) from information_schema.views where table_schema='public'") fonctions:$(Q "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'")"
  echo "filtrage_flux=$(Q "select items_collectes||'/'||items_filtres||'/'||file_humaine||'/'||items_audites||'/'||faux_negatifs from v_bilan_filtrage")"
}
if [ "${1:-}" = "--figer" ]; then
  { echo "# Relevé figé par requête le $(date +%d.%m.%Y) — verification/base.sh --figer"; releve; } > "$ATTENDU"
  echo "  relevé figé dans $ATTENDU"; cat "$ATTENDU"
elif [ ! -f "$ATTENDU" ]; then
  verdict KO "relevé figé absent" "lancer une première fois avec --figer"
else
  # Relevé calculé une fois, hors de la boucle : `docker compose exec` lit l'entrée
  # standard et viderait le fichier lu par `read` dès le premier tour.
  actuel_tout=$(releve)
  while IFS='=' read -r cle valeur; do
    [ -z "$cle" ] || [ "${cle#\#}" != "$cle" ] && continue
    actuel=$(printf '%s\n' "$actuel_tout" | grep "^$cle=" | cut -d= -f2-)
    [ "$actuel" = "$valeur" ] && verdict ok "$cle = $valeur" || verdict KO "$cle" "attendu $valeur, relevé $actuel"
  done < "$ATTENDU"
fi

echo
echo "3. Pour information (varie à chaque collecte, non contrôlé)"
printf '  runs par statut : %s\n' "$(Q "select string_agg(status||' '||n, ', ' order by status) from (select status,count(*) n from runs group by 1) s")"
printf '  observations : %s, sur %s indicateurs, dont %s certifiés\n' \
  "$(Q "select count(*) from indicator_values")" \
  "$(Q "select count(distinct indicator_id) from indicator_values")" \
  "$(Q "select count(distinct v.indicator_id) from indicator_values v join indicators i using (indicator_id) where i.status='certifie'")"
printf '  statuts de validation : %s\n' "$(Q "select string_agg(validation_status||' '||n, ', ' order by validation_status) from (select validation_status,count(*) n from indicator_values group by 1) s")"

echo
if [ $ko = 0 ]; then echo "Base conforme : aucun invariant violé."; else echo "$ko contrôle(s) en échec."; exit 1; fi
