-- Phase 5A: one operating identity per canonical competitive occurrence.
-- Calendar remains scheduling authority. Raw game records are closed.
-- Monotonic revision metadata preserves the existing module activation model.
alter table public.organization_modules add column version bigint not null default 1 check(version>0);
create function boss_private.games_module_version() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.version is distinct from old.version then raise exception 'Module revision cannot be rewritten' using errcode='23514';end if;
 if(new.status,new.starts_at,new.ends_at,new.configuration) is distinct from(old.status,old.starts_at,old.ends_at,old.configuration) then
 new.version:=old.version+1;new.updated_at:=clock_timestamp();end if;
 return new;
end $$;
create trigger games_module_revision before update on public.organization_modules for each row execute function boss_private.games_module_version();
insert into public.permissions(key,name,description) values
 ('games.view','View Game Center','Current scoped safe game projection'),
 ('games.create','Link a canonical game','Create an operating layer for an authorized Calendar occurrence'),
 ('games.manage','Manage scoped games','Manage roster and operator foundation in exact current scope'),
 ('games.operate','Operate an assigned game','Explicit current game assignment is independently required'),
 ('games.finalize','Finalize a scoped game','Seal a game score and roster revision'),
 ('games.correct','Correct a finalized game','Elevated audited reopen and correction workflow'),
 ('games.publish','Publish a game summary','Independent Calendar publication boundary still applies');
with mappings(role_key,keys) as(values
 ('super_administrator',array['games.view','games.create','games.manage','games.operate','games.finalize','games.correct','games.publish']),
 ('platform_administrator',array['games.view','games.create','games.manage','games.operate','games.finalize','games.correct','games.publish']),
 ('organization_owner',array['games.view','games.create','games.manage','games.operate','games.finalize','games.correct','games.publish']),
 ('organization_administrator',array['games.view','games.create','games.manage','games.operate','games.finalize','games.correct','games.publish']),
 ('athletic_director',array['games.view','games.create','games.manage','games.operate','games.finalize','games.correct']),
 ('program_administrator',array['games.view','games.create','games.manage','games.operate','games.finalize']),
 ('sport_administrator',array['games.view','games.create','games.manage','games.operate','games.finalize']),
 ('team_administrator',array['games.view','games.manage']),
 ('head_coach',array['games.view','games.manage']),
 ('assistant_coach',array['games.view']),('team_staff',array['games.view']),
 ('scorekeeper',array['games.view','games.operate']),('livestream_operator',array['games.view'])
)
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from mappings m join public.roles r on r.key=m.role_key join public.permissions p on p.key=any(m.keys);

