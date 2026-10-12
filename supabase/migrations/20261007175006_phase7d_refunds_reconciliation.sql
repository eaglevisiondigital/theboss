-- Explicit original-tender corrections. No network-wide atomicity is claimed;
-- external dispatch and internal restoration retain separate audited outcomes.
create table public.payment_refund_requests(
 id uuid primary key default gen_random_uuid(),payment_id uuid not null references public.external_payment_tenders(payment_id),
 organization_id uuid not null references public.organizations(id),actor_id uuid not null references public.people(id),
 request_id uuid not null unique,command jsonb not null,operation_id uuid not null unique references public.provider_operations(id),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000),principal_minor bigint not null check(principal_minor between 0 and amount_minor),
 created_at timestamptz not null default clock_timestamp());
create index payment_refund_requests_payment_idx on public.payment_refund_requests(payment_id);
create index payment_refund_requests_org_idx on public.payment_refund_requests(organization_id,created_at,id);
create index payment_refund_requests_actor_idx on public.payment_refund_requests(actor_id);
create table public.external_payment_corrections(
 reversal_payment_id uuid primary key references public.payments(id),original_payment_id uuid not null references public.external_payment_tenders(payment_id),
 event_id uuid not null unique references public.provider_event_evidence(id),refund_request_id uuid references public.payment_refund_requests(id),
 kind text not null check(kind in('refund','void','chargeback','ach_return')),principal_minor bigint not null check(principal_minor between 0 and 1000000000),
 created_at timestamptz not null default clock_timestamp());
create index external_payment_corrections_original_idx on public.external_payment_corrections(original_payment_id);
create index external_payment_corrections_request_idx on public.external_payment_corrections(refund_request_id);
create table public.payment_dispute_cases(
 id uuid primary key default gen_random_uuid(),payment_id uuid not null references public.external_payment_tenders(payment_id),
 event_id uuid not null unique references public.provider_event_evidence(id),case_reference text not null check(length(case_reference)between 1 and 200),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000),category text not null check(category in('chargeback','ach_return','provider_reversal')),
 created_at timestamptz not null default clock_timestamp());
create index payment_dispute_cases_payment_idx on public.payment_dispute_cases(payment_id);
create table public.settlement_deficits(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),currency text not null,
 correction_payment_id uuid not null unique references public.payments(id),amount_minor bigint not null check(amount_minor between 1 and 1000000000),
 created_at timestamptz not null default clock_timestamp());
create index settlement_deficits_org_idx on public.settlement_deficits(organization_id,currency,created_at,id);
create table public.settlement_deficit_offsets(
 id uuid primary key default gen_random_uuid(),deficit_id uuid not null references public.settlement_deficits(id),payment_id uuid not null references public.settlement_sources(payment_id),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000),created_at timestamptz not null default clock_timestamp(),unique(deficit_id,payment_id));
create index settlement_deficit_offsets_payment_idx on public.settlement_deficit_offsets(payment_id);
create table public.payment_reconciliation_runs(
 id uuid primary key default gen_random_uuid(),account_id uuid not null references public.processing_accounts(id),request_id uuid not null unique,
 from_at timestamptz not null,to_at timestamptz not null,command_digest text not null check(command_digest~'^[a-f0-9]{64}$'),created_at timestamptz not null default clock_timestamp(),
 check(isfinite(from_at)and isfinite(to_at)and to_at>from_at and to_at<=from_at+interval'31 days'));
create index payment_reconciliation_runs_account_idx on public.payment_reconciliation_runs(account_id,created_at,id);
create table public.payment_reconciliation_items(
 id uuid primary key default gen_random_uuid(),run_id uuid not null references public.payment_reconciliation_runs(id),
 operation_id uuid references public.provider_operations(id),event_id uuid references public.provider_event_evidence(id),
 provider_reference text not null check(length(provider_reference)between 1 and 200),
 state text not null check(state in('matched','pending','mismatch','missing_provider','missing_boss','amount_mismatch','fee_mismatch','settlement_mismatch')),
 created_at timestamptz not null default clock_timestamp(),unique(run_id,provider_reference));
