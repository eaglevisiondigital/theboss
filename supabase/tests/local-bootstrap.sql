-- Test-only managed Supabase compatibility layer. Never apply remotely.
-- This file contains only the Auth/role surfaces used by foundation migrations.
-- It does not emulate Auth HTTP/JWT verification, session issuance or PostgREST.
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
  is_anonymous boolean not null default false
);
revoke all on auth.users from public, anon, authenticated, service_role;
grant select, insert, update, delete, truncate, references on auth.users to postgres;

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

-- Model the previously audited broad future defaults so the first migration
-- must actually remove them. Applications must grant approved access explicitly.
alter default privileges for role postgres in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on functions to anon, authenticated, service_role;
