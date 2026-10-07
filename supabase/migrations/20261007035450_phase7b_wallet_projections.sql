create function boss_private.bucks_grant_state(g public.boss_bucks_grants)returns text language sql volatile security definer set search_path=''as $$
 select case when exists(select 1 from public.boss_bucks_journals where grant_id=g.id and kind='reversal')then'reversed'
 when g.expires_at<=clock_timestamp()or exists(select 1 from public.boss_bucks_journals where grant_id=g.id and kind='expiration')then'expired'
 when g.available_at>clock_timestamp()then'held'else'available'end
$$;
create function boss_private.bucks_campaign_earning(campaign uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select coalesce((select p.mode='percentage'and p.basis_points>0 and boss_private.bucks_feature(p.organization_id,'fundraising_issuance')from public.boss_bucks_policy_revisions p where p.campaign_id=campaign order by revision desc limit 1),false)
$$;
create function boss_private.bucks_available(wallet uuid,org uuid default null)returns bigint language sql volatile security definer set search_path=''as $$
 select coalesce(sum(p.amount_minor),0)::bigint from public.boss_bucks_grants g join public.boss_bucks_journals j on j.grant_id=g.id
 join public.boss_bucks_postings p on p.journal_id=j.id and p.account_id=g.account_id
 join public.organizations o on o.id=g.organization_id and o.status='active'
 where g.wallet_id=wallet and(org is null or g.organization_id=org)and g.available_at<=clock_timestamp()and(g.expires_at is null or g.expires_at>clock_timestamp())
$$;
create function boss_private.bucks_rebuild(wallet uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$declare result jsonb;begin
 perform 1 from public.boss_bucks_wallets where id=wallet for share;
 select coalesce(jsonb_agg(jsonb_build_object('organization_id',a.organization_id,'currency',a.currency,'posted_minor',(select coalesce(sum(p.amount_minor),0)from public.boss_bucks_postings p where p.account_id=a.id),'available_minor',boss_private.bucks_available(wallet,a.organization_id))order by a.organization_id),'[]')into result from public.boss_bucks_accounts a where a.wallet_id=wallet;
 perform boss_private.bucks_audit(null,'boss_bucks.rebuild',null,wallet);return result;
end$$;

-- Phase 4A transport, deduplication and preferences remain authoritative.
alter table public.notification_events drop constraint notification_events_source_module_check;
alter table public.notification_events add constraint notification_events_source_module_check check(source_module in('calendar','registration','messaging','volunteers','sports','fundraising','boss_bucks'));
alter table public.notification_events drop constraint notification_events_source_type_check;
alter table public.notification_events add constraint notification_events_source_type_check check(source_type in('event','registration','registration_document','charge','payment','message','attendance_request','volunteer_shift','volunteer_assignment','volunteer_event','game_operation','tournament_advancement','achievement_history','fundraising_history','boss_bucks_history'));
insert into boss_private.notification_types(key,category,source_module,title,body)values
 ('boss_bucks.earned','fees','boss_bucks','Boss Bucks earned','Verified fundraising earnings are available in your family wallet.'),
 ('boss_bucks.reversed','fees','boss_bucks','Boss Bucks source reversed','A source adjustment is recorded in your family wallet.'),
 ('boss_bucks.expired','fees','boss_bucks','Boss Bucks expired','An explicit earning-policy expiration is recorded in your family wallet.');
create function boss_private.bucks_notification_visible(e public.notification_events,actor uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select e.source_type='boss_bucks_history'and e.source_module='boss_bucks'and boss_private.notification_person_active(actor)and exists(
 select 1 from public.boss_bucks_history h join public.boss_bucks_access a on a.wallet_id=h.wallet_id and a.person_id=actor
 join public.guardian_relationships g on g.id=a.guardian_relationship_id and g.can_receive_communications
 where h.id=e.source_id and h.organization_id=e.organization_id and boss_private.bucks_accessible(actor,h.wallet_id))
$$;
alter function boss_private.notification_source_visible(public.notification_events,uuid)rename to notification_source_visible_phase7a;
create function boss_private.notification_source_visible(p_event public.notification_events,p_person uuid)returns boolean language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type='boss_bucks_history'then return boss_private.bucks_notification_visible(p_event,p_person);end if;return boss_private.notification_source_visible_phase7a(p_event,p_person);end$$;
alter function boss_private.notification_candidates(public.notification_events,uuid,integer)rename to notification_candidates_phase7a;
create function boss_private.notification_candidates(p_event public.notification_events,p_after uuid,p_limit integer)returns table(person_id uuid)language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type<>'boss_bucks_history'then return query select *from boss_private.notification_candidates_phase7a(p_event,p_after,p_limit);return;end if;
 return query select distinct a.person_id from public.boss_bucks_history h join public.boss_bucks_access a on a.wallet_id=h.wallet_id
 where h.id=p_event.source_id and(p_after is null or a.person_id>p_after)and boss_private.bucks_notification_visible(p_event,a.person_id)order by a.person_id limit p_limit;
end$$;
alter function boss_private.notification_contexts(public.notification_events,uuid)rename to notification_contexts_phase7a;
create function boss_private.notification_contexts(p_event public.notification_events,p_person uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type='boss_bucks_history'then return jsonb_build_array(jsonb_build_object('kind','boss_bucks','source_id',p_event.source_id));end if;return boss_private.notification_contexts_phase7a(p_event,p_person);end$$;
alter function boss_private.notification_destination(public.notification_events)rename to notification_destination_phase7a;
create function boss_private.notification_destination(p_event public.notification_events)returns text language plpgsql stable security definer set search_path=''as $$begin
 if p_event.source_type='boss_bucks_history'then return'/app/boss-bucks';end if;return boss_private.notification_destination_phase7a(p_event);end$$;
create function boss_private.bucks_notification_ingest()returns trigger language plpgsql volatile security definer set search_path=''as $$declare k text;begin
 k:=case new.action when'boss_bucks.issuance'then'boss_bucks.earned'when'boss_bucks.reversal'then'boss_bucks.reversed'when'boss_bucks.expiration'then'boss_bucks.expired'end;
 if k is not null then perform boss_private.notification_enqueue('boss_bucks','boss_bucks_history',new.id,new.organization_id,k,'1','{}');end if;return new;
end$$;
create trigger boss_bucks_notification_source after insert on public.boss_bucks_history for each row execute function boss_private.bucks_notification_ingest();
revoke all on function boss_private.bucks_notification_visible(public.notification_events,uuid),boss_private.notification_source_visible_phase7a(public.notification_events,uuid),boss_private.notification_source_visible(public.notification_events,uuid),boss_private.notification_candidates_phase7a(public.notification_events,uuid,integer),boss_private.notification_candidates(public.notification_events,uuid,integer),boss_private.notification_contexts_phase7a(public.notification_events,uuid),boss_private.notification_contexts(public.notification_events,uuid),boss_private.notification_destination_phase7a(public.notification_events),boss_private.notification_destination(public.notification_events),boss_private.bucks_notification_ingest()from public,anon,authenticated,service_role;
create function boss_private.bucks_charge_preview(actor uuid,wallet uuid,charge uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare c public.charges;w public.boss_bucks_wallets;subject uuid;due bigint;available bigint;begin
 select *into c from public.charges where id=charge;select *into w from public.boss_bucks_wallets where id=wallet;
 select person_id into subject from public.participants where id=c.participant_id;
 perform boss_private.bucks_fence(actor,c.organization_id,wallet);
 if c.id is null or c.status<>'active'or not boss_private.bucks_accessible(actor,wallet)or c.household_id is distinct from w.household_id or c.currency<>w.currency
 or not boss_private.bucks_feature(c.organization_id,'charge_eligibility_preview')or not boss_private.registration_feature(c.organization_id,'fees')
 or not boss_private.registration_guardian(c.participant_id,'can_manage_payments')or not boss_private.bucks_guardian(actor,subject,w.household_id)then raise exception'Access denied'using errcode='PT403';end if;
 due:=(boss_private.registration_charge_balance(c.id)->>'balance_due_minor')::bigint;available:=boss_private.bucks_available(w.id,c.organization_id);
 return jsonb_build_object('charge_id',c.id,'title',c.title,'organization_id',c.organization_id,'organization',(select name from public.organizations where id=c.organization_id),
 'currency',c.currency,'due_minor',due,'available_minor',available,'eligible_minor',least(due,available),'remaining_minor',greatest(due-available,0),'payment_available',false);
end$$;
create function boss_private.bucks_activity(wallet uuid,org uuid default null,subject uuid default null,campaign uuid default null,kind text default null,before_id uuid default null)returns jsonb language sql volatile security definer set search_path=''as $$
 select coalesce(jsonb_agg(row.data order by row.created_at desc,row.id desc),'[]')from(
 select j.id,j.created_at,jsonb_build_object('id',j.id,'at',j.created_at,'kind',j.kind,'amount_minor',p.amount_minor,'currency',g.currency,'organization_id',g.organization_id,'organization',o.name,
 'child_id',g.person_id,'child',person.display_name,'campaign_id',g.campaign_id,'campaign',c.name,'team',t.name,'state',boss_private.bucks_grant_state(g),'available_at',g.available_at,'expires_at',g.expires_at)||case when org is not null then jsonb_build_object('source_reference',(select source_reference from public.fundraising_success_evidence where id=g.evidence_id),'fundraiser',(select public_display_name from public.fundraising_fundraisers where id=g.fundraiser_id))else '{}'::jsonb end data
 from public.boss_bucks_grants g join public.boss_bucks_journals j on j.grant_id=g.id join public.boss_bucks_postings p on p.journal_id=j.id and p.account_id=g.account_id
 join public.organizations o on o.id=g.organization_id join public.people person on person.id=g.person_id join public.fundraising_campaigns c on c.id=g.campaign_id left join public.teams t on t.id=g.team_id
 where g.wallet_id=wallet and(org is null or g.organization_id=org)and(subject is null or g.person_id=subject)and(campaign is null or g.campaign_id=campaign)and(kind is null or j.kind=kind)
 and(before_id is null or(j.created_at,j.id)<(select created_at,id from public.boss_bucks_journals where id=before_id and grant_id in(select id from public.boss_bucks_grants where wallet_id=wallet)))
 order by j.created_at desc,j.id desc limit 50)row
$$;
create function boss_private.bucks_read(query jsonb default '{}')returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;mode text;org uuid;wallet uuid;subject uuid;campaign uuid;kind text;before_id uuid;result jsonb;wallets jsonb;choices jsonb;reports jsonb;policies jsonb;charges jsonb;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();if actor is null then raise exception'Access denied'using errcode='PT403';end if;
 if jsonb_typeof(query)<>'object'or exists(select 1 from jsonb_object_keys(query)k where k<>all(array['mode','organization_id','wallet_id','child_id','campaign_id','kind','before_id','charge_id','report_after_id']))then raise exception'Invalid wallet filters'using errcode='PT422';end if;
 mode:=coalesce(query->>'mode','family');org:=(query->>'organization_id')::uuid;wallet:=(query->>'wallet_id')::uuid;subject:=(query->>'child_id')::uuid;campaign:=(query->>'campaign_id')::uuid;kind:=query->>'kind';before_id:=(query->>'before_id')::uuid;
 if mode not in('family','organization')or kind is not null and kind not in('issuance','reversal','expiration')then raise exception'Invalid wallet view'using errcode='PT422';end if;
 if mode='organization'then
 perform boss_private.bucks_fence(actor,org);
 if org is null or not boss_private.bucks_feature(org,'organization_wallet_reporting')or not boss_private.bucks_role(actor,'boss_bucks.financial_view',org)then raise exception'Access denied'using errcode='PT403';end if;
 select coalesce(jsonb_agg(jsonb_build_object('wallet_id',w.id,'household',h.name,'currency',w.currency,'issued_minor',(select coalesce(sum(amount_minor),0)from public.boss_bucks_grants where wallet_id=w.id and organization_id=org),
 'available_minor',boss_private.bucks_available(w.id,org),'reversed_minor',(select coalesce(sum(g.amount_minor),0)from public.boss_bucks_grants g join public.boss_bucks_journals j on j.grant_id=g.id and j.kind='reversal'where g.wallet_id=w.id and g.organization_id=org),
 'expired_minor',(select coalesce(sum(g.amount_minor),0)from public.boss_bucks_grants g where g.wallet_id=w.id and g.organization_id=org and boss_private.bucks_grant_state(g)='expired'))),'[]')into reports
 from(select distinct w.*from public.boss_bucks_accounts a join public.boss_bucks_wallets w on w.id=a.wallet_id where a.organization_id=org and(query->>'report_after_id' is null or w.id>(query->>'report_after_id')::uuid)order by w.id limit 100)w join public.households h on h.id=w.household_id;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'campaign_id',p.campaign_id,'campaign',c.name,'revision',p.revision,'mode',p.mode,'basis_points',p.basis_points,'currency',p.currency,'channels',p.channels,'availability_seconds',p.availability_seconds,'expiry_seconds',p.expiry_seconds,'at',p.created_at)),'[]')into policies
 from(select *from public.boss_bucks_policy_revisions where organization_id=org order by created_at desc,id desc limit 100)p join public.fundraising_campaigns c on c.id=p.campaign_id;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'currency',currency)),'[]')into choices from(select id,name,currency from public.fundraising_campaigns where organization_id=org and status<>'archived'order by created_at desc,id desc limit 100)c;
 if wallet is not null and not exists(select 1 from public.boss_bucks_accounts where wallet_id=wallet and organization_id=org)then raise exception'Access denied'using errcode='PT403';end if;
 perform boss_private.bucks_audit(actor,'boss_bucks.report.read',org,null);
 return jsonb_build_object('mode',mode,'reports',reports,'policies',policies,'campaigns',choices,'report_limit',100,'can_manage_policy',boss_private.bucks_role(actor,'boss_bucks.policy_manage',org),
 'activity',case when wallet is not null then boss_private.bucks_activity(wallet,org,subject,campaign,kind,before_id)else'[]'::jsonb end);
 end if;
 if wallet is not null then perform boss_private.bucks_fence(actor,null,wallet);if not boss_private.bucks_accessible(actor,wallet)then raise exception'Access denied'using errcode='PT403';end if;end if;
 -- Lock/re-evaluate each selected access before producing the family projection.
 for result in select to_jsonb(w)from public.boss_bucks_wallets w where(wallet is null or w.id=wallet)and w.id in(select wallet_id from public.boss_bucks_access where person_id=actor and status='active')order by w.id limit 20 loop
 perform boss_private.bucks_fence(actor,null,(result->>'id')::uuid);end loop;
 select coalesce(jsonb_agg(jsonb_build_object('id',w.id,'household',h.name,'currency',w.currency,'available_minor',boss_private.bucks_available(w.id),
 'organizations',coalesce((select jsonb_agg(jsonb_build_object('id',a.organization_id,'name',o.name,'status',o.status,'available_minor',boss_private.bucks_available(w.id,a.organization_id)))from public.boss_bucks_accounts a join public.organizations o on o.id=a.organization_id where a.wallet_id=w.id),'[]'),
 'children',coalesce((select jsonb_agg(jsonb_build_object('id',x.person_id,'name',p.display_name,'organization_id',x.organization_id,'organization',o.name,'earned_minor',x.earned))from(select person_id,organization_id,sum(amount_minor)::bigint earned from public.boss_bucks_grants where wallet_id=w.id group by person_id,organization_id order by person_id,organization_id limit 100)x join public.people p on p.id=x.person_id join public.organizations o on o.id=x.organization_id),'[]'),
 'campaigns',coalesce((select jsonb_agg(jsonb_build_object('id',x.campaign_id,'name',c.name,'earned_minor',x.earned))from(select campaign_id,sum(amount_minor)::bigint earned from public.boss_bucks_grants where wallet_id=w.id group by campaign_id order by campaign_id limit 100)x join public.fundraising_campaigns c on c.id=x.campaign_id),'[]'),
 'activity',boss_private.bucks_activity(w.id,org,subject,campaign,kind,before_id))), '[]')into wallets
 from(select *from public.boss_bucks_wallets w where(wallet is null or w.id=wallet)and w.id in(select wallet_id from public.boss_bucks_access where person_id=actor and status='active')and boss_private.bucks_accessible(actor,w.id)order by w.id limit 20)w join public.households h on h.id=w.household_id;
 select coalesce(jsonb_agg(jsonb_build_object('household_id',h.id,'household',h.name,'child_id',g.dependent_person_id,'child',p.display_name,'organization_id',o.id,'organization',o.name)),'[]')into choices
 from(select distinct h.id,h.name,g.dependent_person_id,m.organization_id from public.guardian_relationships g join public.household_memberships hm on hm.person_id=g.dependent_person_id
 join public.households h on h.id=hm.household_id join public.organization_memberships m on m.person_id=g.dependent_person_id where g.guardian_person_id=actor
 and boss_private.bucks_guardian(actor,g.dependent_person_id,h.id)and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())
 and boss_private.bucks_feature(m.organization_id,'family_wallet')order by h.id,g.dependent_person_id,m.organization_id limit 50)g
 join public.households h on h.id=g.id join public.people p on p.id=g.dependent_person_id join public.organizations o on o.id=g.organization_id;
 select coalesce(jsonb_agg(boss_private.bucks_charge_preview(actor,w.id,c.id)),'[]')into charges from public.charges c join public.boss_bucks_wallets w on w.household_id=c.household_id and w.currency=c.currency
 where(wallet is null or w.id=wallet)and w.id in(select wallet_id from public.boss_bucks_access where person_id=actor and status='active'order by wallet_id limit 20)and boss_private.bucks_accessible(actor,w.id)and c.status='active'and boss_private.registration_guardian(c.participant_id,'can_manage_payments')
 and boss_private.bucks_feature(c.organization_id,'charge_eligibility_preview')and boss_private.registration_feature(c.organization_id,'fees')
 and c.id in(select id from public.charges where household_id=w.household_id and status='active'order by created_at desc,id desc limit 20);
 if query?'charge_id'then if wallet is null then raise exception'Wallet required'using errcode='PT422';end if;charges:=jsonb_build_array(boss_private.bucks_charge_preview(actor,wallet,(query->>'charge_id')::uuid));end if;
 return jsonb_build_object('mode','family','wallets',wallets,'provision_choices',choices,'charges',charges,'payment_available',false,
 'fundraisers',coalesce((select jsonb_agg(data)from(select jsonb_build_object('id',f.id,'name',p.display_name,'campaign',c.name,'household_id',x->>'household_id','household',x->>'household','bound',f.household_id=(x->>'household_id')::uuid,'may_earn',boss_private.bucks_campaign_earning(c.id)) data
 from jsonb_array_elements(choices)x join public.fundraising_fundraisers f on f.person_id=(x->>'child_id')::uuid and f.organization_id=(x->>'organization_id')::uuid
 join public.fundraising_campaigns c on c.id=f.campaign_id join public.people p on p.id=f.person_id
 where boss_private.fundraising_related(actor,f)and boss_private.fundraising_module(c.organization_id,'fundraising')and c.status<>'archived'order by f.id,x->>'household_id'limit 100)bounded),'[]'));
