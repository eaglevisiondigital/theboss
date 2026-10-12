-- DML-only canonical compatibility verifier. Distinct synthetic namespace, no
-- helper DDL/TEMP objects, real credentials, file bytes, managed deletes or remote
-- calls. Every fixture and audit write rolls back. DO assertions raise on failure.
BEGIN;
DO $$
DECLARE
 org uuid:=md5('boss-phase4a-comm-live:org')::uuid;other_org uuid:=md5('boss-phase4a-comm-live:other-org')::uuid;
 unit uuid:=md5('boss-phase4a-comm-live:unit')::uuid;sibling uuid:=md5('boss-phase4a-comm-live:sibling')::uuid;
 team uuid:=md5('boss-phase4a-comm-live:team')::uuid;other_team uuid:=md5('boss-phase4a-comm-live:other-team')::uuid;
 admin uuid:=md5('boss-phase4a-comm-live:admin')::uuid;coach uuid:=md5('boss-phase4a-comm-live:coach')::uuid;guardian uuid:=md5('boss-phase4a-comm-live:guardian')::uuid;
 child uuid:=md5('boss-phase4a-comm-live:child')::uuid;hh_only uuid:=md5('boss-phase4a-comm-live:household-only')::uuid;hh uuid:=md5('boss-phase4a-comm-live:household')::uuid;
 actor_label text;actor uuid;thread uuid;msg uuid;ann uuid;result jsonb;passed integer:=0;
