-- Explicit bounded formats, canonical clock/lifecycle integration and replay.
begin;
\ir phase5b/fixture.sql
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.create_game('format','external');
select pg_temp.game_op('game.roster.snapshot','format');
select pg_temp.game_op('game.operator.assign','format',jsonb_build_object('person_id',pg_temp.f('admin'),'role_assignment_id',pg_temp.f('role-admin'),'function_key','game_administrator','team_id',pg_temp.f('falcons'),'ends_at',now()+interval '1 hour'));
do $$declare field text;value jsonb;base jsonb:='{"regulation_periods":4,"period_seconds":120,"overtime_seconds":60,"lineup_size":1,"enforce_lineup":false}';begin
 for field,value in select * from(values('regulation_periods','3'::jsonb),('period_seconds','59'::jsonb),('period_seconds','3601'::jsonb),('overtime_seconds','59'::jsonb),('overtime_seconds','1801'::jsonb),('lineup_size','0'::jsonb),('lineup_size','6'::jsonb),('enforce_lineup','"true"'::jsonb),('period_seconds','60.5'::jsonb))v(field,value)loop
  perform pg_temp.conflict('bounded format rejects '||field||'/'||value::text,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bad-format-'||field||value::text),pg_temp.game_command('basketball.configure','format',base||jsonb_build_object(field,value))));
 end loop;
end$$;
select pg_temp.bb_op('basketball.configure','format','{"regulation_periods":4,"period_seconds":120,"overtime_seconds":60,"lineup_size":1,"enforce_lineup":false}','format-configure');
select pg_temp.denied('configured pregame snapshot cannot be replaced',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('pregame-configured-snapshot'),pg_temp.game_command('game.roster.snapshot','format')),'PT409');
select pg_temp.check('four quarters and bounded one-player foundation explicit','FORMAT',pg_temp.bb_detail('format')->>'regulation_periods'='4' and pg_temp.bb_detail('format')->>'lineup_size'='1' and not(pg_temp.bb_detail('format')->>'enforce_lineup')::boolean);
-- Retain the real signed command before each feature removal. Hidden controls
-- alone do not prove that a stale form cannot start the configured engine.
reset role;
do $$declare flag text;command jsonb:=pg_temp.game_command('game.start','format');begin
 foreach flag in array array['basketball_live_scoring','basketball_stats'] loop
  update public.organization_modules set configuration=configuration||jsonb_build_object(flag,false) where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
  set local role authenticated;
  perform pg_temp.actor('admin');
  perform pg_temp.denied('disabled '||flag||' denies retained configured game start',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('disabled-start-'||flag),command),'PT403');
  perform pg_temp.check('disabled '||flag||' suppresses configured start capability','FEATURE',not(select(g->'capabilities'->>'start')::boolean from jsonb_array_elements(public.boss_games_read(pg_temp.query('format'))->'games')g));
  reset role;
  perform pg_temp.check('denied '||flag||' start leaves configured pregame unchanged','FEATURE',(select status in('scheduled','pregame') and started_at is null and version=(command->'input'->>'expected_version')::bigint from public.games where id=pg_temp.bb_game('format')));
  update public.organization_modules set configuration=configuration||jsonb_build_object(flag,true) where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
 end loop;
end$$;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.game_op('game.start','format');
select pg_temp.bb_op('basketball.period.start','format');
select pg_temp.bb_event('format','made_2','primary',1,'format-shot');
select pg_temp.bb_op('basketball.clock.start','format');
select pg_sleep(0.025);
select pg_temp.game_op('game.transition','format','{"status":"paused"}');
select pg_temp.check('canonical pause freezes running sport clock','CLOCK',not(pg_temp.bb_detail('format')->>'clock_running')::boolean and(pg_temp.bb_detail('format')->>'clock_ms')::bigint between 0 and 119999);
create temp table bb_pause_clock(ms bigint);
grant select,insert on bb_pause_clock to authenticated;
insert into bb_pause_clock select(pg_temp.bb_detail('format')->>'clock_ms')::bigint;
select pg_sleep(0.025);
select pg_temp.check('paused clock does not continue counting down','CLOCK',(select ms=(pg_temp.bb_detail('format')->>'clock_ms')::bigint from bb_pause_clock));
select pg_temp.state_denied('pause closes new shot entry',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('pause-event'),pg_temp.game_command('basketball.event.add','format',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('format','primary',1)))));
reset role;
do $$declare flag text;command jsonb:=pg_temp.game_command('game.transition','format','{"status":"live"}');begin
 foreach flag in array array['basketball_live_scoring','basketball_stats'] loop
  update public.organization_modules set configuration=configuration||jsonb_build_object(flag,false) where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
  set local role authenticated;
  perform pg_temp.actor('admin');
  perform pg_temp.denied('disabled '||flag||' denies retained configured live transition',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('disabled-resume-'||flag),command),'PT403');
  perform pg_temp.check('disabled '||flag||' suppresses configured resume capability','FEATURE',not(select(g->'capabilities'->>'resume')::boolean from jsonb_array_elements(public.boss_games_read(pg_temp.query('format'))->'games')g));
  reset role;
  perform pg_temp.check('denied '||flag||' resume preserves frozen pause clock','FEATURE',(select g.status='paused' and not s.clock_running and s.clock_anchor is null and s.clock_remaining_ms=(select ms from bb_pause_clock) and g.version=(command->'input'->>'expected_version')::bigint from public.games g join public.game_basketball_states s on s.game_id=g.id where g.id=pg_temp.bb_game('format')));
  update public.organization_modules set configuration=configuration||jsonb_build_object(flag,true) where organization_id=pg_temp.f('org') and module_id=(select id from public.modules where key='sports');
 end loop;
