alter table public.game_operations drop constraint game_operations_finite_operation;
alter table public.game_operations add constraint game_operations_finite_operation check(operation in(
 'game.create','game.roster.snapshot','game.operator.assign','game.operator.end','game.start','game.transition','game.score.set','game.score.reverse','game.finalize','game.reopen','game.publish','game.calendar.sync',
 'basketball.configure','basketball.period.start','basketball.period.end','basketball.clock.start','basketball.clock.stop','basketball.clock.set','basketball.lineup.set','basketball.substitute','basketball.event.add','basketball.event.correct','basketball.event.reverse',
 'soccer.configure','soccer.segment.start','soccer.segment.end','soccer.clock.start','soccer.clock.stop','soccer.clock.set','soccer.added_time.set','soccer.lineup.set','soccer.keeper.set','soccer.substitute','soccer.event.add','soccer.event.correct','soccer.event.reverse',
 'football.configure','football.period.start','football.period.end','football.clock.start','football.clock.stop','football.clock.set','football.state.set','football.lineup.set','football.substitute','football.play.add','football.play.correct','football.play.reverse',
 'tracking.profile.set','volleyball.configure','volleyball.set.start','volleyball.lineup.set','volleyball.substitute','volleyball.event.add','volleyball.event.correct','volleyball.event.reverse','diamond.configure','diamond.lineup.set','diamond.pa.start','diamond.pitch.add','diamond.play.add','diamond.runner.advance','diamond.substitute','diamond.pitcher.change','diamond.half.start','diamond.event.correct','diamond.event.reverse','diamond.fielding.add'));

create function boss_private.diamond_active_events(p_game uuid)
returns setof public.game_diamond_events language sql stable security definer set search_path=''as $$
 select e.*from public.game_diamond_events e where e.game_id=p_game and e.event_type<>'reversal'
 and not exists(select 1 from public.game_diamond_events r where r.game_id=e.game_id and r.correction_of=e.id)
 order by e.origin_sequence,e.id
$$;
create function boss_private.diamond_rebuild(p_game uuid,candidate jsonb default null,excluded uuid default null)returns jsonb
language plpgsql stable security definer set search_path=''as $$
declare c jsonb;s jsonb;e record;begin
 select configuration into c from public.game_diamond_states where game_id=p_game;
 s:=boss_private.diamond_initial(c);
 for e in select x.origin_sequence,x.event_type,x.payload from(
 select a.origin_sequence,a.event_type,a.payload from boss_private.diamond_active_events(p_game)a where a.id is distinct from excluded
 union all select(candidate->>'origin_sequence')::bigint,candidate->>'event_type',candidate->'payload'where candidate is not null)x order by x.origin_sequence loop
 if e.event_type in('configure','reversal')then continue;end if;
 s:=boss_private.diamond_transition(c,s,e.payload);end loop;return s;
end$$;
create function boss_private.diamond_roster(actor uuid,g public.games,rid text,side text)returns void
language plpgsql volatile security definer set search_path=''as $$begin
 if rid is null then return;end if;
 if rid!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'then raise exception 'Invalid Diamond roster identity'using errcode='PT422';end if;
 perform boss_private.volleyball_roster(actor,g,rid::uuid,side);
