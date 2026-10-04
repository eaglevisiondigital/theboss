-- Avoid Calendar occurrence expansion when no relative deadline is configured.
-- Fixed/offset deadline behavior, authorization, scope and feature policy are
-- unchanged. Prior Phase 4B migrations remain immutable.
create or replace function boss_private.attendance_deadline(p_event uuid,p_key text)
returns timestamptz language sql stable security definer set search_path='' as $$
 select case
  when settings.response_deadline_at is not null then settings.response_deadline_at
  when settings.deadline_offset_minutes is null then null::timestamptz
  else (boss_private.attendance_occurrence(e.id,p_key)->>'start_at')::timestamptz
   -make_interval(mins=>settings.deadline_offset_minutes)
 end
 from public.events e left join public.event_attendance_settings settings on settings.event_id=e.id
 where e.id=p_event
$$;
revoke all on function boss_private.attendance_deadline(uuid,text)
 from public,anon,authenticated,service_role;
