begin;
set local statement_timeout='8s';
\ir phase6d/fixture.sql
create temp table phase6d_timings(size integer primary key,milliseconds numeric not null)on commit drop;
create temp table phase6d_operation_timings(label text primary key,milliseconds numeric not null)on commit drop;
grant select,insert on phase6d_timings to authenticated;
grant select,insert on phase6d_operation_timings to authenticated;
insert into public.teams(id,organization_id,parent_unit_id,season_id,name,slug,status,visibility)
select md5('phase6d-volume-team-'||n)::uuid,pg_temp.f('org'),pg_temp.f('unit'),pg_temp.f('season'),'Synthetic Volume Team '||n,'phase6d-volume-'||n,'active','member'from generate_series(1,64)n;
insert into public.competition_entries(id,edition_id,team_organization_id,team_id,season_id,status,approved_by_person_id)
select md5('phase6d-volume-entry-'||n)::uuid,pg_temp.rb_id('edition'),pg_temp.f('org'),md5('phase6d-volume-team-'||n)::uuid,pg_temp.f('season'),'active',pg_temp.f('admin')from generate_series(1,64)n;
set local role authenticated;select pg_temp.actor('admin');
do $$declare n int;b uuid;started timestamptz;seeds jsonb;begin foreach n in array array[16,32,64]loop started:=clock_timestamp();b:=(public.boss_tournament_mutate(jsonb_build_object('action','bracket.create','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'name','Synthetic '||n||'-team bracket','bracket_size',n)))->>'id')::uuid;select jsonb_agg(jsonb_build_object('seed',x,'entry_id',md5('phase6d-volume-entry-'||x)::uuid)order by x)into seeds from generate_series(1,n)x;perform public.boss_tournament_mutate(jsonb_build_object('action','bracket.seed','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',b,'expected_version',1,'source_kind','manual','seeds',seeds,'reason','Disposable scale validation')));insert into pg_temp.phase6d_timings values(n,1000*extract(epoch from clock_timestamp()-started));insert into pg_temp.phase6d_ids values('volume-'||n,b);end loop;end$$;
reset role;
select pg_temp.check('16-team bracket exact match count','SCALE',(select count(*)=15 from public.tournament_matches where bracket_id=pg_temp.td_id('volume-16')));
select pg_temp.check('32-team bracket exact match count','SCALE',(select count(*)=31 from public.tournament_matches where bracket_id=pg_temp.td_id('volume-32')));
select pg_temp.check('64-team bracket exact match count','SCALE',(select count(*)=63 from public.tournament_matches where bracket_id=pg_temp.td_id('volume-64')));
select pg_temp.check('all scale builds under local bound','PERFORMANCE',(select bool_and(milliseconds<4000)from phase6d_timings));
insert into pg_temp.phase6d_ids select'performance-match',id from public.tournament_matches where bracket_id=pg_temp.td_id('bracket')and round_number=1 and match_number=1;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.td('match.link_game',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'match_id',pg_temp.td_id('performance-match'),'expected_version',1,'game_id',(select id from pg_temp.phase5a_games where label='tournament-first')));
reset role;
update public.games set status='final',roster_revision=1,started_at=clock_timestamp()-interval'2 hours',finalized_at=clock_timestamp(),finalized_by_person_id=pg_temp.f('admin'),winner_side='primary',tied=false,primary_score=2,opponent_score=0,final_primary_score=2,final_opponent_score=0,finalization_count=1 where id=(select id from pg_temp.phase5a_games where label='tournament-first');
set local role authenticated;select pg_temp.actor('admin');
do $$declare started timestamptz;begin started:=clock_timestamp();perform public.boss_tournament_mutate(jsonb_build_object('action','result.process','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'match_id',pg_temp.td_id('performance-match'),'expected_version',2,'reason','Disposable advancement benchmark')));insert into pg_temp.phase6d_operation_timings values('official result advancement',1000*extract(epoch from clock_timestamp()-started));started:=clock_timestamp();perform public.boss_tournament_mutate(jsonb_build_object('action','projection.rebuild','request_id',gen_random_uuid(),'input',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('volume-64'),'expected_version',2)));insert into pg_temp.phase6d_operation_timings values('64-team projection rebuild',1000*extract(epoch from clock_timestamp()-started));end$$;
select pg_temp.check('64-team read bounded','PERFORMANCE',jsonb_array_length(public.boss_tournament_read(jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'bracket_id',pg_temp.td_id('volume-64')))->'matches')=63);
reset role;
select pg_temp.check('advancement and rebuild under local bound','PERFORMANCE',(select bool_and(milliseconds<2000)from phase6d_operation_timings));
select count(*)passed_assertions from pg_temp.phase5a_assertions;
select size,round(milliseconds,3)milliseconds from phase6d_timings order by size;
select label,round(milliseconds,3)milliseconds from phase6d_operation_timings order by label;
rollback;
