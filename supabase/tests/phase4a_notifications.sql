-- Synthetic Phase 4A pipeline assertions. Every fixture is rolled back.
begin;
create temp table phase4a_notification_assertions(label text primary key,category text not null) on commit drop;
grant select,insert on phase4a_notification_assertions to authenticated,anon;
create function pg_temp.n(label text) returns uuid language sql immutable as $$select md5('boss-phase4a-notifications:'||label)::uuid$$;
create function pg_temp.check(label text,category text,ok boolean) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'FAIL [%] %',category,label;end if;insert into phase4a_notification_assertions values(label,category);end$$;
create function pg_temp.actor(label text) returns void language plpgsql as $$begin perform set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.n('auth-'||label),'role','authenticated','is_anonymous',false,'session_id',pg_temp.n('session-'||label))::text,true);end$$;
create function pg_temp.denied(label text,statement text,expected text default 'PT403') returns void language plpgsql as $$declare denied boolean:=false;begin begin execute statement;exception when others then if sqlstate=expected then denied:=true;else raise exception 'FAIL % unexpected %: %',label,sqlstate,sqlerrm;end if;end;perform pg_temp.check(label,'DENIAL',denied);end$$;
revoke all on function pg_temp.n(text),pg_temp.check(text,text,boolean),pg_temp.actor(text),pg_temp.denied(text,text,text) from public;
grant execute on function pg_temp.n(text),pg_temp.check(text,text,boolean),pg_temp.actor(text),pg_temp.denied(text,text,text) to authenticated,anon;

