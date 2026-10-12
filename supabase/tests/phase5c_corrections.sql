-- Independent correction outcomes: safe current reconstruction, immutable facts,
-- dependent chronology and honest incomplete participation after ambiguity.
begin;
\ir phase5c/fixture.sql
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_create('leaf-sub');select pg_temp.sc_clock('leaf-sub',30000);
select pg_temp.sc_op('soccer.substitute','leaf-sub',jsonb_build_object('side','primary','out_roster_id',pg_temp.sc_roster('leaf-sub','primary',11),'in_roster_id',pg_temp.sc_roster('leaf-sub','primary',12)),'original-leaf-sub');
select pg_temp.sc_end('leaf-sub');
select pg_temp.sc_op('soccer.event.correct','leaf-sub',jsonb_build_object('event_id',pg_temp.sc_event_id('leaf-sub','original-leaf-sub'),'event_type','substitution','side','primary','out_roster_id',pg_temp.sc_roster('leaf-sub','primary',10),'in_roster_id',pg_temp.sc_roster('leaf-sub','primary',12),'reason','Synthetic replace leaf outgoing athlete'),'corrected-leaf-sub');
reset role;
select pg_temp.check('leaf substitution replacement reconstructs exact eleven current slots','CORRECTION',(select count(*)=11 and count(distinct roster_id)=11 and bool_or(roster_id=pg_temp.sc_roster('leaf-sub','primary',11))and not bool_or(roster_id=pg_temp.sc_roster('leaf-sub','primary',10))and bool_or(roster_id=pg_temp.sc_roster('leaf-sub','primary',12))from public.game_soccer_lineups where game_id=pg_temp.sc_game('leaf-sub')and side='primary'));
select pg_temp.check('substitution correction preserves original player fact and chronology','CORRECTION',(select roster_id=pg_temp.sc_roster('leaf-sub','primary',12)and secondary_roster_id=pg_temp.sc_roster('leaf-sub','primary',11)and clock_ms=30000 from public.game_soccer_events where id=pg_temp.sc_event_id('leaf-sub','original-leaf-sub'))and(select correction_of=pg_temp.sc_event_id('leaf-sub','original-leaf-sub')and secondary_roster_id=pg_temp.sc_roster('leaf-sub','primary',10)and clock_ms=30000 and playing_ms=30000 from public.game_soccer_events where id=pg_temp.sc_event_id('leaf-sub','corrected-leaf-sub')));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_op('soccer.event.reverse','leaf-sub',jsonb_build_object('event_id',pg_temp.sc_event_id('leaf-sub','corrected-leaf-sub'),'reason','Synthetic reverse corrected current leaf'));
select pg_temp.sc_op('soccer.segment.start','leaf-sub');select pg_temp.sc_end('leaf-sub');select pg_temp.game_op('game.finalize','leaf-sub');
reset role;
select pg_temp.check('leaf substitution reversal restores original eleven field athletes','CORRECTION',(select count(*)=11 and bool_or(roster_id=pg_temp.sc_roster('leaf-sub','primary',10))and bool_or(roster_id=pg_temp.sc_roster('leaf-sub','primary',11))and not bool_or(roster_id=pg_temp.sc_roster('leaf-sub','primary',12))from public.game_soccer_lineups where game_id=pg_temp.sc_game('leaf-sub')and side='primary'));
select pg_temp.check('participation correction seals NULL rather than invented minutes','HONESTY',(select bool_and(minutes is null and goals_allowed is null and clean_sheet is null)from public.game_soccer_final_stats where game_id=pg_temp.sc_game('leaf-sub')and roster_id is not null));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_create('leaf-keeper');select pg_temp.sc_clock('leaf-keeper',10000);
select pg_temp.sc_op('soccer.keeper.set','leaf-keeper',jsonb_build_object('side','primary','goalkeeper_roster_id',pg_temp.sc_roster('leaf-keeper','primary',2)),'original-keeper');select pg_temp.sc_end('leaf-keeper');
select pg_temp.sc_op('soccer.event.correct','leaf-keeper',jsonb_build_object('event_id',pg_temp.sc_event_id('leaf-keeper','original-keeper'),'event_type','keeper_set','side','primary','goalkeeper_roster_id',pg_temp.sc_roster('leaf-keeper','primary',3),'reason','Synthetic keeper leaf replacement'),'corrected-keeper');
reset role;
select pg_temp.check('latest keeper correction reconstructs one safe current designation','CORRECTION',(select count(*)filter(where goalkeeper)=1 and bool_or(goalkeeper and roster_id=pg_temp.sc_roster('leaf-keeper','primary',3))from public.game_soccer_lineups where game_id=pg_temp.sc_game('leaf-keeper')and side='primary'));
select pg_temp.check('keeper replacement retains original designated player and coordinate','CORRECTION',(select goalkeeper_roster_id=pg_temp.sc_roster('leaf-keeper','primary',2)and clock_ms=10000 from public.game_soccer_events where id=pg_temp.sc_event_id('leaf-keeper','original-keeper'))and(select goalkeeper_roster_id=pg_temp.sc_roster('leaf-keeper','primary',3)and correction_of=pg_temp.sc_event_id('leaf-keeper','original-keeper')and clock_ms=10000 from public.game_soccer_events where id=pg_temp.sc_event_id('leaf-keeper','corrected-keeper')));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_op('soccer.event.reverse','leaf-keeper',jsonb_build_object('event_id',pg_temp.sc_event_id('leaf-keeper','corrected-keeper'),'reason','Synthetic keeper designation reversal'));
reset role;
select pg_temp.check('keeper leaf reversal restores prior original designation','CORRECTION',(select count(*)filter(where goalkeeper)=1 and bool_or(goalkeeper and roster_id=pg_temp.sc_roster('leaf-keeper','primary',1))from public.game_soccer_lineups where game_id=pg_temp.sc_game('leaf-keeper')and side='primary'));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_create('dependent-sub');select pg_temp.sc_clock('dependent-sub',10000);
select pg_temp.sc_op('soccer.substitute','dependent-sub',jsonb_build_object('side','primary','out_roster_id',pg_temp.sc_roster('dependent-sub','primary',11),'in_roster_id',pg_temp.sc_roster('dependent-sub','primary',12)),'dependent-sub-source');
select pg_temp.sc_clock('dependent-sub',20000);select pg_temp.sc_event('dependent-sub','goal','primary',12,'dependent-goal');
select pg_temp.denied('earlier substitution with later dependent player goal cannot reverse',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('reverse-dependent-sub'),pg_temp.game_command('soccer.event.reverse','dependent-sub',jsonb_build_object('event_id',pg_temp.sc_event_id('dependent-sub','dependent-sub-source'),'reason','Synthetic unsafe earlier participation reversal'))),'PT409');
select pg_temp.conflict('statistic cannot silently become a substitution',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('goal-into-sub'),pg_temp.game_command('soccer.event.correct','dependent-sub',jsonb_build_object('event_id',pg_temp.sc_event_id('dependent-sub','dependent-goal'),'event_type','substitution','side','primary','out_roster_id',pg_temp.sc_roster('dependent-sub','primary',10),'in_roster_id',pg_temp.sc_roster('dependent-sub','primary',11),'reason','Synthetic invalid type replacement'))));
select pg_temp.conflict('substitution cannot silently become a statistic',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('sub-into-goal'),pg_temp.game_command('soccer.event.correct','dependent-sub',jsonb_build_object('event_id',pg_temp.sc_event_id('dependent-sub','dependent-sub-source'),'event_type','goal','side','primary','roster_id',pg_temp.sc_roster('dependent-sub','primary',12),'reason','Synthetic invalid kind replacement'))));
select pg_temp.sc_create('card-history');select pg_temp.sc_clock('card-history',10000);
select pg_temp.denied('second yellow without prior yellow fails closed',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('second-yellow-without-prior'),pg_temp.game_command('soccer.event.add','card-history',jsonb_build_object('event_type','second_yellow','side','primary','roster_id',pg_temp.sc_roster('card-history','primary',2)))),'PT409');
select pg_temp.sc_event('card-history','yellow_card','primary',2,'first-yellow');select pg_temp.sc_event('card-history','second_yellow','primary',2,'second-yellow');
select pg_temp.denied('first yellow cannot reverse while dependent second yellow is active',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('reverse-first-yellow'),pg_temp.game_command('soccer.event.reverse','card-history',jsonb_build_object('event_id',pg_temp.sc_event_id('card-history','first-yellow'),'reason','Synthetic invalid earlier card reversal'))),'PT409');
select pg_temp.sc_clock('card-history',20000);select pg_temp.sc_event('card-history','goal','primary',3,'after-card-goal');
select pg_temp.denied('earlier dismissal with subsequent play cannot reverse',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('reverse-earlier-dismissal'),pg_temp.game_command('soccer.event.reverse','card-history',jsonb_build_object('event_id',pg_temp.sc_event_id('card-history','second-yellow'),'reason','Synthetic unsafe earlier card reversal'))),'PT409');
select pg_temp.sc_event('card-history','red_card','primary',4,'leaf-red');
select pg_temp.sc_op('soccer.event.reverse','card-history',jsonb_build_object('event_id',pg_temp.sc_event_id('card-history','leaf-red'),'reason','Synthetic current card correction'));
reset role;
select pg_temp.check('card reversal corrects stats while preserving blocked on-field slots','CARDS',(select yellow_cards=2 and red_cards=1 from boss_private.soccer_totals(pg_temp.sc_game('card-history'))where side='primary'and roster_id is null)and(select count(*)filter(where dismissed)=2 and bool_or(dismissed and roster_id=pg_temp.sc_roster('card-history','primary',4))from public.game_soccer_lineups where game_id=pg_temp.sc_game('card-history')and side='primary'));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.state_denied('reversed dismissed athlete still cannot be replaced on field',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('red-reversal-sub'),pg_temp.game_command('soccer.substitute','card-history',jsonb_build_object('side','primary','out_roster_id',pg_temp.sc_roster('card-history','primary',4),'in_roster_id',pg_temp.sc_roster('card-history','primary',12)))));
reset role;
select pg_temp.check('ambiguous card reversal makes tracked minutes unavailable','HONESTY',(select bool_and(minutes is null)from boss_private.soccer_totals(pg_temp.sc_game('card-history'))where roster_id is not null));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_create('forbidden-control');select pg_temp.sc_event('forbidden-control','goal','primary',2,'forbidden-control-source');
reset role;
create temp table sc_forbidden_before as select g.version,g.primary_score,g.opponent_score,
 (select count(*)from public.game_operations where game_id=g.id)operations,
 (select count(*)from boss_private.game_operation_receipts where result->>'game_id'=g.id::text)receipts,
 (select jsonb_agg(to_jsonb(e)order by e.sequence)from public.game_soccer_events e where e.game_id=g.id)facts,
 (select to_jsonb(z)from public.game_soccer_states z where z.game_id=g.id)state,
 (select jsonb_agg(to_jsonb(l)order by l.side,l.slot)from public.game_soccer_lineups l where l.game_id=g.id)lineups
 from public.games g where g.id=pg_temp.sc_game('forbidden-control');
