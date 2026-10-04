-- Synthetic correction histories only. Each suite rolls back; do not use hosted data.
-- Expected outcomes are literals, independent of the Football reducer.
begin;
\ir phase5d/fixture.sql

-- Capture every persisted surface touched by a command, including private receipts.
-- The helper exists only in this disposable test transaction.
create function pg_temp.ff_correction_snapshot(label text) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('game',to_jsonb(g),
 'state',(select to_jsonb(s)from public.game_football_states s where s.game_id=g.id),
 'facts',(select coalesce(jsonb_agg(to_jsonb(e)order by e.sequence),'[]')from public.game_football_events e where e.game_id=g.id),
 'operations',(select coalesce(jsonb_agg(to_jsonb(o)order by o.sequence),'[]')from public.game_operations o where o.game_id=g.id),
 'receipts',(select coalesce(jsonb_agg(to_jsonb(r)order by r.request_id),'[]')from boss_private.game_operation_receipts r where r.result->>'game_id'=g.id::text),
 'audit',(select coalesce(jsonb_agg(to_jsonb(a)order by a.id),'[]')from public.audit_events a where a.resource_type='game'and a.resource_id=g.id),
 'lineups',(select coalesce(jsonb_agg(to_jsonb(l)order by l.side,l.slot),'[]')from public.game_football_lineups l where l.game_id=g.id),
 'seals',(select coalesce(jsonb_agg(to_jsonb(s)order by s.epoch),'[]')from public.game_football_finalizations s where s.game_id=g.id),
 'sealed_stats',(select coalesce(jsonb_agg(to_jsonb(s)order by s.id),'[]')from public.game_football_final_stats s where s.game_id=g.id))
 from public.games g where g.id=pg_temp.ff_game(label)
$$;
revoke all on function pg_temp.ff_correction_snapshot(text) from public;
grant execute on function pg_temp.ff_correction_snapshot(text) to authenticated;

set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('leaf-runner');select pg_temp.ff_clock('leaf-runner',345000);
select pg_temp.ff_play('leaf-runner','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('leaf-runner','primary',3),'yards',8,'tackler_roster_id',pg_temp.ff_roster('leaf-runner','opponent',5)),'runner-original');
reset role;
create temp table ff_original_runner as select *from public.game_football_events where id=pg_temp.ff_event_id('leaf-runner','runner-original');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_op('football.play.correct','leaf-runner',jsonb_build_object('event_id',pg_temp.ff_event_id('leaf-runner','runner-original'),'play_type','rush','side','primary','roster_id',pg_temp.ff_roster('leaf-runner','primary',2),'yards',8,'tackler_roster_id',pg_temp.ff_roster('leaf-runner','opponent',5),'reason','Synthetic correct runner attribution'),'runner-replacement');
reset role;
select pg_temp.ff_expect('leaf-runner','primary',2,'{"rush_attempts":1,"rushing_yards":8,"long_rush":8}','corrected runner');
select pg_temp.ff_expect('leaf-runner','primary',3,'{"rush_attempts":0,"rushing_yards":0,"long_rush":0}','replaced runner');
select pg_temp.ff_expect('leaf-runner','primary',0,'{"rush_attempts":1,"rushing_yards":8,"points":0}','runner correction team');
select pg_temp.ff_expect('leaf-runner','opponent',5,'{"solo_tackles":1,"assisted_tackles":0,"tackles":1}','runner correction defender');
select pg_temp.check('runner replacement keeps original period clock and origin sequence','CORRECTION',
 (select c.correction_of=o.id and c.origin_sequence=o.origin_sequence and c.period_number=o.period_number and c.clock_ms=345000 and c.clock_ms=o.clock_ms and c.sequence>o.sequence
  from public.game_football_events c cross join ff_original_runner o where c.id=pg_temp.ff_event_id('leaf-runner','runner-replacement')));
select pg_temp.check('runner replacement preserves the entire original fact','CORRECTION',
 (select to_jsonb(n)=to_jsonb(o)from ff_original_runner o join public.game_football_events n on n.id=o.id));
select pg_temp.check('runner replacement leaves one active play and unchanged placement','CORRECTION',
 (select count(*)=1 and bool_and(roster_id=pg_temp.ff_roster('leaf-runner','primary',2))from boss_private.football_active_events(pg_temp.ff_game('leaf-runner')))
 and(select field_state->>'ball_spot'='38'and field_state->>'down'='2'and field_state->>'distance'='2'from public.game_football_states where game_id=pg_temp.ff_game('leaf-runner')));
create temp table ff_runner_receipt as select command,result from boss_private.game_operation_receipts where request_id=pg_temp.f('runner-replacement');
create temp table ff_runner_retry_before as select pg_temp.ff_correction_snapshot('leaf-runner')snapshot;
grant select on ff_runner_receipt,ff_runner_retry_before to authenticated;
set local role authenticated;select pg_temp.actor('admin');
do $$declare replay jsonb;begin
 replay:=public.boss_games_mutate(pg_temp.f('runner-replacement'),(select command from ff_runner_receipt));
 perform pg_temp.check('correction retry returns the exact original receipt despite its prior version','IDEMPOTENCY',
  replay-'replayed'=(select result-'replayed'from ff_runner_receipt));
 perform pg_temp.check('correction retry explicitly marks the receipt replay','IDEMPOTENCY',replay->'replayed'='true'::jsonb);
end$$;
select pg_temp.denied('correction request key rejects a different replacement payload',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('runner-replacement'),(select jsonb_set(command,'{input,yards}','9')from ff_runner_receipt)),'PT409');
select pg_temp.check('correction retries and conflicting payload append no fact ledger or receipt','IDEMPOTENCY',
 pg_temp.ff_correction_snapshot('leaf-runner')=(select snapshot from ff_runner_retry_before));
