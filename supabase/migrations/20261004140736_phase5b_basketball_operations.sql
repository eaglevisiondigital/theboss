-- One caller receipt, one canonical game version and one ordered operation per
-- accepted sport command. All semantics and current authorization are server-side.
create function boss_private.basketball_roster(p_actor uuid,g public.games,p_roster uuid,p_side text,p_on_court boolean default false) returns public.game_roster_snapshots
language plpgsql volatile security definer set search_path='' as $$
declare r public.game_roster_snapshots;team uuid;begin
 team:=case p_side when 'primary' then g.primary_team_id when 'opponent' then g.opponent_team_id end;
 select * into r from public.game_roster_snapshots where id=p_roster and game_id=g.id and organization_id=g.organization_id and revision=g.roster_revision and team_id=team;
 if r.id is null or not boss_private.basketball_roster_side(p_actor,g,team) then raise exception 'Access denied' using errcode='PT403';end if;
 if not r.active or not exists(select 1 from public.people p join public.participants a on a.person_id=p.id and a.id=r.participant_id where p.id=r.person_id and p.status='active' and a.status='active') then raise exception 'Athlete is not eligible in this game snapshot' using errcode='PT409';end if;
 if p_on_court and not exists(select 1 from public.game_basketball_lineups where game_id=g.id and side=p_side and roster_id=r.id) then raise exception 'Athlete is not on court' using errcode='PT409';end if;
 return r;
