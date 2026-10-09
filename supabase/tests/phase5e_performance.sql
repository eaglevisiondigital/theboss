-- Bounded complete-detail/append timing on synthetic disposable records.
begin;
\ir phase5e/fixture.sql
set local role authenticated;select pg_temp.actor('admin');select pg_temp.ff_link('performance','internal','falcons','volleyball');
select pg_temp.vv_profile('performance','primary','full');select pg_temp.vv_profile('performance','opponent','score_only');
select pg_temp.game_op('volleyball.configure','performance','{"configuration":{"best_of":3,"normal_target":99,"deciding_target":99,"win_by_two":true,"score_cap":99,"court_size":2,"strict_rotation":false,"enforce_lineup":false,"allow_reentry":true,"libero_enabled":false,"libero_can_serve":false}}');
select pg_temp.game_op('game.start','performance');select pg_temp.game_op('volleyball.set.start','performance','{"side":"primary"}');
create temp table vv_timings(kind text,ms double precision);grant select,insert on vv_timings to authenticated;
do $$declare started timestamptz;i int;result jsonb;begin
 for i in 1..80 loop started:=clock_timestamp();perform pg_temp.vv_add('performance','rally',case when i%2=0 then'opponent'else'primary'end,'{"outcome":"team_point"}');insert into vv_timings values('append',extract(epoch from clock_timestamp()-started)*1000);end loop;
 for i in 1..12 loop started:=clock_timestamp();result:=public.boss_games_read(pg_temp.query('performance'));insert into vv_timings values('detail',extract(epoch from clock_timestamp()-started)*1000);if jsonb_array_length(result->'games'->0->'volleyball'->'plays')<>81 then raise exception 'Incomplete bounded detail performance projection';end if;end loop;
end$$;
reset role;
select pg_temp.check('p95 append below 3 seconds','PERFORMANCE',(select percentile_cont(.95)within group(order by ms)<3000 from vv_timings where kind='append'));
select pg_temp.check('p95 complete detail below 3 seconds','PERFORMANCE',(select percentile_cont(.95)within group(order by ms)<3000 from vv_timings where kind='detail'));
select count(*)passed_assertions from pg_temp.phase5a_assertions;
select kind,count(*)requests,round((percentile_cont(.50)within group(order by ms))::numeric,2)p50_ms,round((percentile_cont(.95)within group(order by ms))::numeric,2)p95_ms,round(max(ms)::numeric,2)max_ms from vv_timings group by kind order by kind;
rollback;
