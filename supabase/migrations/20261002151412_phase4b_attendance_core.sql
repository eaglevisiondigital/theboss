-- Phase 4B attendance is an optional Calendar capability. Raw rows remain closed.
alter table public.guardian_relationships add column can_respond_attendance boolean not null default false;
create table public.event_attendance_settings (
 organization_id uuid not null,event_id uuid primary key,response_deadline_at timestamptz,deadline_offset_minutes integer,
 deadline_policy text not null default 'lock' check(deadline_policy in ('lock','allow_late')),
 change_policy text not null default 'needs_reconfirmation' check(change_policy in ('keep','needs_reconfirmation')),
 audience text[] not null default array['participants','staff']::text[],version bigint not null default 1 check(version>0),
 updated_by_person_id uuid not null references public.people(id),updated_at timestamptz not null default now(),
 foreign key(organization_id,event_id) references public.events(organization_id,id),
 check(response_deadline_at is null or isfinite(response_deadline_at)),check(deadline_offset_minutes is null or deadline_offset_minutes between 0 and 44640),
 check(response_deadline_at is null or deadline_offset_minutes is null),
 check(cardinality(audience) between 1 and 2 and array_position(audience,null) is null and audience <@ array['participants','staff']::text[]));
create table public.attendance_responses (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,event_id uuid not null,occurrence_key text not null,
 person_id uuid not null references public.people(id),participant_id uuid,subject_kind text not null check(subject_kind in ('participant','staff')),
 occurrence_mode text not null check(occurrence_mode in ('single','recurring','retired')),
 status text not null check(status in ('attending','not_attending','maybe','pending','unknown')),
 responder_person_id uuid not null references public.people(id),guardian_relationship_id uuid references public.guardian_relationships(id),household_id uuid references public.households(id),
 reason text check(length(reason)<=500),note text check(length(note)<=1000),arrival_difference_minutes integer,departure_difference_minutes integer,
 context_fingerprint text not null check(context_fingerprint~'^[0-9a-f]{64}$'),needs_reconfirmation boolean not null default false,is_late boolean not null default false,
 version bigint not null default 1 check(version>0),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(organization_id,id),unique(event_id,occurrence_key,person_id,subject_kind),
 foreign key(organization_id,event_id) references public.events(organization_id,id),foreign key(participant_id,person_id) references public.participants(id,person_id),
 check((subject_kind='participant')=(participant_id is not null)),
 check(occurrence_key~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$'),
 check(arrival_difference_minutes is null or arrival_difference_minutes between -10080 and 10080),check(departure_difference_minutes is null or departure_difference_minutes between -10080 and 10080));
create table public.attendance_response_history (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,response_id uuid not null,version bigint not null,
 event_id uuid not null,occurrence_key text not null,person_id uuid not null references public.people(id),subject_kind text not null,
 actor_person_id uuid references public.people(id),request_id uuid,change_kind text not null check(change_kind in ('response','context_changed')),
 snapshot jsonb not null,created_at timestamptz not null default now(),unique(response_id,version),
 foreign key(organization_id,response_id) references public.attendance_responses(organization_id,id),
 foreign key(organization_id,event_id) references public.events(organization_id,id),check(jsonb_typeof(snapshot)='object'));
create table public.attendance_checkins (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,event_id uuid not null,occurrence_key text not null,
 person_id uuid not null references public.people(id),participant_id uuid,subject_kind text not null check(subject_kind in ('participant','staff')),
 occurrence_mode text not null check(occurrence_mode in ('single','recurring','retired')),
 state text not null check(state in ('expected','checked_in','absent','late','excused')),
 actor_person_id uuid not null references public.people(id),version bigint not null default 1 check(version>0),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(organization_id,id),unique(event_id,occurrence_key,person_id,subject_kind),foreign key(organization_id,event_id) references public.events(organization_id,id),
 foreign key(participant_id,person_id) references public.participants(id,person_id),check((subject_kind='participant')=(participant_id is not null)),
 check(occurrence_key~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$'));
create table public.attendance_checkin_history (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,checkin_id uuid not null,version bigint not null,
 actor_person_id uuid not null references public.people(id),request_id uuid not null,state text not null,created_at timestamptz not null default now(),
 unique(checkin_id,version),foreign key(organization_id,checkin_id) references public.attendance_checkins(organization_id,id));
create table public.attendance_requests (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,event_id uuid not null,occurrence_key text not null,
 kind text not null check(kind in ('requested','deadline','no_response','context_changed')),context_fingerprint text not null,revision text not null,
 created_at timestamptz not null default now(),unique(event_id,occurrence_key,kind,revision),unique(organization_id,id),
 foreign key(organization_id,event_id) references public.events(organization_id,id),check(length(revision) between 1 and 200),
 check(occurrence_key~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$'));
create table boss_private.attendance_operation_receipts (
 actor_person_id uuid not null references public.people(id),request_id uuid not null,input_hash bytea not null,command jsonb not null,result jsonb not null,
 created_at timestamptz not null default now(),primary key(actor_person_id,request_id));
create index attendance_settings_organization_idx on public.event_attendance_settings(organization_id,event_id);
create index attendance_settings_actor_idx on public.event_attendance_settings(updated_by_person_id);
create index attendance_response_person_idx on public.attendance_responses(person_id,event_id,occurrence_key);
create index attendance_response_tenant_event_idx on public.attendance_responses(organization_id,event_id,occurrence_key);
create index attendance_response_participant_idx on public.attendance_responses(participant_id,person_id);
create index attendance_response_responder_idx on public.attendance_responses(responder_person_id);
create index attendance_response_guardian_idx on public.attendance_responses(guardian_relationship_id);
create index attendance_response_household_idx on public.attendance_responses(household_id);
create index attendance_history_tenant_event_idx on public.attendance_response_history(organization_id,event_id,created_at);
create index attendance_history_tenant_response_idx on public.attendance_response_history(organization_id,response_id,created_at);
create index attendance_history_person_idx on public.attendance_response_history(person_id);
create index attendance_history_actor_idx on public.attendance_response_history(actor_person_id);
create index attendance_checkin_tenant_idx on public.attendance_checkins(organization_id,event_id,occurrence_key);
create index attendance_checkin_person_idx on public.attendance_checkins(person_id);
create index attendance_checkin_participant_idx on public.attendance_checkins(participant_id,person_id);
create index attendance_checkin_actor_idx on public.attendance_checkins(actor_person_id);
create index attendance_checkin_history_tenant_idx on public.attendance_checkin_history(organization_id,checkin_id);
create index attendance_checkin_history_actor_idx on public.attendance_checkin_history(actor_person_id);
create index attendance_request_tenant_idx on public.attendance_requests(organization_id,event_id,created_at);
DO $$declare name text;begin foreach name in array array['event_attendance_settings','attendance_responses','attendance_response_history','attendance_checkins','attendance_checkin_history','attendance_requests'] loop
 execute format('alter table public.%I enable row level security',name);execute format('revoke all on public.%I from public,anon,authenticated,service_role',name);end loop;end $$;
alter table boss_private.attendance_operation_receipts enable row level security;
revoke all on boss_private.attendance_operation_receipts from public,anon,authenticated,service_role;
create trigger attendance_response_identity before update on public.attendance_responses for each row execute function boss_private.preserve_row_identity('id','organization_id','event_id','occurrence_key','person_id','participant_id','subject_kind','created_at');
create trigger attendance_checkin_identity before update on public.attendance_checkins for each row execute function boss_private.preserve_row_identity('id','organization_id','event_id','occurrence_key','person_id','participant_id','subject_kind','created_at');
create trigger attendance_history_immutable before update or delete on public.attendance_response_history for each row execute function boss_private.reject_audit_rewrite();
create trigger attendance_history_no_truncate before truncate on public.attendance_response_history execute function boss_private.reject_audit_rewrite();
create trigger attendance_checkin_history_immutable before update or delete on public.attendance_checkin_history for each row execute function boss_private.reject_audit_rewrite();
create trigger attendance_checkin_history_no_truncate before truncate on public.attendance_checkin_history execute function boss_private.reject_audit_rewrite();

-- Resolve the canonical finite original key, including moved exceptions. A UUID
-- or a syntactically valid timestamp never manufactures an occurrence.
create function boss_private.attendance_occurrence(p_event uuid,p_key text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare e public.events;ex public.event_occurrence_exceptions;anchor timestamptz;result jsonb;begin
 if p_key is null or p_key!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$' then return null;end if;
 select * into e from public.events where id=p_event;if not found then return null;end if;
 if e.recurrence is null then
 if p_key<>to_char(e.start_at at time zone e.timezone,'YYYY-MM-DD"T"HH24:MI:SS') and not exists(select 1 from public.attendance_responses response where response.event_id=e.id and response.occurrence_key=p_key and response.occurrence_mode='single') and not exists(select 1 from public.attendance_checkins checkin where checkin.event_id=e.id and checkin.occurrence_key=p_key and checkin.occurrence_mode='single') then return null;end if;
 select jsonb_build_object('occurrence_key',p_key,'start_at',x.start_at,'end_at',x.end_at,'status',x.status,'title',x.title) into result from boss_private.calendar_occurrences(e,e.start_at-interval '1 second',e.end_at+interval '1 second') x where x.occurrence_key=to_char(e.start_at at time zone e.timezone,'YYYY-MM-DD"T"HH24:MI:SS');
 return result;end if;
 anchor:=p_key::timestamp at time zone e.timezone;
 if anchor<e.start_at-interval '31 days' or anchor>e.start_at+interval '5 years 31 days' then return null;end if;
 select * into ex from public.event_occurrence_exceptions where event_id=e.id and occurrence_key=p_key and is_active;
 select jsonb_build_object('occurrence_key',x.occurrence_key,'start_at',x.start_at,'end_at',x.end_at,'status',x.status,'title',x.title)
 into result from boss_private.calendar_occurrences(e,least(anchor-interval '32 days',ex.override_start_at-interval '1 day'),greatest(anchor+interval '32 days',ex.override_end_at+interval '1 day')) x where x.occurrence_key=p_key;
 return result;
 exception when others then return null;
end $$;
create function boss_private.attendance_effective_key(p_event uuid,p_calendar_key text) returns text language sql stable security definer set search_path='' as $$
 select case when e.recurrence is null then coalesce((select original.occurrence_key from(select r.occurrence_key,r.created_at,r.id from public.attendance_responses r where r.event_id=e.id and r.occurrence_mode='single' union all select c.occurrence_key,c.created_at,c.id from public.attendance_checkins c where c.event_id=e.id and c.occurrence_mode='single')original order by original.created_at,original.id limit 1),p_calendar_key) else p_calendar_key end from public.events e where e.id=p_event
$$;
create function boss_private.attendance_context(p_event uuid,p_key text) returns text language sql stable security definer set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object('occurrence_key',p_key,'start_epoch',extract(epoch from (occurrence->>'start_at')::timestamptz),'end_epoch',extract(epoch from (occurrence->>'end_at')::timestamptz),'status',occurrence->>'status','timezone',e.timezone,'recurrence',e.recurrence,'venue_id',e.venue_id,'resource_id',e.resource_id)::text,'UTF8')),'hex')
 from public.events e cross join lateral (select boss_private.attendance_occurrence(e.id,p_key) occurrence) current_occurrence where e.id=p_event
$$;
create function boss_private.attendance_guardian(p_guardian uuid,p_dependent uuid,p_at timestamptz default now()) returns uuid language sql stable security definer set search_path='' as $$
 select g.id from public.guardian_relationships g where g.guardian_person_id=p_guardian and g.dependent_person_id=p_dependent
 and boss_private.comm_person_active(p_guardian) and boss_private.comm_person_active(p_dependent) and g.can_respond_attendance and g.authority_status='active'
 and g.created_at<=least(now(),p_at) and g.verified_at<=least(now(),p_at) and g.starts_at<=least(now(),p_at) and (g.ends_at is null or g.ends_at>now()) order by g.created_at,g.id limit 1
$$;
-- Subject eligibility is intrinsic current roster/context, independent of caller.
create function boss_private.attendance_subjects(p_event uuid,p_at timestamptz default now()) returns table(person_id uuid,participant_id uuid,subject_kind text)
language sql stable security definer set search_path='' as $$
 with event as (select e.* from public.events e where e.id=p_event and boss_private.attendance_feature(e.organization_id,'attendance')),
 roster as (
 select m.person_id,m.participant_id,case when m.participant_id is not null and m.membership_type='athlete' then 'participant' else 'staff' end subject_kind
 from event e join public.event_targets target on target.event_id=e.id join public.team_memberships m on m.organization_id=e.organization_id
 join public.teams team on team.id=m.team_id and team.organization_id=m.organization_id and team.status='active'
 join public.people p on p.id=m.person_id and p.status='active'
 left join public.participants a on a.id=m.participant_id and a.person_id=m.person_id
 where m.status='active' and m.created_at<=least(now(),p_at) and m.starts_at<=least(now(),p_at) and (m.ends_at is null or m.ends_at>now())
 and (team.parent_unit_id is null or exists(select 1 from public.organization_units u where u.id=team.parent_unit_id and u.organization_id=e.organization_id and u.status='active'))
 and ((target.target_type='team' and target.target_id=m.team_id) or (target.target_type='unit' and target.target_id=team.parent_unit_id) or (target.target_type='organization' and target.target_id=e.organization_id))
 and ((m.participant_id is not null and a.status='active' and m.membership_type='athlete') or (m.participant_id is null and m.membership_type in ('coach','head_coach','assistant_coach','staff','team_staff','volunteer')))
 union
 select m.person_id,a.id,'participant' from event e join public.event_targets target on target.event_id=e.id and target.target_type='organization' and target.target_id=e.organization_id
 join public.organization_memberships m on m.organization_id=e.organization_id join public.participants a on a.person_id=m.person_id and a.status='active' join public.people p on p.id=m.person_id and p.status='active'
 where m.status='active' and m.created_at<=least(now(),p_at) and m.starts_at<=least(now(),p_at) and (m.ends_at is null or m.ends_at>now())
 ) select distinct r.person_id,r.participant_id,r.subject_kind from roster r join event e on true left join public.event_attendance_settings settings on settings.event_id=e.id
 where (case when r.subject_kind='participant' then 'participants' else 'staff' end)=any(coalesce(settings.audience,array['participants','staff']::text[]))
$$;
create function boss_private.attendance_permission(p_actor uuid,p_key text,p_event uuid,p_all boolean default true) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.attendance_feature(e.organization_id,'attendance') and exists(select 1 from public.event_targets where event_id=e.id)
 and case when p_all then not exists(select 1 from public.event_targets target where target.event_id=e.id and not(
 boss_private.comm_permission(p_actor,p_key,e.organization_id,target.target_type,target.target_id)
 and (p_key not in ('attendance.manage','attendance.checkin') or target.target_type<>'team'
 or boss_private.comm_permission(p_actor,p_key,e.organization_id,'organization',e.organization_id)
 or exists(select 1 from public.teams team where team.id=target.target_id and team.parent_unit_id is not null and boss_private.comm_permission(p_actor,p_key,e.organization_id,'unit',team.parent_unit_id))
 or exists(select 1 from public.role_assignments ra join public.roles role on role.id=ra.role_id and role.status='active' join public.role_permissions role_permission on role_permission.role_id=role.id join public.permissions permission on permission.id=role_permission.permission_id and permission.status='active' and permission.key=p_key where ra.person_id=p_actor and ra.scope_type='team' and ra.scope_id=target.target_id and ra.organization_id=e.organization_id and ra.status='active' and ra.starts_at<=now() and (ra.ends_at is null or ra.ends_at>now())
 and ((role.key='head_coach' and boss_private.attendance_feature(e.organization_id,'head_coach_management')) or (role.key='assistant_coach' and boss_private.attendance_feature(e.organization_id,'assistant_coach_management')) or role.key='team_administrator')))))
 else exists(select 1 from public.event_targets target where target.event_id=e.id and boss_private.comm_permission(p_actor,p_key,e.organization_id,target.target_type,target.target_id)) end
 from public.events e where e.id=p_event),false)
$$;
create function boss_private.attendance_self_allowed(p_actor uuid,p_event uuid,p_kind text) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.notification_person_active(p_actor) and case when p_kind='staff' then true else
 boss_private.attendance_feature(e.organization_id,'participant_self_response') and (boss_private.attendance_configuration(e.organization_id)->>'minimum_self_response_age') is not null and exists(select 1 from public.people p where p.id=p_actor and p.date_of_birth is not null and p.date_of_birth<=current_date-make_interval(years=>greatest(18,(boss_private.attendance_configuration(e.organization_id)->>'minimum_self_response_age')::integer))) end
 from public.events e where e.id=p_event),false)
