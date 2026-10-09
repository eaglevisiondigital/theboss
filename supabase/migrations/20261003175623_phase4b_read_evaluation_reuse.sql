-- Request-local reuse for runtime-proven repeated SQL expression evaluation.
-- Context: three flattened occurrence dereferences become one canonical lookup.
-- Configuration: sixteen identical module lookups become one per normalization.
-- Feature: two normalized configuration calls become one, after module gating.
-- Notification visibility: the canonical occurrence already held by the caller
-- supplies its identical fingerprint, eliminating the second occurrence lookup.
-- All original fields, predicates, hashing, recurrence resolution and current
-- authority remain unchanged. Nothing persists between requests or revocation.
-- CREATE OR REPLACE preserves existing ownership, privileges and interfaces.
-- No timeout, RLS, role, module, event, relationship or index change is made.

-- Accept only canonical rows/occurrences from internal caller resolution.
-- This pure fingerprint helper cannot supply authorization or resolve a key.
create function boss_private.attendance_resolved_context(p_event public.events,p_key text,p_occurrence jsonb) returns text
language sql stable security invoker set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object(
  'occurrence_key',p_key,'start_epoch',extract(epoch from (p_occurrence->>'start_at')::timestamptz),
  'end_epoch',extract(epoch from (p_occurrence->>'end_at')::timestamptz),'status',p_occurrence->>'status',
  'timezone',(p_event).timezone,'recurrence',(p_event).recurrence,
  'venue_id',(p_event).venue_id,'resource_id',(p_event).resource_id
 )::text,'UTF8')),'hex')
$$;
revoke all on function boss_private.attendance_resolved_context(public.events,text,jsonb) from public,anon,authenticated,service_role;

create or replace function boss_private.attendance_context(p_event uuid,p_key text) returns text
language sql stable security definer set search_path='' as $$
 with current_occurrence as materialized (
  select e event,boss_private.attendance_occurrence(e.id,p_key) occurrence
  from public.events e where e.id=p_event
 )
 select boss_private.attendance_resolved_context(event,p_key,occurrence) from current_occurrence
$$;

create or replace function boss_private.attendance_configuration(p_org uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 with cfg as materialized (select boss_private.coordination_configuration(p_org,'calendar') as c),
 keys as (select unnest(array['attendance','rsvp','participant_self_response','guardian_rsvp','attendance_reminders','checkin','head_coach_management','assistant_coach_management']) as k)
 select jsonb_object_agg(k,case when jsonb_typeof(c->boss_private.attendance_storage_key(k))='boolean' then c->boss_private.attendance_storage_key(k) else 'false'::jsonb end)
 || jsonb_build_object('minimum_self_response_age',case when not c?'attendance_minimum_self_response_age' then 18
 when jsonb_typeof(c->'attendance_minimum_self_response_age')='number' and c->>'attendance_minimum_self_response_age'~'^[0-9]{2,3}$'
 and (c->>'attendance_minimum_self_response_age')::integer between 18 and 100 then (c->>'attendance_minimum_self_response_age')::integer end)
 from cfg cross join keys group by c
$$;

create or replace function boss_private.attendance_feature(p_org uuid,p_key text) returns boolean
language sql stable security definer set search_path='' as $$
 with cfg as materialized (
  select boss_private.attendance_configuration(p_org) configuration
  where boss_private.calendar_module_enabled(p_org)
 )
 select coalesce((select
  coalesce((configuration->>'attendance')::boolean,false)
  and p_key=any(array['attendance','rsvp','participant_self_response','guardian_rsvp','attendance_reminders','checkin','head_coach_management','assistant_coach_management'])
  and coalesce((configuration->>p_key)::boolean,false)
 from cfg),false)
$$;

-- Visibility reuses its already-resolved occurrence for the identical fingerprint.
-- Current/source-date roster, guardian, feature, response and status checks remain.
create or replace function boss_private.attendance_notification_visible(p_source uuid,p_person uuid,p_at timestamptz) returns boolean
language plpgsql stable security definer set search_path='' as $$declare source public.attendance_requests;occ jsonb;context_event public.events;subject record;r public.attendance_responses;begin
 select * into source from public.attendance_requests where id=p_source;if not found or not boss_private.notification_person_active(p_person)
 or not boss_private.attendance_feature(source.organization_id,'attendance_reminders') then return false;end if;
 occ:=boss_private.attendance_occurrence(source.event_id,source.occurrence_key);
 if occ is null then return false;end if;
 select * into context_event from public.events where id=source.event_id;
 if source.context_fingerprint<>boss_private.attendance_resolved_context(context_event,source.occurrence_key,occ)
 or (source.kind<>'context_changed' and (occ->>'status' not in ('scheduled','confirmed') or (occ->>'end_at')::timestamptz<=now())) then return false;end if;
 for subject in select * from boss_private.attendance_subjects(source.event_id,least(source.created_at,p_at)) loop
 if not (p_person=subject.person_id or boss_private.attendance_guardian(p_person,subject.person_id,least(source.created_at,p_at)) is not null)
 or not boss_private.attendance_subject_authority(p_person,source.event_id,subject.person_id,subject.participant_id,subject.subject_kind,'respond',least(source.created_at,p_at)) then continue;end if;
 select * into r from public.attendance_responses where event_id=source.event_id and occurrence_key=source.occurrence_key and person_id=subject.person_id and subject_kind=subject.subject_kind;
 if source.kind='context_changed' then if r.id is not null then return true;end if;
 elsif source.kind='requested' then return true;
 elsif r.id is null or r.status in ('pending','unknown') or r.needs_reconfirmation then return true;end if;
 end loop;return false;
end $$;
