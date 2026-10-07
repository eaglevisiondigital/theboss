#!/usr/bin/env bash
# Two real connections; private disposable PostgreSQL only, synthetic data only.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]];then printf '%s\n' 'Phase7C races require the private disposable runner socket.' >&2;exit 1;fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd);race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do [[ -z "$pid" ]]||{ kill "$pid" >/dev/null 2>&1||true;wait "$pid" >/dev/null 2>&1||true;};done;exit "$result";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase7C concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
lookup(){ "${psql_cmd[@]}" --command "$1"; }
assert_sql(){ [[ $(lookup "$2") == t ]]||fail "$1"; }
await_state(){ local app=$1 expected=$2 pid=$3 deadline=$((SECONDS+7)) query;if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app'and state='idle in transaction'and query like'%phase7c-writer-ready%'";else query="select count(*) from pg_stat_activity where application_name='$app'and wait_event_type='Lock'";fi;while((SECONDS<deadline));do kill -0 "$pid" >/dev/null 2>&1||return 1;[[ $(lookup "$query") == 1 ]]&&return 0;sleep .025;done;return 1; }
race(){ local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold=${5:-0};local fifo="$race_dir/phase7c-$label.stdin" rc=0;mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/7c-$label-w.out" 2>"$race_dir/7c-$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_phase7c_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase7c-writer-ready */;" >&9;await_state "boss_phase7c_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/7c-$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set application_name='boss_phase7c_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/7c-$label-c.out" 2>"$race_dir/7c-$label-c.err"&contender_pid=$!;await_state "boss_phase7c_${label}_contender" waiting "$contender_pid"||{ head -n 8 "$race_dir/7c-$label-c.err" >&2;fail "$label contender did not block";};if [[ "$hold" != 0 ]];then sleep "$hold";fi;printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||{ head -n 8 "$race_dir/7c-$label-w.err" >&2;fail "$label writer";};writer_pid='';if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid='';if [[ "$expected" == success && "$rc" != 0 ]];then head -n 8 "$race_dir/7c-$label-c.err" >&2;fail "$label contender";fi;if [[ "$expected" != success ]]&&{ [[ "$rc" == 0 ]]||! grep -Fq "$expected" "$race_dir/7c-$label-c.err";};then head -n 8 "$race_dir/7c-$label-c.err" >&2;fail "$label expected $expected";fi;race_count=$((race_count+1)); }
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('$prefix:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('$prefix:session-$1')::uuid)::text,true);"; }
spend(){ printf '%s' "select public.boss_bucks_mutate(jsonb_build_object('action','payment.spend','request_id',md5('$prefix:request-$3')::uuid,'input',jsonb_build_object('wallet_id','$wallet','organization_id',$org,'currency','USD','amount_minor',$1,'allocations',jsonb_build_array(jsonb_build_object('charge_id',md5('$prefix:charge-$2')::uuid,'amount_minor',$1)))));"; }
offline(){ printf '%s' "select public.boss_registration_mutate(gen_random_uuid(),jsonb_build_object('operation','payment.record_offline','input',jsonb_build_object('organization_id',$org,'method','cash','amount_minor',$1,'currency','USD','payer_person_id',md5('$prefix:parent')::uuid,'received_at',clock_timestamp(),'allocations',jsonb_build_array(jsonb_build_object('charge_id',md5('$prefix:charge-camp')::uuid,'amount_minor',$1)))));"; }
reverse(){ printf '%s' "select public.boss_bucks_mutate(jsonb_build_object('action','payment.reverse','request_id',md5('$prefix:request-$2')::uuid,'input',jsonb_build_object('payment_id','$payment','reason','Synthetic controlled correction','allocations',jsonb_build_array(jsonb_build_object('allocation_id','$allocation','amount_minor',$1)))));"; }
setup(){ local label=$1 before=${2:-} after=${3:-} slug;slug=${label//_/-};prefix="boss-phase7c-race-$label";org="md5('$prefix:org')::uuid";guardian="md5('$prefix:guardian-child1')::uuid";
 sed -e "s/boss-phase7b-test:/$prefix:/g" -e "s/phase7b.example.invalid/$slug.phase7c-race.example.invalid/g" -e "s/synthetic-phase7b-/synthetic-$slug-phase7c-/g" "$test_dir/phase7b/fixture.sql" >"$race_dir/phase7c-$label-fixture.sql"
 tail -n +3 "$test_dir/phase7c/fixture.sql" >>"$race_dir/phase7c-$label-fixture.sql"
 printf '%s\n' 'begin;' "\\ir '$race_dir/phase7c-$label-fixture.sql'" "$before" "select pg_temp.success('$label-initial',10000);" "$after" 'commit;' >"$race_dir/phase7c-$label-setup.sql"
 if ! "${psql_cmd[@]}" --file "$race_dir/phase7c-$label-setup.sql" >"$race_dir/7c-$label-setup.out" 2>"$race_dir/7c-$label-setup.err";then head -n 8 "$race_dir/7c-$label-setup.err" >&2;fail "$label setup";fi
 wallet=$(lookup "select id from public.boss_bucks_wallets where household_id=md5('$prefix:household')::uuid")
 evidence=$(lookup "select id from public.fundraising_success_evidence where source_reference='$label-initial'")
 grant=$(lookup "select id from public.boss_bucks_grants where evidence_id='$evidence'")
}
available(){ assert_sql "$1" "select boss_private.bucks_available('$wallet')=$2"; }
pay_before(){ lookup "begin;$(auth parent)$(spend "$1" camp original)commit;" >"$race_dir/7c-paid-before.out";payment=$(lookup "select payment_id from public.boss_bucks_tenders where request_id=md5('$prefix:request-original')::uuid");allocation=$(lookup "select id from public.payment_allocations where payment_id='$payment'"); }

setup wallet
race wallet "$(auth parent)$(spend 3000 camp one)" "$(auth parent)$(spend 3000 gear two)" PT409
available 'two charges cannot overspend one wallet' 2000
setup charge
lookup "begin;$(auth admin)$(offline 7000)commit;" >/dev/null
race charge "$(auth parent)$(spend 2000 camp one)" "$(auth parent)$(spend 2000 camp two)" PT409
assert_sql 'same-charge balance prevents overpayment' "select boss_private.registration_charge_balance(md5('$prefix:charge-camp')::uuid)->>'balance_due_minor'='1000'"
available 'rejected charge contender leaves wallet intact' 3000
setup replay
race replay "$(auth parent)$(spend 1000 camp same)" "$(auth parent)$(spend 1000 camp same)" success
assert_sql 'concurrent replay creates one tender' "select count(*)=1 from public.boss_bucks_tenders where wallet_id='$wallet'"
available 'concurrent replay debits once' 4000
setup adjustment
race adjustment "$(auth admin)select public.boss_registration_mutate(gen_random_uuid(),jsonb_build_object('operation','charge.adjust','input',jsonb_build_object('charge_id',md5('$prefix:charge-camp')::uuid,'adjustment_type','credit','amount_minor',-9500,'reason','Synthetic credit')));" "$(auth parent)$(spend 1000 camp one)" PT409
available 'credit race does not move Bucks' 5000
setup cash_first
race cash_first "$(auth admin)$(offline 9000)" "$(auth parent)$(spend 2000 camp one)" PT409
available 'cash allocation wins without Bucks overpayment' 5000
setup bucks_first
race bucks_first "$(auth parent)$(spend 1000 camp one)" "$(auth admin)$(offline 10000)" PT409
available 'Bucks wins before oversized cash receipt' 4000
setup reverse_spend;pay_before 4000
race reverse_spend "$(auth admin)$(reverse 1000 reversal)" "$(auth parent)$(spend 2000 gear two)" success
available 'new spend sees committed reversal' 0
assert_sql 'charge reversal and new obligation remain canonical' "select boss_private.registration_charge_balance(md5('$prefix:charge-camp')::uuid)->>'balance_due_minor'='7000'and boss_private.registration_charge_balance(md5('$prefix:charge-gear')::uuid)->>'balance_due_minor'='8000'"
setup reverse_duplicate;pay_before 4000
race reverse_duplicate "$(auth admin)$(reverse 3000 first)" "$(auth admin)$(reverse 3000 second)" PT409
available 'two reversals cannot return more than original' 4000
setup source_first
race source_first "select boss_private.bucks_reverse_source('$evidence','Synthetic source loss');" "$(auth parent)$(spend 1000 camp one)" PT409
available 'unspent source loss fences later spend' 0
setup spend_first
race spend_first "$(auth parent)$(spend 4000 camp one)" "select boss_private.bucks_reverse_source('$evidence','Synthetic source loss');" success
available 'spent loss keeps spendable value nonnegative' 0
assert_sql 'source loss preserves payment and records recovery' "select boss_private.bucks_recovery_due('$wallet',$org)=4000 and boss_private.registration_charge_balance(md5('$prefix:charge-camp')::uuid)->>'balance_due_minor'='6000'"

# Prepare trusted synthetic source evidence with issuance disabled, then allow
# the two independent transactions to race on correction/issuance, not setup.
setup deficit_grant '' "update public.organization_modules set configuration=configuration||'{\"fundraising_issuance\":false}'::jsonb where organization_id=pg_temp.f('org')and module_id in(select id from public.modules where key='boss_bucks');select pg_temp.success('deficit-future',10000);update public.organization_modules set configuration=configuration||'{\"fundraising_issuance\":true}'::jsonb where organization_id=pg_temp.f('org')and module_id in(select id from public.modules where key='boss_bucks');"
pay_before 4000
future=$(lookup "select id from public.fundraising_success_evidence where source_reference='deficit-future'")
race deficit_grant "select boss_private.bucks_reverse_source('$evidence','Synthetic source loss');" "select boss_private.bucks_issue('$future');" success
available 'future earning pays recovery and preserves excess' 1000
assert_sql 'future recovery remains scoped and balanced' "select boss_private.bucks_recovery_due('$wallet',$org)=0 and(select count(*)=1 from public.boss_bucks_grants where evidence_id='$future')"
race recovery_replay "select boss_private.bucks_issue('$future');" "select boss_private.bucks_issue('$future');" success
available 'recovery replay cannot consume future earning twice' 1000

setup expiration "insert into public.boss_bucks_policy_revisions(campaign_id,organization_id,revision,mode,basis_points,currency,channels,expiry_seconds,created_by,request_id)values(pg_temp.fid('campaign'),pg_temp.f('org'),2,'percentage',5000,'USD',array['direct_support'],1,pg_temp.f('admin'),gen_random_uuid());"
lookup 'select pg_sleep(1.1)' >/dev/null
race expiration "select boss_private.bucks_expire();" "$(auth parent)$(spend 1000 camp one)" PT409
available 'materialized expiry excludes value from spend' 0
setup wait_expiry "insert into public.boss_bucks_policy_revisions(campaign_id,organization_id,revision,mode,basis_points,currency,channels,expiry_seconds,created_by,request_id)values(pg_temp.fid('campaign'),pg_temp.f('org'),2,'percentage',5000,'USD',array['direct_support'],1,pg_temp.f('admin'),gen_random_uuid());"
race wait_expiry "select id from public.charges where id=md5('$prefix:charge-camp')::uuid for update;" "$(auth parent)$(spend 1000 camp one)" PT409 1.1
available 'grant expiry while waiting cannot be spent' 0
setup guardian
race guardian "update public.guardian_relationships set can_manage_payments=false where id=$guardian;" "$(auth parent)$(spend 1000 camp one)" PT403
available 'payment guardian revocation prevents stale spend' 5000
setup guardian_deadline '' "update public.guardian_relationships set ends_at=clock_timestamp()+interval'1 second'where id=pg_temp.f('guardian-child1');"
race guardian_deadline "select id from public.charges where id=md5('$prefix:charge-camp')::uuid for update;" "$(auth parent)$(spend 1000 camp one)" PT403 1.1
available 'guardian natural expiry during charge wait prevents spend' 5000
setup inactive_identity
race inactive_identity "update public.user_accounts set account_status='inactive'where person_id=md5('$prefix:parent')::uuid;" "$(auth parent)$(spend 1000 camp one)" PT401
available 'Boss account deactivation fences stale spending' 5000
setup removed_session
race removed_session "delete from auth.sessions where id=md5('$prefix:session-parent')::uuid;" "$(auth parent)$(spend 1000 camp one)" PT401
available 'removed managed Auth session fences stale spending' 5000
setup wallet_authority
race wallet_authority "update public.boss_bucks_access set status='ended',ends_at=clock_timestamp()where wallet_id='$wallet';" "$(auth parent)$(spend 1000 camp one)" PT403
available 'wallet manager revocation prevents stale spend' 5000
setup feature
race feature "update public.organization_modules set configuration=configuration||'{\"wallet_spending\":false}'::jsonb where organization_id=$org and module_id in(select id from public.modules where key='boss_bucks');" "$(auth parent)$(spend 1000 camp one)" PT403
available 'feature closure fences spending' 5000
setup reversal_role;pay_before 1000
race reversal_role "update public.role_assignments set status='inactive'where id=md5('$prefix:role-admin')::uuid;" "$(auth admin)$(reverse 500 reversal)" PT403
available 'finance role revocation fences reversal' 4000
setup partial_source
race partial_source "select boss_private.bucks_correct_source('$grant',5000,'Synthetic partial correction');" "$(auth parent)$(spend 3000 camp one)" PT409
available 'partial source entitlement applies after wait' 2500
setup reverse_source;pay_before 4000
race reverse_source "select boss_private.bucks_reverse_source('$evidence','Synthetic source loss');" "$(auth admin)$(reverse 1000 reversal)" success
available 'invalid payment return never recreates invalid value' 0
assert_sql 'invalid return cancels its outstanding claim' "select boss_private.bucks_recovery_due('$wallet',$org)=3000"
setup source_reverse;pay_before 4000
race source_reverse "$(auth admin)$(reverse 1000 reversal)" "select boss_private.bucks_reverse_source('$evidence','Synthetic source loss');" success
available 'source correction sees committed payment return' 0
assert_sql 'source correction tracks actual net consumption' "select boss_private.bucks_recovery_due('$wallet',$org)=3000"
# Binding covered-recovery release races, with true observed lock waits.
prepare_covered(){
 setup "$1" '' "update public.organization_modules set configuration=configuration||'{\"fundraising_issuance\":false}'::jsonb where organization_id=pg_temp.f('org')and module_id in(select id from public.modules where key='boss_bucks');select pg_temp.success('$1-replacement',10000);update public.organization_modules set configuration=configuration||'{\"fundraising_issuance\":true}'::jsonb where organization_id=pg_temp.f('org')and module_id in(select id from public.modules where key='boss_bucks');"
 pay_before 4000
 lookup "select boss_private.bucks_reverse_source('$evidence','Synthetic original source invalidation');" >/dev/null
 future=$(lookup "select id from public.fundraising_success_evidence where source_reference='$1-replacement'")
}
prepare_covered release_then_satisfy
race release_then_satisfy "$(auth admin)$(reverse 1000 returned)" "select boss_private.bucks_issue('$future');" success
available 'new earning satisfies only exposure remaining after return' 2000
assert_sql 'return before future recovery retains exact liability' "select boss_private.bucks_recovery_due('$wallet',$org)=0 and(select sum(case kind when'open'then amount_minor when'cancel'then -amount_minor else 0 end)=3000 from public.boss_bucks_recovery_movements where claim_id in(select id from public.boss_bucks_recovery_claims where grant_id='$grant'))"
prepare_covered satisfy_then_release
race satisfy_then_release "select boss_private.bucks_issue('$future');" "$(auth admin)$(reverse 1000 returned)" success
available 'return after recovery releases recorded replacement' 2000
assert_sql 'covered return records exact replacement release' "select sum(amount_minor)=1000 from public.boss_bucks_recovery_movements where kind='release'and payment_reversal_id in(select payment_id from public.boss_bucks_tenders where original_payment_id='$payment')"
prepare_covered replacement_loss_first
lookup "select boss_private.bucks_issue('$future');" >/dev/null
race replacement_loss_first "select boss_private.bucks_reverse_source('$future','Synthetic replacement loss');" "$(auth admin)$(reverse 4000 returned)" success
available 'replacement loss before return never resurrects value' 0
assert_sql 'replacement loss and original return unwind dependent recovery' "select boss_private.bucks_recovery_due('$wallet',$org)=0"
prepare_covered replacement_loss_last
lookup "select boss_private.bucks_issue('$future');" >/dev/null
race replacement_loss_last "$(auth admin)$(reverse 4000 returned)" "select boss_private.bucks_reverse_source('$future','Synthetic replacement loss');" success
available 'replacement loss after return removes current released value' 0
assert_sql 'return and later replacement loss leave no invented deficit' "select boss_private.bucks_recovery_due('$wallet',$org)=0"
prepare_covered release_then_spend
lookup "select boss_private.bucks_issue('$future');" >/dev/null
race release_then_spend "$(auth admin)$(reverse 3000 returned)" "$(auth parent)$(spend 4000 gear new)" success
available 'competing spend uses newly released value exactly once' 0
prepare_covered spend_then_release
lookup "select boss_private.bucks_issue('$future');" >/dev/null
race spend_then_release "$(auth parent)$(spend 1000 gear new)" "$(auth admin)$(reverse 4000 returned)" success
available 'return preserves earlier separate payment consumption' 4000
prepare_covered release_replay
lookup "select boss_private.bucks_issue('$future');" >/dev/null
race release_replay "$(auth admin)$(reverse 4000 same)" "$(auth admin)$(reverse 4000 same)" success
available 'covered reversal replay releases value once' 5000
assert_sql 'covered replay has one root cancellation and one satisfaction unwind' "select count(*)=2 and sum(amount_minor)=8000 from public.boss_bucks_recovery_movements where payment_reversal_id in(select payment_id from public.boss_bucks_tenders where original_payment_id='$payment')"

for isolation in repeatable_read serializable;do
 setup "$isolation"
 level=${isolation//_/ }
 race "$isolation" "$(auth parent)$(spend 1000 camp one)" "set transaction isolation level $level;select boss_private.bucks_available('$wallet');$(auth parent)$(spend 3000 gear two)" 40001
 available 'stale stronger-isolation spend must retry' 4000
done
assert_sql 'every committed journal remains balanced' "select not exists(select journal_id from public.boss_bucks_postings group by journal_id having count(*)<>2 or sum(amount_minor)<>0)"
printf 'PASS Phase 7C: %s observed concurrency races including binding covered-recovery release.\n' "$race_count"