end$$;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.game_op('game.transition','format','{"status":"live"}');
select pg_temp.check('resume preserves stopped clock foundation','CLOCK',not(pg_temp.bb_detail('format')->>'clock_running')::boolean);
select pg_temp.bb_op('basketball.clock.start','format');
select pg_temp.game_op('game.transition','format','{"status":"delayed"}');
select pg_temp.check('delay also freezes authoritative clock','CLOCK',not(pg_temp.bb_detail('format')->>'clock_running')::boolean);
select pg_temp.game_op('game.transition','format','{"status":"live"}');
select pg_temp.check('delay resume never silently restarts clock','CLOCK',not(pg_temp.bb_detail('format')->>'clock_running')::boolean);
do $$declare n int;begin
 for n in 2..4 loop
  perform pg_temp.bb_end('format');perform pg_temp.bb_op('basketball.period.start','format');
  perform pg_temp.check('sequential quarter '||n,'PERIOD',pg_temp.bb_detail('format')->>'period_number'=n::text and pg_temp.bb_detail('format')->>'period_status'='active' and pg_temp.bb_detail('format')->>'clock_ms'='120000');
 end loop;
end$$;
select pg_temp.bb_event('format','personal_foul','primary',1);
select pg_temp.check('period foul projection isolates Q4 from prior quarters','FOULS',exists(select 1 from jsonb_array_elements(pg_temp.bb_detail('format')->'period_fouls')f where f->>'period_number'='4' and f->>'primary'='1' and f->>'opponent'='0'));
select pg_temp.bb_end('format');
select pg_temp.bb_op('basketball.period.start','format');
select pg_temp.check('explicit overtime uses configured overtime duration','PERIOD',pg_temp.bb_detail('format')->>'period_number'='5' and pg_temp.bb_detail('format')->>'overtime_number'='1' and pg_temp.bb_detail('format')->>'clock_ms'='60000');
select pg_temp.bb_end('format');
select pg_temp.state_denied('ended period rejects another end',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('repeat-period-end'),pg_temp.game_command('basketball.period.end','format')));
select pg_temp.game_op('game.finalize','format');
reset role;
select pg_temp.check('overtime final score seals normally','FINAL',(select status='final' and final_primary_score=2 from public.games where id=pg_temp.bb_game('format')) and(select period_number=5 from public.game_basketball_finalizations where game_id=pg_temp.bb_game('format')));
select pg_temp.check('no future minute or plus-minus display claim','FOUNDATION',not exists(select 1 from information_schema.columns where table_schema='public' and table_name='game_basketball_final_stats' and column_name in('minutes','plus_minus')));
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.bb_create('calendar-clock','internal',true,2,false);
select pg_temp.bb_op('basketball.clock.start','calendar-clock');
reset role;
create temp table bb_calendar_cancel as select pg_temp.cmd('event.update',jsonb_build_object('organization_id',e.organization_id,'event_id',e.id,'expected_version',e.version,'title',e.title,'event_type_key',e.event_type_key,'start_at',e.start_at,'end_at',e.end_at,'timezone',e.timezone,'status','canceled','visibility',e.visibility,'publication_state',e.publication_state,
 'targets',(select jsonb_agg(jsonb_build_object('target_type',t.target_type,'target_id',t.target_id)) from public.event_targets t where t.event_id=e.id),
 'game',(select jsonb_build_object('opponent_team_id',d.opponent_team_id,'external_opponent_name',d.external_opponent_name,'home_away',d.home_away,'game_status',d.game_status) from public.event_game_details d where d.event_id=e.id)))command from public.events e where e.id=pg_temp.f('event-internal');
grant select on bb_calendar_cancel to authenticated;
set local role authenticated;
select pg_temp.actor('admin');
select public.boss_calendar_mutate((select command from bb_calendar_cancel),pg_temp.f('bb-calendar-cancel'));
reset role;
select pg_temp.check('Calendar cancellation freezes clock and preserves identity','CALENDAR',(select g.status='canceled' and not s.clock_running and s.clock_anchor is null from public.games g join public.game_basketball_states s on s.game_id=g.id where g.id=pg_temp.bb_game('calendar-clock')));
select pg_temp.check('Calendar cancellation preserves typed timing history','CALENDAR',exists(select 1 from public.game_basketball_events where game_id=pg_temp.bb_game('calendar-clock') and event_type='clock_start') and exists(select 1 from public.game_operations where game_id=pg_temp.bb_game('calendar-clock') and operation='game.calendar.sync'));
select count(*) as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
