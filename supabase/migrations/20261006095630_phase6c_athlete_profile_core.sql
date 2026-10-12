-- Phase 6C: one private-by-default presentation profile for each canonical participant.
insert into public.permissions(key,name,description) values
 ('athlete_profiles.view','View athlete profiles','View an authorized athlete profile projection'),
 ('athlete_profiles.manage','Manage athlete profiles','Manage permitted athlete presentation fields'),
 ('athlete_profiles.verify','Verify athlete profile facts','Verify measurements and organization achievements'),
 ('recruiting_showcases.view','View recruiting showcases','View authorized recruiting showcase controls'),
 ('recruiting_showcases.manage','Manage recruiting showcases','Manage permitted showcase revisions and links'),
 ('recruiting_showcases.publish','Publish recruiting showcases','Publish only with current explicit subject consent')
on conflict(key)do update set name=excluded.name,description=excluded.description,status='active';

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where p.key=any(array['athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish'])
and r.key in('platform_administrator','organization_administrator') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where p.key=any(array['athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view'])
and r.key in('athletic_director','program_administrator','sport_administrator') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where p.key=any(array['athlete_profiles.view','athlete_profiles.verify','recruiting_showcases.view'])
and r.key in('head_coach','team_administrator') on conflict do nothing;

create table public.athlete_profiles(
 id uuid primary key default gen_random_uuid(),participant_id uuid not null unique,person_id uuid not null unique,
 status text not null default 'active'check(status in('active','inactive','archived')),
 visibility text not null default 'private'check(visibility in('private','athlete_guardian','current_team_staff','organization_staff')),
 current_revision_id uuid,version bigint not null default 1 check(version>0),created_by_person_id uuid not null references public.people(id),
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 foreign key(participant_id,person_id)references public.participants(id,person_id));
create table public.athlete_profile_revisions(
 id uuid primary key default gen_random_uuid(),profile_id uuid not null references public.athlete_profiles(id),revision bigint not null check(revision>0),
 entered_by text not null check(entered_by in('athlete','guardian','staff','administrator')),
 safe_fields jsonb not null default '{}'check(jsonb_typeof(safe_fields)='object'),actor_person_id uuid not null references public.people(id),
 created_at timestamptz not null default clock_timestamp(),unique(profile_id,revision),unique(profile_id,id));
alter table public.athlete_profiles add constraint athlete_profiles_current_revision_fk foreign key(id,current_revision_id)references public.athlete_profile_revisions(profile_id,id);

create table public.athlete_measurables(
 id uuid primary key default gen_random_uuid(),profile_id uuid not null references public.athlete_profiles(id),sport_key text not null references public.game_sports(key),
 metric_key text not null check(metric_key~'^[a-z][a-z0-9_]{0,63}$'),value numeric not null,unit text not null check(unit~'^[a-z][a-z0-9_/%.-]{0,31}$'),
 measured_on date not null,provenance text not null check(provenance in('self_reported','guardian_reported','coach_verified','organization_verified','event_verified')),
 verification_state text not null check(verification_state in('unverified','verified','withdrawn')),
 visibility text not null default 'private'check(visibility in('private','profile','showcase')),
 organization_id uuid references public.organizations(id),team_id uuid,source_label text check(source_label is null or length(btrim(source_label))between 1 and 160),
 actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,team_id)references public.teams(organization_id,id));
create index athlete_measurables_profile_idx on public.athlete_measurables(profile_id,sport_key,metric_key,measured_on desc,id);

create table public.athlete_achievements(
 id uuid primary key default gen_random_uuid(),profile_id uuid not null references public.athlete_profiles(id),sport_key text references public.game_sports(key),
 achievement_type text not null check(achievement_type in('team_award','organization_award','tournament_award','record','statistical_milestone','academic_character')),
 title text not null check(length(btrim(title))between 1 and 160),achieved_on date,season_id uuid references public.seasons(id),
 organization_id uuid references public.organizations(id),verification_level text not null check(verification_level in('self_entered','organization_verified','boss_verified')),
 visibility text not null default 'private'check(visibility in('private','profile','showcase')),
 source_record_event_id uuid references public.record_events(id),source_ranking_candidate_id uuid references public.ranking_candidates(id),
 actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 check(source_record_event_id is null or achievement_type='record'),check(source_record_event_id is null or verification_level='boss_verified'));
create index athlete_achievements_profile_idx on public.athlete_achievements(profile_id,achieved_on desc,id);

