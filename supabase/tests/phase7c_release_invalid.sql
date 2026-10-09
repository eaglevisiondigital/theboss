\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/recovery-release-fixture.sql
select pg_temp.success('replacement-B',8000);select boss_private.bucks_reverse_source((select id from public.fundraising_success_evidence where source_reference='replacement-B'),'Synthetic replacement invalidation');
select pg_temp.check('replacement invalidation creates its own $80 recovery','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=8000);
set local role authenticated;select pg_temp.actor('admin');insert into payment_results values('return',pg_temp.bm('payment.reverse',pg_temp.return_input(8000),pg_temp.f('request-return')));reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('invalid replacement remains unavailable after original return','SOURCE',boss_private.bucks_entitlement(pg_temp.source_grant('replacement-B'))=0 and boss_private.bucks_grant_book(pg_temp.source_grant('replacement-B'))=0 and boss_private.bucks_available(pg_temp.w())=0);
select pg_temp.check('dependent invalid replacement recovery canceled exactly','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0 and boss_private.bucks_net_use(pg_temp.source_grant('replacement-B'))=0);
select pg_temp.check('dependent cancellation has immutable release and removal-journal cause','LINEAGE',exists(select 1 from public.boss_bucks_recovery_movements m join public.boss_bucks_recovery_movements r on r.id=m.cause_release_id join public.boss_bucks_journals j on j.id=m.invalid_release_journal_id where m.kind='cancel'and m.amount_minor=8000 and r.replacement_grant_id=pg_temp.source_grant('replacement-B')and j.grant_id=r.replacement_grant_id and j.kind='reversal'and j.amount_minor=m.amount_minor));

set constraints all immediate;
select pg_temp.verify_release();
select count(*)passed_assertions,'Phase 7C recovery release invalid' suite from phase5a_assertions;rollback;
