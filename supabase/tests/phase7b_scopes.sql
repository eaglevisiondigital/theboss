\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7b/fixture.sql
select pg_temp.success('child1-A',2000);
-- The same family and second child; independent participant attribution.
insert into public.household_memberships(household_id,person_id,relationship_type,starts_at)values(pg_temp.f('household'),pg_temp.f('child2'),'child',now()-interval'1 day');
insert into public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,starts_at,can_manage_boss_bucks,can_manage_fundraising,can_manage_payments)
 values(pg_temp.f('guardian-child2'),pg_temp.f('parent'),pg_temp.f('child2'),'active',now()-interval'1 day',now()-interval'1 day',true,true,true);
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.fm('campaign.create',jsonb_build_object('organization_id',pg_temp.f('org'),'name','Second child campaign','currency','USD','goal_minor',10000,'starts_at',now()-interval'1 day','ends_at',now()+interval'30 days','scope','organization','channels',jsonb_build_array('direct_support')),'campaign-child2');
select pg_temp.fm('campaign.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign-child2'),'expected_version',1));
select pg_temp.fm('fundraiser.enroll',jsonb_build_object('campaign_id',pg_temp.fid('campaign-child2'),'entries',jsonb_build_array(jsonb_build_object('participant_id',pg_temp.f('participant-child2'),'team_id',pg_temp.f('wildcats')))));
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign-child2'),'mode','percentage','basis_points',10000,'currency','USD','channels',jsonb_build_array('direct_support')));
reset role;insert into fundraising_ids select 'fundraiser-child2',id,null from public.fundraising_fundraisers where campaign_id=pg_temp.fid('campaign-child2');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.fm('fundraiser.accept',jsonb_build_object('campaign_id',pg_temp.fid('campaign-child2'),'fundraiser_id',pg_temp.fid('fundraiser-child2'),'display_name','Synthetic Child2'));
select pg_temp.bm('fundraiser.bind_household',jsonb_build_object('fundraiser_id',pg_temp.fid('fundraiser-child2'),'household_id',pg_temp.f('household')));
select pg_temp.fm('share.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign-child2'),'fundraiser_id',pg_temp.fid('fundraiser-child2')),'share-child2');reset role;
-- Owner-only fixture helper keeps each current verified source independent.
create function pg_temp.from_share(label text,share text,amount bigint)returns uuid language plpgsql as $$declare x uuid;begin
 set local role anon;perform public.boss_fundraising_support(jsonb_build_object('action','intent','request_id',pg_temp.f('request-'||label),'input',jsonb_build_object('path',pg_temp.fpath(share),'capability',md5(label)||md5(label||'2'),'display_name','Synthetic supporter','anonymous',true,'amount_minor',amount)));reset role;
 select id into x from public.fundraising_intents where request_id=pg_temp.f('request-'||label);return boss_private.fundraising_ingest_success(x,'disposable-test',label,amount,'USD',clock_timestamp());end$$;
select pg_temp.from_share('child2-A','share-child2',3000);
set constraints all immediate;set constraints all deferred;
select pg_temp.check('two children share one org account','ATTRIBUTION',boss_private.bucks_available(pg_temp.w(),pg_temp.f('org'))=4000 and(select count(*)=1 from public.boss_bucks_accounts where wallet_id=pg_temp.w())and(select count(distinct person_id)=2 from public.boss_bucks_grants));
-- Transfer creates current B membership, never relabels A evidence.
update public.team_memberships set status='inactive',ends_at=clock_timestamp()where person_id=pg_temp.f('child1');
insert into public.organization_memberships(organization_id,person_id,starts_at)values(pg_temp.f('other-org'),pg_temp.f('child1'),now()-interval'1 day');
insert into public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at)values(pg_temp.f('other-org'),pg_temp.f('other-team'),pg_temp.f('child1'),pg_temp.f('participant-child1'),'athlete',now()-interval'1 day');
select pg_temp.check('transfer cannot change originating restriction','TRANSFER',boss_private.bucks_available(pg_temp.w(),pg_temp.f('org'))=4000 and boss_private.bucks_available(pg_temp.w(),pg_temp.f('other-org'))=0);
set local role authenticated;select pg_temp.actor('other-admin');
select pg_temp.fm('campaign.create',jsonb_build_object('organization_id',pg_temp.f('other-org'),'name','Organization B campaign','currency','USD','goal_minor',10000,'starts_at',now()-interval'1 day','ends_at',now()+interval'30 days','scope','organization','channels',jsonb_build_array('direct_support')),'campaign-B');
select pg_temp.fm('campaign.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign-B'),'expected_version',1));
select pg_temp.fm('fundraiser.enroll',jsonb_build_object('campaign_id',pg_temp.fid('campaign-B'),'entries',jsonb_build_array(jsonb_build_object('participant_id',pg_temp.f('participant-child1'),'team_id',pg_temp.f('other-team')))));
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign-B'),'mode','percentage','basis_points',10000,'currency','USD','channels',jsonb_build_array('direct_support')));
reset role;insert into fundraising_ids select 'fundraiser-B',id,null from public.fundraising_fundraisers where campaign_id=pg_temp.fid('campaign-B');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.fm('fundraiser.accept',jsonb_build_object('campaign_id',pg_temp.fid('campaign-B'),'fundraiser_id',pg_temp.fid('fundraiser-B'),'display_name','Synthetic Child1 B'));
select pg_temp.bm('fundraiser.bind_household',jsonb_build_object('fundraiser_id',pg_temp.fid('fundraiser-B'),'household_id',pg_temp.f('household')));
select pg_temp.fm('share.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign-B'),'fundraiser_id',pg_temp.fid('fundraiser-B')),'share-B');reset role;
select pg_temp.from_share('child1-B','share-B',5000);
set constraints all immediate;set constraints all deferred;
select pg_temp.check('master display combines same currency','ORG',boss_private.bucks_available(pg_temp.w())=9000);
select pg_temp.check('B remains independent A','ORG',boss_private.bucks_available(pg_temp.w(),pg_temp.f('org'))=4000 and boss_private.bucks_available(pg_temp.w(),pg_temp.f('other-org'))=5000);
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.check('A finance cannot see B values','ORG',public.boss_bucks_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')))->'reports'->0->>'available_minor'='4000');
select pg_temp.actor('other-admin');
select pg_temp.check('B finance cannot see A values','ORG',public.boss_bucks_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('other-org')))->'reports'->0->>'available_minor'='5000');reset role;
update public.fundraising_campaigns set status='archived'where organization_id=pg_temp.f('org');
select pg_temp.check('campaign archival retains value','HISTORY',boss_private.bucks_available(pg_temp.w(),pg_temp.f('org'))=4000);
update public.organizations set status='archived'where id=pg_temp.f('other-org');
select pg_temp.check('org archival withholds availability preserves history','HISTORY',boss_private.bucks_available(pg_temp.w(),pg_temp.f('other-org'))=0 and(select count(*)=1 from public.boss_bucks_grants where organization_id=pg_temp.f('other-org')));
select count(*)passed_assertions,'Phase 7B scopes' suite from phase5a_assertions;rollback;
