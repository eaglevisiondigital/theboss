-- Read projections are finite and separate medical, finance and ordinary data.
create function boss_private.registration_can_know_offering(p_offering uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.registration_feature(o.organization_id,'registration') and (
 boss_private.registration_can_scope('registration.view',o.organization_id,o.scope_type,o.scope_id)
 or boss_private.registration_can_scope('registration.manage',o.organization_id,o.scope_type,o.scope_id)
 or boss_private.registration_can_scope('fees.view',o.organization_id,o.scope_type,o.scope_id)
 or exists(select 1 from public.registrations r where r.offering_id=o.id and boss_private.registration_can_view(r.id))
 or (o.status='published' and (o.visibility='authenticated' or exists(
 select 1 from public.participants p join public.people person on person.id=p.person_id where person.status='active' and p.status='active'
 and boss_private.registration_guardian(p.id,'can_register') and (
 (o.visibility='member' and exists(select 1 from public.organization_memberships m where m.organization_id=o.organization_id and m.person_id=p.person_id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())))
 or (o.scope_type='organization' and exists(select 1 from public.organization_memberships m where m.organization_id=o.organization_id and m.person_id=p.person_id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())))
 or exists(select 1 from public.team_memberships tm join public.teams t on t.id=tm.team_id and t.organization_id=tm.organization_id where tm.person_id=p.person_id and t.organization_id=o.organization_id and t.status='active'
 and tm.status='active' and tm.starts_at<=now() and (tm.ends_at is null or tm.ends_at>now()) and ((o.scope_type='team' and t.id=o.scope_id) or (o.scope_type='unit' and t.parent_unit_id=o.scope_id)))
 ))))) from public.registration_offerings o where o.id=p_offering),false)
$$;
create function boss_private.registration_safe_offering(p_offering uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',o.id,'organization_id',o.organization_id,'title',o.title,'description',o.description,'scope_type',o.scope_type,'scope_id',o.scope_id,
 'season_id',o.season_id,'event_id',o.event_id,'event_title',(select e.title from public.events e where e.id=o.event_id and boss_private.calendar_can_view_event(e.id)),
 'registration_type',o.registration_type,'participant_type',o.participant_type,'opens_at',o.opens_at,'closes_at',o.closes_at,'capacity',o.capacity,
 'waitlist_enabled',o.waitlist_enabled,'approval_required',o.approval_required,'visibility',o.visibility,'status',o.status,'age_min',o.age_min,'age_max',o.age_max,'grade_min',o.grade_min,'grade_max',o.grade_max,
 'returning_behavior',o.returning_behavior,'team_assignment_policy',o.team_assignment_policy,'version',o.version,
 'forms',coalesce((select jsonb_agg(jsonb_build_object('form_version_id',f.id,'required',l.required,'sort_order',l.sort_order,'version',to_jsonb(f)-'published_by_person_id') order by l.sort_order,f.id)
 from public.registration_offering_forms l join public.registration_form_versions f on f.id=l.form_version_id where l.offering_id=o.id),'[]'::jsonb),
 'waivers',coalesce((select jsonb_agg(jsonb_build_object('waiver_version_id',w.id,'required',l.required,'sort_order',l.sort_order,'version',to_jsonb(w)-'published_by_person_id') order by l.sort_order,w.id)
 from public.registration_offering_waivers l join public.registration_waiver_versions w on w.id=l.waiver_version_id where l.offering_id=o.id),'[]'::jsonb),
 'documents',coalesce((select jsonb_agg(jsonb_build_object('document_requirement_id',d.id,'required',l.required,'sort_order',l.sort_order,'version',to_jsonb(d)-'created_by_person_id') order by l.sort_order,d.id)
 from public.registration_offering_documents l join public.document_requirements d on d.id=l.document_requirement_id where l.offering_id=o.id),'[]'::jsonb),
 'fees',case when boss_private.registration_feature(o.organization_id,'fees') then coalesce((select jsonb_agg(to_jsonb(f) order by f.id) from public.registration_fee_rules f where f.offering_id=o.id and f.status='active'),'[]'::jsonb) else '[]'::jsonb end,
 'operations',to_jsonb(array_remove(array[
 case when boss_private.registration_can_scope('registration.manage',o.organization_id,o.scope_type,o.scope_id) then 'offering.upsert' end,
 case when boss_private.registration_can_scope('registration.manage',o.organization_id,o.scope_type,o.scope_id) then 'offering.publish' end,
 case when boss_private.registration_can_scope('forms.manage',o.organization_id,o.scope_type,o.scope_id) then 'form.publish' end,
 case when boss_private.registration_can_scope('waivers.manage',o.organization_id,o.scope_type,o.scope_id) then 'waiver.publish' end,
 case when boss_private.registration_can_scope('documents.review',o.organization_id,o.scope_type,o.scope_id) then 'document_requirement.upsert' end,
 case when boss_private.registration_can_scope('fees.manage',o.organization_id,o.scope_type,o.scope_id) then 'fee.upsert' end,
 case when boss_private.registration_can_scope('fees.manage',o.organization_id,o.scope_type,o.scope_id) and boss_private.registration_feature(o.organization_id,'coupons') then 'coupon.upsert' end,
 case when o.status='published' and (o.opens_at is null or o.opens_at<=now()) and (o.closes_at is null or o.closes_at>now())
 and (o.visibility<>'restricted' or boss_private.registration_can_scope('registration.create',o.organization_id,o.scope_type,o.scope_id))
 and (o.visibility<>'member' or boss_private.has_active_organization_membership(o.organization_id) or boss_private.registration_can_scope('registration.create',o.organization_id,o.scope_type,o.scope_id)
 or exists(select 1 from public.participants p join public.people person on person.id=p.person_id join public.organization_memberships m on m.person_id=p.person_id
 where p.status='active' and person.status='active' and p.participant_type=o.participant_type and boss_private.registration_guardian(p.id,'can_register')
 and m.organization_id=o.organization_id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()))) then 'registration.start' end
 ],null))) from public.registration_offerings o where o.id=p_offering and boss_private.registration_can_know_offering(o.id)
