-- Bounded disposable measurements. No hosted-load or production SLA claim.
begin;
\ir phase5d/fixture.sql
-- These adapters time the actual closed state/replay helpers; public PBP and
-- detail measurements below still invoke the real authorized Game Center RPC.
create function pg_temp.ff_field_projection(label text) returns jsonb language sql volatile security definer set search_path='' as $$
 select boss_private.football_state(s)->'field_state'from public.game_football_states s where s.game_id=pg_temp.ff_game(label)
$$;
create function pg_temp.ff_play_projection(label text) returns jsonb language sql volatile security definer set search_path='' as $$
 select boss_private.football_rebuild(pg_temp.ff_game(label))->'plays'
$$;
revoke all on function pg_temp.ff_field_projection(text),pg_temp.ff_play_projection(text)from public;
grant execute on function pg_temp.ff_field_projection(text),pg_temp.ff_play_projection(text)to authenticated;
create temp table ff_performance(volume int primary key,append_elapsed_ms numeric,append_per_play_ms numeric,append_rpc_max_ms numeric,field_projection_ms numeric,play_projection_ms numeric,pbp_game_read_ms numeric,box_projection_ms numeric,drive_projection_ms numeric,game_read_ms numeric,play_count int);
grant select,insert on ff_performance to authenticated;
set local role authenticated;select pg_temp.actor('admin');select pg_temp.ff_create('volume');
do $$declare n int;i int;previous int:=0;started timestamptz;sample timestamptz;append_ms numeric;one_append_ms numeric;append_max_ms numeric;field_ms numeric;play_ms numeric;pbp_ms numeric;box_ms numeric;drive_ms numeric;read_ms numeric;payload jsonb;field_payload jsonb;play_payload jsonb;pbp_payload jsonb;side text;begin
 foreach n in array array[10,100,1000]loop
  started:=clock_timestamp();append_max_ms:=0;
  for i in previous+1..n loop
   -- Four zero-yard downs alternate possession; no score or yardage is invented.
   side:=case when((i-1)/4)%2=0 then 'primary'else 'opponent'end;
   sample:=clock_timestamp();
   perform pg_temp.ff_play('volume','rush',side,jsonb_build_object('roster_id',pg_temp.ff_roster('volume',side,2),'yards',0),'volume-rush-'||i);
   one_append_ms:=extract(epoch from(clock_timestamp()-sample))*1000;append_max_ms:=greatest(append_max_ms,one_append_ms);
  end loop;
  append_ms:=extract(epoch from(clock_timestamp()-started))*1000;
  sample:=clock_timestamp();field_payload:=pg_temp.ff_field_projection('volume');field_ms:=extract(epoch from(clock_timestamp()-sample))*1000;
  sample:=clock_timestamp();play_payload:=pg_temp.ff_play_projection('volume');play_ms:=extract(epoch from(clock_timestamp()-sample))*1000;
  sample:=clock_timestamp();pbp_payload:=pg_temp.ff_detail('volume')->'plays';pbp_ms:=extract(epoch from(clock_timestamp()-sample))*1000;
  sample:=clock_timestamp();perform pg_temp.ff_box('volume');box_ms:=extract(epoch from(clock_timestamp()-sample))*1000;
  sample:=clock_timestamp();perform pg_temp.ff_drives('volume');drive_ms:=extract(epoch from(clock_timestamp()-sample))*1000;
  sample:=clock_timestamp();payload:=pg_temp.ff_detail('volume');read_ms:=extract(epoch from(clock_timestamp()-sample))*1000;
  perform pg_temp.check('every measured append completes below eight seconds at '||n,'PERFORMANCE',append_max_ms<8000);
  perform pg_temp.check('field projection below eight seconds at '||n,'PERFORMANCE',field_ms<8000);
  perform pg_temp.check('full accepted play replay below eight seconds at '||n,'PERFORMANCE',play_ms<8000);
  perform pg_temp.check('authorized PBP read below eight seconds at '||n,'PERFORMANCE',pbp_ms<8000);
  perform pg_temp.check('box projection below eight seconds at '||n,'PERFORMANCE',box_ms<8000);
  perform pg_temp.check('drive projection below eight seconds at '||n,'PERFORMANCE',drive_ms<8000);
  perform pg_temp.check('Game Center detail below eight seconds at '||n,'PERFORMANCE',read_ms<8000);
  perform pg_temp.check('field helper and detail agree at '||n,'VOLUME',field_payload=payload->'field_state');
  perform pg_temp.check('play replay retains every accepted fact at '||n,'VOLUME',jsonb_array_length(play_payload)=n);
  perform pg_temp.check('authorized PBP read respects display cap at '||n,'VOLUME',jsonb_array_length(pbp_payload)<=500);
  perform pg_temp.check('volume has exact total ordinary rushes '||n,'VOLUME',(select sum((t->'stats'->>'rush_attempts')::int)=n from jsonb_array_elements(payload->'teams')t));
  perform pg_temp.check('volume zero-yard plays preserve exact zero yards/score '||n,'VOLUME',(select bool_and(t->'stats'->>'rushing_yards'='0'and t->'stats'->>'total_offensive_yards'='0'and t->'stats'->>'points'='0')from jsonb_array_elements(payload->'teams')t));
  perform pg_temp.check('volume full totals retain all turnovers on downs '||n,'VOLUME',(select sum((t->'stats'->>'turnovers_on_downs')::int)=n/4 from jsonb_array_elements(payload->'teams')t));
  perform pg_temp.check('Football display plays bounded '||n,'VOLUME',jsonb_array_length(payload->'plays')<=500);
  perform pg_temp.check('Football private accepted context exact bound '||n,'VOLUME',jsonb_array_length(payload->'entry_plays')=least(n,500));
  perform pg_temp.check('Football drives bounded '||n,'VOLUME',jsonb_array_length(payload->'drives')<=100);
  insert into ff_performance values(n,round(append_ms,3),round(append_ms/(n-previous),3),round(append_max_ms,3),round(field_ms,3),round(play_ms,3),round(pbp_ms,3),round(box_ms,3),round(drive_ms,3),round(read_ms,3),jsonb_array_length(payload->'plays'));previous:=n;
 end loop;
