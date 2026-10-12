#!/usr/bin/env bash
# Real blocked two-connection races, only on the disposable private Unix socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
 printf '%s\n' 'Game races require the private disposable runner socket.' >&2;exit 1
fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses')='' ") != t ]];then exit 1;fi
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase5A concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
diagnostics(){
 local label=$1 errors=$2
 printf 'Phase5A race failure: %s\n' "$label" >&2
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
 if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%phase5a-writer-ready%'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do
  if [[ -s "$errors" ]] && grep -Eq '(^|[[:space:]])(ERROR|FATAL):' "$errors";then
   diagnostics "$app failed before synchronization" "$errors";return 1
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1;then printf 'Game race participant %s exited before synchronization.\n' "$app" >&2;return 1;fi
  if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.025
 done
 printf 'Game race participant %s did not reach %s before the fixed eight-second timeout.\n' "$app" "$expected" >&2;return 1
}
race(){
 local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold_seconds=${5:-0} fifo="$race_dir/phase5a-$1.stdin" rc=0
 mkfifo -m 600 "$fifo"
 "${psql_cmd[@]}" <"$fifo" >"$race_dir/phase5a-$label-writer.out" 2>"$race_dir/phase5a-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='boss_phase5a_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase5a-writer-ready */;" >&9
 await_state "boss_phase5a_${label}_writer" ready "$writer_pid" "$race_dir/phase5a-$label-writer.err"
 "${psql_cmd[@]}" --command "set application_name='boss_phase5a_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/phase5a-$label-contender.out" 2>"$race_dir/phase5a-$label-contender.err" & contender_pid=$!
 await_state "boss_phase5a_${label}_contender" waiting "$contender_pid" "$race_dir/phase5a-$label-contender.err"
 # Optional fixed short hold proves natural deadline expiry while the signed
 # caller is already blocked. Every participant keeps the eight-second limit.
 if [[ "$hold_seconds" != 0 ]];then sleep "$hold_seconds";fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false
 if ! wait "$writer_pid";then writer_pid='';diagnostics "$label writer commit" "$race_dir/phase5a-$label-writer.err";fail "$label writer should have committed";fi;writer_pid=''
 if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid=''
 if [[ "$expected" == success && "$rc" != 0 ]];then diagnostics "$label contender" "$race_dir/phase5a-$label-contender.err";fail "$label contender should have succeeded";fi
 if [[ "$expected" != success ]] && { [[ "$rc" == 0 ]] || ! grep -Fq "$expected" "$race_dir/phase5a-$label-contender.err"; };then diagnostics "$label unexpected contender result" "$race_dir/phase5a-$label-contender.err";fail "$label expected $expected";fi
 race_count=$((race_count+1))
}
# Fixture helpers are temporary; committed rows are local synthetic data only.
cat >"$race_dir/phase5a-race-setup.sql" <<SQL
begin;
\ir '$test_dir/phase5a/fixture.sql'
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.create_game('race-start','race-start');
select pg_temp.create_game('race-score','race-score');
select pg_temp.create_game('race-final','race-final');
select pg_temp.create_game('race-reopen','race-reopen');
select pg_temp.create_game('race-operator','race-operator');
select pg_temp.create_game('race-schedule','race-schedule');
select pg_temp.create_game('race-authority','race-authority');
do \$\$declare label text;begin
 foreach label in array array['race-start','race-score','race-final','race-reopen','race-operator','race-schedule','race-authority'] loop
  perform pg_temp.game_op('game.roster.snapshot',label);
  perform pg_temp.game_op('game.operator.assign',label,jsonb_build_object('person_id',pg_temp.f('admin'),'role_assignment_id',pg_temp.f('role-admin'),'function_key','game_administrator','team_id',pg_temp.f('falcons'),'ends_at',now()+interval '1 hour'));
 end loop;
 perform pg_temp.game_op('game.start','race-final');
 perform pg_temp.game_op('game.start','race-reopen');
 perform pg_temp.game_op('game.start','race-schedule');
 perform pg_temp.game_op('game.operator.assign','race-authority',jsonb_build_object('person_id',pg_temp.f('scorer'),'role_assignment_id',pg_temp.f('role-scorer'),'function_key','scorekeeper','team_id',pg_temp.f('falcons'),'ends_at',now()+interval '1 hour'));
 perform pg_temp.game_op('game.start','race-authority');
 perform pg_temp.game_op('game.score.set','race-reopen','{"primary_score":5,"opponent_score":4}');
 perform pg_temp.game_op('game.finalize','race-reopen');