$$;
create function boss_private.registration_can_know_org(p_org uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select (boss_private.registration_module_enabled(p_org) and boss_private.has_permission('organization.manage',p_org)) or (boss_private.registration_feature(p_org,'registration') and (
 boss_private.has_permission('registration.manage',p_org) or boss_private.has_permission('fees.view',p_org)
 or exists(select 1 from public.organization_units u where u.organization_id=p_org and u.status='active' and boss_private.has_permission('registration.manage',p_org,u.id))
 or exists(select 1 from public.teams t where t.organization_id=p_org and t.status='active' and boss_private.has_permission('registration.manage',p_org,t.parent_unit_id,t.id))
 or exists(select 1 from public.registration_offerings o where o.organization_id=p_org and boss_private.registration_can_know_offering(o.id))))
$$;

create function boss_private.registration_detail(p_registration uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.registrations;finance boolean;ordinary boolean;medical boolean;family boolean;signer boolean;emergency_teams jsonb;d jsonb;begin
 select * into r from public.registrations where id=p_registration;if not found or not boss_private.registration_can_view(r.id) then raise exception 'Request not permitted.' using errcode='PT403';end if;
 family:=boss_private.registration_guardian(r.participant_id,'can_register');signer:=boss_private.registration_guardian(r.participant_id,'can_sign_waivers');ordinary:=family or boss_private.registration_can_record('registration.manage',r.id) or boss_private.registration_can_record('registration.review',r.id);
 finance:=boss_private.registration_feature(r.organization_id,'fees') and (boss_private.registration_guardian(r.participant_id,'can_manage_payments') or boss_private.registration_can_record('fees.view',r.id));
 medical:=boss_private.registration_feature(r.organization_id,'documents') and (boss_private.registration_guardian(r.participant_id,'can_view_documents') or boss_private.registration_can_record('documents.view',r.id));
 select coalesce(jsonb_agg(x),'[]') into emergency_teams from (select jsonb_build_object('id',t.id,'label',t.name) x from public.teams t where t.organization_id=r.organization_id
 and boss_private.registration_emergency_authorized(r.participant_id,r.organization_id,t.id) order by t.name,t.id limit 20) s;
 d:=jsonb_build_object('id',r.id,'organization_id',r.organization_id,'offering_id',r.offering_id,'participant_id',r.participant_id,'household_id',r.household_id,
 'submitted_by_person_id',case when ordinary or finance then r.submitted_by_person_id else null end,
 'submitted_by_name',case when ordinary or finance then (select coalesce(p.display_name,p.preferred_name,'Boss member') from public.people p where p.id=r.submitted_by_person_id) else null end,
 'status',r.status,'form_status',r.form_status,'waiver_status',r.waiver_status,'document_status',r.document_status,'eligibility_status',r.eligibility_status,'approval_status',r.approval_status,'roster_status',r.roster_status,
 'assigned_team_id',r.assigned_team_id,'waitlist_position',r.waitlist_position,'version',r.version,'submitted_at',r.submitted_at,'reviewed_at',r.reviewed_at,
 'offering_snapshot',case when ordinary then r.offering_snapshot else jsonb_build_object('offering',r.offering_snapshot->'offering') end,
 'participant_snapshot',case when ordinary then r.participant_snapshot else jsonb_build_object('id',r.participant_id,'label',coalesce(r.participant_snapshot->>'label',r.participant_snapshot->>'display_name')) end,
 'family_snapshot',case when family then r.family_snapshot else '{}'::jsonb end,'context',case when ordinary then r.context else '{}'::jsonb end,'emergency_teams',emergency_teams,
 'emergency_access_purpose',case when medical then 'ordinary' when jsonb_array_length(emergency_teams)>0 then 'emergency' else null end,
 'emergency_record_id',case when medical or jsonb_array_length(emergency_teams)>0 then (select e.id from public.participant_emergency_records e where e.registration_id=r.id) else null end,
 'forms',case when ordinary or medical then coalesce((select jsonb_agg(jsonb_build_object('form_version_id',fv.id,'title',fv.title,'definition',fv.definition,'sensitivity',fv.sensitivity,
 'required',snap->'required','status',coalesce(a.status,'not_started'),'version',a.version,'answers',case when fv.sensitivity='ordinary' then coalesce(a.answers,'{}'::jsonb) else '{}'::jsonb end,'completed_at',a.completed_at,
 'needs_sensitive_access',fv.sensitivity='medical','operations',to_jsonb(array_remove(array[
 case when family and r.status='draft' and (fv.sensitivity='ordinary' or medical) then 'form.answer' end,
 case when medical and fv.sensitivity='medical' then 'form.access' end],null)))
 order by (snap->>'sort_order')::integer,fv.id) from jsonb_array_elements(coalesce(r.offering_snapshot->'forms','[]')) snap
 join public.registration_form_versions fv on fv.id=(snap->>'form_version_id')::uuid left join public.registration_form_answers a on a.registration_id=r.id and a.form_version_id=fv.id
 where ordinary or (medical and fv.sensitivity='medical')),'[]'::jsonb) else '[]'::jsonb end,
 'waivers',case when ordinary or signer then coalesce((select jsonb_agg(jsonb_build_object('waiver_version_id',w.id,'title',w.title,'body',w.body,'version_number',w.version_number,'signer_type',w.signer_type,'required',snap->'required',
 'signatures',case when signer or medical then coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'signer_name',s.signer_name,'signed_at',s.signed_at,'status',s.status,'version_snapshot',s.version_snapshot)) from public.waiver_signatures s where s.registration_id=r.id and s.waiver_version_id=w.id),'[]'::jsonb)
 else coalesce((select jsonb_agg(jsonb_build_object('signed_at',s.signed_at,'status',s.status)) from public.waiver_signatures s where s.registration_id=r.id and s.waiver_version_id=w.id),'[]'::jsonb) end) order by (snap->>'sort_order')::integer,w.id)
 from jsonb_array_elements(coalesce(r.offering_snapshot->'waivers','[]')) snap join public.registration_waiver_versions w on w.id=(snap->>'waiver_version_id')::uuid),'[]'::jsonb) else '[]'::jsonb end,
 'documents',case when ordinary or medical or jsonb_array_length(emergency_teams)>0 then coalesce((select jsonb_agg(jsonb_build_object('id',doc.id,'requirement_id',doc.requirement_id,'title',doc.snapshot->>'title','classification',doc.snapshot->>'classification',
 'required',doc.snapshot->'required','status',case when doc.expires_on<current_date and doc.status='approved' then 'expired' else doc.status end,'version',doc.version,
 'expires_on',doc.expires_on,'renewal_due_on',doc.renewal_due_on,'uploaded_at',doc.uploaded_at,'reviewed_at',doc.reviewed_at,
 'review_reason',case when medical then doc.review_reason else null end,
 'allowed_mime_types',case when medical then doc.snapshot->'allowed_mime_types' else null end,'max_bytes',case when medical then doc.snapshot->'max_bytes' else null end,
 'access_purpose',case when medical then 'ordinary' when jsonb_array_length(emergency_teams)>0 and doc.snapshot->>'classification'='medical' and doc.snapshot->'emergency_access'='true'::jsonb and doc.status='approved' and (doc.expires_on is null or doc.expires_on>=current_date) then 'emergency' else null end,
 'operations',to_jsonb(array_remove(array[case when medical and boss_private.registration_guardian(r.participant_id,'can_register') then 'document.intent' end,
 case when doc.object_name is not null and (medical or (jsonb_array_length(emergency_teams)>0 and doc.snapshot->>'classification'='medical' and doc.snapshot->'emergency_access'='true'::jsonb and doc.status='approved' and (doc.expires_on is null or doc.expires_on>=current_date))) then 'document.access' end,
 case when boss_private.registration_can_record('documents.review',r.id) then 'document.review' end],null))) order by doc.created_at,doc.id)
 from public.registration_documents doc where doc.registration_id=r.id and (ordinary or medical or (doc.snapshot->>'classification'='medical' and doc.snapshot->'emergency_access'='true'::jsonb and doc.status='approved' and (doc.expires_on is null or doc.expires_on>=current_date)))),'[]'::jsonb) else '[]'::jsonb end,
 'charges',case when finance then coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'title',c.title,'charge_type',c.charge_type,'due_on',c.due_on,'status',c.status,'balance',boss_private.registration_charge_balance(c.id),
 'adjustments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'amount_minor',a.amount_minor,'adjustment_type',a.adjustment_type,'reason',a.reason,'created_at',a.created_at)) from public.charge_adjustments a where a.charge_id=c.id),'[]'::jsonb),
 'allocations',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'amount_minor',a.amount_minor,'status',a.status,'method',p.method,'received_at',p.received_at,'reference',p.reference)) from public.payment_allocations a join public.payments p on p.id=a.payment_id where a.charge_id=c.id),'[]'::jsonb),
 'payment_plans',coalesce((select jsonb_agg(jsonb_build_object('id',plan.id,'title',plan.title,'status',plan.status,'installments',coalesce((select jsonb_agg(jsonb_build_object('sequence_number',i.sequence_number,'amount_minor',i.amount_minor,'due_on',i.due_on) order by i.sequence_number) from public.payment_installments i where i.payment_plan_id=plan.id),'[]'::jsonb))) from public.payment_plans plan where plan.charge_id=c.id),'[]'::jsonb)) order by c.created_at,c.id) from public.charges c where c.registration_id=r.id),'[]'::jsonb) else '[]'::jsonb end,
 'operations',to_jsonb(array_remove(array[
 case when family and r.status='draft' then 'registration.save' end,case when family and r.status='draft' then 'registration.submit' end,
 case when family and r.status in ('draft','submitted','under_review','approved','waitlisted') then 'registration.withdraw' end,
 case when family and r.status='draft' then 'form.answer' end,
 case when boss_private.registration_guardian(r.participant_id,'can_sign_waivers') and r.status='draft' then 'waiver.sign' end,
 case when medical and family and r.status not in ('archived','canceled','withdrawn') then 'emergency.save' end,
 case when medical or jsonb_array_length(emergency_teams)>0 then 'emergency.access' end,
 case when boss_private.registration_can_record('registration.review',r.id) then 'registration.decision' end,
 case when boss_private.registration_can_record('registration.review',r.id) then 'registration.eligibility' end,
 case when boss_private.registration_can_record('registration.manage',r.id) then 'registration.assign_team' end,
 case when boss_private.registration_can_record('registration.manage',r.id) and r.assigned_team_id is not null then 'registration.remove_team' end,
 case when boss_private.registration_can_record('fees.manage',r.id) then 'charge.create' end,
 case when boss_private.registration_can_record('fees.manage',r.id) then 'charge.adjust' end,
 case when boss_private.registration_can_record('fees.manage',r.id) then 'charge.cancel' end,
 case when boss_private.registration_can_record('fees.manage',r.id) and boss_private.registration_feature(r.organization_id,'payment_plans') then 'payment_plan.create' end,
 case when boss_private.registration_can_record('fees.manage',r.id) and boss_private.registration_feature(r.organization_id,'payment_plans') then 'payment_plan.cancel' end,
 case when boss_private.registration_can_record('payments.record_offline',r.id) then 'payment.record_offline' end
 ],null)));return d;
