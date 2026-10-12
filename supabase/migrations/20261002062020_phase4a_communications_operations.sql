-- Finite, caller-bound commands; every retry reauthorizes current resource context.
create function boss_private.comm_validate(i jsonb,allowed text[],required text[] default '{}') returns void language plpgsql set search_path='' as $$
declare k text;begin
 if jsonb_typeof(i) is distinct from 'object' then raise exception 'Invalid communication request.' using errcode='PT422';end if;
 for k in select jsonb_object_keys(i) loop if not k=any(allowed) or i->k='null'::jsonb then raise exception 'Invalid communication request.' using errcode='PT422';end if;end loop;
 foreach k in array required loop if not i?k then raise exception 'Invalid communication request.' using errcode='PT422';end if;end loop;
end $$;
create function boss_private.comm_text(p_value jsonb,p_max integer) returns text language plpgsql immutable set search_path='' as $$
declare v text;begin v:=p_value#>>'{}';if jsonb_typeof(p_value) is distinct from 'string' or length(btrim(v)) not between 1 and p_max or regexp_replace(v,E'[\t\n\r]','','g')~'[[:cntrl:]]' then raise exception 'Invalid communication content.' using errcode='PT422';end if;return btrim(v);end $$;
create function boss_private.comm_audit(p_actor uuid,p_operation text,p_resource uuid,p_org uuid,p_thread uuid default null,p_fields jsonb default '{}') returns void language plpgsql security definer set search_path='' as $$
declare t public.communication_threads;begin
 if p_thread is not null then select * into t from public.communication_threads where id=p_thread;end if;
 insert into public.audit_events(actor_person_id,actor_auth_user_id,organization_id,scope_type,scope_id,action,resource_type,resource_id,after_data)
 values(p_actor,auth.uid(),p_org,case when t.scope_type='unit' then 'organization_unit' when t.scope_type='team' then 'team' when p_org is not null then 'organization' else 'platform' end,
 case when t.scope_type in('unit','team') then t.scope_id else p_org end,'communications.'||p_operation,'communication',p_resource,p_fields);
end $$;
create function boss_private.comm_can_create(p_actor uuid,p_org uuid,p_kind text,p_scope_type text,p_scope uuid) returns boolean language sql stable security definer set search_path='' as $$
 select boss_private.comm_feature(p_org,'communications') and case
 when p_kind in('team_chat','coach_staff') then p_scope_type='team' and boss_private.comm_feature(p_org,'team_chat') and boss_private.comm_permission(p_actor,'communications.manage',p_org,p_scope_type,p_scope)
 when p_kind in('direct','group','family') then boss_private.comm_feature(p_org,'direct_messaging') and
 (boss_private.comm_permission(p_actor,'communications.send',p_org,p_scope_type,p_scope) or (p_scope_type='team' and boss_private.comm_permission(p_actor,'team_chat.send',p_org,p_scope_type,p_scope)) or boss_private.comm_family_send(p_actor,p_org,p_scope_type,p_scope))
 when p_kind='organization_staff' then p_scope_type='organization' and boss_private.comm_permission(p_actor,'communications.manage',p_org,p_scope_type,p_scope)
 when p_kind='program' then p_scope_type='unit' and boss_private.comm_permission(p_actor,'communications.manage',p_org,p_scope_type,p_scope)
 else false end $$;
