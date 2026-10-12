-- One canonical event with bounded local-time recurrence and permission-aware projections.
-- Calendar is independent from Sports. No attendance delivery or later module is added.
create table public.event_types (
  key text primary key, name text not null, description text, status text not null default 'active',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (key ~ '^[a-z][a-z0-9_]*$'), check (length(btrim(name)) between 1 and 100),
  check (status in ('active','inactive','archived'))
);
alter table public.event_types enable row level security;
revoke all on public.event_types from public,anon,authenticated,service_role;
insert into public.event_types(key,name) values
 ('game','Game'),('practice','Practice'),('tournament','Tournament'),('tryout','Tryout'),
 ('camp','Camp'),('clinic','Clinic'),('meeting','Meeting'),('organization_event','Organization event'),
 ('fundraiser','Fundraiser'),('volunteer_activity','Volunteer activity'),('registration_deadline','Registration deadline'),('custom','Custom');

create table public.venues (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict,
 name text not null, address_line1 text,address_line2 text,city text,region text,postal_code text,country_code text,
 timezone text not null default 'UTC',instructions text,status text not null default 'active',is_public boolean not null default false,
 created_by_person_id uuid not null references public.people(id) on delete restrict,
 updated_by_person_id uuid not null references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),version bigint not null default 1,
 unique(organization_id,id),check(length(btrim(name)) between 1 and 200),check(status in ('active','inactive','archived')),
 check(country_code is null or country_code ~ '^[A-Z]{2}$'),check(version>0),
 check(length(coalesce(instructions,''))<=4000),check(length(coalesce(address_line1,''))<=200),check(length(coalesce(address_line2,''))<=200),
 check(length(coalesce(city,''))<=100),check(length(coalesce(region,''))<=100),check(length(coalesce(postal_code,''))<=30)
);
alter table public.venues enable row level security;
revoke all on public.venues from public,anon,authenticated,service_role;
create index venues_organization_status_idx on public.venues(organization_id,status);
create index venues_created_by_idx on public.venues(created_by_person_id);
create index venues_updated_by_idx on public.venues(updated_by_person_id);

create table public.venue_resources (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 venue_id uuid not null,name text not null,resource_type text not null default 'space',status text not null default 'active',
 is_public boolean not null default false,
 created_by_person_id uuid not null references public.people(id) on delete restrict,
 updated_by_person_id uuid not null references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),version bigint not null default 1,
 unique(organization_id,id),unique(organization_id,venue_id,id),
 foreign key(organization_id,venue_id) references public.venues(organization_id,id) on delete restrict,
 check(length(btrim(name)) between 1 and 200),check(length(btrim(resource_type)) between 1 and 50),
 check(status in ('active','inactive','archived')),check(version>0)
);
alter table public.venue_resources enable row level security;
revoke all on public.venue_resources from public,anon,authenticated,service_role;
create index venue_resources_venue_idx on public.venue_resources(organization_id,venue_id);
create index venue_resources_created_by_idx on public.venue_resources(created_by_person_id);
create index venue_resources_updated_by_idx on public.venue_resources(updated_by_person_id);

create table public.events (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 title text not null,description text,event_type_key text not null references public.event_types(key) on delete restrict,
 start_at timestamptz not null,end_at timestamptz not null,timezone text not null default 'UTC',all_day boolean not null default false,
 arrival_at timestamptz,status text not null default 'draft',visibility text not null default 'member',
 publication_state text not null default 'unpublished',venue_id uuid,resource_id uuid,instructions text,
 rsvp_mode text not null default 'not_required',audience text[] not null default array['participants','guardians']::text[],
 recurrence jsonb,recurrence_end_at timestamptz,
 created_by_person_id uuid not null references public.people(id) on delete restrict,
 updated_by_person_id uuid not null references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 published_at timestamptz,archived_at timestamptz,version bigint not null default 1,
 unique(organization_id,id),foreign key(organization_id,venue_id) references public.venues(organization_id,id) on delete restrict,
 foreign key(organization_id,venue_id,resource_id) references public.venue_resources(organization_id,venue_id,id) on delete restrict,
 check(length(btrim(title)) between 1 and 200),check(length(coalesce(description,''))<=4000),check(length(coalesce(instructions,''))<=4000),
 check(isfinite(start_at) and isfinite(end_at) and end_at>start_at and end_at-start_at<=interval '31 days'),
 check(arrival_at is null or (isfinite(arrival_at) and arrival_at<=start_at and start_at-arrival_at<=interval '7 days')),
 check(status in ('draft','scheduled','confirmed','canceled','postponed','completed','archived')),
 check(visibility in ('public','authenticated','member','restricted','private')),
 check(publication_state in ('unpublished','published')),check(resource_id is null or venue_id is not null),
 check(rsvp_mode in ('not_required','optional','required')),check(version>0),
 check(cardinality(audience) between 1 and 7 and array_position(audience,null) is null
   and audience <@ array['organization','unit','team','staff','coaches','guardians','participants','public']::text[]),
 check(recurrence is null or jsonb_typeof(recurrence)='object')
);
alter table public.events enable row level security;
revoke all on public.events from public,anon,authenticated,service_role;
create index events_organization_start_idx on public.events(organization_id,start_at,end_at);
create index events_organization_end_idx on public.events(organization_id,end_at) where recurrence is null;
create index events_recurrence_end_idx on public.events(organization_id,recurrence_end_at,start_at) where recurrence is not null;
create index events_type_idx on public.events(event_type_key);
create index events_venue_idx on public.events(organization_id,venue_id);
create index events_resource_idx on public.events(organization_id,venue_id,resource_id);
create index events_created_by_idx on public.events(created_by_person_id);
create index events_updated_by_idx on public.events(updated_by_person_id);

create table public.event_targets (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 event_id uuid not null,target_type text not null,target_id uuid not null,
 unit_id uuid generated always as(case when target_type='unit' then target_id end) stored,
 team_id uuid generated always as(case when target_type='team' then target_id end) stored,
 created_at timestamptz not null default now(),
 foreign key(organization_id,event_id) references public.events(organization_id,id) on delete restrict,
 foreign key(organization_id,unit_id) references public.organization_units(organization_id,id) on delete restrict,
 foreign key(organization_id,team_id) references public.teams(organization_id,id) on delete restrict,
 unique(event_id,target_type,target_id),
 check(target_type in ('organization','unit','team')),check(target_type<>'organization' or target_id=organization_id)
);
alter table public.event_targets enable row level security;
revoke all on public.event_targets from public,anon,authenticated,service_role;
create index event_targets_event_idx on public.event_targets(organization_id,event_id);
create index event_targets_target_idx on public.event_targets(organization_id,target_type,target_id,event_id);
create index event_targets_unit_idx on public.event_targets(organization_id,unit_id);
create index event_targets_team_idx on public.event_targets(organization_id,team_id);

create table public.event_game_details (
 event_id uuid primary key,organization_id uuid not null references public.organizations(id) on delete restrict,
 opponent_team_id uuid,external_opponent_name text,home_away text not null default 'neutral',game_status text not null default 'scheduled',
 foreign key(organization_id,event_id) references public.events(organization_id,id) on delete restrict,
 foreign key(organization_id,opponent_team_id) references public.teams(organization_id,id) on delete restrict,
 check(opponent_team_id is null or external_opponent_name is null),
 check(external_opponent_name is null or length(btrim(external_opponent_name)) between 1 and 200),
 check(home_away in ('home','away','neutral')),check(game_status in ('scheduled','postponed','canceled','completed'))
);
alter table public.event_game_details enable row level security;
revoke all on public.event_game_details from public,anon,authenticated,service_role;
create index event_game_details_event_idx on public.event_game_details(organization_id,event_id);
create index event_game_details_opponent_idx on public.event_game_details(organization_id,opponent_team_id);