insert into public.people(id,display_name,date_of_birth)
select pg_temp.n(label),'Synthetic notification '||label,'1990-01-01'::date from unnest(array['admin','global','parent','household-only','outsider','late','child1','child2'])label;
insert into public.people(id,display_name,date_of_birth) select pg_temp.n('member-'||n),'Synthetic member '||n,'1990-01-01' from generate_series(1,110)n;
insert into auth.users(id,email,email_confirmed_at) select pg_temp.n('auth-'||label),label||'@phase4a.example.invalid',now()-interval '1 day'
from (select unnest(array['admin','global','parent','household-only','outsider','late']) label union all select 'member-'||n from generate_series(1,110)n)x;
insert into auth.sessions(id,user_id) select pg_temp.n('session-'||label),pg_temp.n('auth-'||label)
from (select unnest(array['admin','global','parent','household-only','outsider','late']) label union all select 'member-'||n from generate_series(1,110)n)x;
insert into public.user_accounts(person_id,auth_user_id,account_status) select pg_temp.n(label),pg_temp.n('auth-'||label),'active'
from (select unnest(array['admin','global','parent','household-only','outsider','late']) label union all select 'member-'||n from generate_series(1,110)n)x;
insert into public.organizations(id,name,slug) values(pg_temp.n('org'),'Synthetic Phase4A notifications','synthetic-phase4a-notifications'),(pg_temp.n('other-org'),'Synthetic Phase4A other tenant','synthetic-phase4a-notifications-other');
insert into public.organization_units(id,organization_id,unit_type,name,slug) values(pg_temp.n('unit'),pg_temp.n('org'),'program','Synthetic program','notification-program');
insert into public.teams(id,organization_id,parent_unit_id,name,slug,status) values(pg_temp.n('team1'),pg_temp.n('org'),pg_temp.n('unit'),'Synthetic team one','n1','active'),(pg_temp.n('team2'),pg_temp.n('org'),pg_temp.n('unit'),'Synthetic team two','n2','active');
insert into public.organization_memberships(organization_id,person_id,starts_at,created_at)
select pg_temp.n('org'),pg_temp.n(label),now()-interval '1 day',now()-interval '1 day' from (select unnest(array['admin','household-only','child1','child2','late'])label union all select 'member-'||n from generate_series(1,110)n)x;
insert into public.organization_memberships(organization_id,person_id,starts_at,created_at) values(pg_temp.n('other-org'),pg_temp.n('outsider'),now()-interval '1 day',now()-interval '1 day');
insert into public.participants(id,person_id) values(pg_temp.n('participant1'),pg_temp.n('child1')),(pg_temp.n('participant2'),pg_temp.n('child2'));
insert into public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at,created_at) values
(pg_temp.n('org'),pg_temp.n('team1'),pg_temp.n('child1'),pg_temp.n('participant1'),'athlete',now()-interval '1 day',now()-interval '1 day'),
(pg_temp.n('org'),pg_temp.n('team2'),pg_temp.n('child2'),pg_temp.n('participant2'),'athlete',now()-interval '1 day',now()-interval '1 day');
insert into public.guardian_relationships(guardian_person_id,dependent_person_id,authority_status,verified_at,starts_at,can_receive_communications,can_register,can_manage_payments,created_at)
select pg_temp.n('parent'),pg_temp.n(child),'active',now()-interval '1 day',now()-interval '1 day',true,true,true,now()-interval '1 day' from unnest(array['child1','child2'])child;
insert into public.households(id,name) values(pg_temp.n('household'),'Synthetic household');
insert into public.household_memberships(household_id,person_id,relationship_type,starts_at) values(pg_temp.n('household'),pg_temp.n('household-only'),'guardian',now()-interval '1 day'),(pg_temp.n('household'),pg_temp.n('child1'),'dependent',now()-interval '1 day');
insert into public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at,created_at)
select pg_temp.n('admin'),id,'organization',pg_temp.n('org'),pg_temp.n('org'),now()-interval '1 day',now()-interval '1 day' from public.roles where key='organization_administrator';
insert into public.role_assignments(person_id,role_id,scope_type,starts_at,created_at) select pg_temp.n('global'),id,'platform',now()-interval '1 day',now()-interval '1 day' from public.roles where key='platform_administrator';
insert into public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at,created_at)
select pg_temp.n('late'),id,'organization',pg_temp.n('org'),pg_temp.n('org'),now()-interval '1 minute',now()-interval '1 day' from public.roles where key='organization_administrator';
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at)
select pg_temp.n('org'),id,'active',case when key='registration' then '{"registration":true,"fees":true,"offline_payments":true}'::jsonb when key='messaging' then '{"team_chat":true,"direct_messaging":true}'::jsonb else '{}'::jsonb end,now()-interval '1 day'
from public.modules where key in ('calendar','registration','messaging');
insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,timezone,status,visibility,created_by_person_id,updated_by_person_id)
values(pg_temp.n('event'),pg_temp.n('org'),'Synthetic multi-team event','practice',date_trunc('second',now())+interval '3 days',date_trunc('second',now())+interval '3 days 1 hour','UTC','scheduled','member',pg_temp.n('admin'),pg_temp.n('admin')),
(pg_temp.n('org-event'),pg_temp.n('org'),'Synthetic organization event','practice',date_trunc('second',now())+interval '4 days',date_trunc('second',now())+interval '4 days 1 hour','UTC','scheduled','member',pg_temp.n('admin'),pg_temp.n('admin')),
(pg_temp.n('private-event'),pg_temp.n('org'),'Synthetic private event','practice',date_trunc('second',now())+interval '5 days',date_trunc('second',now())+interval '5 days 1 hour','UTC','scheduled','private',pg_temp.n('admin'),pg_temp.n('admin'));
insert into public.event_targets(event_id,organization_id,target_type,target_id) values
(pg_temp.n('event'),pg_temp.n('org'),'team',pg_temp.n('team1')),(pg_temp.n('event'),pg_temp.n('org'),'team',pg_temp.n('team2')),
(pg_temp.n('org-event'),pg_temp.n('org'),'organization',pg_temp.n('org')),(pg_temp.n('private-event'),pg_temp.n('org'),'organization',pg_temp.n('org'));
select boss_private.notification_enqueue('calendar','event',pg_temp.n('event'),pg_temp.n('org'),'event.rescheduled','first');
select boss_private.notification_enqueue('calendar','event',pg_temp.n('event'),pg_temp.n('org'),'event.rescheduled','first');
select pg_temp.check('source event deduplicated','IDEMPOTENCY',(select count(*)=1 from public.notification_events where source_id=pg_temp.n('event')));
select pg_temp.check('parent active account resolves','IDENTITY',boss_private.notification_person_active(pg_temp.n('parent')));
select pg_temp.check('parent current communication guardian','GUARDIAN',boss_private.notification_guardian(pg_temp.n('parent'),pg_temp.n('child1'),'can_receive_communications'));
select pg_temp.check('parent event source visible','GUARDIAN',boss_private.notification_source_visible((select e from public.notification_events e where source_revision='first'),pg_temp.n('parent')));
select boss_private.notification_process(pg_temp.n('org'),100);
select boss_private.notification_process(pg_temp.n('org'),100);
select pg_temp.check('two-child parent one notification','DEDUP',(select count(*)=1 from public.notifications where recipient_person_id=pg_temp.n('parent')));
select pg_temp.check('one inapp and one email delivery','DEDUP',(select count(*)=2 from public.notification_deliveries d join public.notifications n on n.id=d.notification_id where n.recipient_person_id=pg_temp.n('parent')));
select pg_temp.check('global read power does not subscribe','AUDIENCE',not exists(select 1 from public.notifications where recipient_person_id=pg_temp.n('global')));
select pg_temp.check('unrelated household does not subscribe','AUDIENCE',not exists(select 1 from public.notifications where recipient_person_id=pg_temp.n('household-only')));
select pg_temp.check('unrelated tenant does not subscribe','TENANCY',not exists(select 1 from public.notifications where recipient_person_id=pg_temp.n('outsider')));
select pg_temp.check('email remains unconfigured','PROVIDER',(select bool_and(status='suppressed' and failure_category='not_configured') from public.notification_deliveries where channel='email'));
select pg_temp.check('sent does not mean delivered','PROVIDER',not exists(select 1 from public.notification_deliveries where status='delivered' or delivered_at is not null));
select boss_private.notification_enqueue('calendar','event',pg_temp.n('org-event'),pg_temp.n('org'),'event.created','large');
select pg_temp.check('bounded page no more than100','BOUNDS',(boss_private.notification_process(pg_temp.n('org'),100)->>'processed')::int<=100);
select pg_temp.check('larger audience remains pending','BOUNDS',exists(select 1 from boss_private.notification_expansion_jobs j join public.notification_events e on e.id=j.notification_event_id where e.source_id=pg_temp.n('org-event') and j.status='queued'));
select boss_private.notification_process(pg_temp.n('org'),100);
select pg_temp.check('larger audience eventually all110','BOUNDS',(select count(*)=110 from public.notifications n join public.notification_events e on e.id=n.notification_event_id where e.source_id=pg_temp.n('org-event') and n.recipient_person_id in(select pg_temp.n('member-'||n) from generate_series(1,110)n)));
insert into public.notification_events(organization_id,event_type,source_module,source_type,source_id,source_revision,occurred_at)
values(pg_temp.n('org'),'event.rescheduled','calendar','event',pg_temp.n('private-event'),'before-late-role',now()-interval '2 minutes');
select pg_temp.check('later role cannot receive old private change','EVENT-TIME',not boss_private.notification_source_visible((select e from public.notification_events e where source_revision='before-late-role'),pg_temp.n('late')));
select pg_temp.check('existing tenant role receives private change','EVENT-TIME',boss_private.notification_source_visible((select e from public.notification_events e where source_revision='before-late-role'),pg_temp.n('admin')));
select pg_temp.check('global-only role excluded from old private change','EVENT-TIME',not boss_private.notification_source_visible((select e from public.notification_events e where source_revision='before-late-role'),pg_temp.n('global')));
-- Backdating a newly inserted relationship window cannot subscribe to an older source.
insert into public.role_assignments(id,person_id,role_id,scope_type,scope_id,organization_id,starts_at)
select pg_temp.n('backdated-role'),pg_temp.n('late'),id,'organization',pg_temp.n('org'),pg_temp.n('org'),now()-interval '1 day' from public.roles where key='organization_administrator';
select pg_temp.check('backdated new role has current permission','EVENT-TIME',boss_private.comm_permission(pg_temp.n('late'),'events.manage',pg_temp.n('org'),'organization',pg_temp.n('org')));
select pg_temp.check('backdated new role cannot receive old source','EVENT-TIME',not boss_private.notification_source_visible((select e from public.notification_events e where source_revision='before-late-role'),pg_temp.n('late')));
delete from public.role_assignments where id=pg_temp.n('backdated-role');
insert into public.organization_memberships(id,organization_id,person_id,starts_at) values(pg_temp.n('backdated-membership'),pg_temp.n('org'),pg_temp.n('outsider'),now()-interval '1 day');
select pg_temp.check('backdated new membership has current context','EVENT-TIME',boss_private.comm_context_related(pg_temp.n('outsider'),pg_temp.n('org'),'organization',pg_temp.n('org')));
select pg_temp.check('backdated new membership cannot receive old source','EVENT-TIME',not boss_private.notification_event_visible(pg_temp.n('org-event'),pg_temp.n('outsider'),now()-interval '2 minutes'));
delete from public.organization_memberships where id=pg_temp.n('backdated-membership');
insert into public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,starts_at,can_receive_communications)
values(pg_temp.n('backdated-guardian'),pg_temp.n('household-only'),pg_temp.n('child1'),'active',now()-interval '1 day',now()-interval '1 day',true);
select pg_temp.check('backdated new guardian has current capability','EVENT-TIME',boss_private.comm_guardian(pg_temp.n('household-only'),pg_temp.n('child1'),'can_receive_communications'));
select pg_temp.check('backdated new guardian cannot receive old source','EVENT-TIME',not boss_private.notification_event_visible(pg_temp.n('event'),pg_temp.n('household-only'),now()-interval '2 minutes'));
delete from public.guardian_relationships where id=pg_temp.n('backdated-guardian');


