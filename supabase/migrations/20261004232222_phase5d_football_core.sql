-- Football extends the one canonical Game Center identity/receipt/sequence.
alter table public.game_operations drop constraint game_operations_finite_operation;
alter table public.game_operations add constraint game_operations_finite_operation check(operation in(
 'game.create','game.roster.snapshot','game.operator.assign','game.operator.end','game.start','game.transition','game.score.set','game.score.reverse','game.finalize','game.reopen','game.publish','game.calendar.sync',
 'basketball.configure','basketball.period.start','basketball.period.end','basketball.clock.start','basketball.clock.stop','basketball.clock.set','basketball.lineup.set','basketball.substitute','basketball.event.add','basketball.event.correct','basketball.event.reverse',
 'soccer.configure','soccer.segment.start','soccer.segment.end','soccer.clock.start','soccer.clock.stop','soccer.clock.set','soccer.added_time.set','soccer.lineup.set','soccer.keeper.set','soccer.substitute','soccer.event.add','soccer.event.correct','soccer.event.reverse',
 'football.configure','football.period.start','football.period.end','football.clock.start','football.clock.stop','football.clock.set','football.state.set','football.lineup.set','football.substitute','football.play.add','football.play.correct','football.play.reverse'));
create table public.game_football_states(
 game_id uuid primary key,organization_id uuid not null,
 quarter_seconds integer not null check(quarter_seconds between 60 and 3600),
 overtime_format text not null check(overtime_format in('none','timed','possession')),
 overtime_seconds integer not null check(overtime_seconds between 60 and 1800),max_overtime_periods integer not null check(max_overtime_periods between 0 and 8),
 play_clock_seconds integer check(play_clock_seconds between 5 and 60),lineup_size integer not null check(lineup_size between 1 and 11),enforce_lineup boolean not null,kneel_counts_as_rush boolean not null,
 period_number integer not null default 0 check(period_number between 0 and 12),period_status text not null default 'pending' check(period_status in('pending','active','ended')),
 clock_remaining_ms bigint not null default 0 check(clock_remaining_ms between 0 and 3600000),clock_running boolean not null default false,clock_anchor timestamptz,
 roster_revision bigint not null check(roster_revision>0),engine_version text not null default 'football-v1' check(engine_version='football-v1'),
 field_state jsonb not null default '{"possession_side":null,"ball_spot":30,"down":1,"distance":10,"line_to_gain":40,"goal_to_go":false,"primary_direction":"increasing","drive_number":0,"drive_open":false,"phase":"scrimmage","scoring_side":null}',
 foreign key(organization_id,game_id) references public.games(organization_id,id),
 check((period_number=0)=(period_status='pending')),check(not clock_running or(period_status='active' and clock_anchor is not null)),
 check(clock_remaining_ms<=(case when period_number>4 then overtime_seconds else quarter_seconds end)*1000),
 check((overtime_format='none')=(max_overtime_periods=0)),check(period_number<=4+max_overtime_periods),
 check(jsonb_typeof(field_state)='object' and octet_length(field_state::text)<=4096)
);
create index football_state_context_idx on public.game_football_states(organization_id,game_id);
create table public.game_football_events(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,game_id uuid not null,operation_id uuid not null,
 sequence bigint not null check(sequence>0),origin_sequence bigint not null check(origin_sequence>0 and origin_sequence<=sequence),period_number integer not null check(period_number between 0 and 12),clock_ms bigint not null check(clock_ms between 0 and 3600000),
 side text check(side in('primary','opponent')),event_type text not null check(event_type in('rush','pass_complete','pass_incomplete','sack','kneel','spike','interception','fumble','fumble_recovery','turnover_on_downs','kickoff','kickoff_return','punt','punt_return','field_goal','extra_point','two_point','safety','penalty','touchdown','engine_configure','period_start','period_end','clock_start','clock_stop','clock_set','state_set','lineup_set','substitution','reversal')),
 roster_id uuid,payload jsonb not null default '{}',before_field jsonb not null default '{}',after_field jsonb not null default '{}',
 actor_person_id uuid not null references public.people(id),request_id uuid not null,correction_of uuid,reason text,created_at timestamptz not null default clock_timestamp(),
 unique(organization_id,game_id,id),unique(game_id,sequence),unique(operation_id),
 foreign key(organization_id,game_id) references public.games(organization_id,id),
 foreign key(organization_id,game_id,operation_id) references public.game_operations(organization_id,game_id,id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 foreign key(organization_id,game_id,correction_of) references public.game_football_events(organization_id,game_id,id),
 check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=8192),
 check(jsonb_typeof(before_field)='object' and jsonb_typeof(after_field)='object' and octet_length(before_field::text)<=4096 and octet_length(after_field::text)<=4096),
 check(correction_of is null or correction_of<>id),check(event_type<>'reversal' or correction_of is not null),
 check(reason is null or(length(btrim(reason)) between 1 and 500 and reason!~'[[:cntrl:]]'))
);
create unique index football_event_supersession_idx on public.game_football_events(game_id,correction_of) where correction_of is not null;
create index football_event_operation_idx on public.game_football_events(organization_id,game_id,operation_id);
create index football_event_correction_idx on public.game_football_events(organization_id,game_id,correction_of);
create index football_event_roster_idx on public.game_football_events(organization_id,game_id,roster_id);
create index football_event_origin_idx on public.game_football_events(game_id,origin_sequence,sequence);
create index football_event_actor_idx on public.game_football_events(actor_person_id);
create table public.game_football_lineups(
 game_id uuid not null,organization_id uuid not null,side text not null check(side in('primary','opponent')),slot integer not null check(slot between 1 and 11),roster_id uuid not null,
 primary key(game_id,side,slot),unique(game_id,roster_id),foreign key(organization_id,game_id) references public.games(organization_id,id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id)
);
create index football_lineup_roster_idx on public.game_football_lineups(organization_id,game_id,roster_id);
create table public.game_football_finalizations(
 finalization_id uuid primary key,organization_id uuid not null,game_id uuid not null,epoch bigint not null check(epoch>0),engine_version text not null check(engine_version='football-v1'),
 roster_revision bigint not null check(roster_revision>0),event_sequence bigint not null check(event_sequence>0),state jsonb not null,
 unique(organization_id,game_id,finalization_id),unique(game_id,epoch),foreign key(organization_id,game_id,finalization_id) references public.game_finalizations(organization_id,game_id,id),
 check(jsonb_typeof(state)='object' and octet_length(state::text)<=65536)
);
create index football_finalization_context_idx on public.game_football_finalizations(organization_id,game_id,finalization_id);
create table public.game_football_final_stats(
 id uuid primary key default gen_random_uuid(),finalization_id uuid not null,organization_id uuid not null,game_id uuid not null,side text not null check(side in('primary','opponent')),roster_id uuid,stats jsonb not null,
 foreign key(organization_id,game_id,finalization_id) references public.game_football_finalizations(organization_id,game_id,finalization_id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id),check(jsonb_typeof(stats)='object' and octet_length(stats::text)<=8192)
);
create unique index football_final_stats_subject_idx on public.game_football_final_stats(finalization_id,side,coalesce(roster_id,'00000000-0000-0000-0000-000000000000'::uuid));
create index football_final_stats_context_idx on public.game_football_final_stats(organization_id,game_id,finalization_id);
create index football_final_stats_roster_idx on public.game_football_final_stats(organization_id,game_id,roster_id);
DO $$declare t text;begin
 foreach t in array array['game_football_states','game_football_events','game_football_lineups','game_football_finalizations','game_football_final_stats']loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);end loop;
 foreach t in array array['game_football_events','game_football_finalizations','game_football_final_stats']loop
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
end$$;
create trigger football_state_identity before update on public.game_football_states for each row execute function boss_private.preserve_row_identity('game_id','organization_id','quarter_seconds','overtime_format','overtime_seconds','max_overtime_periods','play_clock_seconds','lineup_size','enforce_lineup','kneel_counts_as_rush','roster_revision','engine_version');

