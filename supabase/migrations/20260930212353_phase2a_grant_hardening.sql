-- Foundation migrations run as postgres. No managed Auth/Storage policy changes.
-- Anonymous users receive no application table access or helper execution.
create schema boss_private authorization postgres;
revoke all on schema boss_private from public, anon, authenticated, service_role;
grant usage on schema boss_private to authenticated, service_role;

revoke create on schema public from public, anon, authenticated, service_role;
grant usage on schema public to authenticated, service_role;
revoke all on all tables in schema public from public, anon, authenticated, service_role;
revoke all on all sequences in schema public from public, anon, authenticated, service_role;
revoke all on all functions in schema public from public, anon, authenticated, service_role;

-- Remove the broad existing future grants for the application migration owner.
alter default privileges for role postgres in schema public
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on sequences from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema boss_private
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema boss_private
  revoke all on sequences from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema boss_private
  revoke all on functions from public, anon, authenticated, service_role;

-- PostgreSQL's built-in PUBLIC EXECUTE default is global, so a per-schema
-- revoke alone cannot remove it. Existing managed functions are unaffected.
-- Future functions created by postgres must opt in to explicit EXECUTE grants.
alter default privileges for role postgres
  revoke execute on functions from public, anon, authenticated, service_role;

-- supabase_admin is a managed owner not held by postgres. Its future defaults
-- are not altered here. Every application migration explicitly sets ACLs;
-- application objects must continue to be created by the migration owner.
