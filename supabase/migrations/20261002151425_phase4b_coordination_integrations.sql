-- Phase 4B extends the existing Phase 4A source pipeline. Raw tables stay
-- closed. No new delivery provider, global subscriber list, or credential exists.
alter table boss_private.notification_types drop constraint notification_types_category_check;
alter table boss_private.notification_types add constraint notification_types_category_check
 check(category in ('events','registration','fees','communications','security','attendance','volunteers'));
alter table public.notification_preferences drop constraint notification_preferences_category_check;
alter table public.notification_preferences add constraint notification_preferences_category_check
 check(category in ('events','registration','fees','communications','security','attendance','volunteers'));
alter table public.notification_events drop constraint notification_events_source_module_check;
alter table public.notification_events add constraint notification_events_source_module_check
 check(source_module in ('calendar','registration','messaging','volunteers'));
alter table public.notification_events drop constraint notification_events_source_type_check;
alter table public.notification_events add constraint notification_events_source_type_check
 check(source_type in ('event','registration','registration_document','charge','payment','message','attendance_request','volunteer_shift','volunteer_assignment','volunteer_event'));
insert into boss_private.notification_types(key,category,source_module,title,body) values
 ('attendance.requested','attendance','calendar','RSVP requested','Review the attendance request for an upcoming event.'),
 ('attendance.deadline','attendance','calendar','RSVP deadline approaching','An attendance response is due soon.'),
 ('attendance.no_response','attendance','calendar','Attendance response needed','An event still needs an attendance response.'),
 ('attendance.context_changed','attendance','calendar','Review your RSVP','An event changed. Review your attendance response.'),
 ('volunteer.confirmed','volunteers','volunteers','Volunteer signup confirmed','Review your volunteer commitment in Boss.'),
 ('volunteer.reminder','volunteers','volunteers','Volunteer shift reminder','An upcoming volunteer commitment is ready to review.'),
 ('volunteer.changed','volunteers','volunteers','Volunteer shift changed','Review the current details of your volunteer commitment.'),
 ('volunteer.canceled','volunteers','volunteers','Volunteer shift canceled','A volunteer shift was canceled. Review your commitments.'),
 ('volunteer.cancellation','volunteers','volunteers','Volunteer cancellation','A volunteer commitment was canceled. Review the shift.');

-- A selected-shift announcement is a normal private announcement with an extra
-- current audience predicate, rather than an organization/team-wide audience.
alter table public.communication_audiences add column volunteer_shift_id uuid;
alter table public.communication_audiences add constraint communication_audiences_volunteer_shift_fkey
 foreign key(organization_id,volunteer_shift_id) references public.volunteer_shifts(organization_id,id) on delete restrict;
alter table public.communication_audiences add constraint communication_audiences_volunteer_role_check
 check(volunteer_shift_id is null or role_id is null);
create index communication_audiences_volunteer_shift_idx on public.communication_audiences(organization_id,volunteer_shift_id);

-- Source-dated eligibility prevents relationships created after a queued event
-- from becoming historical recipients. Current relationship checks also apply.
create function boss_private.volunteer_context_at(p_person uuid,p_org uuid,p_type text,p_scope uuid,p_at timestamptz) returns boolean
language sql stable security definer set search_path='' as $$
 select boss_private.volunteer_person_eligible(p_person,p_org,p_type,p_scope) and (
 exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id and t.organization_id=m.organization_id and t.status='active'
 where m.organization_id=p_org and m.status='active' and m.created_at<=least(now(),p_at) and m.starts_at<=least(now(),p_at) and(m.ends_at is null or m.ends_at>now())
 and(p_type='organization' or(p_type='unit' and t.parent_unit_id=p_scope) or(p_type='team' and t.id=p_scope))
 and(m.person_id=p_person or exists(select 1 from public.guardian_relationships g where g.guardian_person_id=p_person and g.dependent_person_id=m.person_id
 and boss_private.volunteer_guardian(p_person,m.person_id) and g.created_at<=least(now(),p_at) and g.verified_at<=least(now(),p_at) and g.starts_at<=least(now(),p_at))))
 or(p_type='organization' and p_scope=p_org and exists(select 1 from public.organization_memberships m where m.organization_id=p_org and m.status='active'
 and m.created_at<=least(now(),p_at) and m.starts_at<=least(now(),p_at) and(m.ends_at is null or m.ends_at>now())
 and(m.person_id=p_person or exists(select 1 from public.guardian_relationships g where g.guardian_person_id=p_person and g.dependent_person_id=m.person_id
 and boss_private.volunteer_guardian(p_person,m.person_id) and g.created_at<=least(now(),p_at) and g.verified_at<=least(now(),p_at) and g.starts_at<=least(now(),p_at))))))
$$;
create function boss_private.volunteer_coordinator_at(p_shift uuid,p_person uuid,p_at timestamptz) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.volunteer_coordinator(s.id,p_person) and exists(
 select 1 from public.role_assignments a join public.roles role on role.id=a.role_id join public.role_permissions rp on rp.role_id=a.role_id join public.permissions permission on permission.id=rp.permission_id
 where a.person_id=p_person and a.organization_id=s.organization_id and a.status='active' and role.status='active' and permission.status='active' and permission.key='volunteers.manage'
 and a.created_at<=least(now(),p_at) and a.starts_at<=least(now(),p_at) and(a.ends_at is null or a.ends_at>now())
 and(role.key<>'head_coach' or boss_private.volunteer_feature(s.organization_id,'head_coach_management'))
 and((a.scope_type='organization' and a.scope_id=s.organization_id)
 or(a.scope_type='organization_unit' and a.scope_id=case when s.scope_type='unit' then s.scope_id when s.scope_type='team' then(select parent_unit_id from public.teams where id=s.scope_id)end)
 or(a.scope_type='team' and s.scope_type='team' and a.scope_id=s.scope_id and exists(select 1 from public.team_memberships m where m.team_id=s.scope_id and m.person_id=p_person and m.status='active'
 and m.created_at<=least(now(),p_at) and m.starts_at<=least(now(),p_at) and(m.ends_at is null or m.ends_at>now())))))
 from public.volunteer_shifts s where s.id=p_shift),false)
$$;


create function boss_private.comm_audience_person_phase4a(p_audience uuid,p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select (boss_private.comm_context_related(p_person,a.organization_id,a.scope_type,a.scope_id) or boss_private.comm_permission(p_person,'communications.view',a.organization_id,a.scope_type,a.scope_id)) and (a.role_id is null or exists(
 select 1 from public.role_assignments r join public.roles role on role.id=r.role_id where r.person_id=p_person and r.role_id=a.role_id and role.status='active' and r.status='active'
 and r.starts_at<=now() and (r.ends_at is null or r.ends_at>now()) and r.organization_id=a.organization_id and
 ((a.scope_type='organization' and r.scope_type='organization' and r.scope_id=a.scope_id) or (a.scope_type='unit' and r.scope_type='organization_unit' and r.scope_id=a.scope_id) or (a.scope_type='team' and r.scope_type='team' and r.scope_id=a.scope_id))))
 from public.communication_audiences a where a.id=p_audience),false) $$;

create function boss_private.notification_source_visible_phase4a(p_event public.notification_events,p_person uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$ declare v_registration uuid;v_rec boolean;calendar_event public.events;reminder public.event_reminders;begin
 if not boss_private.notification_person_active(p_person) or not boss_private.comm_feature(p_event.organization_id,'in_app_notifications') or p_event.status='canceled' then return false;end if;
 if p_event.source_type='event' then
  if p_event.event_type='event.reminder' then
   select * into calendar_event from public.events where id=p_event.source_id and organization_id=p_event.organization_id and status in ('scheduled','confirmed');if not found then return false;end if;
   select * into reminder from public.event_reminders where id=(p_event.safe_data->>'reminder_id')::uuid and event_id=calendar_event.id and organization_id=p_event.organization_id and enabled;if not found then return false;end if;
   if not exists(select 1 from boss_private.calendar_occurrences(calendar_event,p_event.scheduled_at-interval '1 day',p_event.scheduled_at+interval '8 days') occurrence
    where occurrence.occurrence_key=p_event.safe_data->>'occurrence_key' and occurrence.status in ('scheduled','confirmed') and occurrence.start_at-make_interval(mins=>reminder.minutes_before)=p_event.scheduled_at) then return false;end if;
   if not (reminder.audience&&array['organization','unit','team']::text[]
    or ('staff'=any(reminder.audience) and exists(select 1 from public.event_targets t where t.event_id=calendar_event.id and boss_private.notification_permission_at(p_person,'events.view',p_event.organization_id,t.target_type,t.target_id,p_event.occurred_at)))
    or ('coaches'=any(reminder.audience) and exists(select 1 from public.team_memberships tm join public.event_targets t on t.event_id=calendar_event.id where tm.person_id=p_person and tm.organization_id=p_event.organization_id and tm.status='active' and tm.membership_type in ('coach','head_coach','assistant_coach') and tm.created_at<=p_event.occurred_at and tm.starts_at<=p_event.occurred_at and (tm.ends_at is null or tm.ends_at>now())
     and (t.target_type='organization' or (t.target_type='team' and t.target_id=tm.team_id) or (t.target_type='unit' and exists(select 1 from public.teams team where team.id=tm.team_id and team.parent_unit_id=t.target_id)))))
    or ('participants'=any(reminder.audience) and exists(select 1 from public.participants a where a.person_id=p_person and a.status='active') and boss_private.comm_participant_allowed(p_person,p_event.organization_id)
      and exists(select 1 from public.event_targets t where t.event_id=calendar_event.id and boss_private.notification_context_at(p_person,p_event.organization_id,t.target_type,t.target_id,p_event.occurred_at)))
    or ('guardians'=any(reminder.audience) and exists(select 1 from public.guardian_relationships g where g.guardian_person_id=p_person and boss_private.notification_guardian(p_person,g.dependent_person_id,'can_receive_communications',p_event.occurred_at)
      and exists(select 1 from public.team_memberships tm join public.teams team on team.id=tm.team_id and team.status='active' join public.event_targets t on t.event_id=calendar_event.id
      where tm.person_id=g.dependent_person_id and tm.organization_id=p_event.organization_id and tm.status='active' and tm.created_at<=p_event.occurred_at and tm.starts_at<=p_event.occurred_at and (tm.ends_at is null or tm.ends_at>now())
      and (t.target_type='organization' or (t.target_type='unit' and team.parent_unit_id=t.target_id) or (t.target_type='team' and team.id=t.target_id)))))) then return false;end if;
  end if;
  return exists(select 1 from public.events e where e.id=p_event.source_id and e.organization_id=p_event.organization_id) and boss_private.notification_event_visible(p_event.source_id,p_person,p_event.occurred_at);
 elsif p_event.source_type='message' then
  return exists(select 1 from public.communication_messages m join public.communication_threads t on t.id=m.thread_id where m.id=p_event.source_id and m.organization_id=p_event.organization_id and m.status='visible' and m.author_person_id<>p_person
   and case when t.kind in ('direct','group','family') then exists(select 1 from public.communication_thread_members member where member.thread_id=t.id and member.person_id=p_person and member.status='active' and member.created_at<=p_event.occurred_at and member.starts_at<=p_event.occurred_at and (member.ends_at is null or member.ends_at>now()))
   when t.kind='announcement' then exists(select 1 from public.communication_audiences audience where audience.thread_id=t.id and boss_private.comm_audience_person(audience.id,p_person)
   and boss_private.notification_context_at(p_person,t.organization_id,audience.scope_type,audience.scope_id,p_event.occurred_at)
   and (audience.role_id is null or exists(select 1 from public.role_assignments a where a.person_id=p_person and a.role_id=audience.role_id and a.organization_id=t.organization_id and a.status='active' and a.created_at<=p_event.occurred_at and a.starts_at<=p_event.occurred_at and (a.ends_at is null or a.ends_at>now()))))
   else boss_private.notification_context_at(p_person,t.organization_id,t.scope_type,t.scope_id,p_event.occurred_at)
   or boss_private.notification_permission_at(p_person,case when t.kind in ('team_chat','coach_staff') then 'team_chat.view' else 'communications.view' end,t.organization_id,t.scope_type,t.scope_id,p_event.occurred_at) end)
   and boss_private.comm_message_can_view(p_event.source_id,p_person);
 elsif p_event.source_type='registration' then
  v_registration:=p_event.source_id;
 elsif p_event.source_type='registration_document' then
  select d.registration_id into v_registration from public.registration_documents d where d.id=p_event.source_id and d.organization_id=p_event.organization_id;
 elsif p_event.source_type='charge' then
  select c.registration_id into v_registration from public.charges c where c.id=p_event.source_id and c.organization_id=p_event.organization_id and c.status='active';
  if p_event.event_type like 'fee.%' and not exists(select 1 from public.charges c where c.id=p_event.source_id and c.organization_id=p_event.organization_id and c.status='active'
   and (boss_private.registration_charge_balance(c.id)->>'balance_due_minor')::bigint>0
   and (p_event.event_type not in ('fee.upcoming','fee.overdue') or (c.due_on is not null and case when p_event.event_type='fee.overdue' then c.due_on<current_date else c.due_on>=current_date and c.due_on<=current_date+32 end))) then return false;end if;
 elsif p_event.source_type='payment' then
  return exists(select 1 from public.payments payment join public.payment_allocations allocation on allocation.payment_id=payment.id and allocation.organization_id=payment.organization_id
   join public.charges charge on charge.id=allocation.charge_id and charge.organization_id=allocation.organization_id
   where payment.id=p_event.source_id and payment.organization_id=p_event.organization_id and payment.status='recorded'
   and boss_private.notification_registration_visible(charge.registration_id,p_person,true,p_event.occurred_at));
 else return false;end if;
 if p_event.event_type='registration.missing_requirement' and not exists(select 1 from public.registrations r where r.id=v_registration and r.status in ('draft','submitted','under_review')
  and (r.document_status in ('missing','rejected','expired') or r.form_status in ('not_started','draft') or r.waiver_status in ('missing','partially_signed'))) then return false;end if;
 if p_event.event_type='registration.deadline' and not exists(select 1 from public.registrations r join public.registration_offerings o on o.id=r.offering_id where r.id=v_registration and r.status='draft' and o.status='published' and o.closes_at>now() and o.closes_at<=now()+interval '32 days') then return false;end if;
 return exists(select 1 from public.registrations r where r.id=v_registration and r.organization_id=p_event.organization_id)
  and boss_private.notification_registration_visible(v_registration,p_person,p_event.event_type like 'fee.%',p_event.occurred_at);
end $$;

create function boss_private.notification_contexts_phase4a(p_event public.notification_events,p_person uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_array(jsonb_build_object('source_type',p_event.source_type,'source_id',p_event.source_id))||coalesce((
 select jsonb_agg(jsonb_build_object('team_id',context.team_id,'reason','team_relationship_or_scope') order by context.team_id) from (
 select target.target_id team_id from public.event_targets target where p_event.source_type='event' and target.event_id=p_event.source_id and target.target_type='team'
 and (boss_private.notification_context_at(p_person,p_event.organization_id,'team',target.target_id,p_event.occurred_at)
 or boss_private.notification_permission_at(p_person,'events.view',p_event.organization_id,'team',target.target_id,p_event.occurred_at))
 union select t.scope_id from public.communication_messages m join public.communication_threads t on t.id=m.thread_id where p_event.source_type='message' and m.id=p_event.source_id and t.scope_type='team' and boss_private.comm_message_can_view(m.id,p_person)
 union select audience.scope_id from public.communication_messages m join public.communication_audiences audience on audience.thread_id=m.thread_id where p_event.source_type='message' and m.id=p_event.source_id and audience.scope_type='team' and boss_private.comm_audience_person(audience.id,p_person)
 union select offering.scope_id from public.registrations r join public.registration_offerings offering on offering.id=r.offering_id where p_event.source_type='registration' and r.id=p_event.source_id and offering.scope_type='team'
 union select offering.scope_id from public.registration_documents d join public.registrations r on r.id=d.registration_id join public.registration_offerings offering on offering.id=r.offering_id where p_event.source_type='registration_document' and d.id=p_event.source_id and offering.scope_type='team'
 union select offering.scope_id from public.charges charge join public.registrations r on r.id=charge.registration_id join public.registration_offerings offering on offering.id=r.offering_id where p_event.source_type='charge' and charge.id=p_event.source_id and offering.scope_type='team'
 union select offering.scope_id from public.payment_allocations allocation join public.charges charge on charge.id=allocation.charge_id join public.registrations r on r.id=charge.registration_id join public.registration_offerings offering on offering.id=r.offering_id
 where p_event.source_type='payment' and allocation.payment_id=p_event.source_id and offering.scope_type='team' and boss_private.notification_registration_visible(r.id,p_person,true,p_event.occurred_at)
 ) context),'[]'::jsonb)
$$;

create function boss_private.notification_destination_phase4a(p_event public.notification_events) returns text
language plpgsql stable security definer set search_path='' as $$ declare rid uuid;tid uuid;event_start timestamptz;event_zone text;event_occurrence text;begin
 if p_event.source_type='event' then
  select e.start_at,e.timezone into event_start,event_zone from public.events e where e.id=p_event.source_id and e.organization_id=p_event.organization_id;
  if not found or not boss_private.calendar_valid_timezone(event_zone) or event_zone!~'^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$' then return null;end if;
  event_occurrence:=coalesce(p_event.safe_data->>'occurrence_key',to_char(event_start at time zone event_zone,'YYYY-MM-DD"T"HH24:MI:SS'));
  if event_occurrence!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$' then return null;end if;
  if p_event.safe_data?'occurrence_key' then
   select coalesce(x.override_start_at,event_occurrence::timestamp at time zone event_zone) into event_start
   from (select 1) base left join public.event_occurrence_exceptions x on x.event_id=p_event.source_id and x.organization_id=p_event.organization_id and x.occurrence_key=event_occurrence and x.is_active;
  end if;
  -- Date follows the current exception; identity keeps the original wall key.
  return '/app/calendar?org='||p_event.organization_id||'&event='||p_event.source_id||'&date='||to_char(event_start at time zone event_zone,'YYYY-MM-DD')
   ||'&tz='||replace(replace(event_zone,'/','%2F'),'+','%2B')||'&occurrence='||replace(event_occurrence,':','%3A');
 end if;
 if p_event.source_type='message' then select thread_id into tid from public.communication_messages where id=p_event.source_id;return '/app/messages?org='||p_event.organization_id||'&thread='||tid;end if;
 if p_event.source_type='registration' then rid:=p_event.source_id;
 elsif p_event.source_type='registration_document' then select registration_id into rid from public.registration_documents where id=p_event.source_id;
 elsif p_event.source_type='charge' then select registration_id into rid from public.charges where id=p_event.source_id;
 elsif p_event.source_type='payment' then
  -- Multiple allocations must not choose an unauthorized registration link.
  return '/app/registrations?view=family&org='||p_event.organization_id;
 end if;
 return '/app/registrations?org='||p_event.organization_id||'&registration='||rid;
end $$;

create function boss_private.notification_candidates_phase4a(p_event public.notification_events,p_after uuid,p_limit integer) returns table(person_id uuid)
language sql stable security definer set search_path='' as $$
 select candidate.person_id from (
 (select distinct m.person_id from public.organization_memberships m
 where m.organization_id=p_event.organization_id and m.status='active' and m.created_at<=p_event.occurred_at and m.starts_at<=p_event.occurred_at and (m.ends_at is null or m.ends_at>now())
 and (p_after is null or m.person_id>p_after) and boss_private.notification_person_active(m.person_id)
 order by m.person_id limit greatest(1,least(p_limit,100)))
 union (select distinct m.person_id from public.team_memberships m
 where m.organization_id=p_event.organization_id and m.status='active' and m.created_at<=p_event.occurred_at and m.starts_at<=p_event.occurred_at and (m.ends_at is null or m.ends_at>now())
 and (p_after is null or m.person_id>p_after) and boss_private.notification_person_active(m.person_id)
 order by m.person_id limit greatest(1,least(p_limit,100)))
 union (select distinct a.person_id from public.role_assignments a
 where a.organization_id=p_event.organization_id and a.status='active' and a.created_at<=p_event.occurred_at and a.starts_at<=p_event.occurred_at and (a.ends_at is null or a.ends_at>now())
 and (p_after is null or a.person_id>p_after) and boss_private.notification_person_active(a.person_id)
 order by a.person_id limit greatest(1,least(p_limit,100)))
 union (select distinct g.guardian_person_id as person_id from public.guardian_relationships g join public.organization_memberships om on om.person_id=g.dependent_person_id and om.organization_id=p_event.organization_id
 where om.status='active' and om.created_at<=p_event.occurred_at and om.starts_at<=p_event.occurred_at and (om.ends_at is null or om.ends_at>now())
 and g.authority_status='active' and g.created_at<=p_event.occurred_at and g.verified_at<=p_event.occurred_at and g.starts_at<=p_event.occurred_at and (g.ends_at is null or g.ends_at>now())
 and (p_after is null or g.guardian_person_id>p_after) and boss_private.notification_person_active(g.guardian_person_id)
 order by person_id limit greatest(1,least(p_limit,100)))
 union (select distinct g.guardian_person_id as person_id from public.guardian_relationships g join public.team_memberships tm on tm.person_id=g.dependent_person_id and tm.organization_id=p_event.organization_id
 where tm.status='active' and tm.created_at<=p_event.occurred_at and tm.starts_at<=p_event.occurred_at and (tm.ends_at is null or tm.ends_at>now())
 and g.authority_status='active' and g.created_at<=p_event.occurred_at and g.verified_at<=p_event.occurred_at and g.starts_at<=p_event.occurred_at and (g.ends_at is null or g.ends_at>now())
 and (p_after is null or g.guardian_person_id>p_after) and boss_private.notification_person_active(g.guardian_person_id)
 order by person_id limit greatest(1,least(p_limit,100)))
 union (select distinct m.person_id from public.communication_thread_members m join public.communication_messages message on message.thread_id=m.thread_id and message.id=p_event.source_id
 where p_event.source_type='message' and m.organization_id=p_event.organization_id and m.status='active' and m.created_at<=p_event.occurred_at and m.starts_at<=p_event.occurred_at and (m.ends_at is null or m.ends_at>now())
 and (p_after is null or m.person_id>p_after) and boss_private.notification_person_active(m.person_id)
 order by m.person_id limit greatest(1,least(p_limit,100)))
 union (select distinct a.person_id from public.participants a join public.registrations r on r.participant_id=a.id and r.organization_id=p_event.organization_id
 where p_event.source_type in ('registration','registration_document','charge','payment') and a.status='active'
 and (p_after is null or a.person_id>p_after) and boss_private.notification_person_active(a.person_id)
 order by a.person_id limit greatest(1,least(p_limit,100)))
 union (select distinct g.guardian_person_id as person_id from public.guardian_relationships g join public.participants a on a.person_id=g.dependent_person_id join public.registrations r on r.participant_id=a.id and r.organization_id=p_event.organization_id
 where p_event.source_type in ('registration','registration_document','charge','payment') and g.authority_status='active' and g.created_at<=p_event.occurred_at and g.verified_at<=p_event.occurred_at and g.starts_at<=p_event.occurred_at and (g.ends_at is null or g.ends_at>now())
 and (p_after is null or g.guardian_person_id>p_after) and boss_private.notification_person_active(g.guardian_person_id)
 order by person_id limit greatest(1,least(p_limit,100)))
 ) candidate order by candidate.person_id limit greatest(1,least(p_limit,100))
$$;


create function boss_private.comm_thread_manage_phase4a(p_thread uuid,p_person uuid,p_key text default 'communications.manage') returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.comm_feature(t.organization_id,'communications') and case when t.kind='announcement' then
 exists(select 1 from public.communication_audiences a where a.thread_id=t.id) and not exists(select 1 from public.communication_audiences a where a.thread_id=t.id and not boss_private.comm_permission(p_person,p_key,t.organization_id,a.scope_type,a.scope_id))
 else boss_private.comm_permission(p_person,p_key,t.organization_id,t.scope_type,t.scope_id) end
 and (t.kind not in('direct','group','family') or exists(select 1 from public.communication_thread_members m where m.thread_id=t.id and m.person_id=p_person and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()))) from public.communication_threads t where t.id=p_thread),false) $$;

