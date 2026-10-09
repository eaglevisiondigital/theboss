#!/usr/bin/env bash
set -euo pipefail
: "${PG_BINDIR:?}" "${PGHOST:?}" "${PGPORT:?}" "${PGDATABASE:?}" "${PGUSER:?}"
[[ "$PGHOST" == /tmp/boss-db-test.*/socket && "$PGPORT" == 5432 && "$PGDATABASE" == postgres && "$PGUSER" == postgres ]]||exit 1
probe_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"&&pwd)
root=$(cd -- "$probe_dir/../../.."&&pwd)
[[ $# == 0 ]] || exit 1
psql=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --quiet --no-align --tuples-only)
expected_metadata=$(<"$probe_dir/schema-contract.json")
expected_types=$(<"$root/apps/platform/src/lib/partners/database.types.ts")
expected="$expected_metadata"$'\n-- TYPESCRIPT CONTRACT --\n'"$expected_types"
verify() {
 [[ "$1" == "$expected" ]] || { printf '%s\n' 'Partner PostgreSQL schema/RPC or generated TypeScript contract differs.' >&2; return 1; }
}
actual=$("${psql[@]}" --file "$probe_dir/schema-contract.sql")
verify "$actual"
printf '%s\n' 'Verified portable Partner schema/types: 16 tables; 3 RPCs.'
# This script accepts only the private disposable runner socket above. The
# deliberately added nullable column exists in this connection's transaction
# only; rollback restores the contract even when the comparison rejects it.
negative=$("${psql[@]}" <<SQL
begin;
alter table public.partner_providers add column probe_negative_control boolean;
\i '$probe_dir/schema-contract.sql'
rollback;
SQL
)
if verify "$negative" 2>/dev/null; then
 printf '%s\n' 'Negative schema control unexpectedly passed.' >&2; exit 1
fi
printf '%s\n' 'Negative schema control rejected as required.'
if verify "${actual/  id: string;/  id: number;}" 2>/dev/null; then
 printf '%s\n' 'Negative generated-type control unexpectedly passed.' >&2; exit 1
fi
printf '%s\n' 'Negative generated-type control rejected as required.'
restored=$("${psql[@]}" --file "$probe_dir/schema-contract.sql")
verify "$restored"
printf '%s\n' 'Restored positive Partner schema/type probe passed.'