set local role authenticated;select pg_temp.actor('admin');
do $$declare kind text;op text;payload jsonb;begin
 foreach kind in array array['engine_configure','segment_start','segment_end','clock_start','clock_stop','clock_set','added_time_set','lineup_set','reversal']loop
  foreach op in array array['soccer.event.add','soccer.event.correct']loop
   payload:=jsonb_build_object('event_type',kind,'side','primary','roster_id',pg_temp.sc_roster('forbidden-control','primary',2));
   if op='soccer.event.correct'then payload:=payload||jsonb_build_object('event_id',pg_temp.sc_event_id('forbidden-control','forbidden-control-source'),'reason','Synthetic forbidden control type replacement');end if;
   perform pg_temp.denied('statistical command rejects control type '||op||'/'||kind,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('forbidden-control-'||op||'-'||kind),pg_temp.game_command(op,'forbidden-control',payload)),'PT422');
  end loop;
 end loop;
end$$;
reset role;
select pg_temp.check('forbidden controls preserve score and canonical version','SECURITY',(select g.version=b.version and g.primary_score=b.primary_score and g.opponent_score=b.opponent_score from public.games g cross join sc_forbidden_before b where g.id=pg_temp.sc_game('forbidden-control')));
select pg_temp.check('forbidden controls leave immutable sport facts unchanged','SECURITY',(select jsonb_agg(to_jsonb(e)order by e.sequence)from public.game_soccer_events e where e.game_id=pg_temp.sc_game('forbidden-control'))=(select facts from sc_forbidden_before));
select pg_temp.check('forbidden controls append no ledger or receipt','SECURITY',(select count(*)from public.game_operations where game_id=pg_temp.sc_game('forbidden-control'))=(select operations from sc_forbidden_before)and(select count(*)from boss_private.game_operation_receipts where result->>'game_id'=pg_temp.sc_game('forbidden-control')::text)=(select receipts from sc_forbidden_before));
select pg_temp.check('forbidden controls preserve elapsed state and field slots','SECURITY',(select to_jsonb(z)from public.game_soccer_states z where z.game_id=pg_temp.sc_game('forbidden-control'))=(select state from sc_forbidden_before)and(select jsonb_agg(to_jsonb(l)order by l.side,l.slot)from public.game_soccer_lineups l where l.game_id=pg_temp.sc_game('forbidden-control'))=(select lineups from sc_forbidden_before));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_create('retroactive-card');select pg_temp.sc_clock('retroactive-card',10000);
select pg_temp.sc_event('retroactive-card','yellow_card','primary',2,'retro-first-yellow');
select pg_temp.denied('known athlete cannot receive a second first-yellow fact',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('duplicate-first-yellow'),pg_temp.game_command('soccer.event.add','retroactive-card',jsonb_build_object('event_type','yellow_card','side','primary','roster_id',pg_temp.sc_roster('retroactive-card','primary',2)))),'PT409');
select pg_temp.sc_clock('retroactive-card',20000);select pg_temp.sc_event('retroactive-card','goal','primary',2,'retro-goal');
select pg_temp.sc_clock('retroactive-card',25000);select pg_temp.sc_event('retroactive-card','yellow_card','primary',3,'retro-other-first-yellow');
select pg_temp.sc_clock('retroactive-card',30000);select pg_temp.sc_event('retroactive-card','second_yellow','primary',2,'retro-second-yellow');
reset role;
create temp table sc_retro_before as select g.version,g.primary_score,g.opponent_score,
 (select jsonb_agg(to_jsonb(e)order by e.sequence)from public.game_soccer_events e where e.game_id=g.id)facts,
 (select count(*)from public.game_operations where game_id=g.id)operations,
 (select count(*)from boss_private.game_operation_receipts where result->>'game_id'=g.id::text)receipts
 from public.games g where g.id=pg_temp.sc_game('retroactive-card');
