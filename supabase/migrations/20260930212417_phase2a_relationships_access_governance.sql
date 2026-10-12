-- Relationships preserve history. Membership labels describe relationships;
-- they never imply administrative permissions or guardian authority.
create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  membership_type text not null default 'member',
  status text not null default 'active',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organization_memberships_period_key unique (organization_id, person_id, membership_type, starts_at),
  constraint organization_memberships_type_check check (length(btrim(membership_type)) > 0),
  constraint organization_memberships_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint organization_memberships_window_check check (ends_at is null or ends_at > starts_at)
);
alter table public.organization_memberships enable row level security;
revoke all on table public.organization_memberships from public, anon, authenticated, service_role;
create index organization_memberships_person_idx on public.organization_memberships(person_id, organization_id);

create table public.team_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  team_id uuid not null,
  person_id uuid not null references public.people(id) on delete restrict,
  participant_id uuid,
  membership_type text not null default 'member',
  status text not null default 'active',
  jersey_number text,
  position_label text,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint team_memberships_team_fk foreign key (organization_id, team_id)
    references public.teams(organization_id, id) on delete restrict,
  constraint team_memberships_participant_fk foreign key (participant_id, person_id)
    references public.participants(id, person_id) on delete restrict,
  constraint team_memberships_period_key unique (team_id, person_id, membership_type, starts_at),
  constraint team_memberships_type_check check (length(btrim(membership_type)) > 0),
  constraint team_memberships_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint team_memberships_window_check check (ends_at is null or ends_at > starts_at)
);
alter table public.team_memberships enable row level security;
revoke all on table public.team_memberships from public, anon, authenticated, service_role;
create index team_memberships_organization_team_idx on public.team_memberships(organization_id, team_id);
create index team_memberships_person_idx on public.team_memberships(person_id, team_id);
create index team_memberships_participant_person_idx on public.team_memberships(participant_id, person_id);

create table public.household_memberships (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  relationship_type text not null default 'member',
  is_primary_contact boolean not null default false,
  status text not null default 'active',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint household_memberships_period_key unique (household_id, person_id, relationship_type, starts_at),
  constraint household_memberships_type_check check (length(btrim(relationship_type)) > 0),
  constraint household_memberships_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint household_memberships_window_check check (ends_at is null or ends_at > starts_at)
);
alter table public.household_memberships enable row level security;
revoke all on table public.household_memberships from public, anon, authenticated, service_role;
create index household_memberships_person_idx on public.household_memberships(person_id, household_id);

create table public.guardian_relationships (
  id uuid primary key default gen_random_uuid(),
  guardian_person_id uuid not null references public.people(id) on delete restrict,
  dependent_person_id uuid not null references public.people(id) on delete restrict,
  relationship_type text not null default 'guardian',
  authority_status text not null default 'pending',
  can_register boolean not null default false,
  can_sign_waivers boolean not null default false,
  can_view_documents boolean not null default false,
  can_manage_payments boolean not null default false,
  can_manage_profile boolean not null default false,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint guardian_relationships_period_key unique (guardian_person_id, dependent_person_id, relationship_type, starts_at),
  constraint guardian_relationships_not_self_check check (guardian_person_id <> dependent_person_id),
  constraint guardian_relationships_type_check check (length(btrim(relationship_type)) > 0),
  constraint guardian_relationships_status_check check (authority_status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint guardian_relationships_window_check check (ends_at is null or ends_at > starts_at)
);
alter table public.guardian_relationships enable row level security;
revoke all on table public.guardian_relationships from public, anon, authenticated, service_role;
create index guardian_relationships_dependent_idx on public.guardian_relationships(dependent_person_id, guardian_person_id);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  allowed_scope_types text[] not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roles_key_check check (key ~ '^[a-z][a-z0-9_]*$'),
  constraint roles_name_check check (length(btrim(name)) > 0),
  constraint roles_scope_types_check check (
    cardinality(allowed_scope_types) > 0
    and array_position(allowed_scope_types, null) is null
    and allowed_scope_types <@ array['platform', 'organization', 'organization_unit', 'team']::text[]),
  constraint roles_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived'))
);
alter table public.roles enable row level security;
revoke all on table public.roles from public, anon, authenticated, service_role;

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint permissions_key_check check (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  constraint permissions_name_check check (length(btrim(name)) > 0),
  constraint permissions_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived'))
);
alter table public.permissions enable row level security;
revoke all on table public.permissions from public, anon, authenticated, service_role;

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete restrict,
  permission_id uuid not null references public.permissions(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);
alter table public.role_permissions enable row level security;
revoke all on table public.role_permissions from public, anon, authenticated, service_role;
create index role_permissions_permission_idx on public.role_permissions(permission_id, role_id);

