-- Forward correction: expiry is time-dependent, so reads derive current
-- document compliance without rewriting retained registration evidence.
-- Preserve the existing registration_refresh_status precedence exactly.
create function boss_private.registration_current_document_status(p_registration uuid) returns text
language plpgsql stable security definer set search_path='' as $$
declare v_org uuid;d_total integer;d_done integer;d_rejected integer;d_expired integer;d_review integer;d_uploaded integer;
begin
 select r.organization_id into v_org from public.registrations r where r.id=p_registration;
 select count(*),count(*) filter(where d.status in ('approved','waived') and (d.expires_on is null or d.expires_on>=current_date)),
 count(*) filter(where d.status='rejected'),count(*) filter(where d.status='expired' or d.expires_on<current_date),
 count(*) filter(where d.status='under_review'),count(*) filter(where d.status in ('submitted','under_review','approved','waived'))
 into d_total,d_done,d_rejected,d_expired,d_review,d_uploaded from public.registration_documents d
 where d.organization_id=v_org and d.registration_id=p_registration and coalesce((d.snapshot->>'required')::boolean,true);
 return case when d_total=0 then 'not_required' when d_expired>0 then 'expired' when d_rejected>0 then 'rejected'
 when d_done=d_total then case when exists(select 1 from public.registration_documents d where d.organization_id=v_org and d.registration_id=p_registration and d.status='waived') then 'waived' else 'approved' end
 when d_review>0 then 'under_review' when d_uploaded>0 then 'submitted' else 'missing' end;
end $$;
revoke all on function boss_private.registration_current_document_status(uuid) from public,anon,authenticated,service_role;

-- Existing guards, projections and function grants remain unchanged. Only the
-- current compliance field and minimal authorized display metadata change.
create or replace function boss_private.registration_detail(p_registration uuid) returns jsonb
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
 'status',r.status,'form_status',r.form_status,'waiver_status',r.waiver_status,'document_status',boss_private.registration_current_document_status(r.id),'eligibility_status',r.eligibility_status,'approval_status',r.approval_status,'roster_status',r.roster_status,
 'assigned_team_id',r.assigned_team_id,'waitlist_position',r.waitlist_position,'version',r.version,'created_at',r.created_at,'submitted_at',r.submitted_at,'reviewed_at',r.reviewed_at,
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

create or replace function boss_private.registration_read(p_query jsonb) returns jsonb
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
 'participant_id',r.participant_id,'participant_label',coalesce(r.participant_snapshot->>'label',r.participant_snapshot->>'display_name','Participant'),'household_id',r.household_id,'household_name',case when boss_private.registration_guardian(r.participant_id,'can_register') then r.family_snapshot->>'household_name' else null end,'status',r.status,'form_status',r.form_status,'waiver_status',r.waiver_status,
 'document_status',boss_private.registration_current_document_status(r.id),'eligibility_status',r.eligibility_status,'approval_status',r.approval_status,'roster_status',r.roster_status,'waitlist_position',r.waitlist_position,'created_at',r.created_at,'submitted_at',r.submitted_at,'version',r.version,
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

-- Read correction complete. Narrow renewal command correction follows.

