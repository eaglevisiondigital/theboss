-- Phase 2B operational acceptance: actual authenticated-role RPC calls.
-- Synthetic identities, session IDs and fixtures exist only in this transaction.
-- This is a disposable PostgreSQL test, never an Auth HTTP/session simulation.
BEGIN;

CREATE TEMP TABLE phase2b_assertions (assertion text PRIMARY KEY, category text NOT NULL) ON COMMIT DROP;
CREATE TEMP TABLE phase2b_results (label text PRIMARY KEY, result jsonb NOT NULL) ON COMMIT DROP;
GRANT SELECT, INSERT ON pg_temp.phase2b_assertions, pg_temp.phase2b_results TO authenticated, anon;

CREATE FUNCTION pg_temp.fixture_id(label text) RETURNS uuid
LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path = pg_catalog
AS $$ SELECT md5('boss-phase2b-transaction-fixture:' || label)::uuid $$;

CREATE FUNCTION pg_temp.expect_true(label text, category text, actual boolean) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF actual IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'FAIL [%] %: expected true, got %', category, label, actual;
  END IF;
  INSERT INTO pg_temp.phase2b_assertions VALUES (label, category);
END;
$$;

CREATE FUNCTION pg_temp.expect_count(label text, category text, query text, expected bigint) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $$
DECLARE actual bigint;
BEGIN
  EXECUTE query INTO actual;
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'FAIL [%] %: expected % rows, got %', category, label, expected, actual;
  END IF;
  INSERT INTO pg_temp.phase2b_assertions VALUES (label, category);
END;
$$;

CREATE FUNCTION pg_temp.command(operation text, input jsonb, ref text DEFAULT NULL) RETURNS jsonb
LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path = pg_catalog
AS $$ SELECT jsonb_strip_nulls(jsonb_build_object('operation',operation,'input',input,'ref',ref)) $$;

CREATE FUNCTION pg_temp.resource(label text, result_index integer DEFAULT 0) RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = pg_catalog, pg_temp
AS $$ SELECT (result->'results'->$2->>'resource_id')::uuid
  FROM pg_temp.phase2b_results WHERE phase2b_results.label = $1 $$;

