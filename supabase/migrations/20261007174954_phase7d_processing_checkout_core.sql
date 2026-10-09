-- Phase 7D extends canonical payments. No credentials, account activation,
-- production fee/rate or live money movement is installed by this migration.
insert into public.modules(key,name,description,status) values
 ('payments','Payments','Canonical online payments and settlement','active');
insert into public.permissions(key,name,description) values
 ('payments.refund','Refund payments','Explicit original-tender allocation refunds'),
 ('payments.provider_manage','Manage processing routes','Approved merchant and routing configuration'),
 ('settlements.view','View settlement','Own-organization settlement evidence'),
 ('settlements.manage','Request settlement','Request only available own-organization payable'),
 ('settlements.reconcile','Reconcile payments','Review discrepancies without rewriting financial history');
insert into public.role_permissions(role_id,permission_id)
 select r.id,p.id from public.roles r cross join public.permissions p
 where p.key in('payments.refund','payments.provider_manage','settlements.view','settlements.manage','settlements.reconcile')
 and (r.key in('super_administrator','platform_administrator','organization_owner','organization_administrator')
 or r.key in('finance','organization_finance') and p.key<>'payments.provider_manage');

create role boss_payment_worker nologin noinherit nosuperuser nobypassrls;
grant boss_payment_worker to postgres;
grant usage on schema boss_private to boss_payment_worker;

create table public.processing_accounts(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 provider text not null check(provider in('authorize_net','nmi')), environment text not null check(environment in('sandbox','production')),
 name text not null check(length(btrim(name)) between 1 and 100), country text not null check(country in('US','CA')),
 currencies text[] not null check(cardinality(currencies) between 1 and 20 and currencies<@array['USD','CAD','GBP','DKK','NOK','PLN','SEK','EUR','AUD','NZD']::text[]),
 merchant_owner text not null check(merchant_owner in('organization','platform')),
 merchant_reference text not null check(length(merchant_reference) between 1 and 100),
 settlement_mode text not null check(settlement_mode in('direct_provider','platform_managed')),
 capabilities text[] not null default '{}' check(capabilities<@array['card_sale','auth_capture','ach','saved_profile','refund','partial_refund','webhook','settlement_query']::text[]),
 status text not null default 'draft' check(status in('draft','pending_verification','active','suspended','disabled','archived')),
 statement_descriptor text check(length(statement_descriptor) between 1 and 22 and statement_descriptor!~'[[:cntrl:]]'),
 created_by uuid not null references public.people(id), version bigint not null default 1 check(version>0),
 created_at timestamptz not null default clock_timestamp(), updated_at timestamptz not null default clock_timestamp(),
 unique(organization_id,id),unique(id,organization_id,provider,environment),
 check(merchant_owner<>'organization' or settlement_mode='direct_provider'));
create index processing_accounts_org_idx on public.processing_accounts(organization_id,status,id);
create index processing_accounts_creator_idx on public.processing_accounts(created_by);
-- Non-secret binding identity only; the secret value stays in approved server
-- infrastructure. A trusted operator must verify it before account activation.
create table boss_private.processing_bindings(
 account_id uuid primary key references public.processing_accounts(id),
 secret_handle text not null check(secret_handle~'^boss/payments/[a-z0-9_/-]{1,100}$'),
 credential_revision uuid not null, verified_environment text not null check(verified_environment in('sandbox','production')),
 verified_merchant_reference text not null, verified_at timestamptz not null,
 collection_key_handle text, revoked_at timestamptz,
 check(collection_key_handle is null or collection_key_handle~'^boss/payments/[a-z0-9_/-]{1,100}$'));

create table public.payment_routing_revisions(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 account_id uuid not null,purpose text not null check(purpose in('fees','fundraising')),
 currency text not null check(currency~'^[A-Z]{3}$'), scope_type text not null check(scope_type in('organization','campaign','team','unit')),
 scope_id uuid not null, revision bigint not null check(revision>0),
 starts_at timestamptz not null,ends_at timestamptz, created_by uuid not null references public.people(id),
 created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,account_id) references public.processing_accounts(organization_id,id),
 unique(organization_id,purpose,currency,scope_type,scope_id,revision),
 check(isfinite(starts_at) and (ends_at is null or isfinite(ends_at) and ends_at>starts_at)));
