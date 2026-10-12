begin;
set local statement_timeout='8s';
\ir phase6e/fixture.sql
update public.organization_modules set configuration=configuration||'{"basketball_live_scoring":true,"basketball_stats":true,"soccer_live_scoring":true,"soccer_stats":true,"football_live_scoring":true,"football_stats":true,"volleyball_live_scoring":true,"volleyball_stats":true}'::jsonb where organization_id=pg_temp.f('org')and module_id=(select id from public.modules where key='sports');
-- Materialization load fixtures are disposable synthetic people, never hosted data.
insert into public.people(id,display_name)select pg_temp.f('pe-load-person-'||n),'Synthetic achievement load '||n from generate_series(1,500)n;
insert into public.participants(id,person_id)select pg_temp.f('pe-load-participant-'||n),pg_temp.f('pe-load-person-'||n)from generate_series(1,500)n;
insert into public.athlete_profiles(id,participant_id,person_id,visibility,created_by_person_id)select pg_temp.f('pe-load-profile-'||n),pg_temp.f('pe-load-participant-'||n),pg_temp.f('pe-load-person-'||n),'athlete_guardian',pg_temp.f('admin')from generate_series(1,500)n;
insert into public.stat_origin_summaries(organization_id,team_id,sport_key,season_id,person_id,generation,is_current,source_watermark,refreshed_at,summary)
select pg_temp.f('org'),pg_temp.f('falcons'),sport,pg_temp.f('season'),pg_temp.f('pe-load-person-'||n),1,true,'synthetic-load',clock_timestamp(),jsonb_build_object('source_game_count',1,'metrics',jsonb_build_object(metric,jsonb_build_object('complete_value',1,'complete_games',1,'partial_games',0,'legacy_unknown_games',0,'untracked_games',0)))from generate_series(1,500)n cross join(values('basketball','points'),('soccer','goals'),('football','rushing_yards'),('volleyball','kills'),('baseball','home_runs'),('softball','hits'))sports(sport,metric);
create temp table pe_performance_samples(name text,elapsed_ms numeric)on commit drop;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.pe_definition('load_baseball',pg_temp.pe_rule('Load baseball','{"threshold":2}'));select pg_temp.pe_definition('load_softball',pg_temp.pe_rule('Load softball','{"sport_key":"softball","metric_key":"hits","threshold":2}'));select pg_temp.pe_definition('load_basketball',pg_temp.pe_rule('Load basketball','{"sport_key":"basketball","metric_key":"points","threshold":2}'));select pg_temp.pe_definition('load_soccer',pg_temp.pe_rule('Load soccer','{"sport_key":"soccer","metric_key":"goals","threshold":2}'));select pg_temp.pe_definition('load_football',pg_temp.pe_rule('Load football','{"sport_key":"football","metric_key":"rushing_yards","threshold":2}'));select pg_temp.pe_definition('load_volleyball',pg_temp.pe_rule('Load volleyball','{"sport_key":"volleyball","metric_key":"kills","threshold":2}'));
do $$declare n int;begin for n in 1..24 loop perform pg_temp.pe_definition('load_additional_'||n,pg_temp.pe_rule('Synthetic additional load '||n,jsonb_build_object('threshold',2+n)));end loop;end$$;
reset role;
select pg_temp.check('many enabled definitions stay separately versioned','PERFORMANCE',(select count(*)>=30 from public.achievement_definitions));
-- Measure a single 50-subject work batch for each sport, not an unbounded render.
create function pg_temp.pe_measure(sport text)returns void language plpgsql as $$declare started timestamptz;rev public.achievement_definition_revisions;result jsonb;begin
 select ar.*into rev from public.achievement_definition_revisions ar join public.achievement_definitions d on d.current_revision_id=ar.id where d.id=pg_temp.pe_id('load_'||sport);
 started:=clock_timestamp();result:=boss_private.achievement_evaluate(rev,pg_temp.f('org'),pg_temp.f('admin'));insert into pe_performance_samples values(sport,extract(epoch from clock_timestamp()-started)*1000);
 perform pg_temp.check(sport||' bounded batch','PERFORMANCE',(result->>'processed')::int<=50 and result->>'has_more'='true');
end$$;
select pg_temp.pe_measure('baseball');select pg_temp.pe_measure('softball');select pg_temp.pe_measure('basketball');select pg_temp.pe_measure('soccer');select pg_temp.pe_measure('football');select pg_temp.pe_measure('volleyball');
select pg_temp.check('six sport workload stays below timeout','PERFORMANCE',(select bool_and(elapsed_ms<8000)from pe_performance_samples));
select pg_temp.check('500 persistent athletes and 3000 materialized origins','PERFORMANCE',(select count(*)=3000 from public.stat_origin_summaries where person_id in(select pg_temp.f('pe-load-person-'||n)from generate_series(1,500)n)));
select pg_temp.check('load fixture cannot fabricate uncrossed honors','PERFORMANCE',not exists(select 1 from public.achievement_recognitions r join public.achievement_definition_revisions d on d.id=r.definition_revision_id where d.threshold=2));
-- Incremental completion and rebuild use the same bounded source adapter.
set local role authenticated;select pg_temp.actor('admin');select pg_temp.pe_evaluate('load_baseball');select pg_temp.pe_evaluate('load_baseball',true);reset role;
select pg_temp.check('rebuild is current with no duplicate load recognition','REBUILD',(select w.state='current'and w.target_generation=w.published_generation from public.achievement_refresh_work w where w.definition_revision_id=pg_temp.pe_id('load_baseball')or w.definition_revision_id=(select current_revision_id from public.achievement_definitions where id=pg_temp.pe_id('load_baseball'))));
do $$begin raise notice 'Phase6E bounded performance milliseconds %',(select jsonb_object_agg(name,round(elapsed_ms,2))from pe_performance_samples);end$$;
select count(*)passed_assertions from pg_temp.phase5a_assertions;
rollback;