CREATE FUNCTION pg_temp.act_as(label text, session_label text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub','',true);
  PERFORM set_config('request.jwt.claim','',true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object(
    'sub',pg_temp.fixture_id('auth-' || label),'role','authenticated',
    'is_anonymous',false,'session_id',pg_temp.fixture_id(coalesce(session_label,'session-' || label)),
    'user_metadata',jsonb_build_object('role','super_administrator','is_admin',true,
      'person_id',pg_temp.fixture_id('platform')))::text,true);
END;
$$;

CREATE FUNCTION pg_temp.ok(label text, category text, commands jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $$
DECLARE result jsonb;
BEGIN
  result := public.boss_admin_mutate(commands,pg_temp.fixture_id('request-' || label));
  PERFORM pg_temp.expect_true(label,category,
    jsonb_typeof(result) = 'object' AND jsonb_typeof(result->'results') = 'array'
    AND jsonb_array_length(result->'results') = jsonb_array_length(commands)
    AND result->>'request_id' = pg_temp.fixture_id('request-' || label)::text);
  INSERT INTO pg_temp.phase2b_results VALUES (label,result);
  RETURN result;
END;
$$;

CREATE FUNCTION pg_temp.deny(label text, category text, commands jsonb,
  allowed_states text[] DEFAULT ARRAY['PT403'], request_label text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, pg_temp AS $$
DECLARE failed boolean := false; safe_error boolean := false;
BEGIN
  BEGIN
    PERFORM public.boss_admin_mutate(commands,
      pg_temp.fixture_id('request-' || coalesce(request_label,label)));
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = ANY(allowed_states) THEN
      failed := true;
      safe_error := length(SQLERRM) < 100 AND SQLERRM !~* '(constraint|relation|column|SQL|stack|password|token|SELECT|INSERT|UPDATE|DELETE)';
    ELSE
      RAISE EXCEPTION 'FAIL [%] %: unexpected SQLSTATE % (%), expected %',category,label,SQLSTATE,SQLERRM,allowed_states;
    END IF;
  END;
  PERFORM pg_temp.expect_true(label,category,failed);
  PERFORM pg_temp.expect_true(label || ': safe error',category,safe_error);
END;
$$;

REVOKE ALL ON FUNCTION pg_temp.fixture_id(text),pg_temp.expect_true(text,text,boolean),
  pg_temp.expect_count(text,text,text,bigint),pg_temp.command(text,jsonb,text),
  pg_temp.resource(text,integer),pg_temp.act_as(text,text),pg_temp.ok(text,text,jsonb),
  pg_temp.deny(text,text,jsonb,text[],text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.fixture_id(text),pg_temp.expect_true(text,text,boolean),
  pg_temp.expect_count(text,text,text,bigint),pg_temp.command(text,jsonb,text),
  pg_temp.resource(text,integer),pg_temp.act_as(text,text),pg_temp.ok(text,text,jsonb),
  pg_temp.deny(text,text,jsonb,text[],text) TO authenticated,anon;

-- ACL and API invariants are checked independently of mutation outcomes.
SELECT pg_temp.expect_count('exact foundation table set remains', 'O',
  $$ SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname='public' AND tablename IN ('people','user_accounts','households','participants','organizations','organization_units','seasons','teams','organization_memberships','team_memberships','household_memberships','guardian_relationships','roles','permissions','role_permissions','role_assignments','modules','organization_modules','entitlements','feature_flags','feature_flag_overrides','audit_events') $$,22);
SELECT pg_temp.expect_count('no public SECURITY DEFINER endpoint', 'O',
  $$ SELECT count(*) FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
     WHERE n.nspname='public' AND p.prosecdef $$,0);
SELECT pg_temp.expect_count('every exposed table retains RLS', 'O',
  $$ SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='public' AND c.relkind='r' AND NOT c.relrowsecurity $$,0);
SELECT pg_temp.expect_count('no client write policy added', 'O',
  $$ SELECT count(*) FROM pg_catalog.pg_policies WHERE schemaname='public' AND cmd<>'SELECT' $$,0);
SELECT pg_temp.expect_true('authenticated can execute protected public mutation wrapper','O',
  has_function_privilege('authenticated','public.boss_admin_mutate(jsonb,uuid)','EXECUTE'));
SELECT pg_temp.expect_true('anon cannot execute protected public mutation wrapper','O',
  NOT has_function_privilege('anon','public.boss_admin_mutate(jsonb,uuid)','EXECUTE'));
SELECT pg_temp.expect_true('receipt store is RLS protected','O',
  (SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid='boss_private.admin_operation_receipts'::regclass));
SELECT pg_temp.expect_true('authenticated cannot read or mutate receipts','O',
  NOT has_table_privilege('authenticated','boss_private.admin_operation_receipts','SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));

-- Auth/account facts are database-owned; the forged editable metadata in every
-- synthetic request above must never become authority.
INSERT INTO auth.users(id,email,email_confirmed_at,is_anonymous,banned_until,deleted_at,raw_user_meta_data)
SELECT pg_temp.fixture_id('auth-' || label),label || '@phase2b.example.invalid',
  CASE WHEN label='unconfirmed' THEN NULL ELSE now()-interval '2 days' END,
  label='anonymous',CASE WHEN label='banned' THEN now()+interval '1 day' END,
  CASE WHEN label='deleted' THEN now()-interval '1 day' END,
  '{"is_admin":true,"role":"super_administrator"}'::jsonb
FROM unnest(ARRAY['platform','org-admin-a','org-admin-b','unit-admin','coach','ordinary',
  'household-only','guardian','wrong-flag','expired','inactive','future','suspended-account',
  'suspended-person','unconfirmed','anonymous','banned','deleted','unmapped','link-auth',
  'ambiguous-auth','unknown']) AS label;
INSERT INTO auth.sessions(id,user_id,not_after)
SELECT pg_temp.fixture_id('session-' || label),pg_temp.fixture_id('auth-' || label),NULL
FROM unnest(ARRAY['platform','org-admin-a','org-admin-b','unit-admin','coach','ordinary',
  'household-only','guardian','wrong-flag','expired','inactive','future','suspended-account',
  'suspended-person','unconfirmed','anonymous','banned','deleted','unmapped','link-auth',
  'ambiguous-auth','unknown']) AS label;
INSERT INTO auth.sessions(id,user_id,not_after) VALUES
  (pg_temp.fixture_id('session-expired-platform'),pg_temp.fixture_id('auth-platform'),now()-interval '1 hour');
INSERT INTO public.people(id,display_name,status)
SELECT pg_temp.fixture_id(label),'Synthetic Phase 2B ' || label,
  CASE WHEN label='suspended-person' THEN 'suspended' ELSE 'active' END
FROM unnest(ARRAY['platform','org-admin-a','org-admin-b','unit-admin','coach','ordinary',
  'household-only','guardian','wrong-flag','expired','inactive','future','suspended-account',
  'suspended-person','unconfirmed','anonymous','banned','deleted','dependent','unrelated-dependent',
  'target-a','target-b','target-unit','target-sibling','target-child','link-person','other-link-person','ambiguous-person']) AS label;
UPDATE public.people SET primary_email='ambiguous-auth@phase2b.example.invalid'
WHERE id=pg_temp.fixture_id('ambiguous-person');
INSERT INTO public.user_accounts(id,auth_user_id,person_id,account_status)
SELECT pg_temp.fixture_id('account-' || label),pg_temp.fixture_id('auth-' || label),pg_temp.fixture_id(label),
  CASE WHEN label='suspended-account' THEN 'suspended' ELSE 'active' END
FROM unnest(ARRAY['platform','org-admin-a','org-admin-b','unit-admin','coach','ordinary',
  'household-only','guardian','wrong-flag','expired','inactive','future','suspended-account',
  'suspended-person','unconfirmed','anonymous','banned','deleted']) AS label;

INSERT INTO public.organizations(id,name,slug,status) VALUES
 (pg_temp.fixture_id('org-a'),'Synthetic Phase 2B Organization A','synthetic-phase2b-org-a','active'),
 (pg_temp.fixture_id('org-b'),'Synthetic Phase 2B Organization B','synthetic-phase2b-org-b','active'),
 (pg_temp.fixture_id('org-suspended'),'Synthetic Phase 2B Suspended Organization','synthetic-phase2b-suspended','suspended');
INSERT INTO public.organization_units(id,organization_id,parent_unit_id,unit_type,name,slug) VALUES
 (pg_temp.fixture_id('unit-a'),pg_temp.fixture_id('org-a'),NULL,'sport','Synthetic unit A','unit-a'),
 (pg_temp.fixture_id('unit-a-child'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a'),'program','Synthetic child','unit-a-child'),
 (pg_temp.fixture_id('unit-a-sibling'),pg_temp.fixture_id('org-a'),NULL,'sport','Synthetic sibling','unit-a-sibling'),
 (pg_temp.fixture_id('unit-b'),pg_temp.fixture_id('org-b'),NULL,'sport','Synthetic unit B','unit-b');
INSERT INTO public.seasons(id,organization_id,parent_unit_id,name,starts_on,ends_on,status) VALUES
 (pg_temp.fixture_id('season-a'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a'),'Synthetic season A','2026-01-01','2026-12-31','active'),
 (pg_temp.fixture_id('season-a-child'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a-child'),'Synthetic child season','2026-01-01','2026-12-31','active'),
 (pg_temp.fixture_id('season-a-sibling'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a-sibling'),'Synthetic sibling season','2026-01-01','2026-12-31','active'),
 (pg_temp.fixture_id('season-b'),pg_temp.fixture_id('org-b'),pg_temp.fixture_id('unit-b'),'Synthetic season B','2026-01-01','2026-12-31','active');
INSERT INTO public.teams(id,organization_id,parent_unit_id,season_id,name,slug,status) VALUES
 (pg_temp.fixture_id('team-a'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a'),pg_temp.fixture_id('season-a'),'Synthetic team A','team-a','active'),
 (pg_temp.fixture_id('team-a-child'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a-child'),pg_temp.fixture_id('season-a-child'),'Synthetic child team','team-a-child','active'),
 (pg_temp.fixture_id('team-a-sibling'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('unit-a-sibling'),pg_temp.fixture_id('season-a-sibling'),'Synthetic sibling team','team-a-sibling','active'),
 (pg_temp.fixture_id('team-b'),pg_temp.fixture_id('org-b'),pg_temp.fixture_id('unit-b'),pg_temp.fixture_id('season-b'),'Synthetic team B','team-b','active');
INSERT INTO public.organization_memberships(id,organization_id,person_id,membership_type,starts_at)
SELECT pg_temp.fixture_id('org-membership-' || label),pg_temp.fixture_id('org-a'),pg_temp.fixture_id(label),'member',now()-interval '2 days'
FROM unnest(ARRAY['org-admin-a','unit-admin','coach','ordinary','target-a','dependent']) AS label;
INSERT INTO public.organization_memberships(id,organization_id,person_id,membership_type,starts_at)
SELECT pg_temp.fixture_id('org-membership-' || label),pg_temp.fixture_id('org-b'),pg_temp.fixture_id(label),'member',now()-interval '2 days'
FROM unnest(ARRAY['org-admin-b','target-b']) AS label;
INSERT INTO public.participants(id,person_id,participant_type) VALUES
 (pg_temp.fixture_id('participant-dependent'),pg_temp.fixture_id('dependent'),'athlete'),
 (pg_temp.fixture_id('participant-target-b'),pg_temp.fixture_id('target-b'),'athlete'),
 (pg_temp.fixture_id('participant-target-sibling'),pg_temp.fixture_id('target-sibling'),'athlete'),
 (pg_temp.fixture_id('participant-target-child'),pg_temp.fixture_id('target-child'),'athlete');
INSERT INTO public.team_memberships(id,organization_id,team_id,person_id,participant_id,membership_type,starts_at) VALUES
 (pg_temp.fixture_id('team-membership-coach'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-a'),pg_temp.fixture_id('coach'),NULL,'coach',now()-interval '2 days'),
 (pg_temp.fixture_id('team-membership-dependent'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-a'),pg_temp.fixture_id('dependent'),pg_temp.fixture_id('participant-dependent'),'athlete',now()-interval '2 days'),
 (pg_temp.fixture_id('team-membership-target-b'),pg_temp.fixture_id('org-b'),pg_temp.fixture_id('team-b'),pg_temp.fixture_id('target-b'),pg_temp.fixture_id('participant-target-b'),'athlete',now()-interval '2 days'),
 (pg_temp.fixture_id('team-membership-target-unit'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-a'),pg_temp.fixture_id('target-unit'),NULL,'member',now()-interval '2 days'),
 (pg_temp.fixture_id('team-membership-target-sibling'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-a-sibling'),pg_temp.fixture_id('target-sibling'),pg_temp.fixture_id('participant-target-sibling'),'athlete',now()-interval '2 days'),
 (pg_temp.fixture_id('team-membership-target-child'),pg_temp.fixture_id('org-a'),pg_temp.fixture_id('team-a-child'),pg_temp.fixture_id('target-child'),pg_temp.fixture_id('participant-target-child'),'athlete',now()-interval '2 days');
INSERT INTO public.households(id,name) VALUES
 (pg_temp.fixture_id('household-a'),'Synthetic Phase 2B Family A'),
 (pg_temp.fixture_id('household-b'),'Synthetic Phase 2B Family B');
INSERT INTO public.household_memberships(id,household_id,person_id,relationship_type,starts_at) VALUES
 (pg_temp.fixture_id('household-membership-only'),pg_temp.fixture_id('household-a'),pg_temp.fixture_id('household-only'),'adult',now()-interval '2 days'),
 (pg_temp.fixture_id('household-membership-dependent'),pg_temp.fixture_id('household-a'),pg_temp.fixture_id('dependent'),'child',now()-interval '2 days'),
 (pg_temp.fixture_id('household-membership-b'),pg_temp.fixture_id('household-b'),pg_temp.fixture_id('target-b'),'adult',now()-interval '2 days');
INSERT INTO public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,can_manage_profile,can_register,starts_at) VALUES
 (pg_temp.fixture_id('guardian-relationship'),pg_temp.fixture_id('guardian'),pg_temp.fixture_id('dependent'),'active',now()-interval '1 day',true,false,now()-interval '2 days'),
 (pg_temp.fixture_id('wrong-flag-relationship'),pg_temp.fixture_id('wrong-flag'),pg_temp.fixture_id('dependent'),'active',now()-interval '1 day',false,true,now()-interval '2 days');

INSERT INTO public.role_assignments(id,person_id,role_id,scope_type,scope_id,organization_id,starts_at,ends_at,status)
SELECT pg_temp.fixture_id('assignment-' || actor),pg_temp.fixture_id(actor),r.id,scope_type,
  CASE WHEN scope_type='platform' THEN NULL ELSE pg_temp.fixture_id(scope_label) END,
  CASE WHEN scope_type='platform' THEN NULL ELSE pg_temp.fixture_id(org_label) END,
  CASE WHEN actor='future' THEN now()+interval '1 day' ELSE now()-interval '2 days' END,
  CASE WHEN actor='expired' THEN now()-interval '1 day' END,
  CASE WHEN actor='inactive' THEN 'inactive' ELSE 'active' END
FROM (VALUES
 ('platform','platform_administrator','platform',NULL,NULL),
 ('org-admin-a','organization_administrator','organization','org-a','org-a'),
 ('org-admin-b','organization_administrator','organization','org-b','org-b'),
 ('unit-admin','program_administrator','organization_unit','unit-a','org-a'),
 ('coach','head_coach','team','team-a','org-a'),
 ('expired','organization_administrator','organization','org-a','org-a'),
 ('inactive','organization_administrator','organization','org-a','org-a'),
 ('future','organization_administrator','organization','org-a','org-a'),
 ('suspended-account','platform_administrator','platform',NULL,NULL),
 ('suspended-person','platform_administrator','platform',NULL,NULL),
 ('unconfirmed','platform_administrator','platform',NULL,NULL),
 ('anonymous','platform_administrator','platform',NULL,NULL),
 ('banned','platform_administrator','platform',NULL,NULL),
 ('deleted','platform_administrator','platform',NULL,NULL)
) f(actor,role_key,scope_type,scope_label,org_label) JOIN public.roles r ON r.key=f.role_key;

-- Only the test transaction gains a synthetic future role for the permission
-- subset check. It is not a migration, catalog addition or production grant.
INSERT INTO public.roles(id,key,name,allowed_scope_types) VALUES
 (pg_temp.fixture_id('ungrantable-role'),'synthetic_phase2b_ungrantable','Synthetic permission-subset test',ARRAY['team']);
INSERT INTO public.role_permissions(role_id,permission_id)
SELECT pg_temp.fixture_id('ungrantable-role'),id FROM public.permissions WHERE key='person.profile.manage';

SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('platform');
SELECT pg_temp.ok('platform creates organization','A',jsonb_build_array(pg_temp.command('organization.create',
  jsonb_build_object('name','Synthetic Phase 2B Created Organization','legal_name','Synthetic Test Only',
    'slug','synthetic-phase2b-created','organization_type','test','timezone','America/Chicago','country','US','default_currency','USD'))));

-- The primary sports foundation flow commits as one RPC transaction. Explicit
-- earlier-result references cannot select arbitrary tables or caller identities.
SELECT pg_temp.ok('primary organization team workflow','A',jsonb_build_array(
 pg_temp.command('organization.create','{"name":"Synthetic Phase 2B Workflow","slug":"synthetic-phase2b-workflow","organization_type":"test"}', 'org'),
 pg_temp.command('module.set',jsonb_build_object('organization_id',jsonb_build_object('$ref','org'),'module_id',(SELECT id FROM public.modules WHERE key='sports'),'status','active'),'module'),
 pg_temp.command('unit.create','{"organization_id":{"$ref":"org"},"unit_type":"sport","name":"Synthetic sport","slug":"synthetic-sport"}','unit'),
 pg_temp.command('season.create','{"organization_id":{"$ref":"org"},"parent_unit_id":{"$ref":"unit"},"name":"Synthetic 2026 season","starts_on":"2026-01-01","ends_on":"2026-12-31","status":"active"}','season'),
 pg_temp.command('team.create','{"organization_id":{"$ref":"org"},"parent_unit_id":{"$ref":"unit"},"season_id":{"$ref":"season"},"name":"Synthetic workflow team","slug":"synthetic-workflow-team","status":"active","visibility":"private"}','team'),
 pg_temp.command('person.create','{"display_name":"Synthetic Phase 2B Athlete"}','athlete'),
 pg_temp.command('participant.create','{"person_id":{"$ref":"athlete"},"participant_type":"athlete"}','participant'),
 pg_temp.command('organization_membership.add','{"organization_id":{"$ref":"org"},"person_id":{"$ref":"athlete"},"membership_type":"athlete"}','org_member'),
 pg_temp.command('team_membership.add','{"team_id":{"$ref":"team"},"person_id":{"$ref":"athlete"},"participant_id":{"$ref":"participant"},"membership_type":"athlete","jersey_number":"12","position_label":"Synthetic position"}','athlete_member'),
 pg_temp.command('person.create','{"display_name":"Synthetic Phase 2B Coach"}','coach'),
 pg_temp.command('team_membership.add','{"team_id":{"$ref":"team"},"person_id":{"$ref":"coach"},"membership_type":"coach"}','coach_member'),
 pg_temp.command('role_assignment.add',jsonb_build_object('person_id',jsonb_build_object('$ref','coach'),'role_id',(SELECT id FROM public.roles WHERE key='head_coach'),'scope_type','team','scope_id',jsonb_build_object('$ref','team'),'organization_id',jsonb_build_object('$ref','org')),'coach_role')
));

SELECT pg_temp.ok('primary family workflow','J',jsonb_build_array(
 pg_temp.command('person.create','{"display_name":"Synthetic Phase 2B Adult"}','adult'),
 pg_temp.command('household.create','{"name":"Synthetic Phase 2B Created Family"}','household'),
 pg_temp.command('household_membership.add','{"household_id":{"$ref":"household"},"person_id":{"$ref":"adult"},"relationship_type":"adult","is_primary_contact":true}','adult_member'),
 pg_temp.command('person.create','{"display_name":"Synthetic Phase 2B Child"}','child'),
 pg_temp.command('participant.create','{"person_id":{"$ref":"child"},"participant_type":"athlete"}','child_participant'),
 pg_temp.command('household_membership.add','{"household_id":{"$ref":"household"},"person_id":{"$ref":"child"},"relationship_type":"child"}','child_member'),
 pg_temp.command('guardian.create','{"guardian_person_id":{"$ref":"adult"},"dependent_person_id":{"$ref":"child"},"can_manage_profile":true,"authority_status":"pending"}','guardian'),
 pg_temp.command('guardian.verify','{"id":{"$ref":"guardian"}}','verification')
));
RESET ROLE;
SELECT pg_temp.expect_count('created athlete has participant without Auth','J',
 $$ SELECT count(*) FROM public.participants p WHERE p.id=pg_temp.resource('primary organization team workflow',6)
    AND NOT EXISTS(SELECT 1 FROM public.user_accounts a WHERE a.person_id=p.person_id) $$,1);
SELECT pg_temp.expect_count('created family child has no Auth','J',
 $$ SELECT count(*) FROM public.people p WHERE p.id=pg_temp.resource('primary family workflow',3)
    AND NOT EXISTS(SELECT 1 FROM public.user_accounts a WHERE a.person_id=p.id) $$,1);
SELECT pg_temp.expect_count('sports flow has scoped coach role','P',
 $$ SELECT count(*) FROM public.role_assignments a JOIN public.roles r ON r.id=a.role_id
    WHERE a.id=pg_temp.resource('primary organization team workflow',11) AND r.key='head_coach'
      AND a.scope_type='team' AND a.scope_id=pg_temp.resource('primary organization team workflow',4)
      AND a.organization_id=pg_temp.resource('primary organization team workflow',0) $$,1);
SELECT pg_temp.expect_count('guardian explicitly verified with flags preserved','I',
 $$ SELECT count(*) FROM public.guardian_relationships g
    WHERE g.id=pg_temp.resource('primary family workflow',6) AND g.authority_status='active'
      AND g.verified_at IS NOT NULL AND g.can_manage_profile AND NOT g.can_manage_payments $$,1);
SELECT pg_temp.expect_count('every primary flow command has audit event','P',
 $$ SELECT count(*) FROM public.audit_events WHERE request_id IN
    (pg_temp.fixture_id('request-primary organization team workflow'),pg_temp.fixture_id('request-primary family workflow')) $$,20);

-- Positive scoped administration, then an independently assembled negative
-- matrix. Every call below executes as authenticated, without client table DML.
CREATE TEMP TABLE phase2b_cases (
 label text PRIMARY KEY, category text NOT NULL, actor text NOT NULL,
 operation text NOT NULL, input jsonb NOT NULL, allowed_states text[]
) ON COMMIT DROP;
INSERT INTO pg_temp.phase2b_cases VALUES
 ('org admin updates own organization','C','org-admin-a','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic A edited'),NULL),
 ('org admin activates module','C','org-admin-a','module.set',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'module_id',(SELECT id FROM public.modules WHERE key='sports'),'status','active'),NULL),
 ('org admin creates unit','C','org-admin-a','unit.create',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'unit_type','program','name','Synthetic new unit','slug','synthetic-new-unit'),NULL),
 ('org admin edits own season','C','org-admin-a','season.update',jsonb_build_object('id',pg_temp.fixture_id('season-a'),'name','Synthetic season edited'),NULL),
 ('org admin edits own participant foundation','C','org-admin-a','participant.update',jsonb_build_object('id',pg_temp.fixture_id('participant-dependent'),'organization_id',pg_temp.fixture_id('org-a'),'participant_type','athlete'),NULL),
 ('unit admin edits exact unit','E','unit-admin','unit.update',jsonb_build_object('id',pg_temp.fixture_id('unit-a'),'name','Synthetic exact unit edited'),NULL),
 ('unit admin creates exact unit team','E','unit-admin','team.create',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'parent_unit_id',pg_temp.fixture_id('unit-a'),'name','Synthetic unit-managed team','slug','synthetic-unit-managed','status','active'),NULL),
 ('unit admin edits exact unit season','E','unit-admin','season.update',jsonb_build_object('id',pg_temp.fixture_id('season-a'),'name','Synthetic exact unit season'),NULL),
 ('unit admin edits exact roster participant','E','unit-admin','participant.update',jsonb_build_object('id',pg_temp.fixture_id('participant-dependent'),'organization_id',pg_temp.fixture_id('org-a'),'participant_type','athlete'),NULL),
 ('unit admin creates participant for existing exact roster person','E','unit-admin','participant.create',jsonb_build_object('person_id',pg_temp.fixture_id('target-unit'),'organization_id',pg_temp.fixture_id('org-a'),'participant_type','athlete'),NULL),
 ('coach updates own exact team','F','coach','team.update',jsonb_build_object('id',pg_temp.fixture_id('team-a'),'short_name','Synthetic own team'),NULL),
 ('coach edits own roster metadata','F','coach','team_membership.update',jsonb_build_object('id',pg_temp.fixture_id('team-membership-dependent'),'jersey_number','42','position_label','Synthetic approved position'),NULL),
 ('verified profile guardian edits dependent name','I','guardian','person.update',jsonb_build_object('id',pg_temp.fixture_id('dependent'),'preferred_name','Synthetic approved nickname'),NULL),
 ('org admin assigns permitted exact team role','L','org-admin-a','role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('target-a'),'role_id',(SELECT id FROM public.roles WHERE key='assistant_coach'),'scope_type','team','scope_id',pg_temp.fixture_id('team-a'),'organization_id',pg_temp.fixture_id('org-a')),NULL),
 ('ordinary user cannot create organization','B','ordinary','organization.create','{"name":"Synthetic forbidden org","slug":"synthetic-forbidden"}',ARRAY['PT403']),
 ('ordinary metadata does not confer global people authority','B','ordinary','person.create','{"display_name":"Synthetic forged admin"}',ARRAY['PT403']),
 ('org A admin cannot mutate organization B','D','org-admin-a','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-b'),'name','Synthetic denied'),ARRAY['PT403']),
 ('org A admin cannot mutate unit B','D','org-admin-a','unit.update',jsonb_build_object('id',pg_temp.fixture_id('unit-b'),'name','Synthetic denied'),ARRAY['PT403']),
 ('org A admin cannot mutate season B','D','org-admin-a','season.update',jsonb_build_object('id',pg_temp.fixture_id('season-b'),'name','Synthetic denied'),ARRAY['PT403']),
 ('org A admin cannot mutate team B','D','org-admin-a','team.update',jsonb_build_object('id',pg_temp.fixture_id('team-b'),'name','Synthetic denied'),ARRAY['PT403']),
 ('org A admin cannot activate module B','D','org-admin-a','module.set',jsonb_build_object('organization_id',pg_temp.fixture_id('org-b'),'module_id',(SELECT id FROM public.modules WHERE key='sports'),'status','active'),ARRAY['PT403']),
 ('org A admin cannot edit B participant with B context','D','org-admin-a','participant.update',jsonb_build_object('id',pg_temp.fixture_id('participant-target-b'),'organization_id',pg_temp.fixture_id('org-b'),'status','inactive'),ARRAY['PT403']),
 ('org A context cannot claim B participant','R','org-admin-a','participant.update',jsonb_build_object('id',pg_temp.fixture_id('participant-target-b'),'organization_id',pg_temp.fixture_id('org-a'),'status','inactive'),ARRAY['PT403']),
 ('org A context cannot adopt unrelated B person','R','org-admin-a','organization_membership.add',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'person_id',pg_temp.fixture_id('target-b'),'membership_type','member'),ARRAY['PT403']),
 ('unit admin cannot mutate sibling unit','E','unit-admin','unit.update',jsonb_build_object('id',pg_temp.fixture_id('unit-a-sibling'),'name','Synthetic denied'),ARRAY['PT403']),
 ('unit admin cannot mutate descendant unit','E','unit-admin','unit.update',jsonb_build_object('id',pg_temp.fixture_id('unit-a-child'),'name','Synthetic denied'),ARRAY['PT403']),
 ('unit admin cannot mutate sibling team','E','unit-admin','team.update',jsonb_build_object('id',pg_temp.fixture_id('team-a-sibling'),'name','Synthetic denied'),ARRAY['PT403']),
 ('unit admin cannot mutate descendant team','E','unit-admin','team.update',jsonb_build_object('id',pg_temp.fixture_id('team-a-child'),'name','Synthetic denied'),ARRAY['PT403']),
 ('unit admin cannot mutate sibling roster participant','E','unit-admin','participant.update',jsonb_build_object('id',pg_temp.fixture_id('participant-target-sibling'),'organization_id',pg_temp.fixture_id('org-a'),'status','inactive'),ARRAY['PT403']),
 ('unit admin cannot mutate descendant roster participant','E','unit-admin','participant.update',jsonb_build_object('id',pg_temp.fixture_id('participant-target-child'),'organization_id',pg_temp.fixture_id('org-a'),'status','inactive'),ARRAY['PT403']),
 ('unit admin cannot create sibling team','E','unit-admin','team.create',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'parent_unit_id',pg_temp.fixture_id('unit-a-sibling'),'name','Synthetic denied team','slug','synthetic-denied-team'),ARRAY['PT403']),
 ('unit admin cannot create descendant team','E','unit-admin','team.create',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'parent_unit_id',pg_temp.fixture_id('unit-a-child'),'name','Synthetic denied team','slug','synthetic-denied-child'),ARRAY['PT403']),
 ('unit scope cannot manage whole organization','E','unit-admin','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT403']),
 ('unit scope cannot activate whole organization module','E','unit-admin','module.set',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'module_id',(SELECT id FROM public.modules WHERE key='fundraising'),'status','active'),ARRAY['PT403']),
 ('coach cannot manage sibling team','F','coach','team.update',jsonb_build_object('id',pg_temp.fixture_id('team-a-sibling'),'name','Synthetic denied'),ARRAY['PT403']),
 ('coach cannot manage other organization team','F','coach','team.update',jsonb_build_object('id',pg_temp.fixture_id('team-b'),'name','Synthetic denied'),ARRAY['PT403']),
 ('coach cannot create a new team','F','coach','team.create',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'parent_unit_id',pg_temp.fixture_id('unit-a'),'name','Synthetic denied team','slug','synthetic-coach-denied'),ARRAY['PT403']),
 ('coach cannot create a participant by read permission','F','coach','participant.create',jsonb_build_object('person_id',pg_temp.fixture_id('target-a'),'organization_id',pg_temp.fixture_id('org-a')),ARRAY['PT403']),
 ('household A member cannot mutate household B','G','household-only','household.update',jsonb_build_object('id',pg_temp.fixture_id('household-b'),'name','Synthetic denied'),ARRAY['PT403']),
 ('household member cannot infer family admin authority','G','household-only','household.update',jsonb_build_object('id',pg_temp.fixture_id('household-a'),'name','Synthetic denied'),ARRAY['PT403']),
 ('household membership does not confer guardian profile authority','H','household-only','person.update',jsonb_build_object('id',pg_temp.fixture_id('dependent'),'preferred_name','Synthetic denied'),ARRAY['PT403']),
 ('household member cannot self approve guardian','H','household-only','guardian.create',jsonb_build_object('guardian_person_id',pg_temp.fixture_id('household-only'),'dependent_person_id',pg_temp.fixture_id('dependent'),'authority_status','active','can_manage_profile',true),ARRAY['PT403']),
 ('guardian cannot edit unrelated child','I','guardian','person.update',jsonb_build_object('id',pg_temp.fixture_id('unrelated-dependent'),'preferred_name','Synthetic denied'),ARRAY['PT403']),
 ('guardian cannot change dependent lifecycle','I','guardian','person.update',jsonb_build_object('id',pg_temp.fixture_id('dependent'),'status','archived'),ARRAY['PT403']),
 ('guardian cannot expand own authority flags','I','guardian','guardian.update',jsonb_build_object('id',pg_temp.fixture_id('guardian-relationship'),'can_manage_payments',true),ARRAY['PT403']),
 ('guardian cannot create role authority','I','guardian','role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('dependent'),'role_id',(SELECT id FROM public.roles WHERE key='head_coach'),'scope_type','team','scope_id',pg_temp.fixture_id('team-a'),'organization_id',pg_temp.fixture_id('org-a')),ARRAY['PT403']),
 ('registration capability does not confer profile authority','I','wrong-flag','person.update',jsonb_build_object('id',pg_temp.fixture_id('dependent'),'preferred_name','Synthetic denied'),ARRAY['PT403']),
 ('org admin cannot access global household mutations','G','org-admin-a','household.update',jsonb_build_object('id',pg_temp.fixture_id('household-a'),'name','Synthetic denied'),ARRAY['PT403']),
 ('org admin cannot create global canonical person','B','org-admin-a','person.create','{"display_name":"Synthetic denied"}',ARRAY['PT403']),
 ('org admin cannot grant platform administrator','K','org-admin-a','role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('target-a'),'role_id',(SELECT id FROM public.roles WHERE key='platform_administrator'),'scope_type','platform'),ARRAY['PT403']),
 ('org admin cannot grant powers they lack','K','org-admin-a','role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('target-a'),'role_id',pg_temp.fixture_id('ungrantable-role'),'scope_type','team','scope_id',pg_temp.fixture_id('team-a'),'organization_id',pg_temp.fixture_id('org-a')),ARRAY['PT403']),
 ('org admin cannot grant role in other org','K','org-admin-a','role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('target-b'),'role_id',(SELECT id FROM public.roles WHERE key='head_coach'),'scope_type','team','scope_id',pg_temp.fixture_id('team-b'),'organization_id',pg_temp.fixture_id('org-b')),ARRAY['PT403']),
 ('unit admin lacks role assignment permission','L','unit-admin','role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('target-a'),'role_id',(SELECT id FROM public.roles WHERE key='head_coach'),'scope_type','team','scope_id',pg_temp.fixture_id('team-a'),'organization_id',pg_temp.fixture_id('org-a')),ARRAY['PT403']),
 ('coach lacks role assignment permission','L','coach','role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('coach'),'role_id',(SELECT id FROM public.roles WHERE key='team_administrator'),'scope_type','team','scope_id',pg_temp.fixture_id('team-a'),'organization_id',pg_temp.fixture_id('org-a')),ARRAY['PT403']),
 ('expired assignment cannot mutate','M','expired','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT403']),
 ('inactive assignment cannot mutate','M','inactive','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT403']),
 ('future assignment cannot mutate','M','future','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT403']),
 ('suspended canonical account cannot mutate','M','suspended-account','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT401','PT403']),
 ('suspended canonical person cannot mutate','M','suspended-person','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT401','PT403']),
 ('unconfirmed Auth cannot mutate','M','unconfirmed','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT401']),
 ('anonymous Auth cannot mutate','M','anonymous','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT401']),
 ('banned Auth cannot mutate','M','banned','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT401']),
 ('deleted Auth cannot mutate','M','deleted','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT401']),
 ('active Sports module does not confer team management','N','ordinary','team.update',jsonb_build_object('id',pg_temp.fixture_id('team-a'),'name','Synthetic denied'),ARRAY['PT403']),
 ('active module does not confer organization management','N','ordinary','organization.update',jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT403']),
 ('forged extra org field cannot repoint team update','R','coach','team.update',jsonb_build_object('id',pg_temp.fixture_id('team-b'),'organization_id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'),ARRAY['PT422']),
 ('forged team scope organization mismatch fails','R','org-admin-a','role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('target-a'),'role_id',(SELECT id FROM public.roles WHERE key='head_coach'),'scope_type','team','scope_id',pg_temp.fixture_id('team-b'),'organization_id',pg_temp.fixture_id('org-a')),ARRAY['PT403','PT422']),
 ('nonexistent team does not disclose SQL internals','R','platform','team.update',jsonb_build_object('id',pg_temp.fixture_id('missing-team'),'name','Synthetic denied'),ARRAY['PT403','PT422']),
 ('unapproved sensitive profile field rejected','I','guardian','person.update',jsonb_build_object('id',pg_temp.fixture_id('dependent'),'date_of_birth','2000-01-01'),ARRAY['PT422']),
 ('immutable season parent cannot be repointed','R','platform','season.update',jsonb_build_object('id',pg_temp.fixture_id('season-a'),'parent_unit_id',pg_temp.fixture_id('unit-b')),ARRAY['PT422']),
 ('immutable team parent cannot be repointed','R','platform','team.update',jsonb_build_object('id',pg_temp.fixture_id('team-a'),'parent_unit_id',pg_temp.fixture_id('unit-b')),ARRAY['PT422']),
 ('immutable team season cannot be repointed','R','platform','team.update',jsonb_build_object('id',pg_temp.fixture_id('team-a'),'season_id',pg_temp.fixture_id('season-b')),ARRAY['PT422']);

DO $test$
DECLARE test record;
BEGIN
  FOR test IN SELECT * FROM pg_temp.phase2b_cases ORDER BY allowed_states IS NOT NULL,label LOOP
    SET LOCAL ROLE authenticated;
    PERFORM pg_temp.act_as(test.actor);
    IF test.allowed_states IS NULL THEN
      PERFORM pg_temp.ok(test.label,test.category,jsonb_build_array(pg_temp.command(test.operation,test.input)));
    ELSE
      PERFORM pg_temp.deny(test.label,test.category,jsonb_build_array(pg_temp.command(test.operation,test.input)),test.allowed_states);
    END IF;
    RESET ROLE;
  END LOOP;
END;
$test$;

SELECT pg_temp.expect_count('denied cross tenant mutations preserve organization B','D',
 $$ SELECT count(*) FROM public.organizations WHERE id=pg_temp.fixture_id('org-b') AND name='Synthetic Phase 2B Organization B' $$,1);
SELECT pg_temp.expect_count('denied cross tenant mutations preserve team B','D',
 $$ SELECT count(*) FROM public.teams WHERE id=pg_temp.fixture_id('team-b') AND name='Synthetic team B' $$,1);
SELECT pg_temp.expect_count('guardian permitted approved profile field changed','I',
 $$ SELECT count(*) FROM public.people WHERE id=pg_temp.fixture_id('dependent') AND preferred_name='Synthetic approved nickname' AND status='active' $$,1);

-- Remaining CRUD/status branches, mapping/linking and adversarial validation
-- follow below. All fixtures and any mutation-generated resources roll back.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('platform');
SELECT pg_temp.ok('platform updates organization status','C',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.resource('platform creates organization'),'status','suspended'))));
SELECT pg_temp.ok('platform restores suspended organization','C',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.resource('platform creates organization'),'status','active'))));
SELECT pg_temp.ok('platform archives unit','C',jsonb_build_array(pg_temp.command('unit.update',
 jsonb_build_object('id',pg_temp.resource('org admin creates unit'),'status','archived'))));
SELECT pg_temp.ok('platform archives season','C',jsonb_build_array(pg_temp.command('season.update',
 jsonb_build_object('id',pg_temp.resource('primary organization team workflow',3),'status','archived'))));
SELECT pg_temp.ok('platform restores archived season','C',jsonb_build_array(pg_temp.command('season.update',
 jsonb_build_object('id',pg_temp.resource('primary organization team workflow',3),'status','active'))));
SELECT pg_temp.ok('platform archives team','C',jsonb_build_array(pg_temp.command('team.update',
 jsonb_build_object('id',pg_temp.resource('unit admin creates exact unit team'),'status','archived'))));
SELECT pg_temp.ok('platform updates no Auth person name','J',jsonb_build_array(pg_temp.command('person.update',
 jsonb_build_object('id',pg_temp.resource('primary family workflow',3),'first_name','Synthetic','last_name','Test Child'))));
SELECT pg_temp.ok('platform updates household foundation','G',jsonb_build_array(pg_temp.command('household.update',
 jsonb_build_object('id',pg_temp.resource('primary family workflow',1),'name','Synthetic Phase 2B Family Edited'))));
SELECT pg_temp.ok('platform updates participant status','J',jsonb_build_array(pg_temp.command('participant.update',
 jsonb_build_object('id',pg_temp.resource('primary family workflow',4),'status','inactive'))));
SELECT pg_temp.ok('platform restores participant','J',jsonb_build_array(pg_temp.command('participant.update',
 jsonb_build_object('id',pg_temp.resource('primary family workflow',4),'status','active'))));
SELECT pg_temp.ok('platform ends household membership','G',jsonb_build_array(pg_temp.command('household_membership.update',
 jsonb_build_object('id',pg_temp.resource('primary family workflow',5),'status','inactive','ends_at',now()+interval '1 hour'))));
SELECT pg_temp.ok('platform deactivates guardian','I',jsonb_build_array(pg_temp.command('guardian.update',
 jsonb_build_object('id',pg_temp.resource('primary family workflow',6),'authority_status','inactive','can_manage_profile',false))));
SELECT pg_temp.ok('platform adds explicit organization member','C',jsonb_build_array(pg_temp.command('organization_membership.add',
 jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'person_id',pg_temp.fixture_id('guardian'),'membership_type','staff'))));
SELECT pg_temp.ok('platform ends organization membership','C',jsonb_build_array(pg_temp.command('organization_membership.update',
 jsonb_build_object('id',pg_temp.resource('platform adds explicit organization member'),'status','inactive','ends_at',now()+interval '1 hour'))));
SELECT pg_temp.ok('platform ends team membership','F',jsonb_build_array(pg_temp.command('team_membership.update',
 jsonb_build_object('id',pg_temp.resource('primary organization team workflow',10),'status','inactive','ends_at',now()+interval '1 hour'))));
SELECT pg_temp.ok('platform ends scoped role','L',jsonb_build_array(pg_temp.command('role_assignment.update',
 jsonb_build_object('id',pg_temp.resource('primary organization team workflow',11),'status','inactive','ends_at',now()+interval '1 hour'))));
SELECT pg_temp.ok('platform deactivates module','N',jsonb_build_array(pg_temp.command('module.set',
 jsonb_build_object('organization_id',pg_temp.resource('primary organization team workflow',0),'module_id',(SELECT id FROM public.modules WHERE key='sports'),'status','inactive'))));

-- Managed linking uses explicit strong identity UUIDs. Shared email is never a
-- merging operation, and an existing Auth mapping cannot be repointed.
SELECT pg_temp.ok('platform explicitly links canonical identity','J',jsonb_build_array(pg_temp.command('account.link',
 jsonb_build_object('person_id',pg_temp.fixture_id('link-person'),'auth_user_id',pg_temp.fixture_id('auth-link-auth')))));
SELECT pg_temp.ok('same exact identity link is idempotent','J',jsonb_build_array(pg_temp.command('account.link',
 jsonb_build_object('person_id',pg_temp.fixture_id('link-person'),'auth_user_id',pg_temp.fixture_id('auth-link-auth')))));
SELECT pg_temp.deny('linked Auth cannot rebind canonical identity','J',jsonb_build_array(pg_temp.command('account.link',
 jsonb_build_object('person_id',pg_temp.fixture_id('other-link-person'),'auth_user_id',pg_temp.fixture_id('auth-link-auth')))),ARRAY['PT409']);
SELECT pg_temp.deny('active person cannot gain duplicate Auth link','J',jsonb_build_array(pg_temp.command('account.link',
 jsonb_build_object('person_id',pg_temp.fixture_id('link-person'),'auth_user_id',pg_temp.fixture_id('auth-unknown')))),ARRAY['PT409']);
SELECT pg_temp.deny('platform cannot link unconfirmed Auth','J',jsonb_build_array(pg_temp.command('account.link',
 jsonb_build_object('person_id',pg_temp.fixture_id('other-link-person'),'auth_user_id',pg_temp.fixture_id('auth-unconfirmed')))),ARRAY['PT403','PT422']);
SELECT pg_temp.deny('platform cannot link anonymous Auth','J',jsonb_build_array(pg_temp.command('account.link',
 jsonb_build_object('person_id',pg_temp.fixture_id('other-link-person'),'auth_user_id',pg_temp.fixture_id('auth-anonymous')))),ARRAY['PT403','PT422']);
SELECT pg_temp.deny('platform cannot link disabled Auth','J',jsonb_build_array(pg_temp.command('account.link',
 jsonb_build_object('person_id',pg_temp.fixture_id('other-link-person'),'auth_user_id',pg_temp.fixture_id('auth-banned')))),ARRAY['PT403','PT422']);
RESET ROLE;
SELECT pg_temp.expect_count('explicit strong identity linkage exists once','J',
 $$ SELECT count(*) FROM public.user_accounts WHERE auth_user_id=pg_temp.fixture_id('auth-link-auth') AND person_id=pg_temp.fixture_id('link-person') AND account_status='active' $$,1);
SELECT pg_temp.expect_count('failed rebind did not create other person account','J',
 $$ SELECT count(*) FROM public.user_accounts WHERE person_id=pg_temp.fixture_id('other-link-person') $$,0);

SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('unmapped');
SELECT pg_temp.ok('verified unmapped caller provisions canonical identity','J',jsonb_build_array(
 pg_temp.command('identity.provision_self','{"display_name":"Synthetic Phase 2B Self Provisioned"}')));
SELECT pg_temp.ok('existing self provisioning does not duplicate identity','J',jsonb_build_array(
 pg_temp.command('identity.provision_self','{"display_name":"Synthetic Phase 2B Self Provisioned"}')));
SELECT pg_temp.deny('self provisioning confers no administrative role','B',jsonb_build_array(
 pg_temp.command('organization.create','{"name":"Synthetic denied","slug":"synthetic-self-provision-denied"}')));
SELECT pg_temp.deny('self provisioning cannot choose existing canonical person','J',jsonb_build_array(
 pg_temp.command('identity.provision_self',jsonb_build_object('person_id',pg_temp.fixture_id('platform')))),ARRAY['PT422']);
SELECT pg_temp.act_as('ambiguous-auth');
SELECT pg_temp.deny('matching email requires explicit identity review','J',jsonb_build_array(
 pg_temp.command('identity.provision_self','{"display_name":"Synthetic ambiguous person"}')),ARRAY['PT409']);
SELECT pg_temp.act_as('ordinary');
SELECT pg_temp.deny('ordinary caller cannot link another Auth','B',jsonb_build_array(
 pg_temp.command('account.link',jsonb_build_object('person_id',pg_temp.fixture_id('other-link-person'),'auth_user_id',pg_temp.fixture_id('auth-unknown')))));
RESET ROLE;
SELECT pg_temp.expect_count('self provisioning creates one active Auth mapping','J',
 $$ SELECT count(*) FROM public.user_accounts WHERE auth_user_id=pg_temp.fixture_id('auth-unmapped') AND account_status='active' $$,1);
SELECT pg_temp.expect_count('self provisioning creates no role assignment','B',
 $$ SELECT count(*) FROM public.role_assignments WHERE person_id IN (SELECT person_id FROM public.user_accounts WHERE auth_user_id=pg_temp.fixture_id('auth-unmapped')) $$,0);
SELECT pg_temp.expect_count('ambiguous email never auto merges or links','J',
 $$ SELECT count(*) FROM public.user_accounts WHERE auth_user_id=pg_temp.fixture_id('auth-ambiguous-auth') $$,0);

-- Independent validation failures must be safe and leave no partial mutation.
TRUNCATE pg_temp.phase2b_cases;
INSERT INTO pg_temp.phase2b_cases VALUES
 ('duplicate participant rejected','J','platform','participant.create',jsonb_build_object('person_id',pg_temp.fixture_id('dependent')),ARRAY['PT409']),
 ('duplicate organization slug rejected','R','platform','organization.create','{"name":"Synthetic duplicate","slug":"synthetic-phase2b-org-a"}',ARRAY['PT409']),
 ('invalid slug rejected safely','R','platform','organization.create','{"name":"Synthetic bad slug","slug":"BAD SLUG"}',ARRAY['PT422']),
 ('unknown timezone rejected safely','R','platform','organization.create','{"name":"Synthetic bad timezone","slug":"synthetic-bad-timezone","timezone":"Not/A_Timezone"}',ARRAY['PT422']),
 ('invalid country rejected safely','R','platform','organization.create','{"name":"Synthetic bad country","slug":"synthetic-bad-country","country":"USA"}',ARRAY['PT422']),
 ('invalid currency rejected safely','R','platform','organization.create','{"name":"Synthetic bad currency","slug":"synthetic-bad-currency","default_currency":"dollars"}',ARRAY['PT422']),
 ('unit cannot self parent','R','platform','unit.update',jsonb_build_object('id',pg_temp.fixture_id('unit-a'),'parent_unit_id',pg_temp.fixture_id('unit-a')),ARRAY['PT422']),
 ('unit hierarchy cannot cycle','R','platform','unit.update',jsonb_build_object('id',pg_temp.fixture_id('unit-a'),'parent_unit_id',pg_temp.fixture_id('unit-a-child')),ARRAY['PT422']),
 ('unit cannot use cross tenant parent','R','platform','unit.create',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'parent_unit_id',pg_temp.fixture_id('unit-b'),'unit_type','sport','name','Synthetic forbidden parent','slug','synthetic-forbidden-parent'),ARRAY['PT403','PT422']),
 ('season date ordering enforced','R','platform','season.create',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'name','Synthetic inverted season','starts_on','2026-12-31','ends_on','2026-01-01'),ARRAY['PT422']),
 ('season cannot use cross tenant parent','R','platform','season.create',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'parent_unit_id',pg_temp.fixture_id('unit-b'),'name','Synthetic forbidden season'),ARRAY['PT403','PT422']),
 ('team cannot use cross tenant parent','R','platform','team.create',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'parent_unit_id',pg_temp.fixture_id('unit-b'),'name','Synthetic forbidden team','slug','synthetic-cross-parent'),ARRAY['PT403','PT422']),
 ('team cannot use cross tenant season','R','platform','team.create',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'parent_unit_id',pg_temp.fixture_id('unit-a'),'season_id',pg_temp.fixture_id('season-b'),'name','Synthetic forbidden team','slug','synthetic-cross-season'),ARRAY['PT403','PT422']),
 ('guardian cannot self reference','R','platform','guardian.create',jsonb_build_object('guardian_person_id',pg_temp.fixture_id('guardian'),'dependent_person_id',pg_temp.fixture_id('guardian')),ARRAY['PT422']),
  ('participant person mismatch rejected','R','platform','team_membership.add',jsonb_build_object('team_id',pg_temp.fixture_id('team-a'),'person_id',pg_temp.fixture_id('target-a'),'participant_id',pg_temp.fixture_id('participant-dependent'),'membership_type','athlete'),ARRAY['PT422']),
 ('athlete membership requires participant','R','platform','team_membership.add',jsonb_build_object('team_id',pg_temp.fixture_id('team-a'),'person_id',pg_temp.fixture_id('target-a'),'membership_type','athlete'),ARRAY['PT422']),
 ('membership invalid window rejected','R','platform','organization_membership.add',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'person_id',pg_temp.fixture_id('guardian'),'membership_type','test-window','starts_at',now(),'ends_at',now()),ARRAY['PT422']),
 ('role scope catalog pairing validated','R','platform','role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('target-a'),'role_id',(SELECT id FROM public.roles WHERE key='head_coach'),'scope_type','organization','scope_id',pg_temp.fixture_id('org-a'),'organization_id',pg_temp.fixture_id('org-a')),ARRAY['PT422']),
 ('platform scope cannot accept tenant id','R','platform','role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('target-a'),'role_id',(SELECT id FROM public.roles WHERE key='platform_administrator'),'scope_type','platform','organization_id',pg_temp.fixture_id('org-a')),ARRAY['PT422']),
 ('malformed UUID gives safe validation error','R','platform','team.update','{"id":"not-a-uuid","name":"Synthetic"}',ARRAY['PT422']),
 ('unknown operation rejected safely','R','platform','schema.drop','{}',ARRAY['PT422']),
 ('unknown privileged input rejected safely','R','platform','person.create','{"display_name":"Synthetic denied","is_admin":true}',ARRAY['PT422']);
DO $test$
DECLARE test record;
BEGIN
  FOR test IN SELECT * FROM pg_temp.phase2b_cases ORDER BY label LOOP
    SET LOCAL ROLE authenticated;
    PERFORM pg_temp.act_as(test.actor);
    PERFORM pg_temp.deny(test.label,test.category,jsonb_build_array(pg_temp.command(test.operation,test.input)),test.allowed_states);
    RESET ROLE;
  END LOOP;
END;
$test$;

-- Active history windows cannot overlap for the same actual relationship or
-- role. Different request IDs are not an excuse for duplicate membership.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('platform');
SELECT pg_temp.deny('overlapping organization membership rejected','R',jsonb_build_array(
 pg_temp.command('organization_membership.add',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'person_id',pg_temp.fixture_id('target-a'),'membership_type','member','starts_at',now()-interval '1 day'))),ARRAY['PT409']);
SELECT pg_temp.deny('overlapping team membership rejected','R',jsonb_build_array(
 pg_temp.command('team_membership.add',jsonb_build_object('team_id',pg_temp.fixture_id('team-a'),'person_id',pg_temp.fixture_id('coach'),'membership_type','coach','starts_at',now()-interval '1 day'))),ARRAY['PT409']);
SELECT pg_temp.deny('overlapping household membership rejected','R',jsonb_build_array(
 pg_temp.command('household_membership.add',jsonb_build_object('household_id',pg_temp.fixture_id('household-a'),'person_id',pg_temp.fixture_id('dependent'),'relationship_type','child','starts_at',now()-interval '1 day'))),ARRAY['PT409']);
SELECT pg_temp.deny('overlapping scoped role rejected','R',jsonb_build_array(
 pg_temp.command('role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('coach'),'role_id',(SELECT id FROM public.roles WHERE key='head_coach'),'scope_type','team','scope_id',pg_temp.fixture_id('team-a'),'organization_id',pg_temp.fixture_id('org-a'),'starts_at',now()-interval '1 day'))),ARRAY['PT409']);
SELECT pg_temp.deny('overlapping guardian relationship rejected','R',jsonb_build_array(
 pg_temp.command('guardian.create',jsonb_build_object('guardian_person_id',pg_temp.fixture_id('guardian'),'dependent_person_id',pg_temp.fixture_id('dependent'),'starts_at',now()-interval '1 day','authority_status','active'))),ARRAY['PT409']);

SELECT pg_temp.ok('historical ended membership remains separate','R',jsonb_build_array(
 pg_temp.command('organization_membership.add',jsonb_build_object('organization_id',pg_temp.fixture_id('org-a'),'person_id',pg_temp.fixture_id('target-a'),'membership_type','member','starts_at',now()-interval '10 days','ends_at',now()-interval '3 days'))));
SELECT pg_temp.ok('pending overlapping guardian can await review','I',jsonb_build_array(
 pg_temp.command('guardian.create',jsonb_build_object('guardian_person_id',pg_temp.fixture_id('guardian'),'dependent_person_id',pg_temp.fixture_id('dependent'),'can_manage_profile',true))));
SELECT pg_temp.deny('verification cannot activate overlapping guardian authority','R',jsonb_build_array(
 pg_temp.command('guardian.verify',jsonb_build_object('id',pg_temp.resource('pending overlapping guardian can await review')))),ARRAY['PT409']);
SELECT pg_temp.ok('active unverified guardian stores no effective authority','I',jsonb_build_array(
 pg_temp.command('guardian.create',jsonb_build_object('guardian_person_id',pg_temp.fixture_id('guardian'),'dependent_person_id',pg_temp.fixture_id('unrelated-dependent'),'authority_status','active','can_manage_profile',true))));
SELECT pg_temp.act_as('guardian');
SELECT pg_temp.expect_true('active guardian status alone does not replace verification','I',
 NOT boss_private.can_manage_dependent_profile(pg_temp.fixture_id('unrelated-dependent')));
SELECT pg_temp.deny('unverified stored guardian flags do not grant profile authority','I',jsonb_build_array(
 pg_temp.command('person.update',jsonb_build_object('id',pg_temp.fixture_id('unrelated-dependent'),'preferred_name','Synthetic denied'))));
SELECT pg_temp.act_as('platform');
SELECT pg_temp.ok('platform creates pending self guardian for independent review','I',jsonb_build_array(
 pg_temp.command('guardian.create',jsonb_build_object('guardian_person_id',pg_temp.fixture_id('platform'),'dependent_person_id',pg_temp.fixture_id('unrelated-dependent'),'can_manage_profile',true))));
SELECT pg_temp.deny('platform role does not allow self verification','I',jsonb_build_array(
 pg_temp.command('guardian.verify',jsonb_build_object('id',pg_temp.resource('platform creates pending self guardian for independent review')))),ARRAY['PT403']);
SELECT pg_temp.deny('overlapping primary contacts rejected','R',jsonb_build_array(
 pg_temp.command('household_membership.add',jsonb_build_object('household_id',pg_temp.resource('primary family workflow',1),
 'person_id',pg_temp.fixture_id('guardian'),'relationship_type','adult','is_primary_contact',true))),ARRAY['PT409']);
SELECT pg_temp.deny('extending historical membership into active period rejected','R',jsonb_build_array(
 pg_temp.command('organization_membership.update',jsonb_build_object('id',pg_temp.resource('historical ended membership remains separate'),'ends_at',now()+interval '1 day'))),ARRAY['PT409']);
SELECT pg_temp.ok('inactive duplicate membership preserves history','R',jsonb_build_array(
 pg_temp.command('team_membership.add',jsonb_build_object('team_id',pg_temp.fixture_id('team-a'),'person_id',pg_temp.fixture_id('coach'),'membership_type','coach','status','inactive'))));
SELECT pg_temp.deny('reactivating overlapping membership rejected','R',jsonb_build_array(
 pg_temp.command('team_membership.update',jsonb_build_object('id',pg_temp.resource('inactive duplicate membership preserves history'),'status','active'))),ARRAY['PT409']);
SELECT pg_temp.ok('inactive duplicate role preserves history','R',jsonb_build_array(
 pg_temp.command('role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('coach'),'role_id',(SELECT id FROM public.roles WHERE key='head_coach'),
 'scope_type','team','scope_id',pg_temp.fixture_id('team-a'),'organization_id',pg_temp.fixture_id('org-a'),'status','inactive'))));
SELECT pg_temp.deny('reactivating overlapping role rejected','R',jsonb_build_array(
 pg_temp.command('role_assignment.update',jsonb_build_object('id',pg_temp.resource('inactive duplicate role preserves history'),'status','active'))),ARRAY['PT409']);

-- Ending explicit authority must remain possible after an identity becomes
-- inactive; cleanup cannot require restoring private access first.
SELECT pg_temp.ok('inactive identity cleanup setup','M',jsonb_build_array(
 pg_temp.command('person.create','{"display_name":"Synthetic Phase 2B Cleanup Person"}','cleanup_person'),
 pg_temp.command('organization_membership.add',jsonb_build_object('person_id',jsonb_build_object('$ref','cleanup_person'),'organization_id',pg_temp.fixture_id('org-a'),'membership_type','staff'),'org_member'),
 pg_temp.command('team_membership.add',jsonb_build_object('person_id',jsonb_build_object('$ref','cleanup_person'),'team_id',pg_temp.fixture_id('team-a'),'membership_type','staff'),'team_member'),
 pg_temp.command('household_membership.add',jsonb_build_object('person_id',jsonb_build_object('$ref','cleanup_person'),'household_id',pg_temp.fixture_id('household-a'),'relationship_type','adult'),'family_member'),
 pg_temp.command('role_assignment.add',jsonb_build_object('person_id',jsonb_build_object('$ref','cleanup_person'),'role_id',(SELECT id FROM public.roles WHERE key='team_staff'),
 'scope_type','team','scope_id',pg_temp.fixture_id('team-a'),'organization_id',pg_temp.fixture_id('org-a')),'team_role'),
 pg_temp.command('guardian.create',jsonb_build_object('guardian_person_id',jsonb_build_object('$ref','cleanup_person'),'dependent_person_id',pg_temp.fixture_id('unrelated-dependent'),'can_manage_profile',true),'guardian'),
 pg_temp.command('guardian.verify','{"id":{"$ref":"guardian"}}'),
 pg_temp.command('participant.create','{"person_id":{"$ref":"cleanup_person"},"participant_type":"participant"}'),
 pg_temp.command('person.update','{"id":{"$ref":"cleanup_person"},"status":"inactive"}')
));
SELECT pg_temp.ok('inactive identity relationships can end','M',jsonb_build_array(
 pg_temp.command('organization_membership.update',jsonb_build_object('id',pg_temp.resource('inactive identity cleanup setup',1),'status','inactive')),
 pg_temp.command('team_membership.update',jsonb_build_object('id',pg_temp.resource('inactive identity cleanup setup',2),'status','inactive')),
 pg_temp.command('household_membership.update',jsonb_build_object('id',pg_temp.resource('inactive identity cleanup setup',3),'status','inactive')),
 pg_temp.command('role_assignment.update',jsonb_build_object('id',pg_temp.resource('inactive identity cleanup setup',4),'status','inactive')),
 pg_temp.command('guardian.update',jsonb_build_object('id',pg_temp.resource('inactive identity cleanup setup',5),'authority_status','inactive','can_manage_profile',false))
));
SELECT pg_temp.deny('inactive identity cannot be restored into membership','M',jsonb_build_array(
 pg_temp.command('team_membership.update',jsonb_build_object('id',pg_temp.resource('inactive identity cleanup setup',2),'status','active'))),ARRAY['PT403']);
SELECT pg_temp.deny('inactive canonical person requires profile restoration before participant mutation','M',jsonb_build_array(
 pg_temp.command('participant.update',jsonb_build_object('id',pg_temp.resource('inactive identity cleanup setup',7),'participant_type','athlete'))),ARRAY['PT403']);
RESET ROLE;
SELECT pg_temp.expect_count('historical membership preserved beside current window','R',
 $$ SELECT count(*) FROM public.organization_memberships WHERE organization_id=pg_temp.fixture_id('org-a') AND person_id=pg_temp.fixture_id('target-a') AND membership_type='member' $$,2);

-- Audits carry authenticated actor/context and safe field names, not submitted
-- person names, contact facts, credentials or generic before/after row copies.
SELECT pg_temp.expect_count('all successful tested commands have audit coverage','P',
 $$ SELECT count(*) FROM pg_temp.phase2b_results r CROSS JOIN LATERAL jsonb_array_elements(r.result->'results') output
    WHERE r.label NOT IN('same exact identity link is idempotent','existing self provisioning does not duplicate identity') AND NOT EXISTS(SELECT 1 FROM public.audit_events a
      WHERE a.request_id=(r.result->>'request_id')::uuid AND a.resource_id=(output->>'resource_id')::uuid) $$,0);
SELECT pg_temp.expect_count('platform request audit binds canonical actor and Auth provenance','P',
 $$ SELECT count(*) FROM public.audit_events a WHERE a.request_id=pg_temp.fixture_id('request-platform creates organization')
    AND a.actor_person_id=pg_temp.fixture_id('platform') AND a.actor_auth_user_id=pg_temp.fixture_id('auth-platform')
    AND a.action='organization.create' AND a.resource_type='organization'
    AND a.organization_id=pg_temp.resource('platform creates organization')
    AND a.scope_type='organization' AND a.scope_id=a.organization_id $$,1);
SELECT pg_temp.expect_count('audit payload excludes copied profile/name/contact values','P',
 $$ SELECT count(*) FROM public.audit_events a
    WHERE coalesce(a.before_data::text,'') || coalesce(a.after_data::text,'') ~* '(Synthetic|example.invalid|password|token|date_of_birth|primary_email|primary_phone)' $$,0);
SELECT pg_temp.expect_count('denied tested requests have no audit side effect','P',
 $$ SELECT count(*) FROM public.audit_events WHERE request_id IN
   (SELECT pg_temp.fixture_id('request-' || assertion) FROM pg_temp.phase2b_assertions
    WHERE assertion NOT LIKE '%: safe error' AND assertion NOT IN(SELECT label FROM pg_temp.phase2b_results)) $$,0);

-- A failed command anywhere rolls back the entire request, its receipt and its
-- earlier audit inserts. The test helpers catch only the safe outward error.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('platform');
SELECT pg_temp.deny('atomic person participant family rollback','Q',jsonb_build_array(
 pg_temp.command('person.create','{"display_name":"Synthetic Phase 2B Rollback Child"}','child'),
 pg_temp.command('participant.create','{"person_id":{"$ref":"child"},"participant_type":"athlete"}','participant'),
 pg_temp.command('household_membership.add',jsonb_build_object('household_id',pg_temp.fixture_id('missing-household'),'person_id',jsonb_build_object('$ref','child'),'relationship_type','child'))
),ARRAY['PT403','PT422']);
SELECT pg_temp.deny('atomic org membership role rollback','Q',jsonb_build_array(
 pg_temp.command('organization.create','{"name":"Synthetic Phase 2B Rollback Org","slug":"synthetic-phase2b-rollback-org"}','org'),
 pg_temp.command('organization_membership.add',jsonb_build_object('organization_id',jsonb_build_object('$ref','org'),'person_id',pg_temp.fixture_id('target-a'),'membership_type','member')),
 pg_temp.command('role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('target-a'),'role_id',(SELECT id FROM public.roles WHERE key='head_coach'),'scope_type','organization','scope_id',jsonb_build_object('$ref','org'),'organization_id',jsonb_build_object('$ref','org')))
),ARRAY['PT422']);
SELECT pg_temp.act_as('coach');
SELECT pg_temp.deny('atomic membership and unapproved role rollback','Q',jsonb_build_array(
 pg_temp.command('team_membership.add',jsonb_build_object('team_id',pg_temp.fixture_id('team-a'),'person_id',pg_temp.fixture_id('coach'),'membership_type','synthetic-rollback-staff')),
 pg_temp.command('role_assignment.add',jsonb_build_object('person_id',pg_temp.fixture_id('coach'),'role_id',(SELECT id FROM public.roles WHERE key='team_administrator'),'scope_type','team','scope_id',pg_temp.fixture_id('team-a'),'organization_id',pg_temp.fixture_id('org-a')))
),ARRAY['PT403']);
SELECT pg_temp.act_as('platform');
SELECT pg_temp.deny('forward resource reference rejected','Q',jsonb_build_array(
 pg_temp.command('participant.create','{"person_id":{"$ref":"later_person"}}'),
 pg_temp.command('person.create','{"display_name":"Synthetic forward ref"}','later_person')
),ARRAY['PT422']);
SELECT pg_temp.deny('unknown resource reference rejected','Q',jsonb_build_array(
 pg_temp.command('participant.create','{"person_id":{"$ref":"not_created"}}')
),ARRAY['PT422']);
SELECT pg_temp.deny('duplicate batch reference rejected','Q',jsonb_build_array(
 pg_temp.command('person.create','{"display_name":"Synthetic duplicate ref 1"}','same'),
 pg_temp.command('person.create','{"display_name":"Synthetic duplicate ref 2"}','same')
),ARRAY['PT422']);
SELECT pg_temp.deny('resource reference type mismatch rejected','Q',jsonb_build_array(
 pg_temp.command('household.create','{"name":"Synthetic wrong ref type"}','family'),
 pg_temp.command('participant.create','{"person_id":{"$ref":"family"}}')
),ARRAY['PT422']);
SELECT pg_temp.deny('too many commands rejected','Q',
 (SELECT jsonb_agg(pg_temp.command('person.create','{"display_name":"Synthetic too many"}')) FROM generate_series(1,13)),ARRAY['PT422']);
SELECT pg_temp.deny('empty transaction rejected','Q','[]',ARRAY['PT422']);
SELECT pg_temp.deny('object instead of command array rejected','Q','{}',ARRAY['PT422']);
SELECT pg_temp.deny('unknown command envelope key rejected','Q',
 '[{"operation":"person.create","input":{"display_name":"Synthetic unknown envelope"},"actor":"platform"}]',ARRAY['PT422']);
RESET ROLE;
SELECT pg_temp.expect_count('failed family batch leaves no person','Q',
 $$ SELECT count(*) FROM public.people WHERE display_name='Synthetic Phase 2B Rollback Child' $$,0);
SELECT pg_temp.expect_count('failed org batch leaves no organization','Q',
 $$ SELECT count(*) FROM public.organizations WHERE slug='synthetic-phase2b-rollback-org' $$,0);
SELECT pg_temp.expect_count('failed team batch leaves no membership','Q',
 $$ SELECT count(*) FROM public.team_memberships WHERE membership_type='synthetic-rollback-staff' $$,0);
SELECT pg_temp.expect_count('failed reference batches leave no resources','Q',
 $$ SELECT (SELECT count(*) FROM public.people WHERE display_name IN('Synthetic duplicate ref 1','Synthetic duplicate ref 2','Synthetic forward ref'))
  +(SELECT count(*) FROM public.households WHERE name='Synthetic wrong ref type') $$,0);
SELECT pg_temp.expect_count('failed transactions leave no audit inserts','Q',
 $$ SELECT count(*) FROM public.audit_events WHERE request_id IN (
  pg_temp.fixture_id('request-atomic person participant family rollback'),pg_temp.fixture_id('request-atomic org membership role rollback'),
  pg_temp.fixture_id('request-atomic membership and unapproved role rollback'),pg_temp.fixture_id('request-duplicate batch reference rejected'),
  pg_temp.fixture_id('request-resource reference type mismatch rejected')) $$,0);
SELECT pg_temp.expect_count('failed transactions leave no receipts','Q',
 $$ SELECT count(*) FROM boss_private.admin_operation_receipts WHERE request_id IN (
  pg_temp.fixture_id('request-atomic person participant family rollback'),pg_temp.fixture_id('request-atomic org membership role rollback'),
  pg_temp.fixture_id('request-atomic membership and unapproved role rollback')) $$,0);

-- Idempotency returns the existing result exactly once but still reauthorizes
-- current access. A receipt is not a permanent authority grant.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('org-admin-a');
SELECT pg_temp.ok('idempotent scoped update','C',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.fixture_id('org-a'),'legal_name','Synthetic idempotent name'))));
SELECT pg_temp.expect_true('same request returns identical result','P',
 public.boss_admin_mutate(jsonb_build_array(pg_temp.command('organization.update',
  jsonb_build_object('id',pg_temp.fixture_id('org-a'),'legal_name','Synthetic idempotent name'))),
  pg_temp.fixture_id('request-idempotent scoped update'))=(SELECT result FROM pg_temp.phase2b_results WHERE label='idempotent scoped update'));
SELECT pg_temp.deny('request id cannot accept altered content','Q',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.fixture_id('org-a'),'legal_name','Synthetic changed idempotent name'))),ARRAY['PT409'],'idempotent scoped update');
RESET ROLE;
SELECT pg_temp.expect_count('idempotent request emits exactly one audit','P',
 $$ SELECT count(*) FROM public.audit_events WHERE request_id=pg_temp.fixture_id('request-idempotent scoped update') $$,1);