$$;
create function boss_private.attendance_subject_authority(p_actor uuid,p_event uuid,p_person uuid,p_participant uuid,p_kind text,p_action text,p_at timestamptz default now()) returns boolean
language sql stable security definer set search_path='' as $$
 select case when p_action='respond' then
 exists(select 1 from public.events e where e.id=p_event and boss_private.attendance_feature(e.organization_id,'rsvp') and e.rsvp_mode<>'not_required') and
 ((p_actor=p_person and boss_private.attendance_self_allowed(p_actor,p_event,p_kind))
 or (p_kind='participant' and exists(select 1 from public.events e where e.id=p_event and boss_private.attendance_feature(e.organization_id,'guardian_rsvp')) and boss_private.attendance_guardian(p_actor,p_person,p_at) is not null)
 or boss_private.attendance_permission(p_actor,'attendance.manage',p_event,true))
 when p_action='manage' then boss_private.attendance_permission(p_actor,'attendance.manage',p_event,true)
 when p_action='checkin' then exists(select 1 from public.events e where e.id=p_event and boss_private.attendance_feature(e.organization_id,'checkin')) and boss_private.attendance_permission(p_actor,'attendance.checkin',p_event,true)
 when p_action='view_private_notes' then (p_actor=p_person and boss_private.attendance_self_allowed(p_actor,p_event,p_kind))
 or (p_kind='participant' and exists(select 1 from public.events e where e.id=p_event and boss_private.attendance_feature(e.organization_id,'guardian_rsvp')) and boss_private.attendance_guardian(p_actor,p_person,p_at) is not null)
 or boss_private.attendance_permission(p_actor,'attendance.manage',p_event,true)
 when p_action='view' then (p_actor=p_person and boss_private.attendance_self_allowed(p_actor,p_event,p_kind))
 or (p_kind='participant' and exists(select 1 from public.events e where e.id=p_event and boss_private.attendance_feature(e.organization_id,'guardian_rsvp')) and boss_private.attendance_guardian(p_actor,p_person,p_at) is not null)
 or boss_private.attendance_permission(p_actor,'attendance.view',p_event,true)
 else false end
