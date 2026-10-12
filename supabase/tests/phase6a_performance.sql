-- Synthetic projection workload; no real people/data and no statement timeout increase.
begin;
\ir phase5a/fixture.sql
create temp table intelligence_bench as
select jsonb_agg(jsonb_build_object('components',(select jsonb_object_agg(k,to_jsonb(i%11))from unnest(boss_private.football_stat_keys())k)||jsonb_build_object('kills',i%11,'attack_errors',i%3,'attack_attempts',20),'coverage',(select jsonb_object_agg(k,'tracked')from unnest(boss_private.football_stat_keys())k)||'{"kills":"tracked","attack_errors":"tracked","attack_attempts":"tracked"}'::jsonb,'participation','{"confirmed":true,"coverage":"partial"}'::jsonb)order by i)rows from generate_series(1,2000)i;
do $$declare started timestamptz:=clock_timestamp();v jsonb;begin
 select boss_private.stat_reduce(rows)into v from intelligence_bench;
 if(v->'kills'->>'complete_games')::int<>2000 then raise exception 'Projection benchmark lost contributions';end if;
 if clock_timestamp()-started>interval '8 seconds'then raise exception 'Projection reduction exceeds bounded benchmark';end if;
 perform set_config('boss.phase6a_benchmark_ms',(extract(epoch from(clock_timestamp()-started))*1000)::text,true);
end$$;
select pg_temp.check('2000 contribution reducer fits unchanged budget','PERFORMANCE',current_setting('boss.phase6a_benchmark_ms')::numeric<8000);
select pg_temp.check('2000 source joint rate includes all complete cohorts','PERFORMANCE',(select(boss_private.stat_rates('volleyball',rows)->'hitting_percentage'->>'complete_games')::int=2000 from intelligence_bench));
select current_setting('boss.phase6a_benchmark_ms') as reduction_ms;
select count(*)passed_assertions,current_setting('boss.phase6a_benchmark_ms')::numeric as reduction_ms from pg_temp.phase5a_assertions;
rollback;