UPDATE public.role_assignments SET status='inactive' WHERE id=pg_temp.fixture_id('assignment-org-admin-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('org-admin-a');
SELECT pg_temp.deny('revoked permission invalidates request replay','M',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.fixture_id('org-a'),'legal_name','Synthetic idempotent name'))),ARRAY['PT403'],'idempotent scoped update');
RESET ROLE;
UPDATE public.role_assignments SET status='active' WHERE id=pg_temp.fixture_id('assignment-org-admin-a');

-- Signed session ownership/expiry is checked on every sensitive RPC, including
-- retries. Claim forgery here emulates invalid server-signed-context inputs;
-- real JWT signature and cookie tests belong to hosted acceptance.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('platform','session-ordinary');
SELECT pg_temp.deny('session must belong to authenticated caller','M',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'))),ARRAY['PT401']);
SELECT pg_temp.act_as('platform','session-expired-platform');
SELECT pg_temp.deny('expired live session cannot mutate','M',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'))),ARRAY['PT401']);
SELECT pg_temp.act_as('platform','missing-session');
SELECT pg_temp.deny('nonexistent live session cannot mutate','M',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'))),ARRAY['PT401']);
SELECT pg_temp.act_as('platform');
SELECT set_config('request.jwt.claims',(current_setting('request.jwt.claims')::jsonb-'session_id')::text,true);
SELECT pg_temp.deny('missing signed session claim cannot mutate','M',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'))),ARRAY['PT401']);
SELECT pg_temp.act_as('platform');
SELECT set_config('request.jwt.claims',jsonb_set(current_setting('request.jwt.claims')::jsonb,'{session_id}','"not-a-session-uuid"')::text,true);
SELECT pg_temp.deny('malformed signed session claim fails safely','M',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'))),ARRAY['PT401']);
RESET ROLE;
DELETE FROM auth.sessions WHERE id=pg_temp.fixture_id('session-platform');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('platform');
SELECT pg_temp.deny('revoked session denies stale authenticated token','M',jsonb_build_array(pg_temp.command('organization.update',
 jsonb_build_object('id',pg_temp.fixture_id('org-a'),'name','Synthetic denied'))),ARRAY['PT401']);
SELECT pg_temp.deny('revoked session denies previous request replay','M',jsonb_build_array(pg_temp.command('organization.create',
 jsonb_build_object('name','Synthetic Phase 2B Created Organization','legal_name','Synthetic Test Only','slug','synthetic-phase2b-created',
  'organization_type','test','timezone','America/Chicago','country','US','default_currency','USD'))),ARRAY['PT401'],'platform creates organization');
RESET ROLE;
INSERT INTO auth.sessions(id,user_id) VALUES(pg_temp.fixture_id('session-platform'),pg_temp.fixture_id('auth-platform'));

-- Read projections use the same live-session boundary and retain the existing
-- table RLS. Their public JSON includes only approved names/context/capabilities.
CREATE TEMP TABLE phase2b_reads(label text PRIMARY KEY,result jsonb NOT NULL) ON COMMIT DROP;
GRANT SELECT,INSERT ON pg_temp.phase2b_reads TO authenticated,anon;
CREATE FUNCTION pg_temp.read_ok(label text,view_name text,org_id uuid DEFAULT NULL,query text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE result jsonb;
BEGIN
 result:=public.boss_admin_read(view_name,org_id,query);
 PERFORM pg_temp.expect_true(label,'READ',
  result->>'provisioned'='true' AND result->'person'->>'id'=boss_private.current_person_id()::text
  AND jsonb_typeof(result->'operations')='array' AND jsonb_typeof(result->'navigation')='array'
  AND jsonb_typeof(result->'organizations')='array' AND jsonb_typeof(result->'records')='object'
  AND result->>'organizationId' IS NOT DISTINCT FROM org_id::text);
 INSERT INTO pg_temp.phase2b_reads VALUES(label,result);
 RETURN result;
END;
$$;
CREATE FUNCTION pg_temp.read_deny(label text,view_name text,org_id uuid DEFAULT NULL,query text DEFAULT NULL,
 allowed_states text[] DEFAULT ARRAY['PT403']) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE denied boolean:=false;safe_error boolean:=false;
BEGIN
 BEGIN PERFORM public.boss_admin_read(view_name,org_id,query);
 EXCEPTION WHEN OTHERS THEN
  IF SQLSTATE=ANY(allowed_states) THEN
   denied:=true;safe_error:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|SQL|stack|password|token|SELECT|INSERT|UPDATE|DELETE)';
  ELSE RAISE EXCEPTION 'FAIL [READ] %: unexpected SQLSTATE % (%)',label,SQLSTATE,SQLERRM;
  END IF;
 END;
 PERFORM pg_temp.expect_true(label,'READ',denied);
 PERFORM pg_temp.expect_true(label || ': safe error','READ',safe_error);
END;
$$;
REVOKE ALL ON FUNCTION pg_temp.read_ok(text,text,uuid,text),pg_temp.read_deny(text,text,uuid,text,text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.read_ok(text,text,uuid,text),pg_temp.read_deny(text,text,uuid,text,text[]) TO authenticated,anon;

-- A unit-only actor has no organization membership; siblings/descendants are
-- therefore outside both read and mutation scope. The other unit fixture has a
-- legitimate org membership, which permits hierarchy reads but not broad edits.
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 (pg_temp.fixture_id('auth-unit-only'),'unit-only@phase2b.example.invalid',now()-interval '1 day');
INSERT INTO auth.sessions(id,user_id) VALUES(pg_temp.fixture_id('session-unit-only'),pg_temp.fixture_id('auth-unit-only'));
INSERT INTO public.people(id,display_name) VALUES(pg_temp.fixture_id('unit-only'),'Synthetic Phase 2B Unit Only');
INSERT INTO public.user_accounts(auth_user_id,person_id,account_status) VALUES(pg_temp.fixture_id('auth-unit-only'),pg_temp.fixture_id('unit-only'),'active');
INSERT INTO public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at)
 SELECT pg_temp.fixture_id('unit-only'),id,'organization_unit',pg_temp.fixture_id('unit-a'),pg_temp.fixture_id('org-a'),now()-interval '1 day'
 FROM public.roles WHERE key='program_administrator';
-- Sensitive fields are fixture-only bait. None may appear in any projection.
UPDATE public.people SET date_of_birth='2000-01-01',primary_email='private-synthetic@phase2b.example.invalid',primary_phone='private-synthetic-phone'
WHERE id=pg_temp.fixture_id('target-a');

SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('platform');
DO $test$
DECLARE view_name text;
BEGIN
 FOREACH view_name IN ARRAY ARRAY['home','organizations','people','families','teams','access','audit','account'] LOOP
  PERFORM pg_temp.read_ok('platform read view: ' || view_name,view_name,pg_temp.fixture_id('org-a'));
 END LOOP;
END;
$test$;
SELECT pg_temp.expect_true('organization view includes all module classifications','READ',
 (SELECT jsonb_array_length(result->'records'->'modules')=(SELECT count(*) FROM public.modules) AND NOT EXISTS(
  SELECT 1 FROM jsonb_array_elements(result->'records'->'modules') m
  WHERE m->'fields'->>'implementation_status' IS DISTINCT FROM CASE m->'fields'->>'module_key' WHEN 'calendar' THEN 'Implemented: Events and calendar' WHEN 'registration' THEN 'Implemented: Registration, forms and private documents' WHEN 'messaging' THEN 'Implemented: Communications and notifications' WHEN 'volunteers' THEN 'Implemented: Volunteer coordination' WHEN 'fundraising' THEN 'Implemented: Fundraising core' WHEN 'money_board' THEN 'Implemented: Digital Money Board' WHEN 'boss_bucks' THEN 'Implemented: Family wallet, restricted ledger and charge payments' ELSE 'Future / not implemented' END
   OR m->'fields'->>'activation_status' NOT IN('active','inactive'))
 FROM pg_temp.phase2b_reads WHERE label='platform read view: organizations'));
SELECT pg_temp.expect_true('selected org projects teams only from its real tenant','READ',
 (SELECT jsonb_array_length(result->'records'->'teams')>0 AND NOT EXISTS(
  SELECT 1 FROM jsonb_array_elements(result->'records'->'teams') t WHERE t->'fields'->>'organization_id'<>pg_temp.fixture_id('org-a')::text)
 FROM pg_temp.phase2b_reads WHERE label='platform read view: teams'));
SELECT pg_temp.expect_true('audit view exposes useful action resource time context','READ',
 (SELECT jsonb_array_length(result->'records'->'audit')>0 AND NOT EXISTS(
  SELECT 1 FROM jsonb_array_elements(result->'records'->'audit') a
  WHERE NOT(a->'fields' ?& ARRAY['action','resource_type','resource_id','occurred_at','organization_id','scope_type','actor']))
 FROM pg_temp.phase2b_reads WHERE label='platform read view: audit'));
SELECT pg_temp.expect_true('audit view excludes raw payload and Auth provenance','READ',
 (SELECT NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'audit') a
  WHERE a->'fields' ?| ARRAY['before_data','after_data','actor_auth_user_id','actor_person_id','request_id','session_id'])
 FROM pg_temp.phase2b_reads WHERE label='platform read view: audit'));
SELECT pg_temp.expect_true('self guardian verification is hidden even for platform administrator','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'guardians') g
  WHERE g->>'id'=pg_temp.resource('platform creates pending self guardian for independent review')::text
   AND g->'operations' ? 'guardian.update' AND NOT g->'operations' ? 'guardian.verify')
 FROM pg_temp.phase2b_reads WHERE label='platform read view: families'));
SELECT pg_temp.expect_true('global person projection never includes sensitive person columns','READ',
 (SELECT jsonb_array_length(result->'records'->'people')>0 AND NOT EXISTS(
  SELECT 1 FROM jsonb_array_elements(result->'records'->'people') p
  WHERE p->'fields' ?| ARRAY['date_of_birth','primary_email','primary_phone','auth_user_id','session_id','raw_user_meta_data'])
 FROM pg_temp.phase2b_reads WHERE label='platform read view: people'));
SELECT pg_temp.expect_true('platform recovery advertises archived unit update','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'units') u
  WHERE u->>'id'=pg_temp.resource('org admin creates unit')::text AND u->>'status'='archived' AND u->'operations' ? 'unit.update')
 FROM pg_temp.phase2b_reads WHERE label='platform read view: organizations'));
