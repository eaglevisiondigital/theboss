-- All Soccer writes serialize through the canonical Calendar/game locks and
-- recheck the current session, exact-game operator and actual roster sides.
create function boss_private.soccer_roster(p_actor uuid,g public.games,p_roster uuid,p_side text,p_on_field boolean default false) returns public.game_roster_snapshots
language plpgsql volatile security definer set search_path='' as $$
declare r public.game_roster_snapshots;team uuid;begin
 team:=case p_side when 'primary' then g.primary_team_id when 'opponent' then g.opponent_team_id end;
 select * into r from public.game_roster_snapshots where id=p_roster and game_id=g.id and organization_id=g.organization_id and revision=g.roster_revision and team_id=team;
 if r.id is null or not boss_private.soccer_roster_side(p_actor,g,team) then raise exception 'Access denied' using errcode='PT403';end if;
 perform 1 from public.people p where p.id=r.person_id for share;
 perform 1 from public.participants p where p.id=r.participant_id for share;
 if not r.active or not exists(select 1 from public.people p join public.participants a on a.person_id=p.id and a.id=r.participant_id where p.id=r.person_id and p.status='active' and a.status='active') then raise exception 'Athlete is not eligible in this game snapshot' using errcode='PT409';end if;
 if p_on_field and not exists(select 1 from public.game_soccer_lineups where game_id=g.id and side=p_side and roster_id=r.id and not dismissed) then raise exception 'Athlete is not on the field' using errcode='PT409';end if;
 return r;
end$$;
-- These helpers use original fact order, not later correction append order.
create function boss_private.soccer_field_at(p_game uuid,p_side text,p_roster uuid,p_origin bigint) returns boolean language sql stable security definer set search_path='' as $$
 select p_roster=any(coalesce((select e.lineup_roster_ids from boss_private.soccer_active_events(p_game)e where e.side=p_side and e.lineup_roster_ids is not null and e.origin_sequence<p_origin order by e.origin_sequence desc limit 1),'{}'::uuid[]))
$$;
create function boss_private.soccer_keeper_at(p_game uuid,p_side text,p_origin bigint) returns uuid language sql stable security definer set search_path='' as $$
 select e.goalkeeper_roster_id from boss_private.soccer_active_events(p_game)e where e.side=p_side and e.lineup_roster_ids is not null and e.origin_sequence<p_origin order by e.origin_sequence desc limit 1
