begin;set local statement_timeout='8s';
\ir phase6b/fixture.sql
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.rb('definition.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'source_organization_id',pg_temp.f('org'),'team_id',pg_temp.f('falcons'),'season_id',pg_temp.f('season'),'product','records','source_kind','athlete_game','name','Synthetic scope-isolated record','metric_key','home_runs','metric_kind','count','direction','high','qualification','{}'::jsonb),'record');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('records','record'),'whole-scope');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('records','record',jsonb_build_object('group_id',pg_temp.rb_id('division'))),'division-scope');
select pg_temp.check('whole-edition current record remains after group rebuild','SCOPE',public.boss_ranking_read(pg_temp.rb_q('records','record'))->'rows'->0 @>'{"value":1,"current_holder":true}');
select pg_temp.check('group current record belongs to its own scope','SCOPE',public.boss_ranking_read(pg_temp.rb_q('records','record',jsonb_build_object('group_id',pg_temp.rb_id('division'))))->'rows'->0 @>'{"value":1,"current_holder":true}');
select pg_temp.check('whole history contains exactly its own recognition','HISTORY',jsonb_array_length(public.boss_ranking_read(pg_temp.rb_q('records','record','{"history":true}'))->'rows')=1);
select pg_temp.check('division history contains exactly its own recognition','HISTORY',jsonb_array_length(public.boss_ranking_read(pg_temp.rb_q('records','record',jsonb_build_object('group_id',pg_temp.rb_id('division'),'history',true)))->'rows')=1);
reset role;
select pg_temp.check('two current holders isolated by scope key','RELATIONAL',(select count(*)=2 from public.record_current_holders where definition_id=pg_temp.rb_id('record')));
select pg_temp.denied('cross-scope candidate pointer violates FK',format('update public.record_current_holders set candidate_id=(select id from public.ranking_candidates where scope_id=%L limit 1)where scope_id=%L',pg_temp.rb_id('division-scope'),pg_temp.rb_id('whole-scope')),'23503');
select pg_temp.denied('cross-scope recognition pointer violates FK',format('update public.record_current_holders set event_id=(select id from public.record_events where scope_id=%L limit 1)where scope_id=%L',pg_temp.rb_id('division-scope'),pg_temp.rb_id('whole-scope')),'23503');
select count(*)passed_assertions from pg_temp.phase5a_assertions;rollback;