create function boss_private.comm_validate_members(p_actor uuid,p_org uuid,p_kind text,p_scope_type text,p_scope uuid,p_members jsonb,p_household uuid default null) returns uuid[] language plpgsql stable security definer set search_path='' as $$
declare a uuid[];v uuid;g uuid;begin
 if jsonb_typeof(p_members) is distinct from 'array' or jsonb_array_length(p_members)>20 then raise exception 'Invalid group membership.' using errcode='PT422';end if;
 select array_agg(distinct id) into a from(select (value#>>'{}')::uuid id from jsonb_array_elements(p_members) union select p_actor)s;
 if cardinality(a)>20 or (p_kind='direct' and cardinality(a)<>2) or cardinality(a)<2 then raise exception 'Invalid group membership.' using errcode='PT422';end if;
 foreach v in array a loop
 if not boss_private.comm_person_active(v) or not (boss_private.comm_context_related(v,p_org,p_scope_type,p_scope) or boss_private.comm_permission(v,'communications.view',p_org,p_scope_type,p_scope)) then raise exception 'Access denied.' using errcode='PT403';end if;
 if p_kind='direct' and boss_private.comm_is_minor(v) then raise exception 'Direct minor communication is disabled.' using errcode='PT403';end if;
 if boss_private.comm_is_minor(v) and v<>p_actor and not (boss_private.comm_permission(p_actor,'communications.send',p_org,p_scope_type,p_scope) or (p_scope_type='team' and boss_private.comm_permission(p_actor,'team_chat.send',p_org,p_scope_type,p_scope)) or boss_private.comm_guardian(p_actor,v,'can_send_communications')) then raise exception 'Minor recipient authority is required.' using errcode='PT403';end if;
 if exists(select 1 from public.participants where person_id=v and status='active') and not boss_private.comm_participant_allowed(v,p_org) then raise exception 'Participant communication is disabled.' using errcode='PT403';end if;
 if boss_private.comm_is_minor(v) and (not boss_private.comm_participant_allowed(v,p_org) or not exists(select 1 from unnest(a)x where boss_private.comm_guardian(x,v,'can_receive_communications'))) then raise exception 'Current guardian visibility is required.' using errcode='PT403';end if;
 if p_kind='family' then
 if p_household is null or not exists(select 1 from public.households h join public.household_memberships m on m.household_id=h.id where h.id=p_household and h.status='active' and m.person_id=v and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()))
 or not exists(select 1 from unnest(a)x where boss_private.comm_guardian(v,x,'can_receive_communications') or boss_private.comm_guardian(x,v,'can_receive_communications')) then raise exception 'Access denied.' using errcode='PT403';end if;
 end if;end loop;return a;
end $$;
create function boss_private.comm_group_safe(p_thread uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare t public.communication_threads;m record;begin select * into t from public.communication_threads where id=p_thread;if t.kind not in('group','family','direct') then return true;end if;
 for m in select person_id from public.communication_thread_members where thread_id=p_thread and status='active' and starts_at<=now() and (ends_at is null or ends_at>now()) loop
 if t.kind='family' and not exists(select 1 from public.household_memberships hm join public.households hh on hh.id=hm.household_id where hm.household_id=t.household_id and hh.status='active' and hm.person_id=m.person_id and hm.status='active' and hm.starts_at<=now() and (hm.ends_at is null or hm.ends_at>now())) then return false;end if;
 if t.kind='direct' and boss_private.comm_is_minor(m.person_id) then return false;end if;
 if (exists(select 1 from public.participants where person_id=m.person_id and status='active') or boss_private.comm_is_minor(m.person_id)) and
 (not boss_private.comm_participant_allowed(m.person_id,t.organization_id) or (boss_private.comm_is_minor(m.person_id) and not exists(select 1 from public.communication_thread_members g
 where g.thread_id=t.id and g.status='active' and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now()) and boss_private.comm_guardian(g.person_id,m.person_id,'can_receive_communications')))) then return false;end if;
 end loop;return true;end $$;
create or replace function boss_private.comm_thread_can_send(p_thread uuid,p_person uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.comm_thread_can_view(t.id,p_person) and t.kind not in('announcement','system') and boss_private.comm_group_safe(t.id) and
 case when t.kind in('team_chat','coach_staff') then boss_private.comm_permission(p_person,'team_chat.send',t.organization_id,t.scope_type,t.scope_id) or (t.kind='team_chat' and boss_private.comm_family_send(p_person,t.organization_id,t.scope_type,t.scope_id))
 when t.kind='family' then boss_private.comm_family_send(p_person,t.organization_id,t.scope_type,t.scope_id)
 when t.kind='group' and exists(select 1 from public.communication_thread_members mm where mm.thread_id=t.id and mm.status='active' and boss_private.comm_is_minor(mm.person_id)) then
 boss_private.comm_permission(p_person,'communications.send',t.organization_id,t.scope_type,t.scope_id) or (t.scope_type='team' and boss_private.comm_permission(p_person,'team_chat.send',t.organization_id,t.scope_type,t.scope_id)) or (boss_private.comm_is_minor(p_person) and boss_private.comm_participant_allowed(p_person,t.organization_id))
 or exists(select 1 from public.communication_thread_members mm where mm.thread_id=t.id and mm.status='active' and boss_private.comm_guardian(p_person,mm.person_id,'can_send_communications'))
 else boss_private.comm_permission(p_person,'communications.send',t.organization_id,t.scope_type,t.scope_id) or (t.kind in('direct','group') and ((t.scope_type='team' and boss_private.comm_permission(p_person,'team_chat.send',t.organization_id,t.scope_type,t.scope_id)) or boss_private.comm_family_send(p_person,t.organization_id,t.scope_type,t.scope_id))) end
 from public.communication_threads t where t.id=p_thread),false) $$;
