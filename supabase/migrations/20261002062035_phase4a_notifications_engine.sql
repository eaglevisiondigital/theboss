-- Phase 4A bounded ingestion, current-authority inbox and offline provider state.
create function boss_private.notification_enqueue(p_module text,p_source_type text,p_source uuid,p_org uuid,p_type text,p_revision text,p_safe jsonb default '{}',p_scheduled timestamptz default now()) returns uuid
language plpgsql security definer set search_path='' as $$ declare result uuid;begin
 if not exists(select 1 from boss_private.notification_types t where t.key=p_type and t.source_module=p_module)
 or p_safe is null or jsonb_typeof(p_safe)<>'object' or exists(select 1 from jsonb_object_keys(p_safe) k where k not in ('team_id','occurrence_key','start_at','end_at','source_version','offset_minutes','reminder_id'))
 then raise exception 'Invalid notification operation' using errcode='PT422';end if;
 if not boss_private.comm_feature(p_org,'in_app_notifications') then return null;end if;
 insert into public.notification_events(organization_id,event_type,source_module,source_type,source_id,source_revision,safe_data,scheduled_at)
 values(p_org,p_type,p_module,p_source_type,p_source,p_revision,p_safe,p_scheduled)
 on conflict(organization_id,event_type,source_type,source_id,source_revision) do nothing returning id into result;
 if result is null then select e.id into result from public.notification_events e where e.organization_id=p_org and e.event_type=p_type and e.source_type=p_source_type and e.source_id=p_source and e.source_revision=p_revision;end if;
 insert into boss_private.notification_expansion_jobs(notification_event_id) values(result) on conflict do nothing;
 return result;
end $$;

-- Seek and active-identity qualification occur inside every bounded source branch.
-- UNION deduplicates overlap before the final bounded continuation page.
create function boss_private.notification_candidates(p_event public.notification_events,p_after uuid,p_limit integer) returns table(person_id uuid)
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

create function boss_private.notification_process(p_org uuid,p_limit integer default 100) returns jsonb
language plpgsql security definer set search_path='' as $$
declare job record;event public.notification_events;typ boss_private.notification_types;candidate record;v_seen integer;v_total integer:=0;v_new integer:=0;v_id uuid;v_team uuid;v_enabled boolean;v_channel text;v_status text;v_failure text;v_last uuid;
begin
 if p_limit not between 1 and 100 then raise exception 'Invalid notification operation' using errcode='PT422';end if;
 for job in select j.* from boss_private.notification_expansion_jobs j join public.notification_events e on e.id=j.notification_event_id
 where e.organization_id=p_org and e.scheduled_at<=now() and e.status not in ('canceled','failed')
 and ((j.status='queued' and j.next_attempt_at<=now()) or (j.status='processing' and j.processing_until<=now())) and j.attempts<5
 order by j.created_at,j.notification_event_id for update of j skip locked limit 10 loop
  exit when v_total>=p_limit;
  begin
  select * into event from public.notification_events where id=job.notification_event_id;
  select * into typ from boss_private.notification_types where key=event.event_type;
  update boss_private.notification_expansion_jobs set status='processing',processing_until=now()+interval '2 minutes',attempts=attempts+1,updated_at=now() where notification_event_id=event.id;
  update public.notification_events set status='processing' where id=event.id;
  v_seen:=0;v_last:=job.cursor_person_id;v_team:=(event.safe_data->>'team_id')::uuid;
  for candidate in select * from boss_private.notification_candidates(event,job.cursor_person_id,p_limit-v_total) loop
   v_seen:=v_seen+1;v_total:=v_total+1;v_last:=candidate.person_id;
   if not boss_private.notification_source_visible(event,candidate.person_id) then continue;end if;
   insert into public.notifications(organization_id,notification_event_id,recipient_person_id,contexts)
   values(p_org,event.id,candidate.person_id,boss_private.notification_contexts(event,candidate.person_id))
   on conflict(notification_event_id,recipient_person_id) do nothing returning id into v_id;
   if v_id is null then continue;end if;v_new:=v_new+1;
   foreach v_channel in array array['in_app','email'] loop
    v_enabled:=boss_private.notification_context_preference(event,candidate.person_id,v_channel,typ.category,typ.mandatory);
    v_status:=case when not v_enabled then 'suppressed' when v_channel='email' then 'suppressed' else 'sent' end;
    v_failure:=case when not v_enabled then 'preference' when v_channel='email' then 'not_configured' else null end;
    insert into public.notification_deliveries(organization_id,notification_id,channel,status,failure_category,sent_at)
    values(p_org,v_id,v_channel,v_status,v_failure,case when v_status='sent' then now() end) on conflict(notification_id,channel) do nothing;
   end loop;
  end loop;
  if v_seen<p_limit-(v_total-v_seen) then
   update boss_private.notification_expansion_jobs set status='complete',cursor_person_id=v_last,processing_until=null,attempts=0,updated_at=now() where notification_event_id=event.id;
   update public.notification_events set status='complete' where id=event.id;
  else
   -- A successful bounded page is not a failed retry and may continue indefinitely
   -- across a finite audience; only failures consume the five-attempt limit.
   update boss_private.notification_expansion_jobs set status='queued',cursor_person_id=v_last,processing_until=null,next_attempt_at=now(),attempts=0,updated_at=now() where notification_event_id=event.id;
  end if;
  exception when others then
   -- Roll back the failed page, retain one safe attempt/backoff state, and never
   -- leak exception text, private payloads or recipient/provider internals.
   update boss_private.notification_expansion_jobs set attempts=job.attempts+1,status=case when job.attempts+1>=5 then 'failed' else 'queued' end,
    processing_until=null,next_attempt_at=now()+make_interval(secs=>least(7200,60*power(5,job.attempts)::integer)),updated_at=now() where notification_event_id=job.notification_event_id;
   update public.notification_events set status=case when job.attempts+1>=5 then 'failed' else 'queued' end where id=job.notification_event_id;
  end;
 end loop;
 -- Revoke queued work after relationship changes. Already accepted email cannot be
 -- unsent; current-authority inbox projection still closes immediately.
 update public.notification_deliveries d set status='suppressed',failure_category='authority_removed',updated_at=now()
 where d.id in (select candidate_delivery.id from public.notification_deliveries candidate_delivery join public.notifications n on n.id=candidate_delivery.notification_id
 join public.notification_events e on e.id=n.notification_event_id where candidate_delivery.organization_id=p_org and candidate_delivery.status in ('queued','processing')
 and not boss_private.notification_source_visible(e,n.recipient_person_id) order by candidate_delivery.id for update of candidate_delivery skip locked limit p_limit);
 return jsonb_build_object('processed',v_total,'notifications_created',v_new,'email_sent',0);
