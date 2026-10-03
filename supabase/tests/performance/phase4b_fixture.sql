-- Persistent synthetic read workload for a disposable PostgreSQL database only.
-- Run AFTER every migration with psql -v boss_disposable=true [-v owned_events=4].
-- Profile this workload across connections; destroy its database for cleanup.
-- owned_events=8 models two children on two exact teams with four weekly
-- four-occurrence series plus four single events: 20 appointments in one month
-- and 60 guardian notification rows across the three prepared source kinds.
-- The 1/2/4 variants keep the same background organizations/teams/participants
-- and expose scaling without introducing additional guardian relationships.
-- Synthetic Auth rows below are local fixtures, never credential material.
-- Source delivery is seeded as already processed; this does not prove delivery
-- acceptance. No RLS, integrity trigger or security policy is disabled.
\if :{?boss_disposable}
\else
\set boss_disposable false
\endif
\if :{?owned_events}
\else
\set owned_events 4
\endif

begin;
set local timezone='UTC';
select set_config('boss.perf_fixture_disposable', :'boss_disposable', true);
select set_config('boss.perf_owned_events', :'owned_events', true);
do $$begin
 if current_setting('boss.perf_fixture_disposable')<>'true'
 or current_database() not like 'boss_phase4b%'
 or coalesce(inet_server_addr()::text,'127.0.0.1') not in ('127.0.0.1','::1') then
 raise exception 'Performance fixture requires explicitly approved local disposable boss_phase4b database';end if;
 if current_setting('boss.perf_owned_events')::integer not in (1,2,4,8) then
 raise exception 'owned_events must be 1, 2, 4 or 8';end if;
end$$;

create schema boss_perf;
revoke all on schema boss_perf from public;
create function boss_perf.id(label text) returns uuid language sql immutable as
$$select md5('boss-phase4b-performance:'||label)::uuid$$;
create function boss_perf.actor(label text) returns void language plpgsql as $$begin
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',boss_perf.id('auth-'||label),
 'role','authenticated','is_anonymous',false,'session_id',boss_perf.id('session-'||label))::text,true);
end$$;
create table boss_perf.seed_metadata(anchor timestamptz not null,owned_events integer not null);
insert into boss_perf.seed_metadata values(date_trunc('day',now())+interval '2 days 18 hours',current_setting('boss.perf_owned_events')::integer);
create table boss_perf.events(event_index integer primary key,event_id uuid not null,
 team_index integer not null,organization_index integer not null,owned boolean not null,recurring boolean not null);
insert into boss_perf.events
select n,boss_perf.id('event-'||n),
 case when n<=m.owned_events then 1+(n-1)%2 else 3+(n-m.owned_events-1)%10 end,
 case when n<=m.owned_events then 1 else 1+(2+(n-m.owned_events-1)%10)/4 end,
 n<=m.owned_events,n%4 in(1,2)
