-- Synthetic fixtures and assertion helpers exist only inside this transaction.
-- Run against a disposable local database after applying canonical migrations.
-- ON_ERROR_STOP is required in the runner: any unexpected result fails the suite.
-- SET LOCAL ROLE models PostgREST database roles, not HTTP JWT verification.
BEGIN;

CREATE TEMP TABLE phase2a_assertions (
  assertion text PRIMARY KEY,
  category text NOT NULL
) ON COMMIT DROP;
GRANT SELECT, INSERT ON TABLE pg_temp.phase2a_assertions TO anon, authenticated, service_role;

CREATE FUNCTION pg_temp.fixture_id(label text)
RETURNS uuid LANGUAGE sql IMMUTABLE SECURITY INVOKER
SET search_path = pg_catalog
AS $$ SELECT md5('boss-phase2a-transaction-fixture:' || label)::uuid $$;

CREATE FUNCTION pg_temp.expect_true(label text, category text, actual boolean)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
  IF actual IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'FAIL [%] %: expected true, got %', category, label, actual;
  END IF;
  INSERT INTO pg_temp.phase2a_assertions VALUES (label, category);
END;
$$;

CREATE FUNCTION pg_temp.expect_count(label text, category text, query text, expected bigint)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE actual bigint;
BEGIN
  EXECUTE query INTO actual;
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'FAIL [%] %: expected % rows, got %', category, label, expected, actual;
  END IF;
  INSERT INTO pg_temp.phase2a_assertions VALUES (label, category);
END;
$$;

CREATE FUNCTION pg_temp.expect_error(label text, category text, statement text, allowed_states text[])
RETURNS void LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE failed boolean := false;
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = ANY (allowed_states) THEN
      failed := true;
    ELSE
      RAISE EXCEPTION 'FAIL [%] %: unexpected SQLSTATE % (%), expected %',
        category, label, SQLSTATE, SQLERRM, allowed_states;
    END IF;
  END;
  IF NOT failed THEN
    RAISE EXCEPTION 'FAIL [%] %: statement succeeded; expected SQLSTATE %',
      category, label, allowed_states;
  END IF;
  INSERT INTO pg_temp.phase2a_assertions VALUES (label, category);
END;
$$;