set local role authenticated;
select pg_temp.actor('parent');
select pg_temp.check('signed inbox current recipient only','INBOX',(select jsonb_array_length(public.boss_notifications_read('{}')->'notifications')>=1));
select pg_temp.check('unread count positive','UNREAD',(public.boss_notifications_read('{}')->>'unread_count')::int>=1);
select public.boss_notifications_mutate(pg_temp.n('read-one-request'),jsonb_build_object('operation','notification.read','input',jsonb_build_object('id',public.boss_notifications_read('{}')->'notifications'->0->>'id')));
select pg_temp.check('mark one read persists database timestamp','UNREAD',exists(select 1 from jsonb_array_elements(public.boss_notifications_read('{}')->'notifications')n where n->>'read_at' is not null));
select public.boss_notifications_mutate(pg_temp.n('read-all-request'),'{"operation":"notification.read_all","input":{}}');
select pg_temp.check('read_all clears unread count','UNREAD',(public.boss_notifications_read('{}')->>'unread_count')::int=0);
select pg_temp.check('safe output no provider internals','PRIVACY',public.boss_notifications_read('{}')::text!~'(provider_message_reference|primary_email|object_name|review_reason)');
select public.boss_notifications_mutate(pg_temp.n('pref-request'),'{"operation":"preference.set","input":{"channel":"email","category":"events","enabled":false}}');
select pg_temp.check('self preference persists','PREFERENCES',exists(select 1 from jsonb_array_elements(public.boss_notifications_read('{"view":"preferences"}')->'preferences')p where p->>'channel'='email' and p->>'enabled'='false'));
select pg_temp.denied('parent cannot run worker',format('select public.boss_notifications_mutate(%L,%L)',pg_temp.n('forged-worker'),jsonb_build_object('operation','delivery.process','input',jsonb_build_object('organization_id',pg_temp.n('org')))));
select pg_temp.denied('parent cannot inspect recipient history',format('select public.boss_notifications_read(%L)',jsonb_build_object('view','history','organization_id',pg_temp.n('org'))));
select pg_temp.denied('client cannot choose recipient',format('select public.boss_notifications_mutate(%L,%L)',pg_temp.n('inject'),'{"operation":"preference.set","input":{"channel":"email","category":"events","enabled":true,"person_id":"00000000-0000-0000-0000-000000000000"}}'),'PT422');
select pg_temp.denied('client cannot choose mandatory',format('select public.boss_notifications_mutate(%L,%L)',pg_temp.n('mandatory'),'{"operation":"preference.set","input":{"channel":"email","category":"events","enabled":true,"mandatory":true}}'),'PT422');
select pg_temp.denied('conflicting receipt rejected',format('select public.boss_notifications_mutate(%L,%L)',pg_temp.n('pref-request'),'{"operation":"preference.set","input":{"channel":"email","category":"events","enabled":true}}'),'PT409');
select pg_temp.denied('forged notification id denied',format('select public.boss_notifications_mutate(%L,%L)',pg_temp.n('forged-id'),jsonb_build_object('operation','notification.read','input',jsonb_build_object('id',pg_temp.n('missing-notification')))));
do $$declare t text;begin foreach t in array array['notification_events','notifications','notification_preferences','notification_deliveries']loop
 perform pg_temp.denied('raw select denied '||t,'select * from public.'||t,'42501');
 perform pg_temp.denied('raw update denied '||t,'update public.'||t||' set id=id','42501');