end $$;

create function boss_private.registration_read(p_query jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid;org uuid;reg uuid;offering uuid;q text;v_status text;v_view text;orgs jsonb;offers jsonb;regs jsonb;participants jsonb;households jsonb;defs jsonb:='{}';features jsonb:='{}';scopes jsonb:='{}';ops text[]:='{}';k text;begin
 actor:=boss_private.require_admin_actor();
 if jsonb_typeof(p_query) is distinct from 'object' or octet_length(p_query::text)>2000 or exists(select 1 from jsonb_object_keys(p_query) x where x not in ('organization_id','registration_id','offering_id','status','query','view')) then raise exception 'Invalid request.' using errcode='PT422';end if;
 foreach k in array array['organization_id','registration_id','offering_id'] loop if p_query?k and p_query->k<>'null'::jsonb and (jsonb_typeof(p_query->k)<>'string' or p_query->>k !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') then raise exception 'Invalid request.' using errcode='PT422';end if;end loop;
 foreach k in array array['status','query','view'] loop if p_query?k and p_query->k<>'null'::jsonb and jsonb_typeof(p_query->k)<>'string' then raise exception 'Invalid request.' using errcode='PT422';end if;end loop;
 org:=nullif(p_query->>'organization_id','')::uuid;reg:=nullif(p_query->>'registration_id','')::uuid;offering:=nullif(p_query->>'offering_id','')::uuid;q:=nullif(btrim(p_query->>'query'),'');v_status:=p_query->>'status';v_view:=coalesce(p_query->>'view','family');
 if length(coalesce(q,''))>100 or coalesce(q,'') ~ '[[:cntrl:]]' or v_view not in ('family','admin') or (v_status is not null and v_status not in ('draft','submitted','under_review','approved','denied','waitlisted','withdrawn','canceled','archived')) then raise exception 'Invalid request.' using errcode='PT422';end if;
 if org is not null and not boss_private.registration_can_know_org(org) then raise exception 'Request not permitted.' using errcode='PT403';end if;
 if offering is not null and (not boss_private.registration_can_know_offering(offering) or (org is not null and not exists(select 1 from public.registration_offerings o where o.id=offering and o.organization_id=org))) then raise exception 'Request not permitted.' using errcode='PT403';end if;
 if reg is not null and (not boss_private.registration_can_view(reg) or (org is not null and not exists(select 1 from public.registrations r where r.id=reg and r.organization_id=org))) then raise exception 'Request not permitted.' using errcode='PT403';end if;
 if reg is not null and offering is not null and not exists(select 1 from public.registrations r where r.id=reg and r.offering_id=offering) then raise exception 'Request not permitted.' using errcode='PT403';end if;
 select coalesce(jsonb_agg(x),'[]') into orgs from (select jsonb_build_object('id',o.id,'label',o.name) x from public.organizations o where boss_private.registration_can_know_org(o.id) order by o.name,o.id limit 100) s;
 if org is not null then
  foreach k in array array['registration','forms','waivers','documents','fees','payment_plans','coupons','waitlists','offline_payments','emergency_access','coach_registration_view'] loop features:=features||jsonb_build_object(k,boss_private.registration_feature(org,k));end loop;
  if boss_private.has_permission('organization.manage',org) then ops:=array_append(ops,'registration.configure');end if;
  if not boss_private.registration_feature(org,'registration') then
   return jsonb_build_object('person',jsonb_build_object('id',actor,'label',(select coalesce(p.display_name,p.preferred_name,'Boss member') from public.people p where p.id=actor)),
   'organizations',orgs,'organizationId',org,'features',features,'scopes','{}'::jsonb,'operations',to_jsonb(ops),'offerings','[]'::jsonb,'registrations','[]'::jsonb,
   'participants','[]'::jsonb,'households','[]'::jsonb,'definitions','{}'::jsonb,'detail',null);
  end if;
  if boss_private.registration_can_scope('registration.manage',org,'organization',org)
   or exists(select 1 from public.organization_units u where u.organization_id=org and boss_private.registration_can_scope('registration.manage',org,'unit',u.id))
   or exists(select 1 from public.teams t where t.organization_id=org and boss_private.registration_can_scope('registration.manage',org,'team',t.id)) then ops:=array_append(ops,'offering.upsert');end if;
  scopes:=jsonb_build_object('organization',case when boss_private.registration_can_scope('registration.manage',org,'organization',org) then jsonb_build_object('id',org,'label',(select name from public.organizations where id=org)) else null end,
   'units',coalesce((select jsonb_agg(x) from(select jsonb_build_object('id',u.id,'label',u.name) x from public.organization_units u where u.organization_id=org and u.status='active' and boss_private.registration_can_scope('registration.manage',org,'unit',u.id) order by u.name,u.id limit 100) s),'[]'::jsonb),
   'teams',coalesce((select jsonb_agg(x) from(select jsonb_build_object('id',t.id,'label',t.name,'parent_unit_id',t.parent_unit_id,'season_id',t.season_id) x from public.teams t where t.organization_id=org and t.status='active' and boss_private.registration_can_scope('registration.manage',org,'team',t.id) order by t.name,t.id limit 100) s),'[]'::jsonb),
   'seasons',coalesce((select jsonb_agg(x) from(select jsonb_build_object('id',s.id,'label',s.name) x from public.seasons s where s.organization_id=org and s.status='active' and (boss_private.registration_can_scope('registration.manage',org,'organization',org) or (s.parent_unit_id is not null and boss_private.registration_can_scope('registration.manage',org,'unit',s.parent_unit_id))) order by s.starts_on desc,s.id limit 100) s),'[]'::jsonb),
   'events',coalesce((select jsonb_agg(x) from(select jsonb_build_object('id',e.id,'label',e.title,'start_at',e.start_at) x from public.events e where e.organization_id=org and e.status<>'archived' and boss_private.calendar_can_view_event(e.id) order by e.start_at,e.id limit 100) s),'[]'::jsonb));
 end if;
 select coalesce(jsonb_agg(x),'[]') into offers from (select boss_private.registration_safe_offering(o.id) x from public.registration_offerings o where (org is null or o.organization_id=org) and (offering is null or o.id=offering)
 and boss_private.registration_can_know_offering(o.id) and (q is null or o.title ilike '%'||q||'%') order by o.created_at desc,o.id limit 50) s;
 select coalesce(jsonb_agg(x),'[]') into regs from (select jsonb_build_object('id',r.id,'organization_id',r.organization_id,'offering_id',r.offering_id,'offering_title',r.offering_snapshot->'offering'->>'title',
 'participant_id',r.participant_id,'participant_label',coalesce(r.participant_snapshot->>'label',r.participant_snapshot->>'display_name','Participant'),'household_id',r.household_id,'status',r.status,'form_status',r.form_status,'waiver_status',r.waiver_status,
 'document_status',r.document_status,'eligibility_status',r.eligibility_status,'approval_status',r.approval_status,'roster_status',r.roster_status,'waitlist_position',r.waitlist_position,'created_at',r.created_at,'version',r.version,
 'payment_status',case when not boss_private.registration_feature(r.organization_id,'fees') then 'not_required' else coalesce((select case when count(*)=0 then 'not_required'
 when bool_and(b->>'payment_status' in ('paid','waived','canceled')) then 'paid' when bool_or(b->>'payment_status'='overdue') then 'overdue'
 when bool_or((b->>'applied_amount_minor')::bigint>0) then 'partially_paid' else 'unpaid' end from public.charges c cross join lateral (select boss_private.registration_charge_balance(c.id) b) x where c.registration_id=r.id),'unpaid') end) x
 from public.registrations r where (org is null or r.organization_id=org) and (offering is null or r.offering_id=offering) and (v_status is null or r.status=v_status)
 and boss_private.registration_can_view(r.id) and (v_view<>'family' or boss_private.registration_guardian(r.participant_id,'can_register') or boss_private.registration_guardian(r.participant_id,'can_sign_waivers') or boss_private.registration_guardian(r.participant_id,'can_view_documents') or boss_private.registration_guardian(r.participant_id,'can_manage_payments'))
 and (q is null or coalesce(r.participant_snapshot->>'label',r.participant_snapshot->>'display_name','') ilike '%'||q||'%' or r.offering_snapshot->'offering'->>'title' ilike '%'||q||'%') order by r.created_at desc,r.id limit 100) s;
 select coalesce(jsonb_agg(x),'[]') into participants from (select jsonb_build_object('id',p.id,'person_id',p.person_id,'label',coalesce(person.display_name,person.preferred_name,nullif(concat_ws(' ',person.first_name,person.last_name),''),'Participant'),
 'participant_type',p.participant_type,'date_of_birth',case when boss_private.registration_guardian(p.id,'can_register') then person.date_of_birth else null end,
 'can_register',boss_private.registration_guardian(p.id,'can_register'),'can_sign_waivers',boss_private.registration_guardian(p.id,'can_sign_waivers'),'can_view_documents',boss_private.registration_guardian(p.id,'can_view_documents'),'can_manage_payments',boss_private.registration_guardian(p.id,'can_manage_payments')) x
 from public.participants p join public.people person on person.id=p.person_id where p.status='active' and person.status='active' and (
 boss_private.registration_guardian(p.id,'can_register') or (v_view='admin' and org is not null and (
 boss_private.has_permission('registration.create') or (boss_private.has_permission('registration.create',org) and exists(select 1 from public.organization_memberships m where m.organization_id=org and m.person_id=p.person_id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())))
 or exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id and t.organization_id=m.organization_id where t.organization_id=org and m.person_id=p.person_id and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()) and t.status='active' and boss_private.has_permission('registration.create',org,t.parent_unit_id,t.id))))) order by person.display_name,p.id limit 100) s;
 select coalesce(jsonb_agg(x),'[]') into households from (select jsonb_build_object('id',h.id,'label',coalesce(h.name,'Household')) x from public.households h where h.status='active' and exists(select 1 from public.household_memberships m
 where m.household_id=h.id and m.person_id=actor and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())) order by h.name,h.id limit 50) s;
 if org is not null then
  if boss_private.registration_can_scope('forms.manage',org,'organization',org) or exists(select 1 from public.registration_offerings o where o.organization_id=org and boss_private.registration_can_scope('forms.manage',org,o.scope_type,o.scope_id)) then
   defs:=defs||jsonb_build_object('forms',coalesce((select jsonb_agg(to_jsonb(f)-'published_by_person_id') from (select fv.* from public.registration_form_versions fv where fv.organization_id=org and (boss_private.registration_can_scope('forms.manage',org,'organization',org)
   or exists(select 1 from public.registration_offering_forms l join public.registration_offerings o on o.id=l.offering_id where l.form_version_id=fv.id and boss_private.registration_can_scope('forms.manage',org,o.scope_type,o.scope_id))) order by fv.published_at desc,fv.id limit 100) f),'[]'::jsonb));end if;
  if boss_private.registration_can_scope('waivers.manage',org,'organization',org) or exists(select 1 from public.registration_offerings o where o.organization_id=org and boss_private.registration_can_scope('waivers.manage',org,o.scope_type,o.scope_id)) then
   defs:=defs||jsonb_build_object('waivers',coalesce((select jsonb_agg(to_jsonb(w)-'published_by_person_id') from (select wv.* from public.registration_waiver_versions wv where wv.organization_id=org and (boss_private.registration_can_scope('waivers.manage',org,'organization',org)
   or exists(select 1 from public.registration_offering_waivers l join public.registration_offerings o on o.id=l.offering_id where l.waiver_version_id=wv.id and boss_private.registration_can_scope('waivers.manage',org,o.scope_type,o.scope_id))) order by wv.published_at desc,wv.id limit 100) w),'[]'::jsonb));end if;
  if boss_private.registration_can_scope('documents.review',org,'organization',org) or exists(select 1 from public.registration_offerings o where o.organization_id=org and boss_private.registration_can_scope('documents.review',org,o.scope_type,o.scope_id)) then
   defs:=defs||jsonb_build_object('documents',coalesce((select jsonb_agg(to_jsonb(d)-'created_by_person_id') from (select dr.* from public.document_requirements dr where dr.organization_id=org and (boss_private.registration_can_scope('documents.review',org,'organization',org)
   or exists(select 1 from public.registration_offering_documents l join public.registration_offerings o on o.id=l.offering_id where l.document_requirement_id=dr.id and boss_private.registration_can_scope('documents.review',org,o.scope_type,o.scope_id))) order by dr.created_at desc,dr.id limit 100) d),'[]'::jsonb));end if;
  defs:=defs||jsonb_build_object('coupons',coalesce((select jsonb_agg(to_jsonb(c)-'created_by_person_id') from (select c.* from public.registration_coupons c join public.registration_offerings o on o.id=c.offering_id where c.organization_id=org and boss_private.registration_can_scope('fees.manage',org,o.scope_type,o.scope_id) order by c.created_at desc,c.id limit 100) c),'[]'::jsonb));
 end if;
 return jsonb_build_object('person',jsonb_build_object('id',actor,'label',(select coalesce(p.display_name,p.preferred_name,'Boss member') from public.people p where p.id=actor)),
 'organizations',orgs,'organizationId',org,'features',features,'scopes',scopes,'operations',to_jsonb(ops),'offerings',offers,'registrations',regs,'participants',participants,'households',households,'definitions',defs,
 'detail',case when reg is not null then boss_private.registration_detail(reg) else null end);