create or replace function boss_private.comm_thread_manage(p_thread uuid,p_person uuid,p_key text default 'communications.manage') returns boolean
language sql stable security definer set search_path='' as $$
 select boss_private.comm_thread_manage_phase4a(p_thread,p_person,p_key) and not exists(
 select 1 from public.communication_audiences audience where audience.thread_id=p_thread and audience.volunteer_shift_id is not null
 and not exists(select 1 from public.volunteer_shifts shift where shift.id=audience.volunteer_shift_id and shift.organization_id=audience.organization_id
 and shift.scope_type=audience.scope_type and shift.scope_id=audience.scope_id
 and boss_private.volunteer_permission(p_person,'volunteers.manage',shift.organization_id,shift.scope_type,shift.scope_id)))
$$;

create or replace function boss_private.comm_audience_person(p_audience uuid,p_person uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select case when a.volunteer_shift_id is null then boss_private.comm_audience_person_phase4a(p_audience,p_person)
 else boss_private.comm_feature(a.organization_id,'announcements') and boss_private.volunteer_notification_recipient(a.volunteer_shift_id,p_person,'changed')
 and exists(select 1 from public.volunteer_shifts s where s.id=a.volunteer_shift_id and s.organization_id=a.organization_id and s.scope_type=a.scope_type and s.scope_id=a.scope_id)
 end from public.communication_audiences a where a.id=p_audience),false)
$$;

create function boss_private.volunteer_announce(p_actor uuid,p_request uuid,p_shift uuid,p_title text,p_body text,p_replay boolean,p_thread uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.volunteer_shifts;tid uuid;begin
 if p_actor is distinct from boss_private.require_admin_actor() or p_request is null then raise exception 'Access denied' using errcode='PT403';end if;
 select * into s from public.volunteer_shifts where id=p_shift;
 if not found or not boss_private.volunteer_permission(p_actor,'volunteers.manage',s.organization_id,s.scope_type,s.scope_id)
 or not boss_private.comm_permission(p_actor,'announcements.send',s.organization_id,s.scope_type,s.scope_id)
 or not boss_private.comm_feature(s.organization_id,'announcements') then raise exception 'Access denied' using errcode='PT403';end if;
 if p_title is null or length(btrim(p_title)) not between 1 and 200 or p_title~'[[:cntrl:]]'
 or p_body is null or length(btrim(p_body)) not between 1 and 8000 or regexp_replace(p_body,E'[\t\n\r]','','g')~'[[:cntrl:]]'
 then raise exception 'Invalid volunteer request' using errcode='PT422';end if;
 if p_replay then
 if p_thread is null or not exists(select 1 from public.communication_threads t join public.communication_audiences a on a.thread_id=t.id
 where t.id=p_thread and t.organization_id=s.organization_id and t.kind='announcement' and t.status='active' and t.created_by_person_id=p_actor
 and a.volunteer_shift_id=s.id and a.scope_type=s.scope_type and a.scope_id=s.scope_id)
 then raise exception 'Access denied' using errcode='PT403';end if;tid:=p_thread;
 else
 tid:=gen_random_uuid();
 insert into public.communication_threads(id,organization_id,kind,title,scope_type,scope_id,created_by_person_id,visibility,next_sequence)
 values(tid,s.organization_id,'announcement',btrim(p_title),s.scope_type,s.scope_id,p_actor,'private',1);
 insert into public.communication_audiences(organization_id,thread_id,scope_type,scope_id,volunteer_shift_id)
 values(s.organization_id,tid,s.scope_type,s.scope_id,s.id);
 insert into public.communication_messages(organization_id,thread_id,author_person_id,body,sequence_number)
 values(s.organization_id,tid,p_actor,btrim(p_body),1);
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
 values(s.organization_id,p_actor,auth.uid(),'volunteers.shift.announce','communication_thread',tid,
 case s.scope_type when 'unit' then 'organization_unit' else s.scope_type end,s.scope_id,p_request,jsonb_build_object('shift_id',s.id,'thread_id',tid));
 end if;
 return jsonb_build_object('resource_id',tid,'version',1,'status','sent');
end $$;



-- A reminder identifies a schedule and an active commitment episode, rather
-- than the shift capacity version bumped when another volunteer joins/leaves.
create function boss_private.volunteer_reminder_context(p_shift uuid) returns text
language sql stable security definer set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object('start_epoch',extract(epoch from shift.start_at),'offset',shift.reminder_minutes_before,
 'event_context',case when shift.event_id is null then null else boss_private.volunteer_event_stamp(shift.event_id,shift.occurrence_key)end)::text,'UTF8')),'hex')
 from public.volunteer_shifts shift where shift.id=p_shift
$$;

create function boss_private.volunteer_event_notification_recipient(p_event uuid,p_person uuid,p_at timestamptz) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.volunteer_shifts shift join public.volunteer_assignments a on a.shift_id=shift.id
 where shift.event_id=p_event and shift.created_at<=p_at and a.person_id=p_person and a.status='active'
 and a.created_at<=p_at and a.updated_at<=p_at and shift.status not in('canceled','archived')
 and shift.event_context_stamp is distinct from boss_private.volunteer_event_stamp(shift.event_id,shift.occurrence_key)
 and boss_private.volunteer_notification_recipient(shift.id,p_person,'changed')
 and boss_private.volunteer_context_at(p_person,shift.organization_id,shift.scope_type,shift.scope_id,p_at))
$$;