end $$;

create function boss_private.notification_cancel_reminders(p_source uuid,p_org uuid) returns void language plpgsql security definer set search_path='' as $$ begin
 update public.notification_events set status='canceled' where source_type='event' and source_id=p_source and organization_id=p_org and event_type='event.reminder' and scheduled_at>now() and status not in ('canceled','failed');
 update boss_private.notification_expansion_jobs j set status='canceled',processing_until=null,updated_at=now() from public.notification_events e where e.id=j.notification_event_id and e.source_type='event' and e.source_id=p_source and e.organization_id=p_org and e.status='canceled';
 update public.notification_deliveries d set status='canceled',failure_category='source_canceled',updated_at=now() from public.notifications n join public.notification_events e on e.id=n.notification_event_id
 where d.notification_id=n.id and e.source_type='event' and e.source_id=p_source and e.organization_id=p_org and e.status='canceled' and d.status in ('queued','processing');
end $$;

-- This narrow capture preserves material OLD/NEW fields missing from the historic
-- calendar audit projection, without copying descriptions, instructions or bodies.
create table boss_private.notification_calendar_changes (
 event_id uuid not null,version bigint not null,material boolean not null,created_at timestamptz not null default now(),primary key(event_id,version)
);
alter table boss_private.notification_calendar_changes enable row level security;
revoke all on boss_private.notification_calendar_changes from public,anon,authenticated,service_role;
create function boss_private.notification_calendar_capture() returns trigger language plpgsql security definer set search_path='' as $$ begin
 insert into boss_private.notification_calendar_changes(event_id,version,material) values(new.id,new.version,
 old.start_at is distinct from new.start_at or old.end_at is distinct from new.end_at or old.timezone is distinct from new.timezone or old.arrival_at is distinct from new.arrival_at
 or old.venue_id is distinct from new.venue_id or old.resource_id is distinct from new.resource_id or old.recurrence is distinct from new.recurrence or old.status is distinct from new.status)
 on conflict(event_id,version) do update set material=excluded.material;
 return new;
end $$;
create trigger notification_calendar_material after update on public.events for each row execute function boss_private.notification_calendar_capture();

