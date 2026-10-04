-- Phase 3B A-Z acceptance under actual authenticated/anon database roles.
-- All people, households, medical text and documents are synthetic; rollback
-- discards fixtures and audit writes without disabling immutable-history rules.
BEGIN;
CREATE TEMP TABLE phase3b_assertions(label text PRIMARY KEY,category text NOT NULL) ON COMMIT DROP;
CREATE TEMP TABLE phase3b_results(label text PRIMARY KEY,result jsonb NOT NULL) ON COMMIT DROP;
GRANT SELECT,INSERT,UPDATE ON pg_temp.phase3b_assertions,pg_temp.phase3b_results TO authenticated,anon;
CREATE FUNCTION pg_temp.f(label text) RETURNS uuid LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog
AS $$ SELECT md5('boss-phase3b-acceptance:'||label)::uuid $$;
CREATE FUNCTION pg_temp.check(label text,category text,ok boolean) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL [%] %',category,label;END IF;INSERT INTO pg_temp.phase3b_assertions VALUES(label,category);END $$;
CREATE FUNCTION pg_temp.act(label text) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM set_config('request.jwt.claim.sub','',true);PERFORM set_config('request.jwt.claim','',true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.f('auth-'||label),'role','authenticated','is_anonymous',false,'session_id',pg_temp.f('session-'||label),'user_metadata',jsonb_build_object('is_admin',true,'role','super_administrator'))::text,true);
END $$;
CREATE FUNCTION pg_temp.command(op text,input jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog
AS $$ SELECT jsonb_build_object('operation',op,'input',input) $$;
CREATE FUNCTION pg_temp.ok(label text,category text,command jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE result jsonb;BEGIN result:=public.boss_registration_mutate(p_request_id=>pg_temp.f('request-'||label),p_command=>command);PERFORM pg_temp.check(label,category,jsonb_typeof(result)='object');INSERT INTO pg_temp.phase3b_results VALUES(label,result);RETURN result;END $$;
CREATE FUNCTION pg_temp.deny(label text,category text,command jsonb,states text[] DEFAULT ARRAY['PT403'],request_label text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE denied boolean:=false;safe boolean:=false;BEGIN
 BEGIN PERFORM public.boss_registration_mutate(p_request_id=>pg_temp.f('request-'||coalesce(request_label,label)),p_command=>command);EXCEPTION WHEN OTHERS THEN
 IF SQLSTATE=ANY(states) THEN denied:=true;safe:=length(SQLERRM)<160 AND SQLERRM !~* '(constraint|relation|column|password|token|stack|SELECT|INSERT|UPDATE|DELETE)';ELSE RAISE EXCEPTION 'FAIL [%] % unexpected state %: %',category,label,SQLSTATE,SQLERRM;END IF;END;
 PERFORM pg_temp.check(label,category,denied);PERFORM pg_temp.check(label||' safe error',category,safe);
END $$;
CREATE FUNCTION pg_temp.result_id(label text) RETURNS uuid LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp
AS $$ SELECT coalesce(result->>'resource_id',result->>'id',result->>'registration_id',result->>'offering_id',result->>'document_id',result->>'charge_id')::uuid FROM pg_temp.phase3b_results WHERE phase3b_results.label=$1 $$;
REVOKE ALL ON FUNCTION pg_temp.f(text),pg_temp.check(text,text,boolean),pg_temp.act(text),pg_temp.command(text,jsonb),pg_temp.ok(text,text,jsonb),pg_temp.deny(text,text,jsonb,text[],text),pg_temp.result_id(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.f(text),pg_temp.check(text,text,boolean),pg_temp.act(text),pg_temp.command(text,jsonb),pg_temp.ok(text,text,jsonb),pg_temp.deny(text,text,jsonb,text[],text),pg_temp.result_id(text) TO authenticated,anon;
CREATE FUNCTION pg_temp.sql_deny(label text,category text,statement text,states text[] DEFAULT ARRAY['42501']) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE denied boolean:=false;BEGIN BEGIN EXECUTE statement;EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(states) THEN denied:=true;ELSE RAISE EXCEPTION 'FAIL [%] % unexpected state %',category,label,SQLSTATE;END IF;END;PERFORM pg_temp.check(label,category,denied);END $$;
CREATE FUNCTION pg_temp.read_deny(label text,query jsonb,states text[] DEFAULT ARRAY['PT403']) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE denied boolean:=false;BEGIN BEGIN PERFORM public.boss_registration_read(query);EXCEPTION WHEN OTHERS THEN IF SQLSTATE=ANY(states) THEN denied:=true;ELSE RAISE EXCEPTION 'FAIL read % unexpected state %',label,SQLSTATE;END IF;END;PERFORM pg_temp.check(label,'READ',denied);END $$;
REVOKE ALL ON FUNCTION pg_temp.sql_deny(text,text,text,text[]),pg_temp.read_deny(text,jsonb,text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.sql_deny(text,text,text,text[]),pg_temp.read_deny(text,jsonb,text[]) TO authenticated,anon;
CREATE FUNCTION pg_temp.payment(method text,amount bigint,charge uuid DEFAULT NULL,organization uuid DEFAULT NULL) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
 SELECT pg_temp.command('payment.record_offline',jsonb_build_object('organization_id',coalesce(organization,pg_temp.f('org-a')),'method',method,'amount_minor',amount,'currency','USD','payer_person_id',pg_temp.f('guardian'),'received_at',now(),'reference',CASE WHEN method='check' THEN 'SYNTHETIC-CHECK-001' ELSE 'SYNTHETIC-CASH-001' END,'note','Synthetic offline acceptance','allocations',jsonb_build_array(jsonb_build_object('charge_id',coalesce(charge,pg_temp.result_id('season charge')),'amount_minor',amount))))
$$;
REVOKE ALL ON FUNCTION pg_temp.payment(text,bigint,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.payment(text,bigint,uuid,uuid) TO authenticated,anon;

INSERT INTO auth.users(id,email,email_confirmed_at,is_anonymous)
SELECT pg_temp.f('auth-'||label),label||'@phase3b.example.invalid',CASE WHEN label='unconfirmed' THEN NULL ELSE now()-interval '1 day' END,label='anonymous'
FROM unnest(ARRAY['platform','admin-a','admin-b','registrar','finance','unit','coach','assistant','emergency','guardian','limited-guardian','unverified','household-only','outsider','expired','unconfirmed','anonymous']) label;
INSERT INTO auth.sessions(id,user_id)
SELECT pg_temp.f('session-'||label),pg_temp.f('auth-'||label)
FROM unnest(ARRAY['platform','admin-a','admin-b','registrar','finance','unit','coach','assistant','emergency','guardian','limited-guardian','unverified','household-only','outsider','expired','unconfirmed','anonymous']) label;
INSERT INTO public.people(id,display_name)
SELECT pg_temp.f(label),'Synthetic Phase3B '||label
FROM unnest(ARRAY['platform','admin-a','admin-b','registrar','finance','unit','coach','assistant','emergency','guardian','limited-guardian','unverified','household-only','outsider','expired','unconfirmed','anonymous','child1','child2','child3','child-other']) label;
INSERT INTO public.user_accounts(auth_user_id,person_id,account_status)
SELECT pg_temp.f('auth-'||label),pg_temp.f(label),'active'
FROM unnest(ARRAY['platform','admin-a','admin-b','registrar','finance','unit','coach','assistant','emergency','guardian','limited-guardian','unverified','household-only','outsider','expired','unconfirmed','anonymous']) label;
INSERT INTO public.organizations(id,name,slug,status)
VALUES(pg_temp.f('org-a'),'Synthetic Phase3B Organization A','synthetic-phase3b-a','active'),(pg_temp.f('org-b'),'Synthetic Phase3B Organization B','synthetic-phase3b-b','active');
INSERT INTO public.organization_units(id,organization_id,parent_unit_id,unit_type,name,slug)
VALUES(pg_temp.f('unit-a'),pg_temp.f('org-a'),NULL,'program','Synthetic Phase3B Unit A','a'),(pg_temp.f('unit-sibling'),pg_temp.f('org-a'),NULL,'program','Synthetic Phase3B Sibling','sibling'),(pg_temp.f('unit-child'),pg_temp.f('org-a'),pg_temp.f('unit-a'),'program','Synthetic Phase3B Child Unit','child'),(pg_temp.f('unit-b'),pg_temp.f('org-b'),NULL,'program','Synthetic Phase3B Unit B','b');
INSERT INTO public.seasons(id,organization_id,parent_unit_id,name,starts_on,ends_on,status)
VALUES(pg_temp.f('season-a'),pg_temp.f('org-a'),pg_temp.f('unit-a'),'Synthetic Phase3B Season','2026-01-01','2026-12-31','active');
INSERT INTO public.teams(id,organization_id,parent_unit_id,season_id,name,slug,status,visibility)
VALUES(pg_temp.f('team-a'),pg_temp.f('org-a'),pg_temp.f('unit-a'),pg_temp.f('season-a'),'Synthetic Phase3B Falcons','falcons','active','private'),(pg_temp.f('team-sibling'),pg_temp.f('org-a'),pg_temp.f('unit-sibling'),pg_temp.f('season-a'),'Synthetic Phase3B Wildcats','wildcats','active','private'),(pg_temp.f('team-b'),pg_temp.f('org-b'),pg_temp.f('unit-b'),NULL,'Synthetic Phase3B Other Tenant','other','active','private');
INSERT INTO public.households(id,name)
VALUES(pg_temp.f('household-a'),'Synthetic Phase3B Household A'),(pg_temp.f('household-b'),'Synthetic Phase3B Household B');
INSERT INTO public.household_memberships(household_id,person_id,relationship_type,starts_at)
SELECT pg_temp.f('household-a'),pg_temp.f(label),CASE WHEN label LIKE 'child%' THEN 'dependent' ELSE 'guardian' END,now()-interval '1 day'
FROM unnest(ARRAY['guardian','limited-guardian','unverified','household-only','child1','child2','child3']) label;
INSERT INTO public.household_memberships(household_id,person_id,relationship_type,starts_at)
VALUES(pg_temp.f('household-b'),pg_temp.f('outsider'),'guardian',now()-interval '1 day'),(pg_temp.f('household-b'),pg_temp.f('child-other'),'dependent',now()-interval '1 day');
INSERT INTO public.participants(id,person_id,participant_type)
SELECT pg_temp.f('participant-'||label),pg_temp.f(label),'athlete'
FROM unnest(ARRAY['child1','child2','child3','child-other']) label;
INSERT INTO public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,can_register,can_sign_waivers,can_view_documents,can_manage_payments,can_manage_profile,starts_at)
SELECT pg_temp.f('guardian-'||label),pg_temp.f('guardian'),pg_temp.f(label),'active',now()-interval '1 day',true,true,true,true,true,now()-interval '1 day'
FROM unnest(ARRAY['child1','child2','child3']) label;
INSERT INTO public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,can_register,can_sign_waivers,can_view_documents,can_manage_payments,starts_at)
VALUES(pg_temp.f('limited-guardian'),pg_temp.f('limited-guardian'),pg_temp.f('child1'),'active',now()-interval '1 day',false,false,false,false,now()-interval '1 day'),(pg_temp.f('unverified'),pg_temp.f('unverified'),pg_temp.f('child1'),'active',NULL,true,true,true,true,now()-interval '1 day'),(pg_temp.f('other-guardian'),pg_temp.f('outsider'),pg_temp.f('child-other'),'active',now()-interval '1 day',true,true,true,true,now()-interval '1 day');
INSERT INTO public.organization_memberships(organization_id,person_id,membership_type,starts_at)
SELECT pg_temp.f('org-a'),pg_temp.f(label),'member',now()-interval '1 day'
FROM unnest(ARRAY['guardian','limited-guardian','unverified','household-only','coach','assistant','emergency','child1','child2','child3']) label;
INSERT INTO public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at)
VALUES(pg_temp.f('org-a'),pg_temp.f('team-a'),pg_temp.f('child1'),pg_temp.f('participant-child1'),'athlete',now()-interval '1 day'),(pg_temp.f('org-a'),pg_temp.f('team-sibling'),pg_temp.f('child2'),pg_temp.f('participant-child2'),'athlete',now()-interval '1 day');

INSERT INTO public.role_assignments(id,person_id,role_id,scope_type,scope_id,organization_id,starts_at,ends_at)
SELECT pg_temp.f('role-'||actor),pg_temp.f(actor),r.id,scope_type,scope_id,organization_id,now()-interval '1 day',ends_at
FROM (VALUES
 ('platform','platform_administrator','platform',NULL::uuid,NULL::uuid,NULL::timestamptz),
 ('admin-a','organization_administrator','organization',pg_temp.f('org-a'),pg_temp.f('org-a'),NULL),
 ('admin-b','organization_administrator','organization',pg_temp.f('org-b'),pg_temp.f('org-b'),NULL),
 ('registrar','registrar','organization',pg_temp.f('org-a'),pg_temp.f('org-a'),NULL),
 ('finance','organization_finance','organization',pg_temp.f('org-a'),pg_temp.f('org-a'),NULL),
 ('unit','program_administrator','organization_unit',pg_temp.f('unit-a'),pg_temp.f('org-a'),NULL),
 ('coach','head_coach','team',pg_temp.f('team-a'),pg_temp.f('org-a'),NULL),
 ('assistant','assistant_coach','team',pg_temp.f('team-a'),pg_temp.f('org-a'),NULL),
 ('emergency','head_coach','team',pg_temp.f('team-a'),pg_temp.f('org-a'),NULL),
 ('expired','organization_finance','organization',pg_temp.f('org-a'),pg_temp.f('org-a'),now()-interval '1 hour')
) x(actor,role_key,scope_type,scope_id,organization_id,ends_at) JOIN public.roles r ON r.key=x.role_key;
INSERT INTO public.team_memberships(organization_id,team_id,person_id,membership_type,starts_at)
VALUES(pg_temp.f('org-a'),pg_temp.f('team-a'),pg_temp.f('emergency'),'coach',now()-interval '1 day');
INSERT INTO public.organization_modules(organization_id,module_id,status,configuration,starts_at)
SELECT pg_temp.f(org),m.id,'active','{"registration":true,"forms":true,"waivers":true,"documents":true,"fees":true,"payment_plans":true,"coupons":true,"waitlists":true,"offline_payments":true,"emergency_access":true,"coach_registration_view":true}',now()-interval '1 day'
FROM unnest(ARRAY['org-a','org-b']) org CROSS JOIN public.modules m WHERE m.key='registration';
INSERT INTO public.organization_modules(organization_id,module_id,status,starts_at)
SELECT pg_temp.f('org-a'),m.id,'active',now()-interval '1 day' FROM public.modules m WHERE m.key='calendar';
UPDATE public.people SET date_of_birth=current_date-interval '10 years' WHERE id=pg_temp.f('child1');
INSERT INTO public.events(id,organization_id,event_type_key,title,start_at,end_at,timezone,status,created_by_person_id,updated_by_person_id)
VALUES(pg_temp.f('event-a'),pg_temp.f('org-a'),'camp','Synthetic Phase3B linked camp',date_trunc('second',now())+interval '7 days',date_trunc('second',now())+interval '7 days 2 hours','UTC','scheduled',pg_temp.f('admin-a'),pg_temp.f('admin-a'));
INSERT INTO public.event_targets(organization_id,event_id,target_type,target_id)
VALUES(pg_temp.f('org-a'),pg_temp.f('event-a'),'organization',pg_temp.f('org-a'));

-- Exact new catalogs are independent of historical subset checks.
SELECT pg_temp.check('historical 51 public tables','CATALOG',(SELECT count(*)=51 FROM pg_catalog.pg_tables WHERE schemaname='public' AND tablename NOT IN ('communication_threads','communication_thread_members','communication_audiences','communication_messages','communication_message_revisions','communication_read_state','communication_attachments','communication_reports','notification_events','notifications','notification_preferences','notification_deliveries','event_attendance_settings','attendance_responses','attendance_response_history','attendance_checkins','attendance_checkin_history','attendance_requests','volunteer_role_definitions','volunteer_shifts','volunteer_assignments','volunteer_assignment_history') AND tablename NOT IN ('game_sports','games','game_roster_snapshots','game_operator_assignments','game_operations','game_finalizations') AND tablename NOT IN ('game_basketball_states','game_basketball_events','game_basketball_lineups','game_basketball_lineup_history','game_basketball_finalizations','game_basketball_final_stats') AND tablename NOT IN ('game_soccer_states','game_soccer_events','game_soccer_lineups','game_soccer_finalizations','game_soccer_final_stats') AND tablename NOT IN ('game_football_states','game_football_events','game_football_lineups','game_football_finalizations','game_football_final_stats')));
SELECT pg_temp.check('historical 21 roles 34 permissions 239 mappings','CATALOG',(SELECT count(*)=21 FROM public.roles) AND (SELECT count(*)=34 FROM public.permissions WHERE key NOT IN ('announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign') AND key NOT LIKE 'games.%') AND (SELECT count(*)=239 FROM public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign') AND p.key NOT LIKE 'games.%'));
SELECT pg_temp.check('private registration bucket constraints','H',(SELECT NOT public AND file_size_limit=10485760 AND allowed_mime_types @> ARRAY['application/pdf','image/jpeg','image/png'] FROM storage.buckets WHERE id='boss-registration-documents'));
DO $$DECLARE t text;denied boolean;action text;col text;BEGIN
 FOREACH t IN ARRAY ARRAY['registration_offerings','registration_form_versions','registration_waiver_versions','document_requirements','registration_offering_forms','registration_offering_waivers','registration_offering_documents','registration_fee_rules','registration_coupons','registrations','registration_form_answers','waiver_signatures','registration_documents','document_upload_intents','participant_emergency_records','charges','charge_adjustments','payments','payment_allocations','payment_plans','payment_installments'] LOOP
  PERFORM pg_temp.check(t||' RLS enabled','Z',(SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid=('public.'||t)::regclass));
  PERFORM pg_temp.check(t||' no anonymous raw grant','Z',NOT has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));
  PERFORM pg_temp.check(t||' no authenticated raw grant','Z',NOT has_table_privilege('authenticated','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));
  PERFORM pg_temp.check(t||' no service-role inherited grant','Z',NOT has_table_privilege('service_role','public.'||t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));
 END LOOP;
 PERFORM pg_temp.check('registration RPC public invoker','Z',NOT (SELECT prosecdef FROM pg_catalog.pg_proc WHERE oid='public.boss_registration_mutate(uuid,jsonb)'::regprocedure));
 PERFORM pg_temp.check('registration mutation anon closed','Z',NOT has_function_privilege('anon','public.boss_registration_mutate(uuid,jsonb)','EXECUTE'));
 PERFORM pg_temp.check('no public definer','Z',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef));
END $$;

SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('season offering','A',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic Phase3B Season Registration','scope_type','team','scope_id',pg_temp.f('team-a'),'season_id',pg_temp.f('season-a'),'registration_type','season','participant_type','athlete','approval_required',true)));
SELECT pg_temp.ok('conditional form v1','E',pg_temp.command('form.publish',jsonb_build_object('offering_id',pg_temp.result_id('season offering'),'form_key','participant_information','title','Synthetic conditional registration','definition',jsonb_build_object('fields',jsonb_build_array(
 jsonb_build_object('key','medical_condition','type','yes_no','label','Medical condition?','required',true),
 jsonb_build_object('key','medical_detail','type','long_text','label','Synthetic follow-up','show_if',jsonb_build_array(jsonb_build_object('source','answer','field','medical_condition','op','equals','value',true)),'required_if',jsonb_build_array(jsonb_build_object('source','answer','field','medical_condition','op','equals','value',true))),
 jsonb_build_object('key','guardian_confirmation','type','acknowledgment','label','Guardian confirmation','required_if',jsonb_build_array(jsonb_build_object('source','participant_age','op','lt','value',18))),
 jsonb_build_object('key','signature','type','signature','label','Typed signature','required',true)
)))));
SELECT pg_temp.ok('waiver v1','F',pg_temp.command('waiver.publish',jsonb_build_object('offering_id',pg_temp.result_id('season offering'),'waiver_key','participation','title','Synthetic participation terms','body','Synthetic immutable accepted terms VERSION ONE.','signer_type','guardian')));
SELECT pg_temp.ok('physical requirement','H',pg_temp.command('document_requirement.upsert',jsonb_build_object('offering_id',pg_temp.result_id('season offering'),'key','sports_physical','title','Synthetic sports physical','classification','medical','emergency_access',true,'max_bytes',100000,'validity_days',365)));
SELECT pg_temp.ok('registration fee','P',pg_temp.command('fee.upsert',jsonb_build_object('offering_id',pg_temp.result_id('season offering'),'title','Synthetic $500 registration fee','charge_type','registration','amount_minor',50000,'currency','USD','due_on',current_date+30)));
SELECT pg_temp.ok('publish season','A',pg_temp.command('offering.publish',jsonb_build_object('offering_id',pg_temp.result_id('season offering'),'expected_version',1)));
SELECT pg_temp.ok('program offering','B',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic Phase3B Volleyball','scope_type','unit','scope_id',pg_temp.f('unit-sibling'),'registration_type','club','participant_type','athlete','status','published')));
SELECT pg_temp.ok('camp offering','B',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic Phase3B Camp','scope_type','organization','scope_id',pg_temp.f('org-a'),'event_id',pg_temp.f('event-a'),'registration_type','camp','participant_type','athlete','status','published')));
SELECT pg_temp.ok('travel birth certificate','L',pg_temp.command('document_requirement.upsert',jsonb_build_object('offering_id',pg_temp.result_id('program offering'),'key','birth_certificate','title','Synthetic birth certificate','classification','identity','required',true)));
SELECT pg_temp.ok('capacity offering','U',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic one seat waitlist','scope_type','organization','scope_id',pg_temp.f('org-a'),'registration_type','clinic','participant_type','athlete','capacity',1,'waitlist_enabled',true,'status','published')));
SELECT pg_temp.ok('coupon offering','DISCOUNT',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic discounted camp','scope_type','organization','scope_id',pg_temp.f('org-a'),'registration_type','camp','participant_type','athlete','status','published')));
SELECT pg_temp.ok('coupon fee','DISCOUNT',pg_temp.command('fee.upsert',jsonb_build_object('offering_id',pg_temp.result_id('coupon offering'),'title','Synthetic coupon fee','charge_type','camp','amount_minor',10000,'currency','USD')));
SELECT pg_temp.ok('fixed coupon','DISCOUNT',pg_temp.command('coupon.upsert',jsonb_build_object('offering_id',pg_temp.result_id('coupon offering'),'code','SYNTHETIC25','title','Synthetic fixed discount','adjustment_type','fixed','amount_minor',2500,'max_uses',1)));

SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('child one draft','A',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('season offering'),'participant_id',pg_temp.f('participant-child1'),'household_id',pg_temp.f('household-a'))));
SELECT pg_temp.ok('child two draft','B',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('program offering'),'participant_id',pg_temp.f('participant-child2'),'household_id',pg_temp.f('household-a'))));
SELECT pg_temp.ok('child three draft','B',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('camp offering'),'participant_id',pg_temp.f('participant-child3'),'household_id',pg_temp.f('household-a'))));
SELECT pg_temp.ok('draft saved','D',pg_temp.command('registration.save',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'expected_version',1,'context',jsonb_build_object('grade',5))));
SELECT pg_temp.deny('stale draft version','D',pg_temp.command('registration.save',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'expected_version',1,'context','{}'::jsonb)),ARRAY['PT409']);
SELECT pg_temp.deny('conditional required detail missing','E',pg_temp.command('form.answer',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'form_version_id',pg_temp.result_id('conditional form v1'),'answers',jsonb_build_object('medical_condition',true,'guardian_confirmation',true,'signature',jsonb_build_object('name','Synthetic Guardian','consent',true)),'finalize',true)),ARRAY['PT422']);
SELECT pg_temp.deny('hidden answer cannot be smuggled','E',pg_temp.command('form.answer',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'form_version_id',pg_temp.result_id('conditional form v1'),'answers',jsonb_build_object('medical_condition',false,'medical_detail','Synthetic hidden medical text','guardian_confirmation',true,'signature',jsonb_build_object('name','Synthetic Guardian','consent',true)),'finalize',true)),ARRAY['PT422']);
SELECT pg_temp.deny('underage guardian acknowledgment missing','E',pg_temp.command('form.answer',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'form_version_id',pg_temp.result_id('conditional form v1'),'answers',jsonb_build_object('medical_condition',false,'signature',jsonb_build_object('name','Synthetic Guardian','consent',true)),'finalize',true)),ARRAY['PT422']);
SELECT pg_temp.deny('signature explicit consent enforced','Y',pg_temp.command('waiver.sign',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'waiver_version_id',pg_temp.result_id('waiver v1'),'name','Synthetic Guardian','consent',false)),ARRAY['PT422']);
SELECT pg_temp.deny('submit before required forms and waiver','E',pg_temp.command('registration.submit',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'expected_version',2)),ARRAY['PT422','PT409']);
SELECT pg_temp.ok('draft form answers','D',pg_temp.command('form.answer',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'form_version_id',pg_temp.result_id('conditional form v1'),'answers',jsonb_build_object('medical_condition',true),'finalize',false)));
SELECT pg_temp.ok('final form answers','E',pg_temp.command('form.answer',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'form_version_id',pg_temp.result_id('conditional form v1'),'expected_version',1,'answers',jsonb_build_object('medical_condition',true,'medical_detail','Synthetic restricted allergy follow-up','guardian_confirmation',true,'signature',jsonb_build_object('name','Synthetic Guardian','consent',true)),'finalize',true)));
SELECT pg_temp.ok('waiver accepted','F',pg_temp.command('waiver.sign',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'waiver_version_id',pg_temp.result_id('waiver v1'),'name','Synthetic Guardian','consent',true)));
SELECT pg_temp.ok('child one submitted','A',pg_temp.command('registration.submit',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'expected_version',2)));
SELECT pg_temp.ok('child two submitted','B',pg_temp.command('registration.submit',jsonb_build_object('registration_id',pg_temp.result_id('child two draft'),'expected_version',1)));
SELECT pg_temp.ok('child three submitted','B',pg_temp.command('registration.submit',jsonb_build_object('registration_id',pg_temp.result_id('child three draft'),'expected_version',1)));
SELECT pg_temp.deny('duplicate active registration retains one identity','C',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('season offering'),'participant_id',pg_temp.f('participant-child1'),'household_id',pg_temp.f('household-a'))),ARRAY['PT409']);
SELECT pg_temp.deny('household A cannot register household B child','X',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('camp offering'),'participant_id',pg_temp.f('participant-child-other'),'household_id',pg_temp.f('household-a'))));
SELECT pg_temp.deny('forged household cannot repoint family','X',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('capacity offering'),'participant_id',pg_temp.f('participant-child1'),'household_id',pg_temp.f('household-b'))));
SELECT pg_temp.act('household-only');
SELECT pg_temp.deny('shared household alone grants no registration','X',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('capacity offering'),'participant_id',pg_temp.f('participant-child1'),'household_id',pg_temp.f('household-a'))));
SELECT pg_temp.act('unverified');
SELECT pg_temp.deny('unverified flags do not grant registration','Y',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('capacity offering'),'participant_id',pg_temp.f('participant-child1'))));
SELECT pg_temp.act('limited-guardian');
SELECT pg_temp.deny('can_register false enforced','Y',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('capacity offering'),'participant_id',pg_temp.f('participant-child1'))));
SELECT pg_temp.deny('can_sign_waivers false enforced','Y',pg_temp.command('waiver.sign',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'waiver_version_id',pg_temp.result_id('waiver v1'),'name','Synthetic Limited Guardian','consent',true)));