create table public.event_occurrence_exceptions (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 event_id uuid not null,occurrence_key text not null,override_start_at timestamptz,override_end_at timestamptz,override_arrival_at timestamptz,
 status text,title text,instructions text,is_active boolean not null default true,
 created_by_person_id uuid not null references public.people(id) on delete restrict,
 updated_by_person_id uuid not null references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),version bigint not null default 1,
 foreign key(organization_id,event_id) references public.events(organization_id,id) on delete restrict,
 check(occurrence_key ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$'),
 check((override_start_at is null)=(override_end_at is null)),
 check(override_start_at is null or (isfinite(override_start_at) and isfinite(override_end_at) and override_end_at>override_start_at and override_end_at-override_start_at<=interval '31 days')),
 check(status is null or status in ('scheduled','confirmed','canceled','postponed','completed','archived')),
 check(title is null or length(btrim(title)) between 1 and 200),check(length(coalesce(instructions,''))<=4000),check(version>0)
);
alter table public.event_occurrence_exceptions enable row level security;
revoke all on public.event_occurrence_exceptions from public,anon,authenticated,service_role;
create unique index event_exceptions_active_key_idx on public.event_occurrence_exceptions(event_id,occurrence_key) where is_active;
create index event_exceptions_event_idx on public.event_occurrence_exceptions(organization_id,event_id);
create index event_exceptions_override_range_idx on public.event_occurrence_exceptions(organization_id,override_start_at,override_end_at) where is_active;
create index event_exceptions_created_by_idx on public.event_occurrence_exceptions(created_by_person_id);
create index event_exceptions_updated_by_idx on public.event_occurrence_exceptions(updated_by_person_id);

create table public.event_reminders (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 event_id uuid not null,minutes_before integer not null,audience text[] not null,enabled boolean not null default true,
 foreign key(organization_id,event_id) references public.events(organization_id,id) on delete restrict,
 unique(event_id,minutes_before,audience),check(minutes_before between 0 and 10080),
 check(cardinality(audience) between 1 and 7 and array_position(audience,null) is null
  and audience <@ array['organization','unit','team','staff','coaches','guardians','participants']::text[])
);
alter table public.event_reminders enable row level security;
revoke all on public.event_reminders from public,anon,authenticated,service_role;
create index event_reminders_event_idx on public.event_reminders(organization_id,event_id);

insert into public.modules(key,name,description) values('calendar','Calendar','Canonical events and permission-aware schedule projections independent from Sports');
insert into public.permissions(key,name,description) values
 ('events.view','View scoped events','View restricted schedules within an actual authorized resource scope'),
 ('events.create','Create scoped events','Create canonical events for authorized target resources'),
 ('events.manage','Manage scoped events','Edit and retain historical events for authorized target resources'),
 ('events.publish','Publish scoped schedules','Explicitly publish authorized schedule records'),
 ('events.override_conflict','Override scoped scheduling conflicts','Explicitly override detected conflicts only when organization policy permits');
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where p.key like 'events.%' and (
 r.key in ('super_administrator','platform_administrator','organization_owner','organization_administrator')
 or (r.key in ('athletic_director','program_administrator','sport_administrator','head_coach') and p.key in ('events.view','events.create','events.manage'))
 or (r.key in ('assistant_coach','team_administrator','team_staff') and p.key='events.view'));

create function boss_private.calendar_module_enabled(p_org uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organizations o join public.organization_modules om on om.organization_id=o.id
 join public.modules m on m.id=om.module_id where o.id=p_org and o.status='active' and m.key='calendar' and m.status='active'
 and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()))
$$;
create function boss_private.calendar_feature(p_org uuid,p_key text) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select case
  when jsonb_typeof(om.configuration->p_key)='boolean' then (om.configuration->>p_key)::boolean
  when om.configuration ? p_key then false
  else p_key=any(array['organization_calendar','team_calendar','recurrence','conflicts']) end
 from public.organization_modules om join public.modules m on m.id=om.module_id join public.organizations o on o.id=om.organization_id
 where om.organization_id=p_org and o.status='active' and m.key='calendar' and m.status='active' and om.status='active'
 and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()) order by om.starts_at desc limit 1),false)
 and p_key=any(array['organization_calendar','team_calendar','recurrence','conflicts','public_schedules','head_coach_management','conflict_overrides','attendance'])
$$;

create function boss_private.calendar_can_target(p_permission text,p_org uuid,p_type text,p_id uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare v_unit uuid;
begin
 if boss_private.current_person_id() is null or not boss_private.calendar_module_enabled(p_org) then return false; end if;
 if p_permission='events.override_conflict' and not boss_private.calendar_feature(p_org,'conflict_overrides') then return false; end if;
 if p_type='organization' then
  return p_id=p_org and boss_private.calendar_feature(p_org,'organization_calendar') and boss_private.has_permission(p_permission,p_org);
 elsif p_type='unit' then
  return boss_private.calendar_feature(p_org,'organization_calendar') and exists(select 1 from public.organization_units u
   where u.id=p_id and u.organization_id=p_org and u.status='active') and boss_private.has_permission(p_permission,p_org,p_id);
 elsif p_type='team' then
  select parent_unit_id into v_unit from public.teams where id=p_id and organization_id=p_org and status='active';
  if not found or not boss_private.calendar_feature(p_org,'team_calendar') then return false; end if;
  return boss_private.has_permission(p_permission,p_org,v_unit)
    or (boss_private.has_permission(p_permission,p_org,v_unit,p_id)
      and (p_permission not in ('events.create','events.manage') or boss_private.calendar_feature(p_org,'head_coach_management')));
 end if;
 return false;
end;
$$;
create function boss_private.calendar_can_manage_targets(p_permission text,p_org uuid,p_targets jsonb) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare v_target jsonb;
begin
 if jsonb_typeof(p_targets) is distinct from 'array' or jsonb_array_length(p_targets) not between 1 and 50 then return false; end if;
 for v_target in select value from jsonb_array_elements(p_targets) loop
  if jsonb_typeof(v_target) is distinct from 'object' or not (v_target ?& array['target_type','target_id'])
   or v_target->>'target_id' !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
   or not boss_private.calendar_can_target(p_permission,p_org,v_target->>'target_type',(v_target->>'target_id')::uuid) then return false; end if;
 end loop;
 return true;
end;
$$;
create function boss_private.calendar_can_manage_event(p_permission text,p_event_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.calendar_can_manage_targets(p_permission,e.organization_id,
  (select jsonb_agg(jsonb_build_object('target_type',t.target_type,'target_id',t.target_id)) from public.event_targets t where t.event_id=e.id))
 from public.events e where e.id=p_event_id),false)
$$;

-- A verified explicit guardian relationship grants schedule viewing only. No
-- household label, profile flag, follower status or editable JWT metadata does.
create function boss_private.calendar_person_related(p_person uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select boss_private.current_person_id() is not null and exists(select 1 from public.people p where p.id=p_person and p.status='active') and
 (p_person=boss_private.current_person_id() or exists(select 1 from public.guardian_relationships g
 where g.guardian_person_id=boss_private.current_person_id() and g.dependent_person_id=p_person
 and g.authority_status='active' and g.verified_at<=now() and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now())))
