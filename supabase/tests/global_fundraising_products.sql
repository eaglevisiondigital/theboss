\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7e/fixture.sql
\ir grouped/cart-helpers.sql
create function pg_temp.product_items(label text)returns jsonb language sql security definer set search_path=''as $$select jsonb_agg(id)from public.discount_order_items where order_id=pg_temp.did(label,'order_id')$$;
grant execute on function pg_temp.product_items(text)to authenticated;
create function pg_temp.product_policy(channel text,rev text)returns uuid language plpgsql as $$declare pp uuid;begin
 pp:=(public.boss_fundraising_allocation_mutate(jsonb_build_object('action','platform_policy.create','request_id',gen_random_uuid(),'input',jsonb_build_object('organization_id',pg_temp.f('org'),'campaign_id',pg_temp.fid('campaign'),'channel',channel,'currency','USD','settlement_policy_id',pg_temp.f('product-policy'),'product_revision_id',pg_temp.did(rev,'revision_id'),'agreement_reference','LOCAL-SYNTHETIC-CARD','participant_credit_max_bps',5000,'wallet_permitted',false,'starts_at',clock_timestamp()-interval'1 hour')))->>'id')::uuid;
 perform public.boss_fundraising_allocation_mutate(jsonb_build_object('action','allocation_policy.create','request_id',gen_random_uuid(),'input',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'team_id',pg_temp.f('falcons'),'channel',channel,'platform_policy_id',pp,'organization_bps',2000,'destination_bps',3000,'participant_bps',5000,'starts_at',clock_timestamp())));return pp;
end$$;
grant execute on function pg_temp.product_policy(text,text)to authenticated;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.product_policy('digital_card','base30');select pg_temp.product_policy('physical_card','card90');
select pg_temp.dm('global-stock','batch.create',jsonb_build_object('revision_id',pg_temp.did('card90','revision_id'),'organization_id',pg_temp.f('org'),'owner_type','organization','name','SYNTHETIC global compatibility stock','quantity',1,'controlled',true));
select pg_temp.dm('global-stock-print','cards.print',jsonb_build_object('organization_id',pg_temp.f('org'),'card_ids',(select jsonb_agg(c->'card_id')from jsonb_array_elements(pg_temp.dr('global-stock')->'one_time_cards')c)));
select pg_temp.actor('parent');
select pg_temp.product_order('global-digital','base30','card',1,jsonb_build_object('path',pg_temp.fpath('share')));
select pg_temp.product_order('global-physical','card90','card',1,jsonb_build_object('path',pg_temp.fpath('share')));
reset role;
select pg_temp.check('each card order snapshots a distinct authoritative channel','CHANNEL',(select array_agg(channel order by channel)=array['digital_card','physical_card']from public.fundraising_checkout_snapshots where product_order_id is not null));
select pg_temp.check('card source never becomes donation intent','SEPARATION',(select bool_and(intent_id is null and product_order_id is not null and participant_id=pg_temp.f('participant-child1'))from public.fundraising_checkout_snapshots));
do $$declare label text;c public.payment_checkouts;e uuid;p uuid;begin foreach label in array array['global-digital','global-physical']loop
 perform boss_private.rails_dispatch(pg_temp.did(label,'checkout_id'));perform pg_temp.product_receive(label,'captured');
 select *into c from public.payment_checkouts where id=pg_temp.did(label,'checkout_id');
 perform boss_private.rails_receive(c.id,label||'-settlement','settled','LOCAL-PRODUCT-'||label,c.external_minor,c.currency,clock_timestamp(),repeat('a',64),jsonb_build_object('processor_fee_minor',0));
 select id into e from public.provider_event_evidence where event_reference=label||'-settlement';select payment_id into p from public.external_payment_tenders where checkout_id=c.id and original_payment_id is null;
 perform boss_private.rails_settlement_match(p,e,0);
end loop;end$$;
select pg_temp.check('each source gets only captured card proceeds designations','CREDIT',(select count(*)=2 and sum(original_minor)=3500 from public.fundraising_credit_sources));
select pg_temp.check('product organization credit is not duplicated as cash','SEPARATION',(select sum(amount_minor)=3500 from public.discount_product_credits)and(select sum(amount_minor)=3500 from public.fundraising_credit_entries)and(select count(*)=2 from public.payments where status='recorded'and id in(select payment_id from public.fundraising_credit_sources)));
select pg_temp.check('cards do not create donation Wallet grants','SEPARATION',not exists(select 1 from public.boss_bucks_grants where evidence_id in(select id from public.fundraising_success_evidence where intent_id in(select intent_id from public.fundraising_checkout_snapshots))));
select pg_temp.check('fixed product economics preserve existing settlement algorithm','COMPATIBILITY',not exists(select 1 from public.fundraising_cash_rounding_sources));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.dm('global-product-refund','order.refund',jsonb_build_object('order_id',pg_temp.did('global-digital','order_id'),'item_ids',pg_temp.product_items('global-digital'),'reason','Synthetic original-source correction'));
reset role;
select boss_private.rails_refund_dispatch(pg_temp.did('global-product-refund','refund_id'));
select boss_private.rails_refund_receive(pg_temp.did('global-product-refund','refund_id'),'LOCAL-GLOBAL-CARD-REFUND','refunded','LOCAL-GLOBAL-CARD-REFUND',2500,'USD',clock_timestamp(),repeat('b',64));
select pg_temp.check('original digital credit is corrected, physical remains','CORRECTION',(select sum(amount_minor)=1750 from public.fundraising_credit_entries)and(select sum(amount_minor)=1750 from public.discount_product_credits));
set local role authenticated;select pg_temp.actor('admin');
insert into group_results values('product-report',public.boss_fundraising_allocation_read(jsonb_build_object('campaign_id',pg_temp.fid('campaign'))));
reset role;
select pg_temp.check('product report distinguishes cash, credit and zero donations','REPORT',(select (select sum((r->>'gross_donation_minor')::bigint)from jsonb_array_elements(data->'source_page')r)=0 and(select sum((r->>'gross_digital_card_sales_minor')::bigint)from jsonb_array_elements(data->'source_page')r)=2500 and(select sum((r->>'gross_physical_card_sales_minor')::bigint)from jsonb_array_elements(data->'source_page')r)=2500 from group_results where label='product-report'));
set constraints all immediate;
select count(*)passed_assertions,'Global digital/physical card channel accounting' suite from phase5a_assertions;rollback;
