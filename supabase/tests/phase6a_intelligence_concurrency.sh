#!/usr/bin/env bash
# Real blocked two-connection races, only on the disposable private Unix socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
 printf '%s\n' 'Intelligence races require the private disposable runner socket.' >&2;exit 1
fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses')='' ") != t ]];then exit 1;fi
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase6A concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
diagnostics(){
 local label=$1 errors=$2
 printf 'Phase6A race failure: %s\n' "$label" >&2
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
 if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%phase6a-writer-ready%'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do
  if [[ -s "$errors" ]] && grep -Eq '(^|[[:space:]])(ERROR|FATAL):' "$errors";then
   diagnostics "$app failed before synchronization" "$errors";return 1
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1;then printf 'Intelligence race participant %s exited before synchronization.\n' "$app" >&2;return 1;fi
  if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.025
 done
 printf 'Intelligence race participant %s did not reach %s before the fixed eight-second timeout.\n' "$app" "$expected" >&2;return 1
}
race(){
 local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold_seconds=${5:-0} fifo="$race_dir/phase6a-$1.stdin" rc=0
 mkfifo -m 600 "$fifo"
 "${psql_cmd[@]}" <"$fifo" >"$race_dir/phase6a-$label-writer.out" 2>"$race_dir/phase6a-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='boss_phase6a_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase6a-writer-ready */;" >&9
 await_state "boss_phase6a_${label}_writer" ready "$writer_pid" "$race_dir/phase6a-$label-writer.err"
 "${psql_cmd[@]}" --command "set application_name='boss_phase6a_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/phase6a-$label-contender.out" 2>"$race_dir/phase6a-$label-contender.err" & contender_pid=$!
 await_state "boss_phase6a_${label}_contender" waiting "$contender_pid" "$race_dir/phase6a-$label-contender.err"
 # Optional fixed short hold proves natural deadline expiry while the signed
 # caller is already blocked. Every participant keeps the eight-second limit.
 if [[ "$hold_seconds" != 0 ]];then sleep "$hold_seconds";fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false
 if ! wait "$writer_pid";then writer_pid='';diagnostics "$label writer commit" "$race_dir/phase6a-$label-writer.err";fail "$label writer should have committed";fi;writer_pid=''
 if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid=''
 if [[ "$expected" == success && "$rc" != 0 ]];then diagnostics "$label contender" "$race_dir/phase6a-$label-contender.err";fail "$label contender should have succeeded";fi
 if [[ "$expected" != success ]] && { [[ "$rc" == 0 ]] || ! grep -Fq "$expected" "$race_dir/phase6a-$label-contender.err"; };then diagnostics "$label unexpected contender result" "$race_dir/phase6a-$label-contender.err";fail "$label expected $expected";fi
race_count=$((race_count+1))
}

# Real canonical fixture, committed only inside the private disposable socket.
sed -e 's/boss-phase5a-test:/boss-phase6a-race-base:/g' -e 's/phase5a.example.invalid/phase6a-race.example.invalid/g' -e 's/synthetic-phase5a-/synthetic-phase6a-race-/g' "$test_dir/phase5a/fixture.sql" >"$race_dir/phase6a-fixture.sql"
awk '$0!="\\ir ../phase5a/fixture.sql" {gsub(/boss-phase5d-test:/,"boss-phase6a-race-roster:");print}' "$test_dir/phase5d/fixture.sql" >>"$race_dir/phase6a-fixture.sql"
awk '$0!="\\ir ../phase5d/fixture.sql" {print}' "$test_dir/phase5f/fixture.sql" >>"$race_dir/phase6a-fixture.sql"
sed -e "s|\\\\ir phase5f/fixture.sql|\\\\ir '$race_dir/phase6a-fixture.sql'|" -e 's/^rollback;$/commit;/' "$test_dir/phase6a_lifecycle.sql" >"$race_dir/phase6a-setup.sql"

