-- Phase 6B canonical competition decisions and disposable ranking projections.
-- No automatic memberships, publication, official classification or authority.
create function boss_private.ranking_permission_keys() returns text[] language sql immutable set search_path='' as $$
 select array['competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild']::text[]
$$;
insert into public.permissions(key,name,description)
select k,initcap(replace(k,'.',' ')),'Phase 6B potential only; live exact resource and audience authorization required.' from unnest(boss_private.ranking_permission_keys())k;
alter table public.roles drop constraint roles_scope_types_check;
alter table public.roles add constraint roles_scope_types_check check(cardinality(allowed_scope_types)>0 and array_position(allowed_scope_types,null)is null and allowed_scope_types<@array['platform','organization','organization_unit','team','competition','competition_edition']::text[]);
insert into public.roles(key,name,description,allowed_scope_types)values('competition_manager','Competition manager','Explicit assigned competition only; no participant-organization or private athlete authority.',array['competition','competition_edition']);
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where p.key=any(boss_private.ranking_permission_keys())and(
 r.key in('platform_administrator','organization_administrator','competition_manager')
 or(r.key in('athletic_director','program_administrator','sport_administrator')and p.key<>all(array['competition.manage','competition.policy_manage']))
 or(r.key in('head_coach','team_administrator')and p.key=any(array['competition.view','standings.view','leaderboard.view','records.view'])));
create table public.competitions(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),parent_unit_id uuid,
 name text not null check(length(btrim(name))between 1 and 200),status text not null default 'active' check(status in('active','inactive','archived')),
 version bigint not null default 1 check(version>0),created_by_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(organization_id,id),foreign key(organization_id,parent_unit_id)references public.organization_units(organization_id,id));
create table public.competition_editions(
 id uuid primary key default gen_random_uuid(),competition_id uuid not null,organization_id uuid not null,sport_key text not null references public.game_sports(key),season_id uuid,
 name text not null check(length(btrim(name))between 1 and 200),cross_organization boolean not null default false,
 team_result_audience text not null default 'managers'check(team_result_audience in('managers','entry_teams')),
 athlete_cross_organization boolean not null default false check(not athlete_cross_organization),publication_state text not null default 'unpublished'check(publication_state='unpublished'),
 status text not null default 'active'check(status in('active','inactive','archived')),starts_at timestamptz,ends_at timestamptz,
 version bigint not null default 1 check(version>0),generation bigint not null default 1 check(generation>0),created_at timestamptz not null default clock_timestamp(),
 unique(competition_id,id),unique(organization_id,id),foreign key(organization_id,competition_id)references public.competitions(organization_id,id),
 foreign key(organization_id,season_id)references public.seasons(organization_id,id),check(starts_at is null or isfinite(starts_at)),check(ends_at is null or isfinite(ends_at)),check(starts_at is null or ends_at is null or ends_at>starts_at));
create table public.competition_groups(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null references public.competition_editions(id),kind text not null check(kind in('division','conference','pool','region')),
 name text not null check(length(btrim(name))between 1 and 200),organization_id uuid not null,organization_unit_id uuid,status text not null default 'active'check(status in('active','inactive')),
 created_at timestamptz not null default clock_timestamp(),unique(edition_id,id),foreign key(organization_id,edition_id)references public.competition_editions(organization_id,id),foreign key(organization_id,organization_unit_id)references public.organization_units(organization_id,id));
create table public.competition_entries(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null references public.competition_editions(id),team_organization_id uuid not null,team_id uuid not null,season_id uuid,
 status text not null default 'pending'check(status in('pending','active','inactive','ineligible')),entered_at timestamptz not null default clock_timestamp(),ended_at timestamptz,
 approved_by_person_id uuid references public.people(id),version bigint not null default 1 check(version>0),created_at timestamptz not null default clock_timestamp(),
 unique(edition_id,id),foreign key(team_organization_id,team_id)references public.teams(organization_id,id),foreign key(team_organization_id,season_id)references public.seasons(organization_id,id),
 check(isfinite(entered_at)),check(ended_at is null or(isfinite(ended_at)and ended_at>entered_at)),check(status<>'active'or approved_by_person_id is not null));
