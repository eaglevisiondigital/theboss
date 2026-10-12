-- Phase 4A: canonical events, recipient state and channel-independent delivery.
-- Closed raw tables; all application projections recheck current source authority.
create table boss_private.notification_types (
 key text primary key,category text not null,source_module text not null,
 title text not null,body text not null,mandatory boolean not null default false,
 check(category in ('events','registration','fees','communications','security'))
);
insert into boss_private.notification_types(key,category,source_module,title,body) values
 ('event.created','events','calendar','New event','An event is available in your calendar.'),
 ('event.rescheduled','events','calendar','Event changed','An event time or location changed. Review your calendar.'),
 ('event.canceled','events','calendar','Event canceled','An event in your calendar was canceled.'),
 ('event.reminder','events','calendar','Event reminder','An upcoming event is ready to review.'),
 ('registration.submitted','registration','registration','Registration submitted','Your registration was submitted.'),
 ('registration.approved','registration','registration','Registration approved','A registration decision is ready to review.'),
 ('registration.denied','registration','registration','Registration decision','A registration decision is ready to review.'),
 ('registration.waitlisted','registration','registration','Registration waitlisted','Your registration is on the waiting list.'),
 ('registration.missing_requirement','registration','registration','Registration requirement','A required registration item needs attention.'),
 ('registration.deadline','registration','registration','Registration deadline','A registration deadline is approaching.'),
 ('document.approved','registration','registration','Document review complete','A registration document review is ready.'),
 ('document.rejected','registration','registration','Document needs attention','A registration document needs attention. Review your registration.'),
 ('payment.recorded','fees','registration','Payment recorded','An offline payment was recorded. Review your fees.'),
 ('fee.balance_due','fees','registration','Balance due','A registration fee balance remains due.'),
 ('fee.upcoming','fees','registration','Fee due soon','A registration fee due date is approaching.'),
 ('fee.overdue','fees','registration','Fee overdue','A registration fee remains overdue.'),
 ('communication.announcement','communications','messaging','New announcement','An announcement is available in Boss.'),
 ('communication.message','communications','messaging','New message','A private conversation has a new message.');
alter table boss_private.notification_types enable row level security;
revoke all on boss_private.notification_types from public,anon,authenticated,service_role;

