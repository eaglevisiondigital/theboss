create table public.merchant_offer_families(
 id uuid primary key default gen_random_uuid(),merchant_id uuid not null references public.merchants(id),
 usage_limit integer check(usage_limit between 1 and 1000000),reset_period text not null check(reset_period in('lifetime','promotion','weekly','monthly')),
 usage_timezone text not null check(length(usage_timezone)between 1 and 80),period_start timestamptz,period_end timestamptz,
 status text not null default 'active'check(status in('active','paused','archived')),created_by uuid not null references public.people(id),
 created_at timestamptz not null default clock_timestamp(),unique(merchant_id,id),
 check((reset_period='promotion')=(period_start is not null and period_end is not null)),
 check(period_end is null or isfinite(period_start)and isfinite(period_end)and period_end>period_start));
create table public.merchant_offer_revisions(
 id uuid primary key default gen_random_uuid(),merchant_id uuid not null,family_id uuid not null,revision bigint not null check(revision>0),
 title text not null check(length(btrim(title))between 1 and 120 and title!~'[<>]'),description text not null default ''check(length(description)<=1500 and description!~'[<>]'),
 offer_type text not null check(offer_type in('percentage_off','fixed_amount_off','bogo','free_item')),
 discount_bps integer check(discount_bps between 1 and 10000),currency text check(currency~'^[A-Z]{3}$'),amount_minor bigint check(amount_minor between 1 and 1000000000),
 buy_quantity integer check(buy_quantity between 1 and 1000),benefit_quantity integer check(benefit_quantity between 1 and 1000),
 purchase_description text check(length(purchase_description)between 1 and 500 and purchase_description!~'[<>]'),
 benefit_description text check(length(benefit_description)between 1 and 500 and benefit_description!~'[<>]'),
 qualification text not null check(qualification in('none','minimum_amount','item')),
 minimum_minor bigint check(minimum_minor between 1 and 1000000000),qualifying_description text check(length(qualifying_description)between 1 and 500 and qualifying_description!~'[<>]'),
 exclusions text not null default ''check(length(exclusions)<=1000 and exclusions!~'[<>]'),
 stacking text not null check(stacking in('none','merchant_promotions','reviewed_policy')),stacking_policy text check(length(stacking_policy)between 1 and 500 and stacking_policy!~'[<>]'),
 starts_at timestamptz not null,ends_at timestamptz not null,weekdays integer[] not null default array[0,1,2,3,4,5,6],
 local_start time,local_end time,weekly_special boolean not null default false,
 location_policy text not null check(location_policy in('selected','all_current')),include_future boolean not null default false,allow_local_pause boolean not null default true,
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(merchant_id,family_id)references public.merchant_offer_families(merchant_id,id),unique(family_id,revision),unique(merchant_id,id),unique(family_id,id),
 check(isfinite(starts_at)and isfinite(ends_at)and ends_at>starts_at),
 check(cardinality(weekdays)between 1 and 7 and array_position(weekdays,null)is null and weekdays<@array[0,1,2,3,4,5,6]),
 check((local_start is null)=(local_end is null)),check(local_start is null or local_end>local_start),
 check(not include_future or location_policy='all_current'),
 check((offer_type='percentage_off'and discount_bps is not null and amount_minor is null and buy_quantity is null and benefit_quantity is null)
 or(offer_type='fixed_amount_off'and amount_minor is not null and currency is not null and discount_bps is null and buy_quantity is null and benefit_quantity is null)
 or(offer_type='bogo'and buy_quantity is not null and benefit_quantity is not null and purchase_description is not null and benefit_description is not null and discount_bps is not null and amount_minor is null)
 or(offer_type='free_item'and benefit_quantity is not null and benefit_description is not null and discount_bps is null and amount_minor is null and buy_quantity is null)),
 check((qualification='none'and minimum_minor is null and qualifying_description is null)
 or(qualification='minimum_amount'and minimum_minor is not null and currency is not null and qualifying_description is null)
 or(qualification='item'and qualifying_description is not null and minimum_minor is null)),
 check((stacking='reviewed_policy')=(stacking_policy is not null)));
