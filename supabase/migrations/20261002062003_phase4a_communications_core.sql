-- Phase 4A canonical private communication model. No people, roles assignments,
-- relationships or module activations are created by this migration.
alter table public.guardian_relationships add column can_receive_communications boolean not null default false,
 add column can_send_communications boolean not null default false;
insert into public.permissions(key,name) values
 ('communications.view','View authorized communications'),('communications.send','Send authorized communications'),
 ('communications.manage','Manage scoped communications'),('announcements.send','Send scoped announcements'),
 ('team_chat.view','View authorized team chat'),('team_chat.send','Send authorized team chat'),
 ('notifications.view','View own authorized notifications'),('notifications.manage','Manage scoped notification operations'),
 ('delivery_history.view','View safe scoped delivery history'),('moderation.manage','Moderate scoped communications');
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.key in ('super_administrator','platform_administrator','organization_owner','organization_administrator')
 and p.key=any(array['communications.view','communications.send','communications.manage','announcements.send','team_chat.view','team_chat.send','notifications.view','notifications.manage','delivery_history.view','moderation.manage']);
with mappings(role_key,keys) as(values
 ('athletic_director',array['communications.view','announcements.send']),
 ('program_administrator',array['communications.view','communications.send','communications.manage','announcements.send','team_chat.view','team_chat.send','delivery_history.view']),
 ('sport_administrator',array['communications.view','communications.send','communications.manage','announcements.send','team_chat.view','team_chat.send','delivery_history.view']),
 ('head_coach',array['communications.view','communications.manage','announcements.send','team_chat.view','team_chat.send']),
 ('assistant_coach',array['communications.view','team_chat.view','team_chat.send']),
 ('team_staff',array['communications.view','team_chat.view','team_chat.send']))
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from mappings m join public.roles r on r.key=m.role_key join public.permissions p on p.key=any(m.keys);

create table public.communication_threads(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 kind text not null check(kind in('announcement','organization_staff','program','team_chat','coach_staff','direct','group','family','system')),
 title text not null check(length(btrim(title)) between 1 and 200), scope_type text not null check(scope_type in('organization','unit','team')),
 scope_id uuid not null, unit_id uuid generated always as(case when scope_type='unit' then scope_id end) stored,
 team_id uuid generated always as(case when scope_type='team' then scope_id end) stored,
 household_id uuid references public.households(id), visibility text not null default 'private' check(visibility in('private','public')),
 status text not null default 'active' check(status in('active','archived')), created_by_person_id uuid not null references public.people(id),
 next_sequence bigint not null default 0 check(next_sequence>=0),version bigint not null default 1 check(version>0),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(organization_id,id), check(scope_type<>'organization' or scope_id=organization_id),
 check((kind='family')=(household_id is not null)),check(kind='announcement' or visibility='private'),
 foreign key(organization_id,unit_id) references public.organization_units(organization_id,id),
 foreign key(organization_id,team_id) references public.teams(organization_id,id));
create index communication_threads_recent_idx on public.communication_threads(organization_id,updated_at desc,id);
create index communication_threads_team_idx on public.communication_threads(organization_id,team_id);
create index communication_threads_unit_idx on public.communication_threads(organization_id,unit_id);
create index communication_threads_creator_idx on public.communication_threads(created_by_person_id);
create index communication_threads_household_idx on public.communication_threads(household_id);
create table public.communication_thread_members(
 organization_id uuid not null,thread_id uuid not null,person_id uuid not null references public.people(id),
 status text not null default 'active' check(status in('active','inactive')),starts_at timestamptz not null default now(),ends_at timestamptz,
 created_at timestamptz not null default now(),primary key(thread_id,person_id),foreign key(organization_id,thread_id) references public.communication_threads(organization_id,id),
 check(ends_at is null or ends_at>starts_at));
create index communication_thread_members_person_idx on public.communication_thread_members(person_id,thread_id);
create index communication_thread_members_org_idx on public.communication_thread_members(organization_id,thread_id);
create table public.communication_audiences(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,thread_id uuid not null,
 scope_type text not null check(scope_type in('organization','unit','team')),scope_id uuid not null,
 unit_id uuid generated always as(case when scope_type='unit' then scope_id end) stored,
 team_id uuid generated always as(case when scope_type='team' then scope_id end) stored,
 role_id uuid references public.roles(id),created_at timestamptz not null default now(),
 foreign key(organization_id,thread_id) references public.communication_threads(organization_id,id),
 foreign key(organization_id,unit_id) references public.organization_units(organization_id,id),
 foreign key(organization_id,team_id) references public.teams(organization_id,id),check(scope_type<>'organization' or scope_id=organization_id));
