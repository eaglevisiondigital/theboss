-- Soccer is an extension of the existing per-game operation and identity model.
-- Actual participation time is separate from the nominal displayed match clock.
alter table public.game_operations drop constraint game_operations_finite_operation;
alter table public.game_operations add constraint game_operations_finite_operation check(operation in(
 'game.create','game.roster.snapshot','game.operator.assign','game.operator.end','game.start','game.transition','game.score.set','game.score.reverse','game.finalize','game.reopen','game.publish','game.calendar.sync',
 'basketball.configure','basketball.period.start','basketball.period.end','basketball.clock.start','basketball.clock.stop','basketball.clock.set','basketball.lineup.set','basketball.substitute','basketball.event.add','basketball.event.correct','basketball.event.reverse',
 'soccer.configure','soccer.segment.start','soccer.segment.end','soccer.clock.start','soccer.clock.stop','soccer.clock.set','soccer.added_time.set','soccer.lineup.set','soccer.keeper.set','soccer.substitute','soccer.event.add','soccer.event.correct','soccer.event.reverse'));

create table public.game_soccer_states(
 game_id uuid primary key,organization_id uuid not null,
 regulation_segments integer not null check(regulation_segments in(2,4)),segment_seconds integer not null check(segment_seconds between 60 and 5400),
 extra_time_segments integer not null check(extra_time_segments in(0,2)),extra_time_seconds integer not null check(extra_time_seconds between 60 and 1800),
 lineup_size integer not null check(lineup_size between 1 and 11),enforce_lineup boolean not null,allow_reentry boolean not null,max_substitutions integer check(max_substitutions between 0 and 100),
 segment_number integer not null default 0 check(segment_number between 0 and 6),segment_status text not null default 'pending' check(segment_status in('pending','active','ended')),
 clock_elapsed_ms bigint not null default 0 check(clock_elapsed_ms between 0 and 7200000),clock_running boolean not null default false,clock_anchor timestamptz,
 added_time_seconds integer not null default 0 check(added_time_seconds between 0 and 1800),segment_base_ms bigint not null default 0 check(segment_base_ms between 0 and 43200000),
 participation_complete boolean not null default false,roster_revision bigint not null check(roster_revision>0),engine_version text not null default 'soccer-v1' check(engine_version='soccer-v1'),
 foreign key(organization_id,game_id) references public.games(organization_id,id),check((segment_number=0)=(segment_status='pending')),
 check(segment_number<=regulation_segments+extra_time_segments),check(not clock_running or(segment_status='active' and clock_anchor is not null)),
 check(clock_elapsed_ms<=(case when segment_number>regulation_segments then extra_time_seconds else segment_seconds end+added_time_seconds)*1000)
);
create index soccer_state_context_idx on public.game_soccer_states(organization_id,game_id);
create table public.game_soccer_events(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,game_id uuid not null,operation_id uuid not null,
 sequence bigint not null check(sequence>0),origin_sequence bigint not null check(origin_sequence>0 and origin_sequence<=sequence),segment_number integer not null check(segment_number between 0 and 6),
 clock_ms bigint not null check(clock_ms between 0 and 7200000),display_clock_ms bigint not null check(display_clock_ms between 0 and 43200000),playing_ms bigint not null check(playing_ms between 0 and 43200000),
 side text check(side in('primary','opponent')),roster_id uuid,secondary_roster_id uuid,goalkeeper_roster_id uuid,prior_goalkeeper_roster_id uuid,
 lineup_roster_ids uuid[],prior_lineup_roster_ids uuid[],was_on_field boolean not null default false,
 event_type text not null check(event_type in('goal','shot_off_target','shot_saved','shot_blocked','penalty_goal','penalty_miss','penalty_saved','own_goal','assist','yellow_card','second_yellow','red_card','foul',
 'engine_configure','segment_start','segment_end','clock_start','clock_stop','clock_set','added_time_set','lineup_set','keeper_set','substitution','reversal')),
 actor_person_id uuid not null references public.people(id),request_id uuid not null,correction_of uuid,scoring_event_id uuid,reason text,
 created_at timestamptz not null default clock_timestamp(),unique(organization_id,game_id,id),unique(game_id,sequence),unique(operation_id),
 foreign key(organization_id,game_id) references public.games(organization_id,id),foreign key(organization_id,game_id,operation_id) references public.game_operations(organization_id,game_id,id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 foreign key(organization_id,game_id,secondary_roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 foreign key(organization_id,game_id,goalkeeper_roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 foreign key(organization_id,game_id,prior_goalkeeper_roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 foreign key(organization_id,game_id,correction_of) references public.game_soccer_events(organization_id,game_id,id),
 foreign key(organization_id,game_id,scoring_event_id) references public.game_soccer_events(organization_id,game_id,id),
 check(reason is null or(length(btrim(reason)) between 1 and 500 and reason!~'[[:cntrl:]]')),
 check(correction_of is null or correction_of<>id),check(scoring_event_id is null or scoring_event_id<>id),check((event_type='assist')=(scoring_event_id is not null)),
 check(event_type<>'reversal' or correction_of is not null),check(event_type not in('goal','shot_off_target','shot_saved','shot_blocked','penalty_goal','penalty_miss','penalty_saved','own_goal','assist','yellow_card','second_yellow','red_card','foul','lineup_set','keeper_set','substitution') or side is not null),
 check(event_type not in('assist','second_yellow','substitution') or roster_id is not null),
 check((event_type='substitution')=(secondary_roster_id is not null)),check(lineup_roster_ids is null or cardinality(lineup_roster_ids)<=11),check(prior_lineup_roster_ids is null or cardinality(prior_lineup_roster_ids)<=11)
);
create unique index soccer_event_supersession_idx on public.game_soccer_events(game_id,correction_of) where correction_of is not null;
create index soccer_event_origin_idx on public.game_soccer_events(game_id,origin_sequence);
create index soccer_event_context_correction_idx on public.game_soccer_events(organization_id,game_id,correction_of);
create index soccer_event_context_scoring_idx on public.game_soccer_events(organization_id,game_id,scoring_event_id);
create index soccer_event_roster_idx on public.game_soccer_events(organization_id,game_id,roster_id);
create index soccer_event_secondary_idx on public.game_soccer_events(organization_id,game_id,secondary_roster_id);
create index soccer_event_keeper_idx on public.game_soccer_events(organization_id,game_id,goalkeeper_roster_id);
create index soccer_event_prior_keeper_idx on public.game_soccer_events(organization_id,game_id,prior_goalkeeper_roster_id);
create index soccer_event_actor_idx on public.game_soccer_events(actor_person_id);
create index soccer_event_operation_idx on public.game_soccer_events(organization_id,game_id,operation_id);
create table public.game_soccer_lineups(
 game_id uuid not null,organization_id uuid not null,side text not null check(side in('primary','opponent')),slot integer not null check(slot between 1 and 11),roster_id uuid not null,
 goalkeeper boolean not null default false,dismissed boolean not null default false,primary key(game_id,side,slot),unique(game_id,roster_id),
 foreign key(organization_id,game_id) references public.games(organization_id,id),foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id),check(not dismissed or not goalkeeper)
);
create unique index soccer_one_keeper_idx on public.game_soccer_lineups(game_id,side) where goalkeeper;
create index soccer_lineup_roster_idx on public.game_soccer_lineups(organization_id,game_id,roster_id);
create table public.game_soccer_finalizations(
 finalization_id uuid primary key,organization_id uuid not null,game_id uuid not null,epoch bigint not null check(epoch>0),engine_version text not null check(engine_version='soccer-v1'),
 roster_revision bigint not null check(roster_revision>0),event_sequence bigint not null check(event_sequence>0),segment_number integer not null check(segment_number between 2 and 6),state jsonb not null,
 unique(organization_id,game_id,finalization_id),unique(game_id,epoch),foreign key(organization_id,game_id,finalization_id) references public.game_finalizations(organization_id,game_id,id),
 check(jsonb_typeof(state)='object' and octet_length(state::text)<=8192)
);
create index soccer_finalization_context_idx on public.game_soccer_finalizations(organization_id,game_id,finalization_id);
create table public.game_soccer_final_stats(
 id uuid primary key default gen_random_uuid(),finalization_id uuid not null,organization_id uuid not null,game_id uuid not null,side text not null check(side in('primary','opponent')),roster_id uuid,
 goals bigint not null,own_goals bigint not null,assists bigint not null,shots bigint not null,shots_on_goal bigint not null,saves bigint not null,goals_allowed bigint,
 yellow_cards bigint not null,red_cards bigint not null,fouls bigint not null,minutes numeric,clean_sheet boolean,
 foreign key(organization_id,game_id,finalization_id) references public.game_soccer_finalizations(organization_id,game_id,finalization_id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 check(least(goals,own_goals,assists,shots,shots_on_goal,saves,yellow_cards,red_cards,fouls)>=0),check(shots_on_goal<=shots),
 check(goals_allowed is null or goals_allowed>=0),check(minutes is null or minutes>=0)
);
create unique index soccer_final_stats_subject_idx on public.game_soccer_final_stats(finalization_id,side,coalesce(roster_id,'00000000-0000-0000-0000-000000000000'::uuid));
create index soccer_final_stats_context_idx on public.game_soccer_final_stats(organization_id,game_id,finalization_id);
create index soccer_final_stats_roster_idx on public.game_soccer_final_stats(organization_id,game_id,roster_id);
DO $$declare t text;begin
 foreach t in array array['game_soccer_states','game_soccer_events','game_soccer_lineups','game_soccer_finalizations','game_soccer_final_stats'] loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);end loop;
 foreach t in array array['game_soccer_events','game_soccer_finalizations','game_soccer_final_stats'] loop
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
end$$;
create trigger soccer_state_identity before update on public.game_soccer_states for each row execute function boss_private.preserve_row_identity('game_id','organization_id','regulation_segments','segment_seconds','extra_time_segments','extra_time_seconds','lineup_size','enforce_lineup','allow_reentry','max_substitutions','roster_revision','engine_version');

create function boss_private.soccer_clock(s public.game_soccer_states) returns bigint language sql volatile set search_path='' as $$
 select least((case when s.segment_number>s.regulation_segments then s.extra_time_seconds else s.segment_seconds end+s.added_time_seconds)*1000,
 greatest(0,s.clock_elapsed_ms+case when s.clock_running then greatest(0,floor(extract(epoch from(clock_timestamp()-s.clock_anchor))*1000)::bigint) else 0 end))
$$;
create function boss_private.soccer_display_clock(s public.game_soccer_states,p_clock bigint default null) returns bigint language sql volatile set search_path='' as $$
 select greatest(0,least(s.segment_number-1,s.regulation_segments))*s.segment_seconds*1000+greatest(0,s.segment_number-s.regulation_segments-1)*s.extra_time_seconds*1000+coalesce(p_clock,boss_private.soccer_clock(s))
$$;
create function boss_private.soccer_state(s public.game_soccer_states) returns jsonb language sql volatile set search_path='' as $$
 select jsonb_build_object('segment_number',s.segment_number,'segment_status',s.segment_status,'clock_ms',boss_private.soccer_clock(s),
 'display_clock_ms',boss_private.soccer_display_clock(s),'playing_ms',s.segment_base_ms+boss_private.soccer_clock(s),'clock_running',s.clock_running,'clock_anchor',s.clock_anchor,
 'added_time_seconds',s.added_time_seconds,'participation_complete',s.participation_complete,'engine_version',s.engine_version)
$$;
create function boss_private.soccer_active_events(p_game uuid) returns setof public.game_soccer_events language sql stable security definer set search_path='' as $$
 select e.* from public.game_soccer_events e where e.game_id=p_game and e.event_type<>'reversal' and not exists(select 1 from public.game_soccer_events c where c.game_id=e.game_id and c.correction_of=e.id)
$$;
-- Immutable post-participation snapshots form intervals on the actual playing axis.
-- NULL is deliberate when either lineup or keeper coverage is not reliable.
create function boss_private.soccer_totals(p_game uuid) returns table(side text,roster_id uuid,goals bigint,own_goals bigint,assists bigint,shots bigint,shots_on_goal bigint,saves bigint,goals_allowed bigint,yellow_cards bigint,red_cards bigint,fouls bigint,minutes numeric,clean_sheet boolean)
language sql volatile security definer set search_path='' as $$
 with g as materialized(select * from public.games where id=p_game),s as materialized(select z.*,z.segment_base_ms+boss_private.soccer_clock(z) total_ms from public.game_soccer_states z where game_id=p_game),
 facts as materialized(select * from boss_private.soccer_active_events(p_game)),
 subjects as(select case when r.team_id=g.primary_team_id then 'primary' else 'opponent' end side,r.id roster_id,false team_total from g join public.game_roster_snapshots r on r.game_id=g.id and r.revision=g.roster_revision
 union all select unnest(array['primary','opponent']),null::uuid,true),
 intervals as materialized(select f.side,f.lineup_roster_ids,f.goalkeeper_roster_id,f.playing_ms start_ms,f.origin_sequence,
 lead(f.playing_ms,1,(select total_ms from s)) over(partition by f.side order by f.origin_sequence) end_ms,
 lead(f.origin_sequence,1,9223372036854775807::bigint) over(partition by f.side order by f.origin_sequence) next_sequence
 from facts f where f.lineup_roster_ids is not null),
 coverage as(select i.side,sum(greatest(0,i.end_ms-i.start_ms)) filter(where i.goalkeeper_roster_id is not null) keeper_ms,min(i.start_ms) first_ms from intervals i group by i.side),
 unassigned as(select a.side,count(f.id)::bigint unknown_goals from subjects a left join facts f on f.event_type in('goal','penalty_goal','own_goal') and(case when f.event_type='own_goal' then f.side=a.side else f.side<>a.side end)
 and not exists(select 1 from intervals i where i.side=a.side and i.goalkeeper_roster_id is not null and i.origin_sequence<f.origin_sequence and f.origin_sequence<i.next_sequence) where a.team_total group by a.side),
 stat as(select a.side,a.roster_id,a.team_total,
 count(f.id) filter(where f.side=a.side and f.event_type in('goal','penalty_goal') and(a.team_total or f.roster_id=a.roster_id))+
 count(f.id) filter(where a.team_total and f.side<>a.side and f.event_type='own_goal') goals,
 count(f.id) filter(where f.side=a.side and f.event_type='own_goal' and(a.team_total or f.roster_id=a.roster_id)) own_goals,
 count(f.id) filter(where f.side=a.side and f.event_type='assist' and(a.team_total or f.roster_id=a.roster_id)) assists,
 count(f.id) filter(where f.side=a.side and f.event_type in('goal','shot_off_target','shot_saved','shot_blocked','penalty_goal','penalty_miss','penalty_saved') and(a.team_total or f.roster_id=a.roster_id)) shots,
 count(f.id) filter(where f.side=a.side and f.event_type in('goal','shot_saved','penalty_goal','penalty_saved') and(a.team_total or f.roster_id=a.roster_id)) shots_on_goal,
 count(f.id) filter(where f.side<>a.side and f.event_type in('shot_saved','penalty_saved') and(a.team_total or f.goalkeeper_roster_id=a.roster_id)) saves,
 count(f.id) filter(where f.side=a.side and f.event_type in('yellow_card','second_yellow') and(a.team_total or f.roster_id=a.roster_id)) yellow_cards,
 count(f.id) filter(where f.side=a.side and f.event_type in('red_card','second_yellow') and(a.team_total or f.roster_id=a.roster_id)) red_cards,
 count(f.id) filter(where f.side=a.side and f.event_type='foul' and(a.team_total or f.roster_id=a.roster_id)) fouls
 from subjects a left join facts f on true group by a.side,a.roster_id,a.team_total),
 participation as(select a.side,a.roster_id,
 coalesce(sum(greatest(0,i.end_ms-i.start_ms)) filter(where a.roster_id=any(i.lineup_roster_ids)),0)::numeric/60000 minutes,
 coalesce(sum(greatest(0,i.end_ms-i.start_ms)) filter(where a.roster_id=i.goalkeeper_roster_id),0) keeper_ms,
 count(i.origin_sequence) filter(where a.roster_id=i.goalkeeper_roster_id) keeper_intervals,
 bool_and(i.goalkeeper_roster_id is not distinct from a.roster_id) keeper_whole_match
 from subjects a left join intervals i on i.side=a.side group by a.side,a.roster_id),
 conceded as(select a.side,a.roster_id,count(f.id)::bigint ga from subjects a left join facts f on f.event_type in('goal','penalty_goal','own_goal')
 and(case when f.event_type='own_goal' then f.side=a.side else f.side<>a.side end)
 and exists(select 1 from intervals i where i.side=a.side and i.goalkeeper_roster_id=a.roster_id and i.origin_sequence<f.origin_sequence and f.origin_sequence<i.next_sequence)
 group by a.side,a.roster_id)
 select a.side,a.roster_id,a.goals,a.own_goals,a.assists,a.shots,a.shots_on_goal,a.saves,
 case when a.team_total then (case a.side when 'primary' then g.opponent_score else g.primary_score end)::bigint
 when s.participation_complete and u.unknown_goals=0 and c.first_ms=0 and c.keeper_ms=s.total_ms and p.keeper_intervals>0 then d.ga end,
 a.yellow_cards,a.red_cards,a.fouls,case when not a.team_total and s.participation_complete then p.minutes end,
 case when g.status='final' and a.team_total then case a.side when 'primary' then g.opponent_score=0 else g.primary_score=0 end
 when g.status='final' and s.participation_complete and u.unknown_goals=0 and c.first_ms=0 and c.keeper_ms=s.total_ms and p.keeper_ms=s.total_ms and p.keeper_intervals>0 and p.keeper_whole_match then case a.side when 'primary' then g.opponent_score=0 else g.primary_score=0 end end
 from stat a cross join g cross join s left join participation p on p.side=a.side and p.roster_id is not distinct from a.roster_id
 left join coverage c on c.side=a.side left join unassigned u on u.side=a.side left join conceded d on d.side=a.side and d.roster_id is not distinct from a.roster_id
$$;
create function boss_private.soccer_roster_side(p_actor uuid,g public.games,p_team uuid) returns boolean language sql volatile security definer set search_path='' as $$
 select boss_private.basketball_roster_side(p_actor,g,p_team)
$$;
DO $$declare r record;begin for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'soccer_%' loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',r.signature);end loop;end$$;
