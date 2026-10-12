#!/usr/bin/env bash
# Real blocked two-connection races, only on the disposable private Unix socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
 printf '%s\n' 'Soccer races require the private disposable runner socket.' >&2;exit 1
fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses')='' ") != t ]];then exit 1;fi
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase5C concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
diagnostics(){
 local label=$1 errors=$2
 printf 'Phase5C race failure: %s\n' "$label" >&2
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
 if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%phase5c-writer-ready%'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do
  if [[ -s "$errors" ]] && grep -Eq '(^|[[:space:]])(ERROR|FATAL):' "$errors";then
   diagnostics "$app failed before synchronization" "$errors";return 1
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1;then printf 'Soccer race participant %s exited before synchronization.\n' "$app" >&2;return 1;fi
  if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.025
 done
 printf 'Soccer race participant %s did not reach %s before the fixed eight-second timeout.\n' "$app" "$expected" >&2;return 1
}
race(){
 local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold_seconds=${5:-0} fifo="$race_dir/phase5c-$1.stdin" rc=0
 mkfifo -m 600 "$fifo"
 "${psql_cmd[@]}" <"$fifo" >"$race_dir/phase5c-$label-writer.out" 2>"$race_dir/phase5c-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='boss_phase5c_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase5c-writer-ready */;" >&9
 await_state "boss_phase5c_${label}_writer" ready "$writer_pid" "$race_dir/phase5c-$label-writer.err"
 "${psql_cmd[@]}" --command "set application_name='boss_phase5c_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/phase5c-$label-contender.out" 2>"$race_dir/phase5c-$label-contender.err" & contender_pid=$!
 await_state "boss_phase5c_${label}_contender" waiting "$contender_pid" "$race_dir/phase5c-$label-contender.err"
 # Optional fixed short hold proves natural deadline expiry while the signed
 # caller is already blocked. Every participant keeps the eight-second limit.
 if [[ "$hold_seconds" != 0 ]];then sleep "$hold_seconds";fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false
 if ! wait "$writer_pid";then writer_pid='';diagnostics "$label writer commit" "$race_dir/phase5c-$label-writer.err";fail "$label writer should have committed";fi;writer_pid=''
 if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid=''
 if [[ "$expected" == success && "$rc" != 0 ]];then diagnostics "$label contender" "$race_dir/phase5c-$label-contender.err";fail "$label contender should have succeeded";fi
 if [[ "$expected" != success ]] && { [[ "$rc" == 0 ]] || ! grep -Fq "$expected" "$race_dir/phase5c-$label-contender.err"; };then diagnostics "$label unexpected contender result" "$race_dir/phase5c-$label-contender.err";fail "$label expected $expected";fi
race_count=$((race_count+1))
}
# Each writer and contender invokes the actual canonical RPC in an independent
# PostgreSQL connection. These committed fixtures exist only in this cluster.
# The historical Game Center race keeps its committed evidence until cluster
# removal. Copy its reviewed fixture into this same private run directory and
# change only fixed synthetic identity/email/slug namespaces. Keep both sets of
# evidence intact; do not delete historical rows or alter security controls.
if [[ $(awk '$0=="\\ir ../phase5a/fixture.sql" {n++} END {print n+0}' "$test_dir/phase5c/fixture.sql") != 1 ]];then fail 'Soccer fixture must extend exactly one reviewed Game Center fixture';fi
sed -e 's/boss-phase5a-test:/boss-phase5c-race-base:/g' \
    -e 's/phase5a.example.invalid/phase5c-race.example.invalid/g' \
    -e 's/synthetic-phase5a-/synthetic-phase5c-race-/g' \
    "$test_dir/phase5a/fixture.sql" >"$race_dir/phase5c-race-fixture.sql"
awk '$0!="\\ir ../phase5a/fixture.sql" {gsub(/boss-phase5c-test:/,"boss-phase5c-race-roster:");print}' \
    "$test_dir/phase5c/fixture.sql" >>"$race_dir/phase5c-race-fixture.sql"