create function boss_private.football_clock(s public.game_football_states) returns bigint language sql volatile set search_path='' as $$
 select greatest(0,s.clock_remaining_ms-case when s.clock_running then greatest(0,floor(extract(epoch from(clock_timestamp()-s.clock_anchor))*1000)::bigint)else 0 end)
$$;
create function boss_private.football_state(s public.game_football_states) returns jsonb language sql volatile set search_path='' as $$
 select jsonb_build_object('period_number',s.period_number,'period_status',s.period_status,'clock_ms',boss_private.football_clock(s),'clock_running',s.clock_running,'clock_anchor',s.clock_anchor,'field_state',s.field_state,'engine_version',s.engine_version)
$$;
create function boss_private.football_stat_keys() returns text[] language sql immutable set search_path='' as $$
 select array['points','passing_completions','passing_attempts','passing_yards','passing_touchdowns','interceptions_thrown','sacks_taken','sack_yards_lost','rush_attempts','rushing_yards','rushing_touchdowns','long_rush','receptions','targets','receiving_yards','receiving_touchdowns','long_reception','fumbles','fumbles_lost','solo_tackles','assisted_tackles','tackles','tackles_for_loss','sacks','defensive_interceptions','interception_return_yards','pass_defenses','forced_fumbles','fumble_recoveries','fumble_return_yards','defensive_touchdowns','field_goals_made','field_goals_attempted','long_field_goal','extra_points_made','extra_points_attempted','punts','punt_yards','long_punt','punt_touchbacks','kick_returns','kick_return_yards','kick_return_touchdowns','long_kick_return','punt_returns','punt_return_yards','punt_return_touchdowns','long_punt_return','first_downs','penalties','penalty_yards','turnovers','turnovers_on_downs','net_passing_yards','total_offensive_yards','return_yards','kneels','kneel_yards','conversion_attempts','conversions_made','safeties','touchdowns']::text[]