create table public.athlete_profile_verifications(
 id uuid primary key default gen_random_uuid(),profile_id uuid not null references public.athlete_profiles(id),profile_revision_id uuid not null,
 field_key text not null check(field_key~'^[a-z][a-z0-9_.]{0,63}$'),field_digest text not null check(field_digest~'^[a-f0-9]{64}$'),
 organization_id uuid not null references public.organizations(id),team_id uuid,verification_state text not null check(verification_state in('verified','withdrawn')),
 actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(profile_id,profile_revision_id)references public.athlete_profile_revisions(profile_id,id),foreign key(organization_id,team_id)references public.teams(organization_id,id));
create index athlete_verifications_profile_idx on public.athlete_profile_verifications(profile_id,field_key,created_at desc,id);

create table public.athlete_media_links(
 id uuid primary key default gen_random_uuid(),profile_id uuid not null references public.athlete_profiles(id),sport_key text references public.game_sports(key),
 media_type text not null check(media_type in('highlight_video','profile_image')),
 url text not null check(length(url)between 12 and 2048 and url~'^https://'),title text not null check(length(btrim(title))between 1 and 120),
 source text not null check(source in('athlete','guardian','organization','external_provider')),
 rights_state text not null check(rights_state in('approved_private','approved_showcase','withdrawn')),
 visibility text not null default 'private'check(visibility in('private','profile','showcase')),
 actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp());
create index athlete_media_profile_idx on public.athlete_media_links(profile_id,created_at desc,id);

create table public.recruiting_showcases(
 id uuid primary key default gen_random_uuid(),profile_id uuid not null unique references public.athlete_profiles(id),
 state text not null default 'draft'check(state in('draft','active','disabled','archived')),
 current_revision_id uuid,published_revision_id uuid,current_consent_id uuid,version bigint not null default 1 check(version>0),
 created_by_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp());
create table public.recruiting_showcase_revisions(
 id uuid primary key default gen_random_uuid(),showcase_id uuid not null references public.recruiting_showcases(id),profile_revision_id uuid not null references public.athlete_profile_revisions(id),
 revision bigint not null check(revision>0),sport_keys text[] not null default '{}',visible_categories text[] not null default '{}',stat_metric_keys text[] not null default '{}',
 presentation jsonb not null default '{}'check(jsonb_typeof(presentation)='object'),actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(showcase_id,revision),unique(showcase_id,id),check(array_position(sport_keys,null)is null),
 check(array_position(visible_categories,null)is null and visible_categories<@array['overview','sports','positions','measurables','statistics','records','achievements','history','media']::text[]),
 check(array_position(stat_metric_keys,null)is null));
create table public.recruiting_consents(
 id uuid primary key default gen_random_uuid(),showcase_id uuid not null references public.recruiting_showcases(id),showcase_revision_id uuid not null,
 subject_person_id uuid not null references public.people(id),actor_person_id uuid not null references public.people(id),actor_kind text not null check(actor_kind in('athlete','guardian')),
 approved_categories text[] not null,consent_version bigint not null check(consent_version>0),status text not null default 'active'check(status in('active','revoked','expired')),
 granted_at timestamptz not null default clock_timestamp(),revoked_at timestamptz,expires_at timestamptz,
 foreign key(showcase_id,showcase_revision_id)references public.recruiting_showcase_revisions(showcase_id,id),
 check(array_position(approved_categories,null)is null),check(expires_at is null or expires_at>granted_at),check((status='revoked')=(revoked_at is not null)));
create unique index recruiting_consents_active_idx on public.recruiting_consents(showcase_id)where status='active';
create index recruiting_consents_subject_idx on public.recruiting_consents(subject_person_id,granted_at desc);

alter table public.recruiting_showcases add constraint recruiting_showcases_current_revision_fk foreign key(id,current_revision_id)references public.recruiting_showcase_revisions(showcase_id,id);
alter table public.recruiting_showcases add constraint recruiting_showcases_published_revision_fk foreign key(id,published_revision_id)references public.recruiting_showcase_revisions(showcase_id,id);
alter table public.recruiting_showcases add constraint recruiting_showcases_current_consent_fk foreign key(current_consent_id)references public.recruiting_consents(id);

