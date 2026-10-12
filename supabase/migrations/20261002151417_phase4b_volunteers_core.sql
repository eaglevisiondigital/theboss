-- Phase 4B volunteer coordination. Raw rows remain closed; caller-bound invoker
-- RPCs enter a private finite dispatcher. Capacity has one transactional anchor.
create table public.volunteer_role_definitions (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 name text not null,description text,status text not null default 'active',version integer not null default 1,
 created_by_person_id uuid not null references public.people(id) on delete restrict,updated_by_person_id uuid not null references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(organization_id,id),
 check(length(btrim(name)) between 1 and 120),check(description is null or length(description)<=1000),check(status in('active','inactive','archived')),check(version>0)
);
create index volunteer_roles_org_status_idx on public.volunteer_role_definitions(organization_id,status,name);
create index volunteer_roles_created_by_idx on public.volunteer_role_definitions(created_by_person_id);
create index volunteer_roles_updated_by_idx on public.volunteer_role_definitions(updated_by_person_id);
create table public.volunteer_shifts (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 role_id uuid not null,title text not null,scope_type text not null,scope_id uuid not null,
 organization_unit_id uuid generated always as(case when scope_type='unit' then scope_id end) stored,
 team_id uuid generated always as(case when scope_type='team' then scope_id end) stored,event_id uuid,occurrence_key text,event_context_stamp text,
 start_at timestamptz not null,end_at timestamptz not null,capacity integer not null,instructions text,location text,
 status text not null default 'draft',visibility text not null default 'members',signup_deadline timestamptz,reminder_minutes_before integer not null default 60,version integer not null default 1,
 created_by_person_id uuid not null references public.people(id) on delete restrict,updated_by_person_id uuid not null references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(organization_id,id),
 foreign key(organization_id,role_id) references public.volunteer_role_definitions(organization_id,id) on delete restrict,
 foreign key(organization_id,organization_unit_id) references public.organization_units(organization_id,id) on delete restrict,
 foreign key(organization_id,team_id) references public.teams(organization_id,id) on delete restrict,
 foreign key(organization_id,event_id) references public.events(organization_id,id) on delete restrict,
 check(length(btrim(title)) between 1 and 200),check(scope_type in('organization','unit','team')),check(scope_type<>'organization' or scope_id=organization_id),
 check((event_id is null)=(occurrence_key is null)),check((event_id is null)=(event_context_stamp is null)),check(occurrence_key is null or occurrence_key~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$'),
 check(isfinite(start_at) and isfinite(end_at) and end_at>start_at and end_at-start_at<=interval '31 days'),
 check(capacity between 1 and 10000),check(instructions is null or length(instructions)<=2000),check(location is null or length(location)<=300),
 check(status in('draft','open','closed','canceled','archived')),check(visibility in('members','staff')),
 check(signup_deadline is null or(isfinite(signup_deadline) and signup_deadline<=end_at)),check(reminder_minutes_before between 0 and 10080),check(version>0)
);
create index volunteer_shifts_upcoming_idx on public.volunteer_shifts(organization_id,start_at,id);
create index volunteer_shifts_team_upcoming_idx on public.volunteer_shifts(organization_id,team_id,start_at);
create index volunteer_shifts_unit_upcoming_idx on public.volunteer_shifts(organization_id,organization_unit_id,start_at);
create index volunteer_shifts_event_idx on public.volunteer_shifts(organization_id,event_id,occurrence_key);
create index volunteer_shifts_role_idx on public.volunteer_shifts(organization_id,role_id);
create index volunteer_shifts_created_by_idx on public.volunteer_shifts(created_by_person_id);
create index volunteer_shifts_updated_by_idx on public.volunteer_shifts(updated_by_person_id);
create table public.volunteer_assignments (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,shift_id uuid not null,
 person_id uuid not null references public.people(id) on delete restrict,status text not null default 'active',source text not null,
 assigned_by_person_id uuid not null references public.people(id) on delete restrict,canceled_by_person_id uuid references public.people(id) on delete restrict,
 canceled_at timestamptz,version integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 foreign key(organization_id,shift_id) references public.volunteer_shifts(organization_id,id) on delete restrict,
 unique(shift_id,person_id),unique(organization_id,id),check(status in('active','canceled')),check(source in('self','staff')),
 check((status='canceled')=(canceled_at is not null)),check(version>0)
);
create index volunteer_assignments_person_idx on public.volunteer_assignments(person_id,status,shift_id);
create index volunteer_assignments_capacity_idx on public.volunteer_assignments(shift_id,status);
create index volunteer_assignments_org_idx on public.volunteer_assignments(organization_id,shift_id);
create index volunteer_assignments_assigner_idx on public.volunteer_assignments(assigned_by_person_id);
create index volunteer_assignments_canceler_idx on public.volunteer_assignments(canceled_by_person_id);
create table public.volunteer_assignment_history (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,assignment_id uuid not null,
 actor_person_id uuid not null references public.people(id) on delete restrict,action text not null,prior_status text,status text not null,
 assignment_version integer not null,request_id uuid not null,created_at timestamptz not null default now(),
 foreign key(organization_id,assignment_id) references public.volunteer_assignments(organization_id,id) on delete restrict,
 unique(assignment_id,assignment_version),check(action in('signup','assign','cancel','reassign')),check(status in('active','canceled')),check(prior_status is null or prior_status in('active','canceled'))
);
create index volunteer_history_assignment_idx on public.volunteer_assignment_history(organization_id,assignment_id,created_at);
create index volunteer_history_actor_idx on public.volunteer_assignment_history(actor_person_id);
create table boss_private.volunteer_operation_receipts (
 actor_person_id uuid not null references public.people(id) on delete restrict,request_id uuid not null,input_hash bytea not null,
 command jsonb not null,result jsonb not null,created_at timestamptz not null default now(),primary key(actor_person_id,request_id)
);
alter table boss_private.volunteer_operation_receipts enable row level security;
revoke all on boss_private.volunteer_operation_receipts from public,anon,authenticated,service_role;
DO $$declare t text;begin foreach t in array array['volunteer_role_definitions','volunteer_shifts','volunteer_assignments','volunteer_assignment_history'] loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 execute format('create trigger %I before delete on public.%I for each row execute function boss_private.registration_reject_rewrite()',t||'_history_retain',t);
 end loop;end$$;

create function boss_private.volunteer_scope_active(p_org uuid,p_type text,p_scope uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organizations where id=p_org and status='active') and case
 when p_type='organization' then p_scope=p_org
 when p_type='unit' then exists(select 1 from public.organization_units where id=p_scope and organization_id=p_org and status='active')
 when p_type='team' then exists(select 1 from public.teams t where id=p_scope and organization_id=p_org and status='active' and(parent_unit_id is null or exists(select 1 from public.organization_units u where u.id=t.parent_unit_id and u.organization_id=p_org and u.status='active')))
 else false end $$;
create function boss_private.volunteer_guardian(p_guardian uuid,p_dependent uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.guardian_relationships g join public.people d on d.id=g.dependent_person_id where g.guardian_person_id=p_guardian and g.dependent_person_id=p_dependent
 and d.status='active' and g.authority_status='active' and g.verified_at<=now() and g.starts_at<=now() and(g.ends_at is null or g.ends_at>now())) $$;
create function boss_private.volunteer_team_related(p_person uuid,p_team uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.team_memberships m join public.people p on p.id=m.person_id left join public.participants a on a.id=m.participant_id and a.person_id=m.person_id
 where m.team_id=p_team and m.status='active' and m.starts_at<=now() and(m.ends_at is null or m.ends_at>now()) and p.status='active' and(m.participant_id is null or a.status='active')
 and(m.person_id=p_person or boss_private.volunteer_guardian(p_person,m.person_id))) $$;
create function boss_private.volunteer_person_related(p_person uuid,p_org uuid,p_type text,p_scope uuid) returns boolean language sql stable security definer set search_path='' as $$
 select boss_private.volunteer_scope_active(p_org,p_type,p_scope) and exists(select 1 from public.people where id=p_person and status='active') and case
 when p_type='team' then boss_private.volunteer_team_related(p_person,p_scope)
 when p_type='unit' then exists(select 1 from public.teams t where t.organization_id=p_org and t.parent_unit_id=p_scope and t.status='active' and boss_private.volunteer_team_related(p_person,t.id))
 when p_type='organization' then exists(select 1 from public.organization_memberships m join public.people d on d.id=m.person_id where m.organization_id=p_org and d.status='active' and m.status='active'
 and m.starts_at<=now() and(m.ends_at is null or m.ends_at>now()) and(m.person_id=p_person or boss_private.volunteer_guardian(p_person,m.person_id)))
 or exists(select 1 from public.teams t where t.organization_id=p_org and t.status='active' and boss_private.volunteer_team_related(p_person,t.id)) else false end $$;
create function boss_private.volunteer_permission(p_person uuid,p_key text,p_org uuid,p_type text,p_scope uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare u uuid;begin
 if p_key not in('volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign') or not boss_private.volunteer_feature(p_org,'volunteers')
 or not boss_private.volunteer_scope_active(p_org,p_type,p_scope) or not exists(select 1 from public.people where id=p_person and status='active') then return false;end if;
 if p_type='unit' then u:=p_scope;elsif p_type='team' then select parent_unit_id into u from public.teams where id=p_scope;end if;
 return exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id
 where a.person_id=p_person and a.status='active' and a.starts_at<=now() and(a.ends_at is null or a.ends_at>now()) and r.status='active' and p.status='active' and p.key=p_key
 and((a.scope_type='platform' and a.scope_id is null and a.organization_id is null) or(a.organization_id=p_org and((a.scope_type='organization' and a.scope_id=p_org)
 or(a.scope_type='organization_unit' and a.scope_id=u) or(a.scope_type='team' and p_type='team' and a.scope_id=p_scope
 and exists(select 1 from public.team_memberships tm where tm.organization_id=p_org and tm.team_id=p_scope and tm.person_id=p_person and tm.status='active' and tm.starts_at<=now() and(tm.ends_at is null or tm.ends_at>now()))))))
 and(r.key<>'head_coach' or p_key not in('volunteers.manage','volunteers.assign') or boss_private.volunteer_feature(p_org,'head_coach_management'))
 and(r.key not in('assistant_coach','team_staff') or p_key not in('volunteers.manage','volunteers.assign') or boss_private.volunteer_feature(p_org,'assistant_management')));
end $$;
create function boss_private.volunteer_person_eligible(p_person uuid,p_org uuid,p_type text,p_scope uuid) returns boolean language sql stable security definer set search_path='' as $$
 select boss_private.volunteer_person_related(p_person,p_org,p_type,p_scope) and exists(select 1 from public.people where id=p_person and status='active'
 and date_of_birth is not null and date_of_birth<=current_date-make_interval(years=>boss_private.volunteer_minimum_age(p_org))) $$;
create function boss_private.volunteer_event_current(p_org uuid,p_event uuid,p_key text,p_type text,p_scope uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare e public.events;o record;k timestamp;begin
 if p_event is null then return p_key is null;end if;
 select * into e from public.events where id=p_event and organization_id=p_org;
 if not found or e.status not in('scheduled','confirmed') or not boss_private.calendar_module_enabled(p_org) or not boss_private.calendar_feature(p_org,case when p_type='team' then 'team_calendar' else 'organization_calendar' end) or p_key is null or p_key!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$'
 or not exists(select 1 from public.event_targets where event_id=e.id and target_type=p_type and target_id=p_scope) then return false;end if;
 if e.recurrence is null then return p_key=to_char(e.start_at at time zone e.timezone,'YYYY-MM-DD"T"HH24:MI:SS') or exists(select 1 from public.volunteer_shifts vs where vs.organization_id=p_org and vs.event_id=e.id and vs.occurrence_key=p_key and vs.scope_type=p_type and vs.scope_id=p_scope);end if;
 k:=p_key::timestamp;
 if not exists(select 1 from boss_private.calendar_expand(e.start_at,e.end_at,e.timezone,e.recurrence,(k at time zone e.timezone)-interval '1 day',(k at time zone e.timezone)+interval '32 days') x where x.occurrence_key=p_key) then return false;end if;
 return not exists(select 1 from public.event_occurrence_exceptions x where x.event_id=e.id and x.occurrence_key=p_key and x.is_active and x.status in('canceled','postponed','completed','archived','draft'));
 exception when invalid_datetime_format or datetime_field_overflow then return false;end $$;
create function boss_private.volunteer_can_view_shift(p_shift uuid,p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.volunteer_feature(s.organization_id,'volunteers') and boss_private.volunteer_scope_active(s.organization_id,s.scope_type,s.scope_id) and(
 boss_private.volunteer_permission(p_person,'volunteers.view',s.organization_id,s.scope_type,s.scope_id)
 or(s.status<>'draft' and s.visibility='members' and boss_private.volunteer_person_eligible(p_person,s.organization_id,s.scope_type,s.scope_id))
 or exists(select 1 from public.volunteer_assignments a join public.people p on p.id=a.person_id where a.shift_id=s.id and a.person_id=p_person and p.status='active' and boss_private.volunteer_person_eligible(p_person,s.organization_id,s.scope_type,s.scope_id))) from public.volunteer_shifts s where s.id=p_shift),false) $$;
create function boss_private.volunteer_coordinator(p_shift uuid,p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.volunteer_permission(p_person,'volunteers.manage',s.organization_id,s.scope_type,s.scope_id) from public.volunteer_shifts s where s.id=p_shift),false) $$;
create function boss_private.volunteer_notification_recipient(p_shift uuid,p_person uuid,p_kind text) returns boolean language sql stable security definer set search_path='' as $$
 select p_kind=any(array['confirmation','changed','canceled','reminder','cancellation']) and coalesce((select boss_private.volunteer_can_view_shift(s.id,p_person)
 and boss_private.volunteer_person_eligible(p_person,s.organization_id,s.scope_type,s.scope_id)
 and(p_kind<>'reminder' or(boss_private.volunteer_feature(s.organization_id,'reminders') and s.status='open' and boss_private.volunteer_event_current(s.organization_id,s.event_id,s.occurrence_key,s.scope_type,s.scope_id)))
 and exists(select 1 from public.volunteer_assignments a where a.shift_id=s.id and a.person_id=p_person and(p_kind in('cancellation','canceled') or a.status='active')) from public.volunteer_shifts s where s.id=p_shift),false) $$;
