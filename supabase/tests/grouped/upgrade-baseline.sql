-- Disposable 119-migration state only. No hosted state or real money.
begin;
\ir ../phase7d/fixture.sql
update public.organization_modules set configuration=configuration||'{"refunds":true,"reconciliation":true}'::jsonb where module_id=(select id from public.modules where key='payments');
select pg_temp.checkout('grouped-upgrade-card','card',5);
select boss_private.rails_dispatch(pg_temp.f('checkout-grouped-upgrade-card'));
select pg_temp.receive('grouped-upgrade-card','captured');
select pg_temp.actor('admin');
create temp table upgrade_refund as select boss_private.rails_refund_prepare(pg_temp.f('admin'),jsonb_build_object('action','refund.prepare','request_id',gen_random_uuid(),'input',jsonb_build_object('payment_id',(select payment_id from public.external_payment_tenders where checkout_id=pg_temp.f('checkout-grouped-upgrade-card')and original_payment_id is null),'amount_minor',101,'principal_minor',101,'allocations','[]'::jsonb,'reason','Synthetic legacy backfill validation'))) data;
select boss_private.rails_refund_dispatch((data->>'refund_id')::uuid)from upgrade_refund;
select boss_private.rails_refund_receive((data->>'refund_id')::uuid,'SYNTHETIC-GROUPED-UPGRADE-REFUND','refunded','SYNTHETIC-UPGRADE-101',101,'USD',clock_timestamp(),repeat('b',64))from upgrade_refund;
-- Give the synthetic initial dispatch a one-second budget; expiry is not extended.
do $$begin execute replace(pg_get_functiondef('pg_temp.checkout(text,text,integer,boolean)'::regprocedure),'60 milliseconds','1 second');end$$;
select pg_temp.checkout('grouped-upgrade-pending','ach',10,true);
select boss_private.rails_dispatch(pg_temp.f('checkout-grouped-upgrade-pending'));
select pg_temp.receive('grouped-upgrade-pending','ach_pending');
select pg_sleep(1.05);
create table boss_private.grouped_upgrade_proof(table_name text primary key,row_count bigint,digest text);
revoke all on boss_private.grouped_upgrade_proof from public,anon,authenticated,service_role;
alter table boss_private.grouped_upgrade_proof enable row level security;
do $$declare t record;begin for t in select relname from pg_class where relnamespace='public'::regnamespace and relkind='r'loop
 execute format('insert into boss_private.grouped_upgrade_proof select %L,count(*),encode(sha256(convert_to(coalesce(string_agg(row_to_json(v)::text,E''\n''order by row_to_json(v)::text),''''),''UTF8'')),''hex'')from public.%I v',t.relname,t.relname);
 end loop;end$$;
commit;
