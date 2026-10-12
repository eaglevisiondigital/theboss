-- Canonical identity is independent from authentication. No Auth trigger creates
-- a person, and deleting an Auth account must preserve operational history.
create table public.people (
  id uuid primary key default gen_random_uuid(),
  first_name text,
  middle_name text,
  last_name text,
  preferred_name text,
  display_name text,
  date_of_birth date,
  primary_email text,
  primary_phone text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint people_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint people_display_name_check check (display_name is null or length(btrim(display_name)) > 0),
  constraint people_primary_email_check check (primary_email is null or length(btrim(primary_email)) > 0),
  constraint people_primary_phone_check check (primary_phone is null or length(btrim(primary_phone)) > 0)
);
alter table public.people enable row level security;
revoke all on table public.people from public, anon, authenticated, service_role;

create table public.user_accounts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  person_id uuid not null references public.people(id) on delete restrict,
  account_status text not null default 'pending',
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_accounts_status_check check (account_status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint user_accounts_active_auth_check check (account_status <> 'active' or auth_user_id is not null)
);
alter table public.user_accounts enable row level security;
revoke all on table public.user_accounts from public, anon, authenticated, service_role;
create unique index user_accounts_one_active_person_idx on public.user_accounts(person_id) where account_status = 'active';
create index user_accounts_person_idx on public.user_accounts(person_id);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint households_name_check check (name is null or length(btrim(name)) > 0),
  constraint households_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived'))
);
alter table public.households enable row level security;
revoke all on table public.households from public, anon, authenticated, service_role;

create table public.participants (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null unique references public.people(id) on delete restrict,
  participant_type text not null default 'participant',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint participants_id_person_key unique (id, person_id),
  constraint participants_type_check check (length(btrim(participant_type)) > 0),
  constraint participants_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived'))
);
alter table public.participants enable row level security;
revoke all on table public.participants from public, anon, authenticated, service_role;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  legal_name text,
  slug text not null unique,
  organization_type text not null default 'organization',
  status text not null default 'active',
  timezone text not null default 'UTC',
  country text,
  default_currency text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organizations_name_check check (length(btrim(name)) > 0),
  constraint organizations_slug_check check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint organizations_type_check check (length(btrim(organization_type)) > 0),
  constraint organizations_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  constraint organizations_timezone_check check (length(btrim(timezone)) > 0),
  constraint organizations_country_check check (country is null or country ~ '^[A-Z]{2}$'),
  constraint organizations_currency_check check (default_currency is null or default_currency ~ '^[A-Z]{3}$')
);
alter table public.organizations enable row level security;
revoke all on table public.organizations from public, anon, authenticated, service_role;

create table public.organization_units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  parent_unit_id uuid,
  unit_type text not null,
  name text not null,
  slug text not null,
  status text not null default 'active',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organization_units_organization_id_key unique (organization_id, id),
  constraint organization_units_parent_slug_key unique nulls not distinct (organization_id, parent_unit_id, slug),
  constraint organization_units_parent_fk foreign key (organization_id, parent_unit_id)
    references public.organization_units(organization_id, id) on delete restrict,
  constraint organization_units_not_self_check check (parent_unit_id is null or parent_unit_id <> id),
  constraint organization_units_type_check check (length(btrim(unit_type)) > 0),
  constraint organization_units_name_check check (length(btrim(name)) > 0),
  constraint organization_units_slug_check check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint organization_units_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived'))
);
alter table public.organization_units enable row level security;
revoke all on table public.organization_units from public, anon, authenticated, service_role;
-- The unique parent/slug index also covers organization + parent traversal.

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  parent_unit_id uuid,
  name text not null,
  starts_on date,
  ends_on date,
  registration_opens_at timestamptz,
  registration_closes_at timestamptz,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint seasons_organization_id_key unique (organization_id, id),
  constraint seasons_parent_unit_fk foreign key (organization_id, parent_unit_id)
    references public.organization_units(organization_id, id) on delete restrict,
  constraint seasons_name_check check (length(btrim(name)) > 0),
  constraint seasons_dates_check check (starts_on is null or ends_on is null or ends_on >= starts_on),
  constraint seasons_registration_dates_check check (
    registration_opens_at is null or registration_closes_at is null or registration_closes_at >= registration_opens_at),
  constraint seasons_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived'))
);
alter table public.seasons enable row level security;
revoke all on table public.seasons from public, anon, authenticated, service_role;
create index seasons_parent_unit_idx on public.seasons(organization_id, parent_unit_id);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  parent_unit_id uuid,
  season_id uuid,
  name text not null,
  short_name text,
  slug text not null,
  status text not null default 'pending',
  visibility text not null default 'private',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint teams_organization_id_key unique (organization_id, id),
  constraint teams_organization_slug_key unique (organization_id, slug),
  constraint teams_parent_unit_fk foreign key (organization_id, parent_unit_id)
    references public.organization_units(organization_id, id) on delete restrict,
  constraint teams_season_fk foreign key (organization_id, season_id)
    references public.seasons(organization_id, id) on delete restrict,
  constraint teams_name_check check (length(btrim(name)) > 0),
  constraint teams_slug_check check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint teams_status_check check (status in ('active', 'inactive', 'pending', 'suspended', 'archived')),
  -- This centrally documented vocabulary is a classification, never an RLS grant.
  constraint teams_visibility_check check (visibility in ('public', 'authenticated', 'member', 'restricted', 'private'))
);
alter table public.teams enable row level security;
revoke all on table public.teams from public, anon, authenticated, service_role;
create index teams_parent_unit_idx on public.teams(organization_id, parent_unit_id);
create index teams_season_idx on public.teams(organization_id, season_id);