$$;
create function boss_private.calendar_team_related(p_team uuid,p_person uuid default null) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id and t.organization_id=m.organization_id
 join public.organizations o on o.id=t.organization_id join public.people p on p.id=m.person_id
 left join public.participants a on a.id=m.participant_id and a.person_id=m.person_id
 where m.team_id=p_team and t.status='active' and o.status='active' and p.status='active'
 and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())
 and (m.participant_id is null or a.status='active')
 and (p_person is null or m.person_id=p_person) and boss_private.calendar_person_related(m.person_id))
$$;
create function boss_private.calendar_target_related(p_org uuid,p_type text,p_id uuid,p_person uuid default null) returns boolean
language sql stable security definer set search_path='' as $$
 select case when p_type='team' then boss_private.calendar_feature(p_org,'team_calendar') and boss_private.calendar_team_related(p_id,p_person)
 when p_type='unit' then boss_private.calendar_feature(p_org,'organization_calendar') and exists(select 1 from public.teams t where t.organization_id=p_org and t.parent_unit_id=p_id and t.status='active'
  and boss_private.calendar_team_related(t.id,p_person))
 when p_type='organization' and p_id=p_org then boss_private.calendar_feature(p_org,'organization_calendar') and (
  (p_person is null and boss_private.has_active_organization_membership(p_org))
  or exists(select 1 from public.teams t where t.organization_id=p_org and t.status='active' and boss_private.calendar_team_related(t.id,p_person)))
 else false end
$$;
create function boss_private.calendar_can_view_event(p_event uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.current_person_id() is not null and boss_private.calendar_module_enabled(e.organization_id)
 and exists(select 1 from public.event_targets t where t.event_id=e.id and ((t.target_type in ('organization','unit') and boss_private.calendar_feature(e.organization_id,'organization_calendar')) or (t.target_type='team' and boss_private.calendar_feature(e.organization_id,'team_calendar')))) and (
  boss_private.has_permission('events.manage',e.organization_id)
  or boss_private.calendar_can_manage_event('events.manage',e.id)
  or (e.created_by_person_id=boss_private.current_person_id() and exists(select 1 from public.event_targets t where t.event_id=e.id
    and boss_private.calendar_can_target('events.view',e.organization_id,t.target_type,t.target_id)))
  or (e.status<>'draft' and e.visibility<>'private' and (
   boss_private.has_permission('events.view',e.organization_id)
   or (e.visibility in ('public','authenticated') and e.publication_state='published'
    and (e.visibility<>'public' or boss_private.calendar_feature(e.organization_id,'public_schedules')))
   or exists(select 1 from public.event_targets t where t.event_id=e.id
    and boss_private.calendar_can_target('events.view',e.organization_id,t.target_type,t.target_id))
   or (e.visibility='member' and exists(select 1 from public.event_targets t where t.event_id=e.id
    and boss_private.calendar_target_related(e.organization_id,t.target_type,t.target_id)))))
 ) from public.events e where e.id=p_event),false)
$$;

create function boss_private.calendar_valid_timezone(p_timezone text) returns boolean
language sql stable security invoker set search_path='' as $$
 select length(p_timezone)<=100 and exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone)
$$;

-- Pure, bounded recurrence engine. The anchor and end are wall-clock timestamps
-- in the selected IANA zone. Date candidates are sought near the requested window;
-- count-limited schedules rank at most five years of candidates, never unbounded history.
create function boss_private.calendar_expand(p_start timestamptz,p_end timestamptz,p_timezone text,p_rule jsonb,p_from timestamptz,p_to timestamptz)
returns table(occurrence_key text,start_at timestamptz,end_at timestamptz)
language plpgsql stable security invoker set search_path='' as $$
declare v_anchor timestamp;v_duration interval;v_freq text;v_interval integer;v_until date;v_count integer;
 v_weekdays integer[];v_week_anchor date;v_first date;v_last date;
begin
 if not isfinite(p_from) or not isfinite(p_to) or p_to<=p_from or p_to-p_from>interval '5 years 95 days'
  or not boss_private.calendar_valid_timezone(p_timezone) then raise exception 'Invalid operation' using errcode='PT422'; end if;
 v_anchor:=p_start at time zone p_timezone;v_duration:=(p_end at time zone p_timezone)-v_anchor;
 if p_rule is null then
  if p_start<p_to and p_end>p_from then
   occurrence_key:=to_char(v_anchor,'YYYY-MM-DD"T"HH24:MI:SS');start_at:=p_start;end_at:=p_end;return next;
  end if;
  return;
 end if;
 v_freq:=p_rule->>'frequency';v_interval:=coalesce((p_rule->>'interval')::integer,1);
 v_count:=(p_rule->>'count')::integer;v_until:=least(coalesce((p_rule->>'until')::date,(v_anchor+interval '5 years')::date),(v_anchor+interval '5 years')::date);
 if v_freq='weekly' then
  select coalesce(array_agg(value::integer),array[extract(isodow from v_anchor)::integer]) into v_weekdays
   from jsonb_array_elements_text(coalesce(p_rule->'weekdays','[]'::jsonb));
 end if;
 v_week_anchor:=date_trunc('week',v_anchor)::date;
 -- Only count-limited rules need the earlier valid-date rank. The maximum horizon
 -- is five years (1,828 daily dates), independent of tenant history or result range.
 v_first:=case when v_count is not null then v_anchor::date else greatest(v_anchor::date,((p_from at time zone p_timezone)-v_duration-interval '1 day')::date) end;
 v_last:=least(v_until,((p_to at time zone p_timezone)+interval '1 day')::date);
 return query
 with candidate_dates as (
  select d::date as day from pg_catalog.generate_series(v_first::timestamp,v_last::timestamp,interval '1 day') d
  where (v_freq='daily' and mod(d::date-v_anchor::date,v_interval)=0)
   or (v_freq='weekly' and mod((d::date-v_week_anchor)/7,v_interval)=0 and extract(isodow from d)::integer=any(v_weekdays))
   or (v_freq='monthly' and extract(day from d)=extract(day from v_anchor)
    and mod((extract(year from d)::integer-extract(year from v_anchor)::integer)*12+extract(month from d)::integer-extract(month from v_anchor)::integer,v_interval)=0)
 ), local_times as (
  select day+v_anchor::time as local_start,(day+v_anchor::time)+v_duration as local_end from candidate_dates
 ), valid_times as (
  select local_start,local_start at time zone p_timezone as instant_start,local_end at time zone p_timezone as instant_end
  from local_times where ((local_start at time zone p_timezone) at time zone p_timezone)=local_start
   and ((local_end at time zone p_timezone) at time zone p_timezone)=local_end
   and (local_end at time zone p_timezone)>(local_start at time zone p_timezone)
 ), ranked as (
  select *,row_number() over(order by local_start) as ordinal from valid_times
 )
 select to_char(local_start,'YYYY-MM-DD"T"HH24:MI:SS'),instant_start,instant_end from ranked
 where (v_count is null or ordinal<=v_count) and instant_start<p_to and instant_end>p_from order by instant_start;
end;
$$;

