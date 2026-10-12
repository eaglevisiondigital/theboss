-- Test-only managed Supabase compatibility layer. Never apply remotely.
-- This file contains only the Auth/role and Storage catalog surfaces used by
-- canonical migrations. It does not emulate Auth HTTP/JWT verification,
-- session issuance, PostgREST, Storage HTTP, file scanning or object bytes.
-- Roles and uid() semantics were checked against the canonical project; uid() is
-- equivalent to Supabase Auth's current implementation.
-- Bootstrap executes as a separate local administrator; migrations execute as
-- this managed-like postgres role, which has RLS bypass but is not a superuser.
create role postgres login inherit nosuperuser bypassrls createdb createrole;
create role anon nologin noinherit nosuperuser nobypassrls;
create role authenticated nologin noinherit nosuperuser nobypassrls;
create role service_role nologin noinherit nosuperuser bypassrls;
create role authenticator nologin noinherit nosuperuser nobypassrls;
grant anon, authenticated, service_role to authenticator;
grant anon, authenticated, service_role to postgres;
alter database postgres owner to postgres;
alter schema public owner to postgres;

create schema auth;
create schema extensions;
grant usage on schema public, auth to postgres, anon, authenticated, service_role;

-- Managed Auth remains distinct from the canonical Boss person. Only the PK is
-- referenced by application FKs. Additional fields allow realistic synthetic
-- identity/metadata fixtures without storing password or session credentials.
create table auth.users (
  id uuid not null primary key,
  aud varchar(255),
  role varchar(255),
  email varchar(255),
  email_confirmed_at timestamptz,
  raw_app_meta_data jsonb,
  raw_user_meta_data jsonb,
  created_at timestamptz,
  updated_at timestamptz,
  phone text,
  banned_until timestamptz,
  deleted_at timestamptz,
  is_anonymous boolean not null default false
);
revoke all on auth.users from public, anon, authenticated, service_role;
grant select, insert, update, delete, truncate, references on auth.users to postgres;

-- Sensitive operational RPCs validate the signed session_id against Auth's
-- session ownership and absolute expiry. These minimal synthetic rows emulate
-- only that lookup. They contain no refresh tokens, passwords or credentials.
create table auth.sessions (
  id uuid not null primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  not_after timestamptz
);
revoke all on auth.sessions from public, anon, authenticated, service_role;
grant select, insert, update, delete, truncate, references on auth.sessions to postgres;

create function auth.uid()
returns uuid
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid
$$;
revoke all on function auth.uid() from public;
grant execute on function auth.uid() to postgres, anon, authenticated, service_role;

create function auth.jwt()
returns jsonb
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')
  )::jsonb
$$;
revoke all on function auth.jwt() from public;
grant execute on function auth.jwt() to postgres, anon, authenticated, service_role;

-- Managed Storage metadata compatibility surface. Policy expressions are the
-- actual migration source and run as real anon/authenticated PostgreSQL roles;
-- only this disposable table shape is synthetic. Hosted Storage acceptance
-- separately verifies HTTP upload/download behavior and bytes. No permissive
-- test policies, bypass-RLS client role or replacement policy functions exist.
create schema storage authorization postgres;
grant usage on schema storage to postgres, anon, authenticated, service_role;
create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text,
  owner uuid,
  owner_id text,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(bucket_id,name)
);
alter table storage.buckets owner to postgres;
alter table storage.objects owner to postgres;
alter table storage.objects enable row level security;
revoke all on storage.buckets,storage.objects from public,anon,authenticated,service_role;
-- These grants match the managed Storage API metadata operations. RLS starts
-- with no policies, so uploads/downloads must pass the canonical policy source.
grant select,insert,update,delete on storage.objects to authenticated;
grant select on storage.objects to anon;

-- Canonical managed Storage operation helpers, copied from the live project.
-- Storage HTTP establishes this setting; SQL tests set only synthetic operation
-- names to execute the actual policy branches. Prefix normalization is exact.
create function storage.operation() returns text language plpgsql stable as $$
begin return current_setting('storage.operation',true);end $$;
create function storage.allow_only_operation(expected_operation text) returns boolean
language sql stable as $$
 with current_operation as(select storage.operation() as raw_operation),
 normalized as(select
  case when raw_operation like 'storage.%' then substr(raw_operation,9) else raw_operation end as current_operation,
  case when expected_operation like 'storage.%' then substr(expected_operation,9) else expected_operation end as requested_operation
  from current_operation)
 select case when requested_operation is null or requested_operation='' then false
 else coalesce(current_operation=requested_operation,false) end from normalized
$$;
alter function storage.operation() owner to postgres;
alter function storage.allow_only_operation(text) owner to postgres;
grant execute on function storage.operation(),storage.allow_only_operation(text) to authenticated,anon,service_role;

-- Managed Storage rejects direct SQL deletion before row filtering or RLS,
-- including statements matching zero rows. The hosted failure established this
-- protection. Model only its deny behavior; never emulate or enable an API
-- deletion bypass. Actual files must be removed through the Storage HTTP API.
create function storage.protect_delete() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  raise exception 'Direct deletion from Storage tables is not permitted' using errcode='P0001';
end $$;
alter function storage.protect_delete() owner to postgres;
revoke all on function storage.protect_delete() from public,anon,authenticated,service_role;
create trigger protect_objects_delete before delete on storage.objects
for each statement execute function storage.protect_delete();
create trigger protect_buckets_delete before delete on storage.buckets
for each statement execute function storage.protect_delete();


-- Model the previously audited broad future defaults so the first migration
-- must actually remove them. Applications must grant approved access explicitly.
alter default privileges for role postgres in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on functions to anon, authenticated, service_role;