if ! "${psql_cmd[@]}" --file "$race_dir/phase6a-setup.sql" >"$race_dir/phase6a-setup.out" 2>"$race_dir/phase6a-setup.err";then diagnostics setup "$race_dir/phase6a-setup.err";fail setup;fi
gid=$("${psql_cmd[@]}" --command "select id from public.games where event_id=md5('boss-phase6a-race-base:event-ff-aggregate')::uuid")
[[ -n "$gid" ]] || fail 'canonical game missing'
parent=$("${psql_cmd[@]}" --command "select md5('boss-phase6a-race-base:parent')::uuid")
child=$("${psql_cmd[@]}" --command "select md5('boss-phase6a-race-base:child1')::uuid")
org=$("${psql_cmd[@]}" --command "select md5('boss-phase6a-race-base:org')::uuid")
team=$("${psql_cmd[@]}" --command "select md5('boss-phase6a-race-base:falcons')::uuid")
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase6a-race-base:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase6a-race-base:session-$1')::uuid)::text,true);"; }
lockgame="select id from public.games where id='$gid'for update;"
refresh="select boss_private.stat_refresh('$gid');"
command(){ printf '%s' "reset role;select set_config('boss.phase6a_test_version',(select version::text from public.games where id='$gid'),true);$(auth admin)select public.boss_games_mutate(gen_random_uuid(),jsonb_build_object('operation','$1','input',jsonb_build_object('game_id','$gid','expected_version',current_setting('boss.phase6a_test_version')::bigint)||case when '$1'='game.reopen'then jsonb_build_object('reason','Synthetic intelligence concurrency')else '{}'::jsonb end));"; }
# Actual signed canonical reopen/finalize operations, not simulated generation labels.
"${psql_cmd[@]}" --command "begin;$(command game.reopen)commit;" >"$race_dir/phase6a-open.out"
race finalization_refresh "$(command game.finalize)" "$refresh" success
race refinalization_refresh "$(command game.reopen)$(command game.finalize)" "$refresh" success
race two_refresh_workers "$lockgame update public.stat_game_selections set generation=generation+1 where game_id='$gid';$refresh" "$refresh" success
race epoch_supersession_refresh "$(command game.reopen)" "$refresh" success
assert_sql 'reopen has no current contribution' "select finalization_id is null from public.stat_game_selections where game_id='$gid'"
race second_rapid_refinalization "$(command game.finalize)" "$refresh" success
race sealed_classification_change_denied "$lockgame $refresh" "$(auth admin)select public.boss_stat_competition_classify('$gid','excluded','Synthetic forbidden sealed change',gen_random_uuid());" PT409

query="jsonb_build_object('person_id','$child','sport_key','baseball')"
race guardian_revoked_read "update public.guardian_relationships set authority_status='inactive'where guardian_person_id='$parent'and dependent_person_id='$child';" "$(auth parent)select public.boss_athlete_career_read($query);" PT403
"${psql_cmd[@]}" --command "update public.guardian_relationships set authority_status='active'where guardian_person_id='$parent'and dependent_person_id='$child';"
"${psql_cmd[@]}" --command "begin;$(auth parent)select public.boss_athlete_career_read($query);commit;" >"$race_dir/phase6a-restored-read.out"
season=$("${psql_cmd[@]}" --command "select season_id from public.games where id='$gid'")
rebuild="$(auth admin)select public.boss_stat_rebuild(jsonb_build_object('organization_id','$org','team_id','$team','sport_key','baseball','season_id','$season'),'team_season');"
race two_rebuild_workers "$rebuild" "$rebuild" success
# A committed dirty selector forces a real signed read refresh to contend with
# the canonical operation whose deferred trigger performs eager refresh.
"${psql_cmd[@]}" --command "update public.stat_game_selections set generation=generation+1 where game_id='$gid';"
race read_refresh_vs_eager "$(command game.reopen)$(command game.finalize)" "$(auth parent)select public.boss_athlete_career_read($query);" success
race season_identity_change_denied "$lockgame $refresh" "update public.games set season_id=null where id='$gid';" 23514
# Existing exact-team authority is rechecked after the membership row wait.
"${psql_cmd[@]}" --command "update public.events set visibility='member'where id=(select event_id from public.games where id='$gid');"
coach=$("${psql_cmd[@]}" --command "select md5('boss-phase6a-race-base:coach')::uuid")
team_query="jsonb_build_object('organization_id','$org','team_id','$team','season_id','$season','sport_key','baseball')"
race team_membership_ended_read "update public.team_memberships set status='inactive',ends_at=clock_timestamp()where person_id='$coach'and team_id='$team';" "$(auth coach)select public.boss_team_season_read($team_query);" PT403
"${psql_cmd[@]}" --command "update public.team_memberships set status='active',ends_at=null where person_id='$coach'and team_id='$team';"
assert_sql 'sole current epoch preserved' "select count(*)=1 from public.stat_game_selections where game_id='$gid'and finalization_id is not null and generation=refreshed_generation"
assert_sql 'no residual pending work' "select count(*)=0 from public.stat_refresh_work where game_id='$gid'"
printf 'Phase6A coordinated concurrency races passed: %s\n' "$race_count"