end$$;
create function boss_private.diamond_command(actor uuid,op text,i jsonb,request uuid,replay boolean default false)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
<<diamond_command>>
declare g public.games;preview public.games;e public.events;s public.game_diamond_states;target public.game_diamond_events;
 fields text[]:=array['game_id','sport_key','expected_version'];required text[]:=fields;kind text;payload jsonb;cfg jsonb;beforestate jsonb;nextstate jsonb;candidate jsonb;eventid uuid:=gen_random_uuid();opid uuid;origin bigint;rid text;side text;reason text;occ jsonb;movement jsonb;reference public.game_diamond_events;trace jsonb;refstate jsonb;refside text;context_state jsonb;saved public.game_diamond_events;begin
 if op='diamond.configure'then fields:=fields||array['configuration'];required:=fields;
 elsif op='diamond.event.reverse'then fields:=fields||array['event_id','reason'];required:=fields;kind:='reversal';
 elsif op='diamond.event.correct'then fields:=fields||array['payload','event_id','reason'];required:=fields;
 else fields:=fields||array['payload'];required:=fields;kind:=case op
 when'diamond.lineup.set'then'lineup_set'when'diamond.pa.start'then'pa_start'when'diamond.pitch.add'then'pitch'
 when'diamond.play.add'then'play'when'diamond.runner.advance'then'advance'when'diamond.substitute'then'substitution'
 when'diamond.fielding.add'then'fielding'when'diamond.pitcher.change'then'pitcher_change'when'diamond.half.start'then'half_start'end;
 if kind is null then raise exception 'Invalid Diamond operation'using errcode='PT422';end if;end if;
 perform boss_private.games_validate(i,fields,required);
 if i->>'sport_key'not in('baseball','softball')or i->>'sport_key'is null then raise exception 'Invalid Diamond sport'using errcode='PT422';end if;
 payload:=coalesce(i->'payload','{}');reason:=i->>'reason';
 if reason is not null and(length(btrim(reason))not between 1 and 500 or reason~'[[:cntrl:]]')then raise exception 'Reason required'using errcode='PT422';end if;
 perform boss_private.games_require_live_auth();if actor is distinct from boss_private.current_person_id()then raise exception 'Access denied'using errcode='PT403';end if;
 select *into preview from public.games where id=(i->>'game_id')::uuid;
 if preview.id is null then raise exception 'Access denied'using errcode='PT403';end if;
 if op='diamond.configure'then cfg:=i->'configuration';perform boss_private.diamond_configuration_validate(cfg);perform boss_private.tracking_resolution_locks(preview);end if;
 select *into e from public.events where id=preview.event_id for update;select *into g from public.games where id=preview.id for update;
 perform boss_private.games_lock_authority(actor,g);perform 1 from public.game_operator_assignments where game_id=g.id and person_id=actor order by id for share;
 perform boss_private.games_require_live_auth();
 if actor is distinct from boss_private.require_admin_actor()or g.sport_key is distinct from i->>'sport_key'or not boss_private.games_feature(g.organization_id,g.sport_key||'_live_scoring')or not boss_private.games_feature(g.organization_id,'game_operations')then raise exception 'Access denied'using errcode='PT403';end if;
 if op='diamond.configure'then if not boss_private.games_permission(actor,'games.manage',g,true)then raise exception 'Access denied'using errcode='PT403';end if;
 elsif op in('diamond.event.correct','diamond.event.reverse')then if not boss_private.games_permission(actor,'games.correct',g,true)then raise exception 'Access denied'using errcode='PT403';end if;
 else if not boss_private.games_operator_current(actor,g)then raise exception 'Access denied'using errcode='PT403';end if;end if;
 if g.status in('final','canceled','postponed','abandoned')then raise exception 'Game is locked'using errcode='PT409';end if;
 occ:=boss_private.games_occurrence(e,g.occurrence_key,g.occurrence_mode);
 if occ is null or occ->>'status'not in('scheduled','confirmed')or e.event_type_key not in('game','tournament')then raise exception 'Game occurrence not operable'using errcode='PT409';end if;
 select *into s from public.game_diamond_states where game_id=g.id;
 if op<>'diamond.configure'and s.game_id is null then raise exception 'Diamond not initialized'using errcode='PT409';end if;
 if op='diamond.configure'and cfg->>'sport'is distinct from g.sport_key then raise exception 'Wrong Diamond sport'using errcode='PT403';end if;
 if op in('diamond.event.correct','diamond.event.reverse')then
 select *into target from public.game_diamond_events where id=(i->>'event_id')::uuid and game_id=g.id;
 if target.id is null or target.event_type='configure'then raise exception 'Fact not correctable'using errcode='PT403';end if;
 if op='diamond.event.correct'then kind:=diamond_command.payload->>'kind';
 if kind='fielding'and(diamond_command.payload->'play_event_id'is distinct from target.payload->'play_event_id'or diamond_command.payload->'stat'is distinct from target.payload->'stat'or diamond_command.payload->'side'is distinct from target.payload->'side'or not boss_private.tracking_at(g.id,diamond_command.payload->>'side',diamond_command.payload->>'stat',target.origin_sequence))then raise exception 'Correction cannot invent untracked fielding'using errcode='PT409';end if;
 if kind is distinct from target.event_type or kind='pa_start'and diamond_command.payload->'key'is distinct from target.payload->'key'then raise exception 'Correction must preserve fact and PA identity'using errcode='PT409';end if;
 else payload:='{}';end if;
 else if op<>'diamond.configure'and kind is distinct from diamond_command.payload->>'kind'then raise exception 'Wrong Diamond command kind'using errcode='PT422';end if;end if;
 context_state:=s.state;
 if replay and op<>'diamond.configure'then
 select *into saved from public.game_diamond_events where game_id=g.id and actor_person_id=actor and request_id=request;
 if saved.id is not null then context_state:=boss_private.diamond_state_before(g.id,saved.origin_sequence);end if;end if;
 side:=coalesce(diamond_command.payload->>'side',context_state->>'batting_side');
 if kind='fielding'then
 select *into reference from boss_private.diamond_active_events(g.id)where id=(diamond_command.payload->>'play_event_id')::uuid and event_type='play';
 if reference.id is null then raise exception 'Fielding requires an active same-game play'using errcode='PT403';end if;
 refstate:=boss_private.diamond_state_before(g.id,reference.origin_sequence);
 refside:=refstate->>'defensive_side';
 if side is distinct from refside or diamond_command.payload->>'stat'not in('putouts','assists','errors','double_plays')then raise exception 'Wrong fielding context'using errcode='PT403';end if;
 if op<>'diamond.event.correct'and(not boss_private.games_feature(g.organization_id,g.sport_key||'_stats')or not boss_private.tracking_enabled(g.id,side,diamond_command.payload->>'stat'))then raise exception 'Fielding statistic not tracked'using errcode='PT403';end if;
 if diamond_command.payload->>'stat'='errors'and reference.payload->>'result'<>'reached_on_error'then raise exception 'Error attribution requires typed error play'using errcode='PT409';end if;
 if diamond_command.payload->>'stat'in('putouts','assists','double_plays')and(select count(*)from jsonb_array_elements(reference.payload->'moves')mv where(mv->>'out')::boolean)<(case diamond_command.payload->>'stat'when'double_plays'then 2 else 1 end) then raise exception 'Fielding credit contradicts play outs'using errcode='PT409';end if;
 if diamond_command.payload->>'roster_id'is not null and op<>'diamond.event.correct'and not boss_private.tracking_enabled(g.id,side,'player_attribution')then raise exception 'Player attribution not tracked'using errcode='PT403';end if;
 if diamond_command.payload->>'stat'='putouts'and not replay and(select count(*)from boss_private.diamond_active_events(g.id)d where d.event_type='fielding'and d.id is distinct from target.id and d.payload->>'play_event_id'=diamond_command.payload->>'play_event_id'and d.payload->>'stat'='putouts')>=(select count(*)from jsonb_array_elements(reference.payload->'moves')mv where(mv->>'out')::boolean)then raise exception 'Putouts exceed play outs'using errcode='PT409';end if;
 if not replay and exists(select 1 from boss_private.diamond_active_events(g.id)d where d.event_type='fielding'and d.id is distinct from target.id and d.payload->>'play_event_id'=diamond_command.payload->>'play_event_id'and d.payload->>'stat'=diamond_command.payload->>'stat'and d.payload->'roster_id'is not distinct from diamond_command.payload->'roster_id')then raise exception 'Duplicate fielding credit'using errcode='PT409';end if;
 end if;
 if op in('diamond.event.correct','diamond.event.reverse')and exists(select 1 from boss_private.diamond_active_events(g.id)d where d.event_type='fielding'and d.id is distinct from target.id and d.payload->>'play_event_id'=target.id::text)then raise exception 'Correct dependent fielding first'using errcode='PT409';end if;
 
 if kind in('lineup_set','substitution','pitcher_change')and not boss_private.games_feature(g.organization_id,g.sport_key||'_lineups')then raise exception 'Access denied'using errcode='PT403';end if;
 foreach rid in array array[diamond_command.payload->>'roster_id',diamond_command.payload->>'batter',diamond_command.payload->>'out_roster_id',diamond_command.payload->>'in_roster_id',diamond_command.payload->'placed_runner'->>'roster_id']loop perform boss_private.diamond_roster(actor,g,rid,side);end loop;
 perform boss_private.diamond_roster(actor,g,diamond_command.payload->>'pitcher',side);
 if kind='lineup_set'then
 for rid in select jsonb_array_elements_text(diamond_command.payload->'order')loop perform boss_private.diamond_roster(actor,g,rid,side);end loop;
 for rid in select value#>>'{}'from jsonb_each(diamond_command.payload->'positions')loop perform boss_private.diamond_roster(actor,g,rid,side);end loop;end if;
 if kind in('pa_start','pitch')then
 if op='diamond.event.correct'then
 -- Correction retains the original observation declaration.
 if diamond_command.payload->'pitch_tracking'is distinct from target.payload->'pitch_tracking'then raise exception 'Correction cannot invent pitch coverage'using errcode='PT409';end if;
 else
 if payload?'pitch_tracking'then raise exception 'Pitch coverage is server owned'using errcode='PT422';end if;
 payload:=payload||jsonb_build_object('pitch_tracking',boss_private.tracking_enabled(g.id,context_state->>'defensive_side','pitch_detail'));end if;
 if kind='pitch'and op<>'diamond.event.correct'and not boss_private.tracking_enabled(g.id,context_state->>'defensive_side','pitch_detail')then raise exception 'Pitches not tracked'using errcode='PT403';end if;
 end if;
 if kind in('pitch','play')then
 if op='diamond.event.correct'then
 if diamond_command.payload->'pitch_gap'is distinct from target.payload->'pitch_gap'then raise exception 'Correction cannot invent pitch coverage'using errcode='PT409';end if;
 else
 if payload?'pitch_gap'then raise exception 'Pitch coverage is server owned'using errcode='PT422';end if;
 payload:=payload||jsonb_build_object('pitch_gap',not boss_private.tracking_enabled(g.id,context_state->>'defensive_side','pitch_detail')or exists(
 select 1 from public.game_tracking_snapshots ts join public.game_diamond_plate_appearances pa on pa.game_id=ts.game_id
 where ts.game_id=g.id and ts.side=context_state->>'defensive_side'and pa.id=(context_state->'pa'->>'key')::uuid
 and ts.effective_sequence>=pa.start_sequence and not(ts.selection->'enabled'?'pitch_detail')));
 end if;end if;
 if kind in('play','advance')then for movement in select value from jsonb_array_elements(diamond_command.payload->'moves')loop
 if movement?'earned'and(case when op='diamond.event.correct'then not boss_private.tracking_at(g.id,boss_private.diamond_state_before(g.id,target.origin_sequence)->>'defensive_side','earned_runs',target.origin_sequence)else not boss_private.tracking_enabled(g.id,s.state->>'defensive_side','earned_runs')end)then raise exception 'Earned-run detail not tracked'using errcode='PT403';end if;
 if movement?'rbi'and op not in('diamond.event.correct')then raise exception 'RBI override requires a reasoned correction'using errcode='PT403';end if;end loop;end if;
 if replay then return jsonb_build_object('game_id',g.id,'version',g.version,'message','Saved.');end if;
 if g.version<>(i->>'expected_version')::bigint then raise exception 'Game changed; reload before saving'using errcode='PT409';end if;
 beforestate:=boss_private.games_core_state(g)||case when s.game_id is null then'{}'::jsonb else jsonb_build_object('diamond',s.state)end;origin:=g.last_sequence+1;
 if op='diamond.configure'then
 if s.game_id is not null or g.started_at is not null or g.status not in('scheduled','pregame','delayed')or g.roster_revision=0 or g.primary_score<>0 or g.opponent_score<>0 or exists(select 1 from public.game_operations where game_id=g.id and operation in('game.score.set','game.score.reverse'))then raise exception 'Diamond requires a new zero-score pregame snapshot'using errcode='PT409';end if;
 insert into public.game_diamond_states(game_id,organization_id,sport_key,roster_revision,configuration,state)values(g.id,g.organization_id,g.sport_key,g.roster_revision,cfg,boss_private.diamond_initial(cfg))returning *into s;
 perform boss_private.tracking_snapshot(g,'primary',origin);perform boss_private.tracking_snapshot(g,'opponent',origin);kind:='configure';payload:=cfg;nextstate:=s.state;
 else
 if op not in('diamond.lineup.set','diamond.event.correct','diamond.event.reverse')and g.status<>'live'then raise exception 'Live game required'using errcode='PT409';end if;
 if op in('diamond.event.correct','diamond.event.reverse')then
 if not exists(select 1 from boss_private.diamond_active_events(g.id)where id=target.id)then raise exception 'Fact not active leaf'using errcode='PT409';end if;
 if boss_private.diamond_rebuild(g.id)is distinct from s.state then raise exception 'Diamond reconciliation failed'using errcode='PT409';end if;
 origin:=target.origin_sequence;candidate:=jsonb_build_object('origin_sequence',origin,'event_type',kind,'payload',payload);
 nextstate:=boss_private.diamond_rebuild(g.id,candidate,target.id);
 else nextstate:=boss_private.diamond_transition(s.configuration,s.state,payload);end if;
 update public.game_diamond_states set state=nextstate where game_id=g.id;end if;
 perform boss_private.games_require_live_auth();
 if actor is distinct from boss_private.require_admin_actor()or not boss_private.games_feature(g.organization_id,g.sport_key||'_live_scoring')or not boss_private.games_feature(g.organization_id,'game_operations')
 or(op='diamond.configure'and not boss_private.games_permission(actor,'games.manage',g,true))or(op in('diamond.event.correct','diamond.event.reverse')and not boss_private.games_permission(actor,'games.correct',g,true))or(op not in('diamond.configure','diamond.event.correct','diamond.event.reverse')and not boss_private.games_operator_current(actor,g))then raise exception 'Access denied'using errcode='PT403';end if;
 update public.games set primary_score=(nextstate->>'primary_score')::int,opponent_score=(nextstate->>'opponent_score')::int,version=g.version+1 where id=g.id returning *into g;
 opid:=boss_private.games_append(g.id,actor,op,request,beforestate,jsonb_build_object('diamond',nextstate,'diamond_event_id',eventid),target.operation_id);
 insert into public.game_diamond_events(id,organization_id,game_id,operation_id,sequence,origin_sequence,event_type,payload,correction_of,actor_person_id,request_id,reason)
 values(eventid,g.organization_id,g.id,opid,g.last_sequence+1,origin,kind,payload,target.id,actor,request,reason);
 if kind='pa_start'and target.id is null then
 insert into public.game_diamond_plate_appearances(id,organization_id,game_id,start_event_id,side,batter_roster_id,pitcher_roster_id,start_sequence,start_state)
 values((diamond_command.payload->>'key')::uuid,g.organization_id,g.id,eventid,nextstate->'pa'->>'side',(nextstate->'pa'->>'batter')::uuid,(nextstate->'pa'->>'pitcher')::uuid,g.last_sequence+1,s.state);end if;
 return jsonb_build_object('game_id',g.id,'version',g.version,'event_id',eventid,'message','Saved.');
