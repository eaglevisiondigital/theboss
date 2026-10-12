-- RLS predicates inspect canonical, database-owned authorization records.
-- The small caller-bound lookups below are SECURITY DEFINER because querying
-- their own protected tables through RLS would create recursive policies.
-- They expose only the caller's identity/authorization booleans, never accept
-- an impersonated actor, use fully qualified names, and are not Data API RPCs.

create function boss_private.current_person_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select a.person_id
  from public.user_accounts a join public.people p on p.id = a.person_id
  where a.auth_user_id = (select auth.uid())
    and (select auth.uid()) is not null
    and (select auth.jwt()->>'role') = 'authenticated'
    and coalesce((select auth.jwt()->>'is_anonymous'), 'false') <> 'true'
    and a.account_status = 'active' and p.status = 'active'
$$;

create function boss_private.has_active_organization_membership(p_organization_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.organization_memberships m
    join public.organizations o on o.id = m.organization_id
    where m.person_id = (select boss_private.current_person_id())
      and m.organization_id = p_organization_id and o.status = 'active'
      and m.status = 'active' and m.starts_at <= now()
      and (m.ends_at is null or m.ends_at > now())
  )
$$;

create function boss_private.has_active_team_relationship(p_team_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.team_memberships m
    join public.teams t on t.id = m.team_id and t.organization_id = m.organization_id
    join public.organizations o on o.id = t.organization_id
    where m.person_id = (select boss_private.current_person_id())
      and m.team_id = p_team_id and t.status = 'active' and o.status = 'active'
      and m.status = 'active' and m.starts_at <= now()
      and (m.ends_at is null or m.ends_at > now())
  )
$$;

create function boss_private.has_active_household_membership(p_household_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.household_memberships m
    join public.households h on h.id = m.household_id
    where m.person_id = (select boss_private.current_person_id())
      and m.household_id = p_household_id and h.status = 'active'
      and m.status = 'active' and m.starts_at <= now()
      and (m.ends_at is null or m.ends_at > now())
  )
$$;

create function boss_private.can_manage_dependent_profile(p_dependent_person_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.guardian_relationships g
    join public.people p on p.id = g.dependent_person_id
    where g.guardian_person_id = (select boss_private.current_person_id())
      and g.dependent_person_id = p_dependent_person_id and p.status = 'active'
      and g.authority_status = 'active' and g.verified_at <= now()
      and g.can_manage_profile and g.starts_at <= now()
      and (g.ends_at is null or g.ends_at > now())
  )
$$;

create function boss_private.has_permission(
  p_permission_key text,
  p_organization_id uuid default null,
  p_organization_unit_id uuid default null,
  p_team_id uuid default null
) returns boolean language sql stable security definer set search_path = '' as $$
  select (select boss_private.current_person_id()) is not null
    -- Validate actual resource context before considering any scope match.
    and (p_organization_id is null or exists (
      select 1 from public.organizations o
      where o.id = p_organization_id and o.status = 'active'
    ))
    and (p_organization_unit_id is null or exists (
      select 1 from public.organization_units u
      where u.id = p_organization_unit_id and u.organization_id = p_organization_id
        and u.status = 'active'
    ))
    and (p_team_id is null or exists (
      select 1 from public.teams t
      where t.id = p_team_id and t.organization_id = p_organization_id
        and t.parent_unit_id is not distinct from p_organization_unit_id
        and t.status = 'active'
    ))
    and exists (
      select 1 from public.role_assignments a
      join public.roles r on r.id = a.role_id and r.status = 'active'
      join public.role_permissions rp on rp.role_id = r.id
      join public.permissions p on p.id = rp.permission_id and p.status = 'active'
      where a.person_id = (select boss_private.current_person_id())
        and p.key = p_permission_key and a.status = 'active'
        and a.starts_at <= now() and (a.ends_at is null or a.ends_at > now())
        and (
          (a.scope_type = 'platform' and a.scope_id is null and a.organization_id is null)
          or (a.scope_type = 'organization' and a.scope_id = p_organization_id
            and a.organization_id = p_organization_id)
          or (a.scope_type = 'organization_unit' and a.scope_id = p_organization_unit_id
            and a.organization_id = p_organization_id)
          or (a.scope_type = 'team' and a.scope_id = p_team_id
            and a.organization_id = p_organization_id)
        )
    )
$$;

