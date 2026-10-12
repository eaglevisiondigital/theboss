-- Integrity functions are SECURITY INVOKER and live outside the Data API schema.
-- They do not supply caller authorization or expose privileged data lookups.
create function boss_private.preserve_row_identity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  protected_column text;
begin
  foreach protected_column in array tg_argv loop
    if (to_jsonb(new) -> protected_column) is distinct from (to_jsonb(old) -> protected_column) then
      raise exception 'Historical identity column % is immutable on %', protected_column, tg_table_name
        using errcode = '23514';
    end if;
  end loop;
  if to_jsonb(new) ? 'updated_at' then
    new.updated_at := statement_timestamp();
  end if;
  return new;
end;
$$;
revoke all on function boss_private.preserve_row_identity() from public, anon, authenticated, service_role;

create function boss_private.detach_deleted_auth_account()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.auth_user_id is distinct from old.auth_user_id then
    if new.auth_user_id is not null then
      raise exception 'An existing account mapping cannot be rebound to an Auth identity'
        using errcode = '23514';
    end if;
    -- This runs before the active-requires-Auth check during ON DELETE SET NULL.
    new.account_status := 'inactive';
  end if;
  return new;
end;
$$;
revoke all on function boss_private.detach_deleted_auth_account() from public, anon, authenticated, service_role;
create trigger a_user_accounts_detach_auth
  before update of auth_user_id on public.user_accounts
  for each row execute function boss_private.detach_deleted_auth_account();

create function boss_private.validate_organization_unit_hierarchy()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- A physical update of the shared organization row serializes hierarchy edits.
  -- Unlike a lock alone, it also produces a serialization failure when a stale
  -- REPEATABLE READ/SERIALIZABLE snapshot cannot safely validate a concurrent edit.
  update public.organizations
    set updated_at = updated_at
    where id = new.organization_id;
  if not found then
    raise exception 'Hierarchy organization does not exist' using errcode = '23503';
  end if;

  if new.parent_unit_id is not null and exists (
    with recursive ancestors(id, parent_unit_id) as (
      select u.id, u.parent_unit_id
      from public.organization_units u
      where u.organization_id = new.organization_id and u.id = new.parent_unit_id
      union
      select u.id, u.parent_unit_id
      from public.organization_units u
      join ancestors a on a.parent_unit_id = u.id
      where u.organization_id = new.organization_id
    )
    select 1 from ancestors where id = new.id
  ) then
    raise exception 'Organization unit hierarchy must be acyclic' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function boss_private.validate_organization_unit_hierarchy() from public, anon, authenticated, service_role;
create trigger organization_units_validate_hierarchy
  before insert or update of parent_unit_id on public.organization_units
  for each row execute function boss_private.validate_organization_unit_hierarchy();

create function boss_private.validate_role_assignment_scope()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  permitted_scopes text[];
begin
  -- Allowed scope kinds are immutable catalog identity. Assignment validation
  -- therefore needs no shared catalog-row write/lock across unrelated tenants.
  select r.allowed_scope_types into permitted_scopes
    from public.roles r where r.id = new.role_id;
  if not found then
    raise exception 'Assigned role does not exist' using errcode = '23503';
  end if;
  if not (new.scope_type = any(permitted_scopes)) then
    raise exception 'Role is not valid for the requested scope' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function boss_private.validate_role_assignment_scope() from public, anon, authenticated, service_role;
create trigger role_assignments_validate_scope
  before insert or update of role_id, scope_type on public.role_assignments
  for each row execute function boss_private.validate_role_assignment_scope();

create function boss_private.reject_audit_rewrite()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'Audit events are append-only' using errcode = '23514';
end;
$$;
revoke all on function boss_private.reject_audit_rewrite() from public, anon, authenticated, service_role;
create trigger audit_events_reject_update_delete
  before update or delete on public.audit_events
  for each row execute function boss_private.reject_audit_rewrite();
create trigger audit_events_reject_truncate
  before truncate on public.audit_events
  for each statement execute function boss_private.reject_audit_rewrite();