$$;
create function boss_private.soccer_command(p_actor uuid,p_op text,i jsonb,p_request uuid,p_replay boolean default false) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare g public.games;e public.events;s public.game_soccer_states;before_state jsonb;occ jsonb;
 fields text[]:=array['game_id','expected_version'];required text[]:=fields;kind text;event_side text;defending_side text;rid uuid;other_rid uuid;keeper uuid;prior_keeper uuid;
 target public.game_soccer_events;context public.game_soccer_events;r public.game_roster_snapshots;
 eventid uuid:=gen_random_uuid();opid uuid;clock_value bigint;display_value bigint;playing_value bigint;segment integer;origin bigint;
 primary_total bigint;opponent_total bigint;reason text;ids uuid[];prior_ids uuid[];k text;team uuid;slot_number integer;was_field boolean:=false;participation boolean:=false;newgoal integer:=0;oldgoal integer:=0;newside text;oldside text;begin
 case p_op
 when 'soccer.configure' then fields:=fields||array['regulation_segments','segment_seconds','extra_time_segments','extra_time_seconds','lineup_size','enforce_lineup','allow_reentry','max_substitutions'];required:=array['game_id','expected_version','regulation_segments','segment_seconds','extra_time_segments','extra_time_seconds','lineup_size','enforce_lineup','allow_reentry'];
 when 'soccer.segment.start' then null;
 when 'soccer.segment.end' then null;
 when 'soccer.clock.start' then null;
 when 'soccer.clock.stop' then null;
 when 'soccer.clock.set' then fields:=fields||array['clock_ms','reason'];required:=fields;
 when 'soccer.added_time.set' then fields:=fields||array['added_time_seconds','reason'];required:=fields;
 when 'soccer.lineup.set' then fields:=fields||array['side','roster_ids','goalkeeper_roster_id'];required:=required||array['side','roster_ids'];
 when 'soccer.keeper.set' then fields:=fields||array['side','goalkeeper_roster_id'];required:=fields;
 when 'soccer.substitute' then fields:=fields||array['side','out_roster_id','in_roster_id','goalkeeper_roster_id'];required:=required||array['side','out_roster_id','in_roster_id'];
 when 'soccer.event.add' then fields:=fields||array['event_type','side','roster_id','goalkeeper_roster_id','scoring_event_id'];required:=required||array['event_type','side'];
 when 'soccer.event.correct' then fields:=fields||array['event_type','side','roster_id','goalkeeper_roster_id','scoring_event_id','out_roster_id','in_roster_id','event_id','reason'];required:=required||array['event_type','side','event_id','reason'];
 when 'soccer.event.reverse' then fields:=fields||array['event_id','reason'];required:=fields;
 else raise exception 'Invalid Soccer command' using errcode='PT422';end case;
 perform boss_private.games_validate(case when p_op='soccer.configure' and i->'max_substitutions'='null'::jsonb then i-'max_substitutions' else i end,fields,required);
 if p_op in('soccer.event.add','soccer.event.correct') then
 if jsonb_typeof(i->'event_type')<>'string' or not(i->>'event_type'=any(array['goal','shot_off_target','shot_saved','shot_blocked','penalty_goal','penalty_miss','penalty_saved','own_goal','assist','yellow_card','second_yellow','red_card','foul'])
 or(p_op='soccer.event.correct' and i->>'event_type' in('substitution','keeper_set'))) then raise exception 'Invalid Soccer event type for this operation' using errcode='PT422';end if;
 if i->>'event_type' in('substitution','keeper_set') and(i?'roster_id' or i?'scoring_event_id') then raise exception 'Participation replacement fields are invalid' using errcode='PT422';end if;
 if i->>'event_type'='keeper_set' and(i?'out_roster_id' or i?'in_roster_id') then raise exception 'Goalkeeper replacement fields are invalid' using errcode='PT422';end if;
 end if;
 foreach k in array array['roster_id','out_roster_id','in_roster_id','goalkeeper_roster_id','scoring_event_id'] loop
 if i?k and(jsonb_typeof(i->k)<>'string' or i->>k!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') then raise exception 'Invalid Soccer reference' using errcode='PT422';end if;end loop;
 if p_actor is distinct from boss_private.current_person_id() then raise exception 'Access denied' using errcode='PT403';end if;
 select event_id into e.id from public.games where id=(i->>'game_id')::uuid;
 if e.id is null then raise exception 'Access denied' using errcode='PT403';end if;
 select * into e from public.events where id=e.id for update;
 select * into g from public.games where id=(i->>'game_id')::uuid for update;
 perform boss_private.games_lock_authority(p_actor,g);
 perform 1 from public.game_operator_assignments a where a.game_id=g.id and a.person_id=p_actor order by a.id for share;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or g.sport_key<>'soccer' or not boss_private.games_feature(g.organization_id,'soccer_live_scoring')
 or not boss_private.games_feature(g.organization_id,'soccer_stats') or not boss_private.games_feature(g.organization_id,'game_operations') then raise exception 'Access denied' using errcode='PT403';end if;
 if p_op='soccer.configure' then
 if not boss_private.games_permission(p_actor,'games.manage',g,true) then raise exception 'Access denied' using errcode='PT403';end if;
 elsif p_op in('soccer.event.correct','soccer.event.reverse') then
 if not boss_private.games_permission(p_actor,'games.correct',g,true) then raise exception 'Access denied' using errcode='PT403';end if;
 else
 if not boss_private.games_operator_current(p_actor,g) then raise exception 'Access denied' using errcode='PT403';end if;
 end if;
 if g.status in('final','canceled','abandoned','postponed') then raise exception 'Game is locked' using errcode='PT409';end if;
 occ:=boss_private.games_occurrence(e,g.occurrence_key,g.occurrence_mode);
 if occ is null or occ->>'status' not in('scheduled','confirmed') or e.event_type_key not in('game','tournament') then raise exception 'Game occurrence is not operable' using errcode='PT409';end if;
 select * into s from public.game_soccer_states where game_id=g.id;
 if p_op<>'soccer.configure' and s.game_id is null then raise exception 'Soccer is not initialized' using errcode='PT409';end if;
 if (p_op in('soccer.lineup.set','soccer.keeper.set','soccer.substitute') or coalesce(s.enforce_lineup,false)
 or(p_op='soccer.event.correct' and i->>'event_type' in('substitution','keeper_set'))) and not boss_private.games_feature(g.organization_id,'soccer_lineups') then raise exception 'Access denied' using errcode='PT403';end if;
 if p_replay then
 if i?'roster_id' then perform boss_private.soccer_roster(p_actor,g,(i->>'roster_id')::uuid,i->>'side');end if;
 if i?'out_roster_id' then perform boss_private.soccer_roster(p_actor,g,(i->>'out_roster_id')::uuid,i->>'side');perform boss_private.soccer_roster(p_actor,g,(i->>'in_roster_id')::uuid,i->>'side');end if;
 if i?'goalkeeper_roster_id' then perform boss_private.soccer_roster(p_actor,g,(i->>'goalkeeper_roster_id')::uuid,case when p_op in('soccer.keeper.set','soccer.lineup.set','soccer.substitute') or i->>'event_type' in('keeper_set','substitution') then i->>'side' when i->>'side'='primary' then 'opponent' else 'primary' end);end if;
 if i?'roster_ids' then for rid in select value::uuid from jsonb_array_elements_text(i->'roster_ids') loop perform boss_private.soccer_roster(p_actor,g,rid,i->>'side');end loop;end if;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_feature(g.organization_id,'soccer_live_scoring') or not boss_private.games_feature(g.organization_id,'soccer_stats') or not boss_private.games_feature(g.organization_id,'game_operations')
 or(p_op='soccer.configure' and not boss_private.games_permission(p_actor,'games.manage',g,true))
 or(p_op in('soccer.event.correct','soccer.event.reverse') and not boss_private.games_permission(p_actor,'games.correct',g,true))
 or(p_op not in('soccer.configure','soccer.event.correct','soccer.event.reverse') and not boss_private.games_operator_current(p_actor,g)) then raise exception 'Access denied' using errcode='PT403';end if;
 return jsonb_build_object('game_id',g.id,'version',g.version,'message','Saved.');end if;
 if g.version<>(i->>'expected_version')::bigint then raise exception 'Game changed; reload before saving' using errcode='PT409';end if;
 before_state:=boss_private.games_core_state(g)||case when s.game_id is not null then jsonb_build_object('soccer',boss_private.soccer_state(s)) else '{}'::jsonb end;
 origin:=g.last_sequence+1;
 if p_op='soccer.configure' then
 if s.game_id is not null or exists(select 1 from public.game_basketball_states where game_id=g.id) or g.started_at is not null or g.status not in('scheduled','pregame','delayed') or g.roster_revision=0 or g.primary_score<>0 or g.opponent_score<>0
 or exists(select 1 from public.game_operations where game_id=g.id and operation in('game.score.set','game.score.reverse')) then raise exception 'Soccer requires a new zero-score pregame snapshot' using errcode='PT409';end if;
 foreach k in array array['enforce_lineup','allow_reentry'] loop if jsonb_typeof(i->k)<>'boolean' then raise exception 'Invalid Soccer policy' using errcode='PT422';end if;end loop;
 foreach k in array array['regulation_segments','segment_seconds','extra_time_segments','extra_time_seconds','lineup_size'] loop
 if jsonb_typeof(i->k)<>'number' or i->>k!~'^[0-9]{1,4}$' then raise exception 'Invalid Soccer format' using errcode='PT422';end if;end loop;
 if(i->>'regulation_segments')::integer not in(2,4) or(i->>'segment_seconds')::integer not between 60 and 5400 or(i->>'extra_time_segments')::integer not in(0,2)
 or(i->>'extra_time_seconds')::integer not between 60 and 1800 or(i->>'lineup_size')::integer not between 1 and 11 then raise exception 'Invalid Soccer format' using errcode='PT422';end if;
 if i?'max_substitutions' and i->'max_substitutions'<>'null'::jsonb and(jsonb_typeof(i->'max_substitutions')<>'number' or i->>'max_substitutions'!~'^[0-9]{1,3}$' or(i->>'max_substitutions')::integer>100) then raise exception 'Invalid substitution limit' using errcode='PT422';end if;
 if(i->>'enforce_lineup')::boolean and not boss_private.games_feature(g.organization_id,'soccer_lineups') then raise exception 'Access denied' using errcode='PT403';end if;
 insert into public.game_soccer_states(game_id,organization_id,regulation_segments,segment_seconds,extra_time_segments,extra_time_seconds,lineup_size,enforce_lineup,allow_reentry,max_substitutions,roster_revision)
 values(g.id,g.organization_id,(i->>'regulation_segments')::integer,(i->>'segment_seconds')::integer,(i->>'extra_time_segments')::integer,(i->>'extra_time_seconds')::integer,(i->>'lineup_size')::integer,(i->>'enforce_lineup')::boolean,(i->>'allow_reentry')::boolean,(i->>'max_substitutions')::integer,g.roster_revision) returning * into s;
 kind:='engine_configure';segment:=0;clock_value:=0;display_value:=0;playing_value:=0;
 else
 clock_value:=boss_private.soccer_clock(s);segment:=s.segment_number;display_value:=boss_private.soccer_display_clock(s,clock_value);playing_value:=s.segment_base_ms+clock_value;
 if p_op not in('soccer.lineup.set','soccer.event.correct','soccer.event.reverse') and g.status<>'live' then raise exception 'Soccer operation requires a live game' using errcode='PT409';end if;
 if p_op in('soccer.event.correct','soccer.event.reverse') and g.status not in('live','paused','suspended') then raise exception 'Game cannot be corrected' using errcode='PT409';end if;
 if p_op in('soccer.clock.set','soccer.added_time.set','soccer.event.correct','soccer.event.reverse') then
 reason:=btrim(i->>'reason');if jsonb_typeof(i->'reason')<>'string' or reason is null or length(reason) not between 1 and 500 or reason~'[[:cntrl:]]' then raise exception 'A bounded correction reason is required' using errcode='PT422';end if;end if;
 case p_op
 when 'soccer.segment.start' then
 if s.segment_status not in('pending','ended') or s.clock_running or s.segment_number>=s.regulation_segments+s.extra_time_segments then raise exception 'Prior segment is not complete' using errcode='PT409';end if;
 if s.segment_number=0 and s.enforce_lineup then
 for event_side in select unnest(array['primary','opponent']) loop
 team:=case event_side when 'primary' then g.primary_team_id else g.opponent_team_id end;
 if team is null or(select count(*) from public.game_soccer_lineups l where l.game_id=g.id and l.side=event_side and not l.dismissed)<>s.lineup_size then raise exception 'Complete both configured lineups first' using errcode='PT409';end if;
 end loop;end if;
 update public.game_soccer_states set segment_base_ms=case when segment_number>0 then segment_base_ms+clock_value else 0 end,
 participation_complete=case when segment_number=0 then enforce_lineup else participation_complete end,segment_number=segment_number+1,segment_status='active',clock_elapsed_ms=0,added_time_seconds=0,clock_running=false,clock_anchor=null where game_id=g.id returning * into s;
 segment:=s.segment_number;clock_value:=0;display_value:=boss_private.soccer_display_clock(s,0);playing_value:=s.segment_base_ms;kind:='segment_start';event_side:=null;
 when 'soccer.segment.end' then
 if s.segment_status<>'active' or clock_value<(case when segment>s.regulation_segments then s.extra_time_seconds else s.segment_seconds end+s.added_time_seconds)*1000 then raise exception 'Segment duration and declared added time are not complete' using errcode='PT409';end if;
 update public.game_soccer_states set segment_status='ended',clock_elapsed_ms=clock_value,clock_running=false,clock_anchor=null where game_id=g.id;kind:='segment_end';
 when 'soccer.clock.start' then
 if s.segment_status<>'active' or s.clock_running or clock_value>=(case when segment>s.regulation_segments then s.extra_time_seconds else s.segment_seconds end+s.added_time_seconds)*1000 then raise exception 'Clock cannot start' using errcode='PT409';end if;
 update public.game_soccer_states set clock_elapsed_ms=clock_value,clock_running=true,clock_anchor=clock_timestamp() where game_id=g.id;kind:='clock_start';
 when 'soccer.clock.stop' then
 if s.segment_status<>'active' or not s.clock_running then raise exception 'Clock is not running' using errcode='PT409';end if;
 update public.game_soccer_states set clock_elapsed_ms=clock_value,clock_running=false,clock_anchor=null where game_id=g.id;kind:='clock_stop';
 when 'soccer.clock.set' then
 if s.segment_status<>'active' or s.clock_running then raise exception 'Stop the active segment clock before correction' using errcode='PT409';end if;
 if jsonb_typeof(i->'clock_ms')<>'number' or i->>'clock_ms'!~'^[0-9]{1,7}$' or(i->>'clock_ms')::bigint>(case when segment>s.regulation_segments then s.extra_time_seconds else s.segment_seconds end+s.added_time_seconds)*1000 then raise exception 'Invalid segment clock' using errcode='PT422';end if;
 update public.game_soccer_states set participation_complete=participation_complete and(i->>'clock_ms')::bigint>=clock_value,clock_elapsed_ms=(i->>'clock_ms')::bigint,clock_anchor=null where game_id=g.id;
 clock_value:=(i->>'clock_ms')::bigint;display_value:=boss_private.soccer_display_clock(s,clock_value);playing_value:=s.segment_base_ms+clock_value;kind:='clock_set';
 when 'soccer.added_time.set' then
 if s.segment_status<>'active' or jsonb_typeof(i->'added_time_seconds')<>'number' or i->>'added_time_seconds'!~'^[0-9]{1,4}$' or(i->>'added_time_seconds')::integer>1800
 or clock_value>(case when segment>s.regulation_segments then s.extra_time_seconds else s.segment_seconds end+(i->>'added_time_seconds')::integer)*1000 then raise exception 'Invalid added time' using errcode='PT422';end if;
 update public.game_soccer_states set clock_elapsed_ms=clock_value,added_time_seconds=(i->>'added_time_seconds')::integer,clock_anchor=case when clock_running then clock_timestamp() end where game_id=g.id;kind:='added_time_set';
 when 'soccer.lineup.set' then
 if s.segment_number<>0 then raise exception 'Initial lineup is already sealed; use substitution' using errcode='PT409';end if;
 event_side:=i->>'side';if event_side not in('primary','opponent') or jsonb_typeof(i->'roster_ids')<>'array' or jsonb_array_length(i->'roster_ids')>s.lineup_size then raise exception 'Invalid initial lineup' using errcode='PT422';end if;
 for k in select value from jsonb_array_elements_text(i->'roster_ids') loop if k!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then raise exception 'Invalid lineup reference' using errcode='PT422';end if;end loop;
 select coalesce(array_agg(value::uuid),'{}') into ids from jsonb_array_elements_text(i->'roster_ids');
 if cardinality(ids)<>(select count(distinct x) from unnest(ids)x) or(s.enforce_lineup and cardinality(ids)<>s.lineup_size) then raise exception 'Invalid lineup size or duplicate player' using errcode='PT422';end if;
 if not boss_private.soccer_roster_side(p_actor,g,case event_side when 'primary' then g.primary_team_id else g.opponent_team_id end) then raise exception 'Access denied' using errcode='PT403';end if;
 foreach rid in array ids loop perform boss_private.soccer_roster(p_actor,g,rid,event_side);end loop;rid:=null;
 keeper:=(i->>'goalkeeper_roster_id')::uuid;
 if keeper is not null and not keeper=any(ids) then raise exception 'Goalkeeper must be in this lineup' using errcode='PT422';end if;
 delete from public.game_soccer_lineups where game_id=g.id and side=event_side;
 insert into public.game_soccer_lineups(game_id,organization_id,side,slot,roster_id,goalkeeper) select g.id,g.organization_id,event_side,ordinality,value,coalesce(value=keeper,false) from unnest(ids) with ordinality as u(value,ordinality);
 kind:='lineup_set';participation:=true;
 when 'soccer.keeper.set','soccer.substitute' then
 kind:=case p_op when 'soccer.keeper.set' then 'keeper_set' else 'substitution' end;
 -- Participation changes use the same finite validation as safe leaf replacements.
 else
 if p_op='soccer.event.add' and s.segment_status<>'active' then raise exception 'Initialize an active segment before entry' using errcode='PT409';end if;
 if p_op in('soccer.event.correct','soccer.event.reverse') then
 select * into target from boss_private.soccer_active_events(g.id) where id=(i->>'event_id')::uuid;
 if target.id is null or target.event_type not in('goal','shot_off_target','shot_saved','shot_blocked','penalty_goal','penalty_miss','penalty_saved','own_goal','assist','yellow_card','second_yellow','red_card','foul','substitution','keeper_set') then raise exception 'Event is not a current correctable play' using errcode='PT409';end if;
 if exists(select 1 from boss_private.soccer_active_events(g.id)a where a.scoring_event_id=target.id) then raise exception 'Correct or reverse the dependent assist first' using errcode='PT409';end if;
 if target.event_type='yellow_card' and exists(select 1 from boss_private.soccer_active_events(g.id)a where a.roster_id=target.roster_id and a.event_type='second_yellow' and a.origin_sequence>target.origin_sequence) then raise exception 'Resolve the dependent second yellow first' using errcode='PT409';end if;
 if p_op='soccer.event.correct' and i->>'event_type' in('substitution','keeper_set') and i->>'event_type'<>target.event_type then raise exception 'Participation correction must preserve its kind' using errcode='PT422';end if;
 if target.event_type in('substitution','keeper_set','red_card','second_yellow') or(p_op='soccer.event.correct' and i->>'event_type' in('red_card','second_yellow')) then
 if exists(select 1 from boss_private.soccer_active_events(g.id)a where a.origin_sequence>target.origin_sequence and a.event_type in('goal','shot_off_target','shot_saved','shot_blocked','penalty_goal','penalty_miss','penalty_saved','own_goal','assist','yellow_card','second_yellow','red_card','foul','substitution','keeper_set')) then raise exception 'Participation correction has dependent later play; retain history' using errcode='PT409';end if;
 update public.game_soccer_states set participation_complete=false where game_id=g.id;
 end if;
 segment:=target.segment_number;clock_value:=target.clock_ms;display_value:=target.display_clock_ms;playing_value:=target.playing_ms;origin:=target.origin_sequence;
 if target.event_type in('substitution','keeper_set') then
 if p_op='soccer.event.correct' and(i->>'event_type'<>target.event_type or i->>'side'<>target.side) then raise exception 'Participation correction must preserve its kind and side' using errcode='PT422';end if;
 -- Reconstruct only the safe current leaf. Dismissed slots never become vacant.
 if target.event_type='substitution' then
 update public.game_soccer_lineups set roster_id=target.secondary_roster_id where game_id=g.id and side=target.side and roster_id=target.roster_id and not dismissed;
 if not found then raise exception 'Substitution cannot be safely reconstructed' using errcode='PT409';end if;
 end if;
 update public.game_soccer_lineups set goalkeeper=false where game_id=g.id and side=target.side;
 update public.game_soccer_lineups set goalkeeper=true where game_id=g.id and side=target.side and roster_id=target.prior_goalkeeper_roster_id and not dismissed;
 end if;
 end if;
 if p_op='soccer.event.reverse' then kind:='reversal';event_side:=target.side;
 else kind:=i->>'event_type';event_side:=i->>'side';end if;
 end case;
 if kind in('keeper_set','substitution') then
 if s.segment_status<>'active' and p_op<>'soccer.event.correct' then raise exception 'Participation change requires an active segment' using errcode='PT409';end if;
 event_side:=i->>'side';if event_side not in('primary','opponent') then raise exception 'Invalid Soccer side' using errcode='PT422';end if;
 select coalesce(array_agg(l.roster_id order by l.slot) filter(where not l.dismissed),'{}'),max(l.roster_id::text) filter(where l.goalkeeper)::uuid into prior_ids,prior_keeper from public.game_soccer_lineups l where l.game_id=g.id and l.side=event_side;
 keeper:=(i->>'goalkeeper_roster_id')::uuid;
 if kind='substitution' then
 if not(i?&array['out_roster_id','in_roster_id']) then raise exception 'Substitution references required' using errcode='PT422';end if;
 rid:=(i->>'in_roster_id')::uuid;other_rid:=(i->>'out_roster_id')::uuid;
 perform boss_private.soccer_roster(p_actor,g,other_rid,event_side,true);perform boss_private.soccer_roster(p_actor,g,rid,event_side);
 if rid=other_rid or exists(select 1 from public.game_soccer_lineups where game_id=g.id and roster_id=rid)
 or exists(select 1 from public.game_soccer_events a where a.game_id=g.id and a.roster_id=rid and a.event_type in('red_card','second_yellow')) then raise exception 'Incoming athlete is on field or dismissed' using errcode='PT409';end if;
 if not s.allow_reentry and exists(select 1 from boss_private.soccer_active_events(g.id)a where a.side=event_side and a.id is distinct from target.id and(rid=any(a.lineup_roster_ids) or a.secondary_roster_id=rid and a.event_type='substitution')) then raise exception 'Reentry is not permitted' using errcode='PT409';end if;
 if s.max_substitutions is not null and(select count(*) from boss_private.soccer_active_events(g.id)a where a.side=event_side and a.event_type='substitution' and a.id is distinct from target.id)>=s.max_substitutions then raise exception 'Substitution limit reached' using errcode='PT409';end if;
 update public.game_soccer_lineups set roster_id=rid,goalkeeper=false where game_id=g.id and side=event_side and roster_id=other_rid and not dismissed;
 if prior_keeper is distinct from other_rid and keeper is null then keeper:=prior_keeper;end if;
 else
 if keeper is null then raise exception 'A goalkeeper designation is required' using errcode='PT422';end if;
 end if;
 if keeper is not null then perform boss_private.soccer_roster(p_actor,g,keeper,event_side,true);end if;
 update public.game_soccer_lineups set goalkeeper=false where game_id=g.id and side=event_side;
 update public.game_soccer_lineups set goalkeeper=true where game_id=g.id and side=event_side and roster_id=keeper and not dismissed;
 participation:=true;
 elsif kind not in('engine_configure','segment_start','segment_end','clock_start','clock_stop','clock_set','added_time_set','lineup_set','reversal') then
 if kind not in('goal','shot_off_target','shot_saved','shot_blocked','penalty_goal','penalty_miss','penalty_saved','own_goal','assist','yellow_card','second_yellow','red_card','foul') or event_side not in('primary','opponent') then raise exception 'Invalid Soccer event' using errcode='PT422';end if;
 if i?'out_roster_id' or i?'in_roster_id' then raise exception 'Substitution fields are not play fields' using errcode='PT422';end if;
 rid:=(i->>'roster_id')::uuid;
 if kind in('assist','second_yellow') and rid is null then raise exception 'A roster athlete is required' using errcode='PT422';end if;
 if rid is not null then
 if s.enforce_lineup and p_op='soccer.event.correct' and kind not in('yellow_card','second_yellow','red_card') and not boss_private.soccer_field_at(g.id,event_side,rid,origin) then raise exception 'Corrected athlete was not on the field at the original play' using errcode='PT409';end if;
 r:=boss_private.soccer_roster(p_actor,g,rid,event_side,s.enforce_lineup and p_op='soccer.event.add' and kind not in('yellow_card','second_yellow','red_card'));
 if exists(select 1 from public.game_soccer_events a where a.game_id=g.id and a.roster_id=rid and a.event_type in('red_card','second_yellow') and a.id is distinct from target.id) and p_op='soccer.event.add' then raise exception 'Dismissed athlete cannot participate' using errcode='PT409';end if;
 end if;
 if kind='assist' then
 select * into context from boss_private.soccer_active_events(g.id) where id=(i->>'scoring_event_id')::uuid;
 if context.id is null or context.event_type not in('goal','penalty_goal') or context.side<>event_side or context.segment_number<>segment or context.roster_id=rid then raise exception 'Invalid assist goal context' using errcode='PT422';end if;
 if exists(select 1 from boss_private.soccer_active_events(g.id)a where a.scoring_event_id=context.id and a.id is distinct from target.id) then raise exception 'Goal already has an assist' using errcode='PT409';end if;
 if context.roster_id is not null then perform boss_private.soccer_roster(p_actor,g,context.roster_id,event_side);end if;
 elsif i?'scoring_event_id' then raise exception 'Goal context is only valid for an assist' using errcode='PT422';end if;
 if kind in('shot_saved','penalty_saved') then
 defending_side:=case event_side when 'primary' then 'opponent' else 'primary' end;keeper:=(i->>'goalkeeper_roster_id')::uuid;
 if keeper is not null then
 perform boss_private.soccer_roster(p_actor,g,keeper,defending_side,p_op='soccer.event.add');
 if(p_op='soccer.event.correct' and keeper is distinct from boss_private.soccer_keeper_at(g.id,defending_side,origin)) or(p_op='soccer.event.add' and not exists(select 1 from public.game_soccer_lineups l where l.game_id=g.id and l.side=defending_side and l.roster_id=keeper and l.goalkeeper and not l.dismissed)) then raise exception 'Saved shot keeper must be the current defending designation' using errcode='PT409';end if;
 end if;
 elsif i?'goalkeeper_roster_id' then raise exception 'Keeper attribution is only valid for a saved shot' using errcode='PT422';end if;
 if kind='yellow_card' and rid is not null and exists(select 1 from boss_private.soccer_active_events(g.id)a where a.roster_id=rid and a.side=event_side and a.event_type='yellow_card' and a.id is distinct from target.id) then raise exception 'Athlete already has a first yellow; use the second-yellow outcome' using errcode='PT409';end if;
 if kind='yellow_card' and rid is not null and exists(select 1 from boss_private.soccer_active_events(g.id)y where y.roster_id=rid and y.side=event_side and y.event_type='second_yellow' and y.origin_sequence>origin and y.id is distinct from target.id
 and(select count(*) from boss_private.soccer_active_events(g.id)a where a.roster_id=rid and a.side=event_side and a.event_type='yellow_card' and a.origin_sequence<y.origin_sequence and a.id is distinct from target.id)+1<>1) then raise exception 'Resolve the dependent second yellow before changing its prior discipline' using errcode='PT409';end if;
 if kind='second_yellow' and(select count(*) from boss_private.soccer_active_events(g.id)a where a.roster_id=rid and a.side=event_side and a.event_type='yellow_card' and a.origin_sequence<origin and a.id is distinct from target.id)<>1 then raise exception 'Second yellow requires the prior active yellow' using errcode='PT409';end if;
 if kind='red_card' and rid is null then update public.game_soccer_states set participation_complete=false where game_id=g.id;end if;
 if kind in('red_card','second_yellow') and rid is not null then
 select exists(select 1 from public.game_soccer_lineups l where l.game_id=g.id and l.roster_id=rid and not l.dismissed) into was_field;
 if was_field then
 select coalesce(array_agg(l.roster_id order by l.slot) filter(where not l.dismissed),'{}'),max(l.roster_id::text) filter(where l.goalkeeper)::uuid into prior_ids,prior_keeper from public.game_soccer_lineups l where l.game_id=g.id and l.side=event_side;
 update public.game_soccer_lineups set dismissed=true,goalkeeper=false where game_id=g.id and roster_id=rid;participation:=true;
 end if;
 end if;
 end if;
 if kind='reversal' and target.event_type in('substitution','keeper_set') then participation:=true;event_side:=target.side;end if;
 if participation then
 select coalesce(array_agg(l.roster_id order by l.slot) filter(where not l.dismissed),'{}'),max(l.roster_id::text) filter(where l.goalkeeper)::uuid into ids,keeper from public.game_soccer_lineups l where l.game_id=g.id and l.side=event_side;
 end if;
 end if;
 -- Canonical match goals are exclusively derived from active shot outcomes.
 select coalesce(sum(case when a.event_type in('goal','penalty_goal') and a.side='primary' or a.event_type='own_goal' and a.side='opponent' then 1 else 0 end),0),
 coalesce(sum(case when a.event_type in('goal','penalty_goal') and a.side='opponent' or a.event_type='own_goal' and a.side='primary' then 1 else 0 end),0)
 into primary_total,opponent_total from boss_private.soccer_active_events(g.id)a;
 if primary_total<>g.primary_score or opponent_total<>g.opponent_score then raise exception 'Soccer score projection is inconsistent' using errcode='PT409';end if;
 oldgoal:=case when target.event_type in('goal','penalty_goal','own_goal') then 1 else 0 end;newgoal:=case when kind in('goal','penalty_goal','own_goal') then 1 else 0 end;
 oldside:=case when target.event_type='own_goal' then case target.side when 'primary' then 'opponent' else 'primary' end else target.side end;
 newside:=case when kind='own_goal' then case event_side when 'primary' then 'opponent' else 'primary' end else event_side end;
 primary_total:=primary_total-case when oldside='primary' then oldgoal else 0 end+case when newside='primary' then newgoal else 0 end;
 opponent_total:=opponent_total-case when oldside='opponent' then oldgoal else 0 end+case when newside='opponent' then newgoal else 0 end;
 if primary_total not between 0 and 1000000 or opponent_total not between 0 and 1000000 then raise exception 'Soccer score exceeds bound' using errcode='PT422';end if;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_feature(g.organization_id,'soccer_live_scoring') or not boss_private.games_feature(g.organization_id,'soccer_stats') or not boss_private.games_feature(g.organization_id,'game_operations')
 or(p_op='soccer.configure' and not boss_private.games_permission(p_actor,'games.manage',g,true))
 or(p_op in('soccer.event.correct','soccer.event.reverse') and not boss_private.games_permission(p_actor,'games.correct',g,true))
 or(p_op not in('soccer.configure','soccer.event.correct','soccer.event.reverse') and not boss_private.games_operator_current(p_actor,g)) then raise exception 'Access denied' using errcode='PT403';end if;
 update public.games set primary_score=primary_total,opponent_score=opponent_total,version=version+1,updated_by_person_id=p_actor,updated_at=clock_timestamp() where id=g.id;
 select * into s from public.game_soccer_states where game_id=g.id;
 opid:=boss_private.games_append(g.id,p_actor,p_op,p_request,before_state,jsonb_build_object('soccer',boss_private.soccer_state(s),'soccer_time',jsonb_build_object('segment_number',segment,'clock_ms',clock_value,'display_clock_ms',display_value,'playing_ms',playing_value),'soccer_event_type',kind,'soccer_event_id',eventid),target.operation_id);
 insert into public.game_soccer_events(id,organization_id,game_id,operation_id,sequence,origin_sequence,segment_number,clock_ms,display_clock_ms,playing_ms,side,roster_id,secondary_roster_id,goalkeeper_roster_id,prior_goalkeeper_roster_id,lineup_roster_ids,prior_lineup_roster_ids,was_on_field,event_type,actor_person_id,request_id,correction_of,scoring_event_id,reason)
 values(eventid,g.organization_id,g.id,opid,g.last_sequence+1,origin,segment,clock_value,display_value,playing_value,event_side,rid,other_rid,keeper,prior_keeper,case when participation then ids end,prior_ids,was_field,kind,p_actor,p_request,target.id,context.id,reason);
 return jsonb_build_object('game_id',g.id,'version',g.version+1,'message','Soccer change saved.');
end$$;
revoke all on function boss_private.soccer_field_at(uuid,text,uuid,bigint),boss_private.soccer_keeper_at(uuid,text,bigint),boss_private.soccer_roster(uuid,public.games,uuid,text,boolean),boss_private.soccer_command(uuid,text,jsonb,uuid,boolean) from public,anon,authenticated,service_role;