$$;
create function boss_private.attendance_can_subject(p_actor uuid,p_event uuid,p_person uuid,p_participant uuid,p_kind text,p_action text,p_at timestamptz default now()) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from boss_private.attendance_subjects(p_event,p_at) subject where subject.person_id=p_person and subject.participant_id is not distinct from p_participant and subject.subject_kind=p_kind)
 and boss_private.attendance_subject_authority(p_actor,p_event,p_person,p_participant,p_kind,p_action,p_at)
$$;
create function boss_private.attendance_deadline(p_event uuid,p_key text) returns timestamptz language sql stable security definer set search_path='' as $$
 select coalesce(settings.response_deadline_at,(boss_private.attendance_occurrence(e.id,p_key)->>'start_at')::timestamptz-make_interval(mins=>settings.deadline_offset_minutes))
 from public.events e left join public.event_attendance_settings settings on settings.event_id=e.id where e.id=p_event
$$;
-- Every material change retains the old response snapshot and marks an explicit,
-- sticky reconfirmation state. A change-back cannot silently revive an old RSVP.
create function boss_private.attendance_invalidate(p_event uuid,p_key text default null) returns void language plpgsql security definer set search_path='' as $$
declare r public.attendance_responses;begin
 if coalesce((select change_policy from public.event_attendance_settings where event_id=p_event),'needs_reconfirmation')='keep' then return;end if;
 for r in select * from public.attendance_responses where event_id=p_event and (p_key is null or occurrence_key=p_key) and not needs_reconfirmation and context_fingerprint is distinct from boss_private.attendance_context(p_event,occurrence_key) for update loop
 update public.attendance_responses set needs_reconfirmation=true,version=version+1,updated_at=now() where id=r.id;
 insert into public.attendance_response_history(organization_id,response_id,version,event_id,occurrence_key,person_id,subject_kind,actor_person_id,change_kind,snapshot)
 values(r.organization_id,r.id,r.version+1,r.event_id,r.occurrence_key,r.person_id,r.subject_kind,boss_private.current_person_id(),'context_changed',to_jsonb(r)||jsonb_build_object('needs_reconfirmation',true,'version',r.version+1,'effective_occurrence',boss_private.attendance_occurrence(p_event,r.occurrence_key)));
 end loop;
end $$;
create function boss_private.attendance_calendar_changed() returns trigger language plpgsql security definer set search_path='' as $$begin
 if TG_TABLE_NAME='events' then perform boss_private.attendance_invalidate(new.id);else perform boss_private.attendance_invalidate(new.event_id,new.occurrence_key);end if;return new;end $$;
create trigger attendance_event_material_changed after update on public.events for each row when (old.start_at is distinct from new.start_at or old.end_at is distinct from new.end_at or old.timezone is distinct from new.timezone or old.recurrence is distinct from new.recurrence or old.venue_id is distinct from new.venue_id or old.resource_id is distinct from new.resource_id or old.status is distinct from new.status) execute function boss_private.attendance_calendar_changed();
create trigger attendance_exception_material_changed after insert or update on public.event_occurrence_exceptions for each row execute function boss_private.attendance_calendar_changed();

create function boss_private.attendance_subject_permission(p_actor uuid,p_key text,p_event uuid,p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.events e join public.event_targets target on target.event_id=e.id where e.id=p_event
 and boss_private.attendance_feature(e.organization_id,'attendance') and boss_private.comm_permission(p_actor,p_key,e.organization_id,target.target_type,target.target_id)
 and (target.target_type='organization' or exists(select 1 from public.team_memberships m join public.teams team on team.id=m.team_id and team.organization_id=m.organization_id and team.status='active'
 where m.organization_id=e.organization_id and m.person_id=p_person and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())
 and ((target.target_type='team' and target.target_id=m.team_id) or (target.target_type='unit' and target.target_id=team.parent_unit_id)))))
$$;
create function boss_private.attendance_request_enqueue(p_event uuid,p_occurrence_key text,p_kind text,p_revision text) returns uuid
language plpgsql security definer set search_path='' as $$declare e public.events;source uuid;begin
 select * into e from public.events where id=p_event;
 if not found or not boss_private.attendance_feature(e.organization_id,'attendance_reminders') or not boss_private.attendance_feature(e.organization_id,'rsvp')
 or e.rsvp_mode='not_required' or boss_private.attendance_occurrence(e.id,p_occurrence_key) is null then return null;end if;
 insert into public.attendance_requests(organization_id,event_id,occurrence_key,kind,context_fingerprint,revision)
 values(e.organization_id,e.id,p_occurrence_key,p_kind,boss_private.attendance_context(e.id,p_occurrence_key),p_revision)
 on conflict(event_id,occurrence_key,kind,revision) do nothing returning id into source;
 if source is null then select id into source from public.attendance_requests where event_id=e.id and occurrence_key=p_occurrence_key and kind=p_kind and revision=p_revision;end if;
 return source;