end loop;end$$;
select pg_temp.denied('private recipient impersonation denied',format('select boss_private.notification_event_visible(%L,%L,now())',pg_temp.n('event'),pg_temp.n('parent')),'42501');
select pg_temp.actor('outsider');
select pg_temp.check('outsider inbox empty','TENANCY',jsonb_array_length(public.boss_notifications_read('{}')->'notifications')=0);
select pg_temp.denied('forged org preference denied',format('select public.boss_notifications_mutate(%L,%L)',pg_temp.n('foreign-pref'),jsonb_build_object('operation','preference.set','input',jsonb_build_object('channel','email','category','events','enabled',true,'organization_id',pg_temp.n('org')))));
reset role;

select boss_private.notification_enqueue('calendar','event',pg_temp.n('event'),pg_temp.n('org'),'event.rescheduled','preference');
select boss_private.notification_process(pg_temp.n('org'),100);select boss_private.notification_process(pg_temp.n('org'),100);
select pg_temp.check('optional email suppressed but inapp remains','PREFERENCES',exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id join public.notification_deliveries email on email.notification_id=n.id and email.channel='email' join public.notification_deliveries app on app.notification_id=n.id and app.channel='in_app' where n.recipient_person_id=pg_temp.n('parent') and e.source_revision='preference' and email.status='suppressed' and email.failure_category='preference' and app.status='sent'));
select pg_temp.check('internal mandatory survives optional preference','POLICY',boss_private.notification_preference(pg_temp.n('parent'),pg_temp.n('org'),null,'email','events',true));
select pg_temp.check('no invented active mandatory categories','POLICY',not exists(select 1 from boss_private.notification_types where mandatory));
insert into public.notification_preferences(person_id,organization_id,team_id,channel,category,enabled)
values(pg_temp.n('parent'),pg_temp.n('org'),pg_temp.n('team1'),'email','events',false),(pg_temp.n('parent'),pg_temp.n('org'),pg_temp.n('team2'),'email','events',false);
select pg_temp.check('all qualifying team contexts off suppress optional email','TEAM-PREFERENCES',not boss_private.notification_context_preference((select e from public.notification_events e where source_revision='first'),pg_temp.n('parent'),'email','events',false));
update public.notification_preferences set enabled=true where person_id=pg_temp.n('parent') and team_id=pg_temp.n('team2');
select pg_temp.check('one qualifying team context on enables one delivery','TEAM-PREFERENCES',boss_private.notification_context_preference((select e from public.notification_events e where source_revision='first'),pg_temp.n('parent'),'email','events',false));
select pg_temp.check('two child team contexts preserved without recipients','TEAM-PREFERENCES',jsonb_array_length(boss_private.notification_contexts((select e from public.notification_events e where source_revision='first'),pg_temp.n('parent')))=3);