create function boss_private.volunteer_event_stamp(p_event uuid,p_key text) returns text language plpgsql stable security definer set search_path='' as $$
declare e public.events;x public.event_occurrence_exceptions;o record;k timestamp;begin
 select * into e from public.events where id=p_event;if not found or p_key is null or p_key!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$' then return null;end if;k:=p_key::timestamp;
 if e.recurrence is null then
 if p_key<>to_char(e.start_at at time zone e.timezone,'YYYY-MM-DD"T"HH24:MI:SS') and not exists(select 1 from public.volunteer_shifts vs where vs.event_id=e.id and vs.occurrence_key=p_key) then return null;end if;
 return encode(sha256(convert_to(jsonb_build_object('start',to_char(e.start_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'end',to_char(e.end_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'status',e.status,'timezone',e.timezone,'venue',e.venue_id,'resource',e.resource_id)::text,'UTF8')),'hex');end if;
 select * into o from boss_private.calendar_expand(e.start_at,e.end_at,e.timezone,e.recurrence,(k at time zone e.timezone)-interval '1 day',(k at time zone e.timezone)+interval '32 days') where occurrence_key=p_key;
 if not found then return null;end if;select * into x from public.event_occurrence_exceptions where event_id=e.id and occurrence_key=p_key and is_active;
 return encode(sha256(convert_to(jsonb_build_object('start',to_char(coalesce(x.override_start_at,o.start_at) at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'end',to_char(coalesce(x.override_end_at,o.end_at) at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'status',case when e.status not in('scheduled','confirmed') then e.status else coalesce(x.status,e.status) end,'timezone',e.timezone,'venue',e.venue_id,'resource',e.resource_id)::text,'UTF8')),'hex');
 exception when invalid_datetime_format or datetime_field_overflow then return null;end $$;
create function boss_private.volunteer_can_signup(p_shift uuid,p_person uuid,p_self boolean default true) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.volunteer_feature(s.organization_id,'volunteers') and(not p_self or boss_private.volunteer_feature(s.organization_id,'self_signup'))
 and s.status='open' and(not p_self or s.visibility='members') and s.end_at>now() and(s.signup_deadline is null or s.signup_deadline>=now())
 and exists(select 1 from public.volunteer_role_definitions r where r.id=s.role_id and r.status='active')
 and boss_private.volunteer_person_eligible(p_person,s.organization_id,s.scope_type,s.scope_id)
 and boss_private.volunteer_event_current(s.organization_id,s.event_id,s.occurrence_key,s.scope_type,s.scope_id)
 and(s.event_id is null or s.event_context_stamp=boss_private.volunteer_event_stamp(s.event_id,s.occurrence_key)) from public.volunteer_shifts s where s.id=p_shift),false) $$;

create function boss_private.volunteer_validate(i jsonb,p_allowed text[],p_required text[] default '{}') returns void language plpgsql immutable set search_path='' as $$
declare k text;v jsonb;begin
 if jsonb_typeof(i) is distinct from 'object' then raise exception 'Invalid volunteer request.' using errcode='PT422';end if;
 for k,v in select key,value from jsonb_each(i) loop
 if not k=any(p_allowed) or(v='null'::jsonb and not k=any(array['description','event_id','occurrence_key','instructions','location','signup_deadline'])) then raise exception 'Invalid volunteer request.' using errcode='PT422';end if;
 if k in('expected_version','capacity','minimum_signup_age','reminder_minutes_before') and(jsonb_typeof(v)<>'number' or v::text!~'^[0-9]{1,8}$') then raise exception 'Invalid volunteer request.' using errcode='PT422';end if;
 if k not in('expected_version','capacity','configuration','input','minimum_signup_age','reminder_minutes_before') and v<>'null'::jsonb and jsonb_typeof(v)<>'string' then raise exception 'Invalid volunteer request.' using errcode='PT422';end if;
 end loop;foreach k in array p_required loop if not i?k or i->k='null'::jsonb then raise exception 'Invalid volunteer request.' using errcode='PT422';end if;end loop;
end $$;
create function boss_private.volunteer_history(p_assignment public.volunteer_assignments,p_actor uuid,p_action text,p_prior text,p_request uuid) returns void language sql security definer set search_path='' as $$
 insert into public.volunteer_assignment_history(organization_id,assignment_id,actor_person_id,action,prior_status,status,assignment_version,request_id)
 values(p_assignment.organization_id,p_assignment.id,p_actor,p_action,p_prior,p_assignment.status,p_assignment.version,p_request) $$;
create function boss_private.volunteer_audit(p_actor uuid,p_op text,p_resource uuid,p_org uuid,p_type text,p_scope uuid,p_request uuid,p_fields jsonb) returns void language sql security definer set search_path='' as $$
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
 values(p_org,p_actor,auth.uid(),case when p_op='volunteers.configure' then p_op else 'volunteers.'||p_op end,case when p_op like 'shift.%' then 'volunteer_shift' when p_op like 'assignment.%' then 'volunteer_assignment' when p_op like 'role.%' then 'volunteer_role' else 'volunteer_configuration' end,
 p_resource,case p_type when 'unit' then 'organization_unit' else p_type end,p_scope,p_request,p_fields) $$;
create function boss_private.volunteer_command(p_actor uuid,p_op text,i jsonb,p_request uuid,p_replay boolean default false,p_resource uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid;rid uuid:=coalesce(p_resource,gen_random_uuid());typ text;sid uuid;pid uuid;prior text;k text;cfg jsonb;v integer;filled integer;material boolean:=false;
 role_row public.volunteer_role_definitions;old_shift public.volunteer_shifts;s public.volunteer_shifts;a public.volunteer_assignments;b public.volunteer_assignments;
 e public.events;om public.organization_modules;fields jsonb:='{}';out jsonb:='{}';
begin
 if p_op='volunteers.configure' then
 perform boss_private.volunteer_validate(i,array['organization_id','configuration'],array['organization_id','configuration']);org:=(i->>'organization_id')::uuid;
 if not boss_private.volunteer_scope_active(org,'organization',org) or not boss_private.has_permission('volunteers.manage',org) then raise exception 'Access denied.' using errcode='PT403';end if;
 cfg:=i->'configuration';if jsonb_typeof(cfg)<>'object' or not exists(select 1 from jsonb_object_keys(cfg)) then raise exception 'Invalid volunteer policy.' using errcode='PT422';end if;
 for k in select jsonb_object_keys(cfg) loop
 if k='minimum_signup_age' then if jsonb_typeof(cfg->k)<>'number' or cfg->>k!~'^[0-9]{2,3}$' or(cfg->>k)::integer not between 18 and 100 then raise exception 'Invalid volunteer policy.' using errcode='PT422';end if;
 elsif k not in('volunteers','self_signup','reminders','head_coach_management','assistant_management') or jsonb_typeof(cfg->k)<>'boolean' then raise exception 'Invalid volunteer policy.' using errcode='PT422';end if;end loop;
 select x.* into om from public.organization_modules x join public.modules m on m.id=x.module_id where x.organization_id=org and m.key='volunteers' and m.status='active' and x.status='active' and x.starts_at<=now() and(x.ends_at is null or x.ends_at>now()) order by x.starts_at desc limit 1 for update of x;
 if not found then raise exception 'Access denied.' using errcode='PT403';end if;if p_replay and om.id is distinct from p_resource then raise exception 'The module assignment changed.' using errcode='PT409';end if;rid:=om.id;typ:='organization';sid:=org;v:=1;
 if not p_replay then update public.organization_modules set configuration=configuration||cfg,updated_at=now() where id=om.id;end if;
 fields:=jsonb_build_object('fields',(select jsonb_agg(key order by key) from jsonb_object_keys(cfg) key));
 elsif p_op='role.upsert' then
 perform boss_private.volunteer_validate(i,array['organization_id','role_id','expected_version','name','description','status'],array['organization_id','name']);org:=(i->>'organization_id')::uuid;typ:='organization';sid:=org;
 if not boss_private.volunteer_permission(p_actor,'volunteers.manage',org,typ,sid) then raise exception 'Access denied.' using errcode='PT403';end if;
 if i?'role_id' or p_replay then select * into role_row from public.volunteer_role_definitions where id=coalesce((i->>'role_id')::uuid,p_resource) and organization_id=org for update;
 if not found then raise exception 'Access denied.' using errcode='PT403';end if;rid:=role_row.id;
 if not p_replay and(i->>'expected_version')::integer is distinct from role_row.version then raise exception 'The volunteer role changed. Reload and try again.' using errcode='PT409';end if;
 end if;
 perform boss_private.comm_text(i->'name',120);
 if coalesce(i->>'status','active') not in('active','inactive','archived') or length(coalesce(i->>'description',''))>1000 then raise exception 'Invalid volunteer role.' using errcode='PT422';end if;
 if p_replay then v:=role_row.version;
 elsif role_row.id is null then insert into public.volunteer_role_definitions(id,organization_id,name,description,status,created_by_person_id,updated_by_person_id) values(rid,org,btrim(i->>'name'),nullif(i->>'description',''),coalesce(i->>'status','active'),p_actor,p_actor) returning version into v;
 else update public.volunteer_role_definitions set name=btrim(i->>'name'),description=nullif(i->>'description',''),status=coalesce(i->>'status','active'),version=version+1,updated_by_person_id=p_actor,updated_at=now() where id=rid returning version into v;end if;
 fields:=jsonb_build_object('version',v,'status',coalesce(i->>'status','active'));
 elsif p_op='shift.upsert' then
 perform boss_private.volunteer_validate(i,array['organization_id','shift_id','expected_version','role_id','title','scope_type','scope_id','event_id','occurrence_key','start_at','end_at','capacity','instructions','location','status','visibility','signup_deadline','reminder_minutes_before'],array['organization_id','role_id','title','scope_type','scope_id','start_at','end_at','capacity','status','visibility']);
 org:=(i->>'organization_id')::uuid;typ:=i->>'scope_type';sid:=(i->>'scope_id')::uuid;
 if not boss_private.volunteer_permission(p_actor,'volunteers.manage',org,typ,sid) then raise exception 'Access denied.' using errcode='PT403';end if;
 if i?'shift_id' or p_replay then select * into old_shift from public.volunteer_shifts where id=coalesce((i->>'shift_id')::uuid,p_resource) and organization_id=org for update;
 if not found or not boss_private.volunteer_permission(p_actor,'volunteers.manage',old_shift.organization_id,old_shift.scope_type,old_shift.scope_id) then raise exception 'Access denied.' using errcode='PT403';end if;rid:=old_shift.id;
 if not p_replay and(i->>'expected_version')::integer is distinct from old_shift.version then raise exception 'The volunteer shift changed. Reload and try again.' using errcode='PT409';end if;end if;
 s:=old_shift;s.id:=rid;s.organization_id:=org;s.scope_type:=typ;s.scope_id:=sid;s.role_id:=(i->>'role_id')::uuid;s.title:=boss_private.comm_text(i->'title',200);
 s.event_id:=(i->>'event_id')::uuid;s.occurrence_key:=i->>'occurrence_key';s.start_at:=(i->>'start_at')::timestamptz;s.end_at:=(i->>'end_at')::timestamptz;s.capacity:=(i->>'capacity')::integer;
 s.instructions:=nullif(i->>'instructions','');s.location:=nullif(i->>'location','');s.status:=i->>'status';s.visibility:=i->>'visibility';s.signup_deadline:=(i->>'signup_deadline')::timestamptz;s.reminder_minutes_before:=coalesce((i->>'reminder_minutes_before')::integer,60);
 if s.status not in('draft','open','closed','canceled','archived') or s.visibility not in('members','staff') or not isfinite(s.start_at) or not isfinite(s.end_at) or s.end_at<=s.start_at or s.end_at-s.start_at>interval '31 days' or s.start_at>now()+interval '5 years'
 or s.reminder_minutes_before not between 0 and 10080 or s.capacity not between 1 and 10000 or length(coalesce(s.instructions,''))>2000 or length(coalesce(s.location,''))>300 or(s.signup_deadline is not null and(not isfinite(s.signup_deadline) or s.signup_deadline>s.end_at)) then raise exception 'Invalid volunteer shift.' using errcode='PT422';end if;
 if not exists(select 1 from public.volunteer_role_definitions r where r.id=s.role_id and r.organization_id=org and r.status='active') then raise exception 'Access denied.' using errcode='PT403';end if;
 if s.event_id is not null then select * into e from public.events where id=s.event_id and organization_id=org;if not found then raise exception 'Access denied.' using errcode='PT403';end if;
 if s.occurrence_key is null and e.recurrence is null then s.occurrence_key:=to_char(e.start_at at time zone e.timezone,'YYYY-MM-DD"T"HH24:MI:SS');end if;
 if not boss_private.volunteer_event_current(org,s.event_id,s.occurrence_key,typ,sid) and not(old_shift.id is not null and s.status in('closed','canceled','archived') and old_shift.event_id=s.event_id and old_shift.occurrence_key=s.occurrence_key and old_shift.scope_type=typ and old_shift.scope_id=sid) then raise exception 'Access denied.' using errcode='PT403';end if;
 s.event_context_stamp:=coalesce(boss_private.volunteer_event_stamp(s.event_id,s.occurrence_key),old_shift.event_context_stamp);if s.event_context_stamp is null then raise exception 'Invalid occurrence.' using errcode='PT422';end if;
 elsif s.occurrence_key is not null then raise exception 'Invalid occurrence.' using errcode='PT422';else s.event_context_stamp:=null;end if;
 select count(*) into filled from public.volunteer_assignments where shift_id=rid and status='active';
 if not p_replay and(s.capacity<filled or(filled>0 and(old_shift.scope_type is distinct from typ or old_shift.scope_id is distinct from sid or old_shift.event_id is distinct from s.event_id or old_shift.occurrence_key is distinct from s.occurrence_key))) then raise exception 'Existing commitments must remain within their current scope and capacity.' using errcode='PT409';end if;
 material:=old_shift.id is not null and(old_shift.role_id is distinct from s.role_id or old_shift.title is distinct from s.title or old_shift.start_at is distinct from s.start_at or old_shift.end_at is distinct from s.end_at or old_shift.location is distinct from s.location or old_shift.instructions is distinct from s.instructions or old_shift.status is distinct from s.status or old_shift.event_context_stamp is distinct from s.event_context_stamp);
 if p_replay then v:=old_shift.version;
 elsif old_shift.id is null then insert into public.volunteer_shifts(id,organization_id,role_id,title,scope_type,scope_id,event_id,occurrence_key,event_context_stamp,start_at,end_at,capacity,instructions,location,status,visibility,signup_deadline,reminder_minutes_before,created_by_person_id,updated_by_person_id)
 values(rid,org,s.role_id,s.title,typ,sid,s.event_id,s.occurrence_key,s.event_context_stamp,s.start_at,s.end_at,s.capacity,s.instructions,s.location,s.status,s.visibility,s.signup_deadline,s.reminder_minutes_before,p_actor,p_actor) returning version into v;
 else update public.volunteer_shifts set role_id=s.role_id,title=s.title,scope_type=typ,scope_id=sid,event_id=s.event_id,occurrence_key=s.occurrence_key,event_context_stamp=s.event_context_stamp,start_at=s.start_at,end_at=s.end_at,capacity=s.capacity,instructions=s.instructions,location=s.location,status=s.status,visibility=s.visibility,signup_deadline=s.signup_deadline,reminder_minutes_before=s.reminder_minutes_before,version=version+1,updated_by_person_id=p_actor,updated_at=now() where id=rid returning version into v;end if;
 fields:=jsonb_build_object('shift_id',rid,'version',v,'status',s.status,'material_change',material,
 'prior_capacity',old_shift.capacity,'capacity',s.capacity,'prior_role_id',old_shift.role_id,'role_id',s.role_id);
 elsif p_op='reminders.prepare' then
 perform boss_private.volunteer_validate(i,array['organization_id','window_start','window_end'],array['organization_id','window_start','window_end']);org:=(i->>'organization_id')::uuid;typ:='organization';sid:=org;rid:=org;
 if not boss_private.volunteer_feature(org,'reminders') or not(boss_private.volunteer_permission(p_actor,'volunteers.manage',org,'organization',org) or exists(select 1 from public.teams t where t.organization_id=org and boss_private.volunteer_permission(p_actor,'volunteers.manage',org,'team',t.id)) or exists(select 1 from public.organization_units u where u.organization_id=org and boss_private.volunteer_permission(p_actor,'volunteers.manage',org,'unit',u.id))) then raise exception 'Access denied.' using errcode='PT403';end if;
 if not isfinite((i->>'window_start')::timestamptz) or not isfinite((i->>'window_end')::timestamptz) or(i->>'window_end')::timestamptz<=(i->>'window_start')::timestamptz or(i->>'window_end')::timestamptz-(i->>'window_start')::timestamptz>interval '7 days' or(i->>'window_start')::timestamptz<now()-interval '1 day' or(i->>'window_end')::timestamptz>now()+interval '7 days' then raise exception 'Invalid reminder window.' using errcode='PT422';end if;
 if not p_replay then filled:=boss_private.volunteer_prepare_reminders(p_actor,org,(i->>'window_start')::timestamptz,(i->>'window_end')::timestamptz);fields:=jsonb_build_object('prepared',filled);end if;out:=jsonb_build_object('prepared',coalesce(filled,0));v:=1;
 elsif p_op='shift.announce' then
 perform boss_private.volunteer_validate(i,array['shift_id','title','body'],array['shift_id','title','body']);
 perform boss_private.comm_text(i->'title',200);perform boss_private.comm_text(i->'body',4000);
 return boss_private.volunteer_announce(p_actor,p_request,(i->>'shift_id')::uuid,i->>'title',i->>'body',p_replay,p_resource)||jsonb_build_object('operation',p_op,'request_id',p_request);
 elsif p_op in('assignment.signup','assignment.assign','assignment.cancel','assignment.reassign') then
 if p_op in('assignment.signup','assignment.assign') then
 perform boss_private.volunteer_validate(i,array['shift_id','person_id'],case when p_op='assignment.assign' then array['shift_id','person_id'] else array['shift_id'] end);
 if p_op='assignment.signup' and i?'person_id' then raise exception 'Self signup cannot select another person.' using errcode='PT422';end if;
 select * into s from public.volunteer_shifts where id=(i->>'shift_id')::uuid for update;if not found then raise exception 'Access denied.' using errcode='PT403';end if;
 pid:=case when p_op='assignment.signup' then p_actor else(i->>'person_id')::uuid end;
 else
 perform boss_private.volunteer_validate(i,array['assignment_id','expected_version','person_id'],case when p_op='assignment.reassign' then array['assignment_id','expected_version','person_id'] else array['assignment_id','expected_version'] end);
 if p_op='assignment.cancel' and i?'person_id' then raise exception 'Invalid volunteer request.' using errcode='PT422';end if;
 select * into a from public.volunteer_assignments where id=(i->>'assignment_id')::uuid;if not found then raise exception 'Access denied.' using errcode='PT403';end if;
 select * into s from public.volunteer_shifts where id=a.shift_id for update;select * into a from public.volunteer_assignments where id=a.id for update;rid:=a.id;pid:=a.person_id;
 end if;
 org:=s.organization_id;typ:=s.scope_type;sid:=s.scope_id;
 if p_op='assignment.cancel' then
 if a.person_id<>p_actor and not boss_private.volunteer_permission(p_actor,'volunteers.assign',org,typ,sid) then raise exception 'Access denied.' using errcode='PT403';end if;
 if not p_replay and(i->>'expected_version')::integer is distinct from a.version then raise exception 'The volunteer commitment changed. Reload and try again.' using errcode='PT409';end if;
 if not p_replay and a.status='active' then prior:=a.status;update public.volunteer_assignments set status='canceled',canceled_by_person_id=p_actor,canceled_at=now(),version=version+1,updated_at=now() where id=a.id returning * into a;
 perform boss_private.volunteer_history(a,p_actor,'cancel',prior,p_request);update public.volunteer_shifts set version=version+1,updated_at=now() where id=s.id;
 fields:=jsonb_build_object('shift_id',s.id,'assignment_id',a.id,'person_id',a.person_id,'version',a.version,'status',a.status);end if;v:=a.version;
 else
 if p_op<>'assignment.signup' and not boss_private.volunteer_permission(p_actor,'volunteers.assign',org,typ,sid) then raise exception 'Access denied.' using errcode='PT403';end if;
 if p_op='assignment.reassign' then pid:=(i->>'person_id')::uuid;if not p_replay and(i->>'expected_version')::integer is distinct from a.version then raise exception 'The volunteer commitment changed. Reload and try again.' using errcode='PT409';end if;if pid=a.person_id then raise exception 'Select a different eligible volunteer.' using errcode='PT422';end if;end if;
 if not boss_private.volunteer_can_signup(s.id,pid,p_op='assignment.signup') then raise exception 'This shift is unavailable for signup.' using errcode='PT403';end if;
 select * into b from public.volunteer_assignments where shift_id=s.id and person_id=pid for update;
 if p_replay then if b.id is distinct from p_resource or b.status<>'active' then raise exception 'The volunteer commitment changed.' using errcode='PT409';end if;rid:=b.id;v:=b.version;
 elsif b.status='active' then
 if p_op='assignment.reassign' then raise exception 'That person already has this commitment.' using errcode='PT409';end if;rid:=b.id;v:=b.version;
 else
 select count(*) into filled from public.volunteer_assignments where shift_id=s.id and status='active';
 if p_op='assignment.reassign' then if a.status<>'active' then raise exception 'The volunteer commitment is no longer active.' using errcode='PT409';end if;filled:=filled-1;end if;
 if filled>=s.capacity then raise exception 'This volunteer shift is full.' using errcode='PT409';end if;
 if p_op='assignment.reassign' then prior:=a.status;update public.volunteer_assignments set status='canceled',canceled_by_person_id=p_actor,canceled_at=now(),version=version+1,updated_at=now() where id=a.id returning * into a;perform boss_private.volunteer_history(a,p_actor,'reassign',prior,p_request);end if;
 prior:=b.status;
 if b.id is null then insert into public.volunteer_assignments(organization_id,shift_id,person_id,source,assigned_by_person_id) values(org,s.id,pid,case when p_op='assignment.signup' then 'self' else 'staff' end,p_actor) returning * into b;
 else update public.volunteer_assignments set status='active',source=case when p_op='assignment.signup' then 'self' else 'staff' end,assigned_by_person_id=p_actor,canceled_by_person_id=null,canceled_at=null,version=version+1,updated_at=now() where id=b.id returning * into b;end if;
 rid:=b.id;v:=b.version;perform boss_private.volunteer_history(b,p_actor,split_part(p_op,'.',2),prior,p_request);update public.volunteer_shifts set version=version+1,updated_at=now() where id=s.id;
 fields:=jsonb_strip_nulls(jsonb_build_object('shift_id',s.id,'assignment_id',b.id,'person_id',pid,'version',v,'status','active','previous_person_id',case when p_op='assignment.reassign' then a.person_id end,'previous_assignment_id',case when p_op='assignment.reassign' then a.id end));
 end if;
 end if;
 out:=jsonb_build_object('status',case when p_op='assignment.cancel' then a.status else b.status end,'shift_id',s.id);
 else raise exception 'Unsupported volunteer operation.' using errcode='PT422';end if;
 if not p_replay and fields<>'{}' then perform boss_private.volunteer_audit(p_actor,p_op,rid,org,typ,sid,p_request,fields);end if;
 return out||jsonb_build_object('operation',p_op,'resource_id',rid,'version',v,'request_id',p_request);
end $$;
create function boss_private.volunteer_mutate(p_request_id uuid,p_command jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;op text;h bytea;r boss_private.volunteer_operation_receipts;result jsonb;begin
 actor:=boss_private.require_admin_actor();perform boss_private.volunteer_validate(p_command,array['operation','input'],array['operation','input']);
 if p_request_id is null or octet_length(p_command::text)>16384 or jsonb_typeof(p_command->'operation')<>'string' then raise exception 'Invalid volunteer request.' using errcode='PT422';end if;
 op:=p_command->>'operation';h:=sha256(convert_to(p_command::text,'UTF8'));
 perform pg_advisory_xact_lock(hashtextextended('volunteer-request:'||actor::text||':'||p_request_id::text,0));
 select * into r from boss_private.volunteer_operation_receipts where actor_person_id=actor and request_id=p_request_id;
 if found then if r.input_hash<>h then raise exception 'Conflicting volunteer request.' using errcode='PT409';end if;
 perform boss_private.volunteer_command(actor,op,p_command->'input',p_request_id,true,(r.result->>'resource_id')::uuid);return r.result;end if;
 result:=boss_private.volunteer_command(actor,op,p_command->'input',p_request_id);insert into boss_private.volunteer_operation_receipts(actor_person_id,request_id,input_hash,command,result) values(actor,p_request_id,h,p_command,result);return result;
 exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' then raise;
 when serialization_failure or deadlock_detected or unique_violation then raise exception 'The volunteer state changed. Reload and try again.' using errcode='PT409';
 when others then raise exception 'Invalid volunteer request.' using errcode='PT422';end $$;

create function boss_private.volunteer_shift_projection(s public.volunteer_shifts,p_actor uuid,p_detail boolean default false) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_strip_nulls(jsonb_build_object('id',s.id,'organization_id',s.organization_id,'label',s.title,'role_id',s.role_id,'role_label',(select name from public.volunteer_role_definitions where id=s.role_id),
 'start_at',s.start_at,'end_at',s.end_at,'capacity',s.capacity,'filled',(select count(*) from public.volunteer_assignments where shift_id=s.id and status='active'),
 'unfilled',greatest(0,s.capacity-(select count(*)::integer from public.volunteer_assignments where shift_id=s.id and status='active')),
 'status',s.status,'visibility',s.visibility,'signup_deadline',s.signup_deadline,'reminder_minutes_before',s.reminder_minutes_before,'scope_type',s.scope_type,'scope_id',s.scope_id,
 'scope_label',case s.scope_type when 'organization' then(select name from public.organizations where id=s.scope_id) when 'unit' then(select name from public.organization_units where id=s.scope_id and organization_id=s.organization_id) when 'team' then(select name from public.teams where id=s.scope_id and organization_id=s.organization_id) end,'event_id',s.event_id,'occurrence_key',s.occurrence_key,
 'event_label',(select title from public.events where id=s.event_id),'event_context_changed',s.event_id is not null and s.event_context_stamp is distinct from boss_private.volunteer_event_stamp(s.event_id,s.occurrence_key),
 'version',s.version,'can_signup',boss_private.volunteer_can_signup(s.id,p_actor) and not exists(select 1 from public.volunteer_assignments where shift_id=s.id and person_id=p_actor and status='active') and(select count(*) from public.volunteer_assignments where shift_id=s.id and status='active')<s.capacity,
 'can_manage',boss_private.volunteer_permission(p_actor,'volunteers.manage',s.organization_id,s.scope_type,s.scope_id),'can_assign',boss_private.volunteer_permission(p_actor,'volunteers.assign',s.organization_id,s.scope_type,s.scope_id),
 'can_announce',boss_private.volunteer_coordinator(s.id,p_actor) and boss_private.comm_feature(s.organization_id,'announcements') and boss_private.comm_permission(p_actor,'announcements.send',s.organization_id,s.scope_type,s.scope_id),
 'my_assignment',(select jsonb_build_object('id',a.id,'status',a.status,'version',a.version,'can_cancel',a.status='active') from public.volunteer_assignments a where a.shift_id=s.id and a.person_id=p_actor),
 'instructions',case when p_detail then s.instructions end,'location',case when p_detail then s.location end,
 'assignments',case when p_detail and boss_private.volunteer_permission(p_actor,'volunteers.view',s.organization_id,s.scope_type,s.scope_id) then(select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'person_id',a.person_id,'label',coalesce(p.display_name,p.preferred_name,'Boss member'),'status',a.status,'version',a.version,'can_cancel',a.status='active' and boss_private.volunteer_permission(p_actor,'volunteers.assign',s.organization_id,s.scope_type,s.scope_id)) order by a.created_at,a.id),'[]') from(select * from public.volunteer_assignments aa where aa.shift_id=s.id order by aa.created_at,aa.id limit 100) a join public.people p on p.id=a.person_id) end)) $$;
create function boss_private.volunteer_module_current(p_org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organization_modules x join public.modules m on m.id=x.module_id join public.organizations o on o.id=x.organization_id where x.organization_id=p_org and o.status='active' and m.key='volunteers' and m.status='active' and x.status='active' and x.starts_at<=now() and(x.ends_at is null or x.ends_at>now())) $$;
create function boss_private.volunteer_organization_visible(p_org uuid,p_actor uuid) returns boolean language sql stable security definer set search_path='' as $$
 select boss_private.volunteer_module_current(p_org) and(boss_private.has_permission('volunteers.manage',p_org) or(boss_private.volunteer_feature(p_org,'volunteers') and(
 boss_private.volunteer_permission(p_actor,'volunteers.view',p_org,'organization',p_org) or boss_private.volunteer_person_eligible(p_actor,p_org,'organization',p_org)
 or exists(select 1 from public.organization_units u where u.organization_id=p_org and boss_private.volunteer_permission(p_actor,'volunteers.view',p_org,'unit',u.id))
 or exists(select 1 from public.teams t where t.organization_id=p_org and boss_private.volunteer_permission(p_actor,'volunteers.view',p_org,'team',t.id))))) $$;
create function boss_private.volunteer_read(q jsonb default '{}') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=boss_private.require_admin_actor();org uuid;shift_id uuid;team uuid;unit uuid;ev uuid;person uuid;v_from timestamptz;v_to timestamptz;lim integer;vw text;
 orgs jsonb;shifts jsonb;commitments jsonb;detail jsonb:='null';roles jsonb;teams jsonb;units jsonb;events jsonb;targets jsonb;candidates jsonb:='[]';ops text[]:='{}';s public.volunteer_shifts;navigation_available boolean;options_limited boolean;
begin
 if q is null or jsonb_typeof(q)<>'object' or octet_length(q::text)>8192 or exists(select 1 from jsonb_object_keys(q) k where k not in('organization_id','shift_id','team_id','unit_id','event_id','person_id','from','to','view','limit')) then raise exception 'Invalid volunteer query.' using errcode='PT422';end if;
 if exists(select 1 from jsonb_each(q) x where(x.key='limit' and(jsonb_typeof(x.value)<>'number' or x.value::text!~'^[0-9]{1,3}$')) or(x.key<>'limit' and jsonb_typeof(x.value)<>'string')) then raise exception 'Invalid volunteer query.' using errcode='PT422';end if;
 org:=(q->>'organization_id')::uuid;shift_id:=(q->>'shift_id')::uuid;team:=(q->>'team_id')::uuid;unit:=(q->>'unit_id')::uuid;ev:=(q->>'event_id')::uuid;person:=(q->>'person_id')::uuid;
 v_from:=coalesce((q->>'from')::timestamptz,now()-interval '1 day');v_to:=coalesce((q->>'to')::timestamptz,v_from+interval '90 days');lim:=coalesce((q->>'limit')::integer,50);vw:=coalesce(q->>'view','upcoming');
 if lim not between 1 and 100 or vw not in('upcoming','manage','family') or not isfinite(v_from) or not isfinite(v_to) or v_to<=v_from or v_to-v_from>interval '366 days' then raise exception 'Invalid volunteer query.' using errcode='PT422';end if;
 select exists(select 1 from public.organization_modules assignment join public.modules module on module.id=assignment.module_id join public.organizations o on o.id=assignment.organization_id
 where module.key='volunteers' and module.status='active' and o.status='active' and assignment.status='active' and assignment.starts_at<=now() and(assignment.ends_at is null or assignment.ends_at>now())
 and boss_private.volunteer_feature(o.id,'volunteers') and boss_private.volunteer_organization_visible(o.id,actor)) into navigation_available;
 select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'label',x.name) order by x.name,x.id),'[]') into orgs from(select o.id,o.name from public.organizations o where o.status='active' and boss_private.volunteer_organization_visible(o.id,actor) order by o.name,o.id limit 101)x;
 options_limited:=jsonb_array_length(orgs)>100;
 if options_limited then select jsonb_agg(x.item order by x.ordinal) into orgs from jsonb_array_elements(orgs) with ordinality x(item,ordinal) where x.ordinal<=100;end if;
 if org is null then org:=(orgs->0->>'id')::uuid;end if;
 if org is not null and not boss_private.volunteer_organization_visible(org,actor) then raise exception 'Access denied.' using errcode='PT403';end if;
 if org is not null and not exists(select 1 from jsonb_array_elements(orgs) x where(x->>'id')::uuid=org) then orgs:=orgs||jsonb_build_array(jsonb_build_object('id',org,'label',(select name from public.organizations where id=org)));end if;
 if org is null and(shift_id is not null or team is not null or unit is not null or ev is not null or person is not null) then raise exception 'Access denied.' using errcode='PT403';end if;
 if org is null then return jsonb_build_object('person',jsonb_build_object('id',actor,'label','Boss member'),'organizations',orgs,'organizationId',null,'navigation_available',navigation_available,'options_limited',options_limited,'features','{}'::jsonb,'operations','[]'::jsonb,'roles','[]'::jsonb,'teams','[]'::jsonb,'units','[]'::jsonb,'events','[]'::jsonb,'shifts','[]'::jsonb,'detail',null,'commitments','[]'::jsonb,'candidates','[]'::jsonb,'targets','[]'::jsonb);end if;
 if not boss_private.volunteer_feature(org,'volunteers') then
 if shift_id is not null or team is not null or unit is not null or ev is not null or person is not null then raise exception 'Access denied.' using errcode='PT403';end if;
 return jsonb_build_object('person',jsonb_build_object('id',actor,'label',(select coalesce(display_name,preferred_name,'Boss member') from public.people where id=actor)),'organizations',orgs,'organizationId',org,'navigation_available',navigation_available,'options_limited',options_limited,'features',boss_private.volunteer_configuration(org),'operations',jsonb_build_array('volunteers.configure'),'roles','[]'::jsonb,'teams','[]'::jsonb,'units','[]'::jsonb,'events','[]'::jsonb,'shifts','[]'::jsonb,'detail',null,'commitments','[]'::jsonb,'candidates','[]'::jsonb,'targets','[]'::jsonb);
 end if;
 if team is not null and not(boss_private.volunteer_scope_active(org,'team',team) and(boss_private.volunteer_person_related(actor,org,'team',team) or boss_private.volunteer_permission(actor,'volunteers.view',org,'team',team))) then raise exception 'Access denied.' using errcode='PT403';end if;
 if unit is not null and not(boss_private.volunteer_scope_active(org,'unit',unit) and(boss_private.volunteer_person_related(actor,org,'unit',unit) or boss_private.volunteer_permission(actor,'volunteers.view',org,'unit',unit))) then raise exception 'Access denied.' using errcode='PT403';end if;
 if ev is not null and not exists(select 1 from public.events e join public.event_targets et on et.event_id=e.id where e.id=ev and e.organization_id=org and(boss_private.volunteer_person_related(actor,org,et.target_type,et.target_id) or boss_private.volunteer_permission(actor,'volunteers.view',org,et.target_type,et.target_id))) then raise exception 'Access denied.' using errcode='PT403';end if;
 if person is not null and person<>actor and vw<>'manage' then raise exception 'Access denied.' using errcode='PT403';end if;
 if boss_private.volunteer_permission(actor,'volunteers.manage',org,'organization',org) then ops:=ops||array['role.upsert','volunteers.configure'];end if;
 if exists(select 1 from public.teams t where t.organization_id=org and boss_private.volunteer_permission(actor,'volunteers.manage',org,'team',t.id)) or exists(select 1 from public.organization_units u where u.organization_id=org and boss_private.volunteer_permission(actor,'volunteers.manage',org,'unit',u.id)) or boss_private.volunteer_permission(actor,'volunteers.manage',org,'organization',org) then ops:=ops||array['shift.upsert'];if boss_private.volunteer_feature(org,'reminders') then ops:=ops||array['reminders.prepare'];end if;end if;
 if boss_private.volunteer_feature(org,'self_signup') then ops:=ops||array['assignment.signup'];end if;ops:=ops||array['assignment.cancel'];
 select coalesce(jsonb_agg(jsonb_build_object('scope_type',x.typ,'scope_id',x.id,'label',x.label) order by x.typ,x.label,x.id),'[]') into targets from(
 select 'organization'::text typ,o.id,o.name label from public.organizations o where o.id=org and team is null and unit is null and boss_private.volunteer_permission(actor,'volunteers.manage',org,'organization',org)
 union all select 'unit',u.id,u.name from public.organization_units u where u.organization_id=org and team is null and(unit is null or u.id=unit) and boss_private.volunteer_permission(actor,'volunteers.manage',org,'unit',u.id)
 union all select 'team',t.id,t.name from public.teams t where t.organization_id=org and(team is null or t.id=team) and(unit is null or t.parent_unit_id=unit) and boss_private.volunteer_permission(actor,'volunteers.manage',org,'team',t.id)
 order by typ,label,id limit 101)x;
 if jsonb_array_length(targets)>100 then options_limited:=true;select jsonb_agg(x.item order by x.ordinal) into targets from jsonb_array_elements(targets) with ordinality x(item,ordinal) where x.ordinal<=100;end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'label',r.name,'description',r.description,'status',r.status,'version',r.version) order by r.name,r.id),'[]') into roles from(select * from public.volunteer_role_definitions rr where rr.organization_id=org and(rr.status='active' or 'role.upsert'=any(ops)) order by rr.name,rr.id limit 100) r;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'label',t.name) order by t.name,t.id),'[]') into teams from(select * from public.teams tt where tt.organization_id=org and boss_private.volunteer_scope_active(org,'team',tt.id) and(boss_private.volunteer_person_eligible(actor,org,'team',tt.id) or boss_private.volunteer_permission(actor,'volunteers.view',org,'team',tt.id)) order by tt.name,tt.id limit 100) t;
 select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'label',u.name) order by u.name,u.id),'[]') into units from(select * from public.organization_units uu where uu.organization_id=org and boss_private.volunteer_scope_active(org,'unit',uu.id) and(boss_private.volunteer_person_eligible(actor,org,'unit',uu.id) or boss_private.volunteer_permission(actor,'volunteers.view',org,'unit',uu.id)) order by uu.name,uu.id limit 100) u;
 select coalesce(jsonb_agg(x.item order by x.start_at,x.id),'[]') into events from(select e.id,e.start_at,jsonb_build_object('id',e.id,'label',e.title,'occurrences',(select coalesce(jsonb_agg(jsonb_build_object('occurrence_key',o.occurrence_key,'start_at',o.start_at,'end_at',o.end_at,'status',o.status) order by o.start_at),'[]') from boss_private.calendar_occurrences(e,v_from,v_to) o)) item from public.events e
 where e.organization_id=org and e.status in('scheduled','confirmed') and boss_private.calendar_module_enabled(org) and exists(select 1 from public.event_targets et where et.event_id=e.id and(boss_private.volunteer_person_related(actor,org,et.target_type,et.target_id) or boss_private.volunteer_permission(actor,'volunteers.view',org,et.target_type,et.target_id))) order by e.start_at,e.id limit 100)x;
 select coalesce(jsonb_agg(x.item order by x.start_at,x.id),'[]') into shifts from(select vs.id,vs.start_at,boss_private.volunteer_shift_projection(vs,actor) item from public.volunteer_shifts vs
 where vs.organization_id=org and vs.start_at<v_to and vs.end_at>v_from and(team is null or vs.team_id=team) and(unit is null or vs.organization_unit_id=unit or exists(select 1 from public.teams t where t.id=vs.team_id and t.parent_unit_id=unit)) and(ev is null or vs.event_id=ev)
 and boss_private.volunteer_can_view_shift(vs.id,actor) and(vw<>'manage' or boss_private.volunteer_permission(actor,'volunteers.view',org,vs.scope_type,vs.scope_id))
 and(person is null or exists(select 1 from public.volunteer_assignments a where a.shift_id=vs.id and a.person_id=person)) order by vs.start_at,vs.id limit lim)x;
 select coalesce(jsonb_agg(x.item order by x.start_at,x.id),'[]') into commitments from(select vs.id,vs.start_at,boss_private.volunteer_shift_projection(vs,actor) item from public.volunteer_assignments a join public.volunteer_shifts vs on vs.id=a.shift_id
 where a.person_id=actor and vs.organization_id=org and vs.start_at<v_to and vs.end_at>v_from and boss_private.volunteer_can_view_shift(vs.id,actor) order by vs.start_at,vs.id limit lim)x;
 if shift_id is not null then select * into s from public.volunteer_shifts where id=shift_id and organization_id=org;
 if not found or not boss_private.volunteer_can_view_shift(s.id,actor) then raise exception 'Access denied.' using errcode='PT403';end if;detail:=boss_private.volunteer_shift_projection(s,actor,true);
 if boss_private.volunteer_permission(actor,'volunteers.manage',org,s.scope_type,s.scope_id) and not exists(select 1 from jsonb_array_elements(targets) x where x->>'scope_type'=s.scope_type and(x->>'scope_id')::uuid=s.scope_id) then
 targets:=targets||jsonb_build_array(jsonb_build_object('scope_type',s.scope_type,'scope_id',s.scope_id,'label',detail->>'scope_label'));end if;
 if boss_private.volunteer_coordinator(s.id,actor) and boss_private.comm_feature(org,'announcements') and boss_private.comm_permission(actor,'announcements.send',org,s.scope_type,s.scope_id) then ops:=ops||array['shift.announce'];end if;
 if boss_private.volunteer_permission(actor,'volunteers.assign',org,s.scope_type,s.scope_id) then
 ops:=ops||array['assignment.assign','assignment.reassign'];
 select coalesce(jsonb_agg(x.item order by x.label,x.id),'[]') into candidates from(select p.id,coalesce(p.display_name,p.preferred_name,'Boss member') label,jsonb_build_object('id',p.id,'label',coalesce(p.display_name,p.preferred_name,'Boss member')) item from (select m.person_id id from public.organization_memberships m where m.organization_id=org and m.status='active' and m.starts_at<=now() and(m.ends_at is null or m.ends_at>now()) union select tm.person_id from public.team_memberships tm where tm.organization_id=org and tm.status='active' and tm.starts_at<=now() and(tm.ends_at is null or tm.ends_at>now()) union select g.guardian_person_id from public.guardian_relationships g join public.team_memberships tm on tm.person_id=g.dependent_person_id where tm.organization_id=org and tm.status='active' and tm.starts_at<=now() and(tm.ends_at is null or tm.ends_at>now()) and g.authority_status='active' and g.verified_at<=now() and g.starts_at<=now() and(g.ends_at is null or g.ends_at>now())) anchor join public.people p on p.id=anchor.id
 where boss_private.volunteer_person_eligible(p.id,org,s.scope_type,s.scope_id) order by coalesce(p.display_name,p.preferred_name,'Boss member'),p.id limit 100)x;
 end if;end if;
 return jsonb_build_object('person',jsonb_build_object('id',actor,'label',(select coalesce(display_name,preferred_name,'Boss member') from public.people where id=actor)),
 'organizations',orgs,'organizationId',org,'navigation_available',navigation_available,'options_limited',options_limited,'features',boss_private.volunteer_configuration(org),'operations',to_jsonb(ops),'roles',roles,'teams',teams,'units',units,'events',events,'shifts',shifts,'detail',detail,'commitments',commitments,'candidates',candidates,'targets',targets);
 exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT422' then raise;when others then raise exception 'Invalid volunteer query.' using errcode='PT422';end $$;