end$$;

-- Batting and pitching use the same accepted play/runner evidence. No counter RPC.
create function boss_private.diamond_counter(m jsonb,side text,rid text,k text,n integer)returns jsonb
language plpgsql immutable set search_path=''as $$declare subject text;row jsonb;begin
 foreach subject in array (case when rid is null then array[side||':team']else array[side||':team',side||':'||rid]end) loop
 row:=coalesce(m->subject,'{}');row:=jsonb_set(row,array[k],to_jsonb(coalesce((row->>k)::int,0)+n));m:=jsonb_set(m,array[subject],row);end loop;return m;
end$$;
create function boss_private.diamond_stat_rates(raw jsonb,era_innings integer)returns jsonb
language plpgsql immutable set search_path=''as $$
declare ab numeric:=coalesce((raw->>'ab')::numeric,0);hits numeric:=coalesce((raw->>'hits')::numeric,0);bb numeric:=coalesce((raw->>'walks')::numeric,0);hbp numeric:=coalesce((raw->>'hbp')::numeric,0);sf numeric:=coalesce((raw->>'sacrifice_flies')::numeric,0);outs numeric:=coalesce((raw->>'outs_pitched')::numeric,0);pitches numeric:=coalesce((raw->>'pitches')::numeric,0);obp numeric;slg numeric;begin
 obp:=round((hits+bb+hbp)/nullif(ab+bb+hbp+sf,0),6);
 slg:=round((coalesce((raw->>'singles')::numeric,0)+2*coalesce((raw->>'doubles')::numeric,0)+3*coalesce((raw->>'triples')::numeric,0)+4*coalesce((raw->>'home_runs')::numeric,0))/nullif(ab,0),6);
 return raw||jsonb_build_object('avg',round(hits/nullif(ab,0),6),'obp',obp,'slg',slg,'ops',obp+slg,
 'era',round(coalesce((raw->>'earned_runs')::numeric,0)*era_innings*3/nullif(outs,0),6),
 'whip',round((coalesce((raw->>'hits_allowed')::numeric,0)+coalesce((raw->>'walks_allowed')::numeric,0))*3/nullif(outs,0),6),
 'strike_percentage',round(coalesce((raw->>'strikes')::numeric,0)/nullif(pitches,0),6));