create unique index competition_entries_open_idx on public.competition_entries(edition_id,team_id)where status in('pending','active')and ended_at is null;
create table public.competition_entry_groups(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null,entry_id uuid not null,group_id uuid not null,
 starts_at timestamptz not null default clock_timestamp(),ends_at timestamptz,status text not null default 'active'check(status in('active','inactive')),
 foreign key(edition_id,entry_id)references public.competition_entries(edition_id,id),foreign key(edition_id,group_id)references public.competition_groups(edition_id,id),
 check(isfinite(starts_at)),check(ends_at is null or(isfinite(ends_at)and ends_at>starts_at)));
create unique index competition_entry_groups_open_idx on public.competition_entry_groups(entry_id,group_id)where status='active'and ends_at is null;
create table public.competition_access_assignments(
 id uuid primary key default gen_random_uuid(),competition_id uuid not null references public.competitions(id),edition_id uuid,person_id uuid not null references public.people(id),role_id uuid not null references public.roles(id),
 status text not null default 'active'check(status in('active','inactive')),starts_at timestamptz not null default clock_timestamp(),ends_at timestamptz,
 granted_by_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(competition_id,edition_id)references public.competition_editions(competition_id,id),check(isfinite(starts_at)),check(ends_at is null or(isfinite(ends_at)and ends_at>starts_at)));
create unique index competition_access_open_idx on public.competition_access_assignments(competition_id,edition_id,person_id,role_id)nulls not distinct where status='active'and ends_at is null;
create table public.standings_policy_revisions(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null references public.competition_editions(id),version bigint not null check(version>0),
 configuration jsonb not null check(jsonb_typeof(configuration)='object'),reason text not null check(length(btrim(reason))between 1 and 500),actor_person_id uuid not null references public.people(id),
 created_at timestamptz not null default clock_timestamp(),unique(edition_id,id),unique(edition_id,version));
alter table public.competition_editions add column standings_policy_id uuid;
alter table public.competition_editions add constraint edition_policy_fk foreign key(id,standings_policy_id)references public.standings_policy_revisions(edition_id,id);
create table public.competition_game_assignments(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null references public.competition_editions(id),source_organization_id uuid not null,game_id uuid not null,
 version bigint not null check(version>0),primary_entry_id uuid not null,opponent_entry_id uuid not null,group_id uuid,
 game_type text not null check(game_type in('league','conference','division','nonconference','tournament','other')),counts_for_standings boolean not null,
 status text not null default 'active'check(status in('active','ended')),source_consent_by_person_id uuid not null references public.people(id),
 reason text not null check(length(btrim(reason))between 1 and 500),actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(edition_id,game_id,version),unique(edition_id,id),foreign key(source_organization_id,game_id)references public.games(organization_id,id),
 foreign key(edition_id,primary_entry_id)references public.competition_entries(edition_id,id),foreign key(edition_id,opponent_entry_id)references public.competition_entries(edition_id,id),
 foreign key(edition_id,group_id)references public.competition_groups(edition_id,id),check(primary_entry_id<>opponent_entry_id));
create table public.competition_game_assignment_groups(
 edition_id uuid not null,assignment_id uuid not null,group_id uuid not null,
 primary key(assignment_id,group_id),foreign key(edition_id,assignment_id)references public.competition_game_assignments(edition_id,id),
 foreign key(edition_id,group_id)references public.competition_groups(edition_id,id));
create table public.competition_rulings(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null references public.competition_editions(id),group_id uuid,assignment_id uuid,primary_entry_id uuid not null,opponent_entry_id uuid,
 kind text not null check(kind in('forfeit','result_override','vacated','points_adjustment','win_adjustment','loss_adjustment','eligibility','reversal','tie_resolution')),
 outcome text check(outcome in('primary','opponent','tie')),amount numeric,standings_primary_score integer,standings_opponent_score integer,reversal_of_id uuid,
 effective_at timestamptz not null default clock_timestamp(),reason text not null check(length(btrim(reason))between 1 and 500),actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(edition_id,id),foreign key(edition_id,group_id)references public.competition_groups(edition_id,id),foreign key(edition_id,assignment_id)references public.competition_game_assignments(edition_id,id),
 foreign key(edition_id,primary_entry_id)references public.competition_entries(edition_id,id),foreign key(edition_id,opponent_entry_id)references public.competition_entries(edition_id,id),
 foreign key(edition_id,reversal_of_id)references public.competition_rulings(edition_id,id),check(primary_entry_id is distinct from opponent_entry_id),check(isfinite(effective_at)),
 check(amount is null or(amount between -1000000 and 1000000)),check((standings_primary_score is null)=(standings_opponent_score is null)),
 check(standings_primary_score is null or(standings_primary_score between 0 and 1000000 and standings_opponent_score between 0 and 1000000)),check((kind='reversal')=(reversal_of_id is not null)));