end $$;
create function boss_private.attendance_notification_visible(p_source uuid,p_person uuid,p_at timestamptz) returns boolean
language plpgsql stable security definer set search_path='' as $$declare source public.attendance_requests;occ jsonb;subject record;r public.attendance_responses;begin
 select * into source from public.attendance_requests where id=p_source;if not found or not boss_private.notification_person_active(p_person)
 or not boss_private.attendance_feature(source.organization_id,'attendance_reminders') then return false;end if;
 occ:=boss_private.attendance_occurrence(source.event_id,source.occurrence_key);
 if occ is null or source.context_fingerprint<>boss_private.attendance_context(source.event_id,source.occurrence_key)
 or (source.kind<>'context_changed' and (occ->>'status' not in ('scheduled','confirmed') or (occ->>'end_at')::timestamptz<=now())) then return false;end if;
 for subject in select * from boss_private.attendance_subjects(source.event_id,least(source.created_at,p_at)) loop
 if not (p_person=subject.person_id or boss_private.attendance_guardian(p_person,subject.person_id,least(source.created_at,p_at)) is not null)
 or not boss_private.attendance_subject_authority(p_person,source.event_id,subject.person_id,subject.participant_id,subject.subject_kind,'respond',least(source.created_at,p_at)) then continue;end if;
 select * into r from public.attendance_responses where event_id=source.event_id and occurrence_key=source.occurrence_key and person_id=subject.person_id and subject_kind=subject.subject_kind;
 if source.kind='context_changed' then if r.id is not null then return true;end if;
 elsif source.kind='requested' then return true;
 elsif r.id is null or r.status in ('pending','unknown') or r.needs_reconfirmation then return true;end if;
 end loop;return false;
end $$;
create function boss_private.attendance_notification_candidates(p_source uuid,p_after uuid,p_limit integer) returns table(person_id uuid)
language sql stable security definer set search_path='' as $$
 select candidate.person_id from (
 select s.person_id from public.attendance_requests r cross join lateral boss_private.attendance_subjects(r.event_id,r.created_at) s where r.id=p_source
 union select g.guardian_person_id from public.attendance_requests r cross join lateral boss_private.attendance_subjects(r.event_id,r.created_at) s
 join public.guardian_relationships g on g.dependent_person_id=s.person_id where r.id=p_source and boss_private.attendance_guardian(g.guardian_person_id,s.person_id,r.created_at)=g.id
 ) candidate where (p_after is null or candidate.person_id>p_after) and boss_private.notification_person_active(candidate.person_id) order by candidate.person_id limit greatest(1,least(100,p_limit))
