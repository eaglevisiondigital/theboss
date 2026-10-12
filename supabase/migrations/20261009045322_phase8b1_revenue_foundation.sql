-- Evidence only; no Wallet/financial posting, provider settlement or money movement.
create table public.partner_commission_policies (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null,contract_id uuid not null,
 revision bigint not null check(revision>0),currency text not null check(currency~'^[A-Z]{3}$'),
 basis text not null check(basis in('fixed','percentage','zero','unknown')),
 fixed_minor bigint check(fixed_minor between 0 and 9000000000000),rate_ppm integer check(rate_ppm between 0 and 1000000),
 recognition_condition text not null check(recognition_condition in('confirmed','fulfilled','settled')),
 starts_at timestamptz not null,ends_at timestamptz not null,created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(provider_id,contract_id)references public.partner_contract_revisions(provider_id,id),
 unique(provider_id,id),unique(contract_id,revision),
 check(isfinite(starts_at)and isfinite(ends_at)and ends_at>starts_at),
 check(case basis when'fixed'then fixed_minor is not null and rate_ppm is null when'percentage'then rate_ppm is not null and fixed_minor is null else fixed_minor is null and rate_ppm is null end));
create table public.partner_transaction_sources (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null,external_id text not null check(external_id~'^[a-zA-Z0-9_.:-]{1,120}$'),
 benefit_revision_id uuid not null,policy_id uuid not null,
 currency text not null check(currency~'^[A-Z]{3}$'),eligible_minor bigint not null check(eligible_minor between 0 and 9000000000000),
 attributed_person_id uuid references public.people(id),native_sales_lead_id uuid references public.merchant_sales_leads(id),
 synthetic boolean not null check(synthetic),occurred_at timestamptz not null check(isfinite(occurred_at)),
 evidence_reference text not null check(evidence_reference~'^synthetic-evidence/[a-zA-Z0-9/_-]{3,160}$'),
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(provider_id,benefit_revision_id)references public.partner_benefit_revisions(provider_id,id),
 foreign key(provider_id,policy_id)references public.partner_commission_policies(provider_id,id),unique(provider_id,external_id),unique(provider_id,id));
create table public.partner_transaction_events (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null,transaction_id uuid not null,
 external_event_id text not null check(external_event_id~'^[a-zA-Z0-9_.:-]{1,120}$'),
 kind text not null check(kind in('discovered','referred','handoff','requested','confirmed','fulfilled','settled','canceled','refund','correction')),
 adjustment_minor bigint not null default 0 check(adjustment_minor between 0 and 9000000000000),
 corrects_event_id uuid references public.partner_transaction_events(id),evidence_reference text not null check(evidence_reference~'^synthetic-evidence/[a-zA-Z0-9/_-]{3,160}$'),
 actor_id uuid not null references public.people(id),request_id uuid not null,created_at timestamptz not null default clock_timestamp(),
 foreign key(provider_id,transaction_id)references public.partner_transaction_sources(provider_id,id),
 unique(provider_id,external_event_id),check((kind='correction')=(corrects_event_id is not null)));
create index partner_transaction_events_idx on public.partner_transaction_events(transaction_id,created_at,id);
create index partner_transactions_policy_idx on public.partner_transaction_sources(policy_id);
create index partner_transactions_person_idx on public.partner_transaction_sources(attributed_person_id);
create index partner_transactions_sales_idx on public.partner_transaction_sources(native_sales_lead_id);

-- Fail closed at this migration boundary, including projects with broad defaults.
do $$declare t record;f record;begin
 for t in select schemaname,tablename from pg_tables where schemaname in('public','boss_private')and tablename like'partner_%'loop
 execute format('alter table %I.%I enable row level security',t.schemaname,t.tablename);
 execute format('revoke all on %I.%I from public,anon,authenticated,service_role,boss_payment_worker',t.schemaname,t.tablename);end loop;
 for f in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'partner_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',f.signature);end loop;
end$$;
