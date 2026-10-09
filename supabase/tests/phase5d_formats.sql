-- Explicit bounded format, remaining server clock, state and lineup foundation.
begin;
\ir phase5d/fixture.sql
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_link('format');
do $$declare field text;value jsonb;base jsonb:='{"quarter_seconds":120,"overtime_format":"timed","overtime_seconds":60,"max_overtime_periods":1,"play_clock_seconds":25,"lineup_size":1,"enforce_lineup":false,"kneel_counts_as_rush":true}';begin
 for field,value in select * from(values
 ('quarter_seconds','59'::jsonb),('quarter_seconds','3601'::jsonb),('quarter_seconds','60.5'::jsonb),('overtime_seconds','59'::jsonb),('overtime_seconds','1801'::jsonb),('max_overtime_periods','-1'::jsonb),('max_overtime_periods','9'::jsonb),('overtime_format','"nfl"'::jsonb),('lineup_size','0'::jsonb),('lineup_size','12'::jsonb),('play_clock_seconds','4'::jsonb),('play_clock_seconds','61'::jsonb),('enforce_lineup','"false"'::jsonb),('kneel_counts_as_rush','"true"'::jsonb)
 )v(field,value)loop
  perform pg_temp.conflict('bounded Football configuration '||field||'/'||value,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bad-ff-config-'||field||value::text),pg_temp.game_command('football.configure','format',base||jsonb_build_object(field,value))));
 end loop;
end$$;
select pg_temp.ff_op('football.configure','format','{"quarter_seconds":120,"overtime_format":"timed","overtime_seconds":60,"max_overtime_periods":1,"play_clock_seconds":25,"lineup_size":1,"enforce_lineup":false,"kneel_counts_as_rush":true}');
select pg_temp.check('four-quarter configurable timing foundation','FORMAT',pg_temp.ff_detail('format')->>'quarter_seconds'='120'and pg_temp.ff_detail('format')->>'overtime_format'='timed'and pg_temp.ff_detail('format')->>'play_clock_seconds'='25'and pg_temp.ff_detail('format')->>'period_number'='0');
select pg_temp.state_denied('period cannot precede canonical start',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-early-period'),pg_temp.game_command('football.period.start','format')));
select pg_temp.game_op('game.start','format');select pg_temp.ff_op('football.period.start','format');
select pg_temp.ff_op('football.state.set','format','{"side":"primary","ball_spot":95,"down":1,"distance":5,"primary_direction":"increasing","reason":"Synthetic goal-to-go placement"}');
select pg_temp.check('normalized goal-to-go field','FIELD',pg_temp.ff_detail('format')->'field_state'->>'ball_spot'='95'and(pg_temp.ff_detail('format')->'field_state'->>'goal_to_go')::boolean and pg_temp.ff_detail('format')->'field_state'->>'line_to_gain'='100');
select pg_temp.ff_op('football.clock.start','format');
select pg_temp.conflict('duplicate running clock start denied',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-double-clock'),pg_temp.game_command('football.clock.start','format')));
select pg_sleep(0.025);
select pg_temp.check('server remaining clock decreases','CLOCK',(pg_temp.ff_detail('format')->>'clock_ms')::bigint between 1 and 119999);
select pg_temp.game_op('game.transition','format','{"status":"paused"}');
create temp table ff_paused(ms bigint);grant select,insert on ff_paused to authenticated;
insert into ff_paused select(pg_temp.ff_detail('format')->>'clock_ms')::bigint;
select pg_sleep(0.025);
select pg_temp.check('canonical pause freezes remaining clock','CLOCK',not(pg_temp.ff_detail('format')->>'clock_running')::boolean and(select ms=(pg_temp.ff_detail('format')->>'clock_ms')::bigint from ff_paused));
select pg_temp.state_denied('paused Football play denied',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-paused-play'),pg_temp.game_command('football.play.add','format','{"play_type":"rush","side":"primary","yards":1}')));
select pg_temp.game_op('game.transition','format','{"status":"live"}');
select pg_temp.check('resume requires explicit clock start','CLOCK',not(pg_temp.ff_detail('format')->>'clock_running')::boolean);
select pg_temp.conflict('clock above nominal duration rejected',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-clock-large'),pg_temp.game_command('football.clock.set','format','{"clock_ms":120001,"reason":"Synthetic invalid remaining time"}')));
select pg_temp.state_denied('timed period cannot end with remaining time',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-early-end'),pg_temp.game_command('football.period.end','format')));
do $$declare n int;begin
 for n in 1..4 loop
  perform pg_temp.ff_end('format');
  if n<4 then perform pg_temp.ff_op('football.period.start','format');perform pg_temp.check('sequential quarter '||(n+1),'PERIOD',pg_temp.ff_detail('format')->>'period_number'=(n+1)::text and pg_temp.ff_detail('format')->>'clock_ms'='120000');end if;
 end loop;
end$$;
select pg_temp.ff_op('football.period.start','format');
select pg_temp.check('timed overtime uses explicit configured duration','OVERTIME',pg_temp.ff_detail('format')->>'period_number'='5'and pg_temp.ff_detail('format')->>'clock_ms'='60000');
select pg_temp.ff_end('format');select pg_temp.game_op('game.finalize','format');
select pg_temp.ff_create('none','internal',true,false,1);
select pg_temp.ff_finish('none');
select pg_temp.state_denied('none overtime refuses fifth period',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-no-ot'),pg_temp.game_command('football.period.start','none')));
select pg_temp.ff_create('possession','internal',true,false,1,'{"overtime_format":"possession","max_overtime_periods":1}');
select pg_temp.ff_finish('possession');select pg_temp.ff_op('football.period.start','possession');
select pg_temp.ff_op('football.period.end','possession');
select pg_temp.check('possession overtime accepts confirmed period boundary','OVERTIME',pg_temp.ff_detail('possession')->>'period_number'='5'and pg_temp.ff_detail('possession')->>'period_status'='ended');
select pg_temp.ff_create('lineup','internal',true,true,6);
select pg_temp.state_denied('enforced lineup denies bench play',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-bench'),pg_temp.game_command('football.play.add','lineup',jsonb_build_object('play_type','rush','side','primary','roster_id',pg_temp.ff_roster('lineup','primary',7),'yards',1))));
select pg_temp.ff_op('football.substitute','lineup',jsonb_build_object('side','primary','out_roster_id',pg_temp.ff_roster('lineup','primary',6),'in_roster_id',pg_temp.ff_roster('lineup','primary',7)));
select pg_temp.ff_play('lineup','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('lineup','primary',7),'yards',1));
select pg_temp.state_denied('duplicate lineup athlete rejected',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-duplicate-lineup'),pg_temp.game_command('football.lineup.set','lineup',jsonb_build_object('side','primary','roster_ids',jsonb_build_array(pg_temp.ff_roster('lineup','primary',1),pg_temp.ff_roster('lineup','primary',1))))));
select pg_temp.ff_create('kneel-separate','internal',true,false,1,'{"kneel_counts_as_rush":false}');
select pg_temp.ff_play('kneel-separate','kneel','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('kneel-separate','primary',1),'yards',-1));
-- LONG is the maximum signed accepted gain; zero is reserved for no attempts.
select pg_temp.ff_create('negative-rush');
select pg_temp.ff_play('negative-rush','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('negative-rush','primary',2),'yards',-3),'negative-rush-three');
select pg_temp.ff_play('negative-rush','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('negative-rush','primary',2),'yards',-1),'negative-rush-one');
select pg_temp.ff_create('negative-reception');
select pg_temp.ff_play('negative-reception','pass_complete','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('negative-reception','primary',1),'receiver_roster_id',pg_temp.ff_roster('negative-reception','primary',3),'yards',-4),'negative-reception-four');
select pg_temp.ff_play('negative-reception','pass_complete','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('negative-reception','primary',1),'receiver_roster_id',pg_temp.ff_roster('negative-reception','primary',3),'yards',-2),'negative-reception-two');
reset role;
select pg_temp.ff_expect('kneel-separate','primary',1,'{"rush_attempts":0,"rushing_yards":0,"kneels":1,"kneel_yards":-1}','explicit separate kneel convention');
select pg_temp.ff_expect('negative-rush','primary',2,'{"rush_attempts":2,"rushing_yards":-4,"long_rush":-1}','negative-only runner longest');
select pg_temp.ff_expect('negative-rush','primary',0,'{"rush_attempts":2,"rushing_yards":-4,"long_rush":-1}','negative-only team rush longest');
select pg_temp.ff_expect('negative-rush','primary',3,'{"rush_attempts":0,"long_rush":0}','no-rush longest zero');
select pg_temp.ff_expect('negative-reception','primary',3,'{"receptions":2,"targets":2,"receiving_yards":-6,"long_reception":-2}','negative-only receiver longest');
select pg_temp.ff_expect('negative-reception','primary',0,'{"passing_completions":2,"passing_yards":-6,"receptions":2,"receiving_yards":-6,"long_reception":-2}','negative-only team reception longest');
select pg_temp.ff_expect('negative-reception','primary',4,'{"receptions":0,"long_reception":0}','no-reception longest zero');
select count(*)as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