create index payment_reconciliation_items_operation_idx on public.payment_reconciliation_items(operation_id);
create index payment_reconciliation_items_event_idx on public.payment_reconciliation_items(event_id);

create function boss_private.rails_refund_prepare(actor uuid,command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare i jsonb:=command->'input';request uuid:=(command->>'request_id')::uuid;p public.payments;t public.external_payment_tenders;
 c public.payment_checkouts;existing public.payment_refund_requests;operation uuid;amount bigint;principal bigint;total bigint:=0;leg jsonb;pa public.payment_allocations;begin
 perform boss_private.athlete_input(i,array['payment_id','amount_minor','principal_minor','allocations','reason'],array['payment_id','amount_minor','principal_minor','allocations','reason']);
 p.id:=(i->>'payment_id')::uuid;select *into p from public.payments where id=p.id;select *into t from public.external_payment_tenders where payment_id=p.id;
 if p.id is null or t.payment_id is null or t.original_payment_id is not null or not boss_private.rails_role(actor,'payments.refund',p.organization_id)
 or not boss_private.rails_actor_current(actor)or not boss_private.rails_feature(p.organization_id,'refunds')then raise exception'Access denied'using errcode='PT403';end if;
 c:=boss_private.rails_checkout_fence(t.checkout_id);
 if not boss_private.rails_actor_current(actor)or not boss_private.rails_role(actor,'payments.refund',p.organization_id)or not boss_private.rails_feature(p.organization_id,'refunds')then raise exception'Access denied'using errcode='PT403';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-payment-refund:'||p.id,0));
 select *into existing from public.payment_refund_requests where request_id=request;
 if existing.id is not null then if existing.actor_id<>actor or existing.command<>command then raise exception'Refund replay conflict'using errcode='PT409';end if;return jsonb_build_object('refund_id',existing.id,'operation_id',existing.operation_id,'replayed',true);end if;
 amount:=boss_private.rails_amount(i,'amount_minor');principal:=boss_private.rails_amount(i,'principal_minor',true);
 if c.purpose='fundraising'and principal>c.principal_minor-(select coalesce(sum(ec.principal_minor),0)from public.external_payment_corrections ec where original_payment_id=p.id)-(select coalesce(sum(rr.principal_minor),0)from public.payment_refund_requests rr join public.provider_operations po on po.id=rr.operation_id where rr.payment_id=p.id and po.state in('prepared','dispatched','unknown','authorized','ach_pending'))then raise exception'Principal is already reserved for refund'using errcode='PT409';end if;
 if principal>amount or jsonb_typeof(i->'allocations')is distinct from'array'or jsonb_array_length(i->'allocations')>50 or length(btrim(i->>'reason'))not between 1 and 200
 or not exists(select 1 from public.processing_accounts where id=c.account_id and status='active'and capabilities@>array['refund','partial_refund'])then raise exception'Refund capability or input unavailable'using errcode='PT422';end if;
 if amount>p.amount_minor-(select coalesce(sum(amount_minor),0)from public.payments where reversal_of_id=p.id)
 -(select coalesce(sum(r.amount_minor),0)from public.payment_refund_requests r join public.provider_operations op on op.id=r.operation_id where r.payment_id=p.id and op.state in('prepared','dispatched','unknown','authorized','ach_pending'))then raise exception'Refund exceeds unreserved remainder'using errcode='PT409';end if;
 for leg in select value from jsonb_array_elements(i->'allocations')loop
 perform boss_private.athlete_input(leg,array['allocation_id','amount_minor'],array['allocation_id','amount_minor']);
 select *into pa from public.payment_allocations where id=(leg->>'allocation_id')::uuid and payment_id=p.id and status='applied';
 if pa.id is null or boss_private.rails_amount(leg,'amount_minor')>pa.amount_minor-(select coalesce(sum(amount_minor),0)from public.payment_allocations where reversal_of_id=pa.id)-(select coalesce(sum((reserved.value->>'amount_minor')::bigint),0)from public.payment_refund_requests rr join public.provider_operations po on po.id=rr.operation_id cross join lateral jsonb_array_elements(rr.command->'input'->'allocations')reserved where rr.payment_id=p.id and po.state in('prepared','dispatched','unknown','authorized','ach_pending')and(reserved.value->>'allocation_id')::uuid=pa.id)then raise exception'Original allocation remainder required'using errcode='PT409';end if;
 total:=total+(leg->>'amount_minor')::bigint;end loop;
 if c.purpose='fees'and(total<>principal or principal<>amount or(select count(distinct(value->>'allocation_id')::uuid)from jsonb_array_elements(i->'allocations'))<>jsonb_array_length(i->'allocations'))
 or c.purpose='fundraising'and(total<>0 or principal>c.principal_minor-(select coalesce(sum(ec.principal_minor),0)from public.external_payment_corrections ec where original_payment_id=p.id))then raise exception'Explicit original tender/principal allocation required'using errcode='PT422';end if;
 insert into public.provider_operations(organization_id,checkout_id,account_id,kind,parent_operation_id,request_id,provider_request_reference,amount_minor,currency)
 values(p.organization_id,c.id,c.account_id,'refund',t.operation_id,request,substr(replace(request::text,'-',''),1,20),amount,p.currency)returning id into operation;
 insert into public.payment_refund_requests(payment_id,organization_id,actor_id,request_id,command,operation_id,amount_minor,principal_minor)
 values(p.id,p.organization_id,actor,request,command,operation,amount,principal)returning *into existing;
 perform boss_private.rails_audit(actor,p.organization_id,'payment.refund.prepared',p.id,request,jsonb_build_object('refund_id',existing.id,'operation_id',operation,'amount_minor',amount,'principal_minor',principal));
 return jsonb_build_object('refund_id',existing.id,'operation_id',operation,'replayed',false);
end$$;

create function boss_private.rails_external_correct(payment uuid,event uuid,p_kind text,principal bigint,allocations jsonb default '[]',refund uuid default null)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare p public.payments;t public.external_payment_tenders;c public.payment_checkouts;e public.provider_event_evidence;r public.payment_refund_requests;
 reversal uuid;leg jsonb;pa public.payment_allocations;total bigint:=0;remaining bigint;orgtake bigint;share bigint;cost bigint;rest bigint;j uuid;sev uuid;s public.settlement_sources;policy public.settlement_policy_revisions;begin
 select *into p from public.payments where id=payment;select *into t from public.external_payment_tenders where payment_id=p.id;
 if t.payment_id is null or t.original_payment_id is not null then raise exception'Original external payment required'using errcode='PT404';end if;
 c:=boss_private.rails_checkout_fence(t.checkout_id);perform pg_advisory_xact_lock(hashtextextended('boss-payment-refund:'||p.id,0));
 select *into e from public.provider_event_evidence where id=event;
 select reversal_payment_id into reversal from public.external_payment_corrections where event_id=event;if reversal is not null then return reversal;end if;
 select *into r from public.payment_refund_requests where id=refund;
 if e.id is null or e.account_id<>c.account_id or e.currency<>p.currency or e.amount_minor<1

 or principal<0 or principal>e.amount_minor or p_kind not in('refund','void','chargeback','ach_return')
 or p_kind='refund'and(e.kind<>'refunded'or r.id is null or r.payment_id<>p.id or r.operation_id<>e.operation_id or r.amount_minor<>e.amount_minor or r.principal_minor<>principal or r.command->'input'->'allocations'<>allocations)
 or p_kind<>'refund'and(e.operation_id<>t.operation_id or e.transaction_reference<>(select provider_transaction_reference from public.provider_operations where id=t.operation_id))
 or p_kind='void'and e.kind<>'voided' or p_kind='chargeback'and e.kind<>'disputed' or p_kind='ach_return'and(e.kind<>'returned'or p.method<>'ach')then raise exception'Exact provider correction evidence required'using errcode='PT422';end if;
 if e.amount_minor>p.amount_minor-(select coalesce(sum(amount_minor),0)from public.payments where reversal_of_id=p.id)then
 insert into public.payment_review_cases(checkout_id,event_id,reason)values(c.id,e.id,'contradictory_status')on conflict do nothing;
 if r.id is not null then update public.provider_operations set state='succeeded'where id=r.operation_id;end if;
 perform boss_private.rails_audit(r.actor_id,p.organization_id,'payment.correction.review',p.id,null,jsonb_build_object('event_id',e.id,'amount_minor',e.amount_minor,'reason','original_remainder_exceeded'));return null;end if;
 for leg in select value from jsonb_array_elements(allocations)loop
 select *into pa from public.payment_allocations where id=(leg->>'allocation_id')::uuid and payment_id=p.id and status='applied';
 if pa.id is null or boss_private.rails_amount(leg,'amount_minor')>pa.amount_minor-(select coalesce(sum(amount_minor),0)from public.payment_allocations where reversal_of_id=pa.id)then raise exception'Correction allocation exceeds remainder'using errcode='PT409';end if;total:=total+(leg->>'amount_minor')::bigint;end loop;
 if c.purpose='fees'and(total<>e.amount_minor or total<>principal)or c.purpose='fundraising'and(total<>0 or principal>c.principal_minor-(select coalesce(sum(ec.principal_minor),0)from public.external_payment_corrections ec where original_payment_id=p.id))then raise exception'Correction principal mismatch'using errcode='PT422';end if;
 insert into public.payments(organization_id,method,amount_minor,currency,payer_person_id,recorded_by_person_id,received_at,status,reversal_of_id,fundraising_intent_id,source_reference)
 values(p.organization_id,p.method,e.amount_minor,p.currency,p.payer_person_id,r.actor_id,e.occurred_at,'reversed',p.id,p.fundraising_intent_id,e.event_reference)returning id into reversal;
 insert into public.external_payment_tenders(payment_id,organization_id,checkout_id,operation_id,event_id,original_payment_id,purpose)
 values(reversal,p.organization_id,c.id,e.operation_id,e.id,p.id,t.purpose);
 insert into public.external_payment_corrections(reversal_payment_id,original_payment_id,event_id,refund_request_id,kind,principal_minor)values(reversal,p.id,e.id,r.id,p_kind,principal);
 for leg in select value from jsonb_array_elements(allocations)loop
 select *into pa from public.payment_allocations where id=(leg->>'allocation_id')::uuid;
 insert into public.payment_allocations(organization_id,payment_id,charge_id,amount_minor,status,reversal_of_id)values(p.organization_id,reversal,pa.charge_id,(leg->>'amount_minor')::bigint,'reversed',pa.id);end loop;
 if c.intent_id is not null and t.purpose='fundraising'then
 remaining:=c.principal_minor-(select coalesce(sum(ec.principal_minor),0)from public.external_payment_corrections ec where original_payment_id=p.id);
 insert into public.fundraising_intent_events(intent_id,state,source_reference,amount_minor,remaining_valid_amount_minor)
 values(c.intent_id,case when remaining>0 then'partially_refunded'when p_kind='chargeback'then'chargeback'else'refunded'end,e.event_reference,principal,remaining);
 end if;
 if p_kind in('chargeback','ach_return')then insert into public.payment_dispute_cases(payment_id,event_id,case_reference,amount_minor,category)
 values(p.id,e.id,e.event_reference,e.amount_minor,case when p_kind='ach_return'then'ach_return'else'chargeback'end);end if;
 update public.settlement_requests sr set state='review'where sr.state='requested'and exists(select 1 from public.settlement_request_items ri where ri.request_id=sr.id and ri.payment_id=p.id);
 insert into public.settlement_request_history(request_id,state)select sr.id,'review'from public.settlement_requests sr where sr.state='review'and exists(select 1 from public.settlement_request_items ri where ri.request_id=sr.id and ri.payment_id=p.id)and not exists(select 1 from public.settlement_request_history h where h.request_id=sr.id and h.state='review');
 if r.id is not null then update public.provider_operations set state='succeeded'where id=r.operation_id;end if;
 update public.payment_checkouts set state=case when(select sum(amount_minor)from public.payments where reversal_of_id=p.id)=p.amount_minor then'refunded'else'partially_refunded'end where id=c.id;
 select *into s from public.settlement_sources where payment_id=p.id;
 if s.payment_id is not null then
 perform pg_advisory_xact_lock(hashtextextended('boss-settlement-source:'||p.id,0));select *into policy from public.settlement_policy_revisions where id=s.policy_id;
 insert into public.settlement_events(payment_id,provider_event_id,kind,source_key,amount_minor)values(p.id,e.id,case p_kind when'chargeback'then'dispute'when'ach_return'then'return'else'refund'end,'correction:'||reversal,e.amount_minor)returning id into sev;
 insert into public.settlement_journals(payment_id,event_id,kind,currency)values(p.id,sev,'correction',p.currency)returning id into j;
 insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'external_receivable'),-e.amount_minor);
 if not exists(select 1 from public.settlement_events where payment_id=p.id and kind='settled')then
 insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'held_gross'),e.amount_minor);
 else
 remaining:=s.principal_minor-(select coalesce(sum(ec.principal_minor),0)from public.external_payment_corrections ec where original_payment_id=p.id);
 share:=floor((remaining+principal)::numeric*policy.organization_basis_points/10000)::bigint-floor(remaining::numeric*policy.organization_basis_points/10000)::bigint;cost:=floor((remaining+principal)::numeric*policy.product_cost_basis_points/10000)::bigint-floor(remaining::numeric*policy.product_cost_basis_points/10000)::bigint;rest:=e.amount_minor-share-cost;
 if share>0 then
 if s.settlement_mode='direct_provider'then
 insert into public.settlement_deficits(organization_id,currency,correction_payment_id,amount_minor)values(p.organization_id,p.currency,reversal,share);
 insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'organization_deficit'),share);
 else
 orgtake:=least(share,boss_private.rails_source_payable(p.id));
 if orgtake>0 then insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'organization_payable'),orgtake);end if;
 if orgtake<share then insert into public.settlement_deficits(organization_id,currency,correction_payment_id,amount_minor)values(p.organization_id,p.currency,reversal,share-orgtake);
 insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'organization_deficit'),share-orgtake);end if;
 end if;end if;
 if cost>0 then insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'product_cost'),cost);end if;
 if rest>0 then insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'platform_share'),rest);end if;
 end if;end if;
 perform boss_private.rails_audit(r.actor_id,p.organization_id,'payment.'||p_kind,p.id,null,jsonb_build_object('reversal_payment_id',reversal,'event_id',e.id,'amount_minor',e.amount_minor,'principal_minor',principal));return reversal;
