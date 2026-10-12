\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7a/fixture.sql
create temp table scope_performance(label text,elapsed_ms numeric,response_bytes integer);
grant all on scope_performance to authenticated,anon;
insert into public.organizations(id,name,slug)select pg_temp.f('scale-org-'||n),'Synthetic scale org '||n,'phase7a-scale-'||n from generate_series(1,100)n;
insert into public.fundraising_campaigns(id,organization_id,name,currency,goal_minor,starts_at,ends_at,scope,status,created_by)
select pg_temp.f('scale-camp-'||o||'-'||n),pg_temp.f('scale-org-'||o),'Synthetic scale campaign','USD',100000,now()-interval'1 day',now()+interval'1 month','organization','active',pg_temp.f('admin')from generate_series(1,100)o cross join generate_series(1,30)n;
insert into public.fundraising_campaigns(id,organization_id,name,currency,goal_minor,starts_at,ends_at,scope,status,created_by)
select pg_temp.f('scale-local-'||n),pg_temp.f('org'),'Synthetic local campaign','USD',100000,now()-interval'1 day',now()+interval'1 month','organization','active',pg_temp.f('admin')from generate_series(1,100)n;
insert into public.people(id,display_name)select pg_temp.f('scale-person-'||n),'Synthetic participant '||n from generate_series(1,500)n;
insert into public.participants(id,person_id)select pg_temp.f('scale-participant-'||n),pg_temp.f('scale-person-'||n)from generate_series(1,500)n;
insert into public.organization_memberships(organization_id,person_id,starts_at)select pg_temp.f('org'),pg_temp.f('scale-person-'||n),now()-interval'1 day'from generate_series(1,500)n;
insert into public.fundraising_fundraisers(id,organization_id,campaign_id,participant_id,person_id,status,public_display_name)
select pg_temp.f('scale-f-'||c||'-'||n),pg_temp.f('org'),pg_temp.f('scale-local-'||c),pg_temp.f('scale-participant-'||n),pg_temp.f('scale-person-'||n),'active','Approved synthetic fundraiser '||n from generate_series(1,5)c cross join generate_series(1,500)n;
insert into public.fundraising_shares(fundraiser_id,authorized_by)select id,pg_temp.f('parent')from public.fundraising_fundraisers where campaign_id in(select pg_temp.f('scale-local-'||c)from generate_series(1,5)c);
insert into fundraising_ids(label,id)select 'scale_cursor',id from public.fundraising_fundraisers where campaign_id=pg_temp.f('scale-local-1')order by id offset 199 limit 1;
set local role authenticated;select pg_temp.actor('admin');
do $$declare started timestamptz:=clock_timestamp();result jsonb;begin
 result:=public.boss_fundraising_read(jsonb_build_object('organization_id',pg_temp.f('org'),'limit',50));
 insert into scope_performance values('50 scoped campaigns',extract(epoch from clock_timestamp()-started)*1000,octet_length(result::text));
 perform pg_temp.check('scope campaign pagination bounded','SCALE',jsonb_array_length(result->'campaigns')=50);
 perform pg_temp.check('scope participant projections bounded','SCALE',not exists(select 1 from jsonb_array_elements(result->'campaigns')c where jsonb_array_length(c->'fundraisers')>200));
 perform pg_temp.check('tenant roster remains bounded','SCALE',jsonb_array_length(result->'catalog'->'participants')<=200);
 perform pg_temp.check('other tenant campaigns never in scoped page','SCALE',not exists(select 1 from jsonb_array_elements(result->'campaigns')c where c->>'organization_id'<>pg_temp.f('org')::text));
end$$;
select pg_temp.check('participant cursor retrieves later eligible page','SCALE',jsonb_array_length(public.boss_fundraising_read(jsonb_build_object('organization_id',pg_temp.f('org'),'campaign_id',pg_temp.f('scale-local-1'),'fundraiser_after',pg_temp.fid('scale_cursor')))->'campaigns'->0->'fundraisers')=200);reset role;
select pg_temp.check('realistic 100 org 3100 extra campaigns 2500 links','SCALE',(select count(*)>=3101 from public.fundraising_campaigns)and(select count(*)>=2501 from public.fundraising_shares));
select pg_temp.check('scoped campaign read under unchanged 8s ceiling','SCALE',(select bool_and(elapsed_ms<8000)from scope_performance));
select count(*)passed_assertions from pg_temp.phase5a_assertions;select *from scope_performance;rollback;