create function boss_private.can_read_person(p_person_id uuid)
returns boolean language sql stable security invoker set search_path = '' as $$
  select (select boss_private.current_person_id()) is not null and (
    p_person_id = (select boss_private.current_person_id())
    or boss_private.can_manage_dependent_profile(p_person_id)
    or (select boss_private.has_permission('person.profile.view'))
  )
$$;

-- Resolve team context internally so reading a role/audit/roster row never
-- depends on an additional SELECT permission on its parent team row.
create function boss_private.has_resource_permission(
  p_permission_key text, p_scope_type text, p_scope_id uuid, p_organization_id uuid
) returns boolean language sql stable security definer set search_path = '' as $$
  select (select boss_private.current_person_id()) is not null and case
    when p_scope_type = 'platform' and p_scope_id is null and p_organization_id is null then
      boss_private.has_permission(p_permission_key)
    when p_scope_type = 'organization' and p_scope_id = p_organization_id then
      boss_private.has_permission(p_permission_key, p_organization_id)
    when p_scope_type = 'organization_unit' and p_scope_id is not null and p_organization_id is not null then
      boss_private.has_permission(p_permission_key, p_organization_id, p_scope_id)
    when p_scope_type = 'team' and p_scope_id is not null and p_organization_id is not null then exists (
      select 1 from public.teams t where t.id = p_scope_id and t.organization_id = p_organization_id
        and boss_private.has_permission(p_permission_key, t.organization_id, t.parent_unit_id, t.id)
    )
    when p_scope_type = 'person' and p_scope_id is not null and p_organization_id is null then
      boss_private.has_permission(p_permission_key)
      and exists (select 1 from public.people p where p.id = p_scope_id)
    when p_scope_type = 'household' and p_scope_id is not null and p_organization_id is null then
      boss_private.has_permission(p_permission_key)
      and exists (select 1 from public.households h where h.id = p_scope_id)
    else false end
$$;

create function boss_private.can_read_participant(p_participant_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.participants p
    where p.id = p_participant_id
      and (select boss_private.current_person_id()) is not null
      and (
        p.person_id = (select boss_private.current_person_id())
        or boss_private.can_manage_dependent_profile(p.person_id)
        or (select boss_private.has_permission('participant.profile.view'))
        or exists (
          select 1 from public.organization_memberships m
          where m.person_id = p.person_id and m.status = 'active'
            and m.starts_at <= now() and (m.ends_at is null or m.ends_at > now())
            and boss_private.has_permission('participant.profile.view', m.organization_id)
        )
        or exists (
          select 1 from public.team_memberships m
          join public.teams t on t.id = m.team_id and t.organization_id = m.organization_id
          where m.person_id = p.person_id and m.status = 'active'
            and m.starts_at <= now() and (m.ends_at is null or m.ends_at > now())
            and boss_private.has_permission('participant.profile.view', t.organization_id, t.parent_unit_id, t.id)
        )
      )
  )
$$;

create function boss_private.can_view_subject(
  p_subject_type text, p_subject_id uuid, p_membership_kind text default null
) returns boolean language sql stable security definer set search_path = '' as $$
  select (select boss_private.current_person_id()) is not null and case
    when p_subject_type = 'organization' and p_membership_kind is null then
      boss_private.has_active_organization_membership(p_subject_id)
      or boss_private.has_permission('organization.view', p_subject_id)
    when p_subject_type = 'person' and p_membership_kind is null then
      p_subject_id = (select boss_private.current_person_id())
      or (select boss_private.has_permission('person.profile.view'))
    when p_subject_type = 'household' and p_membership_kind is null then
      boss_private.has_active_household_membership(p_subject_id)
      or (select boss_private.has_permission('household.view'))
    when p_subject_type = 'membership' and p_membership_kind = 'organization' then exists (
      select 1 from public.organization_memberships m where m.id = p_subject_id
        and (m.person_id = (select boss_private.current_person_id())
          or boss_private.has_permission('organization.members.view', m.organization_id))
    )
    when p_subject_type = 'membership' and p_membership_kind = 'team' then exists (
      select 1 from public.team_memberships m
      join public.teams t on t.id = m.team_id and t.organization_id = m.organization_id
      where m.id = p_subject_id and (m.person_id = (select boss_private.current_person_id())
        or boss_private.has_permission('team.roster.view', t.organization_id, t.parent_unit_id, t.id))
    )
    when p_subject_type = 'membership' and p_membership_kind = 'household' then exists (
      select 1 from public.household_memberships m where m.id = p_subject_id
        and (m.person_id = (select boss_private.current_person_id())
          or (select boss_private.has_permission('household.view')))
    )
    else false end