create table public.notification_events (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 event_type text not null references boss_private.notification_types(key) on delete restrict,
 source_module text not null,source_type text not null,source_id uuid not null,source_revision text not null,
 safe_data jsonb not null default '{}',occurred_at timestamptz not null default now(),scheduled_at timestamptz not null default now(),
 status text not null default 'queued',created_at timestamptz not null default now(),
 unique(organization_id,event_type,source_type,source_id,source_revision),unique(organization_id,id),
 check(source_module in ('calendar','registration','messaging')),
 check(source_type in ('event','registration','registration_document','charge','payment','message')),
 check(length(source_revision) between 1 and 200),check(status in ('queued','processing','complete','canceled','failed')),
 check(jsonb_typeof(safe_data)='object' and octet_length(safe_data::text)<=4096)
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,notification_event_id uuid not null,
 recipient_person_id uuid not null references public.people(id) on delete restrict,contexts jsonb not null default '[]',
 read_at timestamptz,created_at timestamptz not null default now(),
 unique(notification_event_id,recipient_person_id),unique(organization_id,id),
 foreign key(organization_id,notification_event_id) references public.notification_events(organization_id,id) on delete restrict,
 check(jsonb_typeof(contexts)='array' and octet_length(contexts::text)<=8192)
);
create table public.notification_preferences (
 id uuid primary key default gen_random_uuid(),person_id uuid not null references public.people(id) on delete restrict,
 organization_id uuid references public.organizations(id) on delete restrict,team_id uuid,
 channel text not null,category text not null,enabled boolean not null,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 foreign key(organization_id,team_id) references public.teams(organization_id,id) on delete restrict,
 check(team_id is null or organization_id is not null),check(channel in ('in_app','email')),
 check(category in ('events','registration','fees','communications','security')),
 unique nulls not distinct(person_id,organization_id,team_id,channel,category)
);
create table public.notification_deliveries (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,notification_id uuid not null,channel text not null,
 status text not null default 'queued',attempts integer not null default 0,next_attempt_at timestamptz not null default now(),
 processing_until timestamptz,claim_generation bigint not null default 0,provider_message_reference text,
 failure_category text,created_at timestamptz not null default now(),sent_at timestamptz,delivered_at timestamptz,updated_at timestamptz not null default now(),
 foreign key(organization_id,notification_id) references public.notifications(organization_id,id) on delete restrict,
 unique(notification_id,channel),check(channel in ('in_app','email')),
 check(status in ('queued','processing','sent','delivered','failed','bounced','suppressed','canceled')),
 check(attempts between 0 and 5),check(claim_generation>=0),
 check(failure_category is null or failure_category in ('preference','not_configured','authority_removed','source_canceled','transient','permanent','ambiguous','attempts_exhausted')),
 check(provider_message_reference is null or length(provider_message_reference)<=200)
);
create table boss_private.notification_expansion_jobs (
 notification_event_id uuid primary key references public.notification_events(id) on delete restrict,
 cursor_person_id uuid,status text not null default 'queued',processing_until timestamptz,next_attempt_at timestamptz not null default now(),attempts integer not null default 0,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(status in ('queued','processing','complete','canceled','failed')),check(attempts between 0 and 5)
);
create table boss_private.notification_operation_receipts (
 actor_person_id uuid not null references public.people(id) on delete restrict,request_id uuid not null,input_hash bytea not null,
 command jsonb not null,result jsonb not null,created_at timestamptz not null default now(),primary key(actor_person_id,request_id)
);
create index notification_events_ready_idx on public.notification_events(organization_id,scheduled_at,id) where status in ('queued','processing');
create index notification_events_type_idx on public.notification_events(event_type);
create index notifications_inbox_idx on public.notifications(recipient_person_id,created_at desc,id);
create index notifications_unread_idx on public.notifications(recipient_person_id,organization_id,created_at desc) where read_at is null;
create index notifications_event_idx on public.notifications(notification_event_id);
create index notifications_tenant_event_idx on public.notifications(organization_id,notification_event_id);
create index notification_preferences_person_idx on public.notification_preferences(person_id,channel,category);
create index notification_preferences_tenant_team_idx on public.notification_preferences(organization_id,team_id);
create index notification_deliveries_ready_idx on public.notification_deliveries(organization_id,next_attempt_at,id) where status in ('queued','processing');
create index notification_deliveries_history_idx on public.notification_deliveries(organization_id,created_at desc,id);
create index notification_deliveries_tenant_notification_idx on public.notification_deliveries(organization_id,notification_id);
create index notification_expansion_ready_idx on boss_private.notification_expansion_jobs(status,processing_until,created_at);
-- Tenant/person seeks bound the candidate branch outputs without global role scans.
create index notification_org_membership_seek_idx on public.organization_memberships(organization_id,person_id) where status='active';
create index notification_team_membership_seek_idx on public.team_memberships(organization_id,person_id) where status='active';
create index notification_role_seek_idx on public.role_assignments(organization_id,person_id) where status='active' and organization_id is not null;
alter table public.notification_events enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_deliveries enable row level security;
alter table boss_private.notification_expansion_jobs enable row level security;
alter table boss_private.notification_operation_receipts enable row level security;
revoke all on public.notification_events,public.notifications,public.notification_preferences,public.notification_deliveries,
 boss_private.notification_expansion_jobs,boss_private.notification_operation_receipts from public,anon,authenticated,service_role;

create function boss_private.notification_person_active(p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select boss_private.comm_person_active(p_person) and exists(select 1 from public.user_accounts a join auth.users u on u.id=a.auth_user_id
 where a.person_id=p_person and a.account_status='active' and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false) and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now()))
