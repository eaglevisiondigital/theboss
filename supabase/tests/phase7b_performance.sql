\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7b/fixture.sql
-- Real trusted-source paths in bounded fixture-loading batches, not fabricated
-- mutable balances. This database is disposable and has no network/Auth secrets.
insert into public.fundraising_donors(id,display_name)values(pg_temp.f('scale-donor'),'Synthetic scale supporter');
create function pg_temp.load_wallet_batch(batch integer)returns void language plpgsql as $$declare n integer;x uuid;f public.fundraising_fundraisers;begin
 select *into f from public.fundraising_fundraisers where id=pg_temp.fid('fundraiser');
 for n in batch*100+1..batch*100+100 loop
 insert into public.fundraising_intents(campaign_id,fundraiser_id,donor_id,amount_minor,currency,anonymous,fee_cover,source_kind,provenance,reward_policy,capability_digest,expires_at,request_id)
 values(f.campaign_id,f.id,pg_temp.f('scale-donor'),2,'USD',true,false,'participant_share',jsonb_build_object('organization_id',f.organization_id,'restricted_use_organization_id',f.organization_id,'campaign_id',f.campaign_id,'fundraiser_id',f.id,'participant_id',f.participant_id,'person_id',f.person_id,'team_id',f.team_id,'unit_id',f.unit_id,'household_id',f.household_id),'{}',md5('scale-'||n)||md5('scale2-'||n),clock_timestamp()+interval '1 day',gen_random_uuid())returning id into x;
 perform boss_private.fundraising_ingest_success(x,'disposable-scale','scale-'||n,2,'USD',clock_timestamp());
 end loop;end$$;
select format('select pg_temp.load_wallet_batch(%s);',n)from generate_series(0,49)n \gexec
set constraints all immediate;set constraints all deferred;
insert into public.households(id,name)select md5('phase7b-scale-household-'||n)::uuid,'Synthetic scale family '||n from generate_series(1,5000)n;
insert into public.boss_bucks_wallets(household_id,currency)select id,'USD'from public.households where name like'Synthetic scale family %';
insert into public.boss_bucks_accounts(kind,wallet_id,household_id,organization_id,currency)select'household',id,household_id,pg_temp.f('org'),currency from public.boss_bucks_wallets where household_id<>pg_temp.f('household');
analyze public.boss_bucks_grants;analyze public.boss_bucks_journals;analyze public.boss_bucks_postings;analyze public.boss_bucks_wallets;analyze public.boss_bucks_accounts;analyze public.boss_bucks_access;
create temp table wallet_performance(read_ms numeric,report_ms numeric,rebuild_ms numeric,response_bytes integer);
grant all on wallet_performance to authenticated;
set local role authenticated;select pg_temp.actor('parent');
do $$declare at timestamptz:=clock_timestamp();r jsonb;last_id uuid;begin
 r:=public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w()));insert into wallet_performance(read_ms,response_bytes)values(extract(epoch from clock_timestamp()-at)*1000,octet_length(r::text));
 perform pg_temp.check('5000 historical sources exact current value','PERFORMANCE',r->'wallets'->0->>'available_minor'='5000');
 perform pg_temp.check('family cohort excludes 5000 unrelated households','PERFORMANCE',jsonb_array_length(r->'wallets')=1);
 perform pg_temp.check('initial activity limited to 50','PERFORMANCE',jsonb_array_length(r->'wallets'->0->'activity')=50);
 last_id:=(r->'wallets'->0->'activity'->49->>'id')::uuid;
 r:=public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w(),'before_id',last_id));
 perform pg_temp.check('cursor returns next 50 older journals','PERFORMANCE',jsonb_array_length(r->'wallets'->0->'activity')=50 and not exists(select 1 from jsonb_array_elements(r->'wallets'->0->'activity')a where(a->>'id')::uuid=last_id));
end$$;
select pg_temp.actor('admin');
do $$declare at timestamptz:=clock_timestamp();r jsonb;begin r:=public.boss_bucks_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')));update wallet_performance set report_ms=extract(epoch from clock_timestamp()-at)*1000;
 perform pg_temp.check('organization report bounded to 100 family slices','PERFORMANCE',jsonb_array_length(r->'reports')=100 and not(r?'wallets'));
end$$;reset role;
do $$declare at timestamptz:=clock_timestamp();r jsonb;begin r:=boss_private.bucks_rebuild(pg_temp.w());update wallet_performance set rebuild_ms=extract(epoch from clock_timestamp()-at)*1000;perform pg_temp.check('long history rebuild equals live projection','REBUILD',r->0->>'available_minor'='5000');end$$;
select pg_temp.check('family read under 2 second budget','PERFORMANCE',(select read_ms<2000 from wallet_performance));
select pg_temp.check('org report under 2 second budget','PERFORMANCE',(select report_ms<2000 from wallet_performance));
select pg_temp.check('rebuild under 2 second budget','PERFORMANCE',(select rebuild_ms<2000 from wallet_performance));
select pg_temp.check('response bounded below 100 KB','PERFORMANCE',(select response_bytes<100000 from wallet_performance));
select count(*)passed_assertions,'Phase 7B long ledger' suite from phase5a_assertions;
select *from wallet_performance;rollback;