SELECT pg_temp.expect_true('platform recovery advertises archived team update','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'teams') t
  WHERE t->>'id'=pg_temp.resource('unit admin creates exact unit team')::text AND t->>'status'='archived' AND t->'operations' ? 'team.update')
 FROM pg_temp.phase2b_reads WHERE label='platform read view: teams'));
SELECT pg_temp.expect_true('inactive person advertises profile restoration but no participant mutation','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'people') p
  WHERE p->>'id'=pg_temp.resource('inactive identity cleanup setup',0)::text AND p->>'status'='inactive'
   AND p->'operations' ? 'person.update' AND NOT p->'operations' ? 'participant.create')
  AND EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'participants') p
   WHERE p->>'id'=pg_temp.resource('inactive identity cleanup setup',7)::text AND NOT p->'operations' ? 'participant.update')
 FROM pg_temp.phase2b_reads WHERE label='platform read view: people'));
SELECT pg_temp.read_deny('unknown read view rejected safely','schema',NULL,NULL,ARRAY['PT422']);
SELECT pg_temp.read_deny('oversized read query rejected safely','people',NULL,repeat('x',101),ARRAY['PT422']);
SELECT pg_temp.read_deny('control characters in read query rejected safely','people',NULL,E'bad\nquery',ARRAY['PT422']);