from generate_series(1,24)n cross join boss_perf.seed_metadata m;
create function boss_perf.query(view_name text default 'family',event_label text default null)
returns jsonb language sql stable as $$
 select jsonb_build_object('organization_id',boss_perf.id('org-1'),'view',view_name,
 'from',to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
 'to',to_char((anchor+interval '29 days') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'))
 ||case when event_label is null then '{}'::jsonb else jsonb_build_object('event_id',boss_perf.id(event_label))end
 from boss_perf.seed_metadata
$$;
create function boss_perf.notification_query(view_name text default 'inbox',filtered boolean default true)
returns jsonb language sql stable as $$
 select jsonb_build_object('view',view_name,'limit',case when view_name='summary' then 5 else 50 end)
 ||case when filtered then jsonb_build_object('organization_id',boss_perf.id('org-1'))else '{}'::jsonb end
$$;

insert into public.people(id,display_name,date_of_birth)
select boss_perf.id(label),'Synthetic performance '||label,'1990-01-01'::date
from (select unnest(array['admin','guardian','household-only','other-admin','coach'])label
 union all select 'recipient-'||n from generate_series(1,12)n) labels;
insert into auth.users(id,email,email_confirmed_at)
select boss_perf.id('auth-'||label),label||'@phase4b-performance.example.invalid',now()-interval '2 days'
from (select unnest(array['admin','guardian','household-only','other-admin','coach'])label
 union all select 'recipient-'||n from generate_series(1,12)n) labels;
insert into auth.sessions(id,user_id)
select boss_perf.id('session-'||label),boss_perf.id('auth-'||label)
from (select unnest(array['admin','guardian','household-only','other-admin','coach'])label
 union all select 'recipient-'||n from generate_series(1,12)n) labels;
insert into public.user_accounts(person_id,auth_user_id,account_status)
select boss_perf.id(label),boss_perf.id('auth-'||label),'active'
from (select unnest(array['admin','guardian','household-only','other-admin','coach'])label
 union all select 'recipient-'||n from generate_series(1,12)n) labels;
insert into public.people(id,display_name,date_of_birth)
select boss_perf.id('child-'||n),'Synthetic performance child '||n,'2014-01-01'::date from generate_series(1,180)n;
insert into public.organizations(id,name,slug)
select boss_perf.id('org-'||n),'Synthetic performance organization '||n,'synthetic-phase4b-performance-'||n from generate_series(1,3)n;
insert into public.organization_units(id,organization_id,unit_type,name,slug)
select boss_perf.id('unit-'||n),boss_perf.id('org-'||(1+(n-1)/4)),'program',
 'Synthetic performance unit '||n,'perf-unit-'||n from generate_series(1,12)n;
insert into public.teams(id,organization_id,parent_unit_id,name,slug,status)
select boss_perf.id('team-'||n),boss_perf.id('org-'||(1+(n-1)/4)),boss_perf.id('unit-'||n),
 'Synthetic performance team '||n,'perf-team-'||n,'active' from generate_series(1,12)n;
insert into public.participants(id,person_id)
select boss_perf.id('participant-'||n),boss_perf.id('child-'||n) from generate_series(1,180)n;
insert into public.organization_memberships(organization_id,person_id,starts_at,created_at)
select boss_perf.id('org-'||(1+((n-1)%12)/4)),boss_perf.id('child-'||n),now()-interval '2 days',now()-interval '2 days'
from generate_series(1,180)n;
insert into public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,starts_at,created_at)
select boss_perf.id('org-'||(1+((n-1)%12)/4)),boss_perf.id('team-'||(1+(n-1)%12)),
boss_perf.id('child-'||n),boss_perf.id('participant-'||n),'athlete',now()-interval '2 days',now()-interval '2 days'
from generate_series(1,180)n;
insert into public.team_memberships(organization_id,team_id,person_id,membership_type,starts_at,created_at)
values(boss_perf.id('org-1'),boss_perf.id('team-1'),boss_perf.id('coach'),'head_coach',now()-interval '2 days',now()-interval '2 days');
insert into public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,starts_at,created_at,can_respond_attendance)
select boss_perf.id('guardian-child-'||n),boss_perf.id('guardian'),boss_perf.id('child-'||n),'active',
now()-interval '2 days',now()-interval '2 days',now()-interval '2 days',true from generate_series(1,2)n;
insert into public.guardian_relationships(id,guardian_person_id,dependent_person_id,authority_status,verified_at,starts_at,created_at,can_respond_attendance)
select boss_perf.id('recipient-child-'||n),boss_perf.id('recipient-'||n),boss_perf.id('child-'||n),'active',
now()-interval '2 days',now()-interval '2 days',now()-interval '2 days',true from generate_series(1,12)n;
insert into public.households(id,name) values(boss_perf.id('household'),'Synthetic performance household');
insert into public.household_memberships(household_id,person_id,relationship_type,starts_at)
select boss_perf.id('household'),boss_perf.id(label),'member',now()-interval '2 days'
from unnest(array['guardian','household-only','child-1','child-2'])label;
insert into public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at,created_at)
select boss_perf.id('admin'),id,'platform',null,null,now()-interval '2 days',now()-interval '2 days'
from public.roles where key='platform_administrator';
insert into public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at,created_at)
select boss_perf.id('other-admin'),id,'organization',boss_perf.id('org-3'),boss_perf.id('org-3'),now()-interval '2 days',now()-interval '2 days'
from public.roles where key='organization_administrator';
insert into public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at,created_at)
select boss_perf.id('coach'),id,'team',boss_perf.id('team-1'),boss_perf.id('org-1'),now()-interval '2 days',now()-interval '2 days'
from public.roles where key='head_coach';
insert into public.organization_modules(organization_id,module_id,status,configuration,starts_at)
select boss_perf.id('org-'||n),m.id,'active',case when m.key='calendar' then
 '{"attendance":true,"attendance_rsvp":true,"attendance_guardian_rsvp":true,"attendance_reminders":true,"attendance_checkin":true,"attendance_head_coach_management":true}'::jsonb
