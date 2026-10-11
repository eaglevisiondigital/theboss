\set ON_ERROR_STOP on
begin;
\ir grouped/fixture.sql
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','percentage','basis_points',5000,'currency','USD','channels',jsonb_build_array('money_board')));
reset role;
select pg_temp.group_checkout('money-only','card',array[3,4]);
select boss_private.rails_dispatch(pg_temp.f('checkout-money-only'));
select pg_temp.receive('money-only','captured');
select pg_temp.check('grouped Money Board-only Wallet policy earns','CHANNEL',
 (select count(*)=1 and sum(amount_minor)=350 from public.boss_bucks_grants where evidence_id=pg_temp.group_evidence('money-only')));
select count(*) passed_assertions,'Wallet channel defect regression' suite from pg_temp.phase5a_assertions;
rollback;
