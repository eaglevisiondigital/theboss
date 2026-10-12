-- Independent DML-only capability verifier. Synthetic namespace, no helper DDL,
-- real credentials, document bytes, production sender or external provider call.
-- Real authenticated-role RPCs; all records and audit writes roll back.
begin;
do $live$
declare
 org uuid:=md5('boss-phase4a-notif-live:org')::uuid;other_org uuid:=md5('boss-phase4a-notif-live:other-org')::uuid;
 admin uuid:=md5('boss-phase4a-notif-live:admin')::uuid;parent uuid:=md5('boss-phase4a-notif-live:parent')::uuid;
 child1 uuid:=md5('boss-phase4a-notif-live:child1')::uuid;child2 uuid:=md5('boss-phase4a-notif-live:child2')::uuid;
 participant1 uuid:=md5('boss-phase4a-notif-live:participant1')::uuid;participant2 uuid:=md5('boss-phase4a-notif-live:participant2')::uuid;
 team1 uuid:=md5('boss-phase4a-notif-live:team1')::uuid;team2 uuid:=md5('boss-phase4a-notif-live:team2')::uuid;
 offering uuid:=md5('boss-phase4a-notif-live:offering')::uuid;reg uuid:=md5('boss-phase4a-notif-live:registration')::uuid;
 charge uuid:=md5('boss-phase4a-notif-live:charge')::uuid;ev_id uuid;notif_id uuid;result jsonb;command jsonb;actor_label text;passed integer:=0;
