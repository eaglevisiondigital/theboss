-- Phase 6E: recognition over canonical sources, never a second athlete/stat system.
-- No milestone, tier, award, public audience or personal championship is seeded.
insert into public.permissions(key,name,description)values
 ('achievement_definitions.manage','Manage achievement definitions','Version finite recognition rules in the exact issuing scope'),
 ('awards.issue','Nominate or issue awards','Issue bounded organization decisions; approval policy still applies'),
 ('awards.approve','Approve organization awards','Approve or rescind scoped human-selected awards')
on conflict(key)do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.key in('platform_administrator','organization_administrator')and p.key in('achievement_definitions.manage','awards.issue','awards.approve')on conflict do nothing;

create table public.achievement_definitions(
 id uuid primary key default gen_random_uuid(),owner_kind text not null check(owner_kind in('boss','organization')),
 organization_id uuid references public.organizations(id),definition_key text not null check(definition_key~'^[a-z][a-z0-9_]{0,63}$'),
 status text not null default 'active'check(status in('active','inactive','archived')),current_revision_id uuid,
 version bigint not null default 1 check(version>0),created_by_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 check((owner_kind='boss')=(organization_id is null)),unique nulls not distinct(organization_id,definition_key));
create table public.achievement_definition_revisions(
 id uuid primary key default gen_random_uuid(),definition_id uuid not null references public.achievement_definitions(id),revision bigint not null check(revision>0),
 name text not null check(length(btrim(name))between 1 and 160),description text not null default ''check(length(description)<=800),
 subject_type text not null check(subject_type in('athlete','team','organization')),
 category text not null check(category in('statistical_milestone','record','leaderboard','tournament','standings','mvp','offensive_player','defensive_player','most_improved','sportsmanship','leadership','academic_character','coachs_award')),
 source_kind text not null check(source_kind in('athlete_game','athlete_season','athlete_career','team_season','record','leaderboard','tournament','standings','organization_decision')),
 sport_key text references public.game_sports(key),team_id uuid references public.teams(id),season_id uuid references public.seasons(id),
 metric_key text check(metric_key~'^[a-z][a-z0-9_]{0,63}$'),threshold numeric check(threshold>0 and threshold<=1000000000),
 ranking_definition_id uuid references public.ranking_definitions(id),bracket_id uuid references public.tournament_brackets(id),
 standings_scope_id uuid references public.ranking_scopes(id),placement integer check(placement between 1 and 10),
 badge_icon text not null default'trophy'check(badge_icon in('trophy','medal','star','record','milestone','shield','team')),
 tier text check(tier in('bronze','silver','gold','elite')),approval_required boolean not null default true,
 showcase_eligible boolean not null default false,athlete_championship_policy text not null default'none'check(athlete_championship_policy in('none','sealed_participation')),
 effective_at timestamptz not null default clock_timestamp(),historical_evaluation boolean not null default false,
 actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(definition_id,revision),unique(definition_id,id),check(isfinite(effective_at)),
 check((source_kind in('athlete_game','athlete_season','athlete_career','team_season'))=(metric_key is not null and threshold is not null)),
 check((source_kind in('record','leaderboard'))=(ranking_definition_id is not null)),
 check((source_kind='tournament')=(bracket_id is not null)),check((source_kind='standings')=(standings_scope_id is not null)),
 check(source_kind not in('record','leaderboard')or not showcase_eligible),
 check(source_kind not in('athlete_game','athlete_season','athlete_career','team_season')or sport_key is not null),
 check(source_kind<>'team_season'or subject_type='team'),check(source_kind not like'athlete_%'or subject_type='athlete'),
 check(source_kind not in('tournament','standings')or subject_type='team'or(source_kind='tournament'and subject_type='athlete'and athlete_championship_policy='sealed_participation')),
 check(source_kind<>'organization_decision'or category in('mvp','offensive_player','defensive_player','most_improved','sportsmanship','leadership','academic_character','coachs_award')),
 check(source_kind<>'tournament'or(placement is not null and placement in(1,2,3))),check(source_kind<>'leaderboard'or(placement is not null and placement between 1 and 10)),
 check(source_kind<>'standings'or(placement is not null and placement=1)));
