\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/fixture.sql
select pg_temp.success('original',6000);
create function pg_temp.reverse_input(label text,amount bigint)returns jsonb language sql as $$
 select jsonb_build_object('payment_id',result->'receipt'->>'payment_id','reason','Synthetic authorized correction','allocations',jsonb_build_array(jsonb_build_object('allocation_id',
 (select id from public.payment_allocations where payment_id=(result->'receipt'->>'payment_id')::uuid order by id limit 1),'amount_minor',amount)))from payment_results where payment_results.label=$1
$$;
-- Actor-side input is saved while owner constructs the exact reviewed allocation
-- reference; ordinary raw table access remains denied under authenticated role.
create temp table reversal_inputs(label text primary key,input jsonb);grant all on reversal_inputs to authenticated;
set local role authenticated;select pg_temp.actor('parent');
insert into payment_results values('valid',pg_temp.bm('payment.spend',pg_temp.spend_input(1500)));reset role;
insert into reversal_inputs values('valid-500',pg_temp.reverse_input('valid',500)),('valid-1000',pg_temp.reverse_input('valid',1000));
-- Remove only the reversal capability in this rollback-only fixture. Existing
-- reporting permissions remain: read authority cannot authorize a money return.
delete from public.role_permissions where role_id=(select id from public.roles where key='organization_administrator')and permission_id=(select id from public.permissions where key='boss_bucks.payment_reverse');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.check('financial reporting cannot create payment reversal authority','AUTH',public.boss_bucks_read(jsonb_build_object('mode','organization','organization_id',pg_temp.f('org')))->>'can_reverse_payment'='false');
select pg_temp.denied('financial reader cannot return value',format('select pg_temp.bm(''payment.reverse'',%L)',(select input from reversal_inputs where label='valid-500')));
reset role;
insert into public.role_permissions(role_id,permission_id)select r.id,p.id from public.roles r cross join public.permissions p where r.key='organization_administrator'and p.key='boss_bucks.payment_reverse';
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.denied('ordinary family cannot reverse committed payment',format('select pg_temp.bm(''payment.reverse'',%L)',(select input from reversal_inputs where label='valid-500')));
select pg_temp.actor('other-admin');select pg_temp.denied('unrelated org cannot reverse payment',format('select pg_temp.bm(''payment.reverse'',%L)',(select input from reversal_inputs where label='valid-500')));
select pg_temp.actor('admin');
select pg_temp.denied('forged original payment denied',format('select pg_temp.bm(''payment.reverse'',%L)',(select input||jsonb_build_object('payment_id',pg_temp.f('missing-payment'))from reversal_inputs where label='valid-500')));
select pg_temp.denied('forged original allocation denied',format('select pg_temp.bm(''payment.reverse'',%L)',(select input||jsonb_build_object('allocations',jsonb_build_array(jsonb_build_object('allocation_id',pg_temp.f('missing-allocation'),'amount_minor',500)))from reversal_inputs where label='valid-500')));
insert into payment_results values('returned-500',pg_temp.bm('payment.reverse',(select input from reversal_inputs where label='valid-500'),pg_temp.f('valid-return-500')));
select pg_temp.check('payment reversal replay uses original result','IDEMPOTENCY',pg_temp.bm('payment.reverse',(select input from reversal_inputs where label='valid-500'),pg_temp.f('valid-return-500'))->>'replayed'='true');reset role;
set constraints all immediate;set constraints all deferred;
select pg_temp.check('partial return restores charge and original grant','RESTORE',boss_private.bucks_available(pg_temp.w())=2000 and boss_private.registration_charge_balance(pg_temp.f('charge-camp'))->>'balance_due_minor'='9000');
select pg_temp.check('reversal retains original immutable payment','HISTORY',(select count(*)=1 from public.payments where status='recorded')and(select count(*)=1 from public.payments where status='reversed')and(select count(*)=1 from public.boss_bucks_grants));
select pg_temp.check('restoration lineage names original consumed grant','LINEAGE',not exists(select 1 from public.boss_bucks_restorations r join public.boss_bucks_consumptions c on c.id=r.consumption_id join public.boss_bucks_journals j on j.id=r.journal_id where j.grant_id<>c.grant_id));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.bm('payment.reverse',(select input from reversal_inputs where label='valid-1000'));reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('remaining return restores full original value','RESTORE',boss_private.bucks_available(pg_temp.w())=3000 and boss_private.registration_charge_balance(pg_temp.f('charge-camp'))->>'balance_due_minor'='10000');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.conflict('already fully returned payment cannot return more',format('select pg_temp.bm(''payment.reverse'',%L)',(select input from reversal_inputs where label='valid-500')));
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','percentage','basis_points',10000,'currency','USD','channels',jsonb_build_array('direct_support'),'expiry_seconds',3600));reset role;
select pg_temp.success('invalid',1000);
set local role authenticated;select pg_temp.actor('parent');insert into payment_results values('invalid',pg_temp.bm('payment.spend',pg_temp.spend_input(800)));reset role;
select boss_private.bucks_reverse_source((select id from public.fundraising_success_evidence where source_reference='invalid'),'Synthetic source invalidation');
insert into reversal_inputs values('invalid-800',pg_temp.reverse_input('invalid',800));
set local role authenticated;select pg_temp.actor('admin');select pg_temp.bm('payment.reverse',(select input from reversal_inputs where label='invalid-800'));reset role;
set constraints all immediate;set constraints all deferred;
select pg_temp.check('invalid source return cancels only outstanding recovery','INVALID',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0 and boss_private.bucks_available(pg_temp.w())=3000);
select pg_temp.check('invalid source is not resurrected as available','INVALID',(select boss_private.bucks_grant_book(g.id)=0 and boss_private.bucks_entitlement(g.id)=0 from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='invalid'));
select pg_temp.success('partial-invalid',1000);
set local role authenticated;select pg_temp.actor('parent');insert into payment_results values('partial-invalid',pg_temp.bm('payment.spend',pg_temp.spend_input(800)));reset role;
select boss_private.bucks_correct_source((select g.id from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='partial-invalid'),500,'synthetic-partial');
insert into reversal_inputs values('partial-400',pg_temp.reverse_input('partial-invalid',400));
set local role authenticated;select pg_temp.actor('admin');select pg_temp.bm('payment.reverse',(select input from reversal_inputs where label='partial-400'));reset role;
set constraints all immediate;set constraints all deferred;
select pg_temp.check('partial invalid return cancels deficit then restores valid residual','PARTIAL',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0 and boss_private.bucks_available(pg_temp.w())=3100);
select pg_temp.check('partial invalid return respects current source entitlement','PARTIAL',(select boss_private.bucks_net_use(g.id)=400 and boss_private.bucks_entitlement(g.id)=500 and boss_private.bucks_grant_book(g.id)=100 from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='partial-invalid'));
-- Remove the valid partial-source residue by a legitimate spend so the later
-- expiring grant is the sole FEFO source for the expiration-specific payment.
set local role authenticated;select pg_temp.actor('parent');select pg_temp.bm('payment.spend',pg_temp.spend_input(100,'gear'));select pg_temp.actor('admin');
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','percentage','basis_points',10000,'currency','USD','channels',jsonb_build_array('direct_support'),'expiry_seconds',1));reset role;
select pg_temp.success('expired',5000);
set local role authenticated;select pg_temp.actor('parent');insert into payment_results values('expired',pg_temp.bm('payment.spend',pg_temp.spend_input(1500,'travel')));reset role;
insert into reversal_inputs values('expired-500',pg_temp.reverse_input('expired',500));select pg_sleep(1.05);
set local role authenticated;select pg_temp.actor('admin');select pg_temp.bm('payment.reverse',(select input from reversal_inputs where label='expired-500'));reset role;
set constraints all immediate;set constraints all deferred;
select pg_temp.check('expired source return cannot become newly spendable','EXPIRY',boss_private.bucks_available(pg_temp.w())=3000 and(select boss_private.bucks_grant_book(g.id)=0 from public.boss_bucks_grants g join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='expired'));
select pg_temp.check('expired return retains original expiration and balanced history','EXPIRY',exists(select 1 from public.boss_bucks_restorations r join public.boss_bucks_consumptions c on c.id=r.consumption_id join public.boss_bucks_grants g on g.id=c.grant_id join public.fundraising_success_evidence e on e.id=g.evidence_id where e.source_reference='expired')and not exists(select journal_id from public.boss_bucks_postings group by journal_id having sum(amount_minor)<>0));
-- Binding financial decision returns covered recovery to its actual replacement.
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','percentage','basis_points',10000,'currency','USD','channels',jsonb_build_array('direct_support'),'expiry_seconds',3600));reset role;
select pg_temp.success('covered-original',1000);
set local role authenticated;select pg_temp.actor('parent');insert into payment_results values('covered',pg_temp.bm('payment.spend',pg_temp.spend_input(800,'church')));reset role;
select boss_private.bucks_reverse_source((select id from public.fundraising_success_evidence where source_reference='covered-original'),'Synthetic source invalidation');select pg_temp.success('covered-replacement',1000);
insert into reversal_inputs values('covered-800',pg_temp.reverse_input('covered',800));
set local role authenticated;select pg_temp.actor('admin');select pg_temp.bm('payment.reverse',(select input from reversal_inputs where label='covered-800'));reset role;
set constraints all immediate;
select pg_temp.check('covered recovery returns valid replacement without reviving original','RELEASE',boss_private.bucks_recovery_due(pg_temp.w(),pg_temp.f('org'))=0 and boss_private.bucks_available(pg_temp.w())=4000 and boss_private.registration_charge_balance(pg_temp.f('charge-church'))->>'balance_due_minor'='10000');
select count(*)passed_assertions,'Phase 7C payment reversals' suite from phase5a_assertions;rollback;