exception when invalid_text_representation then raise exception'Invalid wallet filters'using errcode='PT422';end$$;
create function public.boss_bucks_read(query jsonb default '{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.bucks_read(query)$$;
revoke all on function public.boss_bucks_read(jsonb)from public,anon,authenticated,service_role;
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'bucks_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role',p.signature);end loop;end$$;
grant execute on function public.boss_bucks_read(jsonb),boss_private.bucks_read(jsonb),public.boss_bucks_mutate(jsonb),boss_private.bucks_mutate(jsonb)to authenticated;

-- Minor-unit totals may exceed JavaScript's exact-number range. The API contract
-- uses decimal strings throughout, without changing integer ledger arithmetic.
create function boss_private.bucks_safe_money_json(value jsonb)returns jsonb language plpgsql immutable set search_path=''as $$declare result jsonb;begin
 if jsonb_typeof(value)='object'then
 select coalesce(jsonb_object_agg(k,case when k like'%\_minor'escape'\'and jsonb_typeof(v)='number'then to_jsonb(v::text)else boss_private.bucks_safe_money_json(v)end),'{}')into result from jsonb_each(value)e(k,v);return result;
 elsif jsonb_typeof(value)='array'then select coalesce(jsonb_agg(boss_private.bucks_safe_money_json(v)order by n),'[]')into result from jsonb_array_elements(value)with ordinality e(v,n);return result;
 else return value;end if;end$$;
alter function boss_private.bucks_read(jsonb)rename to bucks_read_internal;
create function boss_private.bucks_read(query jsonb default '{}')returns jsonb language sql volatile security definer set search_path=''as $$select boss_private.bucks_safe_money_json(boss_private.bucks_read_internal(query))$$;
revoke all on function boss_private.bucks_read_internal(jsonb),boss_private.bucks_safe_money_json(jsonb),boss_private.bucks_read(jsonb)from public,anon,authenticated,service_role;
grant execute on function boss_private.bucks_read(jsonb)to authenticated;

-- Existing admin command and projection machinery retains its own permission checks.
create function boss_private.bucks_admin_feature(org uuid,feature text)returns boolean language plpgsql volatile security definer set search_path=''as $$begin
 perform boss_private.games_require_live_auth();return boss_private.bucks_role(boss_private.current_person_id(),'boss_bucks.view',org)and boss_private.bucks_feature(org,feature);
end$$;
revoke all on function boss_private.bucks_admin_feature(uuid,text)from public,anon,authenticated,service_role;
grant execute on function boss_private.bucks_admin_feature(uuid,text)to authenticated;
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.admin_mutate_command(text,jsonb,uuid,uuid,boolean,uuid)'::regprocedure);
 if position('can_manage_fundraising=case'in d)=0 then raise exception'Unexpected guardian checkpoint';end if;
 d:=replace(d,'''can_manage_fundraising'']','''can_manage_fundraising'',''can_manage_boss_bucks'']');
 d:=replace(d,'can_respond_attendance,can_manage_fundraising)','can_respond_attendance,can_manage_fundraising,can_manage_boss_bucks)');
 d:=replace(d,'coalesce((i->>''can_manage_fundraising'')::boolean,false));','coalesce((i->>''can_manage_fundraising'')::boolean,false),coalesce((i->>''can_manage_boss_bucks'')::boolean,false));');
 d:=replace(d,'else r.can_manage_fundraising end where id=v_id','else r.can_manage_fundraising end,can_manage_boss_bucks=case when i?''can_manage_boss_bucks''then(i->>''can_manage_boss_bucks'')::boolean else r.can_manage_boss_bucks end where id=v_id');
 if position('can_manage_boss_bucks=case'in d)=0 then raise exception'Guardian extension failed';end if;execute d;
 d:=pg_get_functiondef('public.boss_admin_read(text,uuid,text)'::regprocedure);
 d:=replace(d,'''activation_status'',case when', '''wallet_enabled'',boss_private.bucks_admin_feature(p_organization_id,''wallet''),''fundraising_issuance_enabled'',boss_private.bucks_admin_feature(p_organization_id,''fundraising_issuance''),''family_wallet_enabled'',boss_private.bucks_admin_feature(p_organization_id,''family_wallet''),''organization_wallet_reporting_enabled'',boss_private.bucks_admin_feature(p_organization_id,''organization_wallet_reporting''),''charge_eligibility_preview_enabled'',boss_private.bucks_admin_feature(p_organization_id,''charge_eligibility_preview''),''activation_status'',case when');
 d:=replace(d,'''can_manage_fundraising'',g.can_manage_fundraising','''can_manage_fundraising'',g.can_manage_fundraising,''can_manage_boss_bucks'',g.can_manage_boss_bucks');
 d:=replace(d,'else ''Future / not implemented'' end','when m.key=''boss_bucks''then''Implemented: Family wallet and restricted ledger''else ''Future / not implemented'' end');execute d;
end$$;

-- A finite public earning-policy indicator exposes no wallet identity or value.
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.fundraising_public_read(text,integer)'::regprocedure);
 d:=replace(d,'''reward_policy'',c.reward_policy)', '''reward_policy'',c.reward_policy,''may_earn_boss_bucks'',boss_private.bucks_campaign_earning(c.id))');
 if position('may_earn_boss_bucks'in d)=0 then raise exception'Fundraising public checkpoint mismatch';end if;execute d;
 d:=pg_get_functiondef('boss_private.fundraising_read(jsonb)'::regprocedure);
 d:=replace(d,'''public_path'',case when c.public_visible', '''may_earn_boss_bucks'',boss_private.bucks_campaign_earning(c.id),''public_path'',case when c.public_visible');
 if position('may_earn_boss_bucks'in d)=0 then raise exception'Fundraising private checkpoint mismatch';end if;execute d;
end$$;