create function boss_private.calendar_schedule_integrity() returns trigger
language plpgsql security invoker set search_path='' as $$
declare v_key text;v_freq text;v_n integer;v_count integer;v_until date;v_local timestamp;v_end timestamptz;
begin
 if not boss_private.calendar_valid_timezone(new.timezone) then raise exception 'Invalid operation' using errcode='PT422'; end if;
 if tg_table_name='venues' then return new; end if;
 if extract(microseconds from new.start_at)::bigint%1000000<>0 or extract(microseconds from new.end_at)::bigint%1000000<>0 then
  raise exception 'Invalid operation' using errcode='PT422'; end if;
 v_local:=new.start_at at time zone new.timezone;
 if new.all_day and (v_local::time<>time '00:00' or (new.end_at at time zone new.timezone)::time<>time '00:00') then
  raise exception 'Invalid operation' using errcode='PT422'; end if;
 if new.recurrence is null then new.recurrence_end_at:=null;return new;end if;
 if (v_local at time zone new.timezone)<>new.start_at or ((new.end_at at time zone new.timezone) at time zone new.timezone)<>new.end_at then
  raise exception 'Invalid operation' using errcode='PT422'; end if;
 if jsonb_typeof(new.recurrence)<>'object' then raise exception 'Invalid operation' using errcode='PT422'; end if;
 for v_key in select jsonb_object_keys(new.recurrence) loop
  if v_key<>all(array['frequency','interval','weekdays','count','until']) then raise exception 'Invalid operation' using errcode='PT422'; end if;
 end loop;
 v_freq:=new.recurrence->>'frequency';
 if v_freq is null or v_freq<>all(array['daily','weekly','monthly']) or jsonb_typeof(new.recurrence->'frequency')<>'string'
  or (new.recurrence ? 'count')=(new.recurrence ? 'until') then raise exception 'Invalid operation' using errcode='PT422'; end if;
 if new.recurrence ? 'interval' and (jsonb_typeof(new.recurrence->'interval')<>'number' or new.recurrence->>'interval' !~ '^[0-9]{1,2}$') then
  raise exception 'Invalid operation' using errcode='PT422'; end if;
 v_n:=coalesce((new.recurrence->>'interval')::integer,1);
 if v_n not between 1 and 52 then raise exception 'Invalid operation' using errcode='PT422'; end if;
 if new.recurrence ? 'count' then
  if jsonb_typeof(new.recurrence->'count')<>'number' or new.recurrence->>'count' !~ '^[0-9]{1,4}$' then raise exception 'Invalid operation' using errcode='PT422'; end if;
  v_count:=(new.recurrence->>'count')::integer;
  if v_count not between 1 and 1000 then raise exception 'Invalid operation' using errcode='PT422'; end if;
 else
  if jsonb_typeof(new.recurrence->'until')<>'string' or new.recurrence->>'until' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise exception 'Invalid operation' using errcode='PT422'; end if;
  begin v_until:=(new.recurrence->>'until')::date; exception when others then raise exception 'Invalid operation' using errcode='PT422'; end;
  if v_until<v_local::date or v_until>(v_local+interval '5 years')::date then raise exception 'Invalid operation' using errcode='PT422'; end if;
 end if;
 if new.recurrence ? 'weekdays' then
  if v_freq<>'weekly' or jsonb_typeof(new.recurrence->'weekdays')<>'array' or jsonb_array_length(new.recurrence->'weekdays') not between 1 and 7
   or exists(select 1 from jsonb_array_elements(new.recurrence->'weekdays') x where jsonb_typeof(x)<>'number' or x::text !~ '^[1-7]$')
   or (select count(distinct x) from jsonb_array_elements(new.recurrence->'weekdays') x)<>jsonb_array_length(new.recurrence->'weekdays') then raise exception 'Invalid operation' using errcode='PT422'; end if;
 end if;
 new.recurrence:=new.recurrence||jsonb_build_object('interval',v_n);
 if v_freq='weekly' and not(new.recurrence ? 'weekdays') then
  new.recurrence:=new.recurrence||jsonb_build_object('weekdays',jsonb_build_array(extract(isodow from v_local)::integer));
 end if;
 select count(*),max(x.end_at) into v_n,v_end from boss_private.calendar_expand(new.start_at,new.end_at,new.timezone,new.recurrence,new.start_at,new.start_at+interval '5 years 1 day') x;
 if v_n=0 or (v_count is not null and v_n<>v_count) then raise exception 'Invalid operation' using errcode='PT422'; end if;
 new.recurrence_end_at:=v_end;
 return new;
end;
$$;
create trigger events_schedule_integrity before insert or update on public.events for each row execute function boss_private.calendar_schedule_integrity();
create trigger venues_timezone_integrity before insert or update on public.venues for each row execute function boss_private.calendar_schedule_integrity();

create function boss_private.calendar_occurrences(p_event public.events,p_from timestamptz,p_to timestamptz)
returns table(occurrence_key text,start_at timestamptz,end_at timestamptz,arrival_at timestamptz,status text,is_exception boolean,exception_id uuid,title text,instructions text)
language sql stable security invoker set search_path='' as $$
 with base as (
  select x.occurrence_key,x.start_at,x.end_at from boss_private.calendar_expand(p_event.start_at,p_event.end_at,p_event.timezone,p_event.recurrence,p_from,p_to) x
 ), merged as (
  select b.occurrence_key,coalesce(ex.override_start_at,b.start_at) as start_at,coalesce(ex.override_end_at,b.end_at) as end_at,
   case when ex.override_arrival_at is not null then ex.override_arrival_at when p_event.arrival_at is not null then
    coalesce(ex.override_start_at,b.start_at)-(p_event.start_at-p_event.arrival_at) end as arrival_at,
   case when p_event.status in ('draft','canceled','postponed','completed','archived') then p_event.status else coalesce(ex.status,p_event.status) end as status,ex.id is not null as is_exception,ex.id as exception_id,
   coalesce(ex.title,p_event.title) as title,coalesce(ex.instructions,p_event.instructions) as instructions
  from base b left join public.event_occurrence_exceptions ex on ex.event_id=p_event.id and ex.occurrence_key=b.occurrence_key and ex.is_active
  union all
  select ex.occurrence_key,ex.override_start_at,ex.override_end_at,
   coalesce(ex.override_arrival_at,case when p_event.arrival_at is not null then ex.override_start_at-(p_event.start_at-p_event.arrival_at) end),
   case when p_event.status in ('draft','canceled','postponed','completed','archived') then p_event.status else coalesce(ex.status,p_event.status) end,true,ex.id,coalesce(ex.title,p_event.title),coalesce(ex.instructions,p_event.instructions)
  from public.event_occurrence_exceptions ex where ex.event_id=p_event.id and ex.is_active and ex.override_start_at<p_to and ex.override_end_at>p_from
   and not exists(select 1 from base b where b.occurrence_key=ex.occurrence_key)
 ) select * from merged where start_at<p_to and end_at>p_from order by start_at,occurrence_key
$$;

create function boss_private.calendar_can_know_team(p_team uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.calendar_module_enabled(t.organization_id) and t.status='active'
  and boss_private.calendar_feature(t.organization_id,'team_calendar') and (boss_private.calendar_can_target('events.view',t.organization_id,'team',t.id)
    or boss_private.calendar_team_related(t.id)) from public.teams t where t.id=p_team),false)
