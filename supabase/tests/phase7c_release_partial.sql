\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/recovery-release-fixture.sql
select pg_temp.success('replacement-B',8000);
set local role authenticated;select pg_temp.actor('admin');insert into payment_results values('partial',pg_temp.bm('payment.reverse',pg_temp.return_input(3000),pg_temp.f('request-partial')));reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('$30 partial return releases exactly $30','RELEASE',boss_private.bucks_available(pg_temp.w())=3000 and boss_private.bucks_grant_book(pg_temp.source_grant('replacement-B'))=3000);
select pg_temp.check('$50 remains applied to recovery with zero outstanding','RECOVERY',boss_private.bucks_net_use(pg_temp.source_grant('replacement-B'))=5000 and boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0 and(select sum(case kind when 'open' then amount_minor when 'cancel' then -amount_minor else 0 end)=5000 from public.boss_bucks_recovery_movements where claim_id=(select claim_id from release_case)));
select pg_temp.check('partial return changes charge by only $30','CHARGE',boss_private.registration_charge_balance(pg_temp.f('charge-camp'))->>'balance_due_minor'='5000');
create function pg_temp.unpaired_release()returns void language plpgsql as $$declare a public.boss_bucks_recovery_movements;j uuid;begin
 select *into a from public.boss_bucks_recovery_movements where kind='apply'limit 1;
 j:=boss_private.bucks_pair(a.replacement_grant_id,'recovery_release',1,'Synthetic unpaired release');
 insert into public.boss_bucks_recovery_movements(claim_id,kind,amount_minor,replacement_grant_id,journal_id,payment_reversal_id,original_movement_id)
 values(a.claim_id,'release',1,a.replacement_grant_id,j,(select(result->'receipt'->>'payment_id')::uuid from payment_results where label='partial'),a.id);set constraints all immediate;
end$$;
select pg_temp.denied('release without corresponding liability cancellation cannot commit','select pg_temp.unpaired_release()','23514');
select pg_temp.check('unpaired release rolls back wallet and claim effects','ATOMICITY',boss_private.bucks_available(pg_temp.w())=3000 and boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0);
set local role authenticated;select pg_temp.actor('admin');insert into payment_results values('remaining',pg_temp.bm('payment.reverse',pg_temp.return_input(5000),pg_temp.f('request-remaining')));reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('subsequent return releases only remaining $50','RELEASE',boss_private.bucks_available(pg_temp.w())=8000 and(select sum(amount_minor)=8000 from public.boss_bucks_recovery_movements where kind='release'));

set constraints all immediate;
select pg_temp.verify_release();
select count(*)passed_assertions,'Phase 7C recovery release partial' suite from phase5a_assertions;rollback;