end$$;
create function boss_private.diamond_totals(p_game uuid)returns table(side text,roster_id uuid,stats jsonb)
language plpgsql stable security definer set search_path=''as $$
declare c jsonb;s jsonb;n jsonb;m jsonb:='{}';zero jsonb:='{}';ev public.game_diamond_events;pa jsonb;runner jsonb;mv jsonb;bat text;def text;batter text;pitcher text;result text;k text;subject text;rid text;r public.game_roster_snapshots;run_delta int;out_delta int;counter text;seen_double_plays text[]:='{}';count_keys text[]:=array['pa','ab','runs','hits','singles','doubles','triples','home_runs','rbi','walks','hbp','strikeouts','stolen_bases','caught_stealing','sacrifice_flies','sacrifice_bunts','outs_pitched','batters_faced','hits_allowed','runs_allowed','earned_runs','walks_allowed','strikeouts_pitched','hbp_allowed','home_runs_allowed','pitches','strikes','wild_pitches','putouts','assists','errors','double_plays'];begin
 select configuration into c from public.game_diamond_states where game_id=p_game;s:=boss_private.diamond_initial(c);
 select jsonb_object_agg(x,0)into zero from unnest(count_keys)x;
 m:=jsonb_build_object('primary:team',zero,'opponent:team',zero);
 for r in select *from public.game_roster_snapshots where game_id=p_game and revision=(select ds.roster_revision from public.game_diamond_states ds where ds.game_id=p_game)loop
 select case when r.team_id=g.primary_team_id then'primary'else'opponent'end into bat from public.games g where g.id=p_game;
 m:=jsonb_set(m,array[bat||':'||r.id],zero);end loop;
 for ev in select *from boss_private.diamond_active_events(p_game)loop
 if ev.event_type='configure'then continue;end if;
 bat:=s->>'batting_side';def:=s->>'defensive_side';pa:=s->'pa';batter:=pa->>'batter';pitcher:=s->'pitchers'->>def;result:=ev.payload->>'result';
 n:=boss_private.diamond_transition(c,s,ev.payload);
 run_delta:=(n->>(bat||'_score'))::int-(s->>(bat||'_score'))::int;
 -- A half-ending transition retains outs until the next explicit half start.
 out_delta:=(n->>'outs')::int-(s->>'outs')::int;
 if ev.event_type in('play','advance')then
 m:=boss_private.diamond_counter(m,def,pitcher,'outs_pitched',out_delta);
 if run_delta>0 then
 -- Credit only scoring movements that survived third-out legal ordering.
 for mv in select value from jsonb_array_elements(ev.payload->'moves')where not(value->>'out')::boolean and value->>'to'='4'loop
 runner:=case when mv->>'from'='0'then jsonb_build_object('roster_id',pa->'batter','responsible_pitcher',pa->'pitcher','placed',false)else s->'bases'->((mv->>'from')::int-1)end;
 m:=boss_private.diamond_counter(m,bat,runner->>'roster_id','runs',1);
 m:=boss_private.diamond_counter(m,def,runner->>'responsible_pitcher','runs_allowed',1);
 if coalesce((mv->>'earned')::boolean,false)and not coalesce((runner->>'placed')::boolean,false)then m:=boss_private.diamond_counter(m,def,runner->>'responsible_pitcher','earned_runs',1);end if;
 if ev.event_type='play'and coalesce((mv->>'rbi')::boolean,result in('single','double','triple','home_run','walk','intentional_walk','hit_by_pitch','sacrifice_bunt','sacrifice_fly'))then m:=boss_private.diamond_counter(m,bat,batter,'rbi',1);end if;
 end loop;end if;
 if ev.event_type='advance'then
 for mv in select value from jsonb_array_elements(ev.payload->'moves')loop
 runner:=s->'bases'->((mv->>'from')::int-1);
 if mv->>'cause'in('stolen_base','caught_stealing')and boss_private.tracking_at(p_game,bat,case mv->>'cause'when'stolen_base'then'stolen_bases'else'caught_stealing'end,ev.origin_sequence)then
 m:=boss_private.diamond_counter(m,bat,runner->>'roster_id',case mv->>'cause'when'stolen_base'then'stolen_bases'else'caught_stealing'end,1);end if;end loop;
 if exists(select 1 from jsonb_array_elements(ev.payload->'moves')mv where mv->>'cause'='wild_pitch')then m:=boss_private.diamond_counter(m,def,pitcher,'wild_pitches',1);end if;
 else
 pitcher:=pa->>'pitcher';m:=boss_private.diamond_counter(m,bat,batter,'pa',1);m:=boss_private.diamond_counter(m,def,pitcher,'batters_faced',1);
 if result not in('walk','intentional_walk','hit_by_pitch','sacrifice_bunt','sacrifice_fly','catcher_interference')then m:=boss_private.diamond_counter(m,bat,batter,'ab',1);end if;
 if result in('single','double','triple','home_run')then
 m:=boss_private.diamond_counter(m,bat,batter,'hits',1);m:=boss_private.diamond_counter(m,def,pitcher,'hits_allowed',1);
 counter:=case result when'single'then'singles'when'double'then'doubles'when'triple'then'triples'else'home_runs'end;m:=boss_private.diamond_counter(m,bat,batter,counter,1);
 if result='home_run'then m:=boss_private.diamond_counter(m,def,pitcher,'home_runs_allowed',1);end if;end if;
 if result in('walk','intentional_walk')then m:=boss_private.diamond_counter(m,bat,batter,'walks',1);m:=boss_private.diamond_counter(m,def,pitcher,'walks_allowed',1);end if;
 if result='hit_by_pitch'then m:=boss_private.diamond_counter(m,bat,batter,'hbp',1);m:=boss_private.diamond_counter(m,def,pitcher,'hbp_allowed',1);end if;
 if result in('strikeout','dropped_third_strike')then m:=boss_private.diamond_counter(m,bat,batter,'strikeouts',1);m:=boss_private.diamond_counter(m,def,pitcher,'strikeouts_pitched',1);end if;
 if result in('sacrifice_bunt','sacrifice_fly')then m:=boss_private.diamond_counter(m,bat,batter,case result when'sacrifice_bunt'then'sacrifice_bunts'else'sacrifice_flies'end,1);end if;
 end if;
 elsif ev.event_type='fielding'then
 m:=boss_private.diamond_counter(m,ev.payload->>'side',ev.payload->>'roster_id',ev.payload->>'stat',1);
 if ev.payload->>'stat'='double_plays'then
 if ev.payload->>'play_event_id'=any(seen_double_plays)then m:=jsonb_set(m,array[(ev.payload->>'side')||':team','double_plays'],to_jsonb((m->((ev.payload->>'side')||':team')->>'double_plays')::int-1));else seen_double_plays:=array_append(seen_double_plays,ev.payload->>'play_event_id');end if;end if;
 elsif ev.event_type='pitch'then
 m:=boss_private.diamond_counter(m,def,pitcher,'pitches',1);
 if ev.payload->>'outcome'<>'ball'then m:=boss_private.diamond_counter(m,def,pitcher,'strikes',1);end if;
 end if;s:=n;
 end loop;
 for subject in select jsonb_object_keys(m)loop
 side:=split_part(subject,':',1);rid:=split_part(subject,':',2);roster_id:=case rid when'team'then null::uuid else rid::uuid end;
 stats:=boss_private.diamond_stat_rates(m->subject,(c->>'era_innings')::int);return next;end loop;
