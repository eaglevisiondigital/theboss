-- Phase 7B: internal, organization-restricted value only; no spending/provider.
alter table public.guardian_relationships add column can_manage_boss_bucks boolean not null default false;
insert into public.permissions(key,name,description) values
 ('boss_bucks.view','View Boss Bucks','Resource-authorized wallet reporting'),
 ('boss_bucks.manage','Manage Boss Bucks','Explicit resource access configuration'),
 ('boss_bucks.financial_view','View Boss Bucks finance','Own-organization financial slice'),
 ('boss_bucks.policy_manage','Manage Boss Bucks policy','Own-organization earning revisions');
insert into public.role_permissions(role_id,permission_id)
 select r.id,p.id from public.roles r cross join public.permissions p where p.key like 'boss_bucks.%' and
 (r.key in('super_administrator','platform_administrator','organization_owner','organization_administrator')
 or r.key in('finance','organization_finance') and p.key in('boss_bucks.view','boss_bucks.financial_view'));

create table public.boss_bucks_wallets(
 id uuid primary key default gen_random_uuid(),household_id uuid not null references public.households(id),currency text not null check(currency~'^[A-Z]{3}$'),
 status text not null default 'active' check(status in('active','retired')),created_at timestamptz not null default clock_timestamp(),
 unique(household_id,currency),unique(id,household_id,currency));
create table public.boss_bucks_access(
 id uuid primary key default gen_random_uuid(),wallet_id uuid not null references public.boss_bucks_wallets(id),person_id uuid not null references public.people(id),
 guardian_relationship_id uuid not null references public.guardian_relationships(id),organization_id uuid not null references public.organizations(id),access_kind text not null check(access_kind in('manager','viewer')),
 status text not null default 'active' check(status in('active','ended')),starts_at timestamptz not null default clock_timestamp(),ends_at timestamptz,
 created_at timestamptz not null default clock_timestamp(),check(ends_at is null or ends_at>starts_at),unique(wallet_id,person_id,guardian_relationship_id));
create index boss_bucks_access_person_idx on public.boss_bucks_access(person_id,wallet_id,status);
create index boss_bucks_access_guardian_idx on public.boss_bucks_access(guardian_relationship_id);
create index boss_bucks_access_org_idx on public.boss_bucks_access(organization_id);
create table public.boss_bucks_policy_revisions(
 id uuid primary key default gen_random_uuid(),campaign_id uuid not null references public.fundraising_campaigns(id),organization_id uuid not null references public.organizations(id),
 revision bigint not null check(revision>0),mode text not null check(mode in('none','percentage')),basis_points integer not null check(basis_points between 0 and 10000),
 currency text not null check(currency~'^[A-Z]{3}$'),channels text[] not null check(cardinality(channels)>0 and channels<@array['direct_support','money_board']::text[]),
 availability_seconds integer not null default 0 check(availability_seconds between 0 and 31536000),expiry_seconds integer check(expiry_seconds between 1 and 315360000),
 created_at timestamptz not null default clock_timestamp(),created_by uuid not null references public.people(id),request_id uuid not null unique,
 unique(campaign_id,revision),check(mode<>'none' or basis_points=0),check(expiry_seconds is null or expiry_seconds>availability_seconds),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id));
create index boss_bucks_policy_current_idx on public.boss_bucks_policy_revisions(campaign_id,revision desc);
create index boss_bucks_policy_org_campaign_idx on public.boss_bucks_policy_revisions(organization_id,campaign_id);
create table public.boss_bucks_fundraiser_bindings(
 fundraiser_id uuid primary key references public.fundraising_fundraisers(id),household_id uuid not null references public.households(id),
 authorized_by uuid not null references public.people(id),guardian_relationship_id uuid not null references public.guardian_relationships(id),created_at timestamptz not null default clock_timestamp());
