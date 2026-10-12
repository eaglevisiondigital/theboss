\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/recovery-release-fixture.sql
select pg_temp.success('replacement-B',8000);select boss_private.bucks_reverse_source((select id from public.fundraising_success_evidence where source_reference='replacement-B'),'Synthetic B invalidation');
select pg_temp.success('replacement-C',5000);select boss_private.bucks_reverse_source((select id from public.fundraising_success_evidence where source_reference='replacement-C'),'Synthetic C invalidation');
select pg_temp.success('replacement-D',5000);
select pg_temp.check('three-level chain retains $30 outstanding and actual replacement provenance','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=3000 and boss_private.bucks_available(pg_temp.w())=0);
set local role authenticated;select pg_temp.actor('admin');insert into payment_results values('return',pg_temp.bm('payment.reverse',pg_temp.return_input(8000),pg_temp.f('request-return')));reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('dependent covered and outstanding claims both unwind','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0 and(select count(*)=3 from public.boss_bucks_recovery_claims));
select pg_temp.check('only surviving valid D source becomes available','SOURCE',boss_private.bucks_available(pg_temp.w())=5000 and boss_private.bucks_grant_book(pg_temp.source_grant('replacement-D'))=5000 and boss_private.bucks_grant_book(pg_temp.source_grant('replacement-B'))=0 and boss_private.bucks_grant_book(pg_temp.source_grant('replacement-C'))=0);
select pg_temp.check('exact replacement links retained across shared downstream satisfaction','LINEAGE',(select count(*)=4 and sum(amount_minor)=18000 from public.boss_bucks_recovery_movements where kind='release'));
select pg_temp.check('none of the three invalidated sources reactivated','SOURCE',boss_private.bucks_entitlement(pg_temp.source_grant('release-original-A'))=0 and boss_private.bucks_entitlement(pg_temp.source_grant('replacement-B'))=0 and boss_private.bucks_entitlement(pg_temp.source_grant('replacement-C'))=0);

set constraints all immediate;
select pg_temp.verify_release();
select count(*)passed_assertions,'Phase 7C recovery release chain' suite from phase5a_assertions;rollback;