insert into public.event_reminders(id,organization_id,event_id,minutes_before,audience) values(pg_temp.n('reminder'),pg_temp.n('org'),pg_temp.n('event'),60,array['coaches']);
select boss_private.notification_generate_reminders(pg_temp.n('org'),now(),date_trunc('second',now())+interval '7 days');
select pg_temp.check('reminder foundation schedules configured work','REMINDERS',exists(select 1 from public.notification_events where event_type='event.reminder'));
select pg_temp.check('coaches reminder does not broaden to parent','REMINDERS',not boss_private.notification_source_visible((select e from public.notification_events e where event_type='event.reminder' limit 1),pg_temp.n('parent')));
update public.event_reminders set audience=array['guardians'] where id=pg_temp.n('reminder');
select pg_temp.check('guardian reminder explicitly qualified','REMINDERS',boss_private.notification_source_visible((select e from public.notification_events e where event_type='event.reminder' limit 1),pg_temp.n('parent')));
update public.event_reminders set enabled=false where id=pg_temp.n('reminder');
select pg_temp.check('disabled reminder suppresses old work','REMINDERS',not boss_private.notification_source_visible((select e from public.notification_events e where event_type='event.reminder' limit 1),pg_temp.n('parent')));
update public.event_reminders set enabled=true where id=pg_temp.n('reminder');
-- Actual signed calendar RPC exercises the audit integration and trivial edits.
set local role authenticated;select pg_temp.actor('admin');
select public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',pg_temp.n('org'),'event_id',pg_temp.n('event'),'expected_version',1,'title','Synthetic harmless title update','event_type_key','practice','start_at',date_trunc('second',now())+interval '3 days','end_at',date_trunc('second',now())+interval '3 days 1 hour','timezone','UTC','status','scheduled','visibility','member','targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.n('team1')),jsonb_build_object('target_type','team','target_id',pg_temp.n('team2'))))),pg_temp.n('trivial'));
reset role;
select pg_temp.check('trivial edit does not notify','MATERIAL',not exists(select 1 from public.notification_events where source_revision=pg_temp.n('trivial')::text));
set local role authenticated;select pg_temp.actor('admin');
select public.boss_calendar_mutate(jsonb_build_object('operation','event.update','input',jsonb_build_object('organization_id',pg_temp.n('org'),'event_id',pg_temp.n('event'),'expected_version',2,'title','Synthetic moved event','event_type_key','practice','start_at',date_trunc('second',now())+interval '3 days 2 hours','end_at',date_trunc('second',now())+interval '3 days 3 hours','timezone','UTC','status','scheduled','visibility','member','targets',jsonb_build_array(jsonb_build_object('target_type','team','target_id',pg_temp.n('team1')),jsonb_build_object('target_type','team','target_id',pg_temp.n('team2'))))),pg_temp.n('reschedule'));
reset role;
select pg_temp.check('actual reschedule emits one event','INTEGRATION',(select count(*)=1 from public.notification_events where source_revision=pg_temp.n('reschedule')::text and event_type='event.rescheduled'));
select pg_temp.check('actual reschedule cancels old reminder','INTEGRATION',(select bool_and(status='canceled') from public.notification_events where event_type='event.reminder'));

