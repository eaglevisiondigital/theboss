create or replace function boss_private.bucks_charge_preview(actor uuid,wallet uuid,charge uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare c public.charges;w public.boss_bucks_wallets;subject uuid;due bigint;available bigint;executable boolean;begin
 select *into c from public.charges where id=charge;select *into w from public.boss_bucks_wallets where id=wallet;
 select person_id into subject from public.participants where id=c.participant_id;
 perform boss_private.bucks_fence(actor,c.organization_id,wallet);
 if c.id is null or c.status<>'active'or not boss_private.bucks_accessible(actor,wallet)or c.household_id is distinct from w.household_id or c.currency<>w.currency
 or not boss_private.bucks_feature(c.organization_id,'charge_eligibility_preview')or not boss_private.registration_feature(c.organization_id,'fees')
 or not boss_private.bucks_payment_guardian(actor,c.participant_id)or not boss_private.bucks_guardian(actor,subject,w.household_id)then raise exception'Access denied'using errcode='PT403';end if;
 due:=(boss_private.registration_charge_balance(c.id)->>'balance_due_minor')::bigint;available:=boss_private.bucks_available(w.id,c.organization_id);
 executable:=boss_private.bucks_charge_authorized(actor,w.id,c.id)and least(due,available)>0
 and(boss_private.bucks_feature(c.organization_id,'split_tender')or available>=due and not exists(select 1 from public.payment_allocations where charge_id=c.id));
 return jsonb_build_object('charge_id',c.id,'wallet_id',w.id,'title',c.title,'organization_id',c.organization_id,'organization',(select name from public.organizations where id=c.organization_id),
 'currency',c.currency,'due_minor',due,'available_minor',available,'eligible_minor',least(due,available),'remaining_minor',greatest(due-available,0),'payment_available',executable);
end$$;
create function boss_private.bucks_payment_visible(actor uuid,payment uuid,org uuid default null)returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.boss_bucks_tenders t where t.payment_id=payment and(
 org is not null and t.organization_id=org and boss_private.bucks_feature(org,'organization_wallet_reporting')and boss_private.bucks_role(actor,'boss_bucks.financial_view',org)
 or org is null and boss_private.bucks_accessible(actor,t.wallet_id)and boss_private.registration_feature(t.organization_id,'fees')
 and not exists(select 1 from public.payment_allocations a join public.charges c on c.id=a.charge_id join public.participants p on p.id=c.participant_id
 join public.boss_bucks_wallets w on w.id=t.wallet_id where a.payment_id=t.payment_id and(not boss_private.bucks_payment_guardian(actor,p.id)or not boss_private.bucks_guardian(actor,p.person_id,w.household_id)))))
$$;
create function boss_private.bucks_receipt(payment uuid)returns jsonb language sql volatile security definer set search_path=''as $$
 select coalesce((select result->'receipt'from boss_private.bucks_requests where request_id=t.request_id),jsonb_build_object('payment_id',p.id,'organization_id',p.organization_id,'organization',o.name,'method',p.method,'currency',p.currency,'amount_minor',p.amount_minor,
 'at',p.received_at,'status',p.status,'checkout_id',t.checkout_id,'charges',coalesce((select jsonb_agg(jsonb_build_object('allocation_id',a.id,'charge_id',c.id,'title',c.title,'amount_minor',a.amount_minor,
 'remaining_minor',(boss_private.registration_charge_balance(c.id)->>'balance_due_minor')::bigint)order by c.id)from public.payment_allocations a join public.charges c on c.id=a.charge_id where a.payment_id=p.id),'[]'))
 )from public.payments p join public.organizations o on o.id=p.organization_id join public.boss_bucks_tenders t on t.payment_id=p.id where p.id=payment