SELECT pg_temp.act_as('org-admin-a');
SELECT pg_temp.read_ok('org staff contextual people names','people',pg_temp.fixture_id('org-a'));
SELECT pg_temp.read_ok('org staff sees archived hierarchy without false edit capability','organizations',pg_temp.fixture_id('org-a'));
SELECT pg_temp.expect_true('archived unit does not advertise scoped edits requiring platform recovery','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'units') u
  WHERE u->>'id'=pg_temp.resource('org admin creates unit')::text AND u->>'status'='archived'
   AND NOT u->'operations' ?| ARRAY['unit.update','season.create','team.create'])
 FROM pg_temp.phase2b_reads WHERE label='org staff sees archived hierarchy without false edit capability'));
SELECT pg_temp.expect_true('archived team remains outside organization scoped table visibility','READ',
 (SELECT NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'teams') t
  WHERE t->>'id'=pg_temp.resource('unit admin creates exact unit team')::text)
 FROM pg_temp.phase2b_reads WHERE label='org staff sees archived hierarchy without false edit capability'));
SELECT pg_temp.expect_true('organization staff discovers actual own member name','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'people') p
  WHERE p->>'id'=pg_temp.fixture_id('target-a')::text AND p->>'label'='Synthetic Phase 2B target-a')
 FROM pg_temp.phase2b_reads WHERE label='org staff contextual people names'));