insert into public.registration_offerings(id,organization_id,title,scope_type,scope_id,status,created_by_person_id,updated_by_person_id,closes_at)
values(pg_temp.n('offer'),pg_temp.n('org'),'Synthetic registration','organization',pg_temp.n('org'),'published',pg_temp.n('admin'),pg_temp.n('admin'),date_trunc('second',now())+interval '2 days');
insert into public.registrations(id,organization_id,offering_id,participant_id,submitted_by_person_id,status,offering_snapshot,participant_snapshot)
values(pg_temp.n('registration'),pg_temp.n('org'),pg_temp.n('offer'),pg_temp.n('participant1'),pg_temp.n('parent'),'submitted','{"offering":{"approval_required":true},"forms":[],"waivers":[],"documents":[],"fees":[]}','{}');
insert into public.charges(id,organization_id,registration_id,participant_id,title,charge_type,original_amount_minor,currency,created_by_person_id,due_on)
values(pg_temp.n('charge'),pg_temp.n('org'),pg_temp.n('registration'),pg_temp.n('participant1'),'Synthetic fee','registration',1000,'USD',pg_temp.n('admin'),current_date-1);
set local role authenticated;select pg_temp.actor('admin');
select public.boss_registration_mutate(pg_temp.n('approval'),jsonb_build_object('operation','registration.decision','input',jsonb_build_object('registration_id',pg_temp.n('registration'),'expected_version',1,'decision','approve','reason','Synthetic acceptance')));
reset role;
select pg_temp.check('actual approval emits notification source','INTEGRATION',exists(select 1 from public.notification_events where source_id=pg_temp.n('registration') and event_type='registration.approved'));
select boss_private.notification_enqueue('registration','charge',pg_temp.n('charge'),pg_temp.n('org'),'fee.overdue','unpaid');
select pg_temp.check('overdue unpaid source visible','FEES',boss_private.notification_source_visible((select e from public.notification_events e where source_revision='unpaid'),pg_temp.n('parent')));
set local role authenticated;select pg_temp.actor('admin');
select public.boss_registration_mutate(pg_temp.n('payment'),jsonb_build_object('operation','payment.record_offline','input',jsonb_build_object('organization_id',pg_temp.n('org'),'method','cash','amount_minor',1000,'currency','USD','payer_person_id',pg_temp.n('parent'),'received_at',now(),'allocations',jsonb_build_array(jsonb_build_object('charge_id',pg_temp.n('charge'),'amount_minor',1000)))));
reset role;
select pg_temp.check('actual offline recording emits receipt source','INTEGRATION',exists(select 1 from public.notification_events where event_type='payment.recorded'));
select pg_temp.check('paid balance suppresses old overdue work','FEES',not boss_private.notification_source_visible((select e from public.notification_events e where source_revision='unpaid'),pg_temp.n('parent')));
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.check('signed admin worker bounded','WORKER',(public.boss_notifications_mutate(pg_temp.n('signed-worker'),jsonb_build_object('operation','delivery.process','input',jsonb_build_object('organization_id',pg_temp.n('org'),'limit',100)))->>'processed')::int<=100);
select pg_temp.check('safe scoped delivery history available','HISTORY',jsonb_array_length(public.boss_notifications_read(jsonb_build_object('view','history','organization_id',pg_temp.n('org')))->'history')>0);
select pg_temp.check('history contains no provider email privatepayload','HISTORY',public.boss_notifications_read(jsonb_build_object('view','history','organization_id',pg_temp.n('org')))::text!~'(provider_message_reference|primary_email|review_reason|object_name)');
select pg_temp.denied('worker limit over100 denied',format('select public.boss_notifications_mutate(%L,%L)',pg_temp.n('huge-worker'),jsonb_build_object('operation','delivery.process','input',jsonb_build_object('organization_id',pg_temp.n('org'),'limit',101))),'PT422');
select pg_temp.denied('reminder window over7days denied',format('select public.boss_notifications_mutate(%L,%L)',pg_temp.n('huge-reminder'),jsonb_build_object('operation','reminder.generate','input',jsonb_build_object('organization_id',pg_temp.n('org'),'window_start',now(),'window_end',now()+interval '8 days'))),'PT422');
reset role;
select boss_private.notification_enqueue('registration','registration',pg_temp.n('registration'),pg_temp.n('org'),'registration.missing_requirement','missing');
select pg_temp.check('missing item source safe generic template','PRIVACY',(select t.body!~*'(medical|birth|reason|object)' from boss_private.notification_types t where t.key='registration.missing_requirement'));
update public.registrations set form_status='not_required',waiver_status='not_required',document_status='not_required' where id=pg_temp.n('registration');
select pg_temp.check('completed status suppresses missing reminder','REGISTRATION',not boss_private.notification_source_visible((select e from public.notification_events e where source_revision='missing'),pg_temp.n('parent')));
-- Private corruption/fault injection is local only. A bad page must not block the
-- canonical source, leak an error body or retry forever. No API can write it.
select boss_private.notification_enqueue('calendar','event',pg_temp.n('event'),pg_temp.n('org'),'event.rescheduled','retry-fault');
update public.notification_events set safe_data='{"team_id":"synthetic-invalid"}' where source_revision='retry-fault';
-- The preceding bounded page can consume this call's 100-person allowance.
-- Advance at most 32 finite fixture pages; do not widen production limits.
do $$begin for page in 1..32 loop
 exit when exists(select 1 from boss_private.notification_expansion_jobs j join public.notification_events e on e.id=j.notification_event_id where e.source_revision='retry-fault' and j.attempts>0);
 perform boss_private.notification_process(pg_temp.n('org'),100);