create table public.game_sports(
 key text primary key,name text not null,status text not null default 'active' check(status in('active','inactive')),
 check(key in('basketball','football','soccer','volleyball','baseball','softball'))
);
insert into public.game_sports(key,name) values('basketball','Basketball'),('football','Football'),('soccer','Soccer'),('volleyball','Volleyball'),('baseball','Baseball'),('softball','Softball');
create table public.games(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),
 event_id uuid not null,occurrence_key text not null,occurrence_mode text not null check(occurrence_mode in('single','recurring')),
 primary_team_id uuid not null,opponent_team_id uuid,external_opponent_name text,
 parent_unit_id uuid,season_id uuid,sport_key text not null references public.game_sports(key),
 home_away text not null check(home_away in('home','away','neutral')),
 competition_type text not null default 'standard' check(competition_type in('standard','tournament')),
 status text not null default 'scheduled' check(status in('scheduled','pregame','live','paused','delayed','suspended','final','canceled','postponed','abandoned')),
 scheduled_start_at timestamptz not null,scheduled_end_at timestamptz not null,schedule_status text not null,
 venue_id uuid,visibility text not null,publication_state text not null default 'unpublished',
 primary_score integer not null default 0 check(primary_score between 0 and 1000000),opponent_score integer not null default 0 check(opponent_score between 0 and 1000000),
 final_primary_score integer,final_opponent_score integer,winner_side text check(winner_side in('primary','opponent')),tied boolean,
 roster_revision bigint not null default 0 check(roster_revision>=0),finalization_count bigint not null default 0 check(finalization_count>=0),
 version bigint not null default 1 check(version>0),last_sequence bigint not null default 0 check(last_sequence>=0),
 started_at timestamptz,finalized_at timestamptz,finalized_by_person_id uuid references public.people(id),reopened_at timestamptz,
 created_by_person_id uuid not null references public.people(id),updated_by_person_id uuid not null references public.people(id),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(organization_id,id),unique(event_id,occurrence_key),
 foreign key(organization_id,event_id) references public.events(organization_id,id),
 foreign key(organization_id,primary_team_id) references public.teams(organization_id,id),
 foreign key(organization_id,opponent_team_id) references public.teams(organization_id,id),
 foreign key(organization_id,parent_unit_id) references public.organization_units(organization_id,id),
 foreign key(organization_id,season_id) references public.seasons(organization_id,id),
 foreign key(organization_id,venue_id) references public.venues(organization_id,id),
 check(primary_team_id is distinct from opponent_team_id),check((opponent_team_id is not null)<>(external_opponent_name is not null)),
 check(external_opponent_name is null or length(btrim(external_opponent_name)) between 1 and 200),
 check(occurrence_key~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$'),
 check(isfinite(scheduled_start_at) and isfinite(scheduled_end_at) and scheduled_end_at>scheduled_start_at),
 check(schedule_status in('draft','scheduled','confirmed','canceled','postponed','completed','archived')),
 check(visibility in('public','authenticated','member','restricted','private')),check(publication_state in('unpublished','published')),
 check((final_primary_score is null)=(final_opponent_score is null)),check(final_primary_score is null or final_primary_score between 0 and 1000000),
 check(final_opponent_score is null or final_opponent_score between 0 and 1000000),
 check(status<>'final' or(finalized_at is not null and final_primary_score is not null and finalization_count>0 and roster_revision>0))
);
create unique index games_single_event_idx on public.games(event_id) where occurrence_mode='single';
create index games_event_idx on public.games(organization_id,event_id);
create index games_org_time_idx on public.games(organization_id,scheduled_start_at,id);
create index games_org_status_time_idx on public.games(organization_id,status,scheduled_start_at,id);
create index games_primary_time_idx on public.games(organization_id,primary_team_id,scheduled_start_at,id);
create index games_opponent_time_idx on public.games(organization_id,opponent_team_id,scheduled_start_at,id);
create index games_season_time_idx on public.games(organization_id,season_id,scheduled_start_at,id);
create index games_unit_time_idx on public.games(organization_id,parent_unit_id,scheduled_start_at,id);
create index games_sport_idx on public.games(sport_key);
create index games_venue_idx on public.games(organization_id,venue_id);
create index games_creator_idx on public.games(created_by_person_id);
create index games_updater_idx on public.games(updated_by_person_id);
create index games_finalizer_idx on public.games(finalized_by_person_id);