alter table public.achievement_definitions add constraint achievement_definition_current_fk foreign key(id,current_revision_id)references public.achievement_definition_revisions(definition_id,id);
alter table public.athlete_achievements add column definition_revision_id uuid references public.achievement_definition_revisions(id);
create index athlete_achievement_definition_fk_idx on public.athlete_achievements(definition_revision_id);

-- Only team/organization recipients live here. Athletes remain Phase 6C rows.
create table public.entity_achievements(
 id uuid primary key default gen_random_uuid(),subject_type text not null check(subject_type in('team','organization')),
 organization_id uuid not null references public.organizations(id),team_id uuid,definition_revision_id uuid not null references public.achievement_definition_revisions(id),
 title text not null check(length(btrim(title))between 1 and 160),achieved_at timestamptz not null,recognized_at timestamptz not null default clock_timestamp(),
 verification_level text not null check(verification_level in('boss_verified','organization_verified')),actor_person_id uuid not null references public.people(id),
 foreign key(organization_id,team_id)references public.teams(organization_id,id),check((subject_type='team')=(team_id is not null)),check(isfinite(achieved_at)));
create table public.achievement_recognitions(
 id uuid primary key default gen_random_uuid(),definition_revision_id uuid not null references public.achievement_definition_revisions(id),
 athlete_achievement_id uuid unique references public.athlete_achievements(id),entity_achievement_id uuid unique references public.entity_achievements(id),profile_id uuid references public.athlete_profiles(id),
 organization_id uuid not null references public.organizations(id),team_id uuid,person_id uuid references public.people(id),season_id uuid references public.seasons(id),sport_key text references public.game_sports(key),
 subject_key text not null,context_key text not null,source_type text not null check(source_type in('stat_game','stat_summary','record_event','ranking_candidate','tournament_bracket','standings_scope','organization_decision')),
 source_id uuid not null,source_generation bigint not null check(source_generation>=0),source_hash text not null,source_manifest jsonb not null check(jsonb_typeof(source_manifest)='object'),
 state text not null check(state in('current','historical','corrected','revoked')),current_holder boolean not null default false,co_holder boolean not null default false,
 achieved_at timestamptz not null,recognized_at timestamptz not null default clock_timestamp(),version bigint not null default 1 check(version>0),
 foreign key(organization_id,team_id)references public.teams(organization_id,id),unique(definition_revision_id,organization_id,subject_key,context_key),
 check((athlete_achievement_id is null)<>(entity_achievement_id is null)),check((athlete_achievement_id is not null)=(profile_id is not null and person_id is not null)),check(isfinite(achieved_at)));
create index achievement_recognition_person_idx on public.achievement_recognitions(person_id,recognized_at desc,id);
create index achievement_recognition_origin_idx on public.achievement_recognitions(organization_id,team_id,recognized_at desc,id);
create index achievement_recognition_source_idx on public.achievement_recognitions(source_type,source_id);
create table public.achievement_history(
 id uuid primary key default gen_random_uuid(),recognition_id uuid not null references public.achievement_recognitions(id),version bigint not null,
 event_type text not null check(event_type in('recognized','published','hidden','superseded','corrected','revoked','restored','refreshed')),
 state text not null,source_generation bigint not null,source_id uuid not null,source_manifest jsonb not null,
 actor_person_id uuid references public.people(id),created_at timestamptz not null default clock_timestamp(),unique(recognition_id,version));
create table public.achievement_display_choices(
 profile_id uuid not null references public.athlete_profiles(id),athlete_achievement_id uuid primary key references public.athlete_achievements(id),
 show_on_profile boolean not null default true,show_on_showcase boolean not null default false,
 actor_person_id uuid not null references public.people(id),updated_at timestamptz not null default clock_timestamp());
