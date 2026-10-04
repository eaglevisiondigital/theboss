#!/usr/bin/env bash
# Real blocked two-connection races, only on the disposable private Unix socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
 printf '%s\n' 'Basketball races require the private disposable runner socket.' >&2;exit 1
fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses')='' ") != t ]];then exit 1;fi
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase5B concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
diagnostics(){
 local label=$1 errors=$2
 printf 'Phase5B race failure: %s\n' "$label" >&2
 # Only this synthetic local runner writes these files. Show the first primary
 # SQLSTATE/message line; exclude SQL bodies, DETAIL and authentication claims.
 if [[ -s "$errors" ]];then awk '
 /(ERROR|FATAL):/ {line=$0;sub(/^.*(ERROR|FATAL):[[:space:]]*/,"",line);print "PostgreSQL: "substr(line,1,500);found=1;exit}
 /No such file or directory|could not open|Permission denied|^psql:.*(error|fatal):/ {print "psql/file: "substr($0,1,500);found=1;exit}
 END {if(!found)print "No primary SQL error recorded; participant log contains no recognized file or SQL failure."}
 ' "$errors" >&2;fi
}
assert_sql(){ if [[ $("${psql_cmd[@]}" --command "$2") != t ]];then fail "$1";fi; }
await_state(){
 local app=$1 expected=$2 pid=$3 errors=$4 deadline=$((SECONDS+7)) query
 if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%phase5b-writer-ready%'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do
  if [[ -s "$errors" ]] && grep -Eq '(^|[[:space:]])(ERROR|FATAL):' "$errors";then
   diagnostics "$app failed before synchronization" "$errors";return 1
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1;then printf 'Basketball race participant %s exited before synchronization.\n' "$app" >&2;return 1;fi
  if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.025
 done
 printf 'Basketball race participant %s did not reach %s before the fixed eight-second timeout.\n' "$app" "$expected" >&2;return 1
}
race(){
 local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold_seconds=${5:-0} fifo="$race_dir/phase5b-$1.stdin" rc=0
 mkfifo -m 600 "$fifo"
 "${psql_cmd[@]}" <"$fifo" >"$race_dir/phase5b-$label-writer.out" 2>"$race_dir/phase5b-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='boss_phase5b_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase5b-writer-ready */;" >&9
 await_state "boss_phase5b_${label}_writer" ready "$writer_pid" "$race_dir/phase5b-$label-writer.err"
 "${psql_cmd[@]}" --command "set application_name='boss_phase5b_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/phase5b-$label-contender.out" 2>"$race_dir/phase5b-$label-contender.err" & contender_pid=$!
 await_state "boss_phase5b_${label}_contender" waiting "$contender_pid" "$race_dir/phase5b-$label-contender.err"
 # Optional fixed short hold proves natural deadline expiry while the signed
 # caller is already blocked. Every participant keeps the eight-second limit.
 if [[ "$hold_seconds" != 0 ]];then sleep "$hold_seconds";fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false
 if ! wait "$writer_pid";then writer_pid='';diagnostics "$label writer commit" "$race_dir/phase5b-$label-writer.err";fail "$label writer should have committed";fi;writer_pid=''
 if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid=''
 if [[ "$expected" == success && "$rc" != 0 ]];then diagnostics "$label contender" "$race_dir/phase5b-$label-contender.err";fail "$label contender should have succeeded";fi
 if [[ "$expected" != success ]] && { [[ "$rc" == 0 ]] || ! grep -Fq "$expected" "$race_dir/phase5b-$label-contender.err"; };then diagnostics "$label unexpected contender result" "$race_dir/phase5b-$label-contender.err";fail "$label expected $expected";fi
race_count=$((race_count+1))
}
# Each writer and contender invokes the actual canonical RPC in an independent
# PostgreSQL connection. These committed fixtures exist only in this cluster.
# The historical Game Center race keeps its committed evidence until cluster
# removal. Copy its reviewed fixture into this same private run directory and
# change only fixed synthetic identity/email/slug namespaces. Keep both sets of
# evidence intact; do not delete historical rows or alter security controls.
if [[ $(awk '$0=="\\ir ../phase5a/fixture.sql" {n++} END {print n+0}' "$test_dir/phase5b/fixture.sql") != 1 ]];then fail 'Basketball fixture must extend exactly one reviewed Game Center fixture';fi
sed -e 's/boss-phase5a-test:/boss-phase5b-race-base:/g' \
    -e 's/phase5a.example.invalid/phase5b-race.example.invalid/g' \
    -e 's/synthetic-phase5a-/synthetic-phase5b-race-/g' \
    "$test_dir/phase5a/fixture.sql" >"$race_dir/phase5b-race-fixture.sql"
