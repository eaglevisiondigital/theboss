-- Canonical membership products, not wallet value or a general commerce engine.
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.bucks_module_configuration()'::regprocedure);
 if position('''split_tender'']'in d)=0 then raise exception'Boss Bucks finite configuration checkpoint mismatch';end if;
 d:=replace(d,'''split_tender'']','''split_tender'',''discount_membership'',''membership_trials'',''physical_cards'',''membership_sales'',''membership_upgrades'']');execute d;
end$$;
do $$declare d text;needle text;p text;begin
 d:=pg_get_functiondef('boss_private.bucks_feature(uuid,text)'::regprocedure);needle:='''split_tender'')';
 if position(needle in d)=0 then raise exception'Boss Bucks feature checkpoint mismatch';end if;
 d:=replace(d,needle,'''split_tender'',''discount_membership'',''membership_trials'',''physical_cards'',''membership_sales'',''membership_upgrades'')');execute d;
 d:=pg_get_functiondef('boss_private.bucks_mutate_phase7b(jsonb)'::regprocedure);needle:='''split_tender'']';
 if position(needle in d)=0 then raise exception'Boss Bucks mutation checkpoint mismatch';end if;
 d:=replace(d,needle,'''split_tender'',''discount_membership'',''membership_trials'',''physical_cards'',''membership_sales'',''membership_upgrades'']');execute d;
 d:=pg_get_functiondef('public.boss_admin_read(text,uuid,text)'::regprocedure);needle:='''activation_status'',case when';
 if position(needle in d)=0 then raise exception'Admin module projection checkpoint mismatch';end if;
 foreach p in array array['discount_membership','membership_trials','physical_cards','membership_sales','membership_upgrades']loop
 d:=replace(d,needle,format('%L,boss_private.bucks_admin_feature(p_organization_id,%L),',p||'_enabled',p)||needle);end loop;execute d;
end$$;
insert into public.permissions(key,name,description) values
 ('boss_bucks.membership_view','View discount memberships','Explicit subject or exact organization product reporting'),
 ('boss_bucks.membership_manage','Manage discount membership lifecycle','Scoped product suspension and termination, never arbitrary entitlement grants'),
 ('boss_bucks.product_manage','Manage Boss Bucks products','Platform-only immutable pricing and benefit revisions'),
 ('boss_bucks.inventory_manage','Manage physical card inventory','Exact organization/campaign inventory'),
 ('boss_bucks.fulfillment_manage','Manage product fulfillment','Minimum scoped card and delivery information');
insert into public.role_permissions(role_id,permission_id)
 select r.id,p.id from public.roles r cross join public.permissions p
 where p.key like 'boss_bucks.%' and p.key in('boss_bucks.membership_view','boss_bucks.membership_manage','boss_bucks.product_manage','boss_bucks.inventory_manage','boss_bucks.fulfillment_manage')
 and (r.key in('super_administrator','platform_administrator') or r.key in('organization_owner','organization_administrator') and p.key<>'boss_bucks.product_manage');

create table public.discount_products(
 id uuid primary key default gen_random_uuid(),code text not null unique check(code~'^[a-z][a-z0-9_]{1,63}$'),
 name text not null check(length(btrim(name))between 1 and 100),
 kind text not null check(kind in('digital','physical','state_upgrade','nationwide_upgrade')),
 status text not null default 'draft' check(status in('draft','active','archived')),
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp());
create index discount_products_creator_idx on public.discount_products(created_by);
create table public.discount_product_revisions(
 id uuid primary key default gen_random_uuid(),product_id uuid not null references public.discount_products(id),revision bigint not null check(revision>0),
 organization_id uuid references public.organizations(id),membership_product_id uuid not null references public.discount_products(id),
 subject_type text not null check(subject_type in('person','household')),
 claim_policy text not null check(claim_policy in('authenticated_self','household_primary_contact')),
 currency text not null check(currency~'^[A-Z]{3}$'),price_minor bigint not null check(price_minor between 0 and 1000000000),
 term_days integer check(term_days between 1 and 3660),trial_days integer check(trial_days in(30,60,90)),
 country text not null check(country~'^[A-Z]{2}$'),region text not null check(length(region)between 1 and 80),market text not null check(length(market)between 1 and 100),
 tier text not null check(tier in('local','state','nationwide')),
 organization_credit_minor bigint check(organization_credit_minor between 0 and 1000000000),
 platform_retained_minor bigint check(platform_retained_minor between 0 and 1000000000),product_cost_minor bigint check(product_cost_minor between 0 and 1000000000),
 settlement_policy_id uuid references public.settlement_policy_revisions(id),
 sale_channels text[] not null default '{}' check(sale_channels<@array['direct','fundraising']::text[]),
 trial_enabled boolean not null default false,gift_enabled boolean not null default false,
 fulfillment_type text not null check(fulfillment_type in('digital','shipping','pickup')),
 validity_anchor text check(validity_anchor in('print','sale','activation')),card_validity_days integer check(card_validity_days between 1 and 3660),
 upgrade_policy text not null default 'co_terminate' check(upgrade_policy in('co_terminate')),
 upgrade_from_tiers text[] not null default array['local'] check(cardinality(upgrade_from_tiers)>0 and upgrade_from_tiers<@array['local','state']::text[]),
 refund_policy text not null default 'terminate_source' check(refund_policy='terminate_source'),
 starts_at timestamptz not null,ends_at timestamptz,
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(product_id,revision),unique(product_id,id),
 check((subject_type='person')=(claim_policy='authenticated_self')),
 check(not trial_enabled or trial_days is not null),check(not gift_enabled or term_days is not null),
 check(cardinality(sale_channels)=0 or price_minor>0 and organization_id is not null and settlement_policy_id is not null
 and organization_credit_minor is not null and platform_retained_minor is not null and product_cost_minor is not null
 and organization_credit_minor+platform_retained_minor+product_cost_minor=price_minor),
 check((validity_anchor is null)=(card_validity_days is null)),
 check(isfinite(starts_at)and(ends_at is null or isfinite(ends_at)and ends_at>starts_at)));
create index discount_revision_org_idx on public.discount_product_revisions(organization_id,product_id,revision desc);
create index discount_revision_member_product_idx on public.discount_product_revisions(membership_product_id);
create index discount_revision_policy_idx on public.discount_product_revisions(settlement_policy_id);
create index discount_revision_creator_idx on public.discount_product_revisions(created_by);
create table public.discount_revision_events(
 id uuid primary key default gen_random_uuid(),revision_id uuid not null references public.discount_product_revisions(id),
 state text not null check(state in('active','disabled')),actor_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp());
create index discount_revision_events_latest_idx on public.discount_revision_events(revision_id,created_at desc,id desc);
create index discount_revision_events_actor_idx on public.discount_revision_events(actor_id);
create table public.discount_campaign_products(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,campaign_id uuid not null,revision_id uuid not null references public.discount_product_revisions(id),
 trial_enabled boolean not null default false,gift_enabled boolean not null default false,sale_enabled boolean not null default false,
 status text not null default 'active'check(status in('active','ended')),starts_at timestamptz not null,ends_at timestamptz,
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 unique(campaign_id,revision_id,starts_at),check(ends_at is null or ends_at>starts_at));
create index discount_campaign_products_page_idx on public.discount_campaign_products(campaign_id,status,id);
create index discount_campaign_products_org_idx on public.discount_campaign_products(organization_id,id);
create index discount_campaign_products_revision_idx on public.discount_campaign_products(revision_id);
create index discount_campaign_products_creator_idx on public.discount_campaign_products(created_by);

create table public.discount_memberships(
 id uuid primary key default gen_random_uuid(),product_id uuid not null references public.discount_products(id),
 subject_type text not null check(subject_type in('person','household')),subject_id uuid,
 person_id uuid generated always as(case when subject_type='person'then subject_id end)stored references public.people(id),
 household_id uuid generated always as(case when subject_type='household'then subject_id end)stored references public.households(id),
 country text not null check(country~'^[A-Z]{2}$'),region text not null,market text not null,
 state text not null default 'pending_claim'check(state in('pending_claim','trial','active','suspended','expired','canceled','revoked')),
 display_id text not null unique default 'BB-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,16)),
 version bigint not null default 1 check(version>0),created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 check(subject_id is not null or state='pending_claim'));
create unique index discount_membership_subject_idx on public.discount_memberships(product_id,subject_type,subject_id,country,region,market)where subject_id is not null;
create index discount_membership_person_idx on public.discount_memberships(person_id,id);
create index discount_membership_household_idx on public.discount_memberships(household_id,id);
create table public.discount_member_sources(
 id uuid primary key default gen_random_uuid(),membership_id uuid not null references public.discount_memberships(id),revision_id uuid not null references public.discount_product_revisions(id),
 kind text not null check(kind in('direct_purchase','fundraising_product_sale','fundraising_trial','supporter_gift','physical_card','physical_card_digital_trial','renewal','tier_upgrade')),
 source_key text not null unique check(length(source_key)between 1 and 200),
 organization_id uuid references public.organizations(id),campaign_id uuid,fundraiser_id uuid,donor_id uuid references public.fundraising_donors(id),
 qualification_id uuid unique references public.fundraising_reward_qualifications(id),intent_id uuid references public.fundraising_intents(id),
 tier text not null check(tier in('local','state','nationwide')),starts_at timestamptz not null,ends_at timestamptz not null,
 base_source_id uuid references public.discount_member_sources(id),provenance jsonb not null default '{}'check(jsonb_typeof(provenance)='object'),
 created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),
 foreign key(campaign_id,fundraiser_id)references public.fundraising_fundraisers(campaign_id,id),
 check(isfinite(starts_at)and isfinite(ends_at)and ends_at>starts_at),check((kind='tier_upgrade')=(base_source_id is not null)));
create index discount_sources_member_window_idx on public.discount_member_sources(membership_id,ends_at,id);
create index discount_sources_org_idx on public.discount_member_sources(organization_id,campaign_id,fundraiser_id,id);
create index discount_sources_fundraiser_idx on public.discount_member_sources(fundraiser_id);
create index discount_sources_revision_idx on public.discount_member_sources(revision_id);
create index discount_sources_donor_idx on public.discount_member_sources(donor_id);
create index discount_sources_intent_idx on public.discount_member_sources(intent_id);
create index discount_sources_base_idx on public.discount_member_sources(base_source_id);
create table public.discount_source_revocations(
 id uuid primary key default gen_random_uuid(),source_id uuid not null unique references public.discount_member_sources(id),
 reason text not null check(reason in('refund','chargeback','gift_reversal','canceled','revoked','replaced')),source_event_id uuid,
 actor_id uuid references public.people(id),created_at timestamptz not null default clock_timestamp());
create index discount_source_revocation_actor_idx on public.discount_source_revocations(actor_id);
create table public.discount_membership_history(
 id uuid primary key default gen_random_uuid(),membership_id uuid references public.discount_memberships(id),organization_id uuid references public.organizations(id),
 actor_id uuid references public.people(id),action text not null check(length(action)between 1 and 80),resource_id uuid,request_id uuid,
 details jsonb not null default '{}'check(jsonb_typeof(details)='object'),created_at timestamptz not null default clock_timestamp());
create index discount_membership_history_page_idx on public.discount_membership_history(membership_id,created_at desc,id);
create index discount_membership_history_org_idx on public.discount_membership_history(organization_id,created_at desc,id);
create index discount_membership_history_actor_idx on public.discount_membership_history(actor_id);
create table public.discount_entitlement_links(
 source_id uuid primary key references public.discount_member_sources(id),entitlement_id uuid not null unique references public.entitlements(id),
 created_at timestamptz not null default clock_timestamp());
create table boss_private.discount_claims(
 id uuid primary key default gen_random_uuid(),membership_id uuid not null references public.discount_memberships(id),
 digest text not null unique check(digest~'^[a-f0-9]{64}$'),expires_at timestamptz not null,
 claimed_by uuid references public.people(id),claimed_at timestamptz,revoked_at timestamptz,created_at timestamptz not null default clock_timestamp(),
 check(isfinite(expires_at)and expires_at>created_at),check((claimed_by is null)=(claimed_at is null)));
create index discount_claims_membership_idx on boss_private.discount_claims(membership_id);
create index discount_claims_actor_idx on boss_private.discount_claims(claimed_by);
create table boss_private.discount_requests(
 request_id uuid primary key,actor_id uuid not null references public.people(id),action text not null,command_digest text not null check(command_digest~'^[a-f0-9]{64}$'),
 result jsonb not null,created_at timestamptz not null default clock_timestamp());
create index discount_requests_actor_idx on boss_private.discount_requests(actor_id);

-- Close new raw tables immediately, including their PostgreSQL default grants.
do $$declare t text;begin foreach t in array array['discount_products','discount_product_revisions','discount_revision_events','discount_campaign_products','discount_memberships','discount_member_sources','discount_source_revocations','discount_membership_history','discount_entitlement_links']loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);end loop;
foreach t in array array['discount_claims','discount_requests']loop execute format('alter table boss_private.%I enable row level security',t);execute format('revoke all on boss_private.%I from public,anon,authenticated,service_role,boss_payment_worker',t);end loop;end$$;
