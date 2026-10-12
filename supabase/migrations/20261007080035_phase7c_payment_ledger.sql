-- Phase 7C: extend existing canonical payment and organization-restricted ledger.
alter table public.payments drop constraint payments_method_check;
alter table public.payments add constraint payments_method_check check(method in('cash','check','boss_bucks'));
insert into public.permissions(key,name,description)values
 ('boss_bucks.payment_reverse','Reverse Boss Bucks payments','Append authorized own-organization internal payment reversals');
insert into public.role_permissions(role_id,permission_id)
 select r.id,p.id from public.roles r cross join public.permissions p where p.key='boss_bucks.payment_reverse'
 and r.key in('super_administrator','platform_administrator','organization_owner','organization_administrator','finance','organization_finance');

alter table public.boss_bucks_accounts drop constraint boss_bucks_accounts_kind_check;
alter table public.boss_bucks_accounts drop constraint boss_bucks_accounts_check;
alter table public.boss_bucks_accounts add constraint boss_bucks_accounts_kind_check check(kind in('household','clearing','redemption','recovery'));
alter table public.boss_bucks_accounts add constraint boss_bucks_accounts_context_check check(
 (kind in('household','recovery')and wallet_id is not null and household_id is not null)
 or(kind in('clearing','redemption')and wallet_id is null and household_id is null));
create unique index boss_bucks_redemption_idx on public.boss_bucks_accounts(organization_id,currency)where kind='redemption';
create unique index boss_bucks_recovery_idx on public.boss_bucks_accounts(wallet_id,organization_id,currency)where kind='recovery';

alter table public.boss_bucks_journals drop constraint boss_bucks_journals_kind_check;
alter table public.boss_bucks_journals add constraint boss_bucks_journals_kind_check check(kind in(
 'issuance','reversal','expiration','spend','payment_restore','recovery_open','recovery_apply','recovery_cancel','recovery_cancel_source','recovery_release'));
alter table public.boss_bucks_journals add column amount_minor bigint check(amount_minor between 1 and 1000000000000);
drop index public.boss_bucks_journal_end_idx;

-- One tender is a group of balanced per-grant journals, linked both ways through
-- immutable allocation slices. No synthetic blended tender/provider record.
create table public.boss_bucks_tenders(
 payment_id uuid primary key references public.payments(id),wallet_id uuid not null references public.boss_bucks_wallets(id),
 organization_id uuid not null references public.organizations(id),currency text not null check(currency~'^[A-Z]{3}$'),
 actor_person_id uuid not null references public.people(id),request_id uuid not null unique,checkout_id uuid not null,
 original_payment_id uuid references public.boss_bucks_tenders(payment_id),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,payment_id)references public.payments(organization_id,id));
create index boss_bucks_tender_wallet_idx on public.boss_bucks_tenders(wallet_id,created_at desc,payment_id);
create index boss_bucks_tender_org_idx on public.boss_bucks_tenders(organization_id,created_at desc,payment_id);
create index boss_bucks_tender_payment_context_idx on public.boss_bucks_tenders(organization_id,payment_id);
create index boss_bucks_tender_actor_idx on public.boss_bucks_tenders(actor_person_id);
create index boss_bucks_tender_original_idx on public.boss_bucks_tenders(original_payment_id);
create index boss_bucks_tender_checkout_idx on public.boss_bucks_tenders(checkout_id);
create table public.boss_bucks_consumptions(
 id uuid primary key default gen_random_uuid(),allocation_id uuid not null references public.payment_allocations(id),
 grant_id uuid not null references public.boss_bucks_grants(id),journal_id uuid not null references public.boss_bucks_journals(id),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000),ordinal integer not null check(ordinal between 1 and 250),
 created_at timestamptz not null default clock_timestamp(),unique(allocation_id,grant_id));
