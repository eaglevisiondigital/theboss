\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir global/fixture.sql
-- Structural tenant population is not a production throughput certification.
insert into public.organizations(id,name,slug)select md5('global-scale-org-'||n)::uuid,'SYNTHETIC scale tenant '||n,'synthetic-global-scale-'||n from generate_series(1,10000)n;
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at)
select md5('global-scale-org-'||n)::uuid,m.id,'active',jsonb_build_object(m.key,true),now()-interval'1 day'from generate_series(1,10000)n cross join public.modules m where m.key in('fundraising','money_board');
insert into public.fundraising_campaigns(id,organization_id,name,currency,goal_minor,starts_at,ends_at,scope,channels,created_by)
select md5('global-scale-campaign-'||n||'-'||k)::uuid,md5('global-scale-org-'||n)::uuid,'SYNTHETIC independent campaign '||k,'USD',10000000,now()-interval'1 day',now()+interval'30 days','organization',array['money_board','direct_support'],pg_temp.f('director')from generate_series(1,10000)n cross join generate_series(1,2)k;
insert into public.money_boards(campaign_id,title,goal_minor,start_minor,increment_minor,tile_count,visibility)
select md5('global-scale-campaign-'||n||'-'||k)::uuid,'SYNTHETIC independent board',10000000,100,100,50,'public'from generate_series(1,10000)n cross join generate_series(1,2)k;
select pg_temp.check('10000 independent tenants with two campaigns each','SCALE',(select count(*)=10000 from public.organizations where slug like'synthetic-global-scale-%')and(select count(*)=20000 from public.fundraising_campaigns where name like'SYNTHETIC independent campaign%'));
select pg_temp.check('cart limit never limits board/campaign/tenant count','SCALE',(select count(*)=20000 from public.money_boards where title='SYNTHETIC independent board'));
select pg_temp.check('same nominal tile schedules are independently owned','ISOLATION',(select count(distinct campaign_id)=20000 from public.money_boards where title='SYNTHETIC independent board'and start_minor=100 and increment_minor=100));
create temp table scale_times(label text primary key,milliseconds numeric);
do $$declare org uuid;campaign uuid;board public.money_boards;result jsonb;ts timestamptz;idx int;total_ms numeric:=0;begin
 perform pg_temp.actor('director');
 for idx in 1..10 loop
  org:=md5('global-scale-org-'||idx)::uuid;campaign:=md5('global-scale-campaign-'||idx||'-1')::uuid;
  insert into public.organization_memberships(organization_id,person_id,starts_at)values(org,pg_temp.f('director'),now()-interval'1 day');
  select *into board from public.money_boards where campaign_id=campaign;
  result:=public.boss_fundraising_mutate(jsonb_build_object('action','board.generate','request_id',gen_random_uuid(),'input',jsonb_build_object('campaign_id',campaign,'board_id',board.id,'expected_version',1)));
  perform public.boss_fundraising_mutate(jsonb_build_object('action','board.publish','request_id',gen_random_uuid(),'input',jsonb_build_object('campaign_id',campaign,'board_id',board.id,'expected_version',2)));
  perform public.boss_fundraising_mutate(jsonb_build_object('action','campaign.publish','request_id',gen_random_uuid(),'input',jsonb_build_object('campaign_id',campaign,'expected_version',1)));
  ts:=clock_timestamp();result:=public.boss_money_board_public(board.public_path,25);total_ms:=total_ms+extract(epoch from clock_timestamp()-ts)*1000;
  perform pg_temp.check('bounded indexed page at scale tenant '||idx,'SCALE',jsonb_array_length(result->'tiles')=25 and result->>'board_id'=board.id::text);
 end loop;
 insert into scale_times values('ten_native_public_pages_total_ms',total_ms);
end$$;
select pg_temp.check('non-Sports tenants never create Wallet or sports records','PORTABILITY',not exists(select 1 from public.organization_modules m join public.modules d on d.id=m.module_id join public.organizations o on o.id=m.organization_id where o.slug like'synthetic-global-scale-%'and d.key in('sports','boss_bucks')));
set constraints all immediate;
select count(*)passed_assertions,'10000-tenant structural/bounded projection scale' suite from phase5a_assertions;
select *from scale_times;rollback;