create table public.recruiting_share_links(
 id uuid primary key default gen_random_uuid(),showcase_id uuid not null references public.recruiting_showcases(id),token_digest text not null unique check(token_digest~'^[a-f0-9]{64}$'),
 token_prefix text not null check(token_prefix~'^[A-Za-z0-9_-]{6,16}$'),status text not null default 'active'check(status in('active','revoked','expired')),
 expires_at timestamptz,revoked_at timestamptz,last_accessed_at timestamptz,access_count bigint not null default 0 check(access_count>=0),
 created_by_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 check(expires_at is null or expires_at>created_at),check((status='revoked')=(revoked_at is not null)));
create index recruiting_share_links_showcase_idx on public.recruiting_share_links(showcase_id,status,expires_at);

create table boss_private.athlete_profile_operation_receipts(
 actor_person_id uuid not null references public.people(id),request_id uuid not null,input_hash text not null,result jsonb not null,
 created_at timestamptz not null default clock_timestamp(),primary key(actor_person_id,request_id));

do $$declare t text;begin
 foreach t in array array['athlete_profiles','athlete_profile_revisions','athlete_measurables','athlete_achievements','athlete_profile_verifications','athlete_media_links','recruiting_showcases','recruiting_showcase_revisions','recruiting_consents','recruiting_share_links']loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on table public.%I from public,anon,authenticated,service_role',t);
 end loop;
 foreach t in array array['athlete_profile_revisions','athlete_measurables','athlete_achievements','athlete_profile_verifications','athlete_media_links','recruiting_showcase_revisions']loop
  execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
  execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);
 end loop;
end$$;
alter table boss_private.athlete_profile_operation_receipts enable row level security;
revoke all on table boss_private.athlete_profile_operation_receipts from public,anon,authenticated,service_role;
create trigger athlete_profiles_identity before update on public.athlete_profiles for each row execute function boss_private.preserve_row_identity('id','participant_id','person_id','created_by_person_id','created_at');
create trigger recruiting_showcases_identity before update on public.recruiting_showcases for each row execute function boss_private.preserve_row_identity('id','profile_id','created_by_person_id','created_at');

-- Every referencing vector is indexed for bounded authorization and managed-Postgres FK checks.
create index athlete_profiles_current_revision_idx on public.athlete_profiles(id,current_revision_id);
create index athlete_profiles_participant_person_idx on public.athlete_profiles(participant_id,person_id);
create index athlete_profiles_creator_idx on public.athlete_profiles(created_by_person_id);
create index athlete_profile_revisions_actor_idx on public.athlete_profile_revisions(actor_person_id);
create index athlete_measurables_sport_idx on public.athlete_measurables(sport_key);
create index athlete_measurables_origin_idx on public.athlete_measurables(organization_id,team_id);
create index athlete_measurables_actor_idx on public.athlete_measurables(actor_person_id);
create index athlete_achievements_sport_idx on public.athlete_achievements(sport_key);
create index athlete_achievements_season_idx on public.athlete_achievements(season_id);
create index athlete_achievements_organization_idx on public.athlete_achievements(organization_id);
create index athlete_achievements_record_idx on public.athlete_achievements(source_record_event_id);
create index athlete_achievements_ranking_idx on public.athlete_achievements(source_ranking_candidate_id);
create index athlete_achievements_actor_idx on public.athlete_achievements(actor_person_id);
create index athlete_verifications_revision_idx on public.athlete_profile_verifications(profile_id,profile_revision_id);
create index athlete_verifications_origin_idx on public.athlete_profile_verifications(organization_id,team_id);
create index athlete_verifications_actor_idx on public.athlete_profile_verifications(actor_person_id);
create index athlete_media_sport_idx on public.athlete_media_links(sport_key);
create index athlete_media_actor_idx on public.athlete_media_links(actor_person_id);
create index recruiting_showcases_current_revision_idx on public.recruiting_showcases(id,current_revision_id);
create index recruiting_showcases_published_revision_idx on public.recruiting_showcases(id,published_revision_id);
create index recruiting_showcases_consent_idx on public.recruiting_showcases(current_consent_id);
create index recruiting_showcases_creator_idx on public.recruiting_showcases(created_by_person_id);
create index recruiting_showcase_revision_profile_idx on public.recruiting_showcase_revisions(profile_revision_id);
create index recruiting_showcase_revision_actor_idx on public.recruiting_showcase_revisions(actor_person_id);
create index recruiting_consents_revision_idx on public.recruiting_consents(showcase_id,showcase_revision_id);
create index recruiting_consents_actor_idx on public.recruiting_consents(actor_person_id);
create index recruiting_share_creator_idx on public.recruiting_share_links(created_by_person_id);