begin
 if exists(select 1 from public.organizations where slug like 'synthetic-phase4a-notif-live%') or exists(select 1 from auth.users where email like '%@phase4a-notif-live.example.invalid') then raise exception 'Synthetic notification live namespace collision';end if;passed:=passed+1;
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) select md5('boss-phase4a-notif-live:auth-'||label)::uuid,label||'@phase4a-notif-live.example.invalid',now()-interval '1 day',false from unnest(array['admin','parent','outsider'])label;
 insert into auth.sessions(id,user_id) select md5('boss-phase4a-notif-live:session-'||label)::uuid,md5('boss-phase4a-notif-live:auth-'||label)::uuid from unnest(array['admin','parent','outsider'])label;
 insert into public.people(id,display_name,date_of_birth) select md5('boss-phase4a-notif-live:'||label)::uuid,'Synthetic Phase4A Notification Live '||label,case when label like 'child%' then date '2014-01-01' else date '1980-01-01' end from unnest(array['admin','parent','outsider','child1','child2'])label;
 insert into public.user_accounts(person_id,auth_user_id,account_status) select md5('boss-phase4a-notif-live:'||label)::uuid,md5('boss-phase4a-notif-live:auth-'||label)::uuid,'active' from unnest(array['admin','parent','outsider'])label;
 insert into public.organizations(id,name,slug) values(org,'Synthetic notification live tenant','synthetic-phase4a-notif-live'),(other_org,'Synthetic notification live isolation','synthetic-phase4a-notif-live-other');
 insert into public.teams(id,organization_id,name,slug,status) values(team1,org,'Synthetic live team one','n1','active'),(team2,org,'Synthetic live team two','n2','active');
 insert into public.organization_memberships(organization_id,person_id,starts_at) values(org,admin,now()-interval '1 day'),(org,child1,now()-interval '1 day'),(org,child2,now()-interval '1 day'),(other_org,md5('boss-phase4a-notif-live:outsider')::uuid,now()-interval '1 day');
 insert into public.participants(id,person_id) values(participant1,child1),(participant2,child2);
 insert into public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at) values(org,team1,child1,participant1,'athlete',now()-interval '1 day'),(org,team2,child2,participant2,'athlete',now()-interval '1 day');
 insert into public.guardian_relationships(guardian_person_id,dependent_person_id,authority_status,verified_at,starts_at,can_receive_communications,can_register,can_manage_payments)
 values(parent,child1,'active',now()-interval '1 day',now()-interval '1 day',true,true,true),(parent,child2,'active',now()-interval '1 day',now()-interval '1 day',true,true,true);
 insert into public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at) select admin,id,'organization',org,org,now()-interval '1 day' from public.roles where key='organization_administrator';
 insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at) select org,id,'active',case when key='registration' then '{"registration":true,"fees":true,"offline_payments":true}'::jsonb else '{}'::jsonb end,now()-interval '1 day' from public.modules where key in ('messaging','calendar','registration');
 actor_label:='admin';perform set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase4a-notif-live:auth-'||actor_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase4a-notif-live:session-'||actor_label)::uuid)::text,true);
 set local role authenticated;
 command:=jsonb_build_object('operation','event.create','input',jsonb_build_object('organization_id',org,'title','Synthetic notification live event','event_type_key','practice','start_at',date_trunc('second',now())+interval '3 days','end_at',date_trunc('second',now())+interval '3 days 1 hour','timezone','UTC','status','scheduled','visibility','member','targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',team1),jsonb_build_object('target_type','team','target_id',team2))));
 result:=public.boss_calendar_mutate(command,md5('boss-phase4a-notif-live:create-event')::uuid);ev_id:=(result->>'resource_id')::uuid;passed:=passed+1;
 result:=public.boss_calendar_mutate(command,md5('boss-phase4a-notif-live:create-event')::uuid);if (result->>'resource_id')::uuid<>ev_id then raise exception 'FAIL live calendar replay';end if;passed:=passed+1;
 reset role;
 if (select count(*) from public.notification_events where organization_id=org and source_id=ev_id and event_type='event.created')<>1 then raise exception 'FAIL live source dedup';end if;passed:=passed+1;
 if (select count(*) from public.notifications n join public.notification_events e on e.id=n.notification_event_id where n.recipient_person_id=parent and e.source_id=ev_id)<>1 then raise exception 'FAIL live two-child recipient dedup';end if;passed:=passed+1;
 if (select bool_and(status='suppressed' and failure_category='not_configured') from public.notification_deliveries where organization_id=org and channel='email') is distinct from true then raise exception 'FAIL live provider unconfigured';end if;passed:=passed+1;
 if exists(select 1 from public.notification_deliveries where organization_id=org and (delivered_at is not null or status='delivered')) then raise exception 'FAIL live fabricated delivery';end if;passed:=passed+1;
 actor_label:='parent';perform set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase4a-notif-live:auth-'||actor_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase4a-notif-live:session-'||actor_label)::uuid)::text,true);
 set local role authenticated;
 result:=public.boss_notifications_read('{}');if jsonb_array_length(result->'notifications')<>1 or (result->>'unread_count')::int<>1 then raise exception 'FAIL live guardian notification';end if;passed:=passed+1;
 notif_id:=(result->'notifications'->0->>'id')::uuid;
 result:=public.boss_notifications_mutate(md5('boss-phase4a-notif-live:read-one')::uuid,jsonb_build_object('operation','notification.read','input',jsonb_build_object('id',notif_id)));
 if (public.boss_notifications_read('{}')->>'unread_count')::int<>0 then raise exception 'FAIL live mark one read';end if;passed:=passed+1;
 result:=public.boss_notifications_mutate(md5('boss-phase4a-notif-live:email-off')::uuid,'{"operation":"preference.set","input":{"channel":"email","category":"events","enabled":false}}');passed:=passed+1;
 begin perform public.boss_notifications_mutate(md5('boss-phase4a-notif-live:worker-denial')::uuid,jsonb_build_object('operation','delivery.process','input',jsonb_build_object('organization_id',org)));raise exception 'FAIL live guardian worker privilege';exception when sqlstate 'PT403' then passed:=passed+1;end;
 actor_label:='admin';perform set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase4a-notif-live:auth-'||actor_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase4a-notif-live:session-'||actor_label)::uuid)::text,true);
 result:=public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',org,'event_id',ev_id,'expected_version',1,'title','Synthetic moved event','event_type_key','practice','start_at',date_trunc('second',now())+interval '3 days 2 hours','end_at',date_trunc('second',now())+interval '3 days 3 hours','timezone','UTC','status','scheduled','visibility','member','targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',team1),jsonb_build_object('target_type','team','target_id',team2)))),md5('boss-phase4a-notif-live:reschedule')::uuid);passed:=passed+1;
 reset role;
 if (select count(*) from public.notification_events where organization_id=org and source_id=ev_id and event_type='event.rescheduled')<>1 then raise exception 'FAIL live reschedule source';end if;passed:=passed+1;
 if not exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id join public.notification_deliveries app on app.notification_id=n.id and app.channel='in_app' join public.notification_deliveries email on email.notification_id=n.id and email.channel='email' where n.recipient_person_id=parent and e.event_type='event.rescheduled' and app.status='sent' and email.status='suppressed' and email.failure_category='preference') then raise exception 'FAIL live preference channels';end if;passed:=passed+1;
 insert into public.registration_offerings(id,organization_id,title,scope_type,scope_id,status,created_by_person_id,updated_by_person_id) values(offering,org,'Synthetic live registration','organization',org,'published',admin,admin);
 insert into public.registrations(id,organization_id,offering_id,participant_id,submitted_by_person_id,status,offering_snapshot,participant_snapshot) values(reg,org,offering,participant1,parent,'submitted','{"offering":{"approval_required":true},"forms":[],"waivers":[],"documents":[],"fees":[]}','{}');
 insert into public.charges(id,organization_id,registration_id,participant_id,title,charge_type,original_amount_minor,currency,created_by_person_id) values(charge,org,reg,participant1,'Synthetic live fee','registration',1000,'USD',admin);
 set local role authenticated;
 result:=public.boss_registration_mutate(md5('boss-phase4a-notif-live:approval')::uuid,jsonb_build_object('operation','registration.decision','input',jsonb_build_object('registration_id',reg,'expected_version',1,'decision','approve','reason','Synthetic live decision')));passed:=passed+1;
 result:=public.boss_registration_mutate(md5('boss-phase4a-notif-live:payment')::uuid,jsonb_build_object('operation','payment.record_offline','input',jsonb_build_object('organization_id',org,'method','cash','amount_minor',1000,'currency','USD','payer_person_id',parent,'received_at',now(),'note','SYNTHETIC-PRIVATE-REFERENCE','allocations',jsonb_build_array(jsonb_build_object('charge_id',charge,'amount_minor',1000)))));passed:=passed+1;
 reset role;
 if not exists(select 1 from public.notification_events where organization_id=org and event_type='registration.approved' and source_id=reg) then raise exception 'FAIL live registration hook';end if;passed:=passed+1;
 if not exists(select 1 from public.notification_events where organization_id=org and event_type='payment.recorded') then raise exception 'FAIL live payment hook';end if;passed:=passed+1;
 actor_label:='parent';perform set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase4a-notif-live:auth-'||actor_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase4a-notif-live:session-'||actor_label)::uuid)::text,true);
 set local role authenticated;
 result:=public.boss_notifications_read('{}');if result::text like '%SYNTHETIC-PRIVATE-REFERENCE%' or result::text~'(provider_message_reference|primary_email|object_name|review_reason)' then raise exception 'FAIL live sensitive notification payload';end if;passed:=passed+1;
 result:=public.boss_notifications_mutate(md5('boss-phase4a-notif-live:read-all')::uuid,'{"operation":"notification.read_all","input":{}}');
 if (public.boss_notifications_read('{}')->>'unread_count')::int<>0 then raise exception 'FAIL live mark all read';end if;passed:=passed+1;
 reset role;
 update public.guardian_relationships set can_receive_communications=false,can_register=false,can_manage_payments=false where guardian_person_id=parent;
 set local role authenticated;
 result:=public.boss_notifications_read('{}');if jsonb_array_length(result->'notifications')<>0 or (result->>'unread_count')::int<>0 then raise exception 'FAIL live current guardian revocation';end if;passed:=passed+1;
 actor_label:='outsider';perform set_config('request.jwt.claims',jsonb_build_object('sub',md5('boss-phase4a-notif-live:auth-'||actor_label)::uuid,'role','authenticated','is_anonymous',false,'session_id',md5('boss-phase4a-notif-live:session-'||actor_label)::uuid)::text,true);
 if jsonb_array_length(public.boss_notifications_read('{}')->'notifications')<>0 then raise exception 'FAIL live unrelated recipient';end if;passed:=passed+1;
 begin perform public.boss_notifications_mutate(md5('boss-phase4a-notif-live:forged-read')::uuid,jsonb_build_object('operation','notification.read','input',jsonb_build_object('id',notif_id)));raise exception 'FAIL live forged notification id';exception when sqlstate 'PT403' then passed:=passed+1;end;
 begin update public.notifications set id=id;raise exception 'FAIL live direct notification write';exception when insufficient_privilege then passed:=passed+1;end;
 reset role;
 if has_function_privilege('authenticated','boss_private.notification_source_visible(public.notification_events,uuid)','EXECUTE') then raise exception 'FAIL live arbitrary recipient helper';end if;passed:=passed+1;
 if passed<>25 then raise exception 'FAIL live notification assertion accounting %',passed;end if;
end $live$;
rollback;
select 25 as passed_assertions,
 (select count(*) from public.organizations where slug like 'synthetic-phase4a-notif-live%') as residual_organizations,
 (select count(*) from public.people where display_name like 'Synthetic Phase4A Notification Live %') as residual_people,
 (select count(*) from auth.users where email like '%@phase4a-notif-live.example.invalid') as residual_auth_users,
 (select count(*) from public.notification_events where organization_id=md5('boss-phase4a-notif-live:org')::uuid) as residual_source_events,
 (select count(*) from public.notifications where organization_id=md5('boss-phase4a-notif-live:org')::uuid) as residual_notifications,
 (select count(*) from public.notification_deliveries where organization_id=md5('boss-phase4a-notif-live:org')::uuid) as residual_deliveries,
 (select count(*) from public.notification_preferences where person_id=md5('boss-phase4a-notif-live:parent')::uuid) as residual_preferences,
 (select count(*) from public.audit_events where organization_id=md5('boss-phase4a-notif-live:org')::uuid) as residual_audits;