SELECT pg_temp.expect_true('organization staff cannot discover unrelated other org person','READ',
 (SELECT NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'people') p WHERE p->>'id'=pg_temp.fixture_id('target-b')::text)
 FROM pg_temp.phase2b_reads WHERE label='org staff contextual people names'));
SELECT pg_temp.expect_true('contextual names do not open non-sensitive profile mutation powers','READ',
 (SELECT NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'people') p
  WHERE p->>'id'=pg_temp.fixture_id('target-a')::text AND p->'operations' ? 'person.update')
 FROM pg_temp.phase2b_reads WHERE label='org staff contextual people names'));
SELECT pg_temp.expect_count('context projection does not grant underlying sensitive person row','READ',
 $$ SELECT count(*) FROM public.people WHERE id=pg_temp.fixture_id('target-a') $$,0);
SELECT pg_temp.read_deny('org staff global people search denied','people',NULL,'Synthetic');
SELECT pg_temp.read_deny('org staff forged foreign organization context denied','people',pg_temp.fixture_id('org-b'));
SELECT pg_temp.read_deny('forged foreign team view context denied','teams',pg_temp.fixture_id('org-b'));

SELECT pg_temp.act_as('ordinary');
SELECT pg_temp.read_ok('ordinary own identity view','people');
SELECT pg_temp.expect_true('ordinary editable metadata does not impersonate platform identity','READ',
 (SELECT result->'person'->>'id'=pg_temp.fixture_id('ordinary')::text
  AND NOT result->'operations' ?| ARRAY['organization.create','person.create','account.link','role_assignment.add']
  AND jsonb_array_length(result->'records'->'people')=1
 FROM pg_temp.phase2b_reads WHERE label='ordinary own identity view'));