end $$;
create function public.boss_registration_read(p_query jsonb default '{}') returns jsonb
language sql stable security invoker set search_path='' as $$select boss_private.registration_read(p_query)$$;

-- Storage is private. Upload paths are allocated through reviewed intents;
-- overwrites/deletes have no policy. Objects remain submitted until review.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('boss-registration-documents','boss-registration-documents',false,10485760,array['application/pdf','image/jpeg','image/png']);
create function boss_private.registration_storage_insert(p_bucket text,p_name text,p_metadata jsonb) returns boolean
language plpgsql stable security definer set search_path='' as $$begin
 perform boss_private.require_live_auth();
 return p_bucket='boss-registration-documents' and exists(select 1 from public.document_upload_intents i join public.registration_documents d on d.id=i.document_id and d.organization_id=i.organization_id
 where i.object_name=p_name and i.actor_person_id=boss_private.current_person_id() and i.auth_session_id=(auth.jwt()->>'session_id')::uuid and i.expires_at>now() and i.consumed_at is null
 and boss_private.registration_feature(d.organization_id,'registration') and boss_private.registration_feature(d.organization_id,'documents') and boss_private.registration_guardian(d.participant_id,'can_register') and boss_private.registration_guardian(d.participant_id,'can_view_documents')
 and d.status='upload_pending' and d.snapshot->'allowed_mime_types' @> jsonb_build_array(i.mime_type) and i.size_bytes<=coalesce((d.snapshot->>'max_bytes')::bigint,10485760)
 and p_metadata->>'mimetype'=i.mime_type and p_metadata->>'size' ~ '^[0-9]{1,10}$' and (p_metadata->>'size')::bigint=i.size_bytes
 and not exists(select 1 from storage.objects o where o.bucket_id=p_bucket and o.name=p_name));
 exception when sqlstate 'PT401' or invalid_text_representation or numeric_value_out_of_range then return false;
