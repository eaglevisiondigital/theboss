-- Independent hand-calculated Soccer oracle; no engine formulas copied here.
begin;
\ir phase5c/fixture.sql
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.sc_create('oracle','internal',false);
select pg_temp.check('Soccer initializes explicit two-half stopped foundation','STATE',pg_temp.sc_detail('oracle')->>'regulation_segments'='2' and pg_temp.sc_detail('oracle')->>'segment_number'='0' and pg_temp.sc_detail('oracle')->>'segment_status'='pending' and pg_temp.sc_detail('oracle')->>'clock_ms'='0' and not(pg_temp.sc_detail('oracle')->>'clock_running')::boolean);
select pg_temp.state_denied('segment cannot precede canonical game start',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('early-segment'),pg_temp.game_command('soccer.segment.start','oracle')));
select pg_temp.state_denied('goal cannot precede active segment',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('early-goal'),pg_temp.game_command('soccer.event.add','oracle','{"event_type":"goal","side":"primary"}')));
select pg_temp.game_op('game.start','oracle');
select pg_temp.sc_op('soccer.segment.start','oracle');
select pg_temp.check('first half explicitly active at elapsed zero','STATE',pg_temp.sc_detail('oracle')->>'segment_number'='1' and pg_temp.sc_detail('oracle')->>'segment_status'='active' and pg_temp.sc_detail('oracle')->>'clock_ms'='0');
select pg_temp.state_denied('cannot skip unfinished half',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('skip-half'),pg_temp.game_command('soccer.segment.start','oracle')));
create temp table sc_ids(label text primary key,id uuid);
grant select,insert on sc_ids to authenticated;
select pg_temp.sc_clock('oracle',10000);
insert into sc_ids values('goal-p2',pg_temp.sc_event('oracle','goal','primary',2,'goal-p2'));
insert into sc_ids values('assist-p3',pg_temp.sc_event('oracle','assist','primary',3,'assist-p3',(select id from sc_ids where label='goal-p2')));
select pg_temp.sc_event('oracle','shot_saved','opponent',2,'saved-o2',null,1);
select pg_temp.sc_event('oracle','shot_off_target','primary',2);
select pg_temp.sc_event('oracle','shot_blocked','primary',3);
select pg_temp.sc_event('oracle','penalty_goal','primary',2,'penalty-goal-p2');
select pg_temp.sc_event('oracle','penalty_saved','opponent',2,'penalty-saved-o2',null,1);
select pg_temp.sc_event('oracle','penalty_miss','opponent',2);
select pg_temp.sc_event('oracle','goal','opponent',2);
select pg_temp.sc_event('oracle','own_goal','primary',4,'own-goal-p4');
select pg_temp.sc_event('oracle','yellow_card','primary',3);
select pg_temp.sc_event('oracle','yellow_card','opponent',3);
select pg_temp.denied('scorer cannot assist their own goal',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('self-assist'),pg_temp.game_command('soccer.event.add','oracle',jsonb_build_object('event_type','assist','side','primary','roster_id',pg_temp.sc_roster('oracle','primary',2),'scoring_event_id',(select id from sc_ids where label='goal-p2')))),'PT422');
select pg_temp.denied('opponent cannot assist an attacking goal',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('opposing-assist'),pg_temp.game_command('soccer.event.add','oracle',jsonb_build_object('event_type','assist','side','opponent','roster_id',pg_temp.sc_roster('oracle','opponent',3),'scoring_event_id',(select id from sc_ids where label='goal-p2')))),'PT422');
select pg_temp.denied('own goal cannot receive an assist',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('own-assist'),pg_temp.game_command('soccer.event.add','oracle',jsonb_build_object('event_type','assist','side','primary','roster_id',pg_temp.sc_roster('oracle','primary',3),'scoring_event_id',pg_temp.sc_event_id('oracle','own-goal-p4')))),'PT422');
select pg_temp.conflict('one goal cannot receive a duplicate assist',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('duplicate-assist'),pg_temp.game_command('soccer.event.add','oracle',jsonb_build_object('event_type','assist','side','primary','roster_id',pg_temp.sc_roster('oracle','primary',4),'scoring_event_id',(select id from sc_ids where label='goal-p2')))));
select pg_temp.conflict('goal correction cannot orphan dependent assist',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('orphan-assist'),pg_temp.game_command('soccer.event.correct','oracle',jsonb_build_object('event_id',(select id from sc_ids where label='goal-p2'),'event_type','goal','side','primary','roster_id',pg_temp.sc_roster('oracle','primary',3),'reason','Synthetic attribution correction'))));
select pg_temp.sc_clock('oracle',30000);
select pg_temp.sc_op('soccer.substitute','oracle',jsonb_build_object('side','primary','out_roster_id',pg_temp.sc_roster('oracle','primary',11),'in_roster_id',pg_temp.sc_roster('oracle','primary',12)));
select pg_temp.sc_clock('oracle',45000);
select pg_temp.sc_event('oracle','second_yellow','opponent',3,'second-yellow-o3');
select pg_temp.state_denied('dismissed player cannot record another shot',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('dismissed-shot'),pg_temp.game_command('soccer.event.add','oracle',jsonb_build_object('event_type','goal','side','opponent','roster_id',pg_temp.sc_roster('oracle','opponent',3)))));
select pg_temp.state_denied('on-field dismissal cannot be replaced as a substitution',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('dismissed-sub'),pg_temp.game_command('soccer.substitute','oracle',jsonb_build_object('side','opponent','out_roster_id',pg_temp.sc_roster('oracle','opponent',3),'in_roster_id',pg_temp.sc_roster('oracle','opponent',12)))));
select pg_temp.sc_end('oracle');
select pg_temp.sc_op('soccer.segment.start','oracle');
select pg_temp.sc_op('soccer.substitute','oracle',jsonb_build_object('side','opponent','out_roster_id',pg_temp.sc_roster('oracle','opponent',1),'in_roster_id',pg_temp.sc_roster('oracle','opponent',12),'goalkeeper_roster_id',pg_temp.sc_roster('oracle','opponent',12)));
select pg_temp.state_denied('active half cannot be finalized',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('early-final'),pg_temp.game_command('game.finalize','oracle')));
select pg_temp.sc_end('oracle');
select pg_temp.game_op('game.finalize','oracle');
reset role;
select pg_temp.check('match score is independent two-two draw','ORACLE',(select status='final' and primary_score=2 and opponent_score=2 and final_primary_score=2 and final_opponent_score=2 from public.games where id=pg_temp.sc_game('oracle')));
do $$declare expected record;actual record;begin
 for expected in select * from(values
 ('primary',2,1,1,4,2,2,1,0),('opponent',2,0,0,4,3,0,2,1)
 )v(side,goals,own_goals,assists,shots,shots_on_goal,saves,yellow_cards,red_cards)loop
  select * into actual from boss_private.soccer_totals(pg_temp.sc_game('oracle'))t where t.side=expected.side and t.roster_id is null;
  perform pg_temp.check('independent team oracle '||expected.side,'ORACLE',actual.side is not null and actual.goals=expected.goals and actual.own_goals=expected.own_goals and actual.assists=expected.assists and actual.shots=expected.shots and actual.shots_on_goal=expected.shots_on_goal and actual.saves=expected.saves and actual.yellow_cards=expected.yellow_cards and actual.red_cards=expected.red_cards and not actual.clean_sheet);
 end loop;
 for expected in select * from(values
 ('primary',1,0,0,0,0,0,2,2,0,0,120000,false),
 ('primary',2,2,0,0,3,2,0,null::bigint,0,0,120000,null::boolean),
 ('primary',3,0,0,1,1,0,0,null::bigint,1,0,120000,null::boolean),
 ('primary',4,0,1,0,0,0,0,null::bigint,0,0,120000,null::boolean),
 ('primary',11,0,0,0,0,0,0,null::bigint,0,0,30000,null::boolean),
 ('primary',12,0,0,0,0,0,0,null::bigint,0,0,90000,null::boolean),
 ('opponent',1,0,0,0,0,0,0,2,0,0,60000,null::boolean),
 ('opponent',2,1,0,0,4,3,0,null::bigint,0,0,120000,null::boolean),
 ('opponent',3,0,0,0,0,0,0,null::bigint,2,1,45000,null::boolean),
 ('opponent',12,0,0,0,0,0,0,0,0,0,60000,null::boolean)
 )v(side,n,goals,own_goals,assists,shots,shots_on_goal,saves,goals_allowed,yellow_cards,red_cards,playing_ms,clean_sheet)loop
  select * into actual from boss_private.soccer_totals(pg_temp.sc_game('oracle'))t where t.side=expected.side and t.roster_id=pg_temp.sc_roster('oracle',expected.side,expected.n);
  perform pg_temp.check('independent player oracle '||expected.side||'/'||expected.n,'ORACLE',actual.side is not null and actual.goals=expected.goals and actual.own_goals=expected.own_goals and actual.assists=expected.assists and actual.shots=expected.shots and actual.shots_on_goal=expected.shots_on_goal and actual.saves=expected.saves and actual.goals_allowed is not distinct from expected.goals_allowed and actual.yellow_cards=expected.yellow_cards and actual.red_cards=expected.red_cards and actual.minutes=expected.playing_ms/60000.0 and actual.clean_sheet is not distinct from expected.clean_sheet);
 end loop;
