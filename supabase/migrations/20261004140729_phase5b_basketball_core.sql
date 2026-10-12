-- Phase 5B: typed, per-game Basketball extension of the canonical Game Center.
-- No new game identity, operator catalog, operation sequence or receipt store.
alter table public.game_roster_snapshots add constraint game_roster_context_id unique(organization_id,game_id,id);
DO $$declare name text;begin
 select conname into name from pg_constraint where conrelid='public.game_operations'::regclass and contype='c' and pg_get_constraintdef(oid) like '%operation = ANY%';
 if name is null then raise exception 'Canonical operation constraint missing';end if;
 execute format('alter table public.game_operations drop constraint %I',name);
end$$;
alter table public.game_operations add constraint game_operations_finite_operation check(operation in(
 'game.create','game.roster.snapshot','game.operator.assign','game.operator.end','game.start','game.transition','game.score.set','game.score.reverse','game.finalize','game.reopen','game.publish','game.calendar.sync',
 'basketball.configure','basketball.period.start','basketball.period.end','basketball.clock.start','basketball.clock.stop','basketball.clock.set','basketball.lineup.set','basketball.substitute','basketball.event.add','basketball.event.correct','basketball.event.reverse'));

create table public.game_basketball_states(
 game_id uuid primary key,organization_id uuid not null,
 regulation_periods integer not null check(regulation_periods in(2,4)),period_seconds integer not null check(period_seconds between 60 and 3600),
 overtime_seconds integer not null check(overtime_seconds between 60 and 1800),lineup_size integer not null check(lineup_size between 1 and 5),enforce_lineup boolean not null,
 period_number integer not null default 0 check(period_number between 0 and 30),period_status text not null default 'pending' check(period_status in('pending','active','ended')),
 clock_remaining_ms bigint not null default 0 check(clock_remaining_ms between 0 and 3600000),clock_running boolean not null default false,clock_anchor timestamptz,
 roster_revision bigint not null check(roster_revision>0),engine_version text not null default 'basketball-v1' check(engine_version='basketball-v1'),
 foreign key(organization_id,game_id) references public.games(organization_id,id),
 check((period_number=0)=(period_status='pending')),check(not clock_running or(period_status='active' and clock_anchor is not null)),
 check(clock_remaining_ms<=case when period_number>regulation_periods then overtime_seconds else period_seconds end*1000)
);
create index basketball_state_context_idx on public.game_basketball_states(organization_id,game_id);
create table public.game_basketball_events(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,game_id uuid not null,operation_id uuid not null,
 sequence bigint not null check(sequence>0),period_number integer not null check(period_number between 0 and 30),clock_ms bigint not null check(clock_ms between 0 and 3600000),
 side text check(side in('primary','opponent')),roster_id uuid,secondary_roster_id uuid,
 event_type text not null check(event_type in('made_2','made_3','made_ft','missed_2','missed_3','missed_ft','offensive_rebound','defensive_rebound','assist','steal','block','turnover','personal_foul',
 'engine_configure','period_start','period_end','clock_start','clock_stop','clock_set','lineup_set','substitution','reversal')),
 points integer not null check(points=case event_type when 'made_2' then 2 when 'made_3' then 3 when 'made_ft' then 1 else 0 end),
 actor_person_id uuid not null references public.people(id),request_id uuid not null,correction_of uuid,scoring_event_id uuid,reason text,
 created_at timestamptz not null default clock_timestamp(),unique(organization_id,game_id,id),unique(game_id,sequence),unique(operation_id),
 foreign key(organization_id,game_id) references public.games(organization_id,id),
 foreign key(organization_id,game_id,operation_id) references public.game_operations(organization_id,game_id,id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 foreign key(organization_id,game_id,secondary_roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 foreign key(organization_id,game_id,correction_of) references public.game_basketball_events(organization_id,game_id,id),
 foreign key(organization_id,game_id,scoring_event_id) references public.game_basketball_events(organization_id,game_id,id),
 check(reason is null or(length(btrim(reason)) between 1 and 500 and reason!~'[[:cntrl:]]')),
 check(correction_of is null or correction_of<>id),check(scoring_event_id is null or scoring_event_id<>id),
 check((event_type='assist')=(scoring_event_id is not null)),check(event_type<>'reversal' or correction_of is not null),
 check(event_type not in('made_2','made_3','made_ft','missed_2','missed_3','missed_ft','offensive_rebound','defensive_rebound','assist','steal','block','turnover','personal_foul','substitution','lineup_set') or side is not null),
 check(event_type not in('assist','steal','block','personal_foul','substitution') or roster_id is not null),
 check((event_type='substitution')=(secondary_roster_id is not null))
);
create unique index basketball_event_supersession_idx on public.game_basketball_events(game_id,correction_of) where correction_of is not null;
create index basketball_event_context_correction_idx on public.game_basketball_events(organization_id,game_id,correction_of);
create index basketball_event_context_scoring_idx on public.game_basketball_events(organization_id,game_id,scoring_event_id);
create index basketball_event_roster_idx on public.game_basketball_events(organization_id,game_id,roster_id);
create index basketball_event_secondary_idx on public.game_basketball_events(organization_id,game_id,secondary_roster_id);
create index basketball_event_actor_idx on public.game_basketball_events(actor_person_id);
create index basketball_event_operation_context_idx on public.game_basketball_events(organization_id,game_id,operation_id);
create table public.game_basketball_lineups(
 game_id uuid not null,organization_id uuid not null,side text not null check(side in('primary','opponent')),slot integer not null check(slot between 1 and 5),roster_id uuid not null,
 primary key(game_id,side,slot),unique(game_id,roster_id),foreign key(organization_id,game_id) references public.games(organization_id,id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id)
);
create index basketball_lineup_roster_idx on public.game_basketball_lineups(organization_id,game_id,roster_id);
create table public.game_basketball_lineup_history(
 event_id uuid not null references public.game_basketball_events(id),side text not null check(side in('primary','opponent')),slot integer not null check(slot between 1 and 5),
 organization_id uuid not null,game_id uuid not null,roster_id uuid not null,
 primary key(event_id,side,slot),foreign key(organization_id,game_id,event_id) references public.game_basketball_events(organization_id,game_id,id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id)
);
create index basketball_lineup_history_roster_idx on public.game_basketball_lineup_history(organization_id,game_id,roster_id);
create index basketball_lineup_history_event_idx on public.game_basketball_lineup_history(organization_id,game_id,event_id);
DO $$declare t text;begin
 foreach t in array array['game_basketball_states','game_basketball_events','game_basketball_lineups','game_basketball_lineup_history'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);end loop;
 foreach t in array array['game_basketball_events','game_basketball_lineup_history'] loop
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
end$$;
create trigger basketball_state_identity before update on public.game_basketball_states for each row execute function boss_private.preserve_row_identity('game_id','organization_id','regulation_periods','period_seconds','overtime_seconds','lineup_size','enforce_lineup','roster_revision','engine_version');

create or replace function boss_private.games_configuration(p_org uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with raw as(select boss_private.coordination_configuration(p_org,'sports') c),keys as(select unnest(array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management','basketball_live_scoring','basketball_stats','basketball_play_by_play','basketball_lineups']) k)
 select jsonb_object_agg(k,case when jsonb_typeof(c->k)='boolean' then c->k else 'false'::jsonb end) from raw cross join keys
$$;
create or replace function boss_private.games_feature(p_org uuid,p_key text,p_configuration jsonb default null) returns boolean language sql volatile security definer set search_path='' as $$
 select boss_private.games_module_live(p_org,'sports') and p_key=any(array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management','basketball_live_scoring','basketball_stats','basketball_play_by_play','basketball_lineups'])
 and coalesce((coalesce(p_configuration,boss_private.games_configuration(p_org))->>'game_center')::boolean,false)
 and coalesce((coalesce(p_configuration,boss_private.games_configuration(p_org))->>p_key)::boolean,false)
$$;
create function boss_private.basketball_clock(s public.game_basketball_states) returns bigint language sql volatile set search_path='' as $$
 select greatest(0,s.clock_remaining_ms-case when s.clock_running then greatest(0,floor(extract(epoch from(clock_timestamp()-s.clock_anchor))*1000)::bigint) else 0 end)
$$;
create function boss_private.basketball_active_events(p_game uuid) returns setof public.game_basketball_events language sql stable security definer set search_path='' as $$
 select e.* from public.game_basketball_events e where e.game_id=p_game and e.event_type in('made_2','made_3','made_ft','missed_2','missed_3','missed_ft','offensive_rebound','defensive_rebound','assist','steal','block','turnover','personal_foul')
 and not exists(select 1 from public.game_basketball_events c where c.game_id=e.game_id and c.correction_of=e.id)
$$;
create function boss_private.basketball_totals(p_game uuid) returns table(side text,roster_id uuid,points bigint,offensive_rebounds bigint,defensive_rebounds bigint,rebounds bigint,assists bigint,steals bigint,blocks bigint,turnovers bigint,personal_fouls bigint,fgm bigint,fga bigint,tpm bigint,tpa bigint,ftm bigint,fta bigint)
language sql stable security definer set search_path='' as $$
 with plays as materialized(select e.* from boss_private.basketball_active_events(p_game)e),
 seeds as(select r.id roster_id,case when r.team_id=g.primary_team_id then 'primary' else 'opponent' end side from public.games g join public.game_roster_snapshots r on r.game_id=g.id and r.revision=g.roster_revision where g.id=p_game),
 subjects as(select s.side,s.roster_id,false team_total from seeds s union all select unnest(array['primary','opponent']),null::uuid,true),
 agg as(select s.side,s.roster_id,
 coalesce(sum(e.points),0)::bigint points,count(e.id) filter(where e.event_type='offensive_rebound') orb,count(e.id) filter(where e.event_type='defensive_rebound') drb,
 count(e.id) filter(where e.event_type in('offensive_rebound','defensive_rebound')) reb,count(e.id) filter(where e.event_type='assist') ast,
 count(e.id) filter(where e.event_type='steal') stl,count(e.id) filter(where e.event_type='block') blk,count(e.id) filter(where e.event_type='turnover') turnovers,
 count(e.id) filter(where e.event_type='personal_foul') pf,count(e.id) filter(where e.event_type in('made_2','made_3')) fgm,
 count(e.id) filter(where e.event_type in('made_2','made_3','missed_2','missed_3')) fga,count(e.id) filter(where e.event_type='made_3') tpm,
 count(e.id) filter(where e.event_type in('made_3','missed_3')) tpa,count(e.id) filter(where e.event_type='made_ft') ftm,count(e.id) filter(where e.event_type in('made_ft','missed_ft')) fta
 from subjects s left join plays e on e.side=s.side and(s.team_total or e.roster_id=s.roster_id) group by s.side,s.roster_id)
 select * from agg
$$;
-- A minimal sport-entry identity is restricted to the exact assigned team, or
-- an independently authorized roster side. It never includes Attendance data.
create function boss_private.basketball_roster_side(p_actor uuid,g public.games,p_team uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select coalesce(p_team in(g.primary_team_id,g.opponent_team_id) and
 (boss_private.games_role_permission(p_actor,'team.roster.view',g.organization_id,p_team)
 or(boss_private.games_operator_current(p_actor,g) and exists(select 1 from public.game_operator_assignments a
 where a.game_id=g.id and a.person_id=p_actor and a.team_id=p_team and a.status='active' and a.starts_at<=clock_timestamp() and a.ends_at>clock_timestamp()
 and boss_private.games_role_permission(p_actor,'games.operate',g.organization_id,p_team,a.role_assignment_id)))),false)
$$;
create function boss_private.basketball_state(s public.game_basketball_states) returns jsonb language sql volatile set search_path='' as $$
 select jsonb_build_object('period_number',s.period_number,'period_status',s.period_status,'clock_ms',boss_private.basketball_clock(s),'clock_running',s.clock_running,'clock_anchor',s.clock_anchor,'engine_version',s.engine_version)
$$;
create or replace function boss_private.games_append(p_game uuid,p_actor uuid,p_op text,p_request uuid,p_before jsonb,p_extra jsonb default '{}',p_correction uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare g public.games;s public.game_basketball_states;aid uuid;oid uuid:=gen_random_uuid();after_state jsonb;game_time jsonb;begin
 select * into g from public.games where id=p_game for update;
 select * into s from public.game_basketball_states where game_id=p_game;
 if s.game_id is not null then game_time:=jsonb_build_object('period_number',s.period_number,'clock_ms',boss_private.basketball_clock(s));end if;
 after_state:=boss_private.games_core_state(g)||case when s.game_id is not null then jsonb_build_object('basketball',boss_private.basketball_state(s),'basketball_time',game_time) else '{}'::jsonb end||p_extra;
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,before_data,after_data)
 values(g.organization_id,p_actor,auth.uid(),p_op,'game',g.id,'organization',g.organization_id,p_request,p_before,after_state) returning id into aid;
 insert into public.game_operations(id,organization_id,game_id,sequence,version,operation,logical_game_time,actor_person_id,request_id,correction_of,prior_state,next_state,audit_event_id)
 values(oid,g.organization_id,g.id,g.last_sequence+1,g.version,p_op,coalesce(p_extra->'basketball_time',game_time),p_actor,p_request,p_correction,p_before,after_state,aid);
 update public.games set last_sequence=g.last_sequence+1 where id=g.id;
 return oid;
end $$;
DO $$declare r record;begin for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'basketball_%' loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',r.signature);end loop;end$$;