end$$;
create function boss_private.basketball_command(p_actor uuid,p_op text,i jsonb,p_request uuid,p_replay boolean default false) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare g public.games;e public.events;s public.game_basketball_states;before_state jsonb;occ jsonb;
 fields text[]:=array['game_id','expected_version'];required text[]:=fields;kind text;event_side text;rid uuid;other_rid uuid;
 target public.game_basketball_events;score_context public.game_basketball_events;r public.game_roster_snapshots;
 eventid uuid:=gen_random_uuid();opid uuid;clock_value bigint;period integer;newpoints integer:=0;primary_total bigint;opponent_total bigint;
 reason text;ids uuid[];n integer;team uuid;lineup_count integer;extra jsonb;needs_lineup boolean;begin
 case p_op
 when 'basketball.configure' then fields:=fields||array['regulation_periods','period_seconds','overtime_seconds','lineup_size','enforce_lineup'];required:=fields;
 when 'basketball.period.start' then null;
 when 'basketball.period.end' then null;
 when 'basketball.clock.start' then null;
 when 'basketball.clock.stop' then null;
 when 'basketball.clock.set' then fields:=fields||array['clock_ms','reason'];required:=fields;
 when 'basketball.lineup.set' then fields:=fields||array['side','roster_ids'];required:=fields;
 when 'basketball.substitute' then fields:=fields||array['side','out_roster_id','in_roster_id'];required:=fields;
 when 'basketball.event.add' then fields:=fields||array['event_type','side','roster_id','scoring_event_id'];required:=required||array['event_type','side'];
 when 'basketball.event.correct' then fields:=fields||array['event_type','side','roster_id','scoring_event_id','event_id','reason'];required:=required||array['event_type','side','event_id','reason'];
 when 'basketball.event.reverse' then fields:=fields||array['event_id','reason'];required:=fields;
 else raise exception 'Invalid Basketball command' using errcode='PT422';end case;
 perform boss_private.games_validate(i,fields,required);
 if p_actor is distinct from boss_private.current_person_id() then raise exception 'Access denied' using errcode='PT403';end if;
 -- Never lock a guessed resource before resolving its canonical event identity.
 select event_id into e.id from public.games where id=(i->>'game_id')::uuid;
 if e.id is null then raise exception 'Access denied' using errcode='PT403';end if;
 select * into e from public.events where id=e.id for update;
 select * into g from public.games where id=(i->>'game_id')::uuid for update;
 perform boss_private.games_lock_authority(p_actor,g);
 perform 1 from public.game_operator_assignments a where a.game_id=g.id and a.person_id=p_actor order by a.id for share;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or g.sport_key<>'basketball' or not boss_private.games_feature(g.organization_id,'basketball_live_scoring')
 or not boss_private.games_feature(g.organization_id,'basketball_stats') or not boss_private.games_feature(g.organization_id,'game_operations') then raise exception 'Access denied' using errcode='PT403';end if;
 if p_op='basketball.configure' then
 if not boss_private.games_permission(p_actor,'games.manage',g,true) then raise exception 'Access denied' using errcode='PT403';end if;
 elsif p_op in('basketball.event.correct','basketball.event.reverse') then
 if not boss_private.games_permission(p_actor,'games.correct',g,true) then raise exception 'Access denied' using errcode='PT403';end if;
 else
 if not boss_private.games_operator_current(p_actor,g) then raise exception 'Access denied' using errcode='PT403';end if;
 end if;
 -- Natural expiry/revocation is checked after serialization, including replays.
 if g.status in('final','canceled','abandoned','postponed') then raise exception 'Game is locked' using errcode='PT409';end if;
 occ:=boss_private.games_occurrence(e,g.occurrence_key,g.occurrence_mode);
 if occ is null or occ->>'status' not in('scheduled','confirmed') or e.event_type_key not in('game','tournament') then raise exception 'Game occurrence is not operable' using errcode='PT409';end if;
 select * into s from public.game_basketball_states where game_id=g.id;
 if p_op<>'basketball.configure' and s.game_id is null then raise exception 'Basketball is not initialized' using errcode='PT409';end if;
 needs_lineup:=p_op in('basketball.lineup.set','basketball.substitute') or coalesce(s.enforce_lineup,false);
 if needs_lineup and not boss_private.games_feature(g.organization_id,'basketball_lineups') then raise exception 'Access denied' using errcode='PT403';end if;
 -- A replay validates its original referenced side/resources, never appends or
 -- reinitializes. Do not require the original version/period/lineup still current.
 if p_replay then
 if i?'roster_id' then perform boss_private.basketball_roster(p_actor,g,(i->>'roster_id')::uuid,i->>'side');end if;
 if i?'out_roster_id' then perform boss_private.basketball_roster(p_actor,g,(i->>'out_roster_id')::uuid,i->>'side');perform boss_private.basketball_roster(p_actor,g,(i->>'in_roster_id')::uuid,i->>'side');end if;
 if i?'roster_ids' then for rid in select value::text::uuid from jsonb_array_elements_text(i->'roster_ids') loop perform boss_private.basketball_roster(p_actor,g,rid,i->>'side');end loop;end if;
 return jsonb_build_object('game_id',g.id,'version',g.version,'message','Saved.');end if;
 if g.version<>(i->>'expected_version')::bigint then raise exception 'Game changed; reload before saving' using errcode='PT409';end if;
 before_state:=boss_private.games_core_state(g)||case when s.game_id is not null then jsonb_build_object('basketball',boss_private.basketball_state(s)) else '{}'::jsonb end;
 if p_op='basketball.configure' then
 if s.game_id is not null or g.started_at is not null or g.status not in('scheduled','pregame','delayed') or g.roster_revision=0 or g.primary_score<>0 or g.opponent_score<>0
 or exists(select 1 from public.game_operations where game_id=g.id and operation in('game.score.set','game.score.reverse')) then raise exception 'Basketball requires a new zero-score pregame snapshot' using errcode='PT409';end if;
 if jsonb_typeof(i->'enforce_lineup')<>'boolean' then raise exception 'Invalid lineup policy' using errcode='PT422';end if;
 foreach kind in array array['regulation_periods','period_seconds','overtime_seconds','lineup_size'] loop
 if jsonb_typeof(i->kind)<>'number' or i->>kind!~'^[0-9]{1,4}$' then raise exception 'Invalid Basketball format' using errcode='PT422';end if;end loop;
 if(i->>'regulation_periods')::integer not in(2,4) or(i->>'period_seconds')::integer not between 60 and 3600 or(i->>'overtime_seconds')::integer not between 60 and 1800 or(i->>'lineup_size')::integer not between 1 and 5 then raise exception 'Invalid Basketball format' using errcode='PT422';end if;
 if(i->>'enforce_lineup')::boolean and not boss_private.games_feature(g.organization_id,'basketball_lineups') then raise exception 'Access denied' using errcode='PT403';end if;
 insert into public.game_basketball_states(game_id,organization_id,regulation_periods,period_seconds,overtime_seconds,lineup_size,enforce_lineup,roster_revision)
 values(g.id,g.organization_id,(i->>'regulation_periods')::integer,(i->>'period_seconds')::integer,(i->>'overtime_seconds')::integer,(i->>'lineup_size')::integer,(i->>'enforce_lineup')::boolean,g.roster_revision) returning * into s;
 kind:='engine_configure';period:=0;clock_value:=0;
 else
 clock_value:=boss_private.basketball_clock(s);period:=s.period_number;
 if p_op not in('basketball.lineup.set','basketball.event.correct','basketball.event.reverse') and g.status<>'live' then raise exception 'Basketball operation requires a live game' using errcode='PT409';end if;
 if p_op in('basketball.event.correct','basketball.event.reverse') and g.status not in('live','paused','suspended') then raise exception 'Game cannot be corrected' using errcode='PT409';end if;
 if p_op in('basketball.clock.set','basketball.event.correct','basketball.event.reverse') then
 reason:=btrim(i->>'reason');if reason is null or length(reason) not between 1 and 500 or reason~'[[:cntrl:]]' then raise exception 'A bounded correction reason is required' using errcode='PT422';end if;end if;
 case p_op
 when 'basketball.period.start' then
 if s.period_status not in('pending','ended') or s.clock_running or s.period_number>=30 then raise exception 'Prior period is not complete' using errcode='PT409';end if;
 if s.enforce_lineup then
 for team in select unnest(array[g.primary_team_id,g.opponent_team_id]) loop
 if team is not null and(select count(*) from public.game_basketball_lineups l where l.game_id=g.id and l.side=case when team=g.primary_team_id then 'primary' else 'opponent' end)<>s.lineup_size then raise exception 'Complete the configured lineup first' using errcode='PT409';end if;
 end loop;end if;
 period:=s.period_number+1;clock_value:=case when period>s.regulation_periods then s.overtime_seconds else s.period_seconds end*1000;
 update public.game_basketball_states set period_number=period,period_status='active',clock_remaining_ms=clock_value,clock_running=false,clock_anchor=null where game_id=g.id;
 kind:='period_start';
 when 'basketball.period.end' then
 if s.period_status<>'active' then raise exception 'Period is not active' using errcode='PT409';end if;
 update public.game_basketball_states set period_status='ended',clock_remaining_ms=0,clock_running=false,clock_anchor=null where game_id=g.id;
 kind:='period_end'; -- typed evidence retains the actual pre-end clock sample.
 when 'basketball.clock.start' then
 if s.period_status<>'active' or s.clock_running or clock_value<=0 then raise exception 'Clock cannot start' using errcode='PT409';end if;
 update public.game_basketball_states set clock_remaining_ms=clock_value,clock_running=true,clock_anchor=clock_timestamp() where game_id=g.id;kind:='clock_start';
 when 'basketball.clock.stop' then
 if s.period_status<>'active' or not s.clock_running then raise exception 'Clock is not running' using errcode='PT409';end if;
 update public.game_basketball_states set clock_remaining_ms=clock_value,clock_running=false,clock_anchor=null where game_id=g.id;kind:='clock_stop';
 when 'basketball.clock.set' then
 if s.period_status<>'active' or s.clock_running then raise exception 'Stop the active period clock before correction' using errcode='PT409';end if;
 if jsonb_typeof(i->'clock_ms')<>'number' or i->>'clock_ms'!~'^[0-9]{1,7}$' or(i->>'clock_ms')::bigint>(case when s.period_number>s.regulation_periods then s.overtime_seconds else s.period_seconds end)*1000 then raise exception 'Invalid period clock' using errcode='PT422';end if;
 clock_value:=(i->>'clock_ms')::bigint;update public.game_basketball_states set clock_remaining_ms=clock_value,clock_anchor=null where game_id=g.id;kind:='clock_set';
 when 'basketball.lineup.set' then
 if s.period_number<>0 or s.clock_running then raise exception 'Initial lineup is already sealed; use substitution' using errcode='PT409';end if;
 event_side:=i->>'side';if event_side not in('primary','opponent') or jsonb_typeof(i->'roster_ids')<>'array' or jsonb_array_length(i->'roster_ids')>s.lineup_size then raise exception 'Invalid initial lineup' using errcode='PT422';end if;
 select coalesce(array_agg(value::uuid),'{}') into ids from jsonb_array_elements_text(i->'roster_ids');
 if cardinality(ids)<>(select count(distinct x) from unnest(ids)x) or(s.enforce_lineup and cardinality(ids)<>s.lineup_size) then raise exception 'Invalid lineup size or duplicate player' using errcode='PT422';end if;
 if not boss_private.basketball_roster_side(p_actor,g,case event_side when 'primary' then g.primary_team_id else g.opponent_team_id end) then raise exception 'Access denied' using errcode='PT403';end if;
 foreach rid in array ids loop perform boss_private.basketball_roster(p_actor,g,rid,event_side);end loop;rid:=null;
 delete from public.game_basketball_lineups where game_id=g.id and side=event_side;
 insert into public.game_basketball_lineups(game_id,organization_id,side,slot,roster_id) select g.id,g.organization_id,event_side,ordinality,value from unnest(ids) with ordinality as u(value,ordinality);
 kind:='lineup_set';
 when 'basketball.substitute' then
 if s.period_status<>'active' then raise exception 'Substitution requires an active period' using errcode='PT409';end if;
 event_side:=i->>'side';if event_side not in('primary','opponent') then raise exception 'Invalid scoring side' using errcode='PT422';end if;
 rid:=(i->>'in_roster_id')::uuid;other_rid:=(i->>'out_roster_id')::uuid;
 perform boss_private.basketball_roster(p_actor,g,rid,event_side);perform boss_private.basketball_roster(p_actor,g,other_rid,event_side,true);
 if rid=other_rid or exists(select 1 from public.game_basketball_lineups where game_id=g.id and roster_id=rid) then raise exception 'Incoming player is already on court' using errcode='PT409';end if;
 update public.game_basketball_lineups set roster_id=rid where game_id=g.id and side=event_side and roster_id=other_rid;
 select count(*) into lineup_count from public.game_basketball_lineups where game_id=g.id and side=event_side;
 if s.enforce_lineup and lineup_count<>s.lineup_size then raise exception 'Invalid resulting lineup' using errcode='PT409';end if;kind:='substitution';
 else
 if p_op='basketball.event.add' and s.period_status<>'active' then raise exception 'Initialize an active period before entry' using errcode='PT409';end if;
 if p_op in('basketball.event.correct','basketball.event.reverse') then
 select * into target from boss_private.basketball_active_events(g.id) where id=(i->>'event_id')::uuid;
 if target.id is null then raise exception 'Event is not a current correctable play' using errcode='PT409';end if;
 if exists(select 1 from boss_private.basketball_active_events(g.id) a where a.scoring_event_id=target.id) then raise exception 'Correct or reverse the dependent assist first' using errcode='PT409';end if;
 period:=target.period_number;clock_value:=target.clock_ms;
 end if;
 if p_op='basketball.event.reverse' then kind:='reversal';event_side:=target.side;
 else
 kind:=i->>'event_type';event_side:=i->>'side';rid:=(i->>'roster_id')::uuid;
 if kind not in('made_2','made_3','made_ft','missed_2','missed_3','missed_ft','offensive_rebound','defensive_rebound','assist','steal','block','turnover','personal_foul') or event_side not in('primary','opponent') then raise exception 'Invalid Basketball event' using errcode='PT422';end if;
 if kind in('assist','steal','block','personal_foul') and rid is null then raise exception 'A roster athlete is required' using errcode='PT422';end if;
 if rid is not null then r:=boss_private.basketball_roster(p_actor,g,rid,event_side,s.enforce_lineup and p_op='basketball.event.add');end if;
 if kind='assist' then
 select * into score_context from boss_private.basketball_active_events(g.id) where id=(i->>'scoring_event_id')::uuid;
 if score_context.id is null or score_context.event_type not in('made_2','made_3') or score_context.side<>event_side or score_context.period_number<>period or score_context.roster_id is null or score_context.roster_id=rid then raise exception 'Invalid assist scoring context' using errcode='PT422';end if;
 if exists(select 1 from boss_private.basketball_active_events(g.id) a where a.scoring_event_id=score_context.id and a.id is distinct from target.id) then raise exception 'Scoring play already has an assist' using errcode='PT409';end if;
 -- The referenced shooter's side is checked independently of guessed IDs.
 perform boss_private.basketball_roster(p_actor,g,score_context.roster_id,event_side);
 elsif i?'scoring_event_id' then raise exception 'Scoring context is only valid for an assist' using errcode='PT422';end if;
 newpoints:=case kind when 'made_2' then 2 when 'made_3' then 3 when 'made_ft' then 1 else 0 end;
 end if;
 -- Reconcile exact-game event contributions before appending the next fact.
 select coalesce(sum(points) filter(where side='primary'),0),coalesce(sum(points) filter(where side='opponent'),0) into primary_total,opponent_total from boss_private.basketball_active_events(g.id);
 if primary_total<>g.primary_score or opponent_total<>g.opponent_score then raise exception 'Basketball score projection is inconsistent' using errcode='PT409';end if;
 primary_total:=primary_total-case when target.side='primary' then target.points else 0 end+case when event_side='primary' then newpoints else 0 end;
 opponent_total:=opponent_total-case when target.side='opponent' then target.points else 0 end+case when event_side='opponent' then newpoints else 0 end;
 if primary_total not between 0 and 1000000 or opponent_total not between 0 and 1000000 then raise exception 'Basketball score exceeds bound' using errcode='PT422';end if;
 update public.games set primary_score=primary_total,opponent_score=opponent_total where id=g.id;
 end case;
 end if;
 select * into s from public.game_basketball_states where game_id=g.id;
 update public.games set version=version+1,updated_by_person_id=p_actor,updated_at=clock_timestamp() where id=g.id;
 extra:=jsonb_build_object('basketball',boss_private.basketball_state(s),'basketball_time',jsonb_build_object('period_number',period,'clock_ms',clock_value),'basketball_event_type',kind,'basketball_event_id',eventid);
 opid:=boss_private.games_append(g.id,p_actor,p_op,p_request,before_state,extra,target.operation_id);
 insert into public.game_basketball_events(id,organization_id,game_id,operation_id,sequence,period_number,clock_ms,side,roster_id,secondary_roster_id,event_type,points,actor_person_id,request_id,correction_of,scoring_event_id,reason)
 values(eventid,g.organization_id,g.id,opid,g.last_sequence+1,period,clock_value,event_side,rid,other_rid,kind,newpoints,p_actor,p_request,target.id,score_context.id,reason);
 if kind in('lineup_set','substitution') then
 insert into public.game_basketball_lineup_history(event_id,organization_id,game_id,side,slot,roster_id)
 select eventid,organization_id,game_id,side,slot,roster_id from public.game_basketball_lineups where game_id=g.id;
 end if;
 return jsonb_build_object('game_id',g.id,'version',g.version+1,'message','Basketball change saved.');
end$$;
revoke all on function boss_private.basketball_roster(uuid,public.games,uuid,text,boolean),boss_private.basketball_command(uuid,text,jsonb,uuid,boolean) from public,anon,authenticated,service_role;