$$;
-- Dated windows and immutable row creation bound pending-source eligibility.
-- Mutable capability history is not reconstructed; current flags still apply.
create function boss_private.notification_permission_at(p_person uuid,p_key text,p_org uuid,p_type text,p_id uuid,p_at timestamptz) returns boolean
language sql stable security definer set search_path='' as $$
 select boss_private.comm_permission(p_person,p_key,p_org,p_type,p_id) and exists(
 select 1 from public.role_assignments a join public.roles role on role.id=a.role_id join public.role_permissions rp on rp.role_id=role.id join public.permissions permission on permission.id=rp.permission_id
 where a.person_id=p_person and a.organization_id=p_org and a.status='active' and role.status='active' and permission.status='active' and permission.key=p_key
 and a.created_at<=least(now(),p_at) and a.starts_at<=least(now(),p_at) and (a.ends_at is null or a.ends_at>now()) and
 ((a.scope_type='organization' and a.scope_id=p_org)
 or (a.scope_type='organization_unit' and a.scope_id=case when p_type='unit' then p_id when p_type='team' then (select t.parent_unit_id from public.teams t where t.id=p_id and t.organization_id=p_org) end)
 or (a.scope_type='team' and p_type='team' and a.scope_id=p_id and exists(select 1 from public.team_memberships m where m.person_id=p_person and m.team_id=p_id and m.organization_id=p_org and m.status='active' and m.created_at<=least(now(),p_at) and m.starts_at<=least(now(),p_at) and (m.ends_at is null or m.ends_at>now())))))
$$;
create function boss_private.notification_guardian(p_guardian uuid,p_dependent uuid,p_flag text,p_at timestamptz default now()) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.guardian_relationships g join public.people dependent on dependent.id=g.dependent_person_id and dependent.status='active'
 where g.guardian_person_id=p_guardian and g.dependent_person_id=p_dependent and g.authority_status='active'
 and g.verified_at is not null and g.verified_at<=least(now(),p_at) and g.created_at<=least(now(),p_at) and g.starts_at<=least(now(),p_at) and (g.ends_at is null or g.ends_at>now())
 and case p_flag when 'can_register' then g.can_register when 'can_manage_payments' then g.can_manage_payments
 when 'can_receive_communications' then g.can_receive_communications else false end)
$$;

create function boss_private.notification_context_at(p_person uuid,p_org uuid,p_type text,p_id uuid,p_at timestamptz) returns boolean
language sql stable security definer set search_path='' as $$
 select boss_private.comm_context_related(p_person,p_org,p_type,p_id) and (
 exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id and t.organization_id=m.organization_id and t.status='active'
 where m.organization_id=p_org and m.status='active' and m.created_at<=least(now(),p_at) and m.starts_at<=least(now(),p_at) and (m.ends_at is null or m.ends_at>now())
 and (p_type='organization' or (p_type='unit' and t.parent_unit_id=p_id) or (p_type='team' and t.id=p_id))
 and (m.person_id=p_person or boss_private.notification_guardian(p_person,m.person_id,'can_receive_communications',p_at)))
 or (p_type='organization' and p_id=p_org and exists(select 1 from public.organization_memberships m where m.organization_id=p_org and m.status='active' and m.created_at<=least(now(),p_at) and m.starts_at<=least(now(),p_at) and (m.ends_at is null or m.ends_at>now())
 and (m.person_id=p_person or boss_private.notification_guardian(p_person,m.person_id,'can_receive_communications',p_at)))))
$$;
create function boss_private.notification_registration_visible(p_registration uuid,p_person uuid,p_finance boolean default false,p_at timestamptz default now()) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.comm_person_active(p_person) and boss_private.registration_feature(r.organization_id,'registration')
 and (not p_finance or boss_private.registration_feature(r.organization_id,'fees')) and a.status='active' and dependent.status='active'
 and (a.person_id=p_person or boss_private.notification_guardian(p_person,a.person_id,case when p_finance then 'can_manage_payments' else 'can_register' end,p_at)
 or boss_private.notification_permission_at(p_person,case when p_finance then 'fees.view' else 'registration.review' end,r.organization_id,o.scope_type,o.scope_id,p_at))
 from public.registrations r join public.registration_offerings o on o.id=r.offering_id and o.organization_id=r.organization_id
 join public.participants a on a.id=r.participant_id join public.people dependent on dependent.id=a.person_id
 where r.id=p_registration),false)