-- Conditional stored FK columns turn polymorphic scopes into real foreign keys.
-- Clients set scope_type/scope_id, never the generated columns.
create table public.role_assignments (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete restrict,
  role_id uuid not null references public.roles(id) on delete restrict,
  scope_type text not null,
  scope_id uuid,
  organization_id uuid references public.organizations(id) on delete restrict,
  organization_unit_id uuid generated always as (case when scope_type = 'organization_unit' then scope_id end) stored,
  team_id uuid generated always as (case when scope_type = 'team' then scope_id end) stored,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  status text not null default 'active',
  granted_by_person_id uuid references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint role_assignments_scope_check check (
    (scope_type = 'platform' and scope_id is null and organization_id is null)
    or (scope_type = 'organization' and scope_id is not null and organization_id is not null and scope_id = organization_id)
    or (scope_type in ('organization_unit', 'team') and scope_id is not null and organization_id is not null)),
  constraint role_assignments_unit_fk foreign key (organization_id, organization_unit_id)
    references public.organization_units(organization_id, id) on delete restrict,
  constraint role_assignments_team_fk foreign key (organization_id, team_id)
    references public.teams(organization_id, id) on delete restrict,
  constraint role_assignments_period_key unique nulls not distinct (person_id, role_id, scope_type, scope_id, starts_at),
  constraint role_assignments_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint role_assignments_window_check check (ends_at is null or ends_at > starts_at)
);
alter table public.role_assignments enable row level security;
revoke all on table public.role_assignments from public, anon, authenticated, service_role;
create index role_assignments_person_scope_idx on public.role_assignments(person_id, scope_type, scope_id);
create index role_assignments_role_idx on public.role_assignments(role_id);
create index role_assignments_organization_idx on public.role_assignments(organization_id, scope_type, scope_id);
create index role_assignments_unit_idx on public.role_assignments(organization_id, organization_unit_id);
create index role_assignments_team_idx on public.role_assignments(organization_id, team_id);
create index role_assignments_granted_by_idx on public.role_assignments(granted_by_person_id);

create table public.modules (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint modules_key_check check (key ~ '^[a-z][a-z0-9_]*$'),
  constraint modules_name_check check (length(btrim(name)) > 0),
  constraint modules_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived'))
);
alter table public.modules enable row level security;
revoke all on table public.modules from public, anon, authenticated, service_role;

create table public.organization_modules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  module_id uuid not null references public.modules(id) on delete restrict,
  status text not null default 'inactive',
  source text,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  configuration jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organization_modules_period_key unique (organization_id, module_id, starts_at),
  constraint organization_modules_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint organization_modules_window_check check (ends_at is null or ends_at > starts_at),
  constraint organization_modules_configuration_check check (jsonb_typeof(configuration) = 'object')
);
alter table public.organization_modules enable row level security;
revoke all on table public.organization_modules from public, anon, authenticated, service_role;
create index organization_modules_module_idx on public.organization_modules(module_id, organization_id);

-- A membership entitlement is anchored to one explicit membership kind. This
-- supports approved relationship kinds without ambiguous UUID-only references.
create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  subject_type text not null,
  subject_id uuid not null,
  membership_kind text,
  organization_id uuid generated always as (case when subject_type = 'organization' then subject_id end) stored
    references public.organizations(id) on delete restrict,
  person_id uuid generated always as (case when subject_type = 'person' then subject_id end) stored
    references public.people(id) on delete restrict,
  household_id uuid generated always as (case when subject_type = 'household' then subject_id end) stored
    references public.households(id) on delete restrict,
  organization_membership_id uuid generated always as (
    case when subject_type = 'membership' and membership_kind = 'organization' then subject_id end) stored
    references public.organization_memberships(id) on delete restrict,
  team_membership_id uuid generated always as (
    case when subject_type = 'membership' and membership_kind = 'team' then subject_id end) stored
    references public.team_memberships(id) on delete restrict,
  household_membership_id uuid generated always as (
    case when subject_type = 'membership' and membership_kind = 'household' then subject_id end) stored
    references public.household_memberships(id) on delete restrict,
  entitlement_type text not null,
  entitlement_key text not null,
  status text not null default 'inactive',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  source_type text,
  source_id uuid,
  configuration jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint entitlements_subject_check check (
    (subject_type in ('organization', 'person', 'household') and membership_kind is null)
    or (subject_type = 'membership' and membership_kind is not null and membership_kind in ('organization', 'team', 'household'))),
  constraint entitlements_type_check check (length(btrim(entitlement_type)) > 0),
  constraint entitlements_key_check check (length(btrim(entitlement_key)) > 0),
  constraint entitlements_period_key unique nulls not distinct (subject_type, subject_id, membership_kind, entitlement_type, entitlement_key, starts_at),
  constraint entitlements_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint entitlements_window_check check (ends_at is null or ends_at > starts_at),
  constraint entitlements_configuration_check check (jsonb_typeof(configuration) = 'object')
);
alter table public.entitlements enable row level security;
revoke all on table public.entitlements from public, anon, authenticated, service_role;
-- The unique lookup index starts with subject_type, subject_id and membership_kind.
create index entitlements_organization_idx on public.entitlements(organization_id);
create index entitlements_person_idx on public.entitlements(person_id);
create index entitlements_household_idx on public.entitlements(household_id);
create index entitlements_organization_membership_idx on public.entitlements(organization_membership_id);
create index entitlements_team_membership_idx on public.entitlements(team_membership_id);
create index entitlements_household_membership_idx on public.entitlements(household_membership_id);

