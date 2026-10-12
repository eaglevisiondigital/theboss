-- Engines share canonical records but never acquire another explicit sport.
begin;
\ir phase5c/fixture.sql
update public.organization_modules set configuration=configuration||'{"basketball_live_scoring":true,"basketball_stats":true,"basketball_play_by_play":true,"basketball_lineups":true}'where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_create('soccer');
select pg_temp.sc_link('basketball','internal','falcons','basketball');
select pg_temp.sc_op('basketball.configure','basketball','{"regulation_periods":2,"period_seconds":60,"overtime_seconds":60,"lineup_size":1,"enforce_lineup":false}');
select pg_temp.game_op('game.start','basketball');select pg_temp.sc_op('basketball.period.start','basketball');
select pg_temp.sc_op('basketball.event.add','basketball',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.sc_roster('basketball','primary',1)));
select pg_temp.sc_event('soccer','goal','primary',1,'cross-first-goal');
select pg_temp.state_denied('Soccer command cannot score Basketball game',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-to-bb'),pg_temp.game_command('soccer.event.add','basketball','{"event_type":"goal","side":"primary"}')));
select pg_temp.state_denied('Basketball command cannot score Soccer game',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bb-to-sc'),pg_temp.game_command('basketball.event.add','soccer','{"event_type":"made_2","side":"primary"}')));
select pg_temp.state_denied('Soccer cannot own existing Basketball engine',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-own-bb'),pg_temp.game_command('soccer.configure','basketball','{"regulation_segments":2,"segment_seconds":60,"extra_time_segments":0,"extra_time_seconds":60,"lineup_size":1,"enforce_lineup":false,"allow_reentry":true,"max_substitutions":null}')));
select pg_temp.state_denied('Basketball cannot own existing Soccer engine',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bb-own-sc'),pg_temp.game_command('basketball.configure','soccer','{"regulation_periods":2,"period_seconds":60,"overtime_seconds":60,"lineup_size":1,"enforce_lineup":false}')));
do $$declare sport text;label text;begin
 foreach sport in array array['football','baseball','softball','volleyball']loop
  label:='non-soccer-'||sport;perform pg_temp.sc_link(label,'internal','falcons',sport);
  perform pg_temp.state_denied('Soccer configuration rejects explicit '||sport,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-wrong-'||sport),pg_temp.game_command('soccer.configure',label,'{"regulation_segments":2,"segment_seconds":60,"extra_time_segments":0,"extra_time_seconds":60,"lineup_size":1,"enforce_lineup":false,"allow_reentry":true,"max_substitutions":null}')));
 end loop;
end$$;
select pg_temp.state_denied('manual score cannot override configured Soccer',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-manual-override'),pg_temp.game_command('game.score.set','soccer','{"primary_score":77,"opponent_score":0}')));
reset role;create temp table sc_core_operation as select operation_id from public.game_soccer_events where game_id=pg_temp.sc_game('soccer')and request_id=pg_temp.f('cross-first-goal');grant select on sc_core_operation to authenticated;set local role authenticated;select pg_temp.actor('admin');
select pg_temp.state_denied('core reversal cannot override configured Soccer ledger',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-manual-reversal'),pg_temp.game_command('game.score.reverse','soccer',jsonb_build_object('operation_id',(select operation_id from sc_core_operation),'reason','Synthetic attempted ledger bypass'))));
select pg_temp.state_denied('configured Soccer cannot refresh locked roster snapshot',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-refresh'),pg_temp.game_command('game.roster.snapshot','soccer')));
select pg_temp.sc_link('manual','internal','falcons','soccer');select pg_temp.game_op('game.start','manual');select pg_temp.game_op('game.score.set','manual','{"primary_score":3,"opponent_score":1}');
select pg_temp.state_denied('historical manual Soccer score is not silently absorbed',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-history-configure'),pg_temp.game_command('soccer.configure','manual','{"regulation_segments":2,"segment_seconds":60,"extra_time_segments":0,"extra_time_seconds":60,"lineup_size":1,"enforce_lineup":false,"allow_reentry":true,"max_substitutions":null}')));
reset role;
select pg_temp.check('historical manual game remains canonical without engine','COMPATIBILITY',(select primary_score=3 and opponent_score=1 from public.games where id=pg_temp.sc_game('manual'))and not exists(select 1 from public.game_soccer_states where game_id=pg_temp.sc_game('manual')));
select pg_temp.denied('owner cannot insert Soccer state into Football game',format('insert into public.game_soccer_states select (jsonb_populate_record(null::public.game_soccer_states,to_jsonb(s)||jsonb_build_object(%L,%L::uuid))).* from public.game_soccer_states s where s.game_id=%L','game_id',pg_temp.sc_game('non-soccer-football'),pg_temp.sc_game('soccer')),'PT409');
select pg_temp.denied('owner cannot insert Basketball state into Soccer game',format('insert into public.game_basketball_states select (jsonb_populate_record(null::public.game_basketball_states,to_jsonb(s)||jsonb_build_object(%L,%L::uuid))).* from public.game_basketball_states s where s.game_id=%L','game_id',pg_temp.sc_game('soccer'),pg_temp.sc_game('basketball')),'PT409');
update public.organization_modules set configuration=configuration||'{"soccer_live_scoring":false}'where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.denied('Soccer disabled blocks accepted sport path',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-disabled-goal'),pg_temp.game_command('soccer.event.add','soccer','{"event_type":"goal","side":"primary"}')),'PT403');
select pg_temp.state_denied('feature removal never reopens manual Soccer bypass',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-disabled-manual'),pg_temp.game_command('game.score.set','soccer','{"primary_score":99,"opponent_score":0}')));
select pg_temp.sc_op('basketball.event.add','basketball','{"event_type":"made_ft","side":"primary"}');
select pg_temp.check('Soccer flag removal leaves Basketball capability enabled','FLAGS',(select(g->'basketball'->'capabilities'->>'operate')::boolean from jsonb_array_elements(public.boss_games_read(pg_temp.query('basketball'))->'games')g));
reset role;update public.organization_modules set configuration=configuration||'{"soccer_live_scoring":true,"basketball_live_scoring":false}'where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
set local role authenticated;select pg_temp.actor('admin');select pg_temp.sc_event('soccer','goal','primary',1);
select pg_temp.denied('Basketball disabled still blocks its own event',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bb-disabled-goal'),pg_temp.game_command('basketball.event.add','basketball','{"event_type":"made_2","side":"primary"}')),'PT403');
reset role;
select pg_temp.check('independent finite engines retain exact score contribution','COMPATIBILITY',(select primary_score=2 from public.games where id=pg_temp.sc_game('soccer'))and(select primary_score=3 from public.games where id=pg_temp.sc_game('basketball')));
select pg_temp.check('no game owns duplicate engines','COMPATIBILITY',not exists(select 1 from public.game_soccer_states s join public.game_basketball_states b using(game_id)));
select count(*)as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