create index boss_bucks_binding_household_idx on public.boss_bucks_fundraiser_bindings(household_id);
create index boss_bucks_binding_actor_idx on public.boss_bucks_fundraiser_bindings(authorized_by);
create index boss_bucks_binding_guardian_idx on public.boss_bucks_fundraiser_bindings(guardian_relationship_id);
create table public.boss_bucks_source_snapshots(
 intent_id uuid primary key references public.fundraising_intents(id),policy_revision_id uuid references public.boss_bucks_policy_revisions(id),
 household_id uuid references public.households(id),organization_id uuid not null references public.organizations(id),created_at timestamptz not null default clock_timestamp());
create index boss_bucks_snapshots_policy_idx on public.boss_bucks_source_snapshots(policy_revision_id);
create index boss_bucks_snapshots_household_idx on public.boss_bucks_source_snapshots(household_id);
create index boss_bucks_snapshots_org_idx on public.boss_bucks_source_snapshots(organization_id);
create table public.boss_bucks_owner_resolutions(
 intent_id uuid primary key references public.boss_bucks_source_snapshots(intent_id),household_id uuid not null references public.households(id),
 authorized_by uuid not null references public.people(id),guardian_relationship_id uuid not null references public.guardian_relationships(id),created_at timestamptz not null default clock_timestamp());
create index boss_bucks_owner_household_idx on public.boss_bucks_owner_resolutions(household_id);
create index boss_bucks_owner_actor_idx on public.boss_bucks_owner_resolutions(authorized_by);
create index boss_bucks_owner_guardian_idx on public.boss_bucks_owner_resolutions(guardian_relationship_id);
create table public.boss_bucks_accounts(
 id uuid primary key default gen_random_uuid(),kind text not null check(kind in('household','clearing')),wallet_id uuid,household_id uuid,
 organization_id uuid not null references public.organizations(id),currency text not null check(currency~'^[A-Z]{3}$'),created_at timestamptz not null default clock_timestamp(),
 foreign key(wallet_id,household_id,currency)references public.boss_bucks_wallets(id,household_id,currency),
 check((kind='household' and wallet_id is not null and household_id is not null)or(kind='clearing' and wallet_id is null and household_id is null)));
create unique index boss_bucks_household_bucket_idx on public.boss_bucks_accounts(wallet_id,organization_id,currency)where kind='household';
create unique index boss_bucks_clearing_idx on public.boss_bucks_accounts(organization_id,currency)where kind='clearing';
create index boss_bucks_accounts_org_idx on public.boss_bucks_accounts(organization_id,kind,id);
create index boss_bucks_accounts_wallet_contract_idx on public.boss_bucks_accounts(wallet_id,household_id,currency);
create table public.boss_bucks_grants(
 id uuid primary key default gen_random_uuid(),wallet_id uuid not null,household_id uuid not null,currency text not null,
 organization_id uuid not null references public.organizations(id),account_id uuid not null references public.boss_bucks_accounts(id),
 evidence_id uuid not null unique references public.fundraising_success_evidence(id),intent_id uuid not null references public.boss_bucks_source_snapshots(intent_id),
 policy_revision_id uuid not null references public.boss_bucks_policy_revisions(id),campaign_id uuid not null references public.fundraising_campaigns(id),
 fundraiser_id uuid not null references public.fundraising_fundraisers(id),participant_id uuid not null,person_id uuid not null,
 unit_id uuid,team_id uuid,amount_minor bigint not null check(amount_minor between 1 and 1000000000000),
 available_at timestamptz not null,expires_at timestamptz,provenance jsonb not null check(jsonb_typeof(provenance)='object'),created_at timestamptz not null default clock_timestamp(),
 foreign key(wallet_id,household_id,currency)references public.boss_bucks_wallets(id,household_id,currency),foreign key(participant_id,person_id)references public.participants(id,person_id),
 foreign key(organization_id,unit_id)references public.organization_units(organization_id,id),foreign key(organization_id,team_id)references public.teams(organization_id,id),
 unique(evidence_id,wallet_id,policy_revision_id,organization_id),check(expires_at is null or expires_at>available_at));
