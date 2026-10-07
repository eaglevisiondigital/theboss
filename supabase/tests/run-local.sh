#!/usr/bin/env bash
# Fresh PostgreSQL 17 SQL/RLS test run. Never connects to a remote database.
set -euo pipefail
umask 077

test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_dir=$(cd -- "$test_dir/../.." && pwd)
selected_test=''
concurrency_only=false
phase5a_only=false
phase5b_only=false
phase5c_only=false
phase5d_only=false
phase5e_only=false
phase5f_only=false
phase6a_only=false
phase6b_only=false
phase6c_only=false
phase6d_only=false
phase6e_only=false
phase7a_only=false
if [[ $# != 0 ]]; then
  if [[ $# == 1 && "$1" == --concurrency ]]; then
    concurrency_only=true
  elif [[ $# == 1 && "$1" == --test5a ]]; then
    phase5a_only=true
  elif [[ $# == 1 && "$1" == --test5b ]]; then
    phase5b_only=true
  elif [[ $# == 1 && "$1" == --test5c ]]; then
    phase5c_only=true
  elif [[ $# == 1 && "$1" == --test6b ]]; then
    phase6b_only=true
  elif [[ $# == 1 && "$1" == --test6c ]]; then
    phase6c_only=true
  elif [[ $# == 1 && "$1" == --test7a ]]; then
    phase7a_only=true
  elif [[ $# == 1 && "$1" == --test6e ]]; then
    phase6e_only=true
  elif [[ $# == 1 && "$1" == --test6d ]]; then
    phase6d_only=true
  elif [[ $# == 1 && "$1" == --test6a ]]; then
    phase6a_only=true
  elif [[ $# == 1 && "$1" == --test5f ]]; then
    phase5f_only=true
  elif [[ $# == 1 && "$1" == --test5e ]]; then
    phase5e_only=true
  elif [[ $# == 1 && "$1" == --test5d ]]; then
    phase5d_only=true
  elif [[ $# != 2 || "$1" != --test || ! "$2" =~ ^phase([23][ab]|4[ab]|5[abcdef]|6[abcde]|7a)_[a-z_]+\.sql$ || ! -s "$test_dir/$2" ]]; then
    printf '%s\n' 'Usage: run-local.sh [--test phase6d_tournament.sql | --test5a | --test5b | --test5c | --test5d | --test5e | --test5f | --test6a | --test6b | --test6c | --test6d | --test6e | --test7a | --concurrency]' >&2
    exit 1
  else
    selected_test=$2
  fi
fi

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
# Match the canonical Boss project's verified JIT setting, so compiler cost
# does not obscure authorization and concurrency behavior in short requests.
# Local function tracking enables structural regressions without superuser
# privileges for the managed-like migration/test role.
"$postgres_bin_dir/initdb" --pgdata "$data_dir" --username boss_test_admin \
  --auth-local trust --auth-host reject --encoding UTF8 --no-locale -c shared_memory_type=mmap -c dynamic_shared_memory_type=mmap >/dev/null
"$postgres_bin_dir/pg_ctl" --pgdata "$data_dir" --log "$test_run_dir/postgres.log" \
  --options "-c listen_addresses='' -c unix_socket_directories='$socket_dir' -c unix_socket_permissions=0700 -c log_statement=none -c jit=off -c track_functions=all" \
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

tests=("$test_dir"/phase2[ab]_*.sql "$test_dir"/phase3[ab]_*.sql "$test_dir"/phase4[ab]_*.sql "$test_dir"/phase5a_*.sql "$test_dir"/phase5b_*.sql "$test_dir"/phase5c_*.sql "$test_dir"/phase5d_*.sql "$test_dir"/phase5e_*.sql "$test_dir"/phase5f_*.sql "$test_dir"/phase6a_*.sql "$test_dir"/phase6b_*.sql "$test_dir"/phase6c_*.sql "$test_dir"/phase6d_*.sql "$test_dir"/phase6e_*.sql "$test_dir"/phase7a_*.sql)
if [[ "$phase5a_only" == true ]]; then tests=("$test_dir"/phase5a_*.sql);fi
if [[ "$phase5b_only" == true ]]; then tests=("$test_dir"/phase5b_*.sql);fi
if [[ "$phase5c_only" == true ]]; then tests=("$test_dir"/phase5c_*.sql);fi
if [[ "$phase5d_only" == true ]]; then tests=("$test_dir"/phase5d_*.sql);fi
if [[ "$phase5e_only" == true ]]; then tests=("$test_dir"/phase5e_*.sql);fi
if [[ "$phase6b_only" == true ]]; then tests=("$test_dir"/phase6b_*.sql);fi
if [[ "$phase6c_only" == true ]]; then tests=("$test_dir"/phase6c_*.sql);fi
if [[ "$phase7a_only" == true ]]; then tests=("$test_dir"/phase7a_*.sql);fi
if [[ "$phase6e_only" == true ]]; then tests=("$test_dir"/phase6e_*.sql);fi
if [[ "$phase6d_only" == true ]]; then tests=("$test_dir"/phase6d_*.sql);fi
if [[ "$phase6a_only" == true ]]; then tests=("$test_dir"/phase6a_*.sql);fi
if [[ "$phase5f_only" == true ]]; then tests=("$test_dir"/phase5f_*.sql);fi
if [[ -n "$selected_test" ]]; then tests=("$test_dir/$selected_test");fi
if [[ "$concurrency_only" == true ]]; then tests=();fi
if [[ ${#tests[@]} == 0 && "$concurrency_only" != true ]]; then
    printf '%s\n' 'No selected PostgreSQL acceptance suites found.' >&2
  exit 1
fi
if [[ "$concurrency_only" != true ]]; then
for test_file in "${tests[@]}"; do
  printf 'Testing %s\n' "${test_file##*/}"
  # Assertion functions return void. Keep those repetitive result blocks and
  # synthetic request claims in the private run directory, while retaining
  # psql errors on stderr and the actual SQL-generated summary on success.
  test_output=$test_run_dir/${test_file##*/}.stdout
  "${psql_command[@]}" --quiet --file "$test_file" >"$test_output"
  if ! awk '
    /^[[:space:]]*passed_assertions([[:space:]]*\||[[:space:]]*$)/ { summary = 1 }
    summary { print }
    END { if (!summary) exit 1 }
  ' "$test_output"; then
    printf 'SQL test summary missing: %s\n' "${test_file##*/}" >&2
    exit 1
  fi
done
fi

if [[ -z "$selected_test" && ( "$phase6a_only" == true || ( "$phase5a_only" == false && "$phase5b_only" == false && "$phase5c_only" == false && "$phase5d_only" == false && "$phase5e_only" == false && "$phase5f_only" == false && "$phase6b_only" == false && "$phase6c_only" == false && "$phase6d_only" == false && "$phase6e_only" == false && "$phase7a_only" == false ) ) ]]; then
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase6a_sealed_sources.sh"
fi

if [[ -n "$selected_test" ]]; then
  printf 'Focused SQL test passed: %s. Full run without --test remains required.\n' "$selected_test"
  exit 0
fi

if [[ "$phase5a_only" == true ]]; then
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
    PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase5a_games_concurrency.sh"
  printf '%s\n' 'Focused Phase 5A SQL and concurrency tests passed. Full historical run remains required.'
  exit 0
fi

if [[ "$phase5b_only" == true ]]; then
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
    PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase5b_basketball_concurrency.sh"
  printf '%s\n' 'Focused Phase 5B SQL and concurrency tests passed. Full historical run remains required.'
  exit 0
fi

if [[ "$phase5c_only" == true ]]; then
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
    PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase5c_soccer_concurrency.sh"
  printf '%s\n' 'Focused Phase 5C SQL and concurrency tests passed. Full historical run remains required.'
  exit 0
fi

if [[ "$phase5d_only" == true ]]; then
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
    PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase5d_football_concurrency.sh"
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
    PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase5d_athlete_history_concurrency.sh"
  printf '%s\n' 'Focused Phase 5D SQL and concurrency tests passed. Full historical run remains required.'
  exit 0
fi

if [[ "$phase5e_only" == true ]]; then
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase5e_volleyball_concurrency.sh"
  printf '%s\n' 'Focused Phase 5E SQL and concurrency tests passed. Full historical run remains required.'
  exit 0
fi

if [[ "$phase6b_only" == true ]]; then
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase6b_ranking_concurrency.sh"
  printf '%s\n' 'Focused Phase 6B SQL/concurrency passed; full historical validation remains required.'
  exit 0
fi

if [[ "$phase6c_only" == true ]]; then
  if [[ ! -s "$test_dir/phase6c_athlete_profiles_concurrency.sh" ]]; then printf '%s\n' 'Phase 6C concurrency test is missing.' >&2;exit 1;fi
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase6c_athlete_profiles_concurrency.sh" || exit $?
  printf '%s\n' 'Focused Phase 6C SQL/concurrency passed; full historical validation remains required.'
  exit 0
fi

if [[ "$phase7a_only" == true ]]; then
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase7a_fundraising_concurrency.sh"
  printf "%s\n" "Focused Phase 7A SQL/concurrency passed; full historical validation remains required."
  exit 0
fi

if [[ "$phase6e_only" == true ]]; then
  if [[ ! -s "$test_dir/phase6e_achievements_concurrency.sh" ]]; then printf "%s\n" "Phase 6E concurrency test is missing." >&2;exit 1;fi
  if [[ -s "$test_dir/phase6e_achievements_concurrency.sh" ]]; then
    PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase6e_achievements_concurrency.sh"
  fi
  printf "%s\n" "Focused Phase 6E SQL/concurrency passed; full historical validation remains required."
  exit 0
fi

if [[ "$phase6d_only" == true ]]; then
  if [[ ! -s "$test_dir/phase6d_tournament_concurrency.sh" ]]; then printf '%s\n' 'Phase 6D concurrency test is missing.' >&2;exit 1;fi
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase6d_tournament_concurrency.sh" || exit $?
  printf '%s\n' 'Focused Phase 6D SQL/concurrency passed; full historical validation remains required.'
  exit 0
fi

if [[ "$phase6a_only" == true ]]; then
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase6a_intelligence_concurrency.sh"
  printf '%s\n' 'Focused Phase 6A SQL/concurrency passed; full historical validation remains required.'
  exit 0
fi

if [[ "$phase5f_only" == true ]]; then
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 PGDATABASE=postgres PGUSER=postgres bash "$test_dir/phase5f_diamond_concurrency.sh"
  printf '%s\n' 'Focused Phase 5F SQL and concurrency passed; full history remains required.'
  exit 0
fi

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
calendar_concurrency_test=$test_dir/phase3a_mutation_concurrency.sh
if [[ ! -s "$calendar_concurrency_test" ]]; then
  printf '%s\n' 'Phase 3A calendar concurrency test is missing.' >&2
  exit 1
fi
printf 'Testing %s\n' "${calendar_concurrency_test##*/}"
PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
  PGDATABASE=postgres PGUSER=postgres bash "$calendar_concurrency_test"
registration_concurrency_test=$test_dir/phase3b_mutation_concurrency.sh
if [[ ! -s "$registration_concurrency_test" ]]; then
  printf '%s\n' 'Phase 3B registration/payment concurrency test is missing.' >&2
  exit 1
fi
printf 'Testing %s\n' "${registration_concurrency_test##*/}"
PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
  PGDATABASE=postgres PGUSER=postgres bash "$registration_concurrency_test"
for phase4a_test in phase4a_communications_concurrency.sh phase4a_notifications_concurrency.sh phase4b_attendance_concurrency.sh phase4b_volunteers_concurrency.sh phase5a_games_concurrency.sh phase5b_basketball_concurrency.sh phase5c_soccer_concurrency.sh phase5d_football_concurrency.sh phase5d_athlete_history_concurrency.sh phase5e_volleyball_concurrency.sh phase5f_diamond_concurrency.sh phase6a_intelligence_concurrency.sh phase6b_ranking_concurrency.sh phase6c_athlete_profiles_concurrency.sh phase6e_achievements_concurrency.sh phase7a_fundraising_concurrency.sh; do
  concurrency_test=$test_dir/$phase4a_test
  if [[ ! -s "$concurrency_test" ]]; then
    printf 'Phase 4 concurrency test is missing: %s\n' "$phase4a_test" >&2
    exit 1
  fi
  printf 'Testing %s\n' "$phase4a_test"
  PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
    PGDATABASE=postgres PGUSER=postgres bash "$concurrency_test"
done

# Earlier concurrency suites intentionally retain synthetic rows until the
# disposable cluster is removed. Phase 6D composes the established Phase 5A
# and 6B fixtures, whose deterministic identifiers can therefore collide.
# Reinitialize the same private, no-network cluster before the final race set
# so the race test proves its own setup and invariants independently.
"$postgres_bin_dir/pg_ctl" --pgdata "$data_dir" --mode immediate --wait stop >/dev/null
rm -rf -- "$data_dir"
"$postgres_bin_dir/initdb" --pgdata "$data_dir" --username boss_test_admin \
  --auth-local trust --auth-host reject --encoding UTF8 --no-locale -c shared_memory_type=mmap -c dynamic_shared_memory_type=mmap >/dev/null
"$postgres_bin_dir/pg_ctl" --pgdata "$data_dir" --log "$test_run_dir/postgres-phase6d.log" \
  --options "-c listen_addresses='' -c unix_socket_directories='$socket_dir' -c unix_socket_permissions=0700 -c log_statement=none -c jit=off -c track_functions=all" \
  --wait start >/dev/null
"${psql_bootstrap_command[@]}" --quiet --file "$test_dir/local-bootstrap.sql"
for migration in "${migrations[@]}"; do
  "${psql_command[@]}" --quiet --single-transaction --file "$migration"
done
concurrency_test=$test_dir/phase6d_tournament_concurrency.sh
printf 'Testing %s in an isolated disposable database\n' "${concurrency_test##*/}"
PG_BINDIR="$postgres_bin_dir" PGHOST="$socket_dir" PGPORT=5432 \
  PGDATABASE=postgres PGUSER=postgres bash "$concurrency_test"
if [[ "$concurrency_only" == true ]]; then
  printf '%s\n' 'All sealed-source/bootstrap/concurrency checks passed; SQL suites are a separate required validation stage.'
else
  printf '%s\n' 'Phase 2A through Phase 7A PostgreSQL 17 authorization/bootstrap/concurrency tests passed.'
fi
