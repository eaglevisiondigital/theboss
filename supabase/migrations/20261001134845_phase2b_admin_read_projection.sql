-- Bounded, explicit admin projections. Base collections execute as the caller
-- under the unchanged Phase 2A SELECT policies. The two private lookups expose
-- only safe context/name fields and resolve actual relationships internally.
create function boss_private.admin_record(p_id uuid, p_label text, p_status text, p_fields jsonb, p_operations text[] default '{}')
returns jsonb language sql immutable security invoker set search_path = '' as $$
  select jsonb_build_object('id',p_id,'label',coalesce(nullif(p_label,''),'Unnamed record'),
    'status',p_status,'fields',p_fields,'operations',to_jsonb(p_operations))
$$;
revoke all on function boss_private.admin_record(uuid,text,text,jsonb,text[]) from public,anon,authenticated,service_role;
grant execute on function boss_private.admin_record(uuid,text,text,jsonb,text[]) to authenticated;

create function boss_private.admin_contexts(p_query text default null,p_organization_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  perform boss_private.require_admin_actor();
  select coalesce(jsonb_agg(item order by label,id),'[]'::jsonb) into result from (
    select o.id,o.name label,boss_private.admin_record(o.id,o.name,o.status,
      case when boss_private.has_permission('organization.view') or boss_private.has_permission('organization.view',o.id)
        then jsonb_build_object('name',o.name,'legal_name',o.legal_name,'slug',o.slug,'organization_type',o.organization_type,
          'timezone',o.timezone,'country',o.country,'default_currency',o.default_currency)
        else jsonb_build_object('name',o.name,'slug',o.slug) end,
      case when boss_private.has_permission('organization.manage') or boss_private.has_permission('organization.manage',o.id)
        then array['organization.update'] else '{}'::text[] end) item
    from public.organizations o
    where (p_organization_id is null or o.id=p_organization_id) and (p_query is null or o.name ilike '%'||p_query||'%' or o.slug ilike '%'||p_query||'%') and (
      boss_private.has_permission('organization.view') or boss_private.has_active_organization_membership(o.id)
      or boss_private.has_permission('organization.view',o.id)
      or exists(select 1 from public.organization_units u where u.organization_id=o.id
        and boss_private.has_permission('organization.view',o.id,u.id))
      or exists(select 1 from public.teams t where t.organization_id=o.id and (
        boss_private.has_active_team_relationship(t.id) or boss_private.has_permission('team.view',o.id,t.parent_unit_id,t.id)))
    ) order by o.name,o.id limit 50
  ) s;
  return result;
end $$;
revoke all on function boss_private.admin_contexts(text,uuid) from public,anon,authenticated,service_role;
grant execute on function boss_private.admin_contexts(text,uuid) to authenticated;

create function boss_private.admin_people(p_organization_id uuid default null,p_query text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid; result jsonb;
begin
  actor:=boss_private.require_admin_actor();
  -- A scoped name projection does not grant the underlying sensitive person row.
  if p_query is not null and p_organization_id is null and not boss_private.has_permission('person.profile.view') then
    raise exception 'Request not permitted.' using errcode='PT403';
  end if;
  select coalesce(jsonb_agg(item order by label,id),'[]'::jsonb) into result from (
    select p.id,coalesce(p.display_name,p.preferred_name,nullif(concat_ws(' ',p.first_name,p.last_name),''),'Unnamed person') label,
      boss_private.admin_record(p.id,coalesce(p.display_name,p.preferred_name,nullif(concat_ws(' ',p.first_name,p.last_name),'')),p.status,
        jsonb_build_object('first_name',p.first_name,'middle_name',p.middle_name,'last_name',p.last_name,'preferred_name',p.preferred_name,'display_name',p.display_name),
        array_remove(array[
          case when boss_private.has_permission('person.profile.manage') or boss_private.can_manage_dependent_profile(p.id) then 'person.update' end,
          case when p.status='active' and (boss_private.has_permission('participant.profile.manage') or (p_organization_id is not null and (
            exists(select 1 from public.organization_memberships m where m.person_id=p.id and m.organization_id=p_organization_id and m.status='active'
              and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()) and boss_private.has_permission('participant.profile.manage',m.organization_id))
            or exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id and t.organization_id=m.organization_id
              where m.person_id=p.id and m.organization_id=p_organization_id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())
                and boss_private.has_permission('participant.profile.manage',t.organization_id,t.parent_unit_id,t.id))))) then 'participant.create' end
        ],null)) item
    from public.people p
    where (p_query is null or concat_ws(' ',p.first_name,p.last_name,p.preferred_name,p.display_name) ilike '%'||p_query||'%') and (
      boss_private.has_permission('person.profile.view') or p.id=actor or boss_private.can_manage_dependent_profile(p.id)
      or (p_organization_id is not null and (
        exists(select 1 from public.organization_memberships m where m.person_id=p.id and m.organization_id=p_organization_id and m.status='active'
          and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()) and boss_private.has_permission('organization.members.view',m.organization_id))
        or exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id and t.organization_id=m.organization_id
          where m.person_id=p.id and m.organization_id=p_organization_id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())
            and (boss_private.has_permission('team.roster.view',t.organization_id,t.parent_unit_id,t.id)
              or boss_private.has_permission('participant.profile.view',t.organization_id,t.parent_unit_id,t.id)))
      ))
    ) order by label,p.id limit 50
  ) s;
  return result;