REVOKE ALL ON FUNCTION pg_temp.fixture_id(text),
  pg_temp.expect_true(text,text,boolean), pg_temp.expect_count(text,text,text,bigint),
  pg_temp.expect_error(text,text,text,text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.fixture_id(text),
  pg_temp.expect_true(text,text,boolean), pg_temp.expect_count(text,text,text,bigint),
  pg_temp.expect_error(text,text,text,text[]) TO anon, authenticated, service_role;

CREATE FUNCTION pg_temp.act_as(label text, anonymous_identity boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  -- Synthetic claims only; this helper is rolled back and is not an application API.
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claim', '', true);
  PERFORM set_config('request.jwt.claims', jsonb_build_object(
    'sub', pg_temp.fixture_id('auth-' || label), 'role', 'authenticated',
    'is_anonymous', anonymous_identity,
    'user_metadata', jsonb_build_object('role','super_administrator','is_admin',true,
      'person_id',pg_temp.fixture_id('platform')))::text, true);
END;
$$;
REVOKE ALL ON FUNCTION pg_temp.act_as(text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.act_as(text,boolean) TO authenticated;

SELECT pg_temp.expect_true('managed-like migration owner is not superuser', 'P',
  (SELECT NOT rolsuper AND rolbypassrls FROM pg_catalog.pg_roles WHERE rolname = current_user));
SELECT pg_temp.expect_true('API roles cannot bypass RLS', 'P',
  (SELECT bool_and(NOT rolsuper AND NOT rolbypassrls) FROM pg_catalog.pg_roles WHERE rolname IN ('anon','authenticated')));

-- Grant-level denial is deliberately tested separately from RLS row filtering.
-- All 22 exposed tables must remain protected, including catalogs and audit data.
DO $test$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'people','user_accounts','organizations','organization_units','seasons','teams',
    'organization_memberships','team_memberships','households','household_memberships',
    'guardian_relationships','participants','roles','permissions','role_permissions',
    'role_assignments','modules','organization_modules','entitlements','feature_flags',
    'feature_flag_overrides','audit_events'
  ] LOOP
    PERFORM pg_temp.expect_true('RLS enabled on ' || table_name, 'P',
      (SELECT relrowsecurity FROM pg_catalog.pg_class
       WHERE oid = ('public.' || table_name)::regclass));
    PERFORM pg_temp.expect_true('anon cannot SELECT ' || table_name, 'A',
      NOT has_table_privilege('anon', 'public.' || table_name, 'SELECT'));
    PERFORM pg_temp.expect_true('authenticated can reach SELECT policy on ' || table_name, 'P',
      has_table_privilege('authenticated', 'public.' || table_name, 'SELECT'));
    PERFORM pg_temp.expect_true('anon cannot mutate ' || table_name, 'O',
      NOT has_table_privilege('anon', 'public.' || table_name, 'INSERT,UPDATE,DELETE,TRUNCATE'));
    PERFORM pg_temp.expect_true('authenticated cannot mutate ' || table_name, 'O',
      NOT has_table_privilege('authenticated', 'public.' || table_name, 'INSERT,UPDATE,DELETE,TRUNCATE'));
  END LOOP;
END;
$test$;

SELECT pg_temp.expect_count('only approved exposed table set', 'P',
  $$ SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname = 'public' AND tablename IN ('people','user_accounts','households','participants','organizations','organization_units','seasons','teams','organization_memberships','team_memberships','household_memberships','guardian_relationships','roles','permissions','role_permissions','role_assignments','modules','organization_modules','entitlements','feature_flags','feature_flag_overrides','audit_events') $$, 22);
SELECT pg_temp.expect_count('no anonymously accessible policies', 'A',
  $$ SELECT count(*) FROM pg_catalog.pg_policies WHERE schemaname = 'public'
       AND ('anon' = ANY (roles) OR 'public' = ANY (roles)) $$, 0);
SELECT pg_temp.expect_count('no client mutation policies', 'O',
  $$ SELECT count(*) FROM pg_catalog.pg_policies WHERE schemaname = 'public'
       AND cmd <> 'SELECT' $$, 0);
SELECT pg_temp.expect_count('no public-schema SECURITY DEFINER endpoints', 'P',
  $$ SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.prosecdef $$, 0);
SELECT pg_temp.expect_true('anon lacks private helper schema access', 'A',
  NOT has_schema_privilege('anon', 'boss_private', 'USAGE'));
SELECT pg_temp.expect_count('private helper functions have safe empty search paths', 'P',
  $$ SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'boss_private' AND NOT coalesce('search_path=""' = ANY (p.proconfig), false) $$, 0);
SELECT pg_temp.expect_count('anon cannot execute any private helper or trigger', 'A',
  $$ SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'boss_private' AND has_function_privilege('anon',p.oid,'EXECUTE') $$, 0);
SELECT pg_temp.expect_count('trigger functions are not callable by authenticated clients', 'P',
  $$ SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'boss_private' AND p.prorettype = 'trigger'::regtype
         AND has_function_privilege('authenticated',p.oid,'EXECUTE') $$, 0);
SELECT pg_temp.expect_true('module lookup uses invoker security with RLS-visible inputs', 'P',
  (SELECT NOT prosecdef FROM pg_catalog.pg_proc
    WHERE oid = 'boss_private.organization_module_active(uuid,text)'::regprocedure));

-- Probe future grants, not merely the tables that happen to exist today.
CREATE TABLE public.phase2a_default_acl_probe (id integer);
CREATE SEQUENCE public.phase2a_default_sequence_probe;
CREATE FUNCTION public.phase2a_default_execute_probe()
RETURNS integer LANGUAGE sql SECURITY INVOKER SET search_path = pg_catalog AS $$ SELECT 1 $$;
SELECT pg_temp.expect_true('future table denies anon', 'P',
  NOT has_table_privilege('anon', 'public.phase2a_default_acl_probe', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));
SELECT pg_temp.expect_true('future table denies authenticated', 'P',
  NOT has_table_privilege('authenticated', 'public.phase2a_default_acl_probe', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));
SELECT pg_temp.expect_true('future function does not inherit PUBLIC execute', 'P',
  NOT has_function_privilege('anon', 'public.phase2a_default_execute_probe()', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'public.phase2a_default_execute_probe()', 'EXECUTE'));
SELECT pg_temp.expect_true('future table requires explicit trusted-server grants', 'P',
  NOT has_table_privilege('service_role', 'public.phase2a_default_acl_probe', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'));
SELECT pg_temp.expect_true('future sequence requires explicit trusted-server grants', 'P',
  NOT has_sequence_privilege('service_role', 'public.phase2a_default_sequence_probe', 'USAGE,SELECT,UPDATE'));
SELECT pg_temp.expect_true('future function requires explicit trusted-server execute grant', 'P',
  NOT has_function_privilege('service_role', 'public.phase2a_default_execute_probe()', 'EXECUTE'));
SELECT pg_temp.expect_true('trusted server cannot CREATE public-schema objects', 'P',
  NOT has_schema_privilege('service_role', 'public', 'CREATE'));
SELECT pg_temp.expect_true('trusted server cannot CREATE private-schema objects', 'P',
  NOT has_schema_privilege('service_role', 'boss_private', 'CREATE'));
SET LOCAL ROLE service_role;
SELECT pg_temp.expect_error('trusted server future-table SELECT denied', 'P',
  $$ SELECT * FROM public.phase2a_default_acl_probe $$, ARRAY['42501']);
SELECT pg_temp.expect_error('trusted server future-table INSERT denied', 'P',
  $$ INSERT INTO public.phase2a_default_acl_probe DEFAULT VALUES $$, ARRAY['42501']);
SELECT pg_temp.expect_error('trusted server future-table UPDATE denied', 'P',
  $$ UPDATE public.phase2a_default_acl_probe SET id = 1 $$, ARRAY['42501']);
SELECT pg_temp.expect_error('trusted server future-table DELETE denied', 'P',
  $$ DELETE FROM public.phase2a_default_acl_probe $$, ARRAY['42501']);
SELECT pg_temp.expect_error('trusted server future-table TRUNCATE denied', 'P',
  $$ TRUNCATE public.phase2a_default_acl_probe $$, ARRAY['42501']);
SELECT pg_temp.expect_error('trusted server future-sequence usage denied', 'P',
  $$ SELECT nextval('public.phase2a_default_sequence_probe') $$, ARRAY['42501']);
SELECT pg_temp.expect_error('trusted server future-function execution denied', 'P',
  $$ SELECT public.phase2a_default_execute_probe() $$, ARRAY['42501']);
SELECT pg_temp.expect_error('trusted server actual CREATE in public denied', 'P',
  $$ CREATE TABLE public.phase2a_server_creation_probe (id integer) $$, ARRAY['42501']);
SELECT pg_temp.expect_error('trusted server actual CREATE in private schema denied', 'P',
  $$ CREATE TABLE boss_private.phase2a_server_creation_probe (id integer) $$, ARRAY['42501']);
RESET ROLE;
DROP TABLE public.phase2a_default_acl_probe;
DROP SEQUENCE public.phase2a_default_sequence_probe;
DROP FUNCTION public.phase2a_default_execute_probe();

-- Fixtures and behavioral cases follow the exact canonical schema contracts.

-- This approved initial catalog is asserted independently of the migration's
-- implementation. Exact permission sets catch both omissions and added powers.
CREATE TEMP TABLE phase2a_expected_role_catalog (
  role_key text PRIMARY KEY,
  expected_scopes text[] NOT NULL,
  expected_permissions text[] NOT NULL
) ON COMMIT DROP;
INSERT INTO pg_temp.phase2a_expected_role_catalog VALUES
  ('super_administrator',ARRAY['platform'],ARRAY['person.profile.view','person.profile.manage','organization.view','organization.manage','organization.members.view','organization.members.manage','team.view','team.manage','team.roster.view','team.roster.manage','participant.profile.view','participant.profile.manage','household.view','household.manage','roles.view','roles.assign','audit.view']),
  ('platform_administrator',ARRAY['platform'],ARRAY['person.profile.view','person.profile.manage','organization.view','organization.manage','organization.members.view','organization.members.manage','team.view','team.manage','team.roster.view','team.roster.manage','participant.profile.view','participant.profile.manage','household.view','household.manage','roles.view','roles.assign','audit.view']),
  ('support',ARRAY['platform'],ARRAY['organization.view']),
  ('finance',ARRAY['platform'],ARRAY[]::text[]),
  ('sales',ARRAY['platform'],ARRAY['organization.view']),
  ('merchant_network_staff',ARRAY['platform'],ARRAY[]::text[]),
  ('compliance',ARRAY['platform'],ARRAY['organization.view']),
  ('organization_owner',ARRAY['organization'],ARRAY['organization.view','organization.manage','organization.members.view','organization.members.manage','team.view','team.manage','team.roster.view','team.roster.manage','participant.profile.view','participant.profile.manage','household.view','household.manage','roles.view','roles.assign','audit.view']),
  ('organization_administrator',ARRAY['organization'],ARRAY['organization.view','organization.manage','organization.members.view','organization.members.manage','team.view','team.manage','team.roster.view','team.roster.manage','participant.profile.view','participant.profile.manage','household.view','household.manage','roles.view','roles.assign','audit.view']),
  ('athletic_director',ARRAY['organization'],ARRAY['organization.view','organization.members.view','team.view','team.manage','team.roster.view','team.roster.manage','participant.profile.view','participant.profile.manage','household.view','roles.view']),
  ('program_administrator',ARRAY['organization_unit'],ARRAY['organization.view','organization.manage','team.view','team.manage','team.roster.view','team.roster.manage','participant.profile.view','participant.profile.manage','roles.view']),
  ('sport_administrator',ARRAY['organization_unit'],ARRAY['organization.view','organization.manage','team.view','team.manage','team.roster.view','team.roster.manage','participant.profile.view','participant.profile.manage','roles.view']),
  ('head_coach',ARRAY['team'],ARRAY['team.view','team.manage','team.roster.view','team.roster.manage','participant.profile.view']),
  ('assistant_coach',ARRAY['team'],ARRAY['team.view','team.roster.view','participant.profile.view']),
  ('team_administrator',ARRAY['team'],ARRAY['team.view','team.manage','team.roster.view','team.roster.manage']),
  ('team_staff',ARRAY['team'],ARRAY['team.view','team.roster.view']),
  ('volunteer_coordinator',ARRAY['team'],ARRAY['team.view']),
  ('scorekeeper',ARRAY['team'],ARRAY['team.view']),
  ('livestream_operator',ARRAY['team'],ARRAY['team.view']);
SELECT pg_temp.expect_count('exact initial role catalog count', 'P', $$ SELECT count(*) FROM public.roles WHERE key NOT IN ('registrar','organization_finance','competition_manager','merchant_owner','merchant_admin','location_manager','offer_editor','redemption_clerk','sales_rep','regional_manager','support_reviewer') $$, 19);
SELECT pg_temp.expect_count('exact initial permission catalog count', 'P', $$ SELECT count(*) FROM public.permissions WHERE key NOT IN ('events.view','events.create','events.manage','events.publish','events.override_conflict','registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage','boss_bucks.membership_view','boss_bucks.membership_manage','boss_bucks.product_manage','boss_bucks.inventory_manage','boss_bucks.fulfillment_manage','boss_bucks.payment_reverse','payments.refund','payments.provider_manage','settlements.view','settlements.manage','settlements.reconcile','merchants.view','merchants.manage','merchants.access_manage','merchant_locations.view','merchant_locations.manage','merchant_offers.view','merchant_offers.manage','merchant_redemptions.view','merchant_redemptions.manage','merchant_reviews.manage','merchant_sales.view','merchant_sales.manage','partners.view','partners.configure','partners.contract_approve','partners.catalog_review','partners.integration_activate','partners.revenue_report') AND key NOT LIKE 'games.%' $$, 17);
SELECT pg_temp.expect_count('exact initial role-permission mapping count', 'P', $$ SELECT count(*) FROM public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('events.view','events.create','events.manage','events.publish','events.override_conflict','registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage','boss_bucks.membership_view','boss_bucks.membership_manage','boss_bucks.product_manage','boss_bucks.inventory_manage','boss_bucks.fulfillment_manage','boss_bucks.payment_reverse','payments.refund','payments.provider_manage','settlements.view','settlements.manage','settlements.reconcile','merchants.view','merchants.manage','merchants.access_manage','merchant_locations.view','merchant_locations.manage','merchant_offers.view','merchant_offers.manage','merchant_redemptions.view','merchant_redemptions.manage','merchant_reviews.manage','merchant_sales.view','merchant_sales.manage','partners.view','partners.configure','partners.contract_approve','partners.catalog_review','partners.integration_activate','partners.revenue_report') AND p.key NOT LIKE 'games.%' $$, 112);
SELECT pg_temp.expect_count('exact initial module catalog count', 'P', $$ SELECT count(*) FROM public.modules WHERE key NOT IN ('calendar','payments') $$, 13);
SELECT pg_temp.expect_count('no speculative feature flags seeded', 'P', $$ SELECT count(*) FROM public.feature_flags $$, 0);
SELECT pg_temp.expect_count('seed roles and permissions are active', 'P',
  $$ SELECT (SELECT count(*) FROM public.roles WHERE status <> 'active')
          + (SELECT count(*) FROM public.permissions WHERE status <> 'active') $$, 0);
SELECT pg_temp.expect_true('no unexpected initial permission keys', 'P',
  (SELECT array_agg(key ORDER BY key) FROM public.permissions WHERE key NOT IN ('events.view','events.create','events.manage','events.publish','events.override_conflict','registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage','boss_bucks.membership_view','boss_bucks.membership_manage','boss_bucks.product_manage','boss_bucks.inventory_manage','boss_bucks.fulfillment_manage','boss_bucks.payment_reverse','payments.refund','payments.provider_manage','settlements.view','settlements.manage','settlements.reconcile','merchants.view','merchants.manage','merchants.access_manage','merchant_locations.view','merchant_locations.manage','merchant_offers.view','merchant_offers.manage','merchant_redemptions.view','merchant_redemptions.manage','merchant_reviews.manage','merchant_sales.view','merchant_sales.manage','partners.view','partners.configure','partners.contract_approve','partners.catalog_review','partners.integration_activate','partners.revenue_report') AND key NOT LIKE 'games.%') =
  (SELECT array_agg(key ORDER BY key) FROM unnest(ARRAY[
    'person.profile.view','person.profile.manage','organization.view','organization.manage',
    'organization.members.view','organization.members.manage','team.view','team.manage',
    'team.roster.view','team.roster.manage','participant.profile.view','participant.profile.manage',
    'household.view','household.manage','roles.view','roles.assign','audit.view'
  ]) AS key));
SELECT pg_temp.expect_true('no unexpected initial module keys', 'P',
  (SELECT array_agg(key ORDER BY key) FROM public.modules WHERE key NOT IN ('calendar','payments')) =
  (SELECT array_agg(key ORDER BY key) FROM unnest(ARRAY[
    'fundraising','boss_bucks','sports','engage','registration','documents','messaging',
    'volunteers','money_board','commerce','livestream','fan','reporting'
  ]) AS key));
DO $test$
DECLARE expected record; actual_scopes text[]; actual_permissions text[]; sorted_expected_permissions text[];
BEGIN
  FOR expected IN SELECT * FROM pg_temp.phase2a_expected_role_catalog LOOP
    SELECT allowed_scope_types INTO actual_scopes FROM public.roles WHERE key = expected.role_key;
    PERFORM pg_temp.expect_true('approved seed role scopes: ' || expected.role_key, 'P',
      actual_scopes = expected.expected_scopes);
    SELECT coalesce(array_agg(p.key ORDER BY p.key),ARRAY[]::text[]) INTO actual_permissions
      FROM public.roles r JOIN public.role_permissions rp ON rp.role_id = r.id
      JOIN public.permissions p ON p.id = rp.permission_id WHERE r.key = expected.role_key AND p.key NOT IN ('events.view','events.create','events.manage','events.publish','events.override_conflict','registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage','boss_bucks.membership_view','boss_bucks.membership_manage','boss_bucks.product_manage','boss_bucks.inventory_manage','boss_bucks.fulfillment_manage','boss_bucks.payment_reverse','payments.refund','payments.provider_manage','settlements.view','settlements.manage','settlements.reconcile','merchants.view','merchants.manage','merchants.access_manage','merchant_locations.view','merchant_locations.manage','merchant_offers.view','merchant_offers.manage','merchant_redemptions.view','merchant_redemptions.manage','merchant_reviews.manage','merchant_sales.view','merchant_sales.manage','partners.view','partners.configure','partners.contract_approve','partners.catalog_review','partners.integration_activate','partners.revenue_report') AND p.key NOT LIKE 'games.%';
    SELECT coalesce(array_agg(key ORDER BY key),ARRAY[]::text[]) INTO sorted_expected_permissions
      FROM unnest(expected.expected_permissions) AS key;
    PERFORM pg_temp.expect_true('approved seed role capabilities only: ' || expected.role_key, 'P',
      actual_permissions = sorted_expected_permissions);
  END LOOP;
END;
$test$;

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{}', true);
DO $test$
DECLARE table_name text; column_name text;
BEGIN
  FOR table_name IN SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'public' LOOP
    PERFORM pg_temp.expect_error('anonymous SELECT denied: ' || table_name, 'A',
      format('SELECT count(*) FROM public.%I', table_name), ARRAY['42501']);
    PERFORM pg_temp.expect_error('anonymous INSERT denied: ' || table_name, 'O',
      format('INSERT INTO public.%I DEFAULT VALUES', table_name), ARRAY['42501']);
    SELECT attname INTO column_name FROM pg_catalog.pg_attribute
      WHERE attrelid = ('public.' || table_name)::regclass AND attnum > 0 AND NOT attisdropped ORDER BY attnum LIMIT 1;
    PERFORM pg_temp.expect_error('anonymous UPDATE denied: ' || table_name, 'O',
      format('UPDATE public.%I SET %I = %I', table_name, column_name, column_name), ARRAY['42501']);
    PERFORM pg_temp.expect_error('anonymous DELETE denied: ' || table_name, 'O',
      format('DELETE FROM public.%I', table_name), ARRAY['42501']);
    PERFORM pg_temp.expect_error('anonymous TRUNCATE denied: ' || table_name, 'N',
      format('TRUNCATE public.%I', table_name), ARRAY['42501']);
  END LOOP;
END;
$test$;
SELECT pg_temp.expect_error('anonymous cannot invoke identity definer', 'P',
  $$ SELECT boss_private.current_person_id() $$, ARRAY['42501']);
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"role":"authenticated"}', true);
SELECT pg_temp.expect_true('missing JWT subject has no canonical person', 'G', boss_private.current_person_id() IS NULL);
DO $test$
DECLARE table_name text; column_name text;
BEGIN
  FOR table_name IN SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'public' LOOP
    IF has_table_privilege('authenticated','public.'||table_name,'SELECT') THEN
      PERFORM pg_temp.expect_count('missing identity has no rows: ' || table_name, 'P',
        format('SELECT count(*) FROM public.%I', table_name), 0);
    ELSE
      PERFORM pg_temp.expect_error('missing identity raw-table read denied: ' || table_name, 'P',
        format('SELECT count(*) FROM public.%I',table_name),ARRAY['42501']);
    END IF;
    PERFORM pg_temp.expect_error('authenticated INSERT denied: ' || table_name, 'O',
      format('INSERT INTO public.%I DEFAULT VALUES', table_name), ARRAY['42501']);
    SELECT attname INTO column_name FROM pg_catalog.pg_attribute
      WHERE attrelid = ('public.' || table_name)::regclass AND attnum > 0 AND NOT attisdropped ORDER BY attnum LIMIT 1;
    PERFORM pg_temp.expect_error('authenticated UPDATE denied: ' || table_name, 'O',
      format('UPDATE public.%I SET %I = %I', table_name, column_name, column_name), ARRAY['42501']);
    PERFORM pg_temp.expect_error('authenticated DELETE denied: ' || table_name, 'O',
      format('DELETE FROM public.%I', table_name), ARRAY['42501']);
    PERFORM pg_temp.expect_error('authenticated TRUNCATE denied: ' || table_name, 'N',
      format('TRUNCATE public.%I', table_name), ARRAY['42501']);
  END LOOP;
END;
$test$;
RESET ROLE;

-- Synthetic domain fixtures and relationship/scoped-permission cases follow.
INSERT INTO auth.users (id)
SELECT pg_temp.fixture_id('auth-' || label) FROM unnest(ARRAY[
  'alice','bob','coach','household-only','guardian','platform','suspended-account',
  'suspended-person','expired','future','inactive','multiscope','unit-admin','org-admin',
  'outsider','guardian-unverified','guardian-wrong-flag','guardian-expired','unknown','roster-only'
]) AS label;

INSERT INTO public.people (id, display_name, status)
SELECT pg_temp.fixture_id(label), 'Synthetic ' || label,
  CASE WHEN label = 'suspended-person' THEN 'suspended' ELSE 'active' END
FROM unnest(ARRAY[
  'alice','bob','coach','household-only','guardian','platform','suspended-account',
  'suspended-person','expired','future','inactive','multiscope','unit-admin','org-admin',
  'outsider','guardian-unverified','guardian-wrong-flag','guardian-expired','dependent','roster-only'
]) AS label;
UPDATE public.people SET date_of_birth = '2009-01-01', primary_email = 'synthetic-minor@example.invalid',
  primary_phone = 'synthetic-not-a-phone' WHERE id = pg_temp.fixture_id('dependent');

INSERT INTO public.user_accounts (id,auth_user_id,person_id,account_status)
SELECT pg_temp.fixture_id('account-' || label), pg_temp.fixture_id('auth-' || label), pg_temp.fixture_id(label),
  CASE WHEN label = 'suspended-account' THEN 'suspended' ELSE 'active' END
FROM unnest(ARRAY[
  'alice','bob','coach','household-only','guardian','platform','suspended-account',
  'suspended-person','expired','future','inactive','multiscope','unit-admin','org-admin',
  'outsider','guardian-unverified','guardian-wrong-flag','guardian-expired','roster-only'
]) AS label;

INSERT INTO public.organizations (id,name,slug,status) VALUES
  (pg_temp.fixture_id('org-a'),'Synthetic Organization A','synthetic-phase2a-org-a','active'),
  (pg_temp.fixture_id('org-b'),'Synthetic Organization B','synthetic-phase2a-org-b','active'),
  (pg_temp.fixture_id('org-suspended'),'Synthetic Suspended Organization','synthetic-phase2a-org-suspended','suspended');
INSERT INTO public.organization_units (id,organization_id,parent_unit_id,unit_type,name,slug) VALUES
  (pg_temp.fixture_id('unit-a'),pg_temp.fixture_id('org-a'),NULL,'program','Synthetic A Root','a-root'),
  (pg_temp.fixture_id('unit-a-child'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a'),'sport','Synthetic A Child','a-child'),
  (pg_temp.fixture_id('unit-b'),pg_temp.fixture_id('org-b'),NULL,'program','Synthetic B Root','b-root');
INSERT INTO public.seasons (id,organization_id,parent_unit_id,name,status) VALUES
  (pg_temp.fixture_id('season-a'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a'),'Synthetic Season A','active'),
  (pg_temp.fixture_id('season-a-next'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a-child'),'Synthetic Next Season A','active'),
  (pg_temp.fixture_id('season-b'),pg_temp.fixture_id('org-b'),pg_temp.fixture_id('unit-b'),'Synthetic Season B','active');
INSERT INTO public.teams (id,organization_id,parent_unit_id,season_id,name,slug,status,visibility) VALUES
  (pg_temp.fixture_id('team-a'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a'),pg_temp.fixture_id('season-a'),'Synthetic Team A','team-a','active','private'),
  (pg_temp.fixture_id('team-b'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a-child'),pg_temp.fixture_id('season-a-next'),'Synthetic Team B','team-b','active','private'),
  (pg_temp.fixture_id('team-c'),pg_temp.fixture_id('org-b'),pg_temp.fixture_id('unit-b'),pg_temp.fixture_id('season-b'),'Synthetic Team C','team-c','active','private'),
  (pg_temp.fixture_id('team-public'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a'),NULL,'Synthetic Unpublished Public Team','team-public','active','public');
INSERT INTO public.organization_memberships (id,organization_id,person_id,membership_type,status,starts_at,ends_at) VALUES
  (pg_temp.fixture_id('org-membership-alice'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('alice'),'organization_owner','active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('org-membership-bob'),pg_temp.fixture_id('org-b'),pg_temp.fixture_id('bob'),'member','active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('org-membership-expired'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('expired'),'member','active',now() - interval '2 days',now() - interval '1 day'),
  (pg_temp.fixture_id('org-membership-future'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('future'),'member','active',now() + interval '1 day',NULL),
  (pg_temp.fixture_id('org-membership-inactive'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('inactive'),'member','inactive',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('org-membership-suspended'),pg_temp.fixture_id('org-suspended'),pg_temp.fixture_id('alice'),'member','active',now() - interval '1 day',NULL);
INSERT INTO public.participants (id,person_id,participant_type) VALUES
  (pg_temp.fixture_id('participant-dependent'),pg_temp.fixture_id('dependent'),'athlete'),
  (pg_temp.fixture_id('participant-bob'),pg_temp.fixture_id('bob'),'athlete');
INSERT INTO public.team_memberships (id,organization_id,team_id,person_id,participant_id,membership_type,status,starts_at,ends_at) VALUES
  (pg_temp.fixture_id('team-membership-coach'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-a'),pg_temp.fixture_id('coach'),NULL,'head_coach','active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('team-membership-dependent'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-a'),pg_temp.fixture_id('dependent'),pg_temp.fixture_id('participant-dependent'),'athlete','active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('team-membership-dependent-next'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-b'),pg_temp.fixture_id('dependent'),pg_temp.fixture_id('participant-dependent'),'athlete','active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('team-membership-bob'),pg_temp.fixture_id('org-b'),pg_temp.fixture_id('team-c'),pg_temp.fixture_id('bob'),pg_temp.fixture_id('participant-bob'),'athlete','active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('team-membership-expired'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-b'),pg_temp.fixture_id('expired'),NULL,'volunteer','active',now() - interval '2 days',now() - interval '1 day'),
  (pg_temp.fixture_id('team-membership-future'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-b'),pg_temp.fixture_id('future'),NULL,'volunteer','active',now() + interval '1 day',NULL),
  (pg_temp.fixture_id('team-membership-inactive'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-b'),pg_temp.fixture_id('inactive'),NULL,'volunteer','suspended',now() - interval '1 day',NULL);
INSERT INTO public.households (id,name) VALUES
  (pg_temp.fixture_id('household-a'),'Synthetic Household A'),
  (pg_temp.fixture_id('household-b'),'Synthetic Household B');
INSERT INTO public.household_memberships (id,household_id,person_id,relationship_type,status,starts_at,ends_at) VALUES
  (pg_temp.fixture_id('household-membership-alice'),pg_temp.fixture_id('household-a'),pg_temp.fixture_id('alice'),'adult','active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('household-membership-only'),pg_temp.fixture_id('household-a'),pg_temp.fixture_id('household-only'),'adult','active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('household-membership-dependent'),pg_temp.fixture_id('household-a'),pg_temp.fixture_id('dependent'),'dependent','active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('household-membership-bob'),pg_temp.fixture_id('household-b'),pg_temp.fixture_id('bob'),'adult','active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('household-membership-expired'),pg_temp.fixture_id('household-a'),pg_temp.fixture_id('expired'),'adult','active',now() - interval '2 days',now() - interval '1 day'),
  (pg_temp.fixture_id('household-membership-future'),pg_temp.fixture_id('household-a'),pg_temp.fixture_id('future'),'adult','active',now() + interval '1 day',NULL),
  (pg_temp.fixture_id('household-membership-inactive'),pg_temp.fixture_id('household-a'),pg_temp.fixture_id('inactive'),'adult','suspended',now() - interval '1 day',NULL);
INSERT INTO public.guardian_relationships
  (id,guardian_person_id,dependent_person_id,relationship_type,authority_status,can_manage_profile,starts_at,ends_at,verified_at) VALUES
  (pg_temp.fixture_id('guardian-valid'),pg_temp.fixture_id('guardian'),pg_temp.fixture_id('dependent'),'guardian','active',true,now() - interval '1 day',NULL,now() - interval '1 day'),
  (pg_temp.fixture_id('guardian-unverified-relation'),pg_temp.fixture_id('guardian-unverified'),pg_temp.fixture_id('dependent'),'guardian','active',true,now() - interval '1 day',NULL,NULL),
  (pg_temp.fixture_id('guardian-future-verification'),pg_temp.fixture_id('guardian-unverified'),pg_temp.fixture_id('bob'),'guardian','active',true,now() - interval '1 day',NULL,now() + interval '1 day'),
  (pg_temp.fixture_id('guardian-wrong-flag-relation'),pg_temp.fixture_id('guardian-wrong-flag'),pg_temp.fixture_id('dependent'),'guardian','active',false,now() - interval '1 day',NULL,now() - interval '1 day'),
  (pg_temp.fixture_id('guardian-expired-relation'),pg_temp.fixture_id('guardian-expired'),pg_temp.fixture_id('dependent'),'guardian','active',true,now() - interval '2 days',now() - interval '1 day',now() - interval '2 days');

-- Minimal fixture permission maps make the tests independent of product role-map decisions.
INSERT INTO public.roles (id,key,name,allowed_scope_types) VALUES
  (pg_temp.fixture_id('role-team-reader'),'synthetic_phase2a_team_reader','Synthetic Team Reader',ARRAY['team']),
  (pg_temp.fixture_id('role-org-reader'),'synthetic_phase2a_org_reader','Synthetic Organization Reader',ARRAY['organization']),
  (pg_temp.fixture_id('role-unit-reader'),'synthetic_phase2a_unit_reader','Synthetic Unit Reader',ARRAY['organization_unit']),
  (pg_temp.fixture_id('role-platform-reader'),'synthetic_phase2a_platform_reader','Synthetic Platform Reader',ARRAY['platform']),
  (pg_temp.fixture_id('role-roster-only'),'synthetic_phase2a_roster_only','Synthetic Roster Only',ARRAY['team']),
  (pg_temp.fixture_id('role-unused'),'synthetic_phase2a_unused','Synthetic Unused Role',ARRAY['platform']);
INSERT INTO public.role_permissions (role_id,permission_id)
SELECT pg_temp.fixture_id('role-team-reader'), id FROM public.permissions WHERE key IN ('team.view','team.roster.view','participant.profile.view')
UNION ALL SELECT pg_temp.fixture_id('role-org-reader'),id FROM public.permissions WHERE key IN ('organization.view','organization.members.view','team.view','team.roster.view','participant.profile.view','roles.view','audit.view')
UNION ALL SELECT pg_temp.fixture_id('role-unit-reader'),id FROM public.permissions WHERE key IN ('team.view','team.roster.view')
UNION ALL SELECT pg_temp.fixture_id('role-platform-reader'),id FROM public.permissions WHERE key IN ('organization.view','team.view','person.profile.view','participant.profile.view','household.view','audit.view')
UNION ALL SELECT pg_temp.fixture_id('role-roster-only'),id FROM public.permissions WHERE key = 'team.roster.view';
INSERT INTO public.role_assignments (id,person_id,role_id,scope_type,scope_id,organization_id,status,starts_at,ends_at) VALUES
  (pg_temp.fixture_id('assignment-coach'),pg_temp.fixture_id('coach'),pg_temp.fixture_id('role-team-reader'),'team',pg_temp.fixture_id('team-a'),pg_temp.fixture_id('org-a'),'active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('assignment-org-admin'),pg_temp.fixture_id('org-admin'),pg_temp.fixture_id('role-org-reader'),'organization',pg_temp.fixture_id('org-a'),pg_temp.fixture_id('org-a'),'active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('assignment-unit-admin'),pg_temp.fixture_id('unit-admin'),pg_temp.fixture_id('role-unit-reader'),'organization_unit',pg_temp.fixture_id('unit-a'),pg_temp.fixture_id('org-a'),'active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('assignment-multi-a'),pg_temp.fixture_id('multiscope'),pg_temp.fixture_id('role-team-reader'),'team',pg_temp.fixture_id('team-a'),pg_temp.fixture_id('org-a'),'active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('assignment-multi-c'),pg_temp.fixture_id('multiscope'),pg_temp.fixture_id('role-team-reader'),'team',pg_temp.fixture_id('team-c'),pg_temp.fixture_id('org-b'),'active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('assignment-platform'),pg_temp.fixture_id('platform'),pg_temp.fixture_id('role-platform-reader'),'platform',NULL,NULL,'active',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('assignment-expired'),pg_temp.fixture_id('expired'),pg_temp.fixture_id('role-team-reader'),'team',pg_temp.fixture_id('team-b'),pg_temp.fixture_id('org-a'),'active',now() - interval '2 days',now() - interval '1 day'),
  (pg_temp.fixture_id('assignment-future'),pg_temp.fixture_id('future'),pg_temp.fixture_id('role-team-reader'),'team',pg_temp.fixture_id('team-b'),pg_temp.fixture_id('org-a'),'active',now() + interval '1 day',NULL),
  (pg_temp.fixture_id('assignment-inactive'),pg_temp.fixture_id('inactive'),pg_temp.fixture_id('role-team-reader'),'team',pg_temp.fixture_id('team-b'),pg_temp.fixture_id('org-a'),'suspended',now() - interval '1 day',NULL),
  (pg_temp.fixture_id('assignment-roster-only'),pg_temp.fixture_id('roster-only'),pg_temp.fixture_id('role-roster-only'),'team',pg_temp.fixture_id('team-a'),pg_temp.fixture_id('org-a'),'active',now() - interval '1 day',NULL);

INSERT INTO public.organization_modules (id,organization_id,module_id,status,starts_at)
SELECT pg_temp.fixture_id('org-a-sports'),pg_temp.fixture_id('org-a'),id,'active',now() - interval '1 day'
FROM public.modules WHERE key = 'sports';
INSERT INTO public.entitlements (id,subject_type,subject_id,membership_kind,entitlement_type,entitlement_key,status,starts_at) VALUES
  (pg_temp.fixture_id('entitlement-outsider'),'person',pg_temp.fixture_id('outsider'),NULL,'capability','synthetic_phase2a_access','active',now() - interval '1 day'),
  (pg_temp.fixture_id('entitlement-org-a'),'organization',pg_temp.fixture_id('org-a'),NULL,'capability','synthetic_phase2a_access','active',now() - interval '1 day'),
  (pg_temp.fixture_id('entitlement-household-a'),'household',pg_temp.fixture_id('household-a'),NULL,'capability','synthetic_phase2a_access','active',now() - interval '1 day'),
  (pg_temp.fixture_id('entitlement-membership-alice'),'membership',pg_temp.fixture_id('org-membership-alice'),'organization','capability','synthetic_phase2a_membership','active',now() - interval '1 day');
INSERT INTO public.entitlements (id,subject_type,subject_id,membership_kind,entitlement_type,entitlement_key,status,starts_at)
SELECT pg_temp.fixture_id('entitlement-subject-' || kind || '-' || actor),'membership',pg_temp.fixture_id(prefix || actor),
  kind,'capability','synthetic_phase2a_historical_subject','active',now() - interval '1 day'
FROM unnest(ARRAY['expired','future','inactive']) AS actor
CROSS JOIN (VALUES ('organization','org-membership-'),('team','team-membership-'),('household','household-membership-')) AS kinds(kind,prefix);
INSERT INTO public.entitlements (id,subject_type,subject_id,entitlement_type,entitlement_key,status,starts_at) VALUES
  (pg_temp.fixture_id('entitlement-bob'),'person',pg_temp.fixture_id('bob'),'capability','synthetic_phase2a_subject_lifecycle','active',now() - interval '1 day'),
  (pg_temp.fixture_id('entitlement-household-b'),'household',pg_temp.fixture_id('household-b'),'capability','synthetic_phase2a_subject_lifecycle','active',now() - interval '1 day');
INSERT INTO public.feature_flags (id,key,name,enabled) VALUES
  (pg_temp.fixture_id('flag'),'synthetic_phase2a_enabled','Synthetic enabled flag',true);
INSERT INTO public.feature_flag_overrides (id,feature_flag_id,scope_type,scope_id,enabled) VALUES
  (pg_temp.fixture_id('flag-override'),pg_temp.fixture_id('flag'),'person',pg_temp.fixture_id('outsider'),true);
INSERT INTO public.audit_events (id,organization_id,actor_person_id,action,resource_type,resource_id,scope_type,scope_id) VALUES
  (pg_temp.fixture_id('audit-a'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('alice'),'synthetic.fixture','organization',pg_temp.fixture_id('org-a'),'organization',pg_temp.fixture_id('org-a')),
  (pg_temp.fixture_id('audit-b'),pg_temp.fixture_id('org-b'),pg_temp.fixture_id('bob'),'synthetic.fixture','organization',pg_temp.fixture_id('org-b'),'organization',pg_temp.fixture_id('org-b')),
  (pg_temp.fixture_id('audit-team-a'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('coach'),'synthetic.fixture','team',pg_temp.fixture_id('team-a'),'team',pg_temp.fixture_id('team-a'));

SELECT pg_temp.expect_count('participant with no Auth account exists', 'F',
  $$ SELECT count(*) FROM public.participants p JOIN public.people person ON person.id = p.person_id
      WHERE person.id = pg_temp.fixture_id('dependent') AND NOT EXISTS
        (SELECT 1 FROM public.user_accounts a WHERE a.person_id = person.id) $$, 1);
SELECT pg_temp.expect_count('same canonical participant reused across teams and seasons', 'F',
  $$ SELECT count(DISTINCT t.season_id) FROM public.team_memberships m JOIN public.teams t ON t.id = m.team_id
      WHERE m.participant_id = pg_temp.fixture_id('participant-dependent') $$, 2);

SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('alice');
SELECT pg_temp.expect_true('canonical person mapping is independent of metadata', 'G',
  boss_private.current_person_id() = pg_temp.fixture_id('alice'));
SELECT pg_temp.expect_true('official auth.uid uses JSON subject when legacy setting is empty', 'P',
  auth.uid() = pg_temp.fixture_id('auth-alice'));
SELECT pg_temp.expect_count('own private identity visible', 'G',
  $$ SELECT count(*) FROM public.people WHERE id = pg_temp.fixture_id('alice') $$, 1);
SELECT pg_temp.expect_count('unrelated identity including contact data hidden', 'B',
  $$ SELECT count(*) FROM public.people WHERE id = pg_temp.fixture_id('bob') $$, 0);
SELECT pg_temp.expect_count('minor identity is not shared by household membership', 'B',
  $$ SELECT count(date_of_birth) FROM public.people WHERE id = pg_temp.fixture_id('dependent') $$, 0);
SELECT pg_temp.expect_count('own account visible', 'G',
  $$ SELECT count(*) FROM public.user_accounts WHERE person_id = pg_temp.fixture_id('alice') $$, 1);
SELECT pg_temp.expect_count('other account mapping hidden', 'B',
  $$ SELECT count(*) FROM public.user_accounts WHERE person_id = pg_temp.fixture_id('bob') $$, 0);
SELECT pg_temp.expect_count('same organization basic record visible', 'C',
  $$ SELECT count(*) FROM public.organizations WHERE id = pg_temp.fixture_id('org-a') $$, 1);
SELECT pg_temp.expect_count('different organization record hidden', 'C',
  $$ SELECT count(*) FROM public.organizations WHERE id = pg_temp.fixture_id('org-b') $$, 0);
SELECT pg_temp.expect_count('same organization units visible', 'C',
  $$ SELECT count(*) FROM public.organization_units WHERE organization_id = pg_temp.fixture_id('org-a') $$, 2);
SELECT pg_temp.expect_count('other organization units hidden', 'C',
  $$ SELECT count(*) FROM public.organization_units WHERE organization_id = pg_temp.fixture_id('org-b') $$, 0);
SELECT pg_temp.expect_count('same organization season visible', 'C',
  $$ SELECT count(*) FROM public.seasons WHERE organization_id = pg_temp.fixture_id('org-a') $$, 2);
SELECT pg_temp.expect_count('other organization seasons hidden', 'C',
  $$ SELECT count(*) FROM public.seasons WHERE organization_id = pg_temp.fixture_id('org-b') $$, 0);
SELECT pg_temp.expect_true('membership type does not grant management', 'I',
  NOT boss_private.has_permission('organization.manage',pg_temp.fixture_id('org-a'))
  AND NOT boss_private.has_permission('organization.members.view',pg_temp.fixture_id('org-a')));
SELECT pg_temp.expect_count('organization membership alone does not expose private teams', 'D',
  $$ SELECT count(*) FROM public.teams WHERE organization_id = pg_temp.fixture_id('org-a') $$, 0);
SELECT pg_temp.expect_count('own organization membership visible', 'C',
  $$ SELECT count(*) FROM public.organization_memberships WHERE id = pg_temp.fixture_id('org-membership-alice') $$, 1);
SELECT pg_temp.expect_count('unrelated organization membership hidden', 'C',
  $$ SELECT count(*) FROM public.organization_memberships WHERE person_id = pg_temp.fixture_id('bob') $$, 0);
SELECT pg_temp.expect_count('household basic record visible to own valid relationship', 'E',
  $$ SELECT count(*) FROM public.households WHERE id = pg_temp.fixture_id('household-a') $$, 1);
SELECT pg_temp.expect_count('other household basic record hidden', 'E',
  $$ SELECT count(*) FROM public.households WHERE id = pg_temp.fixture_id('household-b') $$, 0);
SELECT pg_temp.expect_count('own household relationship visible', 'E',
  $$ SELECT count(*) FROM public.household_memberships WHERE person_id = pg_temp.fixture_id('alice') $$, 1);
SELECT pg_temp.expect_count('other household relationships hidden', 'E',
  $$ SELECT count(*) FROM public.household_memberships WHERE household_id = pg_temp.fixture_id('household-b') $$, 0);
SELECT pg_temp.expect_count('same household does not expose dependent relationship', 'E',
  $$ SELECT count(*) FROM public.household_memberships WHERE person_id = pg_temp.fixture_id('dependent') $$, 0);
SELECT pg_temp.expect_true('household membership does not create guardian authority', 'E',
  NOT boss_private.can_manage_dependent_profile(pg_temp.fixture_id('dependent')));
SELECT pg_temp.expect_count('unrelated guardian relationships hidden', 'E',
  $$ SELECT count(*) FROM public.guardian_relationships $$, 0);
SELECT pg_temp.expect_count('audit actor cannot read own event without audit permission', 'N',
  $$ SELECT count(*) FROM public.audit_events WHERE actor_person_id = pg_temp.fixture_id('alice') $$, 0);
SELECT pg_temp.expect_error('own credential mapping cannot be reassigned by ordinary user', 'O',
  $$ UPDATE public.user_accounts SET person_id = pg_temp.fixture_id('platform') WHERE id = pg_temp.fixture_id('account-alice') $$,
  ARRAY['42501']);
SELECT pg_temp.expect_true('member can inspect its own active organization module', 'J',
  boss_private.organization_module_active(pg_temp.fixture_id('org-a'),'sports'));
SELECT pg_temp.expect_true('module helper cannot inspect a different tenant', 'J',
  NOT boss_private.organization_module_active(pg_temp.fixture_id('org-b'),'sports'));
SELECT pg_temp.expect_true('own household entitlement inspectable', 'K',
  boss_private.has_active_entitlement('household',pg_temp.fixture_id('household-a'),'synthetic_phase2a_access'));
SELECT pg_temp.expect_true('own organization membership entitlement inspectable', 'K',
  boss_private.has_active_entitlement('membership',pg_temp.fixture_id('org-membership-alice'),'synthetic_phase2a_membership','organization'));
SELECT pg_temp.expect_true('other person entitlement helper cannot be used as an oracle', 'K',
  NOT boss_private.has_active_entitlement('person',pg_temp.fixture_id('outsider'),'synthetic_phase2a_access'));

-- Shadowing the canonical mapping table must not change a definer helper result.
CREATE TEMP TABLE user_accounts (auth_user_id uuid,person_id uuid,account_status text);
INSERT INTO pg_temp.user_accounts VALUES (pg_temp.fixture_id('auth-alice'),pg_temp.fixture_id('platform'),'active');
SET LOCAL search_path = pg_temp, public, pg_catalog;
SELECT pg_temp.expect_true('temporary table/search_path attack cannot impersonate person', 'P',
  boss_private.current_person_id() = pg_temp.fixture_id('alice'));
SET LOCAL search_path = public;
DROP TABLE pg_temp.user_accounts;

SELECT pg_temp.act_as('alice',true);
SELECT pg_temp.expect_true('anonymous Auth identity rejected even if mapped', 'G',boss_private.current_person_id() IS NULL);
SELECT pg_temp.expect_count('anonymous Auth identity cannot read people', 'A', $$ SELECT count(*) FROM public.people $$, 0);
SELECT set_config('request.jwt.claims', jsonb_build_object('sub',pg_temp.fixture_id('auth-alice'),'role','anon')::text, true);
SELECT pg_temp.expect_true('false authenticated claim cannot obtain mapped identity', 'G',boss_private.current_person_id() IS NULL);
SELECT pg_temp.act_as('unknown');
SELECT pg_temp.expect_true('unmapped Auth identity has no person', 'G',boss_private.current_person_id() IS NULL);
SELECT pg_temp.expect_count('unmapped Auth identity cannot read role catalog', 'P', $$ SELECT count(*) FROM public.roles $$, 0);
SELECT pg_temp.act_as('suspended-account');
SELECT pg_temp.expect_true('suspended account cannot authorize', 'M',boss_private.current_person_id() IS NULL);
SELECT pg_temp.expect_count('suspended account has no organization access', 'M', $$ SELECT count(*) FROM public.organizations $$, 0);
SELECT pg_temp.act_as('suspended-person');
SELECT pg_temp.expect_true('suspended canonical person cannot authorize', 'M',boss_private.current_person_id() IS NULL);
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('roster-only');
SELECT pg_temp.expect_count('roster.view works without separate team.view permission', 'D',
  $$ SELECT count(*) FROM public.team_memberships WHERE team_id = pg_temp.fixture_id('team-a') $$, 2);
SELECT pg_temp.expect_count('roster-only permission does not grant team record', 'I',
  $$ SELECT count(*) FROM public.teams WHERE id = pg_temp.fixture_id('team-a') $$, 0);
SELECT pg_temp.expect_count('roster-only permission cannot read other roster', 'D',
  $$ SELECT count(*) FROM public.team_memberships WHERE team_id = pg_temp.fixture_id('team-c') $$, 0);
SELECT pg_temp.act_as('coach');
SELECT pg_temp.expect_true('team permission matches exact valid resource context', 'D',
  boss_private.has_permission('team.view',pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a'),pg_temp.fixture_id('team-a')));
SELECT pg_temp.expect_true('inconsistent team tenant context rejected', 'D',
  NOT boss_private.has_permission('team.view',pg_temp.fixture_id('org-b'),pg_temp.fixture_id('unit-a'),pg_temp.fixture_id('team-a')));
SELECT pg_temp.expect_true('inconsistent team parent context rejected', 'D',
  NOT boss_private.has_permission('team.view',pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a-child'),pg_temp.fixture_id('team-a')));
SELECT pg_temp.expect_count('coach exact private team visible', 'D',
  $$ SELECT count(*) FROM public.teams WHERE id = pg_temp.fixture_id('team-a') $$, 1);
SELECT pg_temp.expect_count('coach cannot read unrelated same-tenant private team', 'D',
  $$ SELECT count(*) FROM public.teams WHERE id = pg_temp.fixture_id('team-b') $$, 0);
SELECT pg_temp.expect_count('coach cannot read another tenant team', 'D',
  $$ SELECT count(*) FROM public.teams WHERE id = pg_temp.fixture_id('team-c') $$, 0);
SELECT pg_temp.expect_count('coach may read its exact roster with roster permission', 'D',
  $$ SELECT count(*) FROM public.team_memberships WHERE team_id = pg_temp.fixture_id('team-a') $$, 2);
SELECT pg_temp.expect_count('coach cannot read unrelated roster', 'D',
  $$ SELECT count(*) FROM public.team_memberships WHERE team_id = pg_temp.fixture_id('team-c') $$, 0);
SELECT pg_temp.expect_count('coach scoped participant row visible', 'D',
  $$ SELECT count(*) FROM public.participants WHERE id = pg_temp.fixture_id('participant-dependent') $$, 1);
SELECT pg_temp.expect_count('coach cannot read unrelated participant', 'D',
  $$ SELECT count(*) FROM public.participants WHERE id = pg_temp.fixture_id('participant-bob') $$, 0);
SELECT pg_temp.expect_count('participant permission does not grant minor person contact record', 'B',
  $$ SELECT count(*) FROM public.people WHERE id = pg_temp.fixture_id('dependent') $$, 0);
SELECT pg_temp.expect_true('team role cannot become organization-wide permission', 'I',
  NOT boss_private.has_permission('team.view',pg_temp.fixture_id('org-a'))
  AND NOT boss_private.has_permission('organization.manage',pg_temp.fixture_id('org-a'))
  AND NOT boss_private.has_active_organization_membership(pg_temp.fixture_id('org-a')));
SELECT pg_temp.expect_count('team relationship grants no organization-wide member list', 'I',
  $$ SELECT count(*) FROM public.organization_memberships WHERE organization_id = pg_temp.fixture_id('org-a') $$, 0);
SELECT pg_temp.expect_count('team role grants no organization record without organization permission', 'I',
  $$ SELECT count(*) FROM public.organizations WHERE id = pg_temp.fixture_id('org-a') $$, 0);
SELECT pg_temp.expect_count('visibility public alone does not publish other team to coach', 'D',
  $$ SELECT count(*) FROM public.teams WHERE id = pg_temp.fixture_id('team-public') $$, 0);

SELECT pg_temp.act_as('multiscope');
SELECT pg_temp.expect_count('one person holds two role assignments in separate scopes', 'H',
  $$ SELECT count(*) FROM public.role_assignments WHERE person_id = pg_temp.fixture_id('multiscope') $$, 2);
SELECT pg_temp.expect_count('multiple team scopes allow exactly assigned teams', 'H',
  $$ SELECT count(*) FROM public.teams $$, 2);
SELECT pg_temp.expect_count('multiple roles do not reveal unassigned sibling team', 'I',
  $$ SELECT count(*) FROM public.teams WHERE id = pg_temp.fixture_id('team-b') $$, 0);
SELECT pg_temp.expect_true('multiple team scopes do not imply platform privilege', 'I',
  NOT boss_private.has_permission('person.profile.view'));

SELECT pg_temp.act_as('org-admin');
SELECT pg_temp.expect_count('organization role may read its tenant', 'C',
  $$ SELECT count(*) FROM public.organizations WHERE id = pg_temp.fixture_id('org-a') $$, 1);
SELECT pg_temp.expect_count('organization role does not cross tenants', 'C',
  $$ SELECT count(*) FROM public.organizations WHERE id = pg_temp.fixture_id('org-b') $$, 0);
SELECT pg_temp.expect_count('organization role covers same-tenant teams', 'H',
  $$ SELECT count(*) FROM public.teams WHERE organization_id = pg_temp.fixture_id('org-a') $$, 3);
SELECT pg_temp.expect_count('organization role does not cover other-tenant teams', 'C',
  $$ SELECT count(*) FROM public.teams WHERE organization_id = pg_temp.fixture_id('org-b') $$, 0);
SELECT pg_temp.expect_count('organization roles.view reads team-scoped assignments in actual parent context', 'H',
  $$ SELECT count(*) FROM public.role_assignments WHERE id = pg_temp.fixture_id('assignment-coach') $$, 1);
SELECT pg_temp.expect_count('organization roles.view cannot read different tenant assignment', 'C',
  $$ SELECT count(*) FROM public.role_assignments WHERE id = pg_temp.fixture_id('assignment-multi-c') $$, 0);
SELECT pg_temp.expect_count('organization audit.view reads team-scoped audit in actual parent context', 'N',
  $$ SELECT count(*) FROM public.audit_events WHERE id = pg_temp.fixture_id('audit-team-a') $$, 1);
SELECT pg_temp.expect_count('organization audit.view cannot read different tenant audit', 'C',
  $$ SELECT count(*) FROM public.audit_events WHERE id = pg_temp.fixture_id('audit-b') $$, 0);

SELECT pg_temp.act_as('unit-admin');
SELECT pg_temp.expect_count('exact unit scope covers teams attached to that unit', 'H',
  $$ SELECT count(*) FROM public.teams WHERE parent_unit_id = pg_temp.fixture_id('unit-a') $$, 2);
SELECT pg_temp.expect_count('unit scope does not infer descendant inheritance', 'I',
  $$ SELECT count(*) FROM public.teams WHERE id = pg_temp.fixture_id('team-b') $$, 0);
SELECT pg_temp.expect_true('unit permission cannot become organization-wide permission', 'I',
  NOT boss_private.has_permission('team.view',pg_temp.fixture_id('org-a')));

SELECT pg_temp.act_as('platform');
SELECT pg_temp.expect_count('explicit platform permission can cross tenant A', 'L',
  $$ SELECT count(*) FROM public.organizations WHERE id = pg_temp.fixture_id('org-a') $$, 1);
SELECT pg_temp.expect_count('explicit platform permission can cross tenant B', 'L',
  $$ SELECT count(*) FROM public.organizations WHERE id = pg_temp.fixture_id('org-b') $$, 1);
SELECT pg_temp.expect_count('platform permission reads unrelated private person', 'L',
  $$ SELECT count(*) FROM public.people WHERE id = pg_temp.fixture_id('bob') $$, 1);
SELECT pg_temp.expect_count('platform household permission crosses household boundaries explicitly', 'L',
  $$ SELECT count(*) FROM public.households $$, 2);
SELECT pg_temp.expect_count('platform audit permission crosses tenant boundaries explicitly', 'L',
  $$ SELECT count(*) FROM public.audit_events $$, 3);
SELECT pg_temp.expect_true('platform scoped reader does not get unassigned management permission', 'L',
  NOT boss_private.has_permission('organization.manage',pg_temp.fixture_id('org-a')));
SELECT pg_temp.expect_true('platform permission cannot bypass missing unit scope', 'P',
  boss_private.has_resource_permission('organization.view','organization_unit',NULL,pg_temp.fixture_id('org-a')) IS FALSE);
SELECT pg_temp.expect_true('platform permission cannot bypass missing unit tenant', 'P',
  boss_private.has_resource_permission('organization.view','organization_unit',pg_temp.fixture_id('unit-a'),NULL) IS FALSE);
SELECT pg_temp.expect_true('platform permission cannot bypass missing team scope', 'P',
  boss_private.has_resource_permission('team.view','team',NULL,pg_temp.fixture_id('org-a')) IS FALSE);
SELECT pg_temp.expect_true('platform permission cannot bypass missing person scope', 'P',
  boss_private.has_resource_permission('person.profile.view','person',NULL,NULL) IS FALSE);
SELECT pg_temp.expect_true('platform permission cannot bypass nonexistent person scope', 'P',
  boss_private.has_resource_permission('person.profile.view','person',pg_temp.fixture_id('nonexistent-person'),NULL) IS FALSE);
SELECT pg_temp.expect_true('platform permission cannot bypass missing household scope', 'P',
  boss_private.has_resource_permission('household.view','household',NULL,NULL) IS FALSE);
SELECT pg_temp.expect_true('platform permission cannot bypass nonexistent household scope', 'P',
  boss_private.has_resource_permission('household.view','household',pg_temp.fixture_id('nonexistent-household'),NULL) IS FALSE);
SELECT pg_temp.expect_error('platform-scoped reader still cannot INSERT through Data API role', 'O',
  $$ INSERT INTO public.organizations (name,slug) VALUES ('Synthetic denied','synthetic-denied') $$, ARRAY['42501']);
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('household-only');
SELECT pg_temp.expect_true('household relationship supplies no guardian grant', 'E',
  NOT boss_private.can_manage_dependent_profile(pg_temp.fixture_id('dependent')));
SELECT pg_temp.expect_count('household-only member cannot read minor profile', 'E',
  $$ SELECT count(*) FROM public.people WHERE id = pg_temp.fixture_id('dependent') $$, 0);
SELECT pg_temp.expect_count('household-only member cannot read participant profile', 'E',
  $$ SELECT count(*) FROM public.participants WHERE id = pg_temp.fixture_id('participant-dependent') $$, 0);
SELECT pg_temp.act_as('guardian');
SELECT pg_temp.expect_true('explicit verified guardian profile authority is honored', 'E',
  boss_private.can_manage_dependent_profile(pg_temp.fixture_id('dependent')));
SELECT pg_temp.expect_count('verified guardian can read own dependent person', 'E',
  $$ SELECT count(*) FROM public.people WHERE id = pg_temp.fixture_id('dependent') $$, 1);
SELECT pg_temp.expect_count('verified guardian can read dependent participant', 'E',
  $$ SELECT count(*) FROM public.participants WHERE id = pg_temp.fixture_id('participant-dependent') $$, 1);
SELECT pg_temp.expect_count('guardian relationship does not create household membership', 'E',
  $$ SELECT count(*) FROM public.households WHERE id = pg_temp.fixture_id('household-a') $$, 0);
SELECT pg_temp.expect_count('own explicit guardian relation visible', 'E',
  $$ SELECT count(*) FROM public.guardian_relationships WHERE id = pg_temp.fixture_id('guardian-valid') $$, 1);
DO $test$
DECLARE actor text;
BEGIN
  FOREACH actor IN ARRAY ARRAY['guardian-unverified','guardian-wrong-flag','guardian-expired'] LOOP
    PERFORM pg_temp.act_as(actor);
    PERFORM pg_temp.expect_true(actor || ' cannot manage dependent', 'E',
      NOT boss_private.can_manage_dependent_profile(pg_temp.fixture_id('dependent')));
    PERFORM pg_temp.expect_count(actor || ' cannot read dependent', 'E',
      $$ SELECT count(*) FROM public.people WHERE id = pg_temp.fixture_id('dependent') $$, 0);
  END LOOP;
END;
$test$;
SELECT pg_temp.act_as('guardian-unverified');
SELECT pg_temp.expect_true('future-dated guardian verification cannot authorize now', 'E',
  NOT boss_private.can_manage_dependent_profile(pg_temp.fixture_id('bob')));

DO $test$
DECLARE actor text; kind text; prefix text;
BEGIN
  FOREACH actor IN ARRAY ARRAY['expired','future','inactive'] LOOP
    PERFORM pg_temp.act_as(actor);
    PERFORM pg_temp.expect_true(actor || ' organization relationship does not authorize', 'M',
      NOT boss_private.has_active_organization_membership(pg_temp.fixture_id('org-a')));
    PERFORM pg_temp.expect_true(actor || ' team relationship does not authorize', 'M',
      NOT boss_private.has_active_team_relationship(pg_temp.fixture_id('team-b')));
    PERFORM pg_temp.expect_true(actor || ' household relationship does not authorize', 'M',
      NOT boss_private.has_active_household_membership(pg_temp.fixture_id('household-a')));
    PERFORM pg_temp.expect_true(actor || ' role assignment does not authorize', 'M',
      NOT boss_private.has_permission('team.view',pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a-child'),pg_temp.fixture_id('team-b')));
    PERFORM pg_temp.expect_count(actor || ' cannot read organizations', 'M', $$ SELECT count(*) FROM public.organizations $$, 0);
    PERFORM pg_temp.expect_count(actor || ' cannot read teams', 'M', $$ SELECT count(*) FROM public.teams $$, 0);
    PERFORM pg_temp.expect_count(actor || ' cannot read households', 'M', $$ SELECT count(*) FROM public.households $$, 0);
    PERFORM pg_temp.expect_count(actor || ' own historical organization relationship remains readable', 'M',
      format('SELECT count(*) FROM public.organization_memberships WHERE person_id = %L::uuid',pg_temp.fixture_id(actor)), 1);
    FOR kind,prefix IN SELECT * FROM (VALUES ('organization','org-membership-'),('team','team-membership-'),('household','household-membership-')) AS kinds LOOP
      PERFORM pg_temp.expect_true(actor || ' ' || kind || ' active entitlement on inactive relationship does not become active access', 'K',
        NOT boss_private.has_active_entitlement('membership',pg_temp.fixture_id(prefix || actor),
          'synthetic_phase2a_historical_subject',kind));
      PERFORM pg_temp.expect_count(actor || ' ' || kind || ' historical entitlement remains readable as own history', 'K',
        format('SELECT count(*) FROM public.entitlements WHERE id = %L::uuid',pg_temp.fixture_id('entitlement-subject-' || kind || '-' || actor)), 1);
    END LOOP;
  END LOOP;
END;
$test$;
SELECT pg_temp.act_as('alice');
SELECT pg_temp.expect_true('suspended organization blocks otherwise active membership', 'M',
  NOT boss_private.has_active_organization_membership(pg_temp.fixture_id('org-suspended')));
SELECT pg_temp.expect_count('suspended organization not readable from active membership', 'M',
  $$ SELECT count(*) FROM public.organizations WHERE id = pg_temp.fixture_id('org-suspended') $$, 0);

SELECT pg_temp.act_as('outsider');
SELECT pg_temp.expect_true('own entitlement can be observed', 'K',
  boss_private.has_active_entitlement('person',pg_temp.fixture_id('outsider'),'synthetic_phase2a_access'));
SELECT pg_temp.expect_count('own feature override can be observed', 'K',
  $$ SELECT count(*) FROM public.feature_flag_overrides WHERE id = pg_temp.fixture_id('flag-override') $$, 1);
SELECT pg_temp.expect_true('active module is not an authorization grant to outsider', 'J',
  NOT boss_private.organization_module_active(pg_temp.fixture_id('org-a'),'sports'));
SELECT pg_temp.expect_true('other tenant entitlement does not disclose its active state', 'K',
  NOT boss_private.has_active_entitlement('organization',pg_temp.fixture_id('org-a'),'synthetic_phase2a_access'));
SELECT pg_temp.expect_count('entitlement and enabled flag do not grant organization rows', 'K',
  $$ SELECT count(*) FROM public.organizations $$, 0);
SELECT pg_temp.expect_count('entitlement and enabled flag do not grant team rows', 'K',
  $$ SELECT count(*) FROM public.teams $$, 0);
SELECT pg_temp.expect_count('public visibility alone remains unpublished for authenticated outsider', 'P',
  $$ SELECT count(*) FROM public.teams WHERE visibility = 'public' $$, 0);
SELECT pg_temp.expect_count('entitlement and flag do not grant other private identities', 'K',
  $$ SELECT count(*) FROM public.people WHERE id <> pg_temp.fixture_id('outsider') $$, 0);
SELECT pg_temp.expect_count('entitlement does not expose unrelated household relationships', 'K',
  $$ SELECT count(*) FROM public.household_memberships $$, 0);
SELECT pg_temp.expect_count('entitlement does not expose organization product configuration', 'K',
  $$ SELECT count(*) FROM public.organization_modules $$, 0);
RESET ROLE;

UPDATE public.roles SET status = 'suspended' WHERE id = pg_temp.fixture_id('role-team-reader');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('coach');
SELECT pg_temp.expect_true('inactive role catalog entry grants no permission', 'M',
  NOT boss_private.has_permission('team.view',pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a'),pg_temp.fixture_id('team-a')));
RESET ROLE;
UPDATE public.roles SET status = 'active' WHERE id = pg_temp.fixture_id('role-team-reader');
UPDATE public.permissions SET status = 'inactive' WHERE key = 'team.view';
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('coach');
SELECT pg_temp.expect_true('inactive permission catalog entry grants no permission', 'M',
  NOT boss_private.has_permission('team.view',pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a'),pg_temp.fixture_id('team-a')));
RESET ROLE;
UPDATE public.permissions SET status = 'active' WHERE key = 'team.view';
UPDATE public.people SET status = 'inactive' WHERE id = pg_temp.fixture_id('bob');
UPDATE public.households SET status = 'inactive' WHERE id = pg_temp.fixture_id('household-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('platform');
SELECT pg_temp.expect_true('inactive person subject makes otherwise active entitlement inactive', 'K',
  NOT boss_private.has_active_entitlement('person',pg_temp.fixture_id('bob'),'synthetic_phase2a_subject_lifecycle'));
SELECT pg_temp.expect_true('inactive household subject makes otherwise active entitlement inactive', 'K',
  NOT boss_private.has_active_entitlement('household',pg_temp.fixture_id('household-b'),'synthetic_phase2a_subject_lifecycle'));
RESET ROLE;
UPDATE public.people SET status = 'active' WHERE id = pg_temp.fixture_id('bob');
UPDATE public.households SET status = 'active' WHERE id = pg_temp.fixture_id('household-b');
UPDATE public.organization_modules SET ends_at = now() WHERE id = pg_temp.fixture_id('org-a-sports');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('alice');
SELECT pg_temp.expect_true('expired organization module is inactive', 'J',
  NOT boss_private.organization_module_active(pg_temp.fixture_id('org-a'),'sports'));
RESET ROLE;
UPDATE public.entitlements SET ends_at = now() WHERE id = pg_temp.fixture_id('entitlement-outsider');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('outsider');
SELECT pg_temp.expect_true('expired own entitlement is inactive', 'K',
  NOT boss_private.has_active_entitlement('person',pg_temp.fixture_id('outsider'),'synthetic_phase2a_access'));
RESET ROLE;

-- Trusted writers must also preserve integrity. These checks are deliberately
-- separate from client grant/RLS denials so a missing grant cannot mask a bad FK.
SELECT pg_temp.expect_error('duplicate organization slug rejected', 'O',
  $$ INSERT INTO public.organizations (name,slug) VALUES ('Synthetic duplicate','synthetic-phase2a-org-a') $$, ARRAY['23505']);
SELECT pg_temp.expect_error('duplicate auth user mapping rejected', 'G',
  $$ INSERT INTO public.user_accounts (auth_user_id,person_id,account_status) VALUES
     (pg_temp.fixture_id('auth-alice'),pg_temp.fixture_id('dependent'),'inactive') $$, ARRAY['23505']);
SELECT pg_temp.expect_error('second active account for same person rejected', 'G',
  $$ INSERT INTO public.user_accounts (auth_user_id,person_id,account_status) VALUES
     (pg_temp.fixture_id('auth-unknown'),pg_temp.fixture_id('alice'),'active') $$, ARRAY['23505']);
SELECT pg_temp.expect_error('active account without auth mapping rejected', 'G',
  $$ INSERT INTO public.user_accounts (person_id,account_status) VALUES (pg_temp.fixture_id('dependent'),'active') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('canonical account person cannot be repointed by trusted writer', 'G',
  $$ UPDATE public.user_accounts SET person_id = pg_temp.fixture_id('bob') WHERE id = pg_temp.fixture_id('account-alice') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('existing auth mapping cannot be rebound by trusted writer', 'G',
  $$ UPDATE public.user_accounts SET auth_user_id = pg_temp.fixture_id('auth-unknown') WHERE id = pg_temp.fixture_id('account-alice') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('canonical participant person unique', 'F',
  $$ INSERT INTO public.participants (person_id) VALUES (pg_temp.fixture_id('dependent')) $$, ARRAY['23505']);
SELECT pg_temp.expect_error('participant must reference real person', 'F',
  $$ INSERT INTO public.participants (person_id) VALUES (pg_temp.fixture_id('nonexistent-person')) $$, ARRAY['23503']);
SELECT pg_temp.expect_error('participant cannot be repointed', 'F',
  $$ UPDATE public.participants SET person_id = pg_temp.fixture_id('alice') WHERE id = pg_temp.fixture_id('participant-dependent') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('self guardian rejected', 'E',
  $$ INSERT INTO public.guardian_relationships (guardian_person_id,dependent_person_id) VALUES
     (pg_temp.fixture_id('alice'),pg_temp.fixture_id('alice')) $$, ARRAY['23514']);
SELECT pg_temp.expect_error('direct hierarchy cycle rejected', 'O',
  $$ UPDATE public.organization_units SET parent_unit_id = id WHERE id = pg_temp.fixture_id('unit-a') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('indirect hierarchy cycle rejected', 'O',
  $$ UPDATE public.organization_units SET parent_unit_id = pg_temp.fixture_id('unit-a-child') WHERE id = pg_temp.fixture_id('unit-a') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('cross-tenant hierarchy parent insert rejected', 'O',
  $$ INSERT INTO public.organization_units (organization_id,parent_unit_id,unit_type,name,slug) VALUES
     (pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-b'),'program','Synthetic invalid','invalid-parent') $$, ARRAY['23503']);
SELECT pg_temp.expect_error('cross-tenant hierarchy parent update rejected', 'O',
  $$ UPDATE public.organization_units SET parent_unit_id = pg_temp.fixture_id('unit-b') WHERE id = pg_temp.fixture_id('unit-a') $$, ARRAY['23503']);
SELECT pg_temp.expect_error('unit tenant immutable on update', 'O',
  $$ UPDATE public.organization_units SET organization_id = pg_temp.fixture_id('org-b') WHERE id = pg_temp.fixture_id('unit-a') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('season parent from another tenant rejected', 'O',
  $$ INSERT INTO public.seasons (organization_id,parent_unit_id,name) VALUES
     (pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-b'),'Synthetic invalid season') $$, ARRAY['23503']);
SELECT pg_temp.expect_error('reversed season date range rejected', 'O',
  $$ INSERT INTO public.seasons (organization_id,name,starts_on,ends_on) VALUES
     (pg_temp.fixture_id('org-a'),'Synthetic invalid range','2026-09-30','2026-09-29') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('reversed season registration range rejected', 'O',
  $$ INSERT INTO public.seasons (organization_id,name,registration_opens_at,registration_closes_at) VALUES
     (pg_temp.fixture_id('org-a'),'Synthetic invalid registration',now(),now() - interval '1 hour') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('team season from another tenant rejected', 'O',
  $$ INSERT INTO public.teams (organization_id,season_id,name,slug) VALUES
     (pg_temp.fixture_id('org-a'),pg_temp.fixture_id('season-b'),'Synthetic invalid','invalid-season') $$, ARRAY['23503']);
SELECT pg_temp.expect_error('team parent from another tenant rejected', 'O',
  $$ INSERT INTO public.teams (organization_id,parent_unit_id,name,slug) VALUES
     (pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-b'),'Synthetic invalid','invalid-unit') $$, ARRAY['23503']);
SELECT pg_temp.expect_error('team tenant immutable on update', 'O',
  $$ UPDATE public.teams SET organization_id = pg_temp.fixture_id('org-b') WHERE id = pg_temp.fixture_id('team-a') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('team relationship tenant mismatch rejected', 'O',
  $$ INSERT INTO public.team_memberships (organization_id,team_id,person_id) VALUES
     (pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-c'),pg_temp.fixture_id('alice')) $$, ARRAY['23503']);
SELECT pg_temp.expect_error('participant and roster person mismatch rejected', 'O',
  $$ INSERT INTO public.team_memberships (organization_id,team_id,person_id,participant_id) VALUES
     (pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-a'),pg_temp.fixture_id('alice'),pg_temp.fixture_id('participant-dependent')) $$, ARRAY['23503']);
SELECT pg_temp.expect_error('team role from another tenant rejected', 'O',
  $$ INSERT INTO public.role_assignments (person_id,role_id,scope_type,scope_id,organization_id) VALUES
     (pg_temp.fixture_id('alice'),pg_temp.fixture_id('role-team-reader'),'team',pg_temp.fixture_id('team-c'),pg_temp.fixture_id('org-a')) $$, ARRAY['23503']);
SELECT pg_temp.expect_error('team role nonexistent resource rejected', 'O',
  $$ INSERT INTO public.role_assignments (person_id,role_id,scope_type,scope_id,organization_id) VALUES
     (pg_temp.fixture_id('alice'),pg_temp.fixture_id('role-team-reader'),'team',pg_temp.fixture_id('nonexistent-team'),pg_temp.fixture_id('org-a')) $$, ARRAY['23503']);
SELECT pg_temp.expect_error('organization unit role tenant mismatch rejected', 'O',
  $$ INSERT INTO public.role_assignments (person_id,role_id,scope_type,scope_id,organization_id) VALUES
     (pg_temp.fixture_id('alice'),pg_temp.fixture_id('role-unit-reader'),'organization_unit',pg_temp.fixture_id('unit-b'),pg_temp.fixture_id('org-a')) $$, ARRAY['23503']);
SELECT pg_temp.expect_error('organization role scope must equal tenant', 'O',
  $$ INSERT INTO public.role_assignments (person_id,role_id,scope_type,scope_id,organization_id) VALUES
     (pg_temp.fixture_id('alice'),pg_temp.fixture_id('role-org-reader'),'organization',pg_temp.fixture_id('org-b'),pg_temp.fixture_id('org-a')) $$, ARRAY['23514']);
SELECT pg_temp.expect_error('team-only role cannot be assigned at platform scope', 'I',
  $$ INSERT INTO public.role_assignments (person_id,role_id,scope_type) VALUES
     (pg_temp.fixture_id('alice'),pg_temp.fixture_id('role-team-reader'),'platform') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('platform assignment must have null resource and tenant', 'I',
  $$ INSERT INTO public.role_assignments (person_id,role_id,scope_type,scope_id,organization_id) VALUES
     (pg_temp.fixture_id('alice'),pg_temp.fixture_id('role-platform-reader'),'platform',pg_temp.fixture_id('org-a'),pg_temp.fixture_id('org-a')) $$, ARRAY['23514']);
SELECT pg_temp.expect_error('role catalog cannot invalidate existing scope history', 'I',
  $$ UPDATE public.roles SET allowed_scope_types = ARRAY['platform'] WHERE id = pg_temp.fixture_id('role-team-reader') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('unused role scope catalog is also immutable', 'I',
  $$ UPDATE public.roles SET allowed_scope_types = ARRAY['team'] WHERE id = pg_temp.fixture_id('role-unused') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('role allowed scope cannot be empty', 'I',
  $$ INSERT INTO public.roles (key,name,allowed_scope_types) VALUES ('synthetic_empty_role','Synthetic invalid',ARRAY[]::text[]) $$, ARRAY['23514']);
SELECT pg_temp.expect_error('entitlement must reference a real subject', 'K',
  $$ INSERT INTO public.entitlements (subject_type,subject_id,entitlement_type,entitlement_key) VALUES
     ('organization',pg_temp.fixture_id('nonexistent-org'),'capability','synthetic') $$, ARRAY['23503']);
SELECT pg_temp.expect_error('membership entitlement requires explicit kind', 'K',
  $$ INSERT INTO public.entitlements (subject_type,subject_id,entitlement_type,entitlement_key) VALUES
     ('membership',pg_temp.fixture_id('org-membership-alice'),'capability','synthetic') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('membership entitlement kind must match real referenced relation', 'K',
  $$ INSERT INTO public.entitlements (subject_type,subject_id,membership_kind,entitlement_type,entitlement_key) VALUES
     ('membership',pg_temp.fixture_id('team-membership-coach'),'organization','capability','synthetic') $$, ARRAY['23503']);
SELECT pg_temp.expect_error('person entitlement cannot carry membership kind', 'K',
  $$ INSERT INTO public.entitlements (subject_type,subject_id,membership_kind,entitlement_type,entitlement_key) VALUES
     ('person',pg_temp.fixture_id('alice'),'organization','capability','synthetic') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('flag override requires real scoped subject', 'K',
  $$ INSERT INTO public.feature_flag_overrides (feature_flag_id,scope_type,scope_id,enabled) VALUES
     (pg_temp.fixture_id('flag'),'organization',pg_temp.fixture_id('nonexistent-org'),true) $$, ARRAY['23503']);
SELECT pg_temp.expect_error('platform flag override requires null scope id', 'K',
  $$ INSERT INTO public.feature_flag_overrides (feature_flag_id,scope_type,scope_id,enabled) VALUES
     (pg_temp.fixture_id('flag'),'platform',pg_temp.fixture_id('org-a'),true) $$, ARRAY['23514']);
SELECT pg_temp.expect_error('visibility vocabulary rejects implicit ungoverned value', 'P',
  $$ INSERT INTO public.teams (organization_id,name,slug,visibility) VALUES
     (pg_temp.fixture_id('org-a'),'Synthetic invalid visibility','invalid-visibility','everyone') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('status vocabulary rejects arbitrary state', 'M',
  $$ INSERT INTO public.people (display_name,status) VALUES ('Synthetic invalid','approved') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('trusted owner cannot rewrite audit event', 'N',
  $$ UPDATE public.audit_events SET action = 'synthetic.rewrite' WHERE id = pg_temp.fixture_id('audit-a') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('trusted owner cannot delete audit event', 'N',
  $$ DELETE FROM public.audit_events WHERE id = pg_temp.fixture_id('audit-a') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('trusted owner cannot truncate audit history', 'N',
  $$ TRUNCATE public.audit_events CASCADE $$, ARRAY['23514']);
SELECT pg_temp.expect_error('audit team scope must belong to same tenant', 'N',
  $$ INSERT INTO public.audit_events (organization_id,action,resource_type,scope_type,scope_id) VALUES
     (pg_temp.fixture_id('org-a'),'synthetic.invalid','team','team',pg_temp.fixture_id('team-c')) $$, ARRAY['23503']);
SELECT pg_temp.expect_error('audit unit scope must belong to same tenant', 'N',
  $$ INSERT INTO public.audit_events (organization_id,action,resource_type,scope_type,scope_id) VALUES
     (pg_temp.fixture_id('org-a'),'synthetic.invalid','organization_unit','organization_unit',pg_temp.fixture_id('unit-b')) $$, ARRAY['23503']);
SELECT pg_temp.expect_error('platform audit cannot carry a misleading tenant context', 'N',
  $$ INSERT INTO public.audit_events (organization_id,action,resource_type,scope_type) VALUES
     (pg_temp.fixture_id('org-a'),'synthetic.invalid','platform','platform') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('person audit requires a real anchored person', 'N',
  $$ INSERT INTO public.audit_events (action,resource_type,scope_type,scope_id) VALUES
     ('synthetic.invalid','person','person',pg_temp.fixture_id('nonexistent-person')) $$, ARRAY['23503']);
SELECT pg_temp.expect_error('household audit requires a real anchored household', 'N',
  $$ INSERT INTO public.audit_events (action,resource_type,scope_type,scope_id) VALUES
     ('synthetic.invalid','household','household',pg_temp.fixture_id('nonexistent-household')) $$, ARRAY['23503']);

-- Ending historical relationships is allowed; changing their principals is not.
DO $test$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY['organization_memberships','team_memberships','household_memberships',
    'guardian_relationships','role_assignments','organization_modules','entitlements','feature_flag_overrides'] LOOP
    PERFORM pg_temp.expect_error('invalid relationship window rejected: ' || table_name, 'M',
      format('UPDATE public.%I SET ends_at = starts_at',table_name), ARRAY['23514']);
  END LOOP;
END;
$test$;
SELECT pg_temp.expect_error('organization membership person cannot be repointed', 'O',
  $$ UPDATE public.organization_memberships SET person_id = pg_temp.fixture_id('bob') WHERE id = pg_temp.fixture_id('org-membership-alice') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('team membership person cannot be repointed', 'O',
  $$ UPDATE public.team_memberships SET person_id = pg_temp.fixture_id('alice') WHERE id = pg_temp.fixture_id('team-membership-coach') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('household membership person cannot be repointed', 'O',
  $$ UPDATE public.household_memberships SET person_id = pg_temp.fixture_id('bob') WHERE id = pg_temp.fixture_id('household-membership-alice') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('guardian dependent cannot be repointed', 'E',
  $$ UPDATE public.guardian_relationships SET dependent_person_id = pg_temp.fixture_id('alice') WHERE id = pg_temp.fixture_id('guardian-valid') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('role assignment cannot be repointed to another tenant', 'O',
  $$ UPDATE public.role_assignments SET scope_id = pg_temp.fixture_id('team-c'),organization_id = pg_temp.fixture_id('org-b') WHERE id = pg_temp.fixture_id('assignment-coach') $$, ARRAY['23514']);
SELECT pg_temp.expect_error('entitlement subject cannot be repointed', 'K',
  $$ UPDATE public.entitlements SET subject_id = pg_temp.fixture_id('bob') WHERE id = pg_temp.fixture_id('entitlement-outsider') $$, ARRAY['23514']);

-- The server role is an explicit trusted writer; clients cannot assume it.
-- These valid writes catch accidentally unusable grant/trigger combinations.
SET LOCAL ROLE service_role;
INSERT INTO public.organizations (id,name,slug) VALUES
  (pg_temp.fixture_id('service-org'),'Synthetic server-owned organization','synthetic-phase2a-service-org');
SELECT pg_temp.expect_count('trusted server can insert organization', 'P',
  $$ SELECT count(*) FROM public.organizations WHERE id = pg_temp.fixture_id('service-org') $$, 1);
INSERT INTO public.people (id,display_name) VALUES
  (pg_temp.fixture_id('service-person'),'Synthetic server-created person without auth');
INSERT INTO public.participants (id,person_id) VALUES
  (pg_temp.fixture_id('service-participant'),pg_temp.fixture_id('service-person'));
SELECT pg_temp.expect_count('trusted server can create no-Auth participant', 'F',
  $$ SELECT count(*) FROM public.participants WHERE id = pg_temp.fixture_id('service-participant') $$, 1);
INSERT INTO public.audit_events (id,organization_id,action,resource_type,resource_id,scope_type,scope_id) VALUES
  (pg_temp.fixture_id('service-audit'),pg_temp.fixture_id('service-org'),'synthetic.server.insert','organization',pg_temp.fixture_id('service-org'),'organization',pg_temp.fixture_id('service-org'));
SELECT pg_temp.expect_count('trusted server can append audit event', 'N',
  $$ SELECT count(*) FROM public.audit_events WHERE id = pg_temp.fixture_id('service-audit') $$, 1);
SELECT pg_temp.expect_error('trusted server lacks audit UPDATE grant', 'N',
  $$ UPDATE public.audit_events SET action = 'synthetic.rewrite' WHERE id = pg_temp.fixture_id('service-audit') $$, ARRAY['42501']);
SELECT pg_temp.expect_error('trusted server lacks audit DELETE grant', 'N',
  $$ DELETE FROM public.audit_events WHERE id = pg_temp.fixture_id('service-audit') $$, ARRAY['42501']);
SELECT pg_temp.expect_error('trusted server lacks audit TRUNCATE grant', 'N',
  $$ TRUNCATE public.audit_events $$, ARRAY['42501']);
RESET ROLE;

DELETE FROM auth.users WHERE id = pg_temp.fixture_id('auth-outsider');
SELECT pg_temp.expect_count('Auth deletion preserves canonical person', 'G',
  $$ SELECT count(*) FROM public.people WHERE id = pg_temp.fixture_id('outsider') $$, 1);
SELECT pg_temp.expect_count('Auth deletion detaches and deactivates account history', 'G',
  $$ SELECT count(*) FROM public.user_accounts WHERE id = pg_temp.fixture_id('account-outsider')
     AND auth_user_id IS NULL AND account_status = 'inactive' $$, 1);
SELECT pg_temp.expect_count('Auth deletion preserves person entitlement history', 'G',
  $$ SELECT count(*) FROM public.entitlements WHERE id = pg_temp.fixture_id('entitlement-outsider') $$, 1);
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('outsider');
SELECT pg_temp.expect_true('stale identity claim cannot authorize after Auth mapping detaches', 'G',boss_private.current_person_id() IS NULL);
RESET ROLE;

SELECT count(*) AS passed_assertions FROM pg_temp.phase2a_assertions;
SELECT category, count(*) AS passed FROM pg_temp.phase2a_assertions GROUP BY category ORDER BY category;
ROLLBACK;

-- Assert cleanup after rollback instead of trusting the command was present.
DO $test$
BEGIN
  IF EXISTS (SELECT 1 FROM public.people WHERE id = md5('boss-phase2a-transaction-fixture:alice')::uuid)
    OR EXISTS (SELECT 1 FROM auth.users WHERE id = md5('boss-phase2a-transaction-fixture:auth-alice')::uuid)
    OR EXISTS (SELECT 1 FROM public.organizations WHERE slug LIKE 'synthetic-phase2a-%')
    OR EXISTS (SELECT 1 FROM public.roles WHERE key LIKE 'synthetic_phase2a_%')
    OR EXISTS (SELECT 1 FROM public.feature_flags WHERE key LIKE 'synthetic_phase2a_%') THEN
    RAISE EXCEPTION 'FAIL cleanup: synthetic fixture survived rollback';
  END IF;
END;
$test$;
SELECT 'transactional fixtures rolled back; no test records persisted' AS cleanup_result;