awk '$0!="\\ir ../phase5a/fixture.sql" {gsub(/boss-phase5b-test:/,"boss-phase5b-race-roster:");print}' \
    "$test_dir/phase5b/fixture.sql" >>"$race_dir/phase5b-race-fixture.sql"
cat >"$race_dir/phase5b-race-setup.sql" <<SQL
begin;
\ir '$race_dir/phase5b-race-fixture.sql'
do \$\$declare label text;begin
 foreach label in array array['baskets','replay','score-sub','score-foul','period-score','score-period','final','correction','substitution','clock','authority','duplicate-foul','duplicate-sub','duplicate-correction'] loop
  insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,timezone,status,visibility,rsvp_mode,created_by_person_id,updated_by_person_id)
  select pg_temp.f('event-bb-race-'||label),organization_id,'Synthetic Basketball race '||label,event_type_key,start_at,end_at,timezone,status,visibility,rsvp_mode,created_by_person_id,updated_by_person_id from public.events where id=pg_temp.f('event-internal');
  insert into public.event_targets(event_id,organization_id,target_type,target_id)
  select pg_temp.f('event-bb-race-'||label),organization_id,target_type,target_id from public.event_targets where event_id=pg_temp.f('event-internal');
  insert into public.event_game_details(event_id,organization_id,opponent_team_id,external_opponent_name,home_away)
  select pg_temp.f('event-bb-race-'||label),organization_id,opponent_team_id,external_opponent_name,home_away from public.event_game_details where event_id=pg_temp.f('event-internal');
 end loop;
end\$\$;
set local role authenticated;
select pg_temp.actor('admin');
do \$\$declare label text;begin
 foreach label in array array['baskets','replay','score-sub','score-foul','period-score','score-period','final','correction','substitution','clock','authority','duplicate-foul','duplicate-sub','duplicate-correction'] loop
  perform pg_temp.bb_create(label,'bb-race-'||label);
 end loop;
 perform pg_temp.bb_event('correction','made_2','primary',1,'correction-source');
 perform pg_temp.bb_event('duplicate-correction','made_2','primary',1,'duplicate-correction-source');
 perform pg_temp.bb_end('final');perform pg_temp.bb_op('basketball.period.start','final');
 perform pg_temp.game_op('game.operator.assign','authority',jsonb_build_object('person_id',pg_temp.f('scorer'),'role_assignment_id',pg_temp.f('role-scorer'),'function_key','scorekeeper','team_id',pg_temp.f('falcons'),'ends_at',now()+interval '1 hour'));
