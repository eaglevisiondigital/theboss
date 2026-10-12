-- Independent, append-only economic settlement. A successful card capture is
-- not a batch settlement, available payable or organization payout.
create table public.settlement_sources(
 payment_id uuid primary key references public.payments(id),organization_id uuid not null references public.organizations(id),
 account_id uuid references public.processing_accounts(id),policy_id uuid references public.settlement_policy_revisions(id),
 method text not null check(method in('card','ach','boss_bucks')),currency text not null check(currency~'^[A-Z]{3}$'),
 purpose text not null check(purpose in('fees','fundraising','boss_bucks','unallocated')),
 settlement_mode text not null check(settlement_mode in('direct_provider','platform_managed','unconfigured')),
 gross_minor bigint not null check(gross_minor between 1 and 1000000000),principal_minor bigint not null check(principal_minor between 0 and gross_minor),
 donor_fee_minor bigint not null check(donor_fee_minor between 0 and gross_minor),platform_fee_minor bigint not null check(platform_fee_minor between 0 and gross_minor),
 payment_success_at timestamptz not null,available_at timestamptz,
 created_at timestamptz not null default clock_timestamp(),foreign key(organization_id,payment_id)references public.payments(organization_id,id),
 check(principal_minor+donor_fee_minor+platform_fee_minor=gross_minor));
create index settlement_sources_org_idx on public.settlement_sources(organization_id,currency,created_at desc,payment_id);
create index settlement_sources_account_idx on public.settlement_sources(account_id,payment_id);
create index settlement_sources_policy_idx on public.settlement_sources(policy_id);
create table public.settlement_events(
 id uuid primary key default gen_random_uuid(),payment_id uuid not null references public.settlement_sources(payment_id),
 provider_event_id uuid references public.provider_event_evidence(id),
 kind text not null check(kind in('success','held_policy','held_fee','matched','mismatch','settled','refund','dispute','dispute_won','return','request','payout','deficit_offset')),
 source_key text not null check(length(source_key)between 1 and 200),amount_minor bigint check(amount_minor between 0 and 1000000000),
 processor_fee_minor bigint check(processor_fee_minor between 0 and 1000000000),
 created_at timestamptz not null default clock_timestamp(),unique(payment_id,source_key));
create index settlement_events_source_idx on public.settlement_events(payment_id,created_at,id);
create index settlement_events_provider_idx on public.settlement_events(provider_event_id);
create table public.settlement_accounts(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),account_id uuid references public.processing_accounts(id),
 currency text not null check(currency~'^[A-Z]{3}$'),kind text not null check(kind in('external_receivable','bucks_exposure','held_gross','organization_payable','platform_share','product_cost','processor_cost','remittance','organization_deficit')),
 created_at timestamptz not null default clock_timestamp(),unique nulls not distinct(organization_id,account_id,currency,kind));
create index settlement_accounts_provider_idx on public.settlement_accounts(account_id);
create table public.settlement_journals(
 id uuid primary key default gen_random_uuid(),payment_id uuid not null references public.settlement_sources(payment_id),event_id uuid not null references public.settlement_events(id),
 kind text not null check(kind in('success','attribution','correction','remittance','deficit_offset')),currency text not null,
 created_at timestamptz not null default clock_timestamp(),unique(payment_id,event_id,kind));
create index settlement_journals_event_idx on public.settlement_journals(event_id);
create table public.settlement_postings(
 id uuid primary key default gen_random_uuid(),journal_id uuid not null references public.settlement_journals(id),account_id uuid not null references public.settlement_accounts(id),
 amount_minor bigint not null check(amount_minor<>0 and amount_minor between -1000000000 and 1000000000),
 source_allocation_id uuid references public.payment_allocations(id),created_at timestamptz not null default clock_timestamp());
create index settlement_postings_journal_idx on public.settlement_postings(journal_id,account_id)include(amount_minor);
create index settlement_postings_account_idx on public.settlement_postings(account_id,journal_id)include(amount_minor);
create index settlement_postings_allocation_idx on public.settlement_postings(source_allocation_id);
create table public.settlement_requests(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),currency text not null check(currency~'^[A-Z]{3}$'),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000),requested_by uuid not null references public.people(id),request_id uuid not null unique,
 state text not null default 'requested'check(state in('requested','review','canceled','scheduled','paid','partially_paid','failed')),
 created_at timestamptz not null default clock_timestamp());