BEGIN
 INSERT INTO auth.users(id,email,email_confirmed_at,is_anonymous) SELECT md5('boss-phase4a-comm-live:auth-'||p)::uuid,p||'@phase4a-comm-live.example.invalid',now()-interval '1 day',false FROM unnest(array['admin','coach','guardian','child','household-only'])p;
 INSERT INTO auth.sessions(id,user_id) SELECT md5('boss-phase4a-comm-live:session-'||p)::uuid,md5('boss-phase4a-comm-live:auth-'||p)::uuid FROM unnest(array['admin','coach','guardian','child','household-only'])p;
 INSERT INTO public.people(id,display_name,date_of_birth) SELECT md5('boss-phase4a-comm-live:'||p)::uuid,'Synthetic Phase4A Live '||p,case when p='child' then current_date-interval '12 years' else date '1980-01-01' end FROM unnest(array['admin','coach','guardian','child','household-only'])p;
 INSERT INTO public.user_accounts(auth_user_id,person_id,account_status) SELECT md5('boss-phase4a-comm-live:auth-'||p)::uuid,md5('boss-phase4a-comm-live:'||p)::uuid,'active' FROM unnest(array['admin','coach','guardian','child','household-only'])p;
 INSERT INTO public.organizations(id,name,slug) VALUES(org,'Synthetic Phase4A Live Organization','phase4a-comm-live'),(other_org,'Synthetic Phase4A Live Other Organization','phase4a-comm-live-other');
 INSERT INTO public.organization_units(id,organization_id,name,slug,unit_type) VALUES(unit,org,'Synthetic unit','a','sport'),(sibling,org,'Synthetic sibling','b','sport');
 INSERT INTO public.teams(id,organization_id,parent_unit_id,name,slug,status) VALUES(team,org,unit,'Synthetic live Falcons','a','active'),(other_team,org,sibling,'Synthetic live unrelated','b','active');
 INSERT INTO public.organization_modules(organization_id,module_id,status,starts_at,configuration) SELECT org,id,'active',now()-interval '1 day','{"communications":true,"announcements":true,"team_chat":true}' FROM public.modules WHERE key='messaging';
 INSERT INTO public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at) SELECT admin,id,'organization',org,org,now()-interval '1 day' FROM public.roles WHERE key='organization_administrator';
 INSERT INTO public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at) SELECT coach,id,'team',team,org,now()-interval '1 day' FROM public.roles WHERE key='head_coach';
 INSERT INTO public.organization_memberships(organization_id,person_id,starts_at) SELECT org,id,now()-interval '1 day' FROM public.people WHERE id IN(admin,coach,guardian,child,hh_only);
 INSERT INTO public.participants(id,person_id,participant_type) VALUES(md5('boss-phase4a-comm-live:participant')::uuid,child,'athlete');
 INSERT INTO public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at) VALUES(org,team,coach,NULL,'coach',now()-interval '1 day'),(org,team,child,md5('boss-phase4a-comm-live:participant')::uuid,'athlete',now()-interval '1 day');
 INSERT INTO public.households(id,name) VALUES(hh,'Synthetic live household');
 INSERT INTO public.household_memberships(household_id,person_id,starts_at) SELECT hh,id,now()-interval '1 day' FROM public.people WHERE id IN(guardian,child,hh_only);
 INSERT INTO public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,starts_at,can_receive_communications,can_send_communications,can_register)
 VALUES(md5('boss-phase4a-comm-live:guardian-relation')::uuid,guardian,child,'active',now()-interval '1 day',now()-interval '1 day',true,true,true);
 IF NOT boss_private.comm_permission(admin,'announcements.send',org,'team',team) THEN RAISE EXCEPTION 'FAIL live admin target permission';END IF;passed:=passed+1;
 IF boss_private.comm_permission(coach,'announcements.send',org,'team',other_team) THEN RAISE EXCEPTION 'FAIL live coach scope';END IF;passed:=passed+1;
 IF boss_private.comm_guardian(hh_only,child,'can_receive_communications') THEN RAISE EXCEPTION 'FAIL live household guardian substitution';END IF;passed:=passed+1;
 IF boss_private.comm_participant_allowed(child,org) THEN RAISE EXCEPTION 'FAIL live participant default';END IF;passed:=passed+1;
 IF has_table_privilege('authenticated','public.communication_messages','SELECT,INSERT,UPDATE,DELETE,TRUNCATE') THEN RAISE EXCEPTION 'FAIL live raw ACL';END IF;passed:=passed+1;
 IF has_function_privilege('authenticated','boss_private.comm_message_can_view(uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'FAIL live arbitrary recipient helper';END IF;passed:=passed+1;
 actor_label:='admin';PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase4a-comm-live:auth-'||actor_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase4a-comm-live:session-'||actor_label)::uuid)::text,true);
 SET LOCAL ROLE authenticated;
 result:=public.boss_communications_mutate(md5('boss-phase4a-comm-live:req-ann')::uuid,jsonb_build_object('operation','announcement.send','input',jsonb_build_object('organization_id',org,'title','Synthetic live announcement','body','Synthetic live announcement content','targets',jsonb_build_array(jsonb_build_object('scope_type','team','scope_id',team)))));ann:=(result->>'resource_id')::uuid;passed:=passed+1;
 result:=public.boss_communications_mutate(md5('boss-phase4a-comm-live:req-thread')::uuid,jsonb_build_object('operation','thread.create','input',jsonb_build_object('organization_id',org,'kind','team_chat','title','Synthetic live private chat','scope_type','team','scope_id',team)));thread:=(result->>'resource_id')::uuid;passed:=passed+1;
 result:=public.boss_communications_mutate(md5('boss-phase4a-comm-live:req-msg')::uuid,jsonb_build_object('operation','message.send','input',jsonb_build_object('thread_id',thread,'body','Synthetic live chat content')));msg:=(result->>'resource_id')::uuid;passed:=passed+1;
 result:=public.boss_communications_mutate(md5('boss-phase4a-comm-live:req-msg')::uuid,jsonb_build_object('operation','message.send','input',jsonb_build_object('thread_id',thread,'body','Synthetic live chat content')));
 IF (result->>'resource_id')::uuid<>msg THEN RAISE EXCEPTION 'FAIL live idempotent message';END IF;passed:=passed+1;
 actor_label:='guardian';PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase4a-comm-live:auth-'||actor_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase4a-comm-live:session-'||actor_label)::uuid)::text,true);
 result:=public.boss_communications_read(jsonb_build_object('organization_id',org,'thread_id',thread));
 IF jsonb_array_length(result->'detail'->'messages')<>1 THEN RAISE EXCEPTION 'FAIL live guardian receipt';END IF;passed:=passed+1;
 IF (result->'unread'->>'messages')::int<>2 THEN RAISE EXCEPTION 'FAIL live deduplicated unread';END IF;passed:=passed+1;
 result:=public.boss_communications_mutate(md5('boss-phase4a-comm-live:req-read')::uuid,jsonb_build_object('operation','read.thread','input',jsonb_build_object('thread_id',thread)));
 result:=public.boss_communications_read(jsonb_build_object('organization_id',org,'thread_id',thread));IF (result->'detail'->'thread'->>'unread_count')::int<>0 THEN RAISE EXCEPTION 'FAIL live read watermark';END IF;passed:=passed+1;
 BEGIN PERFORM public.boss_communications_read(jsonb_build_object('organization_id',other_org,'thread_id',thread));RAISE EXCEPTION 'FAIL live forged org';EXCEPTION WHEN SQLSTATE 'PT403' THEN passed:=passed+1;END;
 actor_label:='household-only';PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase4a-comm-live:auth-'||actor_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase4a-comm-live:session-'||actor_label)::uuid)::text,true);
 BEGIN PERFORM public.boss_communications_read(jsonb_build_object('organization_id',org,'thread_id',thread));RAISE EXCEPTION 'FAIL live household private chat';EXCEPTION WHEN SQLSTATE 'PT403' THEN passed:=passed+1;END;
 actor_label:='child';PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase4a-comm-live:auth-'||actor_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase4a-comm-live:session-'||actor_label)::uuid)::text,true);
 BEGIN PERFORM public.boss_communications_read(jsonb_build_object('organization_id',org,'thread_id',thread));RAISE EXCEPTION 'FAIL live participant policy';EXCEPTION WHEN SQLSTATE 'PT403' THEN passed:=passed+1;END;
 actor_label:='coach';PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase4a-comm-live:auth-'||actor_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase4a-comm-live:session-'||actor_label)::uuid)::text,true);
 BEGIN PERFORM public.boss_communications_mutate(md5('boss-phase4a-comm-live:req-forged')::uuid,jsonb_build_object('operation','announcement.send','input',jsonb_build_object('organization_id',org,'title','Synthetic denied','body','Synthetic denied','targets',jsonb_build_array(jsonb_build_object('scope_type','team','scope_id',other_team)))));RAISE EXCEPTION 'FAIL live unrelated team';EXCEPTION WHEN SQLSTATE 'PT403' THEN passed:=passed+1;END;
 RESET ROLE;
 IF (SELECT count(*) FROM public.communication_messages WHERE thread_id=thread)<>1 THEN RAISE EXCEPTION 'FAIL live duplicate retry rows';END IF;passed:=passed+1;
 UPDATE public.guardian_relationships SET can_receive_communications=false,can_send_communications=false WHERE id=md5('boss-phase4a-comm-live:guardian-relation')::uuid;
 IF boss_private.comm_thread_can_view(thread,guardian) THEN RAISE EXCEPTION 'FAIL live guardian revoke';END IF;passed:=passed+1;
 IF (SELECT can_register FROM public.guardian_relationships WHERE id=md5('boss-phase4a-comm-live:guardian-relation')::uuid) IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL live old flag unchanged';END IF;passed:=passed+1;
 IF EXISTS(SELECT 1 FROM public.audit_events WHERE organization_id=org AND (coalesce(after_data::text,'') LIKE '%Synthetic live chat content%' OR coalesce(after_data::text,'') LIKE '%Synthetic live announcement content%')) THEN RAISE EXCEPTION 'FAIL live audit content leakage';END IF;passed:=passed+1;
 IF passed<>21 THEN RAISE EXCEPTION 'FAIL live assertion accounting %',passed;END IF;
END$$;
ROLLBACK;
SELECT 21 AS passed_assertions,
 (SELECT count(*) FROM public.organizations WHERE id IN(md5('boss-phase4a-comm-live:org')::uuid,md5('boss-phase4a-comm-live:other-org')::uuid)) AS residual_organizations,
 (SELECT count(*) FROM public.people WHERE display_name LIKE 'Synthetic Phase4A Live %') AS residual_people,
 (SELECT count(*) FROM auth.users WHERE email LIKE '%@phase4a-comm-live.example.invalid') AS residual_auth_users,
 (SELECT count(*) FROM public.communication_threads WHERE organization_id=md5('boss-phase4a-comm-live:org')::uuid) AS residual_threads,
 (SELECT count(*) FROM public.communication_messages WHERE organization_id=md5('boss-phase4a-comm-live:org')::uuid) AS residual_messages,
 (SELECT count(*) FROM public.audit_events WHERE organization_id=md5('boss-phase4a-comm-live:org')::uuid) AS residual_audits;
