-- Bounded synthetic append/read measurements. No production load/SLA claim.
begin;
\ir phase5b/fixture.sql
create temp table bb_performance(volume int primary key,append_elapsed_ms numeric,append_per_event_ms numeric,box_projection_ms numeric,game_read_ms numeric,play_count int);
grant select,insert on bb_performance to authenticated;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.bb_create('bb-volume','internal',true,2,false);
do $$declare n int;previous int:=0;started timestamptz;box_started timestamptz;read_started timestamptz;append_ms numeric;box_ms numeric;read_ms numeric;payload jsonb;begin
 foreach n in array array[10,100,1000] loop
  started:=clock_timestamp();
  for i in previous+1..n loop perform pg_temp.bb_event('bb-volume','made_ft','primary',1,'volume-ft-'||i);end loop;
  append_ms:=extract(epoch from(clock_timestamp()-started))*1000;
  box_started:=clock_timestamp();perform pg_temp.bb_box('bb-volume');box_ms:=extract(epoch from(clock_timestamp()-box_started))*1000;
  read_started:=clock_timestamp();payload:=pg_temp.bb_detail('bb-volume');read_ms:=extract(epoch from(clock_timestamp()-read_started))*1000;
  perform pg_temp.check('bounded box score exact total at '||n,'VOLUME',exists(select 1 from jsonb_array_elements(payload->'teams')t where t->>'side'='primary' and t->>'points'=n::text and t->>'ftm'=n::text and t->>'fta'=n::text));
  perform pg_temp.check('bounded play collection at '||n,'VOLUME',jsonb_array_length(payload->'plays')<=500);
  if n=1000 then perform pg_temp.check('play cap does not truncate full stat derivation','VOLUME',(payload->>'more_plays')::boolean and jsonb_array_length(payload->'plays')=500);end if;
  insert into bb_performance values(n,round(append_ms,3),round(append_ms/(n-previous),3),round(box_ms,3),round(read_ms,3),jsonb_array_length(payload->'plays'));
  previous:=n;
 end loop;
end$$;
reset role;
select pg_temp.check('no notification emitted for high-frequency basketball plays','NOTIFICATIONS',not exists(select 1 from public.notification_events e join public.game_operations o on o.id=e.source_id where o.game_id=pg_temp.bb_game('bb-volume') and o.operation like 'basketball.%'));
select pg_temp.check('volume events retain complete canonical sequence','LEDGER',(select count(*)=max(sequence) and min(sequence)=1 from public.game_operations where game_id=pg_temp.bb_game('bb-volume')));
select count(*) as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
select volume,append_elapsed_ms,append_per_event_ms,box_projection_ms,game_read_ms,play_count from bb_performance order by volume;
rollback;