create index settlement_requests_org_idx on public.settlement_requests(organization_id,currency,state,created_at,id);
create index settlement_requests_actor_idx on public.settlement_requests(requested_by);
create table public.settlement_request_items(
 request_id uuid not null references public.settlement_requests(id),payment_id uuid not null references public.settlement_sources(payment_id),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000),primary key(request_id,payment_id));
create index settlement_request_items_payment_idx on public.settlement_request_items(payment_id,request_id);
create table public.settlement_request_history(
 id uuid primary key default gen_random_uuid(),request_id uuid not null references public.settlement_requests(id),state text not null check(state in('requested','review','canceled','scheduled','paid','partially_paid','failed')),
 actor_id uuid references public.people(id),created_at timestamptz not null default clock_timestamp());
create index settlement_request_history_request_idx on public.settlement_request_history(request_id,created_at,id);
create index settlement_request_history_actor_idx on public.settlement_request_history(actor_id);

create function boss_private.rails_settlement_account(s public.settlement_sources,p_kind text)returns uuid language plpgsql volatile security definer set search_path=''as $$declare a uuid;begin
 insert into public.settlement_accounts(organization_id,account_id,currency,kind)values(s.organization_id,s.account_id,s.currency,p_kind)on conflict do nothing;
 select id into a from public.settlement_accounts where organization_id=s.organization_id and account_id is not distinct from s.account_id and currency=s.currency and kind=p_kind;return a;
end$$;
create function boss_private.rails_settlement_proof()returns trigger language plpgsql volatile security definer set search_path=''as $$declare j public.settlement_journals;s public.settlement_sources;begin
 select *into j from public.settlement_journals where id=case when tg_table_name='settlement_journals'then(to_jsonb(new)->>'id')::uuid else(to_jsonb(new)->>'journal_id')::uuid end;
 select *into s from public.settlement_sources where payment_id=j.payment_id;
 if(select count(*)from public.settlement_postings where journal_id=j.id)<2 or(select sum(amount_minor)from public.settlement_postings where journal_id=j.id)<>0
 or j.currency<>s.currency or not exists(select 1 from public.settlement_events where id=j.event_id and payment_id=s.payment_id)
 or exists(select 1 from public.settlement_postings p join public.settlement_accounts a on a.id=p.account_id where p.journal_id=j.id and(a.organization_id<>s.organization_id or a.account_id is distinct from s.account_id or a.currency<>s.currency))
 then raise exception'Invalid balanced settlement journal or tenant lineage'using errcode='23514';end if;return null;
end$$;
create constraint trigger rails_settlement_journal_proof after insert on public.settlement_journals deferrable initially deferred for each row execute function boss_private.rails_settlement_proof();
create constraint trigger rails_settlement_posting_proof after insert on public.settlement_postings deferrable initially deferred for each row execute function boss_private.rails_settlement_proof();

