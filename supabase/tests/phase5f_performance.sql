-- Realistic synthetic nine-inning games, normal timeout unchanged.
begin;
\ir phase5f/fixture.sql
create function pg_temp.dd_firstplay(label text)returns jsonb language sql security definer set search_path=''as $$select jsonb_build_object('event_id',id,'reason','Synthetic benchmark adjudication','payload',jsonb_set(payload,'{moves,0,rbi}','false'))from public.game_diamond_events where game_id=pg_temp.ff_game(label)and event_type='play'order by sequence limit 1$$;
revoke all on function pg_temp.dd_firstplay(text)from public;grant execute on function pg_temp.dd_firstplay(text)to authenticated;
create temp table dd_timings(kind text,ms double precision);grant insert,select on dd_timings to authenticated;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.dd_create('heavy','baseball','full',9);select pg_temp.dd_create('lite','baseball','essential',9);
do $$declare label text;h int;n int;p int;started timestamptz;result jsonb;begin
foreach label in array array['heavy','lite']loop
for h in 1..18 loop
-- First half one extra homer gives a non-tied ordinary final score.
for n in 1..(case h when 1 then 7 else 6 end)loop
perform pg_temp.dd_pa(label,label||'-'||h||'-'||n);
if label='heavy'then for p in 1..4 loop
started:=clock_timestamp();perform pg_temp.dd_op('diamond.pitch.add',label,jsonb_build_object('payload',jsonb_build_object('kind','pitch','outcome',case p when 1 then'ball'when 2 then'called_strike'when 3 then'foul'else'in_play'end)));
insert into dd_timings values('pitch_append',extract(epoch from clock_timestamp()-started)*1000);end loop;end if;
started:=clock_timestamp();
if n<=(case h when 1 then 4 else 3 end) then perform pg_temp.dd_play(label,'home_run',jsonb_build_array(pg_temp.dd_move(0,4)||case label when'heavy'then'{"earned":true}'::jsonb else'{}'::jsonb end));
else perform pg_temp.dd_play(label,'other_out',jsonb_build_array(pg_temp.dd_move(0,null,'advance_on_play',false,true)));end if;
insert into dd_timings values(label||'_play',extract(epoch from clock_timestamp()-started)*1000);
end loop;
if h<18 then perform pg_temp.dd_op('diamond.half.start',label,'{"payload":{"kind":"half_start"}}');end if;end loop;
for n in 1..5 loop started:=clock_timestamp();result:=public.boss_games_read(pg_temp.query(label));
insert into dd_timings values(label||'_detail',extract(epoch from clock_timestamp()-started)*1000);
if result->'games'->0->'diamond'->'state'->>'primary_score'<>'28'or result->'games'->0->'diamond'->'state'->>'opponent_score'<>'27'then raise exception 'Independent realistic score oracle mismatch';end if;end loop;
started:=clock_timestamp();perform pg_temp.dd_op('diamond.event.correct',label,pg_temp.dd_firstplay(label));insert into dd_timings values(label||'_correction',extract(epoch from clock_timestamp()-started)*1000);
started:=clock_timestamp();perform pg_temp.game_op('game.finalize',label);insert into dd_timings values(label||'_final',extract(epoch from clock_timestamp()-started)*1000);
end loop;end$$;
reset role;
select pg_temp.check('realistic pitch count 436','PERFORMANCE',pg_temp.dd_stats('heavy','primary')->>'pitches'='216'and pg_temp.dd_stats('heavy','opponent')->>'pitches'='220');
select pg_temp.check('all complete detail p95 under three seconds','PERFORMANCE',(select bool_and(ms<3000)from dd_timings where kind like'%_detail'));
select pg_temp.check('all mutations under three seconds','PERFORMANCE',(select max(ms)<3000 from dd_timings where kind not like'%_detail'));
select count(*)passed_assertions from pg_temp.phase5a_assertions;
select kind,count(*)requests,round((percentile_cont(.5)within group(order by ms))::numeric,2)p50_ms,round((percentile_cont(.95)within group(order by ms))::numeric,2)p95_ms,round(max(ms)::numeric,2)max_ms from dd_timings group by kind order by kind;rollback;
