-- Phase 7A: no wallet, processor, settlement execution or account auto-linking.
alter table public.guardian_relationships add column can_manage_fundraising boolean not null default false;
insert into public.permissions(key,name,description) values
 ('fundraising.view','View fundraising','Exact-context fundraising progress'),
 ('fundraising.create','Create fundraising','Organization campaign creation'),
 ('fundraising.manage','Manage fundraising','Campaign and participation configuration'),
 ('fundraising.publish','Publish fundraising','Organization campaign publication'),
 ('fundraising.financial_view','View fundraising finance','Private donor and source evidence'),
 ('money_board.view','View Money Board','Exact-context board progress'),
 ('money_board.manage','Manage Money Board','Configure deterministic campaign boards');
insert into public.role_permissions(role_id,permission_id)
 select r.id,p.id from public.roles r cross join public.permissions p where p.key in('fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage') and
 (r.key in('super_administrator','platform_administrator','organization_owner','organization_administrator')
 or r.key in('athletic_director','program_administrator','sport_administrator','team_administrator','head_coach')and p.key in('fundraising.view','money_board.view')
 or r.key in('finance','organization_finance')and p.key in('fundraising.view','fundraising.financial_view'));

create table public.fundraising_campaigns(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),name text not null check(length(btrim(name))between 1 and 120),description text not null default '' check(length(description)<=2400),
 currency text not null check(currency~'^[A-Z]{3}$'),goal_minor bigint not null check(goal_minor between 1 and 1000000000000),
 starts_at timestamptz not null,ends_at timestamptz not null,launch_at timestamptz,
 status text not null default 'draft' check(status in('draft','scheduled','active','paused','completed','canceled','archived')),
 scope text not null check(scope in('organization','selected')),channels text[] not null default array['direct_support'] check(cardinality(channels)>0 and channels<@array['direct_support','money_board','digital_card_future','physical_card_future']::text[]),
 public_path text not null unique default left(replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''),48) check(public_path~'^[a-f0-9]{48}$'),public_visible boolean not null default false,indexable boolean not null default false,
 allow_anonymous boolean not null default true,allow_recurring boolean not null default false,allow_fee_cover boolean not null default false,allow_team_sharing boolean not null default false,allow_adult_self_sharing boolean not null default false,
 leaderboard_visibility text not null default 'disabled' check(leaderboard_visibility in('disabled','authorized','public')),
 branding jsonb not null default '{}' check(jsonb_typeof(branding)='object' and octet_length(branding::text)<=4096),
 reward_policy jsonb not null default '{}' check(jsonb_typeof(reward_policy)='object'),version bigint not null default 1,
 created_by uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 unique(organization_id,id),check(ends_at>starts_at),check(launch_at is null or launch_at<=ends_at));
create index fundraising_campaigns_org_state_idx on public.fundraising_campaigns(organization_id,status,created_at desc,id);
create table public.fundraising_targets(
 id uuid primary key default gen_random_uuid(),campaign_id uuid not null references public.fundraising_campaigns(id),organization_id uuid not null,
 unit_id uuid,team_id uuid,goal_minor bigint check(goal_minor between 1 and 1000000000000),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),foreign key(organization_id,unit_id)references public.organization_units(organization_id,id),foreign key(organization_id,team_id)references public.teams(organization_id,id),
 check(num_nonnulls(unit_id,team_id)=1));
create unique index fundraising_targets_exact_idx on public.fundraising_targets(campaign_id,coalesce(team_id,unit_id));
create index fundraising_targets_team_idx on public.fundraising_targets(team_id,campaign_id);create index fundraising_targets_unit_idx on public.fundraising_targets(unit_id,campaign_id);
create table public.fundraising_fundraisers(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,campaign_id uuid not null,participant_id uuid not null,person_id uuid not null,
 unit_id uuid,team_id uuid,household_id uuid references public.households(id),goal_minor bigint check(goal_minor between 1 and 1000000000000),
 status text not null default 'pending' check(status in('pending','active','ended','archived')),leaderboard_opt_in boolean not null default false,public_display_name text check(length(btrim(public_display_name))between 1 and 100),
 starts_at timestamptz not null default clock_timestamp(),ends_at timestamptz,version bigint not null default 1,created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,campaign_id)references public.fundraising_campaigns(organization_id,id),foreign key(participant_id,person_id)references public.participants(id,person_id),
 foreign key(organization_id,unit_id)references public.organization_units(organization_id,id),foreign key(organization_id,team_id)references public.teams(organization_id,id),unique(campaign_id,participant_id),unique(campaign_id,id),check(ends_at is null or ends_at>starts_at));
