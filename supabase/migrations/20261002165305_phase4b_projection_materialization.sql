-- Evaluate current occurrence deadlines once before expanding subject rows.
-- This changes projection evaluation only; all existing caller, scope, privacy,
-- feature, roster and deadline-policy predicates are retained verbatim.
create or replace function boss_private.attendance_read(p_query jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;org uuid;view_name text;range_from timestamptz;range_to timestamptz;event_filter uuid;child_filter uuid;team_filter uuid;unit_filter uuid;organizations jsonb;children jsonb;teams jsonb;units jsonb;rows jsonb;history jsonb;selected_occurrence jsonb;count_rows integer;conf jsonb;configure boolean;options_limited boolean:=false;begin
 actor:=boss_private.require_admin_actor();perform boss_private.attendance_validate(p_query,array['organization_id','view','from','to','event_id','occurrence_key','team_id','unit_id','child_person_id']);
 org:=(p_query->>'organization_id')::uuid;view_name:=coalesce(p_query->>'view','family');event_filter:=(p_query->>'event_id')::uuid;child_filter:=(p_query->>'child_person_id')::uuid;team_filter:=(p_query->>'team_id')::uuid;unit_filter:=(p_query->>'unit_id')::uuid;
 if view_name not in ('family','staff','history') then raise exception 'Invalid attendance view' using errcode='PT422';end if;
 range_from:=coalesce((p_query->>'from')::timestamptz,date_trunc('day',now()));range_to:=coalesce((p_query->>'to')::timestamptz,range_from+interval '31 days');
 if range_to<=range_from or range_to-range_from>interval '93 days' then raise exception 'Invalid attendance range' using errcode='PT422';end if;
 if p_query?'occurrence_key' and (event_filter is null or p_query->>'occurrence_key'!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$') then raise exception 'Invalid attendance occurrence' using errcode='PT422';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name) order by name,id),'[]') into organizations from (
 select o.id,o.name from public.organizations o where boss_private.attendance_organization_known(actor,o.id) order by o.name,o.id limit 101) options;
 if jsonb_array_length(organizations)>100 then
 options_limited:=true;select coalesce(jsonb_agg(value order by ordinal),'[]') into organizations from jsonb_array_elements(organizations) with ordinality option(value,ordinal) where ordinal<=100;
 end if;
 if org is null then org:=(organizations->0->>'id')::uuid;end if;
 if org is not null then
 if not boss_private.attendance_organization_known(actor,org) then raise exception 'Access denied' using errcode='PT403';end if;
 if not exists(select 1 from jsonb_array_elements(organizations) o where o->>'id'=org::text) then
 organizations:=organizations||(select jsonb_build_array(jsonb_build_object('id',o.id,'label',o.name)) from public.organizations o where o.id=org);
 end if;end if;
 configure:=org is not null and boss_private.calendar_module_enabled(org) and boss_private.has_permission('organization.manage',org);conf:=boss_private.attendance_configuration(org);
 if (team_filter is not null and not exists(select 1 from public.teams team where team.id=team_filter and team.organization_id=org and team.status='active'))
 or (unit_filter is not null and not exists(select 1 from public.organization_units u where u.id=unit_filter and u.organization_id=org and u.status='active')) then raise exception 'Access denied' using errcode='PT403';end if;
 select coalesce(jsonb_agg(jsonb_build_object('person_id',p.id,'participant_id',a.id,'display_name',coalesce(p.display_name,p.preferred_name,p.first_name,'Participant')) order by p.id),'[]') into children
 from (select distinct g.dependent_person_id from public.guardian_relationships g where g.guardian_person_id=actor and g.can_respond_attendance and g.authority_status='active' and g.verified_at<=now() and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now())) current_guardians join public.people p on p.id=current_guardians.dependent_person_id join public.participants a on a.person_id=p.id and a.status='active' where p.status='active' and boss_private.attendance_feature(org,'guardian_rsvp') and boss_private.comm_person_active(actor)
 and exists(select 1 from public.events e cross join lateral boss_private.attendance_subjects(e.id) subject where e.organization_id=org and subject.person_id=p.id and subject.subject_kind='participant');
 if child_filter is not null and not exists(select 1 from jsonb_array_elements(children) child where child->>'person_id'=child_filter::text) and child_filter<>actor then raise exception 'Access denied' using errcode='PT403';end if;
 if event_filter is not null and not exists(select 1 from public.events e where e.id=event_filter and e.organization_id=org and boss_private.attendance_feature(org,'attendance')
 and (boss_private.attendance_permission(actor,'attendance.view',e.id,false) or exists(select 1 from boss_private.attendance_subjects(e.id) subject where (subject.person_id=actor or boss_private.attendance_guardian(actor,subject.person_id) is not null) and boss_private.attendance_subject_authority(actor,e.id,subject.person_id,subject.participant_id,subject.subject_kind,'view')))) then raise exception 'Access denied' using errcode='PT403';end if;
 if event_filter is not null and p_query?'occurrence_key' and not p_query?'from' and not p_query?'to' and view_name<>'history' then
 selected_occurrence:=boss_private.attendance_occurrence(event_filter,p_query->>'occurrence_key');
 if selected_occurrence is null then raise exception 'Access denied' using errcode='PT403';end if;
 range_from:=(selected_occurrence->>'start_at')::timestamptz-interval '1 day';range_to:=(selected_occurrence->>'end_at')::timestamptz+interval '1 day';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name) order by name,id),'[]') into teams from (
 select team.id,team.name from public.teams team where team.organization_id=org and team.status='active' and boss_private.attendance_feature(org,'attendance')
 and (team.parent_unit_id is null or exists(select 1 from public.organization_units u where u.id=team.parent_unit_id and u.organization_id=org and u.status='active'))
 and (boss_private.comm_permission(actor,'attendance.view',org,'team',team.id)
 or exists(select 1 from public.events e join public.event_targets target on target.event_id=e.id cross join lateral boss_private.attendance_subjects(e.id) subject
 join public.team_memberships membership on membership.person_id=subject.person_id and membership.team_id=team.id and membership.organization_id=org and membership.status='active' and membership.starts_at<=now() and (membership.ends_at is null or membership.ends_at>now())
 where e.organization_id=org and ((target.target_type='team' and target.target_id=team.id) or(target.target_type='unit' and target.target_id=team.parent_unit_id) or target.target_type='organization')
 and (subject.person_id=actor or boss_private.attendance_guardian(actor,subject.person_id) is not null) and boss_private.attendance_subject_authority(actor,e.id,subject.person_id,subject.participant_id,subject.subject_kind,'view')))
 order by team.name,team.id limit 201) options;
 if jsonb_array_length(teams)>200 then raise exception 'Attendance team review exceeds safe limit' using errcode='PT409';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',name) order by name,id),'[]') into units from (
 select unit.id,unit.name from public.organization_units unit where unit.organization_id=org and unit.status='active' and boss_private.attendance_feature(org,'attendance')
 and (boss_private.comm_permission(actor,'attendance.view',org,'unit',unit.id) or exists(select 1 from public.teams team join jsonb_array_elements(teams) option on option->>'id'=team.id::text where team.parent_unit_id=unit.id and team.organization_id=org))
 order by unit.name,unit.id limit 101) options;
 if jsonb_array_length(units)>100 then raise exception 'Attendance unit review exceeds safe limit' using errcode='PT409';end if;
 if view_name='history' then
 if event_filter is null or not boss_private.attendance_permission(actor,'attendance.view',event_filter,true) then raise exception 'Access denied' using errcode='PT403';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',h.id,'response_id',h.response_id,'event_id',h.event_id,'occurrence_key',h.occurrence_key,'person_id',h.person_id,'subject_kind',h.subject_kind,'version',h.version,'change_kind',h.change_kind,'created_at',h.created_at,'status',h.snapshot->>'status','needs_reconfirmation',h.snapshot->'needs_reconfirmation','reason',case when boss_private.attendance_permission(actor,'attendance.manage',event_filter,true) then h.snapshot->'reason' end,'note',case when boss_private.attendance_permission(actor,'attendance.manage',event_filter,true) then h.snapshot->'note' end) order by h.created_at desc,h.id),'[]') into history
 from (select * from public.attendance_response_history where event_id=event_filter and organization_id=org and created_at>=range_from and created_at<range_to order by created_at desc,id limit 201) h;
 if jsonb_array_length(history)>200 then raise exception 'Attendance history review exceeds safe limit' using errcode='PT409';end if;
 rows:='[]';
 else
 with events as materialized (
 select e.* from public.events e where e.organization_id=org and boss_private.attendance_feature(org,'attendance') and (event_filter is null or e.id=event_filter)
 and e.status not in ('draft','canceled','postponed','archived') and (e.start_at<range_to or exists(select 1 from public.event_occurrence_exceptions ex where ex.event_id=e.id and ex.is_active and ex.override_start_at<range_to))
 and (coalesce(e.recurrence_end_at,e.end_at)>range_from or exists(select 1 from public.event_occurrence_exceptions ex where ex.event_id=e.id and ex.is_active and ex.override_end_at>range_from))
 and (team_filter is null or exists(select 1 from public.event_targets target where target.event_id=e.id and target.target_type='team' and target.target_id=team_filter))
 and (unit_filter is null or exists(select 1 from public.event_targets target where target.event_id=e.id and ((target.target_type='unit' and target.target_id=unit_filter) or (target.target_type='team' and exists(select 1 from public.teams team where team.id=target.target_id and team.parent_unit_id=unit_filter)))))
 ), visible as materialized (
 select e.*,boss_private.attendance_effective_key(e.id,x.occurrence_key) as occurrence_key,x.start_at as occurrence_start,x.end_at as occurrence_end,x.status as occurrence_status,x.title as occurrence_title,
 boss_private.attendance_permission(actor,'attendance.manage',e.id,true) can_manage,boss_private.attendance_feature(org,'checkin') and boss_private.attendance_permission(actor,'attendance.checkin',e.id,true) can_checkin,
 boss_private.attendance_deadline(e.id,boss_private.attendance_effective_key(e.id,x.occurrence_key)) as effective_deadline_at,
 coalesce(settings.version,0) settings_version,coalesce(settings.deadline_policy,'lock') deadline_policy,coalesce(settings.change_policy,'needs_reconfirmation') change_policy,settings.response_deadline_at,settings.deadline_offset_minutes,coalesce(settings.audience,array['participants','staff']::text[]) attendance_audience
 from events e cross join lateral boss_private.calendar_occurrences(e,range_from,range_to) x left join public.event_attendance_settings settings on settings.event_id=e.id
 where x.status in ('scheduled','confirmed','completed') and (p_query->>'occurrence_key' is null or boss_private.attendance_effective_key(e.id,x.occurrence_key)=p_query->>'occurrence_key')
 and (view_name<>'staff' or boss_private.attendance_permission(actor,'attendance.view',e.id,false))
 ), projected as (
 select v.*,subject_rows.rows,subject_rows.total,subject_rows.summary from visible v cross join lateral (
 select count(*) total,coalesce(jsonb_agg(payload order by subject_person),'[]') rows,
 jsonb_build_object('total',count(*),'attending',count(*) filter(where response_status='attending' and not reconfirm),'not_attending',count(*) filter(where response_status='not_attending' and not reconfirm),'maybe',count(*) filter(where response_status='maybe' and not reconfirm),'pending',count(*) filter(where response_status is null or response_status='pending'),'unknown',count(*) filter(where response_status='unknown'),'needs_reconfirmation',count(*) filter(where reconfirm)) summary
 from (
 select subject.person_id subject_person,response.status response_status,coalesce(response.needs_reconfirmation,false) reconfirm,
 jsonb_build_object('person_id',subject.person_id,'participant_id',subject.participant_id,'subject_kind',subject.subject_kind,'display_name',coalesce(person.display_name,person.preferred_name,person.first_name,'Person'),
 'response',case when response.id is null then null else jsonb_build_object('id',response.id,'status',response.status,'version',response.version,'needs_reconfirmation',response.needs_reconfirmation,'is_late',response.is_late,
 'reason',case when boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view_private_notes') then response.reason end,
 'note',case when boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view_private_notes') then response.note end,
 'arrival_difference_minutes',case when boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view_private_notes') then response.arrival_difference_minutes end,
 'departure_difference_minutes',case when boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view_private_notes') then response.departure_difference_minutes end) end,
 'checkin',case when checkin.id is null then null else jsonb_build_object('id',checkin.id,'state',checkin.state,'version',checkin.version) end,
 'capabilities',jsonb_build_object('respond',v.occurrence_status in ('scheduled','confirmed') and v.occurrence_end>now() and boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'respond') and (v.deadline_policy='allow_late' or v.effective_deadline_at is null or now()<=v.effective_deadline_at),'manage',v.can_manage,'checkin',v.can_checkin,'view_private_notes',boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view_private_notes'))) payload
 from boss_private.attendance_subjects(v.id) subject join public.people person on person.id=subject.person_id
 left join public.attendance_responses response on response.event_id=v.id and response.occurrence_key=v.occurrence_key and response.person_id=subject.person_id and response.subject_kind=subject.subject_kind
 left join public.attendance_checkins checkin on checkin.event_id=v.id and checkin.occurrence_key=v.occurrence_key and checkin.person_id=subject.person_id and checkin.subject_kind=subject.subject_kind
 where (child_filter is null or subject.person_id=child_filter) and case when view_name='staff' then boss_private.attendance_subject_permission(actor,'attendance.view',v.id,subject.person_id)
 else (subject.person_id=actor or boss_private.attendance_guardian(actor,subject.person_id) is not null) and boss_private.attendance_subject_authority(actor,v.id,subject.person_id,subject.participant_id,subject.subject_kind,'view') end
 order by subject.person_id limit 1001) subjects
 ) subject_rows where (subject_rows.total>0 or v.can_manage)
 order by v.occurrence_start,v.id,v.occurrence_key limit 1001
 ) select count(*),coalesce(jsonb_agg(jsonb_build_object('event_id',id,'organization_id',organization_id,'title',occurrence_title,'timezone',timezone,'occurrence_key',occurrence_key,'start_at',occurrence_start,'end_at',occurrence_end,'status',occurrence_status,'rsvp_mode',rsvp_mode,
 'settings',jsonb_build_object('response_deadline_at',response_deadline_at,'effective_deadline_at',effective_deadline_at,'deadline_offset_minutes',deadline_offset_minutes,'deadline_policy',deadline_policy,'change_policy',change_policy,'audience',attendance_audience,'version',settings_version),'summary',summary,'subjects',projected.rows,'capabilities',jsonb_build_object('manage',can_manage,'checkin',can_checkin,'view_summary',view_name='staff')) order by occurrence_start,id,occurrence_key),'[]') into count_rows,rows from projected;
 -- Both occurrence and roster pages are finite; inspect arrays after aggregation.
 if jsonb_array_length(rows)>1000 or exists(select 1 from jsonb_array_elements(rows) row where jsonb_array_length(row->'subjects')>1000) then raise exception 'Attendance review exceeds safe limit' using errcode='PT409';end if;
 history:='[]';end if;
 return jsonb_build_object('organization_id',org,'organizations',organizations,'options_limited',options_limited,'navigation_available',exists(select 1 from jsonb_array_elements(organizations) available where boss_private.attendance_feature((available->>'id')::uuid,'attendance')),'teams',teams,'units',units,'view',view_name,'range',jsonb_build_object('from',range_from,'to',range_to),'features',conf,'capabilities',jsonb_build_object('configure',configure),'children',children,'occurrences',rows,'history',history);
 exception when sqlstate 'PT401' or sqlstate 'PT403' or sqlstate 'PT409' or sqlstate 'PT422' then raise;when others then raise exception 'Invalid attendance request' using errcode='PT422';end $$;
revoke all on function boss_private.attendance_read(jsonb) from public,anon,service_role;
grant execute on function boss_private.attendance_read(jsonb) to authenticated;