cat >"$race_dir/phase5c-race-setup.sql" <<SQL
begin;
\ir '$race_dir/phase5c-race-fixture.sql'
set local role authenticated;select pg_temp.actor('admin');
do \$\$declare label text;begin
 foreach label in array array['goals','replay','final','correction','duplicate-correction','substitution','card-sub','sub-card','duplicate-yellow','duplicate-red','duplicate-save','duplicate-sub','clock-run','clock','segment-goal','goal-segment','authority']loop
  perform pg_temp.sc_create(label);
 end loop;
 perform pg_temp.sc_event('correction','goal','primary',2,'correction-source');
 perform pg_temp.sc_event('duplicate-correction','goal','primary',2,'duplicate-correction-source');
 perform pg_temp.sc_end('final');perform pg_temp.sc_op('soccer.segment.start','final');
 perform pg_temp.game_op('game.operator.assign','authority',jsonb_build_object('person_id',pg_temp.f('scorer'),'role_assignment_id',pg_temp.f('role-scorer'),'function_key','scorekeeper','team_id',pg_temp.f('falcons'),'ends_at',clock_timestamp()+interval '1 hour'));
end\$\$;
commit;
SQL
if ! "${psql_cmd[@]}" --file "$race_dir/phase5c-race-setup.sql" >"$race_dir/phase5c-race-setup.out" 2>"$race_dir/phase5c-race-setup.err";then diagnostics setup "$race_dir/phase5c-race-setup.err";fail 'fixture setup';fi
uuid(){ "${psql_cmd[@]}" --command "select md5('boss-phase5c-race-base:$1')::uuid"; }
game_id(){ "${psql_cmd[@]}" --command "select id from public.games where event_id=md5('boss-phase5c-race-base:event-sc-$1')::uuid"; }
version(){ "${psql_cmd[@]}" --command "select version from public.games where id='$(game_id "$1")'"; }
roster(){
 local label=$1 side=$2 n=$3 person
 if [[ "$n" == 1 ]];then if [[ "$side" == primary ]];then person=$(uuid child1);else person=$(uuid child2);fi
 else person=$("${psql_cmd[@]}" --command "select md5('boss-phase5c-race-roster:$side-player-$n')::uuid");fi
 "${psql_cmd[@]}" --command "select r.id from public.game_roster_snapshots r join public.games g on g.id=r.game_id and g.roster_revision=r.revision where g.id='$(game_id "$label")'and r.person_id='$person'"
}
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase5c-race-base:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase5c-race-base:session-$1')::uuid)::text,true);"; }
command(){
 local op=$1 label=$2 extra=$3 request=$4 ver=${5:-$(version "$2")}
 printf '%s' "select public.boss_games_mutate(md5('boss-phase5c-race-request:$request')::uuid,jsonb_build_object('operation','$op','input',jsonb_build_object('game_id','$(game_id "$label")','expected_version',$ver)||'$extra'::jsonb));"
}
event_extra(){ printf '{"event_type":"%s","side":"%s","roster_id":"%s"}' "$2" "${3:-primary}" "$(roster "$1" "${3:-primary}" "${4:-2}")"; }
sub_extra(){ printf '{"side":"primary","out_roster_id":"%s","in_roster_id":"%s"}' "$(roster "$1" primary "$2")" "$(roster "$1" primary "$3")"; }
admin=$(auth admin);scorer=$(auth scorer)
v=$(version goals)
race goals "$admin$(command soccer.event.add goals "$(event_extra goals goal)" goal-one "$v")" "$admin$(command soccer.event.add goals "$(event_extra goals goal opponent)" goal-two "$v")" PT409
assert_sql 'simultaneous goals retain one winner and one shot outcome' "select primary_score=1 and opponent_score=0 and(select count(*)=1 from public.game_soccer_events where game_id=g.id and event_type='goal')from public.games g where id='$(game_id goals)'"
if ! "${psql_cmd[@]}" --command "begin;$admin$(command soccer.event.add goals "$(event_extra goals goal opponent)" goal-two)commit;" >"$race_dir/phase5c-goal-retry.out" 2>"$race_dir/phase5c-goal-retry.err";then diagnostics 'refreshed goal retry' "$race_dir/phase5c-goal-retry.err";fail 'refreshed loser retry';fi
assert_sql 'refreshed loser contributes once at next sequence' "select primary_score=1 and opponent_score=1 and(select count(*)=2 from public.game_soccer_events where game_id=g.id and event_type='goal')from public.games g where id='$(game_id goals)'"
goal=$(command soccer.event.add replay "$(event_extra replay goal)" goal-replay)
race duplicate_goal "$admin$goal" "$admin$goal" success
assert_sql 'duplicate goal has one fact ledger receipt' "select(select count(*)=1 from public.game_soccer_events where game_id='$(game_id replay)'and request_id=md5('boss-phase5c-race-request:goal-replay')::uuid)and(select count(*)=1 from public.game_operations where game_id='$(game_id replay)'and request_id=md5('boss-phase5c-race-request:goal-replay')::uuid)and(select count(*)=1 from boss_private.game_operation_receipts where request_id=md5('boss-phase5c-race-request:goal-replay')::uuid)"
v=$(version final)
final_writer="$admin$(command soccer.clock.set final '{"clock_ms":60000,"reason":"Synthetic final segment"}' final-clock "$v")$(command soccer.segment.end final '{}' final-end "$((v+1))")$(command game.finalize final '{}' final-seal "$((v+2))")"
race finalization_goal "$final_writer" "$admin$(command soccer.event.add final "$(event_extra final goal)" final-late "$v")" PT409
assert_sql 'final seal wins before waiting late goal' "select status='final'and primary_score=0 and(select count(*)=1 from public.game_soccer_finalizations where game_id=g.id)and not exists(select 1 from public.game_soccer_events where game_id=g.id and request_id=md5('boss-phase5c-race-request:final-late')::uuid)from public.games g where id='$(game_id final)'"
target=$("${psql_cmd[@]}" --command "select id from public.game_soccer_events where game_id='$(game_id correction)'and event_type='goal'")
v=$(version correction);correct="{\"event_id\":\"$target\",\"event_type\":\"penalty_goal\",\"side\":\"primary\",\"roster_id\":\"$(roster correction primary 2)\",\"reason\":\"Synthetic same-score correction\"}"
race goal_correction "$admin$(command soccer.event.correct correction "$correct" correction-one "$v")" "$admin$(command soccer.event.add correction "$(event_extra correction goal)" correction-two "$v")" PT409
assert_sql 'correction preserves source plus one typed replacement and exact score' "select primary_score=1 and(select count(*)=1 from public.game_soccer_events where correction_of='$target'and event_type='penalty_goal')and exists(select 1 from public.game_soccer_events where id='$target'and event_type='goal')from public.games where id='$(game_id correction)'"
v=$(version substitution)
race substitutions "$admin$(command soccer.substitute substitution "$(sub_extra substitution 11 12)" sub-one "$v")" "$admin$(command soccer.substitute substitution "$(sub_extra substitution 10 12)" sub-two "$v")" PT409
assert_sql 'competing substitutions retain eleven distinct winner slots' "select count(*)=11 and count(distinct roster_id)=11 and bool_or(roster_id='$(roster substitution primary 12)')and not bool_or(roster_id='$(roster substitution primary 11)')from public.game_soccer_lineups where game_id='$(game_id substitution)'and side='primary'"
v=$(version card-sub)
race red_substitution "$admin$(command soccer.event.add card-sub "$(event_extra card-sub red_card primary 11)" red-first "$v")" "$admin$(command soccer.substitute card-sub "$(sub_extra card-sub 11 12)" red-sub-second "$v")" PT409
assert_sql 'dismissal blocks field slot with no losing replacement' "select count(*)=11 and count(*)filter(where dismissed)=1 and not bool_or(roster_id='$(roster card-sub primary 12)')from public.game_soccer_lineups where game_id='$(game_id card-sub)'and side='primary'"
v=$(version sub-card)
race substitution_red "$admin$(command soccer.substitute sub-card "$(sub_extra sub-card 11 12)" sub-red-first "$v")" "$admin$(command soccer.event.add sub-card "$(event_extra sub-card red_card primary 11)" sub-red-second "$v")" PT409
assert_sql 'winning substitution cannot partially apply losing red card' "select not exists(select 1 from public.game_soccer_events where game_id='$(game_id sub-card)'and event_type='red_card')and exists(select 1 from public.game_soccer_lineups where game_id='$(game_id sub-card)'and roster_id='$(roster sub-card primary 12)'and not dismissed)"
for kind in yellow_card red_card;do
 if [[ "$kind" == yellow_card ]];then label=duplicate-yellow;else label=duplicate-red;fi
 cmd=$(command soccer.event.add "$label" "$(event_extra "$label" "$kind")" "$kind-replay")
 race "duplicate_$kind" "$admin$cmd" "$admin$cmd" success
 assert_sql "duplicate $kind appends one discipline fact" "select count(*)=1 from public.game_soccer_events where game_id='$(game_id "$label")'and event_type='$kind'"