create index payment_routing_match_idx on public.payment_routing_revisions(organization_id,purpose,currency,scope_type,scope_id,revision desc);
create index payment_routing_account_idx on public.payment_routing_revisions(organization_id,account_id);
create index payment_routing_creator_idx on public.payment_routing_revisions(created_by);
create table public.payment_routing_events(
 id uuid primary key default gen_random_uuid(),routing_id uuid not null references public.payment_routing_revisions(id),
 state text not null check(state in('active','disabled')),actor_id uuid not null references public.people(id),
 created_at timestamptz not null default clock_timestamp());
create index payment_routing_events_latest_idx on public.payment_routing_events(routing_id,created_at desc,id desc);
create index payment_routing_events_actor_idx on public.payment_routing_events(actor_id);

create table public.settlement_policy_revisions(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 purpose text not null check(purpose in('fees','fundraising','boss_bucks')),currency text not null check(currency~'^[A-Z]{3}$'),
 revision bigint not null check(revision>0),organization_basis_points integer not null check(organization_basis_points between 0 and 10000),
 platform_basis_points integer not null check(platform_basis_points between 0 and 10000),
 product_cost_basis_points integer not null check(product_cost_basis_points between 0 and 10000),
 processor_fee_owner text not null check(processor_fee_owner in('organization','platform')),
 availability_seconds integer not null check(availability_seconds between 0 and 31536000),
 request_target_seconds integer check(request_target_seconds between 0 and 31536000),
 estimated_processor_basis_points integer check(estimated_processor_basis_points between 0 and 9999),
 estimated_processor_flat_minor bigint check(estimated_processor_flat_minor between 0 and 1000000000),
 platform_fee_minor bigint not null default 0 check(platform_fee_minor between 0 and 1000000000),
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(organization_id,purpose,currency,revision),
 check(organization_basis_points+platform_basis_points+product_cost_basis_points=10000),
 check((estimated_processor_basis_points is null)=(estimated_processor_flat_minor is null)));
create index settlement_policy_latest_idx on public.settlement_policy_revisions(organization_id,purpose,currency,revision desc);
create index settlement_policy_creator_idx on public.settlement_policy_revisions(created_by);

create table public.payment_checkouts(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 actor_person_id uuid references public.people(id),intent_id uuid references public.fundraising_intents(id),
 purpose text not null check(purpose in('fees','fundraising')),currency text not null check(currency~'^[A-Z]{3}$'),
 account_id uuid not null,routing_id uuid not null references public.payment_routing_revisions(id),
 policy_id uuid references public.settlement_policy_revisions(id),
 method text not null check(method in('card','ach')),wallet_id uuid references public.boss_bucks_wallets(id),
 principal_minor bigint not null check(principal_minor between 1 and 1000000000),
 bucks_minor bigint not null default 0 check(bucks_minor between 0 and 1000000000),
 external_minor bigint not null check(external_minor between 1 and 1000000000),
 donor_covered_fee_minor bigint not null default 0 check(donor_covered_fee_minor between 0 and 1000000000),
 platform_fee_minor bigint not null default 0 check(platform_fee_minor between 0 and 1000000000),
 request_id uuid not null unique,command_hash text not null check(command_hash~'^[a-f0-9]{64}$'),
 capability_digest text unique check(capability_digest~'^[a-f0-9]{64}$'),
 state text not null default 'ready' check(state in('ready','external_pending','unknown','authorized','ach_pending','completed','captured_unallocated','failed','canceled','expired','partially_refunded','refunded')),
 expires_at timestamptz not null, created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,account_id) references public.processing_accounts(organization_id,id),
 unique(organization_id,id),
 check(principal_minor+donor_covered_fee_minor+platform_fee_minor=bucks_minor+external_minor),
 check((purpose='fundraising')=(intent_id is not null)),check(purpose<>'fees' or actor_person_id is not null),
 check((actor_person_id is null)=(capability_digest is not null)),check(bucks_minor=0 or wallet_id is not null and purpose='fees'),
 check(isfinite(expires_at) and expires_at>created_at and expires_at<=created_at+interval'30 minutes'));