SELECT pg_temp.read_ok('ordinary membership organization context','organizations',pg_temp.fixture_id('org-a'));
SELECT pg_temp.expect_true('membership only context contains minimal organization fields','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'organizations') o
  WHERE o->>'id'=pg_temp.fixture_id('org-a')::text AND o->'fields' ?& ARRAY['name','slug']
   AND NOT o->'fields' ?| ARRAY['legal_name','timezone','country','default_currency'])
 FROM pg_temp.phase2b_reads WHERE label='ordinary membership organization context'));
SELECT pg_temp.read_deny('ordinary global people name query denied','people',NULL,'Synthetic');
SELECT pg_temp.read_deny('ordinary foreign context deep link denied','home',pg_temp.fixture_id('org-b'));
SELECT pg_temp.read_deny('ordinary unknown context deep link denied','account',pg_temp.fixture_id('unknown-org'));

SELECT pg_temp.act_as('unit-only');
SELECT pg_temp.read_ok('exact unit only read projection','organizations',pg_temp.fixture_id('org-a'));
SELECT pg_temp.expect_true('exact unit read contains actual assigned unit','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'units') u
  WHERE u->>'id'=pg_temp.fixture_id('unit-a')::text AND u->'operations' ? 'unit.update')
 FROM pg_temp.phase2b_reads WHERE label='exact unit only read projection'));
SELECT pg_temp.expect_true('unit only cannot read sibling or descendant units','READ',
 (SELECT NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'units') u
  WHERE u->>'id' IN(pg_temp.fixture_id('unit-a-sibling')::text,pg_temp.fixture_id('unit-a-child')::text))
 FROM pg_temp.phase2b_reads WHERE label='exact unit only read projection'));
SELECT pg_temp.expect_true('unit only cannot read sibling or descendant teams','READ',
 (SELECT NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'teams') t
  WHERE t->>'id' IN(pg_temp.fixture_id('team-a-sibling')::text,pg_temp.fixture_id('team-a-child')::text))
 FROM pg_temp.phase2b_reads WHERE label='exact unit only read projection'));
SELECT pg_temp.expect_true('exact unit role does not advertise organization wide administration','READ',
 (SELECT NOT result->'operations' ?| ARRAY['module.set','unit.create','season.create','team.create','organization_membership.add','role_assignment.add']
 FROM pg_temp.phase2b_reads WHERE label='exact unit only read projection'));
SELECT pg_temp.act_as('unit-admin');
SELECT pg_temp.read_ok('unit administrator legitimate member hierarchy','organizations',pg_temp.fixture_id('org-a'));
SELECT pg_temp.expect_true('legitimate hierarchy visibility does not grant sibling unit edit operations','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'units') u WHERE u->>'id'=pg_temp.fixture_id('unit-a-sibling')::text)
  AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'units') u
   WHERE u->>'id' IN(pg_temp.fixture_id('unit-a-sibling')::text,pg_temp.fixture_id('unit-a-child')::text)
    AND u->'operations' ?| ARRAY['unit.update','season.create','team.create'])
 FROM pg_temp.phase2b_reads WHERE label='unit administrator legitimate member hierarchy'));

SELECT pg_temp.act_as('coach');
SELECT pg_temp.read_ok('coach exact team read projection','teams',pg_temp.fixture_id('org-a'));
SELECT pg_temp.expect_true('coach own team mutation affordance is explicit','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'teams') t
  WHERE t->>'id'=pg_temp.fixture_id('team-a')::text AND t->'operations' ?& ARRAY['team.update','team_membership.add'])
 FROM pg_temp.phase2b_reads WHERE label='coach exact team read projection'));
SELECT pg_temp.expect_true('coach has no unrelated team mutation affordance','READ',
 (SELECT NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'teams') t
  WHERE t->>'id'<>pg_temp.fixture_id('team-a')::text AND t->'operations' ?| ARRAY['team.update','team_membership.add','role_assignment.add'])
 FROM pg_temp.phase2b_reads WHERE label='coach exact team read projection'));
SELECT pg_temp.act_as('household-only');
SELECT pg_temp.read_ok('household A read remains isolated','families');
SELECT pg_temp.expect_true('household member cannot read household B projection','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'households') h WHERE h->>'id'=pg_temp.fixture_id('household-a')::text)
  AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'households') h WHERE h->>'id'=pg_temp.fixture_id('household-b')::text)
  AND NOT result->'operations' ?| ARRAY['household.create','household_membership.add','guardian.create']
 FROM pg_temp.phase2b_reads WHERE label='household A read remains isolated'));