create index fundraising_fundraisers_person_idx on public.fundraising_fundraisers(person_id,status,campaign_id);create index fundraising_fundraisers_scope_idx on public.fundraising_fundraisers(campaign_id,team_id,unit_id,status,id);
create table public.fundraising_shares(
 id uuid primary key default gen_random_uuid(),fundraiser_id uuid not null references public.fundraising_fundraisers(id),path text not null unique default left(replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''),48),
 authorized_by uuid not null references public.people(id),status text not null default 'active' check(status in('active','revoked')),created_at timestamptz not null default clock_timestamp(),revoked_at timestamptz,check(path~'^[a-f0-9]{48}$'));
create unique index fundraising_shares_current_idx on public.fundraising_shares(fundraiser_id)where status='active';create index fundraising_shares_authorizer_idx on public.fundraising_shares(authorized_by,fundraiser_id);
create table public.money_boards(
 id uuid primary key default gen_random_uuid(),campaign_id uuid not null references public.fundraising_campaigns(id),fundraiser_id uuid,team_id uuid references public.teams(id),
 public_path text not null unique default left(replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''),48),title text not null check(length(btrim(title))between 1 and 120),goal_minor bigint not null check(goal_minor between 1 and 1000000000000),
 start_minor bigint not null check(start_minor>0),increment_minor bigint not null check(increment_minor>0),tile_count integer not null check(tile_count>0),
 reservation_seconds integer not null default 600 check(reservation_seconds between 480 and 600),version bigint not null default 1,
 status text not null default 'draft' check(status in('draft','published','archived')),visibility text not null default 'private' check(visibility in('private','public')),
 created_at timestamptz not null default clock_timestamp(),foreign key(campaign_id,fundraiser_id)references public.fundraising_fundraisers(campaign_id,id),
 unique nulls not distinct(campaign_id,fundraiser_id,team_id),check(fundraiser_id is null or team_id is null),check(start_minor::numeric+(tile_count-1)::numeric*increment_minor<=1000000000000),check(tile_count::numeric*(2*start_minor::numeric+(tile_count-1)::numeric*increment_minor)/2<=9007199254740991));
create index money_boards_fundraiser_idx on public.money_boards(fundraiser_id);create index money_boards_team_idx on public.money_boards(team_id,campaign_id);
create table public.money_board_generations(
 id uuid primary key default gen_random_uuid(),board_id uuid not null references public.money_boards(id),generation bigint not null,start_minor bigint not null,increment_minor bigint not null,tile_count integer not null,
 created_at timestamptz not null default clock_timestamp(),unique(board_id,generation));
create table public.money_board_tiles(
 id uuid primary key default gen_random_uuid(),board_id uuid not null references public.money_boards(id),generation_id uuid not null references public.money_board_generations(id),ordinal integer not null check(ordinal>0),amount_minor bigint not null check(amount_minor>0),
 created_at timestamptz not null default clock_timestamp(),unique(generation_id,ordinal),unique(generation_id,amount_minor),unique(board_id,id));
create index money_board_tiles_page_idx on public.money_board_tiles(board_id,generation_id,ordinal);
create table public.fundraising_donors(
 id uuid primary key default gen_random_uuid(),display_name text not null check(length(btrim(display_name))between 1 and 100),email text check(length(email)<=254 and email~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),mobile text check(length(mobile)between 5 and 32),
 created_at timestamptz not null default clock_timestamp());
create table public.money_board_reservations(
 id uuid primary key default gen_random_uuid(),tile_id uuid not null references public.money_board_tiles(id),capability_digest text not null unique check(capability_digest~'^[a-f0-9]{64}$'),starts_at timestamptz not null default clock_timestamp(),expires_at timestamptz not null,
 released_at timestamptz,release_reason text check(release_reason in('supporter_cancel','archived','expired')),request_id uuid not null unique,check(expires_at>starts_at));
create index money_board_reservations_tile_idx on public.money_board_reservations(tile_id,expires_at desc);create index money_board_reservations_expiry_idx on public.money_board_reservations(expires_at)where released_at is null;
create table public.fundraising_intents(
 id uuid primary key default gen_random_uuid(),campaign_id uuid not null references public.fundraising_campaigns(id),fundraiser_id uuid references public.fundraising_fundraisers(id),donor_id uuid not null references public.fundraising_donors(id),
 board_id uuid references public.money_boards(id),tile_id uuid references public.money_board_tiles(id),reservation_id uuid references public.money_board_reservations(id),share_id uuid references public.fundraising_shares(id),
 amount_minor bigint not null check(amount_minor between 1 and 1000000000000),currency text not null check(currency~'^[A-Z]{3}$'),anonymous boolean not null,fee_cover boolean not null,
 source_kind text not null check(source_kind in('participant_share','qr','organization_campaign','team_campaign','direct_campaign')),
 provenance jsonb not null,reward_policy jsonb not null,capability_digest text not null unique,expires_at timestamptz not null,created_at timestamptz not null default clock_timestamp(),request_id uuid not null unique,
 check(num_nonnulls(board_id,tile_id,reservation_id)in(0,3)));