$$;
create function boss_private.attendance_notification_contexts(p_source uuid,p_person uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_array(jsonb_build_object('source_type','attendance_request','source_id',r.id,'event_id',r.event_id,'occurrence_key',r.occurrence_key))||coalesce((
 select jsonb_agg(jsonb_build_object('team_id',team_id) order by team_id) from (
 select distinct m.team_id from boss_private.attendance_subjects(r.event_id,r.created_at) s join public.team_memberships m on m.person_id=s.person_id and m.organization_id=r.organization_id
 join public.event_targets target on target.event_id=r.event_id join public.teams team on team.id=m.team_id and team.organization_id=r.organization_id and team.status='active'
 where m.status='active' and m.starts_at<=r.created_at and m.created_at<=r.created_at and (m.ends_at is null or m.ends_at>now())
 and ((target.target_type='team' and target.target_id=m.team_id) or (target.target_type='unit' and target.target_id=team.parent_unit_id) or target.target_type='organization')
 and (s.person_id=p_person or boss_private.attendance_guardian(p_person,s.person_id,r.created_at) is not null)
 ) contexts),'[]'::jsonb) from public.attendance_requests r where r.id=p_source and boss_private.attendance_notification_visible(p_source,p_person,r.created_at)
$$;
create or replace function boss_private.attendance_calendar_changed() returns trigger language plpgsql security definer set search_path='' as $$declare e uuid;k text;revision text;begin
 if TG_TABLE_NAME='events' then e:=new.id;
 if (old.recurrence is null)<>(new.recurrence is null) then
 update public.attendance_responses set occurrence_mode='retired' where event_id=e and occurrence_mode<>'retired';
 update public.attendance_checkins set occurrence_mode='retired' where event_id=e and occurrence_mode<>'retired';
 end if;perform boss_private.attendance_invalidate(e);else e:=new.event_id;perform boss_private.attendance_invalidate(e,new.occurrence_key);end if;
 for k in select distinct occurrence_key from public.attendance_responses where event_id=e and needs_reconfirmation and (TG_TABLE_NAME='events' or occurrence_key=case when TG_TABLE_NAME='events' then null else to_jsonb(new)->>'occurrence_key' end) loop
 revision:=(select version::text from public.events where id=e)||':'||boss_private.attendance_context(e,k);
 perform boss_private.attendance_request_enqueue(e,k,'context_changed',revision);
 end loop;return new;
end $$;

create function boss_private.attendance_validate(i jsonb,allowed text[],required text[] default '{}') returns void language plpgsql immutable set search_path='' as $$declare k text;v jsonb;begin
 if jsonb_typeof(i) is distinct from 'object' then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 for k,v in select key,value from jsonb_each(i) loop
 if not k=any(allowed) or (v='null'::jsonb and (k=any(required) or k not in ('participant_id','reason','note','arrival_difference_minutes','departure_difference_minutes','response_deadline_at','deadline_offset_minutes'))) then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 if v='null'::jsonb then continue;end if;
 if k like '%_id' then if jsonb_typeof(v)<>'string' or v#>>'{}'!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 elsif k in ('expected_version','arrival_difference_minutes','departure_difference_minutes','deadline_offset_minutes') then if jsonb_typeof(v)<>'number' or v#>>'{}'!~'^-?[0-9]{1,10}$' then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 elsif k='override_deadline' then if jsonb_typeof(v)<>'boolean' then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 elsif k in ('configuration','input') then if jsonb_typeof(v)<>'object' then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 elsif k='audience' then if jsonb_typeof(v)<>'array' then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 else if jsonb_typeof(v)<>'string' or length(v#>>'{}')>1000 or regexp_replace(v#>>'{}',E'[\t\n\r]','','g')~'[[:cntrl:]]' then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 if k in ('from','to','response_deadline_at') and (v#>>'{}'!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-][0-9]{2}:[0-9]{2})$' or not isfinite((v#>>'{}')::timestamptz)) then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 end if;end loop;
 foreach k in array required loop if not i?k or i->k='null'::jsonb then raise exception 'Invalid attendance request' using errcode='PT422';end if;end loop;
end $$;
create function boss_private.attendance_command(p_command jsonb,p_actor uuid,p_request uuid,p_apply boolean default true) returns jsonb
language plpgsql security definer set search_path='' as $$
declare op text;i jsonb;org uuid;e public.events;occ jsonb;person uuid;participant uuid;kind text;v_status text;expected bigint;v_id uuid;v_version bigint;deadline timestamptz;late boolean;override_late boolean;guardian uuid;household uuid;r public.attendance_responses;c public.attendance_checkins;s public.event_attendance_settings;v_conf jsonb;k text;v jsonb;module_assignment_id uuid;start_range timestamptz;end_range timestamptz;x record;prepared integer:=0;changed_keys text[];begin
 perform boss_private.attendance_validate(p_command,array['operation','input'],array['operation','input']);op:=p_command->>'operation';i:=p_command->'input';
 if op='attendance.configure' then
 perform boss_private.attendance_validate(i,array['organization_id','configuration'],array['organization_id','configuration']);org:=(i->>'organization_id')::uuid;
 if not boss_private.calendar_module_enabled(org) or not boss_private.has_permission('organization.manage',org) then raise exception 'Access denied' using errcode='PT403';end if;
 v_conf:='{}';for k,v in select key,value from jsonb_each(i->'configuration') loop
 if boss_private.attendance_storage_key(k) is null then raise exception 'Invalid attendance policy' using errcode='PT422';end if;
 if k='minimum_self_response_age' then if jsonb_typeof(v)<>'number' or v#>>'{}'!~'^[0-9]{2,3}$' or (v#>>'{}')::int not between 18 and 100 then raise exception 'Invalid attendance policy' using errcode='PT422';end if;
 elsif jsonb_typeof(v)<>'boolean' then raise exception 'Invalid attendance policy' using errcode='PT422';end if;
 v_conf:=v_conf||jsonb_build_object(boss_private.attendance_storage_key(k),v);end loop;
 if p_apply then select om.id into module_assignment_id from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id=org and m.key='calendar' and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()) order by om.starts_at desc limit 1 for update of om;
 update public.organization_modules set configuration=coalesce(configuration,'{}')||v_conf where id=module_assignment_id;end if;v_id:=org;v_version:=1;
 elsif op='reminders.prepare' then
 perform boss_private.attendance_validate(i,array['organization_id','from','to','kind'],array['organization_id','from','to','kind']);org:=(i->>'organization_id')::uuid;start_range:=(i->>'from')::timestamptz;end_range:=(i->>'to')::timestamptz;
 if end_range<=start_range or end_range-start_range>interval '93 days' or i->>'kind' not in ('requested','deadline','no_response') then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 if not boss_private.attendance_feature(org,'attendance_reminders') or not boss_private.comm_permission(p_actor,'attendance.manage',org,'organization',org) then raise exception 'Access denied' using errcode='PT403';end if;
 for e in select * from public.events where organization_id=org and rsvp_mode<>'not_required' and status in ('scheduled','confirmed') and (start_at<end_range or exists(select 1 from public.event_occurrence_exceptions where event_id=events.id and is_active and override_start_at<end_range)) and (coalesce(recurrence_end_at,end_at)>start_range or exists(select 1 from public.event_occurrence_exceptions where event_id=events.id and is_active and override_end_at>start_range)) order by id loop
 if not boss_private.attendance_permission(p_actor,'attendance.manage',e.id,true) then continue;end if;
 for x in select * from boss_private.calendar_occurrences(e,start_range,end_range) where status in ('scheduled','confirmed') and end_at>now() loop
 if i->>'kind'='deadline' and (boss_private.attendance_deadline(e.id,x.occurrence_key)>now() and boss_private.attendance_deadline(e.id,x.occurrence_key)<=now()+interval '1 day') is not true then continue;end if;
 if i->>'kind'='no_response' and (boss_private.attendance_deadline(e.id,x.occurrence_key) is null or boss_private.attendance_deadline(e.id,x.occurrence_key)>now()) then continue;end if;
 prepared:=prepared+1;if prepared>1000 then raise exception 'Attendance review exceeds safe limit' using errcode='PT409';end if;
 if p_apply then perform boss_private.attendance_request_enqueue(e.id,boss_private.attendance_effective_key(e.id,x.occurrence_key),i->>'kind',coalesce((select version::text from public.event_attendance_settings where event_id=e.id),'0')||':'||boss_private.attendance_context(e.id,boss_private.attendance_effective_key(e.id,x.occurrence_key)));end if;
 end loop;end loop;v_id:=org;v_version:=1;
 else
 if op='event.configure' then perform boss_private.attendance_validate(i,array['event_id','expected_version','rsvp_mode','response_deadline_at','deadline_offset_minutes','deadline_policy','change_policy','audience'],array['event_id','expected_version','rsvp_mode','deadline_policy','change_policy','audience']);
 elsif op='response.set' then perform boss_private.attendance_validate(i,array['event_id','occurrence_key','person_id','participant_id','subject_kind','status','expected_version','reason','note','arrival_difference_minutes','departure_difference_minutes','override_deadline'],array['event_id','occurrence_key','person_id','subject_kind','status','expected_version']);
 elsif op='checkin.set' then perform boss_private.attendance_validate(i,array['event_id','occurrence_key','person_id','participant_id','subject_kind','state','expected_version'],array['event_id','occurrence_key','person_id','subject_kind','state','expected_version']);
 else raise exception 'Invalid attendance operation' using errcode='PT422';end if;
 select * into e from public.events where id=(i->>'event_id')::uuid for update;if not found or not boss_private.attendance_feature(e.organization_id,'attendance') then raise exception 'Access denied' using errcode='PT403';end if;org:=e.organization_id;expected:=(i->>'expected_version')::bigint;
 if expected<0 then raise exception 'Invalid attendance version' using errcode='PT422';end if;
 if op='event.configure' then
 if not boss_private.attendance_permission(p_actor,'attendance.manage',e.id,true) then raise exception 'Access denied' using errcode='PT403';end if;
 if i->>'rsvp_mode' not in ('not_required','optional','required') or i->>'deadline_policy' not in ('lock','allow_late') or i->>'change_policy' not in ('keep','needs_reconfirmation')
 or (i->>'response_deadline_at' is not null and i->>'deadline_offset_minutes' is not null) or (i->>'deadline_offset_minutes')::int not between 0 and 44640
 or jsonb_array_length(i->'audience') not between 1 and 2 or exists(select 1 from jsonb_array_elements(i->'audience') a where jsonb_typeof(a)<>'string' or a#>>'{}' not in ('participants','staff')) then raise exception 'Invalid attendance configuration' using errcode='PT422';end if;
 select * into s from public.event_attendance_settings where event_id=e.id for update;
 if p_apply then if expected<>coalesce(s.version,0) then raise exception 'Conflicting attendance operation' using errcode='PT409';end if;
 insert into public.event_attendance_settings(organization_id,event_id,response_deadline_at,deadline_offset_minutes,deadline_policy,change_policy,audience,updated_by_person_id)
 values(org,e.id,(i->>'response_deadline_at')::timestamptz,(i->>'deadline_offset_minutes')::int,i->>'deadline_policy',i->>'change_policy',array(select distinct a#>>'{}' from jsonb_array_elements(i->'audience') a),p_actor)
 on conflict(event_id) do update set response_deadline_at=excluded.response_deadline_at,deadline_offset_minutes=excluded.deadline_offset_minutes,deadline_policy=excluded.deadline_policy,change_policy=excluded.change_policy,audience=excluded.audience,updated_by_person_id=p_actor,version=event_attendance_settings.version+1,updated_at=now() returning event_id,version into v_id,v_version;
 update public.events set rsvp_mode=i->>'rsvp_mode',version=version+1,updated_by_person_id=p_actor,updated_at=now() where id=e.id and rsvp_mode is distinct from i->>'rsvp_mode';
 if i->>'rsvp_mode'<>'not_required' then
 for x in select * from boss_private.calendar_occurrences(e,now(),now()+interval '93 days') where status in ('scheduled','confirmed') loop
 prepared:=prepared+1;if prepared>1000 then raise exception 'Attendance review exceeds safe limit' using errcode='PT409';end if;
 perform boss_private.attendance_request_enqueue(e.id,boss_private.attendance_effective_key(e.id,x.occurrence_key),'requested',v_version::text||':'||boss_private.attendance_context(e.id,boss_private.attendance_effective_key(e.id,x.occurrence_key)));
 end loop;end if;
 end if;v_id:=e.id;v_version:=coalesce(v_version,s.version);
 else
 person:=(i->>'person_id')::uuid;participant:=(i->>'participant_id')::uuid;kind:=i->>'subject_kind';
 if kind not in ('participant','staff') or (kind='participant')<>(participant is not null) then raise exception 'Invalid attendance subject' using errcode='PT422';end if;
 if e.recurrence is null and i->>'occurrence_key' is distinct from boss_private.attendance_effective_key(e.id,to_char(e.start_at at time zone e.timezone,'YYYY-MM-DD"T"HH24:MI:SS')) then raise exception 'Access denied' using errcode='PT403';end if;
 occ:=boss_private.attendance_occurrence(e.id,i->>'occurrence_key');
 if occ is null or occ->>'status' not in ('scheduled','confirmed','completed') or (op='response.set' and (occ->>'status'='completed' or (occ->>'end_at')::timestamptz<=now())) then raise exception 'Access denied' using errcode='PT403';end if;
 if not boss_private.attendance_can_subject(p_actor,e.id,person,participant,kind,case when op='response.set' then 'respond' else 'checkin' end) then raise exception 'Access denied' using errcode='PT403';end if;
 if op='response.set' then
 v_status:=i->>'status';if v_status not in ('attending','not_attending','maybe','pending','unknown') or length(coalesce(i->>'reason',''))>500
 or (i->>'arrival_difference_minutes')::int not between -10080 and 10080 or (i->>'departure_difference_minutes')::int not between -10080 and 10080 then raise exception 'Invalid attendance response' using errcode='PT422';end if;
 deadline:=boss_private.attendance_deadline(e.id,i->>'occurrence_key');late:=deadline is not null and now()>deadline;override_late:=coalesce((i->>'override_deadline')::boolean,false);
 if override_late and not boss_private.attendance_permission(p_actor,'attendance.manage',e.id,true) then raise exception 'Access denied' using errcode='PT403';end if;
 if late and coalesce((select deadline_policy from public.event_attendance_settings where event_id=e.id),'lock')='lock' and not override_late then raise exception 'RSVP deadline has passed' using errcode='PT409';end if;
 select * into r from public.attendance_responses where event_id=e.id and occurrence_key=i->>'occurrence_key' and person_id=person and subject_kind=kind for update;
 if p_apply then if expected<>coalesce(r.version,0) then raise exception 'Conflicting attendance operation' using errcode='PT409';end if;
 guardian:=case when person<>p_actor then boss_private.attendance_guardian(p_actor,person) end;
 if guardian is not null then select a.household_id into household from public.household_memberships a join public.household_memberships b on b.household_id=a.household_id join public.households h on h.id=a.household_id and h.status='active' where a.person_id=p_actor and b.person_id=person and a.status='active' and b.status='active' and a.starts_at<=now() and b.starts_at<=now() and (a.ends_at is null or a.ends_at>now()) and (b.ends_at is null or b.ends_at>now()) order by a.household_id limit 1;end if;
 insert into public.attendance_responses(organization_id,event_id,occurrence_key,person_id,participant_id,subject_kind,occurrence_mode,status,responder_person_id,guardian_relationship_id,household_id,reason,note,arrival_difference_minutes,departure_difference_minutes,context_fingerprint,is_late)
 values(org,e.id,i->>'occurrence_key',person,participant,kind,case when e.recurrence is null then 'single' else 'recurring' end,v_status,p_actor,guardian,household,nullif(btrim(i->>'reason'),''),nullif(btrim(i->>'note'),''),(i->>'arrival_difference_minutes')::int,(i->>'departure_difference_minutes')::int,boss_private.attendance_context(e.id,i->>'occurrence_key'),late)
 on conflict(event_id,occurrence_key,person_id,subject_kind) do update set status=excluded.status,occurrence_mode=excluded.occurrence_mode,responder_person_id=p_actor,guardian_relationship_id=guardian,household_id=household,reason=excluded.reason,note=excluded.note,arrival_difference_minutes=excluded.arrival_difference_minutes,departure_difference_minutes=excluded.departure_difference_minutes,context_fingerprint=excluded.context_fingerprint,needs_reconfirmation=false,is_late=late,version=attendance_responses.version+1,updated_at=now() returning * into r;
 insert into public.attendance_response_history(organization_id,response_id,version,event_id,occurrence_key,person_id,subject_kind,actor_person_id,request_id,change_kind,snapshot) values(org,r.id,r.version,e.id,r.occurrence_key,person,kind,p_actor,p_request,'response',to_jsonb(r)||jsonb_build_object('effective_occurrence',occ,'event_targets',(select jsonb_agg(jsonb_build_object('target_type',target_type,'target_id',target_id) order by target_type,target_id) from public.event_targets where event_id=e.id)));end if;
 v_id:=r.id;v_version:=r.version;
 else
 v_status:=i->>'state';if v_status not in ('expected','checked_in','absent','late','excused') then raise exception 'Invalid check-in state' using errcode='PT422';end if;
 select * into c from public.attendance_checkins where event_id=e.id and occurrence_key=i->>'occurrence_key' and person_id=person and subject_kind=kind for update;
 if p_apply then if expected<>coalesce(c.version,0) then raise exception 'Conflicting attendance operation' using errcode='PT409';end if;
 insert into public.attendance_checkins(organization_id,event_id,occurrence_key,person_id,participant_id,subject_kind,occurrence_mode,state,actor_person_id) values(org,e.id,i->>'occurrence_key',person,participant,kind,case when e.recurrence is null then 'single' else 'recurring' end,v_status,p_actor)
 on conflict(event_id,occurrence_key,person_id,subject_kind) do update set state=excluded.state,occurrence_mode=excluded.occurrence_mode,actor_person_id=p_actor,version=attendance_checkins.version+1,updated_at=now() returning * into c;
 insert into public.attendance_checkin_history(organization_id,checkin_id,version,actor_person_id,request_id,state) values(org,c.id,c.version,p_actor,p_request,v_status);end if;v_id:=c.id;v_version:=c.version;
 end if;end if;
 end if;
 if p_apply then
 -- Audit contains safe resource/scope/version and override markers, never notes.
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
 values(org,p_actor,auth.uid(),'attendance.'||op,'attendance',v_id,'organization',org,p_request,jsonb_build_object('operation',op,'event_id',e.id,'person_id',person,'version',v_version,'is_late',late,'deadline_override',coalesce(override_late,false),'prepared',prepared));end if;
 return jsonb_build_object('operation',op,'resource_id',v_id,'resource_type',case when op='response.set' then 'attendance_response' when op='checkin.set' then 'attendance_checkin' else 'attendance_configuration' end,'version',v_version,'prepared',prepared);
end $$;
create function boss_private.attendance_mutate(p_command jsonb,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;hash bytea;receipt boss_private.attendance_operation_receipts;result jsonb;begin
 actor:=boss_private.require_admin_actor();if p_request_id is null or p_command is null or octet_length(p_command::text)>16384 then raise exception 'Invalid attendance request' using errcode='PT422';end if;
 perform pg_advisory_xact_lock(hashtextextended('attendance-request:'||actor||':'||p_request_id,0));hash:=sha256(convert_to(p_command::text,'UTF8'));
 select * into receipt from boss_private.attendance_operation_receipts where actor_person_id=actor and request_id=p_request_id;
 if found then if receipt.input_hash<>hash then raise exception 'Conflicting attendance operation' using errcode='PT409';end if;perform boss_private.attendance_command(receipt.command,actor,p_request_id,false);return receipt.result;end if;
 result:=boss_private.attendance_command(p_command,actor,p_request_id)||jsonb_build_object('request_id',p_request_id);
 insert into boss_private.attendance_operation_receipts(actor_person_id,request_id,input_hash,command,result) values(actor,p_request_id,hash,p_command,result);return result;
 exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' then raise;
 when unique_violation or serialization_failure or deadlock_detected then raise exception 'Conflicting attendance operation' using errcode='PT409';
 when others then raise exception 'Invalid attendance request' using errcode='PT422';end $$;

create function boss_private.attendance_organization_known(p_actor uuid,p_org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organizations o where o.id=p_org and o.status='active' and boss_private.calendar_module_enabled(o.id) and (
 boss_private.comm_permission(p_actor,'organization.manage',o.id,'organization',o.id)
 or (boss_private.attendance_feature(o.id,'attendance') and (
 boss_private.comm_permission(p_actor,'attendance.view',o.id,'organization',o.id)
 or exists(select 1 from public.teams team where team.organization_id=o.id and team.status='active' and boss_private.comm_permission(p_actor,'attendance.view',o.id,'team',team.id))
 or exists(select 1 from public.organization_units unit where unit.organization_id=o.id and unit.status='active' and boss_private.comm_permission(p_actor,'attendance.view',o.id,'unit',unit.id))
 or exists(select 1 from public.events e cross join lateral boss_private.attendance_subjects(e.id) subject where e.organization_id=o.id
 and (subject.person_id=p_actor or boss_private.attendance_guardian(p_actor,subject.person_id) is not null)
 and boss_private.attendance_subject_authority(p_actor,e.id,subject.person_id,subject.participant_id,subject.subject_kind,'view'))))))
$$;
-- Set-oriented scoped projection: one roster expansion per occurrence, no
-- household-authority fallback, and a hard overflow error instead of truncation.
create function boss_private.attendance_read(p_query jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;org uuid;view_name text;range_from timestamptz;range_to timestamptz;event_filter uuid;child_filter uuid;team_filter uuid;unit_filter uuid;organizations jsonb;children jsonb;teams jsonb;units jsonb;rows jsonb;history jsonb;selected_occurrence jsonb;count_rows integer;conf jsonb;configure boolean;options_limited boolean:=false;begin
 actor:=boss_private.require_admin_actor();perform boss_private.attendance_validate(p_query,array['organization_id','view','from','to','event_id','occurrence_key','team_id','unit_id','child_person_id']);
 org:=(p_query->>'organization_id')::uuid;view_name:=coalesce(p_query->>'view','family');event_filter:=(p_query->>'event_id')::uuid;child_filter:=(p_query->>'child_person_id')::uuid;team_filter:=(p_query->>'team_id')::uuid;unit_filter:=(p_query->>'unit_id')::uuid;
 if view_name not in ('family','staff','history') then raise exception 'Invalid attendance view' using errcode='PT422';end if;
 range_from:=coalesce((p_query->>'from')::timestamptz,date_trunc('day',now()));range_to:=coalesce((p_query->>'to')::timestamptz,range_from+interval '31 days');
 if range_to<=range_from or range_to-range_from>interval '93 days' then raise exception 'Invalid attendance range' using errcode='PT422';end if;
 if p_query?'occurrence_key' and (event_filter is null or p_query->>'occurrence_key'!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$') then raise exception 'Invalid attendance occurrence' using errcode='PT422';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name) order by name,id),'[]') into organizations from (
 select o.id,o.name from public.organizations o where boss_private.attendance_organization_known(actor,o.id) order by o.name,o.id limit 101) options;
 if jsonb_array_length(organizations)>100 then
 options_limited:=true;select coalesce(jsonb_agg(value order by ordinal),'[]') into organizations from jsonb_array_elements(organizations) with ordinality option(value,ordinal) where ordinal<=100;
 end if;
 if org is null then org:=(organizations->0->>'id')::uuid;end if;
 if org is not null then
 if not boss_private.attendance_organization_known(actor,org) then raise exception 'Access denied' using errcode='PT403';end if;
 if not exists(select 1 from jsonb_array_elements(organizations) o where o->>'id'=org::text) then
 organizations:=organizations||(select jsonb_build_array(jsonb_build_object('id',o.id,'label',o.name)) from public.organizations o where o.id=org);
 end if;end if;
 configure:=org is not null and boss_private.calendar_module_enabled(org) and boss_private.has_permission('organization.manage',org);conf:=boss_private.attendance_configuration(org);
 if (team_filter is not null and not exists(select 1 from public.teams team where team.id=team_filter and team.organization_id=org and team.status='active'))
 or (unit_filter is not null and not exists(select 1 from public.organization_units u where u.id=unit_filter and u.organization_id=org and u.status='active')) then raise exception 'Access denied' using errcode='PT403';end if;
 select coalesce(jsonb_agg(jsonb_build_object('person_id',p.id,'participant_id',a.id,'display_name',coalesce(p.display_name,p.preferred_name,p.first_name,'Participant')) order by p.id),'[]') into children
 from (select distinct g.dependent_person_id from public.guardian_relationships g where g.guardian_person_id=actor and g.can_respond_attendance and g.authority_status='active' and g.verified_at<=now() and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now())) current_guardians join public.people p on p.id=current_guardians.dependent_person_id join public.participants a on a.person_id=p.id and a.status='active' where p.status='active' and boss_private.attendance_feature(org,'guardian_rsvp') and boss_private.comm_person_active(actor)
 and exists(select 1 from public.events e cross join lateral boss_private.attendance_subjects(e.id) subject where e.organization_id=org and subject.person_id=p.id and subject.subject_kind='participant');
 if child_filter is not null and not exists(select 1 from jsonb_array_elements(children) child where child->>'person_id'=child_filter::text) and child_filter<>actor then raise exception 'Access denied' using errcode='PT403';end if;
 if event_filter is not null and not exists(select 1 from public.events e where e.id=event_filter and e.organization_id=org and boss_private.attendance_feature(org,'attendance')
 and (boss_private.attendance_permission(actor,'attendance.view',e.id,false) or exists(select 1 from boss_private.attendance_subjects(e.id) subject where (subject.person_id=actor or boss_private.attendance_guardian(actor,subject.person_id) is not null) and boss_private.attendance_subject_authority(actor,e.id,subject.person_id,subject.participant_id,subject.subject_kind,'view')))) then raise exception 'Access denied' using errcode='PT403';end if;
 if event_filter is not null and p_query?'occurrence_key' and not p_query?'from' and not p_query?'to' and view_name<>'history' then
 selected_occurrence:=boss_private.attendance_occurrence(event_filter,p_query->>'occurrence_key');
 if selected_occurrence is null then raise exception 'Access denied' using errcode='PT403';end if;
 range_from:=(selected_occurrence->>'start_at')::timestamptz-interval '1 day';range_to:=(selected_occurrence->>'end_at')::timestamptz+interval '1 day';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name) order by name,id),'[]') into teams from (
 select team.id,team.name from public.teams team where team.organization_id=org and team.status='active' and boss_private.attendance_feature(org,'attendance')
 and (team.parent_unit_id is null or exists(select 1 from public.organization_units u where u.id=team.parent_unit_id and u.organization_id=org and u.status='active'))
 and (boss_private.comm_permission(actor,'attendance.view',org,'team',team.id)
 or exists(select 1 from public.events e join public.event_targets target on target.event_id=e.id cross join lateral boss_private.attendance_subjects(e.id) subject
 join public.team_memberships membership on membership.person_id=subject.person_id and membership.team_id=team.id and membership.organization_id=org and membership.status='active' and membership.starts_at<=now() and (membership.ends_at is null or membership.ends_at>now())
 where e.organization_id=org and ((target.target_type='team' and target.target_id=team.id) or(target.target_type='unit' and target.target_id=team.parent_unit_id) or target.target_type='organization')
 and (subject.person_id=actor or boss_private.attendance_guardian(actor,subject.person_id) is not null) and boss_private.attendance_subject_authority(actor,e.id,subject.person_id,subject.participant_id,subject.subject_kind,'view')))
 order by team.name,team.id limit 201) options;
 if jsonb_array_length(teams)>200 then raise exception 'Attendance team review exceeds safe limit' using errcode='PT409';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name) order by name,id),'[]') into units from (
 select unit.id,unit.name from public.organization_units unit where unit.organization_id=org and unit.status='active' and boss_private.attendance_feature(org,'attendance')
 and (boss_private.comm_permission(actor,'attendance.view',org,'unit',unit.id) or exists(select 1 from public.teams team join jsonb_array_elements(teams) option on option->>'id'=team.id::text where team.parent_unit_id=unit.id and team.organization_id=org))
 order by unit.name,unit.id limit 101) options;
 if jsonb_array_length(units)>100 then raise exception 'Attendance unit review exceeds safe limit' using errcode='PT409';end if;
 if view_name='history' then
 if event_filter is null or not boss_private.attendance_permission(actor,'attendance.view',event_filter,true) then raise exception 'Access denied' using errcode='PT403';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',h.id,'response_id',h.response_id,'event_id',h.event_id,'occurrence_key',h.occurrence_key,'person_id',h.person_id,'subject_kind',h.subject_kind,'version',h.version,'change_kind',h.change_kind,'created_at',h.created_at,'status',h.snapshot->>'status','needs_reconfirmation',h.snapshot->'needs_reconfirmation','reason',case when boss_private.attendance_permission(actor,'attendance.manage',event_filter,true) then h.snapshot->'reason' end,'note',case when boss_private.attendance_permission(actor,'attendance.manage',event_filter,true) then h.snapshot->'note' end) order by h.created_at desc,h.id),'[]') into history
 from (select * from public.attendance_response_history where event_id=event_filter and organization_id=org and created_at>=range_from and created_at<range_to order by created_at desc,id limit 201) h;
 if jsonb_array_length(history)>200 then raise exception 'Attendance history review exceeds safe limit' using errcode='PT409';end if;
 rows:='[]';
 else
 with events as materialized (
 select e.* from public.events e where e.organization_id=org and boss_private.attendance_feature(org,'attendance') and (event_filter is null or e.id=event_filter)
 and e.status not in ('draft','canceled','postponed','archived') and (e.start_at<range_to or exists(select 1 from public.event_occurrence_exceptions ex where ex.event_id=e.id and ex.is_active and ex.override_start_at<range_to))
 and (coalesce(e.recurrence_end_at,e.end_at)>range_from or exists(select 1 from public.event_occurrence_exceptions ex where ex.event_id=e.id and ex.is_active and ex.override_end_at>range_from))
 and (team_filter is null or exists(select 1 from public.event_targets target where target.event_id=e.id and target.target_type='team' and target.target_id=team_filter))
 and (unit_filter is null or exists(select 1 from public.event_targets target where target.event_id=e.id and ((target.target_type='unit' and target.target_id=unit_filter) or (target.target_type='team' and exists(select 1 from public.teams team where team.id=target.target_id and team.parent_unit_id=unit_filter)))))
 ), visible as (
 select e.*,boss_private.attendance_effective_key(e.id,x.occurrence_key) as occurrence_key,x.start_at as occurrence_start,x.end_at as occurrence_end,x.status as occurrence_status,x.title as occurrence_title,
 boss_private.attendance_permission(actor,'attendance.manage',e.id,true) can_manage,boss_private.attendance_feature(org,'checkin') and boss_private.attendance_permission(actor,'attendance.checkin',e.id,true) can_checkin,
 coalesce(settings.version,0) settings_version,coalesce(settings.deadline_policy,'lock') deadline_policy,coalesce(settings.change_policy,'needs_reconfirmation') change_policy,settings.response_deadline_at,settings.deadline_offset_minutes,coalesce(settings.audience,array['participants','staff']::text[]) attendance_audience
 from events e cross join lateral boss_private.calendar_occurrences(e,range_from,range_to) x left join public.event_attendance_settings settings on settings.event_id=e.id
 where x.status in ('scheduled','confirmed','completed') and (p_query->>'occurrence_key' is null or boss_private.attendance_effective_key(e.id,x.occurrence_key)=p_query->>'occurrence_key')
 and (view_name<>'staff' or boss_private.attendance_permission(actor,'attendance.view',e.id,false))
 ), projected as (
 select v.*,subject_rows.rows,subject_rows.total,subject_rows.summary from visible v cross join lateral (
 select count(*) total,coalesce(jsonb_agg(payload order by subject_person),'[]') rows,
 jsonb_build_object('total',count(*),'attending',count(*) filter(where response_status='attending' and not reconfirm),'not_attending',count(*) filter(where response_status='not_attending' and not reconfirm),'maybe',count(*) filter(where response_status='maybe' and not reconfirm),'pending',count(*) filter(where response_status is null or response_status='pending'),'unknown',count(*) filter(where response_status='unknown'),'needs_reconfirmation',count(*) filter(where reconfirm)) summary
 from (
 select subject.person_id subject_person,response.status response_status,coalesce(response.needs_reconfirmation,false) reconfirm,
 jsonb_build_object('person_id',subject.person_id,'participant_id',subject.participant_id,'subject_kind',subject.subject_kind,'display_name',coalesce(person.display_name,person.preferred_name,person.first_name,'Person'),
 'response',case when response.id is null then null else jsonb_build_object('id',response.id,'status',response.status,'version',response.version,'needs_reconfirmation',response.needs_reconfirmation,'is_late',response.is_late,
 'reason',case when boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view_private_notes') then response.reason end,
 'note',case when boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view_private_notes') then response.note end,
 'arrival_difference_minutes',case when boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view_private_notes') then response.arrival_difference_minutes end,
 'departure_difference_minutes',case when boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view_private_notes') then response.departure_difference_minutes end) end,
 'checkin',case when checkin.id is null then null else jsonb_build_object('id',checkin.id,'state',checkin.state,'version',checkin.version) end,
 'capabilities',jsonb_build_object('respond',v.occurrence_status in ('scheduled','confirmed') and v.occurrence_end>now() and boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'respond') and (v.deadline_policy='allow_late' or boss_private.attendance_deadline(v.id,v.occurrence_key) is null or now()<=boss_private.attendance_deadline(v.id,v.occurrence_key)),'manage',v.can_manage,'checkin',v.can_checkin,'view_private_notes',boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view_private_notes'))) payload
 from boss_private.attendance_subjects(v.id) subject join public.people person on person.id=subject.person_id
 left join public.attendance_responses response on response.event_id=v.id and response.occurrence_key=v.occurrence_key and response.person_id=subject.person_id and response.subject_kind=subject.subject_kind
 left join public.attendance_checkins checkin on checkin.event_id=v.id and checkin.occurrence_key=v.occurrence_key and checkin.person_id=subject.person_id and checkin.subject_kind=subject.subject_kind
 where (child_filter is null or subject.person_id=child_filter) and case when view_name='staff' then boss_private.attendance_subject_permission(actor,'attendance.view',v.id,subject.person_id)
 else (subject.person_id=actor or boss_private.attendance_guardian(actor,subject.person_id) is not null) and boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view') end
 order by subject.person_id limit 1001) subjects
 ) subject_rows where (subject_rows.total>0 or v.can_manage)
 order by v.occurrence_start,v.id,v.occurrence_key limit 1001
 ) select count(*),coalesce(jsonb_agg(jsonb_build_object('event_id',id,'organization_id',organization_id,'title',occurrence_title,'timezone',timezone,'occurrence_key',occurrence_key,'start_at',occurrence_start,'end_at',occurrence_end,'status',occurrence_status,'rsvp_mode',rsvp_mode,
 'settings',jsonb_build_object('response_deadline_at',response_deadline_at,'effective_deadline_at',boss_private.attendance_deadline(id,occurrence_key),'deadline_offset_minutes',deadline_offset_minutes,'deadline_policy',deadline_policy,'change_policy',change_policy,'audience',attendance_audience,'version',settings_version),'summary',summary,'subjects',projected.rows,'capabilities',jsonb_build_object('manage',can_manage,'checkin',can_checkin,'view_summary',view_name='staff')) order by occurrence_start,id,occurrence_key),'[]') into count_rows,rows from projected;
 -- Both occurrence and roster pages are finite; inspect arrays after aggregation.
 if jsonb_array_length(rows)>1000 or exists(select 1 from jsonb_array_elements(rows) row where jsonb_array_length(row->'subjects')>1000) then raise exception 'Attendance review exceeds safe limit' using errcode='PT409';end if;
 history:='[]';end if;
 return jsonb_build_object('organization_id',org,'organizations',organizations,'options_limited',options_limited,'navigation_available',exists(select 1 from jsonb_array_elements(organizations) available where boss_private.attendance_feature((available->>'id')::uuid,'attendance')),'teams',teams,'units',units,'view',view_name,'range',jsonb_build_object('from',range_from,'to',range_to),'features',conf,'capabilities',jsonb_build_object('configure',configure),'children',children,'occurrences',rows,'history',history);
 exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' then raise;when others then raise exception 'Invalid attendance request' using errcode='PT422';end $$;
-- Only the two caller-bound entry points are granted to application sessions.
DO $$declare f record;begin for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'attendance_%' loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);end loop;end $$;
grant execute on function boss_private.attendance_read(jsonb),boss_private.attendance_mutate(jsonb,uuid) to authenticated;
create function public.boss_attendance_read(p_query jsonb) returns jsonb language sql security invoker set search_path='' as $$select boss_private.attendance_read(p_query)$$;
create function public.boss_attendance_mutate(p_command jsonb,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select boss_private.attendance_mutate(p_command,p_request_id)$$;
revoke all on function public.boss_attendance_read(jsonb),public.boss_attendance_mutate(jsonb,uuid) from public,anon,authenticated,service_role;
grant execute on function public.boss_attendance_read(jsonb),public.boss_attendance_mutate(jsonb,uuid) to authenticated;