end$$;

-- Shared external proof includes corrections while preserving original capture.
alter function boss_private.rails_external_payment_proof()rename to rails_external_original_proof;
create function boss_private.rails_external_payment_proof()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare p public.payments;original public.payments;t public.external_payment_tenders;e public.provider_event_evidence;ec public.external_payment_corrections;begin
 select *into p from public.payments where id=case when tg_table_name='payments'then(to_jsonb(new)->>'id')::uuid else(to_jsonb(new)->>'payment_id')::uuid end;
 if p.method not in('card','ach')then return null;end if;
 if p.status='recorded'then
 -- Preserve the original verified-success proof and immutable source boundary.
 if not exists(select 1 from public.external_payment_tenders et join public.payment_checkouts c on c.id=et.checkout_id
 join public.payment_eligibility_commits cm on cm.checkout_id=c.id and cm.operation_id=et.operation_id
 join public.provider_operations op on op.id=et.operation_id and op.state='succeeded'and op.checkout_id=c.id and op.account_id=c.account_id and op.organization_id=c.organization_id
 join public.provider_event_evidence ev on ev.id=et.event_id and ev.operation_id=op.id and ev.account_id=c.account_id
 where et.payment_id=p.id and et.original_payment_id is null and et.organization_id=p.organization_id and c.organization_id=p.organization_id
 and p.amount_minor=c.external_minor and p.currency=c.currency and p.method=c.method and p.fundraising_intent_id is not distinct from c.intent_id
 and p.payer_person_id is not distinct from c.actor_person_id and p.recorded_by_person_id is not distinct from c.actor_person_id
 and ev.amount_minor=p.amount_minor and ev.currency=p.currency and ev.transaction_reference=op.provider_transaction_reference and ev.occurred_at>=cm.eligibility_committed_at
 and(p.method='card'and ev.kind in('captured','settled')or p.method='ach'and ev.kind='settled')
 and(c.state='captured_unallocated'and et.purpose='unallocated'and not exists(select 1 from public.payment_allocations where payment_id=p.id)
 or c.state in('completed','partially_refunded','refunded')and et.purpose=c.purpose and(c.purpose='fees'or exists(select 1 from public.fundraising_success_evidence fe where fe.intent_id=c.intent_id and fe.provenance->>'committed_checkout_id'=c.id::text))))then raise exception'External payment requires exact verified checkout evidence'using errcode='23514';end if;
 else
 select *into original from public.payments where id=p.reversal_of_id;select *into t from public.external_payment_tenders where payment_id=p.id;
 select *into e from public.provider_event_evidence where id=t.event_id;select *into ec from public.external_payment_corrections where reversal_payment_id=p.id;
 if ec.reversal_payment_id is null or t.original_payment_id is distinct from original.id or ec.original_payment_id is distinct from original.id
 or original.status<>'recorded'or original.method<>p.method or original.organization_id<>p.organization_id or original.currency<>p.currency
 or e.amount_minor<>p.amount_minor or e.currency<>p.currency or ec.event_id is distinct from e.id
 or(select coalesce(sum(amount_minor),0)from public.payments where reversal_of_id=original.id)>original.amount_minor then raise exception'External correction requires original tender and provider proof'using errcode='23514';end if;
 end if;return null;