end $$;
revoke all on function boss_private.admin_people(uuid,text) from public,anon,authenticated,service_role;
grant execute on function boss_private.admin_people(uuid,text) to authenticated;

-- Global read capability has a separate, narrowly projected lifecycle view.
-- Scoped clients retain active-resource RLS; this does not open table policies.
create function boss_private.admin_platform_records(p_collection text,p_organization_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid; rows jsonb;
begin
  actor:=boss_private.require_admin_actor();
  if p_collection='units' and boss_private.has_permission('organization.view') then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(u.id,u.name,u.status,jsonb_build_object('organization_id',u.organization_id,'parent_unit_id',u.parent_unit_id,
        'name',u.name,'slug',u.slug,'unit_type',u.unit_type,'sort_order',u.sort_order),
        array_remove(array[
          case when boss_private.has_permission('organization.manage') then 'unit.update' end,
          case when u.status='active' and o.status='active' and boss_private.has_permission('organization.manage') then 'season.create' end,
          case when u.status='active' and o.status='active' and boss_private.has_permission('team.manage') then 'team.create' end
        ],null)) item from public.organization_units u join public.organizations o on o.id=u.organization_id
      where u.organization_id=p_organization_id order by u.sort_order,u.name,u.id limit 100
    ) s;
  elsif p_collection='teams' and boss_private.has_permission('team.view') then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(t.id,t.name,t.status,jsonb_build_object('organization_id',t.organization_id,'parent_unit_id',t.parent_unit_id,
        'season_id',t.season_id,'name',t.name,'short_name',t.short_name,'slug',t.slug,'visibility',t.visibility),
        array_remove(array[
          case when boss_private.has_permission('team.manage') then 'team.update' end,
          case when boss_private.has_permission('team.roster.manage') then 'team_membership.add' end,
          case when boss_private.has_permission('roles.assign') then 'role_assignment.add' end
        ],null)) item from public.teams t where t.organization_id=p_organization_id order by t.name,t.id limit 100
    ) s;
  elsif p_collection='audit' and boss_private.has_permission('audit.view') then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(a.id,a.action,null,jsonb_build_object('action',a.action,'resource_type',a.resource_type,'resource_id',a.resource_id,
        'occurred_at',a.created_at,'organization_id',a.organization_id,'scope_type',a.scope_type,'actor',case when a.actor_person_id=actor then 'You'
          when boss_private.has_permission('person.profile.view') then coalesce(p.display_name,p.preferred_name,nullif(concat_ws(' ',p.first_name,p.last_name),''),'Actor '||a.actor_person_id::text,'System')
          else coalesce('Actor '||a.actor_person_id::text,'System') end)) item
      from public.audit_events a left join public.people p on p.id=a.actor_person_id
      where p_organization_id is null or a.organization_id=p_organization_id order by a.created_at desc,a.id limit 100
    ) s;
  else raise exception 'Request not permitted.' using errcode='PT403';
  end if;
  return rows;
