-- Phase 2B finite, caller-bound, transactional administration API. Table writes
-- remain closed to authenticated and anonymous clients. No catalog grants change.
create table boss_private.admin_operation_receipts (
  actor_person_id uuid not null references public.people(id) on delete restrict,
  request_id uuid not null,
  input_hash bytea not null,
  resolved_commands jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor_person_id, request_id),
  constraint admin_operation_receipts_commands_check check (jsonb_typeof(resolved_commands) = 'array'),
  constraint admin_operation_receipts_result_check check (jsonb_typeof(result) = 'object')
);
alter table boss_private.admin_operation_receipts enable row level security;
revoke all on boss_private.admin_operation_receipts from public, anon, authenticated, service_role;

create function boss_private.require_live_auth() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_sid uuid;
begin
  if v_uid is null or auth.jwt()->>'role' is distinct from 'authenticated'
    or coalesce(auth.jwt()->>'is_anonymous', 'false') <> 'false' then
    raise exception 'Authentication required' using errcode = 'PT401';
  end if;
  begin
    v_sid := (auth.jwt()->>'session_id')::uuid;
  exception when invalid_text_representation then
    raise exception 'Authentication required' using errcode = 'PT401';
  end;
  if v_sid is null or not exists (
    select 1 from auth.sessions s join auth.users u on u.id = s.user_id
    where s.id = v_sid and s.user_id = v_uid
      and (s.not_after is null or s.not_after > now())
      and u.email_confirmed_at is not null and not coalesce(u.is_anonymous, false)
      and u.deleted_at is null and (u.banned_until is null or u.banned_until <= now())
  ) then
    raise exception 'Authentication required' using errcode = 'PT401';
  end if;
  return v_uid;
end;
$$;
revoke all on function boss_private.require_live_auth() from public, anon, authenticated, service_role;
grant execute on function boss_private.require_live_auth() to authenticated;

create function boss_private.require_admin_actor() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare v_actor uuid;
begin
  perform boss_private.require_live_auth();
  v_actor := boss_private.current_person_id();
  if v_actor is null then raise exception 'Access denied' using errcode = 'PT403'; end if;
  return v_actor;
end;
$$;
revoke all on function boss_private.require_admin_actor() from public, anon, authenticated, service_role;
grant execute on function boss_private.require_admin_actor() to authenticated;

create function boss_private.admin_require_permission(p_key text, p_org uuid default null, p_unit uuid default null, p_team uuid default null)
returns void language plpgsql stable security invoker set search_path = '' as $$
begin
  -- Resource lookup occurs before this helper. Global capability is evaluated
  -- without an inactive tenant context, permitting explicit platform recovery.
  if not (boss_private.has_permission(p_key) or boss_private.has_permission(p_key, p_org, p_unit, p_team)) then
    raise exception 'Access denied' using errcode = 'PT403';
  end if;
end;
$$;
revoke all on function boss_private.admin_require_permission(text,uuid,uuid,uuid) from public, anon, authenticated, service_role;

create function boss_private.admin_person_in_context(p_person uuid,p_org uuid default null,p_team uuid default null)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.people p where p.id=p_person and p.status='active') and (
    boss_private.has_permission('person.profile.manage')
    or p_person=boss_private.current_person_id()
    or boss_private.can_manage_dependent_profile(p_person)
    or (p_org is not null and exists (
      select 1 from public.organization_memberships m where m.person_id=p_person
        and m.organization_id=p_org and m.status='active' and m.starts_at<=now()
        and (m.ends_at is null or m.ends_at>now())))
    or (p_team is not null and exists (
      select 1 from public.team_memberships m where m.person_id=p_person
        and m.team_id=p_team and m.organization_id=p_org and m.status='active'
        and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())))
  )
$$;
revoke all on function boss_private.admin_person_in_context(uuid,uuid,uuid) from public, anon, authenticated, service_role;