create function boss_private.rails_settlement_ingest(payment uuid)returns void language plpgsql volatile security definer set search_path=''as $$
declare p public.payments;t public.external_payment_tenders;c public.payment_checkouts;policy public.settlement_policy_revisions;s public.settlement_sources;e uuid;j uuid;mode text;purpose text;account uuid;principal bigint;donorfee bigint:=0;platformfee bigint:=0;begin
 select *into p from public.payments where id=payment;
 if p.method not in('card','ach','boss_bucks')or p.status<>'recorded'then return;end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-settlement-source:'||p.id,0));
 if exists(select 1 from public.settlement_sources where payment_id=p.id)then return;end if;
 if p.method='boss_bucks'then
 purpose:='boss_bucks';mode:='platform_managed';principal:=p.amount_minor;
 select *into policy from public.settlement_policy_revisions where organization_id=p.organization_id and settlement_policy_revisions.purpose='boss_bucks'and currency=p.currency and created_at<=p.created_at order by revision desc limit 1;
 else
 select *into t from public.external_payment_tenders where payment_id=p.id;
 if t.payment_id is null then raise exception'Canonical verified tender required'using errcode='23514';end if;
 select *into c from public.payment_checkouts where id=t.checkout_id;
 select *into policy from public.settlement_policy_revisions where id=c.policy_id and organization_id=p.organization_id and settlement_policy_revisions.purpose=c.purpose and currency=p.currency;
 purpose:=t.purpose;account:=c.account_id;select settlement_mode into mode from public.processing_accounts where id=account;
 principal:=c.principal_minor-c.bucks_minor;donorfee:=c.donor_covered_fee_minor;platformfee:=c.platform_fee_minor;
 end if;
 insert into public.settlement_sources(payment_id,organization_id,account_id,policy_id,method,currency,purpose,settlement_mode,gross_minor,principal_minor,donor_fee_minor,platform_fee_minor,payment_success_at,available_at)
 values(p.id,p.organization_id,account,policy.id,p.method,p.currency,purpose,case when policy.id is null then'unconfigured'else mode end,p.amount_minor,principal,donorfee,platformfee,p.received_at,
 case when policy.id is not null then p.received_at+make_interval(secs=>policy.availability_seconds)end)returning *into s;
 insert into public.settlement_events(payment_id,kind,source_key,amount_minor)values(p.id,case when policy.id is null or purpose='unallocated'then'held_policy'else'success'end,'success:'||p.id,p.amount_minor)returning id into e;
 insert into public.settlement_journals(payment_id,event_id,kind,currency)values(p.id,e,'success',p.currency)returning id into j;
 insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,case when p.method='boss_bucks'then'bucks_exposure'else'external_receivable'end),p.amount_minor),
 (j,boss_private.rails_settlement_account(s,'held_gross'),-p.amount_minor);
 perform boss_private.rails_audit(null,s.organization_id,'settlement.source.success',p.id,null,jsonb_build_object('method',s.method,'policy_id',s.policy_id,'settlement_mode',s.settlement_mode));
end$$;
create function boss_private.rails_settlement_ingest_trigger()returns trigger language plpgsql volatile security definer set search_path=''as $$begin
 perform boss_private.rails_settlement_ingest(new.payment_id);return null;end$$;
create trigger rails_settlement_source_dependency after insert on public.external_payment_tenders for each row execute function boss_private.rails_settlement_ingest_trigger();
create trigger rails_settlement_bucks_dependency after insert on public.boss_bucks_tenders for each row execute function boss_private.rails_settlement_ingest_trigger();