RESET ROLE;
SELECT pg_temp.check('three registrations reuse exactly three canonical children','B',(SELECT count(*)=3 AND count(DISTINCT participant_id)=3 AND count(DISTINCT household_id)=1 FROM public.registrations WHERE submitted_by_person_id=pg_temp.f('guardian')));
SELECT pg_temp.check('no duplicate participants or Auth for children','C',(SELECT count(*)=4 FROM public.participants WHERE person_id IN (pg_temp.f('child1'),pg_temp.f('child2'),pg_temp.f('child3'),pg_temp.f('child-other'))) AND NOT EXISTS(SELECT 1 FROM public.user_accounts WHERE person_id IN(pg_temp.f('child1'),pg_temp.f('child2'),pg_temp.f('child3'))));
SELECT pg_temp.check('submission preserves independent missing document pending approval and no roster','M',(SELECT status='submitted' AND form_status='submitted' AND waiver_status='signed' AND document_status='missing' AND eligibility_status='pending' AND approval_status='pending' AND roster_status='not_assigned' AND assigned_team_id IS NULL FROM public.registrations WHERE id=pg_temp.result_id('child one draft')));
SELECT pg_temp.check('submit did not create team membership','O',(SELECT count(*)=2 FROM public.team_memberships WHERE participant_id IN(pg_temp.f('participant-child1'),pg_temp.f('participant-child2'),pg_temp.f('participant-child3'))));
SELECT pg_temp.check('event link belongs to offering and copied charge link','W',(SELECT event_id=pg_temp.f('event-a') FROM public.registration_offerings WHERE id=pg_temp.result_id('camp offering')));
INSERT INTO pg_temp.phase3b_results SELECT 'season charge',jsonb_build_object('resource_id',id) FROM public.charges WHERE registration_id=pg_temp.result_id('child one draft');
INSERT INTO pg_temp.phase3b_results SELECT 'physical document',jsonb_build_object('resource_id',id) FROM public.registration_documents WHERE registration_id=pg_temp.result_id('child one draft');
INSERT INTO pg_temp.phase3b_results SELECT 'birth document',jsonb_build_object('resource_id',id) FROM public.registration_documents WHERE registration_id=pg_temp.result_id('child two draft');
SELECT pg_temp.check('submitted does not imply paid','M',boss_private.registration_charge_balance(pg_temp.result_id('season charge'))->>'payment_status'='unpaid');
SELECT pg_temp.check('draft save context retained','D',(SELECT context->>'grade'='5' FROM public.registrations WHERE id=pg_temp.result_id('child one draft')));

SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('waiver v2','G',pg_temp.command('waiver.publish',jsonb_build_object('offering_id',pg_temp.result_id('season offering'),'waiver_key','participation','title','Synthetic participation replacement','body','Synthetic new terms VERSION TWO.')));
SELECT pg_temp.ok('form v2','VERSION',pg_temp.command('form.publish',jsonb_build_object('offering_id',pg_temp.result_id('season offering'),'form_key','participant_information','title','Synthetic updated form','definition','{"fields":[{"key":"nickname","type":"short_text","label":"New optional nickname"}]}'::jsonb)));
RESET ROLE;
SELECT pg_temp.check('prior signed version snapshot survives later waiver publish','G',(SELECT version_snapshot->>'body'='Synthetic immutable accepted terms VERSION ONE.' AND waiver_version_id=pg_temp.result_id('waiver v1') AND signer_person_id=pg_temp.f('guardian') AND consent AND signed_at IS NOT NULL FROM public.waiver_signatures WHERE id=pg_temp.result_id('waiver accepted')));
SELECT pg_temp.check('old completed form and snapshot still point to version one','VERSION',(SELECT offering_snapshot->'forms'->0->>'form_version_id'=pg_temp.result_id('conditional form v1')::text FROM public.registrations WHERE id=pg_temp.result_id('child one draft')) AND EXISTS(SELECT 1 FROM public.registration_form_answers WHERE form_version_id=pg_temp.result_id('conditional form v1') AND status='submitted' AND answers->>'medical_detail'='Synthetic restricted allergy follow-up'));

-- Private physical upload: actual canonical storage.objects INSERT policy, then
-- each signed-client SELECT requires an audited fresh two-minute access lease.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.deny('unsafe physical MIME rejected','H',pg_temp.command('document.intent',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'mime_type','text/html','size_bytes',100)),ARRAY['PT422']);
SELECT pg_temp.deny('requirement file size maximum enforced','H',pg_temp.command('document.intent',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'mime_type','application/pdf','size_bytes',100001)),ARRAY['PT422']);
SELECT pg_temp.ok('physical upload intent','H',pg_temp.command('document.intent',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'mime_type','application/pdf','size_bytes',100)));
-- Match the managed uploader's preflight metadata and INSERT RETURNING.
-- PL/pgSQL's exception block is a savepoint-backed subtransaction: deliberately
-- roll it back while retaining local returned values for assertions afterward.
SELECT set_config('storage.operation','storage.object.upload',true);
SELECT pg_temp.check('canonical Storage upload prefix normalization','H',storage.operation()='storage.object.upload' AND storage.allow_only_operation('object.upload') AND storage.allow_only_operation('storage.object.upload') AND NOT storage.allow_only_operation(NULL) AND NOT storage.allow_only_operation(''));
DO $$DECLARE returned jsonb;rolled_back boolean:=false;BEGIN
 BEGIN
  INSERT INTO storage.objects(bucket_id,name,owner_id,metadata)
  SELECT 'boss-registration-documents',result->>'object_name',pg_temp.f('auth-guardian')::text,'{"mimetype":"application/pdf","contentLength":100}'::jsonb
  FROM pg_temp.phase3b_results WHERE label='physical upload intent'
  RETURNING metadata INTO returned;
  IF returned IS DISTINCT FROM '{"mimetype":"application/pdf","contentLength":100}'::jsonb THEN RAISE EXCEPTION 'Unexpected preflight metadata';END IF;
  RAISE EXCEPTION 'Synthetic managed preflight rollback' USING ERRCODE='P3B01';
 EXCEPTION WHEN SQLSTATE 'P3B01' THEN rolled_back:=true;
 END;
 PERFORM pg_temp.check('managed contentLength preflight INSERT RETURNING passes','H',rolled_back AND returned='{"mimetype":"application/pdf","contentLength":100}'::jsonb);
 PERFORM pg_temp.check('managed preflight savepoint leaves no object','H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
END $$;
DO $$DECLARE invalid_metadata jsonb;BEGIN
 FOR invalid_metadata IN SELECT value FROM jsonb_array_elements('[null,[],"bad",{}, {"mimetype":"application/pdf"},{"contentLength":100},{"mimetype":"application/pdf","contentLength":101},{"mimetype":"application/pdf","contentLength":-100},{"mimetype":"application/pdf","contentLength":100.5},{"mimetype":"application/pdf","contentLength":true},{"mimetype":"application/pdf","contentLength":"10000000000"},{"mimetype":"application/pdf","size":100,"contentLength":101},{"mimetype":"application/pdf","size":101,"contentLength":100},{"mimetype":"application/pdf","size":"bad","contentLength":100},{"mimetype":"text/html","contentLength":100}]'::jsonb) LOOP
  PERFORM pg_temp.sql_deny('malformed preflight metadata denied '||invalid_metadata::text,'Z',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb) RETURNING metadata','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),invalid_metadata::text));
 END LOOP;
 PERFORM pg_temp.sql_deny('SQL NULL preflight metadata denied','Z',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,NULL) RETURNING metadata','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent')));
END $$;
DO $$DECLARE returned jsonb;completion_denied boolean:=false;BEGIN
 BEGIN
  INSERT INTO storage.objects(bucket_id,name,metadata)
  SELECT 'boss-registration-documents',result->>'object_name','{"mimetype":"application/pdf","size":100,"contentLength":100}'::jsonb FROM pg_temp.phase3b_results WHERE label='physical upload intent'
  RETURNING metadata INTO returned;
  RAISE EXCEPTION 'Synthetic managed preflight rollback' USING ERRCODE='P3B01';
 EXCEPTION WHEN SQLSTATE 'P3B01' THEN NULL;
 END;
 PERFORM pg_temp.check('consistent dual preflight and final size fields accepted','H',returned='{"mimetype":"application/pdf","size":100,"contentLength":100}'::jsonb);
 BEGIN
  INSERT INTO storage.objects(bucket_id,name,metadata)
  SELECT 'boss-registration-documents',result->>'object_name','{"mimetype":"application/pdf","contentLength":100}'::jsonb FROM pg_temp.phase3b_results WHERE label='physical upload intent';
  BEGIN
   PERFORM public.boss_registration_mutate(pg_temp.f('request-preflight-only-complete'),pg_temp.command('document.complete',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'intent_id',(SELECT result->>'intent_id' FROM pg_temp.phase3b_results WHERE label='physical upload intent'))));
  EXCEPTION WHEN SQLSTATE 'PT422' THEN completion_denied:=true;
  END;
  RAISE EXCEPTION 'Synthetic managed preflight rollback' USING ERRCODE='P3B01';
 EXCEPTION WHEN SQLSTATE 'P3B01' THEN NULL;
 END;
 PERFORM pg_temp.check('document completion requires persisted actual size rather than contentLength','H',completion_denied);
 PERFORM pg_temp.check('dual-size and incomplete-object simulations roll back atomically','H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
END $$;
RESET ROLE;
UPDATE public.document_upload_intents SET object_name=object_name||'-mismatch' WHERE id=(SELECT (result->>'intent_id')::uuid FROM pg_temp.phase3b_results WHERE label='physical upload intent');
SET LOCAL ROLE authenticated;
SELECT pg_temp.sql_deny('current intent must match actual pending document path','H',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb) RETURNING metadata','boss-registration-documents',(SELECT result->>'object_name'||'-mismatch' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),'{"mimetype":"application/pdf","contentLength":100}'));
RESET ROLE;
UPDATE public.document_upload_intents SET object_name=(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent') WHERE id=(SELECT (result->>'intent_id')::uuid FROM pg_temp.phase3b_results WHERE label='physical upload intent');
SET LOCAL ROLE authenticated;
DO $$DECLARE attempted_operation text;BEGIN
 FOREACH attempted_operation IN ARRAY ARRAY['','object.sign_upload_url','storage.object.sign_upload_url','object.upload_signed','object.copy','object.update','object.get_authenticated','object.get_authenticated_info','storage.object.get_authenticated_info','object.upload.extra'] LOOP
  PERFORM set_config('storage.operation',attempted_operation,true);
  PERFORM pg_temp.sql_deny('upload intent denies metadata INSERT for operation '||coalesce(nullif(attempted_operation,''),'unset raw SQL'),'H',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb) RETURNING metadata','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),'{"mimetype":"application/pdf","contentLength":100}'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','storage.object.upload',true);
SELECT pg_temp.sql_deny('upload operation cannot replace trusted intent size','Z',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb) RETURNING metadata','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),'{"mimetype":"application/pdf","size":101}'));
RESET ROLE;
UPDATE public.document_upload_intents SET created_at=now()-interval '31 minutes',expires_at=now()-interval '1 minute' WHERE id=(SELECT (result->>'intent_id')::uuid FROM pg_temp.phase3b_results WHERE label='physical upload intent');
SET LOCAL ROLE authenticated;
SELECT pg_temp.sql_deny('expired intent denies preflight INSERT RETURNING','H',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb) RETURNING metadata','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),'{"mimetype":"application/pdf","contentLength":100}'));
RESET ROLE;
UPDATE public.document_upload_intents SET created_at=now(),expires_at=now()+interval '15 minutes' WHERE id=(SELECT (result->>'intent_id')::uuid FROM pg_temp.phase3b_results WHERE label='physical upload intent');
UPDATE public.guardian_relationships SET can_view_documents=false WHERE id=pg_temp.f('guardian-child1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.sql_deny('revoked guardian document flag denies preflight','Y',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb) RETURNING metadata','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),'{"mimetype":"application/pdf","contentLength":100}'));
RESET ROLE;
UPDATE public.guardian_relationships SET can_view_documents=true,can_register=false WHERE id=pg_temp.f('guardian-child1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.sql_deny('revoked guardian registration flag denies preflight','Y',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb) RETURNING metadata','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),'{"mimetype":"application/pdf","contentLength":100}'));
RESET ROLE;
UPDATE public.guardian_relationships SET can_register=true WHERE id=pg_temp.f('guardian-child1');
INSERT INTO auth.sessions(id,user_id) VALUES(pg_temp.f('session-guardian-preflight-alternate'),pg_temp.f('auth-guardian'));
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',(auth.jwt()||jsonb_build_object('session_id',pg_temp.f('session-guardian-preflight-alternate')))::text,true);
SELECT pg_temp.sql_deny('different live session cannot reuse upload intent','H',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb) RETURNING metadata','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),'{"mimetype":"application/pdf","contentLength":100}'));
SELECT pg_temp.act('guardian');
SELECT pg_temp.sql_deny('metadata MIME must match trusted intent','Z',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb)','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),'{"mimetype":"text/html","size":100}'));
SELECT pg_temp.sql_deny('metadata size must match trusted intent','Z',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb)','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),'{"mimetype":"application/pdf","size":101}'));
SELECT pg_temp.sql_deny('knowing a guessed object key grants no upload','Z',format('INSERT INTO storage.objects(bucket_id,name,metadata) VALUES(%L,%L,%L::jsonb)','boss-registration-documents','guessed/org/physical.pdf','{"mimetype":"application/pdf","size":100}'));
SELECT pg_temp.act('limited-guardian');
SELECT pg_temp.deny('can_view_documents false prevents upload intent','Y',pg_temp.command('document.intent',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'mime_type','application/pdf','size_bytes',100)));
SELECT pg_temp.sql_deny('different actor cannot use known authorized intent','Z',format('INSERT INTO storage.objects(bucket_id,name,owner_id,metadata) VALUES(%L,%L,%L,%L::jsonb)','boss-registration-documents',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),pg_temp.f('auth-guardian')::text,'{"mimetype":"application/pdf","size":100}'));
SELECT pg_temp.act('guardian');
SELECT set_config('storage.operation','storage.object.upload',true);
DO $$DECLARE returned jsonb;BEGIN
 INSERT INTO storage.objects(bucket_id,name,owner_id,metadata)
 SELECT 'boss-registration-documents',result->>'object_name',pg_temp.f('auth-guardian')::text,'{"mimetype":"application/pdf","size":100}'::jsonb FROM pg_temp.phase3b_results WHERE label='physical upload intent'
 RETURNING metadata INTO returned;
 PERFORM pg_temp.check('persisted backend size INSERT RETURNING passes','H',returned='{"mimetype":"application/pdf","size":100}'::jsonb);
