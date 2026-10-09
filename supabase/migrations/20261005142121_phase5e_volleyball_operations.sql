alter table public.game_operations drop constraint game_operations_finite_operation;
alter table public.game_operations add constraint game_operations_finite_operation check(operation in(
 'game.create','game.roster.snapshot','game.operator.assign','game.operator.end','game.start','game.transition','game.score.set','game.score.reverse','game.finalize','game.reopen','game.publish','game.calendar.sync',
 'basketball.configure','basketball.period.start','basketball.period.end','basketball.clock.start','basketball.clock.stop','basketball.clock.set','basketball.lineup.set','basketball.substitute','basketball.event.add','basketball.event.correct','basketball.event.reverse',
 'soccer.configure','soccer.segment.start','soccer.segment.end','soccer.clock.start','soccer.clock.stop','soccer.clock.set','soccer.added_time.set','soccer.lineup.set','soccer.keeper.set','soccer.substitute','soccer.event.add','soccer.event.correct','soccer.event.reverse',
 'football.configure','football.period.start','football.period.end','football.clock.start','football.clock.stop','football.clock.set','football.state.set','football.lineup.set','football.substitute','football.play.add','football.play.correct','football.play.reverse',
 'tracking.profile.set','volleyball.configure','volleyball.set.start','volleyball.lineup.set','volleyball.substitute','volleyball.event.add','volleyball.event.correct','volleyball.event.reverse'));

