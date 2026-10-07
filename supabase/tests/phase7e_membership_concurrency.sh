#!/usr/bin/env bash
# Two real connections; private disposable PostgreSQL only, synthetic data only.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]];then printf '%s\n' 'Phase7E races require the private disposable runner socket.' >&2;exit 1;fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd);race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do [[ -z "$pid" ]]||{ kill "$pid" >/dev/null 2>&1||true;wait "$pid" >/dev/null 2>&1||true;};done;exit "$result";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase7E concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
lookup(){ "${psql_cmd[@]}" --command "$1"; }
assert_sql(){ [[ $(lookup "$2") == t ]]||fail "$1"; }
await_state(){ local app=$1 expected=$2 pid=$3 deadline=$((SECONDS+7)) query;if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app'and state='idle in transaction'and query like'%phase7e-writer-ready%'";else query="select count(*) from pg_stat_activity where application_name='$app'and wait_event_type='Lock'";fi;while((SECONDS<deadline));do kill -0 "$pid" >/dev/null 2>&1||return 1;[[ $(lookup "$query") == 1 ]]&&return 0;sleep .025;done;return 1; }
race(){ local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold=${5:-0};local fifo="$race_dir/phase7e-$label.stdin" rc=0;mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/7e-$label-w.out" 2>"$race_dir/7e-$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_phase7e_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase7e-writer-ready */;" >&9;await_state "boss_phase7e_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/7e-$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set application_name='boss_phase7e_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/7e-$label-c.out" 2>"$race_dir/7e-$label-c.err"&contender_pid=$!;await_state "boss_phase7e_${label}_contender" waiting "$contender_pid"||{ head -n 8 "$race_dir/7e-$label-c.err" >&2;fail "$label contender did not block";};if [[ "$hold" != 0 ]];then sleep "$hold";fi;printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||{ head -n 8 "$race_dir/7e-$label-w.err" >&2;fail "$label writer";};writer_pid='';if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid='';if [[ "$expected" == success && "$rc" != 0 ]];then head -n 8 "$race_dir/7e-$label-c.err" >&2;fail "$label contender";fi;if [[ "$expected" != success ]]&&{ [[ "$rc" == 0 ]]||! grep -Fq "$expected" "$race_dir/7e-$label-c.err";};then head -n 8 "$race_dir/7e-$label-c.err" >&2;fail "$label expected $expected";fi;race_count=$((race_count+1)); }
setup(){
 local label=$1 extra=${2:-''}
 prefix="boss-phase7e-race-${label//_/-}";org="md5('$prefix:org')::uuid";admin="md5('$prefix:admin')::uuid";parent="md5('$prefix:parent')::uuid"
 awk '!/^\\ir /' "$test_dir/phase7b/fixture.sql" "$test_dir/phase7c/fixture.sql" "$test_dir/phase7d/fixture.sql" "$test_dir/phase7e/fixture.sql" |
 sed -e "s/'rails-source'/'$prefix-rails-source'/g" -e "s/boss-phase7b-test:/$prefix:/g" -e "s/synthetic-phase7b-/synthetic-$prefix-/g" -e "s/phase7b\.example\.invalid/$prefix.example.invalid/g" -e "s/\"code\":\"synthetic_/\"code\":\"${label}_synthetic_/g" >"$race_dir/7e-$label-fixture.sql"
 cat >"$race_dir/7e-$label-setup.sql" <<SQL
begin;
\ir '$race_dir/7e-$label-fixture.sql'
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.dm('stock','batch.create',jsonb_build_object('revision_id',pg_temp.did('card90','revision_id'),'organization_id',pg_temp.f('org'),'owner_type','organization','name','SYNTHETIC race stock','quantity',3,'controlled',true));
select pg_temp.dm('print','cards.print',jsonb_build_object('organization_id',pg_temp.f('org'),'card_ids',(select jsonb_agg(c->'card_id')from jsonb_array_elements(pg_temp.dr('stock')->'one_time_cards')c)));
reset role;
-- Inert known test proofs exist only in the networkless disposable fixture.
update boss_private.discount_card_secrets set digest=encode(sha256(convert_to(encode(sha256(convert_to('$prefix-card-'|| (select ordinal from public.discount_physical_cards where id=card_id),'UTF8')),'hex'),'UTF8')),'hex')where card_id in(select c.id from public.discount_physical_cards c join public.discount_card_batches b on b.id=c.batch_id where b.organization_id=pg_temp.f('org'));
create function pg_temp.intent_support(label text,amount bigint)returns void language plpgsql as \$\$begin
 set local role anon;
 perform public.boss_fundraising_support(jsonb_build_object('action','intent','request_id',pg_temp.f('request-'||label),'input',jsonb_build_object('path',pg_temp.fpath('share'),'capability',md5(pg_temp.f(label)::text)||md5(pg_temp.f(label||'2')::text),'display_name','Synthetic supporter','anonymous',true,'amount_minor',amount)));
 reset role;
end\$\$;
$extra
commit;
SQL
 if ! "${psql_cmd[@]}" --file "$race_dir/7e-$label-setup.sql" >"$race_dir/7e-$label-setup.out" 2>"$race_dir/7e-$label-setup.err";then head -n 8 "$race_dir/7e-$label-setup.err" >&2;fail "$label setup";fi
 revision=$(lookup "select r.id from public.discount_product_revisions r join public.discount_products p on p.id=r.product_id where p.code='${label}_synthetic_digital'and r.revision=1")
 card=$(lookup "select c.id from public.discount_physical_cards c join public.discount_card_batches b on b.id=c.batch_id where b.organization_id=$org and c.ordinal=1")
 replacement=$(lookup "select c.id from public.discount_physical_cards c join public.discount_card_batches b on b.id=c.batch_id where b.organization_id=$org and c.ordinal=2")
 serial=$(lookup "select serial from public.discount_physical_cards where id='$card'")
 replacement_serial=$(lookup "select serial from public.discount_physical_cards where id='$replacement'")
 cardproof=$(lookup "select encode(sha256(convert_to('$prefix-card-1','UTF8')),'hex')")
 replacementproof=$(lookup "select encode(sha256(convert_to('$prefix-card-2','UTF8')),'hex')")
 claimproof=$(lookup "select md5(md5('$prefix:claim')::uuid::text)||md5(md5('$prefix:claim2')::uuid::text)")
 campaign=$(lookup "select id from public.fundraising_campaigns where organization_id=$org")
 checkout=$(lookup "select checkout_id from public.discount_orders where request_id=md5('$prefix:discount-request-case')::uuid")
 order=$(lookup "select id from public.discount_orders where request_id=md5('$prefix:discount-request-case')::uuid")
}
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('$prefix:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('$prefix:session-$1')::uuid)::text,true);"; }
command(){ printf '%s' "select public.boss_discounts_mutate(jsonb_build_object('action','$1','request_id',gen_random_uuid(),'input',$2));"; }
receive(){ printf '%s' "select boss_private.rails_receive('$checkout','$prefix-$1','$1','LOCAL-$prefix',2500,'USD',clock_timestamp(),repeat('b',64),'{}'::jsonb);"; }
claim_card(){ printf '%s' "$(auth "$1")$(command card.claim "jsonb_build_object('serial','$2','activation_secret','${3:-$cardproof}')")"; }
pending_trial="select boss_private.discount_issue(pg_temp.did('base30','revision_id'),'fundraising_trial','trial:'||pg_temp.f('pending-trial'),pg_temp.f('org'),pg_temp.fid('campaign'),pg_temp.fid('fundraiser'),null,null,null,null,clock_timestamp(),clock_timestamp()+interval'30 days');select boss_private.discount_claim_issue(id)from public.discount_memberships where product_id=pg_temp.did('digital','product_id');update boss_private.discount_claims set digest=encode(sha256(convert_to(md5(pg_temp.f('claim')::text)||md5(pg_temp.f('claim2')::text),'UTF8')),'hex')where membership_id in(select id from public.discount_memberships where product_id=pg_temp.did('digital','product_id'));"
setup duplicate_claim "$pending_trial"
claim_input="jsonb_build_object('claim_secret','$claimproof')"
race duplicate_claim "$(auth parent)$(command membership.claim "$claim_input")" "$(auth household-only)$(command membership.claim "$claim_input")" PT404
assert_sql 'one exact person owns the pending membership' "select count(*)=1 and bool_and(subject_id=$parent)from public.discount_memberships where product_id=(select membership_product_id from public.discount_product_revisions where id='$revision')"
setup duplicate_card
race duplicate_card "$(claim_card parent "$serial")" "$(claim_card household-only "$serial")" PT404
assert_sql 'one physical claim and original trial' "select count(*)=1 from public.discount_member_sources where source_key='card-trial:$card'"
setup inventory_allocation
assign="$(auth admin)$(command cards.assign "jsonb_build_object('organization_id',$org,'campaign_id','$campaign','card_ids',jsonb_build_array('$card'))")"
race inventory_allocation "$assign" "$assign" PT409
assert_sql 'one assignment history item' "select count(*)=1 from public.discount_card_history where card_id='$card'and action='assigned'"
setup fulfillment_refund "set local role authenticated;select pg_temp.actor('parent');select pg_temp.product_order('case','card90','card',1,jsonb_build_object('path',pg_temp.fpath('share')));reset role;select boss_private.rails_dispatch(pg_temp.did('case','checkout_id'));select pg_temp.product_receive('case','captured');select pg_temp.actor('admin');select pg_temp.dm('refund','order.refund',jsonb_build_object('order_id',pg_temp.did('case','order_id'),'item_ids',(select jsonb_agg(id)from public.discount_order_items where order_id=pg_temp.did('case','order_id')),'reason','Synthetic race refund'));reset role;select boss_private.rails_refund_dispatch(pg_temp.did('refund','refund_id'));"
refund=$(lookup "select id from public.payment_refund_requests where request_id=md5('$prefix:discount-request-refund')::uuid")
race fulfillment_refund "select boss_private.rails_refund_receive('$refund','$prefix-refund','refunded','LOCAL-REFUND',2500,'USD',clock_timestamp(),repeat('d',64));" "select boss_private.discount_fulfill('$order');" PT409
assert_sql 'refund prevents fulfillment resurrection' "select state='refunded'from public.discount_orders where id='$order'"
# Make natural expiry a real clock boundary. The original dated source is
# immutable; no acceptance test rewrites its dates to manufacture expiry.
setup trial_gift_expiry "select pg_temp.intent_support('gift',2501);select boss_private.discount_issue(pg_temp.did('base30','revision_id'),'fundraising_trial','trial:'||pg_temp.f('near-expiry'),pg_temp.f('org'),pg_temp.fid('campaign'),pg_temp.fid('fundraiser'),(select donor_id from public.fundraising_intents where request_id=pg_temp.f('request-gift')),null,null,pg_temp.f('parent'),clock_timestamp()-interval'30 days'+interval'2 seconds',clock_timestamp()+interval'2 seconds');"
intent=$(lookup "select id from public.fundraising_intents where request_id=md5('$prefix:request-gift')::uuid")
member=$(lookup "select membership_id from public.discount_member_sources where source_key='trial:'||md5('$prefix:near-expiry')::uuid")
race trial_gift_expiry "select boss_private.fundraising_ingest_success('$intent','disposable-test','$prefix-gift',2501,'USD',clock_timestamp());" "select boss_private.discount_rebuild('$member');" success 2.1
assert_sql 'gift outlives natural trial expiry without extending trial' "select boss_private.discount_effective('$member')->>'source'='supporter_gift'and exists(select 1 from public.discount_member_sources where membership_id='$member'and kind='fundraising_trial'and ends_at<clock_timestamp())"
setup gift_reversal "select pg_temp.intent_support('gift',2501);select boss_private.discount_issue(pg_temp.did('base30','revision_id'),'fundraising_trial','trial:'||pg_temp.f('original-trial'),pg_temp.f('org'),pg_temp.fid('campaign'),pg_temp.fid('fundraiser'),(select donor_id from public.fundraising_intents where request_id=pg_temp.f('request-gift')),null,null,null,clock_timestamp(),clock_timestamp()+interval'30 days');select boss_private.discount_claim_issue(id)from public.discount_memberships where product_id=pg_temp.did('digital','product_id');update boss_private.discount_claims set digest=encode(sha256(convert_to(md5(pg_temp.f('claim')::text)||md5(pg_temp.f('claim2')::text),'UTF8')),'hex')where membership_id in(select id from public.discount_memberships where product_id=pg_temp.did('digital','product_id'));select boss_private.fundraising_ingest_success(id,'disposable-test','gift',2501,'USD',clock_timestamp())from public.fundraising_intents where request_id=pg_temp.f('request-gift');"
intent=$(lookup "select id from public.fundraising_intents where request_id=md5('$prefix:request-gift')::uuid")
race gift_reversal "insert into public.fundraising_intent_events(intent_id,state,source_reference,amount_minor,remaining_valid_amount_minor)values('$intent','partially_refunded','$prefix-reversal',1,2500);" "$(auth parent)$(command membership.claim "jsonb_build_object('claim_secret','$claimproof')")" success
assert_sql 'claim racing gift reversal retains only original valid trial' "select boss_private.discount_effective(id)->>'source'='fundraising_trial'from public.discount_memberships where subject_id=$parent"
setup upgrade_expiry "select boss_private.discount_issue(pg_temp.did('base30','revision_id'),'fundraising_trial','trial:'||pg_temp.f('expiring-base'),pg_temp.f('org'),pg_temp.fid('campaign'),pg_temp.fid('fundraiser'),null,null,null,pg_temp.f('parent'),clock_timestamp()-interval'30 days'+interval'2 seconds',clock_timestamp()+interval'2 seconds');select pg_temp.actor('parent');select pg_temp.product_order('case','upgrade-state','card',1,jsonb_build_object('base_source_id',(select id from public.discount_member_sources where source_key='trial:'||pg_temp.f('expiring-base'))));"
race upgrade_expiry "select boss_private.rails_checkout_fence('$checkout');" "select boss_private.rails_dispatch('$checkout');" PT409 2.1
assert_sql 'expiry before dispatch cannot buy an upgrade without base' "select not exists(select 1 from public.payment_eligibility_commits where checkout_id='$checkout')"
setup replacement_claim
lookup "$(claim_card parent "$serial")" >/dev/null
race replacement_claim "$(auth admin)$(command card.replace "jsonb_build_object('card_id','$card','replacement_card_id','$replacement','reason','lost')")" "$(claim_card parent "$replacement_serial" "$replacementproof")" success
assert_sql 'replacement race preserves one membership and original trial' "select count(*)=1 from public.discount_member_sources where source_key='card-trial:$card'"
assert_sql 'old replacement proof retired' "select revoked_at is not null from boss_private.discount_card_secrets where card_id='$card'"
setup revision_checkout
race revision_checkout "$(auth admin)$(command revision.status "jsonb_build_object('revision_id','$revision','state','disabled')")" "$(auth parent)$(command order.create "jsonb_build_object('revision_id','$revision','organization_id',$org,'quantity',1,'method','card')")" PT409
assert_sql 'revision disable prevents uncommitted checkout' "select not exists(select 1 from public.discount_orders where organization_id=$org)"
setup inventory_cancel "select pg_temp.actor('parent');select pg_temp.product_order('case','card90','card',1,jsonb_build_object('path',pg_temp.fpath('share')));select boss_private.rails_dispatch(pg_temp.did('case','checkout_id'));"
race inventory_cancel "select boss_private.rails_invalidate('$checkout','reviewed_cancel',null,$admin);" "$(receive captured)" success
assert_sql 'late capture after explicit cancellation goes to review' "select state='review'and payment_id is not null from public.discount_orders where id='$order'"
assert_sql 'cancellation cannot allocate inventory or issue fundraising credit' "select not exists(select 1 from public.discount_physical_cards where order_item_id in(select id from public.discount_order_items where order_id='$order'))and not exists(select 1 from public.discount_product_credits where item_id in(select id from public.discount_order_items where order_id='$order'))"
printf 'Phase 7E coordinated concurrency validation passed (%s races).\n' "$race_count"
