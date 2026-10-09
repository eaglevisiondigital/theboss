\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7d/fixture.sql
update public.organization_modules set configuration=configuration||'{"refunds":true,"reconciliation":true}'::jsonb where module_id=(select id from public.modules where key='payments');
create function pg_temp.pm(action text,i jsonb,request uuid default gen_random_uuid())returns jsonb language sql as $$select public.boss_payments_mutate(jsonb_build_object('action',action,'request_id',request,'input',i))$$;
grant execute on function pg_temp.pm(text,jsonb,uuid)to authenticated;
grant all on payment_results to anon;
create function pg_temp.refund(label text,amount bigint)returns uuid language plpgsql as $$declare p uuid;r jsonb;begin
 select payment_id into p from public.external_payment_tenders where checkout_id=pg_temp.f('checkout-'||label)and original_payment_id is null;
 r:=boss_private.rails_refund_prepare(pg_temp.f('admin'),jsonb_build_object('action','refund.prepare','request_id',pg_temp.f('refund-request-'||label||amount),'input',jsonb_build_object('payment_id',p,'amount_minor',amount,'principal_minor',amount,'allocations','[]'::jsonb,'reason','Synthetic reviewed original-tender correction')));
 perform boss_private.rails_refund_dispatch((r->>'refund_id')::uuid);
 perform boss_private.rails_refund_receive((r->>'refund_id')::uuid,'REFUND-'||label||amount,'refunded','TRANSACTION-REFUND-'||label||amount,amount,'USD',clock_timestamp(),repeat('d',64));return p;end$$;
create function pg_temp.settle(label text,fee bigint default 0)returns jsonb language plpgsql as $$declare c public.payment_checkouts;e uuid;p uuid;begin
 select *into c from public.payment_checkouts where id=pg_temp.f('checkout-'||label);
 perform boss_private.rails_receive(c.id,'batch-'||label,'settled','LOCAL-TRANSACTION-'||label,c.external_minor,c.currency,clock_timestamp(),repeat('a',64),jsonb_build_object('processor_fee_minor',fee,'batch_reference','LOCAL-BATCH'));
 select id into e from public.provider_event_evidence where account_id=c.account_id and event_reference='batch-'||label;select payment_id into p from public.external_payment_tenders where checkout_id=c.id and original_payment_id is null;
 return boss_private.rails_settlement_match(p,e,fee);end$$;
