-- Football extends canonical dispatch, features and audit history. Earlier engines remain unchanged.
-- Four Football flags remain finite/default-off; raw data never gains table grants.
-- One low-frequency boundary event reuses the existing source/delivery engine.
insert into boss_private.notification_types(key,category,source_module,title,body)
values('game.halftime','events','sports','Game halftime','A football game reached halftime. Review Game Center.');
create or replace function boss_private.games_notification_ingest() returns trigger language plpgsql security definer set search_path='' as $$
declare g public.games;typ text;begin
 if new.operation='game.start' then typ:='game.started';
 elsif new.operation='game.finalize' then typ:='game.final';
 elsif new.operation='game.operator.assign' then typ:='game.operator_assigned';
 elsif new.operation='football.period.end' and new.next_state->'football_time'->>'period_number'='2'
 and new.prior_state->'football'->>'period_status'='active' and new.next_state->'football'->>'period_status'='ended' then typ:='game.halftime';
 elsif new.operation in('game.transition','game.calendar.sync') and new.next_state->>'status'='canceled' and new.prior_state->>'status' is distinct from 'canceled' then typ:='game.canceled';
 elsif new.operation in('game.transition','game.calendar.sync') and new.next_state->>'status' in('delayed','postponed','suspended') and new.prior_state->>'status' is distinct from new.next_state->>'status' then typ:='game.delayed';end if;
 if typ is null then return new;end if;
 select * into g from public.games where id=new.game_id;
 perform boss_private.notification_enqueue('sports','game_operation',new.id,new.organization_id,typ,new.sequence::text,jsonb_build_object('team_id',g.primary_team_id,'source_version',new.version));
 return new;
