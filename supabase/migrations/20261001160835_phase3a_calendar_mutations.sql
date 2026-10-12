-- Finite calendar commands use the caller's live identity and current scoped
-- capability. Exposed tables remain read-only. Failed commands roll back their
-- event, associations, receipt and audit together.
create table boss_private.calendar_operation_receipts (
 actor_person_id uuid not null references public.people(id) on delete restrict,
 request_id uuid not null, input_hash bytea not null, command jsonb not null,
 result jsonb not null, created_at timestamptz not null default now(),
 primary key(actor_person_id,request_id),
 check(jsonb_typeof(command)='object'),check(jsonb_typeof(result)='object')
);
alter table boss_private.calendar_operation_receipts enable row level security;
revoke all on boss_private.calendar_operation_receipts from public,anon,authenticated,service_role;

create function boss_private.calendar_validate_input(i jsonb,allowed text[],required text[])
returns void language plpgsql immutable security invoker set search_path='' as $$
declare k text;v jsonb;t text;
begin
 if jsonb_typeof(i) is distinct from 'object' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
 for k,v in select key,value from jsonb_each(i) loop
  if not k=any(allowed) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  t:=jsonb_typeof(v);
  if t='null' then
   if k=any(required) or k not in ('description','arrival_at','venue_id','resource_id','instructions','recurrence','game','opponent_team_id','external_opponent_name','address_line1','address_line2','city','region','postal_code','country_code','override_arrival_at','title','status') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  elsif k like '%_id' then
   if t<>'string' or v#>>'{}' !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  elsif k in ('all_day','is_public','enabled','override_conflicts','reset_exceptions') then
   if t<>'boolean' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  elsif k in ('expected_version','minutes_before','interval','count') then
   if t<>'number' or v#>>'{}' !~ '^[0-9]{1,10}$' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  elsif k in ('targets','audience','reminders','weekdays') then
   if t<>'array' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  elsif k in ('recurrence','game','features','input') then
   if t<>'object' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  else
   if t<>'string' or length(v#>>'{}')>(case when k in ('description','instructions') then 4000 else 200 end) or (case when k in ('description','instructions') then regexp_replace(v#>>'{}', E'[\t\n\r]', '', 'g') else v#>>'{}' end) ~ '[[:cntrl:]]' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   if k in ('name','title','timezone','event_type_key','occurrence_key','operation','target_type') and length(btrim(v#>>'{}'))=0 then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   if k in ('start_at','end_at','arrival_at','override_start_at','override_end_at','override_arrival_at') then
    if v#>>'{}' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-][0-9]{2}:[0-9]{2})$' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
    perform (v#>>'{}')::timestamptz;
   end if;
  end if;
 end loop;
 foreach k in array required loop
  if not i?k or i->k='null'::jsonb then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
 end loop;
end;$$;
revoke all on function boss_private.calendar_validate_input(jsonb,text[],text[]) from public,anon,authenticated,service_role;

create function boss_private.calendar_validate_audience(a jsonb) returns text[]
language plpgsql immutable security invoker set search_path='' as $$
declare v text[];
begin
 if jsonb_typeof(a) is distinct from 'array' or jsonb_array_length(a) not between 1 and 7 or exists(select 1 from jsonb_array_elements(a) x where jsonb_typeof(x)<>'string' or x#>>'{}' not in ('organization','unit','team','staff','coaches','guardians','participants','public')) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
 select coalesce(array_agg(distinct x#>>'{}' order by x#>>'{}'),'{}'::text[]) into v from jsonb_array_elements(a) x;
 return v;
end;$$;
revoke all on function boss_private.calendar_validate_audience(jsonb) from public,anon,authenticated,service_role;

create function boss_private.calendar_validate_targets(org uuid,a jsonb) returns void
language plpgsql stable security definer set search_path='' as $$
declare t jsonb;v_target_id uuid;kind text;
begin
 if jsonb_typeof(a) is distinct from 'array' or jsonb_array_length(a) not between 1 and 50 then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
 if (select count(*) from jsonb_array_elements(a))<>(select count(distinct x) from jsonb_array_elements(a) x) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
 for t in select value from jsonb_array_elements(a) loop
  perform boss_private.calendar_validate_input(t,array['target_type','target_id'],array['target_type','target_id']);
  kind:=t->>'target_type';v_target_id:=(t->>'target_id')::uuid;
  if not ((kind='organization' and v_target_id=org and exists(select 1 from public.organizations o where o.id=org and o.status='active'))
    or (kind='unit' and exists(select 1 from public.organization_units u where u.id=v_target_id and u.organization_id=org and u.status='active'))
    or (kind='team' and exists(select 1 from public.teams t where t.id=v_target_id and t.organization_id=org and t.status='active'))) then raise exception 'Access denied' using errcode='PT403';end if;
 end loop;
end;$$;
revoke all on function boss_private.calendar_validate_targets(uuid,jsonb) from public,anon,authenticated,service_role;

-- The complete finite series is checked, rather than only the currently visible
-- month. Organization serialization prevents two concurrent schedulers from
-- both accepting a free resource. Hidden event details become a generic busy slot.
create function boss_private.calendar_conflicts(e public.events,targets jsonb,excluded uuid default null,p_apply_exceptions boolean default true)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_from timestamptz;v_to timestamptz;v_exception_start timestamptz;v_exception_end timestamptz;v_result jsonb;
begin
 if e.status not in ('scheduled','confirmed') or not boss_private.calendar_feature(e.organization_id,'conflicts') then return '[]'::jsonb;end if;
 v_from:=e.start_at;
 v_to:=case when e.recurrence is null then e.end_at else ((e.start_at at time zone e.timezone) + interval '5 years') at time zone e.timezone + (e.end_at-e.start_at) + interval '1 day' end;
 if p_apply_exceptions then
  select min(x.override_start_at),max(x.override_end_at) into v_exception_start,v_exception_end from public.event_occurrence_exceptions x where x.event_id=e.id and x.is_active;
  v_from:=least(v_from,v_exception_start);v_to:=greatest(v_to,v_exception_end);
 end if;
 with candidate as materialized (
  select o.start_at,o.end_at from boss_private.calendar_occurrences(e,v_from,v_to) o where p_apply_exceptions and o.status in ('scheduled','confirmed')
  union all select o.start_at,o.end_at from boss_private.calendar_expand(e.start_at,e.end_at,e.timezone,e.recurrence,v_from,v_to) o where not p_apply_exceptions
 ),
 target_teams as materialized (select (x->>'target_id')::uuid id from jsonb_array_elements(targets) x where x->>'target_type'='team'),
 related as materialized (
  select other.*,
   (e.resource_id is not null and e.resource_id=other.resource_id) resource_match,
   exists(select 1 from public.event_targets ot join target_teams t on t.id=ot.target_id where ot.event_id=other.id and ot.target_type='team') team_match,
   exists(select 1 from public.event_targets ot join public.team_memberships om on om.team_id=ot.target_id and om.organization_id=e.organization_id
    join public.team_memberships cm on cm.person_id=om.person_id and cm.organization_id=e.organization_id join target_teams ct on ct.id=cm.team_id
    join public.people p on p.id=om.person_id and p.status='active'
    where ot.event_id=other.id and ot.target_type='team' and om.status='active' and cm.status='active'
     and om.membership_type in ('coach','head_coach','assistant_coach') and cm.membership_type in ('coach','head_coach','assistant_coach')
     and om.starts_at<=now() and cm.starts_at<=now() and (om.ends_at is null or om.ends_at>now()) and (cm.ends_at is null or cm.ends_at>now())) coach_match,
   exists(select 1 from public.event_targets ot join public.team_memberships om on om.team_id=ot.target_id and om.organization_id=e.organization_id
    join public.team_memberships cm on cm.person_id=om.person_id and cm.organization_id=e.organization_id join target_teams ct on ct.id=cm.team_id
    join public.participants p on p.id=om.participant_id and p.person_id=om.person_id and p.status='active'
    where ot.event_id=other.id and ot.target_type='team' and om.status='active' and cm.status='active'
     and om.membership_type='athlete' and cm.membership_type='athlete' and om.starts_at<=now() and cm.starts_at<=now()
     and (om.ends_at is null or om.ends_at>now()) and (cm.ends_at is null or cm.ends_at>now())) participant_match
  from public.events other where other.organization_id=e.organization_id and other.id is distinct from excluded
   and other.status in ('scheduled','confirmed') and (other.start_at<v_to or exists(select 1 from public.event_occurrence_exceptions ex where ex.event_id=other.id and ex.is_active and ex.override_start_at<v_to))
   and (other.recurrence_end_at>v_from or other.end_at>v_from
    or exists(select 1 from public.event_occurrence_exceptions ex where ex.event_id=other.id and ex.is_active and ex.override_end_at>v_from))
 ), matches as (
  select r.id,r.title,o.start_at,o.end_at,
   case when r.resource_match then 'resource' when r.team_match then 'team' when r.coach_match then 'coach' else 'participant' end kind
  from related r cross join lateral boss_private.calendar_occurrences(jsonb_populate_record(null::public.events,to_jsonb(r)),v_from,v_to) o
  where (r.resource_match or r.team_match or r.coach_match or r.participant_match) and o.status in ('scheduled','confirmed')
   and exists(select 1 from candidate c where tstzrange(c.start_at,c.end_at,'[)') && tstzrange(o.start_at,o.end_at,'[)'))
 ) select coalesce(jsonb_agg(jsonb_build_object('kind',kind,'event_id',id,'title',title,'start_at',start_at,'end_at',end_at) order by start_at,id),'[]'::jsonb) into v_result from (select distinct * from matches limit 101) q;
 if jsonb_array_length(v_result)>100 then raise exception 'Calendar conflict review exceeds safe limit' using errcode='PT409';end if;
 return v_result;
end;$$;
revoke all on function boss_private.calendar_conflicts(public.events,jsonb,uuid,boolean) from public,anon,authenticated,service_role;

create function boss_private.calendar_safe_conflicts(c jsonb) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('kind',x->>'kind','event_id',case when boss_private.calendar_can_view_event((x->>'event_id')::uuid) then x->'event_id' else 'null'::jsonb end,
 'title',case when boss_private.calendar_can_view_event((x->>'event_id')::uuid) then x->>'title' else 'Busy' end,'start_at',x->'start_at','end_at',x->'end_at')),'[]'::jsonb) from jsonb_array_elements(c) x
$$;
revoke all on function boss_private.calendar_safe_conflicts(jsonb) from public,anon,authenticated,service_role;

create function boss_private.calendar_command(p_command jsonb,p_actor uuid,p_request uuid,p_preview boolean default false,p_replay boolean default false,p_resource uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 op text;i jsonb;k text;j jsonb;v_org uuid;v_id uuid:=coalesce(p_resource,gen_random_uuid());v_kind text;
 v_event public.events%rowtype;old_event public.events%rowtype;v_venue public.venues%rowtype;v_resource public.venue_resources%rowtype;
 old_exception public.event_occurrence_exceptions%rowtype;v_targets jsonb;v_old_targets jsonb;v_conflicts jsonb:='[]'::jsonb;
 v_version bigint;v_before jsonb;v_after jsonb;v_module uuid;v_features jsonb;v_changed_timing boolean;v_reset_count integer:=0;
 v_key timestamp;v_original record;v_can_override boolean:=false;v_occurrence_count integer;v_conflict_event public.events%rowtype;
begin
 if p_actor is distinct from boss_private.current_person_id() then raise exception 'Access denied' using errcode='PT403';end if;
 perform boss_private.calendar_validate_input(p_command,array['operation','input'],array['operation','input']);
 if jsonb_typeof(p_command->'input') is distinct from 'object' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
 op:=p_command->>'operation';i:=p_command->'input';
 if op in ('event.create','event.update') then
  perform boss_private.calendar_validate_input(i,array['organization_id','event_id','expected_version','title','description','event_type_key','start_at','end_at','timezone','all_day','arrival_at','status','visibility','publication_state','venue_id','resource_id','instructions','rsvp_mode','audience','recurrence','targets','reminders','game','override_conflicts','reset_exceptions'],array['organization_id','title','event_type_key','start_at','end_at','timezone','targets']);
  if op='event.create' and (i?'event_id' or i?'expected_version' or i?'reset_exceptions') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if op='event.update' and (not i?'event_id' or not i?'expected_version') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  v_org:=(i->>'organization_id')::uuid;v_targets:=i->'targets';
  perform boss_private.calendar_validate_targets(v_org,v_targets);
  if not boss_private.calendar_can_manage_targets(case when op='event.create' then 'events.create' else 'events.manage' end,v_org,v_targets) then raise exception 'Access denied' using errcode='PT403';end if;
  if op='event.update' then
   v_id:=(i->>'event_id')::uuid;
   select * into old_event from public.events where id=v_id and organization_id=v_org for update;
   if not found or not boss_private.calendar_can_manage_event('events.manage',v_id) then raise exception 'Access denied' using errcode='PT403';end if;
   if not p_replay and old_event.version<>(i->>'expected_version')::bigint then raise exception 'Calendar changed; reload before saving' using errcode='PT409';end if;
  elsif p_replay and not boss_private.calendar_can_manage_event('events.create',v_id) then raise exception 'Access denied' using errcode='PT403';end if;
  v_event.id:=v_id;v_event.organization_id:=v_org;v_event.title:=btrim(i->>'title');v_event.description:=i->>'description';v_event.event_type_key:=i->>'event_type_key';v_event.start_at:=(i->>'start_at')::timestamptz;v_event.end_at:=(i->>'end_at')::timestamptz;v_event.timezone:=i->>'timezone';
  v_event.all_day:=coalesce((i->>'all_day')::boolean,false);v_event.arrival_at:=(i->>'arrival_at')::timestamptz;v_event.status:=coalesce(i->>'status','scheduled');v_event.visibility:=coalesce(i->>'visibility','member');v_event.publication_state:=coalesce(i->>'publication_state','unpublished');v_event.venue_id:=(i->>'venue_id')::uuid;v_event.resource_id:=(i->>'resource_id')::uuid;v_event.instructions:=i->>'instructions';v_event.rsvp_mode:=coalesce(i->>'rsvp_mode','not_required');v_event.audience:=boss_private.calendar_validate_audience(coalesce(i->'audience','["guardians","participants"]'::jsonb));v_event.recurrence:=nullif(i->'recurrence','null'::jsonb);
  if v_event.end_at<=v_event.start_at or v_event.end_at-v_event.start_at>interval '31 days' or v_event.status not in ('draft','scheduled','confirmed','canceled','postponed','completed','archived') or v_event.visibility not in ('public','authenticated','member','restricted','private') or v_event.publication_state not in ('unpublished','published') or v_event.rsvp_mode not in ('not_required','optional','required') or not exists(select 1 from pg_catalog.pg_timezone_names where name=v_event.timezone) or not exists(select 1 from public.event_types t where t.key=v_event.event_type_key and t.status='active') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if v_event.arrival_at is not null and (v_event.arrival_at>v_event.start_at or v_event.start_at-v_event.arrival_at>interval '7 days') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if v_event.all_day and ((v_event.start_at at time zone v_event.timezone)::time<>time '00:00' or (v_event.end_at at time zone v_event.timezone)::time<>time '00:00') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if v_event.venue_id is not null and not exists(select 1 from public.venues v where v.id=v_event.venue_id and v.organization_id=v_org and v.status='active') then raise exception 'Access denied' using errcode='PT403';end if;
  if v_event.resource_id is not null and not exists(select 1 from public.venue_resources r where r.id=v_event.resource_id and r.organization_id=v_org and r.venue_id=v_event.venue_id and r.status='active') then raise exception 'Access denied' using errcode='PT403';end if;
  if v_event.recurrence is not null then
   if not boss_private.calendar_feature(v_org,'recurrence') then raise exception 'Access denied' using errcode='PT403';end if;
   perform boss_private.calendar_validate_input(v_event.recurrence,array['frequency','interval','weekdays','until','count'],array['frequency','interval']);
   if v_event.recurrence->>'frequency' not in ('daily','weekly','monthly') or (v_event.recurrence->>'interval')::integer not between 1 and 52 or (v_event.recurrence?'count')=(v_event.recurrence?'until') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   if v_event.recurrence?'count' and (v_event.recurrence->>'count')::integer not between 1 and 1000 then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   if v_event.recurrence?'until' and (v_event.recurrence->>'until' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' or (v_event.recurrence->>'until')::date<(v_event.start_at at time zone v_event.timezone)::date or (v_event.recurrence->>'until')::date>((v_event.start_at at time zone v_event.timezone)+interval '5 years')::date) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   if v_event.recurrence?'weekdays' and (v_event.recurrence->>'frequency'<>'weekly' or jsonb_array_length(v_event.recurrence->'weekdays') not between 1 and 7 or exists(select 1 from jsonb_array_elements(v_event.recurrence->'weekdays') d where jsonb_typeof(d)<>'number' or d#>>'{}' !~ '^[1-7]$') or (select count(distinct d) from jsonb_array_elements(v_event.recurrence->'weekdays') d)<>jsonb_array_length(v_event.recurrence->'weekdays')) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  end if;
  if v_event.recurrence->>'frequency'='weekly' and not(v_event.recurrence?'weekdays') then v_event.recurrence:=v_event.recurrence||jsonb_build_object('weekdays',jsonb_build_array(extract(isodow from v_event.start_at at time zone v_event.timezone)::integer));end if;
  -- Validate the complete bounded recurrence during preview as well as commit.
  -- Impossible count limits cannot produce a misleading successful preview.
  select count(*) into v_occurrence_count from boss_private.calendar_expand(v_event.start_at,v_event.end_at,v_event.timezone,v_event.recurrence,v_event.start_at,v_event.start_at+interval '5 years 1 day');
  if v_occurrence_count=0 or (v_event.recurrence?'count' and v_occurrence_count<>(v_event.recurrence->>'count')::integer) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if v_event.publication_state='published' or (op='event.update' and old_event.publication_state='published') then
   if not boss_private.calendar_feature(v_org,'public_schedules') or not boss_private.calendar_can_manage_targets('events.publish',v_org,v_targets) or (op='event.update' and not boss_private.calendar_can_manage_event('events.publish',v_id)) then raise exception 'Access denied' using errcode='PT403';end if;
  end if;
  if v_event.publication_state='published' and (v_event.visibility not in ('public','authenticated') or v_event.status in ('draft','archived')) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if i?'reminders' then
   if jsonb_array_length(i->'reminders')>8 then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   for j in select value from jsonb_array_elements(i->'reminders') loop
    perform boss_private.calendar_validate_input(j,array['minutes_before','audience','enabled'],array['minutes_before','audience','enabled']);
    if (j->>'minutes_before')::integer not between 0 and 10080 then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
    perform boss_private.calendar_validate_audience(j->'audience');
   end loop;
  end if;
  if i->'game' is not null and i->'game'<>'null'::jsonb then
   j:=i->'game';perform boss_private.calendar_validate_input(j,array['opponent_team_id','external_opponent_name','home_away','game_status'],array['home_away','game_status']);
   if v_event.event_type_key<>'game' or j->>'home_away' not in ('home','away','neutral') or j->>'game_status' not in ('scheduled','postponed','canceled','completed') or (j->>'opponent_team_id' is not null and j->>'external_opponent_name' is not null) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   if j->>'opponent_team_id' is not null and not exists(select 1 from public.teams t where t.id=(j->>'opponent_team_id')::uuid and t.organization_id=v_org and t.status='active') then raise exception 'Access denied' using errcode='PT403';end if;
  end if;
  v_changed_timing:=op='event.update' and (old_event.start_at is distinct from v_event.start_at or old_event.end_at is distinct from v_event.end_at or old_event.timezone is distinct from v_event.timezone or old_event.recurrence is distinct from v_event.recurrence);
  if not p_replay and v_changed_timing and exists(select 1 from public.event_occurrence_exceptions x where x.event_id=v_id and x.is_active) and not coalesce((i->>'reset_exceptions')::boolean,false) then raise exception 'Series changes require explicit exception reset' using errcode='PT409';end if;
  if p_replay then return jsonb_build_object('resource_type','event','resource_id',v_id);end if;
  v_can_override:=boss_private.calendar_can_manage_targets('events.override_conflict',v_org,v_targets);
  if not p_preview then update public.organizations set updated_at=updated_at where id=v_org;end if;
  v_conflicts:=boss_private.calendar_conflicts(v_event,v_targets,case when op='event.update' then v_id end,not v_changed_timing or not coalesce((i->>'reset_exceptions')::boolean,false));
  if p_preview then return jsonb_build_object('conflicts',boss_private.calendar_safe_conflicts(v_conflicts),'has_conflicts',jsonb_array_length(v_conflicts)>0,'can_override',v_can_override);end if;
  if coalesce((i->>'override_conflicts')::boolean,false) and not v_can_override then raise exception 'Access denied' using errcode='PT403';end if;
  if jsonb_array_length(v_conflicts)>0 and not coalesce((i->>'override_conflicts')::boolean,false) then raise exception 'Calendar conflict requires authorized review' using errcode='PT409';end if;
  v_before:=case when op='event.update' then jsonb_build_object('start_at',old_event.start_at,'end_at',old_event.end_at,'status',old_event.status,'visibility',old_event.visibility,'publication_state',old_event.publication_state,'recurrence',old_event.recurrence,'version',old_event.version) end;
  v_version:=coalesce(old_event.version,0)+1;
  if op='event.create' then
   insert into public.events(id,organization_id,title,description,event_type_key,start_at,end_at,timezone,all_day,arrival_at,status,visibility,publication_state,venue_id,resource_id,instructions,rsvp_mode,audience,recurrence,created_by_person_id,updated_by_person_id,version,published_at,archived_at)
   values(v_id,v_org,v_event.title,v_event.description,v_event.event_type_key,v_event.start_at,v_event.end_at,v_event.timezone,v_event.all_day,v_event.arrival_at,v_event.status,v_event.visibility,v_event.publication_state,v_event.venue_id,v_event.resource_id,v_event.instructions,v_event.rsvp_mode,v_event.audience,v_event.recurrence,p_actor,p_actor,v_version,case when v_event.publication_state='published' then now() end,case when v_event.status='archived' then now() end);
  else
   select coalesce(jsonb_agg(jsonb_build_object('target_type',t.target_type,'target_id',t.target_id) order by t.target_type,t.target_id),'[]'::jsonb) into v_old_targets from public.event_targets t where t.event_id=v_id;
   v_before:=v_before||jsonb_build_object('targets',v_old_targets);
   if v_changed_timing and coalesce((i->>'reset_exceptions')::boolean,false) then
    update public.event_occurrence_exceptions set is_active=false,updated_by_person_id=p_actor,updated_at=now(),version=version+1 where event_id=v_id and is_active;
    get diagnostics v_reset_count=row_count;
   end if;
   update public.events set title=v_event.title,description=v_event.description,event_type_key=v_event.event_type_key,start_at=v_event.start_at,end_at=v_event.end_at,timezone=v_event.timezone,all_day=v_event.all_day,arrival_at=v_event.arrival_at,status=v_event.status,visibility=v_event.visibility,publication_state=v_event.publication_state,venue_id=v_event.venue_id,resource_id=v_event.resource_id,instructions=v_event.instructions,rsvp_mode=v_event.rsvp_mode,audience=v_event.audience,recurrence=v_event.recurrence,updated_by_person_id=p_actor,updated_at=now(),version=v_version,published_at=case when v_event.publication_state='published' then coalesce(published_at,now()) else null end,archived_at=case when v_event.status='archived' then coalesce(archived_at,now()) else archived_at end where id=v_id;
   delete from public.event_targets where event_id=v_id;delete from public.event_reminders where event_id=v_id;delete from public.event_game_details where event_id=v_id;
  end if;
  insert into public.event_targets(event_id,organization_id,target_type,target_id) select v_id,v_org,x->>'target_type',(x->>'target_id')::uuid from jsonb_array_elements(v_targets) x;
  insert into public.event_reminders(event_id,organization_id,minutes_before,audience,enabled) select v_id,v_org,(x->>'minutes_before')::integer,boss_private.calendar_validate_audience(x->'audience'),(x->>'enabled')::boolean from jsonb_array_elements(coalesce(i->'reminders','[]'::jsonb)) x;
  if i->'game' is not null and i->'game'<>'null'::jsonb then
   j:=i->'game';insert into public.event_game_details(event_id,organization_id,opponent_team_id,external_opponent_name,home_away,game_status) values(v_id,v_org,(j->>'opponent_team_id')::uuid,j->>'external_opponent_name',j->>'home_away',j->>'game_status');
  end if;
  v_kind:='event';
  v_after:=jsonb_build_object('start_at',v_event.start_at,'end_at',v_event.end_at,'status',v_event.status,'visibility',v_event.visibility,'publication_state',v_event.publication_state,'recurrence',v_event.recurrence,'targets',v_targets,'version',v_version,'exceptions_archived',v_reset_count);
 elsif op='event.exception' then
  perform boss_private.calendar_validate_input(i,array['event_id','expected_version','occurrence_key','override_start_at','override_end_at','override_arrival_at','status','title','instructions','override_conflicts'],array['event_id','expected_version','occurrence_key']);
  v_id:=(i->>'event_id')::uuid;select * into old_event from public.events where id=v_id for update;
  if not found or not boss_private.calendar_can_manage_event('events.manage',v_id) then raise exception 'Access denied' using errcode='PT403';end if;
  v_org:=old_event.organization_id;
  if old_event.recurrence is null or not boss_private.calendar_feature(v_org,'recurrence') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if not p_replay and old_event.version<>(i->>'expected_version')::bigint then raise exception 'Calendar changed; reload before saving' using errcode='PT409';end if;
  if i->>'occurrence_key' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  v_key:=(i->>'occurrence_key')::timestamp;
  select * into v_original from boss_private.calendar_expand(old_event.start_at,old_event.end_at,old_event.timezone,old_event.recurrence,(v_key at time zone old_event.timezone)-interval '1 day',(v_key at time zone old_event.timezone)+interval '32 days') o where o.occurrence_key=i->>'occurrence_key';
  if not found then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  select * into old_exception from public.event_occurrence_exceptions x where x.event_id=v_id and x.occurrence_key=i->>'occurrence_key' and x.is_active;
  v_event:=old_event;v_event.start_at:=coalesce((i->>'override_start_at')::timestamptz,old_exception.override_start_at,v_original.start_at);v_event.end_at:=coalesce((i->>'override_end_at')::timestamptz,old_exception.override_end_at,v_original.end_at);v_event.recurrence:=null;v_event.status:=coalesce(i->>'status',old_exception.status,old_event.status);
  if v_event.end_at<=v_event.start_at or v_event.end_at-v_event.start_at>interval '31 days' or v_event.status not in ('scheduled','confirmed','canceled','postponed','completed') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  -- Durable exceptions stay inside a finite review window: up to 31 days before
  -- the series anchor and five years after it (end may extend a further 31 days).
  if v_event.start_at<old_event.start_at-interval '31 days' or v_event.start_at>old_event.start_at+interval '5 years' or v_event.end_at>old_event.start_at+interval '5 years 31 days' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if old_event.all_day and ((v_event.start_at at time zone old_event.timezone)::time<>time '00:00' or (v_event.end_at at time zone old_event.timezone)::time<>time '00:00') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  v_event.arrival_at:=case when i?'override_arrival_at' then coalesce((i->>'override_arrival_at')::timestamptz,case when old_event.arrival_at is not null then v_event.start_at-(old_event.start_at-old_event.arrival_at) end) else coalesce(old_exception.override_arrival_at,case when old_event.arrival_at is not null then v_event.start_at-(old_event.start_at-old_event.arrival_at) end) end;
  if v_event.arrival_at is not null and (v_event.arrival_at>v_event.start_at or v_event.start_at-v_event.arrival_at>interval '7 days') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if old_event.publication_state='published' and not boss_private.calendar_can_manage_event('events.publish',v_id) then raise exception 'Access denied' using errcode='PT403';end if;
  if p_replay then return jsonb_build_object('resource_type','event','resource_id',v_id);end if;
  select jsonb_agg(jsonb_build_object('target_type',target_type,'target_id',target_id) order by target_type,target_id) into v_targets from public.event_targets where event_id=v_id;
  v_can_override:=boss_private.calendar_can_manage_targets('events.override_conflict',v_org,v_targets);
  if not p_preview then update public.organizations set updated_at=updated_at where id=v_org;end if;
  v_conflict_event:=v_event;
  if old_event.status in ('draft','canceled','postponed','completed','archived') then v_conflict_event.status:=old_event.status;end if;
  v_conflicts:=boss_private.calendar_conflicts(v_conflict_event,v_targets,v_id,false);
  -- A rescheduled exception may also collide with another slot of its own series.
  if v_conflict_event.status in ('scheduled','confirmed') and boss_private.calendar_feature(v_org,'conflicts') and exists(select 1 from boss_private.calendar_occurrences(old_event,v_event.start_at-interval '31 days',v_event.end_at+interval '1 day') o where o.occurrence_key<>i->>'occurrence_key' and o.status in ('scheduled','confirmed') and tstzrange(o.start_at,o.end_at,'[)') && tstzrange(v_event.start_at,v_event.end_at,'[)')) then
   v_conflicts:=v_conflicts||jsonb_build_array(jsonb_build_object('kind','team','event_id',v_id,'title',old_event.title,'start_at',v_event.start_at,'end_at',v_event.end_at));
  end if;
  if p_preview then return jsonb_build_object('conflicts',boss_private.calendar_safe_conflicts(v_conflicts),'has_conflicts',jsonb_array_length(v_conflicts)>0,'can_override',v_can_override);end if;
  if coalesce((i->>'override_conflicts')::boolean,false) and not v_can_override then raise exception 'Access denied' using errcode='PT403';end if;
  if jsonb_array_length(v_conflicts)>0 and not coalesce((i->>'override_conflicts')::boolean,false) then raise exception 'Calendar conflict requires authorized review' using errcode='PT409';end if;
  v_before:=jsonb_build_object('occurrence_key',i->>'occurrence_key','start_at',coalesce(old_exception.override_start_at,v_original.start_at),'end_at',coalesce(old_exception.override_end_at,v_original.end_at),'status',coalesce(old_exception.status,old_event.status),'version',old_event.version);
  if old_exception.id is not null then
   update public.event_occurrence_exceptions set override_start_at=v_event.start_at,override_end_at=v_event.end_at,override_arrival_at=case when i?'override_arrival_at' then (i->>'override_arrival_at')::timestamptz else old_exception.override_arrival_at end,status=v_event.status,title=case when i?'title' then i->>'title' else old_exception.title end,instructions=case when i?'instructions' then i->>'instructions' else old_exception.instructions end,updated_by_person_id=p_actor,updated_at=now(),version=version+1 where id=old_exception.id;
  else
   insert into public.event_occurrence_exceptions(event_id,organization_id,occurrence_key,override_start_at,override_end_at,override_arrival_at,status,title,instructions,created_by_person_id,updated_by_person_id) values(v_id,v_org,i->>'occurrence_key',v_event.start_at,v_event.end_at,(i->>'override_arrival_at')::timestamptz,v_event.status,i->>'title',i->>'instructions',p_actor,p_actor);
  end if;
  v_version:=old_event.version+1;update public.events set version=v_version,updated_at=now(),updated_by_person_id=p_actor where id=v_id;
  v_kind:='event';v_after:=jsonb_build_object('occurrence_key',i->>'occurrence_key','start_at',v_event.start_at,'end_at',v_event.end_at,'status',v_event.status,'version',v_version);
 elsif op in ('venue.create','venue.update') then
  perform boss_private.calendar_validate_input(i,array['organization_id','venue_id','expected_version','name','address_line1','address_line2','city','region','postal_code','country_code','timezone','instructions','status','is_public'],array['organization_id','name','timezone']);
  v_org:=(i->>'organization_id')::uuid;
  if not boss_private.calendar_can_target('events.manage',v_org,'organization',v_org) then raise exception 'Access denied' using errcode='PT403';end if;
  if op='venue.update' then
   if not i?'venue_id' or not i?'expected_version' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   v_id:=(i->>'venue_id')::uuid;select * into v_venue from public.venues where id=v_id and organization_id=v_org for update;
   if not found then raise exception 'Access denied' using errcode='PT403';end if;
   if not p_replay and v_venue.version<>(i->>'expected_version')::bigint then raise exception 'Calendar changed; reload before saving' using errcode='PT409';end if;
  elsif i?'venue_id' or i?'expected_version' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if coalesce(i->>'status','active') not in ('active','inactive') or not exists(select 1 from pg_catalog.pg_timezone_names where name=i->>'timezone') or (coalesce((i->>'is_public')::boolean,false) and (not boss_private.calendar_feature(v_org,'public_schedules') or not boss_private.calendar_can_target('events.publish',v_org,'organization',v_org))) or (op='venue.update' and v_venue.is_public and not boss_private.calendar_can_target('events.publish',v_org,'organization',v_org)) then raise exception 'Access denied' using errcode='PT403';end if;
  if p_replay then return jsonb_build_object('resource_type','venue','resource_id',v_id);end if;
  if p_preview then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  update public.organizations set updated_at=updated_at where id=v_org;
  v_version:=coalesce(v_venue.version,0)+1;
  if op='venue.create' then
   insert into public.venues(id,organization_id,name,address_line1,address_line2,city,region,postal_code,country_code,timezone,instructions,status,is_public,created_by_person_id,updated_by_person_id,version) values(v_id,v_org,btrim(i->>'name'),i->>'address_line1',i->>'address_line2',i->>'city',i->>'region',i->>'postal_code',i->>'country_code',i->>'timezone',i->>'instructions',coalesce(i->>'status','active'),coalesce((i->>'is_public')::boolean,false),p_actor,p_actor,v_version);
  else
   update public.venues set name=btrim(i->>'name'),address_line1=i->>'address_line1',address_line2=i->>'address_line2',city=i->>'city',region=i->>'region',postal_code=i->>'postal_code',country_code=i->>'country_code',timezone=i->>'timezone',instructions=i->>'instructions',status=coalesce(i->>'status','active'),is_public=coalesce((i->>'is_public')::boolean,false),updated_by_person_id=p_actor,updated_at=now(),version=v_version where id=v_id;
  end if;
  v_kind:='venue';v_after:=jsonb_build_object('status',coalesce(i->>'status','active'),'is_public',coalesce((i->>'is_public')::boolean,false),'version',v_version);
 elsif op in ('resource.create','resource.update') then
  perform boss_private.calendar_validate_input(i,array['organization_id','resource_id','venue_id','expected_version','name','resource_type','status','is_public'],array['organization_id','venue_id','name','resource_type']);
  v_org:=(i->>'organization_id')::uuid;
  if not boss_private.calendar_can_target('events.manage',v_org,'organization',v_org) then raise exception 'Access denied' using errcode='PT403';end if;
  if op='resource.update' then
   if not i?'resource_id' or not i?'expected_version' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   v_id:=(i->>'resource_id')::uuid;select * into v_resource from public.venue_resources where id=v_id and organization_id=v_org for update;
   if not found then raise exception 'Access denied' using errcode='PT403';end if;
   if not p_replay and v_resource.version<>(i->>'expected_version')::bigint then raise exception 'Calendar changed; reload before saving' using errcode='PT409';end if;
   if v_resource.venue_id<>(i->>'venue_id')::uuid then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  elsif i?'resource_id' or i?'expected_version' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if not exists(select 1 from public.venues v where v.id=(i->>'venue_id')::uuid and v.organization_id=v_org and v.status='active') then raise exception 'Access denied' using errcode='PT403';end if;
  if coalesce(i->>'status','active') not in ('active','inactive') or (coalesce((i->>'is_public')::boolean,false) and (not boss_private.calendar_feature(v_org,'public_schedules') or not boss_private.calendar_can_target('events.publish',v_org,'organization',v_org))) or (op='resource.update' and v_resource.is_public and not boss_private.calendar_can_target('events.publish',v_org,'organization',v_org)) then raise exception 'Access denied' using errcode='PT403';end if;
  if p_replay then return jsonb_build_object('resource_type','venue_resource','resource_id',v_id);end if;
  if p_preview then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  update public.organizations set updated_at=updated_at where id=v_org;
  v_version:=coalesce(v_resource.version,0)+1;
  if op='resource.create' then
   insert into public.venue_resources(id,organization_id,venue_id,name,resource_type,status,is_public,created_by_person_id,updated_by_person_id,version) values(v_id,v_org,(i->>'venue_id')::uuid,btrim(i->>'name'),i->>'resource_type',coalesce(i->>'status','active'),coalesce((i->>'is_public')::boolean,false),p_actor,p_actor,v_version);
  else
   update public.venue_resources set name=btrim(i->>'name'),resource_type=i->>'resource_type',status=coalesce(i->>'status','active'),is_public=coalesce((i->>'is_public')::boolean,false),updated_by_person_id=p_actor,updated_at=now(),version=v_version where id=v_id;
  end if;
  v_kind:='venue_resource';v_after:=jsonb_build_object('venue_id',i->>'venue_id','status',coalesce(i->>'status','active'),'is_public',coalesce((i->>'is_public')::boolean,false),'version',v_version);
 elsif op='calendar.configure' then
  perform boss_private.calendar_validate_input(i,array['organization_id','features'],array['organization_id','features']);
  v_org:=(i->>'organization_id')::uuid;
  if not boss_private.has_permission('organization.manage',v_org) or not boss_private.organization_module_active(v_org,'calendar') then raise exception 'Access denied' using errcode='PT403';end if;
  v_features:=i->'features';
  for k,j in select key,value from jsonb_each(v_features) loop
   if k not in ('organization_calendar','team_calendar','recurrence','conflicts','public_schedules','head_coach_management','conflict_overrides','attendance') or jsonb_typeof(j)<>'boolean' or (k='attendance' and j='true'::jsonb) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  end loop;
  if p_replay then return jsonb_build_object('resource_type','calendar_configuration','resource_id',v_org);end if;
  if p_preview then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  update public.organizations set updated_at=updated_at where id=v_org;
  select om.id,om.configuration into v_module,v_before from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id=v_org and m.key='calendar' and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()) for update of om;
  if v_module is null then raise exception 'Access denied' using errcode='PT403';end if;
  update public.organization_modules set configuration=coalesce(configuration,'{}'::jsonb)||v_features where id=v_module;
  v_id:=v_org;v_kind:='calendar_configuration';v_after:=v_features;v_version:=1;
 else raise exception 'Invalid calendar operation' using errcode='PT422';
 end if;
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,before_data,after_data)
 values(v_org,p_actor,auth.uid(),op,v_kind,v_id,'organization',v_org,p_request,v_before,v_after||jsonb_build_object('fields',(select jsonb_agg(key order by key) from jsonb_object_keys(i) key)));
 if jsonb_array_length(v_conflicts)>0 then
  insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
  values(v_org,p_actor,auth.uid(),'event.conflict_override','event',v_id,'organization',v_org,p_request,jsonb_build_object('conflicts',(select jsonb_agg(jsonb_build_object('event_id',x->'event_id','kind',x->'kind','start_at',x->'start_at','end_at',x->'end_at')) from jsonb_array_elements(v_conflicts) x)));
 end if;
 return jsonb_build_object('resource_type',v_kind,'resource_id',v_id,'version',v_version);
end;$$;
revoke all on function boss_private.calendar_command(jsonb,uuid,uuid,boolean,boolean,uuid) from public,anon,authenticated,service_role;

create function boss_private.calendar_mutate(p_command jsonb,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_actor uuid;v_hash bytea;r boss_private.calendar_operation_receipts%rowtype;result jsonb;
begin
 v_actor:=boss_private.require_admin_actor();
 if p_request_id is null or p_command is null or octet_length(p_command::text)>32768 then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('calendar-request:'||v_actor::text||':'||p_request_id::text,0));
 v_hash:=pg_catalog.sha256(pg_catalog.convert_to(p_command::text,'UTF8'));
 select * into r from boss_private.calendar_operation_receipts where actor_person_id=v_actor and request_id=p_request_id;
 if found then
  if r.input_hash<>v_hash then raise exception 'Conflicting calendar operation' using errcode='PT409';end if;
  perform boss_private.calendar_command(r.command,v_actor,p_request_id,false,true,(r.result->>'resource_id')::uuid);
  return r.result;
 end if;
 result:=boss_private.calendar_command(p_command,v_actor,p_request_id)||jsonb_build_object('request_id',p_request_id);
 insert into boss_private.calendar_operation_receipts(actor_person_id,request_id,input_hash,command,result) values(v_actor,p_request_id,v_hash,p_command,result);
 return result;
exception
 when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' then raise;
 when unique_violation or exclusion_violation or serialization_failure or deadlock_detected then raise exception 'Conflicting calendar operation' using errcode='PT409';
 when others then raise exception 'Invalid calendar operation' using errcode='PT422';
end;$$;
revoke all on function boss_private.calendar_mutate(jsonb,uuid) from public,anon,authenticated,service_role;
grant execute on function boss_private.calendar_mutate(jsonb,uuid) to authenticated;
create function public.boss_calendar_mutate(p_command jsonb,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select boss_private.calendar_mutate(p_command,p_request_id) $$;
revoke all on function public.boss_calendar_mutate(jsonb,uuid) from public,anon,authenticated,service_role;
grant execute on function public.boss_calendar_mutate(jsonb,uuid) to authenticated;

create function boss_private.calendar_preview(p_command jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;
begin
 actor:=boss_private.require_admin_actor();
 if p_command is null or octet_length(p_command::text)>32768 then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
 return boss_private.calendar_command(p_command,actor,null,true);
exception
 when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' then raise;
 when others then raise exception 'Invalid calendar operation' using errcode='PT422';
end;$$;
revoke all on function boss_private.calendar_preview(jsonb) from public,anon,authenticated,service_role;
grant execute on function boss_private.calendar_preview(jsonb) to authenticated;
create function public.boss_calendar_preview(p_command jsonb) returns jsonb language sql security invoker set search_path='' as $$ select boss_private.calendar_preview(p_command) $$;
revoke all on function public.boss_calendar_preview(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.boss_calendar_preview(jsonb) to authenticated;
