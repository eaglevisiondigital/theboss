#!/usr/bin/env bash
# Two real connections; private disposable PostgreSQL only, synthetic data only.
set -euo pipefail
umask 077
: "${PG_BINDIR:?Disposable runner required}" "${PGHOST:?Disposable runner required}" "${PGPORT:?Disposable runner required}" "${PGDATABASE:?Disposable runner required}" "${PGUSER:?Disposable runner required}"
if [[ "$PGHOST" != /tmp/boss-db-test.*/socket || ! -S "$PGHOST/.s.PGSQL.5432" || "$PGPORT" != 5432 || "$PGDATABASE" != postgres || "$PGUSER" != postgres ]];then printf '%s\n' 'Phase8B1 races require the private disposable runner socket.' >&2;exit 1;fi
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd);race_dir=${PGHOST%/socket}
psql_cmd=("$PG_BINDIR/psql" --no-psqlrc --no-password --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --dbname "$PGDATABASE" --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --quiet --no-align --tuples-only)
writer_pid='';contender_pid='';input_open=false;race_count=0
cleanup(){ local result=$?;trap - EXIT INT TERM;if [[ "$input_open" == true ]];then exec 9>&-;fi;for pid in "$writer_pid" "$contender_pid";do [[ -z "$pid" ]]||{ kill "$pid" >/dev/null 2>&1||true;wait "$pid" >/dev/null 2>&1||true;};done;exit "$result";};trap cleanup EXIT;trap 'exit 130' INT;trap 'exit 143' TERM
fail(){ printf 'Phase8B1 concurrency invariant failed: %s\n' "$1" >&2;exit 1; }
lookup(){ "${psql_cmd[@]}" --command "$1"; }
assert_sql(){ [[ $(lookup "$2") == t ]]||fail "$1"; }
await_state(){ local app=$1 expected=$2 pid=$3 deadline=$((SECONDS+7)) query;if [[ "$expected" == ready ]];then query="select count(*) from pg_stat_activity where application_name='$app'and state='idle in transaction'and query like'%phase8b1-writer-ready%'";else query="select count(*) from pg_stat_activity where application_name='$app'and wait_event_type='Lock'";fi;while((SECONDS<deadline));do kill -0 "$pid" >/dev/null 2>&1||return 1;[[ $(lookup "$query") == 1 ]]&&return 0;sleep .025;done;return 1; }
race(){ local label=$1 writer_sql=$2 contender_sql=$3 expected=$4 hold=${5:-0};local fifo="$race_dir/phase8b1-$label.stdin" rc=0;mkfifo -m 600 "$fifo";"${psql_cmd[@]}" <"$fifo" >"$race_dir/8b1-$label-w.out" 2>"$race_dir/8b1-$label-w.err"&writer_pid=$!;exec 9>"$fifo";input_open=true;printf '%s\n' "set application_name='boss_phase8b1_${label}_writer';set statement_timeout='8s';begin;$writer_sql select 1 /* phase8b1-writer-ready */;" >&9;await_state "boss_phase8b1_${label}_writer" ready "$writer_pid"||{ head -n 8 "$race_dir/8b1-$label-w.err" >&2;fail "$label writer readiness";};"${psql_cmd[@]}" --command "set application_name='boss_phase8b1_${label}_contender';set statement_timeout='8s';begin;$contender_sql commit;" >"$race_dir/8b1-$label-c.out" 2>"$race_dir/8b1-$label-c.err"&contender_pid=$!;await_state "boss_phase8b1_${label}_contender" waiting "$contender_pid"||{ head -n 8 "$race_dir/8b1-$label-c.err" >&2;fail "$label contender did not block";};if [[ "$hold" != 0 ]];then sleep "$hold";fi;printf '%s\n' 'commit;' >&9;exec 9>&-;input_open=false;wait "$writer_pid"||{ head -n 8 "$race_dir/8b1-$label-w.err" >&2;fail "$label writer";};writer_pid='';if wait "$contender_pid";then rc=0;else rc=$?;fi;contender_pid='';if [[ "$expected" == success && "$rc" != 0 ]];then head -n 8 "$race_dir/8b1-$label-c.err" >&2;fail "$label contender";fi;if [[ "$expected" != success ]]&&{ [[ "$rc" == 0 ]]||! grep -Fq "$expected" "$race_dir/8b1-$label-c.err";};then head -n 8 "$race_dir/8b1-$label-c.err" >&2;fail "$label expected $expected";fi;race_count=$((race_count+1)); }
setup(){
 local label=$1 extra=${2:-''}
 prefix="boss-phase8b1-race-${label//_/-}"
 awk '!/^\\ir /' "$test_dir/phase7b/fixture.sql" "$test_dir/phase7c/fixture.sql" "$test_dir/phase7d/fixture.sql" "$test_dir/phase7e/fixture.sql" "$test_dir/phase8a/fixture.sql" "$test_dir/phase8b1/fixture.sql" |
 sed -e "s/'rails-source'/'$prefix-rails-source'/g" -e "s/boss-phase7b-test:/$prefix:/g" -e "s/synthetic-phase7b-/synthetic-$prefix-/g" -e "s/phase7b\.example\.invalid/$prefix.example.invalid/g" -e "s/\"code\":\"synthetic_/\"code\":\"${label}_synthetic_/g" -e "s/INERT DISPOSABLE BUSINESS PROOF /INERT DISPOSABLE BUSINESS PROOF $prefix /g" -e "s/SYNTHETIC LOCAL MARKET/$prefix LOCAL/g" -e "s/SYNTHETIC OTHER MARKET/$prefix OTHER/g" -e "s/SYNTHETIC CANADIAN MARKET/$prefix CANADA/g" -e "s/synthetic-partner-a/$prefix-a/g" -e "s/synthetic-partner-b/$prefix-b/g" >"$race_dir/8b1-$label-fixture.sql"
 cat >"$race_dir/8b1-$label-setup.sql" <<SQL
begin;
\ir '$race_dir/8b1-$label-fixture.sql'
$extra
commit;
SQL
 if ! "${psql_cmd[@]}" --file "$race_dir/8b1-$label-setup.sql" >"$race_dir/8b1-$label-setup.out" 2>"$race_dir/8b1-$label-setup.err";then head -n 8 "$race_dir/8b1-$label-setup.err" >&2;fail "$label setup";fi
 provider=$(result provider);benefit=$(result benefit);contract=$(result contract);source=$(result source);territory=$(result territory)
}
result(){ case "$1" in benefit)lookup "select id from public.partner_benefit_revisions where provider_id=(select(result->>'provider_id')::uuid from boss_private.partner_receipts where request_id=md5('$prefix:partner-request-provider')::uuid)order by source_revision desc limit 1";;source)lookup "select source_id from public.partner_benefit_revisions where provider_id=(select(result->>'provider_id')::uuid from boss_private.partner_receipts where request_id=md5('$prefix:partner-request-provider')::uuid)order by source_revision desc limit 1";;*)lookup "select result->>'resource_id'from boss_private.partner_receipts where request_id=md5('$prefix:partner-request-$1')::uuid";;esac; }
auth(){ printf '%s' "set local role authenticated;select set_config('request.jwt.claims',jsonb_build_object('sub',md5('$prefix:auth-admin')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('$prefix:session-admin')::uuid)::text,true);"; }
command(){ printf '%s' "select public.boss_partners_mutate(jsonb_build_object('action','$1','request_id',gen_random_uuid(),'input',jsonb_build_object('provider_id','$provider')||$2));"; }
feed(){ printf '%s' "$(auth)$(command catalog.import "jsonb_build_object('feed_sequence',$1,'kind','delta','synthetic',true,'items',jsonb_build_array(jsonb_build_object('external_id','race-source','source_revision',2,'withdrawn',true)${2:-}))")"; }
review(){ printf '%s' "$(auth)$(command catalog.review "jsonb_build_object('revision_id','$benefit','state','reviewed')")"; }
setup duplicate_import
race duplicate_import "$(feed 2)" "$(feed 2)" success
assert_sql 'same provider source exists once' "select count(*)=1 from public.partner_benefit_sources where provider_id='$provider'and external_id='race-source'"
setup conflicting_revision
race conflicting_revision "$(feed 2)" "$(feed 3 "||jsonb_build_object('exclusions','Synthetic conflicting revision')")" success
assert_sql 'conflicting material revision quarantined' "select count(*)=1 from public.partner_import_quarantine q join public.partner_import_runs r on r.id=q.run_id where r.provider_id='$provider'and q.category='revision_conflict'"
expiry_setup="insert into public.partner_contract_revisions(provider_id,revision,document_reference,rights_holder_reference,countries,categories,methods,product_id,minimum_tier,display_rights,caching_rights,branding_rules,attribution_rules,sharing_fields,retention_days,refund_policy_reference,starts_at,ends_at,created_by)
 select provider_id,2,document_reference,rights_holder_reference,countries,categories,methods,product_id,minimum_tier,display_rights,caching_rights,branding_rules,attribution_rules,sharing_fields,retention_days,refund_policy_reference,starts_at,clock_timestamp()+interval'4 seconds',created_by from public.partner_contract_revisions where id=pg_temp.pid('contract');
 insert into public.partner_contract_events(provider_id,contract_id,state,actor_id,approval_reference,request_id)select provider_id,id,'approved',pg_temp.f('coach'),'Synthetic independently approved timed contract',gen_random_uuid()from public.partner_contract_revisions where provider_id=pg_temp.pid('provider')and revision=2;
 insert into public.partner_benefit_revisions(provider_id,source_id,source_revision,contract_id,category,title,public_description,member_terms,country,region,market_id,product_id,minimum_tier,fulfillment,starts_at,ends_at,source_digest)
 select r.provider_id,r.source_id,2,c.id,r.category,r.title,r.public_description,r.member_terms,r.country,r.region,r.market_id,r.product_id,r.minimum_tier,r.fulfillment,r.starts_at,r.ends_at,r.source_digest from public.partner_benefit_revisions r join public.partner_contract_revisions c on c.provider_id=r.provider_id and c.revision=2 where r.id=pg_temp.pid('benefit');
 update public.partner_benefit_sources set current_revision=2 where id=pg_temp.pid('source');"