end$$;
create temp table ff_finalize_performance(finish_periods_ms numeric,finalization_ms numeric,stat_rows int);grant select,insert on ff_finalize_performance to authenticated;
do $$declare started timestamptz;finish_ms numeric;seal_ms numeric;begin
 started:=clock_timestamp();perform pg_temp.ff_finish('volume');finish_ms:=extract(epoch from(clock_timestamp()-started))*1000;
 started:=clock_timestamp();perform pg_temp.game_op('game.finalize','volume');seal_ms:=extract(epoch from(clock_timestamp()-started))*1000;
 perform pg_temp.check('combined remaining period controls below eight seconds','PERFORMANCE',finish_ms<8000);
 perform pg_temp.check('1000-play canonical finalization below eight seconds','PERFORMANCE',seal_ms<8000);
 insert into ff_finalize_performance values(round(finish_ms,3),round(seal_ms,3),null);
end$$;
reset role;
update ff_finalize_performance set stat_rows=(select count(*)from public.game_football_final_stats where game_id=pg_temp.ff_game('volume'));
select pg_temp.check('1000-play seal retains complete independent rush totals','VOLUME',(select sum((stats->>'rush_attempts')::int)=1000 from public.game_football_final_stats where game_id=pg_temp.ff_game('volume')and roster_id is null));
select pg_temp.check('1000-play seal preserves all athlete and two team rows','VOLUME',(select stat_rows=16 from ff_finalize_performance));
select pg_temp.check('no per-play notification fanout','NOTIFICATIONS',not exists(select 1 from public.notification_events e join public.game_operations o on o.id=e.source_id where o.game_id=pg_temp.ff_game('volume')and o.operation like 'football.%'and o.operation<>'football.period.end'));
select pg_temp.check('volume complete canonical sequence','LEDGER',(select count(*)=max(sequence)and min(sequence)=1 from public.game_operations where game_id=pg_temp.ff_game('volume')));
select count(*)as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
select *from ff_performance order by volume;select *from ff_finalize_performance;
rollback;