create index boss_bucks_grants_wallet_idx on public.boss_bucks_grants(wallet_id,organization_id,created_at desc,id);
create index boss_bucks_grants_org_idx on public.boss_bucks_grants(organization_id,created_at desc,id);
create index boss_bucks_grants_person_idx on public.boss_bucks_grants(person_id,wallet_id);
create index boss_bucks_grants_policy_idx on public.boss_bucks_grants(policy_revision_id);
create index boss_bucks_grants_campaign_idx on public.boss_bucks_grants(campaign_id);
create index boss_bucks_grants_fundraiser_idx on public.boss_bucks_grants(fundraiser_id);
create index boss_bucks_grants_account_idx on public.boss_bucks_grants(account_id);
create index boss_bucks_grants_participant_idx on public.boss_bucks_grants(participant_id,person_id);
create index boss_bucks_grants_team_idx on public.boss_bucks_grants(organization_id,team_id);
create index boss_bucks_grants_unit_idx on public.boss_bucks_grants(organization_id,unit_id);
create index boss_bucks_grants_wallet_contract_idx on public.boss_bucks_grants(wallet_id,household_id,currency);
create index boss_bucks_grants_intent_idx on public.boss_bucks_grants(intent_id);
create index boss_bucks_grants_expiry_idx on public.boss_bucks_grants(expires_at,id)where expires_at is not null;
create table public.boss_bucks_journals(
 id uuid primary key default gen_random_uuid(),grant_id uuid not null references public.boss_bucks_grants(id),kind text not null check(kind in('issuance','reversal','expiration')),
 currency text not null check(currency~'^[A-Z]{3}$'),original_journal_id uuid references public.boss_bucks_journals(id),reason text not null check(length(reason)between 1 and 200),
 created_at timestamptz not null default clock_timestamp(),check((kind='issuance')=(original_journal_id is null)));
create unique index boss_bucks_journal_issue_idx on public.boss_bucks_journals(grant_id)where kind='issuance';
create unique index boss_bucks_journal_end_idx on public.boss_bucks_journals(grant_id)where kind<>'issuance';
create index boss_bucks_journal_original_idx on public.boss_bucks_journals(original_journal_id);
create index boss_bucks_journal_grant_idx on public.boss_bucks_journals(grant_id,created_at desc,id);
create table public.boss_bucks_postings(
 id uuid primary key default gen_random_uuid(),journal_id uuid not null references public.boss_bucks_journals(id),account_id uuid not null references public.boss_bucks_accounts(id),
 currency text not null check(currency~'^[A-Z]{3}$'),amount_minor bigint not null check(amount_minor<>0 and amount_minor between -1000000000000 and 1000000000000),
 created_at timestamptz not null default clock_timestamp(),unique(journal_id,account_id));
create index boss_bucks_postings_account_idx on public.boss_bucks_postings(account_id,journal_id)include(amount_minor,currency);
create table public.boss_bucks_history(
 id uuid primary key default gen_random_uuid(),organization_id uuid references public.organizations(id),wallet_id uuid references public.boss_bucks_wallets(id),
 grant_id uuid references public.boss_bucks_grants(id),actor_person_id uuid references public.people(id),action text not null,request_id uuid,
 details jsonb not null default '{}' check(jsonb_typeof(details)='object'),created_at timestamptz not null default clock_timestamp());
create index boss_bucks_history_wallet_idx on public.boss_bucks_history(wallet_id,created_at desc,id);
create index boss_bucks_history_org_idx on public.boss_bucks_history(organization_id,created_at desc,id);
create index boss_bucks_history_grant_idx on public.boss_bucks_history(grant_id);
create index boss_bucks_history_actor_idx on public.boss_bucks_history(actor_person_id);
create index boss_bucks_policy_actor_idx on public.boss_bucks_policy_revisions(created_by);
do $$declare t text;begin foreach t in array array['boss_bucks_wallets','boss_bucks_access','boss_bucks_policy_revisions','boss_bucks_fundraiser_bindings','boss_bucks_source_snapshots','boss_bucks_owner_resolutions','boss_bucks_accounts','boss_bucks_grants','boss_bucks_journals','boss_bucks_postings','boss_bucks_history']loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 if t not in('boss_bucks_wallets','boss_bucks_access')then
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end if;
end loop;end$$;