create index merchant_offer_revisions_page_idx on public.merchant_offer_revisions(merchant_id,family_id,revision desc);
create table public.merchant_offer_locations(
 merchant_id uuid not null,revision_id uuid not null,location_id uuid not null,created_at timestamptz not null default clock_timestamp(),primary key(revision_id,location_id),
 foreign key(merchant_id,revision_id)references public.merchant_offer_revisions(merchant_id,id),foreign key(merchant_id,location_id)references public.merchant_locations(merchant_id,id));
create index merchant_offer_locations_location_idx on public.merchant_offer_locations(location_id,revision_id);
create table public.merchant_offer_events(
 id uuid primary key default gen_random_uuid(),revision_id uuid not null references public.merchant_offer_revisions(id),
 state text not null check(state in('draft','pending_review','scheduled','published','paused','expired','rejected','archived')),
 reason text not null default ''check(length(reason)<=1200 and reason!~'[<>]'),actor_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp());
create index merchant_offer_events_latest_idx on public.merchant_offer_events(revision_id,created_at desc,id desc);
create table public.merchant_offer_local_state(
 merchant_id uuid not null,family_id uuid not null,location_id uuid not null,paused boolean not null default false,
 presentation_note text not null default ''check(length(presentation_note)<=300 and presentation_note!~'[<>]'),version bigint not null default 1,
 primary key(family_id,location_id),foreign key(merchant_id,family_id)references public.merchant_offer_families(merchant_id,id),foreign key(merchant_id,location_id)references public.merchant_locations(merchant_id,id));
create table public.merchant_favorites(
 person_id uuid not null references public.people(id),merchant_id uuid not null references public.merchants(id),created_at timestamptz not null default clock_timestamp(),primary key(person_id,merchant_id));
create table boss_private.merchant_redemption_intents(
 id uuid primary key default gen_random_uuid(),person_id uuid not null references public.people(id),membership_id uuid not null references public.discount_memberships(id),
 source_id uuid not null references public.discount_member_sources(id),merchant_id uuid not null,location_id uuid not null,family_id uuid not null,revision_id uuid not null,
 capability_digest text not null unique check(capability_digest~'^[a-f0-9]{64}$'),window_key text not null,
 expires_at timestamptz not null,retired_at timestamptz,consumed_at timestamptz,created_at timestamptz not null default clock_timestamp(),
 foreign key(merchant_id,location_id)references public.merchant_locations(merchant_id,id),foreign key(merchant_id,family_id)references public.merchant_offer_families(merchant_id,id),
 foreign key(family_id,revision_id)references public.merchant_offer_revisions(family_id,id),check(expires_at>created_at and expires_at<=created_at+interval'5 minutes'));
create index merchant_intents_member_idx on boss_private.merchant_redemption_intents(person_id,family_id,created_at desc);
create table public.merchant_redemptions(
 id uuid primary key default gen_random_uuid(),intent_id uuid not null unique references boss_private.merchant_redemption_intents(id),person_id uuid not null references public.people(id),
 membership_id uuid not null references public.discount_memberships(id),source_id uuid not null references public.discount_member_sources(id),
 merchant_id uuid not null,location_id uuid not null,family_id uuid not null,revision_id uuid not null,window_key text not null,
 clerk_id uuid not null references public.people(id),terms_snapshot jsonb not null check(jsonb_typeof(terms_snapshot)='object'),created_at timestamptz not null default clock_timestamp(),
 foreign key(merchant_id,location_id)references public.merchant_locations(merchant_id,id),foreign key(merchant_id,family_id)references public.merchant_offer_families(merchant_id,id),
 foreign key(family_id,revision_id)references public.merchant_offer_revisions(family_id,id));
create index merchant_redemptions_usage_idx on public.merchant_redemptions(person_id,family_id,window_key,id);
create index merchant_redemptions_page_idx on public.merchant_redemptions(merchant_id,location_id,created_at desc,id desc);
create table public.merchant_redemption_corrections(
 id uuid primary key default gen_random_uuid(),redemption_id uuid not null unique references public.merchant_redemptions(id),restore_allowance boolean not null default false,
 reason text not null check(length(btrim(reason))between 10 and 1200 and reason!~'[<>]'),reviewer_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp());