select pg_temp.ff_op('football.play.reverse','leaf-runner',jsonb_build_object('event_id',pg_temp.ff_event_id('leaf-runner','runner-replacement'),'reason','Synthetic reverse current runner leaf'),'runner-reversal');
select pg_temp.conflict('superseded original is not a current correction target',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('runner-old-target'),pg_temp.game_command('football.play.reverse','leaf-runner',jsonb_build_object('event_id',pg_temp.ff_event_id('leaf-runner','runner-original'),'reason','Synthetic invalid superseded target'))));
reset role;
select pg_temp.ff_expect('leaf-runner','primary',0,'{"rush_attempts":0,"rushing_yards":0,"points":0}','reversed runner team');
select pg_temp.ff_expect('leaf-runner','opponent',5,'{"solo_tackles":0,"tackles":0}','reversed runner tackle');
select pg_temp.check('reversal removes the current leaf without resurrecting its original','CORRECTION',
 not exists(select 1 from boss_private.football_active_events(pg_temp.ff_game('leaf-runner')))
 and exists(select 1 from public.game_football_events where id=pg_temp.ff_event_id('leaf-runner','runner-reversal')and event_type='reversal'and correction_of=pg_temp.ff_event_id('leaf-runner','runner-replacement'))
 and(select to_jsonb(n)=to_jsonb(o)from ff_original_runner o join public.game_football_events n on n.id=o.id)
 and(select field_state->>'possession_side'='primary'and field_state->>'ball_spot'='30'and field_state->>'down'='1'and field_state->>'distance'='10'from public.game_football_states where game_id=pg_temp.ff_game('leaf-runner')));

