-- Synthetic occurrence/context equivalence and structural performance regression.
-- Disposable PostgreSQL only. No real account, grant, DOB, or document fixture.
-- Run-local enables function tracking at local cluster startup, so this suite
-- executes as the ordinary managed-like migration owner without extra grants.
-- Every fixture and test helper rolls back. No elapsed-time threshold is used.
begin;
set local timezone='UTC';
set local statement_timeout='8s';
do $$begin
 if current_user<>'postgres' or inet_server_addr() is not null
 or not exists(select 1 from pg_roles where rolname='boss_test_admin' and rolsuper) then
  raise exception 'Performance regression requires the disposable local test cluster';
 end if;
end$$;
create temp table phase4b_performance_assertions(label text primary key,category text not null) on commit drop;
create function pg_temp.performance_id(label text) returns uuid language sql immutable as
$$select md5('boss-phase4b-performance-regression:'||label)::uuid$$;
create function pg_temp.performance_check(label text,category text,ok boolean) returns void language plpgsql as $$begin
 if ok is distinct from true then raise exception 'FAIL [%] %',category,label;end if;
 insert into phase4b_performance_assertions values(label,category);
end$$;
-- Immutable test reference: this is the original context expression, including
-- NULL behavior and epoch conversions. It is never installed in boss_private.
create function pg_temp.original_attendance_context(p_event uuid,p_key text) returns text
language sql stable set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object('occurrence_key',p_key,
 'start_epoch',extract(epoch from (occurrence->>'start_at')::timestamptz),
 'end_epoch',extract(epoch from (occurrence->>'end_at')::timestamptz),
 'status',occurrence->>'status','timezone',e.timezone,'recurrence',e.recurrence,
 'venue_id',e.venue_id,'resource_id',e.resource_id)::text,'UTF8')),'hex')
 from public.events e cross join lateral
 (select boss_private.attendance_occurrence(e.id,p_key) occurrence) current_occurrence
 where e.id=p_event
$$;
create function pg_temp.original_attendance_configuration(p_org uuid) returns jsonb
language sql stable set search_path='' as $$
 with cfg as (select boss_private.coordination_configuration(p_org,'calendar') as c),
 keys as (select unnest(array['attendance','rsvp','participant_self_response','guardian_rsvp','attendance_reminders','checkin','head_coach_management','assistant_coach_management']) as k)
 select jsonb_object_agg(k,case when jsonb_typeof(c->boss_private.attendance_storage_key(k))='boolean' then c->boss_private.attendance_storage_key(k) else 'false'::jsonb end)
 || jsonb_build_object('minimum_self_response_age',case when not c?'attendance_minimum_self_response_age' then 18
 when jsonb_typeof(c->'attendance_minimum_self_response_age')='number' and c->>'attendance_minimum_self_response_age'~'^[0-9]{2,3}$'
 and (c->>'attendance_minimum_self_response_age')::integer between 18 and 100 then (c->>'attendance_minimum_self_response_age')::integer end)
 from cfg cross join keys group by c
$$;
create function pg_temp.original_attendance_feature(p_org uuid,p_key text) returns boolean
language sql stable set search_path='' as $$
 select boss_private.calendar_module_enabled(p_org)
 and coalesce((boss_private.attendance_configuration(p_org)->>'attendance')::boolean,false)
 and p_key=any(array['attendance','rsvp','participant_self_response','guardian_rsvp','attendance_reminders','checkin','head_coach_management','assistant_coach_management'])
 and coalesce((boss_private.attendance_configuration(p_org)->>p_key)::boolean,false)
$$;
revoke all on function pg_temp.performance_id(text),pg_temp.performance_check(text,text,boolean),
 pg_temp.original_attendance_context(uuid,text),pg_temp.original_attendance_configuration(uuid),
 pg_temp.original_attendance_feature(uuid,text) from public;