end$$;
create function boss_private.tracking_at(p_game uuid,p_side text,p_key text,p_sequence bigint)returns boolean
language sql stable security definer set search_path=''as $$select coalesce((select selection->'enabled'?p_key from public.game_tracking_snapshots where game_id=p_game and side=p_side and effective_sequence<=p_sequence order by effective_sequence desc limit 1),false)$$;
create function boss_private.diamond_coverage(p_game uuid,p_side text,p_cutoff bigint,player boolean default false)returns jsonb
language plpgsql stable security definer set search_path=''as $$
declare coverage jsonb:=boss_private.tracking_coverage(p_game,p_side,p_cutoff);c jsonb;s jsonb;n jsonb;e public.game_diamond_events;k text;run_count int;begin
 select configuration into c from public.game_diamond_states where game_id=p_game;s:=boss_private.diamond_initial(c);
 for e in select *from boss_private.diamond_active_events(p_game)where sequence<=p_cutoff loop
 if e.event_type='configure'then continue;end if;
 n:=boss_private.diamond_transition(c,s,e.payload);
 if e.event_type in('play','advance')and s->>'defensive_side'=p_side and(n->>(s->>'batting_side'||'_score'))::int>(s->>(s->>'batting_side'||'_score'))::int
 and exists(select 1 from jsonb_array_elements(e.payload->'moves')mv where mv->>'to'='4'and not(mv?'earned'))then
 foreach k in array array['earned_runs','era']loop if coverage->>k='tracked'then coverage:=jsonb_set(coverage,array[k],'"partially_tracked"');end if;end loop;end if;
 if player and(
 e.event_type='play'and(s->>'batting_side'=p_side and s->'pa'->'batter'='null'::jsonb or s->>'defensive_side'=p_side and s->'pa'->'pitcher'='null'::jsonb)
 or e.event_type in('pitch','advance')and s->>'defensive_side'=p_side and s->'pitchers'->p_side='null'::jsonb
 or e.event_type in('play','advance')and s->>'batting_side'=p_side and exists(select 1 from jsonb_array_elements(s->'bases')r where r->'roster_id'='null'::jsonb))then
 for k in select jsonb_object_keys(coverage)loop if coverage->>k='tracked'then coverage:=jsonb_set(coverage,array[k],'"partially_tracked"');end if;end loop;end if;s:=n;
 end loop;
 return coverage;