$$;
create function boss_private.bucks_payment_history(actor uuid,org uuid default null,wallet uuid default null,before_payment uuid default null)returns jsonb language sql volatile security definer set search_path=''as $$
 select coalesce(jsonb_agg(x.data order by x.received_at desc,x.id desc),'[]')from(
 select p.id,p.received_at,boss_private.bucks_receipt(p.id)||jsonb_build_object('reversible_minor',case when p.status='recorded'then p.amount_minor-(select coalesce(sum(amount_minor),0)from public.payments where reversal_of_id=p.id)else 0 end,
 'allocations',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'charge_id',c.id,'title',c.title,'amount_minor',a.amount_minor,'reversible_minor',case when a.status='applied'then a.amount_minor-(select coalesce(sum(amount_minor),0)from public.payment_allocations where reversal_of_id=a.id)else 0 end)
 ||case when org is not null then jsonb_build_object('sources',coalesce((select jsonb_agg(jsonb_build_object('grant_id',gr.id,'amount_minor',bc.amount_minor,'child',person.display_name,'campaign',campaign.name,'source_reference',e.source_reference)order by bc.ordinal)
 from public.boss_bucks_consumptions bc join public.boss_bucks_grants gr on gr.id=bc.grant_id join public.people person on person.id=gr.person_id
 join public.fundraising_campaigns campaign on campaign.id=gr.campaign_id join public.fundraising_success_evidence e on e.id=gr.evidence_id where bc.allocation_id=a.id),'[]'))else'{}'::jsonb end order by c.id)
 from public.payment_allocations a join public.charges c on c.id=a.charge_id where a.payment_id=p.id),'[]'))data
 from public.boss_bucks_tenders t join public.payments p on p.id=t.payment_id where(org is null or t.organization_id=org)and(wallet is null or t.wallet_id=wallet)
 and(org is not null or t.wallet_id in(select distinct a.wallet_id from public.boss_bucks_access a where a.person_id=actor and a.status='active'order by a.wallet_id limit 20))
 and boss_private.bucks_payment_visible(actor,p.id,org)
 and(before_payment is null or(p.received_at,p.id)<(select received_at,id from public.payments where id=before_payment and boss_private.bucks_payment_visible(actor,id,org)))
 order by p.received_at desc,p.id desc limit 50)x
$$;

