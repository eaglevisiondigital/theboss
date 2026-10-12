\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/fixture.sql
select pg_temp.success('child1-A',2000);
insert into public.household_memberships(household_id,person_id,relationship_type,starts_at)values(pg_temp.f('household'),pg_temp.f('child2'),'child',now()-interval'1 day');
insert into public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,starts_at,can_manage_boss_bucks,can_manage_fundraising,can_manage_payments)
 values(pg_temp.f('guardian-child2'),pg_temp.f('parent'),pg_temp.f('child2'),'active',now()-interval'1 day',now()-interval'1 day',true,true,true);
insert into public.organization_memberships(organization_id,person_id,starts_at)values(pg_temp.f('other-org'),pg_temp.f('child1'),now()-interval'1 day');
insert into public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at)values(pg_temp.f('other-org'),pg_temp.f('other-team'),pg_temp.f('child1'),pg_temp.f('participant-child1'),'athlete',now()-interval'1 day');
create function pg_temp.enroll_source(label text,org_label text,child_label text,team_label text)returns void language plpgsql as $$begin
 set local role authenticated;perform pg_temp.actor(case when org_label='other-org'then'other-admin'else'admin'end);
 perform pg_temp.fm('campaign.create',jsonb_build_object('organization_id',pg_temp.f(org_label),'name','Synthetic source '||label,'currency','USD','goal_minor',10000,'starts_at',now()-interval'1 day','ends_at',now()+interval'30 days','scope','organization','channels',jsonb_build_array('direct_support')),'campaign-'||label);
 perform pg_temp.fm('campaign.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign-'||label),'expected_version',1));
 perform pg_temp.fm('fundraiser.enroll',jsonb_build_object('campaign_id',pg_temp.fid('campaign-'||label),'entries',jsonb_build_array(jsonb_build_object('participant_id',pg_temp.f('participant-'||child_label),'team_id',pg_temp.f(team_label)))));
 perform pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign-'||label),'mode','percentage','basis_points',10000,'currency','USD','channels',jsonb_build_array('direct_support')));reset role;
 insert into fundraising_ids select 'fundraiser-'||label,id,null from public.fundraising_fundraisers where campaign_id=pg_temp.fid('campaign-'||label);
 set local role authenticated;perform pg_temp.actor('parent');
 perform pg_temp.fm('fundraiser.accept',jsonb_build_object('campaign_id',pg_temp.fid('campaign-'||label),'fundraiser_id',pg_temp.fid('fundraiser-'||label),'display_name','Synthetic child'));
 perform pg_temp.bm('fundraiser.bind_household',jsonb_build_object('fundraiser_id',pg_temp.fid('fundraiser-'||label),'household_id',pg_temp.f('household')));
 perform pg_temp.fm('share.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign-'||label),'fundraiser_id',pg_temp.fid('fundraiser-'||label)),'share-'||label);reset role;
end$$;
select pg_temp.enroll_source('child2-A','org','child2','wildcats');select pg_temp.enroll_source('child1-B','other-org','child1','other-team');
create function pg_temp.from_share(label text,share text,amount bigint)returns uuid language plpgsql as $$declare x uuid;begin
 set local role anon;perform public.boss_fundraising_support(jsonb_build_object('action','intent','request_id',pg_temp.f('request-'||label),'input',jsonb_build_object('path',pg_temp.fpath(share),'capability',md5(label)||md5(label||'2'),'display_name','Synthetic supporter','anonymous',true,'amount_minor',amount)));reset role;
 select id into x from public.fundraising_intents where request_id=pg_temp.f('request-'||label);return boss_private.fundraising_ingest_success(x,'disposable-test',label,amount,'USD',clock_timestamp());end$$;
