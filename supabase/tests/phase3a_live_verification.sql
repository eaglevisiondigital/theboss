-- Phase 3A canonical DML-only live verification. No DDL or real credentials.
-- Synthetic Auth/session facts model database roles, not signed HTTP acceptance.
-- One atomic DO block, explicit ROLLBACK, and prefix-scoped cleanup projections.
BEGIN;

DO $live$
DECLARE
 v_passed integer:=0;
v_results jsonb:='{}';
v_result jsonb;
v_command jsonb;
v_failed boolean;
v_safe boolean;

 v_label text;
v_role text;
v_table text;
v_column text;
v_action text;
v_n integer;
v_data jsonb;

BEGIN
 IF EXISTS(select 1 from public.people where display_name like 'Synthetic Phase3A Live %')
  OR EXISTS(select 1 from public.organizations where slug like 'synthetic-phase3a-live-%')
  OR EXISTS(select 1 from auth.users where email like '%@phase3a-live.example.invalid')
  OR EXISTS(select 1 from auth.sessions where user_id in(select md5('boss-phase3a-live:auth-'||label)::uuid from unnest(array['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label))
 THEN RAISE EXCEPTION 'Synthetic live fixture collision';
END IF;
v_passed:=v_passed+1;

-- Exact new public schema and API grants, independently asserted.
IF NOT coalesce(((SELECT count(*)=30 FROM pg_catalog.pg_tables WHERE schemaname='public' AND tablename IN ('people','user_accounts','households','participants','organizations','organization_units','seasons','teams','organization_memberships','team_memberships','household_memberships','guardian_relationships','roles','permissions','role_permissions','role_assignments','modules','organization_modules','entitlements','feature_flags','feature_flag_overrides','audit_events','event_types','venues','venue_resources','events','event_targets','event_game_details','event_occurrence_exceptions','event_reminders'))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','exact exposed table count';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT array_agg(key ORDER BY key)=ARRAY['events.create','events.manage','events.override_conflict','events.publish','events.view'] FROM public.permissions WHERE key LIKE 'events.%')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','five finite calendar permissions';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=12 FROM public.event_types)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','twelve centrally governed types';
END IF;
v_passed:=v_passed+1;

DECLARE tab text;
action text;
role_name text;
denied boolean;
BEGIN
 FOREACH tab IN ARRAY ARRAY['event_types','venues','venue_resources','events','event_targets','event_game_details','event_occurrence_exceptions','event_reminders'] LOOP
  IF NOT coalesce(((SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid=('public.'||tab)::regclass)),false) THEN RAISE EXCEPTION 'Live assertion failed: %',tab||' RLS';
END IF;
v_passed:=v_passed+1;

  IF NOT coalesce((has_table_privilege('authenticated','public.'||tab,'SELECT') AND NOT has_table_privilege('authenticated','public.'||tab,'INSERT,UPDATE,DELETE,TRUNCATE')),false) THEN RAISE EXCEPTION 'Live assertion failed: %',tab||' authenticated read only';
END IF;
v_passed:=v_passed+1;

  IF NOT coalesce((NOT has_table_privilege('anon','public.'||tab,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE')),false) THEN RAISE EXCEPTION 'Live assertion failed: %',tab||' anon table closed';
END IF;
v_passed:=v_passed+1;

  IF NOT coalesce((NOT EXISTS(SELECT 1 FROM pg_catalog.pg_policies WHERE schemaname='public' AND tablename=tab AND cmd<>'SELECT')),false) THEN RAISE EXCEPTION 'Live assertion failed: %',tab||' no mutation policies';
END IF;
v_passed:=v_passed+1;

 END LOOP;

 IF NOT coalesce((NOT EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','no public definers';
END IF;
v_passed:=v_passed+1;

 IF NOT coalesce((NOT has_function_privilege('anon','public.boss_calendar_mutate(jsonb,uuid)','EXECUTE')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','anon mutate denied';
END IF;
v_passed:=v_passed+1;

 IF NOT coalesce((NOT has_function_privilege('anon','public.boss_calendar_read(jsonb)','EXECUTE')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','anon private read denied';
END IF;
v_passed:=v_passed+1;

END;

INSERT INTO auth.users(id,email,email_confirmed_at,is_anonymous)
SELECT (md5('boss-phase3a-live:'||('auth-'||label))::uuid),label||'@phase3a-live.example.invalid',CASE WHEN label='unconfirmed' THEN NULL ELSE now()-interval '1 day' END,false
FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label;

INSERT INTO auth.sessions(id,user_id) SELECT (md5('boss-phase3a-live:'||('session-'||label))::uuid),(md5('boss-phase3a-live:'||('auth-'||label))::uuid) FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label;

INSERT INTO public.people(id,display_name) SELECT (md5('boss-phase3a-live:'||(label))::uuid),'Synthetic Phase3A Live '||label FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label;

INSERT INTO public.user_accounts(auth_user_id,person_id,account_status) SELECT (md5('boss-phase3a-live:'||('auth-'||label))::uuid),(md5('boss-phase3a-live:'||(label))::uuid),'active' FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label;

INSERT INTO public.organizations(id,name,slug) VALUES((md5('boss-phase3a-live:'||('org-a'))::uuid),'Synthetic Phase3A Live Organization A','synthetic-phase3a-live-a'),((md5('boss-phase3a-live:'||('org-b'))::uuid),'Synthetic Phase3A Live Organization B','synthetic-phase3a-live-b');

INSERT INTO public.organization_units(id,organization_id,parent_unit_id,unit_type,name,slug) VALUES
((md5('boss-phase3a-live:'||('unit-a'))::uuid),(md5('boss-phase3a-live:'||('org-a'))::uuid),NULL,'sport','Synthetic Phase3A Live Unit A','a'),((md5('boss-phase3a-live:'||('unit-sibling'))::uuid),(md5('boss-phase3a-live:'||('org-a'))::uuid),NULL,'sport','Synthetic Phase3A Live Sibling','sibling'),((md5('boss-phase3a-live:'||('unit-child'))::uuid),(md5('boss-phase3a-live:'||('org-a'))::uuid),(md5('boss-phase3a-live:'||('unit-a'))::uuid),'program','Synthetic Phase3A Live Child Unit','child'),((md5('boss-phase3a-live:'||('unit-b'))::uuid),(md5('boss-phase3a-live:'||('org-b'))::uuid),NULL,'sport','Synthetic Phase3A Live Unit B','b');

INSERT INTO public.seasons(id,organization_id,parent_unit_id,name,starts_on,ends_on) VALUES((md5('boss-phase3a-live:'||('season-a'))::uuid),(md5('boss-phase3a-live:'||('org-a'))::uuid),(md5('boss-phase3a-live:'||('unit-a'))::uuid),'Synthetic Phase3A Live season','2026-01-01','2026-12-31');

INSERT INTO public.teams(id,organization_id,parent_unit_id,season_id,name,slug,visibility,status)
SELECT (md5('boss-phase3a-live:'||('team'||n))::uuid),(md5('boss-phase3a-live:'||('org-a'))::uuid),CASE WHEN n<=3 THEN (md5('boss-phase3a-live:'||('unit-a'))::uuid) WHEN n=4 THEN (md5('boss-phase3a-live:'||('unit-child'))::uuid) ELSE (md5('boss-phase3a-live:'||('unit-sibling'))::uuid) END,CASE WHEN n<=3 THEN (md5('boss-phase3a-live:'||('season-a'))::uuid) END,'Synthetic Phase3A Live Team '||n,'team-'||n,CASE WHEN n=1 THEN 'public' ELSE 'private' END,'active' FROM generate_series(1,23)n;

INSERT INTO public.teams(id,organization_id,parent_unit_id,name,slug,status) VALUES((md5('boss-phase3a-live:'||('team-b'))::uuid),(md5('boss-phase3a-live:'||('org-b'))::uuid),(md5('boss-phase3a-live:'||('unit-b'))::uuid),'Synthetic Phase3A Live Team B','b','active');

INSERT INTO public.organization_modules(organization_id,module_id,status,starts_at,configuration)
SELECT (md5('boss-phase3a-live:'||(org))::uuid),m.id,'active',now()-interval '1 day','{"organization_calendar":true,"team_calendar":true,"recurrence":true,"conflicts":true,"public_schedules":true,"head_coach_management":true,"conflict_overrides":true}' FROM public.modules m CROSS JOIN unnest(ARRAY['org-a','org-b'])org WHERE m.key='calendar';

INSERT INTO public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at,ends_at)
SELECT (md5('boss-phase3a-live:'||(p))::uuid),r.id,scope,(md5('boss-phase3a-live:'||(target))::uuid),(md5('boss-phase3a-live:'||(org))::uuid),now()-interval '2 days',CASE WHEN p='expired' THEN now()-interval '1 day' END FROM (VALUES('admin-a','organization_administrator','organization','org-a','org-a'),('admin-b','organization_administrator','organization','org-b','org-b'),('unit','program_administrator','organization_unit','unit-a','org-a'),('coach','head_coach','team','team1','org-a'),('assistant','assistant_coach','team','team1','org-a'),('expired','organization_administrator','organization','org-a','org-a'))v(p,role,scope,target,org) JOIN public.roles r ON r.key=v.role;

INSERT INTO public.organization_memberships(organization_id,person_id,membership_type,starts_at)
SELECT (md5('boss-phase3a-live:'||('org-a'))::uuid),(md5('boss-phase3a-live:'||(p))::uuid),'member',now()-interval '1 day' FROM unnest(ARRAY['member','child1','child2','child3','coach','assistant','unit'])p;

INSERT INTO public.participants(id,person_id,participant_type) SELECT (md5('boss-phase3a-live:'||('participant'||n))::uuid),(md5('boss-phase3a-live:'||('child'||n))::uuid),'athlete' FROM generate_series(1,3)n;

INSERT INTO public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at)
SELECT (md5('boss-phase3a-live:'||('org-a'))::uuid),(md5('boss-phase3a-live:'||('team'||n))::uuid),(md5('boss-phase3a-live:'||('child'||n))::uuid),(md5('boss-phase3a-live:'||('participant'||n))::uuid),'athlete',now()-interval '1 day' FROM generate_series(1,3)n;

INSERT INTO public.team_memberships(organization_id,team_id,person_id,membership_type,starts_at) VALUES((md5('boss-phase3a-live:'||('org-a'))::uuid),(md5('boss-phase3a-live:'||('team1'))::uuid),(md5('boss-phase3a-live:'||('coach'))::uuid),'coach',now()-interval '1 day'),((md5('boss-phase3a-live:'||('org-a'))::uuid),(md5('boss-phase3a-live:'||('team1'))::uuid),(md5('boss-phase3a-live:'||('assistant'))::uuid),'coach',now()-interval '1 day');

INSERT INTO public.households(id,name) VALUES((md5('boss-phase3a-live:'||('household'))::uuid),'Synthetic Phase3A Live household');

INSERT INTO public.household_memberships(household_id,person_id,relationship_type,starts_at) SELECT (md5('boss-phase3a-live:'||('household'))::uuid),(md5('boss-phase3a-live:'||(p))::uuid),'member',now()-interval '1 day' FROM unnest(ARRAY['household-only','guardian','child1','child2','child3'])p;

INSERT INTO public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,starts_at,verified_at)
SELECT (md5('boss-phase3a-live:'||('guardian'||n))::uuid),(md5('boss-phase3a-live:'||('guardian'))::uuid),(md5('boss-phase3a-live:'||('child'||n))::uuid),'active',now()-interval '1 day',now()-interval '1 day' FROM generate_series(1,3)n;

 -- Every new table is exercised under the actual API roles. Permission checks
 -- occur before constraints even for empty or malformed direct writes.
 FOREACH v_role IN ARRAY array['anon','authenticated'] LOOP
  EXECUTE format('SET LOCAL ROLE %I',v_role);

  PERFORM set_config('request.jwt.claims',case when v_role='anon' then '{}' else
   jsonb_build_object('sub',md5('boss-phase3a-live:auth-admin-a')::uuid,'role','authenticated','is_anonymous',false,
    'session_id',md5('boss-phase3a-live:session-admin-a')::uuid)::text end,true);

  FOREACH v_table IN ARRAY array['event_types','venues','venue_resources','events','event_targets','event_game_details','event_occurrence_exceptions','event_reminders'] LOOP
   IF v_role='anon' THEN
    v_failed:=false;

    BEGIN EXECUTE format('SELECT count(*) FROM public.%I',v_table);

    EXCEPTION WHEN insufficient_privilege THEN v_failed:=true;
END;

    IF NOT v_failed THEN RAISE EXCEPTION 'Anonymous table read opened';
END IF;
v_passed:=v_passed+1;

   END IF;

   SELECT attname INTO v_column FROM pg_catalog.pg_attribute WHERE attrelid=('public.'||v_table)::regclass AND attnum>0 AND NOT attisdropped ORDER BY attnum LIMIT 1;

   FOREACH v_action IN ARRAY array['INSERT','UPDATE','DELETE','TRUNCATE'] LOOP
    v_failed:=false;

    BEGIN
     CASE v_action
      WHEN 'INSERT' THEN EXECUTE format('INSERT INTO public.%I DEFAULT VALUES',v_table);

      WHEN 'UPDATE' THEN EXECUTE format('UPDATE public.%I SET %I=%I WHERE false',v_table,v_column,v_column);

      WHEN 'DELETE' THEN EXECUTE format('DELETE FROM public.%I WHERE false',v_table);

      WHEN 'TRUNCATE' THEN EXECUTE format('TRUNCATE public.%I',v_table);

     END CASE;

    EXCEPTION WHEN insufficient_privilege THEN v_failed:=true;
END;

    IF NOT v_failed THEN RAISE EXCEPTION 'Direct table mutation opened';
END IF;
v_passed:=v_passed+1;

   END LOOP;

  END LOOP;

  EXECUTE 'RESET ROLE';

 END LOOP;

 IF has_schema_privilege('anon','boss_private','USAGE') THEN RAISE EXCEPTION 'Anonymous private schema access opened';
END IF;
v_passed:=v_passed+1;

 IF has_table_privilege('authenticated','boss_private.calendar_operation_receipts','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
  OR has_table_privilege('anon','boss_private.calendar_operation_receipts','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
  OR NOT (select relrowsecurity from pg_catalog.pg_class where oid='boss_private.calendar_operation_receipts'::regclass)
 THEN RAISE EXCEPTION 'Private receipt boundary changed';
END IF;
v_passed:=v_passed+1;

 IF EXISTS(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  cross join lateral pg_catalog.aclexplode(coalesce(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
  where (n.nspname='boss_private' and p.proname like 'calendar_%' or n.nspname='boss_calendar_public' or n.nspname='public' and p.proname like 'boss_calendar_%')
   and a.grantee=0 and a.privilege_type='EXECUTE')
 THEN RAISE EXCEPTION 'Implicit PUBLIC calendar execution opened';
END IF;
v_passed:=v_passed+1;

 IF EXISTS(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where (n.nspname='boss_private' and p.proname like 'calendar_%' or n.nspname='boss_calendar_public' or n.nspname='public' and p.proname like 'boss_calendar_%')
   and not coalesce('search_path=""'=any(p.proconfig),false))
 THEN RAISE EXCEPTION 'Calendar function search path is mutable';
END IF;
v_passed:=v_passed+1;

 IF has_function_privilege('authenticated','boss_private.calendar_schedule_integrity()','EXECUTE')
  OR has_function_privilege('anon','boss_private.calendar_schedule_integrity()','EXECUTE')
 THEN RAISE EXCEPTION 'Calendar trigger executable by client';
END IF;
v_passed:=v_passed+1;

 IF has_function_privilege('anon','public.boss_calendar_preview(jsonb)','EXECUTE')
  OR NOT has_function_privilege('anon','public.boss_calendar_public_read(jsonb)','EXECUTE')
 THEN RAISE EXCEPTION 'Preview/public function boundary changed';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=23 FROM public.teams WHERE organization_id=(md5('boss-phase3a-live:'||('org-a'))::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','A twenty-three teams no special schema';
END IF;
v_passed:=v_passed+1;

EXECUTE 'SET LOCAL ROLE authenticated';

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('admin-a'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('admin-a'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('organization'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-05T14:00:00Z','end_at','2026-10-05T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','organization','target_id',(md5('boss-phase3a-live:'||('org-a'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('organization event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','organization event';
END IF;
v_results:=v_results||jsonb_build_object('organization event',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('three teams'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',(SELECT jsonb_agg(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team'||n))::uuid))) FROM generate_series(1,3)n),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('three-team event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','three-team event';
END IF;
v_results:=v_results||jsonb_build_object('three-team event',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('one team'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-12T14:00:00Z','end_at','2026-10-12T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('one-team event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','one-team event';
END IF;
v_results:=v_results||jsonb_build_object('one-team event',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('sibling'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-12T14:00:00Z','end_at','2026-10-12T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team23'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('sibling event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','sibling event';
END IF;
v_results:=v_results||jsonb_build_object('sibling event',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('descendant'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-12T14:00:00Z','end_at','2026-10-12T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team4'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('descendant event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','descendant event';
END IF;
v_results:=v_results||jsonb_build_object('descendant event',v_result);
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=1 FROM public.events WHERE id=(coalesce(v_results->('organization event') ->>'resource_id',v_results->('organization event') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','B one organization-wide canonical record';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=1 FROM public.events WHERE id=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','C one multi-team canonical record';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=3 FROM public.event_targets WHERE event_id=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','C three explicit target rows';
END IF;
v_passed:=v_passed+1;

DECLARE n int;
data jsonb;
BEGIN FOR n IN 1..3 LOOP data:=public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','team','organization_id',case when 'team'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when 'team'||n is not null then md5('boss-phase3a-live:'||('team'||n))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)));
IF NOT coalesce((EXISTS(SELECT 1 FROM jsonb_array_elements(data->'occurrences')o WHERE o->>'event_id'=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid)::text)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','D canonical event team view '||n;
END IF;
v_passed:=v_passed+1;
END LOOP;
END;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('guardian'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('guardian'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

DECLARE data jsonb;
n int;
BEGIN data:=public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','personal','organization_id',case when 'personal'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)));
IF NOT coalesce((jsonb_array_length(data->'children')=3),false) THEN RAISE EXCEPTION 'Live assertion failed: %','E three authorized children';
END IF;
v_passed:=v_passed+1;
IF NOT coalesce(((SELECT count(*)=1 FROM jsonb_array_elements(data->'occurrences')o WHERE o->>'event_id'=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid)::text)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','E multi-team occurrence deduplicated';
END IF;
v_passed:=v_passed+1;
FOR n IN 1..3 LOOP data:=public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','personal','organization_id',case when 'personal'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when NULL is not null then md5('boss-phase3a-live:'||(NULL))::uuid end,'child_id',case when 'child'||n is not null then md5('boss-phase3a-live:'||('child'||n))::uuid end)));
IF NOT coalesce((EXISTS(SELECT 1 FROM jsonb_array_elements(data->'occurrences')o WHERE o->>'event_id'=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid)::text)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','F child filter '||n;
END IF;
v_passed:=v_passed+1;
END LOOP;
END;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('household-only'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('household-only'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

IF NOT coalesce((jsonb_array_length(public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','personal','organization_id',case when 'personal'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)))->'children')=0 AND (SELECT count(*)=0 FROM public.events WHERE id=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','W household never implies guardian calendar authority';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('stranger'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('stranger'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

IF NOT coalesce(((SELECT count(*)=0 FROM public.events WHERE id=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','H known event UUID denied';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=0 FROM public.event_targets WHERE event_id=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','H no target IDs leaked';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce((NOT (public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','personal','organization_id',case when 'personal'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)))::text LIKE '%Synthetic instructions%')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','H no private instructions leaked';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('fan'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('fan'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

IF NOT coalesce(((SELECT count(*)=0 FROM public.events WHERE id=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','J no relationship from public team knowledge';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('coach'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('coach'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('denied'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team23'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('sibling event') ->>'resource_id',v_results->('sibling event') ->>'event_id')::uuid),'expected_version',1)),md5('boss-phase3a-live:request-'||('K coach cannot modify sibling team'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'K coach cannot modify sibling team';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','K coach cannot modify sibling team';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','K coach cannot modify sibling team';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('denied'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',(SELECT jsonb_agg(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team'||n))::uuid))) FROM generate_series(1,3)n),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('one-team event') ->>'resource_id',v_results->('one-team event') ->>'event_id')::uuid),'expected_version',1)),md5('boss-phase3a-live:request-'||('K coach cannot add unowned team'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'K coach cannot add unowned team';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','K coach cannot add unowned team';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','K coach cannot add unowned team';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('denied'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('override_conflicts',true)),md5('boss-phase3a-live:request-'||('T coach cannot request conflict override'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT403']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'T coach cannot request conflict override';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','T coach cannot request conflict override';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','T coach cannot request conflict override';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('unit'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('unit'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('denied'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team23'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('sibling event') ->>'resource_id',v_results->('sibling event') ->>'event_id')::uuid),'expected_version',1)),md5('boss-phase3a-live:request-'||('L exact unit cannot mutate sibling'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'L exact unit cannot mutate sibling';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','L exact unit cannot mutate sibling';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','L exact unit cannot mutate sibling';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('denied'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team4'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('descendant event') ->>'resource_id',v_results->('descendant event') ->>'event_id')::uuid),'expected_version',1)),md5('boss-phase3a-live:request-'||('L exact unit no descendant inheritance'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'L exact unit no descendant inheritance';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','L exact unit no descendant inheritance';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','L exact unit no descendant inheritance';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('expired'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('expired'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('denied'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','organization','target_id',(md5('boss-phase3a-live:'||('org-a'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('M expired grant loses scheduling'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'M expired grant loses scheduling';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','M expired grant loses scheduling';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','M expired grant loses scheduling';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('assistant'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('assistant'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('denied'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('assistant view does not imply scheduling'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'assistant view does not imply scheduling';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','assistant view does not imply scheduling';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','assistant view does not imply scheduling';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('admin-b'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('admin-b'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('denied'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('cross-tenant event create denied'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'cross-tenant event create denied';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','cross-tenant event create denied';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','cross-tenant event create denied';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=0 FROM public.events WHERE organization_id=(md5('boss-phase3a-live:'||('org-a'))::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','cross-tenant event read denied';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('unconfirmed'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('unconfirmed'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('denied'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('unconfirmed auth cannot schedule'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT401','PT403']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'unconfirmed auth cannot schedule';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','unconfirmed auth cannot schedule';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','unconfirmed auth cannot schedule';
END IF;
v_passed:=v_passed+1;

EXECUTE 'RESET ROLE';

EXECUTE 'SET LOCAL ROLE authenticated';

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('admin-a'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('admin-a'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_command:=jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('three teams rescheduled'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-10T14:00:00Z','end_at','2026-10-10T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',(SELECT jsonb_agg(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team'||n))::uuid))) FROM generate_series(1,3)n),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid),'expected_version',1));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('G reschedule canonical event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','G reschedule canonical event';
END IF;
v_results:=v_results||jsonb_build_object('G reschedule canonical event',v_result);
v_passed:=v_passed+1;

DECLARE n int;
data jsonb;
BEGIN FOR n IN 1..3 LOOP data:=public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','team','organization_id',case when 'team'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when 'team'||n is not null then md5('boss-phase3a-live:'||('team'||n))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)));
IF NOT coalesce((EXISTS(SELECT 1 FROM jsonb_array_elements(data->'occurrences')o WHERE o->>'event_id'=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid)::text AND (o->>'start_at')::timestamptz='2026-10-10T14:00:00Z'::timestamptz)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','G reschedule propagated team '||n;
END IF;
v_passed:=v_passed+1;
END LOOP;
END;

IF NOT coalesce(((SELECT count(*)=1 FROM public.events WHERE id=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','G still one event after reschedule';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('stale'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid),'expected_version',1)),md5('boss-phase3a-live:request-'||('stale edit rejected'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT409']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'stale edit rejected';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','stale edit rejected';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','stale edit rejected';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('weekly'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-13T14:00:00Z','end_at','2026-10-13T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team2'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||'{"recurrence":{"frequency":"weekly","interval":1,"count":4}}'::jsonb);
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('recurring event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','recurring event';
END IF;
v_results:=v_results||jsonb_build_object('recurring event',v_result);
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=3 FROM jsonb_array_elements(public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','team','organization_id',case when 'team'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when 'team2' is not null then md5('boss-phase3a-live:'||('team2'))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)))->'occurrences')o WHERE o->>'event_id'=(coalesce(v_results->('recurring event') ->>'resource_id',v_results->('recurring event') ->>'event_id')::uuid)::text)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','N bounded weekly expansion';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('recurring event') ->>'resource_id',v_results->('recurring event') ->>'event_id')::uuid),'expected_version',1,'occurrence_key','2026-10-20T09:00:00','override_start_at','2026-10-21T14:00:00Z','override_end_at','2026-10-21T15:00:00Z','status','scheduled'));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('occurrence reschedule'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','occurrence reschedule';
END IF;
v_results:=v_results||jsonb_build_object('occurrence reschedule',v_result);
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=1 FROM jsonb_array_elements(public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','team','organization_id',case when 'team'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when 'team2' is not null then md5('boss-phase3a-live:'||('team2'))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)))->'occurrences')o WHERE o->>'event_id'=(coalesce(v_results->('recurring event') ->>'resource_id',v_results->('recurring event') ->>'event_id')::uuid)::text AND (o->>'start_at')::timestamptz='2026-10-21T14:00:00Z'::timestamptz)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','O only selected occurrence moved';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=1 FROM jsonb_array_elements(public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','team','organization_id',case when 'team'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when 'team2' is not null then md5('boss-phase3a-live:'||('team2'))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)))->'occurrences')o WHERE o->>'event_id'=(coalesce(v_results->('recurring event') ->>'resource_id',v_results->('recurring event') ->>'event_id')::uuid)::text AND (o->>'start_at')::timestamptz='2026-10-13T14:00:00Z'::timestamptz)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','O original first occurrence unchanged';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('recurring event') ->>'resource_id',v_results->('recurring event') ->>'event_id')::uuid),'expected_version',2,'occurrence_key','2026-10-19T09:00:00','status','canceled')),md5('boss-phase3a-live:request-'||('forged exception key denied'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT422']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'forged exception key denied';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','forged exception key denied';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','forged exception key denied';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('recurring event') ->>'resource_id',v_results->('recurring event') ->>'event_id')::uuid),'expected_version',2,'occurrence_key','2026-10-27T09:00:00','status','canceled'));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('occurrence cancel'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','occurrence cancel';
END IF;
v_results:=v_results||jsonb_build_object('occurrence cancel',v_result);
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=1 FROM jsonb_array_elements(public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','team','organization_id',case when 'team'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when 'team2' is not null then md5('boss-phase3a-live:'||('team2'))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)))->'occurrences')o WHERE o->>'event_id'=(coalesce(v_results->('recurring event') ->>'resource_id',v_results->('recurring event') ->>'event_id')::uuid)::text AND o->>'status'='canceled')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','U canceled occurrence retained';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('multi-day'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-23T14:00:00Z','end_at','2026-10-25T19:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team3'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('multi-day event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','multi-day event';
END IF;
v_results:=v_results||jsonb_build_object('multi-day event',v_result);
v_passed:=v_passed+1;

IF NOT coalesce((EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_calendar_read(jsonb_build_object('from','2026-10-24T00:00:00Z','to','2026-10-25T00:00:00Z','view','team','team_id',(md5('boss-phase3a-live:'||('team3'))::uuid)))->'occurrences')o WHERE o->>'event_id'=(coalesce(v_results->('multi-day event') ->>'resource_id',v_results->('multi-day event') ->>'event_id')::uuid)::text)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','Q overlap query includes already-started event';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','venue.create','input',jsonb_build_object('organization_id',(md5('boss-phase3a-live:'||('org-a'))::uuid),'name','Synthetic private facility','timezone','America/Chicago','address_line1','Synthetic PRIVATE address','instructions','Synthetic PRIVATE access instructions','is_public',false));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('private venue'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','private venue';
END IF;
v_results:=v_results||jsonb_build_object('private venue',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','resource.create','input',jsonb_build_object('organization_id',(md5('boss-phase3a-live:'||('org-a'))::uuid),'venue_id',(coalesce(v_results->('private venue') ->>'resource_id',v_results->('private venue') ->>'event_id')::uuid),'name','Synthetic Court 1','resource_type','court','is_public',false));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('court resource'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','court resource';
END IF;
v_results:=v_results||jsonb_build_object('court resource',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('court'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-16T14:00:00Z','end_at','2026-10-16T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team5'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('venue_id',(coalesce(v_results->('private venue') ->>'resource_id',v_results->('private venue') ->>'event_id')::uuid),'resource_id',(coalesce(v_results->('court resource') ->>'resource_id',v_results->('court resource') ->>'event_id')::uuid)));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('court event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','court event';
END IF;
v_results:=v_results||jsonb_build_object('court event',v_result);
v_passed:=v_passed+1;

IF NOT coalesce((jsonb_array_length(public.boss_calendar_preview(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('court overlap'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-16T14:30:00Z','end_at','2026-10-16T15:30:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team6'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('venue_id',(coalesce(v_results->('private venue') ->>'resource_id',v_results->('private venue') ->>'event_id')::uuid),'resource_id',(coalesce(v_results->('court resource') ->>'resource_id',v_results->('court resource') ->>'event_id')::uuid))))->'conflicts')>0),false) THEN RAISE EXCEPTION 'Live assertion failed: %','R court conflict preview';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('court denied'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-16T14:30:00Z','end_at','2026-10-16T15:30:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team6'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('venue_id',(coalesce(v_results->('private venue') ->>'resource_id',v_results->('private venue') ->>'event_id')::uuid),'resource_id',(coalesce(v_results->('court resource') ->>'resource_id',v_results->('court resource') ->>'event_id')::uuid))),md5('boss-phase3a-live:request-'||('R conflict needs explicit review'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT409']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'R conflict needs explicit review';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','R conflict needs explicit review';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','R conflict needs explicit review';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('court override'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-16T14:30:00Z','end_at','2026-10-16T15:30:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team6'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('venue_id',(coalesce(v_results->('private venue') ->>'resource_id',v_results->('private venue') ->>'event_id')::uuid),'resource_id',(coalesce(v_results->('court resource') ->>'resource_id',v_results->('court resource') ->>'event_id')::uuid),'override_conflicts',true));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('S authorized conflict override'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','S authorized conflict override';
END IF;
v_results:=v_results||jsonb_build_object('S authorized conflict override',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('published public'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-17T14:00:00Z','end_at','2026-10-17T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('visibility','public','publication_state','published','venue_id',(coalesce(v_results->('private venue') ->>'resource_id',v_results->('private venue') ->>'event_id')::uuid)));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('published public event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','published public event';
END IF;
v_results:=v_results||jsonb_build_object('published public event',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('unpublished public'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-18T14:00:00Z','end_at','2026-10-18T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||'{"visibility":"public"}'::jsonb);
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('unpublished public event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','unpublished public event';
END IF;
v_results:=v_results||jsonb_build_object('unpublished public event',v_result);
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('forged'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team-b'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('cross-tenant forged team ID rejected'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'cross-tenant forged team ID rejected';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','cross-tenant forged team ID rejected';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','cross-tenant forged team ID rejected';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('forged'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(md5('boss-phase3a-live:'||('unknown-event'))::uuid),'expected_version',1)),md5('boss-phase3a-live:request-'||('forged unknown event ID denied'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'forged unknown event ID denied';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','forged unknown event ID denied';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','forged unknown event ID denied';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('forged'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||'{"is_admin":true}'::jsonb),md5('boss-phase3a-live:request-'||('unknown privileged field denied'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT422']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'unknown privileged field denied';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','unknown privileged field denied';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','unknown privileged field denied';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('backwards'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-20T15:00:00Z','end_at','2026-10-20T14:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('date ordering rejected'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT422']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'date ordering rejected';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','date ordering rejected';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','date ordering rejected';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('unbounded'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||'{"recurrence":{"frequency":"daily","interval":1}}'::jsonb),md5('boss-phase3a-live:request-'||('missing recurrence end rejected'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT422']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'missing recurrence end rejected';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','missing recurrence end rejected';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','missing recurrence end rejected';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('duplicate'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid)),jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('duplicate target rejected'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT422']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'duplicate target rejected';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','duplicate target rejected';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','duplicate target rejected';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('published authenticated'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-19T14:00:00Z','end_at','2026-10-19T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team16'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('visibility','authenticated','publication_state','published','venue_id',(coalesce(v_results->('private venue') ->>'resource_id',v_results->('private venue') ->>'event_id')::uuid),'resource_id',(coalesce(v_results->('court resource') ->>'resource_id',v_results->('court resource') ->>'event_id')::uuid),'arrival_at','2026-10-19T13:30:00Z'));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('published authenticated event'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','published authenticated event';
END IF;
v_results:=v_results||jsonb_build_object('published authenticated event',v_result);
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('stranger'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('stranger'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

DECLARE d jsonb;
payload jsonb;
BEGIN
 d:=public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','organization','organization_id',case when 'organization'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)));

 SELECT x INTO payload FROM jsonb_array_elements(d->'occurrences') x WHERE x->>'event_id'=(coalesce(v_results->('published authenticated event') ->>'resource_id',v_results->('published authenticated event') ->>'event_id')::uuid)::text;

 IF NOT coalesce((payload IS NOT NULL AND payload->>'title'='Synthetic Phase3A Live published authenticated'),false) THEN RAISE EXCEPTION 'Live assertion failed: %','authenticated publication visible to unrelated canonical account';
END IF;
v_passed:=v_passed+1;

 IF NOT coalesce((payload->>'arrival_at' IS NULL AND payload->>'instructions' IS NULL AND payload->>'description' IS NULL AND payload->>'venue_id' IS NULL AND payload->>'resource_id' IS NULL AND d::text NOT LIKE '%PRIVATE%' AND d::text NOT LIKE '%Synthetic private facility%' AND payload->>'targets'='[]' AND payload->>'reminders'='[]'),false) THEN RAISE EXCEPTION 'Live assertion failed: %','authenticated publication redacts private details';
END IF;
v_passed:=v_passed+1;

 IF NOT coalesce((NOT EXISTS(SELECT 1 FROM public.events WHERE id=(coalesce(v_results->('published authenticated event') ->>'resource_id',v_results->('published authenticated event') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','authenticated publication no direct full-row access';
END IF;
v_passed:=v_passed+1;

END;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('admin-a'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('admin-a'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

EXECUTE 'RESET ROLE';

IF NOT coalesce((EXISTS(SELECT 1 FROM public.audit_events WHERE resource_id=(coalesce(v_results->('S authorized conflict override') ->>'resource_id',v_results->('S authorized conflict override') ->>'event_id')::uuid) AND (action LIKE '%override%' OR after_data::text LIKE '%override%'))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','S conflict override audit present';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)>=12 FROM public.audit_events WHERE organization_id=(md5('boss-phase3a-live:'||('org-a'))::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','significant calendar mutations audited';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce((NOT EXISTS(SELECT 1 FROM public.events WHERE title IN ('Synthetic Phase3A Live court denied','Synthetic Phase3A Live forged','Synthetic Phase3A Live unbounded','Synthetic Phase3A Live duplicate'))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','failure leaves no event';
END IF;
v_passed:=v_passed+1;

EXECUTE 'SET LOCAL ROLE anon';

PERFORM set_config('request.jwt.claims','{}',true);

DECLARE d jsonb;
BEGIN d:=public.boss_calendar_public_read(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','organization_id',(md5('boss-phase3a-live:'||('org-a'))::uuid)));
IF NOT coalesce((d::text LIKE '%Synthetic Phase3A Live published public%' AND d::text NOT LIKE '%Synthetic Phase3A Live unpublished public%' AND d::text NOT LIKE '%three teams%' AND d::text NOT LIKE '%published authenticated%'),false) THEN RAISE EXCEPTION 'Live assertion failed: %','I only explicitly published public schedule';
END IF;
v_passed:=v_passed+1;
IF NOT coalesce((d::text NOT LIKE '%PRIVATE%' AND d::text NOT LIKE '%Synthetic private facility%' AND d::text NOT LIKE '%Synthetic instructions%'),false) THEN RAISE EXCEPTION 'Live assertion failed: %','I no private facility or instructions';
END IF;
v_passed:=v_passed+1;
IF NOT coalesce((d::text NOT LIKE '%guardian%' AND d::text NOT LIKE '%child1%' AND d::text NOT LIKE '%minutes_before%'),false) THEN RAISE EXCEPTION 'Live assertion failed: %','I no roster or family data';
END IF;
v_passed:=v_passed+1;
END;

EXECUTE 'RESET ROLE';

EXECUTE 'SET LOCAL ROLE authenticated';

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('guardian'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('guardian'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

DECLARE tab text;
denied boolean;
BEGIN FOREACH tab IN ARRAY ARRAY['events','event_targets','event_occurrence_exceptions','venues','venue_resources','event_game_details','event_reminders'] LOOP
 denied:=false;
BEGIN EXECUTE format('INSERT INTO public.%I DEFAULT VALUES',tab);
EXCEPTION WHEN insufficient_privilege THEN denied:=true;
END;
IF NOT coalesce((denied),false) THEN RAISE EXCEPTION 'Live assertion failed: %','X authenticated actual INSERT denied '||tab;
END IF;
v_passed:=v_passed+1;

 denied:=false;
BEGIN EXECUTE format('DELETE FROM public.%I WHERE false',tab);
EXCEPTION WHEN insufficient_privilege THEN denied:=true;
END;
IF NOT coalesce((denied),false) THEN RAISE EXCEPTION 'Live assertion failed: %','X authenticated actual DELETE denied '||tab;
END IF;
v_passed:=v_passed+1;

END LOOP;
END;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('coach'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('coach'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('recurring event') ->>'resource_id',v_results->('recurring event') ->>'event_id')::uuid),'expected_version',3,'occurrence_key','2026-10-13T09:00:00','status','canceled')),md5('boss-phase3a-live:request-'||('coach occurrence exception denied other team'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'coach occurrence exception denied other team';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','coach occurrence exception denied other team';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','coach occurrence exception denied other team';
END IF;
v_passed:=v_passed+1;

-- Effective occurrence regressions: canceled and moved slots are never treated
-- as their original occupied slot during a material whole-series edit.
PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('admin-a'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('admin-a'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('effective series'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-08T14:00:00Z','end_at','2026-10-08T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team7'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3)));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('effective series'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','effective series';
END IF;
v_results:=v_results||jsonb_build_object('effective series',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid),'expected_version',1,'occurrence_key','2026-10-15T09:00:00','status','canceled'));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('effective canceled slot'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','effective canceled slot';
END IF;
v_results:=v_results||jsonb_build_object('effective canceled slot',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('reuse canceled slot'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-15T14:00:00Z','end_at','2026-10-15T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team7'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('reuse canceled slot'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','reuse canceled slot';
END IF;
v_results:=v_results||jsonb_build_object('reuse canceled slot',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('effective series title edit'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-08T14:00:00Z','end_at','2026-10-08T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team7'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid),'expected_version',2,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3)));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('effective series unchanged timing'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','effective series unchanged timing';
END IF;
v_results:=v_results||jsonb_build_object('effective series unchanged timing',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid),'expected_version',3,'occurrence_key','2026-10-22T09:00:00','override_start_at','2026-10-23T14:00:00Z','override_end_at','2026-10-23T15:00:00Z'));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('effective moved slot'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','effective moved slot';
END IF;
v_results:=v_results||jsonb_build_object('effective moved slot',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('reuse moved original slot'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-22T14:00:00Z','end_at','2026-10-22T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team7'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('reuse moved original slot'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','reuse moved original slot';
END IF;
v_results:=v_results||jsonb_build_object('reuse moved original slot',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('moved-slot collision'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-23T14:00:00Z','end_at','2026-10-23T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team7'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('override_conflicts',true));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('effective moved-slot override'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','effective moved-slot override';
END IF;
v_results:=v_results||jsonb_build_object('effective moved-slot override',v_result);
v_passed:=v_passed+1;

IF NOT coalesce(((public.boss_calendar_preview(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('effective series title edit'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-08T14:00:00Z','end_at','2026-10-08T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team7'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid),'expected_version',4,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))))->>'has_conflicts')::boolean),false) THEN RAISE EXCEPTION 'Live assertion failed: %','effective moved slot appears in preview';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('effective series title edit'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-08T14:00:00Z','end_at','2026-10-08T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team7'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid),'expected_version',4,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))),md5('boss-phase3a-live:request-'||('effective moved slot blocks unreviewed series edit'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT409']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'effective moved slot blocks unreviewed series edit';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','effective moved slot blocks unreviewed series edit';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','effective moved slot blocks unreviewed series edit';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('effective series title edit'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-08T14:00:00Z','end_at','2026-10-08T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team7'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid),'expected_version',4,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3),'override_conflicts',true));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('effective whole series reviewed override'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','effective whole series reviewed override';
END IF;
v_results:=v_results||jsonb_build_object('effective whole series reviewed override',v_result);
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('effective series time edit'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-08T15:00:00Z','end_at','2026-10-08T16:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team7'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid),'expected_version',5,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))),md5('boss-phase3a-live:request-'||('effective timing edit never silently erases exceptions'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT409']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'effective timing edit never silently erases exceptions';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','effective timing edit never silently erases exceptions';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','effective timing edit never silently erases exceptions';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('effective series time edit'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-08T15:00:00Z','end_at','2026-10-08T16:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team7'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid),'expected_version',5,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3),'reset_exceptions',true));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('effective explicit reset retains history'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','effective explicit reset retains history';
END IF;
v_results:=v_results||jsonb_build_object('effective explicit reset retains history',v_result);
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=2 AND bool_and(NOT is_active) FROM public.event_occurrence_exceptions WHERE event_id=(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','effective explicit reset archives both durable exceptions';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT before_data->>'start_at'<>after_data->>'start_at' AND (after_data->>'exceptions_archived')::int=2 FROM public.audit_events WHERE request_id=(md5('boss-phase3a-live:'||('request-effective explicit reset retains history'))::uuid) AND action='event.update')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','effective reset audit records prior and new schedule';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid),'expected_version',6,'occurrence_key','2026-10-15T10:00:00','override_start_at','2026-09-05T14:00:00Z','override_end_at','2026-09-05T15:00:00Z')),md5('boss-phase3a-live:request-'||('exception cannot leave finite early window'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT422']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'exception cannot leave finite early window';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','exception cannot leave finite early window';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','exception cannot leave finite early window';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('effective series') ->>'resource_id',v_results->('effective series') ->>'event_id')::uuid),'expected_version',6,'occurrence_key','2026-10-15T10:00:00','override_start_at','2031-10-09T14:00:00Z','override_end_at','2031-10-09T15:00:00Z')),md5('boss-phase3a-live:request-'||('exception cannot leave finite future window'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT422']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'exception cannot leave finite future window';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','exception cannot leave finite future window';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','exception cannot leave finite future window';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('all-day exception series'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-01T00:00:00Z','end_at','2026-10-02T00:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team8'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('timezone','UTC','all_day',true,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3)));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('all-day exception series'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','all-day exception series';
END IF;
v_results:=v_results||jsonb_build_object('all-day exception series',v_result);
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('all-day exception series') ->>'resource_id',v_results->('all-day exception series') ->>'event_id')::uuid),'expected_version',1,'occurrence_key','2026-10-08T00:00:00','override_start_at','2026-10-08T09:00:00Z','override_end_at','2026-10-08T10:00:00Z')),md5('boss-phase3a-live:request-'||('all-day exception cannot become timed'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT422']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'all-day exception cannot become timed';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','all-day exception cannot become timed';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','all-day exception cannot become timed';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('all-day exception series') ->>'resource_id',v_results->('all-day exception series') ->>'event_id')::uuid),'expected_version',1,'occurrence_key','2026-10-08T00:00:00','override_start_at','2026-10-09T00:00:00Z','override_end_at','2026-10-10T00:00:00Z'));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('all-day midnight exception'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','all-day midnight exception';
END IF;
v_results:=v_results||jsonb_build_object('all-day midnight exception',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('all-day exception series'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-01T00:00:00Z','end_at','2026-10-02T00:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team8'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('event_id',(coalesce(v_results->('all-day exception series') ->>'resource_id',v_results->('all-day exception series') ->>'event_id')::uuid),'expected_version',2,'timezone','UTC','all_day',true,'status','canceled','recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3)));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('cancel complete all-day series'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','cancel complete all-day series';
END IF;
v_results:=v_results||jsonb_build_object('cancel complete all-day series',v_result);
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=3 AND bool_and(o->>'status'='canceled') FROM jsonb_array_elements(public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','organization','organization_id',case when 'organization'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)))->'occurrences')o WHERE o->>'event_id'=(coalesce(v_results->('all-day exception series') ->>'resource_id',v_results->('all-day exception series') ->>'event_id')::uuid)::text)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','whole cancellation dominates prior scheduled exception';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('arrival inheritance'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-01T14:00:00Z','end_at','2026-10-01T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team9'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('arrival_at','2026-10-01T13:30:00Z','recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3)));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('arrival inheritance series'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','arrival inheritance series';
END IF;
v_results:=v_results||jsonb_build_object('arrival inheritance series',v_result);
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('arrival inheritance series') ->>'resource_id',v_results->('arrival inheritance series') ->>'event_id')::uuid),'expected_version',1,'occurrence_key','2026-10-08T09:00:00','override_arrival_at','2026-10-08T13:45:00Z'));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('explicit occurrence arrival'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','explicit occurrence arrival';
END IF;
v_results:=v_results||jsonb_build_object('explicit occurrence arrival',v_result);
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.exception','input',jsonb_build_object('event_id',(coalesce(v_results->('arrival inheritance series') ->>'resource_id',v_results->('arrival inheritance series') ->>'event_id')::uuid),'expected_version',2,'occurrence_key','2026-10-08T09:00:00','override_start_at','2026-10-08T13:00:00Z','override_end_at','2026-10-08T14:00:00Z')),md5('boss-phase3a-live:request-'||('retained occurrence arrival cannot follow new start'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT422']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'retained occurrence arrival cannot follow new start';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','retained occurrence arrival cannot follow new start';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','retained occurrence arrival cannot follow new start';
END IF;
v_passed:=v_passed+1;

-- A finite recurring series must review conflicts beyond a visible 93-day window.
v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('future booking'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2027-04-01T14:00:00Z','end_at','2027-04-01T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team10'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('future one-team booking'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','future one-team booking';
END IF;
v_results:=v_results||jsonb_build_object('future one-team booking',v_result);
v_passed:=v_passed+1;

IF NOT coalesce(((public.boss_calendar_preview(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('finite future conflict'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-01T14:00:00Z','end_at','2026-10-01T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team10'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',52))))->>'has_conflicts')::boolean),false) THEN RAISE EXCEPTION 'Live assertion failed: %','finite series preview finds distant future conflict';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('finite future conflict'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-01T14:00:00Z','end_at','2026-10-01T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team10'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',52))),md5('boss-phase3a-live:request-'||('finite series rejects unreviewed distant conflict'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT409']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'finite series rejects unreviewed distant conflict';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','finite series rejects unreviewed distant conflict';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','finite series rejects unreviewed distant conflict';
END IF;
v_passed:=v_passed+1;

EXECUTE 'RESET ROLE';

INSERT INTO public.team_memberships(organization_id,team_id,person_id,membership_type,starts_at) SELECT (md5('boss-phase3a-live:'||('org-a'))::uuid),(md5('boss-phase3a-live:'||('team'||n))::uuid),(md5('boss-phase3a-live:'||('coach'))::uuid),'coach',now()-interval '1 day' FROM generate_series(11,12)n;

INSERT INTO public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at) SELECT (md5('boss-phase3a-live:'||('org-a'))::uuid),(md5('boss-phase3a-live:'||('team'||n))::uuid),(md5('boss-phase3a-live:'||('child1'))::uuid),(md5('boss-phase3a-live:'||('participant1'))::uuid),'athlete',now()-interval '1 day' FROM generate_series(13,14)n;

EXECUTE 'SET LOCAL ROLE authenticated';

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('admin-a'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('admin-a'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('shared coach first'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-18T16:00:00Z','end_at','2026-10-18T17:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team11'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('coach primary booking'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','coach primary booking';
END IF;
v_results:=v_results||jsonb_build_object('coach primary booking',v_result);
v_passed:=v_passed+1;

IF NOT coalesce((EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_calendar_preview(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('shared coach second'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-18T16:00:00Z','end_at','2026-10-18T17:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team12'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))))->'conflicts')c WHERE c->>'kind'='coach')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','shared coach conflict derives distinct actual team attachments';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('shared coach second'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-18T16:00:00Z','end_at','2026-10-18T17:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team12'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('shared coach overlap requires authorized review'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT409']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'shared coach overlap requires authorized review';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','shared coach overlap requires authorized review';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','shared coach overlap requires authorized review';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('shared athlete first'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-18T20:00:00Z','end_at','2026-10-18T21:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team13'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true))));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('participant primary booking'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','participant primary booking';
END IF;
v_results:=v_results||jsonb_build_object('participant primary booking',v_result);
v_passed:=v_passed+1;

IF NOT coalesce((EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_calendar_preview(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('shared athlete second'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-18T20:00:00Z','end_at','2026-10-18T21:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team14'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))))->'conflicts')c WHERE c->>'kind'='participant')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','shared participant conflict derives distinct actual team attachments';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('shared athlete second'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-18T20:00:00Z','end_at','2026-10-18T21:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team14'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('shared athlete overlap requires authorized review'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT409']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'shared athlete overlap requires authorized review';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','shared athlete overlap requires authorized review';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','shared athlete overlap requires authorized review';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('coach'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('coach'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

DECLARE p jsonb;
BEGIN
 p:=public.boss_calendar_preview(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('hidden resource review'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-16T14:30:00Z','end_at','2026-10-16T15:30:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('venue_id',(coalesce(v_results->('private venue') ->>'resource_id',v_results->('private venue') ->>'event_id')::uuid),'resource_id',(coalesce(v_results->('court resource') ->>'resource_id',v_results->('court resource') ->>'event_id')::uuid))));

 IF NOT coalesce((jsonb_array_length(p->'conflicts')=2 AND (SELECT bool_and(c->>'event_id' IS NULL AND c->>'title'='Busy') FROM jsonb_array_elements(p->'conflicts')c)),false) THEN RAISE EXCEPTION 'Live assertion failed: %','hidden resource conflict returns occupied time without private IDs';
END IF;
v_passed:=v_passed+1;

 IF NOT coalesce(((p->>'can_override')::boolean=false),false) THEN RAISE EXCEPTION 'Live assertion failed: %','ordinary scheduler cannot override hidden conflict';
END IF;
v_passed:=v_passed+1;

END;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('admin-a'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('admin-a'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

DECLARE denied boolean:=false;
BEGIN
 BEGIN PERFORM public.boss_calendar_preview(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('invalid all-day preview'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-09T14:00:00Z','end_at','2026-10-09T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team15'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))||jsonb_build_object('all_day',true)));
EXCEPTION WHEN sqlstate 'PT422' THEN denied:=true;
END;

 IF NOT coalesce((denied),false) THEN RAISE EXCEPTION 'Live assertion failed: %','all-day preview rejects timed bounds before warning';
END IF;
v_passed:=v_passed+1;

END;

EXECUTE 'RESET ROLE';

 -- Organization master history remains visible after team deactivation. Actual
 -- coach and guardian relationships lose active-team access at the same boundary.
 UPDATE public.teams SET status='inactive' WHERE id=md5('boss-phase3a-live:team1')::uuid;

 EXECUTE 'SET LOCAL ROLE authenticated';

 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-admin-a')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-admin-a')::uuid)::text,true);

 v_data:=public.boss_calendar_read(jsonb_build_object('view','organization','organization_id',md5('boss-phase3a-live:org-a')::uuid,'from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z'));

 IF NOT EXISTS(select 1 from jsonb_array_elements(v_data->'occurrences') x where x->>'event_id'=v_results->'one-team event'->>'resource_id')
 THEN RAISE EXCEPTION 'Organization history lost after team deactivation';
END IF;
v_passed:=v_passed+1;

 IF NOT EXISTS(select 1 from public.events where id=(v_results->'one-team event'->>'resource_id')::uuid)
 THEN RAISE EXCEPTION 'Organization raw history lost after team deactivation';
END IF;
v_passed:=v_passed+1;

 IF NOT EXISTS(select 1 from jsonb_array_elements(v_data->'occurrences') x cross join lateral jsonb_array_elements(x->'targets') t
  where x->>'event_id'=v_results->'one-team event'->>'resource_id' and t->>'target_id'=md5('boss-phase3a-live:team1')::uuid::text)
 THEN RAISE EXCEPTION 'Organization history target label lost';
END IF;
v_passed:=v_passed+1;

 FOREACH v_label IN ARRAY array['guardian','coach'] LOOP
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||v_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||v_label)::uuid)::text,true);

  IF EXISTS(select 1 from public.events where id=(v_results->'one-team event'->>'resource_id')::uuid)
  THEN RAISE EXCEPTION 'Inactive team relationship retained private event access';
END IF;
v_passed:=v_passed+1;

 END LOOP;

 EXECUTE 'RESET ROLE';

 UPDATE public.teams SET status='active' WHERE id=md5('boss-phase3a-live:team1')::uuid;

 -- Managed PostgreSQL recurrence/DST behavior is verified through the same
 -- protected creation and read endpoints used by the hosted application.
 EXECUTE 'SET LOCAL ROLE authenticated';

 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-admin-a')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-admin-a')::uuid)::text,true);

 v_command:=jsonb_build_object('operation','event.create','input',jsonb_build_object(
  'organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live DST weekly','event_type_key','practice',
  'start_at','2026-03-01T15:00:00Z','end_at','2026-03-01T16:00:00Z','timezone','America/Chicago',
  'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',md5('boss-phase3a-live:team22')::uuid)),
  'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',4)));

 v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-live-dst')::uuid);

 IF v_result->>'resource_type'<>'event' THEN RAISE EXCEPTION 'Live DST creation failed';
END IF;
v_passed:=v_passed+1;

 v_data:=public.boss_calendar_read(jsonb_build_object('view','organization','organization_id',md5('boss-phase3a-live:org-a')::uuid,'from','2026-03-01T00:00:00Z','to','2026-04-01T00:00:00Z'));

 IF (select count(*) from jsonb_array_elements(v_data->'occurrences') x where x->>'event_id'=v_result->>'resource_id')<>4
 THEN RAISE EXCEPTION 'Live DST recurrence count incorrect';
END IF;
v_passed:=v_passed+1;

 IF NOT (select bool_and(((x->>'start_at')::timestamptz at time zone 'America/Chicago')::time=time '09:00')
  from jsonb_array_elements(v_data->'occurrences') x where x->>'event_id'=v_result->>'resource_id')
 THEN RAISE EXCEPTION 'Live DST intended local start drift';
END IF;
v_passed:=v_passed+1;

 IF NOT EXISTS(select 1 from jsonb_array_elements(v_data->'occurrences') x where x->>'event_id'=v_result->>'resource_id' and (x->>'start_at')::timestamptz='2026-03-08T14:00:00Z')
 THEN RAISE EXCEPTION 'Live DST UTC offset incorrect';
END IF;
v_passed:=v_passed+1;

 IF NOT (select bool_and(x->'recurrence'->'weekdays'='[7]'::jsonb and x->'recurrence'->'interval'='1'::jsonb)
  from jsonb_array_elements(v_data->'occurrences') x where x->>'event_id'=v_result->>'resource_id')
 THEN RAISE EXCEPTION 'Canonical weekly defaults missing';
END IF;
v_passed:=v_passed+1;

 EXECUTE 'RESET ROLE';

 -- Revoking the stored synthetic session invalidates protected reads and raw
 -- SELECT policies despite otherwise current identity and organization grants.
 EXECUTE 'SET LOCAL ROLE authenticated';

 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-admin-b')::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-admin-b')::uuid)::text,true);

 IF (select count(*) from public.event_types)<>12 THEN RAISE EXCEPTION 'Valid session catalog baseline failed';
END IF;
v_passed:=v_passed+1;

 EXECUTE 'RESET ROLE';

 DELETE FROM auth.sessions WHERE id=md5('boss-phase3a-live:session-admin-b')::uuid AND user_id=md5('boss-phase3a-live:auth-admin-b')::uuid;

 EXECUTE 'SET LOCAL ROLE authenticated';

 v_failed:=false;

 BEGIN PERFORM public.boss_calendar_read(jsonb_build_object('view','organization','organization_id',md5('boss-phase3a-live:org-b')::uuid,'from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z'));

 EXCEPTION WHEN sqlstate 'PT401' THEN v_failed:=true;
END;

 IF NOT v_failed THEN RAISE EXCEPTION 'Revoked stored session accepted private calendar read';
END IF;
v_passed:=v_passed+1;

 IF (select count(*) from public.event_types)<>0 THEN RAISE EXCEPTION 'Revoked stored session retained raw RLS catalog access';
END IF;
v_passed:=v_passed+1;

 EXECUTE 'RESET ROLE';

UPDATE public.guardian_relationships SET ends_at=now() WHERE guardian_person_id=(md5('boss-phase3a-live:'||('guardian'))::uuid);

EXECUTE 'SET LOCAL ROLE authenticated';

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('guardian'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('guardian'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

IF NOT coalesce((jsonb_array_length(public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','personal','organization_id',case when 'personal'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)))->'children')=0),false) THEN RAISE EXCEPTION 'Live assertion failed: %','expired guardians lose children projection';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce(((SELECT count(*)=0 FROM public.events WHERE id=(coalesce(v_results->('three-team event') ->>'resource_id',v_results->('three-team event') ->>'event_id')::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','expired guardians lose team schedule';
END IF;
v_passed:=v_passed+1;

EXECUTE 'RESET ROLE';

IF NOT coalesce(((SELECT count(*)=22 FROM public.permissions WHERE key NOT IN ('registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage','boss_bucks.payment_reverse') AND key NOT LIKE 'games.%') AND (SELECT count(*)=147 FROM public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage','boss_bucks.payment_reverse') AND p.key NOT LIKE 'games.%')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','22 permissions 147 role mappings';
END IF;
v_passed:=v_passed+1;

EXECUTE 'SET LOCAL ROLE authenticated';

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('admin-a'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('admin-a'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

IF NOT coalesce((public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('one team'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-12T14:00:00Z','end_at','2026-10-12T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),(md5('boss-phase3a-live:'||('request-one-team event'))::uuid))=(v_results->'one-team event')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','idempotent same input returns same receipt';
END IF;
v_passed:=v_passed+1;

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('changed replay'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-12T14:00:00Z','end_at','2026-10-12T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('one-team event'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT409']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'changed input same request rejected';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','changed input same request rejected';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','changed input same request rejected';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','calendar.configure','input',jsonb_build_object('organization_id',(md5('boss-phase3a-live:'||('org-a'))::uuid),'features',jsonb_build_object('head_coach_management',false)));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('safe coach management off'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','safe coach management off';
END IF;
v_results:=v_results||jsonb_build_object('safe coach management off',v_result);
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('coach'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('coach'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('disabled'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-29T14:00:00Z','end_at','2026-10-29T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('disabled coach management denies create'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'disabled coach management denies create';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','disabled coach management denies create';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','disabled coach management denies create';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('unit'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('unit'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','calendar.configure','input',jsonb_build_object('organization_id',(md5('boss-phase3a-live:'||('org-a'))::uuid),'features',jsonb_build_object('conflicts',false))),md5('boss-phase3a-live:request-'||('unit cannot configure organization features'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(array['PT403']::text[]) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'unit cannot configure organization features';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','unit cannot configure organization features';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','unit cannot configure organization features';
END IF;
v_passed:=v_passed+1;

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('admin-a'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('admin-a'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','calendar.configure','input',jsonb_build_object('organization_id',(md5('boss-phase3a-live:'||('org-a'))::uuid),'features',jsonb_build_object('unapproved_attendance_feature',true))),md5('boss-phase3a-live:request-'||('unknown calendar feature activation denied'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT422']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'unknown calendar feature activation denied';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','unknown calendar feature activation denied';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','unknown calendar feature activation denied';
END IF;
v_passed:=v_passed+1;

v_command:=jsonb_build_object('operation','calendar.configure','input',jsonb_build_object('organization_id',(md5('boss-phase3a-live:'||('org-a'))::uuid),'features',jsonb_build_object('public_schedules',false)));
v_result:=public.boss_calendar_mutate(v_command,md5('boss-phase3a-live:request-'||('disable public schedule'))::uuid);
IF jsonb_typeof(v_result)<>'object' THEN RAISE EXCEPTION 'Live malformed result: %','disable public schedule';
END IF;
v_results:=v_results||jsonb_build_object('disable public schedule',v_result);
v_passed:=v_passed+1;

EXECUTE 'RESET ROLE';

EXECUTE 'SET LOCAL ROLE anon';

PERFORM set_config('request.jwt.claims','{}',true);

IF NOT coalesce((NOT (public.boss_calendar_public_read(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','organization_id',(md5('boss-phase3a-live:'||('org-a'))::uuid)))::text LIKE '%Synthetic Phase3A Live published public%')),false) THEN RAISE EXCEPTION 'Live assertion failed: %','public feature closes published projection';
END IF;
v_passed:=v_passed+1;

EXECUTE 'RESET ROLE';

UPDATE public.role_assignments SET ends_at=now() WHERE person_id=(md5('boss-phase3a-live:'||('admin-a'))::uuid);

EXECUTE 'SET LOCAL ROLE authenticated';

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('admin-a'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('admin-a'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

v_failed:=false;
v_safe:=false;
BEGIN PERFORM public.boss_calendar_mutate(jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',md5('boss-phase3a-live:org-a')::uuid,'title','Synthetic Phase3A Live '||('one team'),'description','Synthetic calendar acceptance','event_type_key','practice','start_at','2026-10-12T14:00:00Z','end_at','2026-10-12T15:00:00Z','timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',(md5('boss-phase3a-live:'||('team1'))::uuid))),'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))),md5('boss-phase3a-live:request-'||('one-team event'))::uuid);
EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(ARRAY['PT403']) THEN v_failed:=true;
v_safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';
ELSE RAISE EXCEPTION 'Unexpected live denial state %: %',SQLSTATE,'same-input replay rechecks expired authority';
END IF;
END;
IF NOT v_failed THEN RAISE EXCEPTION 'Missing live denial: %','same-input replay rechecks expired authority';
END IF;
v_passed:=v_passed+1;
IF NOT v_safe THEN RAISE EXCEPTION 'Unsafe live denial: %','same-input replay rechecks expired authority';
END IF;
v_passed:=v_passed+1;

EXECUTE 'RESET ROLE';

UPDATE public.organization_modules SET status='inactive' WHERE organization_id=(md5('boss-phase3a-live:'||('org-a'))::uuid);

EXECUTE 'SET LOCAL ROLE authenticated';

PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claim','',true);
PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase3a-live:auth-'||('child1'))::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase3a-live:session-'||('child1'))::uuid,'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);

IF NOT coalesce(((SELECT count(*)=0 FROM public.events WHERE organization_id=(md5('boss-phase3a-live:'||('org-a'))::uuid))),false) THEN RAISE EXCEPTION 'Live assertion failed: %','disabled module closes member RLS';
END IF;
v_passed:=v_passed+1;

IF NOT coalesce((jsonb_array_length(public.boss_calendar_read(jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view','personal','organization_id',case when 'personal'='organization' then md5('boss-phase3a-live:org-a')::uuid end,'team_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end,'child_id',case when null is not null then md5('boss-phase3a-live:'||(null))::uuid end)))->'occurrences')=0),false) THEN RAISE EXCEPTION 'Live assertion failed: %','disabled module closes private read projection';
END IF;
v_passed:=v_passed+1;

EXECUTE 'RESET ROLE';

 PERFORM set_config('boss.phase3a_live_assertions',v_passed::text,true);

END;

$live$;

SELECT current_setting('boss.phase3a_live_assertions')::integer AS passed_assertions;

ROLLBACK;

SELECT
 (SELECT count(*) FROM public.people WHERE display_name LIKE 'Synthetic Phase3A Live %') AS synthetic_people_remaining,
 (SELECT count(*) FROM public.organizations WHERE slug LIKE 'synthetic-phase3a-live-%') AS synthetic_organizations_remaining,
 (SELECT count(*) FROM public.events WHERE title LIKE 'Synthetic Phase3A Live %') AS synthetic_events_remaining,
 (SELECT count(*) FROM public.venues WHERE name LIKE 'Synthetic Phase3A Live %' OR organization_id IN (md5('boss-phase3a-live:org-a')::uuid,md5('boss-phase3a-live:org-b')::uuid)) AS synthetic_venues_remaining,
 (SELECT count(*) FROM public.venue_resources WHERE name LIKE 'Synthetic Phase3A Live %' OR organization_id IN (md5('boss-phase3a-live:org-a')::uuid,md5('boss-phase3a-live:org-b')::uuid)) AS synthetic_resources_remaining,
 (SELECT count(*) FROM public.audit_events WHERE actor_person_id IN (SELECT md5('boss-phase3a-live:'||label)::uuid FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label)) AS synthetic_audits_remaining,
 (SELECT count(*) FROM boss_private.calendar_operation_receipts WHERE actor_person_id IN (SELECT md5('boss-phase3a-live:'||label)::uuid FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label)) AS synthetic_receipts_remaining,
 (SELECT count(*) FROM auth.users WHERE email LIKE '%@phase3a-live.example.invalid') AS synthetic_auth_users_remaining,
 (SELECT count(*) FROM auth.sessions WHERE user_id IN (SELECT md5('boss-phase3a-live:auth-'||label)::uuid FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label)) AS synthetic_sessions_remaining;

