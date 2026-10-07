\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7d/fixture.sql
create temp table rails_timings(operation text,elapsed_ms numeric);
do $$declare started timestamptz:=clock_timestamp();begin
 perform pg_temp.checkout('perf');insert into rails_timings values('checkout_create',extract(epoch from clock_timestamp()-started)*1000);
 started:=clock_timestamp();perform boss_private.rails_dispatch(pg_temp.f('checkout-perf'));insert into rails_timings values('eligibility_commit',extract(epoch from clock_timestamp()-started)*1000);
 started:=clock_timestamp();perform pg_temp.receive('perf','captured');insert into rails_timings values('canonical_capture_fundraising_wallet',extract(epoch from clock_timestamp()-started)*1000);
 perform pg_temp.actor('admin');started:=clock_timestamp();perform boss_private.rails_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')));insert into rails_timings values('tenant_settlement_projection',extract(epoch from clock_timestamp()-started)*1000);
 end$$;
select pg_temp.check('each measured operation below the unchanged eight-second budget','PERFORMANCE',not exists(select 1 from rails_timings where elapsed_ms>=8000));
select pg_temp.check('bounded reconciliation range enforced','PERFORMANCE',exists(select 1 from pg_constraint where conrelid='public.payment_reconciliation_runs'::regclass and contype='c'and pg_get_constraintdef(oid)like'%31 days%'));
select pg_temp.check('provider request reference uses an account-scoped lookup index','PERFORMANCE',exists(select 1 from pg_index where indrelid='public.provider_operations'::regclass and indisunique and pg_get_indexdef(indexrelid)like'%account_id, provider_request_reference%'));
do $$declare started timestamptz;batch jsonb;payment uuid;allocation uuid;r jsonb;begin
 select jsonb_agg(jsonb_build_object('request_reference',lpad(n::text,20,'0'),'event_reference','LOCAL-PERF-'||n,'state','missing_provider','digest',repeat('a',64)))into batch from generate_series(1,100)n;
 started:=clock_timestamp();perform boss_private.rails_reconcile_batch(pg_temp.f('rails-account'),pg_temp.f('performance-reconcile'),clock_timestamp()-interval'1 day',clock_timestamp(),batch);
 insert into rails_timings values('reconcile_100_safe_items',extract(epoch from clock_timestamp()-started)*1000);
 update public.organization_modules set configuration=configuration||'{"refunds":true}'::jsonb where module_id=(select id from public.modules where key='payments');
 select payment_id into payment from public.external_payment_tenders where checkout_id=pg_temp.f('checkout-perf')and original_payment_id is null;
 started:=clock_timestamp();r:=boss_private.rails_refund_prepare(pg_temp.f('admin'),jsonb_build_object('action','refund.prepare','request_id',pg_temp.f('performance-refund'),'input',jsonb_build_object('payment_id',payment,'amount_minor',1000,'principal_minor',1000,'allocations','[]'::jsonb,'reason','Synthetic measured dependency correction')));
 perform boss_private.rails_refund_dispatch((r->>'refund_id')::uuid);
 perform boss_private.rails_refund_receive((r->>'refund_id')::uuid,'LOCAL-PERF-REFUND','refunded','LOCAL-PERF-REFUND-TX',1000,'USD',clock_timestamp(),repeat('b',64));
 insert into rails_timings values('refund_with_source_recovery',extract(epoch from clock_timestamp()-started)*1000);
end$$;
select pg_temp.check('bounded 100-item batch measured below eight seconds','PERFORMANCE',(select elapsed_ms<8000 from rails_timings where operation='reconcile_100_safe_items'));
select pg_temp.check('refund dependency measured below eight seconds','PERFORMANCE',(select elapsed_ms<8000 from rails_timings where operation='refund_with_source_recovery'));
select *from rails_timings order by operation;
select count(*)passed_assertions,'Phase 7D measured database performance' suite from phase5a_assertions;rollback;
