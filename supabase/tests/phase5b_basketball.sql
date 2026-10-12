-- Independent hand-calculated oracle, canonical state/clock and immutable epochs.
begin;
\ir phase5b/fixture.sql
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.bb_create('basketball','internal',false);
select pg_temp.check('engine initializes bounded two-half format','STATE',(select configured and regulation_periods=2 and period_seconds=60 and overtime_seconds=60 and period_number=0 and period_status='pending' and clock_ms=0 and not clock_running from jsonb_to_record(pg_temp.bb_detail('basketball'))as b(configured boolean,regulation_periods int,period_seconds int,overtime_seconds int,period_number int,period_status text,clock_ms bigint,clock_running boolean)));
select pg_temp.state_denied('period cannot start before canonical game start',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('early-period'),pg_temp.game_command('basketball.period.start','basketball')));
select pg_temp.state_denied('shot cannot precede initial period',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('early-score'),pg_temp.game_command('basketball.event.add','basketball',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('basketball','primary',1)))));
select pg_temp.game_op('game.start','basketball');
select pg_temp.bb_op('basketball.period.start','basketball');
select pg_temp.check('first period is explicit and active','STATE',pg_temp.bb_detail('basketball')->>'period_number'='1' and pg_temp.bb_detail('basketball')->>'period_status'='active');
select pg_temp.state_denied('cannot skip an unfinished first period',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('period-skip'),pg_temp.game_command('basketball.period.start','basketball')));
select pg_temp.bb_op('basketball.clock.start','basketball');
select pg_temp.denied('running clock rejects another start',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('clock-running-start'),pg_temp.game_command('basketball.clock.start','basketball')),'PT409');
select pg_temp.denied('running clock must stop before explicit correction',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('clock-running-set'),pg_temp.game_command('basketball.clock.set','basketball','{"clock_ms":30000,"reason":"Synthetic forbidden running correction"}')),'PT409');
select pg_sleep(0.025);
select pg_temp.check('server clock advances from canonical anchor','CLOCK',(pg_temp.bb_detail('basketball')->>'clock_running')::boolean and (pg_temp.bb_detail('basketball')->>'clock_ms')::bigint between 0 and 59999);
select pg_temp.bb_op('basketball.clock.stop','basketball');
select pg_temp.check('stopped clock remains bounded','CLOCK',not(pg_temp.bb_detail('basketball')->>'clock_running')::boolean and (pg_temp.bb_detail('basketball')->>'clock_ms')::bigint between 0 and 60000);
select pg_temp.bb_op('basketball.clock.set','basketball','{"clock_ms":45000,"reason":"Synthetic clock correction"}','clock-correction');
select pg_temp.check('explicit corrected clock projects exactly','CLOCK',pg_temp.bb_detail('basketball')->>'clock_ms'='45000');
select pg_temp.conflict('clock correction beyond configured duration denied',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('clock-too-large'),pg_temp.game_command('basketball.clock.set','basketball','{"clock_ms":60001,"reason":"Synthetic invalid correction"}')));
select pg_temp.conflict('clock correction needs reason',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('clock-no-reason'),pg_temp.game_command('basketball.clock.set','basketball','{"clock_ms":30000,"reason":""}')));
create temp table bb_ids(label text primary key,id uuid);
grant select,insert on bb_ids to authenticated;
insert into bb_ids values('p1-two',pg_temp.bb_event('basketball','made_2','primary',1,'p1-two'));
insert into bb_ids values('assist-p2',pg_temp.bb_event('basketball','assist','primary',2,'assist-p2',(select id from bb_ids where label='p1-two')));
insert into bb_ids values('p2-three',pg_temp.bb_event('basketball','made_3','primary',2,'p2-three'));
insert into bb_ids values('assist-p1',pg_temp.bb_event('basketball','assist','primary',1,'assist-p1',(select id from bb_ids where label='p2-three')));
insert into bb_ids values('p1-ft',pg_temp.bb_event('basketball','made_ft','primary',1,'p1-ft'));
select pg_temp.denied('player cannot assist their own scoring play',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('self-assist'),pg_temp.game_command('basketball.event.add','basketball',jsonb_build_object('event_type','assist','side','primary','roster_id',pg_temp.bb_roster('basketball','primary',1),'scoring_event_id',(select id from bb_ids where label='p1-two')))),'PT422');
select pg_temp.denied('assist cannot credit opposing scoring context',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('opposing-assist'),pg_temp.game_command('basketball.event.add','basketball',jsonb_build_object('event_type','assist','side','opponent','roster_id',pg_temp.bb_roster('basketball','opponent',2),'scoring_event_id',(select id from bb_ids where label='p1-two')))),'PT422');
select pg_temp.denied('free throw is not an assist scoring context',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('free-throw-assist'),pg_temp.game_command('basketball.event.add','basketball',jsonb_build_object('event_type','assist','side','primary','roster_id',pg_temp.bb_roster('basketball','primary',2),'scoring_event_id',(select id from bb_ids where label='p1-ft')))),'PT422');
select pg_temp.denied('event correction never rewrites clock control history',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('control-correction'),pg_temp.game_command('basketball.event.reverse','basketball',jsonb_build_object('event_id',pg_temp.bb_event_id('basketball','clock-correction'),'reason','Synthetic prohibited control reversal'))),'PT409');
select pg_temp.bb_event('basketball','missed_ft','primary',1);
select pg_temp.bb_event('basketball','missed_2','primary',3);
select pg_temp.bb_event('basketball','missed_3','primary',2);
select pg_temp.bb_event('basketball','offensive_rebound','primary',3);
select pg_temp.bb_event('basketball','defensive_rebound','primary',1);
select pg_temp.bb_event('basketball','defensive_rebound','primary',0);
select pg_temp.bb_event('basketball','steal','primary',2);
select pg_temp.bb_event('basketball','block','primary',3);
select pg_temp.bb_event('basketball','turnover','primary',1);
select pg_temp.bb_event('basketball','turnover','primary',0);
select pg_temp.bb_event('basketball','personal_foul','primary',2);
select pg_temp.bb_event('basketball','made_2','opponent',1);
select pg_temp.bb_event('basketball','made_ft','opponent',1);
select pg_temp.bb_event('basketball','missed_2','opponent',2);
reset role;
do $$declare actual record;expected record;begin
 for expected in select * from(values
 ('primary',null::uuid,6,1,2,3,2,1,1,2,1,2,4,1,2,1,2),
 ('opponent',null::uuid,3,0,0,0,0,0,0,0,0,1,2,0,0,1,1),
 ('primary',pg_temp.bb_roster('basketball','primary',1),3,0,1,1,1,0,0,1,0,1,1,0,0,1,2),
 ('primary',pg_temp.bb_roster('basketball','primary',2),3,0,0,0,1,1,0,0,1,1,2,1,2,0,0),
 ('primary',pg_temp.bb_roster('basketball','primary',3),0,1,0,1,0,0,1,0,0,0,1,0,0,0,0),
 ('opponent',pg_temp.bb_roster('basketball','opponent',1),3,0,0,0,0,0,0,0,0,1,1,0,0,1,1)
 )v(side,roster_id,points,offensive_rebounds,defensive_rebounds,rebounds,assists,steals,blocks,turnovers,personal_fouls,fgm,fga,tpm,tpa,ftm,fta) loop
  select * into actual from boss_private.basketball_totals(pg_temp.bb_game('basketball')) t where t.side=expected.side and t.roster_id is not distinct from expected.roster_id;
  perform pg_temp.check('hand-computed total '||expected.side||'/'||coalesce(expected.roster_id::text,'team'),'ORACLE',actual.side is not null and to_jsonb(actual)=to_jsonb(expected));
 end loop;
 perform pg_temp.check('all snapshot players have zero-capable totals','ORACLE',(select count(*)=12 from boss_private.basketball_totals(pg_temp.bb_game('basketball'))where roster_id is not null));
 perform pg_temp.check('canonical score reconciles to typed event total','ORACLE',(select primary_score=6 and opponent_score=3 from public.games where id=pg_temp.bb_game('basketball')));
 perform pg_temp.check('period one team fouls derive from typed events','FOULS',(select count(*)=1 from boss_private.basketball_active_events(pg_temp.bb_game('basketball'))where period_number=1 and side='primary' and event_type='personal_foul'));