create unique index communication_audiences_exact_idx on public.communication_audiences(thread_id,scope_type,scope_id,coalesce(role_id,'00000000-0000-0000-0000-000000000000'::uuid));
create index communication_audiences_org_idx on public.communication_audiences(organization_id,thread_id);
create index communication_audiences_role_idx on public.communication_audiences(role_id);
create index communication_audiences_unit_idx on public.communication_audiences(organization_id,unit_id);
create index communication_audiences_team_idx on public.communication_audiences(organization_id,team_id);
create table public.communication_messages(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,thread_id uuid not null,author_person_id uuid not null references public.people(id),
 body text not null check(length(btrim(body)) between 1 and 8000),status text not null default 'visible' check(status in('visible','hidden','removed')),
 sequence_number bigint not null check(sequence_number>0),version bigint not null default 1 check(version>0),pinned_at timestamptz,
 created_at timestamptz not null default now(),edited_at timestamptz,removed_at timestamptz,
 unique(organization_id,id),unique(thread_id,id),unique(thread_id,sequence_number),foreign key(organization_id,thread_id) references public.communication_threads(organization_id,id));
create index communication_messages_recent_idx on public.communication_messages(thread_id,sequence_number desc);
create index communication_messages_org_idx on public.communication_messages(organization_id,id);
create index communication_messages_author_idx on public.communication_messages(author_person_id);
create table public.communication_message_revisions(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,message_id uuid not null,version bigint not null,body text not null,
 actor_person_id uuid not null references public.people(id),created_at timestamptz not null default now(),unique(message_id,version),
 foreign key(organization_id,message_id) references public.communication_messages(organization_id,id));
create index communication_revisions_org_idx on public.communication_message_revisions(organization_id,message_id);
create index communication_revisions_actor_idx on public.communication_message_revisions(actor_person_id);
create table public.communication_read_state(
 organization_id uuid not null,thread_id uuid not null,person_id uuid not null references public.people(id),through_sequence bigint not null default 0 check(through_sequence>=0),
 read_at timestamptz not null default now(),primary key(thread_id,person_id),foreign key(organization_id,thread_id) references public.communication_threads(organization_id,id));
create index communication_read_person_idx on public.communication_read_state(person_id,thread_id);
create index communication_read_org_idx on public.communication_read_state(organization_id,thread_id);
create table public.communication_attachments(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,thread_id uuid not null,message_id uuid,
 actor_person_id uuid not null references public.people(id),file_name text not null check(length(btrim(file_name)) between 1 and 200),
 mime_type text not null check(mime_type in('application/pdf','image/jpeg','image/png')),size_bytes bigint not null check(size_bytes between 1 and 5242880),
 content_sha256 text not null check(content_sha256~'^[0-9a-f]{64}$'),object_name text not null unique,
 status text not null default 'upload_pending' check(status in('upload_pending','ready','attached','removed')),created_at timestamptz not null default now(),completed_at timestamptz,
 unique(organization_id,id),foreign key(organization_id,thread_id) references public.communication_threads(organization_id,id),
 foreign key(thread_id,message_id) references public.communication_messages(thread_id,id),check(status<>'attached' or message_id is not null));
create index communication_attachments_message_idx on public.communication_attachments(message_id);
create index communication_attachments_org_idx on public.communication_attachments(organization_id,thread_id);
create index communication_attachments_actor_idx on public.communication_attachments(actor_person_id);
create table public.communication_reports(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,message_id uuid not null,reporter_person_id uuid not null references public.people(id),
 reason text not null check(reason in('spam','harassment','unsafe','other')),detail text check(length(detail)<=500),
 status text not null default 'open' check(status in('open','reviewed','dismissed','actioned')),moderator_person_id uuid references public.people(id),
 moderation_reason text check(length(moderation_reason)<=500),created_at timestamptz not null default now(),reviewed_at timestamptz,
 foreign key(organization_id,message_id) references public.communication_messages(organization_id,id));
create index communication_reports_org_idx on public.communication_reports(organization_id,status,created_at desc);
create index communication_reports_message_idx on public.communication_reports(message_id);
create index communication_reports_reporter_idx on public.communication_reports(reporter_person_id);
create index communication_reports_moderator_idx on public.communication_reports(moderator_person_id);
create table boss_private.communication_operation_receipts(
 actor_person_id uuid not null references public.people(id),request_id uuid not null,input_hash bytea not null,command jsonb not null,result jsonb not null,
 created_at timestamptz not null default now(),primary key(actor_person_id,request_id));
