\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/fixture.sql
select pg_temp.success('spent-source',10000);
set local role authenticated;select pg_temp.actor('parent');
insert into payment_results values('spend',pg_temp.bm('payment.spend',pg_temp.spend_input(4000)));
reset role;set constraints all immediate;set constraints all deferred;
select boss_private.bucks_reverse_source((select id from public.fundraising_success_evidence where source_reference='spent-source'),'Synthetic full source invalidation');
set constraints all immediate;set constraints all deferred;
select pg_temp.check('unspent removed without negative wallet','SOURCE',boss_private.bucks_available(pg_temp.w())=0);
select pg_temp.check('spent shortfall is explicit own-org claim','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=4000);
select pg_temp.check('historical charge allocation survives source invalidation','CHARGE',boss_private.registration_charge_balance(pg_temp.f('charge-camp'))->>'balance_due_minor'='6000');
select pg_temp.check('recovery is separate from spendable account','LEDGER',(select sum(p.amount_minor)=-4000 from public.boss_bucks_postings p join public.boss_bucks_accounts a on a.id=p.account_id where a.kind='recovery')and(select sum(p.amount_minor)=0 from public.boss_bucks_postings p join public.boss_bucks_accounts a on a.id=p.account_id where a.kind='household'));
select boss_private.bucks_reverse_source((select id from public.fundraising_success_evidence where source_reference='spent-source'),'Synthetic repeated full source invalidation');
select pg_temp.check('full invalidation replay does not duplicate recovery','IDEMPOTENCY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=4000 and(select count(*)=1 from public.boss_bucks_recovery_movements));
select pg_temp.success('replacement-one',6000);
set constraints all immediate;set constraints all deferred;
select pg_temp.check('new valid grant fully preserves earning provenance','PROVENANCE',exists(select 1 from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='replacement-one'and g.amount_minor=3000));
select pg_temp.check('new earning satisfies deficit first','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=1000 and boss_private.bucks_available(pg_temp.w())=0);
select pg_temp.check('recovery reprocessing is idempotent','IDEMPOTENCY',boss_private.bucks_recover_grant((select g.id from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='replacement-one'))=0);
select pg_temp.success('replacement-two',4000);
set constraints all immediate;set constraints all deferred;
select pg_temp.check('only earning excess becomes available','RECOVERY',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0 and boss_private.bucks_available(pg_temp.w())=1000);
select pg_temp.check('recovery rebuild follows ledger','REBUILD',(select sum(p.amount_minor)=0 from public.boss_bucks_postings p join public.boss_bucks_accounts a on a.id=p.account_id where a.kind='recovery')and boss_private.bucks_grant_book((select g.id from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='replacement-two'))=1000);
select boss_private.bucks_reverse_source((select id from public.fundraising_success_evidence where source_reference='replacement-one'),'Synthetic replacement source invalidation');
set constraints all immediate;set constraints all deferred;
select pg_temp.check('replacement invalidation retains dependency and new recovery','CASCADE',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=3000 and boss_private.bucks_available(pg_temp.w())=1000);
select pg_temp.check('previously valid existing earning not retroactively confiscated','RECOVERY',boss_private.bucks_available(pg_temp.w())=1000);
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','percentage','basis_points',3333,'currency','USD','channels',jsonb_build_array('direct_support')));reset role;
select pg_temp.success('rounding-source',101);
-- This new 33-unit earning is fully applied to the older deficit. Successive
-- partial corrections therefore append claims without rounding each refund.
select boss_private.bucks_correct_source((select g.id from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='rounding-source'),100,'partial-1');
select pg_temp.check('first partial refund retains floor entitlement','ROUNDING',(select boss_private.bucks_entitlement(g.id)=33 from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='rounding-source'));
select boss_private.bucks_correct_source((select g.id from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='rounding-source'),99,'partial-2');
select pg_temp.check('cumulative refund crosses floor boundary once','ROUNDING',(select boss_private.bucks_entitlement(g.id)=32 from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='rounding-source'));
select boss_private.bucks_correct_source((select g.id from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='rounding-source'),98,'partial-3');
select pg_temp.check('next refund does not round independently','ROUNDING',(select boss_private.bucks_entitlement(g.id)=32 from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='rounding-source'));
select pg_temp.check('rounding loss is exact cumulative one unit','ROUNDING',(select sum(m.amount_minor)=1 from public.boss_bucks_recovery_movements m join public.boss_bucks_recovery_claims c on c.id=m.claim_id join public.boss_bucks_grants g on g.id=c.grant_id join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='rounding-source'and m.kind='open'));
select pg_temp.denied('remaining authoritative source may not increase',format('select boss_private.bucks_correct_source(%L,99,''increase'')',(select g.id from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='rounding-source')),'PT422');
select pg_temp.conflict('changed correction replay rejected',format('select boss_private.bucks_correct_source(%L,97,''partial-3'')',(select g.id from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='rounding-source')));
select pg_temp.denied('partial canonical source event needs authoritative amount',format('insert into public.fundraising_intent_events(intent_id,state,source_reference)values(%L,''partially_refunded'',''synthetic-partial-no-amount'')',(select intent_id from public.fundraising_success_evidence where source_reference='rounding-source')),'PT422');
select pg_temp.check('no fake external payment or settlement','BOUNDARY',not exists(select 1 from public.payments where method not in('cash','check','boss_bucks')));
select pg_temp.check('all recovery journals balanced','LEDGER',not exists(select journal_id from public.boss_bucks_postings group by journal_id having count(*)<>2 or sum(amount_minor)<>0));
set constraints all immediate;
select count(*)passed_assertions,'Phase 7C recovery' suite from phase5a_assertions;rollback;
