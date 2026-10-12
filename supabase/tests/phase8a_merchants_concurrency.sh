#!/usr/bin/env bash
# Two real connections; private disposable PostgreSQL only, synthetic data only.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]];then printf '%s\n' 'Phase8A races require the private disposable runner socket.' >&2;exit 1;fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd);race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do [[ -z "$pid" ]]||{ kill "$pid" >/dev/null 2>&1||true;wait "$pid" >/dev/null 2>&1||true;};done;exit "$result";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase8A concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
lookup(){ "${psql_cmd[@]}" --command "$1"; }
assert_sql(){ [[ $(lookup "$2") == t ]]||fail "$1"; }
await_state(){ local app=$1 expected=$2 pid=$3 deadline=$((SECONDS+7)) query;if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app'and state='idle in transaction'and query like'%phase8a-writer-ready%'";else query="select count(*) from pg_stat_activity where application_name='$app'and wait_event_type='Lock'";fi;while((SECONDS<deadline));do kill -0 "$pid" >/dev/null 2>&1||return 1;[[ $(lookup "$query") == 1 ]]&&return 0;sleep .025;done;return 1; }
race(){ local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold=${5:-0};local fifo="$race_dir/phase8a-$label.stdin" rc=0;mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/8a-$label-w.out" 2>"$race_dir/8a-$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_phase8a_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase8a-writer-ready */;" >&9;await_state "boss_phase8a_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/8a-$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set application_name='boss_phase8a_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/8a-$label-c.out" 2>"$race_dir/8a-$label-c.err"&contender_pid=$!;await_state "boss_phase8a_${label}_contender" waiting "$contender_pid"||{ head -n 8 "$race_dir/8a-$label-c.err" >&2;fail "$label contender did not block";};if [[ "$hold" != 0 ]];then sleep "$hold";fi;printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||{ head -n 8 "$race_dir/8a-$label-w.err" >&2;fail "$label writer";};writer_pid='';if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid='';if [[ "$expected" == success && "$rc" != 0 ]];then head -n 8 "$race_dir/8a-$label-c.err" >&2;fail "$label contender";fi;if [[ "$expected" != success ]]&&{ [[ "$rc" == 0 ]]||! grep -Fq "$expected" "$race_dir/8a-$label-c.err";};then head -n 8 "$race_dir/8a-$label-c.err" >&2;fail "$label expected $expected";fi;race_count=$((race_count+1)); }
setup(){
 local label=$1 extra=${2:-''}
 prefix="boss-phase8a-race-${label//_/-}";admin="md5('$prefix:admin')::uuid";parent="md5('$prefix:parent')::uuid"
 awk '!/^\\ir /' "$test_dir/phase7b/fixture.sql" "$test_dir/phase7c/fixture.sql" "$test_dir/phase7d/fixture.sql" "$test_dir/phase7e/fixture.sql" "$test_dir/phase8a/fixture.sql" |
 sed -e "s/'rails-source'/'$prefix-rails-source'/g" -e "s/boss-phase7b-test:/$prefix:/g" -e "s/synthetic-phase7b-/synthetic-$prefix-/g" -e "s/phase7b\.example\.invalid/$prefix.example.invalid/g" -e "s/\"code\":\"synthetic_/\"code\":\"${label}_synthetic_/g" -e "s/INERT DISPOSABLE BUSINESS PROOF /INERT DISPOSABLE BUSINESS PROOF $prefix /g" -e "s/SYNTHETIC LOCAL MARKET/$prefix LOCAL/g" -e "s/SYNTHETIC OTHER MARKET/$prefix OTHER/g" -e "s/SYNTHETIC CANADIAN MARKET/$prefix CANADA/g" >"$race_dir/8a-$label-fixture.sql"
 cat >"$race_dir/8a-$label-setup.sql" <<SQL
begin;
\ir '$race_dir/8a-$label-fixture.sql'
$extra
commit;
SQL
 if ! "${psql_cmd[@]}" --file "$race_dir/8a-$label-setup.sql" >"$race_dir/8a-$label-setup.out" 2>"$race_dir/8a-$label-setup.err";then head -n 8 "$race_dir/8a-$label-setup.err" >&2;fail "$label setup";fi
 merchant=$(result merchant merchant_id);other_merchant=$(result merchant-other merchant_id);location=$(result loc-a resource_id);family=$(result family resource_id);offer=$(result offer resource_id);clerk=$(result clerk resource_id)
 market=$(result market market_id)
 proof1=$(lookup "select encode(sha256(convert_to('INERT DISPOSABLE BUSINESS PROOF $prefix one','UTF8')),'hex')")
 proof2=$(lookup "select encode(sha256(convert_to('INERT DISPOSABLE BUSINESS PROOF $prefix two','UTF8')),'hex')")
}
result(){ lookup "select result->>'$2'from boss_private.merchant_receipts where request_id=md5('$prefix:merchant-request-$1')::uuid"; }
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('$prefix:auth-$1')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('$prefix:session-$1')::uuid)::text,true);"; }
command(){ printf '%s' "select public.boss_merchants_mutate(jsonb_build_object('action','$1','request_id',gen_random_uuid(),'input',$2));"; }
context(){ printf '%s' "jsonb_build_object('merchant_id','$merchant','location_id','$location')"; }
intent_setup="set local role authenticated;select pg_temp.actor('parent');select pg_temp.mm('i1','intent.create',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('offer'),'location_id',pg_temp.mid('loc-a'),'capability',pg_temp.proof('one'))));select pg_temp.mm('i2','intent.create',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('offer'),'location_id',pg_temp.mid('loc-a'),'capability',pg_temp.proof('two'))));reset role;"
redeem(){ printf '%s' "$(auth "$1")$(command token.redeem "$(context)||jsonb_build_object('capability','$2')")"; }
merchant_lock(){ printf '%s' "select pg_advisory_xact_lock(hashtextextended('boss-merchant:'||'$merchant'::uuid,0));"; }
setup duplicate_claim "set local role authenticated;select pg_temp.actor('coach');select pg_temp.mm('claim1','claim.submit',jsonb_build_object('merchant_id',pg_temp.mid('merchant-other','merchant_id'),'statement','Synthetic coach reviewed claim'));select pg_temp.actor('assistant');select pg_temp.mm('claim2','claim.submit',jsonb_build_object('merchant_id',pg_temp.mid('merchant-other','merchant_id'),'statement','Synthetic assistant reviewed claim'));reset role;"
claim1=$(result claim1 resource_id);claim2=$(result claim2 resource_id)
race duplicate_claim "$(auth admin)$(command claim.review "jsonb_build_object('merchant_id','$other_merchant','claim_id','$claim1','state','approved','reason','Independent synthetic claimant review')")" "$(auth admin)$(command claim.review "jsonb_build_object('merchant_id','$other_merchant','claim_id','$claim2','state','approved','reason','Independent synthetic competing review')")" PT409
assert_sql 'one approved claim and owner' "select count(*)=1 from public.merchant_claims where merchant_id='$other_merchant'and state='approved'"
setup location_version
edit="$(auth coach)$(command location.edit "$(context)||jsonb_build_object('expected_version',1,'hours_note','Synthetic hours change')")"
race location_version "$edit" "$edit" PT409
assert_sql 'one optimistic location edit' "select version=2 from public.merchant_locations where id='$location'"
setup approval_revision "set local role authenticated;select pg_temp.actor('admin');select pg_temp.mo('next');select pg_temp.mm('next-submit','offer.status',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('next'),'state','pending_review')));reset role;"
next=$(result next resource_id)
race approval_revision "$(auth admin)$(command offer.status "jsonb_build_object('merchant_id','$merchant','revision_id','$next','state','published','reason','Independent synthetic revision review')")" "$(auth parent)$(command offer.create "jsonb_build_object('merchant_id','$merchant','family_id','$family','title','Synthetic later draft','offer_type','percentage_off','discount_bps',1500,'qualification','none','stacking','none','starts_at',clock_timestamp()-interval'1 day','ends_at',clock_timestamp()+interval'2 days','location_policy','selected','location_ids',jsonb_build_array('$location'))")" success
assert_sql 'one published revision and later draft never published automatically' "select count(*)=1 from public.merchant_offer_revisions where family_id='$family'and boss_private.merchant_offer_state(id)in('published','scheduled')"
setup pause_redemption "$intent_setup"
race pause_redemption "$(auth parent)$(command family.status "jsonb_build_object('merchant_id','$merchant','family_id','$family','status','paused')")" "$(redeem staff "$proof1")" PT409
assert_sql 'pause creates no redemption' "select not exists(select 1 from public.merchant_redemptions where merchant_id='$merchant')"
setup final_use "$intent_setup set local role authenticated;select pg_temp.actor('parent');select pg_temp.mm('i3','intent.create',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('offer'),'location_id',pg_temp.mid('loc-a'),'capability',pg_temp.proof('three'))));select pg_temp.actor('staff');select pg_temp.mm('first-use','token.redeem',pg_temp.mi(jsonb_build_object('location_id',pg_temp.mid('loc-a'),'capability',pg_temp.proof('three'))));reset role;"
race final_use "$(redeem staff "$proof1")" "$(redeem assistant "$proof2")" PT409
assert_sql 'last remaining allowance consumed exactly once' "select count(*)=2 from public.merchant_redemptions where merchant_id='$merchant'"
setup same_token "$intent_setup"
race same_token "$(redeem staff "$proof1")" "$(redeem assistant "$proof1")" PT409
assert_sql 'two clerks one token one evidence' "select count(*)=1 from public.merchant_redemptions where merchant_id='$merchant'"
setup member_expiry
# The short historical source is issued through the canonical private test issuer.
# No immutable existing date is rewritten and no production membership is used.
lookup "select boss_private.discount_revoke(id,'revoked',null,$admin)from public.discount_member_sources where membership_id in(select id from public.discount_memberships where subject_id=$parent);" >/dev/null
base=$(lookup "select id from public.discount_product_revisions where product_id=(select id from public.discount_products where code='member_expiry_synthetic_digital')and revision=1")
org="md5('$prefix:org')::uuid";campaign=$(lookup "select id from public.fundraising_campaigns where organization_id=$org");fundraiser=$(lookup "select id from public.fundraising_fundraisers where campaign_id='$campaign'limit 1")
lookup "select boss_private.discount_issue('$base','fundraising_trial','trial:$prefix-expiry',$org,'$campaign','$fundraiser',null,null,null,$parent,clock_timestamp()-interval'30 days'+interval'3 seconds',clock_timestamp()+interval'3 seconds');$(auth parent)$(command intent.create "$(context)||jsonb_build_object('revision_id','$offer','capability','$proof1')")" >/dev/null
race member_expiry "$(merchant_lock)" "$(redeem staff "$proof1")" PT409 3.1
assert_sql 'naturally expired membership cannot redeem a stale intent' "select not exists(select 1 from public.merchant_redemptions where merchant_id='$merchant')"
setup offer_expiry "set local role authenticated;select pg_temp.actor('admin');select pg_temp.mo('expiring',jsonb_build_object('ends_at',clock_timestamp()+interval'3 seconds'));select pg_temp.mm('ex-submit','offer.status',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('expiring'),'state','pending_review')));select pg_temp.mm('ex-publish','offer.status',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('expiring'),'state','published','reason','Reviewed synthetic natural expiry')));select pg_temp.actor('parent');select pg_temp.mm('iex','intent.create',pg_temp.mi(jsonb_build_object('revision_id',pg_temp.mid('expiring'),'location_id',pg_temp.mid('loc-a'),'capability',pg_temp.proof('one'))));reset role;"
race offer_expiry "$(merchant_lock)" "$(redeem staff "$proof1")" PT409 3.1
assert_sql 'naturally expired offer creates no redemption' "select not exists(select 1 from public.merchant_redemptions where merchant_id='$merchant')"
setup location_pause "$intent_setup"
race location_pause "$(auth coach)$(command location.edit "$(context)||jsonb_build_object('expected_version',1,'status','paused')")" "$(redeem staff "$proof1")" PT409
sales_setup="set local role authenticated;select pg_temp.actor('admin');select pg_temp.mm('s1','sales.grant',jsonb_build_object('person_id',pg_temp.f('coach'),'role','sales_rep','market_id',pg_temp.mid('market','market_id')));select pg_temp.mm('s2','sales.grant',jsonb_build_object('person_id',pg_temp.f('assistant'),'role','sales_rep','market_id',pg_temp.mid('market','market_id')));select pg_temp.actor('coach');select pg_temp.mm('lead','lead.create',jsonb_build_object('market_id',pg_temp.mid('market','market_id'),'name','SYNTHETIC race prospect','category','services','source','Synthetic race referral'));reset role;"
setup duplicate_conversion "$sales_setup"
lead=$(result lead lead_id);convert="$(auth coach)$(command lead.convert "jsonb_build_object('lead_id','$lead','expected_version',1,'controlled',true)")"
race duplicate_conversion "$convert" "$convert" PT409
assert_sql 'one opportunity converts to one prospect' "select merchant_id is not null and version=2 from public.merchant_sales_leads where id='$lead'"
setup reassign_conversion "$sales_setup"
lead=$(result lead lead_id)
race reassign_conversion "$(auth admin)$(command lead.reassign "jsonb_build_object('lead_id','$lead','expected_version',1,'rep_id',md5('$prefix:assistant')::uuid)")" "$(auth coach)$(command lead.convert "jsonb_build_object('lead_id','$lead','expected_version',1,'controlled',true)")" PT403
assert_sql 'former rep cannot convert after reassignment' "select merchant_id is null and rep_id=md5('$prefix:assistant')::uuid from public.merchant_sales_leads where id='$lead'"
setup member_revocation "$intent_setup"
source=$(lookup "select source_id from boss_private.merchant_redemption_intents where id='$(result i1 intent_id)'")
race member_revocation "select boss_private.discount_revoke('$source','revoked',null,$admin);" "$(redeem staff "$proof1")" PT409
setup clerk_revocation "$intent_setup"
race clerk_revocation "$(auth admin)$(command access.end "jsonb_build_object('merchant_id','$merchant','assignment_id','$clerk')")" "$(redeem staff "$proof1")" PT403
setup module_disable "$intent_setup"
race module_disable "$(auth admin)$(command merchant.configure "jsonb_build_object('merchant_id','$merchant','status','inactive','portal',false,'offers',false,'redemption',false)")" "$(redeem staff "$proof1")" PT403
setup duplicate_correction "$intent_setup set local role authenticated;select pg_temp.actor('staff');select pg_temp.mm('rd','token.redeem',pg_temp.mi(jsonb_build_object('location_id',pg_temp.mid('loc-a'),'capability',pg_temp.proof('one'))));reset role;"
redemption=$(result rd redemption_id);correction="$(auth admin)$(command redemption.correct "jsonb_build_object('merchant_id','$merchant','redemption_id','$redemption','reason','Synthetic reviewed evidence correction','restore_allowance',true)")"
race duplicate_correction "$correction" "$correction" 23505
assert_sql 'one restoration correction cannot inflate allowance' "select count(*)=1 from public.merchant_redemption_corrections where redemption_id='$redemption'"
printf 'Phase 8A coordinated concurrency validation passed (%s races).\n' "$race_count"
