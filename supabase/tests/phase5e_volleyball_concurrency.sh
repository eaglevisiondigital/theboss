#!/usr/bin/env bash
# Real blocked two-connection races, only on the disposable private Unix socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
 printf '%s\n' 'Volleyball races require the private disposable runner socket.' >&2;exit 1
fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses')='' ") != t ]];then exit 1;fi
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase5E concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
diagnostics(){
 local label=$1 errors=$2
 printf 'Phase5E race failure: %s\n' "$label" >&2
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
 if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%phase5e-writer-ready%'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do
  if [[ -s "$errors" ]] && grep -Eq '(^|[[:space:]])(ERROR|FATAL):' "$errors";then
   diagnostics "$app failed before synchronization" "$errors";return 1
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1;then printf 'Volleyball race participant %s exited before synchronization.\n' "$app" >&2;return 1;fi
  if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.025
 done
 printf 'Volleyball race participant %s did not reach %s before the fixed eight-second timeout.\n' "$app" "$expected" >&2;return 1
}
race(){
 local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold_seconds=${5:-0} fifo="$race_dir/phase5e-$1.stdin" rc=0
 mkfifo -m 600 "$fifo"
 "${psql_cmd[@]}" <"$fifo" >"$race_dir/phase5e-$label-writer.out" 2>"$race_dir/phase5e-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='boss_phase5e_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase5e-writer-ready */;" >&9
 await_state "boss_phase5e_${label}_writer" ready "$writer_pid" "$race_dir/phase5e-$label-writer.err"
 "${psql_cmd[@]}" --command "set application_name='boss_phase5e_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/phase5e-$label-contender.out" 2>"$race_dir/phase5e-$label-contender.err" & contender_pid=$!
 await_state "boss_phase5e_${label}_contender" waiting "$contender_pid" "$race_dir/phase5e-$label-contender.err"
 # Optional fixed short hold proves natural deadline expiry while the signed
 # caller is already blocked. Every participant keeps the eight-second limit.
 if [[ "$hold_seconds" != 0 ]];then sleep "$hold_seconds";fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false
 if ! wait "$writer_pid";then writer_pid='';diagnostics "$label writer commit" "$race_dir/phase5e-$label-writer.err";fail "$label writer should have committed";fi;writer_pid=''
 if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid=''
 if [[ "$expected" == success && "$rc" != 0 ]];then diagnostics "$label contender" "$race_dir/phase5e-$label-contender.err";fail "$label contender should have succeeded";fi
 if [[ "$expected" != success ]] && { [[ "$rc" == 0 ]] || ! grep -Fq "$expected" "$race_dir/phase5e-$label-contender.err"; };then diagnostics "$label unexpected contender result" "$race_dir/phase5e-$label-contender.err";fail "$label expected $expected";fi
race_count=$((race_count+1))
}
# Separate committed fixture namespace; no remote database can satisfy socket guard.
sed -e 's/boss-phase5a-test:/boss-phase5e-race-base:/g' -e 's/phase5a.example.invalid/phase5e-race.example.invalid/g' -e 's/synthetic-phase5a-/synthetic-phase5e-race-/g' "$test_dir/phase5a/fixture.sql" >"$race_dir/phase5e-race-fixture.sql"
awk '$0!="\\ir ../phase5a/fixture.sql" {gsub(/boss-phase5d-test:/,"boss-phase5e-race-roster:");print}' "$test_dir/phase5d/fixture.sql" >>"$race_dir/phase5e-race-fixture.sql"
awk '$0!="\\ir ../phase5d/fixture.sql" {print}' "$test_dir/phase5e/fixture.sql" >>"$race_dir/phase5e-race-fixture.sql"
cat >"$race_dir/phase5e-race-setup.sql" <<SQL
begin;
\ir '$race_dir/phase5e-race-fixture.sql'
set local role authenticated;select pg_temp.actor('admin');
do \$\$declare label text;i int;begin
foreach label in array array['rallies','set','final','correction','duplicate','authority','profile','start','coverage','snapshot','sub']loop
 if label in('snapshot','start')then
 perform pg_temp.ff_link(label,'internal','falcons','volleyball');
 if label='start'then perform pg_temp.game_op('volleyball.configure',label,'{"configuration":{"best_of":3,"normal_target":3,"deciding_target":2,"win_by_two":true,"court_size":2,"strict_rotation":false,"enforce_lineup":false,"allow_reentry":true,"libero_enabled":false,"libero_can_serve":false}}');end if;
 else perform pg_temp.vv_create(label,label='sub');end if;