create index payment_checkouts_org_page_idx on public.payment_checkouts(organization_id,created_at desc,id);
create index payment_checkouts_actor_page_idx on public.payment_checkouts(actor_person_id,created_at desc,id);
create index payment_checkouts_intent_idx on public.payment_checkouts(intent_id);
create unique index payment_checkouts_intent_open_idx on public.payment_checkouts(intent_id) where state in('ready','external_pending','unknown','authorized','ach_pending','completed','captured_unallocated','partially_refunded','refunded');
create index payment_checkouts_account_idx on public.payment_checkouts(organization_id,account_id);
create index payment_checkouts_routing_idx on public.payment_checkouts(routing_id);
create index payment_checkouts_policy_idx on public.payment_checkouts(policy_id);
create index payment_checkouts_wallet_idx on public.payment_checkouts(wallet_id);
create index payment_checkouts_expiry_idx on public.payment_checkouts(expires_at,id) where state in('ready','external_pending','unknown','authorized','ach_pending');
create table public.checkout_charge_allocations(
 checkout_id uuid not null,organization_id uuid not null,charge_id uuid not null,
 principal_minor bigint not null check(principal_minor between 1 and 1000000000),
 bucks_minor bigint not null check(bucks_minor between 0 and principal_minor),
 primary key(checkout_id,charge_id),
 foreign key(organization_id,checkout_id) references public.payment_checkouts(organization_id,id),
 foreign key(organization_id,charge_id) references public.charges(organization_id,id));
create index checkout_charge_allocations_org_checkout_idx on public.checkout_charge_allocations(organization_id,checkout_id);
create index checkout_charge_allocations_charge_idx on public.checkout_charge_allocations(organization_id,charge_id,checkout_id);
create table public.boss_bucks_checkout_reservations(
 checkout_id uuid not null references public.payment_checkouts(id),grant_id uuid not null references public.boss_bucks_grants(id),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000),primary key(checkout_id,grant_id));
create index boss_bucks_checkout_reservations_grant_idx on public.boss_bucks_checkout_reservations(grant_id,checkout_id) include(amount_minor);
create table public.payment_checkout_events(
 id uuid primary key default gen_random_uuid(),checkout_id uuid not null references public.payment_checkouts(id),
 kind text not null check(kind in('ready','dispatch','unknown','authorized','ach_pending','completed','captured_unallocated','failed','canceled','expired','refund','release')),
 operation_id uuid,created_at timestamptz not null default clock_timestamp());
create index payment_checkout_events_checkout_idx on public.payment_checkout_events(checkout_id,created_at,id);

create table public.provider_operations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 checkout_id uuid not null,account_id uuid not null,
 kind text not null check(kind in('sale','authorize','capture','void','refund','save_profile','revoke_profile')),
 parent_operation_id uuid references public.provider_operations(id),request_id uuid not null unique,
 provider_request_reference text not null check(provider_request_reference~'^[a-z0-9]{20}$'),
 amount_minor bigint not null check(amount_minor between 0 and 1000000000),currency text not null check(currency~'^[A-Z]{3}$'),
 state text not null default 'prepared' check(state in('prepared','dispatched','unknown','authorized','ach_pending','succeeded','failed','voided')),
 provider_transaction_reference text check(length(provider_transaction_reference) between 1 and 100),
 dispatched_at timestamptz,created_at timestamptz not null default clock_timestamp(),
 unique(account_id,provider_request_reference),unique(organization_id,id),
 foreign key(organization_id,checkout_id) references public.payment_checkouts(organization_id,id),
 foreign key(organization_id,account_id) references public.processing_accounts(organization_id,id));