end\$\$;
commit;
SQL
if ! "${psql_cmd[@]}" --file "$race_dir/phase5a-race-setup.sql" >"$race_dir/phase5a-race-setup.out" 2>"$race_dir/phase5a-race-setup.err";then diagnostics 'setup' "$race_dir/phase5a-race-setup.err";fail 'fixture setup';fi
uuid(){ "${psql_cmd[@]}" --command "select md5('boss-phase5a-test:$1')::uuid"; }
game_id(){ "${psql_cmd[@]}" --command "select id from public.games where event_id=md5('boss-phase5a-test:event-$1')::uuid"; }
version(){ "${psql_cmd[@]}" --command "select version from public.games where id='$(game_id "$1")'"; }
auth(){ local who=$1;printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase5a-test:auth-$who')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase5a-test:session-$who')::uuid)::text,true);"; }
command(){
 local op=$1 label=$2 extra=$3 req=$4 ver=${5:-$(version "$2")} gid
 gid=$(game_id "$label")
 printf '%s' "select public.boss_games_mutate(md5('boss-phase5a-race-request:$req')::uuid,jsonb_build_object('operation','$op','input',jsonb_build_object('game_id','$gid','expected_version',$ver)||'$extra'::jsonb));"
}
run_op(){ if ! "${psql_cmd[@]}" --command "begin;$(auth "${5:-admin}")$(command "$1" "$2" "$3" "$4")commit;" >"$race_dir/phase5a-op-$4.out" 2>"$race_dir/phase5a-op-$4.err";then diagnostics "$4 single operation" "$race_dir/phase5a-op-$4.err";fail "$4 operation";fi; }
admin=$(auth admin);scorer=$(auth scorer)
create="select public.boss_games_mutate(md5('boss-phase5a-race-request:link')::uuid,jsonb_build_object('operation','game.create','input',jsonb_build_object('organization_id','$(uuid org)','event_id','$(uuid event-denial)','expected_event_version',1,'primary_team_id','$(uuid falcons)','occurrence_key',to_char((date_trunc('day',now())+interval '20 days 18 hours') at time zone 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS'),'sport_key','basketball','competition_type','standard')));"
race linkage "$admin$create" "$admin$create" success
assert_sql 'one canonical game on concurrent linkage' "select count(*)=1 from public.games where event_id='$(uuid event-denial)'"
start=$(command game.start race-start '{}' start-replay)
race start_replay "$admin$start" "$admin$start" success
assert_sql 'one start ledger action on concurrent retry' "select count(*)=1 from public.game_operations where game_id='$(game_id race-start)' and operation='game.start'"
v=$(version race-score)
race start_version "$admin$(command game.start race-score '{}' start-writer "$v")" "$admin$(command game.start race-score '{}' start-loser "$v")" PT409
assert_sql 'one active game after two distinct starts' "select status='live' and (select count(*)=1 from public.game_operations where game_id=games.id and operation='game.start') from public.games where id='$(game_id race-score)'"
assignment="{\"person_id\":\"$(uuid scorer)\",\"role_assignment_id\":\"$(uuid role-scorer)\",\"function_key\":\"scorekeeper\",\"team_id\":\"$(uuid falcons)\",\"ends_at\":\"$("${psql_cmd[@]}" --command "select to_char((now()+interval '1 hour') at time zone 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')")\"}"
v=$(version race-operator)
race operator_collision "$admin$(command game.operator.assign race-operator "$assignment" assign-writer "$v")" "$admin$(command game.operator.assign race-operator "$assignment" assign-loser "$v")" PT409
assert_sql 'one active exact-game operator on assignment collision' "select count(*)=1 from public.game_operator_assignments where game_id='$(game_id race-operator)' and person_id='$(uuid scorer)' and status='active'"
v=$(version race-score)
race score_sequence "$admin$(command game.score.set race-score '{"primary_score":4,"opponent_score":2}' score-writer "$v")" "$admin$(command game.score.set race-score '{"primary_score":5,"opponent_score":2}' score-loser "$v")" PT409
assert_sql 'score version loser has no appended operation' "select primary_score=4 and (select count(*)=1 from public.game_operations where game_id=games.id and operation='game.score.set') from public.games where id='$(game_id race-score)'"
v=$(version race-final)
race finalize_score "$admin$(command game.finalize race-final '{}' final-writer "$v")" "$admin$(command game.score.set race-final '{"primary_score":1,"opponent_score":0}' final-loser "$v")" PT403
assert_sql 'final seal cannot be overwritten by stale score' "select status='final' and primary_score=0 and (select count(*)=1 from public.game_finalizations where game_id=games.id) from public.games where id='$(game_id race-final)'"
v=$(version race-reopen)
race reopen_final "$admin$(command game.reopen race-reopen '{"reason":"Synthetic race correction"}' reopen-writer "$v")" "$admin$(command game.finalize race-reopen '{}' refinal-loser "$v")" PT409
run_op game.finalize race-reopen '{}' refinal-success
assert_sql 'reopen/refinal preserves both immutable seals' "select finalization_count=2 and (select count(*)=2 from public.game_finalizations where game_id=games.id) from public.games where id='$(game_id race-reopen)'"
# The Calendar writer holds the canonical event lock; stale operation waits and
# rechecks current context after commit instead of using last-write-wins state.
calendar=$("${psql_cmd[@]}" --command "select jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',e.organization_id,'event_id',e.id,'expected_version',e.version,'title',e.title,'event_type_key',e.event_type_key,'start_at',e.start_at,'end_at',e.end_at,'timezone',e.timezone,'status','canceled','visibility',e.visibility,'publication_state',e.publication_state,'targets',(select jsonb_agg(jsonb_build_object('target_type',target_type,'target_id',target_id)) from public.event_targets where event_id=e.id),'game',(select jsonb_build_object('opponent_team_id',opponent_team_id,'external_opponent_name',external_opponent_name,'home_away',home_away,'game_status',game_status) from public.event_game_details where event_id=e.id))) from public.events e where id='$(uuid event-race-schedule)'")
v=$(version race-schedule)
race calendar_score "$admin select public.boss_calendar_mutate('$calendar',md5('boss-phase5a-race-request:cancel')::uuid);" "$admin$(command game.score.set race-schedule '{"primary_score":1,"opponent_score":0}' cancel-loser "$v")" PT403
assert_sql 'Calendar cancellation wins before stale score' "select status='canceled' and primary_score=0 from public.games where id='$(game_id race-schedule)'"
run_op game.start race-operator '{}' operator-start
v=$(version race-operator)
old_score=$(command game.score.set race-operator '{"primary_score":2,"opponent_score":1}' operator-score "$v")
"${psql_cmd[@]}" --command "begin;$scorer$old_score commit;" >"$race_dir/phase5a-op-operator-score.out"
assignment_id=$("${psql_cmd[@]}" --command "select id from public.game_operator_assignments where game_id='$(game_id race-operator)' and person_id='$(uuid scorer)' and status='active'")
race operator_revoke "$admin$(command game.operator.end race-operator "{\"assignment_id\":\"$assignment_id\"}" end-operator)" "$scorer$old_score" PT403
assert_sql 'operator revocation denies retry and retains old operation' "select primary_score=2 and (select count(*)=1 from public.game_operations where game_id=games.id and operation='game.score.set') and not exists(select 1 from public.game_operator_assignments where game_id=games.id and person_id='$(uuid scorer)' and status='active') from public.games where id='$(game_id race-operator)'"
v=$(version race-start)
race transitions "$admin$(command game.transition race-start '{"status":"paused"}' pause-writer "$v")" "$admin$(command game.transition race-start '{"status":"suspended"}' pause-loser "$v")" PT409
assert_sql 'concurrent transitions preserve winner' "select status='paused' from public.games where id='$(game_id race-start)'"
v=$(version race-score)
race duplicate_final "$admin$(command game.finalize race-score '{}' final-one "$v")" "$admin$(command game.finalize race-score '{}' final-two "$v")" PT409
assert_sql 'concurrent finalization produces one seal' "select count(*)=1 from public.game_finalizations where game_id='$(game_id race-score)'"
# A real current-authority change commits while the signed contender waits on
# the canonical event lock. Auth rows are synthetic fixture records only.
event_lock="select 1 from public.events where id='$(uuid event-race-authority)' for update;"
v=$(version race-authority)
race auth_session_wait "$event_lock update auth.sessions set not_after=clock_timestamp()-interval '1 second' where id='$(uuid session-scorer)';" "$scorer$(command game.score.set race-authority '{"primary_score":1,"opponent_score":0}' auth-session-loser "$v")" PT401
"${psql_cmd[@]}" --command "update auth.sessions set not_after=null where id='$(uuid session-scorer)'" >"$race_dir/phase5a-authority-restore.out"
"${psql_cmd[@]}" --command "update auth.sessions set not_after=clock_timestamp()+interval '4 seconds' where id='$(uuid session-scorer)'" >>"$race_dir/phase5a-authority-restore.out"
race auth_natural_expiry_wait "$event_lock" "$scorer$(command game.score.set race-authority '{"primary_score":1,"opponent_score":0}' auth-natural-expiry-loser "$v")" PT401 4.5
"${psql_cmd[@]}" --command "update auth.sessions set not_after=null where id='$(uuid session-scorer)'" >>"$race_dir/phase5a-authority-restore.out"
race auth_verification_wait "$event_lock update auth.users set email_confirmed_at=null where id='$(uuid auth-scorer)';" "$scorer$(command game.score.set race-authority '{"primary_score":1,"opponent_score":0}' auth-verification-loser "$v")" PT401
"${psql_cmd[@]}" --command "update auth.users set email_confirmed_at=now()-interval '3 days' where id='$(uuid auth-scorer)'" >>"$race_dir/phase5a-authority-restore.out"
race role_revocation_wait "$event_lock update public.role_assignments set status='inactive' where id='$(uuid role-scorer)';" "$scorer$(command game.score.set race-authority '{"primary_score":1,"opponent_score":0}' role-revocation-loser "$v")" PT403
"${psql_cmd[@]}" --command "update public.role_assignments set status='active' where id='$(uuid role-scorer)'" >>"$race_dir/phase5a-authority-restore.out"
race membership_revocation_wait "$event_lock update public.team_memberships set status='inactive' where id='$(uuid membership-scorer)';" "$scorer$(command game.score.set race-authority '{"primary_score":1,"opponent_score":0}' membership-revocation-loser "$v")" PT403
"${psql_cmd[@]}" --command "update public.team_memberships set status='active' where id='$(uuid membership-scorer)'" >>"$race_dir/phase5a-authority-restore.out"
race module_revocation_wait "$event_lock update public.organization_modules set configuration=configuration||'{\"game_operations\":false}' where organization_id='$(uuid org)' and module_id=(select id from public.modules where key='sports');" "$scorer$(command game.score.set race-authority '{"primary_score":1,"opponent_score":0}' module-revocation-loser "$v")" PT403
"${psql_cmd[@]}" --command "update public.organization_modules set configuration=configuration||'{\"game_operations\":true}' where organization_id='$(uuid org)' and module_id=(select id from public.modules where key='sports')" >>"$race_dir/phase5a-authority-restore.out"
assert_sql 'authority changes leave no unauthorized score action' "select primary_score=0 and opponent_score=0 and not exists(select 1 from public.game_operations where game_id=games.id and operation='game.score.set') from public.games where id='$(game_id race-authority)'"
run_op game.score.set race-authority '{"primary_score":3,"opponent_score":1}' reversible-score
score_operation=$("${psql_cmd[@]}" --command "select id from public.game_operations where game_id='$(game_id race-authority)' and operation='game.score.set'")
v=$(version race-authority)
reverse="{\"operation_id\":\"$score_operation\"}"
race concurrent_reverse "$admin$(command game.score.reverse race-authority "$reverse" reverse-one "$v")" "$admin$(command game.score.reverse race-authority "$reverse" reverse-two "$v")" PT409
assert_sql 'concurrent reverse appends one correction and retains source action' "select primary_score=0 and opponent_score=0 and (select count(*)=1 from public.game_operations where game_id=games.id and correction_of='$score_operation') and exists(select 1 from public.game_operations where id='$score_operation') from public.games where id='$(game_id race-authority)'"
module_version(){ "${psql_cmd[@]}" --command "select om.version from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id='$(uuid org)' and m.key='sports'"; }
configure_command(){
 local flags=$1 req=$2 ver=${3:-$(module_version)}
 printf '%s' "select public.boss_games_mutate(md5('boss-phase5a-race-request:$req')::uuid,jsonb_build_object('operation','games.configure','input',jsonb_build_object('organization_id','$(uuid org)','expected_version',$ver,'configuration','$flags'::jsonb)));"
}
mv=$(module_version)
race configure_version "$admin$(configure_command '{"public_game_center":true}' configure-writer "$mv")" "$admin$(configure_command '{"head_coach_game_management":false}' configure-loser "$mv")" PT409
assert_sql 'configuration conflict preserves winning finite flags' "select (om.configuration->>'public_game_center')::boolean and (om.configuration->>'head_coach_game_management')::boolean from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id='$(uuid org)' and m.key='sports'"
v=$(version race-authority)
race configure_operation "$admin$(configure_command '{"game_operations":false}' configure-disable)" "$scorer$(command game.score.set race-authority '{"primary_score":9,"opponent_score":0}' configure-score-loser "$v")" PT403
assert_sql 'configuration disable denies a score waiting on current module authority' "select primary_score=0 and opponent_score=0 and not exists(select 1 from public.game_operations where game_id=games.id and request_id=md5('boss-phase5a-race-request:configure-score-loser')::uuid) from public.games where id='$(game_id race-authority)'"
if ! "${psql_cmd[@]}" --command "begin;$admin$(configure_command '{"game_operations":true}' configure-restore)commit;" >"$race_dir/phase5a-configure-restore.out" 2>"$race_dir/phase5a-configure-restore.err";then diagnostics 'configure restoration' "$race_dir/phase5a-configure-restore.err";fail 'configure restoration';fi
target_role_lock="select 1 from public.role_assignments where id='$(uuid role-scorer)' for update;"
"${psql_cmd[@]}" --command "update auth.sessions set not_after=clock_timestamp()+interval '4 seconds' where id='$(uuid session-admin)'" >>"$race_dir/phase5a-authority-restore.out"
v=$(version race-operator)
race target_role_natural_expiry "$target_role_lock" "$admin$(command game.operator.assign race-operator "$assignment" expired-assign "$v")" PT401 4.5
"${psql_cmd[@]}" --command "update auth.sessions set not_after=null where id='$(uuid session-admin)'" >>"$race_dir/phase5a-authority-restore.out"
assignment_id=$("${psql_cmd[@]}" --command "select id from public.game_operator_assignments where game_id='$(game_id race-authority)' and person_id='$(uuid scorer)' and status='active'")
operator_lock="select 1 from public.game_operator_assignments where id='$assignment_id' for update;"
"${psql_cmd[@]}" --command "update auth.sessions set not_after=clock_timestamp()+interval '4 seconds' where id='$(uuid session-admin)'" >>"$race_dir/phase5a-authority-restore.out"
v=$(version race-authority)
race operator_end_natural_expiry "$operator_lock" "$admin$(command game.operator.end race-authority "{\"assignment_id\":\"$assignment_id\"}" expired-end "$v")" PT401 4.5
"${psql_cmd[@]}" --command "update auth.sessions set not_after=null where id='$(uuid session-admin)'" >>"$race_dir/phase5a-authority-restore.out"
assert_sql 'caller expiry after target locks creates no assignment or removal' "select not exists(select 1 from public.game_operations where request_id in(md5('boss-phase5a-race-request:expired-assign')::uuid,md5('boss-phase5a-race-request:expired-end')::uuid)) and exists(select 1 from public.game_operator_assignments where id='$assignment_id' and status='active')"
assert_sql 'all ledger sequences remain contiguous after races' "select bool_and(actions=max_sequence and min_sequence=1) from (select game_id,count(*) actions,max(sequence) max_sequence,min(sequence) min_sequence from public.game_operations where organization_id='$(uuid org)' group by game_id) finite_games"
printf 'Phase 5A games: %s coordinated two-connection races passed.\n' "$race_count"