$$;
create function boss_private.calendar_can_know_org(p_org uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select boss_private.calendar_module_enabled(p_org) and (boss_private.has_permission('events.view',p_org)
  or boss_private.has_active_organization_membership(p_org)
  or exists(select 1 from public.organization_units u where u.organization_id=p_org and u.status='active' and boss_private.has_permission('events.view',p_org,u.id))
  or exists(select 1 from public.teams t where t.organization_id=p_org and boss_private.calendar_can_know_team(t.id)))
$$;
create function boss_private.calendar_can_view_venue(p_venue uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.calendar_module_enabled(v.organization_id) and boss_private.current_person_id() is not null and
  (boss_private.has_permission('events.view',v.organization_id)
   or exists(select 1 from public.events e where e.venue_id=v.id and boss_private.calendar_can_view_event(e.id)
    and (v.is_public or boss_private.calendar_can_manage_event('events.manage',e.id)
     or exists(select 1 from public.event_targets t where t.event_id=e.id and
      (boss_private.calendar_can_target('events.view',e.organization_id,t.target_type,t.target_id)
       or boss_private.calendar_target_related(e.organization_id,t.target_type,t.target_id))))))
 from public.venues v where v.id=p_venue),false)
$$;
create function boss_private.calendar_auth_valid() returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
 perform boss_private.require_live_auth();return boss_private.current_person_id() is not null;
 exception when sqlstate 'PT401' then return false;
end;
$$;
create policy event_types_read on public.event_types for select to authenticated
 using ((select boss_private.calendar_auth_valid()));
create policy venues_read on public.venues for select to authenticated
 using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_view_venue(id));
create policy venue_resources_read on public.venue_resources for select to authenticated
 using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_view_venue(venue_id));
create policy events_read on public.events for select to authenticated
 using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_view_event(id));
create policy event_targets_read on public.event_targets for select to authenticated
 using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_view_event(event_id)
 and (target_type='organization' or boss_private.has_permission('events.view',organization_id) or boss_private.calendar_can_target('events.view',organization_id,target_type,target_id)
  or boss_private.calendar_target_related(organization_id,target_type,target_id)));
create policy event_game_details_read on public.event_game_details for select to authenticated
 using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_view_event(event_id));
create policy event_exceptions_read on public.event_occurrence_exceptions for select to authenticated
 using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_view_event(event_id)
  and (is_active or boss_private.calendar_can_manage_event('events.manage',event_id)));
create policy event_reminders_read on public.event_reminders for select to authenticated
 using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_view_event(event_id));
grant select on public.event_types,public.venues,public.venue_resources,public.events,public.event_targets,
 public.event_game_details,public.event_occurrence_exceptions,public.event_reminders to authenticated;
-- Migration/server owners alone write these records; no service credential is needed.
revoke all on function boss_private.calendar_module_enabled(uuid),boss_private.calendar_feature(uuid,text),
 boss_private.calendar_can_target(text,uuid,text,uuid),boss_private.calendar_can_manage_targets(text,uuid,jsonb),
 boss_private.calendar_can_manage_event(text,uuid),boss_private.calendar_person_related(uuid),boss_private.calendar_team_related(uuid,uuid),
 boss_private.calendar_target_related(uuid,text,uuid,uuid),boss_private.calendar_can_view_event(uuid),boss_private.calendar_valid_timezone(text),
 boss_private.calendar_expand(timestamptz,timestamptz,text,jsonb,timestamptz,timestamptz),boss_private.calendar_schedule_integrity(),
 boss_private.calendar_occurrences(public.events,timestamptz,timestamptz),boss_private.calendar_can_know_team(uuid),
 boss_private.calendar_can_know_org(uuid),boss_private.calendar_can_view_venue(uuid),boss_private.calendar_auth_valid()
 from public,anon,authenticated,service_role;
grant execute on function boss_private.calendar_auth_valid(),boss_private.calendar_can_view_event(uuid),
 boss_private.calendar_can_view_venue(uuid),boss_private.calendar_can_target(text,uuid,text,uuid),
 boss_private.calendar_target_related(uuid,text,uuid,uuid),boss_private.calendar_can_manage_event(text,uuid)
 to authenticated;

create function boss_private.calendar_can_read_event_details(p_event uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select boss_private.calendar_can_view_event(p_event) and exists(select 1 from public.events e where e.id=p_event and (
  boss_private.has_permission('events.view',e.organization_id)
  or boss_private.calendar_can_manage_event('events.manage',e.id)
  or exists(select 1 from public.event_targets t where t.event_id=e.id and
   (boss_private.calendar_can_target('events.view',e.organization_id,t.target_type,t.target_id)
    or boss_private.calendar_target_related(e.organization_id,t.target_type,t.target_id)))))
$$;
create function boss_private.calendar_can_view_resource(p_resource uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.calendar_can_view_venue(r.venue_id) and (r.is_public
  or boss_private.has_permission('events.view',r.organization_id)
  or exists(select 1 from public.events e where e.resource_id=r.id and boss_private.calendar_can_read_event_details(e.id)))
 from public.venue_resources r where r.id=p_resource),false)
