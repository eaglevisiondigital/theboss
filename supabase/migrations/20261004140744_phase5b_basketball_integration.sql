-- Basketball uses the existing Game Center dispatcher, score and final epochs.
-- Existing historical migration bytes and raw-table access remain unchanged.
alter table public.game_finalizations add constraint game_finalization_context_id unique(organization_id,game_id,id);
create table public.game_basketball_finalizations(
 finalization_id uuid primary key,organization_id uuid not null,game_id uuid not null,epoch bigint not null check(epoch>0),
 engine_version text not null check(engine_version='basketball-v1'),roster_revision bigint not null check(roster_revision>0),
 event_sequence bigint not null check(event_sequence>0),period_number integer not null check(period_number between 2 and 30),state jsonb not null,
 unique(organization_id,game_id,finalization_id),unique(game_id,epoch),
 foreign key(organization_id,game_id,finalization_id) references public.game_finalizations(organization_id,game_id,id),
 check(jsonb_typeof(state)='object' and octet_length(state::text)<=8192)
);
create index basketball_finalization_context_idx on public.game_basketball_finalizations(organization_id,game_id,finalization_id);
create table public.game_basketball_final_stats(
 finalization_id uuid not null,organization_id uuid not null,game_id uuid not null,side text not null check(side in('primary','opponent')),roster_id uuid,
 points bigint not null,offensive_rebounds bigint not null,defensive_rebounds bigint not null,rebounds bigint not null,
 assists bigint not null,steals bigint not null,blocks bigint not null,turnovers bigint not null,personal_fouls bigint not null,
 fgm bigint not null,fga bigint not null,tpm bigint not null,tpa bigint not null,ftm bigint not null,fta bigint not null,
 foreign key(organization_id,game_id,finalization_id) references public.game_basketball_finalizations(organization_id,game_id,finalization_id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 check(least(points,offensive_rebounds,defensive_rebounds,rebounds,assists,steals,blocks,turnovers,personal_fouls,fgm,fga,tpm,tpa,ftm,fta)>=0),
 check(rebounds=offensive_rebounds+defensive_rebounds),check(tpm<=fgm and fgm<=fga and tpm<=tpa and tpa<=fga and ftm<=fta),
 check(points=2*fgm+tpm+ftm)
);
create unique index basketball_final_stats_subject_idx on public.game_basketball_final_stats(finalization_id,side,coalesce(roster_id,'00000000-0000-0000-0000-000000000000'::uuid));
create index basketball_final_stats_context_idx on public.game_basketball_final_stats(organization_id,game_id,finalization_id);
create index basketball_final_stats_roster_idx on public.game_basketball_final_stats(organization_id,game_id,roster_id);
DO $$declare t text;begin
 foreach t in array array['game_basketball_finalizations','game_basketball_final_stats'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
end$$;

create function boss_private.basketball_freeze_clock() returns trigger language plpgsql security definer set search_path='' as $$
begin
 update public.game_basketball_states s set clock_remaining_ms=boss_private.basketball_clock(s),clock_running=false,clock_anchor=null
 where s.game_id=new.id and s.clock_running;
 return new;
end$$;
create trigger basketball_status_clock before update of status on public.games for each row
when(old.status='live' and new.status<>'live') execute function boss_private.basketball_freeze_clock();

create function boss_private.basketball_seal_finalization() returns trigger language plpgsql security definer set search_path='' as $$
declare s public.game_basketball_states;g public.games;p bigint;o bigint;cutoff bigint;begin
 select * into s from public.game_basketball_states where game_id=new.game_id;
 if not found then return new;end if;
 select * into g from public.games where id=new.game_id;
 if g.sport_key<>'basketball' or g.organization_id<>new.organization_id or g.status<>'final' or g.finalization_count<>new.epoch
 or s.roster_revision<>new.roster_revision or s.period_status<>'ended' or s.period_number<s.regulation_periods or s.clock_running
 or not boss_private.games_feature(g.organization_id,'basketball_live_scoring') or not boss_private.games_feature(g.organization_id,'basketball_stats')
 or not boss_private.games_feature(g.organization_id,'game_operations') then
 raise exception 'Basketball is not ready to seal' using errcode='PT409';end if;
 select coalesce(max(t.points) filter(where t.side='primary'),0),coalesce(max(t.points) filter(where t.side='opponent'),0) into p,o
 from boss_private.basketball_totals(g.id)t where t.roster_id is null;
 if new.primary_score<>p or new.opponent_score<>o or g.primary_score<>p or g.opponent_score<>o then
 raise exception 'Basketball score reconciliation failed' using errcode='PT409';end if;
 select coalesce(max(e.sequence),0) into cutoff from public.game_basketball_events e where e.game_id=g.id and e.sequence<new.operation_sequence;
 if cutoff=0 then raise exception 'Basketball event history is required' using errcode='PT409';end if;
 insert into public.game_basketball_finalizations(finalization_id,organization_id,game_id,epoch,engine_version,roster_revision,event_sequence,period_number,state)
 values(new.id,new.organization_id,g.id,new.epoch,s.engine_version,s.roster_revision,cutoff,s.period_number,
 boss_private.basketball_state(s)||jsonb_build_object('operation_sequence',new.operation_sequence,'regulation_periods',s.regulation_periods,
 'period_seconds',s.period_seconds,'overtime_seconds',s.overtime_seconds,'lineup_size',s.lineup_size,'enforce_lineup',s.enforce_lineup,'clock_remaining_ms',s.clock_remaining_ms));
 insert into public.game_basketball_final_stats(finalization_id,organization_id,game_id,side,roster_id,points,offensive_rebounds,defensive_rebounds,rebounds,assists,steals,blocks,turnovers,personal_fouls,fgm,fga,tpm,tpa,ftm,fta)
 select new.id,new.organization_id,g.id,t.side,t.roster_id,t.points,t.offensive_rebounds,t.defensive_rebounds,t.rebounds,t.assists,t.steals,t.blocks,t.turnovers,t.personal_fouls,t.fgm,t.fga,t.tpm,t.tpa,t.ftm,t.fta
 from boss_private.basketball_totals(g.id)t;
 return new;
end$$;
create trigger basketball_finalization_seal after insert on public.game_finalizations for each row execute function boss_private.basketball_seal_finalization();

alter function boss_private.games_command(uuid,text,jsonb,uuid,boolean,uuid) rename to games_command_phase5a;
create function boss_private.games_command(p_actor uuid,p_op text,i jsonb,p_request uuid,p_replay boolean default false,p_resource uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.games;e public.events;s public.game_basketball_states;p bigint;o bigint;begin
 if p_op like 'basketball.%' then return boss_private.basketball_command(p_actor,p_op,i,p_request,p_replay);end if;
 if p_op in('game.score.set','game.score.reverse','game.roster.snapshot','game.finalize','game.reopen','game.start')
 or(p_op='game.transition' and i->>'status'='live') then
 select * into g from public.games where id=(i->>'game_id')::uuid;
 if exists(select 1 from public.game_basketball_states where game_id=g.id) then
 select * into e from public.events where id=g.event_id for update;
 select * into g from public.games where id=g.id for update;
 perform boss_private.games_lock_authority(p_actor,g);
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_operation_allowed(p_actor,p_op,g) then
 raise exception 'Access denied' using errcode='PT403';end if;
 select * into s from public.game_basketball_states where game_id=g.id;
 -- Per-game ownership persists when an organization feature is disabled.
 if p_op in('game.score.set','game.score.reverse','game.roster.snapshot') then
 raise exception 'Basketball owns the configured game score and roster' using errcode='PT409';end if;
 if not boss_private.games_feature(g.organization_id,'basketball_live_scoring') or not boss_private.games_feature(g.organization_id,'basketball_stats')
 or not boss_private.games_feature(g.organization_id,'game_operations') then
 raise exception 'Access denied' using errcode='PT403';end if;
 if p_op='game.finalize' and not p_replay then
 if s.period_status<>'ended' or s.period_number<s.regulation_periods or s.clock_running or s.roster_revision<>g.roster_revision then
 raise exception 'Basketball is not ready to finalize' using errcode='PT409';end if;
 select coalesce(max(t.points) filter(where t.side='primary'),0),coalesce(max(t.points) filter(where t.side='opponent'),0) into p,o
 from boss_private.basketball_totals(g.id)t where t.roster_id is null;
 if g.primary_score<>p or g.opponent_score<>o then raise exception 'Basketball score reconciliation failed' using errcode='PT409';end if;
 end if;end if;end if;
 return boss_private.games_command_phase5a(p_actor,p_op,i,p_request,p_replay,p_resource);
end$$;

-- Extend only the finite boolean configuration contract; keep its current
-- actor locks, monotonic module version and unrelated configuration fields.
create or replace function boss_private.games_configure(p_actor uuid,i jsonb,p_request uuid,p_replay boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare organization uuid;module public.organization_modules;key text;prior jsonb;after_state jsonb;
 flags text[]:=array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management','basketball_live_scoring','basketball_stats','basketball_play_by_play','basketball_lineups'];begin
 perform boss_private.games_validate(i,array['organization_id','expected_version','configuration'],array['organization_id','expected_version','configuration']);
 if jsonb_typeof(i->'configuration')<>'object' or i->'configuration'='{}'::jsonb then raise exception 'Invalid game configuration' using errcode='PT422';end if;
 for key in select jsonb_object_keys(i->'configuration') loop
 if not key=any(flags) or jsonb_typeof(i->'configuration'->key)<>'boolean' then raise exception 'Invalid game configuration' using errcode='PT422';end if;end loop;
 organization:=(i->>'organization_id')::uuid;
 perform 1 from public.role_assignments assignment where assignment.person_id=p_actor and(assignment.organization_id=organization or assignment.scope_type='platform') order by assignment.id for share;
 perform 1 from public.organization_memberships membership where membership.person_id=p_actor and membership.organization_id=organization order by membership.id for share;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_role_permission(p_actor,'organization.manage',organization) then raise exception 'Access denied' using errcode='PT403';end if;
 select membership.* into module from public.organization_modules membership join public.modules catalog on catalog.id=membership.module_id and catalog.key='sports' and catalog.status='active'
 where membership.organization_id=organization and membership.status='active' and membership.starts_at<=clock_timestamp() and(membership.ends_at is null or membership.ends_at>clock_timestamp())
 order by membership.starts_at desc,membership.id desc limit 1 for update of membership;
 perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_role_permission(p_actor,'organization.manage',organization) then raise exception 'Access denied' using errcode='PT403';end if;
 if module.id is null or module.status<>'active' or module.starts_at>clock_timestamp() or(module.ends_at is not null and module.ends_at<=clock_timestamp()) then raise exception 'Access denied' using errcode='PT403';end if;
 if p_replay then return jsonb_build_object('game_id',null,'organization_id',organization,'version',module.version,'message','Saved.');end if;
 if module.version<>(i->>'expected_version')::bigint then raise exception 'Sports configuration changed; reload before saving' using errcode='PT409';end if;
 select jsonb_build_object('version',module.version,'configuration',jsonb_object_agg(flag,case when jsonb_typeof(module.configuration->flag)='boolean' then module.configuration->flag else 'false'::jsonb end)) into prior from unnest(flags) flag;
 update public.organization_modules set configuration=configuration||(i->'configuration') where id=module.id returning * into module;
 select jsonb_build_object('version',module.version,'configuration',jsonb_object_agg(flag,case when jsonb_typeof(module.configuration->flag)='boolean' then module.configuration->flag else 'false'::jsonb end)) into after_state from unnest(flags) flag;
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,before_data,after_data)
 values(organization,p_actor,auth.uid(),'games.configure','organization_module',module.id,'organization',organization,p_request,prior,after_state);
 return jsonb_build_object('game_id',null,'organization_id',organization,'version',module.version,'message','Game Center settings saved.');
end$$;

-- Finite stat fields only. Percentages are derived by the presentation layer.
create function boss_private.basketball_stat_projection(v jsonb) returns jsonb language sql immutable set search_path='' as $$
 select jsonb_object_agg(k,coalesce(v->k,'0'::jsonb)) from unnest(array['points','offensive_rebounds','defensive_rebounds','rebounds','assists','steals','blocks','turnovers','personal_fouls','fgm','fga','tpm','tpa','ftm','fta']) k
$$;
alter function boss_private.games_projection(public.games,uuid,boolean,boolean,uuid,jsonb) rename to games_projection_phase5a;
create function boss_private.games_projection(g public.games,p_actor uuid,p_detail boolean default false,p_family boolean default false,p_child uuid default null,p_configuration jsonb default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare base jsonb;bb jsonb;caps jsonb;s public.game_basketball_states;live boolean;operate boolean;correct boolean;core_correct boolean;stats boolean;playbyplay boolean;contextual boolean;
 visible uuid[]:='{}';entries uuid[]:='{}';allowed uuid[]:='{}';entry_rows jsonb:='[]';lineup_rows jsonb:='[]';player_rows jsonb:='[]';team_rows jsonb:='[]';plays jsonb:='[]';epochs jsonb:='[]';fouls jsonb:='[]';history_rows jsonb;more boolean:=false;totals jsonb;begin
 base:=boss_private.games_projection_phase5a(g,p_actor,p_detail,p_family,p_child,p_configuration);
 select * into s from public.game_basketball_states where game_id=g.id;
 if not found then
 bb:=case when g.sport_key='basketball' and boss_private.games_feature(g.organization_id,'basketball_live_scoring',p_configuration) then
 jsonb_build_object('configured',false,'capabilities',jsonb_build_object('configure',not p_family and boss_private.games_permission(p_actor,'games.manage',g,true,p_configuration)
 and boss_private.games_feature(g.organization_id,'game_operations',p_configuration) and boss_private.games_feature(g.organization_id,'basketball_stats',p_configuration)
 and g.status in('scheduled','pregame','delayed') and g.started_at is null and g.roster_revision>0 and g.primary_score=0 and g.opponent_score=0
 and not exists(select 1 from public.game_operations where game_id=g.id and operation in('game.score.set','game.score.reverse')),'operate',false,'correct',false,'stats',false,'lineups',false)) end;
 return base||jsonb_build_object('engine_locked',false,'basketball',bb);end if;
 live:=boss_private.games_feature(g.organization_id,'basketball_live_scoring',p_configuration);
 operate:=not p_family and live and boss_private.games_feature(g.organization_id,'basketball_stats',p_configuration)
 and(not s.enforce_lineup or boss_private.games_feature(g.organization_id,'basketball_lineups',p_configuration))
 and coalesce((base->'capabilities'->>'operate')::boolean,false);
 core_correct:=not p_family and live and boss_private.games_feature(g.organization_id,'basketball_stats',p_configuration) and coalesce((base->'capabilities'->>'correct')::boolean,false);
 correct:=core_correct and g.status in('live','paused','suspended');
 contextual:=boss_private.games_role_permission(p_actor,'games.view',g.organization_id,g.primary_team_id,null,p_configuration)
 or(g.opponent_team_id is not null and boss_private.games_role_permission(p_actor,'games.view',g.organization_id,g.opponent_team_id,null,p_configuration))
 or boss_private.games_team_related(p_actor,g.organization_id,g.primary_team_id,p_child)
 or(g.opponent_team_id is not null and boss_private.games_team_related(p_actor,g.organization_id,g.opponent_team_id,p_child));
 stats:=live and contextual and boss_private.games_feature(g.organization_id,'basketball_stats',p_configuration);
 playbyplay:=live and contextual and boss_private.games_feature(g.organization_id,'basketball_play_by_play',p_configuration);
 caps:=base->'capabilities';
 caps:=caps||jsonb_build_object('roster_snapshot',false,'operate',operate,
 'start',live and boss_private.games_feature(g.organization_id,'basketball_stats',p_configuration) and coalesce((caps->>'start')::boolean,false),
 'resume',live and boss_private.games_feature(g.organization_id,'basketball_stats',p_configuration) and coalesce((caps->>'resume')::boolean,false),'correct',core_correct,
 'finalize',live and stats and s.period_status='ended' and s.period_number>=s.regulation_periods and not s.clock_running and coalesce((caps->>'finalize')::boolean,false));
 if p_detail then
 if not p_family then
 select coalesce(jsonb_agg(case when h->>'operation' like 'basketball.%' then h||jsonb_build_object('summary',case h->>'operation'
 when 'basketball.configure' then 'Basketball configured' when 'basketball.period.start' then 'Basketball period started'
 when 'basketball.period.end' then 'Basketball period ended' when 'basketball.clock.start' then 'Basketball clock started'
 when 'basketball.clock.stop' then 'Basketball clock stopped' when 'basketball.clock.set' then 'Basketball clock adjusted'
 when 'basketball.lineup.set' then 'Basketball lineup recorded' when 'basketball.substitute' then 'Basketball substitution recorded'
 when 'basketball.event.add' then 'Basketball play recorded' when 'basketball.event.correct' then 'Basketball play corrected'
 when 'basketball.event.reverse' then 'Basketball play reversed' else 'Basketball operation recorded' end) else h end order by(h->>'sequence')::bigint),'[]')
 into history_rows from jsonb_array_elements(base->'history')h;
 base:=jsonb_set(base,'{history}',history_rows);
 end if;
 select coalesce(array_agg((r->>'id')::uuid),'{}'::uuid[]) into visible from jsonb_array_elements(base->'roster')r;
 if operate then
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'side',case when r.team_id=g.primary_team_id then 'primary' else 'opponent' end,
 'display_name',r.display_name,'jersey_number',r.jersey_number,'active',r.active) order by r.team_id,r.display_name,r.id),'[]'),coalesce(array_agg(r.id),'{}'::uuid[])
 into entry_rows,entries from public.game_roster_snapshots r where r.game_id=g.id and r.revision=s.roster_revision and boss_private.basketball_roster_side(p_actor,g,r.team_id);
 end if;
 allowed:=visible||entries;
 if stats then
 select coalesce(jsonb_agg(to_jsonb(t)),'[]') into totals from boss_private.basketball_totals(g.id)t;
 select coalesce(jsonb_agg(boss_private.basketball_stat_projection(t)||jsonb_build_object('roster_id',r.id,'side',t->>'side','display_name',r.display_name,'jersey_number',r.jersey_number) order by r.team_id,r.display_name,r.id),'[]') into player_rows
 from jsonb_array_elements(totals)t join public.game_roster_snapshots r on r.id=(t->>'roster_id')::uuid where r.id=any(allowed);
 select coalesce(jsonb_agg(boss_private.basketball_stat_projection(t)||jsonb_build_object('side',t->>'side') order by t->>'side'),'[]') into team_rows from jsonb_array_elements(totals)t where t->'roster_id'='null'::jsonb;
 select coalesce(jsonb_agg(jsonb_build_object('period_number',n.period_number,'primary',n.primary_count,'opponent',n.opponent_count) order by n.period_number),'[]') into fouls
 from(select e.period_number,count(*) filter(where e.side='primary') primary_count,count(*) filter(where e.side='opponent') opponent_count from boss_private.basketball_active_events(g.id)e where e.event_type='personal_foul' group by e.period_number)n;
 end if;
 if not p_family and live and boss_private.games_feature(g.organization_id,'basketball_lineups',p_configuration) then
 select coalesce(jsonb_agg(jsonb_build_object('side',n.side,'roster_ids',n.roster_ids) order by n.side),'[]') into lineup_rows
 from(select l.side,jsonb_agg(l.roster_id order by l.slot) roster_ids from public.game_basketball_lineups l where l.game_id=g.id and l.roster_id=any(allowed) group by l.side)n;
 end if;
 if playbyplay then
 with active_ids as materialized(select a.id from boss_private.basketball_active_events(g.id)a), selected as materialized(
 select e.*,e.id in(select id from active_ids) active from public.game_basketball_events e where e.game_id=g.id
 and e.event_type in('made_2','made_3','made_ft','missed_2','missed_3','missed_ft','offensive_rebound','defensive_rebound','assist','steal','block','turnover','personal_foul','period_start','period_end','substitution')
 and(core_correct or e.event_type in('period_start','period_end','substitution') or e.id in(select id from active_ids)) order by e.sequence desc limit 501)
 select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'sequence',x.sequence,'period_number',x.period_number,'clock_ms',x.clock_ms,'side',x.side,'event_type',x.event_type,'points',x.points,
 'display_name',case when x.roster_id=any(allowed) then r.display_name end,'jersey_number',case when x.roster_id=any(allowed) then r.jersey_number end,
 'roster_id',case when x.roster_id=any(allowed) then x.roster_id end,'scoring_event_id',case when x.roster_id=any(allowed) then x.scoring_event_id end,
 'active',x.active or x.event_type in('period_start','period_end','substitution')) order by x.sequence) filter(where x.ordinal<=500),'[]'),count(*)>500 into plays,more
 from(select selected.*,row_number() over(order by sequence desc) ordinal from selected)x left join public.game_roster_snapshots r on r.id=x.roster_id;
 end if;
 if not p_family and stats and(coalesce((base->'capabilities'->>'manage')::boolean,false) or operate or core_correct) then
 select coalesce(jsonb_agg(jsonb_build_object('epoch',f.epoch,'event_sequence',f.event_sequence,'roster_revision',f.roster_revision,'engine_version',f.engine_version,
 'current_authoritative',g.status='final' and f.epoch=g.finalization_count,
 'players',coalesce((select jsonb_agg(boss_private.basketball_stat_projection(to_jsonb(t))||jsonb_build_object('roster_id',r.id,'side',t.side,'display_name',r.display_name,'jersey_number',r.jersey_number) order by r.team_id,r.display_name,r.id)
 from public.game_basketball_final_stats t join public.game_roster_snapshots r on r.id=t.roster_id where t.finalization_id=f.finalization_id and r.id=any(allowed)),'[]'::jsonb),
 'teams',coalesce((select jsonb_agg(boss_private.basketball_stat_projection(to_jsonb(t))||jsonb_build_object('side',t.side) order by t.side) from public.game_basketball_final_stats t where t.finalization_id=f.finalization_id and t.roster_id is null),'[]'::jsonb)) order by f.epoch),'[]') into epochs
 from(select * from public.game_basketball_finalizations where game_id=g.id order by epoch desc limit 100)f;
 end if;
 end if;
 bb:=jsonb_build_object('configured',true,'engine_version',s.engine_version,'regulation_periods',s.regulation_periods,'period_seconds',s.period_seconds,'overtime_seconds',s.overtime_seconds,'lineup_size',s.lineup_size,'enforce_lineup',s.enforce_lineup,
 'period_number',s.period_number,'overtime_number',greatest(0,s.period_number-s.regulation_periods),'period_status',s.period_status,'clock_ms',boss_private.basketball_clock(s),'clock_running',s.clock_running,'clock_observed_at',clock_timestamp(),
 'capabilities',jsonb_build_object('configure',false,'operate',operate,'correct',correct,'stats',stats,'lineups',operate and boss_private.games_feature(g.organization_id,'basketball_lineups',p_configuration)),
 'entry_roster',entry_rows,'lineups',lineup_rows,'players',player_rows,'teams',team_rows,'plays',plays,'more_plays',more,'final_epochs',epochs,'period_fouls',fouls);
 return base||jsonb_build_object('engine_locked',true,'capabilities',caps,'basketball',bb);
end$$;

DO $$declare r record;begin for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='boss_private' and(p.proname like 'basketball_%' or p.proname in('games_command','games_command_phase5a','games_projection','games_projection_phase5a','games_configure')) loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',r.signature);end loop;end$$;