create table boss_private.communication_upload_intents(
 attachment_id uuid primary key references public.communication_attachments(id),actor_person_id uuid not null references public.people(id),auth_session_id uuid not null,
 expires_at timestamptz not null,consumed_at timestamptz,created_at timestamptz not null default now());
create index communication_upload_actor_idx on boss_private.communication_upload_intents(actor_person_id);
create table boss_private.communication_access_leases(
 id uuid primary key default gen_random_uuid(),attachment_id uuid not null references public.communication_attachments(id),actor_person_id uuid not null references public.people(id),
 auth_session_id uuid not null,expires_at timestamptz not null,created_at timestamptz not null default now());
create index communication_leases_attachment_idx on boss_private.communication_access_leases(attachment_id,actor_person_id,expires_at);
create index communication_leases_actor_idx on boss_private.communication_access_leases(actor_person_id);
DO $$declare t text;begin
 foreach t in array array['communication_threads','communication_thread_members','communication_audiences','communication_messages','communication_message_revisions','communication_read_state','communication_attachments','communication_reports'] loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);end loop;
 foreach t in array array['communication_operation_receipts','communication_upload_intents','communication_access_leases'] loop
 execute format('alter table boss_private.%I enable row level security',t);execute format('revoke all on boss_private.%I from public,anon,authenticated,service_role',t);end loop;
end $$;
create trigger communication_threads_identity before update on public.communication_threads for each row execute function boss_private.preserve_row_identity('id','organization_id','kind','scope_type','scope_id','household_id','created_by_person_id','created_at');
create trigger communication_messages_identity before update on public.communication_messages for each row execute function boss_private.preserve_row_identity('id','organization_id','thread_id','author_person_id','sequence_number','created_at');
create trigger communication_attachments_identity before update on public.communication_attachments for each row execute function boss_private.preserve_row_identity('id','organization_id','thread_id','actor_person_id','file_name','mime_type','size_bytes','content_sha256','object_name','created_at');

create function boss_private.comm_person_active(p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.people where id=p_person and status='active') $$;
create function boss_private.comm_configuration(p_org uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce((select om.configuration from public.organization_modules om join public.modules m on m.id=om.module_id join public.organizations o on o.id=om.organization_id
 where o.id=p_org and o.status='active' and m.key='messaging' and m.status='active' and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()) order by om.starts_at desc limit 1),'null'::jsonb) $$;
create function boss_private.comm_feature(p_org uuid,p_key text) returns boolean language sql stable security definer set search_path='' as $$
 select p_key=any(array['communications','announcements','team_chat','staff_send','direct_messaging','guardian_visibility','participant_messaging','minor_groups','attachments','moderation','in_app_notifications','email_notifications'])
 and boss_private.comm_configuration(p_org)<>'null'::jsonb and case
 when jsonb_typeof(boss_private.comm_configuration(p_org)->p_key)='boolean' then (boss_private.comm_configuration(p_org)->>p_key)::boolean
 when boss_private.comm_configuration(p_org)?p_key then false else p_key=any(array['communications','announcements','guardian_visibility','in_app_notifications']) end $$;
create function boss_private.comm_policy_number(p_org uuid,p_key text) returns integer language sql stable security definer set search_path='' as $$
 select case when p_key='minimum_participant_age' then case when jsonb_typeof(boss_private.comm_configuration(p_org)->p_key)='number' and (boss_private.comm_configuration(p_org)->>p_key)~'^[0-9]{1,2}$' then greatest(0,least(99,(boss_private.comm_configuration(p_org)->>p_key)::integer)) else 18 end
 when p_key='sender_edit_minutes' then case when jsonb_typeof(boss_private.comm_configuration(p_org)->p_key)='number' and (boss_private.comm_configuration(p_org)->>p_key)~'^[0-9]{1,3}$' then greatest(0,least(60,(boss_private.comm_configuration(p_org)->>p_key)::integer)) else 15 end else 0 end $$;
