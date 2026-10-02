-- Phase 4B controls use existing Calendar and Volunteers activation periods.
-- Availability never supplies permission, scope or guardian authority.
insert into public.permissions(key,name,description) values
 ('attendance.view','View scoped attendance','Current exact event/team/unit attendance projection'),
 ('attendance.respond','Respond to attendance','Own or explicitly authorized dependent RSVP'),
 ('attendance.manage','Manage scoped attendance','Manage attendance only in current exact event scope'),
 ('attendance.checkin','Record scoped check-in','Light staff check-in with current exact scope'),
 ('volunteers.view','View scoped volunteers','Current exact volunteer opportunity projection'),
 ('volunteers.signup','Sign up as volunteer','Own eligible volunteer commitment'),
 ('volunteers.manage','Manage scoped volunteer needs','Configure roles and shifts in current exact scope'),
 ('volunteers.assign','Assign scoped volunteers','Assign eligible people within current exact scope');
with mappings(role_key,permission_keys) as (values
 ('super_administrator',array['attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign']),
 ('platform_administrator',array['attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign']),
 ('organization_owner',array['attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign']),
 ('organization_administrator',array['attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign']),
 ('athletic_director',array['attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign']),
 ('program_administrator',array['attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign']),
 ('sport_administrator',array['attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign']),
 ('head_coach',array['attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage']),
 ('assistant_coach',array['attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup']),
 ('team_administrator',array['attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign']),
 ('team_staff',array['attendance.view','attendance.respond','volunteers.view','volunteers.signup']),
 ('volunteer_coordinator',array['attendance.view','attendance.respond','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign'])
)
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from mappings m join public.roles r on r.key=m.role_key join public.permissions p on p.key=any(m.permission_keys);

create function boss_private.attendance_storage_key(p_key text) returns text
language sql immutable security definer set search_path='' as $$
 select case p_key when 'attendance' then 'attendance' when 'rsvp' then 'attendance_rsvp'
 when 'participant_self_response' then 'attendance_participant_self_response'
 when 'guardian_rsvp' then 'attendance_guardian_rsvp' when 'attendance_reminders' then 'attendance_reminders'
 when 'checkin' then 'attendance_checkin' when 'head_coach_management' then 'attendance_head_coach_management'
 when 'assistant_coach_management' then 'attendance_assistant_coach_management'
 when 'minimum_self_response_age' then 'attendance_minimum_self_response_age' end
$$;
create function boss_private.coordination_configuration(p_org uuid,p_module text) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce((select om.configuration from public.organization_modules om
 join public.modules m on m.id=om.module_id join public.organizations o on o.id=om.organization_id
 where om.organization_id=p_org and o.status='active' and m.key=p_module and m.status='active'
 and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now())
 order by om.starts_at desc,om.id desc limit 1),'{}'::jsonb)
$$;
create function boss_private.attendance_configuration(p_org uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 with cfg as (select boss_private.coordination_configuration(p_org,'calendar') as c),
 keys as (select unnest(array['attendance','rsvp','participant_self_response','guardian_rsvp','attendance_reminders','checkin','head_coach_management','assistant_coach_management']) as k)
 select jsonb_object_agg(k,case when jsonb_typeof(c->boss_private.attendance_storage_key(k))='boolean' then c->boss_private.attendance_storage_key(k) else 'false'::jsonb end)
 || jsonb_build_object('minimum_self_response_age',case when not c?'attendance_minimum_self_response_age' then 18
 when jsonb_typeof(c->'attendance_minimum_self_response_age')='number' and c->>'attendance_minimum_self_response_age'~'^[0-9]{2,3}$'
 and (c->>'attendance_minimum_self_response_age')::integer between 18 and 100 then (c->>'attendance_minimum_self_response_age')::integer end)
 from cfg cross join keys group by c
$$;
create function boss_private.attendance_feature(p_org uuid,p_key text) returns boolean
language sql stable security definer set search_path='' as $$
 select boss_private.calendar_module_enabled(p_org)
 and coalesce((boss_private.attendance_configuration(p_org)->>'attendance')::boolean,false)
 and p_key=any(array['attendance','rsvp','participant_self_response','guardian_rsvp','attendance_reminders','checkin','head_coach_management','assistant_coach_management'])
 and coalesce((boss_private.attendance_configuration(p_org)->>p_key)::boolean,false)
$$;
create function boss_private.volunteer_configuration(p_org uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 with cfg as (select boss_private.coordination_configuration(p_org,'volunteers') as c),
 keys as (select unnest(array['volunteers','self_signup','reminders','head_coach_management','assistant_management']) as k)
 select jsonb_object_agg(k,case when jsonb_typeof(c->k)='boolean' then c->k else 'false'::jsonb end)
 || jsonb_build_object('minimum_signup_age',case when not c?'minimum_signup_age' then 18
 when jsonb_typeof(c->'minimum_signup_age')='number' and c->>'minimum_signup_age'~'^[0-9]{2,3}$'
 and (c->>'minimum_signup_age')::integer between 18 and 100 then (c->>'minimum_signup_age')::integer end)
 from cfg cross join keys group by c
$$;
create function boss_private.volunteer_feature(p_org uuid,p_key text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organizations o join public.organization_modules om on om.organization_id=o.id join public.modules m on m.id=om.module_id
 where o.id=p_org and o.status='active' and m.key='volunteers' and m.status='active' and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()))
 and coalesce((boss_private.volunteer_configuration(p_org)->>'volunteers')::boolean,false)
 and p_key=any(array['volunteers','self_signup','reminders','head_coach_management','assistant_management'])
 and coalesce((boss_private.volunteer_configuration(p_org)->>p_key)::boolean,false)
$$;
create function boss_private.volunteer_minimum_age(p_org uuid) returns integer
language sql stable security definer set search_path='' as $$
 select (boss_private.volunteer_configuration(p_org)->>'minimum_signup_age')::integer
$$;
revoke all on function boss_private.attendance_storage_key(text),boss_private.coordination_configuration(uuid,text),
 boss_private.attendance_configuration(uuid),boss_private.attendance_feature(uuid,text),
 boss_private.volunteer_configuration(uuid),boss_private.volunteer_feature(uuid,text),boss_private.volunteer_minimum_age(uuid)
 from public,anon,authenticated,service_role;
