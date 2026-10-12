\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir grouped/fixture.sql
select pg_temp.actor('admin');
select pg_temp.fm('board.configure',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',3,'title','Synthetic exact remainder boundary','goal_minor',1000000000,'start_minor',250000001,'increment_minor',499999997,'tile_count',2,'reservation_seconds',600,'visibility','public'));
select pg_temp.fm('board.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',4));
select set_config('request.jwt.claims','{}',true);
select pg_temp.group_checkout('near-remainder','card',array[1,2]);
select boss_private.rails_dispatch(pg_temp.f('checkout-near-remainder'));select pg_temp.receive('near-remainder','captured');
-- Exact common-denominator remainders differ by just one: 499999999 vs
-- 500000000. Numeric division can round both fractions to 0.50000000 at
-- this allowed principal, falsely invoking the ordinal tie-break.
select pg_temp.check('one-cent remainder difference is not an ordinal tie','ROUNDING',(select array_agg(amount_minor order by tie_order)=array[150000000,449999999]::bigint[] from boss_private.money_board_allocate_correction(pg_temp.group_evidence('near-remainder'),599999999)));
select pg_temp.refund_group('near-remainder',599999999);
select pg_temp.check('trusted correction preserves exact mathematical ordering','ROUNDING',(select array_agg(r.amount_minor order by t.ordinal)=array[150000000,449999999]::bigint[]from public.money_board_tile_corrections r join public.money_board_tiles t on t.id=r.tile_id));
select pg_temp.check('near-boundary correction every cent reconciles','ROUNDING',(select sum(amount_minor)=599999999 from public.money_board_tile_corrections));
select pg_temp.refund_group('near-remainder',400000000);
select pg_temp.check('subsequent caps consume exact remaining source without reopening','ROUNDING',(select sum(amount_minor)=999999999 from public.money_board_tile_corrections)and not boss_private.money_board_tile_available(pg_temp.tile(1))and not boss_private.money_board_tile_available(pg_temp.tile(2)));
set constraints all immediate;
select count(*)passed_assertions,'Grouped exact integer Hamilton near-remainder boundary' suite from pg_temp.phase5a_assertions;
rollback;