end loop;end$$;
select pg_temp.check('failed expansion persists one safe attempt','RETRY',(select j.attempts=1 and j.status='queued' and j.next_attempt_at>now() from boss_private.notification_expansion_jobs j join public.notification_events e on e.id=j.notification_event_id where e.source_revision='retry-fault'));
do $$begin for expected_attempt in 2..5 loop
 update boss_private.notification_expansion_jobs j set next_attempt_at=now() from public.notification_events e where e.id=j.notification_event_id and e.source_revision='retry-fault';
 for page in 1..32 loop
  exit when exists(select 1 from boss_private.notification_expansion_jobs j join public.notification_events e on e.id=j.notification_event_id where e.source_revision='retry-fault' and j.attempts>=expected_attempt);
  perform boss_private.notification_process(pg_temp.n('org'),100);
 end loop;
end loop;end$$;
select pg_temp.check('five failed pages become terminal','RETRY',(select j.attempts=5 and j.status='failed' and e.status='failed' from boss_private.notification_expansion_jobs j join public.notification_events e on e.id=j.notification_event_id where e.source_revision='retry-fault'));
select pg_temp.check('failed page leaves no partial recipients','RETRY',not exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id where e.source_revision='retry-fault'));
select pg_temp.check('calendar CTA includes safe canonical date','CTA',(select boss_private.notification_destination(e)~'^/app/calendar\?org=[0-9a-f-]+&event=[0-9a-f-]+&date=[0-9]{4}-[0-9]{2}-[0-9]{2}&tz=UTC&occurrence=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}%3A[0-9]{2}%3A[0-9]{2}$' from public.notification_events e where e.source_revision='first'));
-- A moved recurring instance must retain its original occurrence identity while
-- the destination day uses its current effective start in the canonical timezone.
insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,timezone,status,visibility,recurrence,created_by_person_id,updated_by_person_id)
values(pg_temp.n('cta-event'),pg_temp.n('org'),'Synthetic CTA recurrence','practice',((current_date+5)::timestamp+interval '23 hours 30 minutes') at time zone 'America/Chicago',((current_date+6)::timestamp+interval '30 minutes') at time zone 'America/Chicago','America/Chicago','scheduled','member','{"frequency":"daily","count":3}',pg_temp.n('admin'),pg_temp.n('admin'));
insert into public.event_targets(event_id,organization_id,target_type,target_id) values(pg_temp.n('cta-event'),pg_temp.n('org'),'team',pg_temp.n('team1'));
insert into public.event_occurrence_exceptions(event_id,organization_id,occurrence_key,override_start_at,override_end_at,created_by_person_id,updated_by_person_id)
values(pg_temp.n('cta-event'),pg_temp.n('org'),to_char((current_date+6)::timestamp+interval '23 hours 30 minutes','YYYY-MM-DD"T"HH24:MI:SS'),((current_date+5)::timestamp+interval '22 hours') at time zone 'America/Chicago',((current_date+5)::timestamp+interval '23 hours') at time zone 'America/Chicago',pg_temp.n('admin'),pg_temp.n('admin'));
insert into public.notification_events(organization_id,event_type,source_module,source_type,source_id,source_revision,safe_data)
values(pg_temp.n('org'),'event.reminder','calendar','event',pg_temp.n('cta-event'),'cta-moved',jsonb_build_object('occurrence_key',to_char((current_date+6)::timestamp+interval '23 hours 30 minutes','YYYY-MM-DD"T"HH24:MI:SS')));
select pg_temp.check('calendar CTA encodes canonical zone','CTA',(select position('&tz=America%2FChicago&' in boss_private.notification_destination(e))>0 from public.notification_events e where e.source_revision='cta-moved'));
select pg_temp.check('calendar CTA moved date preserves original occurrence','CTA',(select boss_private.notification_destination(e)='/app/calendar?org='||pg_temp.n('org')||'&event='||pg_temp.n('cta-event')||'&date='||(current_date+5)::text||'&tz=America%2FChicago&occurrence='||(current_date+6)::text||'T23%3A30%3A00' from public.notification_events e where e.source_revision='cta-moved'));
update public.events set timezone='Etc/GMT+5' where id=pg_temp.n('cta-event');
select pg_temp.check('calendar CTA encodes timezone plus','CTA',(select position('&tz=Etc%2FGMT%2B5&' in boss_private.notification_destination(e))>0 from public.notification_events e where e.source_revision='cta-moved'));
-- Current guardian flags are necessary for cached notifications, not HH labels.
update public.guardian_relationships set can_receive_communications=false,can_register=false,can_manage_payments=false where guardian_person_id=pg_temp.n('parent');
set local role authenticated;select pg_temp.actor('parent');
select pg_temp.check('revoked guardian loses inbox immediately','REVOCATION',jsonb_array_length(public.boss_notifications_read('{}')->'notifications')=0);
select pg_temp.check('revoked guardian unread disappears','REVOCATION',(public.boss_notifications_read('{}')->>'unread_count')::int=0);
reset role;
-- Actual authorized module availability drives the header drawer/nav projection.
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.check('enabled authorized module summary available','FEATURES',(public.boss_notifications_read('{"view":"summary"}')->'availability'->>'in_app')::boolean);
reset role;
update public.organization_modules om set configuration=om.configuration||'{"in_app_notifications":false}'::jsonb from public.modules m where m.id=om.module_id and m.key='messaging' and om.organization_id=pg_temp.n('org');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.check('disabled inapp feature summary unavailable','FEATURES',not (public.boss_notifications_read('{"view":"summary"}')->'availability'->>'in_app')::boolean and not (public.boss_notifications_read('{"view":"summary"}')->'features'->>'notifications')::boolean);
reset role;
update public.organization_modules set status='inactive' where organization_id=pg_temp.n('org');
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.check('all modules disabled summary has no access','FEATURES',(select not (s->'availability'->>'in_app')::boolean and not (s->'features'->>'in_app_notifications')::boolean and jsonb_array_length(s->'organizations')=0 and jsonb_array_length(s->'notifications')=0 and (s->>'unread_count')::int=0 from (select public.boss_notifications_read('{"view":"summary"}') s)x));
select public.boss_notifications_mutate(pg_temp.n('global-pref-disabled'),' {"operation":"preference.set","input":{"channel":"in_app","category":"events","enabled":false}}');
select pg_temp.check('global self preference foundation remains usable','FEATURES',exists(select 1 from jsonb_array_elements(public.boss_notifications_read('{"view":"preferences"}')->'preferences')p where p->>'channel'='in_app' and p->>'category'='events' and p->>'enabled'='false' and p->>'organization_id' is null));
reset role;
do $$declare table_name text;begin foreach table_name in array array['notification_events','notifications','notification_preferences','notification_deliveries'] loop perform pg_temp.check(table_name||' RLS enabled','RLS',(select c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=table_name));end loop;end$$;
select category,count(*) assertions from phase4a_notification_assertions group by category order by category;
select count(*) as passed_assertions from phase4a_notification_assertions;
rollback;
