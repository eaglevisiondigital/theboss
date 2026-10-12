\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/fixture.sql
select pg_temp.charge('example-500','org','child1','USD',50000);
select pg_temp.charge('example-100','org','child1','USD',10000);
select pg_temp.charge('example-selected','org','child1','USD',50000);
select pg_temp.success('example-first',30000);
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.bm('payment.spend',pg_temp.spend_input(15000,'example-500'));reset role;
select pg_temp.check('500 charge 150 Bucks leaves 350 due and zero wallet','EXAMPLE',boss_private.registration_charge_balance(pg_temp.f('charge-example-500'))->>'balance_due_minor'='35000'and boss_private.bucks_available(pg_temp.w())=0);
select pg_temp.success('example-full',30000);
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.bm('payment.spend',pg_temp.spend_input(10000,'example-100'));reset role;
select pg_temp.check('100 charge fully paid from 150 wallet leaves 50','FULL',boss_private.registration_charge_balance(pg_temp.f('charge-example-100'))->>'payment_status'='paid'and boss_private.bucks_available(pg_temp.w())=5000);
select pg_temp.success('example-selected',50000);
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.bm('payment.spend',pg_temp.spend_input(12500,'example-selected'));reset role;
select pg_temp.check('family chooses 125 of 300 available toward 500 charge','PARTIAL',boss_private.registration_charge_balance(pg_temp.f('charge-example-selected'))->>'balance_due_minor'='37500'and boss_private.bucks_available(pg_temp.w())=17500);
set local role authenticated;select pg_temp.actor('admin');
select public.boss_registration_mutate(pg_temp.f('split-cash'),jsonb_build_object('operation','payment.record_offline','input',jsonb_build_object('organization_id',pg_temp.f('org'),'method','cash','amount_minor',10000,'currency','USD','payer_person_id',pg_temp.f('parent'),'received_at',now(),'allocations',jsonb_build_array(jsonb_build_object('charge_id',pg_temp.f('charge-example-500'),'amount_minor',10000)))));
select public.boss_registration_mutate(pg_temp.f('split-check'),jsonb_build_object('operation','payment.record_offline','input',jsonb_build_object('organization_id',pg_temp.f('org'),'method','check','reference','SYNTHETIC-CHECK','amount_minor',25000,'currency','USD','payer_person_id',pg_temp.f('parent'),'received_at',now(),'allocations',jsonb_build_array(jsonb_build_object('charge_id',pg_temp.f('charge-example-500'),'amount_minor',25000)))));
select public.boss_registration_mutate(pg_temp.f('cash-first'),jsonb_build_object('operation','payment.record_offline','input',jsonb_build_object('organization_id',pg_temp.f('org'),'method','cash','amount_minor',3000,'currency','USD','payer_person_id',pg_temp.f('parent'),'received_at',now(),'allocations',jsonb_build_array(jsonb_build_object('charge_id',pg_temp.f('charge-gear'),'amount_minor',3000)))));
reset role;
select pg_temp.check('150 Bucks 100 cash 250 check are three identifiable tenders','SPLIT',(select count(*)=3 and count(distinct p.method)=3 and sum(a.amount_minor)=50000 from public.payment_allocations a join public.payments p on p.id=a.payment_id where a.charge_id=pg_temp.f('charge-example-500'))and boss_private.registration_charge_balance(pg_temp.f('charge-example-500'))->>'payment_status'='paid');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.bm('payment.spend',pg_temp.spend_input(5000,'gear'));reset role;
select pg_temp.check('cash-first allocation is respected by later Bucks','SPLIT',boss_private.registration_charge_balance(pg_temp.f('charge-gear'))->>'balance_due_minor'='2000'and boss_private.bucks_available(pg_temp.w())=12500);
set local role authenticated;select pg_temp.actor('admin');
select public.boss_registration_mutate(pg_temp.f('credit-adjustment'),jsonb_build_object('operation','charge.adjust','input',jsonb_build_object('charge_id',pg_temp.f('charge-church'),'amount_minor',-1000,'adjustment_type','credit','reason','Synthetic approved credit')));
reset role;
-- The existing coupon execution path appends this same immutable canonical
-- adjustment; its native operation stays covered by the historical 3B suite.
insert into public.charge_adjustments(organization_id,charge_id,amount_minor,adjustment_type,reason,recorded_by_person_id)
 values(pg_temp.f('org'),pg_temp.f('charge-church'),-1000,'coupon','Synthetic coupon ledger evidence',pg_temp.f('admin'));
set local role authenticated;select pg_temp.actor('admin');
select public.boss_registration_mutate(pg_temp.f('plan'),jsonb_build_object('operation','payment_plan.create','input',jsonb_build_object('charge_id',pg_temp.f('charge-church'),'title','Synthetic two-payment plan','installments',jsonb_build_array(jsonb_build_object('amount_minor',4000,'due_on',current_date+7),jsonb_build_object('amount_minor',4000,'due_on',current_date+14)))));
select pg_temp.actor('parent');
select pg_temp.check('preview uses adjusted obligation','ADJUSTMENT',public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w(),'charge_id',pg_temp.f('charge-church')))->'charges'->0->>'eligible_minor'='8000');
select pg_temp.bm('payment.spend',pg_temp.spend_input(3000,'church'));reset role;
select pg_temp.check('Bucks apply to current payment-plan obligation','PLAN',boss_private.registration_charge_balance(pg_temp.f('charge-church'))->>'balance_due_minor'='5000');
select pg_temp.check('immutable installment schedule is not rewritten','PLAN',(select sum(amount_minor)=8000 and count(*)=2 from public.payment_installments where charge_id=pg_temp.f('charge-church')));
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('receipt history retains balance at original commitment','RECEIPT',(select entry->'charges'->0->>'remaining_minor'='35000'from jsonb_array_elements(public.boss_bucks_read(jsonb_build_object('wallet_id',pg_temp.w()))->'payments')entry where entry->'charges'->0->>'charge_id'=pg_temp.f('charge-example-500')::text));
reset role;set constraints all immediate;
select pg_temp.check('only true canonical allocations derive charge paid state','REBUILD',not exists(select 1 from public.payments where method not in('cash','check','boss_bucks'))and boss_private.bucks_available(pg_temp.w())=9500);
select count(*)passed_assertions,'Phase 7C checkout/split/plans' suite from phase5a_assertions;rollback;
