-- Additive, deployment-independent contracts. No production brand binding or rate is seeded.
create table public.fundraising_brands(
 id uuid primary key default gen_random_uuid(),key text not null unique check(key~'^[a-z][a-z0-9_]{1,63}$'),
 name text not null check(length(btrim(name)) between 1 and 120),created_by uuid references public.people(id),
 created_at timestamptz not null default clock_timestamp());
create index fundraising_brands_creator_idx on public.fundraising_brands(created_by);
-- Current deployment's established brand; no financial rate or foreign deployment is activated.
insert into public.fundraising_brands(key,name)values('the_boss','The Boss');
create table public.fundraising_campaign_origins(
 campaign_id uuid primary key,organization_id uuid not null,brand_id uuid not null references public.fundraising_brands(id),
 legal_recipient_organization_id uuid not null references public.organizations(id),
 fund_code text not null check(length(btrim(fund_code)) between 1 and 100 and fund_code!~'[[:cntrl:]]'),
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 check(legal_recipient_organization_id=organization_id));
create index fundraising_origin_brand_idx on public.fundraising_campaign_origins(brand_id,campaign_id);
create index fundraising_origin_org_idx on public.fundraising_campaign_origins(organization_id,campaign_id);
create index fundraising_origin_recipient_idx on public.fundraising_campaign_origins(legal_recipient_organization_id);
create index fundraising_origin_creator_idx on public.fundraising_campaign_origins(created_by);
create table public.fundraising_destinations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,campaign_id uuid not null,
 kind text not null check(kind in('organization','team','ministry','project')),
 team_id uuid,unit_id uuid,board_id uuid references public.money_boards(id),
 fundraiser_id uuid,referrer_person_id uuid references public.people(id),
 public_path text not null unique default left(replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''),48) check(public_path~'^[a-f0-9]{48}$'),
 goal_minor bigint not null check(goal_minor between 1 and 1000000000000),
 status text not null default 'draft' check(status in('draft','published','archived')),
 starts_at timestamptz not null default clock_timestamp(),ends_at timestamptz,
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 foreign key(organization_id,team_id)references public.teams(organization_id,id),
 foreign key(organization_id,unit_id)references public.organization_units(organization_id,id),
 foreign key(campaign_id,fundraiser_id)references public.fundraising_fundraisers(campaign_id,id),
 unique(organization_id,campaign_id,id),
 check(case kind when 'organization' then num_nonnulls(team_id,unit_id)=0 when 'team' then team_id is not null and unit_id is null else unit_id is not null and team_id is null end),
 check(isfinite(starts_at)and(ends_at is null or isfinite(ends_at)and ends_at>starts_at)));
create index fundraising_destinations_scope_idx on public.fundraising_destinations(organization_id,campaign_id,team_id,unit_id,id);
create index fundraising_destinations_board_idx on public.fundraising_destinations(board_id);
create index fundraising_destinations_fundraiser_idx on public.fundraising_destinations(fundraiser_id);
create index fundraising_destinations_referrer_idx on public.fundraising_destinations(referrer_person_id);
create index fundraising_destinations_creator_idx on public.fundraising_destinations(created_by);
create table public.fundraising_platform_policies(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 campaign_id uuid,channel text not null check(channel in('money_board','direct_support','digital_card','physical_card')),
 currency text not null check(currency~'^[A-Z]{3}$'),revision bigint not null check(revision>0),
 settlement_policy_id uuid not null references public.settlement_policy_revisions(id),
 product_revision_id uuid references public.discount_product_revisions(id),
 agreement_reference text not null check(length(btrim(agreement_reference)) between 1 and 100 and agreement_reference!~'[[:cntrl:]]'),
 exception_reference text check(length(btrim(exception_reference)) between 1 and 100 and exception_reference!~'[[:cntrl:]]'),
 participant_credit_max_bps integer not null check(participant_credit_max_bps between 0 and 10000),
 wallet_permitted boolean not null default false,
 starts_at timestamptz not null,ends_at timestamptz,created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 unique nulls not distinct(organization_id,campaign_id,channel,currency,revision),unique(organization_id,id),
 check((channel in('digital_card','physical_card'))=(product_revision_id is not null)),
 check(isfinite(starts_at)and(ends_at is null or isfinite(ends_at)and ends_at>starts_at)));
