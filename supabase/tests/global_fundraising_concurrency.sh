#!/usr/bin/env bash
# Two real connections; private disposable PostgreSQL only, synthetic data only.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]];then printf '%s\n' 'Global fundraising races require the private disposable runner socket.' >&2;exit 1;fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd);race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do [[ -z "$pid" ]]||{ kill "$pid" >/dev/null 2>&1||true;wait "$pid" >/dev/null 2>&1||true;};done;exit "$result";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Global fundraising concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
lookup(){ "${psql_cmd[@]}" --command "$1"; }
assert_sql(){ [[ $(lookup "$2") == t ]]||fail "$1"; }
await_state(){ local app=$1 expected=$2 pid=$3 deadline=$((SECONDS+7)) query;if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app'and state='idle in transaction'and query like'%grouped-writer-ready%'";else query="select count(*) from pg_stat_activity where application_name='$app'and wait_event_type='Lock'";fi;while((SECONDS<deadline));do kill -0 "$pid" >/dev/null 2>&1||return 1;[[ $(lookup "$query") == 1 ]]&&return 0;sleep .025;done;return 1; }
race(){ local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold=${5:-0};local fifo="$race_dir/grouped-$$-$label.stdin" rc=0;mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/grouped-$label-w.out" 2>"$race_dir/grouped-$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_grouped_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* grouped-writer-ready */;" >&9;await_state "boss_grouped_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/grouped-$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set application_name='boss_grouped_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/grouped-$label-c.out" 2>"$race_dir/grouped-$label-c.err"&contender_pid=$!;await_state "boss_grouped_${label}_contender" waiting "$contender_pid"||{ head -n 8 "$race_dir/grouped-$label-c.err" >&2;fail "$label contender did not block";};if [[ "$hold" != 0 ]];then sleep "$hold";fi;printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||{ head -n 8 "$race_dir/grouped-$label-w.err" >&2;fail "$label writer";};writer_pid='';if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid='';if [[ "$expected" == success && "$rc" != 0 ]];then head -n 8 "$race_dir/grouped-$label-c.err" >&2;fail "$label contender";fi;if [[ "$expected" != success ]]&&{ [[ "$rc" == 0 ]]||! grep -Fq "$expected" "$race_dir/grouped-$label-c.err";};then head -n 8 "$race_dir/grouped-$label-c.err" >&2;fail "$label expected $expected";fi;race_count=$((race_count+1)); }
setup(){
 local label=$1
 prefix="boss-grouped-race-$$-$label";org="md5('$prefix:org')::uuid"
 awk '!/^\\ir /' "$test_dir/phase7b/fixture.sql" "$test_dir/phase7c/fixture.sql" "$test_dir/phase7d/fixture.sql" "$test_dir/grouped/fixture.sql" "$test_dir/global/fixture.sql" | sed -e "s/boss-phase7b-test:/$prefix:/g" -e "s/synthetic-phase7b-/synthetic-${prefix//_/-}-/g" -e "s/'rails-source'/'$prefix-source'/g" >"$race_dir/grouped-$label-fixture.sql"
 printf '%s\n' 'begin;' "\\ir '$race_dir/grouped-$label-fixture.sql'" "select pg_temp.policy('money_board',pg_temp.f('falcons'));" "${2:-}" 'commit;' >"$race_dir/grouped-$label-setup.sql"
 "${psql_cmd[@]}" --file "$race_dir/grouped-$label-setup.sql" >"$race_dir/grouped-$label-setup.out" 2>"$race_dir/grouped-$label-setup.err"||fail "$label fixture"
 path=$(lookup "select path from public.fundraising_shares where fundraiser_id in(select id from public.fundraising_fundraisers where organization_id=$org)limit 1")
 ca=$(lookup "select md5('$prefix:A')||md5('$prefix:A2')");cb=$(lookup "select md5('$prefix:B')||md5('$prefix:B2')")
 board="(select id from public.money_boards where fundraiser_id in(select id from public.fundraising_fundraisers where organization_id=$org)limit 1)"
}
command(){ local cap=$1 action=$2 ordinal=${3:-0} rid=${4:-gen_random_uuid()};printf '%s' "select public.boss_money_board_cart(jsonb_build_object('action','$action','request_id',$rid,'input',jsonb_build_object('path','$path')$( [[ $ordinal != 0 ]]&&printf "||jsonb_build_object('tile_id',(select id from public.money_board_tiles where board_id=$board and ordinal=$ordinal))" )), '$cap');"; }
open_pair(){ lookup "$(command "$ca" open)$(command "$cb" open)$(command "$ca" add 1)$(command "$ca" add 2)$(command "$cb" add 2)$(command "$cb" add 3)" >/dev/null;}

auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('$prefix:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('$prefix:session-$1')::uuid)::text,true);"; }
# Command inputs resolve IDs inside the trusted test owner, before SET ROLE.
command_for(){ local actor=$1 action=$2 input=$3 request=${4:-gen_random_uuid()};local value;value=$(lookup "select ($input)::text");printf '%s' "$(auth "$actor")select public.boss_fundraising_allocation_mutate(jsonb_build_object('action','$action','request_id',$request,'input',\$json\$$value\$json\$::jsonb));"; }
prepare_delegation(){ local stmt;stmt=$(command_for admin delegation.create "jsonb_build_object('campaign_id',(select id from public.fundraising_campaigns where organization_id=$org),'person_id',md5('$prefix:coach')::uuid,'team_id',md5('$prefix:falcons')::uuid,'starts_at',clock_timestamp()-interval'1 minute','ends_at',clock_timestamp()+interval'10 minutes')");lookup "begin;$stmt commit;" >/dev/null; }
allocation_command(){ local request=${1:-gen_random_uuid()};command_for coach allocation_policy.create "jsonb_build_object('campaign_id',(select id from public.fundraising_campaigns where organization_id=$org),'team_id',md5('$prefix:falcons')::uuid,'platform_policy_id',(select id from public.fundraising_platform_policies where organization_id=$org order by revision desc limit 1),'channel','money_board','organization_bps',2000,'destination_bps',3000,'participant_bps',5000,'starts_at','$starts'::timestamptz)" "$request"; }
platform_command(){ command_for director platform_policy.create "jsonb_build_object('organization_id',$org,'campaign_id',(select id from public.fundraising_campaigns where organization_id=$org),'channel','money_board','currency','USD','settlement_policy_id',md5('$prefix:settlement-policy')::uuid,'agreement_reference','LOCAL-SYNTHETIC-RACE','participant_credit_max_bps',10000,'wallet_permitted',true,'starts_at',clock_timestamp()-interval'1 hour')"; }
setup policy_replay;prepare_delegation;starts=$(lookup "select clock_timestamp()::text");fixed="md5('$prefix:fixed-request')::uuid";cmd=$(allocation_command "$fixed")
race policy_replay "$cmd" "$cmd" success
assert_sql 'one allocation command under simultaneous replay' "select count(*)=1 from boss_private.fundraising_allocation_requests where request_id=$fixed"
setup policy_revisions;prepare_delegation;starts=$(lookup "select clock_timestamp()::text")
a=$(allocation_command);b=$(allocation_command)
race policy_revisions "$a" "$b" success
assert_sql 'two independent revisions serialized' "select count(*)=3 and max(revision)=3 from public.fundraising_allocation_policies where organization_id=$org"
setup revoke;prepare_delegation;starts=$(lookup "select clock_timestamp()::text")
a=$(command_for admin delegation.revoke "jsonb_build_object('campaign_id',(select id from public.fundraising_campaigns where organization_id=$org),'delegation_id',(select id from public.fundraising_allocation_delegations where organization_id=$org))");b=$(allocation_command)
race revoke "$a" "$b" PT403
setup member;prepare_delegation;starts=$(lookup "select clock_timestamp()::text");b=$(allocation_command)
race member "select boss_private.fundraising_fence($org,md5('$prefix:coach')::uuid);update public.team_memberships set status='inactive'where person_id=md5('$prefix:coach')::uuid;" "$b" PT403
setup platform_revoke;b=$(platform_command)
race platform_revoke "update public.role_assignments set status='inactive'where person_id=md5('$prefix:director')::uuid and scope_type='platform';" "$b" PT403
setup policy_checkout
# Direct native intent uses a reviewed independent direct_support economics binding.
a=$(command_for director platform_policy.create "jsonb_build_object('organization_id',$org,'campaign_id',(select id from public.fundraising_campaigns where organization_id=$org),'channel','direct_support','currency','USD','settlement_policy_id',md5('$prefix:settlement-policy')::uuid,'agreement_reference','LOCAL-SYNTHETIC-RACE','participant_credit_max_bps',10000,'wallet_permitted',false,'starts_at',clock_timestamp()-interval'1 hour')")
cap=$(lookup "select md5('$prefix:direct-A')||md5('$prefix:direct-B')")
lookup "select public.boss_fundraising_support(jsonb_build_object('action','intent','request_id',gen_random_uuid(),'input',jsonb_build_object('path','$path','capability','$cap','display_name','Synthetic policy race','anonymous',true,'amount_minor',101)));" >/dev/null
b="select public.boss_payments_support(jsonb_build_object('action','prepare','request_id',gen_random_uuid(),'input',jsonb_build_object('path','$path','capability','$cap','method','card')));"
race policy_checkout "$a" "$b" success
assert_sql 'checkout captures newly serialized channel economics' "select count(*)=1 and bool_and(platform_policy_id is not null and channel='direct_support')from public.fundraising_checkout_snapshots where organization_id=$org"
setup credit_replay "select pg_temp.group_checkout('global-credit-race');select boss_private.rails_dispatch(pg_temp.f('checkout-global-credit-race'));select pg_temp.receive('global-credit-race','captured');do \$\$declare c public.payment_checkouts;begin select *into c from public.payment_checkouts where id=pg_temp.f('checkout-global-credit-race');perform boss_private.rails_receive(c.id,'global-credit-race-settled','settled','LOCAL-TRANSACTION-global-credit-race',c.external_minor,c.currency,clock_timestamp(),repeat('a',64),jsonb_build_object('processor_fee_minor',0));end\$\$;"
payment=$(lookup "select payment_id from public.external_payment_tenders where checkout_id=md5('$prefix:checkout-global-credit-race')::uuid and original_payment_id is null")
event=$(lookup "select id from public.provider_event_evidence where event_reference='global-credit-race-settled'and account_id=md5('$prefix:rails-account')::uuid")
a="select boss_private.rails_settlement_match('$payment'::uuid,'$event'::uuid,0);"
race credit_replay "$a" "$a" success
assert_sql 'one immutable credit source under settlement replay' "select count(*)=1 from public.fundraising_credit_sources where payment_id='$payment'::uuid"
assert_sql 'credit entries conserve source under replay' "select sum(amount_minor)=2100 from public.fundraising_credit_entries where payment_id='$payment'::uuid"
# Independent tenants proceed while another tenant retains a policy lock.
for pair in 1 2 3;do
 setup "tenant_${pair}_a";a=$(platform_command)
 setup "tenant_${pair}_b";b=$(platform_command)
 fifo="$race_dir/global-independent-$$-$pair.stdin";mkfifo -m 600 "$fifo"
 "${psql_cmd[@]}" <"$fifo" >"$race_dir/global-independent-$pair.out" 2>"$race_dir/global-independent-$pair.err"&writer_pid=$!
 exec 9>"$fifo";input_open=true
 printf '%s\n' "set application_name='boss_grouped_independent_writer';begin;$a select 1 /* grouped-writer-ready */;" >&9
 await_state boss_grouped_independent_writer ready "$writer_pid"||fail 'independent writer readiness'
 lookup "set statement_timeout='1s';begin;$b commit;" >/dev/null||fail 'cross-tenant policy was globally blocked'
 printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||fail 'independent writer';writer_pid='';race_count=$((race_count+1))
done
printf 'PASS Global fundraising concurrency: %s real two-connection races, exact tenant locks/revision/replay/revocation/source conservation.\n' "$race_count"