create function boss_private.comm_guardian(p_guardian uuid,p_dependent uuid,p_flag text) returns boolean language sql stable security definer set search_path='' as $$
 select p_flag=any(array['can_receive_communications','can_send_communications']) and boss_private.comm_person_active(p_guardian) and boss_private.comm_person_active(p_dependent) and exists(
 select 1 from public.guardian_relationships g where g.guardian_person_id=p_guardian and g.dependent_person_id=p_dependent and g.authority_status='active' and g.verified_at<=now()
 and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now()) and case p_flag when 'can_receive_communications' then g.can_receive_communications when 'can_send_communications' then g.can_send_communications end) $$;
create function boss_private.comm_permission(p_person uuid,p_key text,p_org uuid,p_scope_type text,p_scope_id uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare u uuid;begin
 if not boss_private.comm_person_active(p_person) or not exists(select 1 from public.organizations where id=p_org and status='active') then return false;end if;
 if p_scope_type='organization' then if p_scope_id is distinct from p_org then return false;end if;
 elsif p_scope_type='unit' then select id into u from public.organization_units where id=p_scope_id and organization_id=p_org and status='active';if not found then return false;end if;
 elsif p_scope_type='team' then select parent_unit_id into u from public.teams where id=p_scope_id and organization_id=p_org and status='active';if not found or (u is not null and not exists(select 1 from public.organization_units where id=u and organization_id=p_org and status='active')) then return false;end if;
 else return false;end if;
 return exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id
 where a.person_id=p_person and a.status='active' and r.status='active' and p.status='active' and p.key=p_key and a.starts_at<=now() and (a.ends_at is null or a.ends_at>now())
 and ((a.scope_type='platform' and a.scope_id is null and a.organization_id is null) or (a.organization_id=p_org and
 ((a.scope_type='organization' and a.scope_id=p_org) or (a.scope_type='organization_unit' and a.scope_id=u) or (a.scope_type='team' and p_scope_type='team' and a.scope_id=p_scope_id
 and exists(select 1 from public.team_memberships tm where tm.team_id=p_scope_id and tm.person_id=p_person and tm.status='active' and tm.starts_at<=now() and (tm.ends_at is null or tm.ends_at>now()) and tm.membership_type in('coach','head_coach','assistant_coach','staff','team_staff'))))))
 and (r.key not in('assistant_coach','team_staff') or p_key not in('team_chat.send','communications.send') or boss_private.comm_feature(p_org,'staff_send')));
end $$;
create function boss_private.comm_is_minor(p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select date_of_birth is null or date_of_birth>current_date-interval '18 years' from public.people where id=p_person),true) $$;
create function boss_private.comm_participant_allowed(p_person uuid,p_org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select (not exists(select 1 from public.participants where person_id=p_person and status='active') and exists(select 1 from public.people where id=p_person and date_of_birth is not null and date_of_birth<=current_date-interval '18 years')) or
 (boss_private.comm_feature(p_org,'participant_messaging') and exists(select 1 from public.people p where p.id=p_person and p.date_of_birth is not null
 and p.date_of_birth<=current_date-make_interval(years=>boss_private.comm_policy_number(p_org,'minimum_participant_age'))
 and (not boss_private.comm_is_minor(p_person) or (boss_private.comm_feature(p_org,'minor_groups') and boss_private.comm_feature(p_org,'guardian_visibility')
 and exists(select 1 from public.guardian_relationships g where g.dependent_person_id=p_person and boss_private.comm_guardian(g.guardian_person_id,p_person,'can_receive_communications')))))) $$;
create function boss_private.comm_context_related(p_person uuid,p_org uuid,p_scope_type text,p_scope_id uuid,p_send boolean default false) returns boolean language plpgsql stable security definer set search_path='' as $$
declare flag text:=case when p_send then 'can_send_communications' else 'can_receive_communications' end;begin
 if not boss_private.comm_person_active(p_person) or not boss_private.comm_feature(p_org,'communications') then return false;end if;
 if p_scope_type='team' then
 return exists(select 1 from public.teams t where t.id=p_scope_id and t.organization_id=p_org and t.status='active' and (t.parent_unit_id is null or exists(select 1 from public.organization_units u where u.id=t.parent_unit_id and u.organization_id=p_org and u.status='active')) and (
 exists(select 1 from public.team_memberships m where m.team_id=t.id and m.person_id=p_person and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())
 and m.membership_type not in('coach','head_coach','assistant_coach','staff','team_staff') and boss_private.comm_participant_allowed(p_person,p_org)) or exists(select 1 from public.team_memberships m join public.guardian_relationships g on g.dependent_person_id=m.person_id
 where m.team_id=t.id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()) and boss_private.comm_guardian(p_person,m.person_id,flag))));
 elsif p_scope_type='unit' then return exists(select 1 from public.organization_units where id=p_scope_id and organization_id=p_org and status='active') and exists(select 1 from public.teams t where t.organization_id=p_org and t.parent_unit_id=p_scope_id and boss_private.comm_context_related(p_person,p_org,'team',t.id,p_send));
 elsif p_scope_type='organization' and p_scope_id=p_org then
 return (boss_private.comm_participant_allowed(p_person,p_org) and exists(select 1 from public.organization_memberships m where m.organization_id=p_org and m.person_id=p_person and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())))
 or exists(select 1 from public.teams t where t.organization_id=p_org and boss_private.comm_context_related(p_person,p_org,'team',t.id,p_send))
 or exists(select 1 from public.organization_memberships m where m.organization_id=p_org and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()) and boss_private.comm_guardian(p_person,m.person_id,flag));
 end if;return false;