create function boss_private.notification_audit_ingest() returns trigger language plpgsql security definer set search_path='' as $$
declare typ text;revision text;kind text;source uuid;safe jsonb:='{}';material boolean;begin
 if new.organization_id is null or not boss_private.comm_feature(new.organization_id,'in_app_notifications') then return new;end if;
 source:=new.resource_id;kind:=new.resource_type;revision:=new.request_id::text;
 if new.action='event.create' then typ:='event.created';kind:='event';
 elsif new.action in ('event.update','event.exception') then
  material:=coalesce((select c.material from boss_private.notification_calendar_changes c where c.event_id=new.resource_id and c.version=(new.after_data->>'version')::bigint),false)
   or (new.before_data?'targets' and new.after_data?'targets' and not((new.before_data->'targets') @> (new.after_data->'targets') and (new.after_data->'targets') @> (new.before_data->'targets')));
  if new.action='event.exception' then material:=new.before_data->'start_at' is distinct from new.after_data->'start_at' or new.before_data->'end_at' is distinct from new.after_data->'end_at' or new.before_data->'status' is distinct from new.after_data->'status';end if;
  if not material then return new;end if;
  typ:=case when new.after_data->>'status'='canceled' then 'event.canceled' else 'event.rescheduled' end;kind:='event';
  perform boss_private.notification_cancel_reminders(new.resource_id,new.organization_id);
  safe:=jsonb_strip_nulls(jsonb_build_object('occurrence_key',new.after_data->>'occurrence_key','source_version',new.after_data->'version'));
 elsif new.action='registration.submit' then typ:='registration.submitted';kind:='registration';
 elsif new.action='registration.decision' and new.after_data->>'status' in ('approved','denied','waitlisted') then typ:='registration.'||(new.after_data->>'status');kind:='registration';
 elsif new.action='document.review' and new.after_data->>'status' in ('approved','rejected') then typ:='document.'||(new.after_data->>'status');kind:='registration_document';
 elsif new.action='payment.record_offline' then typ:='payment.recorded';kind:='payment';
 elsif new.action in ('charge.create','charge.create_from_registration') then typ:='fee.balance_due';kind:='charge';
 else return new;end if;
 if revision is null then revision:=new.id::text;end if;
 perform boss_private.notification_enqueue(case when kind='event' then 'calendar' else 'registration' end,kind,source,new.organization_id,typ,revision,safe);
 perform boss_private.notification_process(new.organization_id,100);
 return new;
end $$;
create trigger notification_source_audit after insert on public.audit_events for each row execute function boss_private.notification_audit_ingest();

create function boss_private.notification_message_ingest() returns trigger language plpgsql security definer set search_path='' as $$ declare kind text;begin
 if new.status<>'visible' then return new;end if;
 select t.kind into kind from public.communication_threads t where t.id=new.thread_id and t.organization_id=new.organization_id;
 perform boss_private.notification_enqueue('messaging','message',new.id,new.organization_id,case when kind='announcement' then 'communication.announcement' else 'communication.message' end,'1');
 perform boss_private.notification_process(new.organization_id,100);
 return new;
end $$;
create trigger notification_message_source after insert on public.communication_messages for each row execute function boss_private.notification_message_ingest();

create function boss_private.notification_generate_reminders(p_org uuid,p_start timestamptz,p_end timestamptz) returns integer
language plpgsql security definer set search_path='' as $$ declare row record;occ record;v_id uuid;count_created integer:=0;v_schedule timestamptz;begin
 if p_start is null or p_end is null or p_end<=p_start or p_end-p_start>interval '7 days' or p_start<now()-interval '1 day' or p_end>now()+interval '32 days' then raise exception 'Invalid notification operation' using errcode='PT422';end if;
 for row in select e event,r.minutes_before,r.id reminder_id from public.events e join public.event_reminders r on r.event_id=e.id and r.organization_id=e.organization_id
 where e.organization_id=p_org and e.status in ('scheduled','confirmed') and r.enabled and boss_private.calendar_module_enabled(p_org)
 and ((e.start_at<p_end+interval '7 days' and coalesce(e.recurrence_end_at,e.end_at)>p_start)
 or exists(select 1 from public.event_occurrence_exceptions ex where ex.event_id=e.id and ex.organization_id=e.organization_id and ex.is_active
 and ex.override_start_at<p_end+interval '7 days' and ex.override_end_at>p_start))
 order by e.id,r.id limit 50 loop
  for occ in select * from boss_private.calendar_occurrences(row.event,p_start,p_end+interval '7 days') limit 20 loop
   exit when count_created>=100;
   if occ.status not in ('scheduled','confirmed') then continue;end if;v_schedule:=occ.start_at-make_interval(mins=>row.minutes_before);
   if v_schedule<p_start or v_schedule>=p_end then continue;end if;
   v_id:=boss_private.notification_enqueue('calendar','event',(row.event).id,p_org,'event.reminder',(row.event).version||':'||occ.occurrence_key||':'||row.minutes_before,
    jsonb_build_object('occurrence_key',occ.occurrence_key,'start_at',occ.start_at,'source_version',(row.event).version,'offset_minutes',row.minutes_before,'reminder_id',row.reminder_id),v_schedule);
   if v_id is not null then count_created:=count_created+1;end if;
  end loop;exit when count_created>=100;
 end loop;
 for row in select r.id,r.version,r.status,r.document_status,o.closes_at from public.registrations r join public.registration_offerings o on o.id=r.offering_id and o.organization_id=r.organization_id
 where r.organization_id=p_org and r.status in ('draft','submitted','under_review') and boss_private.registration_feature(p_org,'registration') order by r.id limit 100 loop
  exit when count_created>=100;
  if row.document_status in ('missing','rejected','expired') then
   perform boss_private.notification_enqueue('registration','registration',row.id,p_org,'registration.missing_requirement',row.version||':'||current_date);count_created:=count_created+1;
  end if;
  if row.closes_at>=p_start and row.closes_at<p_end and count_created<100 then
   perform boss_private.notification_enqueue('registration','registration',row.id,p_org,'registration.deadline',row.version||':'||row.closes_at::text,'{}',greatest(now(),row.closes_at-interval '1 day'));count_created:=count_created+1;
  end if;
 end loop;
 for row in select c.*,boss_private.registration_charge_balance(c.id) balance from public.charges c where c.organization_id=p_org and c.status='active' and c.due_on is not null and boss_private.registration_feature(p_org,'fees') order by c.id limit 100 loop
  exit when count_created>=100;
  if (row.balance->>'balance_due_minor')::bigint<=0 then continue;end if;
  if row.due_on<current_date then perform boss_private.notification_enqueue('registration','charge',row.id,p_org,'fee.overdue',row.due_on||':'||current_date);count_created:=count_created+1;
  elsif row.due_on between current_date and p_end::date then perform boss_private.notification_enqueue('registration','charge',row.id,p_org,'fee.upcoming',row.due_on||':'||current_date);count_created:=count_created+1;end if;
 end loop;
 perform boss_private.notification_process(p_org,100);
 return count_created;
