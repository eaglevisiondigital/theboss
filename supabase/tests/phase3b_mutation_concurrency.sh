#!/usr/bin/env bash
# Real two-connection registration/payment RPC races in the disposable runner.
# No remote host, real identity, secret, Auth token or object bytes are used.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Set by disposable runner}"
: "${PGHOST:?Set by disposable runner}"
: "${PGPORT:?Set by disposable runner}"
: "${PGDATABASE:?Set by disposable runner}"
: "${PGUSER:?Set by disposable runner}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
  printf '%s\n' 'Registration races require the private disposable runner socket.' >&2
  exit 1
fi
test_run_dir=${PGHOST%/socket}
psql_command=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_command[@]}" --command "select current_setting('listen_addresses') = ''") != t ]]; then
  printf '%s\n' 'Registration races reject a TCP listener.' >&2
  exit 1
fi
writer_pid='';contender_pid='';writer_input_open=false;all_races_completed=false
cleanup() {
  local result=$?
  if [[ "$result" == 0 && "$all_races_completed" != true ]]; then result=1;fi
  trap - EXIT INT TERM
  if [[ "$writer_input_open" == true ]]; then exec 9>&-;writer_input_open=false;fi
  if [[ -n "$writer_pid" ]]; then kill "$writer_pid" >/dev/null 2>&1 || true;wait "$writer_pid" >/dev/null 2>&1 || true;fi
  if [[ -n "$contender_pid" ]]; then kill "$contender_pid" >/dev/null 2>&1 || true;wait "$contender_pid" >/dev/null 2>&1 || true;fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"${psql_command[@]}" --command "
begin;
insert into auth.users(id,email,email_confirmed_at) values('b3d10000-0000-4000-8000-000000000001','synthetic-race@phase3b.example.invalid',now()-interval '1 day');
insert into auth.sessions(id,user_id) values('b3d20000-0000-4000-8000-000000000001','b3d10000-0000-4000-8000-000000000001');
insert into public.people(id,display_name) values('b3d30000-0000-4000-8000-000000000001','Synthetic Phase3B Race Actor'),('b3d30000-0000-4000-8000-000000000002','Synthetic Phase3B Race Child A'),('b3d30000-0000-4000-8000-000000000003','Synthetic Phase3B Race Child B');
insert into public.user_accounts(auth_user_id,person_id,account_status) values('b3d10000-0000-4000-8000-000000000001','b3d30000-0000-4000-8000-000000000001','active');
insert into public.participants(id,person_id,participant_type) values('b3d40000-0000-4000-8000-000000000001','b3d30000-0000-4000-8000-000000000002','athlete'),('b3d40000-0000-4000-8000-000000000002','b3d30000-0000-4000-8000-000000000003','athlete');
insert into public.guardian_relationships(guardian_person_id,dependent_person_id,authority_status,verified_at,can_register,starts_at) select 'b3d30000-0000-4000-8000-000000000001',id,'active',now()-interval '1 day',true,now()-interval '1 day' from public.people where id in ('b3d30000-0000-4000-8000-000000000002','b3d30000-0000-4000-8000-000000000003');
insert into public.role_assignments(person_id,role_id,scope_type) select 'b3d30000-0000-4000-8000-000000000001',id,'platform' from public.roles where key='platform_administrator';
insert into public.organizations(id,name,slug,organization_type) values('b3d50000-0000-4000-8000-000000000001','Synthetic Phase3B Race Organization','synthetic-phase3b-race','test');
insert into public.organization_modules(organization_id,module_id,status,configuration) select 'b3d50000-0000-4000-8000-000000000001',id,'active','{\"registration\":true,\"fees\":true,\"offline_payments\":true,\"waitlists\":true}' from public.modules where key='registration';
insert into public.registration_offerings(id,organization_id,title,scope_type,scope_id,participant_type,status,capacity,waitlist_enabled,created_by_person_id,updated_by_person_id)
select ('b3d60000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'b3d50000-0000-4000-8000-000000000001','Synthetic capacity/payment race '||n,'organization','b3d50000-0000-4000-8000-000000000001','athlete','published',case when n<=4 then 1 else null end,n=4,'b3d30000-0000-4000-8000-000000000001','b3d30000-0000-4000-8000-000000000001' from generate_series(1,8) n;
insert into public.registrations(id,organization_id,offering_id,participant_id,submitted_by_person_id,offering_snapshot,participant_snapshot)
select ('b3d70000-0000-4000-8000-'||lpad((n*10+c)::text,12,'0'))::uuid,'b3d50000-0000-4000-8000-000000000001',('b3d60000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,('b3d40000-0000-4000-8000-'||lpad(c::text,12,'0'))::uuid,'b3d30000-0000-4000-8000-000000000001','{\"offering\":{\"approval_required\":true},\"forms\":[],\"waivers\":[],\"documents\":[],\"fees\":[]}','{}' from generate_series(1,8) n cross join generate_series(1,2)c;
insert into public.charges(id,organization_id,registration_id,participant_id,title,charge_type,original_amount_minor,currency,created_by_person_id)
select ('b3d80000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'b3d50000-0000-4000-8000-000000000001',('b3d70000-0000-4000-8000-'||lpad((n*10+1)::text,12,'0'))::uuid,'b3d40000-0000-4000-8000-000000000001','Synthetic 10000 minor units race obligation','registration',10000,'USD','b3d30000-0000-4000-8000-000000000001' from generate_series(5,8)n;
commit;" >"$test_run_dir/phase3b-race-setup.out"

await_state() {
 local application_name=$1 expected=$2 query deadline=$((SECONDS+15))
 if [[ "$expected" == ready ]]; then query="select count(*) from pg_stat_activity where application_name='$application_name' and state='idle in transaction' and query like '%boss_registration_mutate%'";
 else query="select count(*) from pg_stat_activity where application_name='$application_name' and wait_event_type='Lock'";fi
 while (( SECONDS<deadline ));do
  if [[ $("${psql_command[@]}" --command "$query") == 1 ]];then return 0;fi
  sleep 0.05
 done
 printf 'Registration race did not synchronize %s (%s).\n' "$application_name" "$expected" >&2
 return 1
}
race() {
 local label=$1 isolation=$2 n=$3 kind=$4 expect_success=$5
 local writer_name="boss_phase3b_${label}_writer" contender_name="boss_phase3b_${label}_contender"
 local fifo="$test_run_dir/phase3b-${label}.stdin" writer_errors="$test_run_dir/phase3b-${label}-writer.err" contender_errors="$test_run_dir/phase3b-${label}-contender.err"
 local writer_request contender_request writer_command contender_command reg1 reg2 charge offer claims contender_status
 printf -v writer_request 'b3d90000-0000-4000-8000-%012d' "$n"
 printf -v contender_request 'b3da0000-0000-4000-8000-%012d' "$n"
 printf -v reg1 'b3d70000-0000-4000-8000-%012d' "$((n*10+1))"
 printf -v reg2 'b3d70000-0000-4000-8000-%012d' "$((n*10+2))"
 printf -v offer 'b3d60000-0000-4000-8000-%012d' "$n"
 printf -v charge 'b3d80000-0000-4000-8000-%012d' "$n"
 claims='{"sub":"b3d10000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"b3d20000-0000-4000-8000-000000000001"}'
 if [[ "$kind" == capacity ]];then
  writer_command="{\"operation\":\"registration.submit\",\"input\":{\"registration_id\":\"$reg1\",\"expected_version\":1}}"
  contender_command="{\"operation\":\"registration.submit\",\"input\":{\"registration_id\":\"$reg2\",\"expected_version\":1}}"
 else
  writer_command="{\"operation\":\"payment.record_offline\",\"input\":{\"organization_id\":\"b3d50000-0000-4000-8000-000000000001\",\"method\":\"cash\",\"amount_minor\":6000,\"currency\":\"USD\",\"payer_person_id\":\"b3d30000-0000-4000-8000-000000000001\",\"received_at\":\"2026-10-01T12:00:00Z\",\"allocations\":[{\"charge_id\":\"$charge\",\"amount_minor\":6000}]}}"
  contender_command="$writer_command"
  if [[ "$kind" == retry ]];then contender_request="$writer_request";fi
 fi
 mkfifo -m 600 "$fifo"
 "${psql_command[@]}" <"$fifo" >"$test_run_dir/phase3b-${label}-writer.out" 2>"$writer_errors" &
 writer_pid=$!
 exec 9>"$fifo";writer_input_open=true
 printf '%s\n' "set application_name='$writer_name';begin;set local role authenticated;select set_config('request.jwt.claims','$claims',true);select public.boss_registration_mutate('$writer_request'::uuid,'$writer_command'::jsonb);" >&9
 await_state "$writer_name" ready
 "${psql_command[@]}" --command "set application_name='$contender_name';set statement_timeout='20s';begin isolation level $isolation;set local role authenticated;select set_config('request.jwt.claims','$claims',true);select count(*) from public.organizations where id='b3d50000-0000-4000-8000-000000000001';select public.boss_registration_mutate('$contender_request'::uuid,'$contender_command'::jsonb);commit;" >"$test_run_dir/phase3b-${label}-contender.out" 2>"$contender_errors" &
 contender_pid=$!
 await_state "$contender_name" blocked
 printf 'commit;\n\\q\n' >&9;exec 9>&-;writer_input_open=false
 if ! wait "$writer_pid";then writer_pid='';cat "$writer_errors" >&2;return 1;fi
 writer_pid=''
 if wait "$contender_pid";then contender_status=0;else contender_status=$?;fi
 contender_pid=''
 if [[ "$expect_success" == true ]];then
  if [[ "$contender_status" != 0 ]];then cat "$contender_errors" >&2;return 1;fi
 else
  if [[ "$contender_status" == 0 || $(<"$contender_errors") != *'PT409:'* ]];then cat "$contender_errors" >&2;printf 'Expected safe PT409 in %s.\n' "$label" >&2;return 1;fi
 fi
 if [[ "$kind" == capacity ]];then
  if [[ $("${psql_command[@]}" --command "select (select count(*)=1 from public.registrations where offering_id='$offer' and status in ('submitted','under_review','approved')) and (select count(*)=1 from public.audit_events where request_id='$writer_request' and action='registration.submit') and (select count(*)=1 from boss_private.registration_operation_receipts where request_id='$writer_request') and case when $expect_success then (select count(*)=1 from public.registrations where offering_id='$offer' and status='waitlisted' and waitlist_position=1) and exists(select 1 from boss_private.registration_operation_receipts where request_id='$contender_request') else not exists(select 1 from public.audit_events where request_id='$contender_request') and not exists(select 1 from boss_private.registration_operation_receipts where request_id='$contender_request') end") != t ]];then printf 'Capacity/waitlist/audit atomicity invariant failed %s.\n' "$label" >&2;return 1;fi
 else
  if [[ $("${psql_command[@]}" --command "select (select count(*)=1 and sum(amount_minor)=6000 from public.payment_allocations where charge_id='$charge') and (boss_private.registration_charge_balance('$charge')->>'balance_due_minor')::bigint=4000 and (select count(*)=1 from public.audit_events where request_id='$writer_request' and action='payment.record_offline') and (select count(*)=1 from boss_private.registration_operation_receipts where request_id='$writer_request') and case when '$kind'='retry' then true else not exists(select 1 from public.audit_events where request_id='$contender_request') and not exists(select 1 from boss_private.registration_operation_receipts where request_id='$contender_request') end") != t ]];then printf 'Payment/allocation/receipt invariant failed %s.\n' "$label" >&2;return 1;fi
 fi
 rm -- "$fifo"
 printf 'PASS Phase3B concurrent RPC: %s (%s), capacity/allocation/audit/receipt invariant held.\n' "$label" "$isolation"
}
race capacity_rc 'read committed' 1 capacity false
race capacity_rr 'repeatable read' 2 capacity false
race capacity_serial 'serializable' 3 capacity false
race waitlist_rc 'read committed' 4 capacity true
race payment_rc 'read committed' 5 payment false
race payment_rr 'repeatable read' 6 payment false
race payment_serial 'serializable' 7 payment false
race payment_retry_rc 'read committed' 8 retry true
all_races_completed=true
printf '%s\n' 'Eight Phase3B two-connection RPC races passed; fixtures remain only until disposable cluster removal.'
