\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir global/fixture.sql
create temp table selected_recovery_baseline as select to_jsonb(a)-'updated_at' row_value from public.role_assignments a where person_id=pg_temp.f('director')and scope_type='platform';
create temp table recovery_module_baseline as select id,to_jsonb(m)row_value from public.organization_modules m where organization_id=pg_temp.f('org');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.am('delegation.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'person_id',pg_temp.f('coach'),'team_id',pg_temp.f('falcons'),'starts_at',clock_timestamp()-interval'1 minute','ends_at',clock_timestamp()+interval'5 minutes'),'recovery-delegation');
reset role;
select pg_temp.check('rehearsal grant initially exact and effective','RECOVERY',boss_private.fundraising_allocation_manage(pg_temp.f('coach'),pg_temp.fid('campaign'),pg_temp.f('falcons'))and not boss_private.fundraising_allocation_manage(pg_temp.f('coach'),pg_temp.fid('campaign'),pg_temp.f('wildcats')));
update public.role_assignments set status='inactive'where person_id=pg_temp.f('director')and scope_type='platform';
select pg_temp.check('synthetic platform pause is effective','RECOVERY',not boss_private.fundraising_platform_actor(pg_temp.f('director')));
-- Independent recovery connection is represented by the disposable owner role.
-- Administrator restoration is the first recovery write, before ending other grants.
update public.role_assignments a set status=b.row_value->>'status'from selected_recovery_baseline b where a.id=(b.row_value->>'id')::uuid;
select pg_temp.check('administrator restored FIRST','RECOVERY',boss_private.fundraising_platform_actor(pg_temp.f('director')));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.am('delegation.revoke',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'delegation_id',(select(data->>'id')::uuid from group_results where label='recovery-delegation')));
reset role;
select pg_temp.check('temporary exact delegate no longer effective','RECOVERY',not boss_private.fundraising_allocation_manage(pg_temp.f('coach'),pg_temp.fid('campaign'),pg_temp.f('falcons')));
select pg_temp.check('immutable ended grant retained as audit history','RECOVERY',(select count(*)=1 and bool_and(revoked_at is not null)from public.fundraising_allocation_delegations));
select pg_temp.check('no residual temporary authority','RECOVERY',not exists(select 1 from public.fundraising_allocation_delegations where revoked_at is null and starts_at<=clock_timestamp()and ends_at>clock_timestamp()));
select pg_temp.check('administrator row equals original selected baseline','RECOVERY',not exists(select 1 from selected_recovery_baseline b join public.role_assignments a on a.id=(b.row_value->>'id')::uuid where to_jsonb(a)-'updated_at'<>b.row_value));
select pg_temp.check('module baseline equal','RECOVERY',not exists(select 1 from recovery_module_baseline b join public.organization_modules m on m.id=b.id where to_jsonb(m)<>b.row_value));
select pg_temp.check('activation and explicit ending both audited','AUDIT',(select count(*)=2 from public.fundraising_history where action in('fundraising.delegation.create','fundraising.delegation.revoke')));
set constraints all immediate;
select count(*)passed_assertions,'Independent administrator-first recovery rehearsal' suite from phase5a_assertions;rollback;