create table public.game_roster_snapshots(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,game_id uuid not null,revision bigint not null check(revision>0),
 team_id uuid not null,participant_id uuid not null,person_id uuid not null references public.people(id),
 display_name text not null,jersey_number text,position_label text,active boolean not null default true,captain boolean not null default false,starter boolean not null default false,
 availability text not null check(availability in('attending','not_attending','maybe','pending','unknown')),
 checkin_state text check(checkin_state in('expected','checked_in','absent','late','excused')),
 captured_by_person_id uuid not null references public.people(id),created_at timestamptz not null default now(),
 unique(game_id,revision,team_id,participant_id),foreign key(organization_id,game_id) references public.games(organization_id,id),
 foreign key(organization_id,team_id) references public.teams(organization_id,id),foreign key(participant_id,person_id) references public.participants(id,person_id),
 check(length(display_name) between 1 and 200),check(jersey_number is null or length(jersey_number)<=30),check(position_label is null or length(position_label)<=100)
);
create index game_roster_person_idx on public.game_roster_snapshots(person_id,game_id);
create index game_roster_game_idx on public.game_roster_snapshots(organization_id,game_id,revision);
create index game_roster_team_idx on public.game_roster_snapshots(organization_id,team_id);
create index game_roster_participant_idx on public.game_roster_snapshots(participant_id,person_id);
create index game_roster_actor_idx on public.game_roster_snapshots(captured_by_person_id);
create table public.game_operator_assignments(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,game_id uuid not null,
 person_id uuid not null references public.people(id),role_assignment_id uuid not null references public.role_assignments(id),team_id uuid not null,
 function_key text not null check(function_key in('game_administrator','scorekeeper')),status text not null default 'active' check(status in('active','inactive','ended')),
 starts_at timestamptz not null default now(),ends_at timestamptz not null,assigned_by_person_id uuid not null references public.people(id),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 foreign key(organization_id,game_id) references public.games(organization_id,id),foreign key(organization_id,team_id) references public.teams(organization_id,id),
 check(isfinite(starts_at) and isfinite(ends_at) and ends_at>starts_at)
);
create index game_operator_game_idx on public.game_operator_assignments(organization_id,game_id,person_id,status,ends_at);
create index game_operator_role_idx on public.game_operator_assignments(role_assignment_id);
create index game_operator_person_idx on public.game_operator_assignments(person_id,game_id);
create index game_operator_team_idx on public.game_operator_assignments(organization_id,team_id);
create index game_operator_assigner_idx on public.game_operator_assignments(assigned_by_person_id);
create table public.game_operations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,game_id uuid not null,sequence bigint not null check(sequence>0),version bigint not null check(version>0),
 operation text not null,logical_game_time jsonb,actor_person_id uuid not null references public.people(id),request_id uuid,
 correction_of uuid,prior_state jsonb not null,next_state jsonb not null,audit_event_id uuid not null references public.audit_events(id),
 created_at timestamptz not null default now(),unique(game_id,sequence),unique(game_id,version),unique(organization_id,game_id,id),
 foreign key(organization_id,game_id) references public.games(organization_id,id),
 foreign key(organization_id,game_id,correction_of) references public.game_operations(organization_id,game_id,id),
 check(logical_game_time is null or(jsonb_typeof(logical_game_time)='object' and octet_length(logical_game_time::text)<=1024)),
 check(operation in('game.create','game.roster.snapshot','game.operator.assign','game.operator.end','game.start','game.transition','game.score.set','game.score.reverse','game.finalize','game.reopen','game.publish','game.calendar.sync')),
 check(jsonb_typeof(prior_state)='object' and jsonb_typeof(next_state)='object'),check(octet_length(prior_state::text)<=8192 and octet_length(next_state::text)<=8192)
);
create unique index game_operation_reversal_idx on public.game_operations(game_id,correction_of) where correction_of is not null;
create index game_operation_actor_idx on public.game_operations(actor_person_id);
create index game_operation_audit_idx on public.game_operations(audit_event_id);
create index game_operation_correction_idx on public.game_operations(organization_id,game_id,correction_of);
create table public.game_finalizations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,game_id uuid not null,epoch bigint not null check(epoch>0),
 primary_score integer not null check(primary_score between 0 and 1000000),opponent_score integer not null check(opponent_score between 0 and 1000000),
 roster_revision bigint not null check(roster_revision>0),operation_sequence bigint not null check(operation_sequence>0),
 winner_side text check(winner_side in('primary','opponent')),tied boolean not null,roster_hash text not null check(roster_hash~'^[a-f0-9]{64}$'),
 actor_person_id uuid not null references public.people(id),created_at timestamptz not null default now(),
 unique(game_id,epoch),foreign key(organization_id,game_id) references public.games(organization_id,id),
 check(tied=(primary_score=opponent_score)),check(winner_side is not distinct from case when primary_score>opponent_score then 'primary' when primary_score<opponent_score then 'opponent' end)
);
create index game_finalization_actor_idx on public.game_finalizations(actor_person_id);
create index game_finalization_game_idx on public.game_finalizations(organization_id,game_id,epoch);
create table boss_private.game_operation_receipts(
 actor_person_id uuid not null references public.people(id),request_id uuid not null,input_hash bytea not null,
 command jsonb not null,result jsonb not null,created_at timestamptz not null default now(),primary key(actor_person_id,request_id)
);
DO $$declare t text;begin
 foreach t in array array['game_sports','games','game_roster_snapshots','game_operator_assignments','game_operations','game_finalizations'] loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);end loop;
 alter table boss_private.game_operation_receipts enable row level security;
 revoke all on boss_private.game_operation_receipts from public,anon,authenticated,service_role;
 foreach t in array array['game_roster_snapshots','game_operations','game_finalizations'] loop
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
end $$;
create trigger games_identity before update on public.games for each row execute function boss_private.preserve_row_identity('id','organization_id','event_id','occurrence_key','occurrence_mode','primary_team_id','opponent_team_id','external_opponent_name','parent_unit_id','season_id','sport_key','home_away','competition_type','created_by_person_id','created_at');
create trigger game_operator_identity before update on public.game_operator_assignments for each row execute function boss_private.preserve_row_identity('id','organization_id','game_id','person_id','role_assignment_id','team_id','function_key','starts_at','assigned_by_person_id','created_at');

