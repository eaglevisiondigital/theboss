-- Reconcile only a completed Calendar command, never its transient detail rows.
-- Keep the latest Phase 4B dispatcher unchanged under an internal name.
alter function boss_private.calendar_command(jsonb,uuid,uuid,boolean,boolean,uuid) rename to calendar_command_phase4b;
create function boss_private.calendar_command(p_command jsonb,p_actor uuid,p_request uuid,p_preview boolean default false,p_replay boolean default false,p_resource uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare op text:=p_command->>'operation';i jsonb:=p_command->'input';result jsonb;old_event public.events;e public.events;g public.games;d public.event_game_details;occ jsonb;prior jsonb;newstatus text;eventid uuid;begin
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.current_person_id() then raise exception 'Access denied' using errcode='PT403';end if;
 perform boss_private.calendar_validate_input(p_command,array['operation','input'],array['operation','input']);
 if op in('event.update','event.exception') then
 eventid:=(i->>'event_id')::uuid;
 if not boss_private.calendar_can_manage_event('events.manage',eventid) then raise exception 'Access denied' using errcode='PT403';end if;
 select * into old_event from public.events where id=eventid for update;
 perform boss_private.games_require_live_auth();
 if not boss_private.calendar_can_manage_event('events.manage',eventid) then raise exception 'Access denied' using errcode='PT403';end if;
 -- The consistent event -> sorted games lock also serializes cancellation
 -- against score/start/finalization, including commands from another device.
 perform 1 from public.games where event_id=eventid order by id for update;
 perform boss_private.games_require_live_auth();
 if not boss_private.calendar_can_manage_event('events.manage',eventid) then raise exception 'Access denied' using errcode='PT403';end if;
 if op='event.update' and exists(select 1 from public.games where event_id=eventid) then
 if i->>'event_type_key' not in('game','tournament') then raise exception 'Linked game identity cannot change' using errcode='PT409';end if;
 if exists(select 1 from public.games gg where gg.event_id=eventid and gg.occurrence_mode='single') and nullif(i->'recurrence','null'::jsonb) is not null then raise exception 'Linked occurrence identity cannot change' using errcode='PT409';end if;
 if exists(select 1 from public.games gg where gg.event_id=eventid and gg.occurrence_mode='recurring') and
 ((i->>'start_at')::timestamptz is distinct from old_event.start_at or i->>'timezone' is distinct from old_event.timezone or nullif(i->'recurrence','null'::jsonb) is distinct from old_event.recurrence or coalesce((i->>'reset_exceptions')::boolean,false)) then raise exception 'Linked recurring identity cannot change; edit the occurrence instead' using errcode='PT409';end if;
 for g in select * from public.games where event_id=eventid order by id loop
 if(i->'game'->>'opponent_team_id')::uuid is distinct from g.opponent_team_id or i->'game'->>'external_opponent_name' is distinct from g.external_opponent_name or i->'game'->>'home_away' is distinct from g.home_away
 or not exists(select 1 from jsonb_array_elements(i->'targets') t where t->>'target_type'='team' and(t->>'target_id')::uuid=g.primary_team_id)
 or(g.opponent_team_id is not null and not exists(select 1 from jsonb_array_elements(i->'targets') t where t->>'target_type'='team' and(t->>'target_id')::uuid=g.opponent_team_id)) then raise exception 'Linked competitors cannot change' using errcode='PT409';end if;
 end loop;end if;end if;
 result:=boss_private.calendar_command_phase4b(p_command,p_actor,p_request,p_preview,p_replay,p_resource);
 if p_preview or p_replay or op not in('event.update','event.exception') then return result;end if;
 select * into e from public.events where id=eventid;
 for g in select * from public.games where event_id=eventid order by id for update loop
 occ:=boss_private.games_occurrence(e,g.occurrence_key,g.occurrence_mode);
 if occ is null then raise exception 'Linked occurrence cannot be removed' using errcode='PT409';end if;
 newstatus:=g.status;
 -- Calendar cancellation never rewrites sealed final competition facts.
 if g.status<>'final' then
 if occ->>'status' in('canceled','archived') then newstatus:='canceled';
 elsif occ->>'status'='postponed' then newstatus:=case when g.started_at is null then 'postponed' else 'suspended' end;
 elsif occ->>'status' in('draft','completed') and g.started_at is not null then newstatus:='suspended';
 elsif occ->>'status' in('scheduled','confirmed') and g.status='postponed' and g.started_at is null then newstatus:='scheduled';end if;end if;
 if(g.scheduled_start_at,g.scheduled_end_at,g.schedule_status,g.venue_id,g.visibility,g.status) is distinct from
 ((occ->>'start_at')::timestamptz,(occ->>'end_at')::timestamptz,occ->>'status',e.venue_id,e.visibility,newstatus) then
 prior:=boss_private.games_core_state(g);
 update public.games set scheduled_start_at=(occ->>'start_at')::timestamptz,scheduled_end_at=(occ->>'end_at')::timestamptz,schedule_status=occ->>'status',venue_id=e.venue_id,visibility=e.visibility,status=newstatus,
 publication_state=case when e.publication_state='unpublished' or e.visibility not in('public','authenticated') then 'unpublished' else publication_state end,
 version=version+1,updated_by_person_id=p_actor,updated_at=statement_timestamp() where id=g.id;
 perform boss_private.games_append(g.id,p_actor,'game.calendar.sync',p_request,prior,jsonb_build_object('calendar_operation',op,'event_version',e.version));
 elsif(e.publication_state='unpublished' or e.visibility not in('public','authenticated')) and g.publication_state='published' then
 prior:=boss_private.games_core_state(g);update public.games set publication_state='unpublished',version=version+1,updated_by_person_id=p_actor,updated_at=statement_timestamp() where id=g.id;
 perform boss_private.games_append(g.id,p_actor,'game.calendar.sync',p_request,prior,jsonb_build_object('calendar_operation',op,'event_version',e.version));end if;
 end loop;
 return result;
end $$;
revoke all on function boss_private.calendar_command(jsonb,uuid,uuid,boolean,boolean,uuid),boss_private.calendar_command_phase4b(jsonb,uuid,uuid,boolean,boolean,uuid) from public,anon,authenticated,service_role;

-- Low-volume lifecycle/assignment source hooks extend the current Notifications
-- pipeline. Manual score operations deliberately enqueue no notification.
alter table public.notification_events drop constraint notification_events_source_module_check;
alter table public.notification_events add constraint notification_events_source_module_check check(source_module in('calendar','registration','messaging','volunteers','sports'));
alter table public.notification_events drop constraint notification_events_source_type_check;
alter table public.notification_events add constraint notification_events_source_type_check check(source_type in('event','registration','registration_document','charge','payment','message','attendance_request','volunteer_shift','volunteer_assignment','volunteer_event','game_operation'));
insert into boss_private.notification_types(key,category,source_module,title,body) values
 ('game.started','events','sports','Game started','An authorized game has started. Review Game Center.'),
 ('game.delayed','events','sports','Game delayed','A game status changed. Review Game Center.'),
 ('game.canceled','events','sports','Game canceled','A game was canceled. Review its current calendar context.'),
 ('game.final','events','sports','Game final','A game result is ready in Game Center.'),
 ('game.operator_assigned','events','sports','Game operator assignment','Review your authorized game operator assignment.');
create function boss_private.games_notification_visible(p_event public.notification_events,p_person uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare g public.games;o public.game_operations;begin
 if p_event.source_type<>'game_operation' or p_event.source_module<>'sports' or not boss_private.notification_person_active(p_person)
 or not boss_private.comm_feature(p_event.organization_id,'in_app_notifications') or p_event.status='canceled' then return false;end if;
 select * into o from public.game_operations where id=p_event.source_id and organization_id=p_event.organization_id;
 if not found then return false;end if;
 select * into g from public.games where id=o.game_id and organization_id=p_event.organization_id;
 if not found or not boss_private.games_can_view(p_person,g) then return false;end if;
 if p_event.event_type='game.operator_assigned' then
 return exists(select 1 from public.game_operator_assignments a where a.id=(o.next_state->>'assignment_id')::uuid and a.person_id=p_person and a.status='active'
 and a.created_at<=p_event.occurred_at and a.starts_at<=p_event.occurred_at and a.ends_at>now() and boss_private.games_operator_current(p_person,g));end if;
 return exists(select 1 from public.game_operator_assignments a where a.game_id=g.id and a.person_id=p_person and a.created_at<=p_event.occurred_at and a.starts_at<=p_event.occurred_at and a.ends_at>now() and a.status='active' and boss_private.games_operator_current(p_person,g))
 or boss_private.notification_context_at(p_person,g.organization_id,'team',g.primary_team_id,p_event.occurred_at)
 or boss_private.notification_permission_at(p_person,'games.view',g.organization_id,'team',g.primary_team_id,p_event.occurred_at)
 or(g.opponent_team_id is not null and(boss_private.notification_context_at(p_person,g.organization_id,'team',g.opponent_team_id,p_event.occurred_at)
 or boss_private.notification_permission_at(p_person,'games.view',g.organization_id,'team',g.opponent_team_id,p_event.occurred_at)));
end $$;
alter function boss_private.notification_source_visible(public.notification_events,uuid) rename to notification_source_visible_phase4b;
create function boss_private.notification_source_visible(p_event public.notification_events,p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select case when p_event.source_type='game_operation' then boss_private.games_notification_visible(p_event,p_person) else boss_private.notification_source_visible_phase4b(p_event,p_person) end
$$;
alter function boss_private.notification_candidates(public.notification_events,uuid,integer) rename to notification_candidates_phase4b;
create function boss_private.notification_candidates(p_event public.notification_events,p_after uuid,p_limit integer) returns table(person_id uuid) language plpgsql stable security definer set search_path='' as $$
declare g public.games;begin
 if p_event.source_type<>'game_operation' then return query select c.person_id from boss_private.notification_candidates_phase4b(p_event,p_after,p_limit)c;return;end if;
 select gg.* into g from public.games gg join public.game_operations o on o.game_id=gg.id where o.id=p_event.source_id and gg.organization_id=p_event.organization_id;
 if not found then return;end if;
 return query select candidate.person_id from(
 (select distinct m.person_id from public.team_memberships m where m.organization_id=g.organization_id and m.team_id in(g.primary_team_id,g.opponent_team_id) and m.status='active'
 and m.created_at<=p_event.occurred_at and m.starts_at<=p_event.occurred_at and(m.ends_at is null or m.ends_at>now()) and(p_after is null or m.person_id>p_after)
 order by m.person_id limit greatest(1,least(p_limit,100)))
 union(select distinct r.guardian_person_id from public.guardian_relationships r join public.team_memberships m on m.person_id=r.dependent_person_id
 where m.organization_id=g.organization_id and m.team_id in(g.primary_team_id,g.opponent_team_id) and m.status='active' and m.created_at<=p_event.occurred_at and m.starts_at<=p_event.occurred_at and(m.ends_at is null or m.ends_at>now())
 and r.authority_status='active' and r.created_at<=p_event.occurred_at and r.verified_at<=p_event.occurred_at and r.starts_at<=p_event.occurred_at and(r.ends_at is null or r.ends_at>now()) and(p_after is null or r.guardian_person_id>p_after)
 order by r.guardian_person_id limit greatest(1,least(p_limit,100)))
 union(select distinct a.person_id from public.game_operator_assignments a where a.game_id=g.id and a.status='active' and a.created_at<=p_event.occurred_at and a.starts_at<=p_event.occurred_at and a.ends_at>now() and(p_after is null or a.person_id>p_after)
 order by a.person_id limit greatest(1,least(p_limit,100)))
 )candidate order by candidate.person_id limit greatest(1,least(p_limit,100));
end $$;
alter function boss_private.notification_contexts(public.notification_events,uuid) rename to notification_contexts_phase4b;
create function boss_private.notification_contexts(p_event public.notification_events,p_person uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare g public.games;result jsonb;begin
 if p_event.source_type<>'game_operation' then return boss_private.notification_contexts_phase4b(p_event,p_person);end if;
 select gg.* into g from public.games gg join public.game_operations o on o.game_id=gg.id where o.id=p_event.source_id and gg.organization_id=p_event.organization_id;
 if g.id is null or not boss_private.games_notification_visible(p_event,p_person) then return '[]';end if;
 select coalesce(jsonb_agg(jsonb_build_object('team_id',t.id)),'[]') into result from public.teams t where t.id in(g.primary_team_id,g.opponent_team_id)
 and(boss_private.games_team_related(p_person,g.organization_id,t.id) or boss_private.games_role_permission(p_person,'games.view',g.organization_id,t.id));
 return jsonb_build_array(jsonb_build_object('source_type','game_operation','source_id',p_event.source_id))||result;
end $$;
alter function boss_private.notification_destination(public.notification_events) rename to notification_destination_phase4b;
create function boss_private.notification_destination(p_event public.notification_events) returns text language plpgsql stable security definer set search_path='' as $$
declare gid uuid;begin
 if p_event.source_type<>'game_operation' then return boss_private.notification_destination_phase4b(p_event);end if;
 select game_id into gid from public.game_operations where id=p_event.source_id and organization_id=p_event.organization_id;
 if gid is null then return null;end if;return '/app/games?org='||p_event.organization_id||'&game='||gid;
end $$;
create function boss_private.games_notification_ingest() returns trigger language plpgsql security definer set search_path='' as $$
declare g public.games;typ text;begin
 if new.operation='game.start' then typ:='game.started';
 elsif new.operation='game.finalize' then typ:='game.final';
 elsif new.operation='game.operator.assign' then typ:='game.operator_assigned';
 elsif new.operation in('game.transition','game.calendar.sync') and new.next_state->>'status'='canceled' and new.prior_state->>'status' is distinct from 'canceled' then typ:='game.canceled';
 elsif new.operation in('game.transition','game.calendar.sync') and new.next_state->>'status' in('delayed','postponed','suspended') and new.prior_state->>'status' is distinct from new.next_state->>'status' then typ:='game.delayed';end if;
 if typ is null then return new;end if;
 select * into g from public.games where id=new.game_id;
 perform boss_private.notification_enqueue('sports','game_operation',new.id,new.organization_id,typ,new.sequence::text,jsonb_build_object('team_id',g.primary_team_id,'source_version',new.version));
 -- Expansion/delivery remains the existing bounded Notifications processor.
 -- No synchronous high-volume game-day delivery loop is introduced.
 return new;
end $$;
create trigger game_notification_source after insert on public.game_operations for each row execute function boss_private.games_notification_ingest();
revoke all on function boss_private.games_notification_visible(public.notification_events,uuid),boss_private.games_notification_ingest(),
 boss_private.notification_source_visible_phase4b(public.notification_events,uuid),boss_private.notification_source_visible(public.notification_events,uuid),
 boss_private.notification_candidates_phase4b(public.notification_events,uuid,integer),boss_private.notification_candidates(public.notification_events,uuid,integer),
 boss_private.notification_contexts_phase4b(public.notification_events,uuid),boss_private.notification_contexts(public.notification_events,uuid),
 boss_private.notification_destination_phase4b(public.notification_events),boss_private.notification_destination(public.notification_events)
 from public,anon,authenticated,service_role;