create temp table financial_ids(label text primary key,id uuid);grant all on financial_ids to authenticated,anon;
select pg_temp.checkout('before-batch');select boss_private.rails_dispatch(pg_temp.f('checkout-before-batch'));select pg_temp.receive('before-batch','captured');
insert into financial_ids values('before-batch',pg_temp.refund('before-batch',5000));
select pg_temp.check('refund before settlement attributes remaining principal only','TIMING',pg_temp.settle('before-batch',100)->>'organization_payable_minor'='3500');
select pg_temp.check('refund before settlement leaves held gross exactly zero','TIMING',not exists(select 1 from public.settlement_postings sp join public.settlement_accounts a on a.id=sp.account_id join public.settlement_journals j on j.id=sp.journal_id where j.payment_id=(select id from financial_ids where label='before-batch')and a.kind='held_gross'group by a.kind having sum(sp.amount_minor)<>0));
select pg_temp.checkout('full-before-batch');select boss_private.rails_dispatch(pg_temp.f('checkout-full-before-batch'));select pg_temp.receive('full-before-batch','captured');select pg_temp.refund('full-before-batch',10000);
select pg_temp.check('full refund before fee-free batch creates no payable','TIMING',pg_temp.settle('full-before-batch')->>'organization_payable_minor'='0');
select pg_temp.checkout('deficit');select boss_private.rails_dispatch(pg_temp.f('checkout-deficit'));select pg_temp.receive('deficit','captured');select pg_temp.settle('deficit');select pg_temp.refund('deficit',5000);
select pg_temp.check('settled direct refund creates distinct org deficit','DEFICIT',exists(select 1 from public.settlement_deficits where amount_minor=3500));
update public.processing_accounts set settlement_mode=settlement_mode where id=pg_temp.f('rails-account');
-- A different same-organization account supplies a platform-managed route.
insert into public.processing_accounts(id,organization_id,provider,environment,name,country,currencies,merchant_owner,merchant_reference,settlement_mode,capabilities,status,created_by)
values(pg_temp.f('platform-account'),pg_temp.f('org'),'authorize_net','sandbox','LOCAL PLATFORM CONTRACT','US',array['USD'],'platform','LOCAL-PLATFORM-CONTRACT','platform_managed',array['card_sale','auth_capture','ach','refund','partial_refund','settlement_query','saved_profile'],'active',pg_temp.f('admin'));
insert into boss_private.processing_bindings(account_id,secret_handle,credential_revision,verified_environment,verified_merchant_reference,verified_at)values(pg_temp.f('platform-account'),'boss/payments/local-contract-only',gen_random_uuid(),'sandbox','LOCAL-PLATFORM-CONTRACT',clock_timestamp());
insert into public.payment_routing_revisions(id,organization_id,account_id,purpose,currency,scope_type,scope_id,revision,starts_at,created_by)values(pg_temp.f('platform-route'),pg_temp.f('org'),pg_temp.f('platform-account'),'fundraising','USD','campaign',pg_temp.fid('campaign'),2,clock_timestamp(),pg_temp.f('admin'));
insert into public.payment_routing_events(routing_id,state,actor_id)values(pg_temp.f('platform-route'),'active',pg_temp.f('admin'));
create function pg_temp.platform_checkout(label text)returns uuid language plpgsql as $$declare x public.fundraising_intents;cap text:=md5(label)||md5('platform'||label);begin
 perform public.boss_fundraising_support(jsonb_build_object('action','intent','request_id',pg_temp.f('intent-'||label),'input',jsonb_build_object('path',pg_temp.fpath('share'),'capability',cap,'display_name','Synthetic donor','anonymous',true,'amount_minor',10000)));
 select *into x from public.fundraising_intents where request_id=pg_temp.f('intent-'||label);
 insert into public.payment_checkouts(id,organization_id,intent_id,purpose,currency,account_id,routing_id,policy_id,method,principal_minor,external_minor,request_id,command_hash,capability_digest,expires_at)values(pg_temp.f('checkout-'||label),pg_temp.f('org'),x.id,'fundraising','USD',pg_temp.f('platform-account'),pg_temp.f('platform-route'),pg_temp.f('settlement-policy'),'card',10000,10000,pg_temp.f('checkout-request-'||label),repeat('e',64),x.capability_digest,clock_timestamp()+interval'10 minutes');return pg_temp.f('checkout-'||label);end$$;