-- A serialization wait cannot extend a caller's natural session deadline.
-- Preserve the established identity/confirmation/ban checks, then use current
-- time for the same native session expiry rule. No session value is returned.
create function boss_private.games_require_live_auth() returns uuid language plpgsql volatile security definer set search_path='' as $$
declare caller uuid:=boss_private.require_live_auth();v_session uuid:=(auth.jwt()->>'session_id')::uuid;begin
 if not exists(select 1 from auth.sessions s where s.id=v_session and s.user_id=caller and(s.not_after is null or s.not_after>clock_timestamp())) then
 raise exception 'Authentication required' using errcode='PT401';end if;
 return caller;
end $$;
create function boss_private.games_configuration(p_org uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with raw as(select boss_private.coordination_configuration(p_org,'sports') c),keys as(select unnest(array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management']) k)
 select jsonb_object_agg(k,case when jsonb_typeof(c->k)='boolean' then c->k else 'false'::jsonb end) from raw cross join keys
$$;
create function boss_private.games_module_live(p_org uuid,p_module text) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.organization_modules om join public.modules catalog on catalog.id=om.module_id and catalog.status='active'
 join public.organizations organization on organization.id=om.organization_id and organization.status='active'
 where om.organization_id=p_org and catalog.key=p_module and om.status='active' and om.starts_at<=clock_timestamp() and(om.ends_at is null or om.ends_at>clock_timestamp()))
$$;
create function boss_private.games_feature(p_org uuid,p_key text,p_configuration jsonb default null) returns boolean language sql volatile security definer set search_path='' as $$
 select boss_private.games_module_live(p_org,'sports') and p_key=any(array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management'])
 and coalesce((coalesce(p_configuration,boss_private.games_configuration(p_org))->>'game_center')::boolean,false)
 and coalesce((coalesce(p_configuration,boss_private.games_configuration(p_org))->>p_key)::boolean,false)
$$;
-- A supplied actor is used only by closed internal projections/recipient checks.
create function boss_private.games_role_permission(p_actor uuid,p_key text,p_org uuid,p_team uuid default null,p_assignment uuid default null,p_configuration jsonb default null)
returns boolean language sql volatile security definer set search_path='' as $$
 select p_key=any(array['games.view','games.create','games.manage','games.operate','games.finalize','games.correct','games.publish','team.roster.view','organization.manage'])
 and exists(select 1 from public.people where id=p_actor and status='active') and exists(select 1 from public.organizations where id=p_org and status='active')
 and(p_team is null or exists(select 1 from public.teams t where t.id=p_team and t.organization_id=p_org and t.status='active' and(t.parent_unit_id is null or exists(select 1 from public.organization_units u where u.id=t.parent_unit_id and u.organization_id=p_org and u.status='active'))))
 and exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id and p.status='active' and p.key=p_key
 where a.person_id=p_actor and(p_assignment is null or a.id=p_assignment) and a.status='active' and a.starts_at<=clock_timestamp() and(a.ends_at is null or a.ends_at>clock_timestamp())
 and((a.scope_type='platform' and a.scope_id is null and a.organization_id is null)
 or(a.organization_id=p_org and(a.scope_type='team' or exists(select 1 from public.organization_memberships om where om.organization_id=p_org and om.person_id=p_actor and om.status='active' and om.starts_at<=clock_timestamp() and(om.ends_at is null or om.ends_at>clock_timestamp()))) and((a.scope_type='organization' and a.scope_id=p_org)
 or(a.scope_type='organization_unit' and p_team is not null and a.scope_id=(select parent_unit_id from public.teams where id=p_team and organization_id=p_org))
 or(a.scope_type='team' and p_team is not null and a.scope_id=p_team and exists(select 1 from public.team_memberships tm
 where tm.organization_id=p_org and tm.team_id=p_team and tm.person_id=p_actor and tm.status='active' and tm.starts_at<=clock_timestamp() and(tm.ends_at is null or tm.ends_at>clock_timestamp()))))))
 and(r.key<>'head_coach' or p_key<>'games.manage' or boss_private.games_feature(p_org,'head_coach_game_management',p_configuration))
 and(r.key<>'team_administrator' or p_key<>'games.manage' or boss_private.games_feature(p_org,'team_game_management',p_configuration)))
$$;
create function boss_private.games_permission(p_actor uuid,p_key text,g public.games,p_all boolean default true,p_configuration jsonb default null) returns boolean language sql volatile security definer set search_path='' as $$
 select boss_private.games_feature(g.organization_id,'game_center',p_configuration) and boss_private.games_module_live(g.organization_id,'calendar') and
 (boss_private.games_role_permission(p_actor,p_key,g.organization_id,g.primary_team_id,null,p_configuration)
 and(case when p_all then g.opponent_team_id is null or boss_private.games_role_permission(p_actor,p_key,g.organization_id,g.opponent_team_id,null,p_configuration) else true end)
 or(not p_all and g.opponent_team_id is not null and boss_private.games_role_permission(p_actor,p_key,g.organization_id,g.opponent_team_id,null,p_configuration)))
$$;
create function boss_private.games_person_related(p_actor uuid,p_person uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.people where id=p_actor and status='active') and exists(select 1 from public.people where id=p_person and status='active')
 and(p_person=p_actor or exists(select 1 from public.guardian_relationships g where g.guardian_person_id=p_actor and g.dependent_person_id=p_person
 and g.authority_status='active' and g.verified_at<=clock_timestamp() and g.starts_at<=clock_timestamp() and(g.ends_at is null or g.ends_at>clock_timestamp())))
$$;
create function boss_private.games_team_related(p_actor uuid,p_org uuid,p_team uuid,p_child uuid default null) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id and t.organization_id=m.organization_id and t.status='active'
 left join public.participants a on a.id=m.participant_id and a.person_id=m.person_id
 where m.organization_id=p_org and m.team_id=p_team and m.status='active' and m.starts_at<=clock_timestamp() and(m.ends_at is null or m.ends_at>clock_timestamp())
 and(m.participant_id is null or a.status='active') and(p_child is null or m.person_id=p_child) and boss_private.games_person_related(p_actor,m.person_id))
$$;
create function boss_private.games_operator_current(p_actor uuid,g public.games,p_configuration jsonb default null) returns boolean language sql volatile security definer set search_path='' as $$
 select boss_private.games_feature(g.organization_id,'game_operations',p_configuration) and boss_private.games_module_live(g.organization_id,'calendar') and exists(select 1 from public.game_operator_assignments a
 join public.role_assignments ra on ra.id=a.role_assignment_id and ra.person_id=a.person_id join public.roles r on r.id=ra.role_id
 where a.organization_id=g.organization_id and a.game_id=g.id and a.person_id=p_actor and a.status='active' and a.starts_at<=clock_timestamp() and a.ends_at>clock_timestamp()
 and a.team_id in(g.primary_team_id,g.opponent_team_id) and boss_private.games_role_permission(p_actor,'games.operate',g.organization_id,a.team_id,a.role_assignment_id,p_configuration)
 and((a.function_key='scorekeeper' and r.key='scorekeeper') or(a.function_key='game_administrator' and r.key<>'scorekeeper'
 and boss_private.games_role_permission(p_actor,'games.manage',g.organization_id,a.team_id,a.role_assignment_id,p_configuration))))
$$;
create function boss_private.games_can_view(p_actor uuid,g public.games,p_configuration jsonb default null) returns boolean language sql volatile security definer set search_path='' as $$
 select boss_private.games_feature(g.organization_id,'game_center',p_configuration) and boss_private.games_module_live(g.organization_id,'calendar')
 and exists(select 1 from public.events e where e.id=g.event_id and e.organization_id=g.organization_id and
 (boss_private.games_role_permission(p_actor,'games.view',g.organization_id)
 or boss_private.games_permission(p_actor,'games.manage',g,true,p_configuration) or boss_private.games_operator_current(p_actor,g,p_configuration)
 or(e.status<>'draft' and e.visibility<>'private' and
 (boss_private.games_permission(p_actor,'games.view',g,false,p_configuration)
 or(e.visibility='member' and(boss_private.games_team_related(p_actor,g.organization_id,g.primary_team_id) or(g.opponent_team_id is not null and boss_private.games_team_related(p_actor,g.organization_id,g.opponent_team_id))))
 or(e.publication_state='published' and g.publication_state='published' and e.visibility in('authenticated','public')
 and(e.visibility<>'public' or boss_private.games_feature(g.organization_id,'public_game_center',p_configuration)))))))
$$;
create function boss_private.games_org_known(p_actor uuid,p_org uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.organizations where id=p_org and status='active') and
 (boss_private.games_role_permission(p_actor,'games.view',p_org) or boss_private.games_role_permission(p_actor,'organization.manage',p_org)
 or exists(select 1 from public.organization_memberships m where m.organization_id=p_org and m.person_id=p_actor and m.status='active' and m.starts_at<=clock_timestamp() and(m.ends_at is null or m.ends_at>clock_timestamp()))
 or exists(select 1 from public.teams t where t.organization_id=p_org and t.status='active' and(boss_private.games_role_permission(p_actor,'games.view',p_org,t.id) or boss_private.games_team_related(p_actor,p_org,t.id))))
$$;
-- Discover candidate tenants from indexed actor relationships before running
-- current-resource authorization. A current platform role intentionally has
-- all-organization context; ordinary identities never scan the tenant catalog.
create function boss_private.games_organization_candidates(p_actor uuid) returns table(organization_id uuid)
language sql volatile security definer set search_path='' as $$
 with related_people as materialized(
 select p_actor person_id
 union select g.dependent_person_id from public.guardian_relationships g join public.people child on child.id=g.dependent_person_id and child.status='active'
 where g.guardian_person_id=p_actor and g.authority_status='active' and g.verified_at<=clock_timestamp() and g.starts_at<=clock_timestamp() and(g.ends_at is null or g.ends_at>clock_timestamp())),
 candidate_ids as materialized(
 select a.organization_id from public.role_assignments a where a.person_id=p_actor and a.organization_id is not null and a.status='active' and a.starts_at<=clock_timestamp() and(a.ends_at is null or a.ends_at>clock_timestamp())
 union select m.organization_id from public.organization_memberships m where m.person_id=p_actor and m.status='active' and m.starts_at<=clock_timestamp() and(m.ends_at is null or m.ends_at>clock_timestamp())
 union select m.organization_id from related_people p join public.team_memberships m on m.person_id=p.person_id where m.status='active' and m.starts_at<=clock_timestamp() and(m.ends_at is null or m.ends_at>clock_timestamp()))
 select o.id from public.organizations o where o.status='active' and exists(
 select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions permission on permission.id=rp.permission_id and permission.status='active' and permission.key in('games.view','organization.manage')
 where a.person_id=p_actor and a.scope_type='platform' and a.scope_id is null and a.organization_id is null and a.status='active' and a.starts_at<=clock_timestamp() and(a.ends_at is null or a.ends_at>clock_timestamp()))
 union select o.id from candidate_ids c join public.organizations o on o.id=c.organization_id and o.status='active'
$$;
create function boss_private.games_occurrence(e public.events,p_key text,p_mode text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare anchor timestamptz;ex public.event_occurrence_exceptions;result jsonb;begin
 if p_key is null or p_key!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$' then return null;end if;
 if p_mode='single' then
 if e.recurrence is not null then return null;end if;
 return jsonb_build_object('occurrence_key',p_key,'start_at',e.start_at,'end_at',e.end_at,'status',e.status,'title',e.title);
 end if;
 if p_mode<>'recurring' or e.recurrence is null then return null;end if;
 anchor:=p_key::timestamp at time zone e.timezone;
 if anchor<e.start_at-interval '1 day' or anchor>e.start_at+interval '5 years 1 day' then return null;end if;
 -- First prove the original recurrence key. An exception cannot invent a game.
 if not exists(select 1 from boss_private.calendar_expand(e.start_at,e.end_at,e.timezone,e.recurrence,anchor-interval '1 day',anchor+interval '32 days') x where x.occurrence_key=p_key) then return null;end if;
 select * into ex from public.event_occurrence_exceptions where event_id=e.id and occurrence_key=p_key and is_active;
 select jsonb_build_object('occurrence_key',x.occurrence_key,'start_at',x.start_at,'end_at',x.end_at,'status',x.status,'title',x.title) into result
 from boss_private.calendar_occurrences(e,least(anchor-interval '1 day',ex.override_start_at-interval '1 second'),greatest(anchor+interval '32 days',ex.override_end_at+interval '1 second')) x where x.occurrence_key=p_key;
 return result;
 exception when invalid_datetime_format or datetime_field_overflow then return null;
end $$;
create function boss_private.games_transition_valid(p_from text,p_to text) returns boolean language sql immutable set search_path='' as $$
 select case p_from
 when 'scheduled' then p_to in('pregame','delayed','postponed','canceled')
 when 'pregame' then p_to in('scheduled','delayed','postponed','canceled')
 when 'live' then p_to in('paused','delayed','suspended','abandoned')
 when 'paused' then p_to in('live','delayed','suspended','abandoned')
 when 'delayed' then p_to in('scheduled','pregame','live','postponed','canceled','abandoned')
 when 'suspended' then p_to in('live','paused','abandoned')
 when 'postponed' then p_to in('scheduled','canceled') else false end
$$;
create function boss_private.games_core_state(g public.games) returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_object('status',g.status,'primary_score',g.primary_score,'opponent_score',g.opponent_score,'roster_revision',g.roster_revision,
 'finalization_count',g.finalization_count,'final_primary_score',g.final_primary_score,'final_opponent_score',g.final_opponent_score,
 'winner_side',g.winner_side,'tied',g.tied,'start_at',g.scheduled_start_at,'end_at',g.scheduled_end_at,'schedule_status',g.schedule_status,
 'venue_id',g.venue_id,'visibility',g.visibility,'publication_state',g.publication_state,'version',g.version,'reopened',g.reopened_at is not null)
$$;
DO $$declare r record;begin for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'games_%' loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',r.signature);end loop;end $$;