select pg_temp.performance_check('local function counters enabled','HARNESS',current_setting('track_functions')='all');
insert into public.people(id,display_name) values(pg_temp.performance_id('actor'),'Synthetic performance regression actor');
insert into public.organizations(id,name,slug)
values(pg_temp.performance_id('organization'),'Synthetic performance regression tenant','synthetic-phase4b-performance-regression');
insert into public.organization_modules(id,organization_id,module_id,status,configuration,starts_at)
select pg_temp.performance_id('calendar-module'),pg_temp.performance_id('organization'),id,'active','{}',now()-interval '1 day'
from public.modules where key='calendar';
insert into public.events(id,organization_id,title,event_type_key,start_at,end_at,timezone,status,visibility,rsvp_mode,recurrence,created_by_person_id,updated_by_person_id)
values
 (pg_temp.performance_id('recurring'),pg_temp.performance_id('organization'),'Synthetic three-occurrence series','practice',
 '2030-01-01T18:00:00Z','2030-01-01T19:00:00Z','UTC','scheduled','private','required',
 '{"frequency":"daily","interval":1,"count":3}',pg_temp.performance_id('actor'),pg_temp.performance_id('actor')),
 (pg_temp.performance_id('single'),pg_temp.performance_id('organization'),'Synthetic retained single occurrence','practice',
 '2030-01-01T20:00:00Z','2030-01-01T21:00:00Z','UTC','scheduled','private','required',
 null,pg_temp.performance_id('actor'),pg_temp.performance_id('actor'));
insert into public.event_occurrence_exceptions(organization_id,event_id,occurrence_key,override_start_at,override_end_at,status,created_by_person_id,updated_by_person_id)
values
 (pg_temp.performance_id('organization'),pg_temp.performance_id('recurring'),'2030-01-02T18:00:00',
 '2030-03-03T20:00:00Z','2030-03-03T21:00:00Z','confirmed',pg_temp.performance_id('actor'),pg_temp.performance_id('actor')),
 (pg_temp.performance_id('organization'),pg_temp.performance_id('recurring'),'2030-01-03T18:00:00',
 null,null,'canceled',pg_temp.performance_id('actor'),pg_temp.performance_id('actor'));
-- A retained single key is a prior canonical response identity, not an arbitrary
-- timestamp alias. The current event's rescheduled start must still be resolved.
insert into public.attendance_responses(organization_id,event_id,occurrence_key,person_id,subject_kind,occurrence_mode,status,responder_person_id,context_fingerprint)
values(pg_temp.performance_id('organization'),pg_temp.performance_id('single'),'2030-01-01T18:00:00',
 pg_temp.performance_id('actor'),'staff','single','attending',pg_temp.performance_id('actor'),repeat('0',64));

select pg_temp.performance_check('scheduled occurrence unchanged','OCCURRENCE',
 (boss_private.attendance_occurrence(pg_temp.performance_id('recurring'),'2030-01-01T18:00:00')->>'start_at')::timestamptz='2030-01-01T18:00:00Z'::timestamptz);
select pg_temp.performance_check('scheduled fingerprint equals original expression','CONTEXT',
 boss_private.attendance_context(pg_temp.performance_id('recurring'),'2030-01-01T18:00:00')
 is not distinct from pg_temp.original_attendance_context(pg_temp.performance_id('recurring'),'2030-01-01T18:00:00'));
select pg_temp.performance_check('moved occurrence preserves canonical key and new start','OCCURRENCE',
 (select occurrence->>'occurrence_key'='2030-01-02T18:00:00'
 and (occurrence->>'start_at')::timestamptz='2030-03-03T20:00:00Z'::timestamptz
 from(select boss_private.attendance_occurrence(pg_temp.performance_id('recurring'),'2030-01-02T18:00:00') occurrence) resolved));
select pg_temp.performance_check('moved fingerprint equals original expression','CONTEXT',
 boss_private.attendance_context(pg_temp.performance_id('recurring'),'2030-01-02T18:00:00')
 is not distinct from pg_temp.original_attendance_context(pg_temp.performance_id('recurring'),'2030-01-02T18:00:00'));
select pg_temp.performance_check('canceled occurrence status preserved','OCCURRENCE',
 boss_private.attendance_occurrence(pg_temp.performance_id('recurring'),'2030-01-03T18:00:00')->>'status'='canceled');
select pg_temp.performance_check('canceled fingerprint equals original expression','CONTEXT',
 boss_private.attendance_context(pg_temp.performance_id('recurring'),'2030-01-03T18:00:00')
 is not distinct from pg_temp.original_attendance_context(pg_temp.performance_id('recurring'),'2030-01-03T18:00:00'));