setup contract_expiry "$expiry_setup"
race contract_expiry "select boss_private.partner_lock('$provider');" "$(review)" PT409 4.1
setup provider_suspension
race provider_suspension "$(auth)$(command provider.state "jsonb_build_object('expected_version',5,'state','suspended','reason','Synthetic reviewed suspension')")" "$(review)" PT409
setup territory_removal
race territory_removal "$(auth)$(command territory.end "jsonb_build_object('territory_id','$territory')")" "select boss_private.partner_decision(md5('$prefix:parent')::uuid,'$benefit',(select id from public.merchant_markets where market='$prefix LOCAL'));" success
grep -Fq '"territory_eligible": false' "$race_dir/8b1-territory_removal-c.out"||fail 'blocked eligibility read saw stale territory'
assert_sql 'post-removal eligibility remains false' "select not(boss_private.partner_decision(md5('$prefix:parent')::uuid,'$benefit',(select id from public.merchant_markets where market='$prefix LOCAL'))->>'territory_eligible')::boolean"
setup import_withdrawal
race import_withdrawal "$(feed 2)" "$(auth)$(command catalog.withdraw "jsonb_build_object('source_id','$source')")" success
assert_sql 'withdrawal retained without rewriting history' "select status='withdrawn'from public.partner_benefit_sources where id='$source'"
setup archive_history
race archive_history "$(auth)$(command provider.state "jsonb_build_object('expected_version',5,'state','archived','reason','Synthetic reviewed archival')")" "select boss_private.partner_lock('$provider');delete from public.partner_providers where id='$provider';" 23514
assert_sql 'archived provider and referenced history survive' "select state='archived'from public.partner_providers where id='$provider'"
financial_setup="set local role authenticated;select pg_temp.actor('admin');select pg_temp.pm('policy','policy.create',pg_temp.pi(jsonb_build_object('contract_id',pg_temp.pid('contract'),'currency','USD','basis','percentage','rate_ppm',100000,'recognition_condition','fulfilled','starts_at',clock_timestamp()-interval'1 day','ends_at',clock_timestamp()+interval'10 days')));reset role;"
setup duplicate_transaction "$financial_setup"
policy=$(result policy)
tx="$(auth)$(command transaction.create "jsonb_build_object('external_id','synthetic-race-tx','revision_id','$benefit','policy_id','$policy','currency','USD','eligible_minor',10000,'synthetic',true,'occurred_at',clock_timestamp(),'evidence_reference','synthetic-evidence/race')")"
race duplicate_transaction "$tx" "$tx" PT409
assert_sql 'transaction business source recorded once' "select count(*)=1 from public.partner_transaction_sources where provider_id='$provider'"
source_setup="$financial_setup set local role authenticated;select pg_temp.pm('tx','transaction.create',pg_temp.pi(jsonb_build_object('external_id','synthetic-race-tx','revision_id',pg_temp.pid('benefit'),'policy_id',pg_temp.pid('policy'),'currency','USD','eligible_minor',10000,'synthetic',true,'occurred_at',clock_timestamp(),'evidence_reference','synthetic-evidence/race')));select pg_temp.pm('requested','transaction.event',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('tx'),'external_event_id','requested','kind','requested','evidence_reference','synthetic-evidence/request')));select pg_temp.pm('refund','transaction.event',pg_temp.pi(jsonb_build_object('transaction_id',pg_temp.pid('tx'),'external_event_id','refund','kind','refund','adjustment_minor',1000,'evidence_reference','synthetic-evidence/refund')));reset role;"
setup duplicate_event "$source_setup"
transaction=$(result tx)
confirmation="$(auth)$(command transaction.event "jsonb_build_object('transaction_id','$transaction','external_event_id','same-confirmation','kind','confirmed','evidence_reference','synthetic-evidence/confirmation')")"
race duplicate_event "$confirmation" "$confirmation" PT409
assert_sql 'duplicate commission confirmation recorded exactly once' "select count(*)=1 from public.partner_transaction_events where provider_id='$provider'and external_event_id='same-confirmation'"
setup correction_confirmation "$source_setup"
transaction=$(result tx);refund=$(result refund)
race correction_confirmation "$(auth)$(command transaction.event "jsonb_build_object('transaction_id','$transaction','external_event_id','correct','kind','correction','corrects_event_id','$refund','evidence_reference','synthetic-evidence/correction')")" "$(auth)$(command transaction.event "jsonb_build_object('transaction_id','$transaction','external_event_id','confirm','kind','confirmed','evidence_reference','synthetic-evidence/confirm')")" success
assert_sql 'correction and delayed confirmation both preserved' "select count(*)=2 from public.partner_transaction_events where transaction_id='$transaction'and kind in('correction','confirmed')"
printf 'Phase 8B1 coordinated concurrency validation passed (%s races).\n' "$race_count"