$$;
create function boss_private.football_stat_projection(s jsonb) returns jsonb language sql immutable set search_path='' as $$
 select coalesce(jsonb_object_agg(k,case when jsonb_typeof(s->k)in('number','null')then s->k else 'null'::jsonb end),'{}')from unnest(boss_private.football_stat_keys())k
$$;
create function boss_private.football_active_events(p_game uuid)returns setof public.game_football_events language sql stable security definer set search_path=''as $$
 select e.* from public.game_football_events e where e.game_id=p_game and e.event_type=any(array['rush','pass_complete','pass_incomplete','sack','kneel','spike','interception','fumble','fumble_recovery','turnover_on_downs','kickoff','kickoff_return','punt','punt_return','field_goal','extra_point','two_point','safety','penalty','touchdown'])
 and not exists(select 1 from public.game_football_events c where c.game_id=e.game_id and c.correction_of=e.id)
$$;
create function boss_private.football_roster_side(p_actor uuid,g public.games,p_team uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select coalesce(p_team in(g.primary_team_id,g.opponent_team_id)and(boss_private.games_role_permission(p_actor,'team.roster.view',g.organization_id,p_team)
 or(boss_private.games_operator_current(p_actor,g)and exists(select 1 from public.game_operator_assignments a where a.game_id=g.id and a.person_id=p_actor and a.team_id=p_team and a.status='active'and a.starts_at<=clock_timestamp()and a.ends_at>clock_timestamp()
 and boss_private.games_role_permission(p_actor,'games.operate',g.organization_id,p_team,a.role_assignment_id)))),false)
$$;

-- One pure normalized transition. Competition-specific special placement is
-- explicitly confirmed, rather than inferred from an NFL/NCAA rulebook.
create function boss_private.football_transition(f jsonb,p_type text,p_side text,p jsonb)returns jsonb language plpgsql immutable set search_path=''as $$
declare n jsonb:=f;spot integer:=coalesce((f->>'ball_spot')::integer,30);dn integer:=coalesce((f->>'down')::integer,1);dist integer:=coalesce((f->>'distance')::integer,10);line integer:=least(100,spot+dist);
 y integer:=coalesce((p->>'yards')::integer,0);ret integer:=coalesce((p->>'return_yards')::integer,0);newspot integer;newside text;other text:=case p_side when 'primary'then'opponent'else'primary'end;
 kind text:=p_type;points integer:=0;score_side text;ended text;first_side text;phase text:=coalesce(f->>'phase','scrimmage');is_fumble boolean:=p_type in('fumble','fumble_recovery')or coalesce((p->>'fumble')::boolean,false);begin
 if p_type='state_set'then
 newside:=p_side;newspot:=(p->>'ball_spot')::integer;dn:=(p->>'down')::integer;dist:=(p->>'distance')::integer;
 n:=n||jsonb_build_object('primary_direction',p->>'primary_direction','phase','scrimmage','scoring_side',null);
 return n||jsonb_build_object('possession_side',newside,'ball_spot',newspot,'down',dn,'distance',dist,'line_to_gain',least(100,newspot+dist),'goal_to_go',newspot+dist>=100,'points',0,'score_side',null,'first_down_side',null,'end_reason','confirmed_state');end if;
 if p_type<>'penalty'and(p_side is distinct from f->>'possession_side')then raise exception'Football possession changed; reload the play'using errcode='PT409';end if;
 if p_type in('extra_point','two_point')then
 if phase<>'try'or p_side is distinct from f->>'scoring_side'then raise exception'No matching touchdown try'using errcode='PT409';end if;
 points:=case when coalesce((p->>'made')::boolean,false)then case p_type when'extra_point'then 1 else 2 end else 0 end;score_side:=p_side;
 return n||jsonb_build_object('phase','kickoff','points',points,'score_side',score_side,'first_down_side',null,'end_reason',null);end if;
 if phase='try'then raise exception'Record the touchdown try before the next play'using errcode='PT409';end if;
 if p_type not in('kickoff','kickoff_return','penalty')and phase<>'scrimmage'then raise exception'Football requires a receiving possession'using errcode='PT409';end if;
 if p_type='fumble'then kind:=coalesce(p->>'base_play_type','none');end if;
 newside:=p_side;newspot:=spot;
 if kind in('rush','pass_complete','sack','kneel')then newspot:=spot+y;
 if newspot<0 or newspot>100 then raise exception'Play yardage leaves the normalized field'using errcode='PT422';end if;
 if newspot=0 then points:=2;score_side:=other;ended:='safety';phase:='kickoff';
 elsif coalesce((p->>'touchdown')::boolean,false)and not is_fumble then
 if newspot<>100 then raise exception'Touchdown yardage must reach the goal line'using errcode='PT422';end if;points:=6;score_side:=p_side;ended:='touchdown';phase:='try';first_side:=p_side;
 elsif newspot=100 and not is_fumble then raise exception'Goal-line outcome requires an explicit touchdown'using errcode='PT422';end if;
 elsif kind in('pass_incomplete','spike')then
 if y<>0 then raise exception'Incomplete passing has no completed yardage'using errcode='PT422';end if;
 end if;
 -- Recovery by the offense is resolved before first-down/fourth-down logic;
 -- mirroring a downs turnover before that recovery would mirror twice.
 if is_fumble and p->>'recovery_side'=p_side then
 newspot:=newspot+ret;
 if newspot=100 and coalesce((p->>'touchdown')::boolean,false)then points:=6;score_side:=p_side;ended:='touchdown';phase:='try';first_side:=p_side;
 elsif newspot not between 1 and 99 or coalesce((p->>'touchdown')::boolean,false)then raise exception'Invalid own-team recovery placement'using errcode='PT422';end if;end if;
 if p_type in('rush','pass_complete','pass_incomplete','sack','kneel','spike','fumble')and ended is null and kind<>'none'and(not is_fumble or p->>'recovery_side'=p_side)then
 if newspot>=line then dn:=1;dist:=least(10,100-newspot);first_side:=p_side;
 elsif dn=4 then ended:='downs';newside:=other;newspot:=100-newspot;dn:=1;dist:=least(10,100-newspot);
 else dn:=dn+1;dist:=line-newspot;end if;end if;
 if p_type='interception'then
 newside:=other;newspot:=100-coalesce((p->>'interception_spot')::integer,spot)+ret;ended:='interception';dn:=1;dist:=least(10,100-newspot);
 if newspot=100 and coalesce((p->>'touchdown')::boolean,false)then points:=6;score_side:=other;phase:='try';
 elsif newspot not between 0 and 99 or coalesce((p->>'touchdown')::boolean,false)then raise exception'Invalid interception return outcome'using errcode='PT422';end if;end if;
 if is_fumble then
 if nullif(p->>'recovery_side','')is null then raise exception'Fumble requires an explicit recovering side'using errcode='PT422';end if;
 if ended='safety'then raise exception'Fumble and safety outcome conflict'using errcode='PT422';end if;
 if p->>'recovery_side'<>p_side then
 if kind in('rush','pass_complete')and newspot>=line then first_side:=p_side;end if;
 newside:=other;newspot:=100-newspot+ret;ended:='fumble';dn:=1;dist:=least(10,100-newspot);
 if newspot=100 and coalesce((p->>'touchdown')::boolean,false)then points:=6;score_side:=other;phase:='try';
 elsif newspot not between 0 and 99 or coalesce((p->>'touchdown')::boolean,false)then raise exception'Invalid fumble return outcome'using errcode='PT422';end if;
 end if;end if;
 if p_type='turnover_on_downs'then
 if dn<>4 then raise exception'Explicit downs turnover requires fourth down'using errcode='PT409';end if;ended:='downs';newside:=other;newspot:=100-spot;dn:=1;dist:=least(10,100-newspot);end if;
 if p_type in('kickoff','kickoff_return','punt','punt_return','field_goal','safety','penalty')then
 if p_type='penalty'and coalesce(p->>'penalty_status','accepted')<>'accepted'then
 return f||jsonb_build_object('points',0,'score_side',null,'first_down_side',null,'end_reason',null);end if;
 if p_type='field_goal'and coalesce((p->>'made')::boolean,false)then points:=3;score_side:=p_side;phase:='kickoff';ended:='field_goal';
 elsif p_type='safety'then points:=2;score_side:=other;phase:='kickoff';ended:='safety';
 else
 if nullif(p->>'result_side','')is null or not p?'result_ball_spot'or not p?'result_down'or not p?'result_distance'then raise exception'Special placement requires confirmed resulting field state'using errcode='PT422';end if;
 newside:=p->>'result_side';newspot:=(p->>'result_ball_spot')::integer;dn:=(p->>'result_down')::integer;dist:=(p->>'result_distance')::integer;phase:='scrimmage';
 if p_type in('kickoff','kickoff_return','punt','punt_return','field_goal')and newside<>other then raise exception'Kick outcome requires the receiving side'using errcode='PT422';end if;
 if p_type in('punt','punt_return')then ended:='punt';elsif p_type='field_goal'then ended:='field_goal_missed';elsif p_type in('kickoff','kickoff_return')then ended:='kickoff';end if;
 if p_type in('kickoff_return','punt_return')and coalesce((p->>'touchdown')::boolean,false)then
 if newspot<>100 then raise exception'Return touchdown must reach the goal line'using errcode='PT422';end if;points:=6;score_side:=other;phase:='try';end if;
 if p_type='penalty'and coalesce((p->>'automatic_first_down')::boolean,false)then first_side:=newside;end if;end if;end if;
 if p_type='touchdown'then points:=6;score_side:=p_side;ended:='touchdown';phase:='try';newspot:=100;first_side:=p_side;end if;
 if newspot not between 0 and 100 or dn not between 1 and 4 or dist not between 0 and 100 or(newspot<100 and dist=0)
 or phase='scrimmage'and(newspot=100 or dist>100-newspot)then raise exception'Invalid resulting football field'using errcode='PT422';end if;
 return n||jsonb_build_object('possession_side',case when phase='try'then score_side else newside end,'ball_spot',newspot,'down',dn,'distance',greatest(1,dist),'line_to_gain',least(100,newspot+greatest(1,dist)),'goal_to_go',newspot+greatest(1,dist)>=100,'phase',phase,'scoring_side',case when phase='try'then score_side else null end,'points',points,'score_side',score_side,'first_down_side',first_side,'end_reason',ended);
end$$;

create function boss_private.football_simulate(p_game uuid,p_candidate jsonb default null,p_skip uuid default null)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare e public.game_football_events;f jsonb:='{"possession_side":null,"ball_spot":30,"down":1,"distance":10,"line_to_gain":40,"goal_to_go":false,"primary_direction":"increasing","drive_number":0,"drive_open":false,"phase":"scrimmage","scoring_side":null}';prior jsonb;n jsonb;plays jsonb:='[]';drives jsonb:='[]';drive jsonb;number integer:=0;isplay boolean;finish text;g public.games;s public.game_football_states;begin
 select *into g from public.games where id=p_game;select *into s from public.game_football_states where game_id=p_game;
 for e in select x.*from(select old.*from public.game_football_events old where old.game_id=p_game and old.id is distinct from p_skip and old.event_type<>'reversal'and not exists(select 1 from public.game_football_events c where c.game_id=old.game_id and c.correction_of=old.id)
 union all select (jsonb_populate_record(null::public.game_football_events,p_candidate)).*where p_candidate is not null and p_candidate->>'event_type'<>'reversal')x order by x.origin_sequence,x.sequence loop
 isplay:=e.event_type=any(array['rush','pass_complete','pass_incomplete','sack','kneel','spike','interception','fumble','fumble_recovery','turnover_on_downs','kickoff','kickoff_return','punt','punt_return','field_goal','extra_point','two_point','safety','penalty','touchdown']);
 if e.event_type='period_end'and(e.period_number=2 or e.period_number>=4)and drive is not null then
 finish:=case when e.period_number=2 then'end_half'when g.status='final'and e.period_number=s.period_number then'end_game'when e.period_number=4 then'end_regulation'else'end_overtime'end;
 drive:=drive||jsonb_build_object('end_period',e.period_number,'end_clock_ms',e.clock_ms,'end_ball_spot',f->'ball_spot','end_reason',finish,'result',finish);drives:=drives||jsonb_build_array(drive);drive:=null;f:=f||jsonb_build_object('drive_open',false);end if;
 if not isplay and e.event_type<>'state_set'then continue;end if;
 prior:=f;n:=boss_private.football_transition(f,e.event_type,e.side,e.payload);
 if e.event_type='state_set'then
 if drive is not null then drive:=drive||jsonb_build_object('end_period',e.period_number,'end_clock_ms',e.clock_ms,'end_ball_spot',f->'ball_spot','end_reason','confirmed_state','result','confirmed_state');drives:=drives||jsonb_build_array(drive);drive:=null;end if;f:=n||jsonb_build_object('drive_open',false);continue;end if;
 if e.event_type not in('extra_point','two_point','kickoff','kickoff_return')and drive is null then
 number:=number+1;drive:=jsonb_build_object('drive_number',number,'side',f->>'possession_side','start_period',e.period_number,'start_clock_ms',e.clock_ms,'start_ball_spot',f->'ball_spot','end_period',null,'end_clock_ms',null,'end_ball_spot',null,'play_count',0,'end_reason',null,'result',null);end if;
 if drive is not null then drive:=drive||jsonb_build_object('play_count',(drive->>'play_count')::integer+case when e.event_type='penalty'and coalesce((e.payload->>'no_play')::boolean,false)then 0 else 1 end,'end_period',e.period_number,'end_clock_ms',e.clock_ms,'end_ball_spot',n->'ball_spot');end if;
 f:=n||jsonb_build_object('drive_number',number,'drive_open',drive is not null and n->>'end_reason'is null);
 plays:=plays||jsonb_build_array(jsonb_build_object('event_id',e.id,'before_field',prior,'after_field',f,'points',n->'points','score_side',n->'score_side','first_down_side',n->'first_down_side','end_reason',n->'end_reason'));
 if n->>'end_reason'is not null and drive is not null then drive:=drive||jsonb_build_object('end_reason',n->>'end_reason','result',case when(n->>'points')::integer>0 then case when n->>'score_side'=drive->>'side'then n->>'end_reason'else'defensive_score'end else n->>'end_reason'end);drives:=drives||jsonb_build_array(drive);drive:=null;end if;
 end loop;
 if drive is not null then drives:=drives||jsonb_build_array(drive);end if;
 return jsonb_build_object('field_state',f-'points'-'score_side'-'first_down_side'-'end_reason','drives',drives,'plays',plays);
end$$;
create function boss_private.football_rebuild(p_game uuid)returns jsonb language sql stable security definer set search_path=''as $$select boss_private.football_simulate(p_game)$$;
create function boss_private.football_drives(p_game uuid)returns jsonb language sql stable security definer set search_path=''as $$
 select coalesce(jsonb_agg(x order by(x->>'drive_number')::integer),'[]')from(select x from jsonb_array_elements(boss_private.football_rebuild(p_game)->'drives')x order by(x->>'drive_number')::integer desc limit 100)bounded
$$;

-- Credit rows are a closed intermediate; no public projection exposes identities.
create function boss_private.football_credit(p_side text,p_roster uuid,p_key text,p_amount bigint,p_team boolean default true)returns table(side text,roster_id uuid,key text,amount bigint)language sql immutable set search_path=''as $$
 select p_side,null::uuid,p_key,p_amount where p_team union all select p_side,p_roster,p_key,p_amount where p_roster is not null
$$;
create function boss_private.football_credits(p_game uuid)returns table(side text,roster_id uuid,key text,amount bigint)language plpgsql stable security definer set search_path=''as $$
declare e public.game_football_events;x jsonb;p jsonb;kind text;opposite text;receiver uuid;defender uuid;tackler uuid;recoverer uuid;returner uuid;fumbler uuid;assists uuid[];a uuid;y bigint;ret bigint;td boolean;made boolean;score_side text;scorer uuid;s public.game_football_states;begin
 select *into s from public.game_football_states where game_id=p_game;
 for x in select value from jsonb_array_elements(boss_private.football_rebuild(p_game)->'plays')loop
 select *into e from public.game_football_events where id=(x->>'event_id')::uuid;p:=e.payload;kind:=case when e.event_type='fumble'then coalesce(p->>'base_play_type','none')else e.event_type end;opposite:=case e.side when'primary'then'opponent'else'primary'end;
 receiver:=(p->>'receiver_roster_id')::uuid;defender:=(p->>'defender_roster_id')::uuid;tackler:=(p->>'tackler_roster_id')::uuid;recoverer:=(p->>'recovery_roster_id')::uuid;returner:=(p->>'returner_roster_id')::uuid;
 select coalesce(array_agg(v::uuid),'{}'::uuid[])into assists from jsonb_array_elements_text(coalesce(p->'assisting_roster_ids','[]'))v;
 y:=coalesce((p->>'yards')::bigint,0);ret:=coalesce((p->>'return_yards')::bigint,0);td:=coalesce((p->>'touchdown')::boolean,false);made:=coalesce((p->>'made')::boolean,false);
 if e.event_type='penalty'then
 if coalesce(p->>'penalty_status','accepted')='accepted'then return query select *from boss_private.football_credit(e.side,e.roster_id,'penalties',1);return query select *from boss_private.football_credit(e.side,e.roster_id,'penalty_yards',coalesce((p->>'penalty_yards')::bigint,0));end if;
 elsif kind in('pass_complete','pass_incomplete','interception','spike')then
 return query select *from boss_private.football_credit(e.side,e.roster_id,'passing_attempts',1);
 if receiver is not null then return query select *from boss_private.football_credit(e.side,receiver,'targets',1);end if;
 if kind='pass_complete'then
 return query select *from boss_private.football_credit(e.side,e.roster_id,'passing_completions',1);return query select *from boss_private.football_credit(e.side,e.roster_id,'passing_yards',y);
 return query select *from boss_private.football_credit(e.side,receiver,'receptions',1);return query select *from boss_private.football_credit(e.side,receiver,'receiving_yards',y);return query select *from boss_private.football_credit(e.side,receiver,'long_reception',y);
 if td and not coalesce((p->>'fumble')::boolean,false)and e.event_type<>'fumble'then return query select *from boss_private.football_credit(e.side,e.roster_id,'passing_touchdowns',1);return query select *from boss_private.football_credit(e.side,receiver,'receiving_touchdowns',1);end if;
 elsif kind='interception'then return query select *from boss_private.football_credit(e.side,e.roster_id,'interceptions_thrown',1);return query select *from boss_private.football_credit(opposite,defender,'defensive_interceptions',1);return query select *from boss_private.football_credit(opposite,defender,'interception_return_yards',ret);if td then return query select *from boss_private.football_credit(opposite,defender,'defensive_touchdowns',1);end if;end if;
 elsif kind in('rush','kneel')then
 if kind='rush'or s.kneel_counts_as_rush then return query select *from boss_private.football_credit(e.side,e.roster_id,'rush_attempts',1);return query select *from boss_private.football_credit(e.side,e.roster_id,'rushing_yards',y);return query select *from boss_private.football_credit(e.side,e.roster_id,'long_rush',y);
 if td and e.event_type<>'fumble'and not coalesce((p->>'fumble')::boolean,false)then return query select *from boss_private.football_credit(e.side,e.roster_id,'rushing_touchdowns',1);end if;
 else return query select *from boss_private.football_credit(e.side,e.roster_id,'kneels',1);return query select *from boss_private.football_credit(e.side,e.roster_id,'kneel_yards',y);end if;
 elsif kind='sack'then return query select *from boss_private.football_credit(e.side,e.roster_id,'sacks_taken',1);return query select *from boss_private.football_credit(e.side,e.roster_id,'sack_yards_lost',-y);return query select *from boss_private.football_credit(opposite,defender,'sacks',1);if tackler is null then tackler:=defender;end if;
 end if;
 if e.event_type in('fumble','fumble_recovery')or coalesce((p->>'fumble')::boolean,false)then
 fumbler:=case when kind='pass_complete'then receiver else e.roster_id end;
 if e.event_type<>'fumble_recovery'then return query select *from boss_private.football_credit(e.side,fumbler,'fumbles',1);if p->>'recovery_side'<>e.side then return query select *from boss_private.football_credit(e.side,fumbler,'fumbles_lost',1);end if;end if;
 return query select *from boss_private.football_credit(p->>'recovery_side',recoverer,'fumble_recoveries',1);return query select *from boss_private.football_credit(p->>'recovery_side',recoverer,'fumble_return_yards',ret);
 if p->>'forced_fumble_roster_id'is not null then return query select *from boss_private.football_credit(opposite,(p->>'forced_fumble_roster_id')::uuid,'forced_fumbles',1);end if;
 if td and p->>'recovery_side'<>e.side then return query select *from boss_private.football_credit(opposite,recoverer,'defensive_touchdowns',1);end if;end if;
 if tackler is not null then
 return query select *from boss_private.football_credit(opposite,null,'tackles',1);
 if cardinality(assists)=0 then return query select *from boss_private.football_credit(opposite,tackler,'solo_tackles',1);return query select *from boss_private.football_credit(opposite,tackler,'tackles',1,false);
 else return query select *from boss_private.football_credit(opposite,tackler,'assisted_tackles',1);return query select *from boss_private.football_credit(opposite,tackler,'tackles',1,false);
 foreach a in array assists loop return query select *from boss_private.football_credit(opposite,a,'assisted_tackles',1,false);return query select *from boss_private.football_credit(opposite,a,'tackles',1,false);end loop;end if;
 if y<0 and kind in('rush','kneel','sack')then return query select *from boss_private.football_credit(opposite,tackler,'tackles_for_loss',1);end if;end if;
 if p->>'pass_defender_roster_id'is not null then return query select *from boss_private.football_credit(opposite,(p->>'pass_defender_roster_id')::uuid,'pass_defenses',1);end if;
 if e.event_type='field_goal'then return query select *from boss_private.football_credit(e.side,e.roster_id,'field_goals_attempted',1);if made then return query select *from boss_private.football_credit(e.side,e.roster_id,'field_goals_made',1);return query select *from boss_private.football_credit(e.side,e.roster_id,'long_field_goal',(p->>'kick_distance')::bigint);end if;
 elsif e.event_type='extra_point'then return query select *from boss_private.football_credit(e.side,e.roster_id,'extra_points_attempted',1);if made then return query select *from boss_private.football_credit(e.side,e.roster_id,'extra_points_made',1);end if;
 elsif e.event_type='two_point'then return query select *from boss_private.football_credit(e.side,e.roster_id,'conversion_attempts',1);if made then return query select *from boss_private.football_credit(e.side,e.roster_id,'conversions_made',1);end if;
 elsif e.event_type in('punt','punt_return')then return query select *from boss_private.football_credit(e.side,e.roster_id,'punts',1);return query select *from boss_private.football_credit(e.side,e.roster_id,'punt_yards',coalesce((p->>'kick_yards')::bigint,0));return query select *from boss_private.football_credit(e.side,e.roster_id,'long_punt',coalesce((p->>'kick_yards')::bigint,0));if coalesce((p->>'touchback')::boolean,false)then return query select *from boss_private.football_credit(e.side,e.roster_id,'punt_touchbacks',1);end if;end if;
 if e.event_type in('kickoff_return','punt_return')then
 if e.event_type='kickoff_return'then return query select *from boss_private.football_credit(opposite,returner,'kick_returns',1);return query select *from boss_private.football_credit(opposite,returner,'kick_return_yards',ret);return query select *from boss_private.football_credit(opposite,returner,'long_kick_return',ret);if td then return query select *from boss_private.football_credit(opposite,returner,'kick_return_touchdowns',1);end if;
 else return query select *from boss_private.football_credit(opposite,returner,'punt_returns',1);return query select *from boss_private.football_credit(opposite,returner,'punt_return_yards',ret);return query select *from boss_private.football_credit(opposite,returner,'long_punt_return',ret);if td then return query select *from boss_private.football_credit(opposite,returner,'punt_return_touchdowns',1);end if;end if;end if;
 if x->>'first_down_side'is not null then return query select *from boss_private.football_credit(x->>'first_down_side',null,'first_downs',1);end if;
 if x->>'end_reason'='downs'then return query select *from boss_private.football_credit(e.side,null,'turnovers_on_downs',1);end if;
 score_side:=x->>'score_side';if coalesce((x->>'points')::bigint,0)>0 then
 scorer:=case when e.event_type in('fumble','fumble_recovery')or coalesce((p->>'fumble')::boolean,false)then recoverer when e.event_type='pass_complete'then receiver when e.event_type='interception'then defender when e.event_type in('kickoff_return','punt_return')then returner when score_side=e.side then e.roster_id else null end;
 return query select *from boss_private.football_credit(score_side,scorer,'points',(x->>'points')::bigint);
 if(x->>'points')::bigint=6 then return query select *from boss_private.football_credit(score_side,scorer,'touchdowns',1);elsif(x->>'points')::bigint=2 and e.event_type<>'two_point'then return query select *from boss_private.football_credit(score_side,null,'safeties',1);end if;end if;
 end loop;
end$$;
create function boss_private.football_totals(p_game uuid)returns table(side text,roster_id uuid,stats jsonb)language sql stable security definer set search_path=''as $$
 with g as(select *from public.games where id=p_game),subjects as(select case when r.team_id=g.primary_team_id then'primary'else'opponent'end side,r.id roster_id from g join public.game_roster_snapshots r on r.game_id=g.id and r.revision=g.roster_revision union all select unnest(array['primary','opponent']),null::uuid),
 credits as materialized(select *from boss_private.football_credits(p_game)),metrics as(select k from unnest(boss_private.football_stat_keys())k),
 values_by_key as(select s.side,s.roster_id,m.k,case when m.k='long_field_goal'then max(c.amount)when m.k=any(array['long_rush','long_reception','long_punt','long_kick_return','long_punt_return'])then coalesce(max(c.amount),0)else coalesce(sum(c.amount),0)end v
 from subjects s cross join metrics m left join credits c on c.side=s.side and c.roster_id is not distinct from s.roster_id and c.key=m.k group by s.side,s.roster_id,m.k),
 boxes as(select side,roster_id,jsonb_object_agg(k,v) stats from values_by_key group by side,roster_id)
 select b.side,b.roster_id,b.stats||jsonb_build_object('net_passing_yards',(b.stats->>'passing_yards')::bigint-(b.stats->>'sack_yards_lost')::bigint,'total_offensive_yards',(b.stats->>'passing_yards')::bigint-(b.stats->>'sack_yards_lost')::bigint+(b.stats->>'rushing_yards')::bigint,'turnovers',(b.stats->>'interceptions_thrown')::bigint+(b.stats->>'fumbles_lost')::bigint,'return_yards',(b.stats->>'kick_return_yards')::bigint+(b.stats->>'punt_return_yards')::bigint+(b.stats->>'interception_return_yards')::bigint+(b.stats->>'fumble_return_yards')::bigint)from boxes b
$$;
DO $$declare r record;begin for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like'football_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role',r.signature);end loop;end$$;