select pg_temp.from_share('child2-A','share-child2-A',3000);select pg_temp.from_share('child1-B','share-child1-B',5000);
set constraints all immediate;set constraints all deferred;
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('charge maximum excludes another organization','ORG',public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w(),'charge_id',pg_temp.f('charge-camp')))->'charges'->0->>'available_minor'='4000');
select pg_temp.conflict('combined family total is not spendable with A',format('select pg_temp.bm(''payment.spend'',%L)',pg_temp.spend_input(5000)));
insert into payment_results values('same-org-two-children',pg_temp.bm('payment.spend',pg_temp.spend_input(4000)));
reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('one charge uses legitimate earnings from two children','ATTRIBUTION',(select count(distinct g.person_id)=2 and sum(c.amount_minor)=4000 from public.boss_bucks_consumptions c join public.boss_bucks_grants g on g.id=c.grant_id));
select pg_temp.check('spending preserves B value','ORG',boss_private.bucks_available(pg_temp.w(),pg_temp.f('other-org'))=5000 and boss_private.bucks_available(pg_temp.w(),pg_temp.f('org'))=0);
select boss_private.bucks_reverse_source((select id from public.fundraising_success_evidence where source_reference='child1-A'),'Synthetic A invalidation');
select pg_temp.from_share('future-child1-B','share-child1-B',1000);
set constraints all immediate;set constraints all deferred;
select pg_temp.check('future B earning cannot cover A recovery','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=1000 and boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('other-org'))=0 and boss_private.bucks_available(pg_temp.w(),pg_temp.f('other-org'))=6000);
select pg_temp.from_share('future-child2-A','share-child2-A',2000);
select pg_temp.check('same-org future child earning covers family deficit','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0 and boss_private.bucks_available(pg_temp.w(),pg_temp.f('org'))=1000);
update public.organization_modules set status='inactive'where organization_id=pg_temp.f('org')and module_id in(select id from public.modules where key='fundraising');
set local role authenticated;select pg_temp.actor('parent');
insert into payment_results values('fundraising-off',pg_temp.bm('payment.spend',pg_temp.spend_input(1000,'church')));
select pg_temp.check('family payment history exposes no finance source details','PRIVACY',public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w()))::text!~'(source_reference|grant_id|account_id|donor_id|email|mobile)');
select pg_temp.check('family payment history is canonical internal evidence','HISTORY',jsonb_array_length(public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w()))->'payments')=2);
select pg_temp.actor('admin');
select pg_temp.check('finance accepted totals are own-org internal value','FINANCE',public.boss_bucks_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')))->'reports'->0->>'accepted_minor'='5000');
select pg_temp.check('finance retains allocation to grant source chain','LINEAGE',public.boss_bucks_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')))->'payments'->0->'allocations'->0->'sources'->0?'source_reference');
select pg_temp.actor('other-admin');
select pg_temp.check('B finance sees no A payment history','ORG',jsonb_array_length(public.boss_bucks_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('other-org')))->'payments')=0);
select pg_temp.actor('coach');select pg_temp.denied('team staff do not inherit household finance',format('select public.boss_bucks_read(%L::jsonb)',jsonb_build_object('mode','organization','organization_id',pg_temp.f('org'))));
reset role;
select pg_temp.check('fundraising module is not required for legitimate retained value','MODULE',boss_private.registration_charge_balance(pg_temp.f('charge-church'))->>'balance_due_minor'='9000');
-- The A payment consumed original child1 value whose recovery was satisfied by
-- the later child2 A earning. Returning that slice must touch no B lineage.
create temp table scoped_return as select jsonb_build_object('payment_id',(r.result->'receipt'->>'payment_id')::uuid,'reason','Synthetic organization-restricted recovery return',
 'allocations',jsonb_build_array(jsonb_build_object('allocation_id',a.id,'amount_minor',1000)))input from payment_results r
 join public.payment_allocations a on a.payment_id=(r.result->'receipt'->>'payment_id')::uuid where r.label='same-org-two-children';
grant select on scoped_return to authenticated;
set local role authenticated;select pg_temp.actor('admin');select pg_temp.bm('payment.reverse',(select input from scoped_return));reset role;
set constraints all immediate;
select pg_temp.check('Org A recovery release preserves all Org B available value','RELEASE_SCOPE',boss_private.bucks_available(pg_temp.w(),pg_temp.f('org'))=1000 and boss_private.bucks_available(pg_temp.w(),pg_temp.f('other-org'))=6000);
select pg_temp.check('Org A return changes only actual A replacement lineage','RELEASE_SCOPE',not exists(select 1 from public.boss_bucks_recovery_movements m join public.boss_bucks_grants g on g.id=m.replacement_grant_id where m.kind='release'and g.organization_id<>pg_temp.f('org'))and boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('other-org'))=0);
select count(*)passed_assertions,'Phase 7C scopes' suite from phase5a_assertions;rollback;
