-- Provider-neutral foundation. No provider, authority, secret or live adapter is seeded.
create table public.partner_providers (
 id uuid primary key default gen_random_uuid(), key text not null unique check(key~'^[a-z][a-z0-9_-]{2,79}$'),
 name text not null check(length(btrim(name)) between 1 and 120 and name!~'[<>]'),
 legal_reference text check(length(legal_reference) between 1 and 200 and legal_reference!~'[<>]'),
 support_reference text check(length(support_reference)<=200 and support_reference!~'[<>]'),
 state text not null default 'prospect' check(state in('prospect','evaluation','contract_pending','approved','configured','suspended','terminated','archived')),
 version bigint not null default 1 check(version>0), synthetic boolean not null default false,
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(id,key));
create table public.partner_config_revisions (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null references public.partner_providers(id),
 revision bigint not null check(revision>0),module_id uuid not null references public.modules(id),
 method text not null check(method in('rest','scheduled_feed','secure_file','hosted_redirect','sso','reservation_flow','mock')),
 capabilities text[] not null default '{}' check(cardinality(capabilities)<=14 and array_position(capabilities,null)is null and capabilities<@array['catalog_read','benefit_search','benefit_detail','eligibility_check','external_redirect','coupon_retrieval','reservation_quote','price_recheck','booking_request','booking_status','cancellation','refund_status','commission_report','commission_reconciliation']::text[]),
 credential_reference text check(credential_reference is null or credential_reference~'^partner-vault/[a-z0-9_-]{3,80}$'),
 credentials_ready boolean not null default false check(not credentials_ready),
 operational boolean not null default false check(not operational),
 full_withdraw_missing boolean not null default false,max_stale_seconds integer not null check(max_stale_seconds between 60 and 2592000),
 starts_at timestamptz not null,ends_at timestamptz,
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(provider_id,revision),unique(provider_id,id),
 check(isfinite(starts_at) and (ends_at is null or isfinite(ends_at)and ends_at>starts_at)));
create index partner_config_current_idx on public.partner_config_revisions(provider_id,revision desc);
create table public.partner_provider_events (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null references public.partner_providers(id),
 state text not null check(state in('prospect','evaluation','contract_pending','approved','configured','suspended','terminated','archived')),
 actor_id uuid not null references public.people(id),reason text not null check(length(btrim(reason))between 10 and 500 and reason!~'[<>]'),
 request_id uuid not null,created_at timestamptz not null default clock_timestamp());
create index partner_provider_events_idx on public.partner_provider_events(provider_id,created_at desc,id desc);
create table boss_private.partner_receipts (
 actor_id uuid not null references public.people(id),request_id uuid not null,action text not null,
 provider_id uuid references public.partner_providers(id),digest text not null check(digest~'^[a-f0-9]{64}$'),result jsonb not null,
 created_at timestamptz not null default clock_timestamp(),primary key(actor_id,request_id));
insert into public.permissions(key,name)values
 ('partners.view','View provider administration'),('partners.configure','Configure provider foundation'),
 ('partners.contract_approve','Approve provider licensing policy'),('partners.catalog_review','Review provider catalog'),
 ('partners.integration_activate','Review integration activation'),('partners.revenue_report','View separate partner revenue evidence');
insert into public.role_permissions(role_id,permission_id)select r.id,p.id from public.roles r cross join public.permissions p
 where r.key in('super_administrator','platform_administrator')and p.key in('partners.view','partners.configure','partners.contract_approve','partners.catalog_review','partners.integration_activate','partners.revenue_report');

-- Fail closed at this migration boundary, including projects with broad defaults.
do $$declare t record;f record;begin
 for t in select schemaname,tablename from pg_tables where schemaname in('public','boss_private')and tablename like'partner_%'loop
 execute format('alter table %I.%I enable row level security',t.schemaname,t.tablename);
 execute format('revoke all on %I.%I from public,anon,authenticated,service_role,boss_payment_worker',t.schemaname,t.tablename);end loop;
 for f in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'partner_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',f.signature);end loop;
end$$;
