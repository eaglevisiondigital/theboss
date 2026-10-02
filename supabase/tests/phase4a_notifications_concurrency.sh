#!/usr/bin/env bash
# Two-connection durable queue/receipt races, private disposable socket only.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Set by disposable runner}"
: "${PGHOST:?Set by disposable runner}"
: "${PGPORT:?Set by disposable runner}"
: "${PGDATABASE:?Set by disposable runner}"
: "${PGUSER:?Set by disposable runner}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
  printf '%s\n' 'Notification races require the private disposable runner socket.' >&2; exit 1
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
"${psql_command[@]}" --command "
begin;
insert into auth.users(id,email,email_confirmed_at) values('a4e10000-0000-4000-8000-000000000001','synthetic-race@phase4a.example.invalid',now()-interval '1 day');
insert into auth.sessions(id,user_id) values('a4e20000-0000-4000-8000-000000000001','a4e10000-0000-4000-8000-000000000001');
insert into public.people(id,display_name) values('a4e30000-0000-4000-8000-000000000001','Synthetic Phase4A queue actor');
insert into public.user_accounts(auth_user_id,person_id,account_status) values('a4e10000-0000-4000-8000-000000000001','a4e30000-0000-4000-8000-000000000001','active');
insert into public.organizations(id,name,slug) values('a4e40000-0000-4000-8000-000000000001','Synthetic notification race','synthetic-phase4a-queue-race');
insert into public.organization_memberships(organization_id,person_id,starts_at) values('a4e40000-0000-4000-8000-000000000001','a4e30000-0000-4000-8000-000000000001',now()-interval '1 day');
insert into public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at) select 'a4e30000-0000-4000-8000-000000000001',id,'organization','a4e40000-0000-4000-8000-000000000001','a4e40000-0000-4000-8000-000000000001',now()-interval '1 day' from public.roles where key='organization_administrator';
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at) select 'a4e40000-0000-4000-8000-000000000001',id,'active','{}',now()-interval '1 day' from public.modules where key in ('messaging','calendar');
insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,status,created_by_person_id,updated_by_person_id) values('a4e50000-0000-4000-8000-000000000001','a4e40000-0000-4000-8000-000000000001','Synthetic queue race','practice',date_trunc('second',now())+interval '1 day',date_trunc('second',now())+interval '1 day 1 hour','scheduled','a4e30000-0000-4000-8000-000000000001','a4e30000-0000-4000-8000-000000000001');
insert into public.event_targets(event_id,organization_id,target_type,target_id) values('a4e50000-0000-4000-8000-000000000001','a4e40000-0000-4000-8000-000000000001','organization','a4e40000-0000-4000-8000-000000000001');
commit;" >"$test_run_dir/phase4a-notification-race-setup.out"
wait_state() {
 local app=$1 state=$2 deadline=$((SECONDS+15)) query
 if [[ "$state" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app' and state='idle in transaction'";
 else query="select count(*) from pg_stat_activity where application_name='$app' and wait_event_type='Lock'";fi
 while ((SECONDS<deadline));do if [[ $("${psql_command[@]}" --command "$query") == 1 ]];then return 0;fi;sleep 0.05;done
 printf 'Notification race did not synchronize %s.\n' "$app" >&2;return 1
}
race() {
 local label=$1 writer_sql=$2 contender_sql=$3 should_block=$4
 local fifo="$test_run_dir/phase4a-notification-$label.stdin"
 mkfifo "$fifo"
 "${psql_command[@]}" <"$fifo" >"$test_run_dir/phase4a-notification-$label-writer.out" 2>"$test_run_dir/phase4a-notification-$label-writer.err" & writer_pid=$!
 exec 9>"$fifo";writer_open=true
 printf '%s\n' "set application_name='boss_phase4a_${label}_writer';begin;$writer_sql" >&9
 wait_state "boss_phase4a_${label}_writer" ready
 "${psql_command[@]}" --command "set application_name='boss_phase4a_${label}_contender';set statement_timeout='20s';begin;$contender_sql commit;" >"$test_run_dir/phase4a-notification-$label-contender.out" 2>"$test_run_dir/phase4a-notification-$label-contender.err" & contender_pid=$!
 if [[ "$should_block" == true ]];then wait_state "boss_phase4a_${label}_contender" lock;else wait "$contender_pid";contender_pid='';fi
 printf '%s\n' 'commit;' >&9;exec 9>&-;writer_open=false
 wait "$writer_pid";writer_pid=''
 if [[ -n "$contender_pid" ]];then wait "$contender_pid";contender_pid='';fi
}
enqueue="select boss_private.notification_enqueue('calendar','event','a4e50000-0000-4000-8000-000000000001','a4e40000-0000-4000-8000-000000000001','event.rescheduled','race');"
race enqueue "$enqueue" "$enqueue" true
if [[ $("${psql_command[@]}" --command "select count(*)=1 from public.notification_events where organization_id='a4e40000-0000-4000-8000-000000000001'") != t ]];then exit 1;fi
process="select boss_private.notification_process('a4e40000-0000-4000-8000-000000000001',100);"
race processing "$process" "$process" false
if [[ $("${psql_command[@]}" --command "select (select count(*)=1 from public.notifications where organization_id='a4e40000-0000-4000-8000-000000000001') and (select count(*)=2 from public.notification_deliveries where organization_id='a4e40000-0000-4000-8000-000000000001')") != t ]];then exit 1;fi
claims='{"sub":"a4e10000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"a4e20000-0000-4000-8000-000000000001"}'
receipt="set local role authenticated;select set_config('request.jwt.claims','$claims',true);select public.boss_notifications_mutate('a4e60000-0000-4000-8000-000000000001','{\"operation\":\"preference.set\",\"input\":{\"channel\":\"email\",\"category\":\"events\",\"enabled\":false}}');"
race receipts "$receipt" "$receipt" true
if [[ $("${psql_command[@]}" --command "select (select count(*)=1 from boss_private.notification_operation_receipts where actor_person_id='a4e30000-0000-4000-8000-000000000001') and (select count(*)=1 from public.notification_preferences where person_id='a4e30000-0000-4000-8000-000000000001')") != t ]];then exit 1;fi
printf '%s\n' 'Notification concurrency: 3 true two-connection races passed (enqueue, SKIP LOCKED processing, same-request receipt).'