else '{"communications":true,"announcements":true,"guardian_visibility":true,"in_app_notifications":false,"email_notifications":false}'::jsonb end,
now()-interval '2 days' from generate_series(1,3)n cross join public.modules m where m.key in('calendar','messaging');
insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,timezone,status,visibility,rsvp_mode,recurrence,created_by_person_id,updated_by_person_id)
select f.event_id,boss_perf.id('org-'||f.organization_index),'Synthetic performance event '||f.event_index,'practice',
m.anchor,m.anchor+interval '1 hour','UTC','scheduled','member','required',
case when f.recurring then '{"frequency":"weekly","interval":1,"count":4}'::jsonb else null end,boss_perf.id('admin'),boss_perf.id('admin')
from boss_perf.events f cross join boss_perf.seed_metadata m;
insert into public.event_targets(event_id,organization_id,target_type,target_id)
select event_id,boss_perf.id('org-'||organization_index),'team',boss_perf.id('team-'||team_index)from boss_perf.events;
insert into public.event_attendance_settings(organization_id,event_id,deadline_offset_minutes,audience,updated_by_person_id)
select boss_perf.id('org-'||organization_index),event_id,case when event_index%3=0 then 60 else null end,
array['participants','staff']::text[],boss_perf.id('admin')from boss_perf.events;
-- A canceled recurring occurrence stays present as a source but must be hidden
-- by current source visibility; no occurrence is invented from its key.
insert into public.event_occurrence_exceptions(id,organization_id,event_id,occurrence_key,status,created_by_person_id,updated_by_person_id)
select boss_perf.id('canceled-occurrence'),boss_perf.id('org-1'),boss_perf.id('event-1'),
to_char((anchor+interval '14 days')at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS'),'canceled',boss_perf.id('admin'),boss_perf.id('admin')
from boss_perf.seed_metadata;
create table boss_perf.occurrences as
select f.*,to_char((m.anchor+k*interval '7 days')at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS')occurrence_key,
boss_private.attendance_context(f.event_id,to_char((m.anchor+k*interval '7 days')at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS'))context_fingerprint,
k occurrence_index
from boss_perf.events f cross join boss_perf.seed_metadata m cross join lateral generate_series(0,case when f.recurring then 3 else 0 end)k;
insert into public.attendance_responses(id,organization_id,event_id,occurrence_key,person_id,participant_id,subject_kind,occurrence_mode,status,responder_person_id,guardian_relationship_id,context_fingerprint,needs_reconfirmation)
select boss_perf.id('response-'||event_index),boss_perf.id('org-'||organization_index),event_id,occurrence_key,
boss_perf.id('child-'||team_index),boss_perf.id('participant-'||team_index),'participant',case when recurring then 'recurring'else 'single'end,
case when event_index=1 then 'attending'else 'pending'end,boss_perf.id('recipient-'||team_index),boss_perf.id('recipient-child-'||team_index),context_fingerprint,event_index%5=0
from boss_perf.occurrences where occurrence_index=0;
insert into public.attendance_requests(id,organization_id,event_id,occurrence_key,kind,context_fingerprint,revision)
select boss_perf.id('source-'||event_index||'-'||occurrence_index||'-'||kind),boss_perf.id('org-'||organization_index),event_id,occurrence_key,kind,
context_fingerprint,'synthetic:'||kind||':'||context_fingerprint
from boss_perf.occurrences cross join unnest(array['requested','deadline','no_response'])kind;
-- Canonical delivery rows are seeded directly as processed to avoid making
-- timing preparation a benchmark of fan-out/mutation processing instead of reads.
insert into public.notification_events(id,organization_id,event_type,source_module,source_type,source_id,source_revision,safe_data,status,occurred_at)
select boss_perf.id('notification-event-'||r.id),r.organization_id,'attendance.'||r.kind,'calendar','attendance_request',r.id,r.revision,
jsonb_build_object('occurrence_key',r.occurrence_key),'complete',r.created_at from public.attendance_requests r
join boss_perf.events f on f.event_id=r.event_id;
insert into public.notifications(id,organization_id,notification_event_id,recipient_person_id,contexts,read_at,created_at)
select boss_perf.id('notification-'||e.id||'-'||label),e.organization_id,e.id,boss_perf.id(label),
jsonb_build_array(jsonb_build_object('source_type','attendance_request','source_id',e.source_id,'event_id',f.event_id,'team_id',boss_perf.id('team-'||f.team_index))),
case when r.kind='requested'and f.event_index%3=0 then now()else null end,
now()-make_interval(secs=>f.event_index*100+o.occurrence_index*10)
from public.notification_events e join public.attendance_requests r on r.id=e.source_id
join boss_perf.events f on f.event_id=r.event_id join boss_perf.occurrences o on o.event_id=r.event_id and o.occurrence_key=r.occurrence_key
cross join lateral(select 'recipient-'||f.team_index label union all select 'guardian'where f.owned)recipients;
insert into public.notification_deliveries(organization_id,notification_id,channel,status,sent_at)
select organization_id,id,'in_app','sent',now()from public.notifications where id in(
select boss_perf.id('notification-'||e.id||'-'||label)from public.notification_events e
join public.attendance_requests r on r.id=e.source_id join boss_perf.events f on f.event_id=r.event_id
cross join lateral(select 'recipient-'||f.team_index label union all select 'guardian'where f.owned)recipients);
update public.organization_modules om set configuration=configuration||'{"in_app_notifications":true}'::jsonb
from public.modules m where m.id=om.module_id and m.key='messaging'and om.organization_id in(select boss_perf.id('org-'||n)from generate_series(1,3)n);

grant usage on schema boss_perf to authenticated;
grant select on boss_perf.seed_metadata,boss_perf.events,boss_perf.occurrences to authenticated;
revoke all on all functions in schema boss_perf from public;
grant execute on function boss_perf.id(text),boss_perf.actor(text),boss_perf.query(text,text),boss_perf.notification_query(text,boolean)to authenticated;
-- Statistics match this completed, persistent workload before timing starts.
analyze public.organizations;analyze public.organization_modules;analyze public.people;
analyze public.organization_memberships;analyze public.team_memberships;analyze public.guardian_relationships;
analyze public.events;analyze public.event_targets;analyze public.event_occurrence_exceptions;
analyze public.event_attendance_settings;analyze public.attendance_responses;analyze public.attendance_requests;
analyze public.notification_events;analyze public.notifications;analyze public.notification_deliveries;
commit;
