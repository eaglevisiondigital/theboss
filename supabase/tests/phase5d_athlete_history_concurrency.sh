#!/usr/bin/env bash
# Two genuine history-read/guardian races on the disposable private Unix socket.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
 printf '%s\n' 'Athlete-history races require the private disposable runner socket.' >&2;exit 1
fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_cmd[@]}" --command "select current_setting('listen_addresses')=''") != t ]];then exit 1;fi
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done;exit "$result";}
trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase5D athlete-history concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
diagnostics(){
 local label=$1 errors=$2
 printf 'Phase5D athlete-history race failure: %s\n' "$label" >&2
 # Print only primary SQLSTATE/message, never SQL bodies or local Auth claims.
 if [[ -s "$errors" ]];then awk '/(ERROR|FATAL):/ {line=$0;sub(/^.*(ERROR|FATAL):[[:space:]]*/,"",line);print "PostgreSQL: "substr(line,1,500);exit}' "$errors" >&2;fi
}
assert_sql(){ if [[ $("${psql_cmd[@]}" --command "$2") != t ]];then fail "$1";fi; }
await_state(){
 local app=$1 expected=$2 pid=$3 errors=$4 deadline=$((SECONDS+8)) query
 if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction' and query like '%history-writer-ready%'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do
  if [[ -s "$errors" ]] && grep -Eq '(^|[[:space:]])(ERROR|FATAL):' "$errors";then diagnostics "$app synchronization" "$errors";return 1;fi
  if ! kill -0 "$pid" >/dev/null 2>&1;then fail "$app exited before synchronization";fi
  if [[ $("${psql_cmd[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.025
 done
 fail "$app failed fixed lock synchronization deadline"
}
race(){
 local label=$1 writer_sql=$2 contender_sql=$3 hold_seconds=${4:-0} fifo="$race_dir/history-$1.stdin" rc=0
 mkfifo -m 600 "$fifo"
 "${psql_cmd[@]}" <"$fifo" >"$race_dir/history-$label-writer.out" 2>"$race_dir/history-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='boss_history_${label}_writer';set statement_timeout='12s';begin;$writer_sql select 1 /* history-writer-ready */;" >&9
 await_state "boss_history_${label}_writer" ready "$writer_pid" "$race_dir/history-$label-writer.err"
 "${psql_cmd[@]}" --command "set application_name='boss_history_${label}_reader';set statement_timeout='12s';begin;$contender_sql commit;" >"$race_dir/history-$label-reader.out" 2>"$race_dir/history-$label-reader.err" & contender_pid=$!
 await_state "boss_history_${label}_reader" waiting "$contender_pid" "$race_dir/history-$label-reader.err"
 if [[ "$hold_seconds" != 0 ]];then sleep "$hold_seconds";fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false
 if ! wait "$writer_pid";then writer_pid='';diagnostics "$label writer" "$race_dir/history-$label-writer.err";fail "$label writer commit";fi;writer_pid=''
 if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid=''
 if [[ "$rc" == 0 ]] || ! grep -Fq PT403 "$race_dir/history-$label-reader.err";then diagnostics "$label reader" "$race_dir/history-$label-reader.err";fail "$label must deny after lock wait";fi
 race_count=$((race_count+1))
}
if [[ $(awk '$0=="\\ir ../phase5a/fixture.sql" {n++} END {print n+0}' "$test_dir/phase5d/fixture.sql") != 1 ]];then fail 'Football fixture must extend exactly one canonical fixture';fi
sed -e 's/boss-phase5a-test:/boss-phase5d-history-race-base:/g' \
    -e 's/phase5a.example.invalid/phase5d-history-race.example.invalid/g' \
    -e 's/synthetic-phase5a-/synthetic-phase5d-history-race-/g' \
    "$test_dir/phase5a/fixture.sql" >"$race_dir/history-race-fixture.sql"
awk '$0!="\\ir ../phase5a/fixture.sql" {gsub(/boss-phase5d-test:/,"boss-phase5d-history-race-roster:");print}' \
    "$test_dir/phase5d/fixture.sql" >>"$race_dir/history-race-fixture.sql"
cat >"$race_dir/history-race-setup.sql" <<SQL
begin;
\ir '$race_dir/history-race-fixture.sql'
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('history-race');
select pg_temp.ff_finish('history-race');select pg_temp.game_op('game.finalize','history-race');
select pg_temp.actor('parent');
select pg_temp.check('real sealed history baseline','RACE',jsonb_array_length(public.boss_athlete_history_read(jsonb_build_object('child_person_id',pg_temp.f('child1')))->'records')=1);
commit;
SQL
if ! "${psql_cmd[@]}" --file "$race_dir/history-race-setup.sql" >"$race_dir/history-race-setup.out" 2>"$race_dir/history-race-setup.err";then diagnostics setup "$race_dir/history-race-setup.err";fail 'fixture setup';fi
uuid(){ "${psql_cmd[@]}" --command "select md5('boss-phase5d-history-race-base:$1')::uuid"; }
auth_parent="set local role authenticated;do \$\$begin perform set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase5d-history-race-base:auth-parent')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase5d-history-race-base:session-parent')::uuid)::text,true);end\$\$;"
reader="$auth_parent select jsonb_array_length(public.boss_athlete_history_read(jsonb_build_object('child_person_id','$(uuid child1)'::uuid))->'records');"
guardian=$(uuid guardian-child1)
race guardian_revocation "update public.guardian_relationships set authority_status='inactive',ends_at=clock_timestamp() where id='$guardian';" "$reader"
assert_sql 'revocation committed and no relationship remained effective' "select authority_status='inactive' and ends_at<=clock_timestamp() from public.guardian_relationships where id='$guardian'"
"${psql_cmd[@]}" --command "update public.guardian_relationships set authority_status='active',ends_at=clock_timestamp()+interval '3 seconds' where id='$guardian'" >"$race_dir/history-expiry-prep.out"
race guardian_natural_expiry "select 1 from public.guardian_relationships where id='$guardian' for update;" "$reader" 4
assert_sql 'bounded guardian expiry was not extended by a lock wait' "select authority_status='active' and ends_at<=clock_timestamp() from public.guardian_relationships where id='$guardian'"
"${psql_cmd[@]}" --command "update public.guardian_relationships set authority_status='inactive' where id='$guardian'" >"$race_dir/history-cleanup.out"
assert_sql 'history race fixture retains no temporary guardian authority' "select authority_status='inactive' from public.guardian_relationships where id='$guardian'"
printf 'Phase5D athlete-history concurrency assertions passed: %s\n' "$race_count"