done
save="{\"event_type\":\"shot_saved\",\"side\":\"opponent\",\"roster_id\":\"$(roster duplicate-save opponent 2)\",\"goalkeeper_roster_id\":\"$(roster duplicate-save primary 1)\"}"
cmd=$(command soccer.event.add duplicate-save "$save" save-replay)
race duplicate_saved_shot "$admin$cmd" "$admin$cmd" success
assert_sql 'duplicate save outcome counts exactly one shot SOG and save' "select(select shots=1 and shots_on_goal=1 from boss_private.soccer_totals('$(game_id duplicate-save)')where side='opponent'and roster_id is null)and(select saves=1 from boss_private.soccer_totals('$(game_id duplicate-save)')where side='primary'and roster_id='$(roster duplicate-save primary 1)')"
cmd=$(command soccer.substitute duplicate-sub "$(sub_extra duplicate-sub 11 12)" sub-replay)
race duplicate_substitution "$admin$cmd" "$admin$cmd" success
assert_sql 'duplicate substitution adds one participation fact' "select count(*)=1 from public.game_soccer_events where game_id='$(game_id duplicate-sub)'and event_type='substitution'"
v=$(version clock-run)
race clock_start_stop "$admin$(command soccer.clock.start clock-run '{}' clock-start "$v")" "$admin$(command soccer.clock.stop clock-run '{}' clock-stop "$v")" PT409
assert_sql 'clock collision keeps winner running state' "select clock_running and clock_anchor is not null from public.game_soccer_states where game_id='$(game_id clock-run)'"
v=$(version clock)
race clock_correction "$admin$(command soccer.clock.set clock '{"clock_ms":42000,"reason":"Synthetic winning clock"}' clock-one "$v")" "$admin$(command soccer.clock.set clock '{"clock_ms":17000,"reason":"Synthetic stale clock"}' clock-two "$v")" PT409
assert_sql 'clock correction keeps exact monotonic winner sample' "select clock_elapsed_ms=42000 and not clock_running and participation_complete from public.game_soccer_states where game_id='$(game_id clock)'"
v=$(version segment-goal)
race segment_goal "$admin$(command soccer.clock.set segment-goal '{"clock_ms":60000,"reason":"Synthetic segment boundary"}' segment-clock "$v")$(command soccer.segment.end segment-goal '{}' segment-one "$((v+1))")" "$admin$(command soccer.event.add segment-goal "$(event_extra segment-goal goal)" segment-two "$v")" PT409
assert_sql 'ended segment denies waiting goal contribution' "select s.segment_status='ended'and g.primary_score=0 from public.games g join public.game_soccer_states s on s.game_id=g.id where g.id='$(game_id segment-goal)'"
v=$(version goal-segment)
race goal_segment "$admin$(command soccer.event.add goal-segment "$(event_extra goal-segment goal)" goal-segment-one "$v")" "$admin$(command soccer.segment.end goal-segment '{}' goal-segment-two "$v")" PT409
assert_sql 'winning goal does not silently close segment' "select s.segment_status='active'and g.primary_score=1 from public.games g join public.game_soccer_states s on s.game_id=g.id where g.id='$(game_id goal-segment)'"
assignment=$("${psql_cmd[@]}" --command "select id from public.game_operator_assignments where game_id='$(game_id authority)'and person_id='$(uuid scorer)'and status='active'")
v=$(version authority)
race operator_revoke "$admin$(command game.operator.end authority "{\"assignment_id\":\"$assignment\"}" revoke-operator "$v")" "$scorer$(command soccer.event.add authority "$(event_extra authority goal)" revoked-goal "$v")" PT403
assert_sql 'revoked waiting exact operator adds no goal' "select primary_score=0 and not exists(select 1 from public.game_soccer_events where game_id=g.id and event_type='goal')from public.games g where id='$(game_id authority)'"
"${psql_cmd[@]}" --command "update public.game_operator_assignments set status='active',ends_at=clock_timestamp()+interval '1 hour'where id='$assignment'" >"$race_dir/phase5c-authority-restore.out"
event_lock="select 1 from public.events where id='$(uuid event-sc-authority)'for update;"
v=$(version authority)
race role_revoke "$event_lock update public.role_assignments set status='inactive'where id='$(uuid role-scorer)';" "$scorer$(command soccer.event.add authority "$(event_extra authority goal)" role-revoked-goal "$v")" PT403
"${psql_cmd[@]}" --command "update public.role_assignments set status='active'where id='$(uuid role-scorer)'" >>"$race_dir/phase5c-authority-restore.out"
race membership_revoke "$event_lock update public.team_memberships set status='inactive'where id='$(uuid membership-scorer)';" "$scorer$(command soccer.event.add authority "$(event_extra authority goal)" member-revoked-goal "$v")" PT403
"${psql_cmd[@]}" --command "update public.team_memberships set status='active'where id='$(uuid membership-scorer)'" >>"$race_dir/phase5c-authority-restore.out"
race operator_expiry "$event_lock update public.game_operator_assignments set ends_at=clock_timestamp()+interval '0.25 seconds'where id='$assignment';" "$scorer$(command soccer.event.add authority "$(event_extra authority goal)" expired-goal "$v")" PT403 0.5
"${psql_cmd[@]}" --command "update public.game_operator_assignments set ends_at=clock_timestamp()+interval '1 hour'where id='$assignment'" >>"$race_dir/phase5c-authority-restore.out"
race role_expiry "$event_lock update public.role_assignments set ends_at=clock_timestamp()+interval '0.25 seconds'where id='$(uuid role-scorer)';" "$scorer$(command soccer.event.add authority "$(event_extra authority goal)" role-expired-goal "$v")" PT403 0.5
"${psql_cmd[@]}" --command "update public.role_assignments set ends_at=null where id='$(uuid role-scorer)'" >>"$race_dir/phase5c-authority-restore.out"
race session_expiry "$event_lock update auth.sessions set not_after=clock_timestamp()+interval '0.25 seconds'where id='$(uuid session-scorer)';" "$scorer$(command soccer.event.add authority "$(event_extra authority goal)" session-expired-goal "$v")" PT401 0.5
"${psql_cmd[@]}" --command "update auth.sessions set not_after=null where id='$(uuid session-scorer)'" >>"$race_dir/phase5c-authority-restore.out"
module_version=$("${psql_cmd[@]}" --command "select om.version from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id='$(uuid org)'and m.key='sports'")
configure="select public.boss_games_mutate(md5('boss-phase5c-race-request:disable-feature')::uuid,jsonb_build_object('operation','games.configure','input',jsonb_build_object('organization_id','$(uuid org)','expected_version',$module_version,'configuration',jsonb_build_object('soccer_live_scoring',false))));"
race feature_disable "$admin$configure" "$scorer$(command soccer.event.add authority "$(event_extra authority goal)" feature-disabled-goal "$v")" PT403
assert_sql 'feature change while blocked adds no Soccer goal' "select primary_score=0 and not exists(select 1 from public.game_soccer_events where game_id=g.id and event_type='goal')from public.games g where id='$(game_id authority)'"
"${psql_cmd[@]}" --command "update public.organization_modules set configuration=configuration||'{\"soccer_live_scoring\":true}'where organization_id='$(uuid org)'and module_id=(select id from public.modules where key='sports')" >>"$race_dir/phase5c-authority-restore.out"
target=$("${psql_cmd[@]}" --command "select id from public.game_soccer_events where game_id='$(game_id duplicate-correction)'and event_type='goal'")
cmd=$(command soccer.event.reverse duplicate-correction "{\"event_id\":\"$target\",\"reason\":\"Synthetic duplicate correction\"}" correction-replay)
race duplicate_correction "$admin$cmd" "$admin$cmd" success
assert_sql 'duplicate reversal adds one linked fact and zero goals' "select primary_score=0 and(select count(*)=1 from public.game_soccer_events where correction_of='$target')from public.games where id='$(game_id duplicate-correction)'"
assert_sql 'all Soccer race games retain one contiguous ledger' "select bool_and(valid)from(select count(*)=max(o.sequence)and min(o.sequence)=1 and count(distinct o.version)=count(*)valid from public.games g join public.game_operations o on o.game_id=g.id where g.event_id in(select id from public.events where title like 'Synthetic Soccer %')and g.organization_id='$(uuid org)'group by g.id)x"
printf 'Phase5C Soccer concurrency assertions passed: %s\n' "$race_count"