select pg_temp.performance_check('invalid key cannot manufacture occurrence','OCCURRENCE',
 boss_private.attendance_occurrence(pg_temp.performance_id('recurring'),'not-an-occurrence') is null);
select pg_temp.performance_check('invalid-key fingerprint equals original expression','CONTEXT',
 boss_private.attendance_context(pg_temp.performance_id('recurring'),'not-an-occurrence')
 is not distinct from pg_temp.original_attendance_context(pg_temp.performance_id('recurring'),'not-an-occurrence'));
select pg_temp.performance_check('missing-event context remains null','CONTEXT',
 boss_private.attendance_context(pg_temp.performance_id('missing'),'2030-01-01T18:00:00') is null
 and pg_temp.original_attendance_context(pg_temp.performance_id('missing'),'2030-01-01T18:00:00') is null);
select pg_temp.performance_check('retained single key resolves current start','OCCURRENCE',
 (select occurrence->>'occurrence_key'='2030-01-01T18:00:00'
 and (occurrence->>'start_at')::timestamptz='2030-01-01T20:00:00Z'::timestamptz
 from(select boss_private.attendance_occurrence(pg_temp.performance_id('single'),'2030-01-01T18:00:00') occurrence) resolved));
select pg_temp.performance_check('retained single fingerprint equals original expression','CONTEXT',
 boss_private.attendance_context(pg_temp.performance_id('single'),'2030-01-01T18:00:00')
 is not distinct from pg_temp.original_attendance_context(pg_temp.performance_id('single'),'2030-01-01T18:00:00'));
create temp table phase4b_performance_context(fingerprint text) on commit drop;
insert into phase4b_performance_context values(boss_private.attendance_context(pg_temp.performance_id('recurring'),'2030-01-01T18:00:00'));
set local timezone='Pacific/Auckland';
select pg_temp.performance_check('fingerprint independent of session timezone','CONTEXT',
 (select fingerprint=boss_private.attendance_context(pg_temp.performance_id('recurring'),'2030-01-01T18:00:00') from phase4b_performance_context));
set local timezone='UTC';
select pg_temp.performance_check('attendance helpers remain private stable definers owned by migration role','PRIVILEGE',
 (select count(*)=3 and bool_and(p.provolatile='s' and p.prosecdef and p.proconfig @> array['search_path=""']
 and p.proowner=(select oid from pg_roles where rolname='postgres')
 and not has_function_privilege('anon',p.oid,'execute')
 and not has_function_privilege('authenticated',p.oid,'execute')
 and not has_function_privilege('service_role',p.oid,'execute'))
 from pg_proc p where p.oid=any(array['boss_private.attendance_context(uuid,text)'::regprocedure,
 'boss_private.attendance_configuration(uuid)'::regprocedure,'boss_private.attendance_feature(uuid,text)'::regprocedure])));

-- Exact JSONB projections and feature outcomes must match the old expressions.
-- Independently assert the age boundary/type rules, so equality cannot bless an
-- accidental common change to both configuration and feature implementations.
create temp table phase4b_performance_config_cases(label text primary key,configuration jsonb not null,minimum_age integer) on commit drop;
insert into phase4b_performance_config_cases values
 ('missing configuration flags and age','{}',18),
 ('all explicit boolean features','{"attendance":true,"attendance_rsvp":true,"attendance_participant_self_response":true,"attendance_guardian_rsvp":true,"attendance_reminders":true,"attendance_checkin":true,"attendance_head_coach_management":true,"attendance_assistant_coach_management":true,"attendance_minimum_self_response_age":18}',18),
 ('mixed invalid flag types','{"attendance":true,"attendance_rsvp":"true","attendance_guardian_rsvp":null,"attendance_checkin":1,"attendance_head_coach_management":false,"attendance_reminders":true,"attendance_minimum_self_response_age":"18"}',null),
 ('maximum allowed age','{"attendance":true,"attendance_rsvp":true,"attendance_minimum_self_response_age":100}',100),
 ('below minimum age','{"attendance":true,"attendance_rsvp":true,"attendance_minimum_self_response_age":17}',null),
 ('above maximum age','{"attendance":true,"attendance_rsvp":true,"attendance_minimum_self_response_age":101}',null),
 ('decimal age','{"attendance":true,"attendance_rsvp":true,"attendance_minimum_self_response_age":18.5}',null),
 ('explicit null age','{"attendance":true,"attendance_rsvp":true,"attendance_minimum_self_response_age":null}',null);
