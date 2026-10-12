\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7c/recovery-release-fixture.sql
set local role authenticated;select pg_temp.actor('admin');select pg_temp.bm('policy.create',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'mode','percentage','basis_points',10000,'currency','USD','channels',jsonb_build_array('direct_support'),'expiry_seconds',1));reset role;
select pg_temp.success('replacement-B',8000);select pg_sleep(1.1);
set local role authenticated;select pg_temp.actor('admin');insert into payment_results values('return',pg_temp.bm('payment.reverse',pg_temp.return_input(8000),pg_temp.f('request-return')));reset role;set constraints all immediate;set constraints all deferred;
select pg_temp.check('expired replacement satisfaction fully unwound','LINEAGE',boss_private.bucks_net_use(pg_temp.source_grant('replacement-B'))=0 and(select sum(amount_minor)=8000 from public.boss_bucks_recovery_movements where kind='release'));
select pg_temp.check('expired replacement remains unavailable and expiration unchanged','EXPIRY',boss_private.bucks_grant_book(pg_temp.source_grant('replacement-B'))=0 and boss_private.bucks_available(pg_temp.w())=0 and(select expires_at<=clock_timestamp()from public.boss_bucks_grants where id=pg_temp.source_grant('replacement-B')));
select pg_temp.check('release retains expiration journal under original grant','EXPIRY',exists(select 1 from public.boss_bucks_journals where grant_id=pg_temp.source_grant('replacement-B')and kind='expiration'and amount_minor=8000));

set constraints all immediate;
select pg_temp.verify_release();
select count(*)passed_assertions,'Phase 7C recovery release expiration' suite from phase5a_assertions;rollback;
