-- Disposable synthetic product terms/economics. None are production defaults.
\ir ../phase7d/fixture.sql
insert into public.role_assignments(person_id,role_id,scope_type,starts_at)
select pg_temp.f('admin'),id,'platform',now()-interval'1 day'from public.roles where key='platform_administrator';
update public.organization_modules set configuration=configuration||'{"discount_membership":true,"membership_trials":true,"physical_cards":true,"membership_sales":true,"membership_upgrades":true}'::jsonb where module_id in(select id from public.modules where key='boss_bucks');
update public.organization_modules set configuration=configuration||'{"online_payments":true,"refunds":true}'::jsonb where module_id in(select id from public.modules where key='payments');
insert into public.settlement_policy_revisions(id,organization_id,purpose,currency,revision,organization_basis_points,platform_basis_points,product_cost_basis_points,processor_fee_owner,availability_seconds,created_by)
values(pg_temp.f('product-policy'),pg_temp.f('org'),'products','USD',1,7000,3000,0,'platform',0,pg_temp.f('admin')),
 (pg_temp.f('upgrade-policy'),pg_temp.f('org'),'products','USD',2,0,10000,0,'platform',0,pg_temp.f('admin'));
insert into public.payment_routing_revisions(id,organization_id,account_id,purpose,currency,scope_type,scope_id,revision,starts_at,created_by)
values(pg_temp.f('product-route'),pg_temp.f('org'),pg_temp.f('rails-account'),'products','USD','organization',pg_temp.f('org'),1,now()-interval'1 day',pg_temp.f('admin'));
insert into public.payment_routing_events(routing_id,state,actor_id)values(pg_temp.f('product-route'),'active',pg_temp.f('admin'));
create temp table discount_test_results(label text primary key,result jsonb);
grant all on discount_test_results to authenticated;
create function pg_temp.dm(label text,action text,input jsonb)returns void language plpgsql as $$begin
 insert into discount_test_results values(label,public.boss_discounts_mutate(jsonb_build_object('request_id',pg_temp.f('discount-request-'||label),'action',action,'input',input)))
 on conflict on constraint discount_test_results_pkey do update set result=excluded.result;end$$;
create function pg_temp.did(label text,key text default 'membership_id')returns uuid language sql stable as $$select(result->>key)::uuid from discount_test_results where discount_test_results.label=did.label$$;
create function pg_temp.dr(label text)returns jsonb language sql stable as $$select result from discount_test_results where discount_test_results.label=dr.label$$;
create function pg_temp.revision(label text,product_label text,extra jsonb default '{}')returns void language plpgsql as $$begin
 perform pg_temp.dm(label,'revision.create',jsonb_strip_nulls(jsonb_build_object('product_id',pg_temp.did(product_label,'product_id'),'membership_product_id',pg_temp.did('digital','product_id'),
 'organization_id',pg_temp.f('org'),'subject_type','person','claim_policy','authenticated_self','currency','USD','price_minor',2500,'term_days',120,'trial_days',30,
 'country','US','region','VA','market','SYNTHETIC LOCAL MARKET','tier','local','organization_credit_minor',1750,'platform_retained_minor',750,'product_cost_minor',0,
 'settlement_policy_id',pg_temp.f('product-policy'),'sale_channels',jsonb_build_array('direct','fundraising'),'trial_enabled',true,'gift_enabled',true,
 'fulfillment_type','digital','starts_at',clock_timestamp()-interval'1 day')||extra));
 perform pg_temp.dm(label||'-activate','revision.status',jsonb_build_object('revision_id',pg_temp.did(label,'revision_id'),'state','active'));
end$$;
grant execute on function pg_temp.dm(text,text,jsonb),pg_temp.did(text,text),pg_temp.dr(text),pg_temp.revision(text,text,jsonb)to authenticated,anon;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.dm('digital','product.create','{"code":"synthetic_digital","name":"Synthetic Boss Bucks Discounts","kind":"digital"}');
select pg_temp.dm('physical','product.create','{"code":"synthetic_physical","name":"Synthetic Physical Boss Bucks Card","kind":"physical"}');
select pg_temp.dm('state','product.create','{"code":"synthetic_state","name":"Synthetic State Upgrade","kind":"state_upgrade"}');
select pg_temp.dm('national','product.create','{"code":"synthetic_national","name":"Synthetic Nationwide Upgrade","kind":"nationwide_upgrade"}');
select pg_temp.revision('base30','digital');
select pg_temp.revision('base60','digital','{"trial_days":60}');
select pg_temp.revision('base90','digital','{"trial_days":90}');
select pg_temp.revision('card90','physical','{"term_days":null,"trial_days":90,"gift_enabled":false,"fulfillment_type":"pickup","validity_anchor":"activation","card_validity_days":180}');
select pg_temp.revision('upgrade-state','state',jsonb_build_object('price_minor',1999,'term_days',null,'trial_days',null,'tier','state','organization_credit_minor',0,'platform_retained_minor',1999,'settlement_policy_id',pg_temp.f('upgrade-policy'),'trial_enabled',false,'gift_enabled',false));
select pg_temp.revision('upgrade-national','national',jsonb_build_object('price_minor',3900,'term_days',null,'trial_days',null,'tier','nationwide','organization_credit_minor',0,'platform_retained_minor',3900,'settlement_policy_id',pg_temp.f('upgrade-policy'),'trial_enabled',false,'gift_enabled',false));
select pg_temp.dm('campaign-base','campaign.configure',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'revision_id',pg_temp.did('base30','revision_id'),'trial_enabled',true,'gift_enabled',true,'sale_enabled',true));
select pg_temp.dm('campaign-card','campaign.configure',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'revision_id',pg_temp.did('card90','revision_id'),'trial_enabled',false,'gift_enabled',false,'sale_enabled',true));
reset role;
create function pg_temp.product_order(label text,revision_label text default 'base30',method text default 'card',quantity integer default 1,extra jsonb default '{}')returns void language plpgsql as $$begin
 perform pg_temp.dm(label,'order.create',jsonb_build_object('revision_id',pg_temp.did(revision_label,'revision_id'),'organization_id',pg_temp.f('org'),'quantity',quantity,'method',method)||extra);
end$$;
create function pg_temp.product_receive(label text,kind text,event_label text default null)returns jsonb language plpgsql as $$declare c public.payment_checkouts;ts timestamptz;ref text:=coalesce(event_label,label||'-'||kind);begin
 select *into c from public.payment_checkouts where id=pg_temp.did(label,'checkout_id');
 select occurred_at into ts from public.provider_event_evidence where account_id=c.account_id and event_reference=ref;
 return boss_private.rails_receive(c.id,ref,kind,'LOCAL-PRODUCT-'||label,c.external_minor,c.currency,coalesce(ts,clock_timestamp()),encode(sha256(convert_to(ref,'UTF8')),'hex'),
 case when kind='settled'then'{"processor_fee_minor":"0"}'::jsonb else'{}'::jsonb end);end$$;
grant execute on function pg_temp.product_order(text,text,text,integer,jsonb)to authenticated;
-- Resolve only disposable synthetic lineage before presenting a signed command.
create function pg_temp.product_source(label text)returns uuid language sql stable security definer set search_path=''as $$select source_id from public.discount_order_items where order_id=pg_temp.did(label,'order_id')order by ordinal limit 1$$;
grant execute on function pg_temp.product_source(text)to authenticated;
