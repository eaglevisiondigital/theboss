#!/usr/bin/env bash
# Real native Next/React acceptance after all proposed migrations. Local only.
set -euo pipefail
umask 077
[[ $# == 0 && $(id -u) != 0 ]]||exit 1
: "${PG_BINDIR:?PostgreSQL 17 required}" "${BOSS_TEST_LOCAL_BUILD:?Isolated production build required}" "${BOSS_TEST_PLAYWRIGHT_MODULE:?Local Playwright required}" "${BOSS_TEST_OUTPUT:?Private output directory required}"
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.."&&pwd)
[[ $BOSS_TEST_LOCAL_BUILD == /private/tmp/boss-global-local-build && -s $BOSS_TEST_LOCAL_BUILD/.next/BUILD_ID ]]||exit 1
run=$(mktemp -d /tmp/boss-db-test.global-browser.XXXXXX)
tls=$(mktemp -d /tmp/boss-fundraising-tls.XXXXXX)
next_pid='';tls_pid=''
cleanup(){ local rc=$?;trap - EXIT INT TERM;
 if [[ -n $tls_pid ]];then kill "$tls_pid" 2>/dev/null||true;wait "$tls_pid" 2>/dev/null||true;fi
 if [[ -n $next_pid ]];then kill "$next_pid" 2>/dev/null||true;wait "$next_pid" 2>/dev/null||true;fi
 if [[ -s "$run/data/postmaster.pid" ]];then "$PG_BINDIR/pg_ctl" -D "$run/data" -m immediate -w stop >/dev/null||exit 1;fi
 rm -rf -- "$run" "$tls";printf '%s\n' 'Disposed owned database, loopback servers and synthetic TLS material.';exit "$rc";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
mkdir -m 700 "$run/socket"
"$PG_BINDIR/initdb" -D "$run/data" -U boss_test_admin --auth-local trust --auth-host reject --encoding UTF8 --no-locale -c shared_memory_type=mmap -c dynamic_shared_memory_type=mmap >/dev/null
"$PG_BINDIR/pg_ctl" -D "$run/data" -l "$run/server.log" -o "-c listen_addresses='' -c unix_socket_directories='$run/socket' -c unix_socket_permissions=0700 -c log_statement=none -c jit=off" -w start >/dev/null
psql=("$PG_BINDIR/psql" -X -h "$run/socket" -d postgres -v ON_ERROR_STOP=1 -v VERBOSITY=terse -q)
"${psql[@]}" -U boss_test_admin -f "$root/supabase/tests/local-bootstrap.sql"
count=0
for migration in "$root"/supabase/migrations/*.sql;do "${psql[@]}" -U postgres -1 -f "$migration";count=$((count+1));done
[[ $count == 129 ]]||exit 1
"${psql[@]}" -U postgres -f "$root/supabase/tests/global/browser-fixture.sql" > "$run/fixture.log"
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$tls/key.pem" -out "$tls/cert.pem" -days 1 -subj '/CN=localhost' > "$tls/generation.log" 2>&1
export BOSS_GROUP_TEST_SOCKET="$run/socket" BOSS_LOCAL_UI_ORIGIN=https://localhost:31443
(cd "$BOSS_TEST_LOCAL_BUILD";export NEXT_TELEMETRY_DISABLED=1 NEXT_PUBLIC_SUPABASE_URL=https://ilykgwgmxtrrikreacrz.supabase.co NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_local_synthetic_unusable_20261010 BOSS_PLATFORM_ORIGIN=https://localhost:31443;export NODE_OPTIONS="--import=\"$root/supabase/tests/grouped/networkless-preload.mjs\"";exec node node_modules/next/dist/bin/next start -H localhost -p 31408) > "$run/next.log" 2>&1 &next_pid=$!
BOSS_LOCAL_TLS_DIR="$tls" node "$root/supabase/tests/global/https-proxy.mjs" > "$run/tls.log" 2>&1 &tls_pid=$!
ready=false
for attempt in {1..30};do if curl --silent --fail --insecure https://localhost:31443/ >/dev/null;then ready=true;break;fi;sleep 1;done
[[ $ready == true ]]||{ printf '%s\n' 'Local loopback readiness failed';exit 1; }
node "$root/supabase/tests/grouped/browser-acceptance.mjs"
node "$root/supabase/tests/global/browser-acceptance.mjs"