create index fundraising_intents_campaign_idx on public.fundraising_intents(campaign_id,created_at desc,id);create index fundraising_intents_fundraiser_idx on public.fundraising_intents(fundraiser_id,created_at desc);create unique index fundraising_intents_reservation_idx on public.fundraising_intents(reservation_id)where reservation_id is not null;
create table public.fundraising_intent_events(
 id uuid primary key default gen_random_uuid(),intent_id uuid not null references public.fundraising_intents(id),state text not null check(state in('awaiting_payment','succeeded','failed','canceled','refunded','partially_refunded','chargeback')),source_reference text,source_event_id uuid references public.fundraising_intent_events(id),amount_minor bigint,
 created_at timestamptz not null default clock_timestamp());
create index fundraising_intent_events_current_idx on public.fundraising_intent_events(intent_id,created_at desc,id);
create table public.fundraising_success_evidence(
 id uuid primary key default gen_random_uuid(),intent_id uuid not null unique references public.fundraising_intents(id),tile_id uuid unique references public.money_board_tiles(id),
 source_system text not null,source_reference text not null,amount_minor bigint not null,currency text not null,provenance jsonb not null,settled_at timestamptz not null,created_at timestamptz not null default clock_timestamp(),unique(source_system,source_reference));
create table public.fundraising_recurring_commitments(
 id uuid primary key default gen_random_uuid(),intent_id uuid not null unique references public.fundraising_intents(id),months integer not null check(months between 6 and 12),amount_minor bigint not null,starts_on date not null,status text not null default 'planned'check(status in('planned','canceled')),created_at timestamptz not null default clock_timestamp());
create table public.fundraising_recurring_occurrences(
 commitment_id uuid not null references public.fundraising_recurring_commitments(id),ordinal integer not null check(ordinal between 1 and 12),due_on date not null,amount_minor bigint not null,primary key(commitment_id,ordinal));
create table public.fundraising_reward_qualifications(
 id uuid primary key default gen_random_uuid(),evidence_id uuid not null unique references public.fundraising_success_evidence(id),policy jsonb not null,qualified boolean not null,trial_days integer check(trial_days in(30,60,90)),
 status text not null check(status in('not_qualified','gift_pending')),provenance jsonb not null,created_at timestamptz not null default clock_timestamp());
create table public.fundraising_history(
 id uuid primary key default gen_random_uuid(),campaign_id uuid not null references public.fundraising_campaigns(id),fundraiser_id uuid references public.fundraising_fundraisers(id),action text not null,actor_person_id uuid references public.people(id),request_id uuid,details jsonb not null default '{}',created_at timestamptz not null default clock_timestamp());
create index fundraising_history_campaign_idx on public.fundraising_history(campaign_id,created_at desc,id);create index fundraising_history_fundraiser_idx on public.fundraising_history(fundraiser_id,created_at desc);
create table boss_private.fundraising_receipts(actor_person_id uuid not null,request_id uuid not null,input_hash text not null,campaign_id uuid not null references public.fundraising_campaigns(id),result jsonb not null,primary key(actor_person_id,request_id));
create table boss_private.fundraising_guest_receipts(request_id uuid primary key,input_hash text not null,capability_digest text not null,result jsonb not null,created_at timestamptz not null default clock_timestamp());
create table boss_private.fundraising_rate_windows(context text not null,window_at timestamptz not null,attempts integer not null,primary key(context,window_at));
-- No direct Data API table access. Deliberately no authenticated/anonymous RLS policy.
do $$declare t text;begin
 foreach t in array array['fundraising_campaigns','fundraising_targets','fundraising_fundraisers','fundraising_shares','money_boards','money_board_generations','money_board_tiles','fundraising_donors','money_board_reservations','fundraising_intents','fundraising_intent_events','fundraising_success_evidence','fundraising_recurring_commitments','fundraising_recurring_occurrences','fundraising_reward_qualifications','fundraising_history']loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 end loop;
 foreach t in array array['fundraising_intents','fundraising_intent_events','fundraising_success_evidence','fundraising_recurring_occurrences','fundraising_reward_qualifications','fundraising_history','money_board_generations','money_board_tiles']loop
 execute format('create trigger immutable_%I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t,t);
 execute format('create trigger immutable_truncate_%I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t,t);
 end loop;
end$$;
revoke all on boss_private.fundraising_receipts,boss_private.fundraising_guest_receipts,boss_private.fundraising_rate_windows from public,anon,authenticated,service_role;