-- Extend the established private projection in place, preserving its role,
-- relationship and pagination checks. Only household accounts are available.
do $$declare d text;start_pos integer;end_pos integer;begin
 d:=pg_get_functiondef('boss_private.bucks_available(uuid,uuid)'::regprocedure);
 d:=replace(d,'join public.organizations o','join public.boss_bucks_wallets w on w.id=g.wallet_id and w.status=''active'' join public.organizations o');execute d;
 d:=pg_get_functiondef('boss_private.bucks_read_internal(jsonb)'::regprocedure);
 d:=replace(d,'''issuance'',''reversal'',''expiration'')','''issuance'',''reversal'',''expiration'',''spend'',''payment_restore'',''recovery_open'',''recovery_apply'',''recovery_cancel'',''recovery_cancel_source'',''recovery_release'')');
 d:=replace(d,'where a.wallet_id=w.id),','where a.wallet_id=w.id and a.kind=''household''),');
 start_pos:=position('select coalesce(jsonb_agg(boss_private.bucks_charge_preview'in d);end_pos:=position('if query?''charge_id'''in d);
 if start_pos=0 or end_pos<=start_pos then raise exception'Charge projection checkpoint mismatch';end if;
 d:=substr(d,1,start_pos-1)||'charges:=''[]''::jsonb;'||substr(d,end_pos);execute d;
 d:=pg_get_functiondef('public.boss_admin_read(text,uuid,text)'::regprocedure);
 d:=replace(d,'''charge_eligibility_preview_enabled'',boss_private.bucks_admin_feature(p_organization_id,''charge_eligibility_preview''),',
 '''charge_eligibility_preview_enabled'',boss_private.bucks_admin_feature(p_organization_id,''charge_eligibility_preview''),''wallet_spending_enabled'',boss_private.bucks_admin_feature(p_organization_id,''wallet_spending''),''charge_payments_enabled'',boss_private.bucks_admin_feature(p_organization_id,''charge_payments''),''split_tender_enabled'',boss_private.bucks_admin_feature(p_organization_id,''split_tender''),');
 d:=replace(d,'Implemented: Family wallet and restricted ledger','Implemented: Family wallet, restricted ledger and charge payments');execute d;
end$$;
create or replace function boss_private.bucks_read(query jsonb default '{}')returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare base jsonb;actor uuid;org uuid;wallet uuid;charges jsonb;reports jsonb;payments jsonb;before_payment uuid;begin
 if jsonb_typeof(query)is distinct from'object'then raise exception'Invalid wallet filters'using errcode='PT422';end if;
 before_payment:=(query->>'payments_before_id')::uuid;base:=boss_private.bucks_read_internal(query-'payments_before_id');
 actor:=boss_private.current_person_id();wallet:=(query->>'wallet_id')::uuid;
 if base->>'mode'='organization'then org:=(query->>'organization_id')::uuid;
 select coalesce(jsonb_agg(r||jsonb_build_object('accepted_minor',(select coalesce(sum(case when p.status='recorded'then p.amount_minor else -p.amount_minor end),0)from public.payments p join public.boss_bucks_tenders t on t.payment_id=p.id where t.wallet_id=(r->>'wallet_id')::uuid and t.organization_id=org),
 'restored_minor',(select coalesce(sum(p.amount_minor),0)from public.payments p join public.boss_bucks_tenders t on t.payment_id=p.id where t.wallet_id=(r->>'wallet_id')::uuid and t.organization_id=org and p.status='reversed'),
 'recovery_minor',boss_private.bucks_recovery_due((r->>'wallet_id')::uuid,org),
 'reversed_minor',(select coalesce(sum(g.amount_minor-boss_private.bucks_entitlement(g.id)),0)from public.boss_bucks_grants g where g.wallet_id=(r->>'wallet_id')::uuid and g.organization_id=org),
 'expired_minor',(select coalesce(sum(coalesce(j.amount_minor,g.amount_minor)),0)from public.boss_bucks_grants g join public.boss_bucks_journals j on j.grant_id=g.id and j.kind='expiration'where g.wallet_id=(r->>'wallet_id')::uuid and g.organization_id=org))),'[]')into reports from jsonb_array_elements(base->'reports')r;
 base:=base||jsonb_build_object('reports',reports,'can_reverse_payment',boss_private.bucks_role(actor,'boss_bucks.payment_reverse',org));
 else
 if not(query?'charge_id')then
 select coalesce(jsonb_agg(boss_private.bucks_charge_preview(actor,c.wallet_id,c.id)order by c.created_at desc,c.id),'[]')into charges from(
 select c.*,w.id wallet_id from public.charges c join public.boss_bucks_wallets w on w.household_id=c.household_id and w.currency=c.currency
 where w.id in(select(value->>'id')::uuid from jsonb_array_elements(base->'wallets'))and c.status='active'
 and boss_private.bucks_feature(c.organization_id,'charge_eligibility_preview')and boss_private.registration_feature(c.organization_id,'fees')
 and boss_private.bucks_payment_guardian(actor,c.participant_id)and boss_private.bucks_guardian(actor,(select person_id from public.participants where id=c.participant_id),w.household_id)
 order by c.created_at desc,c.id limit 50)c;base:=base||jsonb_build_object('charges',charges);end if;
 base:=jsonb_set(base,'{wallets}',coalesce((select jsonb_agg(w||jsonb_build_object('recovery',coalesce((select jsonb_agg(jsonb_build_object('organization_id',g.organization_id,'organization',o.name,'amount_minor',boss_private.bucks_recovery_due((w->>'id')::uuid,g.organization_id)))from(select distinct organization_id from public.boss_bucks_grants where wallet_id=(w->>'id')::uuid)g join public.organizations o on o.id=g.organization_id where boss_private.bucks_recovery_due((w->>'id')::uuid,g.organization_id)>0),'[]')))from jsonb_array_elements(base->'wallets')w),'[]'));
 end if;
 if before_payment is not null and not boss_private.bucks_payment_visible(actor,before_payment,org)then raise exception'Access denied'using errcode='PT403';end if;
 payments:=boss_private.bucks_payment_history(actor,org,wallet,before_payment);
 return boss_private.bucks_safe_money_json(base||jsonb_build_object('payments',payments,'payment_history_limit',50,'charge_limit',50));
exception when invalid_text_representation then raise exception'Invalid payment filters'using errcode='PT422';end$$;
create or replace function boss_private.bucks_activity(wallet uuid,org uuid default null,subject uuid default null,campaign uuid default null,kind text default null,before_id uuid default null)returns jsonb language sql volatile security definer set search_path=''as $$
 with entries as materialized(
 select j.id,j.created_at,j.kind,j.amount_minor,g.id grant_id,g.account_id,g.currency,g.organization_id,g.person_id,g.campaign_id,g.team_id,g.evidence_id,g.fundraiser_id,g.available_at,g.expires_at
 from public.boss_bucks_grants g join public.boss_bucks_journals j on j.grant_id=g.id
 where g.wallet_id=wallet and(org is null or g.organization_id=org)and(subject is null or g.person_id=subject)and(campaign is null or g.campaign_id=campaign)and(kind is null or j.kind=kind)
 and(before_id is null or(j.created_at,j.id)<(select created_at,id from public.boss_bucks_journals where id=before_id and grant_id in(select id from public.boss_bucks_grants where wallet_id=wallet)))
 order by j.created_at desc,j.id desc limit 50),
 source_rows as materialized(
 select s.journal_id,a.payment_id,c.id charge_id,c.title from(
 select bc.journal_id,bc.allocation_id from public.boss_bucks_consumptions bc where bc.journal_id in(select id from entries)
 union all select br.journal_id,br.allocation_id from public.boss_bucks_restorations br where br.journal_id in(select id from entries))s
 join public.payment_allocations a on a.id=s.allocation_id join public.charges c on c.id=a.charge_id),
 visible_payments as materialized(select payment_id from(select distinct payment_id from source_rows)unique_payments
 where boss_private.bucks_payment_visible(boss_private.current_person_id(),payment_id,org)),
 charge_context as materialized(select sr.*from source_rows sr join visible_payments vp on vp.payment_id=sr.payment_id),
 titles as(select journal_id,min(payment_id::text)payment_id,case when count(distinct charge_id)=1 then min(title)else count(distinct charge_id)::text||' organization charges'end title from charge_context group by journal_id)
 select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'at',e.created_at,'kind',e.kind,'amount_minor',coalesce(posting.amount_minor,case when e.kind='recovery_open'then -e.amount_minor else e.amount_minor end),
 'currency',e.currency,'organization_id',e.organization_id,'organization',o.name,'child_id',e.person_id,'child',person.display_name,'campaign_id',e.campaign_id,'campaign',c.name,'team',t.name,
 'state',boss_private.bucks_grant_state(g),'available_at',e.available_at,'expires_at',e.expires_at)
 ||case when titles.journal_id is not null then jsonb_build_object('charge_title',titles.title,'payment_id',titles.payment_id)else'{}'::jsonb end
 ||case when org is not null then jsonb_build_object('source_reference',(select source_reference from public.fundraising_success_evidence where id=e.evidence_id),'fundraiser',(select public_display_name from public.fundraising_fundraisers where id=e.fundraiser_id))else'{}'::jsonb end
 order by e.created_at desc,e.id desc),'[]')from entries e join public.boss_bucks_grants g on g.id=e.grant_id
 join public.organizations o on o.id=e.organization_id join public.people person on person.id=e.person_id join public.fundraising_campaigns c on c.id=e.campaign_id
 left join public.teams t on t.id=e.team_id left join public.boss_bucks_postings posting on posting.journal_id=e.id and posting.account_id=e.account_id left join titles on titles.journal_id=e.id
$$;
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'bucks_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',p.signature);end loop;end$$;
grant execute on function boss_private.bucks_read(jsonb),boss_private.bucks_mutate(jsonb),boss_private.bucks_admin_feature(uuid,text)to authenticated;