select pg_temp.platform_checkout('future');select boss_private.rails_dispatch(pg_temp.f('checkout-future'));select pg_temp.receive('future','captured');select pg_temp.settle('future');
select pg_temp.check('future payable offsets only same-org deficit','OFFSET',(select sum(amount_minor)=3500 from public.settlement_deficit_offsets)and boss_private.rails_payable(pg_temp.f('org'),'USD')=3500);
select pg_temp.check('replaying offset cannot consume value twice','OFFSET',boss_private.rails_offset_deficits((select payment_id from public.external_payment_tenders where checkout_id=pg_temp.f('checkout-future')))=0);
select pg_temp.platform_checkout('available');select boss_private.rails_dispatch(pg_temp.f('checkout-available'));select pg_temp.receive('available','captured');select pg_temp.settle('available');
select pg_temp.check('new payable available after prior deficit satisfied','OFFSET',boss_private.rails_payable(pg_temp.f('org'),'USD')=10500);
set local role authenticated;select pg_temp.actor('admin');
insert into payment_results values('request',pg_temp.pm('settlement.request',jsonb_build_object('organization_id',pg_temp.f('org'),'currency','USD','amount_minor',9000),pg_temp.f('settlement-request')));
select pg_temp.check('signed platform request reserves without pretending payout','REQUEST',public.boss_payments_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')))->'available'@>'[{"currency":"USD","amount_minor":"1500"}]');
reset role;
select pg_temp.refund('available',8000);
select pg_temp.check('refund moves affected settlement request to review','REQUEST',exists(select 1 from public.settlement_requests where request_id=pg_temp.f('settlement-request')and state='review'));
select pg_temp.check('pending request never exposes negative available','REQUEST',boss_private.rails_payable(pg_temp.f('org'),'USD')=0);
set local role authenticated;select pg_temp.actor('admin');select pg_temp.pm('settlement.cancel',jsonb_build_object('organization_id',pg_temp.f('org'),'settlement_request_id',(select(result->>'id')::uuid from payment_results where label='request')));reset role;
select pg_temp.check('cancel releases only surviving canonical payable','REQUEST',boss_private.rails_payable(pg_temp.f('org'),'USD')=4900);
select pg_temp.check('receipt derives canonical principal and refund chronology','RECEIPT',boss_private.rails_receipt((select payment_id from public.external_payment_tenders where checkout_id=pg_temp.f('checkout-available')and original_payment_id is null))->>'refunded_minor'='8000');
-- No provider absence is interpreted as certified failure.
select pg_temp.platform_checkout('batch-unknown');select boss_private.rails_dispatch(pg_temp.f('checkout-batch-unknown'));select pg_temp.receive('batch-unknown','unknown');
insert into financial_ids select 'reconcile',boss_private.rails_reconcile_batch(pg_temp.f('platform-account'),pg_temp.f('reconcile-run'),clock_timestamp()-interval'1 hour',clock_timestamp(),jsonb_build_array(jsonb_build_object('request_reference',(select provider_request_reference from public.provider_operations where checkout_id=pg_temp.f('checkout-batch-unknown')),'event_reference','query-missing','state','missing_provider','digest',repeat('f',64))));
select pg_temp.check('missing provider record is review, not failure/release','UNKNOWN',boss_private.rails_hold(pg_temp.f('checkout-batch-unknown'))and exists(select 1 from public.payment_reconciliation_items where state='missing_provider'));
insert into financial_ids select 'reconcile-success',boss_private.rails_reconcile_batch(pg_temp.f('platform-account'),pg_temp.f('reconcile-success'),clock_timestamp()-interval'1 hour',clock_timestamp()+interval'1 minute',jsonb_build_array(jsonb_build_object('request_reference',(select provider_request_reference from public.provider_operations where checkout_id=pg_temp.f('checkout-batch-unknown')),'transaction_reference','LOCAL-TRANSACTION-batch-unknown','event_reference','query-found','state','captured','amount_minor',10000,'currency','USD','occurred_at',clock_timestamp(),'digest',repeat('b',64))));
select pg_temp.check('batch query recovers original capture exactly once','UNKNOWN',(select count(*)=1 from public.external_payment_tenders where checkout_id=pg_temp.f('checkout-batch-unknown')));
-- Safe public capability entrypoint; raw private tables remain unavailable.
set local role anon;
insert into payment_results values('guest-intent',public.boss_fundraising_support(jsonb_build_object('action','intent','request_id',pg_temp.f('native-guest-intent'),'input',jsonb_build_object('path',pg_temp.fpath('share'),'capability',repeat('7',64),'display_name','Synthetic donor','anonymous',true,'amount_minor',10000))));
insert into payment_results values('guest-prepare',public.boss_payments_support(jsonb_build_object('action','prepare','request_id',pg_temp.f('native-guest-checkout'),'input',jsonb_build_object('path',pg_temp.fpath('share'),'capability',repeat('7',64),'method','card'))));
select pg_temp.denied('forged guest capability cannot reveal an existing attempt',format('select public.boss_payments_support(%L::jsonb)',jsonb_build_object('action','status','request_id',gen_random_uuid(),'input',jsonb_build_object('path',pg_temp.fpath('share'),'capability',repeat('1',64)))),'PT404');
reset role;
select pg_temp.check('guest checkout creates no payment or permanent success','GUEST',exists(select 1 from public.payment_checkouts where request_id=pg_temp.f('native-guest-checkout')and state='ready')and not exists(select 1 from public.provider_operations where checkout_id=(select(result->>'checkout_id')::uuid from payment_results where label='guest-prepare')));
select pg_temp.check('anonymous raw profile and settlement access stays closed','ACL',not has_table_privilege('anon','public.saved_payment_methods','SELECT')and not has_table_privilege('anon','public.settlement_sources','SELECT')and not has_function_privilege('anon','boss_private.rails_guest(jsonb)','EXECUTE'));
set constraints all immediate;
select count(*)passed_assertions,'Phase 7D timing, deficits, requests, reconciliation and guest operations' suite from phase5a_assertions;rollback;
