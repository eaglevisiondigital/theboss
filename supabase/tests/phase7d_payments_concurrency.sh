#!/usr/bin/env bash
# Two real connections; private disposable PostgreSQL only, synthetic data only.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]];then printf '%s\n' 'Phase7D races require the private disposable runner socket.' >&2;exit 1;fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd);race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do [[ -z "$pid" ]]||{ kill "$pid" >/dev/null 2>&1||true;wait "$pid" >/dev/null 2>&1||true;};done;exit "$result";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase7D concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
lookup(){ "${psql_cmd[@]}" --command "$1"; }
assert_sql(){ [[ $(lookup "$2") == t ]]||fail "$1"; }
await_state(){ local app=$1 expected=$2 pid=$3 deadline=$((SECONDS+7)) query;if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app'and state='idle in transaction'and query like'%phase7d-writer-ready%'";else query="select count(*) from pg_stat_activity where application_name='$app'and wait_event_type='Lock'";fi;while((SECONDS<deadline));do kill -0 "$pid" >/dev/null 2>&1||return 1;[[ $(lookup "$query") == 1 ]]&&return 0;sleep .025;done;return 1; }
race(){ local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold=${5:-0};local fifo="$race_dir/phase7d-$label.stdin" rc=0;mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/7d-$label-w.out" 2>"$race_dir/7d-$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_phase7d_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase7d-writer-ready */;" >&9;await_state "boss_phase7d_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/7d-$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set application_name='boss_phase7d_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/7d-$label-c.out" 2>"$race_dir/7d-$label-c.err"&contender_pid=$!;await_state "boss_phase7d_${label}_contender" waiting "$contender_pid"||{ head -n 8 "$race_dir/7d-$label-c.err" >&2;fail "$label contender did not block";};if [[ "$hold" != 0 ]];then sleep "$hold";fi;printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||{ head -n 8 "$race_dir/7d-$label-w.err" >&2;fail "$label writer";};writer_pid='';if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid='';if [[ "$expected" == success && "$rc" != 0 ]];then head -n 8 "$race_dir/7d-$label-c.err" >&2;fail "$label contender";fi;if [[ "$expected" != success ]]&&{ [[ "$rc" == 0 ]]||! grep -Fq "$expected" "$race_dir/7d-$label-c.err";};then head -n 8 "$race_dir/7d-$label-c.err" >&2;fail "$label expected $expected";fi;race_count=$((race_count+1)); }
setup(){
 local label=$1 method=${2:-card} stage=${3:-submitted} timing=${4:-ordinary}
 prefix="boss-phase7d-race-$label";org="md5('$prefix:org')::uuid";checkout="md5('$prefix:checkout-case')::uuid"
 python3 - "$test_dir" "$race_dir/7d-$label-fixture.sql" "$prefix" <<'PY'
import sys
from pathlib import Path
root=Path(sys.argv[1]);s='\n'.join('\n'.join(line for line in (root/p).read_text().splitlines() if not line.startswith('\\ir ')) for p in ['phase7b/fixture.sql','phase7c/fixture.sql','phase7d/fixture.sql'])
s=s.replace("'rails-source'",repr(sys.argv[3]+'-rails-source')).replace("md5('rails'||label)","md5('"+sys.argv[3]+"rails'||label)").replace("md5('rails-second'||label)","md5('"+sys.argv[3]+"rails-second'||label)")
s=s.replace('boss-phase7b-test:',sys.argv[3]+':').replace('synthetic-phase7b-', 'synthetic-'+sys.argv[3].replace('_','-')+'-').replace('phase7b.example.invalid',sys.argv[3]+'.example.invalid').replace("60 milliseconds","1 second")
Path(sys.argv[2]).write_text(s)
PY
 local prepare="select pg_temp.checkout('case','$method',1,$([[ $timing == expiry ]]&&printf true||printf false));"
 if [[ $stage == fee || $stage == fee_ready ]];then
 prepare="select pg_temp.actor('parent');select public.boss_payments_mutate(jsonb_build_object('action','checkout.prepare','request_id',pg_temp.f('fee-request'),'input',jsonb_build_object('organization_id',pg_temp.f('org'),'routing_id',pg_temp.f('rails-route'),'method','card','currency','USD','bucks_minor',0,'allocations',jsonb_build_array(jsonb_build_object('charge_id',pg_temp.f('charge-camp'),'amount_minor',10000,'bucks_minor',0)))));"
 fi
 printf '%s\n' 'begin;' "\\ir '$race_dir/7d-$label-fixture.sql'" "update public.organization_modules set configuration=configuration||'{\"refunds\":true}'::jsonb where module_id=(select id from public.modules where key='payments')and organization_id=pg_temp.f('org');" "$prepare" 'commit;' >"$race_dir/7d-$label-setup.sql"
 if ! "${psql_cmd[@]}" --file "$race_dir/7d-$label-setup.sql" >"$race_dir/7d-$label-setup.out" 2>"$race_dir/7d-$label-setup.err";then head -n 8 "$race_dir/7d-$label-setup.err" >&2;fail "$label setup";fi
 if [[ $stage == fee || $stage == fee_ready ]];then checkout=$(lookup "select id from public.payment_checkouts where request_id=md5('$prefix:fee-request')::uuid");checkout="'$checkout'::uuid";fi
 if [[ $stage == submitted || $stage == fee ]];then lookup "select boss_private.rails_dispatch($checkout);" >/dev/null;fi
 amount=$(lookup "select external_minor from public.payment_checkouts where id=$checkout")
 tx="LOCAL-RACE-$label"
}
receive(){ local kind=$1 ref=${2:-$1};printf '%s' "select boss_private.rails_receive($checkout,'$prefix-$ref','$kind','$tx',$amount,'USD',clock_timestamp(),encode(sha256(convert_to('$prefix-$ref','UTF8')),'hex'),$( [[ $kind == failed ]]&&printf "'{\"failure_contract\":\"definitive_failure\"}'::jsonb"||printf "'{}'::jsonb" ));"; }
assert_one(){ assert_sql "$1" "select count(*)=1 from public.external_payment_tenders where checkout_id=$checkout and original_payment_id is null"; }
setup expiry card ready expiry
race expiry "select boss_private.rails_checkout_fence($checkout);" "select boss_private.rails_dispatch($checkout);" PT409 1.1
assert_sql 'expired undispatched attempt created no operation' "select not exists(select 1 from public.provider_operations where checkout_id=$checkout)"
setup campaign card ready
race campaign "update public.fundraising_campaigns set ends_at=clock_timestamp()+interval'500 milliseconds'where organization_id=$org;" "select boss_private.rails_dispatch($checkout);" PT409 1.1
assert_sql 'new submission after natural campaign end denied' "select not exists(select 1 from public.payment_eligibility_commits where checkout_id=$checkout)"
setup webhook_expiry
race webhook_expiry "$(receive captured)" "select boss_private.rails_checkout_fence($checkout);select boss_private.rails_expire();" success
assert_one 'ordinary expiry cannot discard a committed success'
setup ach_status ach
race ach_status "$(receive settled)" "$(receive failed)" success
assert_one 'ACH success/failure race retains one success plus contradiction evidence'
assert_sql 'failure after success did not release canonical success' "select state='completed'from public.payment_checkouts where id=$checkout"
setup unknown_retry
lookup "$(receive unknown)" >/dev/null
race unknown_retry "$(receive captured)" "select boss_private.rails_dispatch($checkout);" success
assert_one 'unknown reconcile/retry created one original success'
assert_sql 'unknown retry retains one provider identity' "select count(*)=1 from public.provider_operations where checkout_id=$checkout"
setup cancel_first
race cancel_first "select boss_private.rails_invalidate($checkout,'reviewed_cancel',null,md5('$prefix:admin')::uuid);" "$(receive captured)" success
assert_sql 'cancel first routes late money to review' "select state='captured_unallocated'from public.payment_checkouts where id=$checkout"
setup success_first
race success_first "$(receive captured)" "select boss_private.rails_invalidate($checkout,'reviewed_cancel',null,md5('$prefix:admin')::uuid);" PT409
assert_one 'success first requires explicit original tender correction'
setup tile_release
# Supply only the synthetic fixture capability generated from the known label;
# this is not a browser cookie, Auth token or real customer capability.
capability=$(python3 - "$prefix" <<'PY'
import hashlib,sys
print(hashlib.md5((sys.argv[1]+'railscase').encode()).hexdigest()+hashlib.md5((sys.argv[1]+'rails-secondcase').encode()).hexdigest())
PY
)
path=$(lookup "select path from public.fundraising_shares where fundraiser_id in(select fundraiser_id from public.fundraising_intents where id=(select intent_id from public.payment_checkouts where id=$checkout))")
race tile_release "$(receive captured)" "select public.boss_fundraising_support(jsonb_build_object('action','release','request_id',gen_random_uuid(),'input',jsonb_build_object('path','$path','capability','$capability')));" PT409
assert_one 'published paid tile cannot be released by supporter cancellation'
setup charge_cancel card fee
race charge_cancel "$(receive captured)" "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('$prefix:auth-admin')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('$prefix:session-admin')::uuid)::text,true);select public.boss_registration_mutate(gen_random_uuid(),jsonb_build_object('operation','charge.cancel','input',jsonb_build_object('charge_id',md5('$prefix:charge-camp')::uuid,'reason','Synthetic cancel')));" PT409
assert_one 'provider success prevents charge cancellation'
setup capture_refund
race capture_refund "$(receive captured)" "select boss_private.rails_checkout_fence($checkout);select boss_private.rails_refund_prepare(md5('$prefix:admin')::uuid,jsonb_build_object('action','refund.prepare','request_id',md5('$prefix:refund-request')::uuid,'input',jsonb_build_object('payment_id',(select payment_id from public.external_payment_tenders where checkout_id=$checkout),'amount_minor',50,'principal_minor',50,'allocations',jsonb_build_array(),'reason','Synthetic refund')));" success
assert_sql 'refund dispatch is prepared only after valid capture' "select count(*)=1 from public.payment_refund_requests where organization_id=$org"
setup reconcile
race reconcile "$(receive captured)" "select boss_private.rails_checkout_fence($checkout);select boss_private.rails_receive($checkout,'$prefix-batch','settled','$tx',$amount,'USD',clock_timestamp(),repeat('a',64),'{\"processor_fee_minor\":1}');select boss_private.rails_settlement_match((select payment_id from public.external_payment_tenders where checkout_id=$checkout),(select id from public.provider_event_evidence where event_reference='$prefix-batch'),1);" success
assert_one 'concurrent settlement processing never duplicates payment'
assert_sql 'concurrent settlement has one source' "select count(*)=1 from public.settlement_sources where payment_id=(select payment_id from public.external_payment_tenders where checkout_id=$checkout)"
assert_sql 'all settlement journals balanced' "select not exists(select journal_id from public.settlement_postings group by journal_id having sum(amount_minor)<>0)"
setup duplicate_webhook
fixed_at=$(lookup 'select clock_timestamp()')
webhook_sql=$(receive captured replay)
webhook_sql=${webhook_sql//clock_timestamp()/\'$fixed_at\'::timestamptz}
race duplicate_webhook "$webhook_sql" "$webhook_sql" success
assert_one 'concurrent identical webhook creates one payment'
setup account_disable card ready
race account_disable "update public.processing_accounts set status='disabled',version=version+1,updated_at=clock_timestamp()where id=md5('$prefix:rails-account')::uuid;" "select boss_private.rails_dispatch($checkout);" PT409
assert_sql 'disabled processing account cannot dispatch' "select not exists(select 1 from public.payment_eligibility_commits where checkout_id=$checkout)"
setup routing_disable card ready
race routing_disable "select boss_private.rails_checkout_fence($checkout);insert into public.payment_routing_events(routing_id,state,actor_id)values(md5('$prefix:fundraising-route')::uuid,'disabled',md5('$prefix:admin')::uuid);" "select boss_private.rails_dispatch($checkout);" PT409
setup guardian_remove card fee_ready
race guardian_remove "update public.guardian_relationships set can_manage_payments=false where guardian_person_id=md5('$prefix:parent')::uuid;" "select boss_private.rails_dispatch($checkout);" PT409
setup double_refund
lookup "$(receive captured)" >/dev/null
refund_command="select boss_private.rails_refund_prepare(md5('$prefix:admin')::uuid,jsonb_build_object('action','refund.prepare','request_id',gen_random_uuid(),'input',jsonb_build_object('payment_id',(select payment_id from public.external_payment_tenders where checkout_id=$checkout),'amount_minor',80,'principal_minor',80,'allocations',jsonb_build_array(),'reason','Synthetic race refund')));"
race double_refund "$refund_command" "$refund_command" PT409
assert_sql 'concurrent refunds cannot reserve more than original remainder' "select sum(amount_minor)=80 from public.payment_refund_requests where organization_id=$org"
setup refund_chargeback
lookup "$(receive captured)" >/dev/null
refund_sql="select boss_private.rails_refund_prepare(md5('$prefix:admin')::uuid,jsonb_build_object('action','refund.prepare','request_id',md5('$prefix:pending-refund')::uuid,'input',jsonb_build_object('payment_id',(select payment_id from public.external_payment_tenders where checkout_id=$checkout),'amount_minor',50,'principal_minor',50,'allocations',jsonb_build_array(),'reason','Synthetic pending refund')));"
lookup "$refund_sql" >/dev/null
race refund_chargeback "$(receive disputed)select boss_private.rails_external_correct((select payment_id from public.external_payment_tenders where checkout_id=$checkout and original_payment_id is null),(select id from public.provider_event_evidence where event_reference='$prefix-disputed'),'chargeback',$amount);" "select boss_private.rails_refund_dispatch((select id from public.payment_refund_requests where request_id=md5('$prefix:pending-refund')::uuid));" PT409
assert_sql 'chargeback prevents dispatch of a now-unfunded pending refund' "select not exists(select 1 from public.provider_operations where checkout_id=$checkout and kind='refund'and dispatched_at is not null)"
setup simultaneous_checkout card fee_ready
family_auth="set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('$prefix:auth-parent')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('$prefix:session-parent')::uuid)::text,true);"
prepare_sql="select public.boss_payments_mutate(jsonb_build_object('action','checkout.prepare','request_id',md5('$prefix:gear-checkout')::uuid,'input',jsonb_build_object('organization_id',$org,'routing_id',md5('$prefix:rails-route')::uuid,'method','card','currency','USD','bucks_minor',0,'allocations',jsonb_build_array(jsonb_build_object('charge_id',md5('$prefix:charge-gear')::uuid,'amount_minor',10000,'bucks_minor',0)))));"
race simultaneous_checkout "$family_auth $prepare_sql" "$family_auth $prepare_sql" success
assert_sql 'same browser request creates one checkout under observed contention' "select count(*)=1 from public.payment_checkouts where request_id=md5('$prefix:gear-checkout')::uuid"

refund_event(){ local label=$1;printf '%s' "do \$\$declare r jsonb;begin r:=boss_private.rails_refund_prepare(md5('$prefix:admin')::uuid,jsonb_build_object('action','refund.prepare','request_id',md5('$prefix:$label-request')::uuid,'input',jsonb_build_object('payment_id',(select payment_id from public.external_payment_tenders where checkout_id=$checkout and original_payment_id is null),'amount_minor',50,'principal_minor',50,'allocations',jsonb_build_array(),'reason','Synthetic original tender race')));perform boss_private.rails_refund_dispatch((r->>'refund_id')::uuid);perform boss_private.rails_refund_receive((r->>'refund_id')::uuid,'$prefix:$label-result','refunded','LOCAL-$label-REFUND',50,'USD',clock_timestamp(),repeat('c',64));end\$\$;"; }
batch_event(){ printf '%s' "select boss_private.rails_receive($checkout,'$prefix-batch','settled','$tx',$amount,'USD',clock_timestamp(),repeat('b',64),'{\"processor_fee_minor\":0}');select boss_private.rails_settlement_match((select payment_id from public.external_payment_tenders where checkout_id=$checkout and original_payment_id is null),(select id from public.provider_event_evidence where account_id=md5('$prefix:rails-account')::uuid and event_reference='$prefix-batch'),0);"; }
setup actual_capture_refund
race actual_capture_refund "$(receive captured)" "select boss_private.rails_checkout_fence($checkout);$(refund_event capture)" success
assert_sql 'capture/refund event preserves one success and one correction' "select count(*)=1 from public.external_payment_corrections where original_payment_id=(select payment_id from public.external_payment_tenders where checkout_id=$checkout and original_payment_id is null)"
setup refund_before_batch
lookup "$(receive captured)" >/dev/null
race refund_before_batch "$(refund_event before)" "$(batch_event)" success
assert_sql 'refund before batch attributes only remaining principal' "select amount_minor=35 from public.settlement_events where payment_id=(select payment_id from public.external_payment_tenders where checkout_id=$checkout and original_payment_id is null)and kind='settled'"
setup batch_before_refund
lookup "$(receive captured)" >/dev/null
race batch_before_refund "$(batch_event)" "$(refund_event after)" success
assert_sql 'refund after direct settlement creates same-org deficit' "select amount_minor=35 from public.settlement_deficits where organization_id=$org"
setup ach_return ach
race ach_return "$(receive settled)" "select boss_private.rails_checkout_fence($checkout);$(receive returned)select boss_private.rails_external_correct((select payment_id from public.external_payment_tenders where checkout_id=$checkout and original_payment_id is null),(select id from public.provider_event_evidence where event_reference='$prefix-returned'),'ach_return',$amount);" success
assert_sql 'ACH success/return retains one success and one subsequent correction' "select count(*)=1 from public.external_payment_corrections where kind='ach_return'and original_payment_id=(select payment_id from public.external_payment_tenders where checkout_id=$checkout and original_payment_id is null)"

printf 'PASS Phase 7D: %s observed database concurrency races.\n' "$race_count"
