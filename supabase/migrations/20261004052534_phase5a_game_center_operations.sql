-- Finite protected operations, ordered append history and bounded projections.
create function boss_private.games_validate(i jsonb,allowed text[],required text[] default '{}') returns void language plpgsql immutable set search_path='' as $$
declare k text;begin
 if i is null or jsonb_typeof(i)<>'object' or octet_length(i::text)>8192 or not(i?&required) then raise exception 'Invalid game operation' using errcode='PT422';end if;
 for k in select jsonb_object_keys(i) loop
 if not k=any(allowed) or i->k='null'::jsonb then raise exception 'Invalid game operation' using errcode='PT422';end if;
 if k in('expected_version','expected_event_version') and(jsonb_typeof(i->k)<>'number' or i->>k!~'^[1-9][0-9]{0,14}$') then raise exception 'Invalid game version' using errcode='PT422';end if;
 if k in('organization_id','event_id','game_id','team_id','unit_id','season_id','child_person_id','person_id','role_assignment_id','assignment_id','operation_id','primary_team_id') and(jsonb_typeof(i->k)<>'string' or i->>k!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') then raise exception 'Invalid game reference' using errcode='PT422';end if;
 end loop;
end $$;
create function boss_private.games_configure(p_actor uuid,i jsonb,p_request uuid,p_replay boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare organization uuid;module public.organization_modules;key text;prior jsonb;after_state jsonb;
 flags text[]:=array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management'];begin
 perform boss_private.games_validate(i,array['organization_id','expected_version','configuration'],array['organization_id','expected_version','configuration']);
 if jsonb_typeof(i->'configuration')<>'object' or i->'configuration'='{}'::jsonb then raise exception 'Invalid game configuration' using errcode='PT422';end if;
 for key in select jsonb_object_keys(i->'configuration') loop
 if not key=any(flags) or jsonb_typeof(i->'configuration'->key)<>'boolean' then raise exception 'Invalid game configuration' using errcode='PT422';end if;end loop;
 organization:=(i->>'organization_id')::uuid;
 -- Same exact actor/tenant relation locks as operational authorization. This
 -- command deliberately does not require Game Center to already be enabled.
 perform 1 from public.role_assignments assignment where assignment.person_id=p_actor and(assignment.organization_id=organization or assignment.scope_type='platform') order by assignment.id for share;
 perform 1 from public.organization_memberships membership where membership.person_id=p_actor and membership.organization_id=organization order by membership.id for share;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_role_permission(p_actor,'organization.manage',organization) then raise exception 'Access denied' using errcode='PT403';end if;
 select membership.* into module from public.organization_modules membership join public.modules catalog on catalog.id=membership.module_id and catalog.key='sports' and catalog.status='active'
 where membership.organization_id=organization and membership.status='active' and membership.starts_at<=clock_timestamp() and(membership.ends_at is null or membership.ends_at>clock_timestamp())
 order by membership.starts_at desc,membership.id desc limit 1 for update of membership;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_role_permission(p_actor,'organization.manage',organization) then raise exception 'Access denied' using errcode='PT403';end if;
 if module.id is null or module.status<>'active' or module.starts_at>clock_timestamp() or(module.ends_at is not null and module.ends_at<=clock_timestamp()) then raise exception 'Access denied' using errcode='PT403';end if;
 if p_replay then return jsonb_build_object('game_id',null,'organization_id',organization,'version',module.version,'message','Saved.');end if;
 if module.version<>(i->>'expected_version')::bigint then raise exception 'Sports configuration changed; reload before saving' using errcode='PT409';end if;
 select jsonb_build_object('version',module.version,'configuration',jsonb_object_agg(flag,case when jsonb_typeof(module.configuration->flag)='boolean' then module.configuration->flag else 'false'::jsonb end)) into prior from unnest(flags) flag;
 -- The revision trigger increments only for an actual configuration change.
 -- Activation, validity window and all unrelated module fields are preserved.
 update public.organization_modules set configuration=configuration||(i->'configuration') where id=module.id returning * into module;
 select jsonb_build_object('version',module.version,'configuration',jsonb_object_agg(flag,case when jsonb_typeof(module.configuration->flag)='boolean' then module.configuration->flag else 'false'::jsonb end)) into after_state from unnest(flags) flag;
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,before_data,after_data)
 values(organization,p_actor,auth.uid(),'games.configure','organization_module',module.id,'organization',organization,p_request,prior,after_state);
 return jsonb_build_object('game_id',null,'organization_id',organization,'version',module.version,'message','Game Center settings saved.');
end $$;
create function boss_private.games_append(p_game uuid,p_actor uuid,p_op text,p_request uuid,p_before jsonb,p_extra jsonb default '{}',p_correction uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare g public.games;aid uuid;oid uuid:=gen_random_uuid();after_state jsonb;begin
 select * into g from public.games where id=p_game for update;
 after_state:=boss_private.games_core_state(g)||p_extra;
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,before_data,after_data)
 values(g.organization_id,p_actor,auth.uid(),p_op,'game',g.id,'organization',g.organization_id,p_request,p_before,after_state) returning id into aid;
 insert into public.game_operations(id,organization_id,game_id,sequence,version,operation,actor_person_id,request_id,correction_of,prior_state,next_state,audit_event_id)
 values(oid,g.organization_id,g.id,g.last_sequence+1,g.version,p_op,p_actor,p_request,p_correction,p_before,after_state,aid);
 update public.games set last_sequence=g.last_sequence+1 where id=g.id;
 return oid;
end $$;
create function boss_private.games_lock_authority(p_actor uuid,g public.games) returns void language plpgsql security definer set search_path='' as $$
begin
 -- Event -> game -> actor role/membership/module. Revocation cannot commit
 -- through a protected write after these current authority rows are checked.
 perform 1 from public.role_assignments a where a.person_id=p_actor and(a.organization_id=g.organization_id or a.scope_type='platform') order by a.id for share;
 perform 1 from public.organization_memberships om where om.person_id=p_actor and om.organization_id=g.organization_id order by om.id for share;
 perform 1 from public.team_memberships m where m.person_id=p_actor and m.organization_id=g.organization_id and m.team_id in(g.primary_team_id,g.opponent_team_id) order by m.id for share;
 perform 1 from public.organization_modules m join public.modules catalog on catalog.id=m.module_id where m.organization_id=g.organization_id and catalog.key in('sports','calendar') order by m.id for share of m;
end $$;
create function boss_private.games_operation_allowed(p_actor uuid,p_op text,g public.games,p_configuration jsonb default null) returns boolean language sql volatile security definer set search_path='' as $$
 select case p_op
 when 'game.create' then boss_private.games_permission(p_actor,'games.create',g,true,p_configuration) and boss_private.calendar_can_manage_event('events.manage',g.event_id)
 when 'game.roster.snapshot' then g.status in('scheduled','pregame','delayed','postponed') and g.started_at is null and boss_private.games_permission(p_actor,'games.manage',g,true,p_configuration)
 and boss_private.games_role_permission(p_actor,'team.roster.view',g.organization_id,g.primary_team_id)
 and(g.opponent_team_id is null or boss_private.games_role_permission(p_actor,'team.roster.view',g.organization_id,g.opponent_team_id))
 when 'game.operator.assign' then g.status not in('final','canceled','abandoned') and boss_private.games_feature(g.organization_id,'game_operations',p_configuration) and boss_private.games_permission(p_actor,'games.manage',g,true,p_configuration) and boss_private.games_permission(p_actor,'games.operate',g,true,p_configuration)
 when 'game.operator.end' then boss_private.games_permission(p_actor,'games.manage',g,true,p_configuration)
 when 'game.start' then boss_private.games_operator_current(p_actor,g,p_configuration) and g.status not in('final','canceled','postponed','abandoned')
 when 'game.transition' then boss_private.games_operator_current(p_actor,g,p_configuration) and g.status not in('final','canceled','abandoned')
 when 'game.score.set' then boss_private.games_operator_current(p_actor,g,p_configuration) and g.status in('live','paused','suspended')
 when 'game.score.reverse' then boss_private.games_feature(g.organization_id,'game_operations',p_configuration) and boss_private.games_permission(p_actor,'games.correct',g,true,p_configuration) and g.status in('live','paused','suspended')
 when 'game.finalize' then boss_private.games_feature(g.organization_id,'game_operations',p_configuration) and boss_private.games_permission(p_actor,'games.finalize',g,true,p_configuration)
 when 'game.reopen' then boss_private.games_feature(g.organization_id,'game_operations',p_configuration) and boss_private.games_permission(p_actor,'games.correct',g,true,p_configuration)
 when 'game.publish' then boss_private.games_feature(g.organization_id,'public_game_center',p_configuration) and boss_private.games_permission(p_actor,'games.publish',g,true,p_configuration)
 and boss_private.calendar_can_manage_event('events.publish',g.event_id)
 else false end
$$;
create function boss_private.games_command(p_actor uuid,p_op text,i jsonb,p_request uuid,p_replay boolean default false,p_resource uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.games;e public.events;d public.event_game_details;occ jsonb;oldstate jsonb;extra jsonb:='{}';resource_id uuid;mode text;
 operator public.game_operator_assignments;ra public.role_assignments;rolekey text;target public.game_operations;
 hash text;attendance_key text;attendance_allowed boolean;seq bigint;newstatus text;count_roster integer;opid uuid;revision bigint;fields text[];required text[];
begin
 if p_actor is distinct from boss_private.current_person_id() then raise exception 'Access denied' using errcode='PT403';end if;
 if p_op='games.configure' then return boss_private.games_configure(p_actor,i,p_request,p_replay);end if;
 if p_op='game.create' then
 perform boss_private.games_validate(i,array['organization_id','event_id','expected_event_version','occurrence_key','primary_team_id','sport_key','competition_type'],array['event_id','expected_event_version','occurrence_key','primary_team_id','sport_key','competition_type']);
 select * into e from public.events where id=(i->>'event_id')::uuid and(not i?'organization_id' or organization_id=(i->>'organization_id')::uuid) for update;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() then raise exception 'Access denied' using errcode='PT403';end if;
 if e.id is null or not boss_private.games_feature(e.organization_id,'game_center') or not boss_private.games_module_live(e.organization_id,'calendar') or not boss_private.games_role_permission(p_actor,'games.create',e.organization_id,(i->>'primary_team_id')::uuid) or not boss_private.calendar_can_manage_event('events.manage',e.id) then raise exception 'Access denied' using errcode='PT403';end if;
 if e.event_type_key not in('game','tournament') or not boss_private.calendar_module_enabled(e.organization_id) or e.status not in('scheduled','confirmed') then raise exception 'Invalid competitive event' using errcode='PT422';end if;
 if not p_replay and e.version<>(i->>'expected_event_version')::bigint then raise exception 'Calendar changed; reload before linking' using errcode='PT409';end if;
 mode:=case when e.recurrence is null then 'single' else 'recurring' end;
 if p_replay then select * into g from public.games where id=p_resource and event_id=e.id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
 perform boss_private.games_lock_authority(p_actor,g);
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() then raise exception 'Access denied' using errcode='PT403';end if;
 if not boss_private.games_operation_allowed(p_actor,p_op,g) then raise exception 'Access denied' using errcode='PT403';end if;
 return jsonb_build_object('game_id',g.id,'version',g.version,'message','Saved.');end if;
 if mode='single' and i->>'occurrence_key'<>to_char(e.start_at at time zone e.timezone,'YYYY-MM-DD"T"HH24:MI:SS') then raise exception 'Invalid occurrence' using errcode='PT422';end if;
 occ:=boss_private.games_occurrence(e,i->>'occurrence_key',mode);
 if occ is null or occ->>'status' not in('scheduled','confirmed') then raise exception 'Invalid occurrence' using errcode='PT422';end if;
 select * into d from public.event_game_details where event_id=e.id and organization_id=e.organization_id;
 if not found or(d.opponent_team_id is null)=(d.external_opponent_name is null) or d.game_status not in('scheduled') then raise exception 'A valid competitive opponent is required' using errcode='PT422';end if;
 g.id:=gen_random_uuid();g.organization_id:=e.organization_id;g.event_id:=e.id;g.primary_team_id:=(i->>'primary_team_id')::uuid;g.opponent_team_id:=d.opponent_team_id;
 g.external_opponent_name:=d.external_opponent_name;g.sport_key:=i->>'sport_key';g.competition_type:=i->>'competition_type';g.home_away:=d.home_away;
 if g.primary_team_id is not distinct from g.opponent_team_id or g.competition_type not in('standard','tournament')
 or not exists(select 1 from public.game_sports where key=g.sport_key and status='active')
 or not exists(select 1 from public.event_targets where event_id=e.id and target_type='team' and target_id=g.primary_team_id)
 or(g.opponent_team_id is not null and not exists(select 1 from public.event_targets where event_id=e.id and target_type='team' and target_id=g.opponent_team_id)) then raise exception 'Invalid game context' using errcode='PT422';end if;
 perform boss_private.games_lock_authority(p_actor,g);
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() then raise exception 'Access denied' using errcode='PT403';end if;
 if not boss_private.games_permission(p_actor,'games.create',g,true) then raise exception 'Access denied' using errcode='PT403';end if;
 if exists(select 1 from public.games where event_id=e.id and(occurrence_mode='single' or occurrence_key=i->>'occurrence_key')) then raise exception 'Game already linked' using errcode='PT409';end if;
 select parent_unit_id,season_id into g.parent_unit_id,g.season_id from public.teams where id=g.primary_team_id and organization_id=e.organization_id;
 insert into public.games(id,organization_id,event_id,occurrence_key,occurrence_mode,primary_team_id,opponent_team_id,external_opponent_name,parent_unit_id,season_id,sport_key,home_away,competition_type,scheduled_start_at,scheduled_end_at,schedule_status,venue_id,visibility,created_by_person_id,updated_by_person_id)
 values(g.id,e.organization_id,e.id,i->>'occurrence_key',mode,g.primary_team_id,g.opponent_team_id,g.external_opponent_name,g.parent_unit_id,g.season_id,g.sport_key,g.home_away,g.competition_type,(occ->>'start_at')::timestamptz,(occ->>'end_at')::timestamptz,occ->>'status',e.venue_id,e.visibility,p_actor,p_actor);
 perform boss_private.games_append(g.id,p_actor,p_op,p_request,'{}',jsonb_build_object('event_id',e.id,'occurrence_key',i->>'occurrence_key','sport_key',g.sport_key));
 return jsonb_build_object('game_id',g.id,'version',1,'message','Game linked.');
 end if;
 fields:=array['game_id','expected_version'];required:=fields;
 case p_op
 when 'game.roster.snapshot' then null;
 when 'game.operator.assign' then fields:=fields||array['person_id','role_assignment_id','function_key','team_id','ends_at'];required:=fields;
 when 'game.operator.end' then fields:=fields||array['assignment_id'];required:=fields;
 when 'game.start' then null;
 when 'game.transition' then fields:=fields||array['status'];required:=fields;
 when 'game.score.set' then fields:=fields||array['primary_score','opponent_score'];required:=fields;
 when 'game.score.reverse' then fields:=fields||array['operation_id'];required:=fields;
 when 'game.finalize' then null;
 when 'game.reopen' then fields:=fields||array['reason'];required:=fields;
 when 'game.publish' then null;
 else raise exception 'Invalid game operation' using errcode='PT422';end case;
 perform boss_private.games_validate(i,fields,required);
 resource_id:=(i->>'game_id')::uuid;
 -- Resolve without granting access, then acquire the common event-first lock.
 select event_id into e.id from public.games where public.games.id=resource_id;
 if e.id is null then raise exception 'Access denied' using errcode='PT403';end if;
 select * into e from public.events where public.events.id=e.id for update;
 select * into g from public.games where public.games.id=resource_id for update;
 perform boss_private.games_lock_authority(p_actor,g);
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() then raise exception 'Access denied' using errcode='PT403';end if;
 if not boss_private.games_operation_allowed(p_actor,p_op,g) then raise exception 'Access denied' using errcode='PT403';end if;
 if p_replay then
 if p_op='game.operator.assign' then
 select * into ra from public.role_assignments where public.role_assignments.id=(i->>'role_assignment_id')::uuid and person_id=(i->>'person_id')::uuid;
 if not found then raise exception 'Access denied' using errcode='PT403';end if;
 perform boss_private.games_lock_authority(ra.person_id,g);
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_operation_allowed(p_actor,p_op,g) then raise exception 'Access denied' using errcode='PT403';end if;
 if not boss_private.games_role_permission(ra.person_id,'games.operate',g.organization_id,(i->>'team_id')::uuid,ra.id) then raise exception 'Access denied' using errcode='PT403';end if;
 end if;
 return jsonb_build_object('game_id',g.id,'version',g.version,'message','Saved.');end if;
 if g.version<>(i->>'expected_version')::bigint then raise exception 'Game changed; reload before saving' using errcode='PT409';end if;
 if(g.version<=0 or(i->>'expected_version')::bigint<=0) then raise exception 'Invalid game version' using errcode='PT422';end if;
 occ:=boss_private.games_occurrence(e,g.occurrence_key,g.occurrence_mode);
 if p_op in('game.start','game.transition','game.score.set','game.score.reverse','game.finalize') and
 (occ is null or occ->>'status' not in('scheduled','confirmed') or e.event_type_key not in('game','tournament')) then raise exception 'Calendar occurrence is not operable' using errcode='PT409';end if;
 oldstate:=boss_private.games_core_state(g);
 case p_op
 when 'game.roster.snapshot' then
 if g.status not in('scheduled','pregame','delayed','postponed') or g.started_at is not null then raise exception 'Game roster is sealed' using errcode='PT409';end if;
 revision:=g.roster_revision+1;
 attendance_allowed:=boss_private.attendance_feature(g.organization_id,'attendance') and boss_private.attendance_permission(p_actor,'attendance.view',g.event_id,true);
 attendance_key:=coalesce(boss_private.attendance_effective_key(g.event_id,g.occurrence_key),g.occurrence_key);
 select count(*) into count_roster from public.team_memberships m join public.participants p on p.id=m.participant_id and p.person_id=m.person_id and p.status='active'
 join public.people person on person.id=m.person_id and person.status='active' where m.organization_id=g.organization_id and m.team_id in(g.primary_team_id,g.opponent_team_id)
 and m.status='active' and m.starts_at<=now() and(m.ends_at is null or m.ends_at>now());
 if count_roster>500 then raise exception 'Roster exceeds the bounded game limit' using errcode='PT422';end if;
 insert into public.game_roster_snapshots(organization_id,game_id,revision,team_id,participant_id,person_id,display_name,jersey_number,position_label,availability,checkin_state,captured_by_person_id)
 select distinct on(m.team_id,m.participant_id) g.organization_id,g.id,revision,m.team_id,m.participant_id,m.person_id,
 left(coalesce(person.display_name,person.preferred_name,nullif(concat_ws(' ',person.first_name,person.last_name),''),'Participant'),200),left(m.jersey_number,30),left(m.position_label,100),
 case when not attendance_allowed then 'unknown' when response.needs_reconfirmation then 'pending' else coalesce(response.status,'unknown') end,case when attendance_allowed then checkin.state end,p_actor
 from public.team_memberships m join public.participants p on p.id=m.participant_id and p.person_id=m.person_id and p.status='active'
 join public.people person on person.id=m.person_id and person.status='active'
 left join public.attendance_responses response on response.event_id=g.event_id and response.occurrence_key=attendance_key and response.person_id=m.person_id and response.participant_id=m.participant_id and response.subject_kind='participant'
 left join public.attendance_checkins checkin on checkin.event_id=g.event_id and checkin.occurrence_key=attendance_key and checkin.person_id=m.person_id and checkin.participant_id=m.participant_id and checkin.subject_kind='participant'
 where m.organization_id=g.organization_id and m.team_id in(g.primary_team_id,g.opponent_team_id) and m.status='active' and m.starts_at<=now() and(m.ends_at is null or m.ends_at>now())
 order by m.team_id,m.participant_id,m.starts_at desc,m.id;
 update public.games set roster_revision=revision where public.games.id=g.id;extra:=jsonb_build_object('roster_count',count_roster);
 when 'game.operator.assign' then
 if g.status in('final','canceled','abandoned') then raise exception 'Game is locked' using errcode='PT409';end if;
 if i->>'function_key' not in('game_administrator','scorekeeper') or not isfinite((i->>'ends_at')::timestamptz) or(i->>'ends_at')::timestamptz<=clock_timestamp() then raise exception 'Invalid operator window' using errcode='PT422';end if;
 if(i->>'team_id')::uuid not in(g.primary_team_id,coalesce(g.opponent_team_id,g.primary_team_id)) then raise exception 'Access denied' using errcode='PT403';end if;
 select * into ra from public.role_assignments where public.role_assignments.id=(i->>'role_assignment_id')::uuid and person_id=(i->>'person_id')::uuid for share;
 if not found or not boss_private.games_role_permission(ra.person_id,'games.operate',g.organization_id,(i->>'team_id')::uuid,ra.id) then raise exception 'Access denied' using errcode='PT403';end if;
 perform boss_private.games_lock_authority(ra.person_id,g);
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_operation_allowed(p_actor,p_op,g) then raise exception 'Access denied' using errcode='PT403';end if;
 select key into rolekey from public.roles where public.roles.id=ra.role_id;
 if(i->>'function_key'='scorekeeper' and rolekey<>'scorekeeper') or(i->>'function_key'='game_administrator' and(rolekey='scorekeeper' or not boss_private.games_role_permission(ra.person_id,'games.manage',g.organization_id,(i->>'team_id')::uuid,ra.id))) then raise exception 'Access denied' using errcode='PT403';end if;
 if exists(select 1 from public.game_operator_assignments a where a.game_id=g.id and a.person_id=ra.person_id and a.function_key=i->>'function_key' and a.status='active' and a.ends_at>clock_timestamp()) then raise exception 'Operator assignment overlaps' using errcode='PT409';end if;
 insert into public.game_operator_assignments(organization_id,game_id,person_id,role_assignment_id,team_id,function_key,ends_at,assigned_by_person_id)
 values(g.organization_id,g.id,ra.person_id,ra.id,(i->>'team_id')::uuid,i->>'function_key',(i->>'ends_at')::timestamptz,p_actor) returning public.game_operator_assignments.id into resource_id;
 extra:=jsonb_build_object('assignment_id',resource_id,'person_id',ra.person_id,'function_key',i->>'function_key','ends_at',i->>'ends_at');
 when 'game.operator.end' then
 select * into operator from public.game_operator_assignments where public.game_operator_assignments.id=(i->>'assignment_id')::uuid and game_id=g.id and organization_id=g.organization_id for update;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_operation_allowed(p_actor,p_op,g) or operator.id is null then raise exception 'Access denied' using errcode='PT403';end if;
 update public.game_operator_assignments set status='ended',ends_at=least(ends_at,greatest(statement_timestamp(),starts_at+interval '1 microsecond')),updated_at=statement_timestamp() where public.game_operator_assignments.id=operator.id;
 extra:=jsonb_build_object('assignment_id',operator.id);
 when 'game.start' then
 if g.status not in('scheduled','pregame','delayed') or g.started_at is not null or g.roster_revision=0 then raise exception 'Game is not ready to start' using errcode='PT409';end if;
 update public.games set status='live',started_at=statement_timestamp() where public.games.id=g.id;
 when 'game.transition' then
 newstatus:=i->>'status';
 if not boss_private.games_transition_valid(g.status,newstatus) or(newstatus='live' and(g.started_at is null or g.roster_revision=0))
 or(g.started_at is not null and newstatus in('scheduled','pregame','postponed')) then raise exception 'Invalid lifecycle transition' using errcode='PT409';end if;
 update public.games set status=newstatus where public.games.id=g.id;
 when 'game.score.set' then
 if jsonb_typeof(i->'primary_score')<>'number' or jsonb_typeof(i->'opponent_score')<>'number' or i->>'primary_score'!~'^[0-9]{1,7}$' or i->>'opponent_score'!~'^[0-9]{1,7}$'
 or(i->>'primary_score')::integer>1000000 or(i->>'opponent_score')::integer>1000000 then raise exception 'Invalid score summary' using errcode='PT422';end if;
 update public.games set primary_score=(i->>'primary_score')::integer,opponent_score=(i->>'opponent_score')::integer where public.games.id=g.id;
 when 'game.score.reverse' then
 select * into target from public.game_operations where public.game_operations.id=(i->>'operation_id')::uuid and game_id=g.id and organization_id=g.organization_id;
 if not found or target.operation<>'game.score.set' then raise exception 'Access denied' using errcode='PT403';end if;
 if exists(select 1 from public.game_operations where game_id=g.id and(correction_of=target.id or(sequence>target.sequence and operation in('game.score.set','game.score.reverse','game.finalize','game.reopen'))))
 or(target.next_state->>'primary_score')::integer<>g.primary_score or(target.next_state->>'opponent_score')::integer<>g.opponent_score then raise exception 'Score correction is stale' using errcode='PT409';end if;
 update public.games set primary_score=(target.prior_state->>'primary_score')::integer,opponent_score=(target.prior_state->>'opponent_score')::integer where public.games.id=g.id;
 when 'game.finalize' then
 if g.status not in('live','paused','suspended') or g.roster_revision=0 or g.started_at is null then raise exception 'Game cannot be finalized' using errcode='PT409';end if;
 select encode(sha256(convert_to(coalesce(jsonb_agg(jsonb_build_object('participant_id',r.participant_id,'person_id',r.person_id,'team_id',r.team_id,'jersey_number',r.jersey_number,'position_label',r.position_label,'display_name',r.display_name,'active',r.active,'captain',r.captain,'starter',r.starter,'availability',r.availability,'checkin_state',r.checkin_state) order by r.team_id,r.participant_id),'[]'::jsonb)::text,'UTF8')),'hex') into hash
 from public.game_roster_snapshots r where r.game_id=g.id and r.revision=g.roster_revision;
 update public.games set status='final',final_primary_score=primary_score,final_opponent_score=opponent_score,
 winner_side=case when primary_score>opponent_score then 'primary' when primary_score<opponent_score then 'opponent' end,tied=primary_score=opponent_score,
 finalized_at=statement_timestamp(),finalized_by_person_id=p_actor,finalization_count=finalization_count+1 where public.games.id=g.id;
 insert into public.game_finalizations(organization_id,game_id,epoch,primary_score,opponent_score,roster_revision,operation_sequence,winner_side,tied,roster_hash,actor_person_id)
 values(g.organization_id,g.id,g.finalization_count+1,g.primary_score,g.opponent_score,g.roster_revision,g.last_sequence+1,
 case when g.primary_score>g.opponent_score then 'primary' when g.primary_score<g.opponent_score then 'opponent' end,g.primary_score=g.opponent_score,hash,p_actor);
 when 'game.reopen' then
 if g.status<>'final' then raise exception 'Only a finalized game can be reopened' using errcode='PT409';end if;
 if jsonb_typeof(i->'reason')<>'string' or length(btrim(i->>'reason')) not between 1 and 500 or i->>'reason'~'[[:cntrl:]]' then raise exception 'A safe correction reason is required' using errcode='PT422';end if;
 update public.games set status='paused',reopened_at=statement_timestamp() where public.games.id=g.id;
 extra:=jsonb_build_object('reason',btrim(i->>'reason'),'previous_finalization_epoch',g.finalization_count);
 when 'game.publish' then
 if e.visibility not in('public','authenticated') or e.publication_state<>'published' then raise exception 'Calendar publication is required' using errcode='PT403';end if;
 update public.games set publication_state='published' where public.games.id=g.id;
 end case;
 update public.games set version=version+1,updated_by_person_id=p_actor,updated_at=statement_timestamp() where public.games.id=g.id returning * into g;
 opid:=boss_private.games_append(g.id,p_actor,p_op,p_request,oldstate,extra,case when p_op='game.score.reverse' then target.id end);
 return jsonb_build_object('game_id',g.id,'version',g.version,'message','Saved.');
end $$;
create function boss_private.games_mutate(p_request_id uuid,p_command jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;receipt boss_private.game_operation_receipts;hash bytea;result jsonb;begin
 perform boss_private.games_require_live_auth();
 actor:=boss_private.require_admin_actor();
 if p_request_id is null then raise exception 'Invalid game operation' using errcode='PT422';end if;
 perform boss_private.games_validate(p_command,array['operation','input'],array['operation','input']);
 perform pg_advisory_xact_lock(hashtextextended('games-request:'||actor::text||':'||p_request_id::text,0));
 perform boss_private.games_require_live_auth();
 hash:=sha256(convert_to(p_command::text,'UTF8'));
 select * into receipt from boss_private.game_operation_receipts where actor_person_id=actor and request_id=p_request_id;
 if found then
 if receipt.input_hash<>hash then raise exception 'Conflicting game request' using errcode='PT409';end if;
 perform boss_private.games_command(actor,p_command->>'operation',p_command->'input',p_request_id,true,(receipt.result->>'game_id')::uuid);
 return receipt.result||jsonb_build_object('replayed',true);end if;
 result:=boss_private.games_command(actor,p_command->>'operation',p_command->'input',p_request_id)||jsonb_build_object('replayed',false);
 insert into boss_private.game_operation_receipts(actor_person_id,request_id,input_hash,command,result) values(actor,p_request_id,hash,p_command,result);
 return result;
exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' then raise;
 when unique_violation or serialization_failure or deadlock_detected then raise exception 'Conflicting game operation' using errcode='PT409';
 when others then raise exception 'Invalid game operation' using errcode='PT422';
end $$;
create function public.boss_games_mutate(p_request_id uuid,p_command jsonb) returns jsonb language sql security invoker set search_path='' as $$select boss_private.games_mutate(p_request_id,p_command)$$;

create function boss_private.games_projection(g public.games,p_actor uuid,p_detail boolean default false,p_family boolean default false,p_child uuid default null,p_configuration jsonb default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare e public.events;manage boolean;operate boolean;correct boolean;roster jsonb:='[]';operators jsonb:='[]';history jsonb:='[]';finals jsonb:='[]';venue text;attendance_enabled boolean;begin
 select * into e from public.events where id=g.event_id;
 manage:=not p_family and boss_private.games_permission(p_actor,'games.manage',g,true,p_configuration);
 operate:=not p_family and boss_private.games_operator_current(p_actor,g,p_configuration) and g.status not in('final','canceled','postponed','abandoned') and g.schedule_status in('scheduled','confirmed') and e.status in('scheduled','confirmed') and e.event_type_key in('game','tournament');
 correct:=not p_family and boss_private.games_feature(g.organization_id,'game_operations',p_configuration) and boss_private.games_permission(p_actor,'games.correct',g,true,p_configuration);
 if p_detail then
 attendance_enabled:=boss_private.attendance_feature(g.organization_id,'attendance');
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'person_id',r.person_id,'participant_id',r.participant_id,'team_id',r.team_id,'display_name',r.display_name,'jersey_number',r.jersey_number,'position_label',r.position_label,'active',r.active,'captain',r.captain,'starter',r.starter,'availability',case when attendance_enabled and((not p_family and boss_private.attendance_subject_permission(p_actor,'attendance.view',g.event_id,r.person_id)) or boss_private.attendance_can_subject(p_actor,g.event_id,r.person_id,r.participant_id,'participant','view')) then r.availability else 'unknown' end,
 'checkin_state',case when attendance_enabled and((not p_family and boss_private.attendance_subject_permission(p_actor,'attendance.view',g.event_id,r.person_id)) or boss_private.attendance_can_subject(p_actor,g.event_id,r.person_id,r.participant_id,'participant','view')) then r.checkin_state end,'revision',r.revision) order by r.team_id,r.display_name,r.id),'[]') into roster
 from public.game_roster_snapshots r where r.game_id=g.id and r.revision=g.roster_revision
 and(p_child is null or r.person_id=p_child) and(boss_private.games_person_related(p_actor,r.person_id) or(not p_family and boss_private.games_role_permission(p_actor,'team.roster.view',g.organization_id,r.team_id)));
 if manage then
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'person_id',a.person_id,'display_name',coalesce(p.display_name,p.preferred_name,nullif(concat_ws(' ',p.first_name,p.last_name),''),'Operator'),'role_assignment_id',a.role_assignment_id,'team_id',a.team_id,'function_key',a.function_key,'status',case when a.status='active' and(a.ends_at<=clock_timestamp() or not boss_private.games_role_permission(a.person_id,'games.operate',g.organization_id,a.team_id,a.role_assignment_id)) then 'ended' else a.status end,'ends_at',a.ends_at) order by a.created_at,a.id),'[]') into operators
 from(select * from public.game_operator_assignments where game_id=g.id order by created_at desc,id limit 100)a join public.people p on p.id=a.person_id;
 end if;
 if not p_family and(manage or operate or correct) then
 select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'sequence',o.sequence,'version',o.version,'operation',o.operation,'created_at',o.created_at,'correction_of',o.correction_of,'summary',case o.operation when 'game.create' then 'Game linked' when 'game.roster.snapshot' then 'Roster snapshot captured' when 'game.operator.assign' then 'Operator assigned' when 'game.operator.end' then 'Operator removed' when 'game.start' then 'Game started' when 'game.transition' then 'Status '||coalesce(o.prior_state->>'status','unknown')||' to '||coalesce(o.next_state->>'status','unknown') when 'game.score.set' then 'Score '||coalesce(o.prior_state->>'primary_score','0')||':'||coalesce(o.prior_state->>'opponent_score','0')||' to '||coalesce(o.next_state->>'primary_score','0')||':'||coalesce(o.next_state->>'opponent_score','0') when 'game.score.reverse' then 'Score reversal '||coalesce(o.prior_state->>'primary_score','0')||':'||coalesce(o.prior_state->>'opponent_score','0')||' to '||coalesce(o.next_state->>'primary_score','0')||':'||coalesce(o.next_state->>'opponent_score','0') when 'game.finalize' then 'Game finalized' when 'game.reopen' then 'Game reopened for correction' when 'game.publish' then 'Game summary published' else 'Calendar context updated' end) order by o.sequence),'[]') into history
 from(select * from public.game_operations where game_id=g.id order by sequence desc limit 100)o;
 select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'epoch',f.epoch,'primary_score',f.primary_score,'opponent_score',f.opponent_score,'roster_revision',f.roster_revision,'winner_side',f.winner_side,'tied',f.tied,'created_at',f.created_at) order by f.epoch),'[]') into finals
 from(select * from public.game_finalizations where game_id=g.id order by epoch desc limit 100)f;
 end if;end if;
 select v.name into venue from public.venues v where v.id=g.venue_id and(v.is_public or manage or boss_private.games_role_permission(p_actor,'games.view',g.organization_id,g.primary_team_id) or boss_private.games_team_related(p_actor,g.organization_id,g.primary_team_id) or(g.opponent_team_id is not null and boss_private.games_team_related(p_actor,g.organization_id,g.opponent_team_id)));
 return jsonb_build_object('id',g.id,'organization_id',g.organization_id,'event_id',g.event_id,'occurrence_key',g.occurrence_key,'occurrence_mode',g.occurrence_mode,'title',e.title,'sport_key',g.sport_key,'sport_label',(select name from public.game_sports where key=g.sport_key),
 'primary',jsonb_build_object('team_id',g.primary_team_id,'label',(select name from public.teams where id=g.primary_team_id),'score',g.primary_score,'final_score',g.final_primary_score),
 'opponent',jsonb_build_object('team_id',g.opponent_team_id,'label',coalesce((select name from public.teams where id=g.opponent_team_id),g.external_opponent_name),'score',g.opponent_score,'final_score',g.final_opponent_score),
 'home_away',g.home_away,'competition_type',g.competition_type,'start_at',g.scheduled_start_at,'end_at',g.scheduled_end_at,'timezone',e.timezone,'venue_label',venue,'event_status',g.schedule_status,'status',g.status,'visibility',e.visibility,'publication_state',g.publication_state,'version',g.version,'roster_revision',g.roster_revision,'finalization_count',g.finalization_count,'reopened',g.reopened_at is not null,
 'capabilities',jsonb_build_object('manage',manage,'roster_snapshot',not p_family and boss_private.games_operation_allowed(p_actor,'game.roster.snapshot',g,p_configuration),
 'operate',operate,'resume',operate and g.started_at is not null and g.roster_revision>0 and g.status in('paused','delayed','suspended') and boss_private.games_transition_valid(g.status,'live'),'start',operate and g.status in('scheduled','pregame','delayed') and g.started_at is null and g.roster_revision>0,
 'finalize',not p_family and boss_private.games_operation_allowed(p_actor,'game.finalize',g,p_configuration) and g.status in('live','paused','suspended'),
 'correct',correct,'publish',not p_family and boss_private.games_operation_allowed(p_actor,'game.publish',g,p_configuration) and e.publication_state='published' and e.visibility in('public','authenticated'),
 'view_roster',jsonb_array_length(roster)>0),'roster',roster,'operators',operators,'history',history,'finalizations',finals);
