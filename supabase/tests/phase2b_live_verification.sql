-- Canonical Phase 2B runtime verification: DML and assertions only, no DDL.
-- Every managed Auth/session fixture is synthetic; no real credential/token is
-- read or stored. The DO block is atomic on failure and success explicitly rolls
-- back before prefix-scoped cleanup checks. Database roles model PostgREST access,
-- not HTTP JWT signature verification or hosted session issuance.
BEGIN;
DO $live$
DECLARE
  v_passed integer:=0;v_label text;v_actor text;v_state text;v_failed boolean;
  v_table text;v_column text;v_operation text;v_api_role text;v_case record;
  v_uid uuid;v_person uuid;v_request uuid;v_created_org uuid;v_created_person uuid;
  v_created_participant uuid;v_created_household uuid;v_created_guardian uuid;v_created_account uuid;
  v_role uuid;v_result jsonb;v_repeat jsonb;v_input jsonb;v_commands jsonb;
  v_before_audits bigint;v_before_receipts bigint;v_read jsonb;
  v_org_a uuid:='441e1a5f-e1d8-3ee7-7d5e-febbb9ee242e';
  v_org_b uuid:='97b2512d-d137-c684-7b9d-a61b218d7362';
  v_unit_a uuid:='2782fb1e-9744-dedc-5be5-7385be13b8e2';
  v_unit_sibling uuid:='8c9f3bb4-77f9-45e1-f10b-344465c8a67a';
  v_team_a uuid:='7831d147-7ed3-05dd-7be6-83ebc29f7e91';
  v_team_sibling uuid:='449b0277-6889-92b4-929d-74bdf9e3164e';
  v_team_b uuid:='f0c8118b-794e-da8d-0fdc-900777e162ac';
  v_household_a uuid:='917cd021-ce72-ada7-b11b-10a477124293';
  v_household_b uuid:='e5e8f91f-f3eb-7b70-625b-6b82ac1703e8';
  v_participant_dependent uuid:='2f89479f-9bd5-cda0-d92c-28729cbc9012';
  v_participant_b uuid:='af290a00-df2c-84c3-352a-b7c15f5c7da7';
  v_guardian_good uuid:='bfd2ad88-1d56-1ab8-3d34-a99f35c99752';
  v_guardian_wrong uuid:='e660b7c5-c142-888b-480b-63a82f105582';
  v_ungrantable_role uuid:='112af57f-f580-1597-8072-796ffa264916';