create or replace function boss_private.notification_source_visible(p_event public.notification_events,p_person uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare s public.volunteer_shifts;a public.volunteer_assignments;kind text;begin
 if not boss_private.notification_person_active(p_person) or not boss_private.comm_feature(p_event.organization_id,'in_app_notifications') or p_event.status='canceled' then return false;end if;
 if p_event.source_type='attendance_request' then
 return exists(select 1 from public.attendance_requests r where r.id=p_event.source_id and r.organization_id=p_event.organization_id)
 and boss_private.attendance_notification_visible(p_event.source_id,p_person,p_event.occurred_at);

 elsif p_event.source_type='volunteer_event' then
 return exists(select 1 from public.events e where e.id=p_event.source_id and e.organization_id=p_event.organization_id)
 and boss_private.volunteer_event_notification_recipient(p_event.source_id,p_person,p_event.occurred_at);
 elsif p_event.source_type in('volunteer_shift','volunteer_assignment') then
 if p_event.source_type='volunteer_shift' then select * into s from public.volunteer_shifts where id=p_event.source_id and organization_id=p_event.organization_id;
 else select * into a from public.volunteer_assignments where id=p_event.source_id and organization_id=p_event.organization_id;
 if a.id is not null then select * into s from public.volunteer_shifts where id=a.shift_id and organization_id=a.organization_id;end if;end if;
 if s.id is null or not boss_private.volunteer_feature(s.organization_id,'volunteers') then return false;end if;
 kind:=case p_event.event_type when 'volunteer.confirmed' then 'confirmation' when 'volunteer.changed' then 'changed' when 'volunteer.canceled' then 'canceled' when 'volunteer.reminder' then 'reminder' when 'volunteer.cancellation' then 'cancellation' end;
 if kind is null then return false;end if;
 if kind='reminder' and (a.id is null or a.version::text is distinct from p_event.safe_data->>'source_version'
 or p_event.source_revision is distinct from 'assignment:'||a.version||':'||boss_private.volunteer_reminder_context(s.id)
 or s.start_at-make_interval(mins=>s.reminder_minutes_before) is distinct from p_event.scheduled_at
 or(s.event_id is not null and s.event_context_stamp is distinct from boss_private.volunteer_event_stamp(s.event_id,s.occurrence_key))) then return false;end if;
 if kind='cancellation' and boss_private.volunteer_coordinator_at(s.id,p_person,p_event.occurred_at) then return true;end if;
 return(a.id is null or a.person_id=p_person) and boss_private.volunteer_notification_recipient(s.id,p_person,kind)
 and boss_private.volunteer_context_at(p_person,s.organization_id,s.scope_type,s.scope_id,p_event.occurred_at)
 and exists(select 1 from public.volunteer_assignments assignment where assignment.shift_id=s.id and assignment.person_id=p_person
 and assignment.created_at<=p_event.occurred_at and assignment.updated_at<=p_event.occurred_at and(kind in('canceled','cancellation') or assignment.status='active'));
 elsif p_event.source_type='message' and exists(select 1 from public.communication_messages m join public.communication_audiences audience on audience.thread_id=m.thread_id where m.id=p_event.source_id and audience.volunteer_shift_id is not null) then
 return exists(select 1 from public.communication_messages m join public.communication_threads t on t.id=m.thread_id join public.communication_audiences audience on audience.thread_id=t.id
 join public.volunteer_shifts shift on shift.id=audience.volunteer_shift_id and shift.organization_id=audience.organization_id
 join public.volunteer_assignments assignment on assignment.shift_id=shift.id and assignment.person_id=p_person and assignment.status='active'
 where m.id=p_event.source_id and m.organization_id=p_event.organization_id and m.status='visible' and m.author_person_id<>p_person
 and assignment.created_at<=p_event.occurred_at and assignment.updated_at<=p_event.occurred_at and boss_private.comm_audience_person(audience.id,p_person)
 and boss_private.volunteer_context_at(p_person,shift.organization_id,shift.scope_type,shift.scope_id,p_event.occurred_at)
 and boss_private.comm_message_can_view(m.id,p_person));
 end if;
 return boss_private.notification_source_visible_phase4a(p_event,p_person);
end $$;

create or replace function boss_private.notification_candidates(p_event public.notification_events,p_after uuid,p_limit integer) returns table(person_id uuid)
language plpgsql stable security definer set search_path='' as $$declare shift_id uuid;begin
 if p_event.source_type='attendance_request' then
 return query select c.person_id from boss_private.attendance_notification_candidates(p_event.source_id,p_after,p_limit)c;

 elsif p_event.source_type='volunteer_event' then
 return query select distinct a.person_id from public.volunteer_shifts shift join public.volunteer_assignments a on a.shift_id=shift.id
 where shift.event_id=p_event.source_id and shift.organization_id=p_event.organization_id
 and(p_after is null or a.person_id>p_after) and boss_private.notification_source_visible(p_event,a.person_id)
 order by a.person_id limit greatest(1,least(p_limit,100));

 elsif p_event.source_type='volunteer_assignment' then
 return query select c.person_id from(
 (select a.person_id from public.volunteer_assignments a where a.id=p_event.source_id and a.organization_id=p_event.organization_id
 and(p_after is null or a.person_id>p_after) and boss_private.notification_source_visible(p_event,a.person_id))
 union(select distinct a.person_id from public.role_assignments a where p_event.event_type='volunteer.cancellation' and a.organization_id=p_event.organization_id
 and(p_after is null or a.person_id>p_after) and boss_private.notification_source_visible(p_event,a.person_id)
 order by a.person_id limit greatest(1,least(p_limit,100)))
 )c order by c.person_id limit greatest(1,least(p_limit,100));
 elsif p_event.source_type='volunteer_shift' then
 return query select a.person_id from public.volunteer_assignments a where a.shift_id=p_event.source_id and a.created_at<=p_event.occurred_at
 and(p_after is null or a.person_id>p_after) and boss_private.notification_source_visible(p_event,a.person_id)
 order by a.person_id limit greatest(1,least(p_limit,100));
 elsif p_event.source_type='message' and exists(select 1 from public.communication_messages m join public.communication_audiences audience on audience.thread_id=m.thread_id where m.id=p_event.source_id and audience.volunteer_shift_id is not null) then
 return query select distinct a.person_id from public.communication_messages m join public.communication_audiences audience on audience.thread_id=m.thread_id
 join public.volunteer_assignments a on a.shift_id=audience.volunteer_shift_id
 where m.id=p_event.source_id and(p_after is null or a.person_id>p_after) and boss_private.notification_source_visible(p_event,a.person_id)
 order by a.person_id limit greatest(1,least(p_limit,100));
 else return query select c.person_id from boss_private.notification_candidates_phase4a(p_event,p_after,p_limit)c;end if;
end $$;

create or replace function boss_private.notification_contexts(p_event public.notification_events,p_person uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$declare s public.volunteer_shifts;begin
 if p_event.source_type='attendance_request' then return boss_private.attendance_notification_contexts(p_event.source_id,p_person);end if;

 if p_event.source_type='volunteer_event' then
 if not boss_private.notification_source_visible(p_event,p_person) then return '[]';end if;
 return jsonb_build_array(jsonb_build_object('source_type',p_event.source_type,'source_id',p_event.source_id))||coalesce((
 select jsonb_agg(jsonb_build_object('team_id',team_id) order by team_id) from(
 select distinct shift.scope_id team_id from public.volunteer_shifts shift join public.volunteer_assignments a on a.shift_id=shift.id and a.person_id=p_person and a.status='active'
 where shift.event_id=p_event.source_id and shift.organization_id=p_event.organization_id and shift.scope_type='team'
 and a.created_at<=p_event.occurred_at and a.updated_at<=p_event.occurred_at
 and boss_private.volunteer_context_at(p_person,shift.organization_id,shift.scope_type,shift.scope_id,p_event.occurred_at)
 and shift.event_context_stamp is distinct from boss_private.volunteer_event_stamp(shift.event_id,shift.occurrence_key)
 )teams),'[]'::jsonb);
 end if;
 if p_event.source_type in('volunteer_shift','volunteer_assignment') then
 if not boss_private.notification_source_visible(p_event,p_person) then return '[]';end if;
 select shift.* into s from public.volunteer_shifts shift where shift.organization_id=p_event.organization_id and shift.id=case when p_event.source_type='volunteer_shift' then p_event.source_id else(select shift_id from public.volunteer_assignments where id=p_event.source_id)end;
 return jsonb_build_array(jsonb_build_object('source_type',p_event.source_type,'source_id',p_event.source_id,'shift_id',s.id))
 ||case when s.scope_type='team' then jsonb_build_array(jsonb_build_object('team_id',s.scope_id)) else '[]'::jsonb end;
 end if;return boss_private.notification_contexts_phase4a(p_event,p_person);
end $$;

create or replace function boss_private.notification_destination(p_event public.notification_events) returns text
language plpgsql stable security definer set search_path='' as $$declare r public.attendance_requests;sid uuid;begin
 if p_event.source_type='attendance_request' then
 select * into r from public.attendance_requests where id=p_event.source_id and organization_id=p_event.organization_id;
 if not found then return null;end if;
 return '/app/attendance?org='||p_event.organization_id||'&event='||r.event_id||'&occurrence='||replace(r.occurrence_key,':','%3A');

 elsif p_event.source_type='volunteer_event' then
 return '/app/volunteers?org='||p_event.organization_id||'&event='||p_event.source_id;
 elsif p_event.source_type in('volunteer_shift','volunteer_assignment') then
 if p_event.source_type='volunteer_shift' then sid:=p_event.source_id;else select shift_id into sid from public.volunteer_assignments where id=p_event.source_id and organization_id=p_event.organization_id;end if;
 if sid is null then return null;end if;return '/app/volunteers?org='||p_event.organization_id||'&shift='||sid;
 end if;return boss_private.notification_destination_phase4a(p_event);
end $$;

-- Coordination sources must be dated to their statement, matching the
-- assignment identity trigger's updated_at. A transaction timestamp can
-- precede a cancellation/rejoin in the same transaction. Preserve the first
-- source date on replay so a later assignment cannot see an older episode.
create or replace function boss_private.notification_enqueue(p_module text,p_source_type text,p_source uuid,p_org uuid,p_type text,p_revision text,p_safe jsonb default '{}',p_scheduled timestamptz default now()) returns uuid
language plpgsql security definer set search_path='' as $$ declare result uuid;source_at timestamptz;begin
 if not exists(select 1 from boss_private.notification_types t where t.key=p_type and t.source_module=p_module)
 or p_safe is null or jsonb_typeof(p_safe)<>'object' or exists(select 1 from jsonb_object_keys(p_safe) k where k not in ('team_id','occurrence_key','start_at','end_at','source_version','offset_minutes','reminder_id'))
 then raise exception 'Invalid notification operation' using errcode='PT422';end if;
 if not boss_private.comm_feature(p_org,'in_app_notifications') then return null;end if;
 source_at:=case when p_source_type in('attendance_request','volunteer_shift','volunteer_assignment','volunteer_event')
 or(p_source_type='message' and exists(select 1 from public.communication_messages m join public.communication_audiences audience on audience.thread_id=m.thread_id
 where m.id=p_source and m.organization_id=p_org and audience.volunteer_shift_id is not null)) then statement_timestamp() else now() end;
 insert into public.notification_events(organization_id,event_type,source_module,source_type,source_id,source_revision,safe_data,scheduled_at,occurred_at)
 values(p_org,p_type,p_module,p_source_type,p_source,p_revision,p_safe,p_scheduled,source_at)
 on conflict(organization_id,event_type,source_type,source_id,source_revision) do nothing returning id into result;
 if result is null then select e.id into result from public.notification_events e where e.organization_id=p_org and e.event_type=p_type and e.source_type=p_source_type and e.source_id=p_source and e.source_revision=p_revision;end if;
 insert into boss_private.notification_expansion_jobs(notification_event_id) values(result) on conflict do nothing;
 return result;
end $$;

create function boss_private.attendance_notification_ingest() returns trigger language plpgsql security definer set search_path='' as $$begin
 perform boss_private.notification_enqueue('calendar','attendance_request',new.id,new.organization_id,'attendance.'||new.kind,new.revision,
 jsonb_build_object('occurrence_key',new.occurrence_key));
 perform boss_private.notification_process(new.organization_id,100);return new;
end $$;
create trigger attendance_notification_source after insert on public.attendance_requests for each row execute function boss_private.attendance_notification_ingest();

create function boss_private.volunteer_notification_audit_ingest() returns trigger language plpgsql security definer set search_path='' as $$
declare s public.volunteer_shifts;aid uuid;typ text;revision text;safe jsonb;begin
 if new.action='volunteers.shift.upsert' then
 select * into s from public.volunteer_shifts where id=(new.after_data->>'shift_id')::uuid and organization_id=new.organization_id;
 if s.id is null or not coalesce((new.after_data->>'material_change')::boolean,false) then return new;end if;
 typ:=case when s.status in('canceled','archived') then 'volunteer.canceled' else 'volunteer.changed' end;
 perform boss_private.notification_enqueue('volunteers','volunteer_shift',s.id,s.organization_id,typ,'shift:'||s.version,
 jsonb_strip_nulls(jsonb_build_object('source_version',s.version,'team_id',s.team_id)));
 elsif new.action in('volunteers.assignment.signup','volunteers.assignment.assign','volunteers.assignment.cancel','volunteers.assignment.reassign') then
 aid:=(new.after_data->>'assignment_id')::uuid;
 select shift.* into s from public.volunteer_shifts shift join public.volunteer_assignments a on a.shift_id=shift.id where a.id=aid and a.organization_id=new.organization_id;
 if s.id is null then return new;end if;
 typ:=case when new.action='volunteers.assignment.cancel' then 'volunteer.cancellation' else 'volunteer.confirmed' end;
 perform boss_private.notification_enqueue('volunteers','volunteer_assignment',aid,s.organization_id,typ,'audit:'||new.id,
 jsonb_strip_nulls(jsonb_build_object('source_version',new.after_data->'version','team_id',s.team_id)));
 if new.action='volunteers.assignment.reassign' and new.after_data->>'previous_assignment_id' is not null then
 perform boss_private.notification_enqueue('volunteers','volunteer_assignment',(new.after_data->>'previous_assignment_id')::uuid,s.organization_id,'volunteer.cancellation','audit:'||new.id,
 jsonb_strip_nulls(jsonb_build_object('team_id',s.team_id)));
 end if;

 elsif new.action in('event.update','event.exception','event.status') then
 if not exists(select 1 from public.volunteer_shifts shift where shift.event_id=new.resource_id and shift.organization_id=new.organization_id
 and shift.status not in('canceled','archived') and shift.event_context_stamp is distinct from boss_private.volunteer_event_stamp(shift.event_id,shift.occurrence_key)) then return new;end if;
 typ:=case when new.after_data->>'status' in('canceled','archived') then 'volunteer.canceled' else 'volunteer.changed' end;
 perform boss_private.notification_enqueue('volunteers','volunteer_event',new.resource_id,new.organization_id,typ,'event:'||new.id,
 jsonb_strip_nulls(jsonb_build_object('source_version',new.after_data->'version','occurrence_key',new.after_data->>'occurrence_key')));
 else return new;end if;
 perform boss_private.notification_process(new.organization_id,100);return new;
end $$;
create trigger volunteer_notification_source after insert on public.audit_events for each row execute function boss_private.volunteer_notification_audit_ingest();

create function boss_private.volunteer_prepare_reminders(p_actor uuid,p_org uuid,p_start timestamptz,p_end timestamptz) returns integer
language plpgsql security definer set search_path='' as $$declare item record;scheduled timestamptz;revision text;total integer:=0;begin
 if p_actor is distinct from boss_private.require_admin_actor() then raise exception 'Access denied' using errcode='PT403';end if;
 if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end) or p_end<=p_start or p_end-p_start>interval '7 days'
 or p_start<now()-interval '1 day' or p_end>now()+interval '32 days' then raise exception 'Invalid volunteer request' using errcode='PT422';end if;
 if not boss_private.volunteer_feature(p_org,'reminders') then raise exception 'Access denied' using errcode='PT403';end if;
 for item in select shift.id shift_id,shift.start_at,shift.reminder_minutes_before,shift.team_id,assignment.id assignment_id,assignment.version assignment_version,
 'assignment:'||assignment.version||':'||boss_private.volunteer_reminder_context(shift.id) source_revision
 from public.volunteer_shifts shift join public.volunteer_assignments assignment on assignment.shift_id=shift.id and assignment.status='active'
 where shift.organization_id=p_org and shift.status='open' and shift.start_at>=p_start and shift.start_at<p_end+interval '7 days'
 and shift.start_at-make_interval(mins=>shift.reminder_minutes_before)>=p_start and shift.start_at-make_interval(mins=>shift.reminder_minutes_before)<p_end
 and boss_private.volunteer_permission(p_actor,'volunteers.manage',p_org,shift.scope_type,shift.scope_id)
 and boss_private.volunteer_event_current(p_org,shift.event_id,shift.occurrence_key,shift.scope_type,shift.scope_id)
 and(shift.event_id is null or shift.event_context_stamp=boss_private.volunteer_event_stamp(shift.event_id,shift.occurrence_key))
 and boss_private.volunteer_person_eligible(assignment.person_id,p_org,shift.scope_type,shift.scope_id)
 and not exists(select 1 from public.notification_events event where event.organization_id=p_org and event.source_type='volunteer_assignment' and event.source_id=assignment.id
 and event.event_type='volunteer.reminder' and event.source_revision='assignment:'||assignment.version||':'||boss_private.volunteer_reminder_context(shift.id))
 order by shift.start_at,assignment.id limit 100 for update of assignment skip locked loop
 scheduled:=item.start_at-make_interval(mins=>item.reminder_minutes_before);revision:=item.source_revision;
 perform boss_private.notification_enqueue('volunteers','volunteer_assignment',item.assignment_id,p_org,'volunteer.reminder',revision,
 jsonb_strip_nulls(jsonb_build_object('source_version',item.assignment_version,'team_id',item.team_id,'offset_minutes',item.reminder_minutes_before)),scheduled);total:=total+1;
 end loop;perform boss_private.notification_process(p_org,100);return total;
end $$;


create or replace function boss_private.notifications_read(p_query jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;v_org uuid;v_view text;v_category text;v_limit integer;v_before timestamptz;inbox jsonb;preferences jsonb;history jsonb:='[]';orgs jsonb;ops jsonb;unread bigint;v_in_app boolean;begin
 actor:=boss_private.require_admin_actor();
 if p_query is null or jsonb_typeof(p_query)<>'object' or octet_length(p_query::text)>4096 or exists(select 1 from jsonb_object_keys(p_query) k where k not in ('view','organization_id','category','limit','before')) then raise exception 'Invalid notification operation' using errcode='PT422';end if;
 v_view:=coalesce(p_query->>'view','inbox');v_org:=(p_query->>'organization_id')::uuid;v_category:=p_query->>'category';v_limit:=coalesce((p_query->>'limit')::integer,50);v_before:=(p_query->>'before')::timestamptz;
 if v_view not in ('inbox','summary','preferences','history') or v_limit not between 1 and 50 or (v_category is not null and v_category not in ('events','registration','fees','communications','security','attendance','volunteers')) then raise exception 'Invalid notification operation' using errcode='PT422';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'name',o.name) order by o.name,o.id),'[]') into orgs from public.organizations o where o.status='active' and boss_private.comm_feature(o.id,'in_app_notifications') and (
 boss_private.comm_permission(actor,'notifications.manage',o.id,'organization',o.id) or exists(select 1 from public.organization_memberships m where m.organization_id=o.id and m.person_id=actor and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()))
 or exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id where n.recipient_person_id=actor and n.organization_id=o.id and boss_private.notification_source_visible(e,actor)));
 if v_org is not null and not exists(select 1 from jsonb_array_elements(orgs) o where o->>'id'=v_org::text) then raise exception 'Access denied' using errcode='PT403';end if;
 if v_view='history' then
  if v_org is null or not boss_private.comm_permission(actor,'delivery_history.view',v_org,'organization',v_org) then raise exception 'Access denied' using errcode='PT403';end if;
  select coalesce(jsonb_agg(x.row order by x.created_at desc,x.id),'[]') into history from (
   select d.id,d.created_at,jsonb_build_object('id',d.id,'event_type',e.event_type,'channel',d.channel,'status',d.status,'created_at',d.created_at,'sent_at',d.sent_at,'failure_category',d.failure_category,'attempts',d.attempts,'recipient_name',coalesce(p.display_name,'Boss member')) row
   from public.notification_deliveries d join public.notifications n on n.id=d.notification_id join public.notification_events e on e.id=n.notification_event_id join public.people p on p.id=n.recipient_person_id
   where d.organization_id=v_org and (v_before is null or d.created_at<v_before) order by d.created_at desc,d.id limit v_limit) x;
 end if;
 select coalesce(jsonb_agg(x.row order by x.created_at desc,x.id),'[]') into inbox from (
  select n.id,n.created_at,jsonb_build_object('id',n.id,'category',t.category,'event_type',e.event_type,'title',t.title,'body',t.body,'destination',boss_private.notification_destination(e),'organization_id',n.organization_id,'team_id',e.safe_data->>'team_id','created_at',n.created_at,'read_at',n.read_at) row
  from public.notifications n join public.notification_events e on e.id=n.notification_event_id join boss_private.notification_types t on t.key=e.event_type
  join public.notification_deliveries d on d.notification_id=n.id and d.channel='in_app' and d.status='sent'
  where n.recipient_person_id=actor and (v_org is null or n.organization_id=v_org) and (v_category is null or t.category=v_category)
  and (v_before is null or n.created_at<v_before) and boss_private.notification_source_visible(e,actor)
  order by n.created_at desc,n.id limit case when v_view='summary' then 8 else v_limit end) x;
 select count(*) into unread from public.notifications n join public.notification_events e on e.id=n.notification_event_id join public.notification_deliveries d on d.notification_id=n.id and d.channel='in_app' and d.status='sent'
 where n.recipient_person_id=actor and n.read_at is null and (v_org is null or n.organization_id=v_org) and boss_private.notification_source_visible(e,actor);
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'channel',p.channel,'category',p.category,'organization_id',p.organization_id,'team_id',p.team_id,'enabled',p.enabled) order by p.channel,p.category,p.id),'[]') into preferences from public.notification_preferences p where p.person_id=actor;
 ops:='["notification.read","notification.read_all","preference.set"]';
 if v_org is not null and boss_private.comm_permission(actor,'notifications.manage',v_org,'organization',v_org) then ops:=ops||'["delivery.process","reminder.generate"]'::jsonb;end if;
 -- Availability is a current authorized feature projection, not a global constant.
 -- Self/global preferences remain available as a foundation when no module is on.
 v_in_app:=jsonb_array_length(orgs)>0 or jsonb_array_length(inbox)>0;
 return jsonb_build_object('notifications',inbox,'preferences',preferences,'history',history,'unread_count',unread,'operations',ops,
 'availability',jsonb_build_object('in_app',v_in_app,'email','not_configured','sms','future','push','future'),'features',jsonb_build_object('notifications',v_in_app,'in_app_notifications',v_in_app,'email_notifications',false,'delivery_history',v_org is not null and boss_private.comm_permission(actor,'delivery_history.view',v_org,'organization',v_org)),'organizations',orgs,'organizationId',v_org);
exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT422' then raise;when others then raise exception 'Invalid notification operation' using errcode='PT422';end $$;

create or replace function boss_private.notifications_mutate(p_request_id uuid,p_command jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;receipt boss_private.notification_operation_receipts;op text;i jsonb;org uuid;team uuid;v_id uuid;event public.notification_events;result jsonb;hash bytea;before_data jsonb;begin
 actor:=boss_private.require_admin_actor();
 if p_request_id is null or p_command is null or jsonb_typeof(p_command)<>'object' or octet_length(p_command::text)>8192
 or exists(select 1 from jsonb_object_keys(p_command) k where k not in ('operation','input')) or jsonb_typeof(p_command->'input') is distinct from 'object' then raise exception 'Invalid notification operation' using errcode='PT422';end if;
 op:=p_command->>'operation';i:=p_command->'input';org:=(i->>'organization_id')::uuid;
 if op='notification.read' then
  if exists(select 1 from jsonb_object_keys(i) k where k<>'id') then raise exception 'Invalid notification operation' using errcode='PT422';end if;
  v_id:=(i->>'id')::uuid;select e.* into event from public.notifications n join public.notification_events e on e.id=n.notification_event_id where n.id=v_id and n.recipient_person_id=actor;
  if not found or not boss_private.notification_source_visible(event,actor) then raise exception 'Access denied' using errcode='PT403';end if;
 elsif op='notification.read_all' then
  if exists(select 1 from jsonb_object_keys(i) k where k<>'organization_id') then raise exception 'Invalid notification operation' using errcode='PT422';end if;
  if org is not null then perform boss_private.notifications_read(jsonb_build_object('organization_id',org));end if;
 elsif op='preference.set' then
  if exists(select 1 from jsonb_object_keys(i) k where k not in ('channel','category','organization_id','team_id','enabled')) or i->>'channel' not in ('in_app','email') or i->>'category' not in ('events','registration','fees','communications','security','attendance','volunteers') or jsonb_typeof(i->'enabled') is distinct from 'boolean' then raise exception 'Invalid notification operation' using errcode='PT422';end if;
  if i->>'channel' is null or i->>'category' is null then raise exception 'Invalid notification operation' using errcode='PT422';end if;
  team:=(i->>'team_id')::uuid;
  if team is not null and org is null then raise exception 'Access denied' using errcode='PT403';end if;
  if org is not null then perform boss_private.notifications_read(jsonb_build_object('organization_id',org));end if;
  if team is not null and not boss_private.comm_context_related(actor,org,'team',team) and not boss_private.comm_permission(actor,'notifications.manage',org,'team',team)
 and not(i->>'category' in('attendance','volunteers') and exists(select 1 from public.notifications n join public.notification_events e on e.id=n.notification_event_id
 join boss_private.notification_types typ on typ.key=e.event_type where n.recipient_person_id=actor and n.organization_id=org and typ.category=i->>'category'
 and boss_private.notification_source_visible(e,actor) and boss_private.notification_contexts(e,actor) @> jsonb_build_array(jsonb_build_object('team_id',team)))) then raise exception 'Access denied' using errcode='PT403';end if;
 elsif op in ('delivery.process','reminder.generate') then
  if org is null or not boss_private.comm_permission(actor,'notifications.manage',org,'organization',org) then raise exception 'Access denied' using errcode='PT403';end if;
  if exists(select 1 from jsonb_object_keys(i) k where k not in ('organization_id','limit','window_start','window_end')) or (op='delivery.process' and (i?'window_start' or i?'window_end')) or (op='reminder.generate' and i?'limit') then raise exception 'Invalid notification operation' using errcode='PT422';end if;
 else raise exception 'Invalid notification operation' using errcode='PT422';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('notification-request:'||actor||':'||p_request_id,0));
 hash:=pg_catalog.sha256(pg_catalog.convert_to(p_command::text,'UTF8'));
 select * into receipt from boss_private.notification_operation_receipts where actor_person_id=actor and request_id=p_request_id;
 if found then if receipt.input_hash<>hash then raise exception 'Conflicting notification operation' using errcode='PT409';end if;return receipt.result;end if;
 if op='notification.read' then update public.notifications set read_at=coalesce(read_at,now()) where notifications.id=v_id and recipient_person_id=actor;
 elsif op='notification.read_all' then update public.notifications n set read_at=now() from public.notification_events e where e.id=n.notification_event_id and n.recipient_person_id=actor and n.read_at is null and (org is null or n.organization_id=org) and boss_private.notification_source_visible(e,actor);
 elsif op='preference.set' then
  insert into public.notification_preferences(person_id,organization_id,team_id,channel,category,enabled) values(actor,org,team,i->>'channel',i->>'category',(i->>'enabled')::boolean)
  on conflict(person_id,organization_id,team_id,channel,category) do update set enabled=excluded.enabled,updated_at=now() returning notification_preferences.id into v_id;
 elsif op='delivery.process' then result:=boss_private.notification_process(org,coalesce((i->>'limit')::integer,100));v_id:=org;
 elsif op='reminder.generate' then result:=jsonb_build_object('scheduled',boss_private.notification_generate_reminders(org,coalesce((i->>'window_start')::timestamptz,now()),coalesce((i->>'window_end')::timestamptz,now()+interval '7 days')));v_id:=org;
 end if;
 result:=jsonb_build_object('request_id',p_request_id,'operation',op,'resource_id',coalesce(v_id,actor),'version',1)||coalesce(result,'{}');
 insert into boss_private.notification_operation_receipts(actor_person_id,request_id,input_hash,command,result) values(actor,p_request_id,hash,p_command,result);
 if op in ('delivery.process','reminder.generate') then insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
 values(org,actor,auth.uid(),'notifications.'||op,'notification_delivery',org,'organization',org,p_request_id,jsonb_build_object('operation',op));end if;
 return result;
exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' then raise;when unique_violation or deadlock_detected or serialization_failure then raise exception 'Conflicting notification operation' using errcode='PT409';when others then raise exception 'Invalid notification operation' using errcode='PT422';end $$;

create or replace function public.boss_admin_read(p_view text,p_organization_id uuid default null,p_query text default null)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  actor uuid; person jsonb; contexts jsonb; records jsonb:='{}'; ops text[]:='{}'; nav text[]:='{}'; rows jsonb;
  org_manage boolean; team_manage boolean; household_manage boolean; guardian_manage boolean; org_members_manage boolean; role_manage boolean;
begin
  perform boss_private.require_live_auth();
  if p_view is null or p_view not in ('home','organizations','people','families','teams','access','audit','account') or length(coalesce(p_query,''))>100 or coalesce(p_query,'') ~ '[[:cntrl:]]' then
    raise exception 'Invalid request.' using errcode='PT422';
  end if;
  actor:=boss_private.current_person_id();
  if actor is null then return jsonb_build_object('provisioned',false,'person',null,'organizations','[]'::jsonb,'organizationId',null,
    'operations',jsonb_build_array('identity.provision_self'),'navigation','[]'::jsonb,'records','{}'::jsonb); end if;
  contexts:=boss_private.admin_contexts(case when p_view='organizations' then nullif(btrim(p_query),'') end);
  if p_organization_id is not null and jsonb_array_length(boss_private.admin_contexts(null,p_organization_id))=0 then
    raise exception 'Request not permitted.' using errcode='PT403';
  end if;
  if p_organization_id is not null and not exists(select 1 from jsonb_array_elements(contexts) c where c->>'id'=p_organization_id::text) then
    contexts:=boss_private.admin_contexts(null,p_organization_id)||contexts;
  end if;
  select jsonb_build_object('id',id,'label',coalesce(display_name,preferred_name,nullif(concat_ws(' ',first_name,last_name),''),'Boss member')) into person
    from public.people where id=actor;
  org_manage:=boss_private.has_permission('organization.manage') or (p_organization_id is not null and boss_private.has_permission('organization.manage',p_organization_id));
  team_manage:=boss_private.has_permission('team.manage') or (p_organization_id is not null and boss_private.has_permission('team.manage',p_organization_id));
  household_manage:=boss_private.has_permission('household.manage');
  guardian_manage:=household_manage and boss_private.has_permission('person.profile.manage');
  org_members_manage:=boss_private.has_permission('organization.members.manage') or (p_organization_id is not null and boss_private.has_permission('organization.members.manage',p_organization_id));
  role_manage:=boss_private.has_permission('roles.assign') or (p_organization_id is not null and boss_private.has_permission('roles.assign',p_organization_id));
  ops:=array_remove(array[
    case when boss_private.has_permission('organization.manage') then 'organization.create' end,
    case when boss_private.has_permission('person.profile.manage') then 'person.create' end,
    case when boss_private.has_permission('person.profile.manage') then 'account.link' end,
    case when household_manage then 'household.create' end,
    case when household_manage then 'household_membership.add' end,
    case when guardian_manage then 'guardian.create' end,
    case when boss_private.has_permission('participant.profile.manage') then 'participant.create' end,
    case when p_organization_id is not null and org_manage then 'module.set' end,
    case when p_organization_id is not null and org_manage then 'unit.create' end,
    case when p_organization_id is not null and org_manage then 'season.create' end,
    case when p_organization_id is not null and team_manage then 'team.create' end,
    case when boss_private.has_permission('organization.members.manage') or (p_organization_id is not null and org_members_manage) then 'organization_membership.add' end,
    case when role_manage then 'role_assignment.add' end
  ],null);
  if jsonb_array_length(contexts)>0 or boss_private.has_permission('organization.view') then nav:=array_append(nav,'organizations'); end if;
  -- Own/dependent identity views are finite. A global name search is platform-only.
  nav:=array_append(nav,'people');
  if boss_private.has_permission('household.view') or exists(select 1 from public.households) or exists(select 1 from public.guardian_relationships) then nav:=array_append(nav,'families'); end if;
  if boss_private.has_permission('team.view') or exists(select 1 from public.teams)
    or exists(select 1 from jsonb_array_elements(contexts) c where boss_private.has_permission('team.view',(c->>'id')::uuid))
    or exists(select 1 from public.organization_units u where boss_private.has_permission('team.manage',u.organization_id,u.id)) then nav:=array_append(nav,'teams'); end if;
  if boss_private.has_permission('roles.view') or exists(select 1 from public.role_assignments) then nav:=array_append(nav,'access'); end if;
  if boss_private.has_permission('audit.view') or exists(select 1 from jsonb_array_elements(contexts) c where boss_private.has_permission('audit.view',(c->>'id')::uuid))
    or exists(select 1 from public.organization_units u where boss_private.has_permission('audit.view',u.organization_id,u.id))
    or exists(select 1 from public.teams t where boss_private.has_permission('audit.view',t.organization_id,t.parent_unit_id,t.id)) then nav:=array_append(nav,'audit'); end if;
  if p_view not in ('home','account','people') and not p_view=any(nav) then raise exception 'Request not permitted.' using errcode='PT403'; end if;
  records:=jsonb_build_object('organizations',contexts);
  if p_view in ('people','families','teams','access','home','organizations') then
    records:=records||jsonb_build_object('people',boss_private.admin_people(p_organization_id,case when p_view='people' then nullif(btrim(p_query),'') end));
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(p.id,coalesce(n->>'label','Participant'),p.status,jsonb_build_object('person_id',p.person_id,'participant_type',p.participant_type),
        case when n->>'status'='active' and (boss_private.has_permission('participant.profile.manage') or (p_organization_id is not null and n->'operations' ? 'participant.create'))
          then array['participant.update'] else '{}'::text[] end) item
      from public.participants p left join lateral (select pr from jsonb_array_elements(records->'people') pr where pr->>'id'=p.person_id::text limit 1) names(n) on true
      where exists(select 1 from jsonb_array_elements(records->'people') pr where pr->>'id'=p.person_id::text) order by p.id limit 50
    ) s;
    records:=records||jsonb_build_object('participants',rows);
  end if;
  if p_view in ('organizations','teams','access') and p_organization_id is not null then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(u.id,u.name,u.status,jsonb_build_object('organization_id',u.organization_id,'parent_unit_id',u.parent_unit_id,'name',u.name,'slug',u.slug,'unit_type',u.unit_type,'sort_order',u.sort_order),
        array_remove(array[
          case when boss_private.has_permission('organization.manage') or boss_private.has_permission('organization.manage',u.organization_id,u.id) then 'unit.update' end,
          case when u.status='active' and (org_manage or boss_private.has_permission('organization.manage',u.organization_id,u.id)) then 'season.create' end,
          case when u.status='active' and (team_manage or boss_private.has_permission('team.manage',u.organization_id,u.id)) then 'team.create' end
        ],null)) item from public.organization_units u where u.organization_id=p_organization_id order by u.sort_order,u.name,u.id limit 100
    ) s;
    if boss_private.has_permission('organization.view') then rows:=boss_private.admin_platform_records('units',p_organization_id); end if;
    records:=records||jsonb_build_object('units',rows);
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(s.id,s.name,s.status,jsonb_build_object('organization_id',s.organization_id,'parent_unit_id',s.parent_unit_id,'name',s.name,'starts_on',s.starts_on,'ends_on',s.ends_on),
        case when boss_private.has_permission('organization.manage') or boss_private.has_permission('organization.manage',s.organization_id,s.parent_unit_id) then array['season.update'] else '{}'::text[] end) item
      from public.seasons s where s.organization_id=p_organization_id order by s.created_at desc,s.id limit 100
    ) s;
    records:=records||jsonb_build_object('seasons',rows);
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(t.id,t.name,t.status,jsonb_build_object('organization_id',t.organization_id,'parent_unit_id',t.parent_unit_id,'season_id',t.season_id,'name',t.name,'short_name',t.short_name,'slug',t.slug,'visibility',t.visibility),
        array_remove(array[
          case when boss_private.has_permission('team.manage') or boss_private.has_permission('team.manage',t.organization_id,t.parent_unit_id,t.id) then 'team.update' end,
          case when boss_private.has_permission('team.roster.manage') or boss_private.has_permission('team.roster.manage',t.organization_id,t.parent_unit_id,t.id) then 'team_membership.add' end,
          case when boss_private.has_permission('roles.assign') or boss_private.has_permission('roles.assign',t.organization_id,t.parent_unit_id,t.id) then 'role_assignment.add' end
        ],null)) item from public.teams t where t.organization_id=p_organization_id order by t.name,t.id limit 100
    ) s;
    if boss_private.has_permission('team.view') then rows:=boss_private.admin_platform_records('teams',p_organization_id); end if;
    records:=records||jsonb_build_object('teams',rows);
    if p_view='organizations' then
      select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
        select boss_private.admin_record(m.id,m.name,m.status,jsonb_build_object('module_id',m.id,'module_key',m.key,
          'activation_status',case when boss_private.organization_module_active(p_organization_id,m.key) then 'active' else 'inactive' end,
          'implementation_status',case when m.key='calendar' then 'Implemented: Events and calendar' when m.key='registration' then 'Implemented: Registration, forms and private documents' when m.key='messaging' then 'Implemented: Communications and notifications' when m.key='volunteers' then 'Implemented: Volunteer coordination' else 'Future / not implemented' end),case when org_manage then array['module.set'] else '{}'::text[] end) item
        from public.modules m order by m.name,m.id
      ) s;
      records:=records||jsonb_build_object('modules',rows);
    end if;
    if p_view in ('teams','access') then
      select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
        select boss_private.admin_record(m.id,coalesce(pr->>'label','Member')||' / '||m.membership_type,m.status,
          jsonb_build_object('organization_id',m.organization_id,'team_id',m.team_id,'person_id',m.person_id,'participant_id',m.participant_id,
            'membership_type',m.membership_type,'starts_at',m.starts_at,'ends_at',m.ends_at,'jersey_number',m.jersey_number,'position_label',m.position_label),
          case when boss_private.has_permission('team.roster.manage') or boss_private.has_resource_permission('team.roster.manage','team',m.team_id,m.organization_id)
            then array['team_membership.update'] else '{}'::text[] end) item
        from public.team_memberships m left join lateral (select p from jsonb_array_elements(records->'people') p where p->>'id'=m.person_id::text limit 1) names(pr) on true
        where m.organization_id=p_organization_id order by m.created_at desc,m.id limit 100
      ) s;
      records:=records||jsonb_build_object('team_memberships',rows);
    end if;
  end if;
  if p_view='families' then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(h.id,h.name,h.status,jsonb_build_object('name',h.name),
        case when household_manage then array['household.update','household_membership.add'] else '{}'::text[] end) item
      from public.households h where nullif(btrim(p_query),'') is null or h.name ilike '%'||p_query||'%' order by h.name,h.id limit 50
    ) s;
    records:=records||jsonb_build_object('households',rows);
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(m.id,coalesce(pr->>'label','Member')||' / '||m.relationship_type,m.status,
        jsonb_build_object('household_id',m.household_id,'person_id',m.person_id,'relationship_type',m.relationship_type,'is_primary_contact',m.is_primary_contact,'starts_at',m.starts_at,'ends_at',m.ends_at),
        case when household_manage then array['household_membership.update'] else '{}'::text[] end) item
      from public.household_memberships m left join lateral (select p from jsonb_array_elements(records->'people') p where p->>'id'=m.person_id::text limit 1) names(pr) on true
      order by m.created_at desc,m.id limit 100
    ) s;
    records:=records||jsonb_build_object('household_memberships',rows);
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(g.id,coalesce(pr->>'label','Dependent')||' / '||g.relationship_type,g.authority_status,
        jsonb_build_object('guardian_person_id',g.guardian_person_id,'dependent_person_id',g.dependent_person_id,'relationship_type',g.relationship_type,
          'authority_status',g.authority_status,'starts_at',g.starts_at,'ends_at',g.ends_at,'verified_at',g.verified_at,
          'can_register',g.can_register,'can_sign_waivers',g.can_sign_waivers,'can_view_documents',g.can_view_documents,'can_manage_payments',g.can_manage_payments,'can_manage_profile',g.can_manage_profile,'can_respond_attendance',g.can_respond_attendance),
        case when guardian_manage then array_remove(array['guardian.update',case when actor not in (g.guardian_person_id,g.dependent_person_id) then 'guardian.verify' end],null) else '{}'::text[] end) item
      from public.guardian_relationships g left join lateral (select p from jsonb_array_elements(records->'people') p where p->>'id'=g.dependent_person_id::text limit 1) names(pr) on true
      order by g.created_at desc,g.id limit 100
    ) s;
    records:=records||jsonb_build_object('guardians',rows);
  end if;
  if p_view in ('teams','access','organizations') then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(r.id,r.name,r.status,jsonb_build_object('key',r.key,'allowed_scope_types',to_jsonb(r.allowed_scope_types))) item
      from public.roles r where r.status='active' order by r.name,r.id
    ) s;
    records:=records||jsonb_build_object('roles',rows);
  end if;
  if p_view='access' then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(m.id,coalesce(pr->>'label','Member')||' / '||m.membership_type,m.status,
        jsonb_build_object('organization_id',m.organization_id,'person_id',m.person_id,'membership_type',m.membership_type,'starts_at',m.starts_at,'ends_at',m.ends_at),
        case when org_members_manage then array['organization_membership.update'] else '{}'::text[] end) item
      from public.organization_memberships m left join lateral (select p from jsonb_array_elements(records->'people') p where p->>'id'=m.person_id::text limit 1) names(pr) on true
      where p_organization_id is null or m.organization_id=p_organization_id order by m.created_at desc,m.id limit 100
    ) s;
    records:=records||jsonb_build_object('organization_memberships',rows);
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(a.id,coalesce(r.name,'Role')||' / '||a.scope_type,a.status,
        jsonb_build_object('person_id',a.person_id,'role_id',a.role_id,'scope_type',a.scope_type,'scope_id',a.scope_id,'organization_id',a.organization_id,'starts_at',a.starts_at,'ends_at',a.ends_at),
        case when boss_private.has_permission('roles.assign') or boss_private.has_resource_permission('roles.assign',a.scope_type,a.scope_id,a.organization_id)
          then array['role_assignment.update'] else '{}'::text[] end) item
      from public.role_assignments a join public.roles r on r.id=a.role_id where p_organization_id is null or a.organization_id=p_organization_id
      order by a.created_at desc,a.id limit 100
    ) s;
    records:=records||jsonb_build_object('role_assignments',rows);
  end if;
  if p_view='audit' then
    select coalesce(jsonb_agg(item),'[]'::jsonb) into rows from (
      select boss_private.admin_record(a.id,a.action,null,jsonb_build_object('action',a.action,'resource_type',a.resource_type,'resource_id',a.resource_id,
        'occurred_at',a.created_at,'organization_id',a.organization_id,'scope_type',a.scope_type,'actor',case when a.actor_person_id=actor then 'You'
          else coalesce(p.display_name,p.preferred_name,nullif(concat_ws(' ',p.first_name,p.last_name),''),'Actor '||a.actor_person_id::text,'System') end)) item
      from public.audit_events a left join public.people p on p.id=a.actor_person_id
      where p_organization_id is null or a.organization_id=p_organization_id order by a.created_at desc,a.id limit 100
    ) s;
    if boss_private.has_permission('audit.view') then rows:=boss_private.admin_platform_records('audit',p_organization_id); end if;
    records:=records||jsonb_build_object('audit',rows);
  end if;
  return jsonb_build_object('provisioned',true,'person',person,'organizations',contexts,'organizationId',p_organization_id,
    'operations',to_jsonb(ops),'navigation',to_jsonb(nav),'records',records);
end $$;