create function boss_private.volleyball_fact_validate(kind text,p jsonb)returns void
language plpgsql immutable set search_path=''as $$
declare fields text[];required text[]:='{}';k text;ids text[];begin
 case kind
 when'set_start'then fields:='{}';
 when'lineup_set'then fields:=array['roster_ids','libero_roster_id'];required:=array['roster_ids'];
 when'substitution'then fields:=array['out_roster_id','in_roster_id'];required:=fields;
 when'rally'then
 fields:=array['outcome','roster_id'];required:=array['outcome'];
 if p->>'outcome'not in('kill','attack_error','ace','service_error','solo_block','assisted_block','reception_error','team_point')or p->>'outcome'is null then raise exception 'Invalid rally outcome'using errcode='PT422';end if;
 if p->>'outcome'='ace'then fields:=fields||array['receiver_roster_id'];end if;
 if p->>'outcome'='assisted_block'then fields:=array['outcome','blocker_roster_ids'];required:=array['outcome'];end if;
 if p->>'outcome'='team_point'then fields:=array['outcome'];end if;
 when'assist'then fields:=array['roster_id','kill_event_id'];required:=array['kill_event_id'];
 when'attack_attempt','dig','reception','blocking_error'then fields:=array['roster_id'];
 else raise exception 'Invalid Volleyball fact type'using errcode='PT422';end case;
 perform boss_private.games_validate(p,fields,required);
 foreach k in array array['roster_id','receiver_roster_id','kill_event_id','out_roster_id','in_roster_id','libero_roster_id']loop
 if p?k and(jsonb_typeof(p->k)<>'string'or p->>k!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')then raise exception 'Invalid Volleyball identity'using errcode='PT422';end if;end loop;
 foreach k in array array['roster_ids','blocker_roster_ids']loop
 if p?k then
 if jsonb_typeof(p->k)<>'array'or jsonb_array_length(p->k)not between (case k when'blocker_roster_ids'then 2 else 1 end) and 6 then raise exception 'Invalid Volleyball participant list'using errcode='PT422';end if;
 select array_agg(v)into ids from jsonb_array_elements_text(p->k)v;
 if cardinality(ids)<>(select count(distinct v)from unnest(ids)v)or exists(select 1 from unnest(ids)v where v is null or v!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')then raise exception 'Invalid Volleyball participant list'using errcode='PT422';end if;end if;end loop;
end$$;
create function boss_private.volleyball_roster(actor uuid,g public.games,rid uuid,side text)returns void
language plpgsql volatile security definer set search_path=''as $$
declare r public.game_roster_snapshots;team uuid;begin
 team:=case side when'primary'then g.primary_team_id when'opponent'then g.opponent_team_id end;
 select *into r from public.game_roster_snapshots where id=rid and game_id=g.id and organization_id=g.organization_id and revision=g.roster_revision and team_id=team;
 if r.id is null or not(boss_private.games_role_permission(actor,'team.roster.view',g.organization_id,team)or boss_private.games_operator_current(actor,g)and exists(select 1 from public.game_operator_assignments a where a.game_id=g.id and a.person_id=actor and a.team_id=team and a.status='active'and a.starts_at<=clock_timestamp()and a.ends_at>clock_timestamp()and boss_private.games_role_permission(actor,'games.operate',g.organization_id,team,a.role_assignment_id)))then raise exception 'Access denied'using errcode='PT403';end if;
 perform 1 from public.people where id=r.person_id for share;perform 1 from public.participants where id=r.participant_id for share;
 if not r.active or not exists(select 1 from public.people p join public.participants a on a.person_id=p.id and a.id=r.participant_id where p.id=r.person_id and p.status='active'and a.status='active')then raise exception 'Athlete is not eligible in this game snapshot'using errcode='PT409';end if;
end$$;
create function boss_private.volleyball_optional_key(kind text,p jsonb)returns text
language sql immutable set search_path=''as $$select case kind
 when'rally'then case p->>'outcome'when'kill'then'kills'when'attack_error'then'attack_errors'when'ace'then'service_aces'when'service_error'then'service_errors'when'solo_block'then'solo_blocks'when'assisted_block'then'block_assists'when'reception_error'then'reception_errors'end
 when'attack_attempt'then'attack_attempts'when'assist'then'assists'when'dig'then'digs'when'reception'then'receptions'when'blocking_error'then'blocking_errors'end$$;

create function boss_private.volleyball_command(actor uuid,op text,i jsonb,request uuid,replay boolean default false)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
<<volleyball_command>>
declare g public.games;e public.events;s public.game_volleyball_states;target public.game_volleyball_events;
 fields text[]:=array['game_id','expected_version'];required text[]:=fields;kind text;side text;payload jsonb;cfg jsonb;oldstate jsonb;nextstate jsonb;candidate jsonb;origin bigint;eventid uuid:=gen_random_uuid();operationid uuid;rid text;role_side text;optional text;reason text;occ jsonb;preview public.games;begin
 case op
 when'volleyball.configure'then fields:=fields||array['configuration'];required:=fields;
 when'volleyball.set.start'then fields:=fields||array['side'];required:=fields;kind:='set_start';
 when'volleyball.lineup.set'then fields:=fields||array['side','payload'];required:=fields;kind:='lineup_set';
 when'volleyball.substitute'then fields:=fields||array['side','payload'];required:=fields;kind:='substitution';
 when'volleyball.event.add'then fields:=fields||array['side','event_type','payload'];required:=fields;kind:=i->>'event_type';
 when'volleyball.event.correct'then fields:=fields||array['side','event_type','payload','event_id','reason'];required:=fields;kind:=i->>'event_type';
 when'volleyball.event.reverse'then fields:=fields||array['event_id','reason'];required:=fields;kind:='reversal';
 else raise exception 'Invalid Volleyball operation'using errcode='PT422';end case;
 perform boss_private.games_validate(i,fields,required);
 if jsonb_typeof(i->'expected_version')<>'number'or i->>'expected_version'!~'^[0-9]{1,15}$'then raise exception 'Invalid game version'using errcode='PT422';end if;
 side:=i->>'side';payload:=coalesce(i->'payload','{}');reason:=i->>'reason';
 if side is not null and side not in('primary','opponent')then raise exception 'Invalid Volleyball side'using errcode='PT422';end if;
 if op in('volleyball.event.add','volleyball.event.correct')and kind not in('rally','attack_attempt','assist','dig','reception','blocking_error','substitution','lineup_set','set_start')then raise exception 'Invalid Volleyball fact'using errcode='PT422';end if;
 if kind not in('reversal')and op<>'volleyball.configure'then perform boss_private.volleyball_fact_validate(kind,payload);end if;
 if op='volleyball.configure'then cfg:=i->'configuration';perform boss_private.volleyball_configuration_validate(cfg);end if;
 if reason is not null and(length(btrim(reason))not between 1 and 500 or reason~'[[:cntrl:]]')then raise exception 'Correction reason is required'using errcode='PT422';end if;
 perform boss_private.games_require_live_auth();if actor is distinct from boss_private.current_person_id()then raise exception 'Access denied'using errcode='PT403';end if;
 select *into preview from public.games where id=(i->>'game_id')::uuid;
 if preview.id is null then raise exception 'Access denied'using errcode='PT403';end if;
 if op='volleyball.configure'then perform boss_private.tracking_resolution_locks(preview);end if;
 select *into e from public.events where id=preview.event_id for update;
 select *into g from public.games where id=preview.id for update;
 perform boss_private.games_lock_authority(actor,g);perform 1 from public.game_operator_assignments where game_id=g.id and person_id=actor order by id for share;
 perform boss_private.games_require_live_auth();
 if actor is distinct from boss_private.require_admin_actor()or g.sport_key<>'volleyball'or not boss_private.games_feature(g.organization_id,'volleyball_live_scoring')or not boss_private.games_feature(g.organization_id,'game_operations')then raise exception 'Access denied'using errcode='PT403';end if;
 if op='volleyball.configure'then if not boss_private.games_permission(actor,'games.manage',g,true)then raise exception 'Access denied'using errcode='PT403';end if;
 elsif op in('volleyball.event.correct','volleyball.event.reverse')then if not boss_private.games_permission(actor,'games.correct',g,true)then raise exception 'Access denied'using errcode='PT403';end if;
 else if not boss_private.games_operator_current(actor,g)then raise exception 'Access denied'using errcode='PT403';end if;end if;
 if g.status in('final','canceled','postponed','abandoned')then raise exception 'Game is locked'using errcode='PT409';end if;
 occ:=boss_private.games_occurrence(e,g.occurrence_key,g.occurrence_mode);
 if occ is null or occ->>'status'not in('scheduled','confirmed')or e.event_type_key not in('game','tournament')then raise exception 'Game occurrence is not operable'using errcode='PT409';end if;
 select *into s from public.game_volleyball_states where game_id=g.id;
 if op<>'volleyball.configure'and s.game_id is null then raise exception 'Volleyball is not initialized'using errcode='PT409';end if;
 if(kind in('lineup_set','substitution')or coalesce((coalesce(s.configuration,cfg)->>'enforce_lineup')::boolean,false))and not boss_private.games_feature(g.organization_id,'volleyball_lineups')then raise exception 'Access denied'using errcode='PT403';end if;
 if op in('volleyball.event.correct','volleyball.event.reverse')then
 select *into target from public.game_volleyball_events where id=(i->>'event_id')::uuid and game_id=g.id;
 if target.id is null or target.event_type='configure'then raise exception 'Fact is not correctable in this game'using errcode='PT403';end if;
 if kind='reversal'then side:=target.side;payload:='{}';end if;
 end if;
 -- Every supplied identity is tenant/game/revision/side bound even on replay.
 foreach rid in array array[payload->>'roster_id',payload->>'libero_roster_id',payload->>'out_roster_id',payload->>'in_roster_id']loop
 if rid is not null then perform boss_private.volleyball_roster(actor,g,rid::uuid,side);end if;end loop;
 if payload?'receiver_roster_id'then perform boss_private.volleyball_roster(actor,g,(payload->>'receiver_roster_id')::uuid,case side when'primary'then'opponent'else'primary'end);end if;
 for rid in select jsonb_array_elements_text(coalesce(payload->'roster_ids','[]')||coalesce(payload->'blocker_roster_ids','[]'))loop perform boss_private.volleyball_roster(actor,g,rid::uuid,side);end loop;
 if payload?'kill_event_id'and not exists(select 1 from public.game_volleyball_events v where v.id=(volleyball_command.payload->>'kill_event_id')::uuid and v.game_id=g.id and v.side=volleyball_command.side)then raise exception 'Access denied'using errcode='PT403';end if;
 optional:=boss_private.volleyball_optional_key(kind,payload);
 if op in('volleyball.event.add','volleyball.event.correct')and optional is not null and not boss_private.games_feature(g.organization_id,'volleyball_stats')then raise exception 'Access denied'using errcode='PT403';end if;
 if op='volleyball.event.add'then
 if optional is not null and not boss_private.tracking_enabled(g.id,side,optional)then raise exception 'Statistic is not tracked by this game profile'using errcode='PT403';end if;
 if(kind not in('lineup_set','substitution','set_start'))and(payload?'roster_id'or payload?'receiver_roster_id'or payload?'blocker_roster_ids')and not boss_private.tracking_enabled(g.id,side,'player_attribution')then raise exception 'Player attribution is not tracked'using errcode='PT403';end if;
 if payload?'receiver_roster_id'and(not boss_private.tracking_enabled(g.id,case side when'primary'then'opponent'else'primary'end,'reception_errors')or not boss_private.tracking_enabled(g.id,case side when'primary'then'opponent'else'primary'end,'player_attribution'))then raise exception 'Receiver attribution is not tracked'using errcode='PT403';end if;
 end if;
 if replay then return jsonb_build_object('game_id',g.id,'version',g.version,'message','Saved.');end if;
 if g.version<>(i->>'expected_version')::bigint then raise exception 'Game changed; reload before saving'using errcode='PT409';end if;
 oldstate:=boss_private.games_core_state(g)||case when s.game_id is null then'{}'::jsonb else jsonb_build_object('volleyball',s.state)end;origin:=g.last_sequence+1;
 if op='volleyball.configure'then
 if s.game_id is not null or g.started_at is not null or g.status not in('scheduled','pregame','delayed')or g.roster_revision=0 or g.primary_score<>0 or g.opponent_score<>0 or exists(select 1 from public.game_operations where game_id=g.id and operation in('game.score.set','game.score.reverse'))then raise exception 'Volleyball requires a new zero-score pregame snapshot'using errcode='PT409';end if;
 insert into public.game_volleyball_states(game_id,organization_id,roster_revision,configuration,state)values(g.id,g.organization_id,g.roster_revision,cfg,boss_private.volleyball_initial(cfg))returning *into s;
 perform boss_private.tracking_snapshot(g,'primary',origin);perform boss_private.tracking_snapshot(g,'opponent',origin);
 kind:='configure';payload:=cfg;nextstate:=s.state;
 else
 if op not in('volleyball.lineup.set','volleyball.event.correct','volleyball.event.reverse')and g.status<>'live'then raise exception 'A live game is required'using errcode='PT409';end if;
 if op in('volleyball.event.correct','volleyball.event.reverse')then
 if not exists(select 1 from boss_private.volleyball_active_events(g.id)where id=target.id)then raise exception 'Fact is no longer the active leaf'using errcode='PT409';end if;
 if op='volleyball.event.correct'and(kind is distinct from target.event_type or optional is not null and not exists(select 1 from public.game_tracking_snapshots x where x.id=(select sn.id from public.game_tracking_snapshots sn where sn.game_id=g.id and sn.side=volleyball_command.side and sn.effective_sequence<=target.origin_sequence order by sn.effective_sequence desc limit 1)and x.selection->'enabled'?optional))then raise exception 'Correction cannot invent an untracked fact type'using errcode='PT409';end if;
 if boss_private.volleyball_rebuild(g.id)is distinct from s.state then raise exception 'Volleyball state reconciliation failed'using errcode='PT409';end if;
 origin:=target.origin_sequence;
 candidate:=jsonb_build_object('id',eventid,'origin_sequence',origin,'event_type',kind,'side',side,'payload',payload);
 nextstate:=boss_private.volleyball_rebuild(g.id,candidate,target.id);
 elsif kind='assist'then
 candidate:=jsonb_build_object('id',eventid,'origin_sequence',origin,'event_type',kind,'side',side,'payload',payload);
 nextstate:=boss_private.volleyball_rebuild(g.id,candidate);
 else nextstate:=boss_private.volleyball_transition(s.configuration,s.state,kind,side,payload);end if;
 update public.game_volleyball_states set state=nextstate where game_id=g.id;
 end if;
 perform boss_private.games_require_live_auth();
 if actor is distinct from boss_private.require_admin_actor()or not boss_private.games_feature(g.organization_id,'volleyball_live_scoring')or not boss_private.games_feature(g.organization_id,'game_operations')
 or(op='volleyball.configure'and not boss_private.games_permission(actor,'games.manage',g,true))or(op in('volleyball.event.correct','volleyball.event.reverse')and not boss_private.games_permission(actor,'games.correct',g,true))or(op not in('volleyball.configure','volleyball.event.correct','volleyball.event.reverse')and not boss_private.games_operator_current(actor,g))then raise exception 'Access denied'using errcode='PT403';end if;
 update public.games set primary_score=(nextstate->>'primary_sets')::integer,opponent_score=(nextstate->>'opponent_sets')::integer,version=g.version+1 where id=g.id returning *into g;
 operationid:=boss_private.games_append(g.id,actor,op,request,oldstate,jsonb_build_object('volleyball',nextstate,'volleyball_event_id',eventid),target.operation_id);
 insert into public.game_volleyball_events(id,organization_id,game_id,operation_id,sequence,origin_sequence,event_type,side,payload,correction_of,actor_person_id,request_id,reason)
 values(eventid,g.organization_id,g.id,operationid,g.last_sequence+1,origin,kind,side,payload,target.id,actor,request,reason);
 return jsonb_build_object('game_id',g.id,'version',g.version,'event_id',eventid,'message','Saved.');
end$$;
create function boss_private.volleyball_team_coverage(p_game uuid,p_side text,p_cutoff bigint)returns jsonb
language plpgsql stable security definer set search_path=''as $$
declare coverage jsonb;e public.game_volleyball_events;keys text[];k text;begin
 coverage:=boss_private.tracking_coverage(p_game,p_side,p_cutoff);
 for e in select *from boss_private.volleyball_active_events(p_game)where sequence<=p_cutoff and event_type='rally'loop
 keys:='{}';
 if e.side=p_side and e.payload->>'outcome'='assisted_block'and not(e.payload?'blocker_roster_ids')then keys:=array['block_assists'];end if;
 if e.side<>p_side and e.payload->>'outcome'='ace'and not(e.payload?'receiver_roster_id')then keys:=keys||array['receptions','reception_errors'];end if;
 foreach k in array keys loop if coverage->>k='tracked'then coverage:=jsonb_set(coverage,array[k],'"partially_tracked"');end if;end loop;
 end loop;return coverage;
end$$;
create function boss_private.volleyball_player_coverage(p_game uuid,p_side text,p_cutoff bigint)returns jsonb
language plpgsql stable security definer set search_path=''as $$
declare coverage jsonb;e public.game_volleyball_events;k text;keys text[];cfg jsonb;state jsonb;serving text;begin
 coverage:=boss_private.volleyball_team_coverage(p_game,p_side,p_cutoff);
 select configuration into cfg from public.game_volleyball_states where game_id=p_game;
 state:=boss_private.volleyball_initial(cfg);
 for e in select *from boss_private.volleyball_active_events(p_game)where sequence<=p_cutoff order by origin_sequence,id loop
 if e.event_type='configure'then continue;end if;
 keys:='{}'::text[];
 if e.event_type='rally'and state->>'serving_side'=p_side and not(case when(cfg->>'strict_rotation')::boolean then(state->'lineups'->p_side->>0)is not null else e.payload->>'outcome'in('ace','service_error')and e.payload?'roster_id'end) then keys:=array['service_attempts'];end if;
 if e.side=p_side then
 if e.event_type='rally'and e.payload->>'outcome'='assisted_block'then
 if not(e.payload?'blocker_roster_ids')then keys:=keys||array['block_assists','blocks'];end if;
 elsif not(e.payload?'roster_id')then
 if e.event_type='rally'then keys:=keys||case e.payload->>'outcome'when'kill'then array['kills','attack_attempts','hitting_percentage']when'attack_error'then array['attack_errors','attack_attempts','hitting_percentage']when'ace'then array['service_aces']when'service_error'then array['service_errors']when'solo_block'then array['solo_blocks','blocks']when'reception_error'then array['receptions','reception_errors']else'{}'::text[]end;
 else k:=boss_private.volleyball_optional_key(e.event_type,e.payload);keys:=keys||case when k is null then'{}'::text[]when k='attack_attempts'then array[k,'hitting_percentage']else array[k]end;end if;
 end if;
 end if;
 -- An ace without a named receiver leaves receiving-player attribution incomplete.
 if e.side<>p_side and e.event_type='rally'and e.payload->>'outcome'='ace'and not(e.payload?'receiver_roster_id')then keys:=keys||array['receptions','reception_errors'];end if;
 foreach k in array keys loop if coverage->>k='tracked'then coverage:=jsonb_set(coverage,array[k],'"partially_tracked"');end if;end loop;
 state:=boss_private.volleyball_transition(cfg,state,e.event_type,e.side,e.payload);
 end loop;
 return coverage;
end$$;
-- Context comes from the same canonical transition, never from a second scoring engine.
create function boss_private.volleyball_trace(p_game uuid)returns table(event_id uuid,set_number integer,primary_points integer,opponent_points integer,serving_side text)
language plpgsql stable security definer set search_path=''as $$
declare e public.game_volleyball_events;cfg jsonb;state jsonb;begin
 select configuration into cfg from public.game_volleyball_states where game_id=p_game;
 state:=boss_private.volleyball_initial(cfg);
 for e in select *from boss_private.volleyball_active_events(p_game)order by origin_sequence,id loop
 if e.event_type='configure'then continue;end if;
 state:=boss_private.volleyball_transition(cfg,state,e.event_type,e.side,e.payload);
 event_id:=e.id;set_number:=(state->>'set_number')::integer;primary_points:=(state->>'primary_points')::integer;opponent_points:=(state->>'opponent_points')::integer;serving_side:=state->>'serving_side';return next;
 end loop;
end$$;
do $$declare f record;begin for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like'volleyball_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);end loop;end$$;