end$$;
create or replace function boss_private.games_configuration(p_org uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with raw as(select boss_private.coordination_configuration(p_org,'sports') c),keys as(select unnest(array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management','basketball_live_scoring','basketball_stats','basketball_play_by_play','basketball_lineups','soccer_live_scoring','soccer_stats','soccer_play_by_play','soccer_lineups','football_live_scoring','football_stats','football_play_by_play','football_lineups']) k)
 select jsonb_object_agg(k,case when jsonb_typeof(c->k)='boolean' then c->k else 'false'::jsonb end) from raw cross join keys
$$;
create or replace function boss_private.games_feature(p_org uuid,p_key text,p_configuration jsonb default null) returns boolean language sql volatile security definer set search_path='' as $$
 select boss_private.games_module_live(p_org,'sports') and p_key=any(array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management','basketball_live_scoring','basketball_stats','basketball_play_by_play','basketball_lineups','soccer_live_scoring','soccer_stats','soccer_play_by_play','soccer_lineups','football_live_scoring','football_stats','football_play_by_play','football_lineups'])
 and coalesce((coalesce(p_configuration,boss_private.games_configuration(p_org))->>'game_center')::boolean,false)
 and coalesce((coalesce(p_configuration,boss_private.games_configuration(p_org))->>p_key)::boolean,false)
$$;

create or replace function boss_private.games_sport_engine_identity() returns trigger language plpgsql security definer set search_path='' as $$
declare sport text;organization uuid;expected_sport text;begin
 select g.sport_key,g.organization_id into sport,organization from public.games g where g.id=new.game_id for update;
 expected_sport:=case TG_TABLE_NAME when 'game_basketball_states' then 'basketball' when 'game_soccer_states' then 'soccer' when 'game_football_states' then 'football' end;
 if expected_sport is null or organization is distinct from new.organization_id or sport is distinct from expected_sport
 or (expected_sport<>'basketball' and exists(select 1 from public.game_basketball_states where game_id=new.game_id))
 or (expected_sport<>'soccer' and exists(select 1 from public.game_soccer_states where game_id=new.game_id))
 or (expected_sport<>'football' and exists(select 1 from public.game_football_states where game_id=new.game_id)) then raise exception 'Game sport engine identity is inconsistent' using errcode='PT409';end if;
 return new;
end$$;
create trigger football_engine_identity before insert on public.game_football_states for each row execute function boss_private.games_sport_engine_identity();

create or replace function boss_private.games_append(p_game uuid,p_actor uuid,p_op text,p_request uuid,p_before jsonb,p_extra jsonb default '{}',p_correction uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare g public.games;b public.game_basketball_states;s public.game_soccer_states;f public.game_football_states;aid uuid;oid uuid:=gen_random_uuid();after_state jsonb;game_time jsonb;sport_state jsonb:='{}';begin
 select * into g from public.games where id=p_game for update;
 select * into b from public.game_basketball_states where game_id=p_game;
 select * into s from public.game_soccer_states where game_id=p_game;
 select * into f from public.game_football_states where game_id=p_game;
 if b.game_id is not null then
 game_time:=jsonb_build_object('period_number',b.period_number,'clock_ms',boss_private.basketball_clock(b));
 sport_state:=jsonb_build_object('basketball',boss_private.basketball_state(b),'basketball_time',game_time);
 elsif s.game_id is not null then
 game_time:=jsonb_build_object('segment_number',s.segment_number,'clock_ms',boss_private.soccer_clock(s),'display_clock_ms',boss_private.soccer_display_clock(s),'playing_ms',s.segment_base_ms+boss_private.soccer_clock(s));
 sport_state:=jsonb_build_object('soccer',boss_private.soccer_state(s),'soccer_time',game_time);
 elsif f.game_id is not null then
 game_time:=jsonb_build_object('period_number',f.period_number,'clock_ms',boss_private.football_clock(f));
 sport_state:=jsonb_build_object('football',boss_private.football_state(f),'football_time',game_time);
 end if;
 after_state:=boss_private.games_core_state(g)||sport_state||p_extra;
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,before_data,after_data)
 values(g.organization_id,p_actor,auth.uid(),p_op,'game',g.id,'organization',g.organization_id,p_request,p_before,after_state) returning id into aid;
 insert into public.game_operations(id,organization_id,game_id,sequence,version,operation,logical_game_time,actor_person_id,request_id,correction_of,prior_state,next_state,audit_event_id)
 values(oid,g.organization_id,g.id,g.last_sequence+1,g.version,p_op,coalesce(p_extra->'football_time',p_extra->'soccer_time',p_extra->'basketball_time',game_time),p_actor,p_request,p_correction,p_before,after_state,aid);
 update public.games set last_sequence=g.last_sequence+1 where id=g.id;
 return oid;
end$$;

create function boss_private.football_freeze_clock() returns trigger language plpgsql security definer set search_path='' as $$
begin
 update public.game_football_states s set clock_remaining_ms=boss_private.football_clock(s),clock_running=false,clock_anchor=null where s.game_id=new.id and s.clock_running;
 return new;
end$$;
create trigger football_status_clock before update of status on public.games for each row when(old.status='live' and new.status<>'live') execute function boss_private.football_freeze_clock();

create function boss_private.football_seal_finalization() returns trigger language plpgsql security definer set search_path='' as $$
declare s public.game_football_states;g public.games;p bigint;o bigint;cutoff bigint;begin
 select * into s from public.game_football_states where game_id=new.game_id;if not found then return new;end if;
 select * into g from public.games where id=new.game_id;
 perform boss_private.games_require_live_auth();
 if g.sport_key<>'football' or g.organization_id<>new.organization_id or g.status<>'final' or g.finalization_count<>new.epoch or s.roster_revision<>new.roster_revision
 or s.period_status<>'ended' or s.period_number<4 or s.clock_running
 or not boss_private.games_feature(g.organization_id,'football_live_scoring') or not boss_private.games_feature(g.organization_id,'football_stats') or not boss_private.games_feature(g.organization_id,'game_operations') then raise exception 'Football is not ready to seal' using errcode='PT409';end if;
 select coalesce(max((t.stats->>'points')::bigint) filter(where t.side='primary'),0),coalesce(max((t.stats->>'points')::bigint) filter(where t.side='opponent'),0) into p,o from boss_private.football_totals(g.id)t where t.roster_id is null;
 if new.primary_score<>p or new.opponent_score<>o or g.primary_score<>p or g.opponent_score<>o then raise exception 'Football score reconciliation failed' using errcode='PT409';end if;
 select coalesce(max(e.sequence),0) into cutoff from public.game_football_events e where e.game_id=g.id and e.sequence<new.operation_sequence;
 if cutoff=0 then raise exception 'Football play history is required' using errcode='PT409';end if;
 perform boss_private.games_require_live_auth();
 if new.actor_person_id is distinct from boss_private.require_admin_actor() or not boss_private.games_permission(new.actor_person_id,'games.finalize',g,true)
 or not boss_private.games_feature(g.organization_id,'football_live_scoring') or not boss_private.games_feature(g.organization_id,'football_stats') then raise exception 'Access denied' using errcode='PT403';end if;
 insert into public.game_football_finalizations(finalization_id,organization_id,game_id,epoch,engine_version,roster_revision,event_sequence,state)
 values(new.id,new.organization_id,g.id,new.epoch,s.engine_version,s.roster_revision,cutoff,
 to_jsonb(s)-array['game_id','organization_id','clock_anchor']||jsonb_build_object('operation_sequence',new.operation_sequence,'game_version',g.version+1,'drives',boss_private.football_drives(g.id)));
 insert into public.game_football_final_stats(finalization_id,organization_id,game_id,side,roster_id,stats)
 select new.id,new.organization_id,g.id,t.side,t.roster_id,boss_private.football_stat_projection(t.stats) from boss_private.football_totals(g.id)t;
 return new;
end$$;
create trigger football_finalization_seal after insert on public.game_finalizations for each row execute function boss_private.football_seal_finalization();

alter function boss_private.games_command(uuid,text,jsonb,uuid,boolean,uuid) rename to games_command_phase5c;
create function boss_private.games_command(p_actor uuid,p_op text,i jsonb,p_request uuid,p_replay boolean default false,p_resource uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.games;e public.events;s public.game_football_states;p bigint;o bigint;begin
 if p_op like 'football.%' then return boss_private.football_command(p_actor,p_op,i,p_request,p_replay);end if;
 if p_op in('game.score.set','game.score.reverse','game.roster.snapshot','game.finalize','game.reopen','game.start') or(p_op='game.transition' and i->>'status'='live') then
 select * into g from public.games where id=(i->>'game_id')::uuid;
 if exists(select 1 from public.game_football_states where game_id=g.id) then
 select * into e from public.events where id=g.event_id for update;select * into g from public.games where id=g.id for update;
 perform boss_private.games_lock_authority(p_actor,g);perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor() or not boss_private.games_operation_allowed(p_actor,p_op,g) then raise exception 'Access denied' using errcode='PT403';end if;
 select * into s from public.game_football_states where game_id=g.id;
 if p_op in('game.score.set','game.score.reverse','game.roster.snapshot') then raise exception 'Football owns the configured game score and roster' using errcode='PT409';end if;
 if not boss_private.games_feature(g.organization_id,'football_live_scoring') or not boss_private.games_feature(g.organization_id,'football_stats') or not boss_private.games_feature(g.organization_id,'game_operations') then raise exception 'Access denied' using errcode='PT403';end if;
 if p_op='game.finalize' and not p_replay then
 if s.period_status<>'ended' or s.period_number<4 or s.clock_running or s.roster_revision<>g.roster_revision then raise exception 'Football is not ready to finalize' using errcode='PT409';end if;
 select coalesce(max((t.stats->>'points')::bigint) filter(where t.side='primary'),0),coalesce(max((t.stats->>'points')::bigint) filter(where t.side='opponent'),0) into p,o from boss_private.football_totals(g.id)t where t.roster_id is null;
 if g.primary_score<>p or g.opponent_score<>o then raise exception 'Football score reconciliation failed' using errcode='PT409';end if;
 end if;end if;end if;
 return boss_private.games_command_phase5c(p_actor,p_op,i,p_request,p_replay,p_resource);
end$$;

-- Every identity reference is projected independently, including secondary
-- defenders/returners. Safe whole-play facts never include audit reasons.
create function boss_private.football_payload_projection(p jsonb,allowed uuid[]) returns jsonb language sql immutable set search_path='' as $$
 select coalesce(jsonb_object_agg(k,case
 when k=any(array['roster_id','receiver_roster_id','defender_roster_id','tackler_roster_id','forced_fumble_roster_id','recovery_roster_id','returner_roster_id','pass_defender_roster_id']) then
 case when (p->>k)::uuid=any(allowed) then p->k else 'null'::jsonb end
 when k='assisting_roster_ids' then coalesce((select jsonb_agg(v) from jsonb_array_elements(p->k)v where (v#>>'{}')::uuid=any(allowed)),'[]'::jsonb)
 else p->k end),'{}') from jsonb_object_keys(p)k where k=any(array[
 'roster_id','receiver_roster_id','defender_roster_id','tackler_roster_id','assisting_roster_ids','forced_fumble_roster_id','recovery_roster_id','returner_roster_id','pass_defender_roster_id',
 'yards','return_yards','kick_yards','kick_distance','interception_spot','touchdown','made','touchback','fumble','recovery_side','base_play_type','penalty_status','penalty_yards','automatic_first_down','loss_of_down','no_play','result_side','result_ball_spot','result_down','result_distance'])
$$;

alter function boss_private.games_projection(public.games,uuid,boolean,boolean,uuid,jsonb) rename to games_projection_phase5c;
create function boss_private.games_projection(g public.games,p_actor uuid,p_detail boolean default false,p_family boolean default false,p_child uuid default null,p_configuration jsonb default null) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare base jsonb;f public.game_football_states;live boolean;operate boolean;correct boolean;core_correct boolean;stats boolean;pbp boolean;contextual boolean;caps jsonb;ff jsonb;
 visible uuid[]:='{}';entries uuid[]:='{}';allowed uuid[]:='{}';entry_rows jsonb:='[]';players jsonb:='[]';teams jsonb:='[]';plays jsonb:='[]';entry_plays jsonb:='[]';lineups jsonb:='[]';epochs jsonb:='[]';drives jsonb:='[]';more boolean:=false;totals jsonb;contexts jsonb:='{}';begin
 base:=boss_private.games_projection_phase5c(g,p_actor,p_detail,p_family,p_child,p_configuration);
 select * into f from public.game_football_states where game_id=g.id;
 if not found then
 ff:=case when g.sport_key='football' and boss_private.games_feature(g.organization_id,'football_live_scoring',p_configuration) then jsonb_build_object('configured',false,'capabilities',jsonb_build_object(
 'configure',not p_family and boss_private.games_permission(p_actor,'games.manage',g,true,p_configuration) and boss_private.games_feature(g.organization_id,'game_operations',p_configuration) and boss_private.games_feature(g.organization_id,'football_stats',p_configuration)
 and g.status in('scheduled','pregame','delayed') and g.started_at is null and g.roster_revision>0 and g.primary_score=0 and g.opponent_score=0 and not exists(select 1 from public.game_operations where game_id=g.id and operation in('game.score.set','game.score.reverse')),
 'operate',false,'correct',false,'stats',false,'lineups',false)) end;
 return base||jsonb_build_object('football',ff);end if;
 live:=boss_private.games_feature(g.organization_id,'football_live_scoring',p_configuration);
 operate:=not p_family and live and boss_private.games_feature(g.organization_id,'football_stats',p_configuration) and(not f.enforce_lineup or boss_private.games_feature(g.organization_id,'football_lineups',p_configuration)) and coalesce((base->'capabilities'->>'operate')::boolean,false);
 core_correct:=not p_family and live and boss_private.games_feature(g.organization_id,'football_stats',p_configuration) and coalesce((base->'capabilities'->>'correct')::boolean,false);correct:=core_correct and g.status in('live','paused','suspended');
 contextual:=boss_private.games_role_permission(p_actor,'games.view',g.organization_id,g.primary_team_id,null,p_configuration)
 or(g.opponent_team_id is not null and boss_private.games_role_permission(p_actor,'games.view',g.organization_id,g.opponent_team_id,null,p_configuration))
 or boss_private.games_team_related(p_actor,g.organization_id,g.primary_team_id,p_child) or(g.opponent_team_id is not null and boss_private.games_team_related(p_actor,g.organization_id,g.opponent_team_id,p_child));
 stats:=live and contextual and boss_private.games_feature(g.organization_id,'football_stats',p_configuration);pbp:=live and contextual and boss_private.games_feature(g.organization_id,'football_play_by_play',p_configuration);
 caps:=base->'capabilities';caps:=caps||jsonb_build_object('roster_snapshot',false,'operate',operate,'start',live and stats and coalesce((caps->>'start')::boolean,false),
 'resume',live and stats and coalesce((caps->>'resume')::boolean,false),'correct',core_correct,'finalize',live and stats and f.period_status='ended' and f.period_number>=4 and not f.clock_running and coalesce((caps->>'finalize')::boolean,false));
 if p_detail then
 select coalesce(array_agg((r->>'id')::uuid),'{}'::uuid[]) into visible from jsonb_array_elements(base->'roster')r;
 if operate then
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'side',case when r.team_id=g.primary_team_id then 'primary' else 'opponent' end,'display_name',r.display_name,'jersey_number',r.jersey_number,'active',r.active) order by r.team_id,r.display_name,r.id),'[]'),coalesce(array_agg(r.id),'{}'::uuid[]) into entry_rows,entries
 from public.game_roster_snapshots r where r.game_id=g.id and r.revision=f.roster_revision and boss_private.football_roster_side(p_actor,g,r.team_id);
 end if;allowed:=visible||entries;
 if stats then
 select coalesce(jsonb_agg(to_jsonb(t)),'[]') into totals from boss_private.football_totals(g.id)t;
 select coalesce(jsonb_agg(jsonb_build_object('roster_id',r.id,'side',t->>'side','display_name',r.display_name,'jersey_number',r.jersey_number,'stats',boss_private.football_stat_projection(t->'stats')) order by r.team_id,r.display_name,r.id),'[]') into players
 from jsonb_array_elements(totals)t join public.game_roster_snapshots r on r.id=(t->>'roster_id')::uuid where r.id=any(allowed);
 select coalesce(jsonb_agg(jsonb_build_object('side',t->>'side','stats',boss_private.football_stat_projection(t->'stats')) order by t->>'side'),'[]') into teams from jsonb_array_elements(totals)t where t->'roster_id'='null'::jsonb;
 end if;
 if not p_family and live and boss_private.games_feature(g.organization_id,'football_lineups',p_configuration) then
 select coalesce(jsonb_agg(jsonb_build_object('side',x.side,'roster_ids',x.ids) order by x.side),'[]') into lineups
 from(select l.side,jsonb_agg(l.roster_id order by l.slot)ids from public.game_football_lineups l where l.game_id=g.id and l.roster_id=any(allowed) group by l.side)x;
 end if;
 if pbp or (not p_family and live and (operate or correct)) then
 select coalesce(jsonb_object_agg(x->>'event_id',x),'{}') into contexts from jsonb_array_elements(boss_private.football_rebuild(g.id)->'plays')x;
 end if;
 if pbp then
 with active_ids as materialized(select a.id from boss_private.football_active_events(g.id)a),selected as materialized(
 select e.*,e.id in(select id from active_ids) active from public.game_football_events e where e.game_id=g.id and e.event_type not in('reversal','engine_configure','clock_set','state_set','lineup_set','substitution')
 and(core_correct or e.id in(select id from active_ids)) order by e.sequence desc limit 501)
 select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'sequence',x.sequence,'origin_sequence',x.origin_sequence,'period_number',x.period_number,'clock_ms',x.clock_ms,'side',x.side,'type',x.event_type,
 'payload',boss_private.football_payload_projection(x.payload,allowed),'before_field',coalesce(contexts->(x.id::text)->'before_field',x.before_field),'after_field',coalesce(contexts->(x.id::text)->'after_field',x.after_field),'active',x.active) order by x.sequence) filter(where x.ordinal<=500),'[]'),count(*)>500 into plays,more
 from(select selected.*,row_number() over(order by sequence desc) ordinal from selected)x;
 end if;
 if not p_family and live and boss_private.games_feature(g.organization_id,'football_stats',p_configuration) and boss_private.games_feature(g.organization_id,'game_operations',p_configuration) and(operate or correct) then
 select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'sequence',x.sequence,'origin_sequence',x.origin_sequence,'period_number',x.period_number,'clock_ms',x.clock_ms,'side',x.side,'type',x.event_type,
 'payload',boss_private.football_payload_projection(x.payload,allowed),'before_field',coalesce(contexts->(x.id::text)->'before_field',x.before_field),'after_field',coalesce(contexts->(x.id::text)->'after_field',x.after_field),'active',true) order by x.sequence),'[]') into entry_plays
 from(select e.* from boss_private.football_active_events(g.id)e where e.event_type not in('engine_configure','period_start','period_end','clock_start','clock_stop','clock_set','state_set','lineup_set','substitution','reversal') order by e.sequence desc limit 500)x;
 end if;
 if pbp then drives:=boss_private.football_drives(g.id);end if;
 if not p_family and stats and(coalesce((base->'capabilities'->>'manage')::boolean,false) or operate or core_correct) then
 select coalesce(jsonb_agg(jsonb_build_object('epoch',s.epoch,'game_version',s.state->'game_version','event_cutoff',s.event_sequence,'roster_revision',s.roster_revision,'engine_version',s.engine_version,'current_authoritative',g.status='final' and s.epoch=g.finalization_count,
 'players',coalesce((select jsonb_agg(jsonb_build_object('roster_id',r.id,'side',t.side,'display_name',r.display_name,'jersey_number',r.jersey_number,'stats',boss_private.football_stat_projection(t.stats)) order by r.team_id,r.display_name,r.id) from public.game_football_final_stats t join public.game_roster_snapshots r on r.id=t.roster_id where t.finalization_id=s.finalization_id and r.id=any(allowed)),'[]'),
 'teams',coalesce((select jsonb_agg(jsonb_build_object('side',t.side,'stats',boss_private.football_stat_projection(t.stats)) order by t.side) from public.game_football_final_stats t where t.finalization_id=s.finalization_id and t.roster_id is null),'[]')) order by s.epoch),'[]') into epochs
 from(select * from public.game_football_finalizations where game_id=g.id order by epoch desc limit 100)s;
 end if;end if;
 ff:=to_jsonb(f)-array['game_id','organization_id','clock_remaining_ms','clock_anchor']||jsonb_build_object('configured',true,'clock_ms',boss_private.football_clock(f),'clock_observed_at',clock_timestamp(),
 'capabilities',jsonb_build_object('configure',false,'operate',operate,'correct',correct,'stats',stats,'lineups',operate and boss_private.games_feature(g.organization_id,'football_lineups',p_configuration)),
 'entry_roster',entry_rows,'lineups',lineups,'players',players,'teams',teams,'plays',plays,'entry_plays',entry_plays,'drives',drives,'more_plays',more,'final_epochs',epochs);
 return base||jsonb_build_object('engine_locked',true,'capabilities',caps,'football',ff);
end$$;

DO $$declare r record;begin for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and(p.proname like 'football_%' or p.proname in('games_sport_engine_identity','games_command','games_command_phase5c','games_projection','games_projection_phase5c','games_configure','games_configuration','games_feature','games_append')) loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',r.signature);end loop;end$$;
create or replace function boss_private.games_configure(p_actor uuid,i jsonb,p_request uuid,p_replay boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare organization uuid;module public.organization_modules;key text;prior jsonb;after_state jsonb;
 flags text[]:=array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management','basketball_live_scoring','basketball_stats','basketball_play_by_play','basketball_lineups','soccer_live_scoring','soccer_stats','soccer_play_by_play','soccer_lineups','football_live_scoring','football_stats','football_play_by_play','football_lineups'];begin
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