end$$;
-- Existing triggers follow their function OID through the rename. Rebind both
-- to the extended validator; never leave corrections using the old-only proof.
drop trigger rails_external_payment_proof on public.payments;
drop trigger rails_external_tender_proof on public.external_payment_tenders;
create constraint trigger rails_external_payment_proof after insert on public.payments deferrable initially deferred for each row execute function boss_private.rails_external_payment_proof();
create constraint trigger rails_external_tender_proof after insert on public.external_payment_tenders deferrable initially deferred for each row execute function boss_private.rails_external_payment_proof();

create function boss_private.rails_correction_proof()returns trigger language plpgsql volatile security definer set search_path=''as $$declare e public.provider_event_evidence;t public.external_payment_tenders;p public.payments;r public.payment_refund_requests;begin
 select *into p from public.payments where id=new.reversal_payment_id;select *into e from public.provider_event_evidence where id=new.event_id;
 select *into t from public.external_payment_tenders where payment_id=new.original_payment_id;select *into r from public.payment_refund_requests where id=new.refund_request_id;
 if p.reversal_of_id is distinct from t.payment_id or e.account_id<>(select account_id from public.provider_operations where id=t.operation_id)
 or new.kind='refund'and(e.kind<>'refunded'or r.operation_id is distinct from e.operation_id or r.payment_id is distinct from t.payment_id or r.amount_minor<>p.amount_minor or r.principal_minor<>new.principal_minor)
 or new.kind='void'and e.kind<>'voided'or new.kind='chargeback'and e.kind<>'disputed'or new.kind='ach_return'and(e.kind<>'returned'or p.method<>'ach')then raise exception'Correction lineage mismatch'using errcode='23514';end if;return null;
