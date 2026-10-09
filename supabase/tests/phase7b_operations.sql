\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7b/fixture.sql
update public.guardian_relationships set can_manage_boss_bucks=false where id=pg_temp.f('guardian-child1');
select pg_temp.success('pending-owner',4000);
select pg_temp.check('no guessed household issuance','OWNER',not exists(select 1 from public.boss_bucks_grants));
select pg_temp.check('held source retains captured policy','OWNER',(select household_id is null and policy_revision_id is not null from public.boss_bucks_source_snapshots limit 1));
select pg_temp.denied('revoked guardian cannot resolve owner',format('select boss_private.bucks_resolve_owner((select id from public.fundraising_success_evidence where source_reference=''pending-owner''),%L,%L)',pg_temp.f('household'),pg_temp.f('parent')));
update public.guardian_relationships set can_manage_boss_bucks=true where id=pg_temp.f('guardian-child1');
select boss_private.bucks_resolve_owner((select id from public.fundraising_success_evidence where source_reference='pending-owner'),pg_temp.f('household'),pg_temp.f('parent'));
select pg_temp.check('exact trusted owner resolution issues original policy','OWNER',boss_private.bucks_available(pg_temp.w())=2000);
select boss_private.bucks_resolve_owner((select id from public.fundraising_success_evidence where source_reference='pending-owner'),pg_temp.f('household'),pg_temp.f('parent'));
select pg_temp.check('owner replay never duplicates value','OWNER',(select count(*)=1 from public.boss_bucks_grants)and(select count(*)=1 from public.boss_bucks_owner_resolutions));
select pg_temp.check('owner resolution never rewrites snapshot','OWNER',(select household_id is null from public.boss_bucks_source_snapshots limit 1));
set constraints all immediate;set constraints all deferred;
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('family cannot configure feature gates',format('select pg_temp.bm(''features.configure'',%L)',jsonb_build_object('organization_id',pg_temp.f('org'),'features',jsonb_build_object('wallet',true))));
select pg_temp.denied('forged organization provisioning denied',format('select pg_temp.bm(''wallet.provision'',%L)',jsonb_build_object('organization_id',pg_temp.f('other-org'),'household_id',pg_temp.f('household'),'dependent_person_id',pg_temp.f('child1'),'currency','CAD')));
select pg_temp.actor('admin');
select pg_temp.bm('features.configure',jsonb_build_object('organization_id',pg_temp.f('org'),'features',jsonb_build_object('wallet',true,'family_wallet',true)),pg_temp.f('features-request'));
select pg_temp.check('configuration replaces exact finite flags','FEATURE',not boss_private.bucks_admin_feature(pg_temp.f('org'),'fundraising_issuance')and boss_private.bucks_admin_feature(pg_temp.f('org'),'family_wallet'));
select pg_temp.check('feature replay idempotent','FEATURE',pg_temp.bm('features.configure',jsonb_build_object('organization_id',pg_temp.f('org'),'features',jsonb_build_object('wallet',true,'family_wallet',true)),pg_temp.f('features-request'))->>'replayed'='true');
select pg_temp.denied('future spending flag cannot be enabled',format('select pg_temp.bm(''features.configure'',%L)',jsonb_build_object('organization_id',pg_temp.f('org'),'features',jsonb_build_object('wallet',true,'spending',true))),'PT422');
select pg_temp.denied('sibling organization feature mutation denied',format('select pg_temp.bm(''features.configure'',%L)',jsonb_build_object('organization_id',pg_temp.f('other-org'),'features',jsonb_build_object('wallet',true))));
reset role;
update public.organization_modules set ends_at=clock_timestamp()-interval'1 second'where organization_id=pg_temp.f('org')and module_id in(select id from public.modules where key='boss_bucks');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.denied('expired module configuration replay denied',format('select pg_temp.bm(''features.configure'',%L,%L)',jsonb_build_object('organization_id',pg_temp.f('org'),'features',jsonb_build_object('wallet',true,'family_wallet',true)),pg_temp.f('features-request')));reset role;
select count(*)passed_assertions,'Phase 7B operations' suite from phase5a_assertions;rollback;
