\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase8a/fixture.sql
create temp table merchant_projection_timings(label text,milliseconds numeric,response_bytes integer);
grant insert,select on merchant_projection_timings to anon,authenticated;
create function pg_temp.measure_merchant(label text,q jsonb,directory boolean default false)returns jsonb language plpgsql as $$declare started timestamptz:=clock_timestamp();result jsonb;begin
 if directory then result:=public.boss_merchants_directory(q);else result:=public.boss_merchants_read(q);end if;
 insert into merchant_projection_timings values(label,round(extract(epoch from(clock_timestamp()-started))*1000,3),octet_length(result::text));return result;
end$$;
grant execute on function pg_temp.measure_merchant(text,jsonb,boolean)to anon,authenticated;
create temp table merchant_scale_context as select pg_temp.mid('market','market_id') va,pg_temp.mid('market-other','market_id') nc,pg_temp.mid('market-ca','market_id') ca,pg_temp.f('admin') actor;
create temp table merchant_scale_ids as select n,md5('8a-scale-merchant:'||n)::uuid m,md5('8a-scale-family:'||n)::uuid f,md5('8a-scale-offer:'||n)::uuid r from generate_series(1,10000)n;
insert into public.merchants(id,name,category,primary_market_id,status,created_by,controlled)
select m,'SYNTHETIC scale merchant '||n,case when n%2=0 then'retail'else'restaurants'end,c.va,'active',c.actor,true from merchant_scale_ids cross join merchant_scale_context c;
insert into public.merchant_modules(merchant_id,module_id,status,configuration)select m,id,'active','{"portal":true,"offers":true,"redemption":true}'from merchant_scale_ids cross join public.modules where key='commerce';
insert into public.merchant_locations(id,merchant_id,market_id,name,address,city,postal_code,timezone)
select md5('8a-scale-location:'||n||':'||a)::uuid,m,case when a=1 then c.va when a=2 then c.nc else c.ca end,
 'SYNTHETIC location '||a,'SYNTHETIC address','SYNTHETIC City','00000','America/New_York'from merchant_scale_ids cross join merchant_scale_context c cross join generate_series(1,4)a;
insert into public.merchant_offer_families(id,merchant_id,usage_limit,reset_period,usage_timezone,created_by)select f,m,10,'lifetime','America/New_York',c.actor from merchant_scale_ids cross join merchant_scale_context c;
insert into public.merchant_offer_revisions(id,merchant_id,family_id,revision,title,offer_type,discount_bps,qualification,stacking,starts_at,ends_at,location_policy,created_by)
select r,m,f,1,'SYNTHETIC scale discount','percentage_off',1000,'none','none',now()-interval'1 day',now()+interval'20 days','all_current',c.actor from merchant_scale_ids cross join merchant_scale_context c;
insert into public.merchant_offer_locations(merchant_id,revision_id,location_id)select s.m,s.r,l.id from merchant_scale_ids s join public.merchant_locations l on l.merchant_id=s.m;
insert into public.merchant_offer_events(revision_id,state,actor_id)select r,'published',c.actor from merchant_scale_ids cross join merchant_scale_context c;
insert into public.merchant_sales_leads(market_id,name,category,source,rep_id)select c.va,'SYNTHETIC pipeline '||n,'services','Synthetic scale referral',c.actor from generate_series(1,10000)n cross join merchant_scale_context c;
analyze public.merchants;analyze public.merchant_locations;analyze public.merchant_offer_families;analyze public.merchant_offer_revisions;analyze public.merchant_offer_events;analyze public.merchant_offer_locations;analyze public.merchant_sales_leads;
select pg_temp.check('10000 merchants and 40000 locations','SCALE',(select count(*)=10000 from merchant_scale_ids)and(select count(*)=40004 from public.merchant_locations));
\timing on
set local role anon;
select pg_temp.check('directory bounded at launch and growth scale','BOUNDED',jsonb_array_length(pg_temp.measure_merchant('public directory / 10000 merchants',jsonb_build_object('market_id',pg_temp.mid('market','market_id'),'search','SYNTHETIC scale'),true)->'items')=30);
reset role;set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('local consumer discovery bounded at scale','BOUNDED',jsonb_array_length(pg_temp.measure_merchant('consumer / 10000 offers',jsonb_build_object('market_id',pg_temp.mid('market','market_id')))->'offers')=30);
select pg_temp.check('outside country does not return discount terms at scale','GEOGRAPHY',jsonb_array_length(pg_temp.measure_merchant('outside country',jsonb_build_object('market_id',pg_temp.mid('market-ca','market_id')))->'offers')=0);
select pg_temp.actor('coach');
select pg_temp.check('unassigned CRM bounded denial at scale','BOUNDED',jsonb_array_length(pg_temp.measure_merchant('scoped CRM / 10000 leads','{"mode":"sales"}')->'leads')=0);
select pg_temp.actor('parent');
select pg_temp.check('owner portal home checks own resources at scale','BOUNDED',jsonb_array_length(pg_temp.measure_merchant('owner portal home','{"mode":"portal"}')->'merchants')=1);
select pg_temp.actor('admin');
select pg_temp.check('sales pipeline bounded at scale','BOUNDED',jsonb_array_length(pg_temp.measure_merchant('scoped CRM / 10000 leads','{"mode":"sales"}')->'leads')=30);
select pg_temp.check('merchant portal loads only selected merchant offers','BOUNDED',jsonb_array_length(pg_temp.measure_merchant('exact merchant portal',pg_temp.mi('{"mode":"portal"}'))->'offers')=1);
reset role;
do $$declare plan jsonb;begin
 execute format('explain(format json)select id from public.merchant_locations where market_id=%L and status=''active'' order by merchant_id,id limit 30',pg_temp.mid('market','market_id'))into plan;
 perform pg_temp.check('geography leading index used','INDEX',plan::text like'%merchant_locations_discovery_idx%');
 execute format('explain(format json)select id from public.merchant_sales_leads where rep_id=%L and market_id=%L order by state,id limit 30',pg_temp.f('admin'),pg_temp.mid('market','market_id'))into plan;
 perform pg_temp.check('rep market pipeline index used','INDEX',plan::text like'%merchant_sales_leads_pipeline_idx%');
end$$;
set constraints all immediate;
select count(*)passed_assertions,'Phase 8A 10000 merchants 40000 locations 10000 offers and leads'::text suite from phase5a_assertions;
select *from merchant_projection_timings;rollback;