create function boss_private.rails_settlement_match(payment uuid,event uuid,actual_fee bigint)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare s public.settlement_sources;e public.provider_event_evidence;p public.settlement_policy_revisions;t public.external_payment_tenders;ev uuid;j uuid;orgshare bigint;platformshare bigint;cost bigint;existing bigint;net_principal bigint;net_gross bigint;begin
 perform boss_private.rails_settlement_ingest(payment);
 select *into s from public.settlement_sources where payment_id=payment;
 if s.payment_id is null then raise exception'Settlement source unavailable'using errcode='PT404';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-settlement-org:'||s.organization_id||':'||s.currency,0));
 perform pg_advisory_xact_lock(hashtextextended('boss-settlement-source:'||s.payment_id,0));
 select *into p from public.settlement_policy_revisions where id=s.policy_id;
 select *into e from public.provider_event_evidence where id=event;
 select *into t from public.external_payment_tenders where payment_id=payment;
 if s.method='boss_bucks'then
 if event is not null or actual_fee<>0 then raise exception'Internal redemption is not provider cash'using errcode='PT422';end if;
 elsif e.id is null or e.account_id<>s.account_id or e.operation_id<>t.operation_id or e.kind<>'settled'or e.amount_minor<>s.gross_minor or e.currency<>s.currency
 or actual_fee is null or actual_fee<0 or actual_fee>s.gross_minor or e.safe_metadata->>'processor_fee_minor' is distinct from actual_fee::text then raise exception'Authoritative settlement and actual fee required'using errcode='PT422';end if;
 if p.id is null or s.purpose='unallocated'then return jsonb_build_object('state','held','reason','policy_or_review_required');end if;
 select processor_fee_minor into existing from public.settlement_events where payment_id=s.payment_id and kind='settled';
 if found then if existing<>actual_fee then raise exception'Settlement replay fee conflict'using errcode='PT409';end if;return jsonb_build_object('state','settled','replayed',true);end if;
 net_principal:=s.principal_minor-(select coalesce(sum(ec.principal_minor),0)from public.external_payment_corrections ec where ec.original_payment_id=s.payment_id);
 net_gross:=s.gross_minor-(select coalesce(sum(amount_minor),0)from public.payments where reversal_of_id=s.payment_id);
 orgshare:=floor(net_principal::numeric*p.organization_basis_points/10000)::bigint;
 cost:=floor(net_principal::numeric*p.product_cost_basis_points/10000)::bigint;
 platformshare:=net_gross-orgshare-cost;
 if p.processor_fee_owner='organization'then orgshare:=orgshare-actual_fee;else platformshare:=platformshare-actual_fee;end if;
 if orgshare<0 or platformshare<0 then
 insert into public.settlement_events(payment_id,provider_event_id,kind,source_key,processor_fee_minor)values(s.payment_id,event,'mismatch','fee-mismatch:'||coalesce(event::text,'internal'),actual_fee)on conflict do nothing;
 return jsonb_build_object('state','mismatch','reason','fee_exceeds_configured_share');end if;
 insert into public.settlement_events(payment_id,provider_event_id,kind,source_key,amount_minor,processor_fee_minor)values(s.payment_id,event,'settled','settlement:'||s.payment_id,orgshare,actual_fee)returning id into ev;
 if net_gross=0 then return jsonb_build_object('state','settled','replayed',false,'organization_payable_minor',0);end if;
 insert into public.settlement_journals(payment_id,event_id,kind,currency)values(s.payment_id,ev,'attribution',s.currency)returning id into j;
 insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'held_gross'),net_gross);
 if orgshare>0 then insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'organization_payable'),-orgshare);end if;
 if platformshare>0 then insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'platform_share'),-platformshare);end if;
 if cost>0 then insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'product_cost'),-cost);end if;
 if actual_fee>0 then insert into public.settlement_postings(journal_id,account_id,amount_minor)values(j,boss_private.rails_settlement_account(s,'processor_cost'),-actual_fee);end if;
 perform boss_private.rails_offset_deficits(s.payment_id);
 return jsonb_build_object('state','settled','replayed',false,'organization_payable_minor',boss_private.rails_source_payable(s.payment_id));
end$$;

create function boss_private.rails_source_payable(payment uuid)returns bigint language sql volatile security definer set search_path=''as $$
 select greatest(0,-coalesce(sum(p.amount_minor),0))::bigint from public.settlement_sources s join public.settlement_journals j on j.payment_id=s.payment_id
 join public.settlement_postings p on p.journal_id=j.id join public.settlement_accounts a on a.id=p.account_id and a.kind='organization_payable'
 where s.payment_id=payment
$$;
create function boss_private.rails_payable(org uuid,currency text)returns bigint language sql volatile security definer set search_path=''as $$
 select greatest(0,coalesce(sum(boss_private.rails_source_payable(s.payment_id)),0)-coalesce((select sum(i.amount_minor)from public.settlement_request_items i join public.settlement_requests r on r.id=i.request_id where r.organization_id=org and r.currency=rails_payable.currency and r.state in('requested','review','scheduled','paid','partially_paid')),0))::bigint
 from public.settlement_sources s where s.organization_id=org and s.currency=rails_payable.currency and s.settlement_mode='platform_managed'and s.available_at<=clock_timestamp()
 and exists(select 1 from public.settlement_events where payment_id=s.payment_id and kind='settled')
$$;
-- No outbound payout rail or fabricated paid-state endpoint is installed.
do $$declare t text;p record;begin
 foreach t in array array['settlement_sources','settlement_events','settlement_accounts','settlement_journals','settlement_postings','settlement_requests','settlement_request_items','settlement_request_history']loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);
 if t<>'settlement_requests'then execute format('create trigger immutable_%I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t,t);end if;
 execute format('create trigger immutable_truncate_%I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t,t);end loop;
 for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'rails_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.signature);end loop;
end$$;