$$;
revoke all on function boss_private.calendar_can_read_event_details(uuid),boss_private.calendar_can_view_resource(uuid) from public,anon,authenticated,service_role;
grant execute on function boss_private.calendar_can_read_event_details(uuid),boss_private.calendar_can_view_resource(uuid) to authenticated;
create function boss_private.calendar_read(p_query jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_from timestamptz;v_to timestamptz;v_view text;v_org uuid;v_unit uuid;v_team uuid;v_season uuid;v_child uuid;v_location uuid;v_type text;
 v_key text;v_value jsonb;v_result jsonb;v_orgs jsonb;v_units jsonb;v_teams jsonb;v_seasons jsonb;v_children jsonb;v_venues jsonb;v_resources jsonb;
 v_events jsonb;v_create_targets jsonb;v_features jsonb;v_count integer;v_actor uuid;v_options_limited boolean:=false;
begin
 v_actor:=boss_private.require_admin_actor();
 if jsonb_typeof(p_query) is distinct from 'object' or not(p_query ?& array['from','to']) then raise exception 'Invalid operation' using errcode='PT422';end if;
 for v_key,v_value in select key,value from jsonb_each(p_query) loop
  if v_key<>all(array['from','to','view','organization_id','unit_id','team_id','season_id','child_id','event_type_key','location_id'])
   or jsonb_typeof(v_value)<>'string' or length(v_value#>>'{}')>100 then raise exception 'Invalid operation' using errcode='PT422';end if;
  if v_key like '%_id' and v_value#>>'{}' !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then raise exception 'Invalid operation' using errcode='PT422'; end if;
 end loop;
 begin v_from:=(p_query->>'from')::timestamptz;v_to:=(p_query->>'to')::timestamptz;
  v_org:=(p_query->>'organization_id')::uuid;v_unit:=(p_query->>'unit_id')::uuid;v_team:=(p_query->>'team_id')::uuid;
  v_season:=(p_query->>'season_id')::uuid;v_child:=(p_query->>'child_id')::uuid;v_location:=(p_query->>'location_id')::uuid;
 exception when others then raise exception 'Invalid operation' using errcode='PT422';end;
 if not isfinite(v_from) or not isfinite(v_to) or v_to<=v_from or v_to-v_from>interval '93 days' then raise exception 'Invalid operation' using errcode='PT422';end if;
 v_view:=coalesce(p_query->>'view','personal');v_type:=p_query->>'event_type_key';
 if v_view<>all(array['personal','organization','team']) or (v_view='team' and v_team is null)
  or (v_type is not null and v_type !~ '^[a-z][a-z0-9_]*$') then raise exception 'Invalid operation' using errcode='PT422';end if;
 if v_child is not null and not boss_private.calendar_person_related(v_child) then raise exception 'Access denied' using errcode='PT403';end if;
 -- Allowed filter options are independently projected; choosing an ID grants no authority.
 select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'timezone',o.timezone) order by (o.id=v_org) desc nulls last,o.created_at desc,o.id),'[]') into v_orgs
 from (select o.* from public.organizations o where boss_private.calendar_can_know_org(o.id) order by (o.id=v_org) desc nulls last,o.created_at desc,o.id limit 101) o;
 if jsonb_array_length(v_orgs)>100 then
  v_options_limited:=true;select jsonb_agg(value order by ordinality) into v_orgs from jsonb_array_elements(v_orgs) with ordinality where ordinality<=100;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'organization_id',u.organization_id,'name',u.name) order by u.name,u.id),'[]') into v_units
 from (select u.* from public.organization_units u where (v_org is null or u.organization_id=v_org) and u.status='active' and ((v_org is not null and boss_private.calendar_can_target('events.view',u.organization_id,'unit',u.id)) or boss_private.calendar_target_related(u.organization_id,'unit',u.id)) limit 501) u where u.status='active' and (v_org is null or u.organization_id=v_org) and boss_private.calendar_module_enabled(u.organization_id)
  and ((v_org is not null and boss_private.calendar_can_target('events.view',u.organization_id,'unit',u.id))
   or boss_private.calendar_target_related(u.organization_id,'unit',u.id));
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'organization_id',t.organization_id,'parent_unit_id',t.parent_unit_id,'season_id',t.season_id,'name',t.name) order by t.name,t.id),'[]') into v_teams
 from (select t.* from public.teams t where (v_org is null or t.organization_id=v_org) and (v_unit is null or t.parent_unit_id=v_unit) and (v_org is not null or boss_private.calendar_team_related(t.id)) and boss_private.calendar_can_know_team(t.id) limit 501) t where (v_org is null or t.organization_id=v_org) and (v_unit is null or t.parent_unit_id=v_unit)
 and (v_org is not null or boss_private.calendar_team_related(t.id)) and boss_private.calendar_can_know_team(t.id);
 if jsonb_array_length(v_teams)>500 or jsonb_array_length(v_units)>500 then raise exception 'Choose a narrower calendar context' using errcode='PT422';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'organization_id',s.organization_id,'name',s.name) order by s.name,s.id),'[]') into v_seasons
 from (select s.* from public.seasons s where s.status='active' and (v_org is null or s.organization_id=v_org) and boss_private.calendar_module_enabled(s.organization_id)
  and ((v_org is not null and boss_private.has_permission('events.view',s.organization_id,s.parent_unit_id))
   or exists(select 1 from public.teams t where t.season_id=s.id and boss_private.calendar_can_know_team(t.id))) order by s.id limit 501) s;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',coalesce(p.display_name,p.preferred_name,p.first_name,'Participant')) order by p.display_name,p.id),'[]') into v_children
 from (select p.* from public.people p where p.id<>v_actor and boss_private.calendar_person_related(p.id)
  and exists(select 1 from public.participants a where a.person_id=p.id and a.status='active') order by p.id limit 101) p;
 if jsonb_array_length(v_children)>100 then raise exception 'Choose a narrower calendar context' using errcode='PT422';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',v.id,'organization_id',v.organization_id,'name',v.name,'timezone',v.timezone,'instructions',v.instructions,
  'address_line1',v.address_line1,'address_line2',v.address_line2,'city',v.city,'region',v.region,'postal_code',v.postal_code,'country_code',v.country_code,'is_public',v.is_public,'version',v.version,'status',v.status) order by v.name,v.id),'[]') into v_venues
 from (select v.* from public.venues v where (v.status='active' or (v.organization_id=v_org and boss_private.has_permission('events.manage',v_org))) and (v_org is null or v.organization_id=v_org) and boss_private.calendar_can_view_venue(v.id)
 and (v_org is not null or exists(select 1 from public.events e join public.event_targets t on t.event_id=e.id where e.venue_id=v.id and boss_private.calendar_target_related(e.organization_id,t.target_type,t.target_id))) order by v.id limit 501) v;
 if jsonb_array_length(v_venues)>500 then raise exception 'Choose a narrower calendar context' using errcode='PT422';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'organization_id',r.organization_id,'venue_id',r.venue_id,'name',r.name,'resource_type',r.resource_type,'is_public',r.is_public,'version',r.version,'status',r.status) order by r.name,r.id),'[]') into v_resources
 from (select r.* from public.venue_resources r where (r.status='active' or (r.organization_id=v_org and boss_private.has_permission('events.manage',v_org))) and (v_org is null or r.organization_id=v_org) and boss_private.calendar_can_view_resource(r.id)
 and (v_org is not null or exists(select 1 from public.events e join public.event_targets t on t.event_id=e.id where e.resource_id=r.id and boss_private.calendar_target_related(e.organization_id,t.target_type,t.target_id))) order by r.id limit 501) r;
 if jsonb_array_length(v_resources)>500 or jsonb_array_length(v_seasons)>500 then raise exception 'Choose a narrower calendar context' using errcode='PT422';end if;
 select coalesce(jsonb_agg(jsonb_build_object('target_type',z.target_type,'target_id',z.target_id,'label',z.label) order by z.target_type,z.label,z.target_id),'[]') into v_create_targets from (
  select 'organization'::text target_type,o.id target_id,o.name label from public.organizations o where o.id=v_org and boss_private.calendar_can_target('events.create',o.id,'organization',o.id)
  union all select 'unit',u.id,u.name from public.organization_units u where u.organization_id=v_org and u.id in(select (x->>'id')::uuid from jsonb_array_elements(v_units) x) and boss_private.calendar_can_target('events.create',v_org,'unit',u.id)
  union all select 'team',t.id,t.name from public.teams t where t.organization_id=v_org and t.id in(select (x->>'id')::uuid from jsonb_array_elements(v_teams) x) and boss_private.calendar_can_target('events.create',v_org,'team',t.id)
 ) z;
 select jsonb_object_agg(k,case when boss_private.calendar_can_know_org(v_org) then boss_private.calendar_feature(v_org,k) else false end) into v_features from unnest(array['organization_calendar','team_calendar','recurrence','public_schedules','conflicts','head_coach_management','conflict_overrides','attendance']) k;
 -- Filter canonical rows by tenant and date envelope before recurrence expansion.
 -- Exceptions rescheduled from another month are included through their own index.
 with candidates as materialized (
  select e.* from public.events e where (v_org is null or e.organization_id=v_org)
   and (v_type is null or e.event_type_key=v_type) and (v_location is null or e.venue_id=v_location)
   and ((e.start_at<v_to and coalesce(e.recurrence_end_at,e.end_at)>v_from)
    or exists(select 1 from public.event_occurrence_exceptions ex where ex.event_id=e.id and ex.is_active and ex.override_start_at<v_to and ex.override_end_at>v_from))
   and boss_private.calendar_can_view_event(e.id)
   and (v_view<>'personal' or e.created_by_person_id=v_actor or exists(select 1 from public.event_targets t where t.event_id=e.id and boss_private.calendar_target_related(e.organization_id,t.target_type,t.target_id,v_child)))
   and (v_child is null or exists(select 1 from public.event_targets t where t.event_id=e.id and boss_private.calendar_target_related(e.organization_id,t.target_type,t.target_id,v_child)))
   and (v_unit is null or exists(select 1 from public.event_targets t where t.event_id=e.id and
    ((t.target_type='unit' and t.target_id=v_unit) or (t.target_type='organization' and exists(select 1 from public.organization_units u where u.id=v_unit and u.organization_id=e.organization_id
      and (boss_private.calendar_can_target('events.view',e.organization_id,'unit',u.id) or boss_private.calendar_target_related(e.organization_id,'unit',u.id))))
     or (t.target_type='team' and exists(select 1 from public.teams tm where tm.id=t.target_id and tm.parent_unit_id=v_unit and boss_private.calendar_can_know_team(tm.id))))))
   and (v_team is null or (boss_private.calendar_can_know_team(v_team) and exists(select 1 from public.event_targets t join public.teams tm on tm.id=v_team and tm.organization_id=e.organization_id
     where t.event_id=e.id and (t.target_type='organization' or (t.target_type='unit' and t.target_id=tm.parent_unit_id) or (t.target_type='team' and t.target_id=tm.id)))))
   and (v_season is null or exists(select 1 from public.event_targets t join public.teams tm on tm.organization_id=e.organization_id and tm.season_id=v_season
    where t.event_id=e.id and boss_private.calendar_can_know_team(tm.id) and (t.target_type='organization' or (t.target_type='unit' and t.target_id=tm.parent_unit_id) or (t.target_type='team' and t.target_id=tm.id))))
 ), target_rows as (
  select t.event_id,jsonb_agg(jsonb_build_object('target_type',t.target_type,'target_id',t.target_id,'label',case t.target_type when 'organization' then o.name when 'unit' then u.name else tm.name end)
   order by t.target_type,t.target_id) as targets
  from public.event_targets t join candidates c on c.id=t.event_id join public.organizations o on o.id=t.organization_id
  left join public.organization_units u on u.id=t.unit_id left join public.teams tm on tm.id=t.team_id
  where t.target_type='organization' or boss_private.has_permission('events.view',t.organization_id) or boss_private.calendar_can_target('events.view',t.organization_id,t.target_type,t.target_id)
   or boss_private.calendar_target_related(t.organization_id,t.target_type,t.target_id)
  group by t.event_id
 ), reminder_rows as (
  select r.event_id,jsonb_agg(jsonb_build_object('minutes_before',r.minutes_before,'audience',r.audience,'enabled',r.enabled) order by r.minutes_before,r.id) as reminders
  from public.event_reminders r join candidates c on c.id=r.event_id group by r.event_id
 ), rows as (
  select e.id as event_id,x.start_at,x.occurrence_key,jsonb_build_object(
   'event_id',e.id,'organization_id',e.organization_id,'occurrence_key',x.occurrence_key,'start_at',x.start_at,'end_at',x.end_at,'arrival_at',case when boss_private.calendar_can_read_event_details(e.id) then x.arrival_at end,
   'timezone',e.timezone,'all_day',e.all_day,'title',x.title,'description',case when boss_private.calendar_can_read_event_details(e.id) then e.description end,'event_type_key',e.event_type_key,'status',x.status,
   'visibility',e.visibility,'publication_state',e.publication_state,'rsvp_mode',e.rsvp_mode,'instructions',case when boss_private.calendar_can_read_event_details(e.id) then x.instructions end,'audience',case when boss_private.calendar_can_read_event_details(e.id) then to_jsonb(e.audience) else '[]'::jsonb end,
   'venue_id',case when boss_private.calendar_can_view_venue(e.venue_id) then e.venue_id end,
   'resource_id',case when boss_private.calendar_can_view_resource(e.resource_id) then e.resource_id end,
   'targets',coalesce(t.targets,'[]'::jsonb),'game',case when g.event_id is not null then jsonb_build_object('opponent_team_id',
    case when boss_private.calendar_can_know_team(g.opponent_team_id) then g.opponent_team_id end,
    'external_opponent_name',g.external_opponent_name,'home_away',g.home_away,'game_status',g.game_status) end,
   'reminders',case when boss_private.calendar_can_read_event_details(e.id) then coalesce(r.reminders,'[]'::jsonb) else '[]'::jsonb end,'recurrence',e.recurrence,'is_exception',x.is_exception,'exception_id',x.exception_id,'version',e.version,
   'series_start_at',case when boss_private.calendar_can_manage_event('events.manage',e.id) then e.start_at end,
   'series_end_at',case when boss_private.calendar_can_manage_event('events.manage',e.id) then e.end_at end,
   'series_arrival_at',case when boss_private.calendar_can_manage_event('events.manage',e.id) then e.arrival_at end,
   'series_title',case when boss_private.calendar_can_manage_event('events.manage',e.id) then e.title end,
   'series_status',case when boss_private.calendar_can_manage_event('events.manage',e.id) then e.status end,
   'series_instructions',case when boss_private.calendar_can_manage_event('events.manage',e.id) then e.instructions end,
   'capabilities',jsonb_build_object('manage',boss_private.calendar_can_manage_event('events.manage',e.id),'publish',boss_private.calendar_can_manage_event('events.publish',e.id),
    'override_conflict',boss_private.calendar_can_manage_event('events.override_conflict',e.id))) as payload
  from candidates e cross join lateral boss_private.calendar_occurrences(e,v_from,v_to) x
  left join target_rows t on t.event_id=e.id left join reminder_rows r on r.event_id=e.id left join public.event_game_details g on g.event_id=e.id
  order by x.start_at,e.id,x.occurrence_key limit 1001
 ) select count(*),coalesce(jsonb_agg(payload order by start_at,event_id,occurrence_key),'[]'::jsonb) into v_count,v_events from rows;
 if v_count>1000 then raise exception 'Choose a smaller date range' using errcode='PT422';end if;
 v_result:=jsonb_build_object('range',jsonb_build_object('from',v_from,'to',v_to),'organizations',v_orgs,'units',v_units,'teams',v_teams,'seasons',v_seasons,
  'children',v_children,'options_limited',v_options_limited,'event_types',(select coalesce(jsonb_agg(jsonb_build_object('key',key,'name',name) order by name,key),'[]'::jsonb) from public.event_types where status='active'),
  'venues',v_venues,'resources',v_resources,'features',v_features,'occurrences',v_events,'capabilities',jsonb_build_object(
   'create',jsonb_array_length(v_create_targets)>0,'create_targets',v_create_targets,
   'manage_venues',v_org is not null and boss_private.calendar_module_enabled(v_org) and boss_private.has_permission('events.manage',v_org),
   'configure',v_org is not null and boss_private.calendar_module_enabled(v_org) and boss_private.has_permission('organization.manage',v_org),
   'publish',v_org is not null and boss_private.calendar_can_target('events.publish',v_org,'organization',v_org),
   'override_conflict',v_org is not null and boss_private.calendar_can_target('events.override_conflict',v_org,'organization',v_org)));
 return v_result;
