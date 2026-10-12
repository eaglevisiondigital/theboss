create table public.partner_benefit_sources (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null references public.partner_providers(id),
 external_id text not null check(external_id~'^[a-zA-Z0-9_.:-]{1,120}$'),
 current_revision bigint not null default 0 check(current_revision>=0),current_digest text,
 status text not null default 'available'check(status in('available','withdrawn','paused')),last_verified_at timestamptz,
 unique(provider_id,external_id),unique(provider_id,id));
create table public.partner_benefit_revisions (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null,source_id uuid not null,source_revision bigint not null check(source_revision>0),
 contract_id uuid not null,category text not null check(category in('retail','restaurants','fuel','automotive','gift_cards','hotels','travel','entertainment','tickets','other')),
 title text not null check(length(btrim(title))between 1 and 120 and title!~'[<>]'),
 public_description text not null check(length(public_description)<=500 and public_description!~'[<>]'),
 member_terms text not null check(length(btrim(member_terms))between 1 and 2000 and member_terms!~'[<>]'),
 exclusions text not null default ''check(length(exclusions)<=1500 and exclusions!~'[<>]'),
 country text not null check(country~'^[A-Z]{2}$'),region text not null default ''check(length(region)<=80),market_id uuid references public.merchant_markets(id),
 product_id uuid not null references public.discount_products(id),minimum_tier text not null check(minimum_tier in('local','state','nationwide')),
 fulfillment text not null check(fulfillment in('percentage_discount','fixed_discount','cashback','discounted_gift_card','partner_membership','provider_coupon','travel_rate')),
 starts_at timestamptz not null,ends_at timestamptz not null,source_digest text not null check(source_digest~'^[a-f0-9]{64}$'),
 created_at timestamptz not null default clock_timestamp(),
 foreign key(provider_id,source_id)references public.partner_benefit_sources(provider_id,id),
 foreign key(provider_id,contract_id)references public.partner_contract_revisions(provider_id,id),
 unique(source_id,source_revision),unique(provider_id,id),check(isfinite(starts_at)and isfinite(ends_at)and ends_at>starts_at));
-- Review is append-only; never mutate historical material terms.
create table public.partner_benefit_reviews (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null,revision_id uuid not null,state text not null check(state in('reviewed','paused','rejected')),
 actor_id uuid not null references public.people(id),request_id uuid not null,created_at timestamptz not null default clock_timestamp(),
 foreign key(provider_id,revision_id)references public.partner_benefit_revisions(provider_id,id));
create index partner_benefit_review_idx on public.partner_benefit_reviews(revision_id,created_at desc,id desc);
create index partner_benefit_page_idx on public.partner_benefit_revisions(provider_id,category,country,id);
create index partner_source_page_idx on public.partner_benefit_sources(provider_id,status,id);
create table public.partner_import_runs (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null references public.partner_providers(id),feed_sequence bigint not null check(feed_sequence>0),
 kind text not null check(kind in('full','delta')),synthetic boolean not null check(synthetic),
 digest text not null check(digest~'^[a-f0-9]{64}$'),accepted integer not null default 0,quarantined integer not null default 0,
 withdrawn integer not null default 0,actor_id uuid not null references public.people(id),request_id uuid not null,
 created_at timestamptz not null default clock_timestamp(),unique(provider_id,feed_sequence));
create table public.partner_import_quarantine (
 id uuid primary key default gen_random_uuid(),run_id uuid not null references public.partner_import_runs(id),
 item_index integer not null check(item_index>=0),external_id text check(external_id~'^[a-zA-Z0-9_.:-]{1,120}$'),
 category text not null check(category in('invalid_item','revision_conflict','out_of_order')),created_at timestamptz not null default clock_timestamp(),unique(run_id,item_index));
create index partner_quarantine_run_idx on public.partner_import_quarantine(run_id);

create table public.partner_catalog_snapshots(
 id uuid primary key default gen_random_uuid(),provider_id uuid not null references public.partner_providers(id),
 expected_items bigint not null check(expected_items>=0),status text not null default 'open'check(status in('open','complete','aborted')),
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp());
alter table public.partner_import_runs add column snapshot_id uuid references public.partner_catalog_snapshots(id);
create index partner_import_snapshot_idx on public.partner_import_runs(snapshot_id);
create unique index partner_snapshot_open_idx on public.partner_catalog_snapshots(provider_id)where status='open';
create table public.partner_snapshot_items(
 snapshot_id uuid not null references public.partner_catalog_snapshots(id),source_id uuid not null references public.partner_benefit_sources(id),
 run_id uuid not null references public.partner_import_runs(id),primary key(snapshot_id,source_id));
create index partner_snapshot_source_idx on public.partner_snapshot_items(source_id);
create index partner_snapshot_run_idx on public.partner_snapshot_items(run_id);
create index partner_snapshot_creator_idx on public.partner_catalog_snapshots(created_by);
-- Fail closed at this migration boundary, including projects with broad defaults.
do $$declare t record;f record;begin
 for t in select schemaname,tablename from pg_tables where schemaname in('public','boss_private')and tablename like'partner_%'loop
 execute format('alter table %I.%I enable row level security',t.schemaname,t.tablename);
 execute format('revoke all on %I.%I from public,anon,authenticated,service_role,boss_payment_worker',t.schemaname,t.tablename);end loop;
 for f in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'partner_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',f.signature);end loop;
end$$;