create index provider_operations_checkout_idx on public.provider_operations(organization_id,checkout_id,id);
create index provider_operations_account_idx on public.provider_operations(organization_id,account_id,state,id);
create index provider_operations_parent_idx on public.provider_operations(parent_operation_id);
create unique index provider_operations_primary_idx on public.provider_operations(checkout_id) where kind in('sale','authorize');
create unique index provider_operations_transaction_idx on public.provider_operations(account_id,provider_transaction_reference) where kind in('sale','authorize') and provider_transaction_reference is not null;
create table public.provider_event_evidence(
 id uuid primary key default gen_random_uuid(),account_id uuid not null references public.processing_accounts(id),
 operation_id uuid references public.provider_operations(id),event_reference text not null check(length(event_reference) between 1 and 200),
 kind text not null check(kind in('authorized','captured','settled','ach_pending','returned','failed','voided','refunded','disputed','dispute_won','unknown','batch')),
 transaction_reference text not null check(length(transaction_reference) between 1 and 100),
 amount_minor bigint not null check(amount_minor between 0 and 1000000000),currency text not null check(currency~'^[A-Z]{3}$'),
 occurred_at timestamptz not null,body_digest text not null check(body_digest~'^[a-f0-9]{64}$'),
 safe_metadata jsonb not null default '{}' check(jsonb_typeof(safe_metadata)='object'),
 created_at timestamptz not null default clock_timestamp(),unique(account_id,event_reference),
 check(isfinite(occurred_at) and occurred_at<=created_at+interval'5 minutes'));
create index provider_event_evidence_operation_idx on public.provider_event_evidence(operation_id,created_at,id);
create index provider_event_evidence_transaction_idx on public.provider_event_evidence(account_id,transaction_reference,occurred_at,id);

alter table public.payments drop constraint payments_method_check;
alter table public.payments add constraint payments_method_check check(method in('cash','check','boss_bucks','card','ach'));
-- Guest fundraising has an existing canonical donor identity, not a fabricated
-- Boss person. Earlier payment methods still require their existing actor/payer.
alter table public.payments alter column payer_person_id drop not null;
alter table public.payments alter column recorded_by_person_id drop not null;
alter table public.payments add column fundraising_intent_id uuid references public.fundraising_intents(id);
alter table public.payments add constraint payments_payer_boundary check(
 method in('card','ach') and (payer_person_id is not null or fundraising_intent_id is not null)
 or method in('cash','check','boss_bucks') and payer_person_id is not null and recorded_by_person_id is not null and fundraising_intent_id is null);
create index payments_fundraising_intent_idx on public.payments(fundraising_intent_id);
create table public.external_payment_tenders(
 payment_id uuid primary key references public.payments(id),organization_id uuid not null,
 checkout_id uuid not null,operation_id uuid not null references public.provider_operations(id),
 event_id uuid not null references public.provider_event_evidence(id),
 original_payment_id uuid references public.external_payment_tenders(payment_id),
 purpose text not null check(purpose in('fees','fundraising','unallocated')),
 created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,payment_id) references public.payments(organization_id,id),
 foreign key(organization_id,checkout_id) references public.payment_checkouts(organization_id,id));
create index external_payment_tenders_checkout_idx on public.external_payment_tenders(organization_id,checkout_id,payment_id);
create index external_payment_tenders_payment_org_idx on public.external_payment_tenders(organization_id,payment_id);
create index external_payment_tenders_operation_idx on public.external_payment_tenders(operation_id);
create index external_payment_tenders_event_idx on public.external_payment_tenders(event_id);
create index external_payment_tenders_original_idx on public.external_payment_tenders(original_payment_id);
create unique index external_payment_tenders_primary_operation_idx on public.external_payment_tenders(operation_id) where original_payment_id is null;