create function boss_private.comm_message_operations(p_message uuid,p_actor uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce((select to_jsonb(array_remove(array[
 case when boss_private.comm_message_can_view(m.id,p_actor) then 'read.message' end,
 case when boss_private.comm_message_can_view(m.id,p_actor) and boss_private.comm_feature(m.organization_id,'moderation') then 'report.create' end,
 case when boss_private.comm_message_can_view(m.id,p_actor) and m.author_person_id=p_actor and m.created_at+make_interval(mins=>boss_private.comm_policy_number(m.organization_id,'sender_edit_minutes'))>now() and boss_private.comm_thread_can_send(m.thread_id,p_actor) then 'message.edit' end,
 case when boss_private.comm_message_can_view(m.id,p_actor) and ((m.author_person_id=p_actor and m.created_at+make_interval(mins=>boss_private.comm_policy_number(m.organization_id,'sender_edit_minutes'))>now()) or (boss_private.comm_feature(m.organization_id,'moderation') and boss_private.comm_thread_manage(m.thread_id,p_actor,'moderation.manage'))) then 'message.remove' end,
 case when boss_private.comm_message_can_view(m.id,p_actor) and boss_private.comm_thread_manage(m.thread_id,p_actor) then 'message.pin' end],null))
 from public.communication_messages m where m.id=p_message),'[]'::jsonb) $$;
create function boss_private.comm_attachment_can_send(p_thread uuid,p_actor uuid) returns boolean language sql stable security definer set search_path='' as $$
 select boss_private.comm_thread_can_send(p_thread,p_actor) or coalesce((select t.kind='announcement' and boss_private.comm_thread_can_view(t.id,p_actor) and boss_private.comm_thread_manage(t.id,p_actor,'announcements.send') and exists(select 1 from public.communication_messages m where m.thread_id=t.id and m.status='visible') from public.communication_threads t where t.id=p_thread),false) $$;
create function boss_private.comm_command(p_actor uuid,p_operation text,i jsonb,p_replay boolean default false,p_resource uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare t public.communication_threads;m public.communication_messages;at public.communication_attachments;v_report public.communication_reports;g public.guardian_relationships;
 org uuid;v_resource uuid:=coalesce(p_resource,gen_random_uuid());v bigint:=1;s bigint;members uuid[];x uuid;target jsonb;role uuid;v_key text;conf jsonb;obj text;fields jsonb:='{}';expires timestamptz;result jsonb;
begin
 if p_actor is distinct from boss_private.current_person_id() then raise exception 'Access denied.' using errcode='PT403';end if;
 if p_operation='thread.create' then
 perform boss_private.comm_validate(i,array['organization_id','kind','title','scope_type','scope_id','members','household_id'],array['organization_id','kind','title','scope_type','scope_id']);
 org:=(i->>'organization_id')::uuid;
 if not boss_private.comm_can_create(p_actor,org,i->>'kind',i->>'scope_type',(i->>'scope_id')::uuid) then raise exception 'Access denied.' using errcode='PT403';end if;
 if i->>'kind' in('direct','group','family') then members:=boss_private.comm_validate_members(p_actor,org,i->>'kind',i->>'scope_type',(i->>'scope_id')::uuid,coalesce(i->'members','[]'),(i->>'household_id')::uuid);
 elsif i?'members' or i?'household_id' then raise exception 'Invalid communication request.' using errcode='PT422';end if;
 if p_replay then if not boss_private.comm_thread_can_view(v_resource,p_actor) then raise exception 'Access denied.' using errcode='PT403';end if;return jsonb_build_object('resource_id',v_resource);end if;
 perform boss_private.comm_text(i->'title',200);
 insert into public.communication_threads(id,organization_id,kind,title,scope_type,scope_id,household_id,created_by_person_id) values(v_resource,org,i->>'kind',i->>'title',i->>'scope_type',(i->>'scope_id')::uuid,(i->>'household_id')::uuid,p_actor);
 if members is not null then insert into public.communication_thread_members(organization_id,thread_id,person_id) select org,v_resource,unnest(members);end if;
 fields:=jsonb_build_object('kind',i->>'kind','member_count',coalesce(cardinality(members),0));
 elsif p_operation='announcement.send' then
 perform boss_private.comm_validate(i,array['organization_id','title','body','visibility','targets','attachment_ids'],array['organization_id','title','body','targets']);org:=(i->>'organization_id')::uuid;
 if not boss_private.comm_feature(org,'communications') or not boss_private.comm_feature(org,'announcements') or jsonb_typeof(i->'targets') is distinct from 'array' or jsonb_array_length(i->'targets') not between 1 and 50 then raise exception 'Access denied.' using errcode='PT403';end if;
 for target in select value from jsonb_array_elements(i->'targets') loop
 perform boss_private.comm_validate(target,array['scope_type','scope_id','role_key'],array['scope_type','scope_id']);
 if not boss_private.comm_permission(p_actor,'announcements.send',org,target->>'scope_type',(target->>'scope_id')::uuid) then raise exception 'Access denied.' using errcode='PT403';end if;
 if target?'role_key' and not exists(select 1 from public.roles rr where rr.key=target->>'role_key' and rr.status='active' and (case target->>'scope_type' when 'unit' then 'organization_unit' else target->>'scope_type' end)=any(rr.allowed_scope_types)) then raise exception 'Invalid audience.' using errcode='PT422';end if;end loop;
 if coalesce(i->>'visibility','private') not in('private','public') or (i->>'visibility'='public' and not boss_private.comm_permission(p_actor,'communications.manage',org,'organization',org)) then raise exception 'Public announcement publication is unavailable.' using errcode='PT403';end if;
 if i?'attachment_ids' then raise exception 'Create the announcement before adding private attachments.' using errcode='PT422';end if;
 if p_replay then if not boss_private.comm_thread_manage(v_resource,p_actor,'announcements.send') then raise exception 'Access denied.' using errcode='PT403';end if;return jsonb_build_object('resource_id',v_resource);end if;
 perform boss_private.comm_text(i->'title',200);perform boss_private.comm_text(i->'body',8000);
 insert into public.communication_threads(id,organization_id,kind,title,scope_type,scope_id,created_by_person_id,visibility,next_sequence) values(v_resource,org,'announcement',i->>'title','organization',org,p_actor,coalesce(i->>'visibility','private'),1);
 for target in select value from jsonb_array_elements(i->'targets') loop
 select r.id into role from public.roles r where r.key=target->>'role_key';
 insert into public.communication_audiences(organization_id,thread_id,scope_type,scope_id,role_id) values(org,v_resource,target->>'scope_type',(target->>'scope_id')::uuid,role) on conflict do nothing;
 end loop;
 insert into public.communication_messages(organization_id,thread_id,author_person_id,body,sequence_number) values(org,v_resource,p_actor,i->>'body',1);
 fields:=jsonb_build_object('target_count',jsonb_array_length(i->'targets'),'visibility',coalesce(i->>'visibility','private'));
 elsif p_operation='guardian.configure' then
 perform boss_private.comm_validate(i,array['guardian_relationship_id','can_receive_communications','can_send_communications'],array['guardian_relationship_id']);
 select * into g from public.guardian_relationships where public.guardian_relationships.id=(i->>'guardian_relationship_id')::uuid for update;
 if not found or g.verified_at is null or g.verified_at>now() or not boss_private.has_permission('person.profile.manage') or not exists(select 1 from public.role_assignments a join public.roles rr on rr.id=a.role_id join public.role_permissions rp on rp.role_id=rr.id join public.permissions pp on pp.id=rp.permission_id where a.person_id=p_actor and a.scope_type='platform' and a.status='active' and rr.status='active' and pp.status='active' and pp.key='communications.manage' and a.starts_at<=now() and (a.ends_at is null or a.ends_at>now())) then raise exception 'Access denied.' using errcode='PT403';end if;
 if (i?'can_receive_communications' and jsonb_typeof(i->'can_receive_communications')<>'boolean') or (i?'can_send_communications' and jsonb_typeof(i->'can_send_communications')<>'boolean') then raise exception 'Invalid capability.' using errcode='PT422';end if;
 if not p_replay then update public.guardian_relationships set can_receive_communications=coalesce((i->>'can_receive_communications')::boolean,g.can_receive_communications),can_send_communications=coalesce((i->>'can_send_communications')::boolean,g.can_send_communications),updated_at=now() where public.guardian_relationships.id=g.id;end if;
 v_resource:=g.id;fields:=jsonb_build_object('changed_fields',to_jsonb(array(select k from jsonb_object_keys(i) k where k<>'guardian_relationship_id')));
 elsif p_operation='communications.configure' then
 perform boss_private.comm_validate(i,array['organization_id','configuration'],array['organization_id','configuration']);org:=(i->>'organization_id')::uuid;
 if not boss_private.comm_permission(p_actor,'communications.manage',org,'organization',org) then raise exception 'Access denied.' using errcode='PT403';end if;
 perform boss_private.comm_validate(i->'configuration',array['communications','announcements','team_chat','staff_send','direct_messaging','guardian_visibility','participant_messaging','minor_groups','attachments','moderation','in_app_notifications','email_notifications','minimum_participant_age','sender_edit_minutes']);
 for v_key,conf in select k,val from jsonb_each(i->'configuration')e(k,val) loop
 if v_key in('minimum_participant_age','sender_edit_minutes') then if jsonb_typeof(conf)<>'number' or conf::text!~'^[0-9]{1,2}$' or conf::integer>(case when v_key='sender_edit_minutes' then 60 else 99 end) then raise exception 'Invalid policy.' using errcode='PT422';end if;
 elsif jsonb_typeof(conf)<>'boolean' then raise exception 'Invalid feature.' using errcode='PT422';end if;end loop;
 select om.configuration,om.id into conf,v_resource from public.organization_modules om join public.modules mm on mm.id=om.module_id where om.organization_id=org and mm.key='messaging' and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()) order by om.starts_at desc limit 1 for update of om;
 if not found then raise exception 'Activate Communications before configuring it.' using errcode='PT409';end if;
 conf:=conf||(i->'configuration');
 if coalesce((conf->>'minimum_participant_age')::integer,18)<18 and (conf->'minor_groups' is distinct from 'true'::jsonb or conf->'guardian_visibility' is distinct from 'true'::jsonb) then raise exception 'Minor group communication requires guardian visibility.' using errcode='PT422';end if;
 if not p_replay then update public.organization_modules set configuration=conf,updated_at=now() where public.organization_modules.id=v_resource;end if;
 fields:=jsonb_build_object('changed_fields',to_jsonb(array(select jsonb_object_keys(i->'configuration'))));
 else
 if i?'thread_id' then select * into t from public.communication_threads where public.communication_threads.id=(i->>'thread_id')::uuid for update;
 elsif i?'message_id' then select * into m from public.communication_messages where public.communication_messages.id=(i->>'message_id')::uuid for update;select * into t from public.communication_threads where public.communication_threads.id=m.thread_id for update;
 elsif i?'attachment_id' then select * into at from public.communication_attachments where public.communication_attachments.id=(i->>'attachment_id')::uuid for update;select * into t from public.communication_threads where public.communication_threads.id=at.thread_id for update;
 elsif i?'report_id' then select * into v_report from public.communication_reports where public.communication_reports.id=(i->>'report_id')::uuid for update;select * into m from public.communication_messages where public.communication_messages.id=v_report.message_id for update;select * into t from public.communication_threads where public.communication_threads.id=m.thread_id for update;
 end if;
 if t.id is null or not boss_private.comm_thread_can_view(t.id,p_actor) then raise exception 'Access denied.' using errcode='PT403';end if;org:=t.organization_id;
 if p_operation='thread.update' then
 perform boss_private.comm_validate(i,array['thread_id','expected_version','title','status','members'],array['thread_id','expected_version']);
 if not boss_private.comm_thread_manage(t.id,p_actor) then raise exception 'Access denied.' using errcode='PT403';end if;
 if i?'members' then if t.kind not in('direct','group','family') then raise exception 'Invalid membership operation.' using errcode='PT422';end if;members:=boss_private.comm_validate_members(p_actor,org,t.kind,t.scope_type,t.scope_id,i->'members',t.household_id);end if;
 if i?'title' then perform boss_private.comm_text(i->'title',200);end if;
 if i?'status' and i->>'status' not in('active','archived') then raise exception 'Invalid lifecycle.' using errcode='PT422';end if;
 v_resource:=t.id;if p_replay then return jsonb_build_object('resource_id',v_resource);end if;if t.version<>(i->>'expected_version')::bigint then raise exception 'Communication changed; reload.' using errcode='PT409';end if;
 if members is not null then update public.communication_thread_members set status='inactive',ends_at=greatest(now(),starts_at+interval '1 microsecond') where thread_id=t.id and not person_id=any(members);
 insert into public.communication_thread_members(organization_id,thread_id,person_id) select org,t.id,unnest(members) on conflict(thread_id,person_id) do update set status='active',ends_at=null;end if;
 update public.communication_threads set title=coalesce(i->>'title',title),status=coalesce(i->>'status',status),version=version+1,updated_at=now() where public.communication_threads.id=t.id returning version into v;
 fields:=jsonb_build_object('changed_fields',to_jsonb(array(select jsonb_object_keys(i))));
 elsif p_operation='message.send' then
 perform boss_private.comm_validate(i,array['thread_id','body','attachment_ids'],array['thread_id','body']);
 if not boss_private.comm_thread_can_send(t.id,p_actor) or not boss_private.comm_group_safe(t.id) then raise exception 'Access denied.' using errcode='PT403';end if;
 perform boss_private.comm_text(i->'body',8000);
 if p_replay then if not boss_private.comm_message_can_view(v_resource,p_actor) then raise exception 'Access denied.' using errcode='PT403';end if;return jsonb_build_object('resource_id',v_resource);end if;
 if (select count(*) from public.communication_messages where author_person_id=p_actor and created_at>now()-interval '1 minute')>=30 then raise exception 'Please wait before sending another message.' using errcode='PT429';end if;
 update public.communication_threads set next_sequence=next_sequence+1,updated_at=now() where public.communication_threads.id=t.id returning next_sequence into s;
 insert into public.communication_messages(id,organization_id,thread_id,author_person_id,body,sequence_number) values(v_resource,org,t.id,p_actor,i->>'body',s);
 if i?'attachment_ids' then
 if not boss_private.comm_feature(org,'attachments') or jsonb_typeof(i->'attachment_ids') is distinct from 'array' or jsonb_array_length(i->'attachment_ids')>5 then raise exception 'Invalid attachments.' using errcode='PT422';end if;
 for x in select (value#>>'{}')::uuid from jsonb_array_elements(i->'attachment_ids') loop
 update public.communication_attachments set message_id=v_resource,status='attached' where public.communication_attachments.id=x and thread_id=t.id and actor_person_id=p_actor and status='ready' and message_id is null;
 if not found then raise exception 'Access denied.' using errcode='PT403';end if;end loop;end if;
 elsif p_operation in('message.edit','message.remove','message.pin') then
 perform boss_private.comm_validate(i,array['message_id','expected_version','body','reason','pinned'],array['message_id','expected_version']);
 if p_replay and p_operation='message.remove' then if not ((m.author_person_id=p_actor and m.created_at+make_interval(mins=>boss_private.comm_policy_number(org,'sender_edit_minutes'))>now()) or (boss_private.comm_feature(org,'moderation') and boss_private.comm_thread_manage(t.id,p_actor,'moderation.manage'))) then raise exception 'Access denied.' using errcode='PT403';end if;return jsonb_build_object('resource_id',m.id);end if;
 if not boss_private.comm_message_operations(m.id,p_actor)?p_operation then raise exception 'Access denied.' using errcode='PT403';end if;
 v_resource:=m.id;if p_replay then return jsonb_build_object('resource_id',v_resource);end if;if m.version<>(i->>'expected_version')::bigint then raise exception 'Message changed; reload.' using errcode='PT409';end if;
 if p_operation='message.edit' then perform boss_private.comm_text(i->'body',8000);insert into public.communication_message_revisions(organization_id,message_id,version,body,actor_person_id) values(org,m.id,m.version,m.body,p_actor);update public.communication_messages set body=i->>'body',version=version+1,edited_at=now() where public.communication_messages.id=m.id returning version into v;
 elsif p_operation='message.remove' then
 if m.author_person_id<>p_actor then perform boss_private.comm_text(i->'reason',500);end if;
 update public.communication_messages set status='removed',removed_at=now(),pinned_at=null,version=version+1 where public.communication_messages.id=m.id returning version into v;update public.communication_attachments set status='removed' where message_id=m.id;
 fields:=jsonb_build_object('moderator',m.author_person_id<>p_actor);
 else if jsonb_typeof(i->'pinned') is distinct from 'boolean' then raise exception 'Invalid pin state.' using errcode='PT422';end if;
 update public.communication_messages set pinned_at=case when (i->>'pinned')::boolean then now() end,version=version+1 where public.communication_messages.id=m.id returning version into v;fields:=jsonb_build_object('pinned',(i->>'pinned')::boolean);end if;
 elsif p_operation in('read.message','read.thread') then
 perform boss_private.comm_validate(i,array['message_id','thread_id','through_sequence']);
 if p_operation='read.message' then if not boss_private.comm_message_can_view(m.id,p_actor) then raise exception 'Access denied.' using errcode='PT403';end if;s:=m.sequence_number;v_resource:=m.id;
 else s:=coalesce((i->>'through_sequence')::bigint,t.next_sequence);v_resource:=t.id;if s<0 or s>t.next_sequence then raise exception 'Invalid read position.' using errcode='PT422';end if;end if;
 if p_replay then return jsonb_build_object('resource_id',v_resource);end if;
 insert into public.communication_read_state(organization_id,thread_id,person_id,through_sequence) values(org,t.id,p_actor,s) on conflict(thread_id,person_id) do update set through_sequence=greatest(public.communication_read_state.through_sequence,excluded.through_sequence),read_at=now();
 elsif p_operation='report.create' then
 perform boss_private.comm_validate(i,array['message_id','reason','detail'],array['message_id','reason']);
 if not boss_private.comm_message_can_view(m.id,p_actor) or not boss_private.comm_feature(org,'moderation') then raise exception 'Access denied.' using errcode='PT403';end if;
 if i->>'reason' not in('spam','harassment','unsafe','other') or (i?'detail' and length(i->>'detail')>500) then raise exception 'Invalid report.' using errcode='PT422';end if;
 if p_replay then return jsonb_build_object('resource_id',v_resource);end if;
 insert into public.communication_reports(id,organization_id,message_id,reporter_person_id,reason,detail) values(v_resource,org,m.id,p_actor,i->>'reason',i->>'detail');fields:=jsonb_build_object('reason',i->>'reason');
 elsif p_operation='report.moderate' then
 perform boss_private.comm_validate(i,array['report_id','status','remove','reason'],array['report_id','status','reason']);
 if not boss_private.comm_feature(org,'moderation') or not boss_private.comm_thread_manage(t.id,p_actor,'moderation.manage') then raise exception 'Access denied.' using errcode='PT403';end if;
 perform boss_private.comm_text(i->'reason',500);if i->>'status' not in('reviewed','dismissed','actioned') or (i?'remove' and jsonb_typeof(i->'remove')<>'boolean') then raise exception 'Invalid moderation.' using errcode='PT422';end if;
 v_resource:=v_report.id;if p_replay then return jsonb_build_object('resource_id',v_resource);end if;
 update public.communication_reports set status=i->>'status',moderator_person_id=p_actor,moderation_reason=i->>'reason',reviewed_at=now() where public.communication_reports.id=v_report.id;
 if coalesce((i->>'remove')::boolean,false) then update public.communication_messages set status='removed',removed_at=now(),pinned_at=null,version=version+1 where public.communication_messages.id=m.id;update public.communication_attachments set status='removed' where message_id=m.id;end if;fields:=jsonb_build_object('status',i->>'status','removed',coalesce((i->>'remove')::boolean,false));
 elsif p_operation='attachment.intent' then
 perform boss_private.comm_validate(i,array['thread_id','file_name','mime_type','size_bytes','content_sha256'],array['thread_id','file_name','mime_type','size_bytes','content_sha256']);
 if not boss_private.comm_feature(org,'attachments') or not boss_private.comm_attachment_can_send(t.id,p_actor) or not boss_private.comm_group_safe(t.id) then raise exception 'Access denied.' using errcode='PT403';end if;
 perform boss_private.comm_text(i->'file_name',200);
 if i->>'mime_type' not in('application/pdf','image/jpeg','image/png') or (i->>'size_bytes')::bigint not between 1 and 5242880 or i->>'content_sha256'!~'^[0-9a-f]{64}$' then raise exception 'Invalid file.' using errcode='PT422';end if;
 if p_replay then
 select * into at from public.communication_attachments where public.communication_attachments.id=v_resource;
 if at.actor_person_id is distinct from p_actor or not exists(select 1 from boss_private.communication_upload_intents u where u.attachment_id=v_resource and u.actor_person_id=p_actor and u.auth_session_id=(auth.jwt()->>'session_id')::uuid) then raise exception 'Access denied.' using errcode='PT403';end if;
 if at.status in('ready','attached') and at.completed_at is not null and exists(select 1 from boss_private.communication_upload_intents u where u.attachment_id=v_resource and u.consumed_at is not null)
 and exists(select 1 from boss_private.communication_operation_receipts r where r.actor_person_id=p_actor and r.command->>'operation'='attachment.complete' and r.result->>'resource_id'=v_resource::text) then result:=jsonb_build_object('completed',true,'status',at.status);
 elsif at.status<>'upload_pending' or not exists(select 1 from boss_private.communication_upload_intents u where u.attachment_id=v_resource and u.expires_at>now() and u.consumed_at is null) then raise exception 'Upload intent expired.' using errcode='PT409';end if;obj:=at.object_name;
 else obj:=org::text||'/'||t.id::text||'/'||v_resource::text||'/'||gen_random_uuid()::text;expires:=now()+interval '15 minutes';
 insert into public.communication_attachments(id,organization_id,thread_id,actor_person_id,file_name,mime_type,size_bytes,content_sha256,object_name) values(v_resource,org,t.id,p_actor,i->>'file_name',i->>'mime_type',(i->>'size_bytes')::bigint,i->>'content_sha256',obj);
 insert into boss_private.communication_upload_intents(attachment_id,actor_person_id,auth_session_id,expires_at) values(v_resource,p_actor,(auth.jwt()->>'session_id')::uuid,expires);end if;
 result:=coalesce(result,'{}')||jsonb_build_object('attachment_id',v_resource,'id',v_resource,'bucket','boss-communication-attachments','object_path',obj,'object_name',obj,'expires_at',expires);
 elsif p_operation='attachment.complete' then
 perform boss_private.comm_validate(i,array['attachment_id'],array['attachment_id']);v_resource:=at.id;
 if not boss_private.comm_feature(org,'attachments') or not boss_private.comm_attachment_can_send(t.id,p_actor) or at.actor_person_id<>p_actor then raise exception 'Access denied.' using errcode='PT403';end if;
 if p_replay then return jsonb_build_object('resource_id',v_resource);end if;
 if at.status<>'upload_pending' or not exists(select 1 from boss_private.communication_upload_intents u where u.attachment_id=at.id and u.actor_person_id=p_actor and u.auth_session_id=(auth.jwt()->>'session_id')::uuid and u.expires_at>now() and u.consumed_at is null)
 or not exists(select 1 from storage.objects o where o.bucket_id='boss-communication-attachments' and o.name=at.object_name and o.metadata->>'mimetype'=at.mime_type and o.metadata->>'size'~'^[0-9]{1,10}$' and (o.metadata->>'size')::bigint=at.size_bytes) then raise exception 'The private upload is unavailable.' using errcode='PT409';end if;
 update boss_private.communication_upload_intents set consumed_at=now() where attachment_id=at.id;update public.communication_attachments set status=case when t.kind='announcement' then 'attached' else 'ready' end,message_id=case when t.kind='announcement' then (select mm.id from public.communication_messages mm where mm.thread_id=t.id and mm.status='visible' order by mm.sequence_number limit 1) end,completed_at=now() where public.communication_attachments.id=at.id returning status into obj;
 result:=jsonb_build_object('attachment_id',v_resource,'completed',true,'status',obj);
 elsif p_operation='attachment.access' then
 perform boss_private.comm_validate(i,array['attachment_id'],array['attachment_id']);v_resource:=at.id;
 if not boss_private.comm_feature(org,'attachments') or at.status<>'attached' or not boss_private.comm_message_can_view(at.message_id,p_actor) then raise exception 'Access denied.' using errcode='PT403';end if;
 expires:=now()+interval '2 minutes';insert into boss_private.communication_access_leases(attachment_id,actor_person_id,auth_session_id,expires_at) values(at.id,p_actor,(auth.jwt()->>'session_id')::uuid,expires);
 result:=jsonb_build_object('attachment_id',v_resource,'id',v_resource,'bucket','boss-communication-attachments','object_path',at.object_name,'object_name',at.object_name,'file_name',at.file_name,'mime_type',at.mime_type,'size_bytes',at.size_bytes,'expires_at',expires);
 else raise exception 'Unsupported communication operation.' using errcode='PT422';end if;
 end if;
 if not p_replay and p_operation not in('read.message','read.thread') then perform boss_private.comm_audit(p_actor,p_operation,v_resource,org,t.id,fields);end if;
 return coalesce(result,'{}')||jsonb_build_object('operation',p_operation,'resource_id',v_resource,'version',v);
end $$;
create function boss_private.comm_mutate(p_request_id uuid,p_command jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;op text;i jsonb;h bytea;r boss_private.communication_operation_receipts;result jsonb;begin
 actor:=boss_private.require_admin_actor();
 perform boss_private.comm_validate(p_command,array['operation','input'],array['operation','input']);
 if p_request_id is null or octet_length(p_command::text)>32768 or jsonb_typeof(p_command->'operation')<>'string' then raise exception 'Invalid communication request.' using errcode='PT422';end if;
 op:=p_command->>'operation';i:=p_command->'input';h:=sha256(convert_to(p_command::text,'UTF8'));
 perform pg_advisory_xact_lock(hashtextextended('communication-request:'||actor::text||':'||p_request_id::text,0));
 -- Access leases must never replay a bearer-like object response without a fresh audited authorization.
 if op<>'attachment.access' then select * into r from boss_private.communication_operation_receipts where actor_person_id=actor and request_id=p_request_id;
 if found then if r.input_hash<>h then raise exception 'Conflicting request.' using errcode='PT409';end if;
 result:=boss_private.comm_command(actor,op,i,true,(r.result->>'resource_id')::uuid);
 if op='attachment.intent' and result->'completed'='true'::jsonb then return r.result||jsonb_build_object('completed',true,'status',result->'status');end if;return r.result;end if;end if;
 result:=boss_private.comm_command(actor,op,i)||jsonb_build_object('request_id',p_request_id);
 if op<>'attachment.access' then insert into boss_private.communication_operation_receipts(actor_person_id,request_id,input_hash,command,result) values(actor,p_request_id,h,jsonb_build_object('operation',op,'resource_id',result->'resource_id'),result);end if;return result;
 exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' or sqlstate 'PT429' then raise;
 when unique_violation or serialization_failure or deadlock_detected then raise exception 'Communication changed; reload.' using errcode='PT409';
 when others then raise exception 'Invalid communication request.' using errcode='PT422';end $$;
create function boss_private.comm_thread_summary(p_thread uuid,p_actor uuid,p_unread bigint default null) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',t.id,'organization_id',t.organization_id,'kind',t.kind,'thread_type',t.kind,'title',t.title,'scope_type',t.scope_type,'scope_id',t.scope_id,
 'version',t.version,'status',t.status,'visibility',t.visibility,'updated_at',t.updated_at,'members',case when t.kind in('direct','group','family') then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'label',coalesce(p.display_name,p.preferred_name,'Boss member'))) from public.communication_thread_members mm join public.people p on p.id=mm.person_id where mm.thread_id=t.id and mm.status='active' and mm.starts_at<=now() and (mm.ends_at is null or mm.ends_at>now())),'[]'::jsonb) else '[]'::jsonb end,'unread_count',coalesce(p_unread,(select count(*) from public.communication_messages m left join public.communication_read_state r on r.thread_id=m.thread_id and r.person_id=p_actor where m.thread_id=t.id and m.status='visible' and m.author_person_id<>p_actor and m.sequence_number>coalesce(r.through_sequence,0))),
 'operations',to_jsonb(array_remove(array['read.thread',case when boss_private.comm_thread_can_send(t.id,p_actor) and boss_private.comm_group_safe(t.id) then 'message.send' end,
 case when boss_private.comm_thread_manage(t.id,p_actor) then 'thread.update' end,
 case when boss_private.comm_feature(t.organization_id,'attachments') and boss_private.comm_attachment_can_send(t.id,p_actor) then 'attachment.intent' end],null)))
 from public.communication_threads t where t.id=p_thread and boss_private.comm_thread_can_view(t.id,p_actor) $$;
