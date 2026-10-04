#!/usr/bin/env bash
# Two-connection receipt/version/Calendar races, private disposable socket only.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Set by disposable runner}"
: "${PGHOST:?Set by disposable runner}"
: "${PGPORT:?Set by disposable runner}"
: "${PGDATABASE:?Set by disposable runner}"
: "${PGUSER:?Set by disposable runner}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
  printf '%s\n' 'Attendance races require the private disposable runner socket.' >&2; exit 1
fi
test_run_dir=${PGHOST%/socket}
psql_command=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --quiet --no-align --tuples-only)
if [[ $("${psql_command[@]}" --command "select current_setting('listen_addresses')='' ") != t ]]; then exit 1;fi
writer_pid='';contender_pid='';writer_open=false
cleanup() {
  local code=$?;trap - EXIT INT TERM
  if [[ "$writer_open" == true ]];then exec 9>&-;fi
  for pid in "$writer_pid" "$contender_pid";do if [[ -n "$pid" ]];then kill "$pid" >/dev/null 2>&1 || true;wait "$pid" >/dev/null 2>&1 || true;fi;done
  exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
wait_state() {
 local app=$1 state=$2 deadline=$((SECONDS+15)) query
 if [[ "$state" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do if [[ $("${psql_command[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.05;done
 printf 'Attendance race did not synchronize %s.\n' "$app" >&2;return 1
}
race() {
 local label=$1 writer_sql=$2 contender_sql=$3 should_block=$4
 local fifo="$test_run_dir/phase4b-attendance-$label.stdin"
 mkfifo "$fifo"
 "${psql_command[@]}" <"$fifo" >"$test_run_dir/phase4b-attendance-$label-writer.out" 2>"$test_run_dir/phase4b-attendance-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";writer_open=true
 printf '%s\n' "set application_name='boss_phase4b_${label}_writer';begin;$writer_sql" >&9
 wait_state "boss_phase4b_${label}_writer" ready
 "${psql_command[@]}" --command "set application_name='boss_phase4b_${label}_contender';set statement_timeout='20s';begin;$contender_sql commit;" >"$test_run_dir/phase4b-attendance-$label-contender.out" 2>"$test_run_dir/phase4b-attendance-$label-contender.err" & contender_pid=$!
 if [[ "$should_block" == true ]];then wait_state "boss_phase4b_${label}_contender" lock;else wait "$contender_pid";contender_pid='';fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;writer_open=false
 wait "$writer_pid";writer_pid=''
 if [[ -n "$contender_pid" ]];then wait "$contender_pid";contender_pid='';fi
}
"${psql_command[@]}" --command "
begin;
insert into auth.users(id,email,email_confirmed_at) values('b4e10000-0000-4000-8000-000000000001','synthetic-attendance-race@phase4b.example.invalid',now()-interval '2 days');
insert into auth.sessions(id,user_id) values('b4e20000-0000-4000-8000-000000000001','b4e10000-0000-4000-8000-000000000001');
insert into public.people(id,display_name) values('b4e30000-0000-4000-8000-000000000001','Synthetic attendance admin'),('b4e30000-0000-4000-8000-000000000002','Synthetic attendance dependent');
insert into public.user_accounts(auth_user_id,person_id,account_status) values('b4e10000-0000-4000-8000-000000000001','b4e30000-0000-4000-8000-000000000001','active');
insert into public.organizations(id,name,slug) values('b4e40000-0000-4000-8000-000000000001','Synthetic attendance race','synthetic-phase4b-attendance-race');
insert into public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at) select 'b4e30000-0000-4000-8000-000000000001',id,'organization','b4e40000-0000-4000-8000-000000000001','b4e40000-0000-4000-8000-000000000001',now()-interval '1 day' from public.roles where key='organization_administrator';
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at) select 'b4e40000-0000-4000-8000-000000000001',id,'active','{\"attendance\":true,\"attendance_rsvp\":true}',now()-interval '1 day' from public.modules where key='calendar';
insert into public.participants(id,person_id) values('b4e35000-0000-4000-8000-000000000002','b4e30000-0000-4000-8000-000000000002');
insert into public.organization_memberships(organization_id,person_id,starts_at) values('b4e40000-0000-4000-8000-000000000001','b4e30000-0000-4000-8000-000000000002',now()-interval '1 day');
insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,timezone,status,rsvp_mode,created_by_person_id,updated_by_person_id) values('b4e50000-0000-4000-8000-000000000001','b4e40000-0000-4000-8000-000000000001','Synthetic attendance race','practice',date_trunc('day',now())+interval '10 days 18 hours',date_trunc('day',now())+interval '10 days 19 hours','UTC','scheduled','required','b4e30000-0000-4000-8000-000000000001','b4e30000-0000-4000-8000-000000000001');
insert into public.event_targets(event_id,organization_id,target_type,target_id) values('b4e50000-0000-4000-8000-000000000001','b4e40000-0000-4000-8000-000000000001','organization','b4e40000-0000-4000-8000-000000000001');
commit;" >"$test_run_dir/phase4b-attendance-race-setup.out"
claims='{"sub":"b4e10000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"b4e20000-0000-4000-8000-000000000001"}'
authenticate="set local role authenticated;select set_config('request.jwt.claims','$claims',true);"
key=$("${psql_command[@]}" --command "select to_char((date_trunc('day',now())+interval '10 days 18 hours') at time zone 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS')")
command() {
 local status=$1 version=$2 request=$3
 printf '%s' "select public.boss_attendance_mutate('{\"operation\":\"response.set\",\"input\":{\"event_id\":\"b4e50000-0000-4000-8000-000000000001\",\"occurrence_key\":\"$key\",\"person_id\":\"b4e30000-0000-4000-8000-000000000002\",\"participant_id\":\"b4e35000-0000-4000-8000-000000000002\",\"subject_kind\":\"participant\",\"status\":\"$status\",\"expected_version\":$version}}','$request');"
}
first=$(command attending 0 b4e60000-0000-4000-8000-000000000001)
race receipt "$authenticate$first" "$authenticate$first" true
if [[ $("${psql_command[@]}" --command "select (select count(*)=1 from public.attendance_responses where event_id='b4e50000-0000-4000-8000-000000000001') and (select count(*)=1 from public.attendance_response_history where event_id='b4e50000-0000-4000-8000-000000000001') and (select count(*)=1 from boss_private.attendance_operation_receipts where actor_person_id='b4e30000-0000-4000-8000-000000000001')") != t ]];then exit 1;fi
writer=$(command maybe 1 b4e60000-0000-4000-8000-000000000002)
contender=$(command not_attending 1 b4e60000-0000-4000-8000-000000000003)
# The loser must be a safe optimistic conflict, with no receipt/history side effect.
wrapped="do \$\$ begin begin $contender raise exception 'Missing expected conflict';exception when sqlstate 'PT409' then raise notice 'EXPECTED_ATTENDANCE_CONFLICT';end;end \$\$;"
race version "$authenticate$writer" "$authenticate$wrapped" true
if ! grep -Fq EXPECTED_ATTENDANCE_CONFLICT "$test_run_dir/phase4b-attendance-version-contender.err";then exit 1;fi
if [[ $("${psql_command[@]}" --command "select (select count(*)=2 from public.attendance_response_history where event_id='b4e50000-0000-4000-8000-000000000001') and not exists(select 1 from boss_private.attendance_operation_receipts where request_id='b4e60000-0000-4000-8000-000000000003')") != t ]];then exit 1;fi
writer=$(command attending 2 b4e60000-0000-4000-8000-000000000004)
change="update public.events set start_at=start_at+interval '1 hour',end_at=end_at+interval '1 hour',version=version+1 where id='b4e50000-0000-4000-8000-000000000001';"
race calendar "$authenticate$writer" "$change" true
if [[ $("${psql_command[@]}" --command "select (select count(*)=4 from public.attendance_response_history where event_id='b4e50000-0000-4000-8000-000000000001') and (select needs_reconfirmation and version=4 from public.attendance_responses where event_id='b4e50000-0000-4000-8000-000000000001')") != t ]];then exit 1;fi
printf '%s\n' 'Attendance concurrency: 3 true two-connection races passed (receipt replay, optimistic version, Calendar context change).'