end $$;
create function boss_private.comm_audience_person(p_audience uuid,p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select (boss_private.comm_context_related(p_person,a.organization_id,a.scope_type,a.scope_id) or boss_private.comm_permission(p_person,'communications.view',a.organization_id,a.scope_type,a.scope_id)) and (a.role_id is null or exists(
 select 1 from public.role_assignments r join public.roles role on role.id=r.role_id where r.person_id=p_person and r.role_id=a.role_id and role.status='active' and r.status='active'
 and r.starts_at<=now() and (r.ends_at is null or r.ends_at>now()) and r.organization_id=a.organization_id and
 ((a.scope_type='organization' and r.scope_type='organization' and r.scope_id=a.scope_id) or (a.scope_type='unit' and r.scope_type='organization_unit' and r.scope_id=a.scope_id) or (a.scope_type='team' and r.scope_type='team' and r.scope_id=a.scope_id))))
 from public.communication_audiences a where a.id=p_audience),false) $$;
create function boss_private.comm_thread_manage(p_thread uuid,p_person uuid,p_key text default 'communications.manage') returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.comm_feature(t.organization_id,'communications') and case when t.kind='announcement' then
 exists(select 1 from public.communication_audiences a where a.thread_id=t.id) and not exists(select 1 from public.communication_audiences a where a.thread_id=t.id and not boss_private.comm_permission(p_person,p_key,t.organization_id,a.scope_type,a.scope_id))
 else boss_private.comm_permission(p_person,p_key,t.organization_id,t.scope_type,t.scope_id) end
 and (t.kind not in('direct','group','family') or exists(select 1 from public.communication_thread_members m where m.thread_id=t.id and m.person_id=p_person and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()))) from public.communication_threads t where t.id=p_thread),false) $$;
create function boss_private.comm_thread_can_view(p_thread uuid,p_person uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare t public.communication_threads;begin
 select * into t from public.communication_threads where id=p_thread;
 if not found or t.status<>'active' or not boss_private.comm_person_active(p_person) or not boss_private.comm_feature(t.organization_id,'communications') then return false;end if;
 if exists(select 1 from public.participants where person_id=p_person and status='active') and not boss_private.comm_participant_allowed(p_person,t.organization_id) then return false;end if;
 if t.kind='announcement' then return boss_private.comm_feature(t.organization_id,'announcements') and
 (exists(select 1 from public.communication_audiences a where a.thread_id=t.id and boss_private.comm_audience_person(a.id,p_person)) or boss_private.comm_thread_manage(t.id,p_person,'announcements.send'));
 elsif t.kind in('direct','group','family') then
 if not boss_private.comm_feature(t.organization_id,'direct_messaging') or not exists(select 1 from public.communication_thread_members m where m.thread_id=t.id and m.person_id=p_person and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())) then return false;end if;
 if not boss_private.comm_group_safe(t.id) then return false;end if;
 if t.kind='family' then return exists(select 1 from public.household_memberships hm join public.households hh on hh.id=hm.household_id where hm.household_id=t.household_id and hh.status='active' and hm.person_id=p_person and hm.status='active' and hm.starts_at<=now() and (hm.ends_at is null or hm.ends_at>now())) and boss_private.comm_context_related(p_person,t.organization_id,t.scope_type,t.scope_id) and exists(select 1 from public.communication_thread_members m
 where m.thread_id=t.id and m.status='active' and (boss_private.comm_guardian(p_person,m.person_id,'can_receive_communications') or boss_private.comm_guardian(m.person_id,p_person,'can_receive_communications')));end if;
 return boss_private.comm_context_related(p_person,t.organization_id,t.scope_type,t.scope_id) or boss_private.comm_permission(p_person,'communications.view',t.organization_id,t.scope_type,t.scope_id);
 elsif t.kind in('team_chat','coach_staff') then return boss_private.comm_feature(t.organization_id,'team_chat') and
 (boss_private.comm_permission(p_person,'team_chat.view',t.organization_id,t.scope_type,t.scope_id) or (t.kind='team_chat' and boss_private.comm_context_related(p_person,t.organization_id,t.scope_type,t.scope_id)));
 elsif t.kind='organization_staff' then return boss_private.comm_permission(p_person,'communications.view',t.organization_id,t.scope_type,t.scope_id);
 else return boss_private.comm_permission(p_person,'communications.view',t.organization_id,t.scope_type,t.scope_id) or boss_private.comm_context_related(p_person,t.organization_id,t.scope_type,t.scope_id);
 end if;