BEGIN
  IF (SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname='public' AND tablename IN ('people','user_accounts','households','participants','organizations','organization_units','seasons','teams','organization_memberships','team_memberships','household_memberships','guardian_relationships','roles','permissions','role_permissions','role_assignments','modules','organization_modules','entitlements','feature_flags','feature_flag_overrides','audit_events'))<>22
    OR (SELECT count(*) FROM public.roles WHERE key NOT IN ('registrar','organization_finance','competition_manager'))<>19 OR (SELECT count(*) FROM public.permissions WHERE key NOT IN ('events.view','events.create','events.manage','events.publish','events.override_conflict','registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish') AND key NOT LIKE 'games.%')<>17
    OR (SELECT count(*) FROM public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('events.view','events.create','events.manage','events.publish','events.override_conflict','registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish') AND p.key NOT LIKE 'games.%')<>112 THEN
    RAISE EXCEPTION 'Live foundation/catalog baseline changed';END IF;
  v_passed:=v_passed+1;
  IF EXISTS(SELECT 1 FROM public.people p WHERE p.display_name LIKE 'Synthetic Phase2B Live %')
    OR EXISTS(SELECT 1 FROM auth.users u WHERE u.email LIKE '%@phase2b-live.example.invalid') THEN
    RAISE EXCEPTION 'Synthetic live fixture collision';END IF;
  v_passed:=v_passed+1;

  FOREACH v_label IN ARRAY ARRAY['platform','ordinary','org-admin','unit-admin','coach','household-only','guardian','wrong-flag','expired','inactive','unmapped','link-auth','unconfirmed','anonymous','banned','dependent','target-a','target-b','target-unit','target-sibling','link-person'] LOOP
    v_person:=md5('boss-phase2b-live:'||v_label)::uuid;
    IF v_label NOT IN ('unmapped','link-auth') THEN INSERT INTO public.people(id,display_name) VALUES(v_person,'Synthetic Phase2B Live '||v_label);END IF;
    IF v_label NOT IN ('dependent','target-a','target-b','target-unit','target-sibling','link-person') THEN
      v_uid:=md5('boss-phase2b-live:auth:'||v_label)::uuid;
      INSERT INTO auth.users(id,email,email_confirmed_at,is_anonymous,banned_until,raw_user_meta_data)
        VALUES(v_uid,v_label||'@phase2b-live.example.invalid',CASE WHEN v_label='unconfirmed' THEN null ELSE now()-interval '2 days' END,
          v_label='anonymous',CASE WHEN v_label='banned' THEN now()+interval '1 day' END,'{"is_admin":true,"role":"super_administrator"}');
      INSERT INTO auth.sessions(id,user_id,not_after) VALUES(md5('boss-phase2b-live:session:'||v_label)::uuid,v_uid,null);
      IF v_label NOT IN ('unmapped','link-auth') THEN INSERT INTO public.user_accounts(auth_user_id,person_id,account_status) VALUES(v_uid,v_person,'active');END IF;
    END IF;
  END LOOP;
  INSERT INTO public.organizations(id,name,slug) VALUES
    (v_org_a,'Synthetic Phase2B Live Organization A','synthetic-phase2b-live-a'),
    (v_org_b,'Synthetic Phase2B Live Organization B','synthetic-phase2b-live-b');
  INSERT INTO public.organization_units(id,organization_id,unit_type,name,slug) VALUES
    (v_unit_a,v_org_a,'sport','Synthetic Phase2B Live Unit A','live-unit-a'),
    (v_unit_sibling,v_org_a,'sport','Synthetic Phase2B Live Sibling Unit','live-unit-sibling');
  INSERT INTO public.teams(id,organization_id,parent_unit_id,name,slug,status) VALUES
    (v_team_a,v_org_a,v_unit_a,'Synthetic Phase2B Live Team A','live-team-a','active'),
    (v_team_sibling,v_org_a,v_unit_sibling,'Synthetic Phase2B Live Sibling Team','live-team-sibling','active'),
    (v_team_b,v_org_b,null,'Synthetic Phase2B Live Team B','live-team-b','active');
  FOREACH v_label IN ARRAY ARRAY['ordinary','org-admin','unit-admin','coach','target-a','dependent'] LOOP
    INSERT INTO public.organization_memberships(organization_id,person_id,membership_type,starts_at)
      VALUES(v_org_a,md5('boss-phase2b-live:'||v_label)::uuid,CASE WHEN v_label='ordinary' THEN 'organization_owner' ELSE 'member' END,now()-interval '2 days');
  END LOOP;
  INSERT INTO public.organization_memberships(organization_id,person_id,starts_at) VALUES(v_org_b,'eee9b516-89e6-a8b9-d727-84e140364667',now()-interval '2 days');
  INSERT INTO public.participants(id,person_id,participant_type) VALUES
    (v_participant_dependent,'1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6','athlete'),(v_participant_b,'eee9b516-89e6-a8b9-d727-84e140364667','athlete');
  INSERT INTO public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at) VALUES
    (v_org_a,v_team_a,'370ff194-f3d1-7a31-1613-ffcfd359b6bc',null,'coach',now()-interval '2 days'),
    (v_org_a,v_team_a,'1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6',v_participant_dependent,'athlete',now()-interval '2 days'),
    (v_org_a,v_team_a,'b16cf54a-431e-78ff-2428-6a9602eef270',null,'member',now()-interval '2 days'),
    (v_org_a,v_team_sibling,'c0f00eda-0c1f-bcd6-578b-a693d672d0c9',null,'member',now()-interval '2 days'),
    (v_org_b,v_team_b,'eee9b516-89e6-a8b9-d727-84e140364667',v_participant_b,'athlete',now()-interval '2 days');
  INSERT INTO public.households(id,name) VALUES(v_household_a,'Synthetic Phase2B Live Household A'),(v_household_b,'Synthetic Phase2B Live Household B');
  INSERT INTO public.household_memberships(household_id,person_id,relationship_type,starts_at) VALUES
    (v_household_a,'836c0397-f2bb-c6a5-8060-4d00fa28e7c4','adult',now()-interval '2 days'),
    (v_household_a,'1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6','child',now()-interval '2 days'),
    (v_household_b,'eee9b516-89e6-a8b9-d727-84e140364667','adult',now()-interval '2 days');
  INSERT INTO public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,can_manage_profile,can_register,starts_at) VALUES
    (v_guardian_good,'ba266115-2701-7ce8-af9f-d1ded4467612','1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6','active',now()-interval '1 day',true,false,now()-interval '2 days'),
    (v_guardian_wrong,'fcb9afcf-3d27-2b96-89b3-62588058ca8c','1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6','active',now()-interval '1 day',false,true,now()-interval '2 days');
  FOR v_case IN SELECT * FROM (VALUES
    ('platform','platform_administrator','platform',null::uuid,null::uuid),
    ('org-admin','organization_administrator','organization',v_org_a,v_org_a),
    ('unit-admin','program_administrator','organization_unit',v_unit_a,v_org_a),
    ('coach','head_coach','team',v_team_a,v_org_a),
    ('expired','organization_administrator','organization',v_org_a,v_org_a),
    ('inactive','organization_administrator','organization',v_org_a,v_org_a),
    ('unconfirmed','platform_administrator','platform',null::uuid,null::uuid),
    ('anonymous','platform_administrator','platform',null::uuid,null::uuid),
    ('banned','platform_administrator','platform',null::uuid,null::uuid)
  ) f(actor,role_key,scope_type,scope_id,organization_id) LOOP
    INSERT INTO public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,status,starts_at,ends_at)
      SELECT md5('boss-phase2b-live:'||v_case.actor)::uuid,r.id,v_case.scope_type,v_case.scope_id,v_case.organization_id,
        CASE WHEN v_case.actor='inactive' THEN 'inactive' ELSE 'active' END,now()-interval '2 days',
        CASE WHEN v_case.actor='expired' THEN now()-interval '1 day' END FROM public.roles r WHERE r.key=v_case.role_key;
  END LOOP;
  INSERT INTO public.organization_modules(organization_id,module_id,status) SELECT v_org_a,m.id,'active' FROM public.modules m WHERE m.key='sports';
  INSERT INTO public.roles(id,key,name,allowed_scope_types) VALUES(v_ungrantable_role,'synthetic_phase2b_live_ungrantable','Synthetic Phase2B Live permission-subset test',ARRAY['team']);
  INSERT INTO public.role_permissions(role_id,permission_id) SELECT v_ungrantable_role,p.id FROM public.permissions p WHERE p.key='person.profile.manage';

  -- Every public table is tested under real anonymous/authenticated roles.
  FOREACH v_api_role IN ARRAY ARRAY['anon','authenticated'] LOOP
    EXECUTE format('SET LOCAL ROLE %I',v_api_role);
    PERFORM set_config('request.jwt.claim.sub','',true);PERFORM set_config('request.jwt.claim','',true);
    PERFORM set_config('request.jwt.claims',CASE WHEN v_api_role='anon' THEN '{}' ELSE
      jsonb_build_object('sub',md5('boss-phase2b-live:auth:platform')::uuid,'role','authenticated','is_anonymous',false,
        'session_id',md5('boss-phase2b-live:session:platform')::uuid)::text END,true);
    FOR v_table IN SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname='public' LOOP
      IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid=('public.'||v_table)::regclass) THEN RAISE EXCEPTION 'Live RLS missing';END IF;v_passed:=v_passed+1;
      IF v_api_role='anon' THEN
        v_failed:=false;BEGIN EXECUTE format('SELECT count(*) FROM public.%I',v_table);EXCEPTION WHEN insufficient_privilege THEN v_failed:=true;END;
        IF NOT v_failed THEN RAISE EXCEPTION 'Live anonymous table read opened';END IF;v_passed:=v_passed+1;
      END IF;
      SELECT attname INTO v_column FROM pg_catalog.pg_attribute WHERE attrelid=('public.'||v_table)::regclass AND attnum>0 AND NOT attisdropped ORDER BY attnum LIMIT 1;
      FOREACH v_operation IN ARRAY ARRAY['INSERT','UPDATE','DELETE','TRUNCATE'] LOOP
        v_failed:=false;BEGIN
          CASE v_operation
            WHEN 'INSERT' THEN EXECUTE format('INSERT INTO public.%I DEFAULT VALUES',v_table);
            WHEN 'UPDATE' THEN EXECUTE format('UPDATE public.%I SET %I=%I',v_table,v_column,v_column);
            WHEN 'DELETE' THEN EXECUTE format('DELETE FROM public.%I',v_table);
            WHEN 'TRUNCATE' THEN EXECUTE format('TRUNCATE public.%I',v_table);
          END CASE;
        EXCEPTION WHEN insufficient_privilege THEN v_failed:=true;END;
        IF NOT v_failed THEN RAISE EXCEPTION 'Live direct table mutation opened';END IF;v_passed:=v_passed+1;
      END LOOP;
    END LOOP;
    IF v_api_role='anon' THEN
      v_failed:=false;BEGIN PERFORM public.boss_admin_mutate('[{"operation":"person.create","input":{"display_name":"Synthetic Phase2B Live Denied"}}]',gen_random_uuid());
        EXCEPTION WHEN insufficient_privilege THEN v_failed:=true;END;
      IF NOT v_failed THEN RAISE EXCEPTION 'Anonymous RPC execute opened';END IF;v_passed:=v_passed+1;
    END IF;
    EXECUTE 'RESET ROLE';
  END LOOP;
  IF has_table_privilege('authenticated','boss_private.admin_operation_receipts','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
    OR NOT (SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid='boss_private.admin_operation_receipts'::regclass)
    OR has_function_privilege('anon','public.boss_admin_read(text,uuid,text)','EXECUTE') THEN RAISE EXCEPTION 'Private/API boundary changed';END IF;v_passed:=v_passed+1;

  EXECUTE 'SET LOCAL ROLE authenticated';
  -- A successful authorized org/member/role flow and family flow execute RPCs.
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase2b-live:auth:platform')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase2b-live:session:platform')::uuid)::text,true);
  v_request:=md5('boss-phase2b-live:request:organization')::uuid;
  v_commands:=jsonb_build_array(
    jsonb_build_object('operation','organization.create','ref','organization','input',jsonb_build_object('name','Synthetic Phase2B Live Created Organization','slug','synthetic-phase2b-live-created')),
    jsonb_build_object('operation','organization_membership.add','input',jsonb_build_object('organization_id',jsonb_build_object('$ref','organization'),'person_id','2d3a03f4-4ed7-edd3-a7ff-7db9cc6a5916')),
    jsonb_build_object('operation','role_assignment.add','input',jsonb_build_object('person_id','2d3a03f4-4ed7-edd3-a7ff-7db9cc6a5916','role_id',(SELECT r.id FROM public.roles r WHERE r.key='organization_administrator'),'scope_type','organization','organization_id',jsonb_build_object('$ref','organization'),'scope_id',jsonb_build_object('$ref','organization'))));
  v_result:=public.boss_admin_mutate(v_commands,v_request);v_created_org:=(v_result->'results'->0->>'resource_id')::uuid;
  IF jsonb_array_length(v_result->'results')<>3 OR NOT EXISTS(SELECT 1 FROM public.organizations o WHERE o.id=v_created_org) THEN RAISE EXCEPTION 'A platform organization workflow failed';END IF;v_passed:=v_passed+1;
  v_before_audits:=(SELECT count(*) FROM public.audit_events a WHERE a.request_id=v_request);
  v_repeat:=public.boss_admin_mutate(v_commands,v_request);
  IF v_repeat<>v_result OR (SELECT count(*) FROM public.audit_events a WHERE a.request_id=v_request)<>v_before_audits OR v_before_audits<>3 THEN RAISE EXCEPTION 'Idempotent replay duplicated result/audit';END IF;v_passed:=v_passed+1;
  v_failed:=false;BEGIN PERFORM public.boss_admin_mutate('[{"operation":"person.create","input":{"display_name":"Synthetic Phase2B Live Changed Replay"}}]',v_request);EXCEPTION WHEN sqlstate 'PT409' THEN v_failed:=true;END;
  IF NOT v_failed THEN RAISE EXCEPTION 'Changed replay was accepted';END IF;v_passed:=v_passed+1;
  v_commands:='[{"operation":"person.create","ref":"adult","input":{"display_name":"Synthetic Phase2B Live New Adult"}},{"operation":"household.create","ref":"family","input":{"name":"Synthetic Phase2B Live New Family"}},{"operation":"person.create","ref":"child","input":{"display_name":"Synthetic Phase2B Live New Child"}},{"operation":"participant.create","input":{"person_id":{"$ref":"child"},"participant_type":"athlete"}},{"operation":"household_membership.add","input":{"household_id":{"$ref":"family"},"person_id":{"$ref":"child"},"relationship_type":"child"}},{"operation":"guardian.create","ref":"guardian","input":{"guardian_person_id":{"$ref":"adult"},"dependent_person_id":{"$ref":"child"},"can_manage_profile":true}},{"operation":"guardian.verify","input":{"id":{"$ref":"guardian"}}}]';
  v_request:=md5('boss-phase2b-live:request:family')::uuid;v_result:=public.boss_admin_mutate(v_commands,v_request);
  v_created_person:=(v_result->'results'->2->>'resource_id')::uuid;v_created_participant:=(v_result->'results'->3->>'resource_id')::uuid;
  v_created_guardian:=(v_result->'results'->5->>'resource_id')::uuid;
  IF jsonb_array_length(v_result->'results')<>7 OR NOT EXISTS(SELECT 1 FROM public.participants p WHERE p.id=v_created_participant AND p.person_id=v_created_person)
    OR EXISTS(SELECT 1 FROM public.user_accounts a WHERE a.person_id=v_created_person) OR NOT EXISTS(SELECT 1 FROM public.guardian_relationships g WHERE g.id=v_created_guardian AND g.verified_at IS NOT NULL) THEN RAISE EXCEPTION 'J no-Auth family participant workflow failed';END IF;v_passed:=v_passed+1;
  IF EXISTS(SELECT 1 FROM public.audit_events a WHERE a.request_id=v_request AND (a.actor_person_id<>'2d3a03f4-4ed7-edd3-a7ff-7db9cc6a5916' OR a.action NOT IN ('person.create','household.create','participant.create','household_membership.add','guardian.create','guardian.verify') OR a.after_data IS NULL OR a.after_data ? 'display_name' OR a.after_data ? 'email' OR a.before_data IS NOT NULL))
    OR (SELECT count(*) FROM public.audit_events a WHERE a.request_id=v_request)<>7 THEN RAISE EXCEPTION 'P safe correct audit capture failed';END IF;v_passed:=v_passed+1;
  v_read:=public.boss_admin_read('families',null,null);
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_read->'records'->'households') h WHERE h->>'id'=(v_result->'results'->1->>'resource_id')) THEN RAISE EXCEPTION 'Protected family projection failed';END IF;v_passed:=v_passed+1;

  FOR v_case IN SELECT * FROM (VALUES
    ('B ordinary organization create','ordinary','organization.create','{"name":"Synthetic Phase2B Live Denied Org","slug":"synthetic-phase2b-live-denied"}'::jsonb,ARRAY['PT403']::text[]),
    ('D other organization mutate','org-admin','organization.update','{"id":"97b2512d-d137-c684-7b9d-a61b218d7362","name":"Denied cross tenant"}'::jsonb,ARRAY['PT403']::text[]),
    ('E exact unit sibling mutate','unit-admin','team.update','{"id":"449b0277-6889-92b4-929d-74bdf9e3164e","name":"Denied sibling"}'::jsonb,ARRAY['PT403']::text[]),
    ('E exact unit sibling participant denied','unit-admin','participant.create','{"person_id":"c0f00eda-0c1f-bcd6-578b-a693d672d0c9","organization_id":"441e1a5f-e1d8-3ee7-7d5e-febbb9ee242e"}'::jsonb,ARRAY['PT403']::text[]),
    ('F coach unrelated team mutate','coach','team.update','{"id":"f0c8118b-794e-da8d-0fdc-900777e162ac","name":"Denied other team"}'::jsonb,ARRAY['PT403']::text[]),
    ('G household A cannot claim B','household-only','household.update','{"id":"e5e8f91f-f3eb-7b70-625b-6b82ac1703e8","name":"Denied other household"}'::jsonb,ARRAY['PT403']::text[]),
    ('H household membership not guardian','household-only','person.update','{"id":"1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6","display_name":"Denied inferred guardian"}'::jsonb,ARRAY['PT403']::text[]),
    ('I unrelated guardian flag','wrong-flag','person.update','{"id":"1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6","display_name":"Denied wrong flag"}'::jsonb,ARRAY['PT403']::text[]),
    ('I guardian cannot grant capability','guardian','guardian.update','{"id":"bfd2ad88-1d56-1ab8-3d34-a99f35c99752","can_manage_payments":true}'::jsonb,ARRAY['PT403']::text[]),
    ('K organization to platform escalation','org-admin','role_assignment.add','{"person_id":"dffcc392-f1fc-4665-1247-67656d3fddb2","role_id":"$platform_role","scope_type":"platform"}'::jsonb,ARRAY['PT403']::text[]),
    ('L no grant of unheld permission','org-admin','role_assignment.add','{"person_id":"1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6","role_id":"112af57f-f580-1597-8072-796ffa264916","scope_type":"team","scope_id":"7831d147-7ed3-05dd-7be6-83ebc29f7e91","organization_id":"441e1a5f-e1d8-3ee7-7d5e-febbb9ee242e"}'::jsonb,ARRAY['PT403']::text[]),
    ('M expired role denied','expired','organization.update','{"id":"441e1a5f-e1d8-3ee7-7d5e-febbb9ee242e","name":"Denied expired role"}'::jsonb,ARRAY['PT403']::text[]),
    ('M inactive role denied','inactive','organization.update','{"id":"441e1a5f-e1d8-3ee7-7d5e-febbb9ee242e","name":"Denied inactive role"}'::jsonb,ARRAY['PT403']::text[]),
    ('N module does not grant authority','ordinary','team.update','{"id":"7831d147-7ed3-05dd-7be6-83ebc29f7e91","name":"Denied module authority"}'::jsonb,ARRAY['PT403']::text[]),
    ('R forged role context','org-admin','role_assignment.add','{"person_id":"1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6","role_id":"$coach_role","scope_type":"team","scope_id":"f0c8118b-794e-da8d-0fdc-900777e162ac","organization_id":"441e1a5f-e1d8-3ee7-7d5e-febbb9ee242e"}'::jsonb,ARRAY['PT422']::text[]),
    ('R participant person mismatch','org-admin','team_membership.add','{"team_id":"7831d147-7ed3-05dd-7be6-83ebc29f7e91","person_id":"1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6","participant_id":"af290a00-df2c-84c3-352a-b7c15f5c7da7","membership_type":"synthetic_mismatch"}'::jsonb,ARRAY['PT422']::text[]),
    ('R forbidden sensitive profile field','platform','person.update','{"id":"1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6","date_of_birth":"2000-01-01"}'::jsonb,ARRAY['PT422']::text[]),
    ('strict unmapped core denied','unmapped','organization.create','{"name":"Denied unmapped","slug":"synthetic-phase2b-live-unmapped"}'::jsonb,ARRAY['PT403']::text[]),
    ('strict unconfirmed auth denied','unconfirmed','person.create','{"display_name":"Denied unconfirmed"}'::jsonb,ARRAY['PT401']::text[]),
    ('strict anonymous auth denied','anonymous','person.create','{"display_name":"Denied anonymous"}'::jsonb,ARRAY['PT401']::text[]),
    ('strict banned auth denied','banned','person.create','{"display_name":"Denied banned"}'::jsonb,ARRAY['PT401']::text[]),
    ('duplicate active membership denied','platform','organization_membership.add','{"organization_id":"441e1a5f-e1d8-3ee7-7d5e-febbb9ee242e","person_id":"1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6","membership_type":"member"}'::jsonb,ARRAY['PT409']::text[])
  ) f(label,actor,operation,input,states) LOOP
    PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase2b-live:auth:'||v_case.actor)::uuid,'role','authenticated','is_anonymous',false,
      'session_id',md5('boss-phase2b-live:session:'||v_case.actor)::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);
    v_input:=v_case.input;
    IF v_input->>'role_id'='$platform_role' THEN v_input:=jsonb_set(v_input,'{role_id}',to_jsonb((SELECT r.id FROM public.roles r WHERE r.key='platform_administrator')));END IF;
    IF v_input->>'role_id'='$coach_role' THEN v_input:=jsonb_set(v_input,'{role_id}',to_jsonb((SELECT r.id FROM public.roles r WHERE r.key='head_coach')));END IF;
    v_failed:=false;v_state:=null;
    BEGIN
      PERFORM public.boss_admin_mutate(jsonb_build_array(jsonb_build_object('operation',v_case.operation,'input',v_input)),gen_random_uuid());
    EXCEPTION WHEN OTHERS THEN
      IF SQLSTATE=ANY(v_case.states) THEN v_failed:=true;v_state:=SQLERRM;
      ELSE RAISE EXCEPTION 'Live % failed with unexpected safe code %',v_case.label,SQLSTATE;END IF;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION 'Live denial missing: %',v_case.label;END IF;v_passed:=v_passed+1;
    IF length(v_state)>100 OR v_state ~* '(constraint|relation|column|SQL|stack|password|token|SELECT|INSERT|UPDATE|DELETE)' THEN RAISE EXCEPTION 'Live unsafe denial envelope';END IF;v_passed:=v_passed+1;
  END LOOP;
  FOR v_case IN SELECT * FROM (VALUES
    ('C own organization update','org-admin','organization.update','{"id":"441e1a5f-e1d8-3ee7-7d5e-febbb9ee242e","name":"Synthetic Phase2B Live Organization A Edited"}'::jsonb),
    ('E exact unit team update','unit-admin','team.update','{"id":"7831d147-7ed3-05dd-7be6-83ebc29f7e91","name":"Synthetic Phase2B Live Team A Edited"}'::jsonb),
    ('F own coach team update','coach','team.update','{"id":"7831d147-7ed3-05dd-7be6-83ebc29f7e91","short_name":"Synthetic live coach"}'::jsonb),
    ('I verified profile name update','guardian','person.update','{"id":"1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6","display_name":"Synthetic Phase2B Live dependent edited"}'::jsonb),
    ('J scoped no-Auth participant create','unit-admin','participant.create','{"person_id":"b16cf54a-431e-78ff-2428-6a9602eef270","organization_id":"441e1a5f-e1d8-3ee7-7d5e-febbb9ee242e","participant_type":"athlete"}'::jsonb)
  ) f(label,actor,operation,input) LOOP
    PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase2b-live:auth:'||v_case.actor)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase2b-live:session:'||v_case.actor)::uuid)::text,true);
    v_result:=public.boss_admin_mutate(jsonb_build_array(jsonb_build_object('operation',v_case.operation,'input',v_case.input)),gen_random_uuid());
    IF jsonb_array_length(v_result->'results')<>1 THEN RAISE EXCEPTION 'Live positive result malformed: %',v_case.label;END IF;v_passed:=v_passed+1;
  END LOOP;

  -- Scoped names are readable, underlying sensitive canonical row stays denied.
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase2b-live:auth:coach')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase2b-live:session:coach')::uuid)::text,true);
  v_read:=public.boss_admin_read('people',v_org_a,null);
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_read->'records'->'people') p WHERE p->>'id'='1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6')
    OR EXISTS(SELECT 1 FROM public.people p WHERE p.id='1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6')
    OR v_read::text ~ '"(date_of_birth|primary_email|primary_phone)"' THEN RAISE EXCEPTION 'Scoped safe-name/private-profile boundary failed';END IF;v_passed:=v_passed+1;
  v_failed:=false;BEGIN PERFORM public.boss_admin_read('people',null,'Synthetic');EXCEPTION WHEN sqlstate 'PT403' THEN v_failed:=true;END;
  IF NOT v_failed THEN RAISE EXCEPTION 'Ordinary scoped actor global search opened';END IF;v_passed:=v_passed+1;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase2b-live:auth:household-only')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase2b-live:session:household-only')::uuid)::text,true);
  IF NOT EXISTS(SELECT 1 FROM public.households h WHERE h.id=v_household_a) OR EXISTS(SELECT 1 FROM public.households h WHERE h.id=v_household_b) OR EXISTS(SELECT 1 FROM public.people p WHERE p.id='1bcf9eb6-3d1e-1d2b-40e9-3b3c3abfebd6') THEN RAISE EXCEPTION 'Household private isolation failed';END IF;v_passed:=v_passed+1;

  -- Q: a later invalid command rolls back earlier record/audit/receipt writes.
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase2b-live:auth:platform')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase2b-live:session:platform')::uuid)::text,true);
  v_request:=md5('boss-phase2b-live:request:rollback')::uuid;
  v_failed:=false;BEGIN
    PERFORM public.boss_admin_mutate('[{"operation":"person.create","ref":"person","input":{"display_name":"Synthetic Phase2B Live Rollback Child"}},{"operation":"participant.create","input":{"person_id":{"$ref":"person"}}},{"operation":"household_membership.add","input":{"household_id":"ffffffff-ffff-ffff-ffff-ffffffffffff","person_id":{"$ref":"person"}}}]',v_request);
  EXCEPTION WHEN sqlstate 'PT422' OR sqlstate 'PT403' THEN v_failed:=true;END;
  IF NOT v_failed OR EXISTS(SELECT 1 FROM public.people p WHERE p.display_name='Synthetic Phase2B Live Rollback Child') OR EXISTS(SELECT 1 FROM public.audit_events a WHERE a.request_id=v_request) THEN RAISE EXCEPTION 'Q partial transaction escaped rollback';END IF;v_passed:=v_passed+1;
  EXECUTE 'RESET ROLE';
  IF EXISTS(SELECT 1 FROM boss_private.admin_operation_receipts r WHERE r.request_id=v_request) THEN RAISE EXCEPTION 'Q failed request receipt persisted';END IF;v_passed:=v_passed+1;
  SELECT count(*) INTO v_before_receipts FROM boss_private.admin_operation_receipts r WHERE r.actor_person_id='2d3a03f4-4ed7-edd3-a7ff-7db9cc6a5916';
  IF v_before_receipts<2 THEN RAISE EXCEPTION 'Successful requests have no protected receipts';END IF;v_passed:=v_passed+1;

  -- Explicit first account link is actor-bound, audited and cannot rebind.
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_request:=md5('boss-phase2b-live:request:link')::uuid;
  v_result:=public.boss_admin_mutate(jsonb_build_array(jsonb_build_object('operation','account.link','input',jsonb_build_object('person_id','d348a932-b45c-095e-48f5-8d8e9e892dce','auth_user_id',md5('boss-phase2b-live:auth:link-auth')::uuid))),v_request);
  v_created_account:=(v_result->'results'->0->>'resource_id')::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.user_accounts a WHERE a.id=v_created_account AND a.person_id='d348a932-b45c-095e-48f5-8d8e9e892dce' AND a.account_status='active') OR (SELECT count(*) FROM public.audit_events a WHERE a.request_id=v_request AND a.action='account.link')<>1 THEN RAISE EXCEPTION 'Explicit link/audit failed';END IF;v_passed:=v_passed+1;
  v_failed:=false;BEGIN PERFORM public.boss_admin_mutate(jsonb_build_array(jsonb_build_object('operation','account.link','input',jsonb_build_object('person_id','eee9b516-89e6-a8b9-d727-84e140364667','auth_user_id',md5('boss-phase2b-live:auth:link-auth')::uuid))),gen_random_uuid());EXCEPTION WHEN sqlstate 'PT409' THEN v_failed:=true;END;
  IF NOT v_failed THEN RAISE EXCEPTION 'Account mapping rebind allowed';END IF;v_passed:=v_passed+1;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase2b-live:auth:unmapped')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase2b-live:session:unmapped')::uuid)::text,true);
  v_read:=public.boss_admin_read('home',null,null);
  IF v_read->>'provisioned'<>'false' OR jsonb_array_length(v_read->'organizations')<>0 THEN RAISE EXCEPTION 'Unmapped identity saw core context';END IF;v_passed:=v_passed+1;
  v_request:=md5('boss-phase2b-live:request:self')::uuid;v_commands:='[{"operation":"identity.provision_self","input":{"display_name":"Synthetic Phase2B Live Self Provisioned"}}]';
  v_result:=public.boss_admin_mutate(v_commands,v_request);v_created_person:=(v_result->'results'->0->>'resource_id')::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.user_accounts a WHERE a.person_id=v_created_person AND a.auth_user_id=md5('boss-phase2b-live:auth:unmapped')::uuid) OR EXISTS(SELECT 1 FROM public.role_assignments a WHERE a.person_id=v_created_person) THEN RAISE EXCEPTION 'Explicit self provisioning silently granted role';END IF;v_passed:=v_passed+1;
  v_repeat:=public.boss_admin_mutate(v_commands,v_request);
  IF v_repeat<>v_result THEN RAISE EXCEPTION 'Self provisioning replay changed identity';END IF;v_passed:=v_passed+1;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase2b-live:auth:platform')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase2b-live:session:platform')::uuid)::text,true);
  EXECUTE 'RESET ROLE';

  -- Actual managed-session removal invalidates the next protected operation.
  DELETE FROM auth.sessions s WHERE s.id=md5('boss-phase2b-live:session:platform')::uuid;
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_failed:=false;BEGIN PERFORM public.boss_admin_mutate('[{"operation":"person.create","input":{"display_name":"Denied removed session"}}]',gen_random_uuid());EXCEPTION WHEN sqlstate 'PT401' THEN v_failed:=true;END;
  IF NOT v_failed THEN RAISE EXCEPTION 'Removed session accepted';END IF;v_passed:=v_passed+1;
  EXECUTE 'RESET ROLE';
  -- Audit history remains append-only even to the trusted migration owner.
  v_failed:=false;BEGIN UPDATE public.audit_events a SET action=action WHERE a.request_id=md5('boss-phase2b-live:request:family')::uuid;EXCEPTION WHEN check_violation THEN v_failed:=true;END;
  IF NOT v_failed THEN RAISE EXCEPTION 'Audit rewrite allowed';END IF;v_passed:=v_passed+1;
  PERFORM set_config('boss.phase2b_live_passed',v_passed::text,true);
