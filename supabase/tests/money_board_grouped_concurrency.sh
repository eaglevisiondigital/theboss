#!/usr/bin/env bash
# Two real connections; private disposable PostgreSQL only, synthetic data only.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]];then printf '%s\n' 'Grouped races require the private disposable runner socket.' >&2;exit 1;fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd);race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do [[ -z "$pid" ]]||{ kill "$pid" >/dev/null 2>&1||true;wait "$pid" >/dev/null 2>&1||true;};done;exit "$result";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Grouped concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
lookup(){ "${psql_cmd[@]}" --command "$1"; }
assert_sql(){ [[ $(lookup "$2") == t ]]||fail "$1"; }
await_state(){ local app=$1 expected=$2 pid=$3 deadline=$((SECONDS+7)) query;if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app'and state='idle in transaction'and query like'%grouped-writer-ready%'";else query="select count(*) from pg_stat_activity where application_name='$app'and wait_event_type='Lock'";fi;while((SECONDS<deadline));do kill -0 "$pid" >/dev/null 2>&1||return 1;[[ $(lookup "$query") == 1 ]]&&return 0;sleep .025;done;return 1; }
race(){ local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold=${5:-0};local fifo="$race_dir/grouped-$$-$label.stdin" rc=0;mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/grouped-$label-w.out" 2>"$race_dir/grouped-$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_grouped_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* grouped-writer-ready */;" >&9;await_state "boss_grouped_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/grouped-$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set application_name='boss_grouped_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/grouped-$label-c.out" 2>"$race_dir/grouped-$label-c.err"&contender_pid=$!;await_state "boss_grouped_${label}_contender" waiting "$contender_pid"||{ head -n 8 "$race_dir/grouped-$label-c.err" >&2;fail "$label contender did not block";};if [[ "$hold" != 0 ]];then sleep "$hold";fi;printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||{ head -n 8 "$race_dir/grouped-$label-w.err" >&2;fail "$label writer";};writer_pid='';if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid='';if [[ "$expected" == success && "$rc" != 0 ]];then head -n 8 "$race_dir/grouped-$label-c.err" >&2;fail "$label contender";fi;if [[ "$expected" != success ]]&&{ [[ "$rc" == 0 ]]||! grep -Fq "$expected" "$race_dir/grouped-$label-c.err";};then head -n 8 "$race_dir/grouped-$label-c.err" >&2;fail "$label expected $expected";fi;race_count=$((race_count+1)); }
setup(){
 local label=$1
 prefix="boss-grouped-race-$$-$label";org="md5('$prefix:org')::uuid"
 awk '!/^\\ir /' "$test_dir/phase7b/fixture.sql" "$test_dir/phase7c/fixture.sql" "$test_dir/phase7d/fixture.sql" "$test_dir/grouped/fixture.sql" | sed -e "s/boss-phase7b-test:/$prefix:/g" -e "s/synthetic-phase7b-/synthetic-${prefix//_/-}-/g" -e "s/'rails-source'/'$prefix-source'/g" >"$race_dir/grouped-$label-fixture.sql"
 printf '%s\n' 'begin;' "\\ir '$race_dir/grouped-$label-fixture.sql'" "${2:-}" 'commit;' >"$race_dir/grouped-$label-setup.sql"
 "${psql_cmd[@]}" --file "$race_dir/grouped-$label-setup.sql" >"$race_dir/grouped-$label-setup.out" 2>"$race_dir/grouped-$label-setup.err"||fail "$label fixture"
 path=$(lookup "select path from public.fundraising_shares where fundraiser_id in(select id from public.fundraising_fundraisers where organization_id=$org)limit 1")
 ca=$(lookup "select md5('$prefix:A')||md5('$prefix:A2')");cb=$(lookup "select md5('$prefix:B')||md5('$prefix:B2')")
 board="(select id from public.money_boards where fundraiser_id in(select id from public.fundraising_fundraisers where organization_id=$org)limit 1)"
}
command(){ local cap=$1 action=$2 ordinal=${3:-0} rid=${4:-gen_random_uuid()};printf '%s' "select public.boss_money_board_cart(jsonb_build_object('action','$action','request_id',$rid,'input',jsonb_build_object('path','$path')$( [[ $ordinal != 0 ]]&&printf "||jsonb_build_object('tile_id',(select id from public.money_board_tiles where board_id=$board and ordinal=$ordinal))" )), '$cap');"; }
open_pair(){ lookup "$(command "$ca" open)$(command "$cb" open)$(command "$ca" add 1)$(command "$ca" add 2)$(command "$cb" add 2)$(command "$cb" add 3)" >/dev/null;}
setup overlap;open_pair
race overlap "$(command "$ca" reserve)" "$(command "$cb" reserve)" PT409
assert_sql 'atomic conflict leaves no partial group' "select count(*)=1 from public.money_board_groups g join public.money_board_carts c on c.id=g.cart_id where c.organization_id=$org"
assert_sql 'atomic winner has exactly two lines' "select count(*)=2 from public.money_board_group_items l join public.money_board_groups g on g.id=l.group_id join public.money_board_carts c on c.id=g.cart_id where c.organization_id=$org"
setup duplicate;open_pair
fixed="md5('$prefix:fixed-request')::uuid"
race duplicate "$(command "$ca" reserve 0 "$fixed")" "$(command "$ca" reserve 0 "$fixed")" success
assert_sql 'concurrent replay creates one group' "select count(*)=1 from public.money_board_groups where request_id=$fixed"
setup edit;open_pair
race edit "$(command "$ca" reserve)" "$(command "$ca" remove 1)" PT409
setup release;open_pair
lookup "$(command "$ca" reserve)" >/dev/null
race release "$(command "$ca" cancel)" "$(command "$cb" reserve)" success
assert_sql 'released overlap can acquire whole next group' "select count(*)=2 from public.money_board_groups g join public.money_board_carts c on c.id=g.cart_id where c.organization_id=$org"
setup reverse;open_pair
race reverse "$(command "$cb" reserve)" "$(command "$ca" reserve)" PT409
setup pause;open_pair
race pause "update public.fundraising_campaigns set status='paused'where organization_id=$org;" "$(command "$ca" reserve)" PT404
setup guardian;open_pair
race guardian "select boss_private.fundraising_fence($org,md5('$prefix:parent')::uuid,md5('$prefix:child1')::uuid);update public.guardian_relationships set can_manage_fundraising=false where guardian_person_id=md5('$prefix:parent')::uuid;" "$(command "$ca" reserve)" PT404
setup share;open_pair
race share "select 1 from public.fundraising_campaigns where organization_id=$org for update;update public.fundraising_shares set status='revoked',revoked_at=clock_timestamp()where path='$path';" "$(command "$ca" reserve)" PT404
setup cancel;open_pair
lookup "$(command "$ca" reserve)" >/dev/null
race cancel "$(command "$ca" cancel)" "$(command "$ca" cancel)" success
assert_sql 'concurrent cancellation releases every winner' "select not exists(select 1 from public.money_board_reservations r join public.money_board_tiles t on t.id=r.tile_id where t.board_id=$board and r.released_at is null)"
financial_setup(){ local label=$1 stage=$2 short=${3:-false};setup "$label" "select set_config('request.jwt.claims','{}',true);select pg_temp.group_checkout('case-$$-$label','card',array[5,10,15],$short);$([[ $stage == submitted ]]&&printf "select boss_private.rails_dispatch(pg_temp.f('checkout-case-$$-$label'));")";checkout="md5('$prefix:checkout-case-$$-$label')::uuid";cap=$(lookup "select md5('case-$$-$label')||md5('groupcase-$$-$label')");}
receive(){ local kind=$1 ref=$2;printf '%s' "select boss_private.rails_receive($checkout,'$prefix-$ref','$kind','LOCAL-GROUP-$prefix',3000,'USD','$fixed_at'::timestamptz,repeat('a',64),'{}');";}
financial_setup payment_success submitted
fixed_at=$(lookup 'select clock_timestamp()')
race payment_success "$(receive captured capture)" "$(receive captured capture)" success
assert_sql 'group success replay exactly three claims once' "select count(*)=3 and count(distinct evidence_id)=1 from public.money_board_tile_claims where group_id=(select group_id from public.money_board_checkout_preparations where intent_id=(select intent_id from public.payment_checkouts where id=$checkout))"
financial_setup success_cancel submitted
fixed_at=$(lookup 'select clock_timestamp()')
race success_cancel "$(receive captured capture)" "$(command "$cap" cancel)" PT409
financial_setup unknown_expire submitted true
fixed_at=$(lookup 'select clock_timestamp()')
race unknown_expire "$(receive unknown unknown)" "$(command "$cap" expire)" PT409 1.1
assert_sql 'unknown retains every original hold after expiry' "select count(*)=3 and bool_and(boss_private.rails_tile_pending(l.tile_id))from public.money_board_group_items l join public.money_board_checkout_preparations p on p.group_id=l.group_id where p.intent_id=(select intent_id from public.payment_checkouts where id=$checkout)"
financial_setup expiry ready true
sleep 1.1
race expiry "$(command "$cap" expire)" "$(command "$cap" expire)" success
assert_sql 'concurrent expiry releases every unpaid line' "select bool_and(r.released_at is not null)from public.money_board_reservations r join public.money_board_group_items l on l.reservation_id=r.id join public.money_board_checkout_preparations p on p.group_id=l.group_id where p.intent_id=(select intent_id from public.payment_checkouts where id=$checkout)"
financial_setup archive ready
race archive "update public.fundraising_campaigns set status='archived'where organization_id=$org;" "select boss_private.rails_dispatch($checkout);" PT404
assert_sql 'archive before dispatch creates no committed group' "select not exists(select 1 from public.money_board_group_commits where checkout_id=$checkout)"
printf 'PASS grouped core: %s observed lock/contention races.\n' "$race_count"
