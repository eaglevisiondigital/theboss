-- Merchant resources reuse Boss identity/catalogs, never organization tenancy.
create table public.merchant_markets(
 id uuid primary key default gen_random_uuid(),country text not null check(country~'^[A-Z]{2}$'),
 region text not null check(length(btrim(region))between 1 and 80),market text not null check(length(btrim(market))between 1 and 100),
 status text not null default 'active' check(status in('active','inactive')),created_at timestamptz not null default clock_timestamp(),
 unique(country,region,market));
create table public.merchant_categories(
 key text primary key check(key~'^[a-z][a-z0-9_]{1,39}$'),name text not null check(length(btrim(name))between 1 and 80),
 status text not null default 'active'check(status in('active','inactive')));
insert into public.merchant_categories(key,name)values('restaurants','Restaurants'),('automotive','Automotive'),('entertainment','Entertainment'),('retail','Retail'),('services','Services'),('health_fitness','Health and fitness');
create table public.merchants(
 id uuid primary key default gen_random_uuid(),name text not null check(length(btrim(name))between 1 and 120),
 legal_name text check(length(legal_name)<=160),description text not null default ''check(length(description)<=1500 and description!~'[<>]'),
 category text not null references public.merchant_categories(key),primary_market_id uuid not null references public.merchant_markets(id),
 website text check(website is null or length(website)<=500 and website~'^https://[^[:space:]<>]+$'),
 public_phone text check(length(public_phone)<=40),logo_ref text check(logo_ref is null or logo_ref~'^/merchant-images/[a-zA-Z0-9/_-]+\.(png|jpg|webp)$'),
 status text not null default 'prospect'check(status in('prospect','invited','claimed','pending_review','active','paused','suspended','archived')),
 claim_state text not null default 'unclaimed'check(claim_state in('unclaimed','reviewed')),
 version bigint not null default 1 check(version>0),controlled boolean not null default false,
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp());
create index merchants_directory_idx on public.merchants(primary_market_id,category,name,id)where status='active';
create index merchants_name_prefix_idx on public.merchants(lower(name)text_pattern_ops,id)where status='active';
create table public.merchant_modules(
 merchant_id uuid primary key references public.merchants(id),module_id uuid not null references public.modules(id),
 status text not null default 'inactive'check(status in('active','inactive')),starts_at timestamptz not null default clock_timestamp(),ends_at timestamptz,
 configuration jsonb not null default '{}' check(jsonb_typeof(configuration)='object'and configuration-'portal'-'offers'-'redemption'='{}'::jsonb),
 check(isfinite(starts_at)and(ends_at is null or isfinite(ends_at)and ends_at>starts_at)));
create table public.merchant_locations(
 id uuid primary key default gen_random_uuid(),merchant_id uuid not null references public.merchants(id),market_id uuid not null references public.merchant_markets(id),
 name text not null check(length(btrim(name))between 1 and 120),address text not null check(length(btrim(address))between 1 and 250),
 city text not null check(length(btrim(city))between 1 and 100),postal_code text not null check(length(postal_code)between 1 and 24),
 timezone text not null check(length(timezone)between 1 and 80),phone text check(length(phone)<=40),
 website text check(website is null or length(website)<=500 and website~'^https://[^[:space:]<>]+$'),
 hours_note text not null default ''check(length(hours_note)<=500 and hours_note!~'[<>]'),
 status text not null default 'active'check(status in('active','paused','archived')),version bigint not null default 1,
 created_at timestamptz not null default clock_timestamp(),unique(merchant_id,id),unique(merchant_id,name));
create index merchant_locations_discovery_idx on public.merchant_locations(market_id,merchant_id,id)where status='active';
create index merchant_locations_page_idx on public.merchant_locations(merchant_id,id);

alter table public.roles drop constraint roles_scope_types_check;
alter table public.roles add constraint roles_scope_types_check check(cardinality(allowed_scope_types)>0 and array_position(allowed_scope_types,null)is null
 and allowed_scope_types<@array['platform','organization','organization_unit','team','competition','competition_edition','merchant','merchant_location']::text[]);
insert into public.roles(key,name,allowed_scope_types)values
 ('merchant_owner','Merchant owner',array['merchant']),('merchant_admin','Merchant administrator',array['merchant']),
 ('location_manager','Location manager',array['merchant_location']),('offer_editor','Offer editor',array['merchant','merchant_location']),
 ('redemption_clerk','Redemption clerk',array['merchant_location']),('sales_rep','Merchant sales representative',array['platform']),
 ('regional_manager','Merchant regional manager',array['platform']),('support_reviewer','Merchant support reviewer',array['platform']);
insert into public.permissions(key,name)values
 ('merchants.view','View assigned merchants'),('merchants.manage','Manage assigned merchants'),
 ('merchants.access_manage','Manage merchant operational assignments'),('merchant_locations.view','View assigned merchant locations'),('merchant_locations.manage','Manage assigned locations'),
 ('merchant_offers.view','View assigned offers'),('merchant_offers.manage','Draft and manage assigned offers'),
 ('merchant_redemptions.view','View scoped redemption evidence'),('merchant_redemptions.manage','Redeem at assigned location'),
 ('merchant_reviews.manage','Review assigned merchants and offers'),('merchant_sales.view','View assigned sales pipeline'),('merchant_sales.manage','Manage assigned sales pipeline');
