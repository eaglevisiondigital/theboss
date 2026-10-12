#!/usr/bin/env bash
# Local-only two-session tests. The calling runner owns the disposable cluster.
# Unlike a timing-only sleep, a FIFO holds the writer until the contender has
# taken its snapshot and is blocked on the per-organization serialization row.
set -euo pipefail
umask 077

: "${PG_BINDIR:?Set by the disposable runner}"
: "${PGHOST:?Set by the disposable runner}"
: "${PGPORT:?Set by the disposable runner}"
: "${PGDATABASE:?Set by the disposable runner}"
: "${PGUSER:?Set by the disposable runner}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" \
  || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
  printf '%s\n' 'Hierarchy concurrency tests require the private disposable runner socket.' >&2
  exit 1
fi
test_run_dir=${PGHOST%/socket}
psql_command=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" \
  --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" \
  --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
if [[ $("${psql_command[@]}" --command "select current_setting('listen_addresses') = ''") != t ]]; then
  printf '%s\n' 'Hierarchy concurrency tests reject a database with a TCP listener.' >&2
  exit 1
fi

writer_pid=''
contender_pid=''
writer_input_open=false
fixtures_created=false
cleanup() {
  local result=$?
  trap - EXIT INT TERM
  if [[ "$writer_input_open" == true ]]; then
    exec 9>&-
    writer_input_open=false
  fi
  # Only child psql processes started by this script are signaled. Closing their
  # connections rolls back unfinished test transactions; no backend is selected.
  if [[ -n "$writer_pid" ]]; then
    kill "$writer_pid" >/dev/null 2>&1 || true
    wait "$writer_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "$contender_pid" ]]; then
    kill "$contender_pid" >/dev/null 2>&1 || true
    wait "$contender_pid" >/dev/null 2>&1 || true
  fi
  if [[ "$fixtures_created" == true ]]; then
    if ! "${psql_command[@]}" --command "
      set statement_timeout='5s';
      begin;
      update public.organization_units set parent_unit_id=null
        where id in ('72000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002');
      delete from public.organization_units
        where id in ('72000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002');
      delete from public.organizations where id='71000000-0000-4000-8000-000000000001';
      commit;"; then
      printf '%s\n' 'Concurrency fixture cleanup failed; the runner must discard its cluster.' >&2
      result=1
    elif [[ $("${psql_command[@]}" --command "
      select not exists (select 1 from public.organizations where id='71000000-0000-4000-8000-000000000001')
        and not exists (select 1 from public.organization_units
          where id in ('72000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000002'))") != t ]]; then
      printf '%s\n' 'Concurrency fixture cleanup left a synthetic row.' >&2
      result=1
    fi
  fi
  if [[ "$result" == 0 ]]; then
    printf '%s\n' 'Hierarchy concurrency fixtures removed.'
  fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Concurrent sessions need committed starting rows. These fixed synthetic IDs
# exist only in this private local cluster and are explicitly removed afterward.
"${psql_command[@]}" --command "
  begin;
  insert into public.organizations(id,name,slug) values
    ('71000000-0000-4000-8000-000000000001','Synthetic hierarchy concurrency','synthetic-phase2a-hierarchy-concurrency');
  insert into public.organization_units(id,organization_id,unit_type,name,slug) values
    ('72000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001','program','Synthetic A','a'),
    ('72000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000001','program','Synthetic B','b');
  commit;"
fixtures_created=true

await_session_state() {
  local application_name=$1 expected_state=$2
  local deadline=$((SECONDS + 10))
  local query
  if [[ "$expected_state" == writer_ready ]]; then
    query="select count(*) from pg_catalog.pg_stat_activity
      where application_name='$application_name' and state='idle in transaction'
        and query like '%update public.organization_units%'
        and query like '%72000000-0000-4000-8000-000000000001%'"
  else
    query="select count(*) from pg_catalog.pg_stat_activity
      where application_name='$application_name' and wait_event_type='Lock'"
  fi
  while (( SECONDS < deadline )); do
    if [[ $("${psql_command[@]}" --command "$query") == 1 ]]; then
      return 0
    fi
    sleep 0.05
  done
  printf 'Concurrency synchronization failed: %s did not reach %s.\n' "$application_name" "$expected_state" >&2
  return 1
}

run_case() {
  local label=$1 isolation=$2 expected_state=$3
  local writer_name="boss_phase2a_hierarchy_${label}_writer"
  local contender_name="boss_phase2a_hierarchy_${label}_contender"
  local writer_fifo="$test_run_dir/hierarchy-${label}.stdin"
  local writer_errors="$test_run_dir/hierarchy-${label}-writer.err"
  local contender_errors="$test_run_dir/hierarchy-${label}-contender.err"
  local contender_status

  "${psql_command[@]}" --command "update public.organization_units set parent_unit_id=null
    where organization_id='71000000-0000-4000-8000-000000000001'"
  mkfifo -m 600 "$writer_fifo"
  "${psql_command[@]}" <"$writer_fifo" >"$test_run_dir/hierarchy-${label}-writer.out" 2>"$writer_errors" &
  writer_pid=$!
  exec 9>"$writer_fifo"
  writer_input_open=true
  printf '%s\n' "set application_name='$writer_name'; begin;
    update public.organization_units set parent_unit_id='72000000-0000-4000-8000-000000000002'
      where id='72000000-0000-4000-8000-000000000001';" >&9
  await_session_state "$writer_name" writer_ready

  "${psql_command[@]}" --command "set application_name='$contender_name'; set statement_timeout='15s';
    begin isolation level $isolation;
    select count(*) from public.organization_units
      where organization_id='71000000-0000-4000-8000-000000000001';
    update public.organization_units set parent_unit_id='72000000-0000-4000-8000-000000000001'
      where id='72000000-0000-4000-8000-000000000002';
    commit;" >"$test_run_dir/hierarchy-${label}-contender.out" 2>"$contender_errors" &
  contender_pid=$!
  await_session_state "$contender_name" contender_blocked

  printf 'commit;\n\\q\n' >&9
  exec 9>&-
  writer_input_open=false
  if ! wait "$writer_pid"; then
    writer_pid=''
    cat "$writer_errors" >&2
    printf 'Hierarchy writer failed in %s.\n' "$isolation" >&2
    return 1
  fi
  writer_pid=''
  if wait "$contender_pid"; then contender_status=0; else contender_status=$?; fi
  contender_pid=''
  if [[ "$contender_status" == 0 || $(<"$contender_errors") != *"$expected_state:"* ]]; then
    cat "$contender_errors" >&2
    printf 'Expected hierarchy rejection %s in %s; process status was %s.\n' \
      "$expected_state" "$isolation" "$contender_status" >&2
    return 1
  fi
  if [[ $("${psql_command[@]}" --command "
    select exists (select 1 from public.organization_units
      where id='72000000-0000-4000-8000-000000000001'
        and parent_unit_id='72000000-0000-4000-8000-000000000002')
      and exists (select 1 from public.organization_units
        where id='72000000-0000-4000-8000-000000000002' and parent_unit_id is null)
      and not exists (select 1 from public.organization_units a join public.organization_units b
        on b.id=a.parent_unit_id where a.organization_id='71000000-0000-4000-8000-000000000001'
        and b.parent_unit_id=a.id)") != t ]]; then
    printf 'Hierarchy invariant failed after %s rejection.\n' "$isolation" >&2
    return 1
  fi
  rm -- "$writer_fifo"
  printf 'PASS concurrent hierarchy: %s rejected unsafe edit with %s; no cycle.\n' "$isolation" "$expected_state"
}

run_case rc 'read committed' 23514
run_case rr 'repeatable read' 40001
run_case serializable serializable 40001