create unique index competition_ruling_reversal_idx on public.competition_rulings(reversal_of_id)where reversal_of_id is not null;
create table public.ranking_definitions(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null references public.competition_editions(id),source_organization_id uuid not null references public.organizations(id),team_id uuid,season_id uuid,
 product text not null check(product in('leaderboard','records')),source_kind text not null check(source_kind in('athlete_game','athlete_season','athlete_career','team_game','team_season','organization_history')),
 name text not null check(length(btrim(name))between 1 and 200),metric_key text not null check(metric_key~'^[a-z][a-z0-9_]{0,63}$'),metric_kind text not null check(metric_kind in('count','rate')),direction text not null check(direction in('high','low')),
 stat_definition_version text not null default 'intelligence-v1'check(stat_definition_version='intelligence-v1'),qualification jsonb not null default '{}'check(jsonb_typeof(qualification)='object'),competition_only boolean not null default true,allow_partial boolean not null default false,
 status text not null default 'active'check(status in('active','inactive')),version bigint not null default 1 check(version>0),created_at timestamptz not null default clock_timestamp(),actor_person_id uuid not null references public.people(id),
 unique(edition_id,id),foreign key(source_organization_id,team_id)references public.teams(organization_id,id),foreign key(source_organization_id,season_id)references public.seasons(organization_id,id),
 check(source_kind not in('athlete_season','team_season')or season_id is not null),check(product<>'leaderboard'or source_kind in('athlete_season','athlete_career','team_season')));
create table public.ranking_scopes(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null references public.competition_editions(id),product text not null check(product in('standings','leaderboard','records')),group_id uuid,definition_id uuid references public.ranking_definitions(id),
 target_generation bigint not null default 1,published_generation bigint not null default 0,source_manifest jsonb not null default '[]',source_hash text,refreshed_at timestamptz,
 valid_until timestamptz,state text not null default 'pending'check(state in('current','refreshing','pending','unavailable')),reason text,build_cursor text,
 unique(id,definition_id),unique nulls not distinct(edition_id,product,group_id,definition_id),foreign key(edition_id,group_id)references public.competition_groups(edition_id,id),foreign key(edition_id,definition_id)references public.ranking_definitions(edition_id,id),
 check(published_generation>=0 and target_generation>=published_generation),check((product='standings')=(definition_id is null)));
create table public.standings_rows(
 scope_id uuid not null references public.ranking_scopes(id)on delete cascade,entry_id uuid not null references public.competition_entries(id),rank integer not null check(rank>0),
 wins numeric not null,losses numeric not null,ties numeric not null,games_played numeric not null,points numeric,win_percentage numeric,scoring_for numeric,scoring_against numeric,
 metrics jsonb not null,explanation jsonb not null,primary key(scope_id,entry_id));
create index standings_rows_rank_idx on public.standings_rows(scope_id,rank,entry_id);
create table public.ranking_candidates(
 id uuid primary key default gen_random_uuid(),scope_id uuid not null references public.ranking_scopes(id)on delete cascade,subject_key text not null,person_id uuid references public.people(id),team_id uuid references public.teams(id),
 built_generation bigint not null default 0,value numeric,rank integer,qualification_state text not null check(qualification_state in('qualified','incomplete','below_minimum','unqualified','no_policy','not_applicable')),
 qualification jsonb not null,coverage jsonb not null,summary jsonb not null,source_manifest jsonb not null,achieved_at timestamptz,
 unique(scope_id,subject_key),check(rank is null or rank>0));
alter table public.ranking_candidates add unique(scope_id,id);
create index ranking_candidates_page_idx on public.ranking_candidates(scope_id,rank,subject_key);
create table public.record_events(
 id uuid primary key default gen_random_uuid(),scope_id uuid not null,definition_id uuid not null references public.ranking_definitions(id),subject_key text not null,event_key text not null unique,
 event_type text not null check(event_type in('recognized','co_holder_added','superseded','invalidated_by_source_correction','restored','policy_superseded')),
 value numeric not null,achieved_at timestamptz not null,recognized_at timestamptz not null default clock_timestamp(),source_manifest jsonb not null,qualification jsonb not null,
 generation bigint not null,previous_event_id uuid,unique(scope_id,id),unique(scope_id,subject_key,id),foreign key(scope_id,definition_id)references public.ranking_scopes(id,definition_id),foreign key(scope_id,previous_event_id)references public.record_events(scope_id,id));