end $$;
create function boss_private.comm_thread_can_send(p_thread uuid,p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.comm_thread_can_view(t.id,p_person) and t.kind not in('announcement','system') and
 case when t.kind in('team_chat','coach_staff') then boss_private.comm_permission(p_person,'team_chat.send',t.organization_id,t.scope_type,t.scope_id) or (t.kind='team_chat' and boss_private.comm_context_related(p_person,t.organization_id,t.scope_type,t.scope_id,true))
 else boss_private.comm_permission(p_person,'communications.send',t.organization_id,t.scope_type,t.scope_id) or (t.kind in('direct','group','family') and boss_private.comm_context_related(p_person,t.organization_id,t.scope_type,t.scope_id,true)) end
 from public.communication_threads t where t.id=p_thread),false) $$;
create function boss_private.comm_message_can_view(p_message uuid,p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select m.status='visible' and boss_private.comm_thread_can_view(m.thread_id,p_person) from public.communication_messages m where m.id=p_message),false) $$;
-- Every helper accepting an arbitrary person is private; callers cannot impersonate
-- a notification recipient or enumerate authorization from the Data API.
DO $$declare f record;begin for f in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'comm_%' loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.f);end loop;end $$;
-- Child policy disabling login does not remove the guardian's own team-chat authority.
create function boss_private.comm_family_send(p_person uuid,p_org uuid,p_scope_type text,p_scope_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.guardian_relationships g where g.guardian_person_id=p_person and boss_private.comm_guardian(p_person,g.dependent_person_id,'can_send_communications') and
 ((p_scope_type='team' and exists(select 1 from public.team_memberships m where m.organization_id=p_org and m.team_id=p_scope_id and m.person_id=g.dependent_person_id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())))
 or (p_scope_type='unit' and exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id where m.organization_id=p_org and t.parent_unit_id=p_scope_id and t.status='active' and m.person_id=g.dependent_person_id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())))
 or (p_scope_type='organization' and p_scope_id=p_org and exists(select 1 from public.organization_memberships m where m.organization_id=p_org and m.person_id=g.dependent_person_id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())))))
 or exists(select 1 from public.participants p where p.person_id=p_person and p.status='active' and boss_private.comm_participant_allowed(p_person,p_org) and boss_private.comm_context_related(p_person,p_org,p_scope_type,p_scope_id)) $$;
create or replace function boss_private.comm_thread_can_send(p_thread uuid,p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.comm_thread_can_view(t.id,p_person) and t.kind not in('announcement','system') and
 case when t.kind in('team_chat','coach_staff') then boss_private.comm_permission(p_person,'team_chat.send',t.organization_id,t.scope_type,t.scope_id) or (t.kind='team_chat' and boss_private.comm_family_send(p_person,t.organization_id,t.scope_type,t.scope_id))
 else boss_private.comm_permission(p_person,'communications.send',t.organization_id,t.scope_type,t.scope_id) or (t.kind in('direct','group','family') and boss_private.comm_context_related(p_person,t.organization_id,t.scope_type,t.scope_id,true)) end
 from public.communication_threads t where t.id=p_thread),false) $$;
revoke all on function boss_private.comm_family_send(uuid,uuid,text,uuid),boss_private.comm_thread_can_send(uuid,uuid) from public,anon,authenticated,service_role;

create index communication_messages_thread_tenant_idx on public.communication_messages(organization_id,thread_id);
create index communication_attachments_thread_message_idx on public.communication_attachments(thread_id,message_id);
create index communication_reports_message_tenant_idx on public.communication_reports(organization_id,message_id);