$$;

create function boss_private.notification_event_visible(p_event uuid,p_person uuid,p_at timestamptz default now()) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.comm_person_active(p_person) and boss_private.calendar_module_enabled(e.organization_id)
 and e.status not in ('draft','archived') and exists(select 1 from public.event_targets target where target.event_id=e.id and (
 boss_private.notification_permission_at(p_person,'events.manage',e.organization_id,target.target_type,target.target_id,p_at)
 or (e.visibility<>'private' and boss_private.notification_permission_at(p_person,'events.view',e.organization_id,target.target_type,target.target_id,p_at))
 or (e.visibility='member' and (
 exists(select 1 from public.team_memberships tm join public.teams t on t.id=tm.team_id and t.organization_id=tm.organization_id and t.status='active'
 where tm.organization_id=e.organization_id and tm.status='active' and tm.created_at<=least(now(),p_at) and tm.starts_at<=least(now(),p_at) and (tm.ends_at is null or tm.ends_at>now())
 and (target.target_type='organization' or (target.target_type='unit' and t.parent_unit_id=target.target_id) or (target.target_type='team' and t.id=target.target_id))
 and ((tm.person_id=p_person and boss_private.comm_participant_allowed(p_person,e.organization_id))
 or ('guardians'=any(e.audience) and boss_private.comm_feature(e.organization_id,'guardian_visibility') and boss_private.notification_guardian(p_person,tm.person_id,'can_receive_communications',p_at))))
 or (target.target_type='organization' and exists(select 1 from public.organization_memberships om where om.organization_id=e.organization_id and om.person_id=p_person and om.status='active' and om.created_at<=least(now(),p_at) and om.starts_at<=least(now(),p_at) and (om.ends_at is null or om.ends_at>now())))))))
 from public.events e where e.id=p_event),false)
$$;

create function boss_private.notification_source_visible(p_event public.notification_events,p_person uuid) returns boolean
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

create function boss_private.notification_preference(p_person uuid,p_org uuid,p_team uuid,p_channel text,p_category text,p_mandatory boolean default false) returns boolean
language sql stable security definer set search_path='' as $$
 select p_mandatory or coalesce((select preference.enabled from public.notification_preferences preference
 where preference.person_id=p_person and preference.channel=p_channel and preference.category=p_category
 and (preference.organization_id is null or preference.organization_id=p_org) and (preference.team_id is null or preference.team_id=p_team)
 order by (preference.team_id is not null) desc,(preference.organization_id is not null) desc limit 1),true)
$$;

create function boss_private.notification_contexts(p_event public.notification_events,p_person uuid) returns jsonb
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
create function boss_private.notification_context_preference(p_event public.notification_events,p_person uuid,p_channel text,p_category text,p_mandatory boolean default false) returns boolean
language sql stable security definer set search_path='' as $$
 select p_mandatory or coalesce((select bool_or(boss_private.notification_preference(p_person,p_event.organization_id,(context->>'team_id')::uuid,p_channel,p_category,false))
 from jsonb_array_elements(boss_private.notification_contexts(p_event,p_person)) context where context?'team_id'),
 boss_private.notification_preference(p_person,p_event.organization_id,null,p_channel,p_category,false))
$$;

create function boss_private.notification_destination(p_event public.notification_events) returns text
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

revoke all on function boss_private.notification_person_active(uuid),boss_private.notification_permission_at(uuid,text,uuid,text,uuid,timestamptz),boss_private.notification_context_at(uuid,uuid,text,uuid,timestamptz),boss_private.notification_guardian(uuid,uuid,text,timestamptz),boss_private.notification_registration_visible(uuid,uuid,boolean,timestamptz),
 boss_private.notification_event_visible(uuid,uuid,timestamptz),boss_private.notification_source_visible(public.notification_events,uuid),
 boss_private.notification_preference(uuid,uuid,uuid,text,text,boolean),boss_private.notification_contexts(public.notification_events,uuid),boss_private.notification_context_preference(public.notification_events,uuid,text,text,boolean),boss_private.notification_destination(public.notification_events) from public,anon,authenticated,service_role;