end$$;
do $$declare f record;begin for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and(p.proname like'diamond_%'or p.proname='tracking_at')loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);end loop;end$$;

create function boss_private.diamond_state_before(p_game uuid,p_sequence bigint)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare c jsonb;s jsonb;e public.game_diamond_events;begin
 select configuration into c from public.game_diamond_states where game_id=p_game;s:=boss_private.diamond_initial(c);
 for e in select *from boss_private.diamond_active_events(p_game)where origin_sequence<p_sequence loop if e.event_type='configure'then continue;end if;s:=boss_private.diamond_transition(c,s,e.payload);end loop;return s;
end$$;
revoke all on function boss_private.diamond_state_before(uuid,bigint)from public,anon,authenticated,service_role;

create function boss_private.diamond_trace(p_game uuid)returns table(event_id uuid,inning integer,half text,batting_side text,outs integer,runs integer)
language plpgsql stable security definer set search_path=''as $$
declare c jsonb;s jsonb;n jsonb;e public.game_diamond_events;begin
 select configuration into c from public.game_diamond_states where game_id=p_game;s:=boss_private.diamond_initial(c);
 for e in select *from boss_private.diamond_active_events(p_game)loop
 if e.event_type='configure'then continue;end if;n:=boss_private.diamond_transition(c,s,e.payload);
 event_id:=e.id;inning:=(s->>'inning')::int;half:=s->>'half';batting_side:=s->>'batting_side';outs:=(n->>'outs')::int;runs:=(n->>'primary_score')::int+(n->>'opponent_score')::int-(s->>'primary_score')::int-(s->>'opponent_score')::int;
 return next;s:=n;end loop;
end$$;
revoke all on function boss_private.diamond_trace(uuid)from public,anon,authenticated,service_role;