end loop;
foreach label in array array['final','correction','coverage']loop
 for i in 1..3 loop perform pg_temp.vv_add(label,'rally','primary','{"outcome":"team_point"}');end loop;
 perform pg_temp.game_op('volleyball.set.start',label,'{"side":"primary"}');
 for i in 1..3 loop perform pg_temp.vv_add(label,'rally','primary','{"outcome":"team_point"}');end loop;
end loop;
for i in 1..2 loop perform pg_temp.vv_add('set','rally','primary','{"outcome":"team_point"}');end loop;
perform pg_temp.game_op('game.operator.assign','authority',jsonb_build_object('person_id',pg_temp.f('scorer'),'role_assignment_id',pg_temp.f('role-scorer'),'function_key','scorekeeper','team_id',pg_temp.f('falcons'),'ends_at',clock_timestamp()+interval '1 hour'));
end\$\$;
commit;
SQL
if ! "${psql_cmd[@]}" --file "$race_dir/phase5e-race-setup.sql" >"$race_dir/phase5e-race-setup.out" 2>"$race_dir/phase5e-race-setup.err";then diagnostics setup "$race_dir/phase5e-race-setup.err";fail 'fixture setup';fi
uuid(){ "${psql_cmd[@]}" --command "select md5('boss-phase5e-race-base:$1')::uuid"; }
game_id(){ "${psql_cmd[@]}" --command "select id from public.games where event_id=md5('boss-phase5e-race-base:event-ff-$1')::uuid"; }
version(){ "${psql_cmd[@]}" --command "select version from public.games where id='$(game_id "$1")'"; }
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase5e-race-base:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase5e-race-base:session-$1')::uuid)::text,true);"; }
command(){ local op=$1 label=$2 extra=$3 request=$4 ver=${5:-$(version "$2")};printf '%s' "select public.boss_games_mutate(md5('boss-phase5e-race-request:$request')::uuid,jsonb_build_object('operation','$op','input',jsonb_build_object('game_id','$(game_id "$label")','expected_version',$ver)||'$extra'::jsonb));"; }
profile(){ local label=$1 request=$2 gv=${3:-$(version "$1")} pv=${4:-$("${psql_cmd[@]}" --command "select coalesce((select version from public.game_tracking_profiles where game_id='$(game_id "$1")'and side='primary'),0)")};printf '%s' "select public.boss_games_mutate(md5('boss-phase5e-race-request:$request')::uuid,jsonb_build_object('operation','tracking.profile.set','input',jsonb_build_object('sport_key','volleyball','scope_type','game','organization_id','$(uuid org)','game_id','$(game_id "$label")','side','primary','expected_game_version',$gv,'expected_profile_version',$pv,'preset','score_only','reason','Synthetic race profile')));"; }
rally='{"event_type":"rally","side":"primary","payload":{"outcome":"team_point"}}'
admin=$(auth admin);scorer=$(auth scorer)
v=$(version rallies)
race simultaneous_rallies "$admin$(command volleyball.event.add rallies "$rally" rally-one "$v")" "$admin$(command volleyball.event.add rallies "$rally" rally-two "$v")" PT409
assert_sql 'one accepted simultaneous rally' "select state->>'primary_points'='1'and(select count(*)=1 from public.game_volleyball_events where game_id=s.game_id and event_type='rally')from public.game_volleyball_states s where game_id='$(game_id rallies)'"
v=$(version set)
race set_completion "$admin$(command volleyball.event.add set "$rally" set-one "$v")" "$admin$(command volleyball.event.add set "$rally" set-two "$v")" PT409
assert_sql 'one completed set' "select state->>'primary_sets'='1'and state->>'set_status'='completed'from public.game_volleyball_states where game_id='$(game_id set)'"
v=$(version final)
race finalization_late_fact "$admin$(command game.finalize final '{}' final-one "$v")" "$admin$(command volleyball.event.add final "$rally" final-two "$v")" PT409
assert_sql 'one immutable epoch plus two tracking seals' "select(select count(*)=1 from public.game_volleyball_finalizations where game_id='$(game_id final)')and(select count(*)=2 from public.game_finalization_tracking_seals where game_id='$(game_id final)')"
target=$("${psql_cmd[@]}" --command "select id from public.game_volleyball_events where game_id='$(game_id correction)'and event_type='rally'order by sequence limit 1")
v=$(version correction)
correction="{\"event_id\":\"$target\",\"event_type\":\"rally\",\"side\":\"primary\",\"payload\":{\"outcome\":\"team_point\"},\"reason\":\"Synthetic corrected fact\"}"
race correction_finalization "$admin$(command volleyball.event.correct correction "$correction" correction-one "$v")" "$admin$(command game.finalize correction '{}' correction-two "$v")" PT409
assert_sql 'correction winner retains source and no losing seal' "select exists(select 1 from public.game_volleyball_events where correction_of='$target')and not exists(select 1 from public.game_volleyball_finalizations where game_id='$(game_id correction)')"
cmd=$(command volleyball.event.add duplicate "$rally" duplicate)
race duplicate_request "$admin$cmd" "$admin$cmd" success
assert_sql 'idempotency exactly one fact and receipt' "select(select count(*)=1 from public.game_volleyball_events where game_id='$(game_id duplicate)'and event_type='rally')and(select count(*)=1 from boss_private.game_operation_receipts where request_id=md5('boss-phase5e-race-request:duplicate')::uuid)"
v=$(version profile);pv=$("${psql_cmd[@]}" --command "select version from public.game_tracking_profiles where game_id='$(game_id profile)'and side='primary'")
race two_profile_edits "$admin$(profile profile profile-one "$v" "$pv")" "$admin$(profile profile profile-two "$v" "$pv")" PT409
assert_sql 'one new profile interval' "select count(*)=2 from public.game_tracking_snapshots where game_id='$(game_id profile)'and side='primary'"
v=$(version rallies)
race midgame_profile_rally "$admin$(profile rallies profile-rally "$v")" "$admin$(command volleyball.event.add rallies "$rally" profile-rally-two "$v")" PT409
v=$(version start)
race profile_scoring_start "$admin$(profile start profile-start "$v" 0)" "$admin$(command game.start start '{}' profile-start-two "$v")" PT409
"${psql_cmd[@]}" --command "begin;$admin$(command game.start start '{}' profile-start-retry)commit;" >"$race_dir/phase5e-start-retry.out"
assert_sql 'started game uses frozen profile' "select status='live'and exists(select 1 from public.game_tracking_snapshots where game_id=g.id and side='primary'and selection->>'preset'='score_only')from public.games g where id='$(game_id start)'"
v=$(version coverage)
race coverage_finalization "$admin$(profile coverage coverage-one "$v")" "$admin$(command game.finalize coverage '{}' coverage-two "$v")" PT409
assert_sql 'losing finalization has no partial seal' "select not exists(select 1 from public.game_finalization_tracking_seals where game_id='$(game_id coverage)')"
orgprofile="select public.boss_games_mutate(md5('boss-phase5e-race-request:org-profile')::uuid,jsonb_build_object('operation','tracking.profile.set','input',jsonb_build_object('sport_key','volleyball','scope_type','organization','organization_id','$(uuid org)','expected_profile_version',0,'preset','essential','reason','Synthetic snapshot race')));"
config='{"configuration":{"best_of":3,"normal_target":3,"deciding_target":2,"win_by_two":true,"court_size":2,"strict_rotation":false,"enforce_lineup":false,"allow_reentry":true,"libero_enabled":false,"libero_can_serve":false}}'
race profile_snapshot "$admin$orgprofile" "$admin$(command volleyball.configure snapshot "$config" snapshot-configure)" success
assert_sql 'snapshot resolves committed organization profile' "select count(*)=2 and bool_and(selection->>'preset'='essential')from public.game_tracking_snapshots where game_id='$(game_id snapshot)'"
assignment=$("${psql_cmd[@]}" --command "select id from public.game_operator_assignments where game_id='$(game_id authority)'and person_id='$(uuid scorer)'and status='active'")
v=$(version authority)
race operator_revocation "$admin$(command game.operator.end authority "{\"assignment_id\":\"$assignment\"}" revoke "$v")" "$scorer$(command volleyball.event.add authority "$rally" revoke-two "$v")" PT403
"${psql_cmd[@]}" --command "update public.game_operator_assignments set status='active',ends_at=clock_timestamp()+interval '1 hour'where id='$assignment'" >"$race_dir/phase5e-restore.out"
event_lock="select 1 from public.events where id='$(uuid event-ff-authority)'for update;"
race natural_operator_expiry "$event_lock update public.game_operator_assignments set ends_at=clock_timestamp()+interval '0.25 seconds'where id='$assignment';" "$scorer$(command volleyball.event.add authority "$rally" expiry "$v")" PT403 0.5
"${psql_cmd[@]}" --command "update public.game_operator_assignments set status='inactive'where id='$assignment'" >>"$race_dir/phase5e-restore.out"
assert_sql 'revoked and expired calls append no facts' "select not exists(select 1 from public.game_volleyball_events where game_id='$(game_id authority)'and event_type='rally')"

