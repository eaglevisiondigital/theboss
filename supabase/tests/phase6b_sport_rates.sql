begin;set local statement_timeout='8s';
create temp table rb_assertions(label text primary key);
create function pg_temp.ok(label text,condition boolean)returns void language plpgsql as $$begin if condition is distinct from true then raise exception 'FAIL Phase6B %',label;end if;insert into rb_assertions values(label);end$$;
create temp table rate_oracles(sport text,metric text,expected numeric,components jsonb,basis int);
insert into rate_oracles values
('basketball','fg_percentage',25,'{"fgm":1,"fga":4}',null),('basketball','ft_percentage',40,'{"ftm":2,"fta":5}',null),('basketball','three_point_percentage',100::numeric/3,'{"tpm":1,"tpa":3}',null),('basketball','two_point_percentage',0,'{"fgm":1,"fga":4,"tpm":1,"tpa":3}',null),
('soccer','save_percentage',75,'{"saves":3,"goals_allowed":1}',null),('soccer','shots_on_goal_rate',40,'{"shots_on_goal":2,"shots":5}',null),
('football','completion_percentage',40,'{"passing_completions":2,"passing_attempts":5}',null),('football','passing_yards_per_attempt',2,'{"passing_yards":10,"passing_attempts":5}',null),('football','yards_per_carry',3,'{"rushing_yards":9,"rush_attempts":3}',null),('football','yards_per_reception',6,'{"receiving_yards":12,"receptions":2}',null),('football','punt_average',50,'{"punt_yards":100,"punts":2}',null),('football','field_goal_percentage',50,'{"field_goals_made":1,"field_goals_attempted":2}',null),('football','extra_point_percentage',200::numeric/3,'{"extra_points_made":2,"extra_points_attempted":3}',null),
('volleyball','hitting_percentage',0.3,'{"kills":4,"attack_errors":1,"attack_attempts":10}',null),
('baseball','avg',0.25,'{"hits":1,"ab":4}',9),('baseball','obp',0.4,'{"hits":1,"walks":1,"hbp":0,"ab":4,"sacrifice_flies":0}',9),('baseball','slg',1,'{"singles":0,"doubles":0,"triples":0,"home_runs":1,"ab":4}',9),('baseball','ops',1.4,'{"hits":1,"walks":1,"hbp":0,"ab":4,"sacrifice_flies":0,"singles":0,"doubles":0,"triples":0,"home_runs":1}',9),('baseball','whip',1.5,'{"walks_allowed":1,"hits_allowed":2,"outs_pitched":6}',9),('baseball','era',9,'{"earned_runs":2,"outs_pitched":6}',9),('baseball','strike_percentage',60,'{"strikes":6,"pitches":10}',9);
insert into rate_oracles select 'softball',metric,case metric when'era'then 7 else expected end,components,7 from rate_oracles where sport='baseball';
do $$declare o record;coverage jsonb;rows jsonb;r jsonb;first_key text;begin
for o in select *from rate_oracles loop
 select jsonb_object_agg(k,'tracked')into coverage from jsonb_object_keys(o.components)k;
 rows:=jsonb_build_array(jsonb_build_object('components',o.components,'coverage',coverage,'participation','{"confirmed":true}'::jsonb,'era_basis_innings',o.basis));
 r:=boss_private.ranking_measure(o.sport,rows,o.metric,'rate','{"thresholds":[{"type":"min_games","value":1}]}',false,1);
 perform pg_temp.ok(o.sport||':'||o.metric||':independent frozen formula',r->>'state'='qualified'and abs((r->>'value')::numeric-o.expected)<0.000001);
 first_key:=(boss_private.ranking_rate_keys(o.metric))[1];
 r:=boss_private.ranking_measure(o.sport,jsonb_set(rows,array['0','coverage',first_key],'"not_tracked"'),o.metric,'rate','{"thresholds":[{"type":"min_games","value":1}]}',false,1);
 perform pg_temp.ok(o.sport||':'||o.metric||':missing component is incomplete',r->>'state'='incomplete'and r->>'value'is null);
 r:=boss_private.ranking_measure(o.sport,rows,o.metric,'rate','{"thresholds":[{"type":"min_games","value":2}]}',false,1);
 perform pg_temp.ok(o.sport||':'||o.metric||':explicit sample minimum',r->>'state'='below_minimum');
end loop;end$$;
select count(*)passed_assertions from rb_assertions;rollback;