end $$;

create function boss_private.notifications_read(p_query jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;v_org uuid;v_view text;v_category text;v_limit integer;v_before timestamptz;inbox jsonb;preferences jsonb;history jsonb:='[]';orgs jsonb;ops jsonb;unread bigint;v_in_app boolean;begin
 actor:=boss_private.require_admin_actor();
 if p_query is null or jsonb_typeof(p_query)<>'object' or octet_length(p_query::text)>4096 or exists(select 1 from jsonb_object_keys(p_query) k where k not in ('view','organization_id','category','limit','before')) then raise exception 'Invalid notification operation' using errcode='PT422';end if;
 v_view:=coalesce(p_query->>'view','inbox');v_org:=(p_query->>'organization_id')::uuid;v_category:=p_query->>'category';v_limit:=coalesce((p_query->>'limit')::integer,50);v_before:=(p_query->>'before')::timestamptz;
 if v_view not in ('inbox','summary','preferences','history') or v_limit not between 1 and 50 or (v_category is not null and v_category not in ('events','registration','fees','communications','security')) then raise exception 'Invalid notification operation' using errcode='PT422';end if;
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

create function boss_private.notifications_mutate(p_request_id uuid,p_command jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
  if exists(select 1 from jsonb_object_keys(i) k where k not in ('channel','category','organization_id','team_id','enabled')) or i->>'channel' not in ('in_app','email') or i->>'category' not in ('events','registration','fees','communications','security') or jsonb_typeof(i->'enabled') is distinct from 'boolean' then raise exception 'Invalid notification operation' using errcode='PT422';end if;
  if i->>'channel' is null or i->>'category' is null then raise exception 'Invalid notification operation' using errcode='PT422';end if;
  team:=(i->>'team_id')::uuid;
  if team is not null and org is null then raise exception 'Access denied' using errcode='PT403';end if;
  if org is not null then perform boss_private.notifications_read(jsonb_build_object('organization_id',org));end if;
  if team is not null and not boss_private.comm_context_related(actor,org,'team',team) and not boss_private.comm_permission(actor,'notifications.manage',org,'team',team) then raise exception 'Access denied' using errcode='PT403';end if;
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

-- Private arbitrary-recipient and worker code has no Data API execute grant.
DO $$declare f record;begin for f in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and (p.proname like 'notification_%' or p.proname in ('notifications_read','notifications_mutate')) loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.f);end loop;end $$;
create function public.boss_notifications_read(p_query jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$ select boss_private.notifications_read(p_query) $$;
create function public.boss_notifications_mutate(p_request_id uuid,p_command jsonb) returns jsonb language sql security invoker set search_path='' as $$ select boss_private.notifications_mutate(p_request_id,p_command) $$;
revoke all on function public.boss_notifications_read(jsonb),public.boss_notifications_mutate(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function boss_private.notifications_read(jsonb),boss_private.notifications_mutate(uuid,jsonb),public.boss_notifications_read(jsonb),public.boss_notifications_mutate(uuid,jsonb) to authenticated;