-- A historical relationship is ended/archived and replaced, never repointed to
-- another person, tenant or resource. Corrections require a separately reviewed
-- operational process. parent_unit_id is the deliberate hierarchy-edit exception.
create trigger people_preserve_identity before update on public.people
  for each row execute function boss_private.preserve_row_identity('id', 'created_at');
create trigger user_accounts_preserve_identity before update on public.user_accounts
  for each row execute function boss_private.preserve_row_identity('id', 'person_id', 'created_at');
create trigger households_preserve_identity before update on public.households
  for each row execute function boss_private.preserve_row_identity('id', 'created_at');
create trigger participants_preserve_identity before update on public.participants
  for each row execute function boss_private.preserve_row_identity('id', 'person_id', 'created_at');
create trigger organizations_preserve_identity before update on public.organizations
  for each row execute function boss_private.preserve_row_identity('id', 'created_at');
create trigger organization_units_preserve_identity before update on public.organization_units
  for each row execute function boss_private.preserve_row_identity('id', 'organization_id', 'created_at');
create trigger seasons_preserve_identity before update on public.seasons
  for each row execute function boss_private.preserve_row_identity('id', 'organization_id', 'parent_unit_id', 'created_at');
create trigger teams_preserve_identity before update on public.teams
  for each row execute function boss_private.preserve_row_identity('id', 'organization_id', 'parent_unit_id', 'season_id', 'created_at');
create trigger organization_memberships_preserve_identity before update on public.organization_memberships
  for each row execute function boss_private.preserve_row_identity('id', 'organization_id', 'person_id', 'membership_type', 'starts_at', 'created_at');
create trigger team_memberships_preserve_identity before update on public.team_memberships
  for each row execute function boss_private.preserve_row_identity('id', 'organization_id', 'team_id', 'person_id', 'participant_id', 'membership_type', 'starts_at', 'created_at');
create trigger household_memberships_preserve_identity before update on public.household_memberships
  for each row execute function boss_private.preserve_row_identity('id', 'household_id', 'person_id', 'relationship_type', 'starts_at', 'created_at');
create trigger guardian_relationships_preserve_identity before update on public.guardian_relationships
  for each row execute function boss_private.preserve_row_identity('id', 'guardian_person_id', 'dependent_person_id', 'relationship_type', 'starts_at', 'created_at');
create trigger roles_preserve_identity before update on public.roles
  for each row execute function boss_private.preserve_row_identity('id', 'key', 'allowed_scope_types', 'created_at');
create trigger permissions_preserve_identity before update on public.permissions
  for each row execute function boss_private.preserve_row_identity('id', 'key', 'created_at');
create trigger role_permissions_preserve_identity before update on public.role_permissions
  for each row execute function boss_private.preserve_row_identity('role_id', 'permission_id', 'created_at');
create trigger role_assignments_preserve_identity before update on public.role_assignments
  for each row execute function boss_private.preserve_row_identity('id', 'person_id', 'role_id', 'scope_type', 'scope_id', 'organization_id', 'granted_by_person_id', 'starts_at', 'created_at');
create trigger modules_preserve_identity before update on public.modules
  for each row execute function boss_private.preserve_row_identity('id', 'key', 'created_at');
create trigger organization_modules_preserve_identity before update on public.organization_modules
  for each row execute function boss_private.preserve_row_identity('id', 'organization_id', 'module_id', 'starts_at', 'created_at');
create trigger entitlements_preserve_identity before update on public.entitlements
  for each row execute function boss_private.preserve_row_identity('id', 'subject_type', 'subject_id', 'membership_kind', 'entitlement_type', 'entitlement_key', 'starts_at', 'created_at');
create trigger feature_flags_preserve_identity before update on public.feature_flags
  for each row execute function boss_private.preserve_row_identity('id', 'key', 'created_at');
create trigger feature_flag_overrides_preserve_identity before update on public.feature_flag_overrides
  for each row execute function boss_private.preserve_row_identity('id', 'feature_flag_id', 'scope_type', 'scope_id', 'starts_at', 'created_at');
