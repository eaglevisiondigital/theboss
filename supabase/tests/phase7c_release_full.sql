\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/recovery-release-fixture.sql
select pg_temp.success('replacement-B',8000);
set constraints all immediate;set constraints all deferred;
select pg_temp.check('exact replacement $80 satisfies recovery','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0 and boss_private.bucks_available(pg_temp.w())=0 and boss_private.bucks_net_use(pg_temp.source_grant('replacement-B'))=8000);
set local role authenticated;select pg_temp.actor('admin');insert into payment_results values('return',pg_temp.bm('payment.reverse',pg_temp.return_input(8000),pg_temp.f('request-return')));reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('full payment return releases valid replacement $80','RELEASE',boss_private.bucks_available(pg_temp.w())=8000 and boss_private.bucks_grant_book(pg_temp.source_grant('replacement-B'))=8000 and boss_private.bucks_net_use(pg_temp.source_grant('replacement-B'))=0);
select pg_temp.check('recovery exposure and outstanding are both zero','RECOVERY',(select sum(case kind when 'open' then amount_minor when 'cancel' then -amount_minor else 0 end)=0 from public.boss_bucks_recovery_movements where claim_id=(select claim_id from release_case))and boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0);
select pg_temp.check('charge becomes unpaid under canonical reversal','CHARGE',boss_private.registration_charge_balance(pg_temp.f('charge-camp'))->>'balance_due_minor'='10000');
select pg_temp.check('no generic grant minted','LINEAGE',(select count(*)=2 from public.boss_bucks_grants));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.check('duplicate full return replay does not release twice','IDEMPOTENCY',pg_temp.bm('payment.reverse',pg_temp.return_input(8000),pg_temp.f('request-return'))->>'replayed'='true');
select pg_temp.conflict('new request cannot return already returned payment',format('select pg_temp.bm(''payment.reverse'',%L)',pg_temp.return_input(8000)));reset role;
create function pg_temp.over_release()returns void language plpgsql as $$declare a public.boss_bucks_recovery_movements;j uuid;begin
 select *into a from public.boss_bucks_recovery_movements where kind='apply'limit 1;
 j:=boss_private.bucks_pair(a.replacement_grant_id,'recovery_release',1,'Synthetic over-release');
 insert into public.boss_bucks_recovery_movements(claim_id,kind,amount_minor,replacement_grant_id,journal_id,payment_reversal_id,original_movement_id)
 values(a.claim_id,'release',1,a.replacement_grant_id,j,(select(result->'receipt'->>'payment_id')::uuid from payment_results where label='return'),a.id);set constraints all immediate;
end$$;
select pg_temp.denied('owner forged over-release cannot commit','select pg_temp.over_release()','23514');
select pg_temp.check('failed forged release preserves exact wallet','ATOMICITY',boss_private.bucks_available(pg_temp.w())=8000);

set constraints all immediate;
select pg_temp.verify_release();
select count(*)passed_assertions,'Phase 7C recovery release full' suite from phase5a_assertions;rollback;