create index fundraising_platform_policy_match_idx on public.fundraising_platform_policies(organization_id,channel,currency,campaign_id,revision desc);
create index fundraising_platform_policy_settlement_idx on public.fundraising_platform_policies(settlement_policy_id);
create index fundraising_platform_policy_product_idx on public.fundraising_platform_policies(product_revision_id);
create index fundraising_platform_policy_creator_idx on public.fundraising_platform_policies(created_by);
create table public.fundraising_allocation_delegations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,campaign_id uuid not null,
 person_id uuid not null references public.people(id),team_id uuid,unit_id uuid,
 starts_at timestamptz not null,ends_at timestamptz not null,revoked_at timestamptz,
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 foreign key(organization_id,team_id)references public.teams(organization_id,id),foreign key(organization_id,unit_id)references public.organization_units(organization_id,id),
 check(num_nonnulls(team_id,unit_id)=1),check(isfinite(starts_at)and isfinite(ends_at)and ends_at>starts_at));
create index fundraising_allocation_delegate_idx on public.fundraising_allocation_delegations(person_id,campaign_id,team_id,unit_id,ends_at);
create index fundraising_allocation_delegate_org_idx on public.fundraising_allocation_delegations(organization_id,campaign_id);
create index fundraising_allocation_delegate_team_idx on public.fundraising_allocation_delegations(team_id);
create index fundraising_allocation_delegate_unit_idx on public.fundraising_allocation_delegations(unit_id);
create index fundraising_allocation_delegate_creator_idx on public.fundraising_allocation_delegations(created_by);
create table public.fundraising_allocation_policies(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,campaign_id uuid not null,
 platform_policy_id uuid not null,channel text not null check(channel in('money_board','direct_support','digital_card','physical_card')),
 team_id uuid,unit_id uuid,revision bigint not null check(revision>0),
 organization_bps integer not null check(organization_bps between 0 and 10000),
 destination_bps integer not null check(destination_bps between 0 and 10000),
 participant_bps integer not null check(participant_bps between 0 and 10000),
 basis text not null default 'verified_organization_allocation' check(basis='verified_organization_allocation'),
 accounting_kind text not null default 'noncash_designation' check(accounting_kind='noncash_designation'),
 starts_at timestamptz not null,ends_at timestamptz,created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 foreign key(organization_id,platform_policy_id)references public.fundraising_platform_policies(organization_id,id),
 foreign key(organization_id,team_id)references public.teams(organization_id,id),foreign key(organization_id,unit_id)references public.organization_units(organization_id,id),
 unique nulls not distinct(campaign_id,channel,team_id,unit_id,revision),unique(organization_id,id),
 check(num_nonnulls(team_id,unit_id)<=1),check(organization_bps+destination_bps+participant_bps=10000),
 check(destination_bps=0 or num_nonnulls(team_id,unit_id)=1),
 check(isfinite(starts_at)and(ends_at is null or isfinite(ends_at)and ends_at>starts_at)));
create index fundraising_allocation_policy_match_idx on public.fundraising_allocation_policies(campaign_id,channel,team_id,unit_id,revision desc);
create index fundraising_allocation_policy_platform_idx on public.fundraising_allocation_policies(organization_id,platform_policy_id);
create index fundraising_allocation_policy_team_idx on public.fundraising_allocation_policies(team_id);
create index fundraising_allocation_policy_unit_idx on public.fundraising_allocation_policies(unit_id);
create index fundraising_allocation_policy_creator_idx on public.fundraising_allocation_policies(created_by);
create table public.fundraising_wallet_channel_policies(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,campaign_id uuid not null,
 channel text not null check(channel in('money_board','direct_support')),
 wallet_policy_id uuid not null references public.boss_bucks_policy_revisions(id),revision bigint not null check(revision>0),
 starts_at timestamptz not null,ends_at timestamptz,created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 unique(campaign_id,channel,revision),check(isfinite(starts_at)and(ends_at is null or isfinite(ends_at)and ends_at>starts_at)));
