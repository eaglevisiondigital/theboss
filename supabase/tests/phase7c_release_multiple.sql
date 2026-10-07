\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/recovery-release-fixture.sql
select pg_temp.success('replacement-B',3000);select pg_temp.success('replacement-C',5000);
set local role authenticated;select pg_temp.actor('admin');insert into payment_results values('partial',pg_temp.bm('payment.reverse',pg_temp.return_input(6000),pg_temp.f('request-partial')));reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('most recent C satisfaction unwound first','ORDER',boss_private.bucks_grant_book(pg_temp.source_grant('replacement-C'))=5000 and boss_private.bucks_grant_book(pg_temp.source_grant('replacement-B'))=1000);
select pg_temp.check('partial unwind retains $20 of earlier B satisfaction','LINEAGE',boss_private.bucks_net_use(pg_temp.source_grant('replacement-B'))=2000 and boss_private.bucks_available(pg_temp.w())=6000);
select pg_temp.check('exact recorded applications linked to release','LINEAGE',(select count(*)=2 and sum(amount_minor)=6000 from public.boss_bucks_recovery_movements where kind='release'));
set local role authenticated;select pg_temp.actor('admin');insert into payment_results values('remaining',pg_temp.bm('payment.reverse',pg_temp.return_input(2000),pg_temp.f('request-remaining')));reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('full multiple-grant unwind returns actual B and C without duplication','RELEASE',boss_private.bucks_grant_book(pg_temp.source_grant('replacement-B'))=3000 and boss_private.bucks_grant_book(pg_temp.source_grant('replacement-C'))=5000 and boss_private.bucks_available(pg_temp.w())=8000);

set constraints all immediate;
select pg_temp.verify_release();
select count(*)passed_assertions,'Phase 7C recovery release multiple' suite from phase5a_assertions;rollback;