END $$;
SELECT pg_temp.check('exact upload operation sees its own pending metadata','H',(SELECT count(*)=1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
RESET ROLE;
UPDATE public.document_upload_intents SET created_at=now()-interval '31 minutes',expires_at=now()-interval '1 minute' WHERE id=(SELECT (result->>'intent_id')::uuid FROM pg_temp.phase3b_results WHERE label='physical upload intent');
SET LOCAL ROLE authenticated;
SELECT pg_temp.check('upload RETURNING read gate rejects expired intent','H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
RESET ROLE;
UPDATE public.document_upload_intents SET created_at=now(),expires_at=now()+interval '15 minutes' WHERE id=(SELECT (result->>'intent_id')::uuid FROM pg_temp.phase3b_results WHERE label='physical upload intent');
UPDATE public.guardian_relationships SET can_view_documents=false WHERE id=pg_temp.f('guardian-child1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.check('upload RETURNING read gate rejects revoked document authority','Y',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
RESET ROLE;
UPDATE public.guardian_relationships SET can_view_documents=true,can_register=false WHERE id=pg_temp.f('guardian-child1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.check('upload RETURNING read gate rejects revoked registration authority','Y',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
RESET ROLE;
UPDATE public.guardian_relationships SET can_register=true WHERE id=pg_temp.f('guardian-child1');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',(auth.jwt()||jsonb_build_object('session_id',pg_temp.f('session-guardian-preflight-alternate')))::text,true);
SELECT pg_temp.check('upload RETURNING read gate rejects a different live session','H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
SELECT pg_temp.act('guardian');
RESET ROLE;
UPDATE auth.sessions SET not_after=now()-interval '1 second' WHERE id=pg_temp.f('session-guardian');
SET LOCAL ROLE authenticated;
SELECT pg_temp.check('upload RETURNING read gate rejects expired Auth session','H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
RESET ROLE;
UPDATE auth.sessions SET not_after=NULL WHERE id=pg_temp.f('session-guardian');
SET LOCAL ROLE authenticated;
DO $$DECLARE attempted_operation text;BEGIN
 FOREACH attempted_operation IN ARRAY ARRAY['','object.get_authenticated','storage.object.get_authenticated','object.get_authenticated_info','storage.object.get_authenticated_info','object.head','object.get','storage.object.get','object.list','object.sign','object.sign_many','object.info','object.copy','object.update','object.upload.extra','storage.storage.object.upload'] LOOP
  PERFORM set_config('storage.operation',attempted_operation,true);
  PERFORM pg_temp.check('unaudited pending object denied for operation '||coalesce(nullif(attempted_operation,''),'unset raw SQL'),'H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','',true);
SELECT pg_temp.check('uploaded bytes metadata hidden before audited lease','H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
SELECT pg_temp.ok('physical upload complete','H',pg_temp.command('document.complete',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'intent_id',(SELECT result->>'intent_id' FROM pg_temp.phase3b_results WHERE label='physical upload intent'))));
SELECT set_config('storage.operation','storage.object.upload',true);
SELECT pg_temp.check('consumed upload intent grants no completed-object read','H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
SELECT set_config('storage.operation','',true);
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('completed object without audited lease denies '||download_operation,'H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
SELECT pg_temp.ok('guardian document access','H',pg_temp.command('document.access',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'purpose','ordinary')));
SELECT pg_temp.check('authorized guardian lease permits only one physical','H',(SELECT count(*)=1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
SELECT set_config('storage.operation','object.get_authenticated_info',true);
SELECT pg_temp.check('audited lease permits normalized authenticated metadata preflight','H',(SELECT count(*)=1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
SELECT set_config('storage.operation','storage.object.get_authenticated_info',true);
SELECT pg_temp.check('audited lease permits prefixed authenticated metadata preflight','H',(SELECT count(*)=1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
-- A real isolated unleased metadata row ensures cross-path denials are not
-- vacuous empty-table checks. The fixture and all writes roll back together.
RESET ROLE;
INSERT INTO storage.objects(bucket_id,name,owner_id,metadata)
SELECT 'boss-registration-documents',result->>'object_name'||'/unleased-path',pg_temp.f('auth-guardian')::text,'{"mimetype":"application/pdf","size":100}'::jsonb FROM pg_temp.phase3b_results WHERE label='physical upload intent';
SELECT pg_temp.check('isolated unleased cross-path metadata fixture exists','H',EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents' AND name=(SELECT result->>'object_name'||'/unleased-path' FROM pg_temp.phase3b_results WHERE label='physical upload intent')));
SET LOCAL ROLE authenticated;
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('audited lease remains exact-object path for '||download_operation,'H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents' AND name=(SELECT result->>'object_name'||'/unleased-path' FROM pg_temp.phase3b_results WHERE label='physical upload intent')));
 END LOOP;
END $$;
RESET ROLE;
UPDATE auth.sessions SET not_after=now()-interval '1 second' WHERE id=pg_temp.f('session-guardian');
SET LOCAL ROLE authenticated;
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('audited lease cannot outlive expired Auth session for '||download_operation,'H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
RESET ROLE;
UPDATE auth.sessions SET not_after=NULL WHERE id=pg_temp.f('session-guardian');
DELETE FROM auth.sessions WHERE id=pg_temp.f('session-guardian');
SET LOCAL ROLE authenticated;
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('audited lease cannot outlive deleted Auth session for '||download_operation,'H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
RESET ROLE;
INSERT INTO auth.sessions(id,user_id) VALUES(pg_temp.f('session-guardian'),pg_temp.f('auth-guardian'));
SET LOCAL ROLE authenticated;
DO $$DECLARE attempted_operation text;BEGIN
 FOREACH attempted_operation IN ARRAY ARRAY['','object.sign','storage.object.sign','object.sign_many','object.list','object.info','object.copy','object.upload_signed','object.get_public','object.get_signed','object.get','object.head','object.get_authenticated_info.extra','object.download.extra'] LOOP
  PERFORM set_config('storage.operation',attempted_operation,true);
  PERFORM pg_temp.check('valid lease never grants bearer signing or alternative operation '||coalesce(nullif(attempted_operation,''),'unset raw SQL'),'H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','object.get_authenticated',true);
SELECT pg_temp.check('authenticated download operation accepts unprefixed canonical form','H',(SELECT count(*)=1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
-- UPDATE has an API metadata grant but no policy; target only this isolated
-- upload-intent fixture. Managed Storage forbids direct SQL DELETE, so immutable
-- DELETE policy closure is asserted structurally without issuing a deletion.
DO $$DECLARE affected integer;BEGIN
 UPDATE storage.objects SET metadata=metadata WHERE bucket_id='boss-registration-documents' AND name=(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent');GET DIAGNOSTICS affected=ROW_COUNT;
 PERFORM pg_temp.check('authenticated UPDATE cannot replace document object','Z',affected=0);
 PERFORM pg_temp.check('authenticated DELETE has no object replacement or erasure policy','Z',NOT EXISTS(SELECT 1 FROM pg_catalog.pg_policies WHERE schemaname='storage' AND tablename='objects' AND cmd IN('ALL','DELETE') AND (roles @> ARRAY['authenticated']::name[] OR roles @> ARRAY['public']::name[])));
END $$;
SELECT pg_temp.act('outsider');
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('known object ID grants stranger no read '||download_operation,'Z',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
SELECT pg_temp.deny('unrelated guardian known physical document denied','X',pg_temp.command('document.access',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'purpose','ordinary')));
SELECT pg_temp.act('coach');
SELECT pg_temp.deny('ordinary coach private physical denied','I',pg_temp.command('document.access',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'purpose','ordinary')));
SELECT pg_temp.deny('coach role without actual staff relation emergency denied','I',pg_temp.command('document.access',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'purpose','emergency','team_id',pg_temp.f('team-a'))));
SELECT pg_temp.act('registrar');
SELECT pg_temp.ok('physical approved','O',pg_temp.command('document.review',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'expected_version',3,'status','approved','reason','Synthetic reviewed physical','expires_on',current_date+365,'renewal_due_on',current_date+335)));
SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('synthetic emergency saved','J',pg_temp.command('emergency.save',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'contacts',jsonb_build_array(jsonb_build_object('name','Synthetic Emergency Contact','relationship','Guardian','phone','555-0100')),'medical',jsonb_build_object('allergies','Synthetic restricted allergy information'),'physician',jsonb_build_object('name','Synthetic Physician'),'insurance',jsonb_build_object('provider','Synthetic Insurance'))));
SELECT pg_temp.act('emergency');
SELECT pg_temp.ok('exact Falcons emergency access','J',pg_temp.command('emergency.access',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'purpose','emergency','team_id',pg_temp.f('team-a'))));
SELECT pg_temp.ok('exact Falcons physical emergency lease','J',pg_temp.command('document.access',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'purpose','emergency','team_id',pg_temp.f('team-a'))));
SELECT pg_temp.check('audited exact-team lease allows only approved physical','J',(SELECT count(*)=1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
SELECT pg_temp.deny('identity birth certificate outside emergency permission','I',pg_temp.command('document.access',jsonb_build_object('document_id',pg_temp.result_id('birth document'),'purpose','emergency','team_id',pg_temp.f('team-a'))));
SELECT pg_temp.deny('forged sibling team cannot broaden medical access','I',pg_temp.command('emergency.access',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'purpose','emergency','team_id',pg_temp.f('team-sibling'))));
RESET ROLE;
UPDATE public.role_assignments SET ends_at=now()-interval '1 second' WHERE id=pg_temp.f('role-emergency');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('emergency');
SELECT pg_temp.deny('expired exact-team role denies emergency RPC','K',pg_temp.command('emergency.access',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'purpose','emergency','team_id',pg_temp.f('team-a'))));
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('unexpired medical lease revoked by current role expiry '||download_operation,'K',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
RESET ROLE;
UPDATE public.role_assignments SET ends_at=NULL WHERE id=pg_temp.f('role-emergency');
UPDATE public.team_memberships SET status='inactive' WHERE person_id=pg_temp.f('emergency');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('emergency');
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('unexpired medical lease revoked by staff membership inactivity '||download_operation,'K',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
RESET ROLE;
UPDATE public.team_memberships SET status='active' WHERE person_id=pg_temp.f('emergency');
UPDATE boss_private.document_access_leases SET expires_at=now()-interval '1 second',created_at=now()-interval '2 minutes' WHERE actor_person_id=pg_temp.f('emergency');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('emergency');
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('expired medical lease no longer reads object '||download_operation,'K',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
SELECT pg_temp.act('finance');
SELECT pg_temp.deny('finance cannot read medical physical','SEPARATION',pg_temp.command('document.access',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'purpose','ordinary')));
SELECT pg_temp.deny('finance cannot retrieve emergency medical data','SEPARATION',pg_temp.command('emergency.access',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'purpose','ordinary')));
SELECT pg_temp.check('finance list has no private medical or signed answer values','SEPARATION',public.boss_registration_read(jsonb_build_object('view','admin','organization_id',pg_temp.f('org-a'),'registration_id',pg_temp.result_id('child one draft')))::text !~ '(Synthetic restricted|Synthetic Physician|Synthetic Insurance|medical_detail|signer_name|object_name)');

SELECT pg_temp.ok('five hundred installment plan','T',pg_temp.command('payment_plan.create',jsonb_build_object('charge_id',pg_temp.result_id('season charge'),'title','Synthetic deposit and two installments','installments',jsonb_build_array(jsonb_build_object('amount_minor',10000,'due_on',current_date+1),jsonb_build_object('amount_minor',20000,'due_on',current_date+15),jsonb_build_object('amount_minor',20000,'due_on',current_date+30)))));
SELECT pg_temp.deny('installment total cannot diverge from obligation','T',pg_temp.command('payment_plan.create',jsonb_build_object('charge_id',pg_temp.result_id('season charge'),'title','Synthetic invalid installments','installments',jsonb_build_array(jsonb_build_object('amount_minor',49999,'due_on',current_date+1)))),ARRAY['PT422']);
SELECT pg_temp.deny('installment dates must be ordered','T',pg_temp.command('payment_plan.create',jsonb_build_object('charge_id',pg_temp.result_id('season charge'),'title','Synthetic backward installments','installments',jsonb_build_array(jsonb_build_object('amount_minor',25000,'due_on',current_date+30),jsonb_build_object('amount_minor',25000,'due_on',current_date+1)))),ARRAY['PT422']);
SELECT pg_temp.ok('cash one hundred','P',pg_temp.payment('cash',10000));
SELECT pg_temp.ok('check one fifty','P',pg_temp.payment('check',15000));
SELECT pg_temp.check('exact request payment retry returns original evidence','IDEMPOTENCY',public.boss_registration_mutate(pg_temp.f('request-cash one hundred'),pg_temp.payment('cash',10000))->>'resource_id'=pg_temp.result_id('cash one hundred')::text);
SELECT pg_temp.deny('changed payment payload same request rejected','IDEMPOTENCY',pg_temp.payment('cash',10001),ARRAY['PT409'],'cash one hundred');
SELECT pg_temp.deny('card not operational in offline foundation','BOUNDARY',pg_temp.payment('card',1000),ARRAY['PT422']);
SELECT pg_temp.deny('ACH distinct from manual check and not operational','BOUNDARY',pg_temp.payment('ach',1000),ARRAY['PT422']);
SELECT pg_temp.deny('Boss Bucks cannot be spent in this phase','BOUNDARY',pg_temp.payment('boss_bucks',1000),ARRAY['PT422']);
SELECT pg_temp.deny('overpayment cannot exceed remaining charge','P',pg_temp.payment('cash',25001),ARRAY['PT409','PT422']);
SELECT pg_temp.ok('birth registration obligation','N',pg_temp.command('charge.create',jsonb_build_object('registration_id',pg_temp.result_id('child two draft'),'title','Synthetic independent birth document test charge','charge_type','club','amount_minor',10000,'currency','USD')));
SELECT pg_temp.ok('birth registration fully paid','N',pg_temp.payment('cash',10000,pg_temp.result_id('birth registration obligation')));
SELECT pg_temp.ok('camp adjustment obligation','DISCOUNT',pg_temp.command('charge.create',jsonb_build_object('registration_id',pg_temp.result_id('child three draft'),'title','Synthetic camp adjustment charge','charge_type','camp','amount_minor',10000,'currency','USD')));
SELECT pg_temp.ok('explicit scholarship adjustment','DISCOUNT',pg_temp.command('charge.adjust',jsonb_build_object('charge_id',pg_temp.result_id('camp adjustment obligation'),'amount_minor',-2000,'adjustment_type','scholarship','reason','Synthetic approved scholarship')));
SELECT pg_temp.deny('negative surcharge sign invalid','DISCOUNT',pg_temp.command('charge.adjust',jsonb_build_object('charge_id',pg_temp.result_id('camp adjustment obligation'),'amount_minor',-1,'adjustment_type','surcharge','reason','Synthetic invalid sign')),ARRAY['PT422']);
SELECT pg_temp.act('registrar');
SELECT pg_temp.deny('registrar cannot make financial adjustments','SEPARATION',pg_temp.command('charge.adjust',jsonb_build_object('charge_id',pg_temp.result_id('camp adjustment obligation'),'amount_minor',-100,'adjustment_type','credit','reason','Synthetic denied registrar adjustment')));
SELECT pg_temp.deny('registrar cannot record offline payment','Q',pg_temp.payment('cash',100));
SELECT pg_temp.act('coach');
SELECT pg_temp.deny('coach cannot record offline payment','R',pg_temp.payment('cash',100));
SELECT pg_temp.act('guardian');
SELECT pg_temp.deny('guardian payment-management flag does not grant offline recorder','Q',pg_temp.payment('cash',100));
SELECT pg_temp.act('admin-b');
SELECT pg_temp.deny('other tenant admin cannot mutate charge','S',pg_temp.command('charge.adjust',jsonb_build_object('charge_id',pg_temp.result_id('camp adjustment obligation'),'amount_minor',-100,'adjustment_type','credit','reason','Synthetic cross tenant')));
SELECT pg_temp.deny('other tenant payment org cannot allocate known charge','S',pg_temp.payment('cash',100,NULL,pg_temp.f('org-b')));
SELECT pg_temp.act('expired');
SELECT pg_temp.deny('expired financial grant cannot record payment','Q',pg_temp.payment('cash',100));
RESET ROLE;
SELECT pg_temp.check('$500 minus $100 cash minus $150 check leaves $250','P',boss_private.registration_charge_balance(pg_temp.result_id('season charge')) @> '{"original_amount_minor":50000,"adjusted_amount_minor":50000,"applied_amount_minor":25000,"balance_due_minor":25000,"payment_status":"partially_paid"}'::jsonb);
SELECT pg_temp.check('cash and check remain distinct canonical evidence','P',(SELECT count(*)=2 AND sum(amount_minor)=25000 AND count(DISTINCT method)=2 FROM public.payments WHERE id IN(pg_temp.result_id('cash one hundred'),pg_temp.result_id('check one fifty'))));
SELECT pg_temp.check('same payment request has one payment allocation and audit','IDEMPOTENCY',(SELECT count(*)=1 FROM public.payment_allocations WHERE payment_id=pg_temp.result_id('cash one hundred')) AND (SELECT count(*)=1 FROM public.audit_events WHERE request_id=pg_temp.f('request-cash one hundred') AND action='payment.record_offline'));
SELECT pg_temp.check('both manual payment entries audited with canonical recorder','Q',(SELECT count(*)=2 AND bool_and(actor_person_id=pg_temp.f('finance')) FROM public.audit_events WHERE request_id IN(pg_temp.f('request-cash one hundred'),pg_temp.f('request-check one fifty')) AND action='payment.record_offline'));
SELECT pg_temp.check('installments preserve deposit and sum exact obligation','T',(SELECT count(*)=3 AND sum(amount_minor)=50000 AND min(sequence_number)=1 AND max(sequence_number)=3 FROM public.payment_installments WHERE payment_plan_id=pg_temp.result_id('five hundred installment plan')));
SELECT pg_temp.check('paid does not approve birth document or registration','N',boss_private.registration_charge_balance(pg_temp.result_id('birth registration obligation'))->>'payment_status'='paid' AND (SELECT document_status='missing' AND approval_status='pending' AND roster_status='not_assigned' FROM public.registrations WHERE id=pg_temp.result_id('child two draft')));
SELECT pg_temp.check('approved physical does not assign roster','O',(SELECT document_status='approved' AND roster_status='not_assigned' AND assigned_team_id IS NULL FROM public.registrations WHERE id=pg_temp.result_id('child one draft')));
SELECT pg_temp.check('explicit adjustment amount and append-only evidence','DISCOUNT',boss_private.registration_charge_balance(pg_temp.result_id('camp adjustment obligation'))->>'balance_due_minor'='8000' AND EXISTS(SELECT 1 FROM public.audit_events WHERE request_id=pg_temp.f('request-explicit scholarship adjustment') AND action='charge.adjust'));

-- Current authority is checked on financial replay as well as first execution.
UPDATE public.role_assignments SET status='inactive' WHERE id=pg_temp.f('role-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('finance');
SELECT pg_temp.deny('inactive finance role cannot replay prior payment','IDEMPOTENCY',pg_temp.payment('cash',10000),ARRAY['PT403'],'cash one hundred');
RESET ROLE;
UPDATE public.role_assignments SET status='active' WHERE id=pg_temp.f('role-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('capacity first draft','V',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('capacity offering'),'participant_id',pg_temp.f('participant-child1'))));
SELECT pg_temp.ok('capacity second draft','V',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('capacity offering'),'participant_id',pg_temp.f('participant-child2'))));
SELECT pg_temp.ok('capacity third draft','V',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('capacity offering'),'participant_id',pg_temp.f('participant-child3'))));
SELECT pg_temp.ok('capacity first submit','V',pg_temp.command('registration.submit',jsonb_build_object('registration_id',pg_temp.result_id('capacity first draft'),'expected_version',1)));
SELECT pg_temp.ok('capacity second waitlist','V',pg_temp.command('registration.submit',jsonb_build_object('registration_id',pg_temp.result_id('capacity second draft'),'expected_version',1)));
SELECT pg_temp.ok('capacity third waitlist','V',pg_temp.command('registration.submit',jsonb_build_object('registration_id',pg_temp.result_id('capacity third draft'),'expected_version',1)));
SELECT pg_temp.act('admin-a');
SELECT pg_temp.deny('waitlist promotion cannot exceed capacity','U',pg_temp.command('registration.decision',jsonb_build_object('registration_id',pg_temp.result_id('capacity second draft'),'expected_version',2,'decision','promote','reason','Synthetic full capacity')),ARRAY['PT409']);
SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('capacity first withdrawn','V',pg_temp.command('registration.withdraw',jsonb_build_object('registration_id',pg_temp.result_id('capacity first draft'),'expected_version',2,'reason','Synthetic free seat')));
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('waitlist controlled promotion','V',pg_temp.command('registration.decision',jsonb_build_object('registration_id',pg_temp.result_id('capacity second draft'),'expected_version',2,'decision','promote','reason','Synthetic next available place')));
SELECT pg_temp.ok('child three reviewed','APPROVAL',pg_temp.command('registration.decision',jsonb_build_object('registration_id',pg_temp.result_id('child three draft'),'expected_version',2,'decision','approve','reason','Synthetic camp approval')));
SELECT pg_temp.ok('child three explicit team assignment','O',pg_temp.command('registration.assign_team',jsonb_build_object('registration_id',pg_temp.result_id('child three draft'),'expected_version',3,'team_id',pg_temp.f('team-a'))));
SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('returning child new offering','C',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('camp offering'),'participant_id',pg_temp.f('participant-child1'),'household_id',pg_temp.f('household-a'))));
SELECT pg_temp.ok('coupon child draft','DISCOUNT',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('coupon offering'),'participant_id',pg_temp.f('participant-child1'))));
SELECT pg_temp.ok('coupon applied on submission','DISCOUNT',pg_temp.command('registration.submit',jsonb_build_object('registration_id',pg_temp.result_id('coupon child draft'),'expected_version',1,'coupon_code','SYNTHETIC25')));
SELECT pg_temp.ok('coupon second child draft','DISCOUNT',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('coupon offering'),'participant_id',pg_temp.f('participant-child2'))));
SELECT pg_temp.deny('coupon exhausted server-side','DISCOUNT',pg_temp.command('registration.submit',jsonb_build_object('registration_id',pg_temp.result_id('coupon second child draft'),'expected_version',1,'coupon_code','SYNTHETIC25')),ARRAY['PT422']);
RESET ROLE;
SELECT pg_temp.check('one capacity reservation after withdrawal and promotion','V',(SELECT count(*)=1 FROM public.registrations WHERE offering_id=pg_temp.result_id('capacity offering') AND status IN('submitted','under_review','approved')));
SELECT pg_temp.check('stable waitlist position retained for third child','V',(SELECT status='waitlisted' AND waitlist_position=2 FROM public.registrations WHERE id=pg_temp.result_id('capacity third draft')));
SELECT pg_temp.check('returning uses original participant and retains previous historical snapshot','C',(SELECT participant_id=pg_temp.f('participant-child1') FROM public.registrations WHERE id=pg_temp.result_id('returning child new offering')) AND (SELECT offering_snapshot->'waivers'->0->>'waiver_version_id'=pg_temp.result_id('waiver v1')::text FROM public.registrations WHERE id=pg_temp.result_id('child one draft')));
SELECT pg_temp.check('explicit approved team assignment audited','O',(SELECT roster_status='assigned' AND assigned_team_id=pg_temp.f('team-a') FROM public.registrations WHERE id=pg_temp.result_id('child three draft')) AND EXISTS(SELECT 1 FROM public.audit_events WHERE request_id=pg_temp.f('request-child three explicit team assignment') AND action='registration.assign_team'));
SELECT pg_temp.check('coupon explicit adjustment preserves $75 balance','DISCOUNT',EXISTS(SELECT 1 FROM public.charges c WHERE c.registration_id=pg_temp.result_id('coupon child draft') AND boss_private.registration_charge_balance(c.id)->>'balance_due_minor'='7500') AND EXISTS(SELECT 1 FROM public.charge_adjustments a JOIN public.charges c ON c.id=a.charge_id WHERE c.registration_id=pg_temp.result_id('coupon child draft') AND a.amount_minor=-2500 AND a.adjustment_type='coupon') AND EXISTS(SELECT 1 FROM public.audit_events WHERE request_id=pg_temp.f('request-coupon applied on submission') AND action='coupon.apply'));
SELECT pg_temp.check('exhausted coupon atomic rollback leaves draft and no charge','DISCOUNT',(SELECT status='draft' FROM public.registrations WHERE id=pg_temp.result_id('coupon second child draft')) AND NOT EXISTS(SELECT 1 FROM public.charges WHERE registration_id=pg_temp.result_id('coupon second child draft')));

-- Every sensitive evidence table is closed through both API roles. Immutable
-- triggers are additionally exercised as the trusted local owner: they protect
-- history independently of whether clients ever gain a raw table grant.
DO $$DECLARE t text;role_name text;action text;col text;statement text;BEGIN
 FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
  EXECUTE format('SET LOCAL ROLE %I',role_name);
  FOR t IN SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname='public' AND tablename=ANY(ARRAY['registration_offerings','registration_form_versions','registration_waiver_versions','document_requirements','registration_offering_forms','registration_offering_waivers','registration_offering_documents','registration_fee_rules','registration_coupons','registrations','registration_form_answers','waiver_signatures','registration_documents','document_upload_intents','participant_emergency_records','charges','charge_adjustments','payments','payment_allocations','payment_plans','payment_installments']) LOOP
   SELECT attname INTO col FROM pg_catalog.pg_attribute WHERE attrelid=('public.'||t)::regclass AND attnum>0 AND NOT attisdropped ORDER BY attnum LIMIT 1;
   FOREACH action IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE'] LOOP
    statement:=CASE action WHEN 'SELECT' THEN format('SELECT count(*) FROM public.%I WHERE false',t) WHEN 'INSERT' THEN format('INSERT INTO public.%I DEFAULT VALUES',t) WHEN 'UPDATE' THEN format('UPDATE public.%I SET %I=%I WHERE false',t,col,col) WHEN 'DELETE' THEN format('DELETE FROM public.%I WHERE false',t) ELSE format('TRUNCATE public.%I',t) END;
    PERFORM pg_temp.sql_deny(role_name||' actual '||action||' denied '||t,'Z',statement);
   END LOOP;
  END LOOP;
  EXECUTE 'RESET ROLE';
 END LOOP;
END $$;
SELECT pg_temp.sql_deny('waiver version immutable even trusted owner','G',format('UPDATE public.registration_waiver_versions SET body=%L WHERE id=%L','Synthetic rewritten terms',pg_temp.result_id('waiver v1')),ARRAY['PT409']);
SELECT pg_temp.sql_deny('signature snapshot immutable even trusted owner','F',format('UPDATE public.waiver_signatures SET signer_name=%L WHERE id=%L','Synthetic forged signer',pg_temp.result_id('waiver accepted')),ARRAY['PT409']);
SELECT pg_temp.sql_deny('form definition immutable even trusted owner','VERSION',format('DELETE FROM public.registration_form_versions WHERE id=%L',pg_temp.result_id('conditional form v1')),ARRAY['PT409']);
SELECT pg_temp.sql_deny('completed form answer immutable even trusted owner','VERSION',format('UPDATE public.registration_form_answers SET answers=%L::jsonb WHERE id=%L','{}',pg_temp.result_id('final form answers')),ARRAY['PT409']);
SELECT pg_temp.sql_deny('cash payment cannot be silently changed','P',format('UPDATE public.payments SET amount_minor=1 WHERE id=%L',pg_temp.result_id('cash one hundred')),ARRAY['PT409']);
SELECT pg_temp.sql_deny('allocation cannot be silently deleted','P',format('DELETE FROM public.payment_allocations WHERE payment_id=%L',pg_temp.result_id('check one fifty')),ARRAY['PT409']);
SELECT pg_temp.sql_deny('discount evidence cannot be silently rewritten','DISCOUNT',format('UPDATE public.charge_adjustments SET amount_minor=-9000 WHERE id=%L',pg_temp.result_id('explicit scholarship adjustment')),ARRAY['PT409']);
SELECT pg_temp.sql_deny('installment schedule evidence immutable','T',format('UPDATE public.payment_installments SET amount_minor=1 WHERE payment_plan_id=%L',pg_temp.result_id('five hundred installment plan')),ARRAY['PT409']);
SELECT pg_temp.check('physical upload and review retain all previous document versions','H',(SELECT count(*)=3 AND min(version)=1 AND max(version)=3 FROM boss_private.registration_document_history WHERE document_id=pg_temp.result_id('physical document')));
SELECT pg_temp.sql_deny('document historical evidence cannot be rewritten','H',format('UPDATE boss_private.registration_document_history SET snapshot=%L::jsonb WHERE document_id=%L','{}',pg_temp.result_id('physical document')),ARRAY['PT409']);

UPDATE public.guardian_relationships SET can_register=true WHERE id=pg_temp.f('limited-guardian');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('limited-guardian');
SELECT pg_temp.check('registration authority does not grant financial charge details','Y',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('child one draft')))->'detail'->'charges'='[]'::jsonb);
SELECT pg_temp.deny('separate signing flag denied despite registration authority','Y',pg_temp.command('waiver.sign',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'waiver_version_id',pg_temp.result_id('waiver v1'),'name','Synthetic Limited Guardian','consent',true)));
SELECT pg_temp.deny('embedded form signature cannot bypass signing flag','Y',pg_temp.command('form.answer',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'form_version_id',pg_temp.result_id('conditional form v1'),'answers',jsonb_build_object('medical_condition',false,'guardian_confirmation',true,'signature',jsonb_build_object('name','Synthetic Limited Guardian','consent',true)),'finalize',true)));
SELECT pg_temp.deny('separate documents flag denied despite registration authority','Y',pg_temp.command('document.access',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'purpose','ordinary')));
RESET ROLE;
UPDATE public.guardian_relationships SET can_view_documents=false WHERE id=pg_temp.f('guardian-child1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('revoked guardian document flag invalidates unexpired lease '||download_operation,'Y',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
SELECT pg_temp.deny('revoked document flag prevents prior access replay','IDEMPOTENCY',pg_temp.command('document.access',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'purpose','ordinary')),ARRAY['PT403'],'guardian document access');
RESET ROLE;
UPDATE public.guardian_relationships SET can_view_documents=true,can_sign_waivers=false,can_manage_payments=false WHERE id=pg_temp.f('guardian-child1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.deny('revoked signing flag prevents prior signature replay','IDEMPOTENCY',pg_temp.command('waiver.sign',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'waiver_version_id',pg_temp.result_id('waiver v1'),'name','Synthetic Guardian','consent',true)),ARRAY['PT403'],'waiver accepted');
SELECT pg_temp.check('revoked payments flag hides financial allocations','Y',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('child one draft')))->'detail'->'charges'='[]'::jsonb);
RESET ROLE;
UPDATE public.guardian_relationships SET can_sign_waivers=true,can_manage_payments=true WHERE id=pg_temp.f('guardian-child1');
INSERT INTO auth.sessions(id,user_id) VALUES(pg_temp.f('session-guardian-alternate'),pg_temp.f('auth-guardian'));
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT set_config('request.jwt.claims',(auth.jwt()||jsonb_build_object('session_id',pg_temp.f('session-guardian-alternate')))::text,true);
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('different valid session cannot reuse private download lease '||download_operation,'H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
SELECT pg_temp.act('guardian');
SELECT pg_temp.check('family drilldown retains child name','READ',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read('{}')->'registrations') x WHERE x->>'participant_label'='Synthetic Phase3B child1'));
SELECT pg_temp.check('event linked offering projection names actual event','W',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read('{}')->'offerings') x WHERE x->>'id'=pg_temp.result_id('camp offering')::text AND x->>'event_id'=pg_temp.f('event-a')::text AND x->>'event_title'='Synthetic Phase3B linked camp'));
SELECT pg_temp.read_deny('knowing another family registration ID no access',jsonb_build_object('registration_id',pg_temp.f('unknown-registration')));
SELECT pg_temp.read_deny('cross-organization registration context refused',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'organization_id',pg_temp.f('org-b')));
SELECT pg_temp.read_deny('unknown privileged read fields denied',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'include_medical',true),ARRAY['PT422']);
SELECT pg_temp.act('unit');
SELECT pg_temp.deny('exact unit has no sibling program management','SCOPE',pg_temp.command('waiver.publish',jsonb_build_object('offering_id',pg_temp.result_id('program offering'),'waiver_key','forged_sibling','title','Synthetic denied sibling waiver','body','Synthetic denied.')));
SELECT pg_temp.deny('exact unit has no organization-wide management','SCOPE',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic denied org authority','scope_type','organization','scope_id',pg_temp.f('org-a'),'registration_type','camp')));
SELECT pg_temp.deny('exact unit no implicit child-unit inheritance','SCOPE',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic denied descendant authority','scope_type','unit','scope_id',pg_temp.f('unit-child'),'registration_type','camp')));
SELECT pg_temp.act('outsider');
SELECT pg_temp.read_deny('known family registration ID grants outsider no read',jsonb_build_object('registration_id',pg_temp.result_id('child one draft')));
SELECT pg_temp.deny('forged event IDs cannot authorize registration alteration','SCOPE',pg_temp.command('registration.save',jsonb_build_object('registration_id',pg_temp.result_id('child one draft'),'expected_version',3,'context','{}'::jsonb)));
SELECT pg_temp.act('unconfirmed');
SELECT pg_temp.deny('unconfirmed Auth denied sensitive mutation','AUTH',pg_temp.payment('cash',1),ARRAY['PT401','PT403']);
SELECT pg_temp.act('anonymous');
SELECT pg_temp.deny('anonymous sign-in role cannot mutate private records','AUTH',pg_temp.payment('cash',1),ARRAY['PT401','PT403']);
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{}',true);
SELECT pg_temp.sql_deny('anonymous actual registration RPC denied','Z','SELECT public.boss_registration_read(''{}''::jsonb)');
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('anonymous storage listing empty '||download_operation,'H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents'));
 END LOOP;
END $$;
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
RESET ROLE;
SELECT pg_temp.check('emergency sensitive access audited without medical plaintext','AUDIT',EXISTS(SELECT 1 FROM public.audit_events WHERE request_id=pg_temp.f('request-exact Falcons emergency access') AND action='emergency.access') AND NOT EXISTS(SELECT 1 FROM public.audit_events WHERE organization_id=pg_temp.f('org-a') AND (coalesce(before_data::text,'')||coalesce(after_data::text,'')) ~ '(Synthetic restricted|Synthetic Physician|Synthetic Insurance|555-0100|Synthetic Guardian|VERSION ONE)'));
SELECT pg_temp.check('authorized physical access audits each new lease','AUDIT',(SELECT count(*)=2 FROM public.audit_events WHERE request_id IN(pg_temp.f('request-guardian document access'),pg_temp.f('request-exact Falcons physical emergency lease')) AND action='document.access'));
SELECT pg_temp.check('denied modified financial request leaves no extra allocation','ATOMIC',(SELECT count(*)=1 FROM public.payment_allocations WHERE payment_id=pg_temp.result_id('cash one hundred')));

-- Server-side form DSL validation is tested independently of any frontend.
-- These pure validation calls run as the local fixture owner because their
-- helpers are deliberately unavailable as standalone client RPCs.
SELECT pg_temp.act('guardian');
DO $$DECLARE field_type text;f jsonb;definition jsonb;answers jsonb;value jsonb;BEGIN
 FOREACH field_type IN ARRAY ARRAY['short_text','long_text','email','phone','number','date','dropdown','radio','checkbox','multi_select','yes_no','address','file_upload','acknowledgment','signature','emergency_contact','content'] LOOP
  f:=jsonb_build_object('key','test_field','type',field_type,'label','Synthetic typed field');
  IF field_type IN('dropdown','radio','multi_select') THEN f:=f||'{"options":["a","b"]}'::jsonb;END IF;
  definition:=jsonb_build_object('fields',jsonb_build_array(f));
  value:=CASE field_type WHEN 'short_text' THEN '"Synthetic short"'::jsonb WHEN 'long_text' THEN '"Synthetic long"'::jsonb WHEN 'email' THEN '"synthetic@example.invalid"'::jsonb WHEN 'phone' THEN '"555-0100"'::jsonb WHEN 'number' THEN '5'::jsonb WHEN 'date' THEN '"2026-10-01"'::jsonb WHEN 'dropdown' THEN '"a"'::jsonb WHEN 'radio' THEN '"b"'::jsonb WHEN 'checkbox' THEN 'true'::jsonb WHEN 'multi_select' THEN '["a","b"]'::jsonb WHEN 'yes_no' THEN 'false'::jsonb WHEN 'address' THEN '{"line1":"Synthetic test address","city":"Synthetic city"}'::jsonb WHEN 'file_upload' THEN to_jsonb(pg_temp.result_id('physical document')::text) WHEN 'acknowledgment' THEN 'true'::jsonb WHEN 'signature' THEN '{"name":"Synthetic Guardian","consent":true}'::jsonb WHEN 'emergency_contact' THEN to_jsonb(pg_temp.result_id('synthetic emergency saved')::text) ELSE NULL END;
  answers:=CASE WHEN field_type='content' THEN '{}'::jsonb ELSE jsonb_build_object('test_field',value) END;
  PERFORM boss_private.registration_validate_form_answers(definition,answers,pg_temp.f('participant-child1'),'{}',true);
  PERFORM pg_temp.check('bounded server field type '||field_type,'FORM_TYPES',true);
 END LOOP;
END $$;
SELECT pg_temp.sql_deny('forward condition reference rejected','E',$sql$SELECT boss_private.registration_validate_form_definition('{"fields":[{"key":"a","type":"short_text","label":"A","show_if":[{"source":"answer","field":"b","op":"equals","value":true}]},{"key":"b","type":"yes_no","label":"B"}]}')$sql$,ARRAY['PT422']);
SELECT pg_temp.sql_deny('unknown condition source rejected','E',$sql$SELECT boss_private.registration_validate_form_definition('{"fields":[{"key":"a","type":"short_text","label":"A","show_if":[{"source":"script","field":"is_admin","op":"equals","value":true}]}]}')$sql$,ARRAY['PT422']);
SELECT pg_temp.sql_deny('missing condition source rejected','E',$sql$SELECT boss_private.registration_validate_form_definition('{"fields":[{"key":"a","type":"short_text","label":"A","show_if":[{"op":"equals","value":true}]}]}')$sql$,ARRAY['PT422']);
SELECT pg_temp.sql_deny('unknown arbitrary privileged context rejected','E',format('SELECT boss_private.registration_validate_form_answers(%L::jsonb,%L::jsonb,%L::uuid,%L::jsonb,true)','{"fields":[{"key":"a","type":"yes_no","label":"A"}]}','{}',pg_temp.f('participant-child1'),' {"is_admin":true}'),ARRAY['PT422']);
SELECT pg_temp.sql_deny('invalid calendar date answer rejected','FORM_TYPES',format('SELECT boss_private.registration_validate_form_answers(%L::jsonb,%L::jsonb,%L::uuid,%L::jsonb,true)','{"fields":[{"key":"a","type":"date","label":"A"}]}','{"a":"2026-02-30"}',pg_temp.f('participant-child1'),'{}'),ARRAY['PT422']);
SELECT pg_temp.sql_deny('duplicate multi-select options rejected','FORM_TYPES',format('SELECT boss_private.registration_validate_form_answers(%L::jsonb,%L::jsonb,%L::uuid,%L::jsonb,true)','{"fields":[{"key":"a","type":"multi_select","label":"A","options":["x","y"]}]}','{"a":["x","x"]}',pg_temp.f('participant-child1'),'{}'),ARRAY['PT422']);
SELECT pg_temp.sql_deny('participant medical reference cannot cross children','FORM_TYPES',format('SELECT boss_private.registration_validate_form_answers(%L::jsonb,%L::jsonb,%L::uuid,%L::jsonb,true)','{"fields":[{"key":"a","type":"file_upload","label":"A"}]}',jsonb_build_object('a',pg_temp.result_id('physical document'))::text,pg_temp.f('participant-child2'),'{}'),ARRAY['PT422']);
SELECT pg_temp.sql_deny('travel context conditional requirement enforced','E',format('SELECT boss_private.registration_validate_form_answers(%L::jsonb,%L::jsonb,%L::uuid,%L::jsonb,true)','{"fields":[{"key":"a","type":"short_text","label":"Synthetic travel terms","show_if":[{"source":"context","field":"travel_team_selected","op":"equals","value":true}],"required_if":[{"source":"context","field":"travel_team_selected","op":"equals","value":true}]}]}','{}',pg_temp.f('participant-child1'),'{"travel_team_selected":true}'),ARRAY['PT422']);
SELECT pg_temp.sql_deny('payment-plan conditional acknowledgment enforced','E',format('SELECT boss_private.registration_validate_form_answers(%L::jsonb,%L::jsonb,%L::uuid,%L::jsonb,true)','{"fields":[{"key":"a","type":"acknowledgment","label":"Synthetic installment terms","show_if":[{"source":"context","field":"payment_plan_selected","op":"equals","value":true}],"required_if":[{"source":"context","field":"payment_plan_selected","op":"equals","value":true}]}]}','{"a":false}',pg_temp.f('participant-child1'),'{"payment_plan_selected":true}'),ARRAY['PT422']);

SET LOCAL ROLE authenticated;
SELECT pg_temp.act('finance');
SELECT pg_temp.deny('cancel cannot erase already applied cash and check','P',pg_temp.command('charge.cancel',jsonb_build_object('charge_id',pg_temp.result_id('season charge'),'reason','Synthetic prohibited payment erasure')),ARRAY['PT409']);
SELECT pg_temp.ok('camp installment plan','T',pg_temp.command('payment_plan.create',jsonb_build_object('charge_id',pg_temp.result_id('camp adjustment obligation'),'title','Synthetic adjusted obligation installments','installments',jsonb_build_array(jsonb_build_object('amount_minor',4000,'due_on',current_date+1),jsonb_build_object('amount_minor',4000,'due_on',current_date+15)))));
SELECT pg_temp.deny('planned charge adjustment requires reviewed plan replacement','T',pg_temp.command('charge.adjust',jsonb_build_object('charge_id',pg_temp.result_id('camp adjustment obligation'),'amount_minor',-1000,'adjustment_type','credit','reason','Synthetic planned charge adjustment')),ARRAY['PT409']);
SELECT pg_temp.ok('camp plan canceled','T',pg_temp.command('payment_plan.cancel',jsonb_build_object('charge_id',pg_temp.result_id('camp adjustment obligation'),'reason','Synthetic reviewed plan replacement')));
SELECT pg_temp.check('plan cancellation retry preserves original result','IDEMPOTENCY',public.boss_registration_mutate(pg_temp.f('request-camp plan canceled'),pg_temp.command('payment_plan.cancel',jsonb_build_object('charge_id',pg_temp.result_id('camp adjustment obligation'),'reason','Synthetic reviewed plan replacement')))->>'resource_id'=pg_temp.result_id('camp plan canceled')::text);
SELECT pg_temp.ok('reviewed unplanned charge credit','DISCOUNT',pg_temp.command('charge.adjust',jsonb_build_object('charge_id',pg_temp.result_id('camp adjustment obligation'),'amount_minor',-1000,'adjustment_type','credit','reason','Synthetic approved credit after plan cancellation')));
SELECT pg_temp.ok('unpaid camp charge canceled','P',pg_temp.command('charge.cancel',jsonb_build_object('charge_id',pg_temp.result_id('camp adjustment obligation'),'reason','Synthetic canceled obligation')));
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('explicit team assignment removed','O',pg_temp.command('registration.remove_team',jsonb_build_object('registration_id',pg_temp.result_id('child three draft'),'expected_version',4,'reason','Synthetic remove controlled roster placement')));
SELECT pg_temp.check('roster removal retry reauthorizes original exact team','IDEMPOTENCY',public.boss_registration_mutate(pg_temp.f('request-explicit team assignment removed'),pg_temp.command('registration.remove_team',jsonb_build_object('registration_id',pg_temp.result_id('child three draft'),'expected_version',4,'reason','Synthetic remove controlled roster placement')))->>'resource_id'=pg_temp.result_id('child three draft')::text);
SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('reviewed registration withdrawn','STATUS',pg_temp.command('registration.withdraw',jsonb_build_object('registration_id',pg_temp.result_id('child three draft'),'expected_version',5,'reason','Synthetic controlled withdrawal')));
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('withdrawn registration archived','STATUS',pg_temp.command('registration.decision',jsonb_build_object('registration_id',pg_temp.result_id('child three draft'),'expected_version',6,'decision','archive','reason','Synthetic historical archive')));
RESET ROLE;
SELECT pg_temp.check('canceled charge preserves original amount and all explicit adjustments','P',(SELECT status='canceled' AND original_amount_minor=10000 FROM public.charges WHERE id=pg_temp.result_id('camp adjustment obligation')) AND (SELECT count(*)=2 AND sum(amount_minor)=-3000 FROM public.charge_adjustments WHERE charge_id=pg_temp.result_id('camp adjustment obligation')));
SELECT pg_temp.check('canceled plan retains immutable installment schedule','T',(SELECT status='canceled' FROM public.payment_plans WHERE id=pg_temp.result_id('camp installment plan')) AND (SELECT count(*)=2 AND sum(amount_minor)=8000 FROM public.payment_installments WHERE payment_plan_id=pg_temp.result_id('camp installment plan')));
SELECT pg_temp.check('remove assignment inactivates own placement only and preserves history','O',(SELECT roster_status='removed' AND assigned_team_id IS NULL AND status='archived' FROM public.registrations WHERE id=pg_temp.result_id('child three draft')) AND EXISTS(SELECT 1 FROM public.team_memberships WHERE participant_id=pg_temp.f('participant-child3') AND team_id=pg_temp.f('team-a') AND status='inactive') AND EXISTS(SELECT 1 FROM public.team_memberships WHERE participant_id=pg_temp.f('participant-child1') AND team_id=pg_temp.f('team-a') AND status='active'));

SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('medical form offering','SEPARATION',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic restricted medical form offering','scope_type','team','scope_id',pg_temp.f('team-a'),'registration_type','clinic','participant_type','athlete','status','published')));
SELECT pg_temp.ok('medical form version','SEPARATION',pg_temp.command('form.publish',jsonb_build_object('offering_id',pg_temp.result_id('medical form offering'),'form_key','medical_information','title','Synthetic medical form','sensitivity','medical','definition','{"fields":[{"key":"allergies","type":"long_text","label":"Synthetic allergies","required":true}]}'::jsonb)));
SELECT pg_temp.ok('registration emergency reference form','FORM_TYPES',pg_temp.command('form.publish',jsonb_build_object('offering_id',pg_temp.result_id('medical form offering'),'form_key','emergency_reference','title','Synthetic registration-specific emergency reference','definition','{"fields":[{"key":"contact","type":"emergency_contact","label":"Synthetic emergency record reference","required":true}]}'::jsonb)));
SELECT pg_temp.ok('medical offering identity requirement','H',pg_temp.command('document_requirement.upsert',jsonb_build_object('offering_id',pg_temp.result_id('medical form offering'),'key','identity_reference','title','Synthetic non-emergency identity document','classification','identity','required',false,'emergency_access',false)));
SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('medical form child draft','SEPARATION',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('medical form offering'),'participant_id',pg_temp.f('participant-child1'))));
SELECT pg_temp.ok('guardian initial audited medical form entry','AUDIT',pg_temp.command('form.access',jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft'),'form_version_id',pg_temp.result_id('medical form version'))));
SELECT pg_temp.check('first audited medical form entry returns definition and empty unversioned state','SEPARATION',(SELECT result->>'status'='not_started' AND result->'answers'='{}'::jsonb AND result->'definition' ? 'fields' AND result->'version'='null'::jsonb AND result->>'resource_id'=pg_temp.result_id('medical form version')::text FROM pg_temp.phase3b_results WHERE label='guardian initial audited medical form entry'));
RESET ROLE;
SELECT pg_temp.check('first medical entry writes only access audit no fabricated answer or receipt','AUDIT',NOT EXISTS(SELECT 1 FROM public.registration_form_answers WHERE registration_id=pg_temp.result_id('medical form child draft') AND form_version_id=pg_temp.result_id('medical form version')) AND NOT EXISTS(SELECT 1 FROM boss_private.registration_operation_receipts WHERE request_id=pg_temp.f('request-guardian initial audited medical form entry')) AND EXISTS(SELECT 1 FROM public.audit_events WHERE request_id=pg_temp.f('request-guardian initial audited medical form entry') AND action='form.access'));
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('medical form submitted answers','SEPARATION',pg_temp.command('form.answer',jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft'),'form_version_id',pg_temp.result_id('medical form version'),'answers',jsonb_build_object('allergies','Synthetic highly restricted medical form answer'),'finalize',true)));
SELECT pg_temp.check('ordinary family detail never embeds medical form answers','SEPARATION',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft')))::text NOT LIKE '%Synthetic highly restricted medical form answer%');
SELECT pg_temp.ok('guardian audited medical form access','AUDIT',pg_temp.command('form.access',jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft'),'form_version_id',pg_temp.result_id('medical form version'))));
SELECT pg_temp.check('stored audited medical form access returns exact submitted answer version','VERSION',(SELECT result->>'version'='1' AND result->>'status'='submitted' FROM pg_temp.phase3b_results WHERE label='guardian audited medical form access'));
SELECT pg_temp.check('audited medical form access returns current answer','SEPARATION',(SELECT result::text LIKE '%Synthetic highly restricted medical form answer%' FROM pg_temp.phase3b_results WHERE label='guardian audited medical form access'));
SELECT pg_temp.act('finance');
SELECT pg_temp.deny('finance cannot retrieve medical form answers','SEPARATION',pg_temp.command('form.access',jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft'),'form_version_id',pg_temp.result_id('medical form version'))));
SELECT pg_temp.act('coach');
SELECT pg_temp.deny('ordinary coach cannot retrieve medical form answers','SEPARATION',pg_temp.command('form.access',jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft'),'form_version_id',pg_temp.result_id('medical form version'))));
SELECT pg_temp.check('coach safe summary has no medical answer or date of birth','SEPARATION',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft')))::text !~ '(Synthetic highly restricted|date_of_birth|medical_detail)');
RESET ROLE;
SELECT pg_temp.check('medical form retrieval audited without plaintext','AUDIT',EXISTS(SELECT 1 FROM public.audit_events WHERE request_id=pg_temp.f('request-guardian audited medical form access') AND action='form.access') AND NOT EXISTS(SELECT 1 FROM boss_private.registration_operation_receipts WHERE request_id=pg_temp.f('request-guardian audited medical form access')) AND NOT EXISTS(SELECT 1 FROM public.audit_events WHERE (coalesce(before_data::text,'')||coalesce(after_data::text,'')) LIKE '%Synthetic highly restricted medical form answer%'));

-- Same participant identity does not allow references to another registration's
-- emergency payload, and advertised controls obey the same domain permissions.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.deny('same child emergency reference cannot cross registrations','FORM_TYPES',pg_temp.command('form.answer',jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft'),'form_version_id',pg_temp.result_id('registration emergency reference form'),'answers',jsonb_build_object('contact',pg_temp.result_id('synthetic emergency saved')),'finalize',true)),ARRAY['PT422']);
SELECT pg_temp.ok('own registration emergency saved','J',pg_temp.command('emergency.save',jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft'),'contacts',jsonb_build_array(jsonb_build_object('name','Synthetic separate contact','relationship','Guardian','phone','555-0101')))));
SELECT pg_temp.ok('own registration emergency reference accepted','FORM_TYPES',pg_temp.command('form.answer',jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft'),'form_version_id',pg_temp.result_id('registration emergency reference form'),'answers',jsonb_build_object('contact',pg_temp.result_id('own registration emergency saved')),'finalize',true)));
RESET ROLE;
INSERT INTO pg_temp.phase3b_results SELECT 'mixed authority identity document',jsonb_build_object('resource_id',id) FROM public.registration_documents WHERE registration_id=pg_temp.result_id('medical form child draft');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('mixed authority identity upload intent','H',pg_temp.command('document.intent',jsonb_build_object('document_id',pg_temp.result_id('mixed authority identity document'),'mime_type','application/pdf','size_bytes',100)));
SELECT set_config('storage.operation','storage.object.upload',true);
INSERT INTO storage.objects(bucket_id,name,owner_id,metadata)
SELECT 'boss-registration-documents',result->>'object_name',pg_temp.f('auth-guardian')::text,'{"mimetype":"application/pdf","size":100}' FROM pg_temp.phase3b_results WHERE label='mixed authority identity upload intent';
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
SELECT pg_temp.ok('mixed authority identity upload complete','H',pg_temp.command('document.complete',jsonb_build_object('document_id',pg_temp.result_id('mixed authority identity document'),'intent_id',(SELECT result->>'intent_id' FROM pg_temp.phase3b_results WHERE label='mixed authority identity upload intent'))));
RESET ROLE;
UPDATE public.guardian_relationships SET can_register=false,can_view_documents=true WHERE id=pg_temp.f('limited-guardian');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('limited-guardian');
SELECT pg_temp.check('documents-only guardian receives audited medical form control','SEPARATION',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft')))->'detail'->'forms') f WHERE f->>'sensitivity'='medical' AND f->'operations' ? 'form.access' AND f->'answers'='{}'::jsonb));
SELECT pg_temp.check('documents-only guardian emergency retrieval purpose is ordinary','SEPARATION',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft')))->'detail'->>'emergency_access_purpose'='ordinary');
SELECT pg_temp.check('documents-only guardian receives no ordinary form definition or answers','SEPARATION',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft')))->'detail'->'forms') f WHERE f->>'sensitivity'='ordinary'));
RESET ROLE;
UPDATE public.guardian_relationships SET can_register=true,can_view_documents=false WHERE id=pg_temp.f('limited-guardian');
INSERT INTO public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at,ends_at)
SELECT pg_temp.f('limited-guardian'),id,'team',pg_temp.f('team-a'),pg_temp.f('org-a'),now()-interval '1 hour',now()+interval '2 hours' FROM public.roles WHERE key='head_coach';
INSERT INTO public.team_memberships(organization_id,team_id,person_id,membership_type,starts_at,ends_at)
VALUES(pg_temp.f('org-a'),pg_temp.f('team-a'),pg_temp.f('limited-guardian'),'coach',now()-interval '1 hour',now()+interval '2 hours');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('limited-guardian');
SELECT pg_temp.check('registration plus exact emergency authority purpose is emergency without medical flag','SEPARATION',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft')))->'detail'->>'emergency_access_purpose'='emergency');
SELECT pg_temp.check('mixed registration and emergency authority has exact emergency team context','SCOPE',jsonb_array_length(public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft')))->'detail'->'emergency_teams')=1);
SELECT pg_temp.check('mixed registration and emergency authority never advertises identity download','SEPARATION',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft')))->'detail'->'documents') d WHERE d->>'id'=pg_temp.result_id('mixed authority identity document')::text AND NOT(d->'operations' ? 'document.access') AND d->'access_purpose'='null'::jsonb));
SELECT pg_temp.deny('mixed registration and emergency authority cannot retrieve identity document','SCOPE',pg_temp.command('document.access',jsonb_build_object('document_id',pg_temp.result_id('mixed authority identity document'),'purpose','emergency','team_id',pg_temp.f('team-a'))));
RESET ROLE;

-- Fixed coupon minor units have no currency conversion model. A rejected
-- mixed-currency attempt must not consume a coupon, charge or request receipt.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('mixed currency offering','DISCOUNT',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic mixed currency fixed coupon safeguard','scope_type','organization','scope_id',pg_temp.f('org-a'),'registration_type','camp','participant_type','athlete','status','published')));
SELECT pg_temp.ok('mixed USD required fee','DISCOUNT',pg_temp.command('fee.upsert',jsonb_build_object('offering_id',pg_temp.result_id('mixed currency offering'),'title','Synthetic USD required fee','charge_type','camp','amount_minor',10000,'currency','USD')));
SELECT pg_temp.ok('mixed EUR required fee','DISCOUNT',pg_temp.command('fee.upsert',jsonb_build_object('offering_id',pg_temp.result_id('mixed currency offering'),'title','Synthetic EUR required fee','charge_type','camp','amount_minor',10000,'currency','EUR')));
SELECT pg_temp.ok('mixed currency fixed coupon','DISCOUNT',pg_temp.command('coupon.upsert',jsonb_build_object('offering_id',pg_temp.result_id('mixed currency offering'),'code','SYNTHETICMIXED','title','Synthetic incomparable minor units guard','adjustment_type','fixed','amount_minor',2500,'max_uses',1)));
SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('mixed currency child draft','DISCOUNT',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('mixed currency offering'),'participant_id',pg_temp.f('participant-child3'))));
SELECT pg_temp.deny('fixed coupon cannot combine USD and EUR minor units','DISCOUNT',pg_temp.command('registration.submit',jsonb_build_object('registration_id',pg_temp.result_id('mixed currency child draft'),'expected_version',1,'coupon_code','SYNTHETICMIXED')),ARRAY['PT422']);
SELECT pg_temp.check('guardian document authority selects ordinary emergency access','SEPARATION',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('child one draft')))->'detail'->>'emergency_access_purpose'='ordinary');
SELECT pg_temp.act('emergency');
SELECT pg_temp.check('exact emergency coach selects emergency retrieval purpose','SEPARATION',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('child one draft')))->'detail'->>'emergency_access_purpose'='emergency');
SELECT pg_temp.act('finance');
SELECT pg_temp.check('finance never receives emergency retrieval purpose','SEPARATION',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('child one draft')))->'detail'->'emergency_access_purpose'='null'::jsonb);
RESET ROLE;
SELECT pg_temp.check('mixed fixed coupon denial retains draft and zero usage evidence','ATOMIC',(SELECT status='draft' AND version=1 FROM public.registrations WHERE id=pg_temp.result_id('mixed currency child draft')) AND (SELECT used_count=0 FROM public.registration_coupons WHERE id=pg_temp.result_id('mixed currency fixed coupon')) AND NOT EXISTS(SELECT 1 FROM public.charges WHERE registration_id=pg_temp.result_id('mixed currency child draft')) AND NOT EXISTS(SELECT 1 FROM public.audit_events WHERE request_id=pg_temp.f('request-fixed coupon cannot combine USD and EUR minor units')) AND NOT EXISTS(SELECT 1 FROM boss_private.registration_operation_receipts WHERE request_id=pg_temp.f('request-fixed coupon cannot combine USD and EUR minor units')));

UPDATE public.guardian_relationships SET can_register=false,can_view_documents=true WHERE id=pg_temp.f('limited-guardian');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('limited-guardian');
SELECT pg_temp.check('documents-only guardian plus active coach still selects ordinary emergency purpose','SEPARATION',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft')))->'detail'->>'emergency_access_purpose'='ordinary' AND jsonb_array_length(public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft')))->'detail'->'emergency_teams')=1);
SELECT pg_temp.ok('documents-only mixed guardian ordinary emergency retrieval','SEPARATION',pg_temp.command('emergency.access',jsonb_build_object('registration_id',pg_temp.result_id('medical form child draft'),'purpose','ordinary')));
RESET ROLE;

-- Configuration controls remain available when the registration feature is
-- disabled, while family/finance data and mutations remain closed.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.deny('configuration rejects undeclared later module features','BOUNDARY',pg_temp.command('registration.configure',jsonb_build_object('organization_id',pg_temp.f('org-a'),'features',jsonb_build_object('boss_bucks',true))),ARRAY['PT422']);
SELECT pg_temp.ok('registration feature controlled disable','BOUNDARY',pg_temp.command('registration.configure',jsonb_build_object('organization_id',pg_temp.f('org-a'),'features',jsonb_build_object('registration',false))));
SELECT pg_temp.check('disabled registration manager receives configuration only','BOUNDARY',public.boss_registration_read(jsonb_build_object('organization_id',pg_temp.f('org-a'),'view','admin'))->'operations'='["registration.configure"]'::jsonb AND public.boss_registration_read(jsonb_build_object('organization_id',pg_temp.f('org-a'),'view','admin'))->'registrations'='[]'::jsonb AND public.boss_registration_read(jsonb_build_object('organization_id',pg_temp.f('org-a'),'view','admin'))->'offerings'='[]'::jsonb AND public.boss_registration_read(jsonb_build_object('organization_id',pg_temp.f('org-a'),'view','admin'))->'detail'='null'::jsonb);
SELECT pg_temp.act('guardian');
SELECT pg_temp.read_deny('disabled registration blocks family detail',jsonb_build_object('registration_id',pg_temp.result_id('child one draft')));
SELECT pg_temp.deny('disabled registration blocks known offering start','BOUNDARY',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('camp offering'),'participant_id',pg_temp.f('participant-child2'))));
SELECT pg_temp.act('finance');
SELECT pg_temp.deny('finance cannot change registration configuration','BOUNDARY',pg_temp.command('registration.configure',jsonb_build_object('organization_id',pg_temp.f('org-a'),'features',jsonb_build_object('registration',true))));
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('registration feature controlled restore','BOUNDARY',pg_temp.command('registration.configure',jsonb_build_object('organization_id',pg_temp.f('org-a'),'features',jsonb_build_object('registration',true))));
SELECT pg_temp.check('restored registration manager sees tenant offerings again','BOUNDARY',jsonb_array_length(public.boss_registration_read(jsonb_build_object('organization_id',pg_temp.f('org-a'),'view','admin'))->'offerings')>0);
SELECT pg_temp.ok('offline payments controlled disable','BOUNDARY',pg_temp.command('registration.configure',jsonb_build_object('organization_id',pg_temp.f('org-a'),'features',jsonb_build_object('offline_payments',false))));
SELECT pg_temp.act('finance');
SELECT pg_temp.deny('disabled offline payments refuses previously valid replay','IDEMPOTENCY',pg_temp.payment('cash',10000),ARRAY['PT403'],'cash one hundred');
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('offline payments controlled restore','BOUNDARY',pg_temp.command('registration.configure',jsonb_build_object('organization_id',pg_temp.f('org-a'),'features',jsonb_build_object('offline_payments',true))));
RESET ROLE;

-- The persistent Phase3B payment invariant is offline-only, independently of
-- RPC authorization. Even a trusted operator cannot insert a future tender.
SELECT pg_temp.check('persistent payment method CHECK permits cash and check only','BOUNDARY',(SELECT count(*)=1 AND bool_and(pg_get_constraintdef(oid) LIKE '%cash%' AND pg_get_constraintdef(oid) LIKE '%check%' AND pg_get_constraintdef(oid) !~ '(card|ach|boss_bucks|adjustment)') FROM pg_catalog.pg_constraint WHERE conrelid='public.payments'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%method%'));
DO $$DECLARE future_method text;BEGIN
 FOREACH future_method IN ARRAY ARRAY['card','ach','boss_bucks','adjustment'] LOOP
  PERFORM pg_temp.sql_deny('persistent future tender rejected '||future_method,'BOUNDARY',format('INSERT INTO public.payments(organization_id,method,amount_minor,currency,payer_person_id,received_at,recorded_by_person_id) VALUES(%L,%L,100,%L,%L,now(),%L)',pg_temp.f('org-a'),future_method,'USD',pg_temp.f('guardian'),pg_temp.f('finance')),ARRAY['23514']);
 END LOOP;
END $$;
SELECT pg_temp.check('future tender attempts leave no unsupported payment rows','BOUNDARY',NOT EXISTS(SELECT 1 FROM public.payments WHERE organization_id=pg_temp.f('org-a') AND method NOT IN('cash','check')));

-- Read action hints must match the already enforced visibility gates. Knowledge
-- of a restricted offering remains insufficient registration-create authority.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('restricted visibility offering','SCOPE',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic restricted start hint','scope_type','organization','scope_id',pg_temp.f('org-a'),'registration_type','clinic','participant_type','athlete','status','published','visibility','restricted')));
SELECT pg_temp.ok('member visibility offering','SCOPE',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic member start hint','scope_type','organization','scope_id',pg_temp.f('org-a'),'registration_type','clinic','participant_type','athlete','status','published','visibility','member')));
SELECT pg_temp.ok('member mismatched participant type offering','SCOPE',pg_temp.command('offering.upsert',jsonb_build_object('organization_id',pg_temp.f('org-a'),'title','Synthetic member matching participant gate','scope_type','organization','scope_id',pg_temp.f('org-a'),'registration_type','clinic','participant_type','participant','status','published','visibility','member')));
SELECT pg_temp.check('scoped registration creator receives restricted start hint','SCOPE',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('offering_id',pg_temp.result_id('restricted visibility offering')))->'offerings') o WHERE o->>'id'=pg_temp.result_id('restricted visibility offering')::text AND o->'operations' ? 'registration.start'));
SELECT pg_temp.act('guardian');
SELECT pg_temp.check('visible restricted offering never advertises unauthorized family start','SCOPE',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('offering_id',pg_temp.result_id('restricted visibility offering')))->'offerings') o WHERE o->>'id'=pg_temp.result_id('restricted visibility offering')::text AND NOT(o->'operations' ? 'registration.start')));
SELECT pg_temp.deny('forged restricted start denied despite known offering ID','SCOPE',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('restricted visibility offering'),'participant_id',pg_temp.f('participant-child2'))));
SELECT pg_temp.check('active family member receives member-only start hint','SCOPE',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('offering_id',pg_temp.result_id('member visibility offering')))->'offerings') o WHERE o->'operations' ? 'registration.start'));
SELECT pg_temp.ok('member visibility child draft','SCOPE',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('member visibility offering'),'participant_id',pg_temp.f('participant-child1'))));
SELECT pg_temp.act('finance');
SELECT pg_temp.check('finance knows member offering but receives no member or creator start hint','SCOPE',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('offering_id',pg_temp.result_id('member visibility offering')))->'offerings') o WHERE o->>'id'=pg_temp.result_id('member visibility offering')::text AND NOT(o->'operations' ? 'registration.start')));
RESET ROLE;
UPDATE public.organization_memberships SET status='inactive' WHERE organization_id=pg_temp.f('org-a') AND person_id IN(pg_temp.f('guardian'),pg_temp.f('child1'),pg_temp.f('child2'),pg_temp.f('child3'));
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.check('historical family offering knowledge does not retain expired member start hint','SCOPE',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('offering_id',pg_temp.result_id('member visibility offering')))->'offerings') o WHERE o->>'id'=pg_temp.result_id('member visibility offering')::text AND NOT(o->'operations' ? 'registration.start')));
SELECT pg_temp.deny('historical family offering knowledge cannot bypass current member restriction','SCOPE',pg_temp.command('registration.start',jsonb_build_object('offering_id',pg_temp.result_id('member visibility offering'),'participant_id',pg_temp.f('participant-child2'))));
RESET ROLE;
UPDATE public.organization_memberships SET status='active' WHERE organization_id=pg_temp.f('org-a') AND person_id IN(pg_temp.f('guardian'),pg_temp.f('child1'),pg_temp.f('child2'),pg_temp.f('child3'));
UPDATE public.organization_memberships SET status='inactive' WHERE organization_id=pg_temp.f('org-a') AND person_id=pg_temp.f('guardian');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.check('different participant type membership never advertises member start','SCOPE',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('offering_id',pg_temp.result_id('member mismatched participant type offering')))->'offerings') o WHERE o->>'id'=pg_temp.result_id('member mismatched participant type offering')::text AND NOT(o->'operations' ? 'registration.start')));
SELECT pg_temp.check('current dependent membership alone restores member start hint','SCOPE',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('offering_id',pg_temp.result_id('member visibility offering')))->'offerings') o WHERE o->'operations' ? 'registration.start'));
RESET ROLE;