create index fundraising_wallet_channel_match_idx on public.fundraising_wallet_channel_policies(campaign_id,channel,revision desc);
create index fundraising_wallet_channel_policy_idx on public.fundraising_wallet_channel_policies(wallet_policy_id);
create index fundraising_wallet_channel_creator_idx on public.fundraising_wallet_channel_policies(created_by);
create table public.fundraising_checkout_snapshots(
 checkout_id uuid primary key references public.payment_checkouts(id),organization_id uuid not null,campaign_id uuid not null,
 brand_id uuid not null references public.fundraising_brands(id),destination_id uuid,
 channel text not null check(channel in('money_board','direct_support','digital_card','physical_card')),
 intent_id uuid references public.fundraising_intents(id),product_order_id uuid references public.discount_orders(id),
 fundraiser_id uuid,participant_id uuid references public.participants(id),credited_person_id uuid references public.people(id),
 origin_person_id uuid references public.people(id),referrer_person_id uuid references public.people(id),team_id uuid,unit_id uuid,
 fund_code text,platform_policy_id uuid,allocation_policy_id uuid,
 account_id uuid not null,routing_id uuid not null references public.payment_routing_revisions(id),
 settlement_policy_id uuid references public.settlement_policy_revisions(id),currency text not null,
 principal_minor bigint not null check(principal_minor between 1 and 1000000000),snapshot_version int not null default 1 check(snapshot_version=1),
 provenance jsonb not null check(jsonb_typeof(provenance)='object'and octet_length(provenance::text)<=8192),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 foreign key(campaign_id,fundraiser_id)references public.fundraising_fundraisers(campaign_id,id),
 foreign key(organization_id,campaign_id,destination_id)references public.fundraising_destinations(organization_id,campaign_id,id),
 foreign key(organization_id,team_id)references public.teams(organization_id,id),foreign key(organization_id,unit_id)references public.organization_units(organization_id,id),
 foreign key(organization_id,platform_policy_id)references public.fundraising_platform_policies(organization_id,id),
 foreign key(organization_id,allocation_policy_id)references public.fundraising_allocation_policies(organization_id,id),
 foreign key(organization_id,account_id)references public.processing_accounts(organization_id,id),
 check(num_nonnulls(intent_id,product_order_id)=1),check(channel in('money_board','direct_support')=(intent_id is not null)));
create index fundraising_checkout_report_idx on public.fundraising_checkout_snapshots(organization_id,campaign_id,channel,team_id,unit_id,checkout_id);
create index fundraising_checkout_origin_idx on public.fundraising_checkout_snapshots(brand_id,campaign_id);
create index fundraising_checkout_destination_idx on public.fundraising_checkout_snapshots(destination_id);
create index fundraising_checkout_intent_idx on public.fundraising_checkout_snapshots(intent_id);
create index fundraising_checkout_order_idx on public.fundraising_checkout_snapshots(product_order_id);
create index fundraising_checkout_participant_idx on public.fundraising_checkout_snapshots(participant_id,campaign_id,checkout_id);
create index fundraising_checkout_credited_idx on public.fundraising_checkout_snapshots(credited_person_id);
create index fundraising_checkout_actor_idx on public.fundraising_checkout_snapshots(origin_person_id);
create index fundraising_checkout_referrer_idx on public.fundraising_checkout_snapshots(referrer_person_id,campaign_id);
create index fundraising_checkout_platform_idx on public.fundraising_checkout_snapshots(platform_policy_id);
create index fundraising_checkout_allocation_idx on public.fundraising_checkout_snapshots(allocation_policy_id);
create index fundraising_checkout_route_idx on public.fundraising_checkout_snapshots(routing_id);
create index fundraising_checkout_settlement_idx on public.fundraising_checkout_snapshots(settlement_policy_id);
create index fundraising_checkout_account_idx on public.fundraising_checkout_snapshots(organization_id,account_id);
create table public.fundraising_credit_sources(
 payment_id uuid primary key references public.settlement_sources(payment_id),checkout_id uuid not null references public.fundraising_checkout_snapshots(checkout_id),
 organization_id uuid not null,campaign_id uuid not null,policy_id uuid not null,
 currency text not null,original_minor bigint not null check(original_minor between 0 and 1000000000),
 accounting_kind text not null default 'noncash_designation'check(accounting_kind='noncash_designation'),
 created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 foreign key(organization_id,policy_id)references public.fundraising_allocation_policies(organization_id,id));
create index fundraising_credit_sources_report_idx on public.fundraising_credit_sources(organization_id,campaign_id,payment_id);
create index fundraising_credit_sources_checkout_idx on public.fundraising_credit_sources(checkout_id);
create index fundraising_credit_sources_policy_idx on public.fundraising_credit_sources(organization_id,policy_id);
create table public.fundraising_credit_entries(
 id uuid primary key default gen_random_uuid(),payment_id uuid not null references public.fundraising_credit_sources(payment_id),
 correction_id uuid references public.external_payment_corrections(reversal_payment_id),
 category text not null check(category in('organization_designation','team_designation','unit_designation','participant_credit')),
 beneficiary_id uuid not null,amount_minor bigint not null check(amount_minor<>0 and amount_minor between -1000000000 and 1000000000),
 algorithm text not null check(algorithm='hamilton_original_cumulative_v1'),created_at timestamptz not null default clock_timestamp(),
 unique nulls not distinct(payment_id,correction_id,category,beneficiary_id),
 check((correction_id is null and amount_minor>0)or(correction_id is not null and amount_minor<0)));
