\set ON_ERROR_STOP on
begin;
\ir grouped/fixture.sql
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.denied('organization administrator cannot zero platform share',format(
 'select public.boss_payments_mutate(%L::jsonb)',jsonb_build_object('action','policy.create','request_id',gen_random_uuid(),'input',jsonb_build_object('organization_id',pg_temp.f('org'),'purpose','fundraising','currency','USD','organization_basis_points',10000,'platform_basis_points',0,'product_cost_basis_points',0,'processor_fee_owner','platform','availability_seconds',0))));
reset role;
select count(*) passed_assertions,'Platform revenue defect regression' suite from pg_temp.phase5a_assertions;
rollback;