-- Read metadata is useful without promoting household membership or staff
-- capability into guardian authority; dates reflect retained canonical records.
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.check('current registration guardian sees own household name in list','READ',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read('{}')->'registrations') r WHERE r->>'id'=pg_temp.result_id('child one draft')::text AND r->>'household_name'='Synthetic Phase3B Household A' AND r->>'submitted_at' IS NOT NULL));
SELECT pg_temp.check('registration detail exposes canonical creation timestamp','READ',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('child one draft')))->'detail'->>'created_at' IS NOT NULL);
SELECT pg_temp.act('coach');
SELECT pg_temp.check('coach capability alone never exposes household name in list','SEPARATION',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('view','admin','organization_id',pg_temp.f('org-a')))->'registrations') r WHERE r->>'id'=pg_temp.result_id('child one draft')::text AND r->>'household_name' IS NULL));
SELECT pg_temp.act('finance');
SELECT pg_temp.check('finance capability alone never exposes household name in list','SEPARATION',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read(jsonb_build_object('view','admin','organization_id',pg_temp.f('org-a')))->'registrations') r WHERE r->>'id'=pg_temp.result_id('child one draft')::text AND r->>'household_name' IS NULL));
SELECT pg_temp.act('limited-guardian');
SELECT pg_temp.check('documents-only guardian with household membership receives no household name','SEPARATION',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read('{}')->'registrations') r WHERE r->>'id'=pg_temp.result_id('child one draft')::text AND r->>'household_name' IS NULL));
SELECT pg_temp.act('guardian');
SELECT pg_temp.deny('unexpired approved physical cannot renew prematurely','H',pg_temp.command('document.intent',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'mime_type','application/pdf','size_bytes',100)),ARRAY['PT409']);
RESET ROLE;
SELECT pg_temp.check('derived document status helper has no caller execution grant','Z',NOT has_function_privilege('authenticated','boss_private.registration_current_document_status(uuid)','EXECUTE') AND NOT has_function_privilege('anon','boss_private.registration_current_document_status(uuid)','EXECUTE') AND NOT has_function_privilege('service_role','boss_private.registration_current_document_status(uuid)','EXECUTE'));
UPDATE public.registration_documents SET expires_on=current_date,renewal_due_on=null,version=version+1,updated_at=now() WHERE id=pg_temp.result_id('physical document');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.deny('approved physical expiring today remains valid and cannot renew','H',pg_temp.command('document.intent',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'mime_type','application/pdf','size_bytes',100)),ARRAY['PT409']);
RESET ROLE;
UPDATE public.registration_documents SET expires_on=null,version=version+1,updated_at=now() WHERE id=pg_temp.result_id('physical document');
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.deny('approved physical without expiry cannot renew','H',pg_temp.command('document.intent',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'mime_type','application/pdf','size_bytes',100)),ARRAY['PT409']);
RESET ROLE;
UPDATE public.registration_documents SET expires_on=current_date-1,renewal_due_on=current_date-2,version=version+1,updated_at=now() WHERE id=pg_temp.result_id('physical document');
SELECT pg_temp.check('naturally expired document fixture retains stale approved registration evidence','H',(SELECT document_status='approved' FROM public.registrations WHERE id=pg_temp.result_id('child one draft')) AND (SELECT status='approved' AND expires_on<current_date FROM public.registration_documents WHERE id=pg_temp.result_id('physical document')));
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT pg_temp.check('naturally expired required physical is current in detail projection','H',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('child one draft')))->'detail'->>'document_status'='expired');
SELECT pg_temp.check('naturally expired required physical is current in list projection','H',EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read('{}')->'registrations') r WHERE r->>'id'=pg_temp.result_id('child one draft')::text AND r->>'document_status'='expired'));
SELECT pg_temp.act('outsider');
SELECT pg_temp.deny('natural expiry creates no unrelated guardian renewal authority','X',pg_temp.command('document.intent',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'mime_type','application/pdf','size_bytes',100)));
SELECT pg_temp.act('guardian');
SELECT pg_temp.ok('naturally expired physical renewal intent','H',pg_temp.command('document.intent',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'mime_type','application/pdf','size_bytes',100)));
DO $$DECLARE download_operation text;BEGIN
 FOREACH download_operation IN ARRAY ARRAY['object.get_authenticated','storage.object.get_authenticated_info'] LOOP
  PERFORM set_config('storage.operation',download_operation,true);
  PERFORM pg_temp.check('renewed document path invalidates old object lease for '||download_operation,'H',NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents' AND name=(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent')));
 END LOOP;
