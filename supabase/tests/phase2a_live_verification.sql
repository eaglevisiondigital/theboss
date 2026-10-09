-- Reviewed live verification: DML and assertions only, no schema/function/table DDL.
-- Run only after disposable validation passes and canonical migrations are applied.
-- Every fixture and assertion is inside one atomic DO statement. A failure aborts
-- that statement and its writes; success reaches the explicit transaction rollback.
-- If a client stops on an error, issue ROLLBACK before reusing its connection.
-- Synthetic Auth UUIDs are required solely for the real user_accounts FK. No
-- password, token, session, email, real identity or user metadata is read or stored.
BEGIN;
DO $live$
DECLARE
  table_name text;
  column_name text;
  operation text;
  api_role text;
  denied boolean;
  passed integer := 0;
  alice uuid := 'f2a10000-0000-4000-8000-000000000001';
  bob uuid := 'f2a10000-0000-4000-8000-000000000002';
  coach uuid := 'f2a10000-0000-4000-8000-000000000003';
  owner_person uuid := 'f2a10000-0000-4000-8000-000000000004';
  guardian uuid := 'f2a10000-0000-4000-8000-000000000005';
  household_only uuid := 'f2a10000-0000-4000-8000-000000000006';
  dependent uuid := 'f2a10000-0000-4000-8000-000000000007';
  platform_person uuid := 'f2a10000-0000-4000-8000-000000000008';
  org_a uuid := 'f2a30000-0000-4000-8000-000000000001';
  org_b uuid := 'f2a30000-0000-4000-8000-000000000002';
  unit_a uuid := 'f2a40000-0000-4000-8000-000000000001';
  unit_b uuid := 'f2a40000-0000-4000-8000-000000000002';
  team_a uuid := 'f2a50000-0000-4000-8000-000000000001';
  team_b uuid := 'f2a50000-0000-4000-8000-000000000002';
  team_a_sibling uuid := 'f2a50000-0000-4000-8000-000000000003';
  household_a uuid := 'f2a60000-0000-4000-8000-000000000001';
  household_b uuid := 'f2a60000-0000-4000-8000-000000000002';
  participant_id uuid := 'f2a80000-0000-4000-8000-000000000001';
