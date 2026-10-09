-- Synthetic workload shapes on a rollback-only disposable database. Cloned
-- source rows measure volume; native lifecycle truth is tested in separate suites.
begin;
set local statement_timeout='8s';
\ir phase6b/fixture.sql
create temp table rb_timings(label text,elapsed_ms numeric);
create function pg_temp.timed(label text,statement text)returns void language plpgsql as $$declare started timestamptz:=clock_timestamp();begin execute statement;insert into rb_timings values(label,1000*extract(epoch from clock_timestamp()-started));end$$;
-- 500 explicit team entries, no product limit or invented implicit affiliation.
insert into public.teams(id,organization_id,parent_unit_id,season_id,name,slug,status,visibility)
select pg_temp.f('volume-team-'||n),pg_temp.f('org'),pg_temp.f('unit'),pg_temp.f('season'),'Synthetic volume team '||n,'synthetic-volume-team-'||n,'active','member'from generate_series(1,498)n;
insert into public.competition_entries(edition_id,team_organization_id,team_id,season_id,status,approved_by_person_id)
select pg_temp.rb_id('edition'),pg_temp.f('org'),pg_temp.f('volume-team-'||n),pg_temp.f('season'),'active',pg_temp.f('admin')from generate_series(1,498)n;
select pg_temp.timed('500-entry raw standings refresh',format('select public.boss_ranking_mutate(%L::jsonb)',jsonb_build_object('action','ranking.rebuild','request_id',gen_random_uuid(),'input',pg_temp.rb_q())))from(select pg_temp.actor('admin'))as actor;
select pg_temp.check('500 explicit standings rows materialized','SCALE',(select count(*)=500 from public.standings_rows where scope_id=(select id from public.ranking_scopes where edition_id=pg_temp.rb_id('edition')and product='standings')));
-- Exercise the actual signed bounded cursor contract, not a LIMIT-only surrogate.
do $$declare q jsonb:=pg_temp.rb_q('standings',null,'{"limit":100}');r jsonb;pages int:=0;seen int:=0;begin
loop r:=public.boss_ranking_read(q);pages:=pages+1;seen:=seen+jsonb_array_length(r->'rows');exit when r->>'next_cursor'is null;q:=pg_temp.rb_q('standings',null,jsonb_build_object('limit',100,'cursor',r->'next_cursor'));end loop;
perform pg_temp.check('500 entries across five bounded pages','PAGINATION',seen=500 and pages=5);end$$;
-- Repair official sealed Phase 6A dependencies before workload expansion.
select boss_private.stat_refresh(pg_temp.ff_game('ranking-game'));
insert into public.people(id,display_name)select pg_temp.f('volume-person-'||n),'Synthetic workload athlete '||n from generate_series(1,10000)n;
insert into public.participants(id,person_id)select pg_temp.f('volume-participant-'||n),pg_temp.f('volume-person-'||n)from generate_series(1,10000)n;
insert into public.game_roster_snapshots(id,organization_id,game_id,revision,team_id,participant_id,person_id,display_name,availability,captured_by_person_id)
select pg_temp.f('volume-roster-'||n),pg_temp.f('org'),pg_temp.ff_game('ranking-game'),g.roster_revision,pg_temp.f('falcons'),pg_temp.f('volume-participant-'||n),pg_temp.f('volume-person-'||n),'Synthetic workload athlete '||n,'attending',pg_temp.f('admin')from generate_series(1,10000)n cross join public.games g where g.id=pg_temp.ff_game('ranking-game');
insert into public.stat_game_contributions(organization_id,game_id,finalization_id,epoch,roster_revision,side,team_id,roster_id,person_id,participant_id,season_id,sport_key,definition_version,engine_version,classification_id,classification,source_stat_id,tracking_snapshot_id,components,coverage,participation,era_basis_innings)
select c.organization_id,c.game_id,c.finalization_id,c.epoch,c.roster_revision,c.side,c.team_id,pg_temp.f('volume-roster-'||n),pg_temp.f('volume-person-'||n),pg_temp.f('volume-participant-'||n),c.season_id,c.sport_key,c.definition_version,c.engine_version,c.classification_id,c.classification,c.source_stat_id,c.tracking_snapshot_id,c.components,c.coverage,c.participation,c.era_basis_innings
from public.stat_game_contributions c cross join generate_series(1,10000)n where c.game_id=pg_temp.ff_game('ranking-game')and c.person_id=pg_temp.f('child1');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.rb('definition.create',jsonb_build_object('edition_id',pg_temp.rb_id('edition'),'source_organization_id',pg_temp.f('org'),'team_id',pg_temp.f('falcons'),'season_id',pg_temp.f('season'),'product','leaderboard','source_kind','athlete_season','name','Synthetic 10000 candidate workload','metric_key','home_runs','metric_kind','count','direction','high','qualification','{}'::jsonb),'volume-definition');
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'),'volume-scope');
reset role;
select pg_temp.check('bounded first batch does not publish partial pool','BATCH',(select state='refreshing'and published_generation=0 from public.ranking_scopes where id=pg_temp.rb_id('volume-scope')));
-- Each rebuild is a separate request below the unchanged eight-second timeout.
set local role authenticated;select pg_temp.actor('admin');
select clock_timestamp() batch_start_0 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',0*0+1000*extract(epoch from clock_timestamp()-:'batch_start_0'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_1 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',1*0+1000*extract(epoch from clock_timestamp()-:'batch_start_1'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_2 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',2*0+1000*extract(epoch from clock_timestamp()-:'batch_start_2'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_3 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',3*0+1000*extract(epoch from clock_timestamp()-:'batch_start_3'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_4 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',4*0+1000*extract(epoch from clock_timestamp()-:'batch_start_4'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_5 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',5*0+1000*extract(epoch from clock_timestamp()-:'batch_start_5'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_6 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',6*0+1000*extract(epoch from clock_timestamp()-:'batch_start_6'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_7 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',7*0+1000*extract(epoch from clock_timestamp()-:'batch_start_7'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_8 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',8*0+1000*extract(epoch from clock_timestamp()-:'batch_start_8'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_9 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',9*0+1000*extract(epoch from clock_timestamp()-:'batch_start_9'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_10 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',10*0+1000*extract(epoch from clock_timestamp()-:'batch_start_10'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_11 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',11*0+1000*extract(epoch from clock_timestamp()-:'batch_start_11'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_12 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',12*0+1000*extract(epoch from clock_timestamp()-:'batch_start_12'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_13 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',13*0+1000*extract(epoch from clock_timestamp()-:'batch_start_13'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_14 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',14*0+1000*extract(epoch from clock_timestamp()-:'batch_start_14'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_15 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',15*0+1000*extract(epoch from clock_timestamp()-:'batch_start_15'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_16 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',16*0+1000*extract(epoch from clock_timestamp()-:'batch_start_16'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_17 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',17*0+1000*extract(epoch from clock_timestamp()-:'batch_start_17'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_18 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',18*0+1000*extract(epoch from clock_timestamp()-:'batch_start_18'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_19 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',19*0+1000*extract(epoch from clock_timestamp()-:'batch_start_19'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_20 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',20*0+1000*extract(epoch from clock_timestamp()-:'batch_start_20'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_21 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',21*0+1000*extract(epoch from clock_timestamp()-:'batch_start_21'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_22 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',22*0+1000*extract(epoch from clock_timestamp()-:'batch_start_22'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_23 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',23*0+1000*extract(epoch from clock_timestamp()-:'batch_start_23'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_24 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',24*0+1000*extract(epoch from clock_timestamp()-:'batch_start_24'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_25 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',25*0+1000*extract(epoch from clock_timestamp()-:'batch_start_25'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_26 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',26*0+1000*extract(epoch from clock_timestamp()-:'batch_start_26'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_27 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',27*0+1000*extract(epoch from clock_timestamp()-:'batch_start_27'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_28 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',28*0+1000*extract(epoch from clock_timestamp()-:'batch_start_28'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_29 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',29*0+1000*extract(epoch from clock_timestamp()-:'batch_start_29'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_30 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',30*0+1000*extract(epoch from clock_timestamp()-:'batch_start_30'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_31 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',31*0+1000*extract(epoch from clock_timestamp()-:'batch_start_31'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_32 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',32*0+1000*extract(epoch from clock_timestamp()-:'batch_start_32'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_33 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',33*0+1000*extract(epoch from clock_timestamp()-:'batch_start_33'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_34 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',34*0+1000*extract(epoch from clock_timestamp()-:'batch_start_34'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_35 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',35*0+1000*extract(epoch from clock_timestamp()-:'batch_start_35'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_36 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',36*0+1000*extract(epoch from clock_timestamp()-:'batch_start_36'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_37 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',37*0+1000*extract(epoch from clock_timestamp()-:'batch_start_37'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_38 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',38*0+1000*extract(epoch from clock_timestamp()-:'batch_start_38'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_39 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',39*0+1000*extract(epoch from clock_timestamp()-:'batch_start_39'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_40 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',40*0+1000*extract(epoch from clock_timestamp()-:'batch_start_40'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_41 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',41*0+1000*extract(epoch from clock_timestamp()-:'batch_start_41'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_42 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',42*0+1000*extract(epoch from clock_timestamp()-:'batch_start_42'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_43 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',43*0+1000*extract(epoch from clock_timestamp()-:'batch_start_43'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_44 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',44*0+1000*extract(epoch from clock_timestamp()-:'batch_start_44'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_45 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',45*0+1000*extract(epoch from clock_timestamp()-:'batch_start_45'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_46 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',46*0+1000*extract(epoch from clock_timestamp()-:'batch_start_46'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_47 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',47*0+1000*extract(epoch from clock_timestamp()-:'batch_start_47'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_48 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',48*0+1000*extract(epoch from clock_timestamp()-:'batch_start_48'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_49 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',49*0+1000*extract(epoch from clock_timestamp()-:'batch_start_49'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_50 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',50*0+1000*extract(epoch from clock_timestamp()-:'batch_start_50'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_51 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',51*0+1000*extract(epoch from clock_timestamp()-:'batch_start_51'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_52 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',52*0+1000*extract(epoch from clock_timestamp()-:'batch_start_52'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_53 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',53*0+1000*extract(epoch from clock_timestamp()-:'batch_start_53'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_54 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',54*0+1000*extract(epoch from clock_timestamp()-:'batch_start_54'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_55 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',55*0+1000*extract(epoch from clock_timestamp()-:'batch_start_55'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_56 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',56*0+1000*extract(epoch from clock_timestamp()-:'batch_start_56'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_57 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',57*0+1000*extract(epoch from clock_timestamp()-:'batch_start_57'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_58 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',58*0+1000*extract(epoch from clock_timestamp()-:'batch_start_58'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_59 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',59*0+1000*extract(epoch from clock_timestamp()-:'batch_start_59'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_60 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',60*0+1000*extract(epoch from clock_timestamp()-:'batch_start_60'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_61 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',61*0+1000*extract(epoch from clock_timestamp()-:'batch_start_61'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_62 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',62*0+1000*extract(epoch from clock_timestamp()-:'batch_start_62'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_63 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',63*0+1000*extract(epoch from clock_timestamp()-:'batch_start_63'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_64 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',64*0+1000*extract(epoch from clock_timestamp()-:'batch_start_64'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_65 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',65*0+1000*extract(epoch from clock_timestamp()-:'batch_start_65'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_66 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',66*0+1000*extract(epoch from clock_timestamp()-:'batch_start_66'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_67 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',67*0+1000*extract(epoch from clock_timestamp()-:'batch_start_67'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_68 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',68*0+1000*extract(epoch from clock_timestamp()-:'batch_start_68'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_69 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',69*0+1000*extract(epoch from clock_timestamp()-:'batch_start_69'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_70 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',70*0+1000*extract(epoch from clock_timestamp()-:'batch_start_70'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_71 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',71*0+1000*extract(epoch from clock_timestamp()-:'batch_start_71'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_72 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',72*0+1000*extract(epoch from clock_timestamp()-:'batch_start_72'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_73 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',73*0+1000*extract(epoch from clock_timestamp()-:'batch_start_73'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_74 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',74*0+1000*extract(epoch from clock_timestamp()-:'batch_start_74'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_75 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',75*0+1000*extract(epoch from clock_timestamp()-:'batch_start_75'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_76 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',76*0+1000*extract(epoch from clock_timestamp()-:'batch_start_76'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_77 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',77*0+1000*extract(epoch from clock_timestamp()-:'batch_start_77'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_78 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',78*0+1000*extract(epoch from clock_timestamp()-:'batch_start_78'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_79 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',79*0+1000*extract(epoch from clock_timestamp()-:'batch_start_79'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_80 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',80*0+1000*extract(epoch from clock_timestamp()-:'batch_start_80'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_81 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',81*0+1000*extract(epoch from clock_timestamp()-:'batch_start_81'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_82 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',82*0+1000*extract(epoch from clock_timestamp()-:'batch_start_82'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_83 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',83*0+1000*extract(epoch from clock_timestamp()-:'batch_start_83'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_84 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',84*0+1000*extract(epoch from clock_timestamp()-:'batch_start_84'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_85 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',85*0+1000*extract(epoch from clock_timestamp()-:'batch_start_85'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_86 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',86*0+1000*extract(epoch from clock_timestamp()-:'batch_start_86'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_87 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',87*0+1000*extract(epoch from clock_timestamp()-:'batch_start_87'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_88 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',88*0+1000*extract(epoch from clock_timestamp()-:'batch_start_88'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_89 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',89*0+1000*extract(epoch from clock_timestamp()-:'batch_start_89'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_90 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',90*0+1000*extract(epoch from clock_timestamp()-:'batch_start_90'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_91 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',91*0+1000*extract(epoch from clock_timestamp()-:'batch_start_91'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_92 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',92*0+1000*extract(epoch from clock_timestamp()-:'batch_start_92'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_93 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',93*0+1000*extract(epoch from clock_timestamp()-:'batch_start_93'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_94 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',94*0+1000*extract(epoch from clock_timestamp()-:'batch_start_94'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_95 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',95*0+1000*extract(epoch from clock_timestamp()-:'batch_start_95'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_96 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',96*0+1000*extract(epoch from clock_timestamp()-:'batch_start_96'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_97 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',97*0+1000*extract(epoch from clock_timestamp()-:'batch_start_97'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_98 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',98*0+1000*extract(epoch from clock_timestamp()-:'batch_start_98'::timestamptz));set local role authenticated;
select clock_timestamp() batch_start_99 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',99*0+1000*extract(epoch from clock_timestamp()-:'batch_start_99'::timestamptz));set local role authenticated;
-- Publication must remain bounded even without favorable join estimates.
set local enable_hashjoin=off;set local enable_mergejoin=off;
select clock_timestamp() batch_start_100 \gset
select pg_temp.rb('ranking.rebuild',pg_temp.rb_q('leaderboard','volume-definition'));
reset role;insert into rb_timings values('100-candidate rebuild batch',100*0+1000*extract(epoch from clock_timestamp()-:'batch_start_100'::timestamptz));set local role authenticated;
set local enable_hashjoin=on;set local enable_mergejoin=on;
-- Native private pages remain bounded even with adverse label-join choices.
set local enable_hashjoin=off;set local enable_mergejoin=off;
select coalesce((select calls from pg_stat_xact_user_functions where funcid='boss_private.games_can_view(uuid,public.games,jsonb)'::regprocedure),0) privacy_calls_before \gset
select clock_timestamp() private_read_start \gset
select pg_temp.check('complete 10000-plus canonical candidate pool','SCALE',jsonb_array_length(public.boss_ranking_read(pg_temp.rb_q('leaderboard','volume-definition','{"limit":100}'))->'rows')=100);
select pg_temp.check('one distinct game authorization does not expand to athlete pool','PRIVACY_SCALE',coalesce((select calls from pg_stat_xact_user_functions where funcid='boss_private.games_can_view(uuid,public.games,jsonb)'::regprocedure),0)-:'privacy_calls_before'::bigint between 1 and 20);
reset role;
-- The trusted oracle reads closed raw projections; native requests keep the
-- authenticated Data API role. Do not grant raw business-table access to tests.
create temp table rb_private_page_oracle as
select (select jsonb_build_object('scope_id',rc.scope_id,'generation',rc.built_generation,'rank',coalesce(rc.rank,2147483647),'id',rc.subject_key)
 from public.ranking_candidates rc where rc.scope_id=pg_temp.rb_id('volume-scope')order by coalesce(rc.rank,2147483647),rc.subject_key offset 4999 limit 1)cursor,
 (select jsonb_agg(to_jsonb(subject_key)order by position)from
 (select subject_key,row_number()over(order by coalesce(rank,2147483647),subject_key)position from public.ranking_candidates where scope_id=pg_temp.rb_id('volume-scope'))oracle where position between 5001 and 5100)expected;
grant select on rb_private_page_oracle to authenticated;
set local role authenticated;
do $$declare first jsonb;second jsonb;middle jsonb;cursor jsonb;expected jsonb;begin
 first:=public.boss_ranking_read(pg_temp.rb_q('leaderboard','volume-definition','{"limit":100}'));
 second:=public.boss_ranking_read(pg_temp.rb_q('leaderboard','volume-definition',jsonb_build_object('limit',100,'cursor',first->'next_cursor')));
 select o.cursor,o.expected into cursor,expected from pg_temp.rb_private_page_oracle o;
 middle:=public.boss_ranking_read(pg_temp.rb_q('leaderboard','volume-definition',jsonb_build_object('limit',100,'cursor',cursor)));
 perform pg_temp.check('native next and deep cursor pages match independent ordered cohort','PAGINATION',jsonb_array_length(second->'rows')=100
 and not exists(select 1 from jsonb_array_elements(first->'rows')a join jsonb_array_elements(second->'rows')b on a->>'id'=b->>'id')
 and(select jsonb_agg(value->'id'order by ordinality)from jsonb_array_elements(middle->'rows')with ordinality)=expected);
end$$;
set local enable_hashjoin=on;set local enable_mergejoin=on;
reset role;
insert into rb_timings values('100-row native private read',1000*extract(epoch from clock_timestamp()-:'private_read_start'::timestamptz));
select pg_temp.check('whole source pool published atomically','SCALE',(select state='current'from public.ranking_scopes where id=pg_temp.rb_id('volume-scope'))and(select count(*)>=10000 from public.ranking_candidates where scope_id=pg_temp.rb_id('volume-scope')));
select pg_temp.check('every rebuild request under unchanged eight-second timeout','TIMEOUT',not exists(select 1 from rb_timings where elapsed_ms>=8000));
select pg_temp.check('every published rank equals whole-cohort competition rank','RANK',not exists(select 1 from(select rank,rank()over(order by value desc)::int expected from public.ranking_candidates where scope_id=pg_temp.rb_id('volume-scope')and qualification_state='qualified')ranked where rank is distinct from expected));
select count(*)passed_assertions from pg_temp.phase5a_assertions;
select label,count(*)requests,round(min(elapsed_ms),2)min_ms,round(max(elapsed_ms),2)max_ms,round(avg(elapsed_ms),2)mean_ms from rb_timings group by label order by label;
rollback;
