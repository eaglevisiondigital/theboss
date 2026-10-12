-- One canonical game has one explicit sport engine. All data is synthetic and rolled back.
begin;
\ir phase5d/fixture.sql
update public.organization_modules set configuration=configuration||'{"basketball_live_scoring":true,"basketball_stats":true,"basketball_play_by_play":true,"basketball_lineups":true,"soccer_live_scoring":true,"soccer_stats":true,"soccer_play_by_play":true,"soccer_lineups":true}'
 where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('football');
select pg_temp.ff_play('football','field_goal','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('football','primary',7),'made',true,'kick_distance',39),'cross-football-fg');
select pg_temp.ff_play('football','kickoff','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('football','primary',7),'touchback',true,'result_side','opponent','result_ball_spot',25,'result_down',1,'result_distance',10),'cross-football-kickoff');
select pg_temp.ff_link('basketball','internal','falcons','basketball');
select pg_temp.ff_op('basketball.configure','basketball','{"regulation_periods":2,"period_seconds":60,"overtime_seconds":60,"lineup_size":1,"enforce_lineup":false}');
select pg_temp.game_op('game.start','basketball');select pg_temp.ff_op('basketball.period.start','basketball');
select pg_temp.ff_op('basketball.event.add','basketball',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.ff_roster('basketball','primary',1)),'cross-basketball-two');
select pg_temp.ff_link('soccer','internal','falcons','soccer');
select pg_temp.ff_op('soccer.configure','soccer','{"regulation_segments":2,"segment_seconds":60,"extra_time_segments":0,"extra_time_seconds":60,"lineup_size":1,"enforce_lineup":false,"allow_reentry":true,"max_substitutions":null}');
select pg_temp.game_op('game.start','soccer');select pg_temp.ff_op('soccer.segment.start','soccer');
select pg_temp.ff_op('soccer.event.add','soccer',jsonb_build_object('event_type','goal','side','primary','roster_id',pg_temp.ff_roster('soccer','primary',1)),'cross-soccer-goal');
reset role;
create function pg_temp.ff_cross_snapshot(label text) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('game',to_jsonb(g),
 'football',(select to_jsonb(s)from public.game_football_states s where s.game_id=g.id),
 'basketball',(select to_jsonb(s)from public.game_basketball_states s where s.game_id=g.id),
 'soccer',(select to_jsonb(s)from public.game_soccer_states s where s.game_id=g.id),
 'football_facts',(select coalesce(jsonb_agg(to_jsonb(e)order by e.sequence),'[]')from public.game_football_events e where e.game_id=g.id),
 'basketball_facts',(select coalesce(jsonb_agg(to_jsonb(e)order by e.sequence),'[]')from public.game_basketball_events e where e.game_id=g.id),
 'soccer_facts',(select coalesce(jsonb_agg(to_jsonb(e)order by e.sequence),'[]')from public.game_soccer_events e where e.game_id=g.id),
 'operations',(select coalesce(jsonb_agg(to_jsonb(o)order by o.sequence),'[]')from public.game_operations o where o.game_id=g.id),
 'receipts',(select coalesce(jsonb_agg(to_jsonb(r)order by r.request_id),'[]')from boss_private.game_operation_receipts r where r.result->>'game_id'=g.id::text))
 from public.games g where g.id=pg_temp.ff_game(label)
$$;
revoke all on function pg_temp.ff_cross_snapshot(text) from public;
grant execute on function pg_temp.ff_cross_snapshot(text) to authenticated;
create temp table ff_cross_before as select label,pg_temp.ff_cross_snapshot(label)snapshot from unnest(array['football','basketball','soccer'])label;
grant select on ff_cross_before to authenticated;
create temp table ff_cross_core_operation as select operation_id from public.game_football_events where id=pg_temp.ff_event_id('football','cross-football-fg');
grant select on ff_cross_core_operation to authenticated;
set local role authenticated;select pg_temp.actor('admin');
do $$declare sport text;begin
 foreach sport in array array['basketball','soccer']loop
  perform pg_temp.state_denied('Football command cannot score '||sport,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-to-'||sport),pg_temp.game_command('football.play.add',sport,jsonb_build_object('play_type','rush','side','primary','roster_id',pg_temp.ff_roster(sport,'primary',2),'yards',5))));
  perform pg_temp.state_denied('Football cannot configure existing '||sport||' engine',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-own-'||sport),pg_temp.game_command('football.configure',sport,'{"quarter_seconds":60,"overtime_format":"none","overtime_seconds":60,"max_overtime_periods":0,"play_clock_seconds":25,"lineup_size":1,"enforce_lineup":false,"kneel_counts_as_rush":true}')));
  perform pg_temp.state_denied('Football control cannot advance '||sport,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-period-'||sport),pg_temp.game_command('football.period.start',sport)));
 end loop;
end$$;
select pg_temp.state_denied('Basketball command cannot score Football',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bb-to-ff'),pg_temp.game_command('basketball.event.add','football','{"event_type":"made_2","side":"primary"}')));
select pg_temp.state_denied('Soccer command cannot score Football',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-to-ff'),pg_temp.game_command('soccer.event.add','football','{"event_type":"goal","side":"primary"}')));
select pg_temp.state_denied('Basketball cannot configure existing Football engine',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bb-own-ff'),pg_temp.game_command('basketball.configure','football','{"regulation_periods":2,"period_seconds":60,"overtime_seconds":60,"lineup_size":1,"enforce_lineup":false}')));
select pg_temp.state_denied('Soccer cannot configure existing Football engine',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-own-ff'),pg_temp.game_command('soccer.configure','football','{"regulation_segments":2,"segment_seconds":60,"extra_time_segments":0,"extra_time_seconds":60,"lineup_size":1,"enforce_lineup":false,"allow_reentry":true,"max_substitutions":null}')));
select pg_temp.state_denied('Basketball control cannot advance Football',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bb-period-ff'),pg_temp.game_command('basketball.period.start','football')));
select pg_temp.state_denied('Soccer control cannot advance Football',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-segment-ff'),pg_temp.game_command('soccer.segment.start','football')));
select pg_temp.state_denied('manual score cannot override configured Football',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-manual-override'),pg_temp.game_command('game.score.set','football','{"primary_score":77,"opponent_score":0}')));
select pg_temp.state_denied('canonical reversal cannot bypass configured Football ledger',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-manual-reversal'),pg_temp.game_command('game.score.reverse','football',jsonb_build_object('operation_id',(select operation_id from ff_cross_core_operation),'reason','Synthetic attempted Football ledger bypass'))));
select pg_temp.state_denied('configured Football cannot refresh its locked roster',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-refresh-roster'),pg_temp.game_command('game.roster.snapshot','football')));
do $$declare b record;begin
 for b in select *from ff_cross_before loop
  perform pg_temp.check('wrong-sport and manual bypass denials preserve all persisted surfaces '||b.label,'COMPATIBILITY',pg_temp.ff_cross_snapshot(b.label)=b.snapshot);
 end loop;
end$$;

do $$declare sport text;label text;begin
 foreach sport in array array['baseball','softball','volleyball']loop
  label:='non-football-'||sport;perform pg_temp.ff_link(label,'internal','falcons',sport);
  perform pg_temp.state_denied('Football configuration rejects explicit '||sport,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-wrong-'||sport),pg_temp.game_command('football.configure',label,'{"quarter_seconds":60,"overtime_format":"none","overtime_seconds":60,"max_overtime_periods":0,"play_clock_seconds":25,"lineup_size":1,"enforce_lineup":false,"kneel_counts_as_rush":true}')));
 end loop;
end$$;
select pg_temp.ff_link('manual-football');select pg_temp.game_op('game.start','manual-football');
select pg_temp.game_op('game.score.set','manual-football','{"primary_score":3,"opponent_score":1}');
select pg_temp.state_denied('historical manual Football is not silently absorbed',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-manual-history-configure'),pg_temp.game_command('football.configure','manual-football','{"quarter_seconds":60,"overtime_format":"none","overtime_seconds":60,"max_overtime_periods":0,"play_clock_seconds":25,"lineup_size":1,"enforce_lineup":false,"kneel_counts_as_rush":true}')));
reset role;
select pg_temp.check('historical manual Football retains canonical score without an engine','COMPATIBILITY',
 (select sport_key='football'and primary_score=3 and opponent_score=1 from public.games where id=pg_temp.ff_game('manual-football'))
 and not exists(select 1 from public.game_football_states where game_id=pg_temp.ff_game('manual-football')));

-- Defense in depth covers the owner as well as the denied authenticated APIs.
select pg_temp.denied('owner cannot insert Football state into Basketball game',format('insert into public.game_football_states select(jsonb_populate_record(null::public.game_football_states,to_jsonb(s)||jsonb_build_object(%L,%L::uuid))).*from public.game_football_states s where s.game_id=%L','game_id',pg_temp.ff_game('basketball'),pg_temp.ff_game('football')),'PT409');
select pg_temp.denied('owner cannot insert Football state into Soccer game',format('insert into public.game_football_states select(jsonb_populate_record(null::public.game_football_states,to_jsonb(s)||jsonb_build_object(%L,%L::uuid))).*from public.game_football_states s where s.game_id=%L','game_id',pg_temp.ff_game('soccer'),pg_temp.ff_game('football')),'PT409');
select pg_temp.denied('owner cannot insert Basketball state into Football game',format('insert into public.game_basketball_states select(jsonb_populate_record(null::public.game_basketball_states,to_jsonb(s)||jsonb_build_object(%L,%L::uuid))).*from public.game_basketball_states s where s.game_id=%L','game_id',pg_temp.ff_game('football'),pg_temp.ff_game('basketball')),'PT409');
select pg_temp.denied('owner cannot insert Soccer state into Football game',format('insert into public.game_soccer_states select(jsonb_populate_record(null::public.game_soccer_states,to_jsonb(s)||jsonb_build_object(%L,%L::uuid))).*from public.game_soccer_states s where s.game_id=%L','game_id',pg_temp.ff_game('football'),pg_temp.ff_game('soccer')),'PT409');
select pg_temp.check('owner wrong-sport inserts change no configured game state or ledger','SECURITY',
 not exists(select 1 from ff_cross_before b where pg_temp.ff_cross_snapshot(b.label)is distinct from b.snapshot));

update public.organization_modules set configuration=configuration||'{"football_live_scoring":false}'
 where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.denied('Football flag removal denies own sport command',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-disabled-rush'),pg_temp.game_command('football.play.add','football','{"play_type":"rush","side":"opponent","yards":1}')),'PT403');
select pg_temp.state_denied('Football flag removal never restores manual score ownership',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-disabled-manual'),pg_temp.game_command('game.score.set','football','{"primary_score":99,"opponent_score":0}')));
select pg_temp.state_denied('Football flag removal never restores canonical score reversal',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-disabled-core-reverse'),pg_temp.game_command('game.score.reverse','football',jsonb_build_object('operation_id',(select operation_id from ff_cross_core_operation),'reason','Synthetic feature-removal bypass attempt'))));
select pg_temp.ff_op('basketball.event.add','basketball','{"event_type":"made_ft","side":"primary"}');
select pg_temp.ff_op('soccer.event.add','soccer','{"event_type":"goal","side":"primary"}');
select pg_temp.check('Football flag removal leaves Basketball and Soccer operations enabled','FLAGS',
 (select(g->'basketball'->'capabilities'->>'operate')::boolean from jsonb_array_elements(public.boss_games_read(pg_temp.query('basketball'))->'games')g)
 and(select(g->'soccer'->'capabilities'->>'operate')::boolean from jsonb_array_elements(public.boss_games_read(pg_temp.query('soccer'))->'games')g)
 and not coalesce((pg_temp.ff_detail('football')->'capabilities'->>'operate')::boolean,false));
reset role;
update public.organization_modules set configuration=configuration||'{"football_live_scoring":true,"basketball_live_scoring":false}'
 where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_play('football','rush','opponent',jsonb_build_object('roster_id',pg_temp.ff_roster('football','opponent',2),'yards',1));
select pg_temp.ff_op('soccer.event.add','soccer','{"event_type":"goal","side":"primary"}');
select pg_temp.denied('Basketball flag removal still denies own sport command',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('bb-disabled-cross-event'),pg_temp.game_command('basketball.event.add','basketball','{"event_type":"made_2","side":"primary"}')),'PT403');
select pg_temp.check('Basketball flag removal leaves Football and Soccer enabled','FLAGS',
 (pg_temp.ff_detail('football')->'capabilities'->>'operate')::boolean
 and(select(g->'soccer'->'capabilities'->>'operate')::boolean from jsonb_array_elements(public.boss_games_read(pg_temp.query('soccer'))->'games')g));
reset role;
update public.organization_modules set configuration=configuration||'{"basketball_live_scoring":true,"soccer_live_scoring":false}'
 where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_play('football','rush','opponent',jsonb_build_object('roster_id',pg_temp.ff_roster('football','opponent',2),'yards',1));
select pg_temp.ff_op('basketball.event.add','basketball','{"event_type":"made_ft","side":"primary"}');
select pg_temp.denied('Soccer flag removal still denies own sport command',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sc-disabled-cross-event'),pg_temp.game_command('soccer.event.add','soccer','{"event_type":"goal","side":"primary"}')),'PT403');
select pg_temp.check('Soccer flag removal leaves Football and Basketball enabled','FLAGS',
 (pg_temp.ff_detail('football')->'capabilities'->>'operate')::boolean
 and(select(g->'basketball'->'capabilities'->>'operate')::boolean from jsonb_array_elements(public.boss_games_read(pg_temp.query('basketball'))->'games')g));
reset role;
select pg_temp.check('independent engines retain literal score contributions','COMPATIBILITY',
 (select primary_score=3 and opponent_score=0 from public.games where id=pg_temp.ff_game('football'))
 and(select primary_score=4 and opponent_score=0 from public.games where id=pg_temp.ff_game('basketball'))
 and(select primary_score=3 and opponent_score=0 from public.games where id=pg_temp.ff_game('soccer')));
select pg_temp.ff_expect('football','primary',7,'{"field_goals_attempted":1,"field_goals_made":1,"long_field_goal":39,"points":3}','cross-sport retained field goal');
select pg_temp.ff_expect('football','opponent',2,'{"rush_attempts":2,"rushing_yards":2,"points":0}','cross-sport independent runner');
select pg_temp.check('finite engines never share the same canonical game','COMPATIBILITY',
 not exists(select 1 from public.game_football_states f join public.game_basketball_states b using(game_id))
 and not exists(select 1 from public.game_football_states f join public.game_soccer_states s using(game_id))
 and not exists(select 1 from public.game_basketball_states b join public.game_soccer_states s using(game_id)));
select pg_temp.check('configured state ownership exactly matches all three canonical sports','COMPATIBILITY',
 (select count(*)=3 and bool_and(g.sport_key=e.sport and g.organization_id=e.organization_id)from public.games g join(
 select game_id,organization_id,'football'::text sport from public.game_football_states
 union all select game_id,organization_id,'basketball'from public.game_basketball_states
 union all select game_id,organization_id,'soccer'from public.game_soccer_states)e on e.game_id=g.id
 where g.id in(pg_temp.ff_game('football'),pg_temp.ff_game('basketball'),pg_temp.ff_game('soccer'))));
select count(*)as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