create index boss_bucks_consumption_grant_idx on public.boss_bucks_consumptions(grant_id,id)include(amount_minor);
create index boss_bucks_consumption_journal_idx on public.boss_bucks_consumptions(journal_id);
create table public.boss_bucks_restorations(
 id uuid primary key default gen_random_uuid(),consumption_id uuid not null references public.boss_bucks_consumptions(id),
 allocation_id uuid not null references public.payment_allocations(id),journal_id uuid not null unique references public.boss_bucks_journals(id),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000),created_at timestamptz not null default clock_timestamp());
create index boss_bucks_restoration_consumption_idx on public.boss_bucks_restorations(consumption_id)include(amount_minor);
create index boss_bucks_restoration_allocation_idx on public.boss_bucks_restorations(allocation_id);

-- Corrections capture cumulative remaining gross source; clients cannot submit
-- corrections or mint grants. The private source boundary remains closed.
alter table public.fundraising_intent_events add column remaining_valid_amount_minor bigint check(remaining_valid_amount_minor>=0);
create table public.boss_bucks_source_corrections(
 id uuid primary key default gen_random_uuid(),grant_id uuid not null references public.boss_bucks_grants(id),
 source_event_id uuid unique references public.fundraising_intent_events(id),source_key text not null check(length(source_key)between 1 and 200),
 remaining_source_minor bigint not null check(remaining_source_minor>=0),entitlement_minor bigint not null check(entitlement_minor>=0),
 created_at timestamptz not null default clock_timestamp(),unique(grant_id,source_key));
create index boss_bucks_source_correction_latest_idx on public.boss_bucks_source_corrections(grant_id,created_at desc,id);
create table public.boss_bucks_recovery_claims(
 id uuid primary key default gen_random_uuid(),grant_id uuid not null unique references public.boss_bucks_grants(id),
 created_at timestamptz not null default clock_timestamp());
create table public.boss_bucks_recovery_movements(
 id uuid primary key default gen_random_uuid(),claim_id uuid not null references public.boss_bucks_recovery_claims(id),
 kind text not null check(kind in('open','apply','cancel','release')),amount_minor bigint not null check(amount_minor between 1 and 1000000000000),
 replacement_grant_id uuid references public.boss_bucks_grants(id),journal_id uuid not null unique references public.boss_bucks_journals(id),
 payment_reversal_id uuid references public.boss_bucks_tenders(payment_id),
 cause_release_id uuid references public.boss_bucks_recovery_movements(id),
 invalid_release_journal_id uuid references public.boss_bucks_journals(id),
 original_movement_id uuid references public.boss_bucks_recovery_movements(id),created_at timestamptz not null default clock_timestamp(),
 check((kind in('apply','release'))=(replacement_grant_id is not null)),check((kind='release')=(original_movement_id is not null)),
 check((kind in('cancel','release'))=(payment_reversal_id is not null)),
 check((cause_release_id is null)=(invalid_release_journal_id is null)),
 check(cause_release_id is null or kind='cancel'));
create index boss_bucks_recovery_claim_moves_idx on public.boss_bucks_recovery_movements(claim_id,created_at,id)include(amount_minor,kind);
create index boss_bucks_recovery_replacement_idx on public.boss_bucks_recovery_movements(replacement_grant_id,created_at,id);
create index boss_bucks_recovery_original_idx on public.boss_bucks_recovery_movements(original_movement_id);
create index boss_bucks_recovery_payment_idx on public.boss_bucks_recovery_movements(payment_reversal_id);
create index boss_bucks_recovery_cause_idx on public.boss_bucks_recovery_movements(cause_release_id);
create unique index boss_bucks_recovery_invalid_release_idx on public.boss_bucks_recovery_movements(invalid_release_journal_id);
create index boss_bucks_grant_fefo_idx on public.boss_bucks_grants(wallet_id,organization_id,expires_at,available_at,created_at,id);

do $$declare t text;begin foreach t in array array['boss_bucks_tenders','boss_bucks_consumptions','boss_bucks_restorations','boss_bucks_source_corrections','boss_bucks_recovery_claims','boss_bucks_recovery_movements']loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);
end loop;end$$;
