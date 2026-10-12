-- Football commands share Calendar/game serialization, current authorization,
-- caller receipts and the canonical operation sequence. No client score input.
create function boss_private.football_roster(p_actor uuid,g public.games,p_roster uuid,p_side text,p_on_field boolean default false)returns public.game_roster_snapshots
language plpgsql volatile security definer set search_path=''as $$
declare r public.game_roster_snapshots;team uuid;begin
 team:=case p_side when'primary'then g.primary_team_id when'opponent'then g.opponent_team_id end;
 select *into r from public.game_roster_snapshots where id=p_roster and game_id=g.id and organization_id=g.organization_id and revision=g.roster_revision and team_id=team;
 if r.id is null or not boss_private.football_roster_side(p_actor,g,team)then raise exception'Access denied'using errcode='PT403';end if;
 perform 1 from public.people where id=r.person_id for share;perform 1 from public.participants where id=r.participant_id for share;
 if not r.active or not exists(select 1 from public.people p join public.participants a on a.person_id=p.id and a.id=r.participant_id where p.id=r.person_id and p.status='active'and a.status='active')then raise exception'Athlete is not eligible in this game snapshot'using errcode='PT409';end if;
 if p_on_field and not exists(select 1 from public.game_football_lineups where game_id=g.id and side=p_side and roster_id=r.id)then raise exception'Athlete is not on the field'using errcode='PT409';end if;return r;
end$$;
create function boss_private.football_field_at(p_game uuid,p_side text,p_roster uuid,p_origin bigint)returns boolean language sql stable security definer set search_path=''as $$
 select p_roster=any(coalesce((select array(select jsonb_array_elements_text(e.payload->'roster_ids'))::uuid[]from public.game_football_events e where e.game_id=p_game and e.side=p_side and e.event_type in('lineup_set','substitution')and e.origin_sequence<p_origin order by e.origin_sequence desc limit 1),'{}'::uuid[]))
$$;