BEGIN
  IF (SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname = 'public' AND tablename IN ('people','user_accounts','households','participants','organizations','organization_units','seasons','teams','organization_memberships','team_memberships','household_memberships','guardian_relationships','roles','permissions','role_permissions','role_assignments','modules','organization_modules','entitlements','feature_flags','feature_flag_overrides','audit_events')) <> 22 THEN
    RAISE EXCEPTION 'Live foundation table count is not exactly 22';
  END IF;
  passed := passed + 1;
  -- A collision fails safely rather than altering an existing record.
  IF EXISTS (SELECT 1 FROM public.people WHERE id IN (alice,bob,coach,owner_person,guardian,household_only,dependent,platform_person))
    OR EXISTS (SELECT 1 FROM public.organizations WHERE id IN (org_a,org_b)) THEN
    RAISE EXCEPTION 'Live verification synthetic fixture collision';
  END IF;
  INSERT INTO auth.users (id) VALUES
    ('f2a20000-0000-4000-8000-000000000001'),('f2a20000-0000-4000-8000-000000000002'),
    ('f2a20000-0000-4000-8000-000000000003'),('f2a20000-0000-4000-8000-000000000004'),
    ('f2a20000-0000-4000-8000-000000000005'),('f2a20000-0000-4000-8000-000000000006'),
    ('f2a20000-0000-4000-8000-000000000008');
  INSERT INTO public.people (id,display_name) VALUES
    (alice,'Synthetic live Alice'),(bob,'Synthetic live Bob'),(coach,'Synthetic live coach'),
    (owner_person,'Synthetic live organization owner'),(guardian,'Synthetic live guardian'),
    (household_only,'Synthetic live household member'),(dependent,'Synthetic live dependent'),
    (platform_person,'Synthetic live platform reader');
  INSERT INTO public.user_accounts (auth_user_id,person_id,account_status) VALUES
    ('f2a20000-0000-4000-8000-000000000001',alice,'active'),
    ('f2a20000-0000-4000-8000-000000000002',bob,'active'),
    ('f2a20000-0000-4000-8000-000000000003',coach,'active'),
    ('f2a20000-0000-4000-8000-000000000004',owner_person,'active'),
    ('f2a20000-0000-4000-8000-000000000005',guardian,'active'),
    ('f2a20000-0000-4000-8000-000000000006',household_only,'active'),
    ('f2a20000-0000-4000-8000-000000000008',platform_person,'active');
  INSERT INTO public.organizations (id,name,slug) VALUES
    (org_a,'Synthetic live organization A','synthetic-phase2a-live-a'),
    (org_b,'Synthetic live organization B','synthetic-phase2a-live-b');
  INSERT INTO public.organization_units (id,organization_id,unit_type,name,slug) VALUES
    (unit_a,org_a,'program','Synthetic live unit A','synthetic-live-a'),
    (unit_b,org_b,'program','Synthetic live unit B','synthetic-live-b');
  INSERT INTO public.teams (id,organization_id,parent_unit_id,name,slug,status,visibility) VALUES
    (team_a,org_a,unit_a,'Synthetic live team A','synthetic-live-a','active','private'),
    (team_b,org_b,unit_b,'Synthetic live team B','synthetic-live-b','active','private'),
    (team_a_sibling,org_a,unit_a,'Synthetic live sibling team','synthetic-live-sibling','active','public');
  INSERT INTO public.organization_memberships (organization_id,person_id,membership_type,starts_at) VALUES
    (org_a,alice,'organization_owner',now() - interval '1 day'),
    (org_b,bob,'member',now() - interval '1 day');
  INSERT INTO public.participants (id,person_id,participant_type) VALUES (participant_id,dependent,'athlete');
  INSERT INTO public.team_memberships (organization_id,team_id,person_id,participant_id,membership_type,starts_at) VALUES
    (org_a,team_a,coach,NULL,'coach',now() - interval '1 day'),
    (org_a,team_a,dependent,participant_id,'athlete',now() - interval '1 day'),
    (org_b,team_b,bob,NULL,'volunteer',now() - interval '1 day');
  INSERT INTO public.households (id,name) VALUES (household_a,'Synthetic live household A'),(household_b,'Synthetic live household B');
  INSERT INTO public.household_memberships (household_id,person_id,relationship_type,starts_at) VALUES
    (household_a,alice,'adult',now() - interval '1 day'),
    (household_a,household_only,'adult',now() - interval '1 day'),
    (household_a,dependent,'dependent',now() - interval '1 day'),
    (household_b,bob,'adult',now() - interval '1 day');
  INSERT INTO public.guardian_relationships
    (guardian_person_id,dependent_person_id,authority_status,can_manage_profile,starts_at,verified_at) VALUES
    (guardian,dependent,'active',true,now() - interval '1 day',now() - interval '1 day');
  INSERT INTO public.role_assignments (person_id,role_id,scope_type,scope_id,organization_id,starts_at)
    SELECT coach,id,'team',team_a,org_a,now() - interval '1 day' FROM public.roles WHERE key = 'head_coach';
  INSERT INTO public.role_assignments (person_id,role_id,scope_type,scope_id,organization_id,starts_at)
    SELECT owner_person,id,'organization',org_a,org_a,now() - interval '1 day' FROM public.roles WHERE key = 'organization_owner';
  INSERT INTO public.role_assignments (person_id,role_id,scope_type,starts_at)
    SELECT platform_person,id,'platform',now() - interval '1 day' FROM public.roles WHERE key = 'platform_administrator';
  INSERT INTO public.organization_modules (organization_id,module_id,status,starts_at)
    SELECT org_a,id,'active',now() - interval '1 day' FROM public.modules WHERE key = 'sports';
  INSERT INTO public.entitlements (subject_type,subject_id,entitlement_type,entitlement_key,status,starts_at) VALUES
    ('person',household_only,'capability','synthetic_live_phase2a','active',now() - interval '1 day');
  INSERT INTO public.audit_events (organization_id,actor_person_id,action,resource_type,scope_type,scope_id) VALUES
    (org_a,alice,'synthetic.live.fixture','organization','organization',org_a),
    (org_b,bob,'synthetic.live.fixture','organization','organization',org_b);

  IF (SELECT count(*) FROM public.participants p WHERE p.id = participant_id AND NOT EXISTS
        (SELECT 1 FROM public.user_accounts a WHERE a.person_id = p.person_id)) <> 1 THEN
    RAISE EXCEPTION 'Live no-Auth participant failed';
  END IF;
  passed := passed + 1;

  -- Model real PostgREST database roles, not HTTP JWT signature verification.
  FOREACH api_role IN ARRAY ARRAY['anon','authenticated'] LOOP
    EXECUTE format('SET LOCAL ROLE %I',api_role);
    PERFORM set_config('request.jwt.claim.sub','',true);
    PERFORM set_config('request.jwt.claim','',true);
    PERFORM set_config('request.jwt.claims',CASE WHEN api_role = 'anon' THEN '{}'
      ELSE '{"sub":"f2a20000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"user_metadata":{"is_admin":true,"role":"super_administrator"}}' END,true);
    FOR table_name IN SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'public' LOOP
      IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid = ('public.' || table_name)::regclass) THEN
        RAISE EXCEPTION 'Live RLS missing on %',table_name;
      END IF;
      passed := passed + 1;
      IF api_role = 'anon' THEN
        denied := false;
        BEGIN EXECUTE format('SELECT count(*) FROM public.%I',table_name);
        EXCEPTION WHEN insufficient_privilege THEN denied := true; END;
        IF NOT denied THEN RAISE EXCEPTION 'Live anonymous SELECT opened on %',table_name; END IF;
        passed := passed + 1;
      END IF;
      SELECT attname INTO column_name FROM pg_catalog.pg_attribute
        WHERE attrelid = ('public.' || table_name)::regclass AND attnum > 0 AND NOT attisdropped ORDER BY attnum LIMIT 1;
      FOREACH operation IN ARRAY ARRAY['INSERT','UPDATE','DELETE','TRUNCATE'] LOOP
        denied := false;
        BEGIN
          CASE operation
            WHEN 'INSERT' THEN EXECUTE format('INSERT INTO public.%I DEFAULT VALUES',table_name);
            WHEN 'UPDATE' THEN EXECUTE format('UPDATE public.%I SET %I = %I',table_name,column_name,column_name);
            WHEN 'DELETE' THEN EXECUTE format('DELETE FROM public.%I',table_name);
            WHEN 'TRUNCATE' THEN EXECUTE format('TRUNCATE public.%I',table_name);
          END CASE;
        EXCEPTION WHEN insufficient_privilege THEN denied := true; END;
        IF NOT denied THEN RAISE EXCEPTION 'Live % mutation opened on % for %',operation,table_name,api_role; END IF;
        passed := passed + 1;
      END LOOP;
    END LOOP;
    EXECUTE 'RESET ROLE';
  END LOOP;

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claims','{"sub":"f2a20000-0000-4000-8000-000000000001","role":"authenticated","user_metadata":{"is_admin":true,"role":"super_administrator"}}',true);
  IF boss_private.current_person_id() IS DISTINCT FROM alice THEN RAISE EXCEPTION 'Live canonical mapping failed'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.people WHERE id = alice) <> 1 OR (SELECT count(*) FROM public.people WHERE id IN (bob,dependent)) <> 0 THEN
    RAISE EXCEPTION 'Live own/private person isolation failed'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.user_accounts WHERE person_id = alice) <> 1 OR
     (SELECT count(*) FROM public.user_accounts WHERE person_id = bob) <> 0 THEN RAISE EXCEPTION 'Live account isolation failed'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.organizations WHERE id = org_a) <> 1 OR
     (SELECT count(*) FROM public.organizations WHERE id = org_b) <> 0 THEN RAISE EXCEPTION 'Live tenant isolation failed'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.organization_units WHERE organization_id = org_a) <> 1 OR
     (SELECT count(*) FROM public.organization_units WHERE organization_id = org_b) <> 0 THEN RAISE EXCEPTION 'Live unit isolation failed'; END IF;
  passed := passed + 1;
  IF boss_private.has_permission('organization.manage',org_a) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Live membership type or editable metadata granted authority'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.teams WHERE id IN (team_a,team_b,team_a_sibling)) <> 0 THEN
    RAISE EXCEPTION 'Live organization membership or visibility exposed private team'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.households WHERE id = household_a) <> 1 OR
     (SELECT count(*) FROM public.households WHERE id = household_b) <> 0 THEN RAISE EXCEPTION 'Live household isolation failed'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.household_memberships WHERE person_id = alice) <> 1 OR
     (SELECT count(*) FROM public.household_memberships WHERE person_id IN (bob,dependent)) <> 0 THEN
    RAISE EXCEPTION 'Live household relationship privacy failed'; END IF;
  passed := passed + 1;
  IF boss_private.can_manage_dependent_profile(dependent) IS DISTINCT FROM false OR
     (SELECT count(*) FROM public.guardian_relationships WHERE dependent_person_id = dependent) <> 0 THEN
    RAISE EXCEPTION 'Live household membership implied guardian authority'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.audit_events WHERE actor_person_id = alice) <> 0 THEN
    RAISE EXCEPTION 'Live audit actor gained unauthorized audit access'; END IF;
  passed := passed + 1;

  PERFORM set_config('request.jwt.claims','{"sub":"f2a20000-0000-4000-8000-000000000003","role":"authenticated"}',true);
  IF (SELECT count(*) FROM public.teams WHERE id = team_a) <> 1 OR
     (SELECT count(*) FROM public.teams WHERE id IN (team_b,team_a_sibling)) <> 0 THEN RAISE EXCEPTION 'Live seeded coach team scope failed'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.team_memberships WHERE team_id = team_a) <> 2 OR
     (SELECT count(*) FROM public.team_memberships WHERE team_id = team_b) <> 0 THEN RAISE EXCEPTION 'Live seeded coach roster scope failed'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.participants WHERE id = participant_id) <> 1 OR
     (SELECT count(*) FROM public.people WHERE id = dependent) <> 0 THEN RAISE EXCEPTION 'Live participant/person privacy boundary failed'; END IF;
  passed := passed + 1;
  IF boss_private.has_permission('organization.manage',org_a) IS DISTINCT FROM false OR
     (SELECT count(*) FROM public.organization_memberships WHERE organization_id = org_a) <> 0 THEN
    RAISE EXCEPTION 'Live seeded team role escalated organization authority'; END IF;
  passed := passed + 1;

  PERFORM set_config('request.jwt.claims','{"sub":"f2a20000-0000-4000-8000-000000000004","role":"authenticated"}',true);
  IF boss_private.has_permission('organization.manage',org_a) IS DISTINCT FROM true OR
     boss_private.has_permission('organization.manage',org_b) IS DISTINCT FROM false THEN RAISE EXCEPTION 'Live seeded organization owner scope failed'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.teams WHERE organization_id = org_a) <> 2 OR
     (SELECT count(*) FROM public.teams WHERE organization_id = org_b) <> 0 THEN RAISE EXCEPTION 'Live owner team tenant isolation failed'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.households WHERE id IN (household_a,household_b)) <> 0 THEN
    RAISE EXCEPTION 'Live organization role leaked unanchored household data'; END IF;
  passed := passed + 1;
  IF (SELECT count(*) FROM public.audit_events WHERE organization_id = org_a) <> 1 OR
     (SELECT count(*) FROM public.audit_events WHERE organization_id = org_b) <> 0 THEN RAISE EXCEPTION 'Live owner audit tenant isolation failed'; END IF;
  passed := passed + 1;

  PERFORM set_config('request.jwt.claims','{"sub":"f2a20000-0000-4000-8000-000000000006","role":"authenticated"}',true);
  IF boss_private.has_active_entitlement('person',household_only,'synthetic_live_phase2a') IS DISTINCT FROM true OR
     (SELECT count(*) FROM public.organizations WHERE id IN (org_a,org_b)) <> 0 OR
     (SELECT count(*) FROM public.teams WHERE id IN (team_a,team_b,team_a_sibling)) <> 0 THEN
    RAISE EXCEPTION 'Live entitlement improperly granted operational authority'; END IF;
  passed := passed + 1;
  IF boss_private.organization_module_active(org_a,'sports') IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Live module active state leaked to unrelated caller'; END IF;
  passed := passed + 1;
  IF boss_private.can_manage_dependent_profile(dependent) IS DISTINCT FROM false OR
     (SELECT count(*) FROM public.people WHERE id = dependent) <> 0 THEN RAISE EXCEPTION 'Live household-only profile isolation failed'; END IF;
  passed := passed + 1;

  PERFORM set_config('request.jwt.claims','{"sub":"f2a20000-0000-4000-8000-000000000005","role":"authenticated"}',true);
  IF boss_private.can_manage_dependent_profile(dependent) IS DISTINCT FROM true OR
     (SELECT count(*) FROM public.people WHERE id = dependent) <> 1 OR
     (SELECT count(*) FROM public.participants WHERE id = participant_id) <> 1 THEN RAISE EXCEPTION 'Live explicit verified guardian profile access failed'; END IF;
  passed := passed + 1;

  PERFORM set_config('request.jwt.claims','{"sub":"f2a20000-0000-4000-8000-000000000008","role":"authenticated"}',true);
  IF (SELECT count(*) FROM public.organizations WHERE id IN (org_a,org_b)) <> 2 OR
     (SELECT count(*) FROM public.households WHERE id IN (household_a,household_b)) <> 2 THEN RAISE EXCEPTION 'Live explicit platform scope failed'; END IF;
  passed := passed + 1;
  PERFORM set_config('request.jwt.claims','{"sub":"f2a20000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":true}',true);
  IF boss_private.current_person_id() IS NOT NULL THEN RAISE EXCEPTION 'Live mapped anonymous Auth identity accepted'; END IF;
  passed := passed + 1;
  EXECUTE 'RESET ROLE';
  PERFORM set_config('boss.phase2a_live_assertions',passed::text,true);
  RAISE NOTICE 'Phase 2A live database-role assertions passed: %; rollback follows',passed;