end\$\$;
commit;
SQL
if ! "${psql_cmd[@]}" --file "$race_dir/phase5b-race-setup.sql" >"$race_dir/phase5b-race-setup.out" 2>"$race_dir/phase5b-race-setup.err";then diagnostics setup "$race_dir/phase5b-race-setup.err";fail 'fixture setup';fi
uuid(){ "${psql_cmd[@]}" --command "select md5('boss-phase5b-race-base:$1')::uuid"; }
game_id(){ "${psql_cmd[@]}" --command "select id from public.games where event_id=md5('boss-phase5b-race-base:event-bb-race-$1')::uuid"; }
version(){ "${psql_cmd[@]}" --command "select version from public.games where id='$(game_id "$1")'"; }
roster(){
 local label=$1 side=$2 n=$3 person
 if [[ "$n" == 1 ]];then if [[ "$side" == primary ]];then person=$(uuid child1);else person=$(uuid child2);fi
 else person=$("${psql_cmd[@]}" --command "select md5('boss-phase5b-race-roster:$side-player-$n')::uuid");fi
 "${psql_cmd[@]}" --command "select r.id from public.game_roster_snapshots r join public.games g on g.id=r.game_id and g.roster_revision=r.revision where g.id='$(game_id "$label")' and r.person_id='$person'"
}
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase5b-race-base:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase5b-race-base:session-$1')::uuid)::text,true);"; }
command(){
 local op=$1 label=$2 extra=$3 request=$4 ver=${5:-$(version "$2")}
 printf '%s' "select public.boss_games_mutate(md5('boss-phase5b-race-request:$request')::uuid,jsonb_build_object('operation','$op','input',jsonb_build_object('game_id','$(game_id "$label")','expected_version',$ver)||'$extra'::jsonb));"
}
event_extra(){ printf '{"event_type":"%s","side":"%s","roster_id":"%s"}' "$2" "${3:-primary}" "$(roster "$1" "${3:-primary}" "${4:-1}")"; }
sub_extra(){ printf '{"side":"primary","out_roster_id":"%s","in_roster_id":"%s"}' "$(roster "$1" primary "$2")" "$(roster "$1" primary "$3")"; }
admin=$(auth admin);scorer=$(auth scorer)
v=$(version baskets)
race baskets "$admin$(command basketball.event.add baskets "$(event_extra baskets made_2)" baskets-one "$v")" "$admin$(command basketball.event.add baskets "$(event_extra baskets made_3 opponent)" baskets-two "$v")" PT409
assert_sql 'simultaneous baskets retain exactly one version winner' "select primary_score=2 and opponent_score=0 and (select count(*)=1 from public.game_basketball_events where game_id=g.id and event_type in('made_2','made_3')) from public.games g where id='$(game_id baskets)'"
if ! "${psql_cmd[@]}" --command "begin;$admin$(command basketball.event.add baskets "$(event_extra baskets made_3 opponent)" baskets-two)commit;" >"$race_dir/phase5b-basket-retry.out" 2>"$race_dir/phase5b-basket-retry.err";then diagnostics 'version loser refreshed retry' "$race_dir/phase5b-basket-retry.err";fail 'refreshed basket retry';fi
assert_sql 'refreshed loser contributes once in deterministic next sequence' "select primary_score=2 and opponent_score=3 and (select count(*)=2 from public.game_basketball_events where game_id=g.id and event_type in('made_2','made_3')) from public.games g where id='$(game_id baskets)'"
replay=$(command basketball.event.add replay "$(event_extra replay made_ft)" ft-replay)
race duplicate_request "$admin$replay" "$admin$replay" success
assert_sql 'duplicate free throw has one typed event one ledger one receipt' "select (select count(*)=1 from public.game_basketball_events where game_id='$(game_id replay)' and request_id=md5('boss-phase5b-race-request:ft-replay')::uuid) and (select count(*)=1 from public.game_operations where game_id='$(game_id replay)' and request_id=md5('boss-phase5b-race-request:ft-replay')::uuid) and (select count(*)=1 from boss_private.game_operation_receipts where request_id=md5('boss-phase5b-race-request:ft-replay')::uuid)"
v=$(version score-sub)
race score_substitution "$admin$(command basketball.event.add score-sub "$(event_extra score-sub made_2)" score-sub-one "$v")" "$admin$(command basketball.substitute score-sub "$(sub_extra score-sub 5 6)" score-sub-two "$v")" PT409
assert_sql 'version-conflicting substitution cannot partially change lineup' "select count(*)=5 and bool_or(roster_id='$(roster score-sub primary 5)') and not bool_or(roster_id='$(roster score-sub primary 6)') from public.game_basketball_lineups where game_id='$(game_id score-sub)' and side='primary'"
v=$(version score-foul)
race score_foul "$admin$(command basketball.event.add score-foul "$(event_extra score-foul made_2)" score-foul-one "$v")" "$admin$(command basketball.event.add score-foul "$(event_extra score-foul personal_foul)" score-foul-two "$v")" PT409
assert_sql 'score/foul collision leaves no losing foul fact' "select not exists(select 1 from public.game_basketball_events where game_id='$(game_id score-foul)' and event_type='personal_foul')"
v=$(version period-score)
race period_score "$admin$(command basketball.period.end period-score '{}' period-one "$v")" "$admin$(command basketball.event.add period-score "$(event_extra period-score made_2)" period-two "$v")" PT409
assert_sql 'period end closes waiting score without contribution' "select s.period_status='ended' and g.primary_score=0 from public.games g join public.game_basketball_states s on s.game_id=g.id where g.id='$(game_id period-score)'"
v=$(version score-period)
race score_period "$admin$(command basketball.event.add score-period "$(event_extra score-period made_2)" score-period-one "$v")" "$admin$(command basketball.period.end score-period '{}' score-period-two "$v")" PT409
assert_sql 'score winner does not silently advance period' "select s.period_status='active' and g.primary_score=2 from public.games g join public.game_basketball_states s on s.game_id=g.id where g.id='$(game_id score-period)'"
v=$(version final)
final_writer="$admin$(command basketball.period.end final '{}' final-end "$v")$(command game.finalize final '{}' final-seal "$((v+1))")"
race finalization_event "$final_writer" "$admin$(command basketball.event.add final "$(event_extra final made_2)" final-late "$v")" PT409
assert_sql 'finalization seals before waiting late event' "select status='final' and primary_score=0 and (select count(*)=1 from public.game_basketball_finalizations where game_id=g.id) and not exists(select 1 from public.game_basketball_events where game_id=g.id and request_id=md5('boss-phase5b-race-request:final-late')::uuid) from public.games g where id='$(game_id final)'"
target=$("${psql_cmd[@]}" --command "select id from public.game_basketball_events where game_id='$(game_id correction)' and event_type='made_2'")
v=$(version correction)
reverse="{\"event_id\":\"$target\",\"reason\":\"Synthetic race reversal\"}"
race correction_event "$admin$(command basketball.event.reverse correction "$reverse" correction-one "$v")" "$admin$(command basketball.event.add correction "$(event_extra correction personal_foul)" correction-two "$v")" PT409
assert_sql 'correction race keeps source plus one linked reversal' "select primary_score=0 and (select count(*)=1 from public.game_basketball_events where correction_of='$target') and exists(select 1 from public.game_basketball_events where id='$target') from public.games where id='$(game_id correction)'"
v=$(version substitution)
race substitutions "$admin$(command basketball.substitute substitution "$(sub_extra substitution 5 6)" sub-one "$v")" "$admin$(command basketball.substitute substitution "$(sub_extra substitution 4 6)" sub-two "$v")" PT409
assert_sql 'competing substitutions keep one valid five-player lineup' "select count(*)=5 and count(distinct roster_id)=5 and bool_or(roster_id='$(roster substitution primary 6)') and not bool_or(roster_id='$(roster substitution primary 5)') from public.game_basketball_lineups where game_id='$(game_id substitution)' and side='primary'"
v=$(version clock)
race clock_collision "$admin$(command basketball.clock.set clock '{"clock_ms":42000,"reason":"Synthetic winner clock"}' clock-one "$v")" "$admin$(command basketball.clock.set clock '{"clock_ms":17000,"reason":"Synthetic stale clock"}' clock-two "$v")" PT409
assert_sql 'clock collision retains exact winner sample' "select clock_remaining_ms=42000 and not clock_running from public.game_basketball_states where game_id='$(game_id clock)'"
assignment=$("${psql_cmd[@]}" --command "select id from public.game_operator_assignments where game_id='$(game_id authority)' and person_id='$(uuid scorer)' and status='active'")
v=$(version authority)
race operator_revoke "$admin$(command game.operator.end authority "{\"assignment_id\":\"$assignment\"}" revoke-operator "$v")" "$scorer$(command basketball.event.add authority "$(event_extra authority made_2)" revoked-event "$v")" PT403
assert_sql 'revoked waiting operator has no sport contribution' "select primary_score=0 and not exists(select 1 from public.game_basketball_events where game_id=g.id and event_type='made_2') from public.games g where id='$(game_id authority)'"
# Restore only the synthetic assignment for the independent role/feature races.
"${psql_cmd[@]}" --command "update public.game_operator_assignments set status='active',ends_at=clock_timestamp()+interval '1 hour' where id='$assignment'" >"$race_dir/phase5b-authority-restore.out"
assert_sql 'restored operator is current before independent revocation races' "select boss_private.games_operator_current('$(uuid scorer)',g) from public.games g where id='$(game_id authority)'"
event_lock="select 1 from public.events where id='$(uuid event-bb-race-authority)' for update;"
v=$(version authority)
race role_revoke "$event_lock update public.role_assignments set status='inactive' where id='$(uuid role-scorer)';" "$scorer$(command basketball.event.add authority "$(event_extra authority made_2)" role-revoked-event "$v")" PT403
"${psql_cmd[@]}" --command "update public.role_assignments set status='active' where id='$(uuid role-scorer)'" >>"$race_dir/phase5b-authority-restore.out"
race membership_revoke "$event_lock update public.team_memberships set status='inactive' where id='$(uuid membership-scorer)';" "$scorer$(command basketball.event.add authority "$(event_extra authority made_2)" member-revoked-event "$v")" PT403
"${psql_cmd[@]}" --command "update public.team_memberships set status='active' where id='$(uuid membership-scorer)'" >>"$race_dir/phase5b-authority-restore.out"
module_version=$("${psql_cmd[@]}" --command "select om.version from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id='$(uuid org)' and m.key='sports'")
configure="select public.boss_games_mutate(md5('boss-phase5b-race-request:disable-feature')::uuid,jsonb_build_object('operation','games.configure','input',jsonb_build_object('organization_id','$(uuid org)','expected_version',$module_version,'configuration',jsonb_build_object('basketball_live_scoring',false))));"
race feature_disable "$admin$configure" "$scorer$(command basketball.event.add authority "$(event_extra authority made_2)" feature-disabled-event "$v")" PT403
assert_sql 'feature change while blocked creates no basketball event' "select primary_score=0 and not exists(select 1 from public.game_basketball_events where game_id=g.id and event_type='made_2') from public.games g where id='$(game_id authority)'"
"${psql_cmd[@]}" --command "update public.organization_modules set configuration=configuration||'{\"basketball_live_scoring\":true}' where organization_id='$(uuid org)' and module_id=(select id from public.modules where key='sports')" >>"$race_dir/phase5b-authority-restore.out"
foul=$(command basketball.event.add duplicate-foul "$(event_extra duplicate-foul personal_foul)" foul-replay)
race duplicate_foul "$admin$foul" "$admin$foul" success
assert_sql 'duplicate foul appends one statistical foul' "select personal_fouls=1 from boss_private.basketball_totals('$(game_id duplicate-foul)') where side='primary' and roster_id is null"
sub=$(command basketball.substitute duplicate-sub "$(sub_extra duplicate-sub 5 6)" sub-replay)
race duplicate_substitution "$admin$sub" "$admin$sub" success
assert_sql 'duplicate substitution appends one fact and one lineup snapshot' "select count(*)=1 from public.game_basketball_events where game_id='$(game_id duplicate-sub)' and event_type='substitution'"
target=$("${psql_cmd[@]}" --command "select id from public.game_basketball_events where game_id='$(game_id duplicate-correction)' and event_type='made_2'")
correction="{\"event_id\":\"$target\",\"reason\":\"Synthetic duplicate reversal\"}"
reversal=$(command basketball.event.reverse duplicate-correction "$correction" correction-replay)
race duplicate_correction "$admin$reversal" "$admin$reversal" success
assert_sql 'duplicate correction retains one correction and original source' "select (select count(*)=1 from public.game_basketball_events where correction_of='$target') and exists(select 1 from public.game_basketball_events where id='$target')"
assert_sql 'all Basketball games retain contiguous canonical sequence and versions' "select bool_and(n=last and first=1) from(select count(*) n,max(sequence) last,min(sequence) first from public.game_operations where game_id in(select game_id from public.game_basketball_states) group by game_id)s"
assert_sql 'all race scores reconcile to accepted active contributions' "select bool_and(g.primary_score=p.points and g.opponent_score=o.points) from public.games g join public.game_basketball_states s on s.game_id=g.id cross join lateral (select points from boss_private.basketball_totals(g.id)where side='primary' and roster_id is null)p cross join lateral(select points from boss_private.basketball_totals(g.id)where side='opponent' and roster_id is null)o"
printf 'Phase 5B Basketball: %s coordinated two-connection races passed.\n' "$race_count"