end$$;
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.check('live box projects team/player totals and safe play identities','PROJECTION',jsonb_array_length(pg_temp.bb_detail('basketball')->'players')=12 and jsonb_array_length(pg_temp.bb_detail('basketball')->'teams')=2 and jsonb_array_length(pg_temp.bb_detail('basketball')->'plays')>=19);
select pg_temp.conflict('same-side scoring context has at most one assist',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('duplicate-assist'),pg_temp.game_command('basketball.event.add','basketball',jsonb_build_object('event_type','assist','side','primary','roster_id',pg_temp.bb_roster('basketball','primary',3),'scoring_event_id',(select id from bb_ids where label='p1-two')))));
select pg_temp.conflict('shot correction cannot orphan its active assist',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('dependent-shot-correction'),pg_temp.game_command('basketball.event.correct','basketball',jsonb_build_object('event_id',(select id from bb_ids where label='p2-three'),'event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('basketball','primary',2),'reason','Synthetic correction'))));
select pg_temp.bb_op('basketball.event.reverse','basketball',jsonb_build_object('event_id',(select id from bb_ids where label='assist-p1'),'reason','Synthetic dependent assist reversal'));
select pg_temp.bb_op('basketball.event.correct','basketball',jsonb_build_object('event_id',(select id from bb_ids where label='p2-three'),'event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('basketball','primary',2),'reason','Synthetic two-point correction'));
select pg_temp.bb_op('basketball.event.reverse','basketball',jsonb_build_object('event_id',(select id from bb_ids where label='p1-ft'),'reason','Synthetic free throw reversal'));
reset role;
select pg_temp.check('correction and reversal recompute score','CORRECTION',(select primary_score=4 and opponent_score=3 from public.games where id=pg_temp.bb_game('basketball')));
select pg_temp.check('correction preserves original immutable three-point row','CORRECTION',(select event_type='made_3' and points=3 from public.game_basketball_events where id=(select id from bb_ids where label='p2-three')) and exists(select 1 from public.game_basketball_events where correction_of=(select id from bb_ids where label='p2-three') and event_type='made_2' and points=2));
select pg_temp.check('corrected independent shooting oracle','CORRECTION',(select points=4 and fgm=2 and fga=4 and tpm=0 and tpa=1 and ftm=0 and fta=1 and assists=1 from boss_private.basketball_totals(pg_temp.bb_game('basketball'))where side='primary' and roster_id is null));
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.conflict('already superseded event cannot be reversed twice',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('reverse-twice'),pg_temp.game_command('basketball.event.reverse','basketball',jsonb_build_object('event_id',(select id from bb_ids where label='p1-ft'),'reason','Synthetic repeated reversal'))));
select pg_temp.bb_op('basketball.substitute','basketball',jsonb_build_object('side','primary','out_roster_id',pg_temp.bb_roster('basketball','primary',5),'in_roster_id',pg_temp.bb_roster('basketball','primary',6)));
reset role;
select pg_temp.check('substitution maintains five distinct current players','LINEUP',(select count(*)=5 and count(distinct roster_id)=5 and bool_or(roster_id=pg_temp.bb_roster('basketball','primary',6)) and not bool_or(roster_id=pg_temp.bb_roster('basketball','primary',5)) from public.game_basketball_lineups where game_id=pg_temp.bb_game('basketball') and side='primary'));
select pg_temp.check('substitution seals the resulting lineup history','LINEUP',exists(select 1 from public.game_basketball_lineup_history h join public.game_basketball_events e on e.id=h.event_id where e.game_id=pg_temp.bb_game('basketball') and e.event_type='substitution' and h.roster_id=pg_temp.bb_roster('basketball','primary',6)));
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.conflict('active incoming player cannot occupy duplicate slot',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('duplicate-lineup'),pg_temp.game_command('basketball.substitute','basketball',jsonb_build_object('side','primary','out_roster_id',pg_temp.bb_roster('basketball','primary',4),'in_roster_id',pg_temp.bb_roster('basketball','primary',6)))));
select pg_temp.state_denied('cannot finalize active regulation',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('early-final'),pg_temp.game_command('game.finalize','basketball')));
select pg_temp.bb_finish('basketball');
select pg_temp.game_op('game.finalize','basketball');
reset role;
create temp table bb_first_seal as select b.finalization_id from public.game_basketball_finalizations b where game_id=pg_temp.bb_game('basketball') and epoch=1;
create temp table bb_first_stat_identity as select s.* from public.game_basketball_final_stats s where s.finalization_id=(select finalization_id from bb_first_seal);
grant select on bb_first_seal to authenticated;
select pg_temp.check('first sealed totals receive fourteen distinct stable row identities','FINAL',(select count(*)=14 and count(distinct id)=14 and bool_and(id is not null) from bb_first_stat_identity));
select pg_temp.check('basketball epoch ties canonical final identity and engine','FINAL',(select b.epoch=1 and b.engine_version='basketball-v1' and b.roster_revision=g.roster_revision and b.event_sequence>0 and b.period_number=2 from public.game_basketball_finalizations b join public.games g on g.id=b.game_id where b.finalization_id=(select finalization_id from bb_first_seal)));
select pg_temp.check('first epoch seals exact independent score','FINAL',(select points=4 from public.game_basketball_final_stats where finalization_id=(select finalization_id from bb_first_seal) and side='primary' and roster_id is null) and (select points=3 from public.game_basketball_final_stats where finalization_id=(select finalization_id from bb_first_seal) and side='opponent' and roster_id is null));
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.state_denied('final game rejects late sport event',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('late-shot'),pg_temp.game_command('basketball.event.add','basketball',jsonb_build_object('event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('basketball','primary',1)))));
select pg_temp.conflict('reopen requires explicit reason',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('reopen-no-reason'),pg_temp.game_command('game.reopen','basketball','{"reason":""}')));
select pg_temp.game_op('game.reopen','basketball','{"reason":"Synthetic postgame attribution review"}');
select pg_temp.bb_op('basketball.event.reverse','basketball',jsonb_build_object('event_id',(select id from bb_ids where label='assist-p2'),'reason','Synthetic prerequisite reversal'));
select pg_temp.bb_op('basketball.event.correct','basketball',jsonb_build_object('event_id',(select id from bb_ids where label='p1-two'),'event_type','made_2','side','primary','roster_id',pg_temp.bb_roster('basketball','primary',3),'reason','Synthetic corrected player attribution'));
select pg_temp.game_op('game.finalize','basketball');
reset role;
select pg_temp.check('refinalization appends second distinct seal','FINAL',(select finalization_count=2 and status='final' from public.games where id=pg_temp.bb_game('basketball')) and (select count(*)=2 from public.game_basketball_finalizations where game_id=pg_temp.bb_game('basketball')));
select pg_temp.check('refinalization preserves original stat row identities and appends distinct rows','FINAL',not exists(select 1 from bb_first_stat_identity row_prior left join public.game_basketball_final_stats row_now on row_now.id=row_prior.id where to_jsonb(row_now) is distinct from to_jsonb(row_prior)) and(select count(*)=28 and count(distinct id)=28 from public.game_basketball_final_stats where game_id=pg_temp.bb_game('basketball')));
set local role authenticated;
select pg_temp.actor('admin');
do $$declare expected record;history jsonb;begin
 select g->'history' into history from jsonb_array_elements(public.boss_games_read(pg_temp.query('basketball'))->'games')g;
 for expected in select * from(values
  ('basketball.configure','Basketball configured'),('basketball.period.start','Basketball period started'),('basketball.period.end','Basketball period ended'),
  ('basketball.clock.start','Basketball clock started'),('basketball.clock.stop','Basketball clock stopped'),('basketball.clock.set','Basketball clock adjusted'),
  ('basketball.lineup.set','Basketball lineup recorded'),('basketball.substitute','Basketball substitution recorded'),('basketball.event.add','Basketball play recorded'),
  ('basketball.event.correct','Basketball play corrected'),('basketball.event.reverse','Basketball play reversed')
 )v(operation,summary) loop
  perform pg_temp.check('canonical history labels '||expected.operation,'HISTORY',exists(select 1 from jsonb_array_elements(history)h where h->>'operation'=expected.operation) and not exists(select 1 from jsonb_array_elements(history)h where h->>'operation'=expected.operation and h->>'summary' is distinct from expected.summary));
 end loop;
end$$;
reset role;
select pg_temp.check('prior player epoch preserved after reattribution','FINAL',(select points=2 from public.game_basketball_final_stats where finalization_id=(select finalization_id from bb_first_seal) and side='primary' and roster_id=pg_temp.bb_roster('basketball','primary',1)) and (select s.points=0 from public.game_basketball_final_stats s join public.game_basketball_finalizations f on f.finalization_id=s.finalization_id where f.game_id=pg_temp.bb_game('basketball') and f.epoch=2 and s.roster_id=pg_temp.bb_roster('basketball','primary',1)));
select pg_temp.check('basketball uses one canonical contiguous operation ledger','LEDGER',(select count(*)=max(sequence) and min(sequence)=1 and count(distinct version)=count(*) from public.game_operations where game_id=pg_temp.bb_game('basketball')));
select pg_temp.denied('typed events cannot be rewritten by trusted owner',format('update public.game_basketball_events set points=0 where id=%L',(select id from bb_ids where label='p1-two')),'23514');
select pg_temp.denied('sealed stats cannot be rewritten by trusted owner',format('update public.game_basketball_final_stats set points=999 where finalization_id=%L',(select finalization_id from bb_first_seal)),'23514');
select pg_temp.denied('sealed stat row identities cannot be replaced by trusted owner',format('update public.game_basketball_final_stats set id=gen_random_uuid() where finalization_id=%L',(select finalization_id from bb_first_seal)),'23514');
select count(*) as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