END;
$live$;
SELECT current_setting('boss.phase2a_live_assertions')::integer AS passed_assertions;
ROLLBACK;

DO $cleanup$
BEGIN
  IF EXISTS (SELECT 1 FROM public.people WHERE id::text LIKE 'f2a10000-0000-4000-8000-%')
    OR EXISTS (SELECT 1 FROM auth.users WHERE id::text LIKE 'f2a20000-0000-4000-8000-%')
    OR EXISTS (SELECT 1 FROM public.organizations WHERE id::text LIKE 'f2a30000-0000-4000-8000-%')
    OR EXISTS (SELECT 1 FROM public.teams WHERE id::text LIKE 'f2a50000-0000-4000-8000-%')
    OR EXISTS (SELECT 1 FROM public.households WHERE id::text LIKE 'f2a60000-0000-4000-8000-%')
    OR EXISTS (SELECT 1 FROM public.participants WHERE id::text LIKE 'f2a80000-0000-4000-8000-%') THEN
    RAISE EXCEPTION 'Live synthetic fixture survived rollback';
  END IF;
END;
$cleanup$;

-- Only counts/status are returned. No live real-user records are selected.
SELECT jsonb_build_object(
  'status','passed_fixture_cleanup',
  'people', (SELECT count(*) FROM public.people WHERE id::text LIKE 'f2a10000-0000-4000-8000-%'),
  'auth_users', (SELECT count(*) FROM auth.users WHERE id::text LIKE 'f2a20000-0000-4000-8000-%'),
  'organizations', (SELECT count(*) FROM public.organizations WHERE id::text LIKE 'f2a30000-0000-4000-8000-%'),
  'teams', (SELECT count(*) FROM public.teams WHERE id::text LIKE 'f2a50000-0000-4000-8000-%'),
  'households', (SELECT count(*) FROM public.households WHERE id::text LIKE 'f2a60000-0000-4000-8000-%'),
  'participants', (SELECT count(*) FROM public.participants WHERE id::text LIKE 'f2a80000-0000-4000-8000-%')
) AS cleanup_result;