END;
$live$;
SELECT current_setting('boss.phase2b_live_passed')::integer AS passed_assertions;
ROLLBACK;
SELECT
  (SELECT count(*) FROM public.people p WHERE p.display_name LIKE 'Synthetic Phase2B Live %') AS synthetic_people_remaining,
  (SELECT count(*) FROM public.organizations o WHERE o.slug LIKE 'synthetic-phase2b-live-%') AS synthetic_organizations_remaining,
  (SELECT count(*) FROM public.households h WHERE h.name LIKE 'Synthetic Phase2B Live %') AS synthetic_households_remaining,
  (SELECT count(*) FROM public.audit_events a WHERE a.actor_person_id='2d3a03f4-4ed7-edd3-a7ff-7db9cc6a5916') AS synthetic_audits_remaining,
  (SELECT count(*) FROM boss_private.admin_operation_receipts r WHERE r.actor_person_id='2d3a03f4-4ed7-edd3-a7ff-7db9cc6a5916') AS synthetic_receipts_remaining,
  (SELECT count(*) FROM auth.users u WHERE u.email LIKE '%@phase2b-live.example.invalid') AS synthetic_auth_users_remaining,
  (SELECT count(*) FROM auth.sessions s WHERE s.user_id IN (SELECT md5('boss-phase2b-live:auth:'||label)::uuid FROM unnest(ARRAY['platform','ordinary','org-admin','unit-admin','coach','household-only','guardian','wrong-flag','expired','inactive','unmapped','link-auth','unconfirmed','anonymous','banned','dependent','target-a','target-b','target-unit','target-sibling','link-person']) label)) AS synthetic_sessions_remaining;