create function boss_private.merchant_platform(actor uuid,k text)returns boolean language sql volatile security definer set search_path=''as $$
 select boss_private.rails_actor_current(actor)and exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.status='active'and p.key=k
 where a.person_id=actor and a.scope_type='platform'and a.scope_id is null and a.organization_id is null
 and r.key in('super_administrator','platform_administrator')and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp()))
$$;
create function boss_private.merchant_feature(merchant uuid,feature text)returns boolean language sql volatile security definer set search_path=''as $$
 select feature in('portal','offers','redemption')and exists(select 1 from public.merchant_modules mm join public.modules m on m.id=mm.module_id and m.key='commerce'and m.status='active'
 join public.merchants b on b.id=mm.merchant_id and b.status not in('suspended','archived')where mm.merchant_id=merchant and mm.status='active'
 and mm.starts_at<=clock_timestamp()and(mm.ends_at is null or mm.ends_at>clock_timestamp())and mm.configuration->feature='true'::jsonb)
$$;
create function boss_private.merchant_can(actor uuid,k text,merchant uuid,location uuid default null)returns boolean language sql volatile security definer set search_path=''as $$
 select boss_private.rails_actor_current(actor)and k in('merchants.view','merchants.manage','merchants.access_manage','merchant_locations.view','merchant_locations.manage','merchant_offers.view','merchant_offers.manage','merchant_redemptions.view','merchant_redemptions.manage','merchant_reviews.manage')
 and exists(select 1 from public.merchants where id=merchant)
 and(location is null or exists(select 1 from public.merchant_locations where id=location and merchant_id=merchant))and(
 boss_private.merchant_platform(actor,k)
 or k='merchant_reviews.manage'and exists(select 1 from public.merchant_staff_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.status='active'and p.key=k
 where a.person_id=actor and a.merchant_id=merchant and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())and r.key in('support_reviewer','merchant_network_staff'))
 or k in('merchants.view','merchant_locations.view','merchant_offers.view')and exists(select 1 from public.merchant_staff_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.status='active'and p.key=k
 where a.person_id=actor and a.merchant_id=merchant and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())and r.key in('support_reviewer','merchant_network_staff'))
 or boss_private.merchant_feature(merchant,'portal')and exists(select 1 from public.merchant_access_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.status='active'and p.key=k
 where a.person_id=actor and a.merchant_id=merchant and(a.location_id is null or a.location_id=location)and a.status='active'
 and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())and r.key in('merchant_owner','merchant_admin','location_manager','offer_editor','redemption_clerk')))
$$;
create function boss_private.merchant_require(actor uuid,k text,merchant uuid,location uuid default null)returns void language plpgsql volatile security definer set search_path=''as $$begin
 if not boss_private.merchant_can(actor,k,merchant,location)then raise exception'Merchant scope restricted'using errcode='PT403';end if;
end$$;
create function boss_private.merchant_fence(actor uuid,merchant uuid default null)returns void language plpgsql volatile security definer set search_path=''as $$begin
 if merchant is not null then perform pg_advisory_xact_lock(hashtextextended('boss-merchant:'||merchant,0));
 perform 1 from public.merchant_modules where merchant_id=merchant for share;end if;
 perform 1 from public.merchant_access_assignments where person_id=actor and merchant_id=merchant order by id for share;
 perform 1 from public.merchant_staff_assignments where person_id=actor and merchant_id=merchant order by id for share;
 perform 1 from public.role_assignments where person_id=actor order by id for share;
 perform 1 from public.people where id=actor for share;perform 1 from public.user_accounts where person_id=actor for share;
 perform 1 from auth.users where id in(select auth_user_id from public.user_accounts where person_id=actor)for share;
end$$;
create function boss_private.merchant_audit(actor uuid,merchant uuid,action text,resource uuid,request uuid,details jsonb default '{}')returns void language plpgsql volatile security definer set search_path=''as $$begin
 insert into public.merchant_history(merchant_id,actor_id,action,resource_id,request_id,details)values(merchant,actor,action,resource,request,details);
 insert into public.audit_events(actor_person_id,actor_auth_user_id,action,resource_type,resource_id,request_id,after_data)
 values(actor,auth.uid(),action,'merchant',coalesce(resource,merchant),request,jsonb_build_object('merchant_id',merchant)||details);