end$$;
create constraint trigger rails_correction_proof after insert on public.external_payment_corrections deferrable initially deferred for each row execute function boss_private.rails_correction_proof();

do $$declare t text;p record;begin
 foreach t in array array['payment_refund_requests','external_payment_corrections','payment_dispute_cases','settlement_deficits','settlement_deficit_offsets','payment_reconciliation_runs','payment_reconciliation_items']loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);
 execute format('create trigger immutable_%I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t,t);
 execute format('create trigger immutable_truncate_%I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t,t);end loop;
 for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'rails_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;
end$$;

create function boss_private.rails_refund_dispatch(refund uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$declare r public.payment_refund_requests;o public.provider_operations;t public.external_payment_tenders;c public.payment_checkouts;begin
 select *into r from public.payment_refund_requests where id=refund;select *into t from public.external_payment_tenders where payment_id=r.payment_id;
 if r.id is null then raise exception'Refund unavailable'using errcode='PT404';end if;c:=boss_private.rails_checkout_fence(t.checkout_id);
 select *into o from public.provider_operations where id=r.operation_id for update;
 if o.dispatched_at is not null then return jsonb_build_object('operation_id',o.id,'first_dispatch',false,'transaction_reference',o.provider_transaction_reference);end if;
 if not boss_private.rails_actor_current(r.actor_id)or not boss_private.rails_role(r.actor_id,'payments.refund',r.organization_id)or not boss_private.rails_feature(r.organization_id,'refunds')
 or not boss_private.rails_account_ready(c.account_id,c.organization_id,c.method,c.currency)then raise exception'Refund execution authority ended'using errcode='PT403';end if;
 if r.amount_minor>(select p.amount_minor-coalesce((select sum(rp.amount_minor)from public.payments rp where rp.reversal_of_id=p.id),0)from public.payments p where p.id=r.payment_id)then raise exception'Original refundable remainder changed'using errcode='PT409';end if;
 update public.provider_operations set state='dispatched',dispatched_at=clock_timestamp()where id=o.id;
 return jsonb_build_object('operation_id',o.id,'first_dispatch',true,'provider_request_reference',o.provider_request_reference);
end$$;
create function boss_private.rails_refund_receive(refund uuid,p_reference text,p_kind text,p_transaction text,p_amount bigint,p_currency text,p_at timestamptz,p_digest text)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare r public.payment_refund_requests;o public.provider_operations;t public.external_payment_tenders;c public.payment_checkouts;e public.provider_event_evidence;rev uuid;begin
 select *into r from public.payment_refund_requests where id=refund;select *into t from public.external_payment_tenders where payment_id=r.payment_id;
 if r.id is null then raise exception'Refund unavailable'using errcode='PT404';end if;c:=boss_private.rails_checkout_fence(t.checkout_id);
 select *into o from public.provider_operations where id=r.operation_id for update;
 if o.provider_transaction_reference is not null and p_transaction is distinct from o.provider_transaction_reference then raise exception'Refund transaction identity changed'using errcode='PT409';end if;
 if o.state='succeeded'and p_kind<>'refunded'then raise exception'Completed refund cannot become failed or unknown'using errcode='PT409';end if;
 if o.dispatched_at is null or p_kind not in('refunded','unknown','failed')or p_amount is distinct from r.amount_minor or p_currency is distinct from o.currency
 or p_at<o.dispatched_at or p_kind='refunded'and p_transaction is null then raise exception'Refund evidence mismatch'using errcode='PT422';end if;
 select *into e from public.provider_event_evidence where account_id=o.account_id and event_reference=p_reference;
 if e.id is not null then if e.kind<>p_kind or e.operation_id<>o.id or e.body_digest<>p_digest or e.amount_minor<>p_amount or e.currency<>p_currency or e.transaction_reference<>coalesce(p_transaction,'unresolved:'||o.provider_request_reference)or e.occurred_at<>p_at then raise exception'Refund event replay conflict'using errcode='PT409';end if;
 return jsonb_build_object('state',o.state,'replayed',true);end if;
 insert into public.provider_event_evidence(account_id,operation_id,event_reference,kind,transaction_reference,amount_minor,currency,occurred_at,body_digest)
 values(o.account_id,o.id,p_reference,p_kind,coalesce(p_transaction,'unresolved:'||o.provider_request_reference),p_amount,p_currency,p_at,p_digest)returning *into e;
 if p_transaction is not null then update public.provider_operations set provider_transaction_reference=p_transaction where id=o.id;end if;
 if p_kind='refunded'then
 rev:=boss_private.rails_external_correct(r.payment_id,e.id,'refund',r.principal_minor,r.command->'input'->'allocations',r.id);
 else update public.provider_operations set state=case when p_kind='failed'then'failed'else'unknown'end where id=o.id;end if;
 return jsonb_build_object('state',case when rev is not null then'succeeded'else p_kind end,'reversal_payment_id',rev,'replayed',false);
end$$;
revoke all on function boss_private.rails_refund_dispatch(uuid),boss_private.rails_refund_receive(uuid,text,text,text,bigint,text,timestamptz,text)from public,anon,authenticated,service_role,boss_payment_worker;

-- Same-organization recovery consumes only a newly attributable payable, with
-- immutable offsets and a balanced journal; family wallet deficits are separate.
create function boss_private.rails_offset_deficits(payment uuid)returns bigint language plpgsql volatile security definer set search_path=''as $$
declare s public.settlement_sources;d public.settlement_deficits;remaining bigint;free bigint;take bigint;total bigint:=0;e uuid;j uuid;begin
 select *into s from public.settlement_sources where payment_id=payment;
 if s.payment_id is null or s.settlement_mode<>'platform_managed'then return 0;end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-settlement-org:'||s.organization_id||':'||s.currency,0));
 free:=boss_private.rails_source_payable(payment)-coalesce((select sum(i.amount_minor)from public.settlement_request_items i join public.settlement_requests r on r.id=i.request_id where i.payment_id=payment and r.state in('requested','review','scheduled','paid','partially_paid')),0);
 for d in select *from public.settlement_deficits where organization_id=s.organization_id and currency=s.currency order by created_at,id limit 100 for update loop
 remaining:=d.amount_minor-(select coalesce(sum(amount_minor),0)from public.settlement_deficit_offsets where deficit_id=d.id);
 take:=least(free,remaining);if take<=0 then continue;end if;
 insert into public.settlement_deficit_offsets(deficit_id,payment_id,amount_minor)values(d.id,payment,take);
 insert into public.settlement_events(payment_id,kind,source_key,amount_minor)values(payment,'deficit_offset','deficit:'||d.id,take)returning id into e;
 insert into public.settlement_journals(payment_id,event_id,kind,currency)values(payment,e,'deficit_offset',s.currency)returning id into j;
 insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'organization_payable'),take),(j,boss_private.rails_settlement_account(s,'organization_deficit'),-take);
 free:=free-take;total:=total+take;exit when free=0;end loop;
 if total>0 then perform boss_private.rails_audit(null,s.organization_id,'settlement.deficit.offset',payment,null,jsonb_build_object('amount_minor',total));end if;return total;
end$$;
create function boss_private.rails_offset_proof()returns trigger language plpgsql volatile security definer set search_path=''as $$declare d public.settlement_deficits;s public.settlement_sources;begin
 select *into d from public.settlement_deficits where id=new.deficit_id;select *into s from public.settlement_sources where payment_id=new.payment_id;
 if d.organization_id<>s.organization_id or d.currency<>s.currency or s.settlement_mode<>'platform_managed'
 or(select sum(amount_minor)from public.settlement_deficit_offsets where deficit_id=d.id)>d.amount_minor
 or not exists(select 1 from public.settlement_events where payment_id=s.payment_id and source_key='deficit:'||d.id and amount_minor=new.amount_minor)then raise exception'Exact organization deficit offset required'using errcode='23514';end if;return null;
end$$;
create constraint trigger rails_deficit_offset_proof after insert on public.settlement_deficit_offsets deferrable initially deferred for each row execute function boss_private.rails_offset_proof();
revoke all on function boss_private.rails_offset_deficits(uuid),boss_private.rails_offset_proof()from public,anon,authenticated,service_role,boss_payment_worker;