create index record_events_history_idx on public.record_events(definition_id,recognized_at,id);
create table public.record_current_holders(
 scope_id uuid not null,definition_id uuid not null references public.ranking_definitions(id),subject_key text not null,event_id uuid not null,candidate_id uuid not null,
 primary key(scope_id,subject_key),foreign key(scope_id,definition_id)references public.ranking_scopes(id,definition_id),foreign key(scope_id,subject_key,event_id)references public.record_events(scope_id,subject_key,id),foreign key(scope_id,candidate_id)references public.ranking_candidates(scope_id,id));
create table public.ranking_refresh_work(
 scope_id uuid primary key references public.ranking_scopes(id)on delete cascade,target_generation bigint not null,attempts integer not null default 0,claimed_until timestamptz,created_at timestamptz not null default clock_timestamp());
create table boss_private.ranking_operation_receipts(
 actor_person_id uuid not null references public.people(id),request_id uuid not null,input_hash text not null,result jsonb not null,created_at timestamptz not null default clock_timestamp(),primary key(actor_person_id,request_id));
alter table boss_private.ranking_operation_receipts enable row level security;
revoke all on table boss_private.ranking_operation_receipts from public,anon,authenticated,service_role;
do $$declare t text;c record;begin
 foreach t in array array['competitions','competition_editions','competition_groups','competition_entries','competition_entry_groups','competition_access_assignments','standings_policy_revisions','competition_game_assignments','competition_game_assignment_groups','competition_rulings','ranking_definitions','ranking_scopes','standings_rows','ranking_candidates','record_events','record_current_holders','ranking_refresh_work']loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on table public.%I from public,anon,authenticated,service_role',t);
 -- Index every referencing column vector; closed tables never rely on scanning another tenant.
 for c in select conname,string_agg(quote_ident(a.attname),','order by k.n)cols from pg_constraint fk cross join lateral unnest(fk.conkey)with ordinality k(attnum,n)join pg_attribute a on a.attrelid=fk.conrelid and a.attnum=k.attnum where fk.contype='f'and fk.conrelid=format('public.%I',t)::regclass group by conname loop
 execute format('create index %I on public.%I(%s)',left(t,36)||'_fk_'||substr(md5(c.conname),1,12),t,c.cols);
 end loop;
 end loop;
 foreach t in array array['standings_policy_revisions','competition_game_assignments','competition_game_assignment_groups','competition_rulings','record_events']loop execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
end$$;
create trigger competitions_identity before update on public.competitions for each row execute function boss_private.preserve_row_identity('id','organization_id','parent_unit_id','created_by_person_id','created_at');
create trigger competition_editions_identity before update on public.competition_editions for each row execute function boss_private.preserve_row_identity('id','competition_id','organization_id','sport_key','season_id','created_at');
create trigger competition_entries_identity before update on public.competition_entries for each row execute function boss_private.preserve_row_identity('id','edition_id','team_organization_id','team_id','season_id','entered_at','created_at');
create trigger competition_access_identity before update on public.competition_access_assignments for each row execute function boss_private.preserve_row_identity('id','competition_id','edition_id','person_id','role_id','starts_at','granted_by_person_id','created_at');
create trigger ranking_definitions_identity before update on public.ranking_definitions for each row execute function boss_private.preserve_row_identity('id','edition_id','source_organization_id','team_id','season_id','product','source_kind','metric_key','metric_kind','direction','qualification','competition_only','allow_partial','created_at','actor_person_id');
-- Meaning/policy revisions are append-only; current lifecycle may be ended without rewriting meaning.
revoke all on function boss_private.ranking_permission_keys()from public,anon,authenticated,service_role;

create index ranking_candidate_generation_idx on public.ranking_candidates(scope_id,built_generation,subject_key);
create index stat_summary_ranking_scope_idx on public.stat_origin_summaries(organization_id,sport_key,season_id,team_id,person_id);