create table public.saved_payment_methods(
 id uuid primary key default gen_random_uuid(),account_id uuid not null references public.processing_accounts(id),
 person_id uuid references public.people(id),donor_id uuid references public.fundraising_donors(id),
 customer_reference text not null check(length(customer_reference) between 1 and 100),
 profile_reference text not null check(length(profile_reference) between 1 and 100),
 method text not null check(method in('card','ach')),brand text check(length(brand)<=30),last_four text check(last_four~'^[0-9]{4}$'),
 expires_month integer check(expires_month between 1 and 12),expires_year integer check(expires_year between 2020 and 2200),
 revoked_at timestamptz,created_at timestamptz not null default clock_timestamp(),
 check(num_nonnulls(person_id,donor_id)=1),unique(account_id,customer_reference,profile_reference));
create index saved_payment_methods_person_idx on public.saved_payment_methods(person_id,account_id);
create index saved_payment_methods_donor_idx on public.saved_payment_methods(donor_id,account_id);
create table public.payment_execution_consents(
 id uuid primary key default gen_random_uuid(),person_id uuid references public.people(id),donor_id uuid references public.fundraising_donors(id),
 method_id uuid not null references public.saved_payment_methods(id),plan_id uuid references public.payment_plans(id),
 recurring_commitment_id uuid references public.fundraising_recurring_commitments(id),starts_at timestamptz not null,ends_at timestamptz,
 revoked_at timestamptz,created_at timestamptz not null default clock_timestamp(),
 check(num_nonnulls(person_id,donor_id)=1),check(num_nonnulls(plan_id,recurring_commitment_id)=1),
 check(isfinite(starts_at) and(ends_at is null or isfinite(ends_at) and ends_at>starts_at)));
create index payment_execution_consents_person_idx on public.payment_execution_consents(person_id);
create index payment_execution_consents_donor_idx on public.payment_execution_consents(donor_id);
create index payment_execution_consents_method_idx on public.payment_execution_consents(method_id);
create index payment_execution_consents_plan_idx on public.payment_execution_consents(plan_id);
create index payment_execution_consents_recurring_idx on public.payment_execution_consents(recurring_commitment_id);
create table public.payment_recurring_work(
 id uuid primary key default gen_random_uuid(),consent_id uuid not null references public.payment_execution_consents(id),
 commitment_id uuid not null,ordinal integer not null,checkout_id uuid references public.payment_checkouts(id),
 state text not null default 'inactive' check(state in('inactive','ready','claimed','completed','failed','canceled')),
 created_at timestamptz not null default clock_timestamp(),
 foreign key(commitment_id,ordinal) references public.fundraising_recurring_occurrences(commitment_id,ordinal),
 unique(commitment_id,ordinal));
create index payment_recurring_work_consent_idx on public.payment_recurring_work(consent_id);
create index payment_recurring_work_checkout_idx on public.payment_recurring_work(checkout_id);

create table boss_private.payment_requests(
 request_id uuid primary key,actor_id uuid references public.people(id),command jsonb not null,result jsonb not null,
 created_at timestamptz not null default clock_timestamp());
create index payment_requests_actor_idx on boss_private.payment_requests(actor_id,created_at);
create table public.payment_history(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 actor_id uuid references public.people(id),action text not null check(length(action) between 1 and 80),
 resource_id uuid,request_id uuid,details jsonb not null default '{}',created_at timestamptz not null default clock_timestamp());
create index payment_history_org_idx on public.payment_history(organization_id,created_at desc,id);
create index payment_history_actor_idx on public.payment_history(actor_id);

do $$declare t text;begin
 foreach t in array array['processing_accounts','payment_routing_revisions','payment_routing_events','settlement_policy_revisions','payment_checkouts','checkout_charge_allocations','boss_bucks_checkout_reservations','payment_checkout_events','provider_operations','provider_event_evidence','external_payment_tenders','saved_payment_methods','payment_execution_consents','payment_recurring_work','payment_history']loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);
 if t not in('processing_accounts','payment_checkouts','provider_operations','saved_payment_methods','payment_execution_consents','payment_recurring_work')then
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);end if;
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);
 end loop;
end$$;
alter table boss_private.processing_bindings enable row level security;
alter table boss_private.payment_requests enable row level security;
revoke all on boss_private.processing_bindings,boss_private.payment_requests from public,anon,authenticated,service_role,boss_payment_worker;
