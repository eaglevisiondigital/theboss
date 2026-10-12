-- Immutable legal-policy references, not a representation of a signed agreement.
create table public.partner_contract_revisions (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null references public.partner_providers(id),revision bigint not null check(revision>0),
 document_reference text not null check(document_reference~'^legal-reference/[a-zA-Z0-9/_-]{3,160}$'),
 rights_holder_reference text not null check(length(btrim(rights_holder_reference))between 1 and 200 and rights_holder_reference!~'[<>]'),
 countries text[] not null check(cardinality(countries)between 1 and 100 and array_position(countries,null)is null),
 categories text[] not null check(cardinality(categories)between 1 and 20 and array_position(categories,null)is null and categories<@array['retail','restaurants','fuel','automotive','gift_cards','hotels','travel','entertainment','tickets','other']::text[]),
 methods text[] not null check(cardinality(methods)between 1 and 7 and array_position(methods,null)is null and methods<@array['rest','scheduled_feed','secure_file','hosted_redirect','sso','reservation_flow','mock']::text[]),
 product_id uuid not null references public.discount_products(id),minimum_tier text not null check(minimum_tier in('local','state','nationwide')),
 display_rights boolean not null,caching_rights boolean not null,branding_rules text not null check(length(branding_rules)between 1 and 1000 and branding_rules!~'[<>]'),
 attribution_rules text not null check(length(attribution_rules)between 1 and 1000 and attribution_rules!~'[<>]'),
 sharing_fields text[] not null default '{}' check(array_position(sharing_fields,null)is null and sharing_fields<@array['subject_pseudonym','country','membership_tier']::text[]),
 retention_days integer not null check(retention_days between 0 and 3650),refund_policy_reference text not null check(length(refund_policy_reference)between 1 and 200),
 starts_at timestamptz not null,ends_at timestamptz not null,created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(provider_id,revision),unique(provider_id,id),check(isfinite(starts_at)and isfinite(ends_at)and ends_at>starts_at));
create table public.partner_contract_events (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null,contract_id uuid not null,
 state text not null check(state in('approved','suspended','terminated')),actor_id uuid not null references public.people(id),
 approval_reference text not null check(length(btrim(approval_reference))between 10 and 200 and approval_reference!~'[<>]'),
 request_id uuid not null,created_at timestamptz not null default clock_timestamp(),
 foreign key(provider_id,contract_id)references public.partner_contract_revisions(provider_id,id));
create index partner_contract_state_idx on public.partner_contract_events(contract_id,created_at desc,id desc);
create table public.partner_territories (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null,contract_id uuid not null,
 country text not null check(country~'^[A-Z]{2}$'),region text not null default '' check(length(region)<=80),
 market_id uuid references public.merchant_markets(id),status text not null default 'active'check(status in('active','ended')),
 starts_at timestamptz not null,ends_at timestamptz not null,created_by uuid not null references public.people(id),
 created_at timestamptz not null default clock_timestamp(),
 foreign key(provider_id,contract_id)references public.partner_contract_revisions(provider_id,id),
 check(isfinite(starts_at)and isfinite(ends_at)and ends_at>starts_at),check(market_id is null or region<>''));
create unique index partner_territory_exact_idx on public.partner_territories(contract_id,country,region,market_id) nulls not distinct where status='active';

-- Fail closed at this migration boundary, including projects with broad defaults.
do $$declare t record;f record;begin
 for t in select schemaname,tablename from pg_tables where schemaname in('public','boss_private')and tablename like'partner_%'loop
 execute format('alter table %I.%I enable row level security',t.schemaname,t.tablename);
 execute format('revoke all on %I.%I from public,anon,authenticated,service_role,boss_payment_worker',t.schemaname,t.tablename);end loop;
 for f in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'partner_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',f.signature);end loop;
end$$;