do $$declare config_case record;features_equal boolean;begin
 for config_case in select * from phase4b_performance_config_cases order by label loop
  update public.organization_modules set configuration=config_case.configuration where id=pg_temp.performance_id('calendar-module');
  perform pg_temp.performance_check(config_case.label||' projection','CONFIGURATION',
   boss_private.attendance_configuration(pg_temp.performance_id('organization'))
   is not distinct from pg_temp.original_attendance_configuration(pg_temp.performance_id('organization')));
  perform pg_temp.performance_check(config_case.label||' age rule','CONFIGURATION',
   (boss_private.attendance_configuration(pg_temp.performance_id('organization'))->>'minimum_self_response_age')::integer
   is not distinct from config_case.minimum_age);
  select bool_and(boss_private.attendance_feature(pg_temp.performance_id('organization'),feature)
   is not distinct from pg_temp.original_attendance_feature(pg_temp.performance_id('organization'),feature)) into features_equal
  from unnest(array['attendance','rsvp','participant_self_response','guardian_rsvp','attendance_reminders','checkin',
   'head_coach_management','assistant_coach_management','unknown',null]::text[]) feature;
  perform pg_temp.performance_check(config_case.label||' feature outcomes','FEATURE',features_equal);
 end loop;
end$$;
update public.organization_modules set configuration='{"attendance":true,"attendance_rsvp":true}' where id=pg_temp.performance_id('calendar-module');

create temp table phase4b_performance_lookup_snapshots(stage text primary key,calls bigint not null) on commit drop;
insert into phase4b_performance_lookup_snapshots select 'configuration-before',coalesce((select calls from pg_stat_xact_user_functions
 where funcid='boss_private.coordination_configuration(uuid,text)'::regprocedure),0);
do $$begin perform boss_private.attendance_configuration(pg_temp.performance_id('organization'));end$$;
insert into phase4b_performance_lookup_snapshots select 'configuration-after',coalesce((select calls from pg_stat_xact_user_functions
 where funcid='boss_private.coordination_configuration(uuid,text)'::regprocedure),0);
do $$declare call_delta bigint;begin
 select (select calls from phase4b_performance_lookup_snapshots where stage='configuration-after')
 -(select calls from phase4b_performance_lookup_snapshots where stage='configuration-before') into call_delta;
 if call_delta is distinct from 1 then
  raise exception 'FAIL [STRUCTURAL] one attendance configuration lookup: expected 1 call, observed %',call_delta;
 end if;
 perform pg_temp.performance_check('one attendance configuration resolves one module configuration','STRUCTURAL',true);
end$$;
insert into phase4b_performance_lookup_snapshots select 'feature-before',coalesce((select calls from pg_stat_xact_user_functions
 where funcid='boss_private.attendance_configuration(uuid)'::regprocedure),0);
select pg_temp.performance_check('enabled feature stays true','FEATURE',boss_private.attendance_feature(pg_temp.performance_id('organization'),'rsvp'));
insert into phase4b_performance_lookup_snapshots select 'feature-after',coalesce((select calls from pg_stat_xact_user_functions
 where funcid='boss_private.attendance_configuration(uuid)'::regprocedure),0);
do $$declare call_delta bigint;begin
 select (select calls from phase4b_performance_lookup_snapshots where stage='feature-after')
 -(select calls from phase4b_performance_lookup_snapshots where stage='feature-before') into call_delta;
 if call_delta is distinct from 1 then
  raise exception 'FAIL [STRUCTURAL] one enabled feature configuration lookup: expected 1 call, observed %',call_delta;
 end if;
 perform pg_temp.performance_check('one enabled feature resolves one attendance configuration','STRUCTURAL',true);
end$$;
update public.organization_modules set status='inactive' where id=pg_temp.performance_id('calendar-module');
insert into phase4b_performance_lookup_snapshots select 'inactive-before',coalesce((select calls from pg_stat_xact_user_functions
 where funcid='boss_private.attendance_configuration(uuid)'::regprocedure),0);
