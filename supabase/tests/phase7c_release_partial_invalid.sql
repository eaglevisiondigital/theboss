\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/recovery-release-fixture.sql
select pg_temp.success('replacement-B',8000);select boss_private.bucks_correct_source(pg_temp.source_grant('replacement-B'),3000,'Synthetic partial replacement invalidation');
set local role authenticated;select pg_temp.actor('admin');insert into payment_results values('return',pg_temp.bm('payment.reverse',pg_temp.return_input(8000),pg_temp.f('request-return')));reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('only legitimate $30 of partially invalid replacement is available','SOURCE',boss_private.bucks_entitlement(pg_temp.source_grant('replacement-B'))=3000 and boss_private.bucks_grant_book(pg_temp.source_grant('replacement-B'))=3000 and boss_private.bucks_available(pg_temp.w())=3000);
select pg_temp.check('partial replacement invalid exposure canceled without reviving $50','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0 and(select sum(amount_minor)=5000 from public.boss_bucks_recovery_movements where cause_release_id is not null));

set constraints all immediate;
select pg_temp.verify_release();
select count(*)passed_assertions,'Phase 7C recovery release partial_invalid' suite from phase5a_assertions;rollback;