-- A naturally expired approval may request a fresh private upload intent.
-- Approved files with no expiry or a current expiry remain protected; all
-- existing live-session, guardian, feature, receipt and history checks are kept.
create or replace function boss_private.registration_command(p_command jsonb,p_actor uuid,p_request uuid,p_replay boolean default false,p_resource uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare op text;i jsonb;k text;j jsonb;x jsonb;v_org uuid;v_id uuid:=coalesce(p_resource,gen_random_uuid());v_kind text;v_version bigint:=1;
 o public.registration_offerings%rowtype;old_o public.registration_offerings%rowtype;r public.registrations%rowtype;
 f public.registration_form_versions%rowtype;w public.registration_waiver_versions%rowtype;d public.registration_documents%rowtype;
 req public.document_requirements%rowtype;fr public.registration_fee_rules%rowtype;c public.charges%rowtype;
 coupon public.registration_coupons%rowtype;answer public.registration_form_answers%rowtype;intent public.document_upload_intents%rowtype;
 person public.people%rowtype;participant public.participants%rowtype;emergency public.participant_emergency_records%rowtype;
 v_snapshot jsonb;v_before jsonb;v_after jsonb:='{}'::jsonb;v_result jsonb;v_context jsonb;v_scope text;v_scope_id uuid;
 v_age integer;v_count bigint;v_position bigint;v_status text;v_reason text;v_total bigint;v_adjustment bigint;v_paid bigint;v_amount bigint;
 v_charge uuid;v_payment uuid;v_plan uuid;v_installment integer;v_mime text;v_extension text;v_object text;v_purpose text;v_team uuid;
 v_fields text[];v_required text[];v_permission text;v_feature text;v_is_family boolean;v_definition jsonb;
begin
 if p_actor is distinct from boss_private.current_person_id() then raise exception 'Access denied' using errcode='PT403';end if;
 perform boss_private.registration_validate_input(p_command,array['operation','input'],array['operation','input']);
 op:=p_command->>'operation';i:=p_command->'input';
 case op
  when 'offering.upsert' then v_fields:=array['organization_id','offering_id','expected_version','title','description','scope_type','scope_id','season_id','event_id','registration_type','participant_type','opens_at','closes_at','capacity','waitlist_enabled','approval_required','visibility','status','age_min','age_max','grade_min','grade_max','team_assignment_policy'];v_required:=array['organization_id','title','scope_type','scope_id','registration_type'];
  when 'offering.publish' then v_fields:=array['offering_id','expected_version'];v_required:=v_fields;
  when 'form.publish' then v_fields:=array['offering_id','form_key','title','definition','sensitivity','required','sort_order'];v_required:=array['offering_id','form_key','title','definition'];
  when 'waiver.publish' then v_fields:=array['offering_id','waiver_key','title','body','signer_type','effective_from','effective_until','required','sort_order'];v_required:=array['offering_id','waiver_key','title','body'];
  when 'document_requirement.upsert' then v_fields:=array['offering_id','key','title','classification','required','emergency_access','allowed_mime_types','max_bytes','validity_days','sort_order'];v_required:=array['offering_id','key','title'];
  when 'fee.upsert' then v_fields:=array['offering_id','fee_rule_id','expected_version','title','charge_type','amount_minor','currency','due_on','required','status'];v_required:=array['offering_id','title','charge_type','amount_minor','currency'];
  when 'coupon.upsert' then v_fields:=array['offering_id','coupon_id','expected_version','code','title','adjustment_type','amount_minor','percent_bps','max_uses','opens_at','closes_at','status'];v_required:=array['offering_id','code','title','adjustment_type'];
  when 'registration.configure' then v_fields:=array['organization_id','features'];v_required:=v_fields;
  when 'registration.start' then v_fields:=array['offering_id','participant_id','household_id','context'];v_required:=array['offering_id','participant_id'];
  when 'registration.save' then v_fields:=array['registration_id','expected_version','context'];v_required:=array['registration_id','expected_version'];
  when 'registration.submit' then v_fields:=array['registration_id','expected_version','coupon_code'];v_required:=array['registration_id','expected_version'];
  when 'registration.decision' then v_fields:=array['registration_id','expected_version','decision','reason'];v_required:=array['registration_id','expected_version','decision'];
  when 'registration.withdraw' then v_fields:=array['registration_id','expected_version','reason'];v_required:=array['registration_id','expected_version'];
  when 'registration.eligibility' then v_fields:=array['registration_id','expected_version','status','reason'];v_required:=v_fields;
  when 'registration.assign_team' then v_fields:=array['registration_id','expected_version','team_id'];v_required:=v_fields;
  when 'registration.remove_team' then v_fields:=array['registration_id','expected_version','reason'];v_required:=v_fields;
  when 'form.answer' then v_fields:=array['registration_id','form_version_id','answers','finalize','expected_version'];v_required:=array['registration_id','form_version_id','answers','finalize'];
  when 'form.access' then v_fields:=array['registration_id','form_version_id'];v_required:=v_fields;
  when 'waiver.sign' then v_fields:=array['registration_id','waiver_version_id','name','consent'];v_required:=v_fields;
  when 'document.intent' then v_fields:=array['document_id','mime_type','size_bytes','sha256'];v_required:=array['document_id','mime_type','size_bytes'];
  when 'document.complete' then v_fields:=array['document_id','intent_id'];v_required:=v_fields;
  when 'document.review' then v_fields:=array['document_id','expected_version','status','reason','expires_on','renewal_due_on'];v_required:=array['document_id','expected_version','status','reason'];
  when 'document.access' then v_fields:=array['document_id','purpose','team_id'];v_required:=array['document_id','purpose'];
  when 'emergency.save' then v_fields:=array['registration_id','contacts','medical','physician','insurance','expected_version'];v_required:=array['registration_id','contacts'];
  when 'emergency.access' then v_fields:=array['registration_id','purpose','team_id'];v_required:=array['registration_id','purpose'];
  when 'charge.create' then v_fields:=array['registration_id','title','charge_type','amount_minor','currency','due_on'];v_required:=array['registration_id','title','charge_type','amount_minor','currency'];
  when 'charge.adjust' then v_fields:=array['charge_id','amount_minor','adjustment_type','reason'];v_required:=v_fields;
  when 'charge.cancel' then v_fields:=array['charge_id','reason'];v_required:=v_fields;
  when 'payment.record_offline' then v_fields:=array['organization_id','method','amount_minor','currency','payer_person_id','received_at','reference','note','allocations'];v_required:=array['organization_id','method','amount_minor','currency','payer_person_id','received_at','allocations'];
  when 'payment_plan.create' then v_fields:=array['charge_id','title','installments'];v_required:=v_fields;
  when 'payment_plan.cancel' then v_fields:=array['charge_id','reason'];v_required:=v_fields;
  else raise exception 'Invalid registration operation' using errcode='PT422';
 end case;
 perform boss_private.registration_validate_input(i,v_fields,v_required);
 if i?'context' then perform boss_private.registration_validate_context(i->'context');end if;

 if op='registration.configure' then
  v_org:=(i->>'organization_id')::uuid;
  if not boss_private.registration_module_enabled(v_org) or not boss_private.has_permission('organization.manage',v_org) then raise exception 'Access denied' using errcode='PT403';end if;
  for k,j in select key,value from jsonb_each(i->'features') loop
   if k not in ('registration','forms','waivers','documents','fees','payment_plans','coupons','waitlists','offline_payments','emergency_access','coach_registration_view') or jsonb_typeof(j)<>'boolean' then raise exception 'Invalid registration operation' using errcode='PT422';end if;
  end loop;
  v_id:=v_org;v_kind:='registration_configuration';
  if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
  select om.configuration into v_before from public.organization_modules om join public.modules m on m.id=om.module_id
   where om.organization_id=v_org and m.key='registration' and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()) for update of om;
  update public.organization_modules om set configuration=coalesce(om.configuration,'{}'::jsonb)||(i->'features')
   from public.modules m where m.id=om.module_id and om.organization_id=v_org and m.key='registration';v_after:=i->'features';
 elsif op='offering.upsert' then
  v_org:=(i->>'organization_id')::uuid;v_scope:=i->>'scope_type';v_scope_id:=(i->>'scope_id')::uuid;
  if not boss_private.registration_module_enabled(v_org) or not boss_private.registration_can_scope('registration.manage',v_org,v_scope,v_scope_id) then raise exception 'Access denied' using errcode='PT403';end if;
  if i?'offering_id' then
   v_id:=(i->>'offering_id')::uuid;select * into old_o from public.registration_offerings where id=v_id and organization_id=v_org for update;
   if not found then raise exception 'Access denied' using errcode='PT403';end if;perform boss_private.registration_require_scope('registration.manage',old_o);
   if not p_replay and (not i?'expected_version' or old_o.version<>(i->>'expected_version')::bigint) then raise exception 'Registration changed; reload before saving' using errcode='PT409';end if;
  elsif i?'expected_version' then raise exception 'Invalid registration operation' using errcode='PT422';
  end if;
  if i?'team_assignment_policy' then
   for k,j in select key,value from jsonb_each(i->'team_assignment_policy') loop
    if k='mode' then if j#>>'{}'<>'manual' then raise exception 'Invalid registration operation' using errcode='PT422';end if;
    elsif k not in ('require_approval','require_eligibility','require_documents','require_payment') or jsonb_typeof(j)<>'boolean' then raise exception 'Invalid registration operation' using errcode='PT422';end if;
   end loop;
  end if;
  if coalesce((i->>'waitlist_enabled')::boolean,false) and not boss_private.registration_feature(v_org,'waitlists') then raise exception 'Access denied' using errcode='PT403';end if;
  if i->>'season_id' is not null and not exists(select 1 from public.seasons s where s.id=(i->>'season_id')::uuid and s.organization_id=v_org and s.status='active'
    and (v_scope='organization' or (v_scope='unit' and s.parent_unit_id=v_scope_id) or (v_scope='team' and exists(select 1 from public.teams t where t.id=v_scope_id and t.organization_id=v_org and t.season_id=s.id)))) then raise exception 'Access denied' using errcode='PT403';end if;
  if i->>'event_id' is not null and not exists(select 1 from public.events e where e.id=(i->>'event_id')::uuid and e.organization_id=v_org and e.status<>'archived' and boss_private.calendar_can_view_event(e.id)) then raise exception 'Access denied' using errcode='PT403';end if;
  v_kind:='registration_offering';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
  if old_o.id is not null then v_before:=jsonb_build_object('status',old_o.status,'version',old_o.version);end if;
  insert into public.registration_offerings(id,organization_id,title,description,scope_type,scope_id,season_id,event_id,registration_type,participant_type,opens_at,closes_at,capacity,waitlist_enabled,approval_required,visibility,status,age_min,age_max,grade_min,grade_max,team_assignment_policy,created_by_person_id,updated_by_person_id)
  values(v_id,v_org,btrim(i->>'title'),i->>'description',v_scope,v_scope_id,(i->>'season_id')::uuid,(i->>'event_id')::uuid,i->>'registration_type',coalesce(i->>'participant_type','participant'),(i->>'opens_at')::timestamptz,(i->>'closes_at')::timestamptz,(i->>'capacity')::integer,coalesce((i->>'waitlist_enabled')::boolean,false),coalesce((i->>'approval_required')::boolean,true),coalesce(i->>'visibility','authenticated'),coalesce(i->>'status','draft'),(i->>'age_min')::integer,(i->>'age_max')::integer,(i->>'grade_min')::integer,(i->>'grade_max')::integer,coalesce(i->'team_assignment_policy','{"mode":"manual","require_approval":true}'::jsonb),p_actor,p_actor)
  on conflict(id) do update set title=excluded.title,description=excluded.description,scope_type=excluded.scope_type,scope_id=excluded.scope_id,season_id=excluded.season_id,event_id=excluded.event_id,registration_type=excluded.registration_type,participant_type=excluded.participant_type,opens_at=excluded.opens_at,closes_at=excluded.closes_at,capacity=excluded.capacity,waitlist_enabled=excluded.waitlist_enabled,approval_required=excluded.approval_required,visibility=excluded.visibility,status=excluded.status,age_min=excluded.age_min,age_max=excluded.age_max,grade_min=excluded.grade_min,grade_max=excluded.grade_max,team_assignment_policy=excluded.team_assignment_policy,updated_by_person_id=p_actor,updated_at=now(),version=public.registration_offerings.version+1
  returning version into v_version;
  select count(*) into v_count from public.registrations rr where rr.offering_id=v_id and rr.status in ('submitted','under_review','approved');
  if i->>'capacity' is not null and v_count>(i->>'capacity')::integer then raise exception 'Capacity cannot be lower than reserved places' using errcode='PT409';end if;
  v_after:=jsonb_build_object('status',coalesce(i->>'status','draft'),'version',v_version);
 elsif op in ('offering.publish','form.publish','waiver.publish','document_requirement.upsert','fee.upsert','coupon.upsert','registration.start') then
 select * into o from public.registration_offerings where id=(i->>'offering_id')::uuid for update;
  if not found or not boss_private.registration_module_enabled(o.organization_id) then raise exception 'Access denied' using errcode='PT403';end if;v_org:=o.organization_id;
  -- A physical parent-row write also prevents stale REPEATABLE READ snapshots
  -- from accepting mutually incompatible configuration/capacity changes.
  update public.registration_offerings set updated_at=updated_at where id=o.id;
  if op='registration.start' then
   if not boss_private.registration_feature(v_org,'registration') or not boss_private.registration_guardian((i->>'participant_id')::uuid,'can_register')
    or o.status<>'published' or (o.opens_at is not null and o.opens_at>now()) or (o.closes_at is not null and o.closes_at<=now()) then raise exception 'Access denied' using errcode='PT403';end if;
   if o.visibility='restricted' and not boss_private.registration_can_scope('registration.create',v_org,o.scope_type,o.scope_id) then raise exception 'Access denied' using errcode='PT403';end if;
   if o.visibility='member' and not (boss_private.has_active_organization_membership(v_org) or boss_private.registration_can_scope('registration.create',v_org,o.scope_type,o.scope_id)
    or exists(select 1 from public.participants p join public.organization_memberships m on m.person_id=p.person_id where p.id=(i->>'participant_id')::uuid and m.organization_id=v_org and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now()))) then raise exception 'Access denied' using errcode='PT403';end if;
   perform boss_private.registration_require_household((i->>'participant_id')::uuid,(i->>'household_id')::uuid);
   select * into participant from public.participants where id=(i->>'participant_id')::uuid and status='active';select * into person from public.people where id=participant.person_id and status='active';
   if person.id is null or participant.participant_type<>o.participant_type then raise exception 'Access denied' using errcode='PT403';end if;
   v_context:=coalesce(i->'context','{}'::jsonb);v_age:=extract(year from age(current_date,person.date_of_birth))::integer;
   if (o.age_min is not null and (v_age is null or v_age<o.age_min)) or (o.age_max is not null and (v_age is null or v_age>o.age_max))
    or (o.grade_min is not null and (v_context->>'grade' is null or (v_context->>'grade')::integer<o.grade_min)) or (o.grade_max is not null and (v_context->>'grade' is null or (v_context->>'grade')::integer>o.grade_max)) then raise exception 'Participant does not meet configured requirements' using errcode='PT422';end if;
   if coalesce((v_context->>'payment_plan_selected')::boolean,false) and not boss_private.registration_feature(v_org,'payment_plans') then raise exception 'Access denied' using errcode='PT403';end if;
   v_kind:='registration';if p_replay then
    if not exists(select 1 from public.registrations rr where rr.id=v_id and rr.organization_id=v_org and rr.offering_id=o.id and rr.participant_id=participant.id) then raise exception 'Access denied' using errcode='PT403';end if;return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);
   end if;
   if exists(select 1 from public.registrations rr where rr.offering_id=o.id and rr.participant_id=participant.id and rr.status not in ('withdrawn','denied','canceled','archived')) then raise exception 'An active registration already exists' using errcode='PT409';end if;
   select jsonb_build_object('offering',to_jsonb(o),
    'forms',coalesce((select jsonb_agg(jsonb_build_object('form_version_id',l.form_version_id,'required',l.required,'sort_order',l.sort_order,'version',to_jsonb(fv)) order by l.sort_order,l.form_version_id) from public.registration_offering_forms l join public.registration_form_versions fv on fv.id=l.form_version_id where l.offering_id=o.id),'[]'::jsonb),
    'waivers',coalesce((select jsonb_agg(jsonb_build_object('waiver_version_id',l.waiver_version_id,'required',l.required,'sort_order',l.sort_order,'version',to_jsonb(wv)) order by l.sort_order,l.waiver_version_id) from public.registration_offering_waivers l join public.registration_waiver_versions wv on wv.id=l.waiver_version_id where l.offering_id=o.id),'[]'::jsonb),
    'documents',coalesce((select jsonb_agg(jsonb_build_object('document_requirement_id',l.document_requirement_id,'required',l.required,'sort_order',l.sort_order,'version',to_jsonb(dr)) order by l.sort_order,l.document_requirement_id) from public.registration_offering_documents l join public.document_requirements dr on dr.id=l.document_requirement_id where l.offering_id=o.id),'[]'::jsonb),
    'fees',coalesce((select jsonb_agg(to_jsonb(ff) order by ff.id) from public.registration_fee_rules ff where ff.offering_id=o.id and ff.status='active' and ff.required),'[]'::jsonb)) into v_snapshot;
   insert into public.registrations(id,organization_id,offering_id,participant_id,household_id,submitted_by_person_id,offering_snapshot,participant_snapshot,family_snapshot,context,approval_status)
   values(v_id,v_org,o.id,participant.id,(i->>'household_id')::uuid,p_actor,v_snapshot,jsonb_build_object('participant_id',participant.id,'person_id',person.id,'label',coalesce(person.display_name,concat_ws(' ',person.first_name,person.last_name)),'display_name',coalesce(person.display_name,concat_ws(' ',person.first_name,person.last_name)),'date_of_birth',person.date_of_birth,'participant_type',participant.participant_type),
    jsonb_build_object('household_id',(i->>'household_id')::uuid,'household_name',(select h.name from public.households h where h.id=(i->>'household_id')::uuid),'submitter_person_id',p_actor,'submitter_name',(select p.display_name from public.people p where p.id=p_actor)),v_context,case when o.approval_required then 'pending' else 'not_required' end);
   for x in select value from jsonb_array_elements(v_snapshot->'documents') loop
    insert into public.registration_documents(organization_id,registration_id,participant_id,requirement_id,status,snapshot)
     values(v_org,v_id,participant.id,(x->>'document_requirement_id')::uuid,'missing',(x->'version')||jsonb_build_object('required',(x->>'required')::boolean));
   end loop;
   perform boss_private.registration_refresh_status(v_id);v_after:=jsonb_build_object('status','draft','participant_id',participant.id);
  else
   v_permission:=case when op='offering.publish' then 'registration.manage' when op='form.publish' then 'forms.manage' when op='waiver.publish' then 'waivers.manage' when op='document_requirement.upsert' then 'documents.review' else 'fees.manage' end;
   v_feature:=case when op='form.publish' then 'forms' when op='waiver.publish' then 'waivers' when op='document_requirement.upsert' then 'documents' when op='coupon.upsert' then 'coupons' when op='fee.upsert' then 'fees' else 'registration' end;
   perform boss_private.registration_require_scope(v_permission,o,v_feature);
   if op='offering.publish' then
    v_id:=o.id;v_kind:='registration_offering';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
    if o.version<>(i->>'expected_version')::bigint then raise exception 'Registration changed; reload before saving' using errcode='PT409';end if;
    v_before:=jsonb_build_object('status',o.status,'version',o.version);update public.registration_offerings set status='published',version=version+1,updated_by_person_id=p_actor,updated_at=now() where id=o.id returning version into v_version;v_after:=jsonb_build_object('status','published','version',v_version);
   elsif op='form.publish' then
    perform boss_private.registration_validate_form_definition(i->'definition');
    if coalesce(i->>'sensitivity','ordinary')='medical' then perform boss_private.registration_require_scope('documents.view',o,'documents');end if;
    v_kind:='form_version';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('registration-form:'||v_org::text||':'||(i->>'form_key'),0));
    select coalesce(max(version_number),0)+1 into v_version from public.registration_form_versions where organization_id=v_org and form_key=i->>'form_key';
    insert into public.registration_form_versions(id,organization_id,form_key,title,version_number,definition,sensitivity,published_by_person_id) values(v_id,v_org,i->>'form_key',i->>'title',v_version,i->'definition',coalesce(i->>'sensitivity','ordinary'),p_actor);
    delete from public.registration_offering_forms l using public.registration_form_versions fv where l.offering_id=o.id and fv.id=l.form_version_id and fv.form_key=i->>'form_key';
    insert into public.registration_offering_forms(organization_id,offering_id,form_version_id,required,sort_order) values(v_org,o.id,v_id,coalesce((i->>'required')::boolean,true),coalesce((i->>'sort_order')::integer,0));
    v_after:=jsonb_build_object('version',v_version,'offering_id',o.id);
   elsif op='waiver.publish' then
    v_kind:='waiver_version';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('registration-waiver:'||v_org::text||':'||(i->>'waiver_key'),0));
    select coalesce(max(version_number),0)+1 into v_version from public.registration_waiver_versions where organization_id=v_org and waiver_key=i->>'waiver_key';
    insert into public.registration_waiver_versions(id,organization_id,waiver_key,title,version_number,body,signer_type,effective_from,effective_until,published_by_person_id) values(v_id,v_org,i->>'waiver_key',i->>'title',v_version,i->>'body',coalesce(i->>'signer_type','guardian'),coalesce((i->>'effective_from')::timestamptz,now()),(i->>'effective_until')::timestamptz,p_actor);
    delete from public.registration_offering_waivers l using public.registration_waiver_versions wv where l.offering_id=o.id and wv.id=l.waiver_version_id and wv.waiver_key=i->>'waiver_key';
    insert into public.registration_offering_waivers(organization_id,offering_id,waiver_version_id,required,sort_order) values(v_org,o.id,v_id,coalesce((i->>'required')::boolean,true),coalesce((i->>'sort_order')::integer,0));v_after:=jsonb_build_object('version',v_version,'offering_id',o.id);
   elsif op='document_requirement.upsert' then
    if coalesce((i->>'emergency_access')::boolean,false) and (coalesce(i->>'classification','standard')<>'medical' or not boss_private.registration_feature(v_org,'emergency_access')) then raise exception 'Access denied' using errcode='PT403';end if;
    if i?'allowed_mime_types' and (jsonb_array_length(i->'allowed_mime_types') not between 1 and 3 or exists(select 1 from jsonb_array_elements(i->'allowed_mime_types') m where jsonb_typeof(m)<>'string' or m#>>'{}' not in ('application/pdf','image/jpeg','image/png'))) then raise exception 'Invalid registration operation' using errcode='PT422';end if;
    v_kind:='document_requirement';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('registration-document:'||v_org::text||':'||(i->>'key'),0));
    select coalesce(max(version_number),0)+1 into v_version from public.document_requirements where organization_id=v_org and key=i->>'key';
    insert into public.document_requirements(id,organization_id,key,title,version_number,classification,required,emergency_access,allowed_mime_types,max_bytes,validity_days,created_by_person_id)
    values(v_id,v_org,i->>'key',i->>'title',v_version,coalesce(i->>'classification','standard'),coalesce((i->>'required')::boolean,true),coalesce((i->>'emergency_access')::boolean,false),case when i?'allowed_mime_types' then array(select m#>>'{}' from jsonb_array_elements(i->'allowed_mime_types') m) else array['application/pdf','image/jpeg','image/png'] end,coalesce((i->>'max_bytes')::bigint,10485760),(i->>'validity_days')::integer,p_actor);
    delete from public.registration_offering_documents l using public.document_requirements dr where l.offering_id=o.id and dr.id=l.document_requirement_id and dr.key=i->>'key';
    insert into public.registration_offering_documents(organization_id,offering_id,document_requirement_id,required,sort_order) values(v_org,o.id,v_id,coalesce((i->>'required')::boolean,true),coalesce((i->>'sort_order')::integer,0));v_after:=jsonb_build_object('version',v_version,'offering_id',o.id);
   elsif op='fee.upsert' then
    if (i->>'amount_minor')::bigint<0 or i->>'currency'!~'^[A-Z]{3}$' then raise exception 'Invalid registration operation' using errcode='PT422';end if;
    if i?'fee_rule_id' then
     v_id:=(i->>'fee_rule_id')::uuid;select * into fr from public.registration_fee_rules where id=v_id and offering_id=o.id for update;
     if not found then raise exception 'Access denied' using errcode='PT403';end if;
     if not p_replay and (not i?'expected_version' or fr.version<>(i->>'expected_version')::bigint) then raise exception 'Registration changed; reload before saving' using errcode='PT409';end if;
    end if;
    v_kind:='fee_rule';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
    insert into public.registration_fee_rules(id,organization_id,offering_id,title,charge_type,amount_minor,currency,due_on,required,status)
    values(v_id,v_org,o.id,i->>'title',i->>'charge_type',(i->>'amount_minor')::bigint,i->>'currency',(i->>'due_on')::date,coalesce((i->>'required')::boolean,true),coalesce(i->>'status','active'))
    on conflict(id) do update set title=excluded.title,charge_type=excluded.charge_type,amount_minor=excluded.amount_minor,currency=excluded.currency,due_on=excluded.due_on,required=excluded.required,status=excluded.status,version=public.registration_fee_rules.version+1 returning version into v_version;v_after:=jsonb_build_object('version',v_version,'amount_minor',(i->>'amount_minor')::bigint,'currency',i->>'currency');
   elsif op='coupon.upsert' then
    if i->>'code'!~'^[A-Z0-9_-]{1,40}$' or (i->>'adjustment_type'='fixed' and ((i->>'amount_minor')::bigint is null or (i->>'amount_minor')::bigint<=0 or i?'percent_bps')) or (i->>'adjustment_type'='percent' and ((i->>'percent_bps')::integer is null or (i->>'percent_bps')::integer not between 1 and 10000 or i?'amount_minor')) or i->>'adjustment_type' not in ('fixed','percent') then raise exception 'Invalid registration operation' using errcode='PT422';end if;
    if i?'coupon_id' then v_id:=(i->>'coupon_id')::uuid;select * into coupon from public.registration_coupons where id=v_id and offering_id=o.id for update;
     if not found then raise exception 'Access denied' using errcode='PT403';end if;if not p_replay and (not i?'expected_version' or coupon.version<>(i->>'expected_version')::bigint) then raise exception 'Registration changed; reload before saving' using errcode='PT409';end if;
    end if;
    v_kind:='coupon';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
    insert into public.registration_coupons(id,organization_id,offering_id,code,title,adjustment_type,amount_minor,percent_bps,max_uses,opens_at,closes_at,status,created_by_person_id)
    values(v_id,v_org,o.id,i->>'code',i->>'title',i->>'adjustment_type',(i->>'amount_minor')::bigint,(i->>'percent_bps')::integer,(i->>'max_uses')::integer,(i->>'opens_at')::timestamptz,(i->>'closes_at')::timestamptz,coalesce(i->>'status','active'),p_actor)
    on conflict(id) do update set code=excluded.code,title=excluded.title,adjustment_type=excluded.adjustment_type,amount_minor=excluded.amount_minor,percent_bps=excluded.percent_bps,max_uses=excluded.max_uses,opens_at=excluded.opens_at,closes_at=excluded.closes_at,status=excluded.status,version=public.registration_coupons.version+1 returning version into v_version;
    if i->>'max_uses' is not null and coupon.used_count>(i->>'max_uses')::integer then raise exception 'Coupon limit cannot be lower than existing uses' using errcode='PT409';end if;v_after:=jsonb_build_object('version',v_version,'offering_id',o.id);
   end if;
  end if;
 elsif op='payment.record_offline' then
  v_org:=(i->>'organization_id')::uuid;v_kind:='payment';v_payment:=v_id;
  if not boss_private.registration_feature(v_org,'fees') or not boss_private.registration_feature(v_org,'offline_payments') then raise exception 'Access denied' using errcode='PT403';end if;
  if i->>'method' not in ('cash','check') or (i->>'amount_minor')::bigint not between 1 and 1000000000
   or i->>'currency'!~'^[A-Z]{3}$' or (i->>'method'='check' and coalesce(length(btrim(i->>'reference')),0)=0)
   or jsonb_array_length(i->'allocations') not between 1 and 50 then raise exception 'Invalid registration operation' using errcode='PT422';end if;
  v_total:=0;
  for x in select value from jsonb_array_elements(i->'allocations') loop
   perform boss_private.registration_validate_input(x,array['charge_id','amount_minor'],array['charge_id','amount_minor']);
   if (x->>'amount_minor')::bigint not between 1 and 1000000000 then raise exception 'Invalid registration operation' using errcode='PT422';end if;v_total:=v_total+(x->>'amount_minor')::bigint;
  end loop;
  if v_total<>(i->>'amount_minor')::bigint or (select count(distinct allocation_item->>'charge_id') from jsonb_array_elements(i->'allocations') allocation_item)<>jsonb_array_length(i->'allocations') then raise exception 'Invalid registration operation' using errcode='PT422';end if;
  for x in select value from jsonb_array_elements(i->'allocations') order by value->>'charge_id' loop
   select * into c from public.charges where id=(x->>'charge_id')::uuid and organization_id=v_org for update;
   if not found or not boss_private.registration_can_record('payments.record_offline',c.registration_id) then raise exception 'Access denied' using errcode='PT403';end if;
   update public.charges set status=status where id=c.id;
   select * into r from public.registrations where id=c.registration_id;
   if not exists(select 1 from public.people p where p.id=(i->>'payer_person_id')::uuid and p.status='active' and (
    p.id=r.submitted_by_person_id or p.id=(select pp.person_id from public.participants pp where pp.id=r.participant_id)
    or exists(select 1 from public.guardian_relationships g join public.participants pp on pp.person_id=g.dependent_person_id where pp.id=r.participant_id and g.guardian_person_id=p.id and g.authority_status='active' and g.can_manage_payments and g.verified_at<=now() and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now()))
    or exists(select 1 from public.household_memberships hm where hm.household_id=r.household_id and hm.person_id=p.id and hm.status='active' and hm.starts_at<=now() and (hm.ends_at is null or hm.ends_at>now())))) then raise exception 'Access denied' using errcode='PT403';end if;
   if c.currency<>i->>'currency' then raise exception 'Access denied' using errcode='PT403';end if;
   if not p_replay then
    if c.status<>'active' or (boss_private.registration_charge_balance(c.id)->>'balance_due_minor')::bigint<(x->>'amount_minor')::bigint then raise exception 'Payment exceeds current obligation' using errcode='PT409';end if;
   end if;
  end loop;
  if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
  insert into public.payments(id,organization_id,method,amount_minor,currency,payer_person_id,received_at,reference,note,recorded_by_person_id)
   values(v_payment,v_org,i->>'method',(i->>'amount_minor')::bigint,i->>'currency',(i->>'payer_person_id')::uuid,(i->>'received_at')::timestamptz,i->>'reference',i->>'note',p_actor);
  for x in select value from jsonb_array_elements(i->'allocations') loop
   insert into public.payment_allocations(organization_id,payment_id,charge_id,amount_minor) values(v_org,v_payment,(x->>'charge_id')::uuid,(x->>'amount_minor')::bigint);
  end loop;
  v_after:=jsonb_build_object('method',i->>'method','amount_minor',(i->>'amount_minor')::bigint,'currency',i->>'currency','allocation_count',jsonb_array_length(i->'allocations'));
 else
  -- Resolve every parent internally before considering caller-supplied scope.
  if op like 'document.%' then
   select * into d from public.registration_documents where id=(i->>'document_id')::uuid;
   if not found then raise exception 'Access denied' using errcode='PT403';end if;select * into r from public.registrations where id=d.registration_id;
  elsif op in ('charge.adjust','charge.cancel','payment_plan.create','payment_plan.cancel') then
   select * into c from public.charges where id=(i->>'charge_id')::uuid;
   if not found then raise exception 'Access denied' using errcode='PT403';end if;select * into r from public.registrations where id=c.registration_id;
  else select * into r from public.registrations where id=(i->>'registration_id')::uuid;
  end if;
  if r.id is null then raise exception 'Access denied' using errcode='PT403';end if;
  select * into o from public.registration_offerings where id=r.offering_id and organization_id=r.organization_id for update;
  if not found or not boss_private.registration_feature(r.organization_id,'registration') then raise exception 'Access denied' using errcode='PT403';end if;v_org:=r.organization_id;
  if op not in ('document.access','emergency.access','form.access') then update public.registration_offerings set updated_at=updated_at where id=o.id;end if;
  select * into r from public.registrations where id=r.id for update;
  v_is_family:=boss_private.registration_guardian(r.participant_id,'can_register');
  if op in ('registration.save','registration.submit','registration.withdraw','form.answer','emergency.save') then
   if not v_is_family then raise exception 'Access denied' using errcode='PT403';end if;perform boss_private.registration_require_household(r.participant_id,r.household_id);
  elsif op='waiver.sign' then
   if not boss_private.registration_feature(v_org,'waivers') or not boss_private.registration_guardian(r.participant_id,'can_sign_waivers') then raise exception 'Access denied' using errcode='PT403';end if;
  elsif op in ('registration.decision','registration.eligibility') then perform boss_private.registration_require_scope('registration.review',o,'registration');
  elsif op in ('registration.assign_team','registration.remove_team') then perform boss_private.registration_require_scope('registration.manage',o,'registration');
  elsif op='document.review' then perform boss_private.registration_require_scope('documents.review',o,'documents');
  elsif op in ('document.intent','document.complete') then
   if not boss_private.registration_feature(v_org,'documents') or not boss_private.registration_guardian(r.participant_id,'can_view_documents') or not v_is_family then raise exception 'Access denied' using errcode='PT403';end if;
  elsif op in ('charge.create','charge.adjust','charge.cancel','payment_plan.create','payment_plan.cancel') then perform boss_private.registration_require_scope('fees.manage',o,case when op like 'payment_plan.%' then 'payment_plans' else 'fees' end);
  end if;
  if op in ('registration.save','registration.submit','registration.decision','registration.withdraw','registration.eligibility','registration.assign_team','registration.remove_team') then
   v_kind:='registration';v_id:=r.id;
   if not p_replay and r.version<>(i->>'expected_version')::bigint then raise exception 'Registration changed; reload before saving' using errcode='PT409';end if;
   v_before:=jsonb_build_object('status',r.status,'approval_status',r.approval_status,'eligibility_status',r.eligibility_status,'roster_status',r.roster_status,'version',r.version);
  end if;
  if op='registration.save' then
   if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if r.status<>'draft' then raise exception 'Submitted registration evidence cannot be rewritten' using errcode='PT409';end if;
   v_context:=coalesce(i->'context',r.context);
   if coalesce((v_context->>'payment_plan_selected')::boolean,false) and not boss_private.registration_feature(v_org,'payment_plans') then raise exception 'Access denied' using errcode='PT403';end if;
   update public.registrations set context=v_context,version=version+1,updated_at=now() where id=r.id returning version into v_version;v_after:=jsonb_build_object('status','draft','version',v_version);
  elsif op='registration.submit' then
   if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if r.status<>'draft' or o.status<>'published' or (o.opens_at is not null and o.opens_at>now()) or (o.closes_at is not null and o.closes_at<=now()) then raise exception 'Registration cannot be submitted' using errcode='PT409';end if;
   j:=r.offering_snapshot->'offering';v_age:=extract(year from age(current_date,(r.participant_snapshot->>'date_of_birth')::date))::integer;
   if (j->>'age_min' is not null and (v_age is null or v_age<(j->>'age_min')::integer)) or (j->>'age_max' is not null and (v_age is null or v_age>(j->>'age_max')::integer))
    or (j->>'grade_min' is not null and (r.context->>'grade' is null or (r.context->>'grade')::integer<(j->>'grade_min')::integer)) or (j->>'grade_max' is not null and (r.context->>'grade' is null or (r.context->>'grade')::integer>(j->>'grade_max')::integer)) then raise exception 'Participant does not meet configured requirements' using errcode='PT422';end if;
   for x in select value from jsonb_array_elements(r.offering_snapshot->'forms') where (value->>'required')::boolean loop
    select * into answer from public.registration_form_answers where registration_id=r.id and form_version_id=(x->>'form_version_id')::uuid and status='submitted';
    if not found then raise exception 'Required forms remain incomplete' using errcode='PT422';end if;
    perform boss_private.registration_validate_form_answers(x->'version'->'definition',answer.answers,r.participant_id,r.context,true);
   end loop;
   for x in select value from jsonb_array_elements(r.offering_snapshot->'waivers') where (value->>'required')::boolean loop
    if not exists(select 1 from public.waiver_signatures s where s.registration_id=r.id and s.waiver_version_id=(x->>'waiver_version_id')::uuid and s.status='signed') then raise exception 'Required signatures remain incomplete' using errcode='PT422';end if;
   end loop;
   select count(*) into v_count from public.registrations rr where rr.offering_id=o.id and rr.status in ('submitted','under_review','approved');
   v_status:=case when coalesce((r.offering_snapshot->'offering'->>'approval_required')::boolean,true) then 'submitted' else 'approved' end;
   if o.capacity is not null and v_count>=o.capacity then
    if not o.waitlist_enabled or not boss_private.registration_feature(v_org,'waitlists') then raise exception 'Registration capacity reached' using errcode='PT409';end if;
    v_status:='waitlisted';select coalesce(max(waitlist_position),0)+1 into v_position from public.registrations rr where rr.offering_id=o.id;
   end if;
   if i?'coupon_code' then
    if not boss_private.registration_feature(v_org,'coupons') or not boss_private.registration_feature(v_org,'fees') then raise exception 'Access denied' using errcode='PT403';end if;
    select * into coupon from public.registration_coupons where offering_id=o.id and code=i->>'coupon_code' and status='active' for update;
    if not found or (coupon.opens_at is not null and coupon.opens_at>now()) or (coupon.closes_at is not null and coupon.closes_at<=now()) or (coupon.max_uses is not null and coupon.used_count>=coupon.max_uses) then raise exception 'Coupon is unavailable' using errcode='PT422';end if;
    if coupon.adjustment_type='fixed' and (select count(distinct fee_item->>'currency') from jsonb_array_elements(r.offering_snapshot->'fees') fee_item)>1 then raise exception 'Fixed coupon requires one obligation currency' using errcode='PT422';end if;
   end if;
   if jsonb_array_length(r.offering_snapshot->'fees')>0 and not boss_private.registration_feature(v_org,'fees') then raise exception 'Access denied' using errcode='PT403';end if;
   v_adjustment:=coalesce(coupon.amount_minor,0);
   for x in select value from jsonb_array_elements(r.offering_snapshot->'fees') order by value->>'id' loop
    v_charge:=gen_random_uuid();v_amount:=(x->>'amount_minor')::bigint;
    insert into public.charges(id,organization_id,registration_id,participant_id,household_id,event_id,fee_rule_id,title,charge_type,original_amount_minor,currency,due_on,created_by_person_id)
    values(v_charge,v_org,r.id,r.participant_id,r.household_id,(r.offering_snapshot->'offering'->>'event_id')::uuid,(x->>'id')::uuid,x->>'title',x->>'charge_type',v_amount,x->>'currency',(x->>'due_on')::date,p_actor);
    if coupon.id is not null then
     v_total:=case when coupon.adjustment_type='percent' then v_amount*coupon.percent_bps/10000 else least(v_amount,v_adjustment) end;
     if v_total>0 then insert into public.charge_adjustments(organization_id,charge_id,amount_minor,adjustment_type,reason,source_coupon_id,recorded_by_person_id) values(v_org,v_charge,-v_total,'coupon','Configured registration coupon',coupon.id,p_actor);end if;
     if coupon.adjustment_type='fixed' then v_adjustment:=v_adjustment-v_total;end if;
    end if;
    insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data)
    values(v_org,p_actor,auth.uid(),'charge.create_from_registration','charge',v_charge,'organization',v_org,p_request,jsonb_build_object('registration_id',r.id,'original_amount_minor',v_amount,'currency',x->>'currency'));
   end loop;
   if coupon.id is not null then update public.registration_coupons set used_count=used_count+1 where id=coupon.id;
    insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,after_data) values(v_org,p_actor,auth.uid(),'coupon.apply','registration',r.id,'organization',v_org,p_request,jsonb_build_object('coupon_id',coupon.id));end if;
   update public.registrations set status=v_status,submitted_at=now(),waitlist_position=v_position,approval_status=case when v_status='approved' then 'not_required' else approval_status end,version=version+1,updated_at=now() where id=r.id returning version into v_version;
   perform boss_private.registration_refresh_status(r.id);v_after:=jsonb_build_object('status',v_status,'waitlist_position',v_position,'version',v_version);
  elsif op='registration.decision' then
   if i->>'decision' not in ('under_review','approve','deny','waitlist','promote','cancel','archive') then raise exception 'Invalid registration operation' using errcode='PT422';end if;
   if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if r.status in ('draft','withdrawn','canceled','archived','denied') and i->>'decision'<>'archive' then raise exception 'Registration cannot be reviewed in its current state' using errcode='PT409';end if;
   v_status:=case i->>'decision' when 'approve' then 'approved' when 'deny' then 'denied' when 'waitlist' then 'waitlisted' when 'promote' then case when coalesce((r.offering_snapshot->'offering'->>'approval_required')::boolean,true) then 'submitted' else 'approved' end when 'cancel' then 'canceled' when 'archive' then 'archived' else 'under_review' end;
   if i->>'decision'='promote' and r.status<>'waitlisted' then raise exception 'Registration is not waitlisted' using errcode='PT409';end if;
   if v_status in ('approved','submitted','under_review') and r.status not in ('submitted','under_review','approved') then
    select count(*) into v_count from public.registrations rr where rr.offering_id=o.id and rr.status in ('submitted','under_review','approved');
    if o.capacity is not null and v_count>=o.capacity then raise exception 'Registration capacity reached' using errcode='PT409';end if;
   end if;
   if v_status='waitlisted' then
    if not o.waitlist_enabled or not boss_private.registration_feature(v_org,'waitlists') then raise exception 'Access denied' using errcode='PT403';end if;select coalesce(r.waitlist_position,(select coalesce(max(waitlist_position),0)+1 from public.registrations rr where rr.offering_id=o.id)) into v_position;
   end if;
   if v_status in ('denied','canceled','archived','waitlisted') and r.assigned_team_id is not null then raise exception 'Remove roster assignment before ending or waitlisting registration' using errcode='PT409';end if;
   update public.registrations set status=v_status,waitlist_position=v_position,approval_status=case when v_status='approved' then 'approved' when v_status='denied' then 'denied' else approval_status end,reviewed_by_person_id=p_actor,reviewed_at=now(),review_reason=i->>'reason',version=version+1,updated_at=now() where id=r.id returning version into v_version;v_after:=jsonb_build_object('status',v_status,'version',v_version);
  elsif op='registration.withdraw' then
   if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if r.status in ('withdrawn','canceled','archived','denied') or r.assigned_team_id is not null then raise exception 'Registration cannot be withdrawn in its current state' using errcode='PT409';end if;
   update public.registrations set status='withdrawn',waitlist_position=null,review_reason=i->>'reason',version=version+1,updated_at=now() where id=r.id returning version into v_version;v_after:=jsonb_build_object('status','withdrawn','version',v_version);
  elsif op='registration.eligibility' then
   if i->>'status' not in ('pending','eligible','ineligible','waived') then raise exception 'Invalid registration operation' using errcode='PT422';end if;
   if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   update public.registrations set eligibility_status=i->>'status',reviewed_by_person_id=p_actor,reviewed_at=now(),review_reason=i->>'reason',version=version+1,updated_at=now() where id=r.id returning version into v_version;v_after:=jsonb_build_object('eligibility_status',i->>'status','version',v_version);
  elsif op='registration.assign_team' then
   v_team:=(i->>'team_id')::uuid;
   if not exists(select 1 from public.teams t where t.id=v_team and t.organization_id=v_org and t.status='active' and boss_private.has_permission('team.roster.manage',v_org,t.parent_unit_id,t.id)
    and (o.scope_type='organization' or (o.scope_type='unit' and t.parent_unit_id=o.scope_id) or (o.scope_type='team' and t.id=o.scope_id))
    and ((r.offering_snapshot->'offering'->>'season_id') is null or t.season_id=(r.offering_snapshot->'offering'->>'season_id')::uuid)) then raise exception 'Access denied' using errcode='PT403';end if;
   if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('registration-team:'||v_team::text||':'||r.participant_id::text,0));
   update public.teams set updated_at=updated_at where id=v_team and organization_id=v_org;
   if r.status not in ('submitted','under_review','approved') or r.assigned_team_id is not null then raise exception 'Registration cannot be assigned in its current state' using errcode='PT409';end if;
   j:=r.offering_snapshot->'offering'->'team_assignment_policy';
   perform boss_private.registration_refresh_status(r.id);select * into r from public.registrations where id=r.id;
   if (coalesce((j->>'require_approval')::boolean,true) and (r.status<>'approved' or r.approval_status not in ('approved','not_required')))
    or (coalesce((j->>'require_eligibility')::boolean,false) and r.eligibility_status not in ('eligible','waived'))
    or (coalesce((j->>'require_documents')::boolean,false) and r.document_status not in ('approved','waived','not_required'))
    or (coalesce((j->>'require_payment')::boolean,false) and exists(select 1 from public.charges cc where cc.registration_id=r.id and cc.status='active' and (boss_private.registration_charge_balance(cc.id)->>'balance_due_minor')::bigint>0)) then raise exception 'Configured roster prerequisites remain incomplete' using errcode='PT409';end if;
   if exists(select 1 from public.team_memberships tm where tm.team_id=v_team and tm.participant_id=r.participant_id and tm.status='active' and tm.starts_at<=now() and (tm.ends_at is null or tm.ends_at>now())) then raise exception 'Participant already has an active team assignment' using errcode='PT409';end if;
   insert into public.team_memberships(organization_id,team_id,person_id,participant_id,membership_type,status) values(v_org,v_team,(select pp.person_id from public.participants pp where pp.id=r.participant_id),r.participant_id,'athlete','active');
   update public.registrations set roster_status='assigned',assigned_team_id=v_team,version=version+1,updated_at=now() where id=r.id returning version into v_version;v_after:=jsonb_build_object('roster_status','assigned','team_id',v_team,'version',v_version);
  elsif op='registration.remove_team' then
   v_team:=r.assigned_team_id;
   if p_replay then select (a.after_data->>'removed_team_id')::uuid into v_team from public.audit_events a where a.actor_person_id=p_actor and a.request_id=p_request and a.action='registration.remove_team' and a.resource_id=r.id order by a.created_at desc limit 1;end if;
   if v_team is null or not exists(select 1 from public.teams t where t.id=v_team and t.organization_id=v_org and boss_private.has_permission('team.roster.manage',v_org,t.parent_unit_id,t.id)) then raise exception 'Access denied' using errcode='PT403';end if;
   if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('registration-team:'||v_team::text||':'||r.participant_id::text,0));
   update public.teams set updated_at=updated_at where id=v_team and organization_id=v_org;
   update public.team_memberships set status='inactive',ends_at=greatest(now(),starts_at+interval '1 microsecond') where team_id=v_team and organization_id=v_org and participant_id=r.participant_id and membership_type='athlete' and status='active' and starts_at<=now() and (ends_at is null or ends_at>now());
   update public.registrations set roster_status='removed',assigned_team_id=null,version=version+1,updated_at=now() where id=r.id returning version into v_version;v_after:=jsonb_build_object('roster_status','removed','removed_team_id',v_team,'version',v_version);
  elsif op='form.answer' then
   if not boss_private.registration_feature(v_org,'forms') then raise exception 'Access denied' using errcode='PT403';end if;
   select value->'version'->'definition' into v_definition from jsonb_array_elements(r.offering_snapshot->'forms') where value->>'form_version_id'=i->>'form_version_id';
   if v_definition is null then raise exception 'Access denied' using errcode='PT403';end if;
   select * into f from public.registration_form_versions where id=(i->>'form_version_id')::uuid and organization_id=v_org;
   if f.sensitivity='medical' and not boss_private.registration_guardian(r.participant_id,'can_view_documents') then raise exception 'Access denied' using errcode='PT403';end if;
   if (i->>'finalize')::boolean and exists(select 1 from jsonb_array_elements(v_definition->'fields') ff where ff->>'type'='signature') and not boss_private.registration_guardian(r.participant_id,'can_sign_waivers') then raise exception 'Access denied' using errcode='PT403';end if;
   v_kind:='form_answer';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if r.status<>'draft' then raise exception 'Submitted registration evidence cannot be rewritten' using errcode='PT409';end if;
   perform boss_private.registration_validate_form_answers(v_definition,i->'answers',r.participant_id,r.context,(i->>'finalize')::boolean);
   -- Private references must resolve within this exact registration, even when
   -- one canonical participant has registrations in several organizations.
   for x in select value from jsonb_array_elements(v_definition->'fields') where value->>'type' in ('file_upload','emergency_contact') loop
    if i->'answers'?(x->>'key') and i->'answers'->(x->>'key') not in ('null'::jsonb,'""'::jsonb) then
     if x->>'type'='file_upload' and not exists(select 1 from public.registration_documents dd where dd.id=(i->'answers'->>(x->>'key'))::uuid and dd.registration_id=r.id and dd.status in ('submitted','under_review','approved')) then raise exception 'Invalid document reference' using errcode='PT422';end if;
     if x->>'type'='emergency_contact' and not exists(select 1 from public.participant_emergency_records ee where ee.id=(i->'answers'->>(x->>'key'))::uuid and ee.registration_id=r.id) then raise exception 'Invalid emergency reference' using errcode='PT422';end if;
    end if;
   end loop;
   select * into answer from public.registration_form_answers where registration_id=r.id and form_version_id=f.id for update;
   if found then
    v_id:=answer.id;if answer.status='submitted' or not i?'expected_version' or answer.version<>(i->>'expected_version')::bigint then raise exception 'Form changed; reload before saving' using errcode='PT409';end if;
   elsif i?'expected_version' then raise exception 'Form changed; reload before saving' using errcode='PT409';end if;
   insert into public.registration_form_answers(id,organization_id,registration_id,form_version_id,answers,status,respondent_person_id,completed_at)
    values(v_id,v_org,r.id,f.id,i->'answers',case when (i->>'finalize')::boolean then 'submitted' else 'draft' end,p_actor,case when (i->>'finalize')::boolean then now() end)
    on conflict(registration_id,form_version_id) do update set answers=excluded.answers,status=excluded.status,respondent_person_id=p_actor,completed_at=excluded.completed_at,version=public.registration_form_answers.version+1,updated_at=now() returning version into v_version;
   perform boss_private.registration_refresh_status(r.id);v_after:=jsonb_build_object('form_version_id',f.id,'status',case when (i->>'finalize')::boolean then 'submitted' else 'draft' end,'version',v_version);
  elsif op='form.access' then
   if not boss_private.registration_feature(v_org,'forms') or not boss_private.registration_feature(v_org,'documents')
    or not (boss_private.registration_guardian(r.participant_id,'can_view_documents') or boss_private.registration_can_record('documents.view',r.id))
    or not exists(select 1 from jsonb_array_elements(r.offering_snapshot->'forms') ff where ff->>'form_version_id'=i->>'form_version_id') then raise exception 'Access denied' using errcode='PT403';end if;
   select * into f from public.registration_form_versions where id=(i->>'form_version_id')::uuid and organization_id=v_org;
   select * into answer from public.registration_form_answers where registration_id=r.id and form_version_id=f.id;
   -- The same audited private path supplies a blank definition for the actual
   -- family's first medical response. Reading never creates answer evidence.
   if found then
    v_kind:='form_answer';v_id:=answer.id;v_version:=answer.version;
    v_result:=jsonb_build_object('form_version_id',f.id,'definition',f.definition,'answers',answer.answers,'status',answer.status,'completed_at',answer.completed_at,'respondent_person_id',answer.respondent_person_id);
   else
    v_kind:='form_version';v_id:=f.id;v_version:=null;
    v_result:=jsonb_build_object('form_version_id',f.id,'definition',f.definition,'answers','{}'::jsonb,'status','not_started','completed_at',null,'respondent_person_id',null);
   end if;
   v_after:=jsonb_build_object('registration_id',r.id,'form_version_id',f.id,'version',v_version);
  elsif op='waiver.sign' then
   select * into w from public.registration_waiver_versions where id=(i->>'waiver_version_id')::uuid and organization_id=v_org;
   if not found or not exists(select 1 from jsonb_array_elements(r.offering_snapshot->'waivers') ww where ww->>'waiver_version_id'=i->>'waiver_version_id') then raise exception 'Access denied' using errcode='PT403';end if;
   select * into participant from public.participants where id=r.participant_id;
   if (w.signer_type='guardian' and participant.person_id=p_actor) or (w.signer_type='participant' and participant.person_id<>p_actor) then raise exception 'Access denied' using errcode='PT403';end if;
   if i->'consent'<>'true'::jsonb then raise exception 'Explicit signature consent is required' using errcode='PT422';end if;
   v_kind:='waiver_signature';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if r.status<>'draft' or w.effective_from>now() or (w.effective_until is not null and w.effective_until<=now()) then raise exception 'Waiver cannot be signed in its current state' using errcode='PT409';end if;
   insert into public.waiver_signatures(id,organization_id,registration_id,waiver_version_id,participant_id,signer_person_id,signer_name,consent,version_snapshot,request_context)
    values(v_id,v_org,r.id,w.id,r.participant_id,p_actor,btrim(i->>'name'),true,to_jsonb(w),jsonb_build_object('actor_auth_user_id',auth.uid(),'request_id',p_request,'context_source','validated authenticated session and database timestamp'));
   perform boss_private.registration_refresh_status(r.id);v_after:=jsonb_build_object('waiver_version_id',w.id,'participant_id',r.participant_id,'status','signed');
  elsif op='document.intent' then
   select * into d from public.registration_documents where id=d.id for update;
   v_kind:='document_upload_intent';v_mime:=i->>'mime_type';
   if not v_mime=any(array(select jsonb_array_elements_text(d.snapshot->'allowed_mime_types'))) or (i->>'size_bytes')::bigint not between 1 and (d.snapshot->>'max_bytes')::bigint or (i?'sha256' and i->>'sha256'!~'^[a-f0-9]{64}$') then raise exception 'Invalid private document upload' using errcode='PT422';end if;
   if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if r.status in ('withdrawn','canceled','archived','denied') or not (d.status in ('missing','rejected','expired','upload_pending') or (d.status='approved' and coalesce(d.expires_on<current_date,false))) then raise exception 'Document cannot be uploaded in its current state' using errcode='PT409';end if;
   v_extension:=case v_mime when 'application/pdf' then 'pdf' when 'image/jpeg' then 'jpg' when 'image/png' then 'png' else null end;
   if v_extension is null then raise exception 'Invalid private document upload' using errcode='PT422';end if;
   v_object:=v_org::text||'/'||r.id::text||'/'||d.id::text||'/'||v_id::text||'.'||v_extension;
   update public.document_upload_intents set consumed_at=now() where document_id=d.id and consumed_at is null;
   insert into public.document_upload_intents(id,organization_id,document_id,actor_person_id,auth_session_id,object_name,mime_type,size_bytes,sha256,expires_at)
    values(v_id,v_org,d.id,p_actor,(auth.jwt()->>'session_id')::uuid,v_object,v_mime,(i->>'size_bytes')::bigint,i->>'sha256',now()+interval '15 minutes');
   v_before:=jsonb_build_object('document_id',d.id,'status',d.status,'version',d.version);
   update public.registration_documents set status='upload_pending',object_name=v_object,upload_mime_type=v_mime,upload_size_bytes=(i->>'size_bytes')::bigint,upload_sha256=i->>'sha256',reviewed_by_person_id=null,reviewed_at=null,review_reason=null,version=version+1,updated_at=now() where id=d.id returning version into v_version;
   v_result:=jsonb_build_object('intent_id',v_id,'document_id',d.id,'bucket','boss-registration-documents','object_name',v_object,'expires_in_seconds',900);v_after:=jsonb_build_object('document_id',d.id,'status','upload_pending','version',v_version);
  elsif op='document.complete' then
   select * into d from public.registration_documents where id=d.id for update;
   select * into intent from public.document_upload_intents where id=(i->>'intent_id')::uuid and document_id=d.id;
   if not found or intent.actor_person_id<>p_actor or intent.auth_session_id<>(auth.jwt()->>'session_id')::uuid or intent.object_name is distinct from d.object_name then raise exception 'Access denied' using errcode='PT403';end if;
   v_kind:='registration_document';v_id:=d.id;if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if intent.expires_at<=now() or intent.consumed_at is not null or d.status<>'upload_pending' then raise exception 'Upload intent is no longer active' using errcode='PT409';end if;
   if not exists(select 1 from storage.objects so where so.bucket_id='boss-registration-documents' and so.name=intent.object_name and so.metadata->>'mimetype'=intent.mime_type and so.metadata->>'size'~'^[0-9]{1,12}$' and (so.metadata->>'size')::bigint=intent.size_bytes) then raise exception 'Uploaded object could not be verified' using errcode='PT422';end if;
   update public.document_upload_intents set consumed_at=now() where id=intent.id;
   v_before:=jsonb_build_object('status',d.status,'version',d.version);update public.registration_documents set status='submitted',uploaded_by_person_id=p_actor,uploaded_at=now(),version=version+1,updated_at=now() where id=d.id returning version into v_version;
   perform boss_private.registration_refresh_status(r.id);v_after:=jsonb_build_object('status','submitted','version',v_version);
  elsif op='document.review' then
   select * into d from public.registration_documents where id=d.id for update;v_id:=d.id;v_kind:='registration_document';
   if i->>'status' not in ('under_review','approved','rejected','waived') then raise exception 'Invalid registration operation' using errcode='PT422';end if;
   if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if d.version<>(i->>'expected_version')::bigint then raise exception 'Document changed; reload before saving' using errcode='PT409';end if;
   if i->>'status'<>'waived' and (d.object_name is null or d.uploaded_at is null or d.status not in ('submitted','under_review','approved','rejected','expired')) then raise exception 'Document cannot be reviewed in its current state' using errcode='PT409';end if;
   v_before:=jsonb_build_object('status',d.status,'version',d.version);
   update public.registration_documents set status=i->>'status',reviewed_by_person_id=p_actor,reviewed_at=now(),review_reason=i->>'reason',expires_on=coalesce((i->>'expires_on')::date,case when d.snapshot->>'validity_days' is not null then current_date+(d.snapshot->>'validity_days')::integer else d.expires_on end),renewal_due_on=(i->>'renewal_due_on')::date,version=version+1,updated_at=now() where id=d.id returning version into v_version;
   perform boss_private.registration_refresh_status(r.id);v_after:=jsonb_build_object('status',i->>'status','version',v_version);
  elsif op='document.access' then
   v_purpose:=i->>'purpose';v_team:=(i->>'team_id')::uuid;
   if (v_purpose='ordinary' and (i?'team_id' or not boss_private.registration_can_document(d.id))) or (v_purpose='emergency' and (v_team is null or not coalesce((d.snapshot->>'emergency_access')::boolean,false) or d.snapshot->>'classification'<>'medical' or d.status<>'approved' or (d.expires_on is not null and d.expires_on<current_date) or not boss_private.registration_emergency_authorized(d.participant_id,v_org,v_team))) or v_purpose not in ('ordinary','emergency') then raise exception 'Access denied' using errcode='PT403';end if;
   if d.object_name is null or d.uploaded_at is null then raise exception 'Private document is not available' using errcode='PT409';end if;
   v_kind:='registration_document';v_id:=d.id;if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   insert into boss_private.document_access_leases(document_id,actor_person_id,auth_session_id,purpose,team_id,expires_at) values(d.id,p_actor,(auth.jwt()->>'session_id')::uuid,v_purpose,v_team,now()+interval '2 minutes');
   v_result:=jsonb_build_object('bucket','boss-registration-documents','object_name',d.object_name,'mime_type',d.upload_mime_type,'filename','private-document.'||case d.upload_mime_type when 'application/pdf' then 'pdf' when 'image/jpeg' then 'jpg' else 'png' end,'purpose',v_purpose,'expires_in_seconds',120);v_after:=jsonb_build_object('purpose',v_purpose,'team_id',v_team,'document_id',d.id);
  elsif op='emergency.save' then
   if not boss_private.registration_feature(v_org,'documents') or not boss_private.registration_guardian(r.participant_id,'can_view_documents') then raise exception 'Access denied' using errcode='PT403';end if;
   if jsonb_array_length(i->'contacts') not between 1 and 10 then raise exception 'Invalid registration operation' using errcode='PT422';end if;
   for x in select value from jsonb_array_elements(i->'contacts') loop
    perform boss_private.registration_validate_input(x,array['name','relationship','phone','email'],array['name','relationship','phone']);
   end loop;
   for k,j in select key,value from jsonb_each(coalesce(i->'medical','{}'::jsonb)) loop
    if k not in ('allergies','conditions','medications','instructions') or jsonb_typeof(j)<>'string' or length(j#>>'{}')>2000 then raise exception 'Invalid registration operation' using errcode='PT422';end if;
   end loop;
   perform boss_private.registration_validate_input(coalesce(i->'physician','{}'::jsonb),array['name','phone'],array[]::text[]);
   perform boss_private.registration_validate_input(coalesce(i->'insurance','{}'::jsonb),array['provider','policy_reference'],array[]::text[]);
   select * into emergency from public.participant_emergency_records where registration_id=r.id for update;
   v_kind:='emergency_record';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if r.status in ('withdrawn','canceled','archived','denied') then raise exception 'Registration cannot be changed in its current state' using errcode='PT409';end if;
   if emergency.id is not null then v_id:=emergency.id;if not i?'expected_version' or emergency.version<>(i->>'expected_version')::bigint then raise exception 'Emergency information changed; reload before saving' using errcode='PT409';end if;end if;
   insert into public.participant_emergency_records(id,organization_id,registration_id,participant_id,contacts,medical,physician,insurance,updated_by_person_id)
    values(v_id,v_org,r.id,r.participant_id,i->'contacts',coalesce(i->'medical','{}'::jsonb),coalesce(i->'physician','{}'::jsonb),coalesce(i->'insurance','{}'::jsonb),p_actor)
    on conflict(registration_id) do update set contacts=excluded.contacts,medical=excluded.medical,physician=excluded.physician,insurance=excluded.insurance,updated_by_person_id=p_actor,updated_at=now(),version=public.participant_emergency_records.version+1 returning version into v_version;v_after:=jsonb_build_object('participant_id',r.participant_id,'version',v_version);
  elsif op='emergency.access' then
   v_purpose:=i->>'purpose';v_team:=(i->>'team_id')::uuid;
   if (v_purpose='ordinary' and (i?'team_id' or not (boss_private.registration_guardian(r.participant_id,'can_view_documents') or boss_private.registration_can_record('documents.view',r.id)))) or (v_purpose='emergency' and (v_team is null or not boss_private.registration_emergency_authorized(r.participant_id,v_org,v_team))) or v_purpose not in ('ordinary','emergency') or not boss_private.registration_feature(v_org,'documents') then raise exception 'Access denied' using errcode='PT403';end if;
   select * into emergency from public.participant_emergency_records where registration_id=r.id;
   if not found then raise exception 'Emergency information is not available' using errcode='PT409';end if;
   v_id:=emergency.id;v_kind:='emergency_record';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   v_result:=jsonb_build_object('participant_id',r.participant_id,'contacts',emergency.contacts,'medical',emergency.medical,'physician',emergency.physician,'version',emergency.version);
   if v_purpose='ordinary' then v_result:=v_result||jsonb_build_object('insurance',emergency.insurance);end if;
   v_after:=jsonb_build_object('participant_id',r.participant_id,'purpose',v_purpose,'team_id',v_team,'version',emergency.version);
  elsif op='charge.create' then
   v_kind:='charge';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if (i->>'amount_minor')::bigint not between 0 and 1000000000 or i->>'currency'!~'^[A-Z]{3}$' or r.status in ('withdrawn','canceled','archived','denied') then raise exception 'Invalid registration operation' using errcode='PT422';end if;
   insert into public.charges(id,organization_id,registration_id,participant_id,household_id,event_id,title,charge_type,original_amount_minor,currency,due_on,created_by_person_id)
    values(v_id,v_org,r.id,r.participant_id,r.household_id,(r.offering_snapshot->'offering'->>'event_id')::uuid,i->>'title',i->>'charge_type',(i->>'amount_minor')::bigint,i->>'currency',(i->>'due_on')::date,p_actor);v_after:=jsonb_build_object('registration_id',r.id,'original_amount_minor',(i->>'amount_minor')::bigint,'currency',i->>'currency');
  elsif op='charge.adjust' then
   select * into c from public.charges where id=c.id for update;
   update public.charges set status=status where id=c.id;
   v_kind:='charge_adjustment';v_amount:=(i->>'amount_minor')::bigint;
   if v_amount=0 or abs(v_amount)>1000000000 or i->>'adjustment_type' not in ('discount','scholarship','credit','surcharge') or ((i->>'adjustment_type'='surcharge')<>(v_amount>0)) then raise exception 'Invalid registration operation' using errcode='PT422';end if;
   if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   j:=boss_private.registration_charge_balance(c.id);
   if c.status<>'active' or (j->>'adjusted_amount_minor')::bigint+v_amount<(j->>'applied_amount_minor')::bigint then raise exception 'Adjustment would exceed the unpaid obligation' using errcode='PT409';end if;
   if exists(select 1 from public.payment_plans pp where pp.charge_id=c.id and pp.status='active') then raise exception 'A planned charge requires a reviewed plan replacement before adjustment' using errcode='PT409';end if;
   insert into public.charge_adjustments(id,organization_id,charge_id,amount_minor,adjustment_type,reason,recorded_by_person_id) values(v_id,v_org,c.id,v_amount,i->>'adjustment_type',i->>'reason',p_actor);v_after:=jsonb_build_object('charge_id',c.id,'amount_minor',v_amount,'adjustment_type',i->>'adjustment_type');
  elsif op='charge.cancel' then
   select * into c from public.charges where id=c.id for update;update public.charges set status=status where id=c.id;
   v_id:=c.id;v_kind:='charge';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if c.status<>'active' or (boss_private.registration_charge_balance(c.id)->>'applied_amount_minor')::bigint<>0 then raise exception 'A charge with applied payments cannot be canceled' using errcode='PT409';end if;
   update public.charges set status='canceled' where id=c.id;update public.payment_plans set status='canceled' where charge_id=c.id and status='active';v_before:=jsonb_build_object('status','active');v_after:=jsonb_build_object('status','canceled','reason',i->>'reason');
  elsif op='payment_plan.cancel' then
   select * into c from public.charges where id=c.id for update;update public.charges set status=status where id=c.id;
   select id into v_id from public.payment_plans where charge_id=c.id and organization_id=v_org and ((p_replay and id=p_resource) or (not p_replay and status='active')) for update;
   if v_id is null then raise exception 'Active payment plan is not available' using errcode='PT409';end if;
   v_kind:='payment_plan';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   update public.payment_plans set status='canceled' where id=v_id;v_before:=jsonb_build_object('status','active');v_after:=jsonb_build_object('status','canceled','charge_id',c.id,'reason',i->>'reason');
  elsif op='payment_plan.create' then
   select * into c from public.charges where id=c.id for update;
   update public.charges set status=status where id=c.id;
   if jsonb_array_length(i->'installments') not between 1 and 60 then raise exception 'Invalid registration operation' using errcode='PT422';end if;
   v_total:=0;v_installment:=0;
   for x in select value from jsonb_array_elements(i->'installments') loop
    perform boss_private.registration_validate_input(x,array['amount_minor','due_on'],array['amount_minor','due_on']);
    if (x->>'amount_minor')::bigint not between 1 and 1000000000 then raise exception 'Invalid registration operation' using errcode='PT422';end if;
    if v_installment>0 and (x->>'due_on')::date<(j->>'due_on')::date then raise exception 'Installment dates must be ordered' using errcode='PT422';end if;
    v_total:=v_total+(x->>'amount_minor')::bigint;v_installment:=v_installment+1;j:=x;
   end loop;
   v_kind:='payment_plan';if p_replay then return jsonb_build_object('resource_type',v_kind,'resource_id',v_id);end if;
   if c.status<>'active' or v_total<>(boss_private.registration_charge_balance(c.id)->>'adjusted_amount_minor')::bigint then raise exception 'Installments must equal the complete adjusted obligation' using errcode='PT422';end if;
   insert into public.payment_plans(id,organization_id,registration_id,charge_id,title,created_by_person_id) values(v_id,v_org,r.id,c.id,i->>'title',p_actor);v_installment:=0;
   for x in select value from jsonb_array_elements(i->'installments') loop
    v_installment:=v_installment+1;insert into public.payment_installments(organization_id,payment_plan_id,charge_id,sequence_number,amount_minor,due_on) values(v_org,v_id,c.id,v_installment,(x->>'amount_minor')::bigint,(x->>'due_on')::date);
   end loop;v_after:=jsonb_build_object('charge_id',c.id,'installment_count',v_installment,'amount_minor',v_total);
  end if;
 end if;
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,before_data,after_data)
 values(v_org,p_actor,auth.uid(),op,v_kind,v_id,'organization',v_org,p_request,v_before,v_after||jsonb_build_object('fields',(select jsonb_agg(key order by key) from jsonb_object_keys(i) key)));
 return jsonb_build_object('resource_type',v_kind,'resource_id',v_id,'version',v_version)||coalesce(v_result,'{}'::jsonb);
end;$$;