end $$;

create function boss_private.games_read(q jsonb default '{}') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;org uuid;gameid uuid;team uuid;unit uuid;season uuid;child uuid;from_at timestamptz;to_at timestamptz;viewkey text;statuskey text;configuration_version bigint:=0;
 organizations jsonb:='[]';teams jsonb:='[]';units jsonb:='[]';seasons jsonb:='[]';sports jsonb;games jsonb:='[]';candidates jsonb:='[]';operators jsonb:='[]';features jsonb;cancreate boolean:=false;configure boolean:=false;g public.games;more boolean:=false;begin
 perform boss_private.games_require_live_auth();
 actor:=boss_private.require_admin_actor();
 perform boss_private.games_validate(q,array['view','from','to','organization_id','game_id','team_id','unit_id','season_id','status','child_person_id']);
 viewkey:=coalesce(q->>'view','all');statuskey:=q->>'status';from_at:=coalesce((q->>'from')::timestamptz,now()-interval '7 days');to_at:=coalesce((q->>'to')::timestamptz,now()+interval '28 days');
 if viewkey not in('all','family','navigation') or not isfinite(from_at) or not isfinite(to_at) or to_at<=from_at or to_at-from_at>interval '93 days' or(statuskey is not null and statuskey not in('scheduled','pregame','live','paused','delayed','suspended','final','canceled','postponed','abandoned')) then raise exception 'Invalid game query' using errcode='PT422';end if;
 org:=(q->>'organization_id')::uuid;gameid:=(q->>'game_id')::uuid;team:=(q->>'team_id')::uuid;unit:=(q->>'unit_id')::uuid;season:=(q->>'season_id')::uuid;child:=(q->>'child_person_id')::uuid;
 if child is not null and not boss_private.games_person_related(actor,child) then raise exception 'Access denied' using errcode='PT403';end if;
 if viewkey='navigation' then
 return jsonb_build_object('navigation_available',exists(select 1 from boss_private.games_organization_candidates(actor) candidate where boss_private.games_org_known(actor,candidate.organization_id) and(boss_private.games_role_permission(actor,'organization.manage',candidate.organization_id) or(boss_private.games_feature(candidate.organization_id,'game_center') and(boss_private.games_role_permission(actor,'games.view',candidate.organization_id) or exists(select 1 from public.teams t where t.organization_id=candidate.organization_id and(boss_private.games_role_permission(actor,'games.view',candidate.organization_id,t.id) or boss_private.games_team_related(actor,candidate.organization_id,t.id))))))));
 end if;
 if gameid is not null then select * into g from public.games where id=gameid;
 if not found then raise exception 'Access denied' using errcode='PT403';end if;features:=boss_private.games_configuration(g.organization_id);
 if not boss_private.games_can_view(actor,g,features) or(org is not null and org<>g.organization_id) then raise exception 'Access denied' using errcode='PT403';end if;org:=g.organization_id;end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'label',o.name) order by o.name,o.id),'[]') into organizations
 from(select o.* from boss_private.games_organization_candidates(actor) candidate join public.organizations o on o.id=candidate.organization_id where boss_private.games_org_known(actor,o.id) order by o.name,o.id limit 100)o;
 if org is null then org:=(organizations->0->>'id')::uuid;end if;
 if org is not null and not boss_private.games_org_known(actor,org) then raise exception 'Access denied' using errcode='PT403';end if;
 features:=coalesce(features,boss_private.games_configuration(org));configure:=org is not null and boss_private.games_role_permission(actor,'organization.manage',org);
 select coalesce((select membership.version from public.organization_modules membership join public.modules catalog on catalog.id=membership.module_id and catalog.key='sports' and catalog.status='active'
 where membership.organization_id=org and membership.status='active' and membership.starts_at<=clock_timestamp() and(membership.ends_at is null or membership.ends_at>clock_timestamp()) order by membership.starts_at desc,membership.id desc limit 1),0) into configuration_version;
 select jsonb_agg(jsonb_build_object('key',key,'label',name) order by key) into sports from public.game_sports where status='active';
 if org is not null and boss_private.games_feature(org,'game_center',features) and boss_private.calendar_module_enabled(org) then
 if team is not null and not exists(select 1 from public.teams t where t.id=team and t.organization_id=org and(boss_private.games_role_permission(actor,'games.view',org,t.id) or boss_private.games_team_related(actor,org,t.id,child))) then raise exception 'Access denied' using errcode='PT403';end if;
 if unit is not null and not exists(select 1 from public.organization_units u where u.id=unit and u.organization_id=org and u.status='active') then raise exception 'Access denied' using errcode='PT403';end if;
 if season is not null and not exists(select 1 from public.seasons s where s.id=season and s.organization_id=org) then raise exception 'Access denied' using errcode='PT403';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'label',t.name) order by t.name,t.id),'[]') into teams
 from(select * from public.teams t where t.organization_id=org and t.status='active' and(boss_private.games_role_permission(actor,'games.view',org,t.id) or boss_private.games_team_related(actor,org,t.id,child)) order by t.name,t.id limit 100)t;
 select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'label',u.name) order by u.name,u.id),'[]') into units
 from(select * from public.organization_units u where u.organization_id=org and u.status='active' and(boss_private.games_role_permission(actor,'games.view',org) or exists(select 1 from jsonb_array_elements(teams) t join public.teams tm on tm.id=(t->>'id')::uuid where tm.parent_unit_id=u.id)) order by u.name,u.id limit 100)u;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'label',s.name) order by s.name,s.id),'[]') into seasons
 from(select * from public.seasons s where s.organization_id=org and(boss_private.games_role_permission(actor,'games.view',org) or exists(select 1 from jsonb_array_elements(teams) t join public.teams tm on tm.id=(t->>'id')::uuid where tm.season_id=s.id)) order by s.name,s.id limit 100)s;
 with selected as materialized(select gg.* from public.games gg where gg.organization_id=org and(gameid is null or gg.id=gameid)
 and(gameid is not null or(gg.scheduled_start_at<to_at and gg.scheduled_end_at>from_at)) and(statuskey is null or gg.status=statuskey)
 and(team is null or team in(gg.primary_team_id,gg.opponent_team_id))
 and(unit is null or gg.parent_unit_id=unit or exists(select 1 from public.teams t where t.id=gg.opponent_team_id and t.parent_unit_id=unit))
 and(season is null or gg.season_id=season)
 and boss_private.games_can_view(actor,gg,features)
 and(viewkey<>'family' or boss_private.games_team_related(actor,org,gg.primary_team_id,child) or(gg.opponent_team_id is not null and boss_private.games_team_related(actor,org,gg.opponent_team_id,child)))
 and(child is null or boss_private.games_team_related(actor,org,gg.primary_team_id,child) or(gg.opponent_team_id is not null and boss_private.games_team_related(actor,org,gg.opponent_team_id,child)))
 order by gg.scheduled_start_at,gg.id limit 101)
 select coalesce(jsonb_agg(s.payload order by s.ordinal) filter(where s.ordinal<=100),'[]'),count(*)>100 into games,more
 from(select boss_private.games_projection(selected::public.games,actor,gameid is not null,viewkey='family',child,features) payload,row_number() over(order by scheduled_start_at,id) ordinal from selected)s;
 -- Creation expands only a bounded, indexed Calendar candidate set. Existing
 -- linked games are read from resolved schedule columns, never re-expanded.
 if viewkey='all' and gameid is null then
 with event_candidates as materialized(select e.* from public.events e where e.organization_id=org and e.event_type_key in('game','tournament') and e.status in('scheduled','confirmed')
 and e.start_at<to_at and(e.end_at>from_at or(e.recurrence is not null and e.recurrence_end_at>from_at))
 and boss_private.calendar_can_manage_event('events.manage',e.id) order by e.start_at,e.id limit 100),
 occurrences as(select e.id event_id,e.version event_version,e.recurrence,d.opponent_team_id,d.external_opponent_name,d.home_away,x.*
 from event_candidates e join public.event_game_details d on d.event_id=e.id and(d.opponent_team_id is not null or d.external_opponent_name is not null)
 cross join lateral boss_private.calendar_occurrences(e::public.events,from_at,to_at)x where x.status in('scheduled','confirmed')
 and not exists(select 1 from public.games gg where gg.event_id=e.id and(gg.occurrence_mode='single' or gg.occurrence_key=x.occurrence_key))),
 projected as(select o.*,coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'label',t.name) order by t.name,t.id) from public.event_targets target join public.teams t on t.id=target.target_id and t.organization_id=org
 where target.event_id=o.event_id and target.target_type='team' and t.id is distinct from o.opponent_team_id and boss_private.games_role_permission(actor,'games.create',org,t.id)
 and(o.opponent_team_id is null or boss_private.games_role_permission(actor,'games.create',org,o.opponent_team_id))),'[]') choices from occurrences o order by o.start_at,o.event_id,o.occurrence_key limit 100)
 select coalesce(jsonb_agg(jsonb_build_object('event_id',event_id,'event_version',event_version,'occurrence_key',occurrence_key,'title',title,'start_at',start_at,'end_at',end_at,'home_away',home_away,'opponent_label',coalesce((select name from public.teams where id=opponent_team_id),external_opponent_name),'teams',choices) order by start_at,event_id,occurrence_key) filter(where jsonb_array_length(choices)>0),'[]') into candidates from projected;
 cancreate:=jsonb_array_length(candidates)>0;end if;
 if viewkey='all' and gameid is not null and boss_private.games_permission(actor,'games.manage',g,true,features) and boss_private.games_permission(actor,'games.operate',g,true,features) then
 select coalesce(jsonb_agg(candidate.payload order by candidate.person_id,candidate.role_id,candidate.team_id),'[]') into operators from(
 select a.person_id,a.id role_id,t.id team_id,jsonb_build_object('person_id',a.person_id,'display_name',coalesce(p.display_name,p.preferred_name,nullif(concat_ws(' ',p.first_name,p.last_name),''),'Operator'),'role_assignment_id',a.id,'team_id',t.id,'functions',case when r.key='scorekeeper' then jsonb_build_array('scorekeeper') else jsonb_build_array('game_administrator') end) payload
 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active' join public.people p on p.id=a.person_id and p.status='active'
 join public.teams t on t.id in(g.primary_team_id,g.opponent_team_id)
 where a.status='active' and a.starts_at<=now() and(a.ends_at is null or a.ends_at>now()) and(a.organization_id=org or a.scope_type='platform')
 and boss_private.games_role_permission(a.person_id,'games.operate',org,t.id,a.id,features) and(r.key='scorekeeper' or boss_private.games_role_permission(a.person_id,'games.manage',org,t.id,a.id,features))
 order by a.person_id,a.id,t.id limit 100)candidate;
 end if;end if;
 return jsonb_build_object('navigation_available',org is not null and boss_private.games_feature(org,'game_center',features) and boss_private.calendar_module_enabled(org),'organization_id',org,'view',viewkey,'range',jsonb_build_object('from',from_at,'to',to_at),'features',features,'configuration_version',configuration_version,'capabilities',jsonb_build_object('configure',configure and viewkey='all','create',cancreate),'organizations',organizations,'teams',teams,'units',units,'seasons',seasons,'sports',sports,'games',games,'create_candidates',candidates,'operator_candidates',operators,'more',more);
exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT422' then raise;
 when others then raise exception 'Invalid game query' using errcode='PT422';end $$;
create function public.boss_games_read(p_query jsonb default '{}') returns jsonb language sql stable security invoker set search_path='' as $$select boss_private.games_read(p_query)$$;
DO $$declare r record;begin for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'games_%' loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',r.signature);end loop;end $$;
revoke all on function public.boss_games_read(jsonb),public.boss_games_mutate(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function boss_private.games_read(jsonb),boss_private.games_mutate(uuid,jsonb),public.boss_games_read(jsonb),public.boss_games_mutate(uuid,jsonb) to authenticated;