set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('leaf-receiver');select pg_temp.ff_clock('leaf-receiver',320000);
select pg_temp.ff_play('leaf-receiver','pass_complete','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('leaf-receiver','primary',1),'receiver_roster_id',pg_temp.ff_roster('leaf-receiver','primary',3),'yards',6),'receiver-original');
select pg_temp.ff_op('football.play.correct','leaf-receiver',jsonb_build_object('event_id',pg_temp.ff_event_id('leaf-receiver','receiver-original'),'play_type','pass_complete','side','primary','roster_id',pg_temp.ff_roster('leaf-receiver','primary',1),'receiver_roster_id',pg_temp.ff_roster('leaf-receiver','primary',4),'yards',6,'reason','Synthetic correct receiver attribution'),'receiver-replacement');
select pg_temp.ff_create('leaf-tackler');
select pg_temp.ff_play('leaf-tackler','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('leaf-tackler','primary',2),'yards',-2,'tackler_roster_id',pg_temp.ff_roster('leaf-tackler','opponent',5)),'tackler-original');
select pg_temp.ff_op('football.play.correct','leaf-tackler',jsonb_build_object('event_id',pg_temp.ff_event_id('leaf-tackler','tackler-original'),'play_type','rush','side','primary','roster_id',pg_temp.ff_roster('leaf-tackler','primary',2),'yards',-2,'tackler_roster_id',pg_temp.ff_roster('leaf-tackler','opponent',6),'reason','Synthetic correct solo tackler attribution'),'tackler-replacement');
reset role;
select pg_temp.ff_expect('leaf-receiver','primary',1,'{"passing_attempts":1,"passing_completions":1,"passing_yards":6,"passing_touchdowns":0}','receiver correction passer');
select pg_temp.ff_expect('leaf-receiver','primary',3,'{"receptions":0,"targets":0,"receiving_yards":0}','replaced receiver');
select pg_temp.ff_expect('leaf-receiver','primary',4,'{"receptions":1,"targets":1,"receiving_yards":6,"long_reception":6}','corrected receiver');
select pg_temp.ff_expect('leaf-receiver','primary',0,'{"passing_attempts":1,"passing_completions":1,"passing_yards":6,"receiving_yards":6,"points":0}','receiver correction team');
select pg_temp.ff_expect('leaf-tackler','opponent',5,'{"solo_tackles":0,"tackles":0,"tackles_for_loss":0}','replaced tackler');
select pg_temp.ff_expect('leaf-tackler','opponent',6,'{"solo_tackles":1,"assisted_tackles":0,"tackles":1,"tackles_for_loss":1}','corrected tackler');
select pg_temp.ff_expect('leaf-tackler','opponent',0,'{"tackles":1,"tackles_for_loss":1}','tackler correction team');
select pg_temp.ff_expect('leaf-tackler','primary',2,'{"rush_attempts":1,"rushing_yards":-2}','tackler correction runner');
select pg_temp.check('receiver and tackler correction append replacements and preserve old attribution','CORRECTION',
 (select payload->>'receiver_roster_id'=pg_temp.ff_roster('leaf-receiver','primary',3)::text from public.game_football_events where id=pg_temp.ff_event_id('leaf-receiver','receiver-original'))
 and(select payload->>'tackler_roster_id'=pg_temp.ff_roster('leaf-tackler','opponent',5)::text from public.game_football_events where id=pg_temp.ff_event_id('leaf-tackler','tackler-original'))
 and(select correction_of=pg_temp.ff_event_id('leaf-receiver','receiver-original')from public.game_football_events where id=pg_temp.ff_event_id('leaf-receiver','receiver-replacement'))
 and(select correction_of=pg_temp.ff_event_id('leaf-tackler','tackler-original')from public.game_football_events where id=pg_temp.ff_event_id('leaf-tackler','tackler-replacement')));

-- A legal yardage correction changes a later first-down outcome. Raw later facts
-- keep their original capture state; the derived field and drives replay the leaf.
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('yardage-replay');
select pg_temp.ff_play('yardage-replay','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('yardage-replay','primary',2),'yards',4),'yardage-original');
select pg_temp.ff_play('yardage-replay','pass_complete','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('yardage-replay','primary',1),'receiver_roster_id',pg_temp.ff_roster('yardage-replay','primary',3),'yards',5),'yardage-dependent-pass');
reset role;
create temp table ff_original_later as select *from public.game_football_events where id=pg_temp.ff_event_id('yardage-replay','yardage-dependent-pass');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_op('football.play.correct','yardage-replay',jsonb_build_object('event_id',pg_temp.ff_event_id('yardage-replay','yardage-original'),'play_type','rush','side','primary','roster_id',pg_temp.ff_roster('yardage-replay','primary',2),'yards',5,'reason','Synthetic reviewed gain five rather than four'),'yardage-replacement');
reset role;
select pg_temp.ff_expect('yardage-replay','primary',0,'{"rush_attempts":1,"rushing_yards":5,"passing_attempts":1,"passing_completions":1,"passing_yards":5,"total_offensive_yards":10,"first_downs":1,"points":0}','valid yardage replay');
select pg_temp.check('valid yardage replacement reconstructs later exact first down','CORRECTION',
 (select field_state->>'possession_side'='primary'and field_state->>'ball_spot'='40'and field_state->>'down'='1'and field_state->>'distance'='10'and field_state->>'line_to_gain'='50'from public.game_football_states where game_id=pg_temp.ff_game('yardage-replay'))
 and(select p->'before_field'->>'ball_spot'='35'and p->'before_field'->>'down'='2'and p->'before_field'->>'distance'='5'and p->'after_field'->>'ball_spot'='40'and p->'after_field'->>'down'='1'
 from jsonb_array_elements(boss_private.football_rebuild(pg_temp.ff_game('yardage-replay'))->'plays')p where p->>'event_id'=pg_temp.ff_event_id('yardage-replay','yardage-dependent-pass')::text));
select pg_temp.check('yardage correction leaves later captured fact immutable','CORRECTION',
 (select to_jsonb(n)=to_jsonb(o)and o.before_field->>'ball_spot'='34'from ff_original_later o join public.game_football_events n on n.id=o.id)
 and(select payload->>'yards'='4'from public.game_football_events where id=pg_temp.ff_event_id('yardage-replay','yardage-original')));
select pg_temp.check('yardage correction rebuilds one two-play drive with exact bounds','DRIVE',
 (select jsonb_array_length(d)=1 and d->0->>'side'='primary'and d->0->>'start_ball_spot'='30'and d->0->>'end_ball_spot'='40'and d->0->>'play_count'='2'from(select boss_private.football_drives(pg_temp.ff_game('yardage-replay'))d)x));

-- A later receiving possession depends on the earlier turnover; a touchdown try
-- depends on the touchdown. Reject unsafe history atomically.
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('dependent-interception');
select pg_temp.ff_play('dependent-interception','interception','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('dependent-interception','primary',1),'receiver_roster_id',pg_temp.ff_roster('dependent-interception','primary',3),'defender_roster_id',pg_temp.ff_roster('dependent-interception','opponent',5),'interception_spot',35,'return_yards',5),'dependent-interception-source');
select pg_temp.ff_play('dependent-interception','rush','opponent',jsonb_build_object('roster_id',pg_temp.ff_roster('dependent-interception','opponent',2),'yards',4),'after-interception-rush');
select pg_temp.ff_create('dependent-fumble');
select pg_temp.ff_play('dependent-fumble','fumble','primary',jsonb_build_object('base_play_type','rush','roster_id',pg_temp.ff_roster('dependent-fumble','primary',2),'yards',5,'recovery_side','opponent','recovery_roster_id',pg_temp.ff_roster('dependent-fumble','opponent',6),'return_yards',0),'dependent-fumble-source');
select pg_temp.ff_play('dependent-fumble','rush','opponent',jsonb_build_object('roster_id',pg_temp.ff_roster('dependent-fumble','opponent',2),'yards',3),'after-fumble-rush');
select pg_temp.ff_create('dependent-touchdown');
select pg_temp.ff_play('dependent-touchdown','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('dependent-touchdown','primary',2),'yards',70,'touchdown',true),'dependent-touchdown-source');
select pg_temp.ff_play('dependent-touchdown','extra_point','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('dependent-touchdown','primary',7),'made',true),'after-touchdown-try');
select pg_temp.ff_play('dependent-touchdown','kickoff','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('dependent-touchdown','primary',7),'touchback',true,'result_side','opponent','result_ball_spot',25,'result_down',1,'result_distance',10),'after-touchdown-kickoff');
select pg_temp.ff_play('dependent-touchdown','rush','opponent',jsonb_build_object('roster_id',pg_temp.ff_roster('dependent-touchdown','opponent',2),'yards',2),'after-touchdown-rush');
reset role;
create temp table ff_dependent_before as select label,pg_temp.ff_correction_snapshot(label) snapshot from unnest(array['dependent-interception','dependent-fumble','dependent-touchdown'])label;
grant select on ff_dependent_before to authenticated;
set local role authenticated;select pg_temp.actor('admin');
do $$declare label text;source text;begin
 foreach label in array array['dependent-interception','dependent-fumble','dependent-touchdown']loop
  source:=label||'-source';
  perform pg_temp.denied('earlier '||label||' cannot reverse a dependent history',format('select public.boss_games_mutate(%L,%L)',pg_temp.f(label||'-unsafe-reverse'),pg_temp.game_command('football.play.reverse',label,jsonb_build_object('event_id',pg_temp.ff_event_id(label,source),'reason','Synthetic unsafe earlier reversal'))),'PT409');
 end loop;
end$$;
select pg_temp.denied('interception cannot become completion before opponent possession',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('unsafe-interception-complete'),pg_temp.game_command('football.play.correct','dependent-interception',jsonb_build_object('event_id',pg_temp.ff_event_id('dependent-interception','dependent-interception-source'),'play_type','pass_complete','side','primary','roster_id',pg_temp.ff_roster('dependent-interception','primary',1),'receiver_roster_id',pg_temp.ff_roster('dependent-interception','primary',3),'yards',5,'reason','Synthetic unsafe turnover removal'))),'PT409');
select pg_temp.denied('fumble cannot become own recovery before opponent possession',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('unsafe-fumble-own-recovery'),pg_temp.game_command('football.play.correct','dependent-fumble',jsonb_build_object('event_id',pg_temp.ff_event_id('dependent-fumble','dependent-fumble-source'),'play_type','fumble','side','primary','base_play_type','rush','roster_id',pg_temp.ff_roster('dependent-fumble','primary',2),'yards',5,'recovery_side','primary','recovery_roster_id',pg_temp.ff_roster('dependent-fumble','primary',3),'return_yards',0,'reason','Synthetic unsafe recovering side change'))),'PT409');
select pg_temp.denied('touchdown cannot become ordinary gain before a dependent try',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('unsafe-touchdown-remove'),pg_temp.game_command('football.play.correct','dependent-touchdown',jsonb_build_object('event_id',pg_temp.ff_event_id('dependent-touchdown','dependent-touchdown-source'),'play_type','rush','side','primary','roster_id',pg_temp.ff_roster('dependent-touchdown','primary',2),'yards',5,'touchdown',false,'reason','Synthetic unsafe touchdown removal'))),'PT409');
do $$declare b record;begin
 for b in select *from ff_dependent_before loop
  perform pg_temp.check('unsafe correction preserves all state ledger receipts and facts '||b.label,'DEPENDENCY',pg_temp.ff_correction_snapshot(b.label)=b.snapshot);
 end loop;
end$$;
reset role;
select pg_temp.ff_expect('dependent-interception','primary',0,'{"passing_attempts":1,"interceptions_thrown":1,"turnovers":1}','retained dependent interception');
select pg_temp.ff_expect('dependent-fumble','primary',2,'{"rush_attempts":1,"rushing_yards":5,"fumbles":1,"fumbles_lost":1}','retained dependent fumble');
select pg_temp.ff_expect('dependent-touchdown','primary',0,'{"points":7,"touchdowns":1,"rushing_touchdowns":1,"extra_points_made":1}','retained dependent touchdown');

set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('forbidden-control','internal',true,true,7);
select pg_temp.ff_play('forbidden-control','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('forbidden-control','primary',2),'yards',1),'forbidden-control-source');
reset role;
create temp table ff_forbidden_before as select pg_temp.ff_correction_snapshot('forbidden-control')snapshot;
grant select on ff_forbidden_before to authenticated;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.denied('whole fumble sack rejects distinct sack defender and primary tackler',
 format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-fumble-sack-mismatched-tackler'),
  pg_temp.game_command('football.play.add','forbidden-control',jsonb_build_object(
   'play_type','fumble','side','primary','base_play_type','sack',
   'roster_id',pg_temp.ff_roster('forbidden-control','primary',1),'yards',-2,
   'defender_roster_id',pg_temp.ff_roster('forbidden-control','opponent',5),
   'tackler_roster_id',pg_temp.ff_roster('forbidden-control','opponent',6),
   'recovery_side','opponent','recovery_roster_id',pg_temp.ff_roster('forbidden-control','opponent',6),'return_yards',0))),'PT422');
select pg_temp.check('invalid whole fumble sack preserves every persisted surface','SECURITY',
 pg_temp.ff_correction_snapshot('forbidden-control')=(select snapshot from ff_forbidden_before));
select pg_temp.denied('confirmed field rejects distance beyond the opposing goal',
 format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-state99-distance10'),
  pg_temp.game_command('football.state.set','forbidden-control',
   '{"side":"primary","ball_spot":99,"down":1,"distance":10,"primary_direction":"increasing","reason":"Synthetic inconsistent goal-to-go"}')),'PT422');
select pg_temp.check('invalid confirmed distance preserves every persisted surface','FIELD',
 pg_temp.ff_correction_snapshot('forbidden-control')=(select snapshot from ff_forbidden_before));
select pg_temp.denied('unscored kickoff return cannot leave scrimmage on the opposing goal line',
 format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-unscored-return-goal-line'),
  pg_temp.game_command('football.play.add','forbidden-control',jsonb_build_object(
   'play_type','kickoff_return','side','primary','roster_id',pg_temp.ff_roster('forbidden-control','primary',7),
   'returner_roster_id',pg_temp.ff_roster('forbidden-control','opponent',4),'return_yards',100,'touchdown',false,
   'result_side','opponent','result_ball_spot',100,'result_down',1,'result_distance',1))),'PT422');
select pg_temp.check('unscored goal-line return preserves every persisted surface','FIELD',
 pg_temp.ff_correction_snapshot('forbidden-control')=(select snapshot from ff_forbidden_before));
select pg_temp.denied('touchback cannot also record a one-yard kickoff return',
 format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-touchback-return-contradiction'),
  pg_temp.game_command('football.play.add','forbidden-control',jsonb_build_object(
   'play_type','kickoff_return','side','primary','roster_id',pg_temp.ff_roster('forbidden-control','primary',7),
   'returner_roster_id',pg_temp.ff_roster('forbidden-control','opponent',4),'return_yards',1,'touchback',true,
   'result_side','opponent','result_ball_spot',25,'result_down',1,'result_distance',10))),'PT422');
select pg_temp.check('contradictory touchback return preserves every persisted surface','FIELD',
 pg_temp.ff_correction_snapshot('forbidden-control')=(select snapshot from ff_forbidden_before));
select pg_temp.denied('accepted automatic first down cannot confirm second down',
 format('select public.boss_games_mutate(%L,%L)',pg_temp.f('ff-auto-first-down-second-down'),
  pg_temp.game_command('football.play.add','forbidden-control',
   '{"play_type":"penalty","side":"opponent","penalty_status":"accepted","penalty_yards":10,"automatic_first_down":true,"no_play":true,"result_side":"primary","result_ball_spot":41,"result_down":2,"result_distance":10}')),'PT422');
select pg_temp.check('contradictory automatic first down preserves every persisted surface','FIELD',
 pg_temp.ff_correction_snapshot('forbidden-control')=(select snapshot from ff_forbidden_before));
do $$declare kind text;op text;payload jsonb;begin
 foreach kind in array array['engine_configure','period_start','period_end','clock_start','clock_stop','clock_set','state_set','lineup_set','substitution','reversal']loop
  foreach op in array array['football.play.add','football.play.correct']loop
   payload:=jsonb_build_object('play_type',kind,'side','primary','roster_id',pg_temp.ff_roster('forbidden-control','primary',2),'yards',1);
   if op='football.play.correct'then payload:=payload||jsonb_build_object('event_id',pg_temp.ff_event_id('forbidden-control','forbidden-control-source'),'reason','Synthetic forbidden control replacement');end if;
   perform pg_temp.denied('play command rejects forged control '||op||'/'||kind,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('forbidden-'||op||'-'||kind),pg_temp.game_command(op,'forbidden-control',payload)),'PT422');
  end loop;
 end loop;
end$$;
select pg_temp.check('forged controls leave score version state lineups audit ledger receipts unchanged','SECURITY',pg_temp.ff_correction_snapshot('forbidden-control')=(select snapshot from ff_forbidden_before));
reset role;

set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('bounded-goal');
select pg_temp.ff_op('football.state.set','bounded-goal',
 '{"side":"primary","ball_spot":99,"down":1,"distance":1,"primary_direction":"increasing","reason":"Synthetic exact one-yard goal-to-go"}');
select pg_temp.check('confirmed99/1 preserves exact one-yard goal-to-go','FIELD',
 pg_temp.ff_detail('bounded-goal')->'field_state'->>'ball_spot'='99'
 and pg_temp.ff_detail('bounded-goal')->'field_state'->>'distance'='1'
 and pg_temp.ff_detail('bounded-goal')->'field_state'->>'line_to_gain'='100'
 and(pg_temp.ff_detail('bounded-goal')->'field_state'->>'goal_to_go')::boolean);
reset role;

-- Own-team recovery return yards finish the offensive outcome before checking
-- the line to gain. A fourth-down failure mirrors its final spot only once.
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('own-recovery-short');
select pg_temp.ff_op('football.state.set','own-recovery-short','{"side":"primary","ball_spot":30,"down":4,"distance":10,"primary_direction":"increasing","reason":"Synthetic fourth-and-ten recovery case"}');
select pg_temp.ff_play('own-recovery-short','fumble','primary',jsonb_build_object('base_play_type','rush','roster_id',pg_temp.ff_roster('own-recovery-short','primary',2),'yards',5,'recovery_side','primary','recovery_roster_id',pg_temp.ff_roster('own-recovery-short','primary',3),'return_yards',2),'own-recovery-short-outcome');
select pg_temp.ff_create('own-recovery-first-down');
select pg_temp.ff_op('football.state.set','own-recovery-first-down','{"side":"primary","ball_spot":30,"down":4,"distance":10,"primary_direction":"increasing","reason":"Synthetic fourth-down recovered gain case"}');
select pg_temp.ff_play('own-recovery-first-down','fumble','primary',jsonb_build_object('base_play_type','rush','roster_id',pg_temp.ff_roster('own-recovery-first-down','primary',2),'yards',5,'recovery_side','primary','recovery_roster_id',pg_temp.ff_roster('own-recovery-first-down','primary',3),'return_yards',5),'own-recovery-first-down-outcome');
reset role;
select pg_temp.ff_expect('own-recovery-short','primary',2,'{"rush_attempts":1,"rushing_yards":5,"fumbles":1,"fumbles_lost":0,"rushing_touchdowns":0}','short recovery original runner');
select pg_temp.ff_expect('own-recovery-short','primary',3,'{"rush_attempts":0,"rushing_yards":0,"fumble_recoveries":1,"fumble_return_yards":2,"return_yards":2}','short recovery returner');
select pg_temp.ff_expect('own-recovery-short','primary',0,'{"rush_attempts":1,"rushing_yards":5,"total_offensive_yards":5,"fumbles":1,"fumbles_lost":0,"turnovers":0,"turnovers_on_downs":1,"first_downs":0,"fumble_return_yards":2,"points":0}','short own recovery team');
select pg_temp.check('own recovery short on fourth down mirrors A37 once to B63','FIELD',
 (select field_state->>'possession_side'='opponent'and field_state->>'ball_spot'='63'and field_state->>'down'='1'and field_state->>'distance'='10'and field_state->>'line_to_gain'='73'from public.game_football_states where game_id=pg_temp.ff_game('own-recovery-short'))
 and(select jsonb_array_length(d)=1 and d->0->>'side'='primary'and d->0->>'start_ball_spot'='30'and d->0->>'end_ball_spot'='63'and d->0->>'play_count'='1'and d->0->>'end_reason'='downs'from(select boss_private.football_drives(pg_temp.ff_game('own-recovery-short'))d)x));
select pg_temp.ff_expect('own-recovery-first-down','primary',2,'{"rush_attempts":1,"rushing_yards":5,"fumbles":1,"fumbles_lost":0}','first-down recovery original runner');
select pg_temp.ff_expect('own-recovery-first-down','primary',3,'{"rush_attempts":0,"rushing_yards":0,"fumble_recoveries":1,"fumble_return_yards":5,"return_yards":5}','first-down recovery returner');
select pg_temp.ff_expect('own-recovery-first-down','primary',0,'{"rush_attempts":1,"rushing_yards":5,"total_offensive_yards":5,"fumbles":1,"fumbles_lost":0,"turnovers":0,"turnovers_on_downs":0,"first_downs":1,"fumble_return_yards":5,"points":0}','first-down own recovery team');
select pg_temp.check('own recovery gains fourth-down line at A40 before down progression','FIELD',
 (select field_state->>'possession_side'='primary'and field_state->>'ball_spot'='40'and field_state->>'down'='1'and field_state->>'distance'='10'and field_state->>'line_to_gain'='50'from public.game_football_states where game_id=pg_temp.ff_game('own-recovery-first-down'))
 and(select jsonb_array_length(d)=1 and d->0->>'side'='primary'and d->0->>'start_ball_spot'='30'and d->0->>'end_ball_spot'='40'and d->0->>'play_count'='1'and d->0->'end_reason'='null'::jsonb from(select boss_private.football_drives(pg_temp.ff_game('own-recovery-first-down'))d)x));

-- A typed team-unattributed touchdown confirms six points without inventing
-- a passing, receiving or rushing performance for any snapshot athlete.
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('unattributed-touchdown');
select pg_temp.ff_play('unattributed-touchdown','touchdown','primary','{}','unattributed-touchdown-source');
reset role;
select pg_temp.ff_expect('unattributed-touchdown','primary',0,'{"points":6,"touchdowns":1,"first_downs":1,"passing_attempts":0,"passing_completions":0,"passing_yards":0,"passing_touchdowns":0,"rush_attempts":0,"rushing_yards":0,"rushing_touchdowns":0,"receptions":0,"targets":0,"receiving_yards":0,"receiving_touchdowns":0,"total_offensive_yards":0}','team-unattributed touchdown');
select pg_temp.check('direct team touchdown credits no invented quarterback runner receiver or defender','HONESTY',
 (select count(*)=14 and bool_and(stats->>'points'='0'and stats->>'touchdowns'='0'and stats->>'passing_attempts'='0'and stats->>'passing_touchdowns'='0'and stats->>'rush_attempts'='0'and stats->>'rushing_touchdowns'='0'and stats->>'receptions'='0'and stats->>'receiving_touchdowns'='0'and stats->>'defensive_touchdowns'='0')from boss_private.football_totals(pg_temp.ff_game('unattributed-touchdown'))where roster_id is not null)
 and(select roster_id is null and event_type='touchdown'from public.game_football_events where id=pg_temp.ff_event_id('unattributed-touchdown','unattributed-touchdown-source'))
 and(select primary_score=6 and opponent_score=0 from public.games where id=pg_temp.ff_game('unattributed-touchdown'))
 and(select field_state->>'phase'='try'and field_state->>'scoring_side'='primary'and field_state->>'ball_spot'='100'from public.game_football_states where game_id=pg_temp.ff_game('unattributed-touchdown')));

-- Quarter changes preserve a drive; halftime and the terminal period close it.
-- Finalization changes the final boundary result to end_game in the sealed epoch.
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('drive-boundaries');
select pg_temp.ff_play('drive-boundaries','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('drive-boundaries','primary',2),'yards',5));
select pg_temp.ff_end('drive-boundaries');select pg_temp.ff_op('football.period.start','drive-boundaries');
select pg_temp.ff_play('drive-boundaries','pass_complete','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('drive-boundaries','primary',1),'receiver_roster_id',pg_temp.ff_roster('drive-boundaries','primary',3),'yards',5));
select pg_temp.ff_end('drive-boundaries');
reset role;
select pg_temp.check('first-quarter boundary preserves one drive and halftime closes its two plays','DRIVE',
 (select jsonb_array_length(d)=1 and d->0->>'side'='primary'and d->0->>'start_period'='1'and d->0->>'end_period'='2'and d->0->>'start_ball_spot'='30'and d->0->>'end_ball_spot'='40'and d->0->>'end_clock_ms'='0'and d->0->>'play_count'='2'and d->0->>'end_reason'='end_half'and d->0->>'result'='end_half'from(select boss_private.football_drives(pg_temp.ff_game('drive-boundaries'))d)x));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_op('football.period.start','drive-boundaries');
select pg_temp.ff_op('football.state.set','drive-boundaries','{"side":"primary","ball_spot":25,"down":1,"distance":10,"primary_direction":"increasing","reason":"Synthetic confirmed second-half receiving placement"}');
select pg_temp.ff_play('drive-boundaries','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('drive-boundaries','primary',2),'yards',4));
select pg_temp.ff_end('drive-boundaries');select pg_temp.ff_op('football.period.start','drive-boundaries');
select pg_temp.ff_play('drive-boundaries','pass_complete','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('drive-boundaries','primary',1),'receiver_roster_id',pg_temp.ff_roster('drive-boundaries','primary',3),'yards',6));
select pg_temp.ff_end('drive-boundaries');
reset role;
select pg_temp.check('fourth-quarter boundary closes second drive as regulation before finalization','DRIVE',
 (select jsonb_array_length(d)=2 and d->0->>'end_reason'='end_half'and d->1->>'side'='primary'and d->1->>'start_period'='3'and d->1->>'end_period'='4'and d->1->>'start_ball_spot'='25'and d->1->>'end_ball_spot'='35'and d->1->>'end_clock_ms'='0'and d->1->>'play_count'='2'and d->1->>'end_reason'='end_regulation'and d->1->>'result'='end_regulation'from(select boss_private.football_drives(pg_temp.ff_game('drive-boundaries'))d)x));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.game_op('game.finalize','drive-boundaries');
reset role;
select pg_temp.check('final regulation drive seals end_game while halftime remains end_half','FINAL',
 (select jsonb_array_length(state->'drives')=2 and state->'drives'->0->>'end_reason'='end_half'and state->'drives'->1->>'end_reason'='end_game'and state->'drives'->1->>'result'='end_game'and state->'drives'->1->>'end_period'='4'and state->'drives'->1->>'end_clock_ms'='0'and state->'drives'->1->>'end_ball_spot'='35'and state->'drives'=boss_private.football_drives(game_id)from public.game_football_finalizations where game_id=pg_temp.ff_game('drive-boundaries')and epoch=1));
select pg_temp.ff_expect('drive-boundaries','primary',0,'{"rush_attempts":2,"rushing_yards":9,"passing_attempts":2,"passing_completions":2,"passing_yards":11,"first_downs":2,"total_offensive_yards":20,"points":0}','drive boundary literal offense');

set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_create('overtime-drive-boundary','internal',true,false,7,'{"overtime_format":"timed","max_overtime_periods":1}');
select pg_temp.ff_finish('overtime-drive-boundary');select pg_temp.ff_op('football.period.start','overtime-drive-boundary');
select pg_temp.ff_play('overtime-drive-boundary','rush','primary',jsonb_build_object('roster_id',pg_temp.ff_roster('overtime-drive-boundary','primary',2),'yards',2));
select pg_temp.ff_end('overtime-drive-boundary');
reset role;
select pg_temp.check('overtime period closes one two-yard drive before finalization','DRIVE',
 (select jsonb_array_length(d)=1 and d->0->>'start_period'='5'and d->0->>'end_period'='5'and d->0->>'start_ball_spot'='30'and d->0->>'end_ball_spot'='32'and d->0->>'play_count'='1'and d->0->>'end_reason'='end_overtime'and d->0->>'result'='end_overtime'from(select boss_private.football_drives(pg_temp.ff_game('overtime-drive-boundary'))d)x));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.game_op('game.finalize','overtime-drive-boundary');
reset role;
select pg_temp.check('last overtime drive seals end_game without inventing an automatic winner','FINAL',
 (select jsonb_array_length(state->'drives')=1 and state->'drives'->0->>'end_reason'='end_game'and state->'drives'->0->>'result'='end_game'and state->'drives'->0->>'end_period'='5'and state->'drives'->0->>'end_ball_spot'='32'from public.game_football_finalizations where game_id=pg_temp.ff_game('overtime-drive-boundary')and epoch=1)
 and(select primary_score=0 and opponent_score=0 and status='final'from public.games where id=pg_temp.ff_game('overtime-drive-boundary')));

-- Sealed records remain immutable. Authorized reopening creates a new epoch;
-- it never edits E1 or mixes its receiver attribution with E2.
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.ff_finish('leaf-receiver');select pg_temp.game_op('game.finalize','leaf-receiver');
reset role;
create temp table ff_prior_seal as select *from public.game_football_finalizations where game_id=pg_temp.ff_game('leaf-receiver')and epoch=1;
create temp table ff_prior_stats as select *from public.game_football_final_stats where finalization_id=(select finalization_id from ff_prior_seal);
create temp table ff_sealed_before as select pg_temp.ff_correction_snapshot('leaf-receiver')snapshot;
grant select on ff_sealed_before to authenticated;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.state_denied('sealed Football denies receiver correction before reopening',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sealed-receiver-correct'),pg_temp.game_command('football.play.correct','leaf-receiver',jsonb_build_object('event_id',pg_temp.ff_event_id('leaf-receiver','receiver-replacement'),'play_type','pass_complete','side','primary','roster_id',pg_temp.ff_roster('leaf-receiver','primary',1),'receiver_roster_id',pg_temp.ff_roster('leaf-receiver','primary',3),'yards',6,'reason','Synthetic unauthorized sealed correction'))));
select pg_temp.state_denied('sealed Football denies reversal before reopening',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sealed-receiver-reverse'),pg_temp.game_command('football.play.reverse','leaf-receiver',jsonb_build_object('event_id',pg_temp.ff_event_id('leaf-receiver','receiver-replacement'),'reason','Synthetic unauthorized sealed reversal'))));
select pg_temp.check('sealed correction denials preserve all persisted surfaces','FINAL',pg_temp.ff_correction_snapshot('leaf-receiver')=(select snapshot from ff_sealed_before));
select pg_temp.game_op('game.reopen','leaf-receiver','{"reason":"Synthetic authorized origin attribution review"}');
select pg_temp.ff_op('football.play.correct','leaf-receiver',jsonb_build_object('event_id',pg_temp.ff_event_id('leaf-receiver','receiver-replacement'),'play_type','pass_complete','side','primary','roster_id',pg_temp.ff_roster('leaf-receiver','primary',1),'receiver_roster_id',pg_temp.ff_roster('leaf-receiver','primary',3),'yards',6,'reason','Synthetic reviewed second epoch attribution'),'receiver-second-epoch');
select pg_temp.game_op('game.finalize','leaf-receiver');
reset role;
select pg_temp.check('post-reopen correction appends a second canonical epoch','FINAL',
 (select finalization_count=2 and status='final'and primary_score=0 and opponent_score=0 from public.games where id=pg_temp.ff_game('leaf-receiver'))
 and(select count(*)=2 from public.game_football_finalizations where game_id=pg_temp.ff_game('leaf-receiver'))
 and(select bool_and(f.epoch=c.epoch and f.roster_revision=c.roster_revision and f.engine_version='football-v1')from public.game_football_finalizations f join public.game_finalizations c on c.id=f.finalization_id where f.game_id=pg_temp.ff_game('leaf-receiver')));
select pg_temp.check('E1 seal and every stable stat identity are byte-preserved after E2','FINAL',
 not exists(select 1 from ff_prior_seal p left join public.game_football_finalizations n on n.finalization_id=p.finalization_id where to_jsonb(n)is distinct from to_jsonb(p))
 and not exists(select 1 from ff_prior_stats p left join public.game_football_final_stats n on n.id=p.id where to_jsonb(n)is distinct from to_jsonb(p))
 and(select count(*)=32 and count(distinct id)=32 from public.game_football_final_stats where game_id=pg_temp.ff_game('leaf-receiver')));
select pg_temp.check('E1 receiver attribution remains six yards to player four','FINAL',
 (select stats->>'receptions'='1'and stats->>'targets'='1'and stats->>'receiving_yards'='6'from ff_prior_stats where roster_id=pg_temp.ff_roster('leaf-receiver','primary',4))
 and(select stats->>'receptions'='0'and stats->>'receiving_yards'='0'from ff_prior_stats where roster_id=pg_temp.ff_roster('leaf-receiver','primary',3)));
select pg_temp.check('E2 independently seals six yards to player three','FINAL',
 (select s.stats->>'receptions'='1'and s.stats->>'targets'='1'and s.stats->>'receiving_yards'='6'from public.game_football_final_stats s join public.game_football_finalizations f on f.finalization_id=s.finalization_id where f.game_id=pg_temp.ff_game('leaf-receiver')and f.epoch=2 and s.roster_id=pg_temp.ff_roster('leaf-receiver','primary',3))
 and(select s.stats->>'receptions'='0'and s.stats->>'receiving_yards'='0'from public.game_football_final_stats s join public.game_football_finalizations f on f.finalization_id=s.finalization_id where f.game_id=pg_temp.ff_game('leaf-receiver')and f.epoch=2 and s.roster_id=pg_temp.ff_roster('leaf-receiver','primary',4)));
select pg_temp.denied('owner cannot rewrite original Football attribution',format('update public.game_football_events set payload=payload||jsonb_build_object(%L,99)where id=%L','yards',pg_temp.ff_event_id('leaf-receiver','receiver-original')),'23514');
select pg_temp.denied('owner cannot delete original Football attribution',format('delete from public.game_football_events where id=%L',pg_temp.ff_event_id('leaf-receiver','receiver-original')),'23514');
select pg_temp.denied('owner cannot rewrite E1 Football seal',format('update public.game_football_finalizations set state=%L::jsonb where finalization_id=%L','{}',(select finalization_id from ff_prior_seal)),'23514');
select pg_temp.denied('owner cannot rewrite E1 Football stat identity',format('update public.game_football_final_stats set id=gen_random_uuid()where finalization_id=%L',(select finalization_id from ff_prior_seal)),'23514');
select pg_temp.check('correction epochs retain one contiguous canonical operation ledger','LEDGER',
 (select count(*)=max(sequence)and min(sequence)=1 and count(distinct version)=count(*)from public.game_operations where game_id=pg_temp.ff_game('leaf-receiver')));
select count(*)as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