create function boss_private.comm_read(p_query jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
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
 or exists(select 1 from public.teams t where t.organization_id=o.id and boss_private.comm_permission(actor,'communications.view',o.id,'team',t.id))) order by o.name,o.id limit 100)s;
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
create function public.boss_communications_read(p_query jsonb default '{}') returns jsonb language sql stable security invoker set search_path='' as $$select boss_private.comm_read(p_query)$$;
create function public.boss_communications_mutate(p_request_id uuid,p_command jsonb) returns jsonb language sql security invoker set search_path='' as $$select boss_private.comm_mutate(p_request_id,p_command)$$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('boss-communication-attachments','boss-communication-attachments',false,5242880,array['application/pdf','image/jpeg','image/png']);
create function boss_private.comm_storage_insert(p_bucket text,p_name text,p_metadata jsonb) returns boolean language plpgsql stable security definer set search_path='' as $$begin
 perform boss_private.require_live_auth();return storage.allow_only_operation('object.upload') and p_bucket='boss-communication-attachments' and jsonb_typeof(p_metadata)='object' and exists(
 select 1 from public.communication_attachments a join boss_private.communication_upload_intents i on i.attachment_id=a.id where a.object_name=p_name and a.status='upload_pending'
 and i.actor_person_id=boss_private.current_person_id() and i.auth_session_id=(auth.jwt()->>'session_id')::uuid and i.consumed_at is null and i.expires_at>now()
 and boss_private.comm_feature(a.organization_id,'attachments') and boss_private.comm_attachment_can_send(a.thread_id,i.actor_person_id) and boss_private.comm_group_safe(a.thread_id)
 and p_metadata->>'mimetype'=a.mime_type and (p_metadata->>'size' is not null or p_metadata->>'contentLength' is not null)
 and (p_metadata->>'size' is null or (p_metadata->>'size'~'^[0-9]{1,10}$' and (p_metadata->>'size')::bigint=a.size_bytes))
 and (p_metadata->>'contentLength' is null or (p_metadata->>'contentLength'~'^[0-9]{1,10}$' and (p_metadata->>'contentLength')::bigint=a.size_bytes))
 and not exists(select 1 from storage.objects where bucket_id=p_bucket and name=p_name));
 exception when sqlstate 'PT401' or invalid_text_representation or numeric_value_out_of_range then return false;end $$;
