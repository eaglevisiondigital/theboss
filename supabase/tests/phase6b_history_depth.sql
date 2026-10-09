-- Disposable synthetic history-depth shape. No statistical source is reclassified
-- or edited; the generated chronology benchmark does not claim 500 native games.
begin;
set local statement_timeout='8s';
\ir phase6b/fixture.sql
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.rb('definition.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'source_organization_id',pg_temp.f('org'),'team_id',pg_temp.f('falcons'),'season_id',pg_temp.f('season'),'product','records','source_kind','athlete_career','name','Synthetic history-depth record','metric_key','home_runs','metric_kind','count','direction','high','qualification','{}'::jsonb),'definition');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('records','definition'),'scope');
reset role;
create temp table history_measure(started_at timestamptz,completed_at timestamptz,measurement jsonb);
insert into history_measure(started_at)values(clock_timestamp());
update history_measure set measurement=boss_private.ranking_candidate_measure((select d from public.ranking_definitions d where id=pg_temp.rb_id('definition')),
(select jsonb_agg(src.payload||jsonb_build_object('performance_at',clock_timestamp()-interval'1 day'+n*interval'1 second')order by n)from boss_private.ranking_contributions(pg_temp.rb_id('definition'))src cross join generate_series(1,500)n where src.subject_key=pg_temp.f('child1')::text),500);
update history_measure set completed_at=clock_timestamp();
select pg_temp.check('500-source history uses Phase6A reducer value','HISTORY_DEPTH',(select measurement @>'{"value":500,"state":"qualified"}'from history_measure));
select pg_temp.check('history source proof retains all 500 sources','PROVENANCE',(select jsonb_array_length(measurement->'source_manifest'->'sources')=500 from history_measure));
-- Audited recognition paging at meaningful historical depth.
do $$declare ev public.record_events;prior uuid;gen bigint;scope uuid:=pg_temp.rb_id('scope');begin
select *into ev from public.record_events where definition_id=pg_temp.rb_id('definition')limit 1;prior:=ev.id;
for gen in 1..500 loop prior:=boss_private.ranking_record_event(ev.definition_id,ev.subject_key,'restored',ev.value,ev.achieved_at,ev.source_manifest,ev.qualification,gen,prior,scope);end loop;end$$;
set local role authenticated;select pg_temp.actor('admin');
do $$declare q jsonb:=pg_temp.rb_q('records','definition','{"limit":100,"history":true}');r jsonb;seen int:=0;pages int:=0;begin
loop r:=public.boss_ranking_read(q);pages:=pages+1;seen:=seen+jsonb_array_length(r->'rows');exit when r->>'next_cursor'is null;q:=pg_temp.rb_q('records','definition',jsonb_build_object('limit',100,'history',true,'cursor',r->'next_cursor'));end loop;
perform pg_temp.check('immutable record history six bounded pages','PAGINATION',seen=501 and pages=6);end$$;
reset role;
select count(*)passed_assertions from pg_temp.phase5a_assertions;
select round(1000*extract(epoch from completed_at-started_at),2)history_measurement_ms from history_measure;
rollback;
