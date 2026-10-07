-- Phase 3A A-X: canonical multi-target events and actual database-role isolation.
-- Synthetic identities/claims only. All fixture DML and local helpers roll back.
BEGIN;
CREATE TEMP TABLE phase3a_assertions(label text PRIMARY KEY,category text NOT NULL) ON COMMIT DROP;
CREATE TEMP TABLE phase3a_results(label text PRIMARY KEY,result jsonb NOT NULL) ON COMMIT DROP;
GRANT SELECT,INSERT,UPDATE ON pg_temp.phase3a_assertions,pg_temp.phase3a_results TO authenticated,anon;
CREATE FUNCTION pg_temp.f(label text) RETURNS uuid LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog
AS $$ SELECT md5('boss-phase3a-acceptance:'||label)::uuid $$;
CREATE FUNCTION pg_temp.check(label text,category text,ok boolean) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL [%] %',category,label;END IF;INSERT INTO pg_temp.phase3a_assertions VALUES(label,category);END $$;
CREATE FUNCTION pg_temp.act(label text) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM set_config('request.jwt.claim.sub','',true);PERFORM set_config('request.jwt.claim','',true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.f('auth-'||label),'role','authenticated','is_anonymous',false,'session_id',pg_temp.f('session-'||label),'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);
END $$;
CREATE FUNCTION pg_temp.command(op text,input jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog
AS $$ SELECT jsonb_build_object('operation',op,'input',input) $$;
CREATE FUNCTION pg_temp.event_input(label text,targets jsonb,starts text DEFAULT '2026-10-09T14:00:00Z',ends text DEFAULT '2026-10-09T15:00:00Z') RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
 SELECT jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic Phase3A '||label,'description','Synthetic calendar acceptance','event_type_key','practice','start_at',starts,'end_at',ends,'timezone','America/Chicago','all_day',false,'arrival_at',null,'status','scheduled','visibility','member','publication_state','unpublished','venue_id',null,'resource_id',null,'instructions','Synthetic instructions','rsvp_mode','optional','audience',jsonb_build_array('participants','guardians'),'recurrence',null,'targets',targets,'game',null,'reminders',jsonb_build_array(jsonb_build_object('minutes_before',60,'audience',jsonb_build_array('participants'),'enabled',true)))
$$;
CREATE FUNCTION pg_temp.ok(label text,cat text,command jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE result jsonb;BEGIN result:=public.boss_calendar_mutate(command,pg_temp.f('request-'||label));PERFORM pg_temp.check(label,cat,jsonb_typeof(result)='object');INSERT INTO pg_temp.phase3a_results VALUES(label,result);RETURN result;END $$;
CREATE FUNCTION pg_temp.deny(label text,cat text,command jsonb,states text[] DEFAULT ARRAY['PT403'],request_label text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE denied boolean:=false;safe boolean:=false;BEGIN
 BEGIN PERFORM public.boss_calendar_mutate(command,pg_temp.f('request-'||coalesce(request_label,label)));EXCEPTION WHEN OTHERS THEN
 IF SQLSTATE=ANY(states) THEN denied:=true;safe:=length(SQLERRM)<100 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';ELSE RAISE EXCEPTION 'FAIL [%] % unexpected state %: %',cat,label,SQLSTATE,SQLERRM;END IF;END;
 PERFORM pg_temp.check(label,cat,denied);PERFORM pg_temp.check(label||' safe error',cat,safe);
END $$;
CREATE FUNCTION pg_temp.event_id(label text) RETURNS uuid LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp
AS $$ SELECT coalesce(result->>'resource_id',result->>'event_id')::uuid FROM pg_temp.phase3a_results WHERE phase3a_results.label=$1 $$;
CREATE FUNCTION pg_temp.query(view text DEFAULT 'personal',team text DEFAULT NULL,child text DEFAULT NULL) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
 SELECT jsonb_strip_nulls(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','view',view,'organization_id',CASE WHEN view='organization' THEN pg_temp.f('org-a') END,'team_id',CASE WHEN team IS NOT NULL THEN pg_temp.f(team) END,'child_id',CASE WHEN child IS NOT NULL THEN pg_temp.f(child) END))
$$;
REVOKE ALL ON FUNCTION pg_temp.f(text),pg_temp.check(text,text,boolean),pg_temp.act(text),pg_temp.command(text,jsonb),pg_temp.event_input(text,jsonb,text,text),pg_temp.ok(text,text,jsonb),pg_temp.deny(text,text,jsonb,text[],text),pg_temp.event_id(text),pg_temp.query(text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.f(text),pg_temp.check(text,text,boolean),pg_temp.act(text),pg_temp.command(text,jsonb),pg_temp.event_input(text,jsonb,text,text),pg_temp.ok(text,text,jsonb),pg_temp.deny(text,text,jsonb,text[],text),pg_temp.event_id(text),pg_temp.query(text,text,text) TO authenticated,anon;

-- Exact new public schema and API grants, independently asserted.
SELECT pg_temp.check('exact exposed table count','X',(SELECT count(*)=30 FROM pg_catalog.pg_tables WHERE schemaname='public' AND tablename IN ('people','user_accounts','households','participants','organizations','organization_units','seasons','teams','organization_memberships','team_memberships','household_memberships','guardian_relationships','roles','permissions','role_permissions','role_assignments','modules','organization_modules','entitlements','feature_flags','feature_flag_overrides','audit_events','event_types','venues','venue_resources','events','event_targets','event_game_details','event_occurrence_exceptions','event_reminders')));
SELECT pg_temp.check('five finite calendar permissions','PERMISSIONS',(SELECT array_agg(key ORDER BY key)=ARRAY['events.create','events.manage','events.override_conflict','events.publish','events.view'] FROM public.permissions WHERE key LIKE 'events.%'));
SELECT pg_temp.check('twelve centrally governed types','MODEL',(SELECT count(*)=12 FROM public.event_types));
DO $$DECLARE tab text;action text;role_name text;denied boolean;BEGIN
 FOREACH tab IN ARRAY ARRAY['event_types','venues','venue_resources','events','event_targets','event_game_details','event_occurrence_exceptions','event_reminders'] LOOP
  PERFORM pg_temp.check(tab||' RLS','X',(SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid=('public.'||tab)::regclass));
  PERFORM pg_temp.check(tab||' authenticated read only','X',has_table_privilege('authenticated','public.'||tab,'SELECT') AND NOT has_table_privilege('authenticated','public.'||tab,'INSERT,UPDATE,DELETE,TRUNCATE'));
  PERFORM pg_temp.check(tab||' anon table closed','I',NOT has_table_privilege('anon','public.'||tab,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));
  PERFORM pg_temp.check(tab||' no mutation policies','X',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_policies WHERE schemaname='public' AND tablename=tab AND cmd<>'SELECT'));
 END LOOP;
 PERFORM pg_temp.check('no public definers','SECURITY',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef));
 PERFORM pg_temp.check('anon mutate denied','X',NOT has_function_privilege('anon','public.boss_calendar_mutate(jsonb,uuid)','EXECUTE'));
 PERFORM pg_temp.check('anon private read denied','I',NOT has_function_privilege('anon','public.boss_calendar_read(jsonb)','EXECUTE'));
END $$;

INSERT INTO auth.users(id,email,email_confirmed_at,is_anonymous)
SELECT pg_temp.f('auth-'||label),label||'@phase3a.example.invalid',CASE WHEN label='unconfirmed' THEN NULL ELSE now()-interval '1 day' END,false
FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label;
INSERT INTO auth.sessions(id,user_id) SELECT pg_temp.f('session-'||label),pg_temp.f('auth-'||label) FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label;
INSERT INTO public.people(id,display_name) SELECT pg_temp.f(label),'Synthetic Phase3A '||label FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label;
INSERT INTO public.user_accounts(auth_user_id,person_id,account_status) SELECT pg_temp.f('auth-'||label),pg_temp.f(label),'active' FROM unnest(ARRAY['admin-a','admin-b','unit','coach','assistant','guardian','household-only','member','fan','stranger','expired','unconfirmed','child1','child2','child3']) label;
INSERT INTO public.organizations(id,name,slug) VALUES(pg_temp.f('org-a'),'Synthetic Phase3A Organization A','synthetic-phase3a-a'),(pg_temp.f('org-b'),'Synthetic Phase3A Organization B','synthetic-phase3a-b');
INSERT INTO public.organization_units(id,organization_id,parent_unit_id,unit_type,name,slug) VALUES
(pg_temp.f('unit-a'),pg_temp.f('org-a'),NULL,'sport','Synthetic Phase3A Unit A','a'),(pg_temp.f('unit-sibling'),pg_temp.f('org-a'),NULL,'sport','Synthetic Phase3A Sibling','sibling'),(pg_temp.f('unit-child'),pg_temp.f('org-a'),pg_temp.f('unit-a'),'program','Synthetic Phase3A Child Unit','child'),(pg_temp.f('unit-b'),pg_temp.f('org-b'),NULL,'sport','Synthetic Phase3A Unit B','b');
INSERT INTO public.seasons(id,organization_id,parent_unit_id,name,starts_on,ends_on) VALUES(pg_temp.f('season-a'),pg_temp.f('org-a'),pg_temp.f('unit-a'),'Synthetic Phase3A season','2026-01-01','2026-12-31');
INSERT INTO public.teams(id,organization_id,parent_unit_id,season_id,name,slug,visibility,status)
SELECT pg_temp.f('team'||n),pg_temp.f('org-a'),CASE WHEN n<=3 THEN pg_temp.f('unit-a') WHEN n=4 THEN pg_temp.f('unit-child') ELSE pg_temp.f('unit-sibling') END,CASE WHEN n<=3 THEN pg_temp.f('season-a') END,'Synthetic Phase3A Team '||n,'team-'||n,CASE WHEN n=1 THEN 'public' ELSE 'private' END,'active' FROM generate_series(1,23)n;
INSERT INTO public.teams(id,organization_id,parent_unit_id,name,slug,status) VALUES(pg_temp.f('team-b'),pg_temp.f('org-b'),pg_temp.f('unit-b'),'Synthetic Phase3A Team B','b','active');
INSERT INTO public.organization_modules(organization_id,module_id,status,starts_at,configuration)
SELECT pg_temp.f(org),m.id,'active',now()-interval '1 day','{"organization_calendar":true,"team_calendar":true,"recurrence":true,"conflicts":true,"public_schedules":true,"head_coach_management":true,"conflict_overrides":true}' FROM public.modules m CROSS JOIN unnest(ARRAY['org-a','org-b'])org WHERE m.key='calendar';
INSERT INTO public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at,ends_at)
SELECT pg_temp.f(p),r.id,scope,pg_temp.f(target),pg_temp.f(org),now()-interval '2 days',CASE WHEN p='expired' THEN now()-interval '1 day' END FROM (VALUES('admin-a','organization_administrator','organization','org-a','org-a'),('admin-b','organization_administrator','organization','org-b','org-b'),('unit','program_administrator','organization_unit','unit-a','org-a'),('coach','head_coach','team','team1','org-a'),('assistant','assistant_coach','team','team1','org-a'),('expired','organization_administrator','organization','org-a','org-a'))v(p,role,scope,target,org) JOIN public.roles r ON r.key=v.role;
INSERT INTO public.organization_memberships(organization_id,person_id,membership_type,starts_at)
SELECT pg_temp.f('org-a'),pg_temp.f(p),'member',now()-interval '1 day' FROM unnest(ARRAY['member','child1','child2','child3','coach','assistant','unit'])p;
INSERT INTO public.participants(id,person_id,participant_type) SELECT pg_temp.f('participant'||n),pg_temp.f('child'||n),'athlete' FROM generate_series(1,3)n;
INSERT INTO public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at)
SELECT pg_temp.f('org-a'),pg_temp.f('team'||n),pg_temp.f('child'||n),pg_temp.f('participant'||n),'athlete',now()-interval '1 day' FROM generate_series(1,3)n;
INSERT INTO public.team_memberships(organization_id,team_id,person_id,membership_type,starts_at) VALUES(pg_temp.f('org-a'),pg_temp.f('team1'),pg_temp.f('coach'),'coach',now()-interval '1 day'),(pg_temp.f('org-a'),pg_temp.f('team1'),pg_temp.f('assistant'),'coach',now()-interval '1 day');
INSERT INTO public.households(id,name) VALUES(pg_temp.f('household'),'Synthetic Phase3A household');
INSERT INTO public.household_memberships(household_id,person_id,relationship_type,starts_at) SELECT pg_temp.f('household'),pg_temp.f(p),'member',now()-interval '1 day' FROM unnest(ARRAY['household-only','guardian','child1','child2','child3'])p;
INSERT INTO public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,starts_at,verified_at)
SELECT pg_temp.f('guardian'||n),pg_temp.f('guardian'),pg_temp.f('child'||n),'active',now()-interval '1 day',now()-interval '1 day' FROM generate_series(1,3)n;
SELECT pg_temp.check('A twenty-three teams no special schema','A',(SELECT count(*)=23 FROM public.teams WHERE organization_id=pg_temp.f('org-a')));
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('organization event','B',pg_temp.command('event.create',pg_temp.event_input('organization',jsonb_build_array(jsonb_build_object('target_type','organization','target_id',pg_temp.f('org-a'))),'2026-10-05T14:00:00Z','2026-10-05T15:00:00Z')));
SELECT pg_temp.ok('three-team event','C',pg_temp.command('event.create',pg_temp.event_input('three teams',(SELECT jsonb_agg(jsonb_build_object('target_type','team','target_id',pg_temp.f('team'||n))) FROM generate_series(1,3)n))));
SELECT pg_temp.ok('one-team event','MODEL',pg_temp.command('event.create',pg_temp.event_input('one team',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))),'2026-10-12T14:00:00Z','2026-10-12T15:00:00Z')));
SELECT pg_temp.ok('sibling event','L',pg_temp.command('event.create',pg_temp.event_input('sibling',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team23'))),'2026-10-12T14:00:00Z','2026-10-12T15:00:00Z')));
SELECT pg_temp.ok('descendant event','L',pg_temp.command('event.create',pg_temp.event_input('descendant',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team4'))),'2026-10-12T14:00:00Z','2026-10-12T15:00:00Z')));
SELECT pg_temp.check('B one organization-wide canonical record','B',(SELECT count(*)=1 FROM public.events WHERE id=pg_temp.event_id('organization event')));
SELECT pg_temp.check('C one multi-team canonical record','C',(SELECT count(*)=1 FROM public.events WHERE id=pg_temp.event_id('three-team event')));
SELECT pg_temp.check('C three explicit target rows','C',(SELECT count(*)=3 FROM public.event_targets WHERE event_id=pg_temp.event_id('three-team event')));
DO $$DECLARE n int;data jsonb;BEGIN FOR n IN 1..3 LOOP data:=public.boss_calendar_read(pg_temp.query('team','team'||n));PERFORM pg_temp.check('D canonical event team view '||n,'D',EXISTS(SELECT 1 FROM jsonb_array_elements(data->'occurrences')o WHERE o->>'event_id'=pg_temp.event_id('three-team event')::text));END LOOP;END $$;
SELECT pg_temp.act('guardian');
DO $$DECLARE data jsonb;n int;BEGIN data:=public.boss_calendar_read(pg_temp.query());PERFORM pg_temp.check('E three authorized children','E',jsonb_array_length(data->'children')=3);PERFORM pg_temp.check('E multi-team occurrence deduplicated','E',(SELECT count(*)=1 FROM jsonb_array_elements(data->'occurrences')o WHERE o->>'event_id'=pg_temp.event_id('three-team event')::text));FOR n IN 1..3 LOOP data:=public.boss_calendar_read(pg_temp.query('personal',NULL,'child'||n));PERFORM pg_temp.check('F child filter '||n,'F',EXISTS(SELECT 1 FROM jsonb_array_elements(data->'occurrences')o WHERE o->>'event_id'=pg_temp.event_id('three-team event')::text));END LOOP;END $$;
SELECT pg_temp.act('household-only');
SELECT pg_temp.check('W household never implies guardian calendar authority','W',jsonb_array_length(public.boss_calendar_read(pg_temp.query())->'children')=0 AND (SELECT count(*)=0 FROM public.events WHERE id=pg_temp.event_id('three-team event')));
SELECT pg_temp.act('stranger');
SELECT pg_temp.check('H known event UUID denied','H',(SELECT count(*)=0 FROM public.events WHERE id=pg_temp.event_id('three-team event')));
SELECT pg_temp.check('H no target IDs leaked','H',(SELECT count(*)=0 FROM public.event_targets WHERE event_id=pg_temp.event_id('three-team event')));
SELECT pg_temp.check('H no private instructions leaked','H',NOT (public.boss_calendar_read(pg_temp.query())::text LIKE '%Synthetic instructions%'));
SELECT pg_temp.act('fan');
SELECT pg_temp.check('J no relationship from public team knowledge','J',(SELECT count(*)=0 FROM public.events WHERE id=pg_temp.event_id('three-team event')));
SELECT pg_temp.act('coach');
SELECT pg_temp.deny('K coach cannot modify sibling team','K',pg_temp.command('event.update',pg_temp.event_input('denied',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team23'))))||jsonb_build_object('event_id',pg_temp.event_id('sibling event'),'expected_version',1)));
SELECT pg_temp.deny('K coach cannot add unowned team','K',pg_temp.command('event.update',pg_temp.event_input('denied',(SELECT jsonb_agg(jsonb_build_object('target_type','team','target_id',pg_temp.f('team'||n))) FROM generate_series(1,3)n))||jsonb_build_object('event_id',pg_temp.event_id('one-team event'),'expected_version',1)));
SELECT pg_temp.deny('T coach cannot request conflict override','T',pg_temp.command('event.create',pg_temp.event_input('denied',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))))||jsonb_build_object('override_conflicts',true)),ARRAY['PT403']);
SELECT pg_temp.act('unit');
SELECT pg_temp.deny('L exact unit cannot mutate sibling','L',pg_temp.command('event.update',pg_temp.event_input('denied',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team23'))))||jsonb_build_object('event_id',pg_temp.event_id('sibling event'),'expected_version',1)));
SELECT pg_temp.deny('L exact unit no descendant inheritance','L',pg_temp.command('event.update',pg_temp.event_input('denied',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team4'))))||jsonb_build_object('event_id',pg_temp.event_id('descendant event'),'expected_version',1)));
SELECT pg_temp.act('expired');
SELECT pg_temp.deny('M expired grant loses scheduling','M',pg_temp.command('event.create',pg_temp.event_input('denied',jsonb_build_array(jsonb_build_object('target_type','organization','target_id',pg_temp.f('org-a'))))));
SELECT pg_temp.act('assistant');
SELECT pg_temp.deny('assistant view does not imply scheduling','PERMISSIONS',pg_temp.command('event.create',pg_temp.event_input('denied',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))))));
SELECT pg_temp.act('admin-b');
SELECT pg_temp.deny('cross-tenant event create denied','TENANCY',pg_temp.command('event.create',pg_temp.event_input('denied',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))))));
SELECT pg_temp.check('cross-tenant event read denied','TENANCY',(SELECT count(*)=0 FROM public.events WHERE organization_id=pg_temp.f('org-a')));
SELECT pg_temp.act('unconfirmed');
SELECT pg_temp.deny('unconfirmed auth cannot schedule','SESSION',pg_temp.command('event.create',pg_temp.event_input('denied',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))))),ARRAY['PT401','PT403']);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('G reschedule canonical event','G',pg_temp.command('event.update',pg_temp.event_input('three teams rescheduled',(SELECT jsonb_agg(jsonb_build_object('target_type','team','target_id',pg_temp.f('team'||n))) FROM generate_series(1,3)n),'2026-10-10T14:00:00Z','2026-10-10T15:00:00Z')||jsonb_build_object('event_id',pg_temp.event_id('three-team event'),'expected_version',1)));
DO $$DECLARE n int;data jsonb;BEGIN FOR n IN 1..3 LOOP data:=public.boss_calendar_read(pg_temp.query('team','team'||n));PERFORM pg_temp.check('G reschedule propagated team '||n,'G',EXISTS(SELECT 1 FROM jsonb_array_elements(data->'occurrences')o WHERE o->>'event_id'=pg_temp.event_id('three-team event')::text AND (o->>'start_at')::timestamptz='2026-10-10T14:00:00Z'::timestamptz));END LOOP;END $$;
SELECT pg_temp.check('G still one event after reschedule','G',(SELECT count(*)=1 FROM public.events WHERE id=pg_temp.event_id('three-team event')));
SELECT pg_temp.deny('stale edit rejected','VERSION',pg_temp.command('event.update',pg_temp.event_input('stale',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))))||jsonb_build_object('event_id',pg_temp.event_id('three-team event'),'expected_version',1)),ARRAY['PT409']);
SELECT pg_temp.ok('recurring event','N',pg_temp.command('event.create',pg_temp.event_input('weekly',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team2'))),'2026-10-13T14:00:00Z','2026-10-13T15:00:00Z')||'{"recurrence":{"frequency":"weekly","interval":1,"count":4}}'::jsonb));
SELECT pg_temp.check('N bounded weekly expansion','N',(SELECT count(*)=3 FROM jsonb_array_elements(public.boss_calendar_read(pg_temp.query('team','team2'))->'occurrences')o WHERE o->>'event_id'=pg_temp.event_id('recurring event')::text));
SELECT pg_temp.ok('occurrence reschedule','O',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('recurring event'),'expected_version',1,'occurrence_key','2026-10-20T09:00:00','override_start_at','2026-10-21T14:00:00Z','override_end_at','2026-10-21T15:00:00Z','status','scheduled')));
SELECT pg_temp.check('O only selected occurrence moved','O',(SELECT count(*)=1 FROM jsonb_array_elements(public.boss_calendar_read(pg_temp.query('team','team2'))->'occurrences')o WHERE o->>'event_id'=pg_temp.event_id('recurring event')::text AND (o->>'start_at')::timestamptz='2026-10-21T14:00:00Z'::timestamptz));
SELECT pg_temp.check('O original first occurrence unchanged','O',(SELECT count(*)=1 FROM jsonb_array_elements(public.boss_calendar_read(pg_temp.query('team','team2'))->'occurrences')o WHERE o->>'event_id'=pg_temp.event_id('recurring event')::text AND (o->>'start_at')::timestamptz='2026-10-13T14:00:00Z'::timestamptz));
SELECT pg_temp.deny('forged exception key denied','O',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('recurring event'),'expected_version',2,'occurrence_key','2026-10-19T09:00:00','status','canceled')),ARRAY['PT422']);
SELECT pg_temp.ok('occurrence cancel','U',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('recurring event'),'expected_version',2,'occurrence_key','2026-10-27T09:00:00','status','canceled')));
SELECT pg_temp.check('U canceled occurrence retained','U',(SELECT count(*)=1 FROM jsonb_array_elements(public.boss_calendar_read(pg_temp.query('team','team2'))->'occurrences')o WHERE o->>'event_id'=pg_temp.event_id('recurring event')::text AND o->>'status'='canceled'));
SELECT pg_temp.ok('multi-day event','Q',pg_temp.command('event.create',pg_temp.event_input('multi-day',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team3'))),'2026-10-23T14:00:00Z','2026-10-25T19:00:00Z')));
SELECT pg_temp.check('Q overlap query includes already-started event','Q',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_calendar_read(jsonb_build_object('from','2026-10-24T00:00:00Z','to','2026-10-25T00:00:00Z','view','team','team_id',pg_temp.f('team3')))->'occurrences')o WHERE o->>'event_id'=pg_temp.event_id('multi-day event')::text));
SELECT pg_temp.ok('private venue','MODEL',pg_temp.command('venue.create',jsonb_build_object('organization_id',pg_temp.f('org-a'),'name','Synthetic private facility','timezone','America/Chicago','address_line1','Synthetic PRIVATE address','instructions','Synthetic PRIVATE access instructions','is_public',false)));
SELECT pg_temp.ok('court resource','MODEL',pg_temp.command('resource.create',jsonb_build_object('organization_id',pg_temp.f('org-a'),'venue_id',pg_temp.event_id('private venue'),'name','Synthetic Court 1','resource_type','court','is_public',false)));
SELECT pg_temp.ok('court event','R',pg_temp.command('event.create',pg_temp.event_input('court',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team5'))),'2026-10-16T14:00:00Z','2026-10-16T15:00:00Z')||jsonb_build_object('venue_id',pg_temp.event_id('private venue'),'resource_id',pg_temp.event_id('court resource'))));
SELECT pg_temp.check('R court conflict preview','R',jsonb_array_length(public.boss_calendar_preview(pg_temp.command('event.create',pg_temp.event_input('court overlap',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team6'))),'2026-10-16T14:30:00Z','2026-10-16T15:30:00Z')||jsonb_build_object('venue_id',pg_temp.event_id('private venue'),'resource_id',pg_temp.event_id('court resource'))))->'conflicts')>0);
SELECT pg_temp.deny('R conflict needs explicit review','R',pg_temp.command('event.create',pg_temp.event_input('court denied',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team6'))),'2026-10-16T14:30:00Z','2026-10-16T15:30:00Z')||jsonb_build_object('venue_id',pg_temp.event_id('private venue'),'resource_id',pg_temp.event_id('court resource'))),ARRAY['PT409']);
SELECT pg_temp.ok('S authorized conflict override','S',pg_temp.command('event.create',pg_temp.event_input('court override',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team6'))),'2026-10-16T14:30:00Z','2026-10-16T15:30:00Z')||jsonb_build_object('venue_id',pg_temp.event_id('private venue'),'resource_id',pg_temp.event_id('court resource'),'override_conflicts',true)));
SELECT pg_temp.ok('published public event','I',pg_temp.command('event.create',pg_temp.event_input('published public',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))),'2026-10-17T14:00:00Z','2026-10-17T15:00:00Z')||jsonb_build_object('visibility','public','publication_state','published','venue_id',pg_temp.event_id('private venue'))));
SELECT pg_temp.ok('unpublished public event','I',pg_temp.command('event.create',pg_temp.event_input('unpublished public',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))),'2026-10-18T14:00:00Z','2026-10-18T15:00:00Z')||'{"visibility":"public"}'::jsonb));
SELECT pg_temp.deny('cross-tenant forged team ID rejected','TENANCY',pg_temp.command('event.create',pg_temp.event_input('forged',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team-b'))))));
SELECT pg_temp.deny('forged unknown event ID denied','H',pg_temp.command('event.update',pg_temp.event_input('forged',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))))||jsonb_build_object('event_id',pg_temp.f('unknown-event'),'expected_version',1)));
SELECT pg_temp.deny('unknown privileged field denied','INPUT',pg_temp.command('event.create',pg_temp.event_input('forged',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))))||'{"is_admin":true}'::jsonb),ARRAY['PT422']);
SELECT pg_temp.deny('date ordering rejected','INPUT',pg_temp.command('event.create',pg_temp.event_input('backwards',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))),'2026-10-20T15:00:00Z','2026-10-20T14:00:00Z')),ARRAY['PT422']);
SELECT pg_temp.deny('missing recurrence end rejected','INPUT',pg_temp.command('event.create',pg_temp.event_input('unbounded',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))))||'{"recurrence":{"frequency":"daily","interval":1}}'::jsonb),ARRAY['PT422']);
SELECT pg_temp.deny('duplicate target rejected','INPUT',pg_temp.command('event.create',pg_temp.event_input('duplicate',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1')),jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))))),ARRAY['PT422']);
SELECT pg_temp.ok('published authenticated event','VISIBILITY',pg_temp.command('event.create',pg_temp.event_input('published authenticated',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team16'))),'2026-10-19T14:00:00Z','2026-10-19T15:00:00Z')||jsonb_build_object('visibility','authenticated','publication_state','published','venue_id',pg_temp.event_id('private venue'),'resource_id',pg_temp.event_id('court resource'),'arrival_at','2026-10-19T13:30:00Z')));
SELECT pg_temp.act('stranger');
DO $$DECLARE d jsonb;payload jsonb;BEGIN
 d:=public.boss_calendar_read(pg_temp.query('organization'));
 SELECT x INTO payload FROM jsonb_array_elements(d->'occurrences') x WHERE x->>'event_id'=pg_temp.event_id('published authenticated event')::text;
 PERFORM pg_temp.check('authenticated publication visible to unrelated canonical account','VISIBILITY',payload IS NOT NULL AND payload->>'title'='Synthetic Phase3A published authenticated');
 PERFORM pg_temp.check('authenticated publication redacts private details','VISIBILITY',payload->>'arrival_at' IS NULL AND payload->>'instructions' IS NULL AND payload->>'description' IS NULL AND payload->>'venue_id' IS NULL AND payload->>'resource_id' IS NULL AND d::text NOT LIKE '%PRIVATE%' AND d::text NOT LIKE '%Synthetic private facility%' AND payload->>'targets'='[]' AND payload->>'reminders'='[]');
 PERFORM pg_temp.check('authenticated publication no direct full-row access','VISIBILITY',NOT EXISTS(SELECT 1 FROM public.events WHERE id=pg_temp.event_id('published authenticated event')));
END $$;
SELECT pg_temp.act('admin-a');

RESET ROLE;
SELECT pg_temp.check('S conflict override audit present','S',EXISTS(SELECT 1 FROM public.audit_events WHERE resource_id=pg_temp.event_id('S authorized conflict override') AND (action LIKE '%override%' OR after_data::text LIKE '%override%')));
SELECT pg_temp.check('significant calendar mutations audited','AUDIT',(SELECT count(*)>=12 FROM public.audit_events WHERE organization_id=pg_temp.f('org-a')));
SELECT pg_temp.check('failure leaves no event','ATOMIC',NOT EXISTS(SELECT 1 FROM public.events WHERE title IN ('Synthetic Phase3A court denied','Synthetic Phase3A forged','Synthetic Phase3A unbounded','Synthetic Phase3A duplicate')));
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{}',true);
DO $$DECLARE d jsonb;BEGIN d:=public.boss_calendar_public_read(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','organization_id',pg_temp.f('org-a')));PERFORM pg_temp.check('I only explicitly published public schedule','I',d::text LIKE '%Synthetic Phase3A published public%' AND d::text NOT LIKE '%Synthetic Phase3A unpublished public%' AND d::text NOT LIKE '%three teams%' AND d::text NOT LIKE '%published authenticated%');PERFORM pg_temp.check('I no private facility or instructions','I',d::text NOT LIKE '%PRIVATE%' AND d::text NOT LIKE '%Synthetic private facility%' AND d::text NOT LIKE '%Synthetic instructions%');PERFORM pg_temp.check('I no roster or family data','I',d::text NOT LIKE '%guardian%' AND d::text NOT LIKE '%child1%' AND d::text NOT LIKE '%minutes_before%');END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
DO $$DECLARE tab text;denied boolean;BEGIN FOREACH tab IN ARRAY ARRAY['events','event_targets','event_occurrence_exceptions','venues','venue_resources','event_game_details','event_reminders'] LOOP
 denied:=false;BEGIN EXECUTE format('INSERT INTO public.%I DEFAULT VALUES',tab);EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;PERFORM pg_temp.check('X authenticated actual INSERT denied '||tab,'X',denied);
 denied:=false;BEGIN EXECUTE format('DELETE FROM public.%I WHERE false',tab);EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;PERFORM pg_temp.check('X authenticated actual DELETE denied '||tab,'X',denied);
END LOOP;END $$;
SELECT pg_temp.act('coach');
SELECT pg_temp.deny('coach occurrence exception denied other team','O',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('recurring event'),'expected_version',3,'occurrence_key','2026-10-13T09:00:00','status','canceled')));
-- Effective occurrence regressions: canceled and moved slots are never treated
-- as their original occupied slot during a material whole-series edit.
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('effective series','CONFLICT',pg_temp.command('event.create',pg_temp.event_input('effective series',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team7'))),'2026-10-08T14:00:00Z','2026-10-08T15:00:00Z')||jsonb_build_object('recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))));
SELECT pg_temp.ok('effective canceled slot','CONFLICT',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('effective series'),'expected_version',1,'occurrence_key','2026-10-15T09:00:00','status','canceled')));
SELECT pg_temp.ok('reuse canceled slot','CONFLICT',pg_temp.command('event.create',pg_temp.event_input('reuse canceled slot',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team7'))),'2026-10-15T14:00:00Z','2026-10-15T15:00:00Z')));
SELECT pg_temp.ok('effective series unchanged timing','CONFLICT',pg_temp.command('event.update',pg_temp.event_input('effective series title edit',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team7'))),'2026-10-08T14:00:00Z','2026-10-08T15:00:00Z')||jsonb_build_object('event_id',pg_temp.event_id('effective series'),'expected_version',2,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))));
SELECT pg_temp.ok('effective moved slot','CONFLICT',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('effective series'),'expected_version',3,'occurrence_key','2026-10-22T09:00:00','override_start_at','2026-10-23T14:00:00Z','override_end_at','2026-10-23T15:00:00Z')));
SELECT pg_temp.ok('reuse moved original slot','CONFLICT',pg_temp.command('event.create',pg_temp.event_input('reuse moved original slot',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team7'))),'2026-10-22T14:00:00Z','2026-10-22T15:00:00Z')));
SELECT pg_temp.ok('effective moved-slot override','CONFLICT',pg_temp.command('event.create',pg_temp.event_input('moved-slot collision',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team7'))),'2026-10-23T14:00:00Z','2026-10-23T15:00:00Z')||jsonb_build_object('override_conflicts',true)));
SELECT pg_temp.check('effective moved slot appears in preview','CONFLICT',(public.boss_calendar_preview(pg_temp.command('event.update',pg_temp.event_input('effective series title edit',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team7'))),'2026-10-08T14:00:00Z','2026-10-08T15:00:00Z')||jsonb_build_object('event_id',pg_temp.event_id('effective series'),'expected_version',4,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))))->>'has_conflicts')::boolean);
SELECT pg_temp.deny('effective moved slot blocks unreviewed series edit','CONFLICT',pg_temp.command('event.update',pg_temp.event_input('effective series title edit',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team7'))),'2026-10-08T14:00:00Z','2026-10-08T15:00:00Z')||jsonb_build_object('event_id',pg_temp.event_id('effective series'),'expected_version',4,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))),ARRAY['PT409']);
SELECT pg_temp.ok('effective whole series reviewed override','CONFLICT',pg_temp.command('event.update',pg_temp.event_input('effective series title edit',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team7'))),'2026-10-08T14:00:00Z','2026-10-08T15:00:00Z')||jsonb_build_object('event_id',pg_temp.event_id('effective series'),'expected_version',4,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3),'override_conflicts',true)));
SELECT pg_temp.deny('effective timing edit never silently erases exceptions','CONFLICT',pg_temp.command('event.update',pg_temp.event_input('effective series time edit',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team7'))),'2026-10-08T15:00:00Z','2026-10-08T16:00:00Z')||jsonb_build_object('event_id',pg_temp.event_id('effective series'),'expected_version',5,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))),ARRAY['PT409']);
SELECT pg_temp.ok('effective explicit reset retains history','CONFLICT',pg_temp.command('event.update',pg_temp.event_input('effective series time edit',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team7'))),'2026-10-08T15:00:00Z','2026-10-08T16:00:00Z')||jsonb_build_object('event_id',pg_temp.event_id('effective series'),'expected_version',5,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3),'reset_exceptions',true)));
SELECT pg_temp.check('effective explicit reset archives both durable exceptions','CONFLICT',(SELECT count(*)=2 AND bool_and(NOT is_active) FROM public.event_occurrence_exceptions WHERE event_id=pg_temp.event_id('effective series')));
SELECT pg_temp.check('effective reset audit records prior and new schedule','AUDIT',(SELECT before_data->>'start_at'<>after_data->>'start_at' AND (after_data->>'exceptions_archived')::int=2 FROM public.audit_events WHERE request_id=pg_temp.f('request-effective explicit reset retains history') AND action='event.update'));
SELECT pg_temp.deny('exception cannot leave finite early window','INPUT',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('effective series'),'expected_version',6,'occurrence_key','2026-10-15T10:00:00','override_start_at','2026-09-05T14:00:00Z','override_end_at','2026-09-05T15:00:00Z')),ARRAY['PT422']);
SELECT pg_temp.deny('exception cannot leave finite future window','INPUT',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('effective series'),'expected_version',6,'occurrence_key','2026-10-15T10:00:00','override_start_at','2031-10-09T14:00:00Z','override_end_at','2031-10-09T15:00:00Z')),ARRAY['PT422']);

SELECT pg_temp.ok('all-day exception series','Q',pg_temp.command('event.create',pg_temp.event_input('all-day exception series',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team8'))),'2026-10-01T00:00:00Z','2026-10-02T00:00:00Z')||jsonb_build_object('timezone','UTC','all_day',true,'recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))));
SELECT pg_temp.deny('all-day exception cannot become timed','Q',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('all-day exception series'),'expected_version',1,'occurrence_key','2026-10-08T00:00:00','override_start_at','2026-10-08T09:00:00Z','override_end_at','2026-10-08T10:00:00Z')),ARRAY['PT422']);
SELECT pg_temp.ok('all-day midnight exception','Q',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('all-day exception series'),'expected_version',1,'occurrence_key','2026-10-08T00:00:00','override_start_at','2026-10-09T00:00:00Z','override_end_at','2026-10-10T00:00:00Z')));
SELECT pg_temp.ok('cancel complete all-day series','U',pg_temp.command('event.update',pg_temp.event_input('all-day exception series',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team8'))),'2026-10-01T00:00:00Z','2026-10-02T00:00:00Z')||jsonb_build_object('event_id',pg_temp.event_id('all-day exception series'),'expected_version',2,'timezone','UTC','all_day',true,'status','canceled','recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))));
SELECT pg_temp.check('whole cancellation dominates prior scheduled exception','U',(SELECT count(*)=3 AND bool_and(o->>'status'='canceled') FROM jsonb_array_elements(public.boss_calendar_read(pg_temp.query('organization'))->'occurrences')o WHERE o->>'event_id'=pg_temp.event_id('all-day exception series')::text));
SELECT pg_temp.ok('arrival inheritance series','MODEL',pg_temp.command('event.create',pg_temp.event_input('arrival inheritance',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team9'))),'2026-10-01T14:00:00Z','2026-10-01T15:00:00Z')||jsonb_build_object('arrival_at','2026-10-01T13:30:00Z','recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',3))));
SELECT pg_temp.ok('explicit occurrence arrival','MODEL',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('arrival inheritance series'),'expected_version',1,'occurrence_key','2026-10-08T09:00:00','override_arrival_at','2026-10-08T13:45:00Z')));
SELECT pg_temp.deny('retained occurrence arrival cannot follow new start','INPUT',pg_temp.command('event.exception',jsonb_build_object('event_id',pg_temp.event_id('arrival inheritance series'),'expected_version',2,'occurrence_key','2026-10-08T09:00:00','override_start_at','2026-10-08T13:00:00Z','override_end_at','2026-10-08T14:00:00Z')),ARRAY['PT422']);

-- A finite recurring series must review conflicts beyond a visible 93-day window.
SELECT pg_temp.ok('future one-team booking','CONFLICT',pg_temp.command('event.create',pg_temp.event_input('future booking',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team10'))),'2027-04-01T14:00:00Z','2027-04-01T15:00:00Z')));
SELECT pg_temp.check('finite series preview finds distant future conflict','CONFLICT',(public.boss_calendar_preview(pg_temp.command('event.create',pg_temp.event_input('finite future conflict',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team10'))),'2026-10-01T14:00:00Z','2026-10-01T15:00:00Z')||jsonb_build_object('recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',52))))->>'has_conflicts')::boolean);
SELECT pg_temp.deny('finite series rejects unreviewed distant conflict','CONFLICT',pg_temp.command('event.create',pg_temp.event_input('finite future conflict',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team10'))),'2026-10-01T14:00:00Z','2026-10-01T15:00:00Z')||jsonb_build_object('recurrence',jsonb_build_object('frequency','weekly','interval',1,'count',52))),ARRAY['PT409']);
RESET ROLE;
INSERT INTO public.team_memberships(organization_id,team_id,person_id,membership_type,starts_at) SELECT pg_temp.f('org-a'),pg_temp.f('team'||n),pg_temp.f('coach'),'coach',now()-interval '1 day' FROM generate_series(11,12)n;
INSERT INTO public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at) SELECT pg_temp.f('org-a'),pg_temp.f('team'||n),pg_temp.f('child1'),pg_temp.f('participant1'),'athlete',now()-interval '1 day' FROM generate_series(13,14)n;
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('coach primary booking','CONFLICT',pg_temp.command('event.create',pg_temp.event_input('shared coach first',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team11'))),'2026-10-18T16:00:00Z','2026-10-18T17:00:00Z')));
SELECT pg_temp.check('shared coach conflict derives distinct actual team attachments','CONFLICT',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_calendar_preview(pg_temp.command('event.create',pg_temp.event_input('shared coach second',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team12'))),'2026-10-18T16:00:00Z','2026-10-18T17:00:00Z')))->'conflicts')c WHERE c->>'kind'='coach'));
SELECT pg_temp.deny('shared coach overlap requires authorized review','CONFLICT',pg_temp.command('event.create',pg_temp.event_input('shared coach second',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team12'))),'2026-10-18T16:00:00Z','2026-10-18T17:00:00Z')),ARRAY['PT409']);
SELECT pg_temp.ok('participant primary booking','CONFLICT',pg_temp.command('event.create',pg_temp.event_input('shared athlete first',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team13'))),'2026-10-18T20:00:00Z','2026-10-18T21:00:00Z')));
SELECT pg_temp.check('shared participant conflict derives distinct actual team attachments','CONFLICT',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_calendar_preview(pg_temp.command('event.create',pg_temp.event_input('shared athlete second',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team14'))),'2026-10-18T20:00:00Z','2026-10-18T21:00:00Z')))->'conflicts')c WHERE c->>'kind'='participant'));
SELECT pg_temp.deny('shared athlete overlap requires authorized review','CONFLICT',pg_temp.command('event.create',pg_temp.event_input('shared athlete second',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team14'))),'2026-10-18T20:00:00Z','2026-10-18T21:00:00Z')),ARRAY['PT409']);
SELECT pg_temp.act('coach');
DO $$DECLARE p jsonb;BEGIN
 p:=public.boss_calendar_preview(pg_temp.command('event.create',pg_temp.event_input('hidden resource review',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))),'2026-10-16T14:30:00Z','2026-10-16T15:30:00Z')||jsonb_build_object('venue_id',pg_temp.event_id('private venue'),'resource_id',pg_temp.event_id('court resource'))));
 PERFORM pg_temp.check('hidden resource conflict returns occupied time without private IDs','CONFLICT',jsonb_array_length(p->'conflicts')=2 AND (SELECT bool_and(c->>'event_id' IS NULL AND c->>'title'='Busy') FROM jsonb_array_elements(p->'conflicts')c));
 PERFORM pg_temp.check('ordinary scheduler cannot override hidden conflict','CONFLICT',(p->>'can_override')::boolean=false);
END $$;
SELECT pg_temp.act('admin-a');
DO $$DECLARE denied boolean:=false;BEGIN
 BEGIN PERFORM public.boss_calendar_preview(pg_temp.command('event.create',pg_temp.event_input('invalid all-day preview',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team15'))))||jsonb_build_object('all_day',true)));EXCEPTION WHEN sqlstate 'PT422' THEN denied:=true;END;
 PERFORM pg_temp.check('all-day preview rejects timed bounds before warning','INPUT',denied);
END $$;

RESET ROLE;
UPDATE public.guardian_relationships SET ends_at=now() WHERE guardian_person_id=pg_temp.f('guardian');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.check('expired guardians lose children projection','FAMILY',jsonb_array_length(public.boss_calendar_read(pg_temp.query())->'children')=0);
SELECT pg_temp.check('expired guardians lose team schedule','FAMILY',(SELECT count(*)=0 FROM public.events WHERE id=pg_temp.event_id('three-team event')));
RESET ROLE;

SELECT pg_temp.check('historical 22 permissions 147 role mappings','PERMISSIONS',(SELECT count(*)=22 FROM public.permissions WHERE key NOT IN ('registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage','boss_bucks.payment_reverse') AND key NOT LIKE 'games.%') AND (SELECT count(*)=147 FROM public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage','boss_bucks.payment_reverse') AND p.key NOT LIKE 'games.%'));
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.check('idempotent same input returns same receipt','REPLAY',public.boss_calendar_mutate(pg_temp.command('event.create',pg_temp.event_input('one team',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))),'2026-10-12T14:00:00Z','2026-10-12T15:00:00Z')),pg_temp.f('request-one-team event'))=(SELECT result FROM pg_temp.phase3a_results WHERE label='one-team event'));
SELECT pg_temp.deny('changed input same request rejected','REPLAY',pg_temp.command('event.create',pg_temp.event_input('changed replay',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))),'2026-10-12T14:00:00Z','2026-10-12T15:00:00Z')),ARRAY['PT409'],'one-team event');
SELECT pg_temp.ok('safe coach management off','FEATURE',pg_temp.command('calendar.configure',jsonb_build_object('organization_id',pg_temp.f('org-a'),'features',jsonb_build_object('head_coach_management',false))));
SELECT pg_temp.act('coach');
SELECT pg_temp.deny('disabled coach management denies create','FEATURE',pg_temp.command('event.create',pg_temp.event_input('disabled',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))),'2026-10-29T14:00:00Z','2026-10-29T15:00:00Z')));
SELECT pg_temp.act('unit');
SELECT pg_temp.deny('unit cannot configure organization features','FEATURE',pg_temp.command('calendar.configure',jsonb_build_object('organization_id',pg_temp.f('org-a'),'features',jsonb_build_object('conflicts',false))));
SELECT pg_temp.act('admin-a');
SELECT pg_temp.deny('unknown calendar feature activation denied','FEATURE',pg_temp.command('calendar.configure',jsonb_build_object('organization_id',pg_temp.f('org-a'),'features',jsonb_build_object('unapproved_attendance_feature',true))),ARRAY['PT422']);
SELECT pg_temp.ok('disable public schedule','FEATURE',pg_temp.command('calendar.configure',jsonb_build_object('organization_id',pg_temp.f('org-a'),'features',jsonb_build_object('public_schedules',false))));
RESET ROLE;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{}',true);
SELECT pg_temp.check('public feature closes published projection','FEATURE',NOT (public.boss_calendar_public_read(jsonb_build_object('from','2026-10-01T00:00:00Z','to','2026-11-01T00:00:00Z','organization_id',pg_temp.f('org-a')))::text LIKE '%Synthetic Phase3A published public%'));
RESET ROLE;
UPDATE public.role_assignments SET ends_at=now() WHERE person_id=pg_temp.f('admin-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.deny('same-input replay rechecks expired authority','REPLAY',pg_temp.command('event.create',pg_temp.event_input('one team',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.f('team1'))),'2026-10-12T14:00:00Z','2026-10-12T15:00:00Z')),ARRAY['PT403'],'one-team event');
RESET ROLE;
UPDATE public.organization_modules SET status='inactive' WHERE organization_id=pg_temp.f('org-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('child1');
SELECT pg_temp.check('disabled module closes member RLS','FEATURE',(SELECT count(*)=0 FROM public.events WHERE organization_id=pg_temp.f('org-a')));
SELECT pg_temp.check('disabled module closes private read projection','FEATURE',jsonb_array_length(public.boss_calendar_read(pg_temp.query())->'occurrences')=0);
RESET ROLE;
SELECT count(*) AS passed_assertions FROM pg_temp.phase3a_assertions;
ROLLBACK;
SELECT count(*) AS remaining_calendar_fixtures FROM public.organizations WHERE slug LIKE 'synthetic-phase3a-%';
