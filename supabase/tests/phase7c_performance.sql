\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/fixture.sql
insert into public.fundraising_donors(id,display_name)values(pg_temp.f('scale-donor'),'Synthetic scale supporter');
create function pg_temp.load_spend_grants(batch integer)returns void language plpgsql as $$declare n integer;x uuid;f public.fundraising_fundraisers;begin
 select *into f from public.fundraising_fundraisers where id=pg_temp.fid('fundraiser');
 for n in batch*100+1..batch*100+100 loop
 insert into public.fundraising_intents(campaign_id,fundraiser_id,donor_id,amount_minor,currency,anonymous,fee_cover,source_kind,provenance,reward_policy,capability_digest,expires_at,request_id)
 values(f.campaign_id,f.id,pg_temp.f('scale-donor'),2,'USD',true,false,'participant_share',jsonb_build_object('organization_id',f.organization_id,'restricted_use_organization_id',f.organization_id,'campaign_id',f.campaign_id,'fundraiser_id',f.id,'participant_id',f.participant_id,'person_id',f.person_id,'team_id',f.team_id,'unit_id',f.unit_id,'household_id',f.household_id),'{}',md5('7c-scale-'||n)||md5('7c-scale2-'||n),clock_timestamp()+interval'1 day',gen_random_uuid())returning id into x;
 perform boss_private.fundraising_ingest_success(x,'disposable-7c-scale','scale-'||n,2,'USD',clock_timestamp());end loop;
end$$;
select pg_temp.load_spend_grants(0);select pg_temp.load_spend_grants(1);select pg_temp.success('extra',2);
select pg_temp.charge('scale-'||n)from generate_series(1,150)n;
analyze public.boss_bucks_grants;analyze public.boss_bucks_journals;analyze public.boss_bucks_postings;analyze public.charges;
create temp table spending_performance(label text primary key,milliseconds numeric,response_bytes integer);
grant all on spending_performance to authenticated;
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.conflict('more than 200 required positive lots fails atomically',format('select pg_temp.bm(''payment.spend'',%L)',pg_temp.spend_input(201)));
reset role;
select pg_temp.check('bounded-batch failure preserves entire payment/wallet','BOUNDS',boss_private.bucks_available(pg_temp.w())=201 and not exists(select 1 from public.boss_bucks_consumptions)and not exists(select 1 from public.payments));
set local role authenticated;select pg_temp.actor('parent');
do $$declare at timestamptz:=clock_timestamp();r jsonb;allocations jsonb;begin
 select jsonb_agg(jsonb_build_object('charge_id',pg_temp.f('charge-scale-'||n),'amount_minor',4)order by n)into allocations from generate_series(1,50)n;
 r:=pg_temp.bm('payment.spend',jsonb_build_object('wallet_id',pg_temp.w(),'organization_id',pg_temp.f('org'),'currency','USD','amount_minor',200,'allocations',allocations));
 insert into spending_performance values('200 grants / 50 charges',extract(epoch from clock_timestamp()-at)*1000,octet_length(r::text));end$$;
reset role;
do $$declare at timestamptz:=clock_timestamp();begin set constraints all immediate;insert into spending_performance values('deferred proof',extract(epoch from clock_timestamp()-at)*1000,0);set constraints all deferred;end$$;
select pg_temp.check('200 lots conserve all payment allocations','SCALE',(select count(*)=200 and sum(amount_minor)=200 from public.boss_bucks_consumptions)and(select count(*)=50 and sum(amount_minor)=200 from public.payment_allocations)and boss_private.bucks_available(pg_temp.w())=1);
set local role authenticated;select pg_temp.actor('parent');
do $$declare at timestamptz:=clock_timestamp();r jsonb;begin r:=public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w()));insert into spending_performance values('family / 154 charges',extract(epoch from clock_timestamp()-at)*1000,octet_length(r::text));
 perform pg_temp.check('many-charge family returns bounded 50','BOUNDS',jsonb_array_length(r->'charges')=50);
 perform pg_temp.check('wallet activity remains bounded','BOUNDS',jsonb_array_length(r->'wallets'->0->'activity')=50);end$$;
select pg_temp.actor('admin');
do $$declare at timestamptz:=clock_timestamp();r jsonb;begin r:=public.boss_bucks_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org'),'wallet_id',pg_temp.w()));insert into spending_performance values('own-org finance',extract(epoch from clock_timestamp()-at)*1000,octet_length(r::text));
 perform pg_temp.check('finance exact accepted total','FINANCE',r->'reports'->0->>'accepted_minor'='200');end$$;reset role;
do $$declare at timestamptz:=clock_timestamp();r jsonb;begin r:=boss_private.bucks_rebuild(pg_temp.w());insert into spending_performance values('ledger rebuild',extract(epoch from clock_timestamp()-at)*1000,octet_length(r::text));perform pg_temp.check('many-lot rebuild exact','REBUILD',r->0->>'available_minor'='1');end$$;
do $$begin if(select max(milliseconds)from spending_performance)>=2000 then raise exception'Phase7C performance milliseconds: %',(select jsonb_object_agg(label,round(milliseconds,2))from spending_performance);end if;end$$;
select pg_temp.check('all focused operations under two seconds','PERFORMANCE',(select max(milliseconds)<2000 from spending_performance));
select pg_temp.check('bounded responses under 100KB','PERFORMANCE',(select max(response_bytes)<100000 from spending_performance));
select pg_temp.check('8-second ceiling preserved','PERFORMANCE',current_setting('statement_timeout')='8s');
select count(*)passed_assertions,'Phase 7C many grants/charges' suite from phase5a_assertions;
select *from spending_performance order by label;rollback;