create or replace function boss_private.calendar_command(p_command jsonb,p_actor uuid,p_request uuid,p_preview boolean default false,p_replay boolean default false,p_resource uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 op text;i jsonb;k text;j jsonb;v_org uuid;v_id uuid:=coalesce(p_resource,gen_random_uuid());v_kind text;
 v_event public.events%rowtype;old_event public.events%rowtype;v_venue public.venues%rowtype;v_resource public.venue_resources%rowtype;
 old_exception public.event_occurrence_exceptions%rowtype;v_targets jsonb;v_old_targets jsonb;v_conflicts jsonb:='[]'::jsonb;
 v_version bigint;v_before jsonb;v_after jsonb;v_module uuid;v_features jsonb;v_changed_timing boolean;v_reset_count integer:=0;
 v_key timestamp;v_original record;v_can_override boolean:=false;v_occurrence_count integer;v_conflict_event public.events%rowtype;
begin
 if p_actor is distinct from boss_private.current_person_id() then raise exception 'Access denied' using errcode='PT403';end if;
 perform boss_private.calendar_validate_input(p_command,array['operation','input'],array['operation','input']);
 if jsonb_typeof(p_command->'input') is distinct from 'object' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
 op:=p_command->>'operation';i:=p_command->'input';
 if op in ('event.create','event.update') then
  perform boss_private.calendar_validate_input(i,array['organization_id','event_id','expected_version','title','description','event_type_key','start_at','end_at','timezone','all_day','arrival_at','status','visibility','publication_state','venue_id','resource_id','instructions','rsvp_mode','audience','recurrence','targets','reminders','game','override_conflicts','reset_exceptions'],array['organization_id','title','event_type_key','start_at','end_at','timezone','targets']);
  if op='event.create' and (i?'event_id' or i?'expected_version' or i?'reset_exceptions') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if op='event.update' and (not i?'event_id' or not i?'expected_version') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  v_org:=(i->>'organization_id')::uuid;v_targets:=i->'targets';
  perform boss_private.calendar_validate_targets(v_org,v_targets);
  if not boss_private.calendar_can_manage_targets(case when op='event.create' then 'events.create' else 'events.manage' end,v_org,v_targets) then raise exception 'Access denied' using errcode='PT403';end if;
  if op='event.update' then
   v_id:=(i->>'event_id')::uuid;
   select * into old_event from public.events where id=v_id and organization_id=v_org for update;
   if not found or not boss_private.calendar_can_manage_event('events.manage',v_id) then raise exception 'Access denied' using errcode='PT403';end if;
   if not p_replay and old_event.version<>(i->>'expected_version')::bigint then raise exception 'Calendar changed; reload before saving' using errcode='PT409';end if;
  elsif p_replay and not boss_private.calendar_can_manage_event('events.create',v_id) then raise exception 'Access denied' using errcode='PT403';end if;
  v_event.id:=v_id;v_event.organization_id:=v_org;v_event.title:=btrim(i->>'title');v_event.description:=i->>'description';v_event.event_type_key:=i->>'event_type_key';v_event.start_at:=(i->>'start_at')::timestamptz;v_event.end_at:=(i->>'end_at')::timestamptz;v_event.timezone:=i->>'timezone';
  v_event.all_day:=coalesce((i->>'all_day')::boolean,false);v_event.arrival_at:=(i->>'arrival_at')::timestamptz;v_event.status:=coalesce(i->>'status','scheduled');v_event.visibility:=coalesce(i->>'visibility','member');v_event.publication_state:=coalesce(i->>'publication_state','unpublished');v_event.venue_id:=(i->>'venue_id')::uuid;v_event.resource_id:=(i->>'resource_id')::uuid;v_event.instructions:=i->>'instructions';v_event.rsvp_mode:=coalesce(i->>'rsvp_mode','not_required');v_event.audience:=boss_private.calendar_validate_audience(coalesce(i->'audience','["guardians","participants"]'::jsonb));v_event.recurrence:=nullif(i->'recurrence','null'::jsonb);
  if v_event.end_at<=v_event.start_at or v_event.end_at-v_event.start_at>interval '31 days' or v_event.status not in ('draft','scheduled','confirmed','canceled','postponed','completed','archived') or v_event.visibility not in ('public','authenticated','member','restricted','private') or v_event.publication_state not in ('unpublished','published') or v_event.rsvp_mode not in ('not_required','optional','required') or not exists(select 1 from pg_catalog.pg_timezone_names where name=v_event.timezone) or not exists(select 1 from public.event_types t where t.key=v_event.event_type_key and t.status='active') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if v_event.arrival_at is not null and (v_event.arrival_at>v_event.start_at or v_event.start_at-v_event.arrival_at>interval '7 days') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if v_event.all_day and ((v_event.start_at at time zone v_event.timezone)::time<>time '00:00' or (v_event.end_at at time zone v_event.timezone)::time<>time '00:00') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if v_event.venue_id is not null and not exists(select 1 from public.venues v where v.id=v_event.venue_id and v.organization_id=v_org and v.status='active') then raise exception 'Access denied' using errcode='PT403';end if;
  if v_event.resource_id is not null and not exists(select 1 from public.venue_resources r where r.id=v_event.resource_id and r.organization_id=v_org and r.venue_id=v_event.venue_id and r.status='active') then raise exception 'Access denied' using errcode='PT403';end if;
  if v_event.recurrence is not null then
   if not boss_private.calendar_feature(v_org,'recurrence') then raise exception 'Access denied' using errcode='PT403';end if;
   perform boss_private.calendar_validate_input(v_event.recurrence,array['frequency','interval','weekdays','until','count'],array['frequency','interval']);
   if v_event.recurrence->>'frequency' not in ('daily','weekly','monthly') or (v_event.recurrence->>'interval')::integer not between 1 and 52 or (v_event.recurrence?'count')=(v_event.recurrence?'until') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   if v_event.recurrence?'count' and (v_event.recurrence->>'count')::integer not between 1 and 1000 then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   if v_event.recurrence?'until' and (v_event.recurrence->>'until' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' or (v_event.recurrence->>'until')::date<(v_event.start_at at time zone v_event.timezone)::date or (v_event.recurrence->>'until')::date>((v_event.start_at at time zone v_event.timezone)+interval '5 years')::date) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   if v_event.recurrence?'weekdays' and (v_event.recurrence->>'frequency'<>'weekly' or jsonb_array_length(v_event.recurrence->'weekdays') not between 1 and 7 or exists(select 1 from jsonb_array_elements(v_event.recurrence->'weekdays') d where jsonb_typeof(d)<>'number' or d#>>'{}' !~ '^[1-7]$') or (select count(distinct d) from jsonb_array_elements(v_event.recurrence->'weekdays') d)<>jsonb_array_length(v_event.recurrence->'weekdays')) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  end if;
  if v_event.recurrence->>'frequency'='weekly' and not(v_event.recurrence?'weekdays') then v_event.recurrence:=v_event.recurrence||jsonb_build_object('weekdays',jsonb_build_array(extract(isodow from v_event.start_at at time zone v_event.timezone)::integer));end if;
  -- Validate the complete bounded recurrence during preview as well as commit.
  -- Impossible count limits cannot produce a misleading successful preview.
  select count(*) into v_occurrence_count from boss_private.calendar_expand(v_event.start_at,v_event.end_at,v_event.timezone,v_event.recurrence,v_event.start_at,v_event.start_at+interval '5 years 1 day');
  if v_occurrence_count=0 or (v_event.recurrence?'count' and v_occurrence_count<>(v_event.recurrence->>'count')::integer) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if v_event.publication_state='published' or (op='event.update' and old_event.publication_state='published') then
   if not boss_private.calendar_feature(v_org,'public_schedules') or not boss_private.calendar_can_manage_targets('events.publish',v_org,v_targets) or (op='event.update' and not boss_private.calendar_can_manage_event('events.publish',v_id)) then raise exception 'Access denied' using errcode='PT403';end if;
  end if;
  if v_event.publication_state='published' and (v_event.visibility not in ('public','authenticated') or v_event.status in ('draft','archived')) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if i?'reminders' then
   if jsonb_array_length(i->'reminders')>8 then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   for j in select value from jsonb_array_elements(i->'reminders') loop
    perform boss_private.calendar_validate_input(j,array['minutes_before','audience','enabled'],array['minutes_before','audience','enabled']);
    if (j->>'minutes_before')::integer not between 0 and 10080 then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
    perform boss_private.calendar_validate_audience(j->'audience');
   end loop;
  end if;
  if i->'game' is not null and i->'game'<>'null'::jsonb then
   j:=i->'game';perform boss_private.calendar_validate_input(j,array['opponent_team_id','external_opponent_name','home_away','game_status'],array['home_away','game_status']);
   if v_event.event_type_key<>'game' or j->>'home_away' not in ('home','away','neutral') or j->>'game_status' not in ('scheduled','postponed','canceled','completed') or (j->>'opponent_team_id' is not null and j->>'external_opponent_name' is not null) then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   if j->>'opponent_team_id' is not null and not exists(select 1 from public.teams t where t.id=(j->>'opponent_team_id')::uuid and t.organization_id=v_org and t.status='active') then raise exception 'Access denied' using errcode='PT403';end if;
  end if;
  v_changed_timing:=op='event.update' and (old_event.start_at is distinct from v_event.start_at or old_event.end_at is distinct from v_event.end_at or old_event.timezone is distinct from v_event.timezone or old_event.recurrence is distinct from v_event.recurrence);
  if not p_replay and v_changed_timing and exists(select 1 from public.event_occurrence_exceptions x where x.event_id=v_id and x.is_active) and not coalesce((i->>'reset_exceptions')::boolean,false) then raise exception 'Series changes require explicit exception reset' using errcode='PT409';end if;
  if p_replay then return jsonb_build_object('resource_type','event','resource_id',v_id);end if;
  v_can_override:=boss_private.calendar_can_manage_targets('events.override_conflict',v_org,v_targets);
  if not p_preview then update public.organizations set updated_at=updated_at where id=v_org;end if;
  v_conflicts:=boss_private.calendar_conflicts(v_event,v_targets,case when op='event.update' then v_id end,not v_changed_timing or not coalesce((i->>'reset_exceptions')::boolean,false));
  if p_preview then return jsonb_build_object('conflicts',boss_private.calendar_safe_conflicts(v_conflicts),'has_conflicts',jsonb_array_length(v_conflicts)>0,'can_override',v_can_override);end if;
  if coalesce((i->>'override_conflicts')::boolean,false) and not v_can_override then raise exception 'Access denied' using errcode='PT403';end if;
  if jsonb_array_length(v_conflicts)>0 and not coalesce((i->>'override_conflicts')::boolean,false) then raise exception 'Calendar conflict requires authorized review' using errcode='PT409';end if;
  v_before:=case when op='event.update' then jsonb_build_object('start_at',old_event.start_at,'end_at',old_event.end_at,'status',old_event.status,'visibility',old_event.visibility,'publication_state',old_event.publication_state,'recurrence',old_event.recurrence,'version',old_event.version) end;
  v_version:=coalesce(old_event.version,0)+1;
  if op='event.create' then
   insert into public.events(id,organization_id,title,description,event_type_key,start_at,end_at,timezone,all_day,arrival_at,status,visibility,publication_state,venue_id,resource_id,instructions,rsvp_mode,audience,recurrence,created_by_person_id,updated_by_person_id,version,published_at,archived_at)
   values(v_id,v_org,v_event.title,v_event.description,v_event.event_type_key,v_event.start_at,v_event.end_at,v_event.timezone,v_event.all_day,v_event.arrival_at,v_event.status,v_event.visibility,v_event.publication_state,v_event.venue_id,v_event.resource_id,v_event.instructions,v_event.rsvp_mode,v_event.audience,v_event.recurrence,p_actor,p_actor,v_version,case when v_event.publication_state='published' then now() end,case when v_event.status='archived' then now() end);
  else
   select coalesce(jsonb_agg(jsonb_build_object('target_type',t.target_type,'target_id',t.target_id) order by t.target_type,t.target_id),'[]'::jsonb) into v_old_targets from public.event_targets t where t.event_id=v_id;
   v_before:=v_before||jsonb_build_object('targets',v_old_targets);
   if v_changed_timing and coalesce((i->>'reset_exceptions')::boolean,false) then
    update public.event_occurrence_exceptions set is_active=false,updated_by_person_id=p_actor,updated_at=now(),version=version+1 where event_id=v_id and is_active;
    get diagnostics v_reset_count=row_count;
   end if;
   update public.events set title=v_event.title,description=v_event.description,event_type_key=v_event.event_type_key,start_at=v_event.start_at,end_at=v_event.end_at,timezone=v_event.timezone,all_day=v_event.all_day,arrival_at=v_event.arrival_at,status=v_event.status,visibility=v_event.visibility,publication_state=v_event.publication_state,venue_id=v_event.venue_id,resource_id=v_event.resource_id,instructions=v_event.instructions,rsvp_mode=v_event.rsvp_mode,audience=v_event.audience,recurrence=v_event.recurrence,updated_by_person_id=p_actor,updated_at=now(),version=v_version,published_at=case when v_event.publication_state='published' then coalesce(published_at,now()) else null end,archived_at=case when v_event.status='archived' then coalesce(archived_at,now()) else archived_at end where id=v_id;
   delete from public.event_targets where event_id=v_id;delete from public.event_reminders where event_id=v_id;delete from public.event_game_details where event_id=v_id;
  end if;
  insert into public.event_targets(event_id,organization_id,target_type,target_id) select v_id,v_org,x->>'target_type',(x->>'target_id')::uuid from jsonb_array_elements(v_targets) x;
  insert into public.event_reminders(event_id,organization_id,minutes_before,audience,enabled) select v_id,v_org,(x->>'minutes_before')::integer,boss_private.calendar_validate_audience(x->'audience'),(x->>'enabled')::boolean from jsonb_array_elements(coalesce(i->'reminders','[]'::jsonb)) x;
  if i->'game' is not null and i->'game'<>'null'::jsonb then
   j:=i->'game';insert into public.event_game_details(event_id,organization_id,opponent_team_id,external_opponent_name,home_away,game_status) values(v_id,v_org,(j->>'opponent_team_id')::uuid,j->>'external_opponent_name',j->>'home_away',j->>'game_status');
  end if;
  v_kind:='event';
  v_after:=jsonb_build_object('start_at',v_event.start_at,'end_at',v_event.end_at,'status',v_event.status,'visibility',v_event.visibility,'publication_state',v_event.publication_state,'recurrence',v_event.recurrence,'targets',v_targets,'version',v_version,'exceptions_archived',v_reset_count);
 elsif op='event.exception' then
  perform boss_private.calendar_validate_input(i,array['event_id','expected_version','occurrence_key','override_start_at','override_end_at','override_arrival_at','status','title','instructions','override_conflicts'],array['event_id','expected_version','occurrence_key']);
  v_id:=(i->>'event_id')::uuid;select * into old_event from public.events where id=v_id for update;
  if not found or not boss_private.calendar_can_manage_event('events.manage',v_id) then raise exception 'Access denied' using errcode='PT403';end if;
  v_org:=old_event.organization_id;
  if old_event.recurrence is null or not boss_private.calendar_feature(v_org,'recurrence') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if not p_replay and old_event.version<>(i->>'expected_version')::bigint then raise exception 'Calendar changed; reload before saving' using errcode='PT409';end if;
  if i->>'occurrence_key' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  v_key:=(i->>'occurrence_key')::timestamp;
  select * into v_original from boss_private.calendar_expand(old_event.start_at,old_event.end_at,old_event.timezone,old_event.recurrence,(v_key at time zone old_event.timezone)-interval '1 day',(v_key at time zone old_event.timezone)+interval '32 days') o where o.occurrence_key=i->>'occurrence_key';
  if not found then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  select * into old_exception from public.event_occurrence_exceptions x where x.event_id=v_id and x.occurrence_key=i->>'occurrence_key' and x.is_active;
  v_event:=old_event;v_event.start_at:=coalesce((i->>'override_start_at')::timestamptz,old_exception.override_start_at,v_original.start_at);v_event.end_at:=coalesce((i->>'override_end_at')::timestamptz,old_exception.override_end_at,v_original.end_at);v_event.recurrence:=null;v_event.status:=coalesce(i->>'status',old_exception.status,old_event.status);
  if v_event.end_at<=v_event.start_at or v_event.end_at-v_event.start_at>interval '31 days' or v_event.status not in ('scheduled','confirmed','canceled','postponed','completed') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  -- Durable exceptions stay inside a finite review window: up to 31 days before
  -- the series anchor and five years after it (end may extend a further 31 days).
  if v_event.start_at<old_event.start_at-interval '31 days' or v_event.start_at>old_event.start_at+interval '5 years' or v_event.end_at>old_event.start_at+interval '5 years 31 days' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if old_event.all_day and ((v_event.start_at at time zone old_event.timezone)::time<>time '00:00' or (v_event.end_at at time zone old_event.timezone)::time<>time '00:00') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  v_event.arrival_at:=case when i?'override_arrival_at' then coalesce((i->>'override_arrival_at')::timestamptz,case when old_event.arrival_at is not null then v_event.start_at-(old_event.start_at-old_event.arrival_at) end) else coalesce(old_exception.override_arrival_at,case when old_event.arrival_at is not null then v_event.start_at-(old_event.start_at-old_event.arrival_at) end) end;
  if v_event.arrival_at is not null and (v_event.arrival_at>v_event.start_at or v_event.start_at-v_event.arrival_at>interval '7 days') then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if old_event.publication_state='published' and not boss_private.calendar_can_manage_event('events.publish',v_id) then raise exception 'Access denied' using errcode='PT403';end if;
  if p_replay then return jsonb_build_object('resource_type','event','resource_id',v_id);end if;
  select jsonb_agg(jsonb_build_object('target_type',target_type,'target_id',target_id) order by target_type,target_id) into v_targets from public.event_targets where event_id=v_id;
  v_can_override:=boss_private.calendar_can_manage_targets('events.override_conflict',v_org,v_targets);
  if not p_preview then update public.organizations set updated_at=updated_at where id=v_org;end if;
  v_conflict_event:=v_event;
  if old_event.status in ('draft','canceled','postponed','completed','archived') then v_conflict_event.status:=old_event.status;end if;
  v_conflicts:=boss_private.calendar_conflicts(v_conflict_event,v_targets,v_id,false);
  -- A rescheduled exception may also collide with another slot of its own series.
  if v_conflict_event.status in ('scheduled','confirmed') and boss_private.calendar_feature(v_org,'conflicts') and exists(select 1 from boss_private.calendar_occurrences(old_event,v_event.start_at-interval '31 days',v_event.end_at+interval '1 day') o where o.occurrence_key<>i->>'occurrence_key' and o.status in ('scheduled','confirmed') and tstzrange(o.start_at,o.end_at,'[)') && tstzrange(v_event.start_at,v_event.end_at,'[)')) then
   v_conflicts:=v_conflicts||jsonb_build_array(jsonb_build_object('kind','team','event_id',v_id,'title',old_event.title,'start_at',v_event.start_at,'end_at',v_event.end_at));
  end if;
  if p_preview then return jsonb_build_object('conflicts',boss_private.calendar_safe_conflicts(v_conflicts),'has_conflicts',jsonb_array_length(v_conflicts)>0,'can_override',v_can_override);end if;
  if coalesce((i->>'override_conflicts')::boolean,false) and not v_can_override then raise exception 'Access denied' using errcode='PT403';end if;
  if jsonb_array_length(v_conflicts)>0 and not coalesce((i->>'override_conflicts')::boolean,false) then raise exception 'Calendar conflict requires authorized review' using errcode='PT409';end if;
  v_before:=jsonb_build_object('occurrence_key',i->>'occurrence_key','start_at',coalesce(old_exception.override_start_at,v_original.start_at),'end_at',coalesce(old_exception.override_end_at,v_original.end_at),'status',coalesce(old_exception.status,old_event.status),'version',old_event.version);
  if old_exception.id is not null then
   update public.event_occurrence_exceptions set override_start_at=v_event.start_at,override_end_at=v_event.end_at,override_arrival_at=case when i?'override_arrival_at' then (i->>'override_arrival_at')::timestamptz else old_exception.override_arrival_at end,status=v_event.status,title=case when i?'title' then i->>'title' else old_exception.title end,instructions=case when i?'instructions' then i->>'instructions' else old_exception.instructions end,updated_by_person_id=p_actor,updated_at=now(),version=version+1 where id=old_exception.id;
  else
   insert into public.event_occurrence_exceptions(event_id,organization_id,occurrence_key,override_start_at,override_end_at,override_arrival_at,status,title,instructions,created_by_person_id,updated_by_person_id) values(v_id,v_org,i->>'occurrence_key',v_event.start_at,v_event.end_at,(i->>'override_arrival_at')::timestamptz,v_event.status,i->>'title',i->>'instructions',p_actor,p_actor);
  end if;
  v_version:=old_event.version+1;update public.events set version=v_version,updated_at=now(),updated_by_person_id=p_actor where id=v_id;
  v_kind:='event';v_after:=jsonb_build_object('occurrence_key',i->>'occurrence_key','start_at',v_event.start_at,'end_at',v_event.end_at,'status',v_event.status,'version',v_version);
 elsif op in ('venue.create','venue.update') then
  perform boss_private.calendar_validate_input(i,array['organization_id','venue_id','expected_version','name','address_line1','address_line2','city','region','postal_code','country_code','timezone','instructions','status','is_public'],array['organization_id','name','timezone']);
  v_org:=(i->>'organization_id')::uuid;
  if not boss_private.calendar_can_target('events.manage',v_org,'organization',v_org) then raise exception 'Access denied' using errcode='PT403';end if;
  if op='venue.update' then
   if not i?'venue_id' or not i?'expected_version' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   v_id:=(i->>'venue_id')::uuid;select * into v_venue from public.venues where id=v_id and organization_id=v_org for update;
   if not found then raise exception 'Access denied' using errcode='PT403';end if;
   if not p_replay and v_venue.version<>(i->>'expected_version')::bigint then raise exception 'Calendar changed; reload before saving' using errcode='PT409';end if;
  elsif i?'venue_id' or i?'expected_version' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if coalesce(i->>'status','active') not in ('active','inactive') or not exists(select 1 from pg_catalog.pg_timezone_names where name=i->>'timezone') or (coalesce((i->>'is_public')::boolean,false) and (not boss_private.calendar_feature(v_org,'public_schedules') or not boss_private.calendar_can_target('events.publish',v_org,'organization',v_org))) or (op='venue.update' and v_venue.is_public and not boss_private.calendar_can_target('events.publish',v_org,'organization',v_org)) then raise exception 'Access denied' using errcode='PT403';end if;
  if p_replay then return jsonb_build_object('resource_type','venue','resource_id',v_id);end if;
  if p_preview then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  update public.organizations set updated_at=updated_at where id=v_org;
  v_version:=coalesce(v_venue.version,0)+1;
  if op='venue.create' then
   insert into public.venues(id,organization_id,name,address_line1,address_line2,city,region,postal_code,country_code,timezone,instructions,status,is_public,created_by_person_id,updated_by_person_id,version) values(v_id,v_org,btrim(i->>'name'),i->>'address_line1',i->>'address_line2',i->>'city',i->>'region',i->>'postal_code',i->>'country_code',i->>'timezone',i->>'instructions',coalesce(i->>'status','active'),coalesce((i->>'is_public')::boolean,false),p_actor,p_actor,v_version);
  else
   update public.venues set name=btrim(i->>'name'),address_line1=i->>'address_line1',address_line2=i->>'address_line2',city=i->>'city',region=i->>'region',postal_code=i->>'postal_code',country_code=i->>'country_code',timezone=i->>'timezone',instructions=i->>'instructions',status=coalesce(i->>'status','active'),is_public=coalesce((i->>'is_public')::boolean,false),updated_by_person_id=p_actor,updated_at=now(),version=v_version where id=v_id;
  end if;
  v_kind:='venue';v_after:=jsonb_build_object('status',coalesce(i->>'status','active'),'is_public',coalesce((i->>'is_public')::boolean,false),'version',v_version);
 elsif op in ('resource.create','resource.update') then
  perform boss_private.calendar_validate_input(i,array['organization_id','resource_id','venue_id','expected_version','name','resource_type','status','is_public'],array['organization_id','venue_id','name','resource_type']);
  v_org:=(i->>'organization_id')::uuid;
  if not boss_private.calendar_can_target('events.manage',v_org,'organization',v_org) then raise exception 'Access denied' using errcode='PT403';end if;
  if op='resource.update' then
   if not i?'resource_id' or not i?'expected_version' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
   v_id:=(i->>'resource_id')::uuid;select * into v_resource from public.venue_resources where id=v_id and organization_id=v_org for update;
   if not found then raise exception 'Access denied' using errcode='PT403';end if;
   if not p_replay and v_resource.version<>(i->>'expected_version')::bigint then raise exception 'Calendar changed; reload before saving' using errcode='PT409';end if;
   if v_resource.venue_id<>(i->>'venue_id')::uuid then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  elsif i?'resource_id' or i?'expected_version' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  if not exists(select 1 from public.venues v where v.id=(i->>'venue_id')::uuid and v.organization_id=v_org and v.status='active') then raise exception 'Access denied' using errcode='PT403';end if;
  if coalesce(i->>'status','active') not in ('active','inactive') or (coalesce((i->>'is_public')::boolean,false) and (not boss_private.calendar_feature(v_org,'public_schedules') or not boss_private.calendar_can_target('events.publish',v_org,'organization',v_org))) or (op='resource.update' and v_resource.is_public and not boss_private.calendar_can_target('events.publish',v_org,'organization',v_org)) then raise exception 'Access denied' using errcode='PT403';end if;
  if p_replay then return jsonb_build_object('resource_type','venue_resource','resource_id',v_id);end if;
  if p_preview then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  update public.organizations set updated_at=updated_at where id=v_org;
  v_version:=coalesce(v_resource.version,0)+1;
  if op='resource.create' then
   insert into public.venue_resources(id,organization_id,venue_id,name,resource_type,status,is_public,created_by_person_id,updated_by_person_id,version) values(v_id,v_org,(i->>'venue_id')::uuid,btrim(i->>'name'),i->>'resource_type',coalesce(i->>'status','active'),coalesce((i->>'is_public')::boolean,false),p_actor,p_actor,v_version);
  else
   update public.venue_resources set name=btrim(i->>'name'),resource_type=i->>'resource_type',status=coalesce(i->>'status','active'),is_public=coalesce((i->>'is_public')::boolean,false),updated_by_person_id=p_actor,updated_at=now(),version=v_version where id=v_id;
  end if;
  v_kind:='venue_resource';v_after:=jsonb_build_object('venue_id',i->>'venue_id','status',coalesce(i->>'status','active'),'is_public',coalesce((i->>'is_public')::boolean,false),'version',v_version);
 elsif op='calendar.configure' then
  perform boss_private.calendar_validate_input(i,array['organization_id','features'],array['organization_id','features']);
  v_org:=(i->>'organization_id')::uuid;
  if not boss_private.has_permission('organization.manage',v_org) or not boss_private.organization_module_active(v_org,'calendar') then raise exception 'Access denied' using errcode='PT403';end if;
  v_features:=i->'features';
  for k,j in select key,value from jsonb_each(v_features) loop
   if k not in ('organization_calendar','team_calendar','recurrence','conflicts','public_schedules','head_coach_management','conflict_overrides','attendance') or jsonb_typeof(j)<>'boolean' then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  end loop;
  if p_replay then return jsonb_build_object('resource_type','calendar_configuration','resource_id',v_org);end if;
  if p_preview then raise exception 'Invalid calendar operation' using errcode='PT422';end if;
  update public.organizations set updated_at=updated_at where id=v_org;
  select om.id,om.configuration into v_module,v_before from public.organization_modules om join public.modules m on m.id=om.module_id where om.organization_id=v_org and m.key='calendar' and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()) for update of om;
  if v_module is null then raise exception 'Access denied' using errcode='PT403';end if;
  update public.organization_modules set configuration=coalesce(configuration,'{}'::jsonb)||v_features where id=v_module;
  v_id:=v_org;v_kind:='calendar_configuration';v_after:=v_features;v_version:=1;
 else raise exception 'Invalid calendar operation' using errcode='PT422';
 end if;
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,before_data,after_data)
 values(v_org,p_actor,auth.uid(),op,v_kind,v_id,'organization',v_org,p_request,v_before,v_after||jsonb_build_object('fields',(select jsonb_agg(key order by key) from jsonb_object_keys(i) key)));
 if jsonb_array_length(v_conflicts)>0 then
  insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
  values(v_org,p_actor,auth.uid(),'event.conflict_override','event',v_id,'organization',v_org,p_request,jsonb_build_object('conflicts',(select jsonb_agg(jsonb_build_object('event_id',x->'event_id','kind',x->'kind','start_at',x->'start_at','end_at',x->'end_at')) from jsonb_array_elements(v_conflicts) x)));
 end if;
 return jsonb_build_object('resource_type',v_kind,'resource_id',v_id,'version',v_version);