end$$;
create function boss_private.merchant_offer_state(revision uuid)returns text language sql volatile security definer set search_path=''as $$
 select state from public.merchant_offer_events where revision_id=revision order by created_at desc,id desc limit 1
$$;
create function boss_private.merchant_window(f public.merchant_offer_families,at_time timestamptz default clock_timestamp())returns text language sql stable set search_path=''as $$
 select case f.reset_period when'lifetime'then'lifetime'when'promotion'then'promotion:'||f.id
 when'weekly'then'week:'||to_char(at_time at time zone f.usage_timezone,'IYYY-IW')when'monthly'then'month:'||to_char(at_time at time zone f.usage_timezone,'YYYY-MM')end
$$;
create function boss_private.merchant_usage(person uuid,family uuid,window_key text)returns bigint language sql volatile security definer set search_path=''as $$
 select count(*)from public.merchant_redemptions r where r.person_id=person and r.family_id=family and r.window_key=merchant_usage.window_key
 and not exists(select 1 from public.merchant_redemption_corrections c where c.redemption_id=r.id and c.restore_allowance)
$$;
create function boss_private.merchant_available(revision uuid,location uuid,at_time timestamptz default clock_timestamp())returns boolean language sql volatile security definer set search_path=''as $$
 select exists(select 1 from public.merchant_offer_revisions r join public.merchant_offer_families f on f.id=r.family_id and f.merchant_id=r.merchant_id and f.status='active'
 join public.merchants m on m.id=r.merchant_id and m.status='active'join public.merchant_locations l on l.id=location and l.merchant_id=m.id and l.status='active'
 join public.merchant_markets g on g.id=l.market_id and g.status='active'
 where r.id=merchant_available.revision and boss_private.merchant_feature(m.id,'offers')and boss_private.merchant_offer_state(r.id)in('scheduled','published')
 and r.starts_at<=at_time and r.ends_at>at_time and(f.reset_period<>'promotion'or f.period_start<=at_time and f.period_end>at_time)
 and(exists(select 1 from public.merchant_offer_locations t where t.revision_id=r.id and t.location_id=l.id)or r.include_future and l.created_at>r.created_at)
 and(not r.allow_local_pause or not exists(select 1 from public.merchant_offer_local_state s where s.family_id=f.id and s.location_id=l.id and s.paused))
 and extract(dow from at_time at time zone l.timezone)::integer=any(r.weekdays)
 and(r.local_start is null or(at_time at time zone l.timezone)::time>=r.local_start and(at_time at time zone l.timezone)::time<r.local_end))
$$;
create function boss_private.merchant_market_source(actor uuid,market uuid)returns uuid language sql volatile security definer set search_path=''as $$
 select s.id from public.merchant_markets g join public.discount_memberships m on m.country=g.country join public.discount_member_sources s on s.membership_id=m.id
 where g.id=merchant_market_source.market and g.status='active'and(m.subject_type='person'and m.subject_id=actor or m.subject_type='household'and m.subject_id in(select household_id from public.household_memberships where person_id=actor and status='active'))
 and boss_private.discount_subject(actor,m.subject_type,m.subject_id)and boss_private.discount_source_valid(s.id)
 and(s.tier='nationwide'or s.tier='state'and m.region=g.region or s.tier='local'and m.region=g.region and m.market=g.market)
 order by boss_private.discount_tier_rank(s.tier)desc,s.ends_at desc,s.id limit 1
$$;
create function boss_private.merchant_membership_source(actor uuid,location uuid)returns uuid language sql volatile security definer set search_path=''as $$
 select boss_private.merchant_market_source(actor,l.market_id)from public.merchant_locations l where l.id=location
$$;
do $$declare t text;begin for t in select tablename from pg_tables where schemaname='public'and tablename like'merchant_%'loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role,boss_payment_worker',t);end loop;
 alter table boss_private.merchant_redemption_intents enable row level security;
 revoke all on boss_private.merchant_redemption_intents from public,anon,authenticated,service_role,boss_payment_worker;
end$$;