end $$;
create function boss_private.registration_storage_select(p_bucket text,p_name text) returns boolean
language plpgsql stable security definer set search_path='' as $$begin
 perform boss_private.require_live_auth();
 return p_bucket='boss-registration-documents' and exists(select 1 from public.registration_documents d join boss_private.document_access_leases l on l.document_id=d.id
 where d.object_name=p_name and l.actor_person_id=boss_private.current_person_id() and l.auth_session_id=(auth.jwt()->>'session_id')::uuid and l.expires_at>now()
 and ((l.purpose='ordinary' and boss_private.registration_can_document(d.id)) or (l.purpose='emergency' and d.snapshot->>'classification'='medical' and d.snapshot->'emergency_access'='true'::jsonb
 and d.status='approved' and (d.expires_on is null or d.expires_on>=current_date) and boss_private.registration_emergency_authorized(d.participant_id,d.organization_id,l.team_id))));
 exception when sqlstate 'PT401' or invalid_text_representation then return false;
end $$;
create policy boss_registration_document_upload on storage.objects for insert to authenticated
 with check(boss_private.registration_storage_insert(bucket_id,name,metadata));
create policy boss_registration_document_download on storage.objects for select to authenticated
 using(boss_private.registration_storage_select(bucket_id,name));
revoke all on function boss_private.registration_can_know_offering(uuid),boss_private.registration_safe_offering(uuid),boss_private.registration_can_know_org(uuid),boss_private.registration_detail(uuid),
 boss_private.registration_read(jsonb),public.boss_registration_read(jsonb),boss_private.registration_storage_insert(text,text,jsonb),boss_private.registration_storage_select(text,text)
 from public,anon,authenticated,service_role;
grant execute on function boss_private.registration_read(jsonb),public.boss_registration_read(jsonb),boss_private.registration_storage_insert(text,text,jsonb),boss_private.registration_storage_select(text,text) to authenticated;

-- Preserve the foundation invoker authorization and finite records unchanged.
-- Mark only the now implemented Registration module as available.
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
          'implementation_status',case when m.key='calendar' then 'Implemented: Events and calendar' when m.key='registration' then 'Implemented: Registration, forms and private documents' else 'Future / not implemented' end),case when org_manage then array['module.set'] else '{}'::text[] end) item
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
          'can_register',g.can_register,'can_sign_waivers',g.can_sign_waivers,'can_view_documents',g.can_view_documents,'can_manage_payments',g.can_manage_payments,'can_manage_profile',g.can_manage_profile),
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
revoke all on function public.boss_admin_read(text,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.boss_admin_read(text,uuid,text) to authenticated;
