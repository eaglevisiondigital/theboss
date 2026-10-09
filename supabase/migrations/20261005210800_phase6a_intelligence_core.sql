-- Phase 6A: closed, rebuildable statistics; immutable game seals remain truth.
create table public.stat_competition_classifications (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, game_id uuid not null,
 version bigint not null check(version>0), applies_epoch bigint not null check(applies_epoch>0), classification text not null check(classification in('official','exhibition','scrimmage','practice','controlled_test','excluded','pending')),
 definition_version text not null default 'competition-v1' check(definition_version='competition-v1'),
 reason text not null check(length(btrim(reason)) between 1 and 500), actor_person_id uuid not null references public.people(id),
 created_at timestamptz not null default clock_timestamp(), unique(game_id,version), unique(organization_id,game_id,id),
 foreign key(organization_id,game_id) references public.games(organization_id,id)
);
create table public.stat_game_selections (
 game_id uuid primary key, organization_id uuid not null, finalization_id uuid,
 generation bigint not null default 1 check(generation>0), refreshed_generation bigint not null default 0,
 changed_at timestamptz not null default clock_timestamp(), refreshed_at timestamptz,
 foreign key(organization_id,game_id) references public.games(organization_id,id),
 foreign key(organization_id,game_id,finalization_id) references public.game_finalizations(organization_id,game_id,id),
 check(refreshed_generation>=0 and refreshed_generation<=generation)
);
create table public.stat_game_contributions (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, game_id uuid not null, finalization_id uuid not null,
 epoch bigint not null, roster_revision bigint not null, side text not null check(side in('primary','opponent')), team_id uuid,
 roster_id uuid, person_id uuid references public.people(id), participant_id uuid, season_id uuid, sport_key text not null references public.game_sports(key),
 definition_version text not null default 'intelligence-v1' check(definition_version='intelligence-v1'), engine_version text not null,
 classification_id uuid, classification text not null, source_stat_id uuid not null, tracking_snapshot_id uuid,
 components jsonb not null, coverage jsonb not null, participation jsonb not null, era_basis_innings integer,
 created_at timestamptz not null default clock_timestamp(),
 unique nulls not distinct(finalization_id,side,roster_id,definition_version),
 foreign key(organization_id,game_id,finalization_id) references public.game_finalizations(organization_id,game_id,id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 foreign key(organization_id,team_id) references public.teams(organization_id,id),
 foreign key(organization_id,season_id) references public.seasons(organization_id,id),
 foreign key(participant_id,person_id) references public.participants(id,person_id),
 foreign key(organization_id,game_id,tracking_snapshot_id) references public.game_tracking_snapshots(organization_id,game_id,id),
 foreign key(organization_id,game_id,classification_id) references public.stat_competition_classifications(organization_id,game_id,id),
 check(classification in('official','exhibition','scrimmage','practice','controlled_test','excluded','pending')),
 check(jsonb_typeof(components)='object' and jsonb_typeof(coverage)='object' and jsonb_typeof(participation)='object'),
 check((roster_id is null)=(person_id is null)), check(era_basis_innings is null or era_basis_innings between 1 and 20)
);
create index stat_contribution_origin_idx on public.stat_game_contributions(organization_id,team_id,sport_key,season_id,person_id);
create index stat_contribution_person_idx on public.stat_game_contributions(person_id,sport_key,season_id,game_id);
create index stat_contribution_current_idx on public.stat_game_contributions(game_id,finalization_id);
create table public.stat_origin_summaries (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, team_id uuid not null,
 sport_key text not null references public.game_sports(key), season_id uuid, person_id uuid references public.people(id),
 definition_version text not null default 'intelligence-v1', generation bigint not null default 0, is_current boolean not null default false,
 source_watermark text, refreshed_at timestamptz, summary jsonb not null default '{}',
 unique nulls not distinct(organization_id,team_id,sport_key,season_id,person_id,definition_version),
 foreign key(organization_id,team_id) references public.teams(organization_id,id),foreign key(organization_id,season_id) references public.seasons(organization_id,id)
);
create index stat_summary_person_idx on public.stat_origin_summaries(person_id,sport_key,season_id);
create table public.stat_refresh_work (
 game_id uuid primary key references public.stat_game_selections(game_id), target_generation bigint not null, attempts integer not null default 0,
 created_at timestamptz not null default clock_timestamp()
);
do $$declare t text;begin
 foreach t in array array['stat_competition_classifications','stat_game_selections','stat_game_contributions','stat_origin_summaries','stat_refresh_work']loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on table public.%I from public,anon,authenticated,service_role',t);
 end loop;
 foreach t in array array['stat_competition_classifications','stat_game_contributions']loop
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 end loop;
end$$;
-- Tenant-qualified foreign-key support; no unindexed reference scans.
create index stat_classification_actor_idx on public.stat_competition_classifications(actor_person_id);
create index stat_selection_context_idx on public.stat_game_selections(organization_id,game_id,finalization_id);
create index stat_contribution_finalization_fk_idx on public.stat_game_contributions(organization_id,game_id,finalization_id);
create index stat_contribution_roster_fk_idx on public.stat_game_contributions(organization_id,game_id,roster_id);
create index stat_contribution_classification_fk_idx on public.stat_game_contributions(organization_id,game_id,classification_id);
create index stat_contribution_season_fk_idx on public.stat_game_contributions(organization_id,season_id);
create index stat_summary_season_fk_idx on public.stat_origin_summaries(organization_id,season_id);
create index stat_contribution_sport_fk_idx on public.stat_game_contributions(sport_key);
create index stat_summary_sport_fk_idx on public.stat_origin_summaries(sport_key);

create index stat_contribution_participant_fk_idx on public.stat_game_contributions(participant_id,person_id);
create index stat_contribution_tracking_fk_idx on public.stat_game_contributions(organization_id,game_id,tracking_snapshot_id);