set local role authenticated;select pg_temp.actor('admin');
do $$declare kind text;begin
 foreach kind in array array['yellow_card','second_yellow']loop
  perform pg_temp.denied('retroactive goal correction cannot invalidate later card chronology '||kind,format('select public.boss_games_mutate(%L,%L)',pg_temp.f('retro-goal-to-'||kind),pg_temp.game_command('soccer.event.correct','retroactive-card',jsonb_build_object('event_id',pg_temp.sc_event_id('retroactive-card','retro-goal'),'event_type',kind,'side','primary','roster_id',pg_temp.sc_roster('retroactive-card','primary',2),'reason','Synthetic invalid earlier card insertion'))),'PT409');
 end loop;
end$$;
select pg_temp.denied('other-athlete first-yellow correction cannot create extra prior yellow',format('select public.boss_games_mutate(%L,%L)',pg_temp.f('retro-other-yellow-to-dismissed'),pg_temp.game_command('soccer.event.correct','retroactive-card',jsonb_build_object('event_id',pg_temp.sc_event_id('retroactive-card','retro-other-first-yellow'),'event_type','yellow_card','side','primary','roster_id',pg_temp.sc_roster('retroactive-card','primary',2),'reason','Synthetic invalid earlier card reattribution'))),'PT409');
reset role;
select pg_temp.check('invalid retroactive card changes no score version or facts','CARDS',(select g.version=b.version and g.primary_score=1 and g.opponent_score=0 from public.games g cross join sc_retro_before b where g.id=pg_temp.sc_game('retroactive-card'))and(select jsonb_agg(to_jsonb(e)order by e.sequence)from public.game_soccer_events e where e.game_id=pg_temp.sc_game('retroactive-card'))=(select facts from sc_retro_before));
select pg_temp.check('invalid retroactive card creates no ledger or receipt','CARDS',(select count(*)from public.game_operations where game_id=pg_temp.sc_game('retroactive-card'))=(select operations from sc_retro_before)and(select count(*)from boss_private.game_operation_receipts where result->>'game_id'=pg_temp.sc_game('retroactive-card')::text)=(select receipts from sc_retro_before));
select pg_temp.check('known yellow plus second yellow remains exactly two yellows one red','CARDS',(select goals=1 and yellow_cards=2 and red_cards=1 from boss_private.soccer_totals(pg_temp.sc_game('retroactive-card'))where roster_id=pg_temp.sc_roster('retroactive-card','primary',2)));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.sc_create('team-yellow-repeat');select pg_temp.sc_event('team-yellow-repeat','yellow_card','primary',0);select pg_temp.sc_event('team-yellow-repeat','yellow_card','primary',0);
reset role;
select pg_temp.check('legitimate unattributed team-yellow facts remain separately counted','CARDS',(select yellow_cards=2 and red_cards=0 from boss_private.soccer_totals(pg_temp.sc_game('team-yellow-repeat'))where side='primary'and roster_id is null)and(select bool_and(yellow_cards=0 and red_cards=0)from boss_private.soccer_totals(pg_temp.sc_game('team-yellow-repeat'))where roster_id is not null));
select count(*)as passed_assertions,category from pg_temp.phase5a_assertions group by category order by category;
rollback;