create index fundraising_credit_entries_source_idx on public.fundraising_credit_entries(payment_id,category,beneficiary_id)include(amount_minor);
create index fundraising_credit_entries_correction_idx on public.fundraising_credit_entries(correction_id);
create table boss_private.fundraising_allocation_requests(
 request_id uuid primary key,actor_id uuid not null references public.people(id),command jsonb not null,result jsonb not null,
 created_at timestamptz not null default clock_timestamp());
create index fundraising_allocation_requests_actor_idx on boss_private.fundraising_allocation_requests(actor_id);
do $$declare t text;begin
 foreach t in array array['fundraising_brands','fundraising_campaign_origins','fundraising_destinations','fundraising_platform_policies','fundraising_allocation_delegations','fundraising_allocation_policies','fundraising_wallet_channel_policies','fundraising_checkout_snapshots','fundraising_credit_sources','fundraising_credit_entries']loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);
  if t not in('fundraising_destinations','fundraising_allocation_delegations')then
   execute format('create trigger immutable_%I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t,t);
  else
   execute format('create trigger immutable_%I before delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t,t);
  end if;
  execute format('create trigger immutable_truncate_%I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t,t);
 end loop;
end$$;
create trigger fundraising_destination_identity before update on public.fundraising_destinations for each row execute function boss_private.preserve_row_identity('id','organization_id','campaign_id','kind','team_id','unit_id','board_id','fundraiser_id','referrer_person_id','public_path','goal_minor','starts_at','ends_at','created_by','created_at');
create trigger fundraising_delegation_identity before update on public.fundraising_allocation_delegations for each row execute function boss_private.preserve_row_identity('id','organization_id','campaign_id','person_id','team_id','unit_id','starts_at','ends_at','created_by','created_at');
alter table boss_private.fundraising_allocation_requests enable row level security;
revoke all on boss_private.fundraising_allocation_requests from public,anon,authenticated,service_role,boss_payment_worker;
create trigger immutable_allocation_requests before update or delete on boss_private.fundraising_allocation_requests for each row execute function boss_private.reject_audit_rewrite();
create trigger immutable_truncate_allocation_requests before truncate on boss_private.fundraising_allocation_requests execute function boss_private.reject_audit_rewrite();

create function boss_private.fundraising_delegation_revoke_guard()returns trigger language plpgsql set search_path=''as $$begin
 if old.revoked_at is not null and new.revoked_at is distinct from old.revoked_at or new.revoked_at is not null and(not isfinite(new.revoked_at)or new.revoked_at>clock_timestamp())then raise exception'Immutable revocation'using errcode='23514';end if;return new;end$$;
create trigger fundraising_delegation_revoke before update on public.fundraising_allocation_delegations for each row execute function boss_private.fundraising_delegation_revoke_guard();
revoke all on function boss_private.fundraising_delegation_revoke_guard()from public,anon,authenticated,service_role,boss_payment_worker;

-- Composite tenant foreign keys have matching leading-column indexes.
create index fundraising_destinations_org_team_idx on public.fundraising_destinations(organization_id,team_id);
create index fundraising_destinations_org_unit_idx on public.fundraising_destinations(organization_id,unit_id);
create index fundraising_destinations_campaign_fundraiser_idx on public.fundraising_destinations(campaign_id,fundraiser_id);
create index fundraising_platform_policy_org_campaign_idx on public.fundraising_platform_policies(organization_id,campaign_id);
create index fundraising_allocation_delegate_org_team_idx on public.fundraising_allocation_delegations(organization_id,team_id);
create index fundraising_allocation_delegate_org_unit_idx on public.fundraising_allocation_delegations(organization_id,unit_id);
create index fundraising_allocation_policy_org_campaign_idx on public.fundraising_allocation_policies(organization_id,campaign_id);
create index fundraising_allocation_policy_org_team_idx on public.fundraising_allocation_policies(organization_id,team_id);
create index fundraising_allocation_policy_org_unit_idx on public.fundraising_allocation_policies(organization_id,unit_id);
create index fundraising_wallet_channel_org_campaign_idx on public.fundraising_wallet_channel_policies(organization_id,campaign_id);
create index fundraising_checkout_campaign_fundraiser_idx on public.fundraising_checkout_snapshots(campaign_id,fundraiser_id);
create index fundraising_checkout_exact_destination_idx on public.fundraising_checkout_snapshots(organization_id,campaign_id,destination_id);
create index fundraising_checkout_org_team_idx on public.fundraising_checkout_snapshots(organization_id,team_id);
create index fundraising_checkout_org_unit_idx on public.fundraising_checkout_snapshots(organization_id,unit_id);
create index fundraising_checkout_org_platform_idx on public.fundraising_checkout_snapshots(organization_id,platform_policy_id);
create index fundraising_checkout_org_allocation_idx on public.fundraising_checkout_snapshots(organization_id,allocation_policy_id);
