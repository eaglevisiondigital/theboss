#!/usr/bin/env bash
# Executes the actual approved operator DO block in a disposable rollback suite.
# The source is extracted verbatim, not a copied implementation or production run.
set -euo pipefail
umask 077

: "${PG_BINDIR:?Set by the disposable runner}"
: "${PGHOST:?Set by the disposable runner}"
: "${PGPORT:?Set by the disposable runner}"
: "${PGDATABASE:?Set by the disposable runner}"
: "${PGUSER:?Set by the disposable runner}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" \
  || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]]; then
  printf '%s\n' 'Bootstrap tests require the private disposable runner socket.' >&2
  exit 1
fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_run_dir=${PGHOST%/socket}
bootstrap_source=$test_dir/../operations/bootstrap-platform-admin.sql
bootstrap_test=$test_run_dir/bootstrap-actual-source.sql
bootstrap_output=$test_run_dir/bootstrap-actual-source.stdout
if [[ ! -s "$bootstrap_source" ]]; then
  printf '%s\n' 'Approved operator bootstrap source is missing.' >&2
  exit 1
fi
psql_command=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" \
  --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" \
  --set ON_ERROR_STOP=1 --set VERBOSITY=terse --quiet)
if [[ $("${psql_command[@]}" --no-align --tuples-only --command "select current_setting('listen_addresses') = ''") != t ]]; then
  printf '%s\n' 'Bootstrap tests reject a database with a TCP listener.' >&2
  exit 1
fi

printf '%s\n' 'BEGIN;' 'CREATE TEMP TABLE phase2b_bootstrap_source (statement text NOT NULL) ON COMMIT DROP;' \
  'INSERT INTO pg_temp.phase2b_bootstrap_source VALUES ($actual_operator_source$' >"$bootstrap_test"
awk '
  /^do \$\$$/ { in_body=1; blocks++ }
  in_body { print }
  in_body && /^end \$\$;$/ { in_body=0; complete++ }
  END { if (blocks != 1 || complete != 1 || in_body) exit 1 }
' "$bootstrap_source" >>"$bootstrap_test"
printf '%s\n' '$actual_operator_source$);' >>"$bootstrap_test"
cat "$test_dir/bootstrap-cases.sql" >>"$bootstrap_test"
"${psql_command[@]}" --file "$bootstrap_test" >"$bootstrap_output"
awk '
  /^[[:space:]]*passed_assertions[[:space:]]*$/ { summary=1 }
  summary { print }
  END { if (!summary) exit 1 }
' "$bootstrap_output"