end;
$$;
revoke all on function boss_private.calendar_read(jsonb) from public,anon,authenticated,service_role;
grant execute on function boss_private.calendar_read(jsonb) to authenticated;
create function public.boss_calendar_read(p_query jsonb) returns jsonb
language sql stable security invoker set search_path='' as $$select boss_private.calendar_read(p_query)$$;
revoke all on function public.boss_calendar_read(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.boss_calendar_read(jsonb) to authenticated;

-- Full rows are a member/scoped projection. General published schedules use a
-- whitelist, even for authenticated outsiders, and never expose private facilities.
alter policy events_read on public.events using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_read_event_details(id));
alter policy event_targets_read on public.event_targets using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_read_event_details(event_id)
 and (target_type='organization' or boss_private.has_permission('events.view',organization_id) or boss_private.calendar_can_target('events.view',organization_id,target_type,target_id) or boss_private.calendar_target_related(organization_id,target_type,target_id)));
alter policy event_game_details_read on public.event_game_details using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_read_event_details(event_id));
alter policy event_exceptions_read on public.event_occurrence_exceptions using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_read_event_details(event_id)
 and (is_active or boss_private.calendar_can_manage_event('events.manage',event_id)));
alter policy event_reminders_read on public.event_reminders using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_read_event_details(event_id));
alter policy venue_resources_read on public.venue_resources using ((select boss_private.calendar_auth_valid()) and boss_private.calendar_can_view_resource(id));