END $$;
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
SELECT pg_temp.check('renewal issues new private path and revokes old object lease','H',(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='naturally expired physical renewal intent')<>(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent') AND NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='boss-registration-documents' AND name=(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent')));
RESET ROLE;
SELECT pg_temp.check('renewal resets current approval while retaining old reviewed evidence','H',(SELECT status='upload_pending' AND reviewed_by_person_id IS NULL AND reviewed_at IS NULL AND review_reason IS NULL FROM public.registration_documents WHERE id=pg_temp.result_id('physical document')) AND EXISTS(SELECT 1 FROM boss_private.registration_document_history WHERE document_id=pg_temp.result_id('physical document') AND snapshot->>'status'='approved' AND snapshot->>'reviewed_by_person_id'=pg_temp.f('registrar')::text));
SET LOCAL ROLE authenticated;
SELECT pg_temp.act('guardian');
SELECT set_config('storage.operation','storage.object.upload',true);
INSERT INTO storage.objects(bucket_id,name,owner_id,metadata)
SELECT 'boss-registration-documents',result->>'object_name',pg_temp.f('auth-guardian')::text,'{"mimetype":"application/pdf","size":100}' FROM pg_temp.phase3b_results WHERE label='naturally expired physical renewal intent';
SELECT set_config('storage.operation','storage.object.get_authenticated',true);
SELECT pg_temp.ok('naturally expired physical renewal complete','H',pg_temp.command('document.complete',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'intent_id',(SELECT result->>'intent_id' FROM pg_temp.phase3b_results WHERE label='naturally expired physical renewal intent'))));
SELECT pg_temp.deny('guardian renewal does not create reviewer authority','Y',pg_temp.command('document.review',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'expected_version',(SELECT (result->>'version')::bigint FROM pg_temp.phase3b_results WHERE label='naturally expired physical renewal complete'),'status','approved','reason','Synthetic denied self approval')));
SELECT pg_temp.act('admin-a');
SELECT pg_temp.ok('naturally expired physical authorized renewed review','H',pg_temp.command('document.review',jsonb_build_object('document_id',pg_temp.result_id('physical document'),'expected_version',(SELECT (result->>'version')::bigint FROM pg_temp.phase3b_results WHERE label='naturally expired physical renewal complete'),'status','approved','reason','Synthetic reviewed renewed physical','expires_on',current_date+365)));
SELECT pg_temp.act('guardian');
SELECT pg_temp.check('reviewed renewed physical current status is approved in detail and list','H',public.boss_registration_read(jsonb_build_object('registration_id',pg_temp.result_id('child one draft')))->'detail'->>'document_status'='approved' AND EXISTS(SELECT 1 FROM jsonb_array_elements(public.boss_registration_read('{}')->'registrations') r WHERE r->>'id'=pg_temp.result_id('child one draft')::text AND r->>'document_status'='approved'));
RESET ROLE;
SELECT pg_temp.check('renewal retains both isolated metadata versions and all history','H',(SELECT count(*)=2 FROM storage.objects WHERE bucket_id='boss-registration-documents' AND name IN((SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='physical upload intent'),(SELECT result->>'object_name' FROM pg_temp.phase3b_results WHERE label='naturally expired physical renewal intent'))) AND EXISTS(SELECT 1 FROM boss_private.registration_document_history WHERE document_id=pg_temp.result_id('physical document') AND version=4 AND snapshot->>'status'='approved') AND EXISTS(SELECT 1 FROM public.audit_events WHERE request_id=pg_temp.f('request-naturally expired physical renewal intent') AND action='document.intent'));

SELECT count(*) AS passed_assertions FROM pg_temp.phase3b_assertions;
SELECT category,count(*) AS passed FROM pg_temp.phase3b_assertions GROUP BY category ORDER BY category;
ROLLBACK;
SELECT count(*) AS remaining_registration_fixtures FROM public.registrations WHERE submitted_by_person_id=md5('boss-phase3b-acceptance:guardian')::uuid;