SELECT pg_temp.act_as('guardian');
SELECT pg_temp.read_ok('verified guardian read of permitted dependent','people');
SELECT pg_temp.expect_true('verified guardian dependent profile operation stays narrow','READ',
 (SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'people') p
  WHERE p->>'id'=pg_temp.fixture_id('dependent')::text AND p->'operations' ? 'person.update')
  AND NOT result->'operations' ?| ARRAY['household.create','guardian.create','role_assignment.add']
 FROM pg_temp.phase2b_reads WHERE label='verified guardian read of permitted dependent'));

SELECT pg_temp.act_as('unknown');
SELECT pg_temp.expect_true('unprovisioned verified Auth gets no data or administrative capability','READ',
 (SELECT r->>'provisioned'='false' AND r->'person'='null'::jsonb AND r->'organizations'='[]'::jsonb
  AND r->'records'='{}'::jsonb AND r->'operations'='["identity.provision_self"]'::jsonb
  FROM (SELECT public.boss_admin_read('home') r) s));
RESET ROLE;

-- A legitimate selected organization beyond the first fifty contexts remains
-- accessible. Pagination may not accidentally become an authorization gate.
INSERT INTO public.organizations(id,name,slug,organization_type)
SELECT pg_temp.fixture_id('context-' || n::text),'AAA Synthetic Phase 2B Context ' || lpad(n::text,2,'0'),
 'synthetic-phase2b-context-' || lpad(n::text,2,'0'),'test' FROM generate_series(1,55) n;
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('platform');
SELECT pg_temp.read_ok('selected deep organization beyond fifty contexts','organizations',pg_temp.fixture_id('org-a'));
SELECT pg_temp.expect_true('selected authorized deep context appears beyond bounded first page','READ',
 (SELECT jsonb_array_length(result->'organizations')=51 AND EXISTS(SELECT 1 FROM jsonb_array_elements(result->'organizations') o
  WHERE o->>'id'=pg_temp.fixture_id('org-a')::text)
  AND result->>'organizationId'=pg_temp.fixture_id('org-a')::text
 FROM pg_temp.phase2b_reads WHERE label='selected deep organization beyond fifty contexts'));
SELECT pg_temp.read_ok('context search supports legitimate organization lookup','organizations',NULL,'Context 55');
SELECT pg_temp.expect_true('organization search returns only authorized matching context','READ',
 (SELECT jsonb_array_length(result->'organizations')=1 AND result->'organizations'->0->>'id'=pg_temp.fixture_id('context-55')::text
 FROM pg_temp.phase2b_reads WHERE label='context search supports legitimate organization lookup'));
SELECT pg_temp.act_as('ordinary');
SELECT pg_temp.read_deny('pagination does not authorize unrelated deep context','organizations',pg_temp.fixture_id('context-55'));
RESET ROLE;

SELECT pg_temp.expect_count('all tested projections exclude sensitive keys and fixture contact values','READ',
 $$ SELECT count(*) FROM pg_temp.phase2b_reads WHERE result::text ~* '(date_of_birth|primary_email|primary_phone|auth_user_id|session_id|raw_user_meta_data|raw_app_meta_data|before_data|after_data|private-synthetic)' $$,0);
SELECT pg_temp.expect_count('every projected record has safe structured fields','READ',
 $$ SELECT count(*) FROM pg_temp.phase2b_reads r CROSS JOIN LATERAL jsonb_each(r.result->'records') collection
    CROSS JOIN LATERAL jsonb_array_elements(collection.value) item
    WHERE NOT(item ?& ARRAY['id','label','fields','operations']) OR jsonb_typeof(item->'fields')<>'object' OR jsonb_typeof(item->'operations')<>'array' $$,0);

-- Private projection helpers also bind the current live caller. Calling them
-- directly cannot retain access after that caller's Auth session is removed.
DELETE FROM auth.sessions WHERE id=pg_temp.fixture_id('session-ordinary');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('ordinary');
SELECT pg_temp.read_deny('read RPC rejects revoked live session','people',NULL,NULL,ARRAY['PT401']);
DO $test$
DECLARE statement text;label text;denied boolean;
BEGIN
 FOREACH statement IN ARRAY ARRAY[
  'SELECT boss_private.admin_contexts(NULL,NULL)',
  'SELECT boss_private.admin_people(NULL,NULL)'
 ] LOOP
  denied:=false;
  BEGIN EXECUTE statement;
  EXCEPTION WHEN SQLSTATE 'PT401' THEN denied:=true;
  END;
  label:=CASE WHEN statement LIKE '%admin_contexts%' THEN 'private contexts helper rejects revoked live session'
   ELSE 'private people helper rejects revoked live session' END;
  PERFORM pg_temp.expect_true(label,'READ',denied);
 END LOOP;
END;
$test$;
RESET ROLE;
INSERT INTO auth.sessions(id,user_id) VALUES(pg_temp.fixture_id('session-ordinary'),pg_temp.fixture_id('auth-ordinary'));

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{}',true);
DO $test$
DECLARE denied boolean:=false;
BEGIN
 BEGIN PERFORM public.boss_admin_read('home');
 EXCEPTION WHEN insufficient_privilege THEN denied:=true;
 END;
 PERFORM pg_temp.expect_true('actual anonymous read RPC denied','READ',denied);
END;
$test$;
RESET ROLE;

-- Successful RPC administration does not confer any direct table mutation,
-- receipt access, trusted database role or audit rewrite power to clients.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('platform');
DO $test$
DECLARE table_name text; column_name text; statement text; operation text; denied boolean;
BEGIN
 FOR table_name IN SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname='public' LOOP
  PERFORM pg_temp.expect_true('authenticated direct mutation grants stay closed: ' || table_name,'O',
   NOT has_table_privilege('authenticated','public.' || table_name,'INSERT,UPDATE,DELETE,TRUNCATE'));
  SELECT attname INTO column_name FROM pg_catalog.pg_attribute WHERE attrelid=('public.' || table_name)::regclass
   AND attnum>0 AND NOT attisdropped ORDER BY attnum LIMIT 1;
  FOREACH operation IN ARRAY ARRAY['INSERT','UPDATE','DELETE','TRUNCATE'] LOOP
   statement := CASE operation
    WHEN 'INSERT' THEN format('INSERT INTO public.%I DEFAULT VALUES',table_name)
    WHEN 'UPDATE' THEN format('UPDATE public.%I SET %I=%I',table_name,column_name,column_name)
    WHEN 'DELETE' THEN format('DELETE FROM public.%I',table_name)
    WHEN 'TRUNCATE' THEN format('TRUNCATE public.%I',table_name) END;
   denied := false;
   BEGIN EXECUTE statement;
   EXCEPTION WHEN insufficient_privilege THEN denied := true;
   END;
   PERFORM pg_temp.expect_true('actual authenticated ' || operation || ' denied: ' || table_name,'O',denied);
  END LOOP;
 END LOOP;
END;
$test$;
DO $test$
DECLARE denied boolean := false;
BEGIN
 BEGIN EXECUTE 'SELECT * FROM boss_private.admin_operation_receipts';
 EXCEPTION WHEN insufficient_privilege THEN denied := true;
 END;
 PERFORM pg_temp.expect_true('actual receipt SELECT denied to authenticated','O',denied);
END;
$test$;
RESET ROLE;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{}',true);
DO $test$
DECLARE denied boolean := false;
BEGIN
 BEGIN PERFORM public.boss_admin_mutate('[]',pg_temp.fixture_id('anon-request'));
 EXCEPTION WHEN insufficient_privilege THEN denied := true;
 END;
 PERFORM pg_temp.expect_true('actual anonymous mutation RPC denied','O',denied);
END;
$test$;
RESET ROLE;

-- Scoped candidate discovery must not be displaced by unrelated directory rows,
-- duplicate relationship paths or inactive dependent identity. This also exercises
-- substring filtering after the authorized IDs have been selected.
INSERT INTO public.people(id,display_name)
SELECT pg_temp.fixture_id('candidate-noise-'||n::text),'Synthetic Phase 2B 000 unrelated candidate noise '||lpad(n::text,4,'0')
FROM generate_series(1,2000) n;
INSERT INTO public.people(id,display_name,status) VALUES
  (pg_temp.fixture_id('candidate-dependent'),'Synthetic Phase 2B candidate dependent','active'),
  (pg_temp.fixture_id('candidate-inactive'),'Synthetic Phase 2B candidate dependent inactive','inactive');
INSERT INTO public.guardian_relationships(guardian_person_id,dependent_person_id,relationship_type,authority_status,verified_at,can_manage_profile,starts_at) VALUES
  (pg_temp.fixture_id('ordinary'),pg_temp.fixture_id('candidate-dependent'),'guardian','active',now()-interval '1 day',true,now()-interval '2 days'),
  (pg_temp.fixture_id('ordinary'),pg_temp.fixture_id('candidate-dependent'),'custodian','active',now()-interval '1 day',true,now()-interval '2 days'),
  (pg_temp.fixture_id('ordinary'),pg_temp.fixture_id('candidate-inactive'),'guardian','active',now()-interval '1 day',true,now()-interval '2 days');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act_as('ordinary');
SELECT pg_temp.read_ok('scoped candidates resist unrelated directory volume','people');
SELECT pg_temp.expect_true('scoped candidate own and dependent identities remain exact','READ',
  (SELECT jsonb_array_length(result->'records'->'people')=2 AND EXISTS(
     SELECT 1 FROM jsonb_array_elements(result->'records'->'people') p WHERE p->>'id'=pg_temp.fixture_id('ordinary')::text)
   AND EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'people') p
     WHERE p->>'id'=pg_temp.fixture_id('candidate-dependent')::text AND p->'operations' ? 'person.update')
   FROM pg_temp.phase2b_reads WHERE label='scoped candidates resist unrelated directory volume'));
SELECT pg_temp.expect_true('duplicate guardian paths return one projected person','READ',
  (SELECT (SELECT count(*) FROM jsonb_array_elements(result->'records'->'people') p
     WHERE p->>'id'=pg_temp.fixture_id('candidate-dependent')::text)=1
   FROM pg_temp.phase2b_reads WHERE label='scoped candidates resist unrelated directory volume'));
SELECT pg_temp.expect_true('inactive guardian target and unrelated noise are not candidates','READ',
  (SELECT NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'records'->'people') p
    WHERE p->>'id'=pg_temp.fixture_id('candidate-inactive')::text OR p->>'label' LIKE '%unrelated candidate noise%')
   FROM pg_temp.phase2b_reads WHERE label='scoped candidates resist unrelated directory volume'));
SELECT pg_temp.read_ok('scoped candidates preserve contextual substring search','people',pg_temp.fixture_id('org-a'),'candidate dependent');
SELECT pg_temp.expect_true('contextual search returns authorized dependent only','READ',
  (SELECT jsonb_array_length(result->'records'->'people')=1 AND result->'records'->'people'->0->>'id'=pg_temp.fixture_id('candidate-dependent')::text
   FROM pg_temp.phase2b_reads WHERE label='scoped candidates preserve contextual substring search'));
SELECT pg_temp.act_as('platform');
SELECT pg_temp.read_ok('global directory retains substring behavior after scoped optimization','people',NULL,'candidate noise 0500');
SELECT pg_temp.expect_true('global substring search still finds unrelated canonical person','READ',
  (SELECT jsonb_array_length(result->'records'->'people')=1 AND result->'records'->'people'->0->>'id'=pg_temp.fixture_id('candidate-noise-500')::text
   FROM pg_temp.phase2b_reads WHERE label='global directory retains substring behavior after scoped optimization'));
RESET ROLE;

SELECT count(*) AS passed_assertions FROM pg_temp.phase2b_assertions;
SELECT category,count(*) AS passed FROM pg_temp.phase2b_assertions GROUP BY category ORDER BY category;
ROLLBACK;

DO $test$
BEGIN
 IF EXISTS(SELECT 1 FROM public.people WHERE display_name LIKE 'Synthetic Phase 2B%')
  OR EXISTS(SELECT 1 FROM public.organizations WHERE slug LIKE 'synthetic-phase2b-%')
  OR EXISTS(SELECT 1 FROM public.households WHERE name LIKE 'Synthetic Phase 2B%')
  OR EXISTS(SELECT 1 FROM public.roles WHERE key='synthetic_phase2b_ungrantable')
  OR EXISTS(SELECT 1 FROM auth.users WHERE id=md5('boss-phase2b-transaction-fixture:auth-platform')::uuid)
  OR EXISTS(SELECT 1 FROM auth.sessions WHERE id=md5('boss-phase2b-transaction-fixture:session-platform')::uuid)
  OR EXISTS(SELECT 1 FROM boss_private.admin_operation_receipts
   WHERE request_id=md5('boss-phase2b-transaction-fixture:request-platform creates organization')::uuid) THEN
  RAISE EXCEPTION 'FAIL cleanup: Phase 2B transactional fixture survived rollback';
 END IF;
END;
$test$;
SELECT 'Phase 2B fixtures and receipts rolled back; no test records persisted' AS cleanup_result;