create table public.award_nominations(
 id uuid primary key default gen_random_uuid(),definition_revision_id uuid not null references public.achievement_definition_revisions(id),organization_id uuid not null references public.organizations(id),
 team_id uuid,season_id uuid references public.seasons(id),profile_id uuid references public.athlete_profiles(id),
 subject_type text not null check(subject_type in('athlete','team','organization')),subject_key text not null,
 state text not null default'nominated'check(state in('nominated','declined','withdrawn','awarded','revoked')),version bigint not null default 1,
 achieved_at timestamptz not null,recognition_id uuid references public.achievement_recognitions(id),
 nominated_by_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,team_id)references public.teams(organization_id,id),check(isfinite(achieved_at)),check((subject_type='athlete')=(profile_id is not null)));
create unique index award_nomination_once_idx on public.award_nominations(definition_revision_id,organization_id,subject_key,season_id)nulls not distinct;
create table public.award_decisions(
 id uuid primary key default gen_random_uuid(),nomination_id uuid not null references public.award_nominations(id),version bigint not null,
 decision text not null check(decision in('nominated','approved','declined','withdrawn','revoked','restored')),
 private_note text not null check(length(btrim(private_note))between 1 and 500),actor_person_id uuid not null references public.people(id),
 created_at timestamptz not null default clock_timestamp(),unique(nomination_id,version));
create table public.achievement_competition_closures(
 id uuid primary key default gen_random_uuid(),scope_id uuid not null references public.ranking_scopes(id),generation bigint not null,
 source_hash text not null,champion_entry_id uuid not null references public.competition_entries(id),
 reason text not null check(length(btrim(reason))between 1 and 500),actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),unique(scope_id,generation));
create table public.achievement_refresh_work(
 definition_revision_id uuid not null references public.achievement_definition_revisions(id),organization_id uuid not null references public.organizations(id),
 target_generation bigint not null default 1,published_generation bigint not null default 0,cursor text,
 state text not null default'pending'check(state in('pending','processing','current','unavailable')),updated_at timestamptz not null default clock_timestamp(),
 primary key(definition_revision_id,organization_id),check(target_generation>=published_generation));
create table boss_private.achievement_operation_receipts(actor_person_id uuid not null references public.people(id),request_id uuid not null,input_hash text not null,result jsonb not null,created_at timestamptz not null default clock_timestamp(),primary key(actor_person_id,request_id));
alter table boss_private.achievement_operation_receipts enable row level security;revoke all on table boss_private.achievement_operation_receipts from public,anon,authenticated,service_role;
do $$declare t text;c record;begin
 foreach t in array array['achievement_definitions','achievement_definition_revisions','entity_achievements','achievement_recognitions','achievement_history','achievement_display_choices','award_nominations','award_decisions','achievement_competition_closures','achievement_refresh_work']loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on table public.%I from public,anon,authenticated,service_role',t);
  for c in select conname,string_agg(quote_ident(a.attname),','order by k.n)cols from pg_constraint fk cross join lateral unnest(fk.conkey)with ordinality k(attnum,n)join pg_attribute a on a.attrelid=fk.conrelid and a.attnum=k.attnum where fk.contype='f'and fk.conrelid=format('public.%I',t)::regclass group by conname loop execute format('create index %I on public.%I(%s)',left(t,32)||'_fk_'||substr(md5(c.conname),1,12),t,c.cols);end loop;
 end loop;
 foreach t in array array['achievement_definition_revisions','entity_achievements','achievement_history','award_decisions','achievement_competition_closures']loop
  execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
  execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);
 end loop;
end$$;
create trigger achievement_definition_identity before update on public.achievement_definitions for each row execute function boss_private.preserve_row_identity('id','owner_kind','organization_id','definition_key','created_by_person_id','created_at');
create trigger achievement_recognition_identity before update on public.achievement_recognitions for each row execute function boss_private.preserve_row_identity('id','definition_revision_id','athlete_achievement_id','entity_achievement_id','profile_id','organization_id','team_id','person_id','season_id','sport_key','subject_key','context_key','recognized_at');
create trigger award_nomination_identity before update on public.award_nominations for each row execute function boss_private.preserve_row_identity('id','definition_revision_id','organization_id','team_id','season_id','profile_id','subject_type','subject_key','achieved_at','nominated_by_person_id','created_at');