-- A finite schema validates every primitive before any mutation. Input is never
-- a table name, column name, SQL fragment, policy, permission or raw audit payload.
create function boss_private.admin_validate_input(p_input jsonb,p_fields text[],p_required text[])
returns void language plpgsql immutable security invoker set search_path = '' as $$
declare v_key text; v_value jsonb; v_type text;
begin
  if jsonb_typeof(p_input) is distinct from 'object' then raise exception 'Invalid operation' using errcode='PT422'; end if;
  for v_key,v_value in select key,value from jsonb_each(p_input) loop
    if not v_key=any(p_fields) then raise exception 'Invalid operation' using errcode='PT422'; end if;
    v_type:=jsonb_typeof(v_value);
    if v_type='null' then
      if v_key=any(p_required) or v_key in ('id','status','authority_status','scope_type','name','slug','unit_type','organization_type','timezone','participant_type','membership_type','relationship_type','starts_at','is_primary_contact','sort_order','visibility') or v_key like 'can_%' then
        raise exception 'Invalid operation' using errcode='PT422';
      end if;
    elsif v_key='id' or v_key like '%_id' then
      if v_type<>'string' or v_value#>>'{}' !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then raise exception 'Invalid operation' using errcode='PT422'; end if;
    elsif v_key='is_primary_contact' or v_key like 'can_%' then
      if v_type<>'boolean' then raise exception 'Invalid operation' using errcode='PT422'; end if;
    elsif v_key='sort_order' then
      if v_type<>'number' or v_value#>>'{}' !~ '^-?[0-9]{1,7}$' then raise exception 'Invalid operation' using errcode='PT422'; end if;
    else
      if v_type<>'string' or length(v_value#>>'{}')>200 or length(btrim(v_value#>>'{}'))=0 then raise exception 'Invalid operation' using errcode='PT422'; end if;
      if v_value#>>'{}' ~ '[[:cntrl:]]' then raise exception 'Invalid operation' using errcode='PT422'; end if;
      if v_key in ('status','authority_status') and v_value#>>'{}' not in ('active','inactive','pending','suspended','archived') then raise exception 'Invalid operation' using errcode='PT422'; end if;
      if v_key='slug' and v_value#>>'{}' !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then raise exception 'Invalid operation' using errcode='PT422'; end if;
      if v_key='scope_type' and v_value#>>'{}' not in ('platform','organization','organization_unit','team') then raise exception 'Invalid operation' using errcode='PT422'; end if;
      if v_key='visibility' and v_value#>>'{}' not in ('public','authenticated','member','restricted','private') then raise exception 'Invalid operation' using errcode='PT422'; end if;
      if v_key in ('starts_on','ends_on') then
        if v_value#>>'{}' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise exception 'Invalid operation' using errcode='PT422'; end if;
        perform (v_value#>>'{}')::date;
      end if;
      if v_key in ('starts_at','ends_at') then
        if v_value#>>'{}' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$' then raise exception 'Invalid operation' using errcode='PT422'; end if;
        perform (v_value#>>'{}')::timestamptz;
      end if;
    end if;
  end loop;
  foreach v_key in array p_required loop
    if not p_input?v_key or p_input->v_key='null'::jsonb then raise exception 'Invalid operation' using errcode='PT422'; end if;
  end loop;
end;
$$;
revoke all on function boss_private.admin_validate_input(jsonb,text[],text[]) from public, anon, authenticated, service_role;

-- A global participant has no tenant owner. A scoped administrator must reach
-- it through the person's explicit, currently active organization/roster context.
-- Caller-supplied organization filters can narrow these real relationships only.
create function boss_private.admin_participant_context(p_person uuid,p_organization uuid default null)
returns table(organization_id uuid,organization_unit_id uuid,team_id uuid)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists(select 1 from public.people p where p.id=p_person and p.status='active')
    or (p_organization is not null and not exists(select 1 from public.organizations o where o.id=p_organization)) then
    raise exception 'Access denied' using errcode='PT403';
  end if;
  if boss_private.has_permission('participant.profile.manage') then
    return query select p_organization,null::uuid,null::uuid;
    return;
  end if;
  return query select m.organization_id,null::uuid,null::uuid
    from public.organization_memberships m
    where m.person_id=p_person and (p_organization is null or m.organization_id=p_organization)
      and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())
      and boss_private.has_permission('participant.profile.manage',m.organization_id)
    order by m.organization_id,m.id limit 1;
  if found then return;end if;
  return query select t.organization_id,t.parent_unit_id,t.id
    from public.team_memberships m join public.teams t on t.id=m.team_id and t.organization_id=m.organization_id
    where m.person_id=p_person and (p_organization is null or t.organization_id=p_organization)
      and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())
      and boss_private.has_permission('participant.profile.manage',t.organization_id,t.parent_unit_id,t.id)
    order by t.organization_id,t.id,m.id limit 1;
  if not found then raise exception 'Access denied' using errcode='PT403';end if;
end;
$$;
revoke all on function boss_private.admin_participant_context(uuid,uuid) from public,anon,authenticated,service_role;

create function boss_private.admin_mutate_command(p_operation text,i jsonb,p_actor uuid,p_request uuid,p_check_only boolean default false,p_created_id uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r record; v_id uuid:=coalesce((i->>'id')::uuid,p_created_id,gen_random_uuid());
  v_org uuid;v_unit uuid;v_team uuid;v_person uuid;v_anchor uuid;v_role uuid;
  v_scope text;v_type text;v_key text;v_start timestamptz;v_end timestamptz;v_status text;
  v_uid uuid;v_account uuid;v_email text;v_existing uuid;
begin
  if p_actor is distinct from boss_private.current_person_id() then
    raise exception 'Access denied' using errcode='PT403';
  end if;
  case p_operation
  when 'person.create' then
    perform boss_private.admin_validate_input(i,array['first_name','middle_name','last_name','preferred_name','display_name','status']::text[],array[]::text[]);
    v_type:='person';
    perform boss_private.admin_require_permission('person.profile.manage');
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    insert into public.people(id,first_name,middle_name,last_name,preferred_name,display_name,status) values(v_id,(i->>'first_name')::text,(i->>'middle_name')::text,(i->>'last_name')::text,(i->>'preferred_name')::text,(i->>'display_name')::text,coalesce((i->>'status')::text,'active'));
    v_person:=v_id;
  when 'person.update' then
    perform boss_private.admin_validate_input(i,array['id','first_name','middle_name','last_name','preferred_name','display_name','status']::text[],array['id']::text[]);
    v_type:='person';
    select * into r from public.people where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    if not boss_private.has_permission('person.profile.manage') then if not boss_private.can_manage_dependent_profile(v_id) or i?'status' then raise exception 'Access denied' using errcode='PT403'; end if; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    update public.people set first_name=case when i?'first_name' then (i->>'first_name')::text else r.first_name end,middle_name=case when i?'middle_name' then (i->>'middle_name')::text else r.middle_name end,last_name=case when i?'last_name' then (i->>'last_name')::text else r.last_name end,preferred_name=case when i?'preferred_name' then (i->>'preferred_name')::text else r.preferred_name end,display_name=case when i?'display_name' then (i->>'display_name')::text else r.display_name end,status=case when i?'status' then (i->>'status')::text else r.status end where id=v_id;
    v_person:=v_id;
  when 'organization.create' then
    perform boss_private.admin_validate_input(i,array['name','legal_name','slug','organization_type','status','timezone','country','default_currency']::text[],array['name','slug']::text[]);
    v_type:='organization';
    perform boss_private.admin_require_permission('organization.manage');
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if i?'timezone' and not exists(select 1 from pg_catalog.pg_timezone_names where name=i->>'timezone') then raise exception 'Invalid operation' using errcode='PT422'; end if;
    insert into public.organizations(id,name,legal_name,slug,organization_type,status,timezone,country,default_currency) values(v_id,(i->>'name')::text,(i->>'legal_name')::text,(i->>'slug')::text,coalesce((i->>'organization_type')::text,'organization'),coalesce((i->>'status')::text,'active'),coalesce((i->>'timezone')::text,'UTC'),(i->>'country')::text,(i->>'default_currency')::text);
    v_org:=v_id;
  when 'organization.update' then
    perform boss_private.admin_validate_input(i,array['id','name','legal_name','slug','organization_type','status','timezone','country','default_currency']::text[],array['id']::text[]);
    v_type:='organization';
    select * into r from public.organizations where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_org:=v_id; perform boss_private.admin_require_permission('organization.manage',v_org);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if i?'timezone' and not exists(select 1 from pg_catalog.pg_timezone_names where name=i->>'timezone') then raise exception 'Invalid operation' using errcode='PT422'; end if;
    update public.organizations set name=case when i?'name' then (i->>'name')::text else r.name end,legal_name=case when i?'legal_name' then (i->>'legal_name')::text else r.legal_name end,slug=case when i?'slug' then (i->>'slug')::text else r.slug end,organization_type=case when i?'organization_type' then (i->>'organization_type')::text else r.organization_type end,status=case when i?'status' then (i->>'status')::text else r.status end,timezone=case when i?'timezone' then (i->>'timezone')::text else r.timezone end,country=case when i?'country' then (i->>'country')::text else r.country end,default_currency=case when i?'default_currency' then (i->>'default_currency')::text else r.default_currency end where id=v_id;
    v_org:=v_id;
  when 'unit.create' then
    perform boss_private.admin_validate_input(i,array['organization_id','parent_unit_id','unit_type','name','slug','status','sort_order']::text[],array['organization_id','unit_type','name','slug']::text[]);
    v_type:='organization_unit';
    v_org:=(i->>'organization_id')::uuid; perform boss_private.admin_require_permission('organization.manage',v_org);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if not exists(select 1 from public.organizations where id=v_org) then raise exception 'Access denied' using errcode='PT403'; end if; if i->>'parent_unit_id' is not null and not exists(select 1 from public.organization_units where id=(i->>'parent_unit_id')::uuid and organization_id=v_org and status='active') then raise exception 'Invalid operation' using errcode='PT422'; end if;
    insert into public.organization_units(id,organization_id,parent_unit_id,unit_type,name,slug,status,sort_order) values(v_id,(i->>'organization_id')::uuid,(i->>'parent_unit_id')::uuid,(i->>'unit_type')::text,(i->>'name')::text,(i->>'slug')::text,coalesce((i->>'status')::text,'active'),coalesce((i->>'sort_order')::integer,0));
    v_unit:=v_id;
  when 'unit.update' then
    perform boss_private.admin_validate_input(i,array['id','parent_unit_id','unit_type','name','slug','status','sort_order']::text[],array['id']::text[]);
    v_type:='organization_unit';
    select * into r from public.organization_units where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_org:=r.organization_id;v_unit:=v_id;perform boss_private.admin_require_permission('organization.manage',v_org,v_unit);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if i?'parent_unit_id' and (i->>'parent_unit_id')::uuid is distinct from r.parent_unit_id then perform boss_private.admin_require_permission('organization.manage',v_org,(i->>'parent_unit_id')::uuid); if i->>'parent_unit_id' is not null and not exists(select 1 from public.organization_units where id=(i->>'parent_unit_id')::uuid and organization_id=v_org and status='active') then raise exception 'Invalid operation' using errcode='PT422'; end if; end if;
    update public.organization_units set parent_unit_id=case when i?'parent_unit_id' then (i->>'parent_unit_id')::uuid else r.parent_unit_id end,unit_type=case when i?'unit_type' then (i->>'unit_type')::text else r.unit_type end,name=case when i?'name' then (i->>'name')::text else r.name end,slug=case when i?'slug' then (i->>'slug')::text else r.slug end,status=case when i?'status' then (i->>'status')::text else r.status end,sort_order=case when i?'sort_order' then (i->>'sort_order')::integer else r.sort_order end where id=v_id;
    v_unit:=v_id;
  when 'season.create' then
    perform boss_private.admin_validate_input(i,array['organization_id','parent_unit_id','name','starts_on','ends_on','status']::text[],array['organization_id','name']::text[]);
    v_type:='season';
    v_org:=(i->>'organization_id')::uuid;v_unit:=(i->>'parent_unit_id')::uuid;perform boss_private.admin_require_permission('organization.manage',v_org,v_unit);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if not exists(select 1 from public.organizations where id=v_org) or (v_unit is not null and not exists(select 1 from public.organization_units where id=v_unit and organization_id=v_org and status='active')) then raise exception 'Invalid operation' using errcode='PT422'; end if;
    insert into public.seasons(id,organization_id,parent_unit_id,name,starts_on,ends_on,status) values(v_id,(i->>'organization_id')::uuid,(i->>'parent_unit_id')::uuid,(i->>'name')::text,(i->>'starts_on')::date,(i->>'ends_on')::date,coalesce((i->>'status')::text,'pending'));
  when 'season.update' then
    perform boss_private.admin_validate_input(i,array['id','name','starts_on','ends_on','status']::text[],array['id']::text[]);
    v_type:='season';
    select * into r from public.seasons where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_org:=r.organization_id;v_unit:=r.parent_unit_id;perform boss_private.admin_require_permission('organization.manage',v_org,v_unit);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    update public.seasons set name=case when i?'name' then (i->>'name')::text else r.name end,starts_on=case when i?'starts_on' then (i->>'starts_on')::date else r.starts_on end,ends_on=case when i?'ends_on' then (i->>'ends_on')::date else r.ends_on end,status=case when i?'status' then (i->>'status')::text else r.status end where id=v_id;
  when 'team.create' then
    perform boss_private.admin_validate_input(i,array['organization_id','parent_unit_id','season_id','name','short_name','slug','status','visibility']::text[],array['organization_id','name','slug']::text[]);
    v_type:='team';
    v_org:=(i->>'organization_id')::uuid;v_unit:=(i->>'parent_unit_id')::uuid;perform boss_private.admin_require_permission('team.manage',v_org,v_unit);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if not exists(select 1 from public.organizations where id=v_org) or (v_unit is not null and not exists(select 1 from public.organization_units where id=v_unit and organization_id=v_org and status='active')) then raise exception 'Invalid operation' using errcode='PT422'; end if;if i->>'season_id' is not null and not exists(select 1 from public.seasons where id=(i->>'season_id')::uuid and organization_id=v_org and status='active' and (parent_unit_id is null or parent_unit_id is not distinct from v_unit)) then raise exception 'Invalid operation' using errcode='PT422'; end if;
    insert into public.teams(id,organization_id,parent_unit_id,season_id,name,short_name,slug,status,visibility) values(v_id,(i->>'organization_id')::uuid,(i->>'parent_unit_id')::uuid,(i->>'season_id')::uuid,(i->>'name')::text,(i->>'short_name')::text,(i->>'slug')::text,coalesce((i->>'status')::text,'pending'),coalesce((i->>'visibility')::text,'private'));
    v_team:=v_id;
  when 'team.update' then
    perform boss_private.admin_validate_input(i,array['id','name','short_name','slug','status','visibility']::text[],array['id']::text[]);
    v_type:='team';
    select * into r from public.teams where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_org:=r.organization_id;v_unit:=r.parent_unit_id;v_team:=v_id;perform boss_private.admin_require_permission('team.manage',v_org,v_unit,v_team);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    update public.teams set name=case when i?'name' then (i->>'name')::text else r.name end,short_name=case when i?'short_name' then (i->>'short_name')::text else r.short_name end,slug=case when i?'slug' then (i->>'slug')::text else r.slug end,status=case when i?'status' then (i->>'status')::text else r.status end,visibility=case when i?'visibility' then (i->>'visibility')::text else r.visibility end where id=v_id;
    v_team:=v_id;
  when 'household.create' then
    perform boss_private.admin_validate_input(i,array['name','status']::text[],array['name']::text[]);
    v_type:='household';
    perform boss_private.admin_require_permission('household.manage');
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    insert into public.households(id,name,status) values(v_id,(i->>'name')::text,coalesce((i->>'status')::text,'active'));
    v_scope:='household';v_anchor:=v_id;
  when 'participant.create' then
    perform boss_private.admin_validate_input(i,array['person_id','participant_type','status','organization_id']::text[],array['person_id']::text[]);
    v_type:='participant';
    v_person:=(i->>'person_id')::uuid;select c.organization_id,c.organization_unit_id,c.team_id into v_org,v_unit,v_team from boss_private.admin_participant_context(v_person,(i->>'organization_id')::uuid) c;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    insert into public.participants(id,person_id,participant_type,status) values(v_id,(i->>'person_id')::uuid,coalesce((i->>'participant_type')::text,'participant'),coalesce((i->>'status')::text,'active'));
  when 'household.update' then
    perform boss_private.admin_validate_input(i,array['id','name','status']::text[],array['id']::text[]);
    v_type:='household';
    select * into r from public.households where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    perform boss_private.admin_require_permission('household.manage');
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    update public.households set name=case when i?'name' then (i->>'name')::text else r.name end,status=case when i?'status' then (i->>'status')::text else r.status end where id=v_id;
    v_scope:='household';v_anchor:=v_id;
  when 'participant.update' then
    perform boss_private.admin_validate_input(i,array['id','participant_type','status','organization_id']::text[],array['id']::text[]);
    v_type:='participant';
    select * into r from public.participants where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_person:=r.person_id;select c.organization_id,c.organization_unit_id,c.team_id into v_org,v_unit,v_team from boss_private.admin_participant_context(v_person,(i->>'organization_id')::uuid) c;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    update public.participants set participant_type=case when i?'participant_type' then (i->>'participant_type')::text else r.participant_type end,status=case when i?'status' then (i->>'status')::text else r.status end where id=v_id;
  when 'organization_membership.add' then
    perform boss_private.admin_validate_input(i,array['organization_id','person_id','membership_type','starts_at','status','ends_at']::text[],array['organization_id','person_id']::text[]);
    v_type:='organization_membership';
    v_person:=(i->>'person_id')::uuid;v_anchor:=(i->>'organization_id')::uuid;v_org:=v_anchor;perform boss_private.admin_require_permission('organization.members.manage',v_org);if not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=coalesce((i->>'starts_at')::timestamptz,now());v_end:=(i->>'ends_at')::timestamptz;v_status:=coalesce(i->>'status','active'); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.organizations set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('organization_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.organization_memberships m where m.organization_id=v_anchor and m.person_id=v_person and m.membership_type=coalesce(i->>'membership_type','member') and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    insert into public.organization_memberships(id,organization_id,person_id,membership_type,starts_at,status,ends_at) values(v_id,(i->>'organization_id')::uuid,(i->>'person_id')::uuid,coalesce((i->>'membership_type')::text,'member'),coalesce((i->>'starts_at')::timestamptz,now()),coalesce((i->>'status')::text,'active'),(i->>'ends_at')::timestamptz);
  when 'organization_membership.update' then
    perform boss_private.admin_validate_input(i,array['id','status','ends_at']::text[],array['id']::text[]);
    v_type:='organization_membership';
    select * into r from public.organization_memberships where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_person:=r.person_id;v_anchor:=r.organization_id;v_org:=v_anchor;perform boss_private.admin_require_permission('organization.members.manage',v_org);if not (coalesce(i->>'status','active')<>'active' or coalesce((i->>'ends_at')::timestamptz<=now(),false)) and not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=r.starts_at;v_end:=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end;v_status:=coalesce(i->>'status',r.status); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.organizations set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('organization_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.organization_memberships m where m.organization_id=v_anchor and m.person_id=v_person and m.membership_type=r.membership_type and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    update public.organization_memberships set status=case when i?'status' then (i->>'status')::text else r.status end,ends_at=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end where id=v_id;
  when 'team_membership.add' then
    perform boss_private.admin_validate_input(i,array['team_id','person_id','membership_type','starts_at','status','ends_at','participant_id','jersey_number','position_label']::text[],array['team_id','person_id']::text[]);
    v_type:='team_membership';
    v_person:=(i->>'person_id')::uuid;v_anchor:=(i->>'team_id')::uuid;select organization_id,parent_unit_id into v_org,v_unit from public.teams where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403'; end if;v_team:=v_anchor;perform boss_private.admin_require_permission('team.roster.manage',v_org,v_unit,v_team);if not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=coalesce((i->>'starts_at')::timestamptz,now());v_end:=(i->>'ends_at')::timestamptz;v_status:=coalesce(i->>'status','active'); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.teams set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('team_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.team_memberships m where m.team_id=v_anchor and m.person_id=v_person and m.membership_type=coalesce(i->>'membership_type','member') and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;if (i->>'participant_id')::uuid is not null and not exists(select 1 from public.participants where id=(i->>'participant_id')::uuid and person_id=v_person and status='active') then raise exception 'Invalid operation' using errcode='PT422';end if; if coalesce(i->>'membership_type','member')='athlete' and (i->>'participant_id')::uuid is null then raise exception 'Invalid operation' using errcode='PT422';end if;
    insert into public.team_memberships(id,team_id,person_id,membership_type,starts_at,status,ends_at,participant_id,jersey_number,position_label,organization_id) values(v_id,(i->>'team_id')::uuid,(i->>'person_id')::uuid,coalesce((i->>'membership_type')::text,'member'),coalesce((i->>'starts_at')::timestamptz,now()),coalesce((i->>'status')::text,'active'),(i->>'ends_at')::timestamptz,(i->>'participant_id')::uuid,(i->>'jersey_number')::text,(i->>'position_label')::text,v_org);
  when 'team_membership.update' then
    perform boss_private.admin_validate_input(i,array['id','status','ends_at','jersey_number','position_label']::text[],array['id']::text[]);
    v_type:='team_membership';
    select * into r from public.team_memberships where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_person:=r.person_id;v_anchor:=r.team_id;select organization_id,parent_unit_id into v_org,v_unit from public.teams where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403'; end if;v_team:=v_anchor;perform boss_private.admin_require_permission('team.roster.manage',v_org,v_unit,v_team);if not (coalesce(i->>'status','active')<>'active' or coalesce((i->>'ends_at')::timestamptz<=now(),false)) and not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=r.starts_at;v_end:=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end;v_status:=coalesce(i->>'status',r.status); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.teams set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('team_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.team_memberships m where m.team_id=v_anchor and m.person_id=v_person and m.membership_type=r.membership_type and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;if r.participant_id is not null and not exists(select 1 from public.participants where id=r.participant_id and person_id=v_person and status='active') then raise exception 'Invalid operation' using errcode='PT422';end if; if r.membership_type='athlete' and r.participant_id is null then raise exception 'Invalid operation' using errcode='PT422';end if;
    update public.team_memberships set status=case when i?'status' then (i->>'status')::text else r.status end,ends_at=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end,jersey_number=case when i?'jersey_number' then (i->>'jersey_number')::text else r.jersey_number end,position_label=case when i?'position_label' then (i->>'position_label')::text else r.position_label end where id=v_id;
  when 'household_membership.add' then
    perform boss_private.admin_validate_input(i,array['household_id','person_id','relationship_type','starts_at','status','ends_at','is_primary_contact']::text[],array['household_id','person_id']::text[]);
    v_type:='household_membership';
    v_person:=(i->>'person_id')::uuid;v_anchor:=(i->>'household_id')::uuid;perform boss_private.admin_require_permission('household.manage');if not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=coalesce((i->>'starts_at')::timestamptz,now());v_end:=(i->>'ends_at')::timestamptz;v_status:=coalesce(i->>'status','active'); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.households set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('household_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.household_memberships m where m.household_id=v_anchor and m.person_id=v_person and m.relationship_type=coalesce(i->>'relationship_type','member') and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;if v_status='active' and coalesce((i->>'is_primary_contact')::boolean,false) and exists(select 1 from public.household_memberships m where m.household_id=v_anchor and m.is_primary_contact and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    insert into public.household_memberships(id,household_id,person_id,relationship_type,starts_at,status,ends_at,is_primary_contact) values(v_id,(i->>'household_id')::uuid,(i->>'person_id')::uuid,coalesce((i->>'relationship_type')::text,'member'),coalesce((i->>'starts_at')::timestamptz,now()),coalesce((i->>'status')::text,'active'),(i->>'ends_at')::timestamptz,coalesce((i->>'is_primary_contact')::boolean,false));
    v_scope:='household';
  when 'household_membership.update' then
    perform boss_private.admin_validate_input(i,array['id','status','ends_at','is_primary_contact']::text[],array['id']::text[]);
    v_type:='household_membership';
    select * into r from public.household_memberships where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_person:=r.person_id;v_anchor:=r.household_id;perform boss_private.admin_require_permission('household.manage');if not (coalesce(i->>'status','active')<>'active' or coalesce((i->>'ends_at')::timestamptz<=now(),false)) and not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=r.starts_at;v_end:=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end;v_status:=coalesce(i->>'status',r.status); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.households set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('household_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.household_memberships m where m.household_id=v_anchor and m.person_id=v_person and m.relationship_type=r.relationship_type and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;if v_status='active' and (case when i?'is_primary_contact' then (i->>'is_primary_contact')::boolean else r.is_primary_contact end) and exists(select 1 from public.household_memberships m where m.household_id=v_anchor and m.is_primary_contact and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    update public.household_memberships set status=case when i?'status' then (i->>'status')::text else r.status end,ends_at=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end,is_primary_contact=case when i?'is_primary_contact' then (i->>'is_primary_contact')::boolean else r.is_primary_contact end where id=v_id;
    v_scope:='household';
  when 'guardian.create' then
    perform boss_private.admin_validate_input(i,array['guardian_person_id','dependent_person_id','relationship_type','starts_at','authority_status','ends_at','can_register','can_sign_waivers','can_view_documents','can_manage_payments','can_manage_profile']::text[],array['guardian_person_id','dependent_person_id']::text[]);
    v_type:='guardian_relationship';
    perform boss_private.admin_require_permission('household.manage');perform boss_private.admin_require_permission('person.profile.manage');v_person:=(i->>'dependent_person_id')::uuid;v_anchor:=(i->>'guardian_person_id')::uuid;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if v_person=v_anchor or not exists(select 1 from public.people where id=v_person and status='active') or not exists(select 1 from public.people where id=v_anchor and status='active') then raise exception 'Invalid operation' using errcode='PT422';end if;v_start:=coalesce((i->>'starts_at')::timestamptz,now());v_end:=(i->>'ends_at')::timestamptz;v_status:=coalesce(i->>'authority_status','pending');if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if;update public.people set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('guardian:'||v_anchor::text||':'||v_person::text,0));if v_status='active' and exists(select 1 from public.guardian_relationships g where g.guardian_person_id=v_anchor and g.dependent_person_id=v_person and g.relationship_type=coalesce(i->>'relationship_type','guardian') and g.authority_status='active' and g.id<>v_id and pg_catalog.tstzrange(g.starts_at,g.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    insert into public.guardian_relationships(id,guardian_person_id,dependent_person_id,relationship_type,starts_at,authority_status,ends_at,can_register,can_sign_waivers,can_view_documents,can_manage_payments,can_manage_profile) values(v_id,(i->>'guardian_person_id')::uuid,(i->>'dependent_person_id')::uuid,coalesce((i->>'relationship_type')::text,'guardian'),coalesce((i->>'starts_at')::timestamptz,now()),coalesce((i->>'authority_status')::text,'pending'),(i->>'ends_at')::timestamptz,coalesce((i->>'can_register')::boolean,false),coalesce((i->>'can_sign_waivers')::boolean,false),coalesce((i->>'can_view_documents')::boolean,false),coalesce((i->>'can_manage_payments')::boolean,false),coalesce((i->>'can_manage_profile')::boolean,false));
  when 'guardian.update' then
    perform boss_private.admin_validate_input(i,array['id','authority_status','ends_at','can_register','can_sign_waivers','can_view_documents','can_manage_payments','can_manage_profile']::text[],array['id']::text[]);
    v_type:='guardian_relationship';
    select * into r from public.guardian_relationships where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    perform boss_private.admin_require_permission('household.manage');perform boss_private.admin_require_permission('person.profile.manage');v_person:=r.dependent_person_id;v_anchor:=r.guardian_person_id;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if v_person=v_anchor or (not (coalesce(i->>'authority_status','active')<>'active' or coalesce((i->>'ends_at')::timestamptz<=now(),false)) and (not exists(select 1 from public.people where id=v_person and status='active') or not exists(select 1 from public.people where id=v_anchor and status='active'))) then raise exception 'Invalid operation' using errcode='PT422';end if;v_start:=r.starts_at;v_end:=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end;v_status:=coalesce(i->>'authority_status',r.authority_status);if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if;update public.people set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('guardian:'||v_anchor::text||':'||v_person::text,0));if v_status='active' and exists(select 1 from public.guardian_relationships g where g.guardian_person_id=v_anchor and g.dependent_person_id=v_person and g.relationship_type=r.relationship_type and g.authority_status='active' and g.id<>v_id and pg_catalog.tstzrange(g.starts_at,g.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    update public.guardian_relationships set authority_status=case when i?'authority_status' then (i->>'authority_status')::text else r.authority_status end,ends_at=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end,can_register=case when i?'can_register' then (i->>'can_register')::boolean else r.can_register end,can_sign_waivers=case when i?'can_sign_waivers' then (i->>'can_sign_waivers')::boolean else r.can_sign_waivers end,can_view_documents=case when i?'can_view_documents' then (i->>'can_view_documents')::boolean else r.can_view_documents end,can_manage_payments=case when i?'can_manage_payments' then (i->>'can_manage_payments')::boolean else r.can_manage_payments end,can_manage_profile=case when i?'can_manage_profile' then (i->>'can_manage_profile')::boolean else r.can_manage_profile end where id=v_id;
  when 'guardian.verify' then
    perform boss_private.admin_validate_input(i,array['id']::text[],array['id']::text[]);
    v_type:='guardian_relationship';
    select * into r from public.guardian_relationships where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    perform boss_private.admin_require_permission('household.manage');perform boss_private.admin_require_permission('person.profile.manage');v_person:=r.dependent_person_id;v_anchor:=r.guardian_person_id;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if v_person=v_anchor or not exists(select 1 from public.people where id=v_person and status='active') or not exists(select 1 from public.people where id=v_anchor and status='active') then raise exception 'Invalid operation' using errcode='PT422';end if;if v_anchor=p_actor or v_person=p_actor then raise exception 'Access denied' using errcode='PT403';end if;
    update public.people set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('guardian:'||v_anchor::text||':'||v_person::text,0));
    if exists(select 1 from public.guardian_relationships g where g.guardian_person_id=v_anchor and g.dependent_person_id=v_person and g.relationship_type=r.relationship_type and g.authority_status='active' and g.id<>v_id and pg_catalog.tstzrange(g.starts_at,g.ends_at,'[)') && pg_catalog.tstzrange(r.starts_at,r.ends_at,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    update public.guardian_relationships set verified_at=statement_timestamp(),authority_status='active' where id=v_id;
  when 'role_assignment.add' then
    perform boss_private.admin_validate_input(i,array['person_id','role_id','scope_type','scope_id','organization_id','starts_at','status','ends_at']::text[],array['person_id','role_id','scope_type']::text[]);
    v_type:='role_assignment';
    v_person:=(i->>'person_id')::uuid;v_role:=(i->>'role_id')::uuid;v_scope:=i->>'scope_type';v_anchor:=(i->>'scope_id')::uuid;v_org:=(i->>'organization_id')::uuid;if v_scope='platform' then if v_anchor is not null or v_org is not null then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='organization' then if v_anchor is null or v_anchor is distinct from v_org or not exists(select 1 from public.organizations where id=v_org) then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='organization_unit' then v_unit:=v_anchor;if not exists(select 1 from public.organization_units where id=v_unit and organization_id=v_org) then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='team' then v_team:=v_anchor;select parent_unit_id into v_unit from public.teams where id=v_team and organization_id=v_org;if not found then raise exception 'Invalid operation' using errcode='PT422';end if;else raise exception 'Invalid operation' using errcode='PT422';end if;perform boss_private.admin_require_permission('roles.assign',v_org,v_unit,v_team);if not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;if not exists(select 1 from public.roles where id=v_role and status='active' and v_scope=any(allowed_scope_types)) then raise exception 'Invalid operation' using errcode='PT422';end if; for v_key in select p.key from public.role_permissions rp join public.permissions p on p.id=rp.permission_id where rp.role_id=v_role loop perform boss_private.admin_require_permission(v_key,v_org,v_unit,v_team);end loop;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=coalesce((i->>'starts_at')::timestamptz,now());v_end:=(i->>'ends_at')::timestamptz;v_status:=coalesce(i->>'status','active');if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if;update public.people set updated_at=updated_at where id=v_person; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('role:'||v_person::text||':'||v_role::text||':'||coalesce(v_anchor::text,'platform'),0));if v_status='active' and exists(select 1 from public.role_assignments a where a.person_id=v_person and a.role_id=v_role and a.scope_type=v_scope and a.scope_id is not distinct from v_anchor and a.status='active' and a.id<>v_id and pg_catalog.tstzrange(a.starts_at,a.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    insert into public.role_assignments(id,person_id,role_id,scope_type,scope_id,organization_id,starts_at,status,ends_at,granted_by_person_id) values(v_id,(i->>'person_id')::uuid,(i->>'role_id')::uuid,(i->>'scope_type')::text,(i->>'scope_id')::uuid,(i->>'organization_id')::uuid,coalesce((i->>'starts_at')::timestamptz,now()),coalesce((i->>'status')::text,'active'),(i->>'ends_at')::timestamptz,p_actor);
  when 'role_assignment.update' then
    perform boss_private.admin_validate_input(i,array['id','status','ends_at']::text[],array['id']::text[]);
    v_type:='role_assignment';
    select * into r from public.role_assignments where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_person:=r.person_id;v_role:=r.role_id;v_scope:=r.scope_type;v_anchor:=r.scope_id;v_org:=r.organization_id;if v_scope='platform' then if v_anchor is not null or v_org is not null then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='organization' then if v_anchor is null or v_anchor is distinct from v_org or not exists(select 1 from public.organizations where id=v_org) then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='organization_unit' then v_unit:=v_anchor;if not exists(select 1 from public.organization_units where id=v_unit and organization_id=v_org) then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='team' then v_team:=v_anchor;select parent_unit_id into v_unit from public.teams where id=v_team and organization_id=v_org;if not found then raise exception 'Invalid operation' using errcode='PT422';end if;else raise exception 'Invalid operation' using errcode='PT422';end if;perform boss_private.admin_require_permission('roles.assign',v_org,v_unit,v_team);if not (coalesce(i->>'status','active')<>'active' or coalesce((i->>'ends_at')::timestamptz<=now(),false)) and not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;if not exists(select 1 from public.roles where id=v_role and status='active' and v_scope=any(allowed_scope_types)) then raise exception 'Invalid operation' using errcode='PT422';end if; for v_key in select p.key from public.role_permissions rp join public.permissions p on p.id=rp.permission_id where rp.role_id=v_role loop perform boss_private.admin_require_permission(v_key,v_org,v_unit,v_team);end loop;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=r.starts_at;v_end:=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end;v_status:=coalesce(i->>'status',r.status);if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if;update public.people set updated_at=updated_at where id=v_person; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('role:'||v_person::text||':'||v_role::text||':'||coalesce(v_anchor::text,'platform'),0));if v_status='active' and exists(select 1 from public.role_assignments a where a.person_id=v_person and a.role_id=v_role and a.scope_type=v_scope and a.scope_id is not distinct from v_anchor and a.status='active' and a.id<>v_id and pg_catalog.tstzrange(a.starts_at,a.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    update public.role_assignments set status=case when i?'status' then (i->>'status')::text else r.status end,ends_at=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end where id=v_id;

  when 'account.link' then
    perform boss_private.admin_validate_input(i,array['person_id','auth_user_id'],array['person_id','auth_user_id']);
    perform boss_private.admin_require_permission('person.profile.manage');
    v_type:='user_account';v_person:=(i->>'person_id')::uuid;v_uid:=(i->>'auth_user_id')::uuid;
    if not exists(select 1 from public.people where id=v_person and status='active') or not exists(select 1 from auth.users where id=v_uid and email_confirmed_at is not null and not coalesce(is_anonymous,false) and deleted_at is null and (banned_until is null or banned_until<=now())) then raise exception 'Invalid operation' using errcode='PT422';end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('auth-link:'||v_uid::text,0));
    select id,person_id into v_account,v_existing from public.user_accounts where auth_user_id=v_uid;
    if found then
      if v_existing<>v_person then raise exception 'Conflicting operation' using errcode='PT409';end if;
      v_id:=v_account;
      return jsonb_build_object('resource_type',v_type,'resource_id',v_id);
    end if;
    if exists(select 1 from public.user_accounts where person_id=v_person and account_status='active') then raise exception 'Conflicting operation' using errcode='PT409';end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    insert into public.user_accounts(id,auth_user_id,person_id,account_status) values(v_id,v_uid,v_person,'active');
  when 'identity.provision_self' then
    perform boss_private.admin_validate_input(i,array['display_name'],array[]::text[]);
    v_uid:=boss_private.require_live_auth();v_type:='person';
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('auth-link:'||v_uid::text,0));
    select person_id into v_existing from public.user_accounts where auth_user_id=v_uid;
    if found then
      if boss_private.current_person_id() is null then raise exception 'Access denied' using errcode='PT403';end if;
      return jsonb_build_object('resource_type',v_type,'resource_id',v_existing);
    end if;
    select email into v_email from auth.users where id=v_uid;
    if v_email is not null and exists(select 1 from public.people where lower(primary_email)=lower(v_email)) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    if p_check_only then raise exception 'Access denied' using errcode='PT403';end if;
    insert into public.people(id,display_name) values(v_id,coalesce(i->>'display_name','Boss member'));
    insert into public.user_accounts(auth_user_id,person_id,account_status) values(v_uid,v_id,'active');
    p_actor:=v_id;v_person:=v_id;
    insert into public.audit_events(actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
      values(p_actor,v_uid,'account.link','user_account',(select id from public.user_accounts where auth_user_id=v_uid),'person',v_id,p_request,jsonb_build_object('fields',jsonb_build_array('auth_user_id','person_id','account_status')));
  when 'module.set' then
    perform boss_private.admin_validate_input(i,array['organization_id','module_id','status'],array['organization_id','module_id','status']);
    v_org:=(i->>'organization_id')::uuid;v_anchor:=(i->>'module_id')::uuid;v_type:='organization_module';
    perform boss_private.admin_require_permission('organization.manage',v_org);
    if not exists(select 1 from public.organizations where id=v_org) or not exists(select 1 from public.modules where id=v_anchor and status='active') or i->>'status' not in ('active','inactive') then raise exception 'Invalid operation' using errcode='PT422';end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    update public.organizations set updated_at=updated_at where id=v_org; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('module:'||v_org::text||':'||v_anchor::text,0));
    select id into v_existing from public.organization_modules where organization_id=v_org and module_id=v_anchor and starts_at<=now() and (ends_at is null or ends_at>now()) order by starts_at desc limit 1 for update;
    if found then v_id:=v_existing;update public.organization_modules set status=i->>'status' where id=v_id;
    else insert into public.organization_modules(id,organization_id,module_id,status,source) values(v_id,v_org,v_anchor,i->>'status','operational_admin');end if;
  else raise exception 'Invalid operation' using errcode='PT422';
  end case;
  if v_scope is null or v_scope not in ('household') then
    if v_team is not null then v_scope:='team';v_anchor:=v_team;
    elsif v_unit is not null then v_scope:='organization_unit';v_anchor:=v_unit;
    elsif v_org is not null then v_scope:='organization';v_anchor:=v_org;
    elsif v_person is not null then v_scope:='person';v_anchor:=v_person;
    else v_scope:='platform';v_anchor:=null;end if;
  end if;
  if v_scope in ('person','household','platform') then v_org:=null;end if;
  insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
    values(v_org,p_actor,auth.uid(),p_operation,v_type,v_id,v_scope,v_anchor,p_request,jsonb_build_object('fields',(select jsonb_agg(key order by key) from jsonb_object_keys(i) key)));
  return jsonb_build_object('resource_type',v_type,'resource_id',v_id);
end;
$$;
revoke all on function boss_private.admin_mutate_command(text,jsonb,uuid,uuid,boolean,uuid) from public, anon, authenticated, service_role;

create function boss_private.admin_mutate(p_commands jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid;v_actor uuid;v_hash bytea;v_receipt record;v_command jsonb;v_input jsonb;
  v_key text;v_value jsonb;v_ref text;v_expected text;v_operation text;v_result jsonb;
  v_refs jsonb:='{}'::jsonb;v_results jsonb:='[]'::jsonb;v_resolved jsonb:='[]'::jsonb;
  v_index integer:=0;v_id uuid;v_self boolean;
begin
  v_uid:=boss_private.require_live_auth();
  if p_request_id is null or jsonb_typeof(p_commands) is distinct from 'array'
    or jsonb_array_length(p_commands) not between 1 and 12
    or pg_catalog.octet_length(p_commands::text)>24000 then raise exception 'Invalid operation' using errcode='PT422';end if;
  v_self:=jsonb_array_length(p_commands)=1 and p_commands->0->>'operation'='identity.provision_self';
  v_actor:=boss_private.current_person_id();
  if v_actor is null and not v_self then raise exception 'Access denied' using errcode='PT403';end if;
  -- Serialize provision/retries before canonical identity exists. The key never
  -- appears in logs, responses or audit payloads.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('admin-request:'||v_uid::text||':'||p_request_id::text,0));
  v_actor:=boss_private.current_person_id();
  v_hash:=pg_catalog.sha256(pg_catalog.convert_to(p_commands::text,'UTF8'));
  if v_actor is not null then
    select * into v_receipt from boss_private.admin_operation_receipts
      where actor_person_id=v_actor and request_id=p_request_id;
    if found then
      if v_receipt.input_hash<>v_hash then raise exception 'Conflicting operation' using errcode='PT409';end if;
      -- Re-run authorization against current roles/resources before a replay.
      -- Created resource IDs are internal receipt data, never accepted as create input.
      for v_command in select value from jsonb_array_elements(v_receipt.resolved_commands) loop
        perform boss_private.admin_mutate_command(v_command->>'operation',v_command->'input',v_actor,p_request_id,true,(v_receipt.result->'results'->v_index->>'resource_id')::uuid);
        v_index:=v_index+1;
      end loop;
      return v_receipt.result;
    end if;
  end if;
  for v_command in select value from jsonb_array_elements(p_commands) loop
    if jsonb_typeof(v_command) is distinct from 'object' or exists(select 1 from jsonb_object_keys(v_command) k where k not in ('operation','input','ref')) or jsonb_typeof(v_command->'operation') is distinct from 'string' or jsonb_typeof(v_command->'input') is distinct from 'object' then raise exception 'Invalid operation' using errcode='PT422';end if;
    v_operation:=v_command->>'operation';v_input:=v_command->'input';
    if v_operation='identity.provision_self' and not v_self then raise exception 'Invalid operation' using errcode='PT422';end if;
    v_ref:=null;
    if v_command?'ref' then
      if jsonb_typeof(v_command->'ref')<>'string' or v_command->>'ref' !~ '^[a-z][a-z0-9_]{0,31}$' or v_refs?(v_command->>'ref') then raise exception 'Invalid operation' using errcode='PT422';end if;
      v_ref:=v_command->>'ref';
    end if;
    for v_key,v_value in select key,value from jsonb_each(v_input) loop
      if jsonb_typeof(v_value)='object' then
        if (select count(*) from jsonb_object_keys(v_value))<>1 or jsonb_typeof(v_value->'$ref') is distinct from 'string' or not v_refs?(v_value->>'$ref') then raise exception 'Invalid operation' using errcode='PT422';end if;
        v_expected:=case v_key
          when 'person_id' then 'person' when 'guardian_person_id' then 'person' when 'dependent_person_id' then 'person'
          when 'organization_id' then 'organization' when 'parent_unit_id' then 'organization_unit'
          when 'season_id' then 'season' when 'team_id' then 'team' when 'household_id' then 'household'
          when 'participant_id' then 'participant'
          when 'scope_id' then case v_input->>'scope_type' when 'organization' then 'organization' when 'organization_unit' then 'organization_unit' when 'team' then 'team' end
          when 'id' then case split_part(v_operation,'.',1) when 'person' then 'person' when 'organization' then 'organization' when 'unit' then 'organization_unit' when 'season' then 'season' when 'team' then 'team' when 'household' then 'household' when 'participant' then 'participant' when 'guardian' then 'guardian_relationship' when 'household_membership' then 'household_membership' when 'organization_membership' then 'organization_membership' when 'team_membership' then 'team_membership' when 'role_assignment' then 'role_assignment' end
        end;
        if v_expected is null or v_refs->(v_value->>'$ref')->>'resource_type' is distinct from v_expected then raise exception 'Invalid operation' using errcode='PT422';end if;
        v_input:=jsonb_set(v_input,array[v_key],v_refs->(v_value->>'$ref')->'resource_id');
      end if;
    end loop;
    v_result:=boss_private.admin_mutate_command(v_operation,v_input,v_actor,p_request_id);
    if v_ref is not null then v_refs:=jsonb_set(v_refs,array[v_ref],v_result);v_result:=v_result||jsonb_build_object('ref',v_ref);end if;
    v_results:=v_results||jsonb_build_array(v_result);
    v_resolved:=v_resolved||jsonb_build_array(jsonb_build_object('operation',v_operation,'input',v_input));
    if v_actor is null then v_actor:=boss_private.require_admin_actor();end if;
  end loop;
  v_result:=jsonb_build_object('request_id',p_request_id,'results',v_results);
  insert into boss_private.admin_operation_receipts(actor_person_id,request_id,input_hash,resolved_commands,result) values(v_actor,p_request_id,v_hash,v_resolved,v_result);
  return v_result;
exception
  when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' then raise;
  when unique_violation or exclusion_violation or serialization_failure or deadlock_detected then raise exception 'Conflicting operation' using errcode='PT409';
  when others then raise exception 'Invalid operation' using errcode='PT422';
end;
$$;
revoke all on function boss_private.admin_mutate(jsonb,uuid) from public, anon, authenticated, service_role;
grant execute on function boss_private.admin_mutate(jsonb,uuid) to authenticated;

create function public.boss_admin_mutate(p_commands jsonb,p_request_id uuid)
returns jsonb language sql security invoker set search_path = '' as $$
  select boss_private.admin_mutate(p_commands,p_request_id)
$$;
revoke all on function public.boss_admin_mutate(jsonb,uuid) from public, anon, authenticated, service_role;
grant execute on function public.boss_admin_mutate(jsonb,uuid) to authenticated;