create function public.boss_volunteers_read(p_query jsonb default '{}') returns jsonb language sql stable security invoker set search_path='' as $$select boss_private.volunteer_read(p_query)$$;
create function public.boss_volunteers_mutate(p_request_id uuid,p_command jsonb) returns jsonb language sql security invoker set search_path='' as $$select boss_private.volunteer_mutate(p_request_id,p_command)$$;
create trigger volunteer_roles_identity before update on public.volunteer_role_definitions for each row execute function boss_private.preserve_row_identity('id','organization_id','created_at','created_by_person_id');
create trigger volunteer_shifts_identity before update on public.volunteer_shifts for each row execute function boss_private.preserve_row_identity('id','organization_id','created_at','created_by_person_id');
create trigger volunteer_assignments_identity before update on public.volunteer_assignments for each row execute function boss_private.preserve_row_identity('id','organization_id','shift_id','person_id','created_at');
create trigger volunteer_history_immutable before update on public.volunteer_assignment_history for each row execute function boss_private.registration_reject_rewrite();
DO $$declare f record;begin for f in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'volunteer_%' loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.f);end loop;end$$;
revoke all on function public.boss_volunteers_read(jsonb),public.boss_volunteers_mutate(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.boss_volunteers_read(jsonb),public.boss_volunteers_mutate(uuid,jsonb),boss_private.volunteer_read(jsonb),boss_private.volunteer_mutate(uuid,jsonb) to authenticated;