end;$$;


-- New helpers and historical implementation copies are never Data API entries.
DO $$declare f record;begin
 for f in select p.oid::regprocedure signature from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
 where n.nspname='boss_private' and(p.proname like '%_phase4a' or p.proname in(
 'volunteer_context_at','volunteer_reminder_context','volunteer_event_notification_recipient','volunteer_coordinator_at','volunteer_announce','attendance_notification_ingest','volunteer_notification_audit_ingest','volunteer_prepare_reminders'))
 loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);end loop;
end $$;


-- Extend the existing guardian dispatcher with one independently verified flag.
create or replace function boss_private.admin_mutate_command(p_operation text,i jsonb,p_actor uuid,p_request uuid,p_check_only boolean default false,p_created_id uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  r record; v_id uuid:=coalesce((i->>'id')::uuid,p_created_id,gen_random_uuid());
  v_org uuid;v_unit uuid;v_team uuid;v_person uuid;v_anchor uuid;v_role uuid;
  v_scope text;v_type text;v_key text;v_start timestamptz;v_end timestamptz;v_status text;
  v_uid uuid;v_account uuid;v_email text;v_existing uuid;
begin
  if p_actor is distinct from boss_private.current_person_id() then
    raise exception 'Access denied' using errcode='PT403';
  end if;
  case p_operation
  when 'person.create' then
    perform boss_private.admin_validate_input(i,array['first_name','middle_name','last_name','preferred_name','display_name','status']::text[],array[]::text[]);
    v_type:='person';
    perform boss_private.admin_require_permission('person.profile.manage');
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    insert into public.people(id,first_name,middle_name,last_name,preferred_name,display_name,status) values(v_id,(i->>'first_name')::text,(i->>'middle_name')::text,(i->>'last_name')::text,(i->>'preferred_name')::text,(i->>'display_name')::text,coalesce((i->>'status')::text,'active'));
    v_person:=v_id;
  when 'person.update' then
    perform boss_private.admin_validate_input(i,array['id','first_name','middle_name','last_name','preferred_name','display_name','status']::text[],array['id']::text[]);
    v_type:='person';
    select * into r from public.people where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    if not boss_private.has_permission('person.profile.manage') then if not boss_private.can_manage_dependent_profile(v_id) or i?'status' then raise exception 'Access denied' using errcode='PT403'; end if; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    update public.people set first_name=case when i?'first_name' then (i->>'first_name')::text else r.first_name end,middle_name=case when i?'middle_name' then (i->>'middle_name')::text else r.middle_name end,last_name=case when i?'last_name' then (i->>'last_name')::text else r.last_name end,preferred_name=case when i?'preferred_name' then (i->>'preferred_name')::text else r.preferred_name end,display_name=case when i?'display_name' then (i->>'display_name')::text else r.display_name end,status=case when i?'status' then (i->>'status')::text else r.status end where id=v_id;
    v_person:=v_id;
  when 'organization.create' then
    perform boss_private.admin_validate_input(i,array['name','legal_name','slug','organization_type','status','timezone','country','default_currency']::text[],array['name','slug']::text[]);
    v_type:='organization';
    perform boss_private.admin_require_permission('organization.manage');
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if i?'timezone' and not exists(select 1 from pg_catalog.pg_timezone_names where name=i->>'timezone') then raise exception 'Invalid operation' using errcode='PT422'; end if;
    insert into public.organizations(id,name,legal_name,slug,organization_type,status,timezone,country,default_currency) values(v_id,(i->>'name')::text,(i->>'legal_name')::text,(i->>'slug')::text,coalesce((i->>'organization_type')::text,'organization'),coalesce((i->>'status')::text,'active'),coalesce((i->>'timezone')::text,'UTC'),(i->>'country')::text,(i->>'default_currency')::text);
    v_org:=v_id;
  when 'organization.update' then
    perform boss_private.admin_validate_input(i,array['id','name','legal_name','slug','organization_type','status','timezone','country','default_currency']::text[],array['id']::text[]);
    v_type:='organization';
    select * into r from public.organizations where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_org:=v_id; perform boss_private.admin_require_permission('organization.manage',v_org);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if i?'timezone' and not exists(select 1 from pg_catalog.pg_timezone_names where name=i->>'timezone') then raise exception 'Invalid operation' using errcode='PT422'; end if;
    update public.organizations set name=case when i?'name' then (i->>'name')::text else r.name end,legal_name=case when i?'legal_name' then (i->>'legal_name')::text else r.legal_name end,slug=case when i?'slug' then (i->>'slug')::text else r.slug end,organization_type=case when i?'organization_type' then (i->>'organization_type')::text else r.organization_type end,status=case when i?'status' then (i->>'status')::text else r.status end,timezone=case when i?'timezone' then (i->>'timezone')::text else r.timezone end,country=case when i?'country' then (i->>'country')::text else r.country end,default_currency=case when i?'default_currency' then (i->>'default_currency')::text else r.default_currency end where id=v_id;
    v_org:=v_id;
  when 'unit.create' then
    perform boss_private.admin_validate_input(i,array['organization_id','parent_unit_id','unit_type','name','slug','status','sort_order']::text[],array['organization_id','unit_type','name','slug']::text[]);
    v_type:='organization_unit';
    v_org:=(i->>'organization_id')::uuid; perform boss_private.admin_require_permission('organization.manage',v_org);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if not exists(select 1 from public.organizations where id=v_org) then raise exception 'Access denied' using errcode='PT403'; end if; if i->>'parent_unit_id' is not null and not exists(select 1 from public.organization_units where id=(i->>'parent_unit_id')::uuid and organization_id=v_org and status='active') then raise exception 'Invalid operation' using errcode='PT422'; end if;
    insert into public.organization_units(id,organization_id,parent_unit_id,unit_type,name,slug,status,sort_order) values(v_id,(i->>'organization_id')::uuid,(i->>'parent_unit_id')::uuid,(i->>'unit_type')::text,(i->>'name')::text,(i->>'slug')::text,coalesce((i->>'status')::text,'active'),coalesce((i->>'sort_order')::integer,0));
    v_unit:=v_id;
  when 'unit.update' then
    perform boss_private.admin_validate_input(i,array['id','parent_unit_id','unit_type','name','slug','status','sort_order']::text[],array['id']::text[]);
    v_type:='organization_unit';
    select * into r from public.organization_units where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_org:=r.organization_id;v_unit:=v_id;perform boss_private.admin_require_permission('organization.manage',v_org,v_unit);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if i?'parent_unit_id' and (i->>'parent_unit_id')::uuid is distinct from r.parent_unit_id then perform boss_private.admin_require_permission('organization.manage',v_org,(i->>'parent_unit_id')::uuid); if i->>'parent_unit_id' is not null and not exists(select 1 from public.organization_units where id=(i->>'parent_unit_id')::uuid and organization_id=v_org and status='active') then raise exception 'Invalid operation' using errcode='PT422'; end if; end if;
    update public.organization_units set parent_unit_id=case when i?'parent_unit_id' then (i->>'parent_unit_id')::uuid else r.parent_unit_id end,unit_type=case when i?'unit_type' then (i->>'unit_type')::text else r.unit_type end,name=case when i?'name' then (i->>'name')::text else r.name end,slug=case when i?'slug' then (i->>'slug')::text else r.slug end,status=case when i?'status' then (i->>'status')::text else r.status end,sort_order=case when i?'sort_order' then (i->>'sort_order')::integer else r.sort_order end where id=v_id;
    v_unit:=v_id;
  when 'season.create' then
    perform boss_private.admin_validate_input(i,array['organization_id','parent_unit_id','name','starts_on','ends_on','status']::text[],array['organization_id','name']::text[]);
    v_type:='season';
    v_org:=(i->>'organization_id')::uuid;v_unit:=(i->>'parent_unit_id')::uuid;perform boss_private.admin_require_permission('organization.manage',v_org,v_unit);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if not exists(select 1 from public.organizations where id=v_org) or (v_unit is not null and not exists(select 1 from public.organization_units where id=v_unit and organization_id=v_org and status='active')) then raise exception 'Invalid operation' using errcode='PT422'; end if;
    insert into public.seasons(id,organization_id,parent_unit_id,name,starts_on,ends_on,status) values(v_id,(i->>'organization_id')::uuid,(i->>'parent_unit_id')::uuid,(i->>'name')::text,(i->>'starts_on')::date,(i->>'ends_on')::date,coalesce((i->>'status')::text,'pending'));
  when 'season.update' then
    perform boss_private.admin_validate_input(i,array['id','name','starts_on','ends_on','status']::text[],array['id']::text[]);
    v_type:='season';
    select * into r from public.seasons where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_org:=r.organization_id;v_unit:=r.parent_unit_id;perform boss_private.admin_require_permission('organization.manage',v_org,v_unit);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    update public.seasons set name=case when i?'name' then (i->>'name')::text else r.name end,starts_on=case when i?'starts_on' then (i->>'starts_on')::date else r.starts_on end,ends_on=case when i?'ends_on' then (i->>'ends_on')::date else r.ends_on end,status=case when i?'status' then (i->>'status')::text else r.status end where id=v_id;
  when 'team.create' then
    perform boss_private.admin_validate_input(i,array['organization_id','parent_unit_id','season_id','name','short_name','slug','status','visibility']::text[],array['organization_id','name','slug']::text[]);
    v_type:='team';
    v_org:=(i->>'organization_id')::uuid;v_unit:=(i->>'parent_unit_id')::uuid;perform boss_private.admin_require_permission('team.manage',v_org,v_unit);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if not exists(select 1 from public.organizations where id=v_org) or (v_unit is not null and not exists(select 1 from public.organization_units where id=v_unit and organization_id=v_org and status='active')) then raise exception 'Invalid operation' using errcode='PT422'; end if;if i->>'season_id' is not null and not exists(select 1 from public.seasons where id=(i->>'season_id')::uuid and organization_id=v_org and status='active' and (parent_unit_id is null or parent_unit_id is not distinct from v_unit)) then raise exception 'Invalid operation' using errcode='PT422'; end if;
    insert into public.teams(id,organization_id,parent_unit_id,season_id,name,short_name,slug,status,visibility) values(v_id,(i->>'organization_id')::uuid,(i->>'parent_unit_id')::uuid,(i->>'season_id')::uuid,(i->>'name')::text,(i->>'short_name')::text,(i->>'slug')::text,coalesce((i->>'status')::text,'pending'),coalesce((i->>'visibility')::text,'private'));
    v_team:=v_id;
  when 'team.update' then
    perform boss_private.admin_validate_input(i,array['id','name','short_name','slug','status','visibility']::text[],array['id']::text[]);
    v_type:='team';
    select * into r from public.teams where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_org:=r.organization_id;v_unit:=r.parent_unit_id;v_team:=v_id;perform boss_private.admin_require_permission('team.manage',v_org,v_unit,v_team);
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    update public.teams set name=case when i?'name' then (i->>'name')::text else r.name end,short_name=case when i?'short_name' then (i->>'short_name')::text else r.short_name end,slug=case when i?'slug' then (i->>'slug')::text else r.slug end,status=case when i?'status' then (i->>'status')::text else r.status end,visibility=case when i?'visibility' then (i->>'visibility')::text else r.visibility end where id=v_id;
    v_team:=v_id;
  when 'household.create' then
    perform boss_private.admin_validate_input(i,array['name','status']::text[],array['name']::text[]);
    v_type:='household';
    perform boss_private.admin_require_permission('household.manage');
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    insert into public.households(id,name,status) values(v_id,(i->>'name')::text,coalesce((i->>'status')::text,'active'));
    v_scope:='household';v_anchor:=v_id;
  when 'participant.create' then
    perform boss_private.admin_validate_input(i,array['person_id','participant_type','status','organization_id']::text[],array['person_id']::text[]);
    v_type:='participant';
    v_person:=(i->>'person_id')::uuid;select c.organization_id,c.organization_unit_id,c.team_id into v_org,v_unit,v_team from boss_private.admin_participant_context(v_person,(i->>'organization_id')::uuid) c;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    insert into public.participants(id,person_id,participant_type,status) values(v_id,(i->>'person_id')::uuid,coalesce((i->>'participant_type')::text,'participant'),coalesce((i->>'status')::text,'active'));
  when 'household.update' then
    perform boss_private.admin_validate_input(i,array['id','name','status']::text[],array['id']::text[]);
    v_type:='household';
    select * into r from public.households where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    perform boss_private.admin_require_permission('household.manage');
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    update public.households set name=case when i?'name' then (i->>'name')::text else r.name end,status=case when i?'status' then (i->>'status')::text else r.status end where id=v_id;
    v_scope:='household';v_anchor:=v_id;
  when 'participant.update' then
    perform boss_private.admin_validate_input(i,array['id','participant_type','status','organization_id']::text[],array['id']::text[]);
    v_type:='participant';
    select * into r from public.participants where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_person:=r.person_id;select c.organization_id,c.organization_unit_id,c.team_id into v_org,v_unit,v_team from boss_private.admin_participant_context(v_person,(i->>'organization_id')::uuid) c;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    
    update public.participants set participant_type=case when i?'participant_type' then (i->>'participant_type')::text else r.participant_type end,status=case when i?'status' then (i->>'status')::text else r.status end where id=v_id;
  when 'organization_membership.add' then
    perform boss_private.admin_validate_input(i,array['organization_id','person_id','membership_type','starts_at','status','ends_at']::text[],array['organization_id','person_id']::text[]);
    v_type:='organization_membership';
    v_person:=(i->>'person_id')::uuid;v_anchor:=(i->>'organization_id')::uuid;v_org:=v_anchor;perform boss_private.admin_require_permission('organization.members.manage',v_org);if not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=coalesce((i->>'starts_at')::timestamptz,now());v_end:=(i->>'ends_at')::timestamptz;v_status:=coalesce(i->>'status','active'); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.organizations set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('organization_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.organization_memberships m where m.organization_id=v_anchor and m.person_id=v_person and m.membership_type=coalesce(i->>'membership_type','member') and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    insert into public.organization_memberships(id,organization_id,person_id,membership_type,starts_at,status,ends_at) values(v_id,(i->>'organization_id')::uuid,(i->>'person_id')::uuid,coalesce((i->>'membership_type')::text,'member'),coalesce((i->>'starts_at')::timestamptz,now()),coalesce((i->>'status')::text,'active'),(i->>'ends_at')::timestamptz);
  when 'organization_membership.update' then
    perform boss_private.admin_validate_input(i,array['id','status','ends_at']::text[],array['id']::text[]);
    v_type:='organization_membership';
    select * into r from public.organization_memberships where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_person:=r.person_id;v_anchor:=r.organization_id;v_org:=v_anchor;perform boss_private.admin_require_permission('organization.members.manage',v_org);if not (coalesce(i->>'status','active')<>'active' or coalesce((i->>'ends_at')::timestamptz<=now(),false)) and not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=r.starts_at;v_end:=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end;v_status:=coalesce(i->>'status',r.status); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.organizations set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('organization_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.organization_memberships m where m.organization_id=v_anchor and m.person_id=v_person and m.membership_type=r.membership_type and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    update public.organization_memberships set status=case when i?'status' then (i->>'status')::text else r.status end,ends_at=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end where id=v_id;
  when 'team_membership.add' then
    perform boss_private.admin_validate_input(i,array['team_id','person_id','membership_type','starts_at','status','ends_at','participant_id','jersey_number','position_label']::text[],array['team_id','person_id']::text[]);
    v_type:='team_membership';
    v_person:=(i->>'person_id')::uuid;v_anchor:=(i->>'team_id')::uuid;select organization_id,parent_unit_id into v_org,v_unit from public.teams where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403'; end if;v_team:=v_anchor;perform boss_private.admin_require_permission('team.roster.manage',v_org,v_unit,v_team);if not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=coalesce((i->>'starts_at')::timestamptz,now());v_end:=(i->>'ends_at')::timestamptz;v_status:=coalesce(i->>'status','active'); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.teams set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('team_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.team_memberships m where m.team_id=v_anchor and m.person_id=v_person and m.membership_type=coalesce(i->>'membership_type','member') and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;if (i->>'participant_id')::uuid is not null and not exists(select 1 from public.participants where id=(i->>'participant_id')::uuid and person_id=v_person and status='active') then raise exception 'Invalid operation' using errcode='PT422';end if; if coalesce(i->>'membership_type','member')='athlete' and (i->>'participant_id')::uuid is null then raise exception 'Invalid operation' using errcode='PT422';end if;
    insert into public.team_memberships(id,team_id,person_id,membership_type,starts_at,status,ends_at,participant_id,jersey_number,position_label,organization_id) values(v_id,(i->>'team_id')::uuid,(i->>'person_id')::uuid,coalesce((i->>'membership_type')::text,'member'),coalesce((i->>'starts_at')::timestamptz,now()),coalesce((i->>'status')::text,'active'),(i->>'ends_at')::timestamptz,(i->>'participant_id')::uuid,(i->>'jersey_number')::text,(i->>'position_label')::text,v_org);
  when 'team_membership.update' then
    perform boss_private.admin_validate_input(i,array['id','status','ends_at','jersey_number','position_label']::text[],array['id']::text[]);
    v_type:='team_membership';
    select * into r from public.team_memberships where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_person:=r.person_id;v_anchor:=r.team_id;select organization_id,parent_unit_id into v_org,v_unit from public.teams where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403'; end if;v_team:=v_anchor;perform boss_private.admin_require_permission('team.roster.manage',v_org,v_unit,v_team);if not (coalesce(i->>'status','active')<>'active' or coalesce((i->>'ends_at')::timestamptz<=now(),false)) and not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=r.starts_at;v_end:=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end;v_status:=coalesce(i->>'status',r.status); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.teams set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('team_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.team_memberships m where m.team_id=v_anchor and m.person_id=v_person and m.membership_type=r.membership_type and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;if r.participant_id is not null and not exists(select 1 from public.participants where id=r.participant_id and person_id=v_person and status='active') then raise exception 'Invalid operation' using errcode='PT422';end if; if r.membership_type='athlete' and r.participant_id is null then raise exception 'Invalid operation' using errcode='PT422';end if;
    update public.team_memberships set status=case when i?'status' then (i->>'status')::text else r.status end,ends_at=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end,jersey_number=case when i?'jersey_number' then (i->>'jersey_number')::text else r.jersey_number end,position_label=case when i?'position_label' then (i->>'position_label')::text else r.position_label end where id=v_id;
  when 'household_membership.add' then
    perform boss_private.admin_validate_input(i,array['household_id','person_id','relationship_type','starts_at','status','ends_at','is_primary_contact']::text[],array['household_id','person_id']::text[]);
    v_type:='household_membership';
    v_person:=(i->>'person_id')::uuid;v_anchor:=(i->>'household_id')::uuid;perform boss_private.admin_require_permission('household.manage');if not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=coalesce((i->>'starts_at')::timestamptz,now());v_end:=(i->>'ends_at')::timestamptz;v_status:=coalesce(i->>'status','active'); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.households set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('household_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.household_memberships m where m.household_id=v_anchor and m.person_id=v_person and m.relationship_type=coalesce(i->>'relationship_type','member') and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;if v_status='active' and coalesce((i->>'is_primary_contact')::boolean,false) and exists(select 1 from public.household_memberships m where m.household_id=v_anchor and m.is_primary_contact and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    insert into public.household_memberships(id,household_id,person_id,relationship_type,starts_at,status,ends_at,is_primary_contact) values(v_id,(i->>'household_id')::uuid,(i->>'person_id')::uuid,coalesce((i->>'relationship_type')::text,'member'),coalesce((i->>'starts_at')::timestamptz,now()),coalesce((i->>'status')::text,'active'),(i->>'ends_at')::timestamptz,coalesce((i->>'is_primary_contact')::boolean,false));
    v_scope:='household';
  when 'household_membership.update' then
    perform boss_private.admin_validate_input(i,array['id','status','ends_at','is_primary_contact']::text[],array['id']::text[]);
    v_type:='household_membership';
    select * into r from public.household_memberships where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_person:=r.person_id;v_anchor:=r.household_id;perform boss_private.admin_require_permission('household.manage');if not (coalesce(i->>'status','active')<>'active' or coalesce((i->>'ends_at')::timestamptz<=now(),false)) and not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=r.starts_at;v_end:=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end;v_status:=coalesce(i->>'status',r.status); if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if; update public.households set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('household_membership:'||v_anchor::text,0)); if v_status='active' and exists(select 1 from public.household_memberships m where m.household_id=v_anchor and m.person_id=v_person and m.relationship_type=r.relationship_type and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;if v_status='active' and (case when i?'is_primary_contact' then (i->>'is_primary_contact')::boolean else r.is_primary_contact end) and exists(select 1 from public.household_memberships m where m.household_id=v_anchor and m.is_primary_contact and m.status='active' and m.id<>v_id and pg_catalog.tstzrange(m.starts_at,m.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    update public.household_memberships set status=case when i?'status' then (i->>'status')::text else r.status end,ends_at=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end,is_primary_contact=case when i?'is_primary_contact' then (i->>'is_primary_contact')::boolean else r.is_primary_contact end where id=v_id;
    v_scope:='household';
  when 'guardian.create' then
    perform boss_private.admin_validate_input(i,array['guardian_person_id','dependent_person_id','relationship_type','starts_at','authority_status','ends_at','can_register','can_sign_waivers','can_view_documents','can_manage_payments','can_manage_profile','can_respond_attendance']::text[],array['guardian_person_id','dependent_person_id']::text[]);
    v_type:='guardian_relationship';
    perform boss_private.admin_require_permission('household.manage');perform boss_private.admin_require_permission('person.profile.manage');v_person:=(i->>'dependent_person_id')::uuid;v_anchor:=(i->>'guardian_person_id')::uuid;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if v_person=v_anchor or not exists(select 1 from public.people where id=v_person and status='active') or not exists(select 1 from public.people where id=v_anchor and status='active') then raise exception 'Invalid operation' using errcode='PT422';end if;v_start:=coalesce((i->>'starts_at')::timestamptz,now());v_end:=(i->>'ends_at')::timestamptz;v_status:=coalesce(i->>'authority_status','pending');if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if;update public.people set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('guardian:'||v_anchor::text||':'||v_person::text,0));if v_status='active' and exists(select 1 from public.guardian_relationships g where g.guardian_person_id=v_anchor and g.dependent_person_id=v_person and g.relationship_type=coalesce(i->>'relationship_type','guardian') and g.authority_status='active' and g.id<>v_id and pg_catalog.tstzrange(g.starts_at,g.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    insert into public.guardian_relationships(id,guardian_person_id,dependent_person_id,relationship_type,starts_at,authority_status,ends_at,can_register,can_sign_waivers,can_view_documents,can_manage_payments,can_manage_profile,can_respond_attendance) values(v_id,(i->>'guardian_person_id')::uuid,(i->>'dependent_person_id')::uuid,coalesce((i->>'relationship_type')::text,'guardian'),coalesce((i->>'starts_at')::timestamptz,now()),coalesce((i->>'authority_status')::text,'pending'),(i->>'ends_at')::timestamptz,coalesce((i->>'can_register')::boolean,false),coalesce((i->>'can_sign_waivers')::boolean,false),coalesce((i->>'can_view_documents')::boolean,false),coalesce((i->>'can_manage_payments')::boolean,false),coalesce((i->>'can_manage_profile')::boolean,false),coalesce((i->>'can_respond_attendance')::boolean,false));
  when 'guardian.update' then
    perform boss_private.admin_validate_input(i,array['id','authority_status','ends_at','can_register','can_sign_waivers','can_view_documents','can_manage_payments','can_manage_profile','can_respond_attendance']::text[],array['id']::text[]);
    v_type:='guardian_relationship';
    select * into r from public.guardian_relationships where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    perform boss_private.admin_require_permission('household.manage');perform boss_private.admin_require_permission('person.profile.manage');v_person:=r.dependent_person_id;v_anchor:=r.guardian_person_id;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if v_person=v_anchor or (not (coalesce(i->>'authority_status','active')<>'active' or coalesce((i->>'ends_at')::timestamptz<=now(),false)) and (not exists(select 1 from public.people where id=v_person and status='active') or not exists(select 1 from public.people where id=v_anchor and status='active'))) then raise exception 'Invalid operation' using errcode='PT422';end if;v_start:=r.starts_at;v_end:=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end;v_status:=coalesce(i->>'authority_status',r.authority_status);if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if;update public.people set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('guardian:'||v_anchor::text||':'||v_person::text,0));if v_status='active' and exists(select 1 from public.guardian_relationships g where g.guardian_person_id=v_anchor and g.dependent_person_id=v_person and g.relationship_type=r.relationship_type and g.authority_status='active' and g.id<>v_id and pg_catalog.tstzrange(g.starts_at,g.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    update public.guardian_relationships set authority_status=case when i?'authority_status' then (i->>'authority_status')::text else r.authority_status end,ends_at=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end,can_register=case when i?'can_register' then (i->>'can_register')::boolean else r.can_register end,can_sign_waivers=case when i?'can_sign_waivers' then (i->>'can_sign_waivers')::boolean else r.can_sign_waivers end,can_view_documents=case when i?'can_view_documents' then (i->>'can_view_documents')::boolean else r.can_view_documents end,can_manage_payments=case when i?'can_manage_payments' then (i->>'can_manage_payments')::boolean else r.can_manage_payments end,can_manage_profile=case when i?'can_manage_profile' then (i->>'can_manage_profile')::boolean else r.can_manage_profile end,can_respond_attendance=case when i?'can_respond_attendance' then (i->>'can_respond_attendance')::boolean else r.can_respond_attendance end where id=v_id;
  when 'guardian.verify' then
    perform boss_private.admin_validate_input(i,array['id']::text[],array['id']::text[]);
    v_type:='guardian_relationship';
    select * into r from public.guardian_relationships where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    perform boss_private.admin_require_permission('household.manage');perform boss_private.admin_require_permission('person.profile.manage');v_person:=r.dependent_person_id;v_anchor:=r.guardian_person_id;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    if v_person=v_anchor or not exists(select 1 from public.people where id=v_person and status='active') or not exists(select 1 from public.people where id=v_anchor and status='active') then raise exception 'Invalid operation' using errcode='PT422';end if;if v_anchor=p_actor or v_person=p_actor then raise exception 'Access denied' using errcode='PT403';end if;
    update public.people set updated_at=updated_at where id=v_anchor; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('guardian:'||v_anchor::text||':'||v_person::text,0));
    if exists(select 1 from public.guardian_relationships g where g.guardian_person_id=v_anchor and g.dependent_person_id=v_person and g.relationship_type=r.relationship_type and g.authority_status='active' and g.id<>v_id and pg_catalog.tstzrange(g.starts_at,g.ends_at,'[)') && pg_catalog.tstzrange(r.starts_at,r.ends_at,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    update public.guardian_relationships set verified_at=statement_timestamp(),authority_status='active' where id=v_id;
  when 'role_assignment.add' then
    perform boss_private.admin_validate_input(i,array['person_id','role_id','scope_type','scope_id','organization_id','starts_at','status','ends_at']::text[],array['person_id','role_id','scope_type']::text[]);
    v_type:='role_assignment';
    v_person:=(i->>'person_id')::uuid;v_role:=(i->>'role_id')::uuid;v_scope:=i->>'scope_type';v_anchor:=(i->>'scope_id')::uuid;v_org:=(i->>'organization_id')::uuid;if v_scope='platform' then if v_anchor is not null or v_org is not null then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='organization' then if v_anchor is null or v_anchor is distinct from v_org or not exists(select 1 from public.organizations where id=v_org) then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='organization_unit' then v_unit:=v_anchor;if not exists(select 1 from public.organization_units where id=v_unit and organization_id=v_org) then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='team' then v_team:=v_anchor;select parent_unit_id into v_unit from public.teams where id=v_team and organization_id=v_org;if not found then raise exception 'Invalid operation' using errcode='PT422';end if;else raise exception 'Invalid operation' using errcode='PT422';end if;perform boss_private.admin_require_permission('roles.assign',v_org,v_unit,v_team);if not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;if not exists(select 1 from public.roles where id=v_role and status='active' and v_scope=any(allowed_scope_types)) then raise exception 'Invalid operation' using errcode='PT422';end if; for v_key in select p.key from public.role_permissions rp join public.permissions p on p.id=rp.permission_id where rp.role_id=v_role loop perform boss_private.admin_require_permission(v_key,v_org,v_unit,v_team);end loop;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=coalesce((i->>'starts_at')::timestamptz,now());v_end:=(i->>'ends_at')::timestamptz;v_status:=coalesce(i->>'status','active');if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if;update public.people set updated_at=updated_at where id=v_person; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('role:'||v_person::text||':'||v_role::text||':'||coalesce(v_anchor::text,'platform'),0));if v_status='active' and exists(select 1 from public.role_assignments a where a.person_id=v_person and a.role_id=v_role and a.scope_type=v_scope and a.scope_id is not distinct from v_anchor and a.status='active' and a.id<>v_id and pg_catalog.tstzrange(a.starts_at,a.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    insert into public.role_assignments(id,person_id,role_id,scope_type,scope_id,organization_id,starts_at,status,ends_at,granted_by_person_id) values(v_id,(i->>'person_id')::uuid,(i->>'role_id')::uuid,(i->>'scope_type')::text,(i->>'scope_id')::uuid,(i->>'organization_id')::uuid,coalesce((i->>'starts_at')::timestamptz,now()),coalesce((i->>'status')::text,'active'),(i->>'ends_at')::timestamptz,p_actor);
  when 'role_assignment.update' then
    perform boss_private.admin_validate_input(i,array['id','status','ends_at']::text[],array['id']::text[]);
    v_type:='role_assignment';
    select * into r from public.role_assignments where id=v_id for update;if not found then raise exception 'Access denied' using errcode='PT403';end if;
    v_person:=r.person_id;v_role:=r.role_id;v_scope:=r.scope_type;v_anchor:=r.scope_id;v_org:=r.organization_id;if v_scope='platform' then if v_anchor is not null or v_org is not null then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='organization' then if v_anchor is null or v_anchor is distinct from v_org or not exists(select 1 from public.organizations where id=v_org) then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='organization_unit' then v_unit:=v_anchor;if not exists(select 1 from public.organization_units where id=v_unit and organization_id=v_org) then raise exception 'Invalid operation' using errcode='PT422';end if;elsif v_scope='team' then v_team:=v_anchor;select parent_unit_id into v_unit from public.teams where id=v_team and organization_id=v_org;if not found then raise exception 'Invalid operation' using errcode='PT422';end if;else raise exception 'Invalid operation' using errcode='PT422';end if;perform boss_private.admin_require_permission('roles.assign',v_org,v_unit,v_team);if not (coalesce(i->>'status','active')<>'active' or coalesce((i->>'ends_at')::timestamptz<=now(),false)) and not boss_private.admin_person_in_context(v_person,v_org,v_team) then raise exception 'Access denied' using errcode='PT403'; end if;if not exists(select 1 from public.roles where id=v_role and status='active' and v_scope=any(allowed_scope_types)) then raise exception 'Invalid operation' using errcode='PT422';end if; for v_key in select p.key from public.role_permissions rp join public.permissions p on p.id=rp.permission_id where rp.role_id=v_role loop perform boss_private.admin_require_permission(v_key,v_org,v_unit,v_team);end loop;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    v_start:=r.starts_at;v_end:=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end;v_status:=coalesce(i->>'status',r.status);if v_end is not null and v_end<=v_start then raise exception 'Invalid operation' using errcode='PT422';end if;update public.people set updated_at=updated_at where id=v_person; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('role:'||v_person::text||':'||v_role::text||':'||coalesce(v_anchor::text,'platform'),0));if v_status='active' and exists(select 1 from public.role_assignments a where a.person_id=v_person and a.role_id=v_role and a.scope_type=v_scope and a.scope_id is not distinct from v_anchor and a.status='active' and a.id<>v_id and pg_catalog.tstzrange(a.starts_at,a.ends_at,'[)') && pg_catalog.tstzrange(v_start,v_end,'[)')) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    update public.role_assignments set status=case when i?'status' then (i->>'status')::text else r.status end,ends_at=case when i?'ends_at' then (i->>'ends_at')::timestamptz else r.ends_at end where id=v_id;

  when 'account.link' then
    perform boss_private.admin_validate_input(i,array['person_id','auth_user_id'],array['person_id','auth_user_id']);
    perform boss_private.admin_require_permission('person.profile.manage');
    v_type:='user_account';v_person:=(i->>'person_id')::uuid;v_uid:=(i->>'auth_user_id')::uuid;
    if not exists(select 1 from public.people where id=v_person and status='active') or not exists(select 1 from auth.users where id=v_uid and email_confirmed_at is not null and not coalesce(is_anonymous,false) and deleted_at is null and (banned_until is null or banned_until<=now())) then raise exception 'Invalid operation' using errcode='PT422';end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('auth-link:'||v_uid::text,0));
    select id,person_id into v_account,v_existing from public.user_accounts where auth_user_id=v_uid;
    if found then
      if v_existing<>v_person then raise exception 'Conflicting operation' using errcode='PT409';end if;
      v_id:=v_account;
      return jsonb_build_object('resource_type',v_type,'resource_id',v_id);
    end if;
    if exists(select 1 from public.user_accounts where person_id=v_person and account_status='active') then raise exception 'Conflicting operation' using errcode='PT409';end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    insert into public.user_accounts(id,auth_user_id,person_id,account_status) values(v_id,v_uid,v_person,'active');
  when 'identity.provision_self' then
    perform boss_private.admin_validate_input(i,array['display_name'],array[]::text[]);
    v_uid:=boss_private.require_live_auth();v_type:='person';
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('auth-link:'||v_uid::text,0));
    select person_id into v_existing from public.user_accounts where auth_user_id=v_uid;
    if found then
      if boss_private.current_person_id() is null then raise exception 'Access denied' using errcode='PT403';end if;
      return jsonb_build_object('resource_type',v_type,'resource_id',v_existing);
    end if;
    select email into v_email from auth.users where id=v_uid;
    if v_email is not null and exists(select 1 from public.people where lower(primary_email)=lower(v_email)) then raise exception 'Conflicting operation' using errcode='PT409';end if;
    if p_check_only then raise exception 'Access denied' using errcode='PT403';end if;
    insert into public.people(id,display_name) values(v_id,coalesce(i->>'display_name','Boss member'));
    insert into public.user_accounts(auth_user_id,person_id,account_status) values(v_uid,v_id,'active');
    p_actor:=v_id;v_person:=v_id;
    insert into public.audit_events(actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
      values(p_actor,v_uid,'account.link','user_account',(select id from public.user_accounts where auth_user_id=v_uid),'person',v_id,p_request,jsonb_build_object('fields',jsonb_build_array('auth_user_id','person_id','account_status')));
  when 'module.set' then
    perform boss_private.admin_validate_input(i,array['organization_id','module_id','status'],array['organization_id','module_id','status']);
    v_org:=(i->>'organization_id')::uuid;v_anchor:=(i->>'module_id')::uuid;v_type:='organization_module';
    perform boss_private.admin_require_permission('organization.manage',v_org);
    if not exists(select 1 from public.organizations where id=v_org) or not exists(select 1 from public.modules where id=v_anchor and status='active') or i->>'status' not in ('active','inactive') then raise exception 'Invalid operation' using errcode='PT422';end if;
    if p_check_only then return jsonb_build_object('resource_type',v_type,'resource_id',v_id);end if;
    update public.organizations set updated_at=updated_at where id=v_org; if not found then raise exception 'Access denied' using errcode='PT403';end if; perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('module:'||v_org::text||':'||v_anchor::text,0));
    select id into v_existing from public.organization_modules where organization_id=v_org and module_id=v_anchor and starts_at<=now() and (ends_at is null or ends_at>now()) order by starts_at desc limit 1 for update;
    if found then v_id:=v_existing;update public.organization_modules set status=i->>'status' where id=v_id;
    else insert into public.organization_modules(id,organization_id,module_id,status,source) values(v_id,v_org,v_anchor,i->>'status','operational_admin');end if;
  else raise exception 'Invalid operation' using errcode='PT422';
  end case;
  if v_scope is null or v_scope not in ('household') then
    if v_team is not null then v_scope:='team';v_anchor:=v_team;
    elsif v_unit is not null then v_scope:='organization_unit';v_anchor:=v_unit;
    elsif v_org is not null then v_scope:='organization';v_anchor:=v_org;
    elsif v_person is not null then v_scope:='person';v_anchor:=v_person;
    else v_scope:='platform';v_anchor:=null;end if;
  end if;
  if v_scope in ('person','household','platform') then v_org:=null;end if;
  insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
    values(v_org,p_actor,auth.uid(),p_operation,v_type,v_id,v_scope,v_anchor,p_request,jsonb_build_object('fields',(select jsonb_agg(key order by key) from jsonb_object_keys(i) key)));
  return jsonb_build_object('resource_type',v_type,'resource_id',v_id);
end;
$$;

revoke all on function boss_private.comm_thread_manage_phase4a(uuid,uuid,text) from public,anon,authenticated,service_role;

-- A current selected-volunteer recipient may enter only its authorized organization.
create or replace function boss_private.comm_read(p_query jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;org uuid;tid uuid;team uuid;before_seq bigint;q text;view_name text;orgs jsonb;threads jsonb;msgs jsonb;detail jsonb;features jsonb:='{}';ops text[]:='{}';
 candidates jsonb:='[]';teams jsonb:='[]';units jsonb:='[]';targets jsonb:='[]';reports jsonb:='[]';guardians jsonb:='[]';audience_roles jsonb:='[]';households jsonb:='[]';unread jsonb;key text;more boolean:=false;cursor bigint;
begin
 actor:=boss_private.require_admin_actor();perform boss_private.comm_validate(p_query,array['organization_id','thread_id','team_id','view','before_sequence','query']);
 org:=(p_query->>'organization_id')::uuid;tid:=(p_query->>'thread_id')::uuid;team:=(p_query->>'team_id')::uuid;before_seq:=(p_query->>'before_sequence')::bigint;q:=nullif(btrim(p_query->>'query'),'');view_name:=coalesce(p_query->>'view','messages');
 if length(coalesce(q,''))>100 or coalesce(q,'')~'[[:cntrl:]]' or view_name not in('messages','announcements','summary') or (before_seq is not null and before_seq<1) then raise exception 'Invalid request.' using errcode='PT422';end if;
 if tid is not null then if not boss_private.comm_thread_can_view(tid,actor) or (org is not null and not exists(select 1 from public.communication_threads where id=tid and organization_id=org)) then raise exception 'Access denied.' using errcode='PT403';end if;
 select organization_id into org from public.communication_threads where id=tid;end if;
 select coalesce(jsonb_agg(row),'[]') into orgs from(select jsonb_build_object('id',o.id,'label',o.name) row from public.organizations o where o.status='active' and boss_private.comm_feature(o.id,'communications') and
 (boss_private.comm_permission(actor,'communications.manage',o.id,'organization',o.id) or boss_private.comm_context_related(actor,o.id,'organization',o.id)
 or exists(select 1 from public.organization_units u where u.organization_id=o.id and boss_private.comm_permission(actor,'communications.view',o.id,'unit',u.id))
 or exists(select 1 from public.teams t where t.organization_id=o.id and boss_private.comm_permission(actor,'communications.view',o.id,'team',t.id))
 or exists(select 1 from public.communication_threads t join public.communication_audiences audience on audience.thread_id=t.id
 where t.organization_id=o.id and t.status='active' and audience.volunteer_shift_id is not null
 and boss_private.comm_audience_person(audience.id,actor) and boss_private.comm_thread_can_view(t.id,actor)))
 order by(o.id=org)desc nulls last,o.name,o.id limit 100)s;
 if org is not null and not exists(select 1 from jsonb_array_elements(orgs)o where o->>'id'=org::text) then raise exception 'Access denied.' using errcode='PT403';end if;
 if team is not null and not exists(select 1 from public.teams t where t.id=team and (org is null or t.organization_id=org) and (boss_private.comm_permission(actor,'communications.view',t.organization_id,'team',t.id) or boss_private.comm_context_related(actor,t.organization_id,'team',t.id))) then raise exception 'Access denied.' using errcode='PT403';end if;
 if org is not null then
 select coalesce(jsonb_agg(jsonb_build_object('key',r.key,'label',r.name,'allowed_scope_types',r.allowed_scope_types)),'[]') into audience_roles from public.roles r where r.status='active';
 select coalesce(jsonb_agg(row),'[]') into households from(select jsonb_build_object('id',h.id,'label',coalesce(h.name,'Household')) row from public.households h join public.household_memberships hm on hm.household_id=h.id
 where h.status='active' and hm.person_id=actor and hm.status='active' and hm.starts_at<=now() and (hm.ends_at is null or hm.ends_at>now()) and exists(select 1 from public.guardian_relationships g join public.household_memberships child on child.person_id=g.dependent_person_id and child.household_id=h.id
 where child.status='active' and child.starts_at<=now() and (child.ends_at is null or child.ends_at>now()) and boss_private.comm_guardian(actor,g.dependent_person_id,'can_receive_communications') and exists(select 1 from public.organization_memberships om where om.person_id=g.dependent_person_id and om.organization_id=org and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()))))s;
 foreach key in array array['communications','announcements','team_chat','staff_send','direct_messaging','guardian_visibility','participant_messaging','minor_groups','attachments','moderation','in_app_notifications','email_notifications'] loop features:=features||jsonb_build_object(key,boss_private.comm_feature(org,key));end loop;
 features:=features||jsonb_build_object('minimum_participant_age',boss_private.comm_policy_number(org,'minimum_participant_age'),'sender_edit_minutes',boss_private.comm_policy_number(org,'sender_edit_minutes'));
 select coalesce(jsonb_agg(row),'[]') into targets from(select jsonb_build_object('scope_type',kind,'scope_id',id,'label',label,'thread_kinds',(select coalesce(jsonb_agg(k),'[]') from unnest(array['organization_staff','program','team_chat','coach_staff','direct','group','family']) k where boss_private.comm_can_create(actor,org,k,kind,id)),'operations',to_jsonb(array_remove(array[
 case when boss_private.comm_permission(actor,'announcements.send',org,kind,id) and boss_private.comm_feature(org,'announcements') then 'announcement.send' end,
 case when (boss_private.comm_can_create(actor,org,case kind when 'organization' then 'organization_staff' when 'unit' then 'program' else 'team_chat' end,kind,id) or boss_private.comm_can_create(actor,org,'group',kind,id)) then 'thread.create' end],null))) row
 from(select 'organization' kind,o.id,o.name label from public.organizations o where o.id=org union all select 'unit',u.id,u.name from public.organization_units u where u.organization_id=org and u.status='active' union all select 'team',t.id,t.name from public.teams t where t.organization_id=org and t.status='active')sc
 where boss_private.comm_permission(actor,'announcements.send',org,kind,id) or boss_private.comm_can_create(actor,org,'group',kind,id) or boss_private.comm_permission(actor,'communications.manage',org,kind,id) order by label,id limit 100)s;
 if exists(select 1 from jsonb_array_elements(targets)t where t->'operations'?'announcement.send') then ops:=array_append(ops,'announcement.send');end if;
 if exists(select 1 from jsonb_array_elements(targets)t where t->'operations'?'thread.create') then ops:=array_append(ops,'thread.create');end if;
 if boss_private.comm_permission(actor,'communications.manage',org,'organization',org) then ops:=array_append(ops,'communications.configure');end if;
 select coalesce(jsonb_agg(row),'[]') into teams from(select jsonb_build_object('id',t.id,'label',t.name,'organization_id',t.organization_id,'parent_unit_id',t.parent_unit_id) row from public.teams t where t.organization_id=org and t.status='active' and (boss_private.comm_permission(actor,'communications.view',org,'team',t.id) or boss_private.comm_context_related(actor,org,'team',t.id)) order by t.name,t.id limit 100)s;
 select coalesce(jsonb_agg(row),'[]') into units from(select jsonb_build_object('id',u.id,'label',u.name,'organization_id',u.organization_id) row from public.organization_units u where u.organization_id=org and u.status='active' and (boss_private.comm_permission(actor,'communications.view',org,'unit',u.id) or boss_private.comm_context_related(actor,org,'unit',u.id)) order by u.name,u.id limit 100)s;
 -- Discover only through actual authorized tenant context, never a global people scan.
 select coalesce(jsonb_agg(row),'[]') into candidates from(select jsonb_build_object('id',p.id,'label',coalesce(p.display_name,p.preferred_name,'Boss member')) row from public.people p where p.status='active' and p.id<>actor and
 (exists(select 1 from public.organization_memberships m where m.person_id=p.id and m.organization_id=org and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()))
 or exists(select 1 from public.team_memberships m where m.person_id=p.id and m.organization_id=org and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()))
 or exists(select 1 from public.guardian_relationships g join public.team_memberships m on m.person_id=g.dependent_person_id where g.guardian_person_id=p.id and m.organization_id=org and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()) and boss_private.comm_guardian(p.id,m.person_id,'can_receive_communications')))
 and exists(select 1 from jsonb_array_elements(targets)a where a->'operations'?'thread.create' and boss_private.comm_context_related(p.id,org,a->>'scope_type',(a->>'scope_id')::uuid)) order by p.display_name,p.id limit 100)s;
 end if;
 -- Authorize each thread once, then aggregate all unread messages in one indexed
 -- relational query. List summaries reuse these counts instead of per-row reads.
 with authorized as materialized(select t.* from public.communication_threads t where (org is null or t.organization_id=org) and boss_private.comm_thread_can_view(t.id,actor)),
 unread_by_thread as materialized(select t.id,count(m.id)::bigint n from authorized t left join public.communication_read_state r on r.thread_id=t.id and r.person_id=actor
 left join public.communication_messages m on m.thread_id=t.id and m.status='visible' and m.author_person_id<>actor and m.sequence_number>coalesce(r.through_sequence,0) group by t.id),
 selected as(select t.id,t.updated_at,u.n from authorized t join unread_by_thread u on u.id=t.id where
 (team is null or t.team_id=team or exists(select 1 from public.communication_audiences a where a.thread_id=t.id and a.scope_type='team' and a.scope_id=team))
 and (view_name<>'announcements' or t.kind='announcement') and (view_name<>'messages' or t.kind<>'announcement') order by t.updated_at desc,t.id limit 100)
 select coalesce((select jsonb_agg(boss_private.comm_thread_summary(t.id,actor,t.n) order by t.updated_at desc,t.id) from selected t),'[]'),
 (select jsonb_build_object('messages',coalesce(sum(u.n),0),'channels',count(*) filter(where u.n>0)) from unread_by_thread u) into threads,unread;

 if tid is not null then
 select coalesce(jsonb_agg(row order by seq),'[]'),min(seq),count(*)=50 into msgs,cursor,more from(select m.sequence_number seq,jsonb_build_object('id',m.id,'organization_id',m.organization_id,'thread_id',m.thread_id,'author_person_id',m.author_person_id,
 'author_name',(select coalesce(p.display_name,p.preferred_name,'Boss member') from public.people p where p.id=m.author_person_id),'body',case when m.status='visible' then m.body else '' end,
 'sequence',m.sequence_number,'sequence_number',m.sequence_number,'version',m.version,'status',m.status,'pinned',m.pinned_at is not null,'created_at',m.created_at,'edited_at',m.edited_at,
 'operations',boss_private.comm_message_operations(m.id,actor),'attachments',case when m.status='visible' and boss_private.comm_feature(org,'attachments') then coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'filename',a.file_name,'file_name',a.file_name,'mime_type',a.mime_type,'size_bytes',a.size_bytes,'status',a.status,'operations',jsonb_build_array('attachment.access'))) from public.communication_attachments a where a.message_id=m.id and a.status='attached'),'[]'::jsonb) else '[]'::jsonb end) row
 from public.communication_messages m where m.thread_id=tid and (before_seq is null or m.sequence_number<before_seq) and (q is null or (m.status='visible' and m.body ilike '%'||q||'%')) order by m.sequence_number desc limit 50)s;
 detail:=jsonb_build_object('thread',boss_private.comm_thread_summary(tid,actor),'messages',msgs);
 end if;
 select coalesce(jsonb_agg(row),'[]') into reports from(select jsonb_build_object('id',r.id,'message_id',r.message_id,'reason',r.reason,'detail',r.detail,'status',r.status,'created_at',r.created_at,'operations',jsonb_build_array('report.moderate')) row
 from public.communication_reports r join public.communication_messages m on m.id=r.message_id where (org is null or r.organization_id=org) and boss_private.comm_feature(r.organization_id,'moderation') and boss_private.comm_thread_can_view(m.thread_id,actor) and boss_private.comm_thread_manage(m.thread_id,actor,'moderation.manage') order by r.created_at desc,r.id limit 100)s;
 if boss_private.has_permission('person.profile.manage') and boss_private.has_permission('communications.manage') then ops:=array_append(ops,'guardian.configure');
 select coalesce(jsonb_agg(row),'[]') into guardians from(select jsonb_build_object('id',g.id,'guardian_label',coalesce(p.display_name,p.preferred_name,'Guardian'),'dependent_label',coalesce(d.display_name,d.preferred_name,'Participant'),
 'can_receive_communications',g.can_receive_communications,'can_send_communications',g.can_send_communications,'operations',jsonb_build_array('guardian.configure')) row
 from public.guardian_relationships g join public.people p on p.id=g.guardian_person_id join public.people d on d.id=g.dependent_person_id where g.verified_at<=now() and (org is not null and (exists(select 1 from public.organization_memberships om where om.organization_id=org and om.person_id=d.id and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now())) or exists(select 1 from public.team_memberships tm where tm.organization_id=org and tm.person_id=d.id and tm.status='active' and tm.starts_at<=now() and (tm.ends_at is null or tm.ends_at>now())))) order by g.id limit 100)s;end if;
 return jsonb_build_object('person',jsonb_build_object('id',actor,'label',(select coalesce(display_name,preferred_name,'Boss member') from public.people where id=actor)),
 'organizations',orgs,'organizationId',org,'features',features,'operations',to_jsonb(ops),'threads',threads,'detail',detail,'candidates',candidates,'teams',teams,'units',units,'targets',targets,'reports',reports,'guardians',guardians,'audience_roles',audience_roles,'households',households,'unread',unread,'more',more,'cursor',cursor);
 exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT422' then raise;when others then raise exception 'Invalid communication request.' using errcode='PT422';end $$;