select pg_temp.performance_check('inactive module feature stays false','FEATURE',not boss_private.attendance_feature(pg_temp.performance_id('organization'),'rsvp'));
insert into phase4b_performance_lookup_snapshots select 'inactive-after',coalesce((select calls from pg_stat_xact_user_functions
 where funcid='boss_private.attendance_configuration(uuid)'::regprocedure),0);
select pg_temp.performance_check('inactive module avoids attendance configuration lookup','STRUCTURAL',
 (select calls from phase4b_performance_lookup_snapshots where stage='inactive-after')
 -(select calls from phase4b_performance_lookup_snapshots where stage='inactive-before')=0);
select pg_temp.performance_check('inactive feature equals original expression','FEATURE',
 boss_private.attendance_feature(pg_temp.performance_id('organization'),'rsvp')
 is not distinct from pg_temp.original_attendance_feature(pg_temp.performance_id('organization'),'rsvp'));

-- Counters accumulate in this backend even after earlier work/rollback. Measure
-- the difference around exactly one call; the original body produces delta 3.
create temp table phase4b_performance_counter_snapshots(stage text primary key,calls bigint not null) on commit drop;
insert into phase4b_performance_counter_snapshots
select 'before',coalesce((select calls from pg_stat_xact_user_functions
 where funcid='boss_private.attendance_occurrence(uuid,text)'::regprocedure),0);
do $$begin
 perform boss_private.attendance_context(pg_temp.performance_id('recurring'),'2030-01-01T18:00:00');
end$$;
insert into phase4b_performance_counter_snapshots
select 'after',coalesce((select calls from pg_stat_xact_user_functions
 where funcid='boss_private.attendance_occurrence(uuid,text)'::regprocedure),0);
do $$declare call_delta bigint;begin
 select (select calls from phase4b_performance_counter_snapshots where stage='after')
 -(select calls from phase4b_performance_counter_snapshots where stage='before') into call_delta;
 if call_delta is distinct from 1 then
  raise exception 'FAIL [STRUCTURAL] one context resolves one occurrence: expected 1 call, observed %',call_delta;
 end if;
 perform pg_temp.performance_check('one context resolves one occurrence','STRUCTURAL',true);
end$$;

-- The resolved helper only fingerprints trusted inputs; it never resolves an
-- occurrence or supplies authority. Compare canonical and null-occurrence cases
-- directly to the immutable old expression kept in pg_temp.
create temp table phase4b_performance_resolved_cases(label text primary key,event_id uuid not null,occurrence_key text) on commit drop;
insert into phase4b_performance_resolved_cases values
 ('scheduled',pg_temp.performance_id('recurring'),'2030-01-01T18:00:00'),
 ('moved',pg_temp.performance_id('recurring'),'2030-01-02T18:00:00'),
 ('canceled',pg_temp.performance_id('recurring'),'2030-01-03T18:00:00'),
 ('invalid',pg_temp.performance_id('recurring'),'not-an-occurrence'),
 ('retained single',pg_temp.performance_id('single'),'2030-01-01T18:00:00'),
 ('null key',pg_temp.performance_id('recurring'),null);
do $$declare resolved_case record;event_row public.events;resolved_occurrence jsonb;begin
 for resolved_case in select * from phase4b_performance_resolved_cases order by label loop
  select * into event_row from public.events where id=resolved_case.event_id;
  resolved_occurrence:=boss_private.attendance_occurrence(resolved_case.event_id,resolved_case.occurrence_key);
  perform pg_temp.performance_check(resolved_case.label||' resolved fingerprint equals original expression','RESOLVED_CONTEXT',
   boss_private.attendance_resolved_context(event_row,resolved_case.occurrence_key,resolved_occurrence)
   is not distinct from pg_temp.original_attendance_context(resolved_case.event_id,resolved_case.occurrence_key));
 end loop;
end$$;
select pg_temp.performance_check('resolved helper is private stable invoker with empty search path','PRIVILEGE',
 (select p.provolatile='s' and not p.prosecdef and p.proconfig @> array['search_path=""']
 and p.proowner=(select oid from pg_roles where rolname='postgres')
 and not has_function_privilege('anon',p.oid,'execute')
 and not has_function_privilege('authenticated',p.oid,'execute')
 and not has_function_privilege('service_role',p.oid,'execute')
 from pg_proc p where p.oid='boss_private.attendance_resolved_context(public.events,text,jsonb)'::regprocedure));