-- Operation-specific scalar whitelist. Team-attributed plays never manufacture
-- an athlete; every supplied role is checked against its actual side below.
create function boss_private.football_play_validate(kind text,p jsonb)returns void language plpgsql immutable set search_path=''as $$
declare fields text[]:=array['roster_id'];required text[]:='{}';k text;ids text[];begin
 case kind
 when'rush','kneel'then fields:=fields||array['yards','touchdown','tackler_roster_id','assisting_roster_ids'];required:=array['yards'];
 when'pass_complete'then fields:=fields||array['receiver_roster_id','yards','touchdown','tackler_roster_id','assisting_roster_ids'];required:=array['yards'];
 when'pass_incomplete'then fields:=fields||array['receiver_roster_id','pass_defender_roster_id','yards'];
 when'spike'then fields:=fields||array['yards'];
 when'sack'then fields:=fields||array['yards','defender_roster_id','tackler_roster_id','assisting_roster_ids'];required:=array['yards'];
 when'interception'then fields:=fields||array['receiver_roster_id','defender_roster_id','interception_spot','return_yards','touchdown'];required:=array['interception_spot','return_yards'];
 when'fumble'then fields:=fields||array['base_play_type','receiver_roster_id','yards','defender_roster_id','tackler_roster_id','assisting_roster_ids','forced_fumble_roster_id','recovery_roster_id','recovery_side','return_yards','touchdown'];required:=array['base_play_type','yards','recovery_side','return_yards'];
 when'fumble_recovery'then fields:=fields||array['recovery_roster_id','recovery_side','return_yards','touchdown'];required:=array['recovery_side','return_yards'];
 when'turnover_on_downs'then fields:='{}';
 when'kickoff','kickoff_return','punt','punt_return'then fields:=fields||array['kick_yards','touchback','result_side','result_ball_spot','result_down','result_distance'];required:=array['result_side','result_ball_spot','result_down','result_distance'];
 if kind in('kickoff_return','punt_return')then fields:=fields||array['returner_roster_id','return_yards','touchdown'];required:=required||array['return_yards'];end if;
 if kind in('punt','punt_return')then required:=required||array['kick_yards'];end if;
 when'field_goal'then fields:=fields||array['made','kick_distance','result_side','result_ball_spot','result_down','result_distance'];required:=array['made','kick_distance'];
 when'extra_point','two_point'then fields:=fields||array['made','result_side','result_ball_spot','result_down','result_distance'];required:=array['made'];
 if kind='two_point'then fields:=fields||array['receiver_roster_id','yards'];end if;
 when'safety'then fields:=fields||array['defender_roster_id','result_side','result_ball_spot','result_down','result_distance'];
 when'penalty'then fields:=fields||array['penalty_status','penalty_yards','automatic_first_down','loss_of_down','no_play','result_side','result_ball_spot','result_down','result_distance'];required:=array['penalty_status','penalty_yards'];
 when'touchdown'then null;
 else raise exception'Invalid Football play type'using errcode='PT422';end case;
 perform boss_private.games_validate(p,fields,required);
 foreach k in array array['roster_id','receiver_roster_id','defender_roster_id','tackler_roster_id','forced_fumble_roster_id','recovery_roster_id','returner_roster_id','pass_defender_roster_id']loop
 if p?k and(jsonb_typeof(p->k)<>'string'or p->>k!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')then raise exception'Invalid Football athlete reference'using errcode='PT422';end if;end loop;
 foreach k in array array['yards','return_yards','kick_yards','kick_distance','interception_spot','penalty_yards','result_ball_spot','result_down','result_distance']loop
 if p?k and(jsonb_typeof(p->k)<>'number'or p->>k!~'^-?[0-9]{1,3}$')then raise exception'Invalid Football yardage or field value'using errcode='PT422';end if;end loop;
 if p?'yards'and(p->>'yards')::integer not between -100 and 100 then raise exception'Football yardage exceeds bound'using errcode='PT422';end if;
 foreach k in array array['return_yards','kick_yards','interception_spot','penalty_yards','result_ball_spot']loop if p?k and(p->>k)::integer not between 0 and 100 then raise exception'Football field value exceeds bound'using errcode='PT422';end if;end loop;
 if p?'kick_distance'and(p->>'kick_distance')::integer not between 1 and 100 or p?'result_down'and(p->>'result_down')::integer not between 1 and 4 or p?'result_distance'and(p->>'result_distance')::integer not between 1 and 100 then raise exception'Invalid Football field value'using errcode='PT422';end if;
 foreach k in array array['touchdown','made','touchback','automatic_first_down','loss_of_down','no_play']loop if p?k and jsonb_typeof(p->k)<>'boolean'then raise exception'Invalid Football outcome'using errcode='PT422';end if;end loop;
 foreach k in array array['recovery_side','result_side']loop if p?k and(p->>k)not in('primary','opponent')then raise exception'Invalid Football side'using errcode='PT422';end if;end loop;
 if p?'base_play_type'and p->>'base_play_type'not in('rush','pass_complete','sack','none')or p?'penalty_status'and p->>'penalty_status'not in('accepted','declined','offsetting')then raise exception'Invalid Football whole-play outcome'using errcode='PT422';end if;
 if kind='sack'and(p->>'yards')::integer>=0 or kind='kneel'and(p->>'yards')::integer>0 or kind='fumble'and p->>'base_play_type'='sack'and(p->>'yards')::integer>=0 or kind='fumble'and p->>'base_play_type'='none'and(p->>'yards')::integer<>0 then raise exception'Invalid Football loss or recovery base'using errcode='PT422';end if;
 if kind in('pass_incomplete','spike')and coalesce((p->>'yards')::integer,0)<>0 then raise exception'Incomplete passing has no completed yardage'using errcode='PT422';end if;
 if coalesce((p->>'touchback')::boolean,false)and(coalesce((p->>'return_yards')::integer,0)<>0 or coalesce((p->>'touchdown')::boolean,false))then raise exception'Touchback cannot also credit a return or touchdown'using errcode='PT422';end if;
 if kind='penalty'and coalesce((p->>'automatic_first_down')::boolean,false)and(coalesce((p->>'loss_of_down')::boolean,false)or(p->>'penalty_status')='accepted'and coalesce((p->>'result_down')::integer,0)<>1)then raise exception'Penalty flags contradict the confirmed down'using errcode='PT422';end if;
 if kind='fumble'and p?'receiver_roster_id'and p->>'base_play_type'<>'pass_complete'or kind='fumble'and p?'defender_roster_id'and p->>'base_play_type'<>'sack'then raise exception'Football role does not match the base play'using errcode='PT422';end if;
 if p?'assisting_roster_ids'then
 if jsonb_typeof(p->'assisting_roster_ids')<>'array'or jsonb_array_length(p->'assisting_roster_ids')>4 then raise exception'Invalid assisted-tackle list'using errcode='PT422';end if;
 for k in select jsonb_array_elements_text(p->'assisting_roster_ids')loop if k!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'then raise exception'Invalid assisted-tackle reference'using errcode='PT422';end if;end loop;
 select array_agg(x)into ids from jsonb_array_elements_text(p->'assisting_roster_ids')x;
 if coalesce(cardinality(ids),0)<>(select count(distinct x)from unnest(ids)x)or coalesce(cardinality(ids),0)>0 and not(p?'tackler_roster_id'or kind='sack'and p?'defender_roster_id'or kind='fumble'and p->>'base_play_type'='sack'and p?'defender_roster_id')or coalesce(p->>'tackler_roster_id',case when kind='sack'or kind='fumble'and p->>'base_play_type'='sack'then p->>'defender_roster_id'end)=any(ids)then raise exception'Duplicate or missing primary tackle'using errcode='PT422';end if;end if;
 if(kind='sack'or kind='fumble'and p->>'base_play_type'='sack')and p?'defender_roster_id'and p?'tackler_roster_id'and p->>'defender_roster_id'<>p->>'tackler_roster_id'then raise exception'Sack and its primary tackle require one explicit athlete'using errcode='PT422';end if;
end$$;

create function boss_private.football_command(p_actor uuid,p_op text,i jsonb,p_request uuid,p_replay boolean default false)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare g public.games;e public.events;s public.game_football_states;fields text[]:=array['game_id','expected_version'];required text[]:=fields;
 all_play_fields text[]:=array['roster_id','receiver_roster_id','defender_roster_id','tackler_roster_id','assisting_roster_ids','forced_fumble_roster_id','recovery_roster_id','returner_roster_id','pass_defender_roster_id','yards','return_yards','kick_yards','kick_distance','interception_spot','touchdown','made','touchback','recovery_side','base_play_type','penalty_status','penalty_yards','automatic_first_down','loss_of_down','no_play','result_side','result_ball_spot','result_down','result_distance'];
 kind text;event_side text;other text;k text;role_side text;rid uuid;ids uuid[];target public.game_football_events;payload jsonb:='{}';reason text;period integer;clock_value bigint;origin bigint;eventid uuid:=gen_random_uuid();opid uuid;before_state jsonb;before_field jsonb;after_field jsonb;rebuilt jsonb;candidate jsonb;occ jsonb;primary_total bigint;opponent_total bigint;prior_primary bigint;prior_opponent bigint;duration bigint;slot_number integer;is_play boolean;number integer;opened boolean;begin
 case p_op
 when'football.configure'then fields:=fields||array['quarter_seconds','overtime_format','overtime_seconds','max_overtime_periods','play_clock_seconds','lineup_size','enforce_lineup','kneel_counts_as_rush'];required:=fields;
 when'football.period.start','football.period.end','football.clock.start','football.clock.stop'then null;
 when'football.clock.set'then fields:=fields||array['clock_ms','reason'];required:=fields;
 when'football.state.set'then fields:=fields||array['side','ball_spot','down','distance','primary_direction','reason'];required:=fields;
 when'football.lineup.set'then fields:=fields||array['side','roster_ids'];required:=fields;
 when'football.substitute'then fields:=fields||array['side','out_roster_id','in_roster_id'];required:=fields;
 when'football.play.add'then fields:=fields||array['play_type','side']||all_play_fields;required:=required||array['play_type','side'];
 when'football.play.correct'then fields:=fields||array['play_type','side','event_id','reason']||all_play_fields;required:=required||array['play_type','side','event_id','reason'];
 when'football.play.reverse'then fields:=fields||array['event_id','reason'];required:=fields;
 else raise exception'Invalid Football command'using errcode='PT422';end case;
 if p_op='football.configure'and i->'play_clock_seconds'='null'::jsonb then perform boss_private.games_validate(i-'play_clock_seconds',array_remove(fields,'play_clock_seconds'),array_remove(required,'play_clock_seconds'));else perform boss_private.games_validate(i,fields,required);end if;
 if i?'side'and(jsonb_typeof(i->'side')<>'string'or i->>'side'not in('primary','opponent'))then raise exception'Invalid Football side'using errcode='PT422';end if;
 if p_op in('football.play.add','football.play.correct')then
 if jsonb_typeof(i->'play_type')<>'string'then raise exception'Invalid Football play'using errcode='PT422';end if;
 kind:=i->>'play_type';payload:=i-array['game_id','expected_version','play_type','side','event_id','reason'];perform boss_private.football_play_validate(kind,payload);end if;
 foreach k in array array['out_roster_id','in_roster_id']loop if i?k and(jsonb_typeof(i->k)<>'string'or i->>k!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')then raise exception'Invalid Football substitution reference'using errcode='PT422';end if;end loop;
 if p_actor is distinct from boss_private.current_person_id()then raise exception'Access denied'using errcode='PT403';end if;
 select event_id into e.id from public.games where id=(i->>'game_id')::uuid;if e.id is null then raise exception'Access denied'using errcode='PT403';end if;
 select *into e from public.events where id=e.id for update;select *into g from public.games where id=(i->>'game_id')::uuid for update;
 perform boss_private.games_lock_authority(p_actor,g);perform 1 from public.game_operator_assignments a where a.game_id=g.id and a.person_id=p_actor order by a.id for share;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor()or g.sport_key<>'football'or not boss_private.games_feature(g.organization_id,'football_live_scoring')or not boss_private.games_feature(g.organization_id,'football_stats')or not boss_private.games_feature(g.organization_id,'game_operations')then raise exception'Access denied'using errcode='PT403';end if;
 if p_op='football.configure'then if not boss_private.games_permission(p_actor,'games.manage',g,true)then raise exception'Access denied'using errcode='PT403';end if;
 elsif p_op in('football.play.correct','football.play.reverse')then if not boss_private.games_permission(p_actor,'games.correct',g,true)then raise exception'Access denied'using errcode='PT403';end if;
 else if not boss_private.games_operator_current(p_actor,g)then raise exception'Access denied'using errcode='PT403';end if;end if;
 if g.status in('final','canceled','abandoned','postponed')then raise exception'Game is locked'using errcode='PT409';end if;
 occ:=boss_private.games_occurrence(e,g.occurrence_key,g.occurrence_mode);
 if occ is null or occ->>'status'not in('scheduled','confirmed')or e.event_type_key not in('game','tournament')then raise exception'Game occurrence is not operable'using errcode='PT409';end if;
 select *into s from public.game_football_states where game_id=g.id;
 if p_op<>'football.configure'and s.game_id is null then raise exception'Football is not initialized'using errcode='PT409';end if;
 if(p_op in('football.lineup.set','football.substitute')or coalesce(s.enforce_lineup,false))and not boss_private.games_feature(g.organization_id,'football_lineups')then raise exception'Access denied'using errcode='PT403';end if;
 event_side:=i->>'side';other:=case event_side when'primary'then'opponent'else'primary'end;
 -- Replay checks only current authority and original resources, not a consumed
 -- version/leaf/clock or initial lineup that has legitimately changed.
 foreach k in array array['roster_id','receiver_roster_id','defender_roster_id','tackler_roster_id','forced_fumble_roster_id','recovery_roster_id','returner_roster_id','pass_defender_roster_id']loop
 if payload?k then
 role_side:=case when k in('defender_roster_id','tackler_roster_id','forced_fumble_roster_id','returner_roster_id','pass_defender_roster_id')then other when k='recovery_roster_id'then payload->>'recovery_side'else event_side end;
 rid:=(payload->>k)::uuid;perform boss_private.football_roster(p_actor,g,rid,role_side);end if;end loop;
 if payload?'assisting_roster_ids'then for rid in select value::uuid from jsonb_array_elements_text(payload->'assisting_roster_ids')loop perform boss_private.football_roster(p_actor,g,rid,other);end loop;end if;
 if i?'roster_ids'then
 if jsonb_typeof(i->'roster_ids')<>'array'or jsonb_array_length(i->'roster_ids')not between 1 and s.lineup_size then raise exception'Invalid Football lineup'using errcode='PT422';end if;
 for k in select jsonb_array_elements_text(i->'roster_ids')loop if k!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'then raise exception'Invalid Football lineup reference'using errcode='PT422';end if;perform boss_private.football_roster(p_actor,g,k::uuid,event_side);end loop;end if;
 if i?'out_roster_id'then perform boss_private.football_roster(p_actor,g,(i->>'out_roster_id')::uuid,event_side);perform boss_private.football_roster(p_actor,g,(i->>'in_roster_id')::uuid,event_side);end if;
 if p_replay then
 perform boss_private.games_require_live_auth();if p_actor is distinct from boss_private.require_admin_actor()or not boss_private.games_feature(g.organization_id,'football_live_scoring')or not boss_private.games_feature(g.organization_id,'football_stats')or not boss_private.games_feature(g.organization_id,'game_operations')
 or(p_op='football.configure'and not boss_private.games_permission(p_actor,'games.manage',g,true))or(p_op in('football.play.correct','football.play.reverse')and not boss_private.games_permission(p_actor,'games.correct',g,true))or(p_op not in('football.configure','football.play.correct','football.play.reverse')and not boss_private.games_operator_current(p_actor,g))
 or(p_op in('football.lineup.set','football.substitute')or coalesce(s.enforce_lineup,false))and not boss_private.games_feature(g.organization_id,'football_lineups')then raise exception'Access denied'using errcode='PT403';end if;
 return jsonb_build_object('game_id',g.id,'version',g.version,'message','Saved.');end if;
 if g.version<>(i->>'expected_version')::bigint then raise exception'Game changed; reload before saving'using errcode='PT409';end if;
 before_state:=boss_private.games_core_state(g)||case when s.game_id is not null then jsonb_build_object('football',boss_private.football_state(s))else'{}'::jsonb end;before_field:=s.field_state;origin:=g.last_sequence+1;
 if p_op='football.configure'then
 if s.game_id is not null or exists(select 1 from public.game_basketball_states where game_id=g.id)or exists(select 1 from public.game_soccer_states where game_id=g.id)or g.started_at is not null or g.status not in('scheduled','pregame','delayed')or g.roster_revision=0 or g.primary_score<>0 or g.opponent_score<>0 or exists(select 1 from public.game_operations where game_id=g.id and operation in('game.score.set','game.score.reverse'))then raise exception'Football requires a new zero-score pregame snapshot'using errcode='PT409';end if;
 foreach k in array array['enforce_lineup','kneel_counts_as_rush']loop if jsonb_typeof(i->k)<>'boolean'then raise exception'Invalid Football policy'using errcode='PT422';end if;end loop;
 foreach k in array array['quarter_seconds','overtime_seconds','max_overtime_periods','lineup_size']loop if jsonb_typeof(i->k)<>'number'or i->>k!~'^[0-9]{1,4}$'then raise exception'Invalid Football format'using errcode='PT422';end if;end loop;
 if(i->>'quarter_seconds')::integer not between 60 and 3600 or(i->>'overtime_seconds')::integer not between 60 and 1800 or(i->>'max_overtime_periods')::integer not between 0 and 8 or(i->>'lineup_size')::integer not between 1 and 11 or jsonb_typeof(i->'overtime_format')<>'string'or i->>'overtime_format'not in('none','timed','possession')or((i->>'overtime_format')='none')<>((i->>'max_overtime_periods')::integer=0)then raise exception'Invalid Football format'using errcode='PT422';end if;
 if i->'play_clock_seconds'<>'null'::jsonb and(jsonb_typeof(i->'play_clock_seconds')<>'number'or i->>'play_clock_seconds'!~'^[0-9]{1,2}$'or(i->>'play_clock_seconds')::integer not between 5 and 60)then raise exception'Invalid Football play-clock duration'using errcode='PT422';end if;
 if(i->>'enforce_lineup')::boolean and not boss_private.games_feature(g.organization_id,'football_lineups')then raise exception'Access denied'using errcode='PT403';end if;
 insert into public.game_football_states(game_id,organization_id,quarter_seconds,overtime_format,overtime_seconds,max_overtime_periods,play_clock_seconds,lineup_size,enforce_lineup,kneel_counts_as_rush,roster_revision)
 values(g.id,g.organization_id,(i->>'quarter_seconds')::integer,i->>'overtime_format',(i->>'overtime_seconds')::integer,(i->>'max_overtime_periods')::integer,(i->>'play_clock_seconds')::integer,(i->>'lineup_size')::integer,(i->>'enforce_lineup')::boolean,(i->>'kneel_counts_as_rush')::boolean,g.roster_revision)returning *into s;
 kind:='engine_configure';period:=0;clock_value:=0;payload:=i-array['game_id','expected_version'];before_field:=s.field_state;
 else
 period:=s.period_number;clock_value:=boss_private.football_clock(s);duration:=(case when period>4 then s.overtime_seconds else s.quarter_seconds end)*1000;
 if p_op not in('football.lineup.set','football.play.correct','football.play.reverse')and g.status<>'live'then raise exception'Football operation requires a live game'using errcode='PT409';end if;
 if p_op in('football.play.correct','football.play.reverse')and g.status not in('live','paused','suspended')then raise exception'Game cannot be corrected'using errcode='PT409';end if;
 if p_op in('football.clock.set','football.state.set','football.play.correct','football.play.reverse')then reason:=btrim(i->>'reason');if jsonb_typeof(i->'reason')<>'string'or length(reason)not between 1 and 500 or reason~'[[:cntrl:]]'then raise exception'A bounded correction reason is required'using errcode='PT422';end if;end if;
 case p_op
 when'football.period.start'then
 if s.period_status not in('pending','ended')or s.clock_running or period>=4+s.max_overtime_periods then raise exception'Prior period is not complete'using errcode='PT409';end if;
 if period=0 and s.enforce_lineup and((select count(*)from public.game_football_lineups where game_id=g.id and side='primary')<>s.lineup_size or(select count(*)from public.game_football_lineups where game_id=g.id and side='opponent')<>s.lineup_size)then raise exception'Complete both configured lineups first'using errcode='PT409';end if;
 period:=period+1;clock_value:=(case when period>4 then s.overtime_seconds else s.quarter_seconds end)*1000;
 update public.game_football_states set period_number=period,period_status='active',clock_remaining_ms=clock_value,clock_running=false,clock_anchor=null where game_id=g.id;kind:='period_start';
 when'football.period.end'then
 if s.period_status<>'active'or clock_value<>0 and not(period>4 and s.overtime_format='possession')then raise exception'Period duration is not complete'using errcode='PT409';end if;
 update public.game_football_states set period_status='ended',clock_remaining_ms=clock_value,clock_running=false,clock_anchor=null where game_id=g.id;kind:='period_end';
 when'football.clock.start'then if s.period_status<>'active'or s.clock_running or clock_value=0 then raise exception'Clock cannot start'using errcode='PT409';end if;
 update public.game_football_states set clock_remaining_ms=clock_value,clock_running=true,clock_anchor=clock_timestamp()where game_id=g.id;kind:='clock_start';
 when'football.clock.stop'then if s.period_status<>'active'or not s.clock_running then raise exception'Clock is not running'using errcode='PT409';end if;
 update public.game_football_states set clock_remaining_ms=clock_value,clock_running=false,clock_anchor=null where game_id=g.id;kind:='clock_stop';
 when'football.clock.set'then
 if s.period_status<>'active'or s.clock_running then raise exception'Stop the active period clock before correction'using errcode='PT409';end if;
 if jsonb_typeof(i->'clock_ms')<>'number'or i->>'clock_ms'!~'^[0-9]{1,7}$'or(i->>'clock_ms')::bigint>duration then raise exception'Invalid Football clock'using errcode='PT422';end if;
 clock_value:=(i->>'clock_ms')::bigint;update public.game_football_states set clock_remaining_ms=clock_value,clock_anchor=null where game_id=g.id;kind:='clock_set';payload:=jsonb_build_object('clock_ms',clock_value);
 when'football.state.set'then
 if s.period_status<>'active'then raise exception'Initialize an active period first'using errcode='PT409';end if;
 foreach k in array array['ball_spot','down','distance']loop if jsonb_typeof(i->k)<>'number'or i->>k!~'^[0-9]{1,3}$'then raise exception'Invalid confirmed Football field'using errcode='PT422';end if;end loop;
 if(i->>'ball_spot')::integer not between 0 and 99 or(i->>'down')::integer not between 1 and 4 or(i->>'distance')::integer not between 1 and 100 or(i->>'distance')::integer>100-(i->>'ball_spot')::integer or jsonb_typeof(i->'primary_direction')<>'string'or i->>'primary_direction'not in('increasing','decreasing')then raise exception'Invalid confirmed Football field'using errcode='PT422';end if;
 kind:='state_set';payload:=i-array['game_id','expected_version','side','reason'];
 when'football.lineup.set'then
 if period<>0 then raise exception'Initial lineup is sealed; use substitution'using errcode='PT409';end if;
 select array_agg(value::uuid)into ids from jsonb_array_elements_text(i->'roster_ids');
 if cardinality(ids)<>(select count(distinct x)from unnest(ids)x)or s.enforce_lineup and cardinality(ids)<>s.lineup_size then raise exception'Invalid Football lineup size or duplicates'using errcode='PT422';end if;
 delete from public.game_football_lineups where game_id=g.id and side=event_side;
 insert into public.game_football_lineups(game_id,organization_id,side,slot,roster_id)select g.id,g.organization_id,event_side,ordinality,value from unnest(ids)with ordinality u(value,ordinality);
 kind:='lineup_set';payload:=jsonb_build_object('roster_ids',to_jsonb(ids));
 when'football.substitute'then
 if s.period_status<>'active'then raise exception'Participation change requires an active period'using errcode='PT409';end if;
 select slot into slot_number from public.game_football_lineups where game_id=g.id and side=event_side and roster_id=(i->>'out_roster_id')::uuid;
 if slot_number is null or i->>'out_roster_id'=i->>'in_roster_id'or exists(select 1 from public.game_football_lineups where game_id=g.id and roster_id=(i->>'in_roster_id')::uuid)then raise exception'Invalid substitution participation'using errcode='PT409';end if;
 update public.game_football_lineups set roster_id=(i->>'in_roster_id')::uuid where game_id=g.id and side=event_side and slot=slot_number;
 select array_agg(roster_id order by slot)into ids from public.game_football_lineups where game_id=g.id and side=event_side;
 kind:='substitution';payload:=jsonb_build_object('roster_ids',to_jsonb(ids),'out_roster_id',i->>'out_roster_id','in_roster_id',i->>'in_roster_id');
 else
 if p_op='football.play.add'and s.period_status<>'active'then raise exception'Initialize an active period before entry'using errcode='PT409';end if;
 if p_op in('football.play.correct','football.play.reverse')then
 select *into target from boss_private.football_active_events(g.id)where id=(i->>'event_id')::uuid;if target.id is null then raise exception'Play is not a current correctable fact'using errcode='PT409';end if;
 period:=target.period_number;clock_value:=target.clock_ms;origin:=target.origin_sequence;
 if p_op='football.play.reverse'then kind:='reversal';event_side:=target.side;payload:='{}';end if;end if;
 if kind<>'reversal'and s.enforce_lineup then
 foreach k in array array['roster_id','receiver_roster_id','defender_roster_id','tackler_roster_id','forced_fumble_roster_id','recovery_roster_id','returner_roster_id','pass_defender_roster_id']loop if payload?k then
 role_side:=case when k in('defender_roster_id','tackler_roster_id','forced_fumble_roster_id','returner_roster_id','pass_defender_roster_id')then other when k='recovery_roster_id'then payload->>'recovery_side'else event_side end;rid:=(payload->>k)::uuid;
 if p_op='football.play.correct'then if not boss_private.football_field_at(g.id,role_side,rid,origin)then raise exception'Corrected athlete was not on the field at the original play'using errcode='PT409';end if;else perform boss_private.football_roster(p_actor,g,rid,role_side,true);end if;end if;end loop;
 for rid in select value::uuid from jsonb_array_elements_text(coalesce(payload->'assisting_roster_ids','[]'))loop
 if p_op='football.play.correct'then if not boss_private.football_field_at(g.id,other,rid,origin)then raise exception'Corrected defender was not on the field at the original play'using errcode='PT409';end if;else perform boss_private.football_roster(p_actor,g,rid,other,true);end if;end loop;end if;
 end case;end if;
 -- Corrections replay the complete accepted history before appending. New facts
 -- transition the closed canonical state once; reads/seals independently rebuild
 -- the full ledger. A growing history never turns ordinary entry into O(n).
 if p_op in('football.play.correct','football.play.reverse')then
 rebuilt:=boss_private.football_rebuild(g.id);
 select coalesce(sum((x->>'points')::bigint)filter(where x->>'score_side'='primary'),0),coalesce(sum((x->>'points')::bigint)filter(where x->>'score_side'='opponent'),0)into prior_primary,prior_opponent from jsonb_array_elements(rebuilt->'plays')x;
 if prior_primary<>g.primary_score or prior_opponent<>g.opponent_score then raise exception'Football score projection is inconsistent'using errcode='PT409';end if;
 candidate:=jsonb_build_object('id',eventid,'game_id',g.id,'sequence',g.last_sequence+1,'origin_sequence',origin,'period_number',period,'clock_ms',clock_value,'side',event_side,'event_type',kind,'payload',payload,'roster_id',payload->>'roster_id');
 rebuilt:=boss_private.football_simulate(g.id,candidate,target.id);after_field:=rebuilt->'field_state';
 select coalesce(sum((x->>'points')::bigint)filter(where x->>'score_side'='primary'),0),coalesce(sum((x->>'points')::bigint)filter(where x->>'score_side'='opponent'),0)into primary_total,opponent_total from jsonb_array_elements(rebuilt->'plays')x;
 if primary_total not between 0 and 1000000 or opponent_total not between 0 and 1000000 then raise exception'Football score exceeds bound'using errcode='PT422';end if;
 select coalesce(x->'before_field',before_field),coalesce(x->'after_field',after_field)into before_field,after_field from jsonb_array_elements(rebuilt->'plays')x where(x->>'event_id')::uuid=eventid;
 if not found then before_field:=s.field_state;after_field:=rebuilt->'field_state';end if;
 else
 is_play:=kind=any(array['rush','pass_complete','pass_incomplete','sack','kneel','spike','interception','fumble','fumble_recovery','turnover_on_downs','kickoff','kickoff_return','punt','punt_return','field_goal','extra_point','two_point','safety','penalty','touchdown']);
 before_field:=s.field_state;after_field:=s.field_state;number:=coalesce((s.field_state->>'drive_number')::integer,0);opened:=coalesce((s.field_state->>'drive_open')::boolean,false);
 if is_play or kind='state_set'then
 after_field:=boss_private.football_transition(s.field_state,kind,event_side,payload);
 if kind='state_set'then opened:=false;
 elsif kind not in('extra_point','two_point','kickoff','kickoff_return')and not opened then number:=number+1;opened:=true;end if;
 if after_field->>'end_reason'is not null then opened:=false;end if;
 elsif kind='period_end'and(period=2 or period>=4)then opened:=false;end if;
 after_field:=after_field||jsonb_build_object('drive_number',number,'drive_open',opened);
 primary_total:=g.primary_score+case when after_field->>'score_side'='primary'then coalesce((after_field->>'points')::bigint,0)else 0 end;
 opponent_total:=g.opponent_score+case when after_field->>'score_side'='opponent'then coalesce((after_field->>'points')::bigint,0)else 0 end;
 rebuilt:=jsonb_build_object('field_state',after_field-array['points','score_side','first_down_side','end_reason']);
 end if;
 if primary_total not between 0 and 1000000 or opponent_total not between 0 and 1000000 then raise exception'Football score exceeds bound'using errcode='PT422';end if;
 -- An independent roster-view grant can naturally expire while a historical
 -- replay is computed. Recheck every actual referenced side before commit.
 foreach k in array array['roster_id','receiver_roster_id','defender_roster_id','tackler_roster_id','forced_fumble_roster_id','recovery_roster_id','returner_roster_id','pass_defender_roster_id']loop if payload?k then
 role_side:=case when k in('defender_roster_id','tackler_roster_id','forced_fumble_roster_id','returner_roster_id','pass_defender_roster_id')then other when k='recovery_roster_id'then payload->>'recovery_side'else event_side end;
 if not boss_private.football_roster_side(p_actor,g,case role_side when'primary'then g.primary_team_id else g.opponent_team_id end)then raise exception'Access denied'using errcode='PT403';end if;end if;end loop;
 if coalesce(jsonb_array_length(payload->'assisting_roster_ids'),0)>0 and not boss_private.football_roster_side(p_actor,g,case other when'primary'then g.primary_team_id else g.opponent_team_id end)then raise exception'Access denied'using errcode='PT403';end if;
 if p_op in('football.lineup.set','football.substitute')and not boss_private.football_roster_side(p_actor,g,case event_side when'primary'then g.primary_team_id else g.opponent_team_id end)then raise exception'Access denied'using errcode='PT403';end if;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor()or not boss_private.games_feature(g.organization_id,'football_live_scoring')or not boss_private.games_feature(g.organization_id,'football_stats')or not boss_private.games_feature(g.organization_id,'game_operations')
 or(p_op='football.configure'and not boss_private.games_permission(p_actor,'games.manage',g,true))or(p_op in('football.play.correct','football.play.reverse')and not boss_private.games_permission(p_actor,'games.correct',g,true))or(p_op not in('football.configure','football.play.correct','football.play.reverse')and not boss_private.games_operator_current(p_actor,g))
 or(p_op in('football.lineup.set','football.substitute')or coalesce(s.enforce_lineup,false))and not boss_private.games_feature(g.organization_id,'football_lineups')then raise exception'Access denied'using errcode='PT403';end if;
 update public.game_football_states set field_state=rebuilt->'field_state'where game_id=g.id returning *into s;
 update public.games set primary_score=primary_total,opponent_score=opponent_total,version=version+1,updated_by_person_id=p_actor,updated_at=clock_timestamp()where id=g.id;
 opid:=boss_private.games_append(g.id,p_actor,p_op,p_request,before_state,jsonb_build_object('football',boss_private.football_state(s),'football_time',jsonb_build_object('period_number',period,'clock_ms',clock_value),'football_event_type',kind,'football_event_id',eventid),target.operation_id);
 insert into public.game_football_events(id,organization_id,game_id,operation_id,sequence,origin_sequence,period_number,clock_ms,side,event_type,roster_id,payload,before_field,after_field,actor_person_id,request_id,correction_of,reason)
 values(eventid,g.organization_id,g.id,opid,g.last_sequence+1,origin,period,clock_value,event_side,kind,(payload->>'roster_id')::uuid,payload,coalesce(before_field,'{}'),coalesce(after_field,'{}'),p_actor,p_request,target.id,reason);
 return jsonb_build_object('game_id',g.id,'version',g.version+1,'message','Football change saved.');
end$$;
DO $$declare r record;begin for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like'football_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role',r.signature);end loop;end$$;
