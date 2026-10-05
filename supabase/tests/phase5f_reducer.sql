-- Independent Diamond literal oracle; synthetic disposable records only.
begin;
\ir phase5a/fixture.sql
create temp table dd(c jsonb,s jsonb);
insert into dd(c)values('{"version":"diamond-rules-v1","sport":"baseball","home_side":"opponent","regulation_innings":1,"lineup_size":4,"continuous_batting":true,"allow_reentry":false,"stealing":true,"dropped_third_strike":"first_unoccupied_or_two_outs","foul_bunt_third_strike":true,"run_cap":null,"tiebreak_from":null,"dh":"none","dp_flex":"none","courtesy_runner":"none","mercy_margin":null,"time_limit_minutes":null,"pitch_limit":null,"era_innings":9}');
update dd set s=boss_private.diamond_initial(c);
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"lineup_set","side":"primary","order":["p1","p2","p3","p4"],"positions":{"1":"p4"},"pitcher":"p4"}');
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"lineup_set","side":"opponent","order":["o1","o2","o3","o4"],"positions":{"1":"o4"},"pitcher":"o4"}');
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"half_start"}');
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"pa_start","key":"pa1","batter":"p1","pitch_tracking":false}');
select pg_temp.check('untracked pitch zero is not measured','COVERAGE',(select s->'pa'->>'pitch_coverage'='not_tracked'from dd));
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"play","result":"single","moves":[{"from":0,"to":1,"out":false,"cause":"hit","force":false,"batter_before_first":false}]}');
select pg_temp.check('actual runner identity and responsibility','RUNNER',(select s->'bases'->0@>'{"key":"pa1","roster_id":"p1","responsible_pitcher":"o4","origin":"hit"}'from dd));
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"pa_start","key":"pa2","batter":"p2","pitch_tracking":false}');
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"play","result":"double","moves":[{"from":1,"to":3,"out":false,"cause":"hit","force":false,"batter_before_first":false},{"from":0,"to":2,"out":false,"cause":"hit","force":false,"batter_before_first":false}]}');
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"pa_start","key":"pa3","batter":"p3","pitch_tracking":false}');
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"play","result":"home_run","moves":[{"from":3,"to":4,"out":false,"cause":"hit","force":false,"batter_before_first":false},{"from":2,"to":4,"out":false,"cause":"hit","force":false,"batter_before_first":false},{"from":0,"to":4,"out":false,"cause":"hit","force":false,"batter_before_first":false}]}');
select pg_temp.check('literal HR three runs and empty bases','ORACLE',(select s@>'{"primary_score":3,"opponent_score":0,"outs":0,"bases":[null,null,null]}'from dd));
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"pa_start","key":"pa4","batter":"p4","pitch_tracking":true}');
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"pitch","outcome":"called_strike","pitch_tracking":true}');
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"pitch","outcome":"swinging_strike","pitch_tracking":true}');
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"pitch","outcome":"foul","pitch_tracking":true}');
select pg_temp.check('two-strike foul stays two','PITCH',(select s->'pa'@>'{"strikes":2,"pitches":3}'from dd));
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"pitch","outcome":"foul_bunt","pitch_tracking":true}');
select pg_temp.check('foul bunt third strike','PITCH',(select s->'pa'@>'{"strikes":3,"pitches":4,"awaiting":"strikeout"}'from dd));
select pg_temp.denied('pitch after terminal count','select boss_private.diamond_transition(c,s,''{"kind":"pitch","outcome":"ball","pitch_tracking":true}'')from dd','PT409');
select pg_temp.denied('result contrary to third strike','select boss_private.diamond_transition(c,s,''{"kind":"play","result":"single","moves":[{"from":0,"to":1,"out":false,"cause":"hit","force":false,"batter_before_first":false}]}'')from dd','PT409');
update dd set s=boss_private.diamond_transition(c,s,'{"kind":"play","result":"strikeout","moves":[{"from":0,"to":null,"out":true,"cause":"advance_on_play","force":false,"batter_before_first":true}]}');
select pg_temp.check('strikeout one out and resolved PA','PITCH',(select s->>'outs'='1'and s->'pa'='null'::jsonb from dd));
-- Separate typed sport configuration, same initial state/reducer.
select pg_temp.check('Softball shared initializer','SPORT',(select boss_private.diamond_initial(c||'{"sport":"softball","era_innings":7}')=boss_private.diamond_initial(c)from dd));
select pg_temp.denied('wrong-sport DP/FLEX','select boss_private.diamond_initial(c||''{"dp_flex":"foundation_only"}'')from dd','PT422');
select pg_temp.denied('wrong engine sport','select boss_private.diamond_initial(c||''{"sport":"soccer"}'')from dd','PT422');
select pg_temp.check('Baseball required profiles','PROFILE',boss_private.tracking_selection('baseball','score_only')->'enabled'?&array['play_state','inning_state','runner_state','participation']);
select pg_temp.check('Softball pitch coverage dependencies','PROFILE',boss_private.tracking_selection('softball','custom','["pitch_detail"]')->'enabled'?&array['pitches','strikes','strike_percentage']);
select pg_temp.denied('wrong-sport tracking key','select boss_private.tracking_selection(''baseball'',''custom'',''["kills"]'')','PT422');
select count(*)passed_assertions from pg_temp.phase5a_assertions;
rollback;