insert into public.role_permissions(role_id,permission_id)select r.id,p.id from public.roles r cross join public.permissions p
 where p.key in('merchants.view','merchants.manage','merchants.access_manage','merchant_locations.view','merchant_locations.manage','merchant_offers.view','merchant_offers.manage','merchant_redemptions.view','merchant_redemptions.manage','merchant_reviews.manage','merchant_sales.view','merchant_sales.manage')
 and(r.key in('super_administrator','platform_administrator')
 or r.key in('merchant_owner','merchant_admin')and p.key not in('merchant_reviews.manage','merchant_sales.view','merchant_sales.manage')
 or r.key='location_manager'and p.key in('merchants.view','merchant_locations.view','merchant_locations.manage','merchant_offers.view','merchant_redemptions.view','merchant_redemptions.manage')
 or r.key='offer_editor'and p.key in('merchants.view','merchant_locations.view','merchant_offers.view','merchant_offers.manage')
 or r.key='redemption_clerk'and p.key in('merchant_offers.view','merchant_redemptions.manage')
 or r.key in('support_reviewer','merchant_network_staff')and p.key in('merchants.view','merchant_locations.view','merchant_offers.view','merchant_reviews.manage')
 or r.key in('sales_rep','regional_manager')and p.key in('merchant_sales.view','merchant_sales.manage'));
create table public.merchant_access_assignments(
 id uuid primary key default gen_random_uuid(),merchant_id uuid not null references public.merchants(id),location_id uuid,
 person_id uuid not null references public.people(id),role_id uuid not null references public.roles(id),
 starts_at timestamptz not null default clock_timestamp(),ends_at timestamptz,status text not null default 'active'check(status in('active','ended')),
 granted_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(merchant_id,location_id)references public.merchant_locations(merchant_id,id),
 check(isfinite(starts_at)and(ends_at is null or isfinite(ends_at)and ends_at>starts_at)),unique nulls not distinct(merchant_id,location_id,person_id,role_id,starts_at));
create index merchant_access_current_idx on public.merchant_access_assignments(person_id,merchant_id,location_id)where status='active';
create table public.merchant_staff_assignments(
 id uuid primary key default gen_random_uuid(),merchant_id uuid not null references public.merchants(id),person_id uuid not null references public.people(id),
 role_id uuid not null references public.roles(id),starts_at timestamptz not null default clock_timestamp(),ends_at timestamptz,
 status text not null default 'active'check(status in('active','ended')),granted_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 check(isfinite(starts_at)and(ends_at is null or isfinite(ends_at)and ends_at>starts_at)));
create index merchant_staff_current_idx on public.merchant_staff_assignments(person_id,merchant_id)where status='active';
create table public.merchant_claims(
 id uuid primary key default gen_random_uuid(),merchant_id uuid not null references public.merchants(id),person_id uuid not null references public.people(id),
 statement text not null check(length(btrim(statement))between 10 and 1200 and statement!~'[<>]'),
 state text not null default 'pending'check(state in('pending','approved','rejected')),review_reason text check(length(review_reason)between 10 and 1200),
 reviewed_by uuid references public.people(id),reviewed_at timestamptz,created_at timestamptz not null default clock_timestamp(),
 check((state='pending')=(reviewed_at is null and reviewed_by is null and review_reason is null)));
create unique index merchant_claims_pending_idx on public.merchant_claims(merchant_id,person_id)where state='pending';
create unique index merchant_claims_approved_idx on public.merchant_claims(merchant_id)where state='approved';
create table public.merchant_history(
 id uuid primary key default gen_random_uuid(),merchant_id uuid references public.merchants(id),actor_id uuid not null references public.people(id),
 action text not null check(length(action)between 1 and 80),resource_id uuid,request_id uuid,details jsonb not null default '{}'check(jsonb_typeof(details)='object'),
 created_at timestamptz not null default clock_timestamp());
create index merchant_history_resource_idx on public.merchant_history(merchant_id,created_at desc,id desc);
create table boss_private.merchant_receipts(
 actor_id uuid not null references public.people(id),request_id uuid not null,action text not null,merchant_id uuid references public.merchants(id),
 location_id uuid references public.merchant_locations(id),permission_key text,command_digest text not null check(command_digest~'^[a-f0-9]{64}$'),
 result jsonb not null check(jsonb_typeof(result)='object'),created_at timestamptz not null default clock_timestamp(),primary key(actor_id,request_id));
-- No actual merchant/person/access/membership is seeded.
do $$declare t text;begin
 for t in select tablename from pg_tables where schemaname='public'and(tablename like'merchant_%'or tablename='merchants')loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);end loop;
 alter table boss_private.merchant_receipts enable row level security;
 revoke all on boss_private.merchant_receipts from public,anon,authenticated,service_role,boss_payment_worker;
end$$;
