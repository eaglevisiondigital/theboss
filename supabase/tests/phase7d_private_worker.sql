\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7d/fixture.sql
update public.organization_modules set configuration=configuration||'{"refunds":true,"reconciliation":true}'::jsonb where module_id=(select id from public.modules where key='payments');
select pg_temp.checkout('worker-return','ach');
insert into payment_results values('ach-claim',boss_private.rails_worker_claim(pg_temp.f('checkout-worker-return')));
select boss_private.rails_worker_finish(pg_temp.f('checkout-worker-return'),(select(result->>'operation_id')::uuid from payment_results where label='ach-claim'),(select(result->>'generation')::timestamptz from payment_results where label='ach-claim'),'{"state":"settled","transaction_reference":"LOCAL-WORKER-ACH","amount_minor":"10000","currency":"USD"}','worker-ach-success',repeat('a',64));
select pg_temp.check('private worker establishes approved final ACH exactly once','WORKER',(select count(*)=1 from public.payments where method='ach'and status='recorded'));
select pg_temp.check('completed payment remains queryable for later return','WORKER',boss_private.rails_worker_claim(pg_temp.f('checkout-worker-return'))->'first_dispatch'='false'::jsonb);
select boss_private.rails_worker_finish(pg_temp.f('checkout-worker-return'),(select(result->>'operation_id')::uuid from payment_results where label='ach-claim'),(select(result->>'generation')::timestamptz from payment_results where label='ach-claim'),'{"state":"returned","transaction_reference":"LOCAL-WORKER-ACH","amount_minor":"10000","currency":"USD"}','worker-ach-return',repeat('b',64));
select pg_temp.check('ACH return is distinct canonical correction after success','WORKER',(select count(*)=1 from public.external_payment_corrections where kind='ach_return')and(select count(*)=1 from public.payment_dispute_cases where category='ach_return'));
select boss_private.rails_worker_finish(pg_temp.f('checkout-worker-return'),(select(result->>'operation_id')::uuid from payment_results where label='ach-claim'),(select(result->>'generation')::timestamptz from payment_results where label='ach-claim'),'{"state":"returned","transaction_reference":"LOCAL-WORKER-ACH","amount_minor":"10000","currency":"USD"}','worker-ach-return',repeat('b',64));
select pg_temp.check('replayed return cannot duplicate correction','WORKER',(select count(*)=1 from public.external_payment_corrections));
select pg_temp.checkout('worker-refund');select boss_private.rails_dispatch(pg_temp.f('checkout-worker-refund'));select pg_temp.receive('worker-refund','captured');
insert into payment_results select 'refund',boss_private.rails_refund_prepare(pg_temp.f('admin'),jsonb_build_object('action','refund.prepare','request_id',pg_temp.f('worker-refund-request'),'input',jsonb_build_object('payment_id',payment_id,'amount_minor',1000,'principal_minor',1000,'allocations','[]'::jsonb,'reason','Synthetic worker refund')))from public.external_payment_tenders where checkout_id=pg_temp.f('checkout-worker-refund');
insert into payment_results values('refund-claim',boss_private.rails_worker_claim((select(result->>'refund_id')::uuid from payment_results where label='refund')));
select pg_temp.check('refund worker claim retains original tender reference','REFUND',(select result->'command'->>'transaction_reference'='LOCAL-TRANSACTION-worker-refund'and result->'command'->>'kind'='refund'from payment_results where label='refund-claim'));
select boss_private.rails_worker_finish((select(result->>'refund_id')::uuid from payment_results where label='refund'),(select(result->>'operation_id')::uuid from payment_results where label='refund-claim'),(select(result->>'generation')::timestamptz from payment_results where label='refund-claim'),'{"state":"refunded","transaction_reference":"LOCAL-WORKER-REFUND","amount_minor":"1000","currency":"USD"}','worker-refund-final',repeat('c',64));
select pg_temp.check('verified refund worker invokes canonical dependency correction','REFUND',exists(select 1 from public.external_payment_corrections where kind='refund'and principal_minor=1000));
select pg_temp.check('completed refund cannot be dispatched again','REFUND',boss_private.rails_worker_claim((select(result->>'refund_id')::uuid from payment_results where label='refund'))is null);
select pg_temp.denied('worker raw financial tables remain closed','set local role boss_payment_worker;select *from public.payments','42501');
select pg_temp.check('private worker cannot directly manufacture financial success','ACL',not has_function_privilege('boss_payment_worker','boss_private.rails_complete(uuid,uuid)','EXECUTE'));
-- A signed family checkout provides the exact returning-user profile owner.
set local role authenticated;select pg_temp.actor('parent');
insert into payment_results values('family',public.boss_payments_mutate(jsonb_build_object('action','checkout.prepare','request_id',pg_temp.f('profile-checkout'),'input',jsonb_build_object('organization_id',pg_temp.f('org'),'routing_id',pg_temp.f('rails-route'),'method','card','currency','USD','bucks_minor',0,'allocations',jsonb_build_array(jsonb_build_object('charge_id',pg_temp.f('charge-camp'),'amount_minor',10000,'bucks_minor',0))))));reset role;
select boss_private.rails_dispatch((select(result->>'checkout_id')::uuid from payment_results where label='family'));
select boss_private.rails_receive((select(result->>'checkout_id')::uuid from payment_results where label='family'),'profile-capture','captured','LOCAL-PROFILE-CAPTURE',10000,'USD',clock_timestamp(),repeat('d',64));
update public.processing_accounts set capabilities=array_append(capabilities,'saved_profile')where id=pg_temp.f('rails-account');
insert into payment_results values('profile',jsonb_build_object('id',boss_private.rails_profile_register((select(result->>'checkout_id')::uuid from payment_results where label='family'),'LOCAL-CUSTOMER','LOCAL-METHOD','Visa','1111')));
insert into public.payment_plans(id,organization_id,registration_id,charge_id,title,created_by_person_id)values(pg_temp.f('profile-plan'),pg_temp.f('org'),pg_temp.f('registration-camp'),pg_temp.f('charge-camp'),'Synthetic future plan',pg_temp.f('admin'));
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('family projection masks saved profile references','PROFILE',public.boss_payments_read()::text not like'%LOCAL-CUSTOMER%'and public.boss_payments_read()::text not like'%LOCAL-METHOD%');
insert into payment_results values('consent',public.boss_payments_mutate(jsonb_build_object('action','consent.create','request_id',pg_temp.f('profile-consent'),'input',jsonb_build_object('method_id',(select result->>'id'from payment_results where label='profile'),'plan_id',pg_temp.f('profile-plan'),'starts_at',clock_timestamp(),'accepted',true))));
select pg_temp.check('explicit consent does not activate autopay','CONSENT',public.boss_payments_read()->'consents'@>'[{"execution":"inactive","revoked":false}]');
select public.boss_payments_mutate(jsonb_build_object('action','method.revoke','request_id',pg_temp.f('profile-revoke'),'input',jsonb_build_object('method_id',(select result->>'id'from payment_results where label='profile'))));reset role;
select pg_temp.check('owner revocation ends method and dependent consent','CONSENT',not exists(select 1 from public.saved_payment_methods where person_id=pg_temp.f('parent')and revoked_at is null)and not exists(select 1 from public.payment_execution_consents where person_id=pg_temp.f('parent')and revoked_at is null));
select pg_temp.check('no recurring scheduler work activated','CONSENT',not exists(select 1 from public.payment_recurring_work where state<>'inactive'));
set constraints all immediate;
select count(*)passed_assertions,'Phase 7D private worker, ACH return, refund and saved consent' suite from phase5a_assertions;rollback;
