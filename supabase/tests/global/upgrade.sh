#!/usr/bin/env bash
# Independently validate the populated old schema followed by exactly four proposals.
set -euo pipefail
umask 077
[[ $# == 0 && $(id -u) != 0 ]]||exit 1
: "${PG_BINDIR:?PostgreSQL 17 binaries required}"
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.."&&pwd)
run=$(mktemp -d /tmp/boss-db-test.global-upgrade.XXXXXX)
mkdir -m 700 "$run/socket"
cleanup(){ local rc=$?;trap - EXIT INT TERM;if [[ -s "$run/data/postmaster.pid" ]];then "$PG_BINDIR/pg_ctl" -D "$run/data" -m immediate -w stop >/dev/null||exit 1;fi;rm -rf -- "$run";exit "$rc";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
"$PG_BINDIR/initdb" -D "$run/data" -U boss_test_admin --auth-local trust --auth-host reject --encoding UTF8 --no-locale -c shared_memory_type=mmap -c dynamic_shared_memory_type=mmap >/dev/null
"$PG_BINDIR/pg_ctl" -D "$run/data" -l "$run/server.log" -o "-c listen_addresses='' -c unix_socket_directories='$run/socket' -c unix_socket_permissions=0700 -c log_statement=none -c jit=off" -w start >/dev/null
psql=("$PG_BINDIR/psql" -X -h "$run/socket" -d postgres -v ON_ERROR_STOP=1 -v VERBOSITY=terse -q)
"${psql[@]}" -U boss_test_admin -f "$root/supabase/tests/local-bootstrap.sql"
"${psql[@]}" -U boss_test_admin -c "create extension pgcrypto with schema extensions;"
"${psql[@]}" -U boss_test_admin -c "select version(),current_setting('listen_addresses') as listen_addresses,current_setting('shared_memory_type') as shared_memory_type,(select extversion from pg_extension where extname='pgcrypto') as pgcrypto_version;"
count=0
for migration in "$root"/supabase/migrations/*.sql;do
 if ((count==129));then break;fi
 if ((count==119));then "${psql[@]}" -U postgres -f "$root/supabase/tests/grouped/upgrade-baseline.sql" >"$run/baseline.out";fi
 if ((count==123));then
  "${psql[@]}" -U postgres -f "$root/supabase/tests/grouped/upgrade-check.sql" >"$run/grouped-check.out"
  cat "$run/grouped-check.out"
  "${psql[@]}" -U postgres -f "$root/supabase/tests/global/upgrade-baseline.sql"
 fi
 "${psql[@]}" -U postgres -1 -f "$migration"
 if ((count>=119));then "${psql[@]}" -U postgres -f "$root/supabase/tests/global/combined-intermediate.sql";fi
 if ((count>=123));then "${psql[@]}" -U postgres -f "$root/supabase/tests/global/intermediate.sql";fi
 count=$((count+1))
done
[[ $count == 129 ]]||exit 1
"${psql[@]}" -U postgres -f "$root/supabase/tests/global/upgrade-check.sql" >"$run/check.out"
awk '/^[[:space:]]*passed_assertions/{ok=1}ok{print}END{if(!ok)exit 1}' "$run/check.out"
printf '%s\n' 'PASS populated combined upgrade 119→123→129; all original rowsets preserved, additive permission/nullable unit metadata explicit, original financial/Wallet/membership/pending lineage retained.'