end$$;
select pg_temp.check('each snapshot athlete receives zero-capable totals','ORACLE',(select count(*)=24 from boss_private.soccer_totals(pg_temp.sc_game('oracle'))where roster_id is not null));
select pg_temp.check('saved outcomes are one fact each and no independent save rows','ORACLE',(select count(*)=2 from public.game_soccer_events where game_id=pg_temp.sc_game('oracle') and event_type in('shot_saved','penalty_saved')) and not exists(select 1 from public.game_soccer_events where game_id=pg_temp.sc_game('oracle') and event_type='save'));
select pg_temp.check('second yellow leaves ten eligible field slots and one blocked dismissal','CARDS',(select count(*)=11 and count(*)filter(where dismissed)=1 and count(*)filter(where not dismissed)=10 from public.game_soccer_lineups where game_id=pg_temp.sc_game('oracle') and side='opponent'));
create temp table sc_prior_seal as select * from public.game_soccer_finalizations where game_id=pg_temp.sc_game('oracle') and epoch=1;
create temp table sc_prior_stats as select s.* from public.game_soccer_final_stats s where finalization_id=(select finalization_id from sc_prior_seal);
grant select on sc_prior_seal to authenticated;
select pg_temp.check('first epoch has twenty-six unique stable stat identities','FINAL',(select count(*)=26 and count(distinct id)=26 from sc_prior_stats));
select pg_temp.check('sport seal shares canonical identity and epoch','FINAL',(select s.epoch=1 and s.engine_version='soccer-v1' and s.roster_revision=c.roster_revision and s.event_sequence>0 from sc_prior_seal s join public.game_finalizations c on c.id=s.finalization_id and c.game_id=s.game_id));
set local role authenticated;
select pg_temp.actor('admin');
select pg_temp.check('final projection retains authoritative elapsed basis','PROJECTION',pg_temp.sc_detail('oracle')->>'playing_ms'='120000' and(pg_temp.sc_detail('oracle')->>'participation_complete')::boolean and jsonb_array_length(pg_temp.sc_detail('oracle')->'players')=24);
select pg_temp.state_denied('final game denies late sport event',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('late-goal'),pg_temp.game_command('soccer.event.add','oracle','{"event_type":"goal","side":"primary"}')));
select pg_temp.game_op('game.reopen','oracle','{"reason":"Synthetic reviewed attribution"}');
select pg_temp.sc_op('soccer.event.reverse','oracle',jsonb_build_object('event_id',(select id from sc_ids where label='assist-p3'),'reason','Synthetic prerequisite assist removal'));
select pg_temp.sc_op('soccer.event.correct','oracle',jsonb_build_object('event_id',(select id from sc_ids where label='goal-p2'),'event_type','goal','side','primary','roster_id',pg_temp.sc_roster('oracle','primary',3),'reason','Synthetic correct scorer'));
select pg_temp.game_op('game.finalize','oracle');
reset role;
select pg_temp.check('corrected goal keeps original immutable fact','CORRECTION',(select event_type='goal' and roster_id=pg_temp.sc_roster('oracle','primary',2) from public.game_soccer_events where id=(select id from sc_ids where label='goal-p2')) and exists(select 1 from public.game_soccer_events where correction_of=(select id from sc_ids where label='goal-p2') and roster_id=pg_temp.sc_roster('oracle','primary',3)));
select pg_temp.check('refinalization creates epoch two on same score','FINAL',(select finalization_count=2 and status='final' and primary_score=2 and opponent_score=2 from public.games where id=pg_temp.sc_game('oracle')) and(select count(*)=2 from public.game_soccer_finalizations where game_id=pg_temp.sc_game('oracle')));
select pg_temp.check('prior seals and stable stat identities are byte-preserved','FINAL',not exists(select 1 from sc_prior_stats p left join public.game_soccer_final_stats n on n.id=p.id where to_jsonb(n)is distinct from to_jsonb(p)) and not exists(select 1 from sc_prior_seal p left join public.game_soccer_finalizations n on n.finalization_id=p.finalization_id where to_jsonb(n)is distinct from to_jsonb(p)) and(select count(*)=52 and count(distinct id)=52 from public.game_soccer_final_stats where game_id=pg_temp.sc_game('oracle')));
select pg_temp.check('corrected independent attribution totals','CORRECTION',(select goals=1 and assists=0 from boss_private.soccer_totals(pg_temp.sc_game('oracle'))where roster_id=pg_temp.sc_roster('oracle','primary',3)) and(select goals=1 from boss_private.soccer_totals(pg_temp.sc_game('oracle'))where roster_id=pg_temp.sc_roster('oracle','primary',2)));
select pg_temp.check('one canonical contiguous operation ledger','LEDGER',(select count(*)=max(sequence) and min(sequence)=1 and count(distinct version)=count(*) from public.game_operations where game_id=pg_temp.sc_game('oracle')));
select pg_temp.denied('immutable typed facts reject owner update',format('update public.game_soccer_events set event_type=%L where id=%L','penalty_goal',(select id from sc_ids where label='goal-p2')),'23514');
select pg_temp.denied('immutable stat identities reject owner update',format('update public.game_soccer_final_stats set id=gen_random_uuid() where finalization_id=%L',(select finalization_id from sc_prior_seal)),'23514');
select count(*)as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