-- Minimal synthetic source receipt: the actor is current staff and responds for
-- self. Local Auth identifiers only satisfy notification_person_active; there
-- are no passwords, tokens, sessions, guardian/household flags or role grants.
insert into auth.users(id,email,email_confirmed_at)
values(pg_temp.performance_id('synthetic-auth'),'performance-regression@phase4b.example.invalid',now()-interval '1 day');
insert into public.user_accounts(person_id,auth_user_id,account_status)
values(pg_temp.performance_id('actor'),pg_temp.performance_id('synthetic-auth'),'active');
insert into public.teams(id,organization_id,name,slug,status)
values(pg_temp.performance_id('staff-team'),pg_temp.performance_id('organization'),'Synthetic performance staff team','synthetic-performance-staff','active');
insert into public.team_memberships(organization_id,team_id,person_id,membership_type,starts_at,created_at)
values(pg_temp.performance_id('organization'),pg_temp.performance_id('staff-team'),pg_temp.performance_id('actor'),
 'staff',now()-interval '1 day',now()-interval '1 day');
insert into public.event_targets(event_id,organization_id,target_type,target_id)
values(pg_temp.performance_id('recurring'),pg_temp.performance_id('organization'),'team',pg_temp.performance_id('staff-team'));
update public.organization_modules set status='active',configuration='{"attendance":true,"attendance_rsvp":true,"attendance_reminders":true}'
where id=pg_temp.performance_id('calendar-module');
insert into public.attendance_requests(id,organization_id,event_id,occurrence_key,kind,context_fingerprint,revision)
values
 (pg_temp.performance_id('visible-request'),pg_temp.performance_id('organization'),pg_temp.performance_id('recurring'),
 '2030-01-01T18:00:00','requested',boss_private.attendance_context(pg_temp.performance_id('recurring'),'2030-01-01T18:00:00'),'synthetic-visible'),
 (pg_temp.performance_id('canceled-request'),pg_temp.performance_id('organization'),pg_temp.performance_id('recurring'),
 '2030-01-03T18:00:00','requested',boss_private.attendance_context(pg_temp.performance_id('recurring'),'2030-01-03T18:00:00'),'synthetic-canceled'),
 (pg_temp.performance_id('mismatched-request'),pg_temp.performance_id('organization'),pg_temp.performance_id('recurring'),
 '2030-01-01T18:00:00','requested',repeat('0',64),'synthetic-mismatched');
insert into phase4b_performance_counter_snapshots select 'visible-before',coalesce((select calls from pg_stat_xact_user_functions
 where funcid='boss_private.attendance_occurrence(uuid,text)'::regprocedure),0);
select pg_temp.performance_check('current staff requested notification remains visible','SOURCE_VISIBILITY',
 boss_private.attendance_notification_visible(pg_temp.performance_id('visible-request'),pg_temp.performance_id('actor'),now()));
insert into phase4b_performance_counter_snapshots select 'visible-after',coalesce((select calls from pg_stat_xact_user_functions
 where funcid='boss_private.attendance_occurrence(uuid,text)'::regprocedure),0);
do $$declare call_delta bigint;begin
 select (select calls from phase4b_performance_counter_snapshots where stage='visible-after')
 -(select calls from phase4b_performance_counter_snapshots where stage='visible-before') into call_delta;
 if call_delta is distinct from 1 then
  raise exception 'FAIL [STRUCTURAL] one visible notification source resolves one occurrence: expected 1 call, observed %',call_delta;
 end if;
 perform pg_temp.performance_check('one visible source resolves one occurrence','STRUCTURAL',true);
end$$;
select pg_temp.performance_check('canceled requested source remains hidden','SOURCE_VISIBILITY',
 not boss_private.attendance_notification_visible(pg_temp.performance_id('canceled-request'),pg_temp.performance_id('actor'),now()));
select pg_temp.performance_check('mismatched source fingerprint remains hidden','SOURCE_VISIBILITY',
 not boss_private.attendance_notification_visible(pg_temp.performance_id('mismatched-request'),pg_temp.performance_id('actor'),now()));

select (select count(*) from phase4b_performance_assertions) as passed_assertions,
 jsonb_object_agg(category,total order by category) as coverage
from (select category,count(*) total from phase4b_performance_assertions group by category) summary;
rollback;