end $$;
revoke all on function boss_private.admin_platform_records(text,uuid) from public,anon,authenticated,service_role;
grant execute on function boss_private.admin_platform_records(text,uuid) to authenticated;

create function public.boss_admin_read(p_view text,p_organization_id uuid default null,p_query text default null)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  actor uuid; person jsonb; contexts jsonb; records jsonb:='{}'; ops text[]:='{}'; nav text[]:='{}'; rows jsonb;
  org_manage boolean; team_manage boolean; household_manage boolean; guardian_manage boolean; org_members_manage boolean; role_manage boolean;
begin
  perform boss_private.require_live_auth();
  if p_view is null or p_view not in ('home','organizations','people','families','teams','access','audit','account') or length(coalesce(p_query,''))>100 or coalesce(p_query,'') ~ '[[:cntrl:]]' then
    raise exception 'Invalid request.' using errcode='PT422';
  end if;
  actor:=boss_private.current_person_id();
  if actor is null then return jsonb_build_object('provisioned',false,'person',null,'organizations','[]'::jsonb,'organizationId',null,
    'operations',jsonb_build_array('identity.provision_self'),'navigation','[]'::jsonb,'records','{}'::jsonb); end if;
  contexts:=boss_private.admin_contexts(case when p_view='organizations' then nullif(btrim(p_query),'') end);
  if p_organization_id is not null and jsonb_array_length(boss_private.admin_contexts(null,p_organization_id))=0 then
    raise exception 'Request not permitted.' using errcode='PT403';
  end if;
  if p_organization_id is not null and not exists(select 1 from jsonb_array_elements(contexts) c where c->>'id'=p_organization_id::text) then
    contexts:=boss_private.admin_contexts(null,p_organization_id)||contexts;
  end if;
  select jsonb_build_object('id',id,'label',coalesce(display_name,preferred_name,nullif(concat_ws(' ',first_name,last_name),''),'Boss member')) into person
    from public.people where id=actor;
  org_manage:=boss_private.has_permission('organization.manage') or (p_organization_id is not null and boss_private.has_permission('organization.manage',p_organization_id));
  team_manage:=boss_private.has_permission('team.manage') or (p_organization_id is not null and boss_private.has_permission('team.manage',p_organization_id));
  household_manage:=boss_private.has_permission('household.manage');
  guardian_manage:=household_manage and boss_private.has_permission('person.profile.manage');
  org_members_manage:=boss_private.has_permission('organization.members.manage') or (p_organization_id is not null and boss_private.has_permission('organization.members.manage',p_organization_id));
  role_manage:=boss_private.has_permission('roles.assign') or (p_organization_id is not null and boss_private.has_permission('roles.assign',p_organization_id));
  ops:=array_remove(array[
    case when boss_private.has_permission('organization.manage') then 'organization.create' end,
    case when boss_private.has_permission('person.profile.manage') then 'person.create' end,
    case when boss_private.has_permission('person.profile.manage') then 'account.link' end,
    case when household_manage then 'household.create' end,
    case when household_manage then 'household_membership.add' end,
    case when guardian_manage then 'guardian.create' end,
    case when boss_private.has_permission('participant.profile.manage') then 'participant.create' end,
    case when p_organization_id is not null and org_manage then 'module.set' end,
    case when p_organization_id is not null and org_manage then 'unit.create' end,
    case when p_organization_id is not null and org_manage then 'season.create' end,
    case when p_organization_id is not null and team_manage then 'team.create' end,
    case when boss_private.has_permission('organization.members.manage') or (p_organization_id is not null and org_members_manage) then 'organization_membership.add' end,
    case when role_manage then 'role_assignment.add' end
  ],null);
  if jsonb_array_length(contexts)>0 or boss_private.has_permission('organization.view') then nav:=array_append(nav,'organizations'); end if;
  -- Own/dependent identity views are finite. A global name search is platform-only.
  nav:=array_append(nav,'people');
  if boss_private.has_permission('household.view') or exists(select 1 from public.households) or exists(select 1 from public.guardian_relationships) then nav:=array_append(nav,'families'); end if;
  if boss_private.has_permission('team.view') or exists(select 1 from public.teams)
    or exists(select 1 from jsonb_array_elements(contexts) c where boss_private.has_permission('team.view',(c->>'id')::uuid))
    or exists(select 1 from public.organization_units u where boss_private.has_permission('team.manage',u.organization_id,u.id)) then nav:=array_append(nav,'teams'); end if;
  if boss_private.has_permission('roles.view') or exists(select 1 from public.role_assignments) then nav:=array_append(nav,'access'); end if;
  if boss_private.has_permission('audit.view') or exists(select 1 from jsonb_array_elements(contexts) c where boss_private.has_permission('audit.view',(c->>'id')::uuid))
    or exists(select 1 from public.organization_units u where boss_private.has_permission('audit.view',u.organization_id,u.id))
    or exists(select 1 from public.teams t where boss_private.has_permission('audit.view',t.organization_id,t.parent_unit_id,t.id)) then nav:=array_append(nav,'audit'); end if;
  if p_view not in ('home','account','people') and not p_view=any(nav) then raise exception 'Request not permitted.' using errcode='PT403'; end if;
  records:=jsonb_build_object('organizations',contexts);
  if p_view in ('people','families','teams','access','home','organizations') then
    records:=records||jsonb_build_object('people',boss_private.admin_people(p_organization_id,case when p_view='people' then nullif(btrim(p_query),'') end));
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(p.id,coalesce(n->>'label','Participant'),p.status,jsonb_build_object('person_id',p.person_id,'participant_type',p.participant_type),
        case when n->>'status'='active' and (boss_private.has_permission('participant.profile.manage') or (p_organization_id is not null and n->'operations' ? 'participant.create'))
          then array['participant.update'] else '{}'::text[] end) item
      from public.participants p left join lateral (select pr from jsonb_array_elements(records->'people') pr where pr->>'id'=p.person_id::text limit 1) names(n) on true
      where exists(select 1 from jsonb_array_elements(records->'people') pr where pr->>'id'=p.person_id::text) order by p.id limit 50
    ) s;
    records:=records||jsonb_build_object('participants',rows);
  end if;
  if p_view in ('organizations','teams','access') and p_organization_id is not null then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(u.id,u.name,u.status,jsonb_build_object('organization_id',u.organization_id,'parent_unit_id',u.parent_unit_id,'name',u.name,'slug',u.slug,'unit_type',u.unit_type,'sort_order',u.sort_order),
        array_remove(array[
          case when boss_private.has_permission('organization.manage') or boss_private.has_permission('organization.manage',u.organization_id,u.id) then 'unit.update' end,
          case when u.status='active' and (org_manage or boss_private.has_permission('organization.manage',u.organization_id,u.id)) then 'season.create' end,
          case when u.status='active' and (team_manage or boss_private.has_permission('team.manage',u.organization_id,u.id)) then 'team.create' end
        ],null)) item from public.organization_units u where u.organization_id=p_organization_id order by u.sort_order,u.name,u.id limit 100
    ) s;
    if boss_private.has_permission('organization.view') then rows:=boss_private.admin_platform_records('units',p_organization_id); end if;
    records:=records||jsonb_build_object('units',rows);
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(s.id,s.name,s.status,jsonb_build_object('organization_id',s.organization_id,'parent_unit_id',s.parent_unit_id,'name',s.name,'starts_on',s.starts_on,'ends_on',s.ends_on),
        case when boss_private.has_permission('organization.manage') or boss_private.has_permission('organization.manage',s.organization_id,s.parent_unit_id) then array['season.update'] else '{}'::text[] end) item
      from public.seasons s where s.organization_id=p_organization_id order by s.created_at desc,s.id limit 100
    ) s;
    records:=records||jsonb_build_object('seasons',rows);
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(t.id,t.name,t.status,jsonb_build_object('organization_id',t.organization_id,'parent_unit_id',t.parent_unit_id,'season_id',t.season_id,'name',t.name,'short_name',t.short_name,'slug',t.slug,'visibility',t.visibility),
        array_remove(array[
          case when boss_private.has_permission('team.manage') or boss_private.has_permission('team.manage',t.organization_id,t.parent_unit_id,t.id) then 'team.update' end,
          case when boss_private.has_permission('team.roster.manage') or boss_private.has_permission('team.roster.manage',t.organization_id,t.parent_unit_id,t.id) then 'team_membership.add' end,
          case when boss_private.has_permission('roles.assign') or boss_private.has_permission('roles.assign',t.organization_id,t.parent_unit_id,t.id) then 'role_assignment.add' end
        ],null)) item from public.teams t where t.organization_id=p_organization_id order by t.name,t.id limit 100
    ) s;
    if boss_private.has_permission('team.view') then rows:=boss_private.admin_platform_records('teams',p_organization_id); end if;
    records:=records||jsonb_build_object('teams',rows);
    if p_view='organizations' then
      select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
        select boss_private.admin_record(m.id,m.name,m.status,jsonb_build_object('module_id',m.id,'module_key',m.key,
          'activation_status',case when boss_private.organization_module_active(p_organization_id,m.key) then 'active' else 'inactive' end,
          'implementation_status','Future / not implemented'),case when org_manage then array['module.set'] else '{}'::text[] end) item
        from public.modules m order by m.name,m.id
      ) s;
      records:=records||jsonb_build_object('modules',rows);
    end if;
    if p_view in ('teams','access') then
      select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
        select boss_private.admin_record(m.id,coalesce(pr->>'label','Member')||' / '||m.membership_type,m.status,
          jsonb_build_object('organization_id',m.organization_id,'team_id',m.team_id,'person_id',m.person_id,'participant_id',m.participant_id,
            'membership_type',m.membership_type,'starts_at',m.starts_at,'ends_at',m.ends_at,'jersey_number',m.jersey_number,'position_label',m.position_label),
          case when boss_private.has_permission('team.roster.manage') or boss_private.has_resource_permission('team.roster.manage','team',m.team_id,m.organization_id)
            then array['team_membership.update'] else '{}'::text[] end) item
        from public.team_memberships m left join lateral (select p from jsonb_array_elements(records->'people') p where p->>'id'=m.person_id::text limit 1) names(pr) on true
        where m.organization_id=p_organization_id order by m.created_at desc,m.id limit 100
      ) s;
      records:=records||jsonb_build_object('team_memberships',rows);
    end if;
  end if;
  if p_view='families' then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(h.id,h.name,h.status,jsonb_build_object('name',h.name),
        case when household_manage then array['household.update','household_membership.add'] else '{}'::text[] end) item
      from public.households h where nullif(btrim(p_query),'') is null or h.name ilike '%'||p_query||'%' order by h.name,h.id limit 50
    ) s;
    records:=records||jsonb_build_object('households',rows);
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(m.id,coalesce(pr->>'label','Member')||' / '||m.relationship_type,m.status,
        jsonb_build_object('household_id',m.household_id,'person_id',m.person_id,'relationship_type',m.relationship_type,'is_primary_contact',m.is_primary_contact,'starts_at',m.starts_at,'ends_at',m.ends_at),
        case when household_manage then array['household_membership.update'] else '{}'::text[] end) item
      from public.household_memberships m left join lateral (select p from jsonb_array_elements(records->'people') p where p->>'id'=m.person_id::text limit 1) names(pr) on true
      order by m.created_at desc,m.id limit 100
    ) s;
    records:=records||jsonb_build_object('household_memberships',rows);
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(g.id,coalesce(pr->>'label','Dependent')||' / '||g.relationship_type,g.authority_status,
        jsonb_build_object('guardian_person_id',g.guardian_person_id,'dependent_person_id',g.dependent_person_id,'relationship_type',g.relationship_type,
          'authority_status',g.authority_status,'starts_at',g.starts_at,'ends_at',g.ends_at,'verified_at',g.verified_at,
          'can_register',g.can_register,'can_sign_waivers',g.can_sign_waivers,'can_view_documents',g.can_view_documents,'can_manage_payments',g.can_manage_payments,'can_manage_profile',g.can_manage_profile),
        case when guardian_manage then array_remove(array['guardian.update',case when actor not in (g.guardian_person_id,g.dependent_person_id) then 'guardian.verify' end],null) else '{}'::text[] end) item
      from public.guardian_relationships g left join lateral (select p from jsonb_array_elements(records->'people') p where p->>'id'=g.dependent_person_id::text limit 1) names(pr) on true
      order by g.created_at desc,g.id limit 100
    ) s;
    records:=records||jsonb_build_object('guardians',rows);
  end if;
  if p_view in ('teams','access','organizations') then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(r.id,r.name,r.status,jsonb_build_object('key',r.key,'allowed_scope_types',to_jsonb(r.allowed_scope_types))) item
      from public.roles r where r.status='active' order by r.name,r.id
    ) s;
    records:=records||jsonb_build_object('roles',rows);
  end if;
  if p_view='access' then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(m.id,coalesce(pr->>'label','Member')||' / '||m.membership_type,m.status,
        jsonb_build_object('organization_id',m.organization_id,'person_id',m.person_id,'membership_type',m.membership_type,'starts_at',m.starts_at,'ends_at',m.ends_at),
        case when org_members_manage then array['organization_membership.update'] else '{}'::text[] end) item
      from public.organization_memberships m left join lateral (select p from jsonb_array_elements(records->'people') p where p->>'id'=m.person_id::text limit 1) names(pr) on true
      where p_organization_id is null or m.organization_id=p_organization_id order by m.created_at desc,m.id limit 100
    ) s;
    records:=records||jsonb_build_object('organization_memberships',rows);
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(a.id,coalesce(r.name,'Role')||' / '||a.scope_type,a.status,
        jsonb_build_object('person_id',a.person_id,'role_id',a.role_id,'scope_type',a.scope_type,'scope_id',a.scope_id,'organization_id',a.organization_id,'starts_at',a.starts_at,'ends_at',a.ends_at),
        case when boss_private.has_permission('roles.assign') or boss_private.has_resource_permission('roles.assign',a.scope_type,a.scope_id,a.organization_id)
          then array['role_assignment.update'] else '{}'::text[] end) item
      from public.role_assignments a join public.roles r on r.id=a.role_id where p_organization_id is null or a.organization_id=p_organization_id
      order by a.created_at desc,a.id limit 100
    ) s;
    records:=records||jsonb_build_object('role_assignments',rows);
  end if;
  if p_view='audit' then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(a.id,a.action,null,jsonb_build_object('action',a.action,'resource_type',a.resource_type,'resource_id',a.resource_id,
        'occurred_at',a.created_at,'organization_id',a.organization_id,'scope_type',a.scope_type,'actor',case when a.actor_person_id=actor then 'You'
          else coalesce(p.display_name,p.preferred_name,nullif(concat_ws(' ',p.first_name,p.last_name),''),'Actor '||a.actor_person_id::text,'System') end)) item
      from public.audit_events a left join public.people p on p.id=a.actor_person_id
      where p_organization_id is null or a.organization_id=p_organization_id order by a.created_at desc,a.id limit 100
    ) s;
    if boss_private.has_permission('audit.view') then rows:=boss_private.admin_platform_records('audit',p_organization_id); end if;
    records:=records||jsonb_build_object('audit',rows);
  end if;
  return jsonb_build_object('provisioned',true,'person',person,'organizations',contexts,'organizationId',p_organization_id,
    'operations',to_jsonb(ops),'navigation',to_jsonb(nav),'records',records);
end $$;
revoke all on function public.boss_admin_read(text,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.boss_admin_read(text,uuid,text) to authenticated;