$$;

create function boss_private.organization_module_active(p_organization_id uuid, p_module_key text)
returns boolean language sql stable security invoker set search_path = '' as $$
  select boss_private.can_view_subject('organization', p_organization_id) and exists (
    select 1 from public.organization_modules om
    join public.modules m on m.id = om.module_id and m.status = 'active'
    where om.organization_id = p_organization_id and m.key = p_module_key
      and om.status = 'active' and om.starts_at <= now()
      and (om.ends_at is null or om.ends_at > now())
  )
$$;

create function boss_private.has_active_entitlement(
  p_subject_type text, p_subject_id uuid, p_entitlement_key text,
  p_membership_kind text default null
) returns boolean language sql stable security definer set search_path = '' as $$
  select boss_private.can_view_subject(p_subject_type, p_subject_id, p_membership_kind) and exists (
    select 1 from public.entitlements e
    where e.subject_type = p_subject_type and e.subject_id = p_subject_id
      and e.membership_kind is not distinct from p_membership_kind
      and e.entitlement_key = p_entitlement_key and e.status = 'active'
      and e.starts_at <= now() and (e.ends_at is null or e.ends_at > now())
      -- Seeing one's relationship history does not make an expired membership
      -- an active subject for a current product-access check.
      and case
        when e.subject_type = 'person' then exists (
          select 1 from public.people p where p.id = e.subject_id and p.status = 'active')
        when e.subject_type = 'household' then exists (
          select 1 from public.households h where h.id = e.subject_id and h.status = 'active')
        when e.subject_type = 'organization' then exists (
          select 1 from public.organizations o where o.id = e.subject_id and o.status = 'active')
        when e.membership_kind = 'organization' then exists (
          select 1 from public.organization_memberships m
          join public.organizations o on o.id = m.organization_id and o.status = 'active'
          where m.id = e.subject_id and m.status = 'active' and m.starts_at <= now()
            and (m.ends_at is null or m.ends_at > now()))
        when e.membership_kind = 'team' then exists (
          select 1 from public.team_memberships m
          join public.teams t on t.id = m.team_id and t.organization_id = m.organization_id and t.status = 'active'
          join public.organizations o on o.id = t.organization_id and o.status = 'active'
          where m.id = e.subject_id and m.status = 'active' and m.starts_at <= now()
            and (m.ends_at is null or m.ends_at > now()))
        when e.membership_kind = 'household' then exists (
          select 1 from public.household_memberships m
          join public.households h on h.id = m.household_id and h.status = 'active'
          where m.id = e.subject_id and m.status = 'active' and m.starts_at <= now()
            and (m.ends_at is null or m.ends_at > now()))
        else false end
  )
$$;

-- No visibility value alone publishes a row. There are deliberately no anon
-- policies, no public projections, and no authenticated mutation policies.
create policy people_read on public.people for select to authenticated
  using (boss_private.can_read_person(id));
create policy accounts_read on public.user_accounts for select to authenticated
  using (person_id = (select boss_private.current_person_id())
    or (select boss_private.has_permission('person.profile.view')));
create policy participants_read on public.participants for select to authenticated
  using (boss_private.can_read_participant(id));
create policy organizations_read on public.organizations for select to authenticated
  using (boss_private.has_active_organization_membership(id)
    or boss_private.has_permission('organization.view', id));
create policy units_read on public.organization_units for select to authenticated
  using (boss_private.has_active_organization_membership(organization_id)
    or boss_private.has_permission('organization.view', organization_id, id));
create policy seasons_read on public.seasons for select to authenticated
  using (boss_private.has_active_organization_membership(organization_id)
    or boss_private.has_permission('organization.view', organization_id, parent_unit_id)
    or exists (select 1 from public.teams t where t.season_id = seasons.id
      and boss_private.has_active_team_relationship(t.id)));
create policy teams_read on public.teams for select to authenticated
  using (boss_private.has_active_team_relationship(id)
    or boss_private.has_permission('team.view', organization_id, parent_unit_id, id));
create policy organization_memberships_read on public.organization_memberships for select to authenticated
  using (person_id = (select boss_private.current_person_id())
    or boss_private.has_permission('organization.members.view', organization_id));
