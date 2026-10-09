-- Bounded disposable measurements, no production SLA/load claim.
begin;
\ir phase5c/fixture.sql
create temp table sc_performance(volume int primary key,append_elapsed_ms numeric,append_per_event_ms numeric,box_projection_ms numeric,game_read_ms numeric,play_count int);
grant select,insert on sc_performance to authenticated;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_create('volume','internal',true,2,false,1);
do $$declare n int;previous int:=0;started timestamptz;box_started timestamptz;read_started timestamptz;append_ms numeric;box_ms numeric;read_ms numeric;payload jsonb;begin
 foreach n in array array[10,100,1000]loop
  started:=clock_timestamp();for i in previous+1..n loop perform pg_temp.sc_event('volume','goal','primary',1,'volume-goal-'||i);end loop;
  append_ms:=extract(epoch from(clock_timestamp()-started))*1000;
  box_started:=clock_timestamp();perform pg_temp.sc_box('volume');box_ms:=extract(epoch from(clock_timestamp()-box_started))*1000;
  read_started:=clock_timestamp();payload:=pg_temp.sc_detail('volume');read_ms:=extract(epoch from(clock_timestamp()-read_started))*1000;
  perform pg_temp.check('bounded independent shot/score total at '||n,'VOLUME',exists(select 1 from jsonb_array_elements(payload->'teams')t where t->>'side'='primary'and t->>'goals'=n::text and t->>'shots'=n::text and t->>'shots_on_goal'=n::text));
  perform pg_temp.check('bounded Soccer play collection at '||n,'VOLUME',jsonb_array_length(payload->'plays')<=500);
  perform pg_temp.check('private operational context has exact 500-fact bound at '||n,'VOLUME',jsonb_array_length(payload->'entry_plays')=least(n,500));
  if n=1000 then perform pg_temp.check('play limit does not truncate full stat derivation','VOLUME',(payload->>'more_plays')::boolean and jsonb_array_length(payload->'plays')=500);end if;
  insert into sc_performance values(n,round(append_ms,3),round(append_ms/(n-previous),3),round(box_ms,3),round(read_ms,3),jsonb_array_length(payload->'plays'));previous:=n;
 end loop;
end$$;
select pg_temp.sc_finish('volume');
create temp table sc_finalize_performance(finalization_ms numeric,stat_rows int);grant select,insert on sc_finalize_performance to authenticated;
do $$declare started timestamptz;begin started:=clock_timestamp();perform pg_temp.game_op('game.finalize','volume');insert into sc_finalize_performance values(round(extract(epoch from(clock_timestamp()-started))*1000,3),null);end$$;
reset role;
update sc_finalize_performance set stat_rows=(select count(*)from public.game_soccer_final_stats where game_id=pg_temp.sc_game('volume'));
select pg_temp.check('1000-goal finalization seals all independent goals','VOLUME',(select goals=1000 and shots=1000 and shots_on_goal=1000 from public.game_soccer_final_stats where game_id=pg_temp.sc_game('volume')and side='primary'and roster_id is null));
select pg_temp.check('no high-frequency sport notification fanout','NOTIFICATIONS',not exists(select 1 from public.notification_events e join public.game_operations o on o.id=e.source_id where o.game_id=pg_temp.sc_game('volume')and o.operation like 'soccer.%'));
select pg_temp.check('volume uses complete canonical sequence','LEDGER',(select count(*)=max(sequence)and min(sequence)=1 from public.game_operations where game_id=pg_temp.sc_game('volume')));
select count(*)as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
select volume,append_elapsed_ms,append_per_event_ms,box_projection_ms,game_read_ms,play_count from sc_performance order by volume;
select finalization_ms,stat_rows from sc_finalize_performance;
rollback;
