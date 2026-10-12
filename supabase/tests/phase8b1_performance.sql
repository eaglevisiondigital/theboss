\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase8b1/fixture.sql
insert into public.partner_benefit_sources(provider_id,external_id,current_revision,status,last_verified_at)
select pg_temp.pid('provider'),'synthetic-volume-'||n,1,'available',clock_timestamp()from generate_series(1,10000)n;
insert into public.partner_benefit_revisions(provider_id,source_id,source_revision,contract_id,category,title,public_description,member_terms,country,region,market_id,product_id,minimum_tier,fulfillment,starts_at,ends_at,source_digest)
select s.provider_id,s.id,1,pg_temp.pid('contract'),'restaurants','Synthetic volume benefit','Synthetic public description','Synthetic member terms','US','VA',pg_temp.mid('market','market_id'),pg_temp.did('digital','product_id'),'local','percentage_discount',clock_timestamp()-interval'1 day',clock_timestamp()+interval'10 days',repeat('a',64)from public.partner_benefit_sources s where external_id like'synthetic-volume-%';
analyze public.partner_benefit_sources;analyze public.partner_benefit_revisions;
do $$declare started timestamptz;r jsonb;elapsed numeric;begin
 started:=clock_timestamp();perform set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.f('auth-admin'),'role','authenticated','is_anonymous',false,'session_id',pg_temp.f('session-admin'))::text,true);
 r:=public.boss_partners_read(pg_temp.pi('{"mode":"catalog","limit":50}'));elapsed:=extract(epoch from clock_timestamp()-started)*1000;
 perform pg_temp.check('10k catalog bounded read','PERFORMANCE',jsonb_array_length(r->'catalog')=50 and elapsed<1000);
 raise notice 'Phase8B1 10000-source/10000-revision catalog page: % ms',round(elapsed,3);
end$$;
select pg_temp.check('provider/external source index','INDEX',exists(select 1 from pg_indexes where tablename='partner_benefit_sources'and indexdef like'%provider_id, external_id%'));
select pg_temp.check('provider/page catalog index','INDEX',exists(select 1 from pg_indexes where indexname='partner_benefit_page_idx'));
select pg_temp.check('future activation locked at scale','ACTIVATION',not exists(select 1 from public.partner_config_revisions where operational));
select pg_temp.check('native at scale remains available','NATIVE',boss_private.merchant_available(pg_temp.mid('offer'),pg_temp.mid('loc-a')));
select count(*)passed_assertions,'Phase 8B1 synthetic catalog performance'::text suite from phase5a_assertions;rollback;
