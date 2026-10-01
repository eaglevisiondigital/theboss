#!/usr/bin/env bash
# Fresh PostgreSQL 17 SQL/RLS test run. Never connects to a remote database.
set -euo pipefail
umask 077

test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_dir=$(cd -- "$test_dir/../.." && pwd)

if [[ -n "${PG_BINDIR:-}" ]]; then
  postgres_bin_dir=$PG_BINDIR
elif command -v pg_config >/dev/null 2>&1; then
  postgres_bin_dir=$(pg_config --bindir)
else
  printf '%s\n' 'PostgreSQL 17 binaries required. Set PG_BINDIR to their bin directory.' >&2
  exit 1
fi
for binary in postgres initdb pg_ctl psql; do
  if [[ ! -x "$postgres_bin_dir/$binary" ]]; then
    printf 'Missing PostgreSQL binary: %s\n' "$binary" >&2
    exit 1
  fi
done
if [[ $("$postgres_bin_dir/postgres" --version) != *'PostgreSQL) 17.'* ]]; then
  printf '%s\n' 'This harness requires PostgreSQL major version 17.' >&2
  exit 1
fi
if [[ $(id -u) == 0 ]]; then
  printf '%s\n' 'Run this harness as an unprivileged user, as required by initdb.' >&2
  exit 1
fi

# A short pathname fits PostgreSQL Unix-socket limits on macOS and Linux.
test_run_dir=$(mktemp -d /tmp/boss-db-test.XXXXXX)
data_dir=$test_run_dir/data
socket_dir=$test_run_dir/socket
mkdir -m 700 "$socket_dir"
cleanup() {
  local result=$?
  trap - EXIT INT TERM
  # pg_ctl may fail after postmaster has already started. Never remove an
  # active data directory just because startup did not return successfully.
  if [[ -s "$data_dir/postmaster.pid" ]]; then
    if ! "$postgres_bin_dir/pg_ctl" --pgdata "$data_dir" --mode immediate --wait stop >/dev/null 2>&1; then
      printf 'Disposable PostgreSQL shutdown failed; data preserved at %s\n' "$test_run_dir" >&2
      exit 1
    fi
  fi
  rm -rf -- "$test_run_dir"
  if [[ "$result" == 0 ]]; then
    printf '%s\n' 'Ephemeral PostgreSQL cluster removed.'
  fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Host connections are rejected and PostgreSQL binds no TCP interfaces.
# The private Unix socket is accessible only to this operating-system user.
"$postgres_bin_dir/initdb" --pgdata "$data_dir" --username boss_test_admin \
  --auth-local trust --auth-host reject --encoding UTF8 --no-locale >/dev/null
"$postgres_bin_dir/pg_ctl" --pgdata "$data_dir" --log "$test_run_dir/postgres.log" \
  --options "-c listen_addresses='' -c unix_socket_directories='$socket_dir' -c unix_socket_permissions=0700 -c log_statement=none" \
  --wait start >/dev/null
psql_bootstrap_command=("$postgres_bin_dir/psql" --no-psqlrc --no-password \
  --host "$socket_dir" --port 5432 --username boss_test_admin --dbname postgres \
  --set ON_ERROR_STOP=1 --set VERBOSITY=terse)
psql_command=("$postgres_bin_dir/psql" --no-psqlrc --no-password \
  --host "$socket_dir" --port 5432 --username postgres --dbname postgres \
  --set ON_ERROR_STOP=1 --set VERBOSITY=terse)

"${psql_bootstrap_command[@]}" --quiet --file "$test_dir/local-bootstrap.sql"
shopt -s nullglob
migrations=("$repository_dir"/supabase/migrations/*.sql)
if [[ ${#migrations[@]} == 0 ]]; then
  printf '%s\n' 'No canonical migrations found.' >&2
  exit 1
fi
for migration in "${migrations[@]}"; do
  if [[ ! -s "$migration" ]]; then
    printf 'Migration is empty: %s\n' "${migration##*/}" >&2
    exit 1
  fi
  printf 'Applying %s\n' "${migration##*/}"
  "${psql_command[@]}" --quiet --single-transaction --file "$migration"
done

tests=("$test_dir"/phase2[ab]_*.sql)
if [[ ${#tests[@]} == 0 ]]; then
  printf '%s\n' 'No Phase 2A/2B SQL test files found.' >&2
  exit 1
fi
for test_file in "${tests[@]}"; do
  printf 'Testing %s\n' "${test_file##*/}"
  # Assertion functions return void. Keep those repetitive result blocks and
  # synthetic request claims in the private run directory, while retaining
  # psql errors on stderr and the actual SQL-generated summary on success.
  test_output=$test_run_dir/${test_file##*/}.stdout
  "${psql_command[@]}" --quiet --file "$test_file" >"$test_output"
  if ! awk '
    /^[[:space:]]*passed_assertions[[:space:]]*$/ { summary = 1 }
    summary { print }
    END { if (!summary) exit 1 }
  ' "$test_output"; then
    printf 'SQL test summary missing: %s\n' "${test_file##*/}" >&2
    exit 1
  fi
done

concurrency_test=$test_dir/phase2a_hierarchy_concurrency.sh
if [[ ! -s "$concurrency_test" ]]; then
  printf '%s\n' 'Phase 2A hierarchy concurrency test is missing.' >&2
  exit 1
fi
printf 'Testing %s\n' "${concurrency_test##*/}"
PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
  PGDATABASE=postgres PGUSER=postgres bash "$concurrency_test"
bootstrap_test=$test_dir/phase2b_bootstrap.sh
if [[ ! -s "$bootstrap_test" ]]; then
  printf '%s\n' 'Phase 2B actual-source bootstrap test is missing.' >&2
  exit 1
fi
printf 'Testing %s\n' "${bootstrap_test##*/}"
PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
  PGDATABASE=postgres PGUSER=postgres bash "$bootstrap_test"
mutation_concurrency_test=$test_dir/phase2b_mutation_concurrency.sh
if [[ ! -s "$mutation_concurrency_test" ]]; then
  printf '%s\n' 'Phase 2B mutation concurrency test is missing.' >&2
  exit 1
fi
printf 'Testing %s\n' "${mutation_concurrency_test##*/}"
PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
  PGDATABASE=postgres PGUSER=postgres bash "$mutation_concurrency_test"
printf '%s\n' 'Phase 2A/2B PostgreSQL 17 authorization tests passed.'