roster(){ local label=$1 n=$2 person;if [[ "$n" == 1 ]];then person=$(uuid child1);else person=$("${psql_cmd[@]}" --command "select md5('boss-phase5e-race-roster:primary-player-$n')::uuid");fi;"${psql_cmd[@]}" --command "select r.id from public.game_roster_snapshots r join public.games g on g.id=r.game_id and g.roster_revision=r.revision where g.id='$(game_id "$label")'and r.person_id='$person'"; }
v=$(version sub)
sub="{\"side\":\"primary\",\"payload\":{\"out_roster_id\":\"$(roster sub 1)\",\"in_roster_id\":\"$(roster sub 3)\"}}"
race simultaneous_substitutions "$admin$(command volleyball.substitute sub "$sub" sub-one "$v")" "$admin$(command volleyball.substitute sub "$sub" sub-two "$v")" PT409
assert_sql 'one substitution and exact court slot' "select state->'lineups'->'primary'->>0='$(roster sub 3)'and state->'substitutions'->>'primary'='1'from public.game_volleyball_states where game_id='$(game_id sub)'"
module_version=$("${psql_cmd[@]}" --command "select om.version from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id='$(uuid org)'and m.key='sports'")
feature="select public.boss_games_mutate(md5('boss-phase5e-race-request:feature')::uuid,jsonb_build_object('operation','games.configure','input',jsonb_build_object('organization_id','$(uuid org)','expected_version',$module_version,'configuration',jsonb_build_object('volleyball_live_scoring',false))));"
v=$(version rallies)
race feature_disable "$admin$feature" "$admin$(command volleyball.event.add rallies "$rally" disabled "$v")" PT403
"${psql_cmd[@]}" --command "update public.organization_modules set configuration=configuration||'{\"volleyball_live_scoring\":true}'where organization_id='$(uuid org)'and module_id=(select id from public.modules where key='sports')" >>"$race_dir/phase5e-restore.out"
coach=$(auth coach)
manager="select public.boss_games_mutate(md5('boss-phase5e-race-request:expired-manager')::uuid,jsonb_build_object('operation','tracking.profile.set','input',jsonb_build_object('sport_key','volleyball','scope_type','team','organization_id','$(uuid org)','team_id','$(uuid falcons)','expected_profile_version',0,'preset','essential','reason','Synthetic expired manager')));"
race manager_natural_expiry "select pg_advisory_xact_lock(hashtextextended('tracking-org:volleyball:$(uuid org)',0));update public.role_assignments set ends_at=clock_timestamp()+interval '0.25 seconds'where id='$(uuid role-coach)';" "$coach$manager" PT403 0.5
assert_sql 'expired manager leaves no profile revision' "select not exists(select 1 from public.game_tracking_profiles where scope_type='team'and organization_id='$(uuid org)')"
"${psql_cmd[@]}" --command "update public.role_assignments set ends_at=null where id='$(uuid role-coach)'" >>"$race_dir/phase5e-restore.out"
printf 'Phase5E profile/Volleyball concurrency assertions passed: %s\n' "$race_count"
