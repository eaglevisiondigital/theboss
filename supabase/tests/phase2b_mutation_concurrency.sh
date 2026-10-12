#!/usr/bin/env bash
# Actual RPC duplicate-window races in the runner's disposable local cluster.
# Committed append-only audit rows are discarded with that entire cluster.
set -euo pipefail
umask 077

: "${PG_BINDIR:?Set by the disposable runner}"
: "${PGHOST:?Set by the disposable runner}"
: "${PGPORT:?Set by the disposable runner}"
: "${PGDATABASE:?Set by the disposable runner}"
: "${PGUSER:?Set by the disposable runner}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" \
  || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
  printf '%s\n' 'Mutation concurrency tests require the private disposable runner socket.' >&2
  exit 1
fi
test_run_dir=${PGHOST%/socket}
psql_command=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" \
  --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" \
  --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_command[@]}" --command "select current_setting('listen_addresses') = ''") != t ]]; then
  printf '%s\n' 'Mutation concurrency tests reject a database with a TCP listener.' >&2
  exit 1
fi
writer_pid=''
contender_pid=''
writer_input_open=false
cleanup() {
  local result=$?
  trap - EXIT INT TERM
  if [[ "$writer_input_open" == true ]]; then exec 9>&-;writer_input_open=false;fi
  if [[ -n "$writer_pid" ]]; then kill "$writer_pid" >/dev/null 2>&1 || true;wait "$writer_pid" >/dev/null 2>&1 || true;fi
  if [[ -n "$contender_pid" ]]; then kill "$contender_pid" >/dev/null 2>&1 || true;wait "$contender_pid" >/dev/null 2>&1 || true;fi
  if [[ "$result" == 0 ]]; then
    printf '%s\n' 'Mutation race fixtures remain only in the disposable cluster for its imminent removal; audit rewrite was never enabled.'
  fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"${psql_command[@]}" --command "
 begin;
 insert into auth.users(id,email,email_confirmed_at) values
  ('b2c10000-0000-4000-8000-000000000001','synthetic-rpc-race@phase2b.example.invalid',now()-interval '1 day');
 insert into auth.sessions(id,user_id) values('b2c20000-0000-4000-8000-000000000001','b2c10000-0000-4000-8000-000000000001');
 insert into public.people(id,display_name) values
  ('b2c30000-0000-4000-8000-000000000001','Synthetic Phase 2B Race Actor'),
  ('b2c30000-0000-4000-8000-000000000002','Synthetic Phase 2B Race Target');
 insert into public.user_accounts(auth_user_id,person_id,account_status) values
  ('b2c10000-0000-4000-8000-000000000001','b2c30000-0000-4000-8000-000000000001','active');
 insert into public.role_assignments(person_id,role_id,scope_type)
  select 'b2c30000-0000-4000-8000-000000000001',id,'platform' from public.roles where key='platform_administrator';
 insert into public.organizations(id,name,slug,organization_type) values
  ('b2c40000-0000-4000-8000-000000000001','Synthetic Phase 2B RC Race','synthetic-phase2b-race-rc','test'),
  ('b2c40000-0000-4000-8000-000000000002','Synthetic Phase 2B RR Race','synthetic-phase2b-race-rr','test');
 commit;" >"$test_run_dir/mutation-race-setup.stdout"

await_session_state() {
  local application_name=$1 expected_state=$2
  local deadline=$((SECONDS + 10)) query
  if [[ "$expected_state" == writer_ready ]]; then
    query="select count(*) from pg_catalog.pg_stat_activity where application_name='$application_name'
      and state='idle in transaction' and query like '%boss_admin_mutate%'"
  else
    query="select count(*) from pg_catalog.pg_stat_activity where application_name='$application_name' and wait_event_type='Lock'"
  fi
  while (( SECONDS < deadline )); do
    if [[ $("${psql_command[@]}" --command "$query") == 1 ]]; then return 0;fi
    sleep 0.05
  done
  printf 'RPC race synchronization failed: %s did not reach %s.\n' "$application_name" "$expected_state" >&2
  return 1
}

run_case() {
  local label=$1 isolation=$2 suffix=$3
  local writer_name="boss_phase2b_rpc_${label}_writer"
  local contender_name="boss_phase2b_rpc_${label}_contender"
  local writer_fifo="$test_run_dir/rpc-${label}.stdin"
  local writer_errors="$test_run_dir/rpc-${label}-writer.err"
  local contender_errors="$test_run_dir/rpc-${label}-contender.err"
  local org_id="b2c40000-0000-4000-8000-00000000000${suffix}"
  local writer_request="b2c50000-0000-4000-8000-00000000000${suffix}"
  local contender_request="b2c60000-0000-4000-8000-00000000000${suffix}"
  local contender_status
  local claims='{"sub":"b2c10000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"b2c20000-0000-4000-8000-000000000001"}'
  local writer_commands="[{\"operation\":\"organization_membership.add\",\"input\":{\"organization_id\":\"$org_id\",\"person_id\":\"b2c30000-0000-4000-8000-000000000002\",\"membership_type\":\"synthetic_race\",\"starts_at\":\"2026-09-01T00:00:00Z\"}}]"
  local contender_commands="[{\"operation\":\"organization_membership.add\",\"input\":{\"organization_id\":\"$org_id\",\"person_id\":\"b2c30000-0000-4000-8000-000000000002\",\"membership_type\":\"synthetic_race\",\"starts_at\":\"2026-09-02T00:00:00Z\"}}]"

  mkfifo -m 600 "$writer_fifo"
  "${psql_command[@]}" <"$writer_fifo" >"$test_run_dir/rpc-${label}-writer.out" 2>"$writer_errors" &
  writer_pid=$!
  exec 9>"$writer_fifo"
  writer_input_open=true
  printf '%s\n' "set application_name='$writer_name';begin;set local role authenticated;
    select set_config('request.jwt.claims','$claims',true);
    select public.boss_admin_mutate('$writer_commands'::jsonb,'$writer_request'::uuid);" >&9
  await_session_state "$writer_name" writer_ready

  "${psql_command[@]}" --command "set application_name='$contender_name';set statement_timeout='15s';
    begin isolation level $isolation;set local role authenticated;
    select set_config('request.jwt.claims','$claims',true);
    select count(*) from public.organizations where id='$org_id';
    select public.boss_admin_mutate('$contender_commands'::jsonb,'$contender_request'::uuid);commit;" \
    >"$test_run_dir/rpc-${label}-contender.out" 2>"$contender_errors" &
  contender_pid=$!
  await_session_state "$contender_name" contender_blocked
  printf 'commit;\n\\q\n' >&9
  exec 9>&-
  writer_input_open=false
  if ! wait "$writer_pid"; then
    writer_pid=''
    cat "$writer_errors" >&2
    printf 'RPC writer failed in %s.\n' "$isolation" >&2
    return 1
  fi
  writer_pid=''
  if wait "$contender_pid"; then contender_status=0;else contender_status=$?;fi
  contender_pid=''
  if [[ "$contender_status" == 0 || $(<"$contender_errors") != *'PT409:'* ]]; then
    cat "$contender_errors" >&2
    printf 'Expected safe RPC conflict PT409 in %s; process status was %s.\n' "$isolation" "$contender_status" >&2
    return 1
  fi
  if [[ $("${psql_command[@]}" --command "select
    (select count(*)=1 from public.organization_memberships where organization_id='$org_id'
      and person_id='b2c30000-0000-4000-8000-000000000002' and membership_type='synthetic_race')
    and (select count(*)=1 from public.audit_events where request_id='$writer_request'
      and actor_person_id='b2c30000-0000-4000-8000-000000000001' and action='organization_membership.add')
    and not exists(select 1 from public.audit_events where request_id='$contender_request')
    and (select count(*)=1 from boss_private.admin_operation_receipts where request_id='$writer_request')
    and not exists(select 1 from boss_private.admin_operation_receipts where request_id='$contender_request')") != t ]]; then
    printf 'RPC duplicate/audit/receipt invariant failed after %s rejection.\n' "$isolation" >&2
    return 1
  fi
  rm -- "$writer_fifo"
  printf 'PASS concurrent RPC: %s has one successful writer, one PT409, one membership/audit/receipt, no partial contender writes.\n' "$isolation"
}

run_case rc 'read committed' 1
run_case rr 'repeatable read' 2