create table public.feature_flags (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  enabled boolean not null default false,
  rollout_type text not null default 'experimental',
  status text not null default 'active',
  configuration jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feature_flags_key_check check (key ~ '^[a-z][a-z0-9_]*$'),
  constraint feature_flags_name_check check (length(btrim(name)) > 0),
  constraint feature_flags_rollout_type_check check (rollout_type in ('experimental', 'phased', 'organization_pilot', 'emergency_disable', 'internal_only')),
  constraint feature_flags_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint feature_flags_configuration_check check (jsonb_typeof(configuration) = 'object')
);
alter table public.feature_flags enable row level security;
revoke all on table public.feature_flags from public, anon, authenticated, service_role;

create table public.feature_flag_overrides (
  id uuid primary key default gen_random_uuid(),
  feature_flag_id uuid not null references public.feature_flags(id) on delete restrict,
  scope_type text not null,
  scope_id uuid,
  organization_id uuid generated always as (case when scope_type = 'organization' then scope_id end) stored
    references public.organizations(id) on delete restrict,
  person_id uuid generated always as (case when scope_type = 'person' then scope_id end) stored
    references public.people(id) on delete restrict,
  enabled boolean not null,
  status text not null default 'active',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  configuration jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feature_flag_overrides_scope_check check (
    (scope_type = 'platform' and scope_id is null)
    or (scope_type in ('organization', 'person') and scope_id is not null)),
  constraint feature_flag_overrides_scope_key unique nulls not distinct (feature_flag_id, scope_type, scope_id, starts_at),
  constraint feature_flag_overrides_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint feature_flag_overrides_window_check check (ends_at is null or ends_at > starts_at),
  constraint feature_flag_overrides_configuration_check check (jsonb_typeof(configuration) = 'object')
);
alter table public.feature_flag_overrides enable row level security;
revoke all on table public.feature_flag_overrides from public, anon, authenticated, service_role;
create index feature_flag_overrides_scope_idx on public.feature_flag_overrides(scope_type, scope_id, feature_flag_id);
create index feature_flag_overrides_organization_idx on public.feature_flag_overrides(organization_id);
create index feature_flag_overrides_person_idx on public.feature_flag_overrides(person_id);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete restrict,
  actor_person_id uuid references public.people(id) on delete restrict,
  -- Historical opaque Auth provenance deliberately survives Auth deletion.
  -- The live canonical mapping belongs to user_accounts, not an audit-event FK.
  actor_auth_user_id uuid,
  action text not null,
  resource_type text not null,
  resource_id uuid,
  scope_type text not null default 'platform',
  scope_id uuid,
  organization_unit_id uuid generated always as (case when scope_type = 'organization_unit' then scope_id end) stored,
  team_id uuid generated always as (case when scope_type = 'team' then scope_id end) stored,
  scope_person_id uuid generated always as (case when scope_type = 'person' then scope_id end) stored
    references public.people(id) on delete restrict,
  household_id uuid generated always as (case when scope_type = 'household' then scope_id end) stored
    references public.households(id) on delete restrict,
  before_data jsonb,
  after_data jsonb,
  request_id uuid,
  created_at timestamptz not null default now(),
  constraint audit_events_action_check check (length(btrim(action)) > 0),
  constraint audit_events_resource_type_check check (length(btrim(resource_type)) > 0),
  constraint audit_events_unit_fk foreign key (organization_id, organization_unit_id)
    references public.organization_units(organization_id, id) on delete restrict,
  constraint audit_events_team_fk foreign key (organization_id, team_id)
    references public.teams(organization_id, id) on delete restrict,
  constraint audit_events_scope_check check (
    (scope_type = 'platform' and scope_id is null and organization_id is null)
    or (scope_type = 'organization' and scope_id is not null and organization_id is not null and scope_id = organization_id)
    or (scope_type in ('organization_unit', 'team') and scope_id is not null and organization_id is not null)
    or (scope_type in ('person', 'household') and scope_id is not null and organization_id is null)),
  constraint audit_events_before_data_check check (before_data is null or jsonb_typeof(before_data) = 'object'),
  constraint audit_events_after_data_check check (after_data is null or jsonb_typeof(after_data) = 'object')
);
alter table public.audit_events enable row level security;
revoke all on table public.audit_events from public, anon, authenticated, service_role;
create index audit_events_organization_created_idx on public.audit_events(organization_id, created_at desc);
create index audit_events_actor_person_idx on public.audit_events(actor_person_id, created_at desc);
create index audit_events_resource_idx on public.audit_events(resource_type, resource_id, created_at desc);
create index audit_events_unit_idx on public.audit_events(organization_id, organization_unit_id);
create index audit_events_team_idx on public.audit_events(organization_id, team_id);
create index audit_events_scope_person_idx on public.audit_events(scope_person_id);
create index audit_events_household_idx on public.audit_events(household_id);