create function boss_private.comm_storage_select(p_bucket text,p_name text) returns boolean language plpgsql stable security definer set search_path='' as $$begin
 perform boss_private.require_live_auth();return p_bucket='boss-communication-attachments' and exists(select 1 from public.communication_attachments a where a.object_name=p_name and boss_private.comm_feature(a.organization_id,'attachments') and (
 (storage.allow_only_operation('object.upload') and a.status='upload_pending' and boss_private.comm_attachment_can_send(a.thread_id,boss_private.current_person_id()) and boss_private.comm_group_safe(a.thread_id) and exists(select 1 from boss_private.communication_upload_intents i where i.attachment_id=a.id and i.actor_person_id=boss_private.current_person_id() and i.auth_session_id=(auth.jwt()->>'session_id')::uuid and i.expires_at>now() and i.consumed_at is null))
 or ((storage.allow_only_operation('object.get_authenticated') or storage.allow_only_operation('object.get_authenticated_info')) and a.status='attached' and boss_private.comm_message_can_view(a.message_id,boss_private.current_person_id()) and exists(select 1 from boss_private.communication_access_leases l where l.attachment_id=a.id and l.actor_person_id=boss_private.current_person_id() and l.auth_session_id=(auth.jwt()->>'session_id')::uuid and l.expires_at>now()))));
 exception when sqlstate 'PT401' or invalid_text_representation then return false;end $$;
create policy boss_communications_attachment_upload on storage.objects for insert to authenticated with check(boss_private.comm_storage_insert(bucket_id,name,metadata));
create policy boss_communications_attachment_read on storage.objects for select to authenticated using(boss_private.comm_storage_select(bucket_id,name));
DO $$declare f record;begin for f in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'comm_%' loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.f);end loop;end $$;
revoke all on function public.boss_communications_read(jsonb),public.boss_communications_mutate(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.boss_communications_read(jsonb),public.boss_communications_mutate(uuid,jsonb),boss_private.comm_read(jsonb),boss_private.comm_mutate(uuid,jsonb),boss_private.comm_storage_insert(text,text,jsonb),boss_private.comm_storage_select(text,text) to authenticated;