create policy team_memberships_read on public.team_memberships for select to authenticated
  using (person_id = (select boss_private.current_person_id())
    or boss_private.has_resource_permission('team.roster.view', 'team', team_id, organization_id));
create policy households_read on public.households for select to authenticated
  using (boss_private.has_active_household_membership(id)
    or (select boss_private.has_permission('household.view')));
create policy household_memberships_read on public.household_memberships for select to authenticated
  using (person_id = (select boss_private.current_person_id())
    or (select boss_private.has_permission('household.view')));
create policy guardians_read on public.guardian_relationships for select to authenticated
  using (guardian_person_id = (select boss_private.current_person_id())
    or dependent_person_id = (select boss_private.current_person_id())
    or (select boss_private.has_permission('household.view')));
create policy roles_read on public.roles for select to authenticated
  using ((select boss_private.current_person_id()) is not null);
create policy permissions_read on public.permissions for select to authenticated
  using ((select boss_private.current_person_id()) is not null);
create policy role_permissions_read on public.role_permissions for select to authenticated
  using ((select boss_private.current_person_id()) is not null);
create policy role_assignments_read on public.role_assignments for select to authenticated
  using (person_id = (select boss_private.current_person_id())
    or boss_private.has_resource_permission('roles.view', scope_type, scope_id, organization_id));
create policy modules_read on public.modules for select to authenticated
  using ((select boss_private.current_person_id()) is not null);
create policy organization_modules_read on public.organization_modules for select to authenticated
  using (boss_private.can_view_subject('organization', organization_id));
create policy entitlements_read on public.entitlements for select to authenticated
  using (boss_private.can_view_subject(subject_type, subject_id, membership_kind));
create policy feature_flags_read on public.feature_flags for select to authenticated
  using ((select boss_private.current_person_id()) is not null);
create policy feature_overrides_read on public.feature_flag_overrides for select to authenticated
  using ((scope_type = 'person' and scope_id = (select boss_private.current_person_id()))
    or (scope_type = 'organization' and boss_private.can_view_subject('organization', scope_id))
    or (select boss_private.has_permission('organization.manage')));
create policy audit_read on public.audit_events for select to authenticated
  using (boss_private.has_resource_permission('audit.view', scope_type, scope_id, organization_id));

-- Defense in depth: RLS on all exposed foundation tables, explicit SELECT only
-- for authenticated, no implicit table/sequence/function rights for PUBLIC.
revoke all on all tables in schema public from public, anon, authenticated;
revoke all on all sequences in schema public from public, anon, authenticated;
grant select on public.people, public.user_accounts, public.organizations,
  public.organization_units, public.seasons, public.teams,
  public.organization_memberships, public.team_memberships, public.households,
  public.household_memberships, public.guardian_relationships, public.participants,
  public.roles, public.permissions, public.role_permissions, public.role_assignments,
  public.modules, public.organization_modules, public.entitlements,
  public.feature_flags, public.feature_flag_overrides, public.audit_events
to authenticated;

-- service_role is a trusted server/migration boundary, never a client key.
-- Only this role and the migration owner may populate the approved foundation.
grant select, insert, update, delete on public.people, public.user_accounts,
  public.organizations, public.organization_units, public.seasons, public.teams,
  public.organization_memberships, public.team_memberships, public.households,
  public.household_memberships, public.guardian_relationships, public.participants,
  public.roles, public.permissions, public.role_permissions, public.role_assignments,
  public.modules, public.organization_modules, public.entitlements,
  public.feature_flags, public.feature_flag_overrides to service_role;
revoke all on public.audit_events from service_role;
grant select, insert on public.audit_events to service_role;

-- Trigger functions are not directly callable. Authorize only reviewed policy
-- helpers; future private functions remain inaccessible unless explicitly added.
revoke all on all functions in schema boss_private from public, anon, authenticated, service_role;
grant execute on function boss_private.current_person_id(),
  boss_private.has_active_organization_membership(uuid),
  boss_private.has_active_team_relationship(uuid),
  boss_private.has_active_household_membership(uuid),
  boss_private.can_manage_dependent_profile(uuid),
  boss_private.has_permission(text, uuid, uuid, uuid),
  boss_private.has_resource_permission(text, text, uuid, uuid),
  boss_private.can_read_person(uuid), boss_private.can_read_participant(uuid),
  boss_private.can_view_subject(text, uuid, text),
  boss_private.organization_module_active(uuid, text),
  boss_private.has_active_entitlement(text, uuid, text, text)
to authenticated;