-- Anonymous callers never receive USAGE on boss_private. This separate, non-
-- exposed schema contains only the explicitly published, fixed-field schedule.
create schema boss_calendar_public authorization postgres;
revoke all on schema boss_calendar_public from public,anon,authenticated,service_role;
grant usage on schema boss_calendar_public to anon,authenticated;
grant usage on schema public to anon;
alter default privileges for role postgres in schema boss_calendar_public revoke all on tables from public,anon,authenticated,service_role;
alter default privileges for role postgres in schema boss_calendar_public revoke all on functions from public,anon,authenticated,service_role;
create function boss_calendar_public.read_schedule(p_query jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_org uuid;v_team uuid;v_location uuid;v_from timestamptz;v_to timestamptz;v_type text;v_key text;v_value jsonb;v_rows jsonb;v_count integer;
begin
 if jsonb_typeof(p_query) is distinct from 'object' or not(p_query ?& array['organization_id','from','to']) then raise exception 'Invalid operation' using errcode='PT422';end if;
 for v_key,v_value in select key,value from jsonb_each(p_query) loop
  if v_key<>all(array['organization_id','team_id','event_type_key','location_id','from','to']) or jsonb_typeof(v_value)<>'string'
   or length(v_value#>>'{}')>100 or (v_key like '%_id' and v_value#>>'{}' !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') then raise exception 'Invalid operation' using errcode='PT422';end if;
 end loop;
 begin v_org:=(p_query->>'organization_id')::uuid;v_team:=(p_query->>'team_id')::uuid;v_location:=(p_query->>'location_id')::uuid;
  v_from:=(p_query->>'from')::timestamptz;v_to:=(p_query->>'to')::timestamptz;
 exception when others then raise exception 'Invalid operation' using errcode='PT422';end;
 if not isfinite(v_from) or not isfinite(v_to) or v_to<=v_from or v_to-v_from>interval '93 days' then raise exception 'Invalid operation' using errcode='PT422';end if;
 v_type:=p_query->>'event_type_key';
 if v_type is not null and v_type !~ '^[a-z][a-z0-9_]*$' then raise exception 'Invalid operation' using errcode='PT422';end if;
 if not boss_private.calendar_feature(v_org,'public_schedules') or (v_team is not null and not exists(select 1 from public.teams t
  where t.id=v_team and t.organization_id=v_org and t.status='active' and t.visibility='public' and boss_private.calendar_feature(v_org,'team_calendar'))) then
  return jsonb_build_object('range',jsonb_build_object('from',v_from,'to',v_to),'occurrences','[]'::jsonb);
 end if;
 with candidates as materialized (
  select e.* from public.events e where e.organization_id=v_org and e.visibility='public' and e.publication_state='published' and e.status<>'draft'
   and exists(select 1 from public.event_targets et where et.event_id=e.id and ((et.target_type in ('organization','unit') and boss_private.calendar_feature(e.organization_id,'organization_calendar')) or (et.target_type='team' and boss_private.calendar_feature(e.organization_id,'team_calendar'))))
   and (v_type is null or e.event_type_key=v_type)
   and (v_location is null or (e.venue_id=v_location and exists(select 1 from public.venues v where v.id=v_location and v.is_public and v.status='active')))
   and ((e.start_at<v_to and coalesce(e.recurrence_end_at,e.end_at)>v_from) or exists(select 1 from public.event_occurrence_exceptions ex
    where ex.event_id=e.id and ex.is_active and ex.override_start_at<v_to and ex.override_end_at>v_from))
   and (v_team is null or exists(select 1 from public.event_targets t join public.teams tm on tm.id=v_team and tm.organization_id=e.organization_id
    where t.event_id=e.id and (t.target_type='organization' or (t.target_type='unit' and t.target_id=tm.parent_unit_id) or (t.target_type='team' and t.target_id=tm.id))))
 ), labels as (
  select t.event_id,jsonb_agg(jsonb_build_object('target_type',t.target_type,'target_id',t.target_id,'label',
   case when t.target_type='organization' then o.name else tm.name end) order by t.target_type,t.target_id) targets
  from public.event_targets t join candidates e on e.id=t.event_id join public.organizations o on o.id=t.organization_id
  left join public.teams tm on tm.id=t.team_id and tm.status='active' and tm.visibility='public'
  where t.target_type='organization' or (t.target_type='team' and tm.id is not null) group by t.event_id
 ), rows as (
  select e.id,x.start_at,x.occurrence_key,jsonb_build_object('event_id',e.id,'organization_id',e.organization_id,'title',x.title,
   'event_type_key',e.event_type_key,'occurrence_key',x.occurrence_key,'start_at',x.start_at,'end_at',x.end_at,'timezone',e.timezone,
   'all_day',e.all_day,'status',x.status,'targets',coalesce(l.targets,'[]'::jsonb),
   'venue',case when v.is_public and v.status='active' then jsonb_build_object('id',v.id,'name',v.name,'timezone',v.timezone) end,
   'resource',case when v.is_public and v.status='active' and r.is_public and r.status='active' then jsonb_build_object('id',r.id,'name',r.name) end,
   'game',case when g.event_id is not null then jsonb_build_object('external_opponent_name',g.external_opponent_name,'home_away',g.home_away,'game_status',g.game_status) end) payload
  from candidates e cross join lateral boss_private.calendar_occurrences(e,v_from,v_to) x left join labels l on l.event_id=e.id
  left join public.venues v on v.id=e.venue_id left join public.venue_resources r on r.id=e.resource_id left join public.event_game_details g on g.event_id=e.id
  order by x.start_at,e.id,x.occurrence_key limit 1001
 ) select count(*),coalesce(jsonb_agg(payload order by start_at,id,occurrence_key),'[]'::jsonb) into v_count,v_rows from rows;
 if v_count>1000 then raise exception 'Choose a smaller date range' using errcode='PT422';end if;
 return jsonb_build_object('range',jsonb_build_object('from',v_from,'to',v_to),'occurrences',v_rows);
end;
$$;
revoke all on function boss_calendar_public.read_schedule(jsonb) from public,anon,authenticated,service_role;
grant execute on function boss_calendar_public.read_schedule(jsonb) to anon,authenticated;
create function public.boss_calendar_public_read(p_query jsonb) returns jsonb
language sql stable security invoker set search_path='' as $$select boss_calendar_public.read_schedule(p_query)$$;
revoke all on function public.boss_calendar_public_read(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.boss_calendar_public_read(jsonb) to anon,authenticated;
