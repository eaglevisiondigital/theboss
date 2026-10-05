create or replace function boss_private.games_sport_engine_identity()returns trigger language plpgsql security definer set search_path=''as $$
declare sport text;organization uuid;expected text;begin
 select g.sport_key,g.organization_id into sport,organization from public.games g where g.id=new.game_id for update;
 expected:=case TG_TABLE_NAME when'game_basketball_states'then'basketball'when'game_soccer_states'then'soccer'when'game_football_states'then'football'when'game_volleyball_states'then'volleyball'end;
 if expected is null or organization is distinct from new.organization_id or sport is distinct from expected
 or(expected<>'basketball'and exists(select 1 from public.game_basketball_states where game_id=new.game_id))
 or(expected<>'soccer'and exists(select 1 from public.game_soccer_states where game_id=new.game_id))
 or(expected<>'football'and exists(select 1 from public.game_football_states where game_id=new.game_id))
 or(expected<>'volleyball'and exists(select 1 from public.game_volleyball_states where game_id=new.game_id))then raise exception 'Game sport engine identity is inconsistent'using errcode='PT409';end if;return new;
end$$;
create trigger volleyball_engine_identity before insert on public.game_volleyball_states for each row execute function boss_private.games_sport_engine_identity();

alter function boss_private.games_append(uuid,uuid,text,uuid,jsonb,jsonb,uuid)rename to games_append_phase5d;
create function boss_private.games_append(p_game uuid,p_actor uuid,p_op text,p_request uuid,p_before jsonb,p_extra jsonb default'{}',p_correction uuid default null)returns uuid
language plpgsql security definer set search_path=''as $$
declare s public.game_volleyball_states;begin
 select *into s from public.game_volleyball_states where game_id=p_game;
 return boss_private.games_append_phase5d(p_game,p_actor,p_op,p_request,p_before,case when s.game_id is null then'{}'::jsonb else jsonb_build_object('volleyball',s.state,'volleyball_time',jsonb_build_object('set_number',s.state->'set_number','service_sequence',s.state->'service_sequence'))end||p_extra,p_correction);
end$$;

create function boss_private.volleyball_seal()returns trigger language plpgsql security definer set search_path=''as $$
declare g public.games;s public.game_volleyball_states;cutoff bigint;begin
 select *into s from public.game_volleyball_states where game_id=new.game_id;if not found then return new;end if;
 select *into g from public.games where id=new.game_id;
 perform boss_private.games_require_live_auth();
 if new.actor_person_id is distinct from boss_private.require_admin_actor()or not boss_private.games_permission(new.actor_person_id,'games.finalize',g,true)or not boss_private.games_feature(g.organization_id,'volleyball_live_scoring')or not boss_private.games_feature(g.organization_id,'game_operations')then raise exception 'Access denied'using errcode='PT403';end if;
 if g.sport_key<>'volleyball'or g.status<>'final'or g.finalization_count<>new.epoch or s.roster_revision<>new.roster_revision or s.state->>'set_status'<>'match_complete'
 or s.state is distinct from boss_private.volleyball_rebuild(g.id)or new.primary_score<>(s.state->>'primary_sets')::integer or new.opponent_score<>(s.state->>'opponent_sets')::integer then raise exception 'Volleyball final reconciliation failed'using errcode='PT409';end if;
 select max(sequence)into cutoff from public.game_volleyball_events where game_id=g.id and sequence<new.operation_sequence;
 insert into public.game_volleyball_finalizations(finalization_id,organization_id,game_id,epoch,engine_version,roster_revision,event_sequence,state)
 values(new.id,g.organization_id,g.id,new.epoch,s.engine_version,s.roster_revision,cutoff,s.state||jsonb_build_object('configuration',s.configuration,'operation_sequence',new.operation_sequence,'game_version',g.version+1));
 insert into public.game_volleyball_final_stats(finalization_id,organization_id,game_id,side,roster_id,stats)
 select new.id,g.organization_id,g.id,t.side,t.roster_id,t.stats from boss_private.volleyball_totals(g.id)t;
 return new;
end$$;
create trigger volleyball_finalization_seal after insert on public.game_finalizations for each row execute function boss_private.volleyball_seal();

alter function boss_private.games_command(uuid,text,jsonb,uuid,boolean,uuid)rename to games_command_phase5d;
create function boss_private.games_command(p_actor uuid,p_op text,i jsonb,p_request uuid,p_replay boolean default false,p_resource uuid default null)returns jsonb
language plpgsql security definer set search_path=''as $$
declare g public.games;e public.events;s public.game_volleyball_states;begin
 if p_op='tracking.profile.set'then return boss_private.tracking_profile_command(p_actor,i,p_request,p_replay);end if;
 if p_op like'volleyball.%'then return boss_private.volleyball_command(p_actor,p_op,i,p_request,p_replay);end if;
 if p_op in('game.score.set','game.score.reverse','game.roster.snapshot','game.finalize','game.reopen','game.start')or(p_op='game.transition'and i->>'status'='live')then
 select *into g from public.games where id=(i->>'game_id')::uuid;
 if exists(select 1 from public.game_volleyball_states where game_id=g.id)then
 select *into e from public.events where id=g.event_id for update;select *into g from public.games where id=g.id for update;
 perform boss_private.games_lock_authority(p_actor,g);perform boss_private.games_require_live_auth();
 if p_actor is distinct from boss_private.require_admin_actor()or not boss_private.games_operation_allowed(p_actor,p_op,g)then raise exception 'Access denied'using errcode='PT403';end if;
 if p_op in('game.score.set','game.score.reverse','game.roster.snapshot')then raise exception 'Volleyball owns the game score and roster'using errcode='PT409';end if;
 if not boss_private.games_feature(g.organization_id,'volleyball_live_scoring')or not boss_private.games_feature(g.organization_id,'game_operations')then raise exception 'Access denied'using errcode='PT403';end if;
 select *into s from public.game_volleyball_states where game_id=g.id;
 if p_op='game.finalize'and not p_replay and(s.state->>'set_status'<>'match_complete'or s.roster_revision<>g.roster_revision or s.state is distinct from boss_private.volleyball_rebuild(g.id)or g.primary_score<>(s.state->>'primary_sets')::integer or g.opponent_score<>(s.state->>'opponent_sets')::integer)then raise exception 'Volleyball is not ready to finalize'using errcode='PT409';end if;
 end if;end if;
 return boss_private.games_command_phase5d(p_actor,p_op,i,p_request,p_replay,p_resource);
end$$;

create function boss_private.tracking_stat_projection(raw jsonb,coverage jsonb,player boolean default false)returns jsonb
language sql immutable set search_path=''as $$
 select coalesce(jsonb_object_agg(k,jsonb_build_object('recorded_value',case when coverage->>k='not_tracked'or player and(coverage->>'player_attribution'='not_tracked'or k in('points','set_wins'))then null else raw->k end,
 'coverage',case when coverage->>k='not_tracked'then'not_tracked'when player and(coverage->>'player_attribution'='not_tracked'or k in('points','set_wins'))then'not_tracked'when coverage->>k is null or player and coverage->>'player_attribution'='partially_tracked'then'partially_tracked'when player then coalesce(coverage->'player_stat_coverage'->>k,coverage->>k)else coverage->>k end,
 'reason',case when coverage->>k is null then'legacy_unknown'else'declared'end)),'{}')from jsonb_object_keys(raw)k
$$;
create function boss_private.volleyball_payload_projection(p jsonb,allowed uuid[])returns jsonb
language sql immutable set search_path=''as $$
 select coalesce(jsonb_object_agg(k,case
 when k=any(array['roster_id','receiver_roster_id','libero_roster_id','out_roster_id','in_roster_id'])then case when(p->>k)::uuid=any(allowed)then p->k else'null'::jsonb end
 when k=any(array['roster_ids','blocker_roster_ids'])then coalesce((select jsonb_agg(v)from jsonb_array_elements(p->k)v where(v#>>'{}')::uuid=any(allowed)),'[]')else p->k end),'{}')
 from jsonb_object_keys(p)k where k=any(array['outcome','roster_id','receiver_roster_id','kill_event_id','roster_ids','blocker_roster_ids','libero_roster_id','out_roster_id','in_roster_id'])
$$;

alter function boss_private.games_projection(public.games,uuid,boolean,boolean,uuid,jsonb)rename to games_projection_phase5d;
create function boss_private.games_projection(g public.games,p_actor uuid,p_detail boolean default false,p_family boolean default false,p_child uuid default null,p_configuration jsonb default null)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
<<games_projection>>
declare base jsonb;s public.game_volleyball_states;caps jsonb;vv jsonb;live boolean;operate boolean;correct boolean;stats boolean;
 visible uuid[]:='{}';entries uuid[]:='{}';allowed uuid[]:='{}';entry_rows jsonb:='[]';players jsonb:='[]';teams jsonb:='[]';plays jsonb:='[]';epochs jsonb:='[]';lineups jsonb:='{}';profiles jsonb:='{}';side text;snap public.game_tracking_snapshots;p public.game_tracking_profiles;coverage jsonb;begin
 base:=boss_private.games_projection_phase5d(g,p_actor,p_detail,p_family,p_child,p_configuration);
 select *into s from public.game_volleyball_states where game_id=g.id;
 if not found then
 vv:=case when g.sport_key='volleyball'and boss_private.games_feature(g.organization_id,'volleyball_live_scoring',p_configuration)then jsonb_build_object('configured',false,'capabilities',jsonb_build_object('configure',not p_family and boss_private.games_permission(p_actor,'games.manage',g,true,p_configuration)and g.status in('scheduled','pregame','delayed')and g.started_at is null and g.roster_revision>0 and g.primary_score=0 and g.opponent_score=0,'operate',false,'correct',false,'stats',false,'lineups',false))end;
 return base||jsonb_build_object('volleyball',vv,'tracking',case when g.sport_key in('basketball','soccer','football')then jsonb_build_object('legacy',true,'coverage_reason','legacy_unknown')else null end);end if;
 live:=boss_private.games_feature(g.organization_id,'volleyball_live_scoring',p_configuration);
 operate:=not p_family and live and coalesce((base->'capabilities'->>'operate')::boolean,false)and(not(s.configuration->>'enforce_lineup')::boolean or boss_private.games_feature(g.organization_id,'volleyball_lineups',p_configuration));
 correct:=not p_family and live and coalesce((base->'capabilities'->>'correct')::boolean,false);
 stats:=live and boss_private.games_feature(g.organization_id,'volleyball_stats',p_configuration);
 caps:=base->'capabilities'||jsonb_build_object('roster_snapshot',false,'operate',operate,'start',live and coalesce((base->'capabilities'->>'start')::boolean,false),'resume',live and coalesce((base->'capabilities'->>'resume')::boolean,false),'correct',correct,'finalize',live and s.state->>'set_status'='match_complete'and coalesce((base->'capabilities'->>'finalize')::boolean,false));
 if p_detail then
 select coalesce(array_agg((r->>'id')::uuid),'{}')into visible from jsonb_array_elements(base->'roster')r;
 if operate or correct then
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'side',case r.team_id when g.primary_team_id then'primary'else'opponent'end,'display_name',r.display_name,'jersey_number',r.jersey_number,'active',r.active)order by r.team_id,r.display_name,r.id),'[]'),coalesce(array_agg(r.id),'{}')into entry_rows,entries
 from public.game_roster_snapshots r where r.game_id=g.id and r.revision=s.roster_revision and boss_private.football_roster_side(p_actor,g,r.team_id);end if;
 allowed:=visible||entries;
 foreach side in array array['primary','opponent']loop
 snap:=boss_private.tracking_current(g.id,side);coverage:=boss_private.volleyball_team_coverage(g.id,side,g.last_sequence)||jsonb_build_object('player_stat_coverage',boss_private.volleyball_player_coverage(g.id,side,g.last_sequence));
 select *into p from public.game_tracking_profiles where game_id=g.id and game_tracking_profiles.side=games_projection.side and scope_type='game';
 profiles:=profiles||jsonb_build_object(side,jsonb_build_object('snapshot_id',snap.id,'selection',snap.selection,'coverage',coverage,'profile_id',case when not p_family then p.id end,'profile_version',case when not p_family then coalesce(p.version,0)end,'can_manage',not p_family and boss_private.tracking_scope_allowed(p_actor,jsonb_populate_record(null::public.game_tracking_profiles,jsonb_build_object('sport_key',g.sport_key,'organization_id',g.organization_id,'scope_type','game','game_id',g.id,'side',side)))));
 select lineups||jsonb_build_object(side,coalesce(jsonb_agg(v),'[]'))into lineups from jsonb_array_elements(s.state->'lineups'->side)v where(v#>>'{}')::uuid=any(allowed);
 end loop;
 if stats then
 select coalesce(jsonb_agg(jsonb_build_object('roster_id',r.id,'side',t.side,'display_name',r.display_name,'jersey_number',r.jersey_number,'stats',boss_private.tracking_stat_projection(t.stats,profiles->t.side->'coverage',true))order by r.team_id,r.display_name,r.id),'[]')into players
 from boss_private.volleyball_totals(g.id)t join public.game_roster_snapshots r on r.id=t.roster_id where r.id=any(allowed);
 select coalesce(jsonb_agg(jsonb_build_object('side',t.side,'stats',boss_private.tracking_stat_projection(t.stats,profiles->t.side->'coverage'))order by t.side),'[]')into teams from boss_private.volleyball_totals(g.id)t where t.roster_id is null;end if;
 if live and(boss_private.games_feature(g.organization_id,'volleyball_play_by_play',p_configuration)or operate or correct)then
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'sequence',a.sequence,'origin_sequence',a.origin_sequence,'event_type',a.event_type,'side',a.side,'payload',boss_private.volleyball_payload_projection(a.payload,allowed),'active',true,'set_number',tr.set_number,'primary_points',tr.primary_points,'opponent_points',tr.opponent_points)order by a.origin_sequence),'[]')into plays from(select *from boss_private.volleyball_active_events(g.id)where event_type<>'configure'order by origin_sequence desc limit 500)a join boss_private.volleyball_trace(g.id)tr on tr.event_id=a.id;end if;
 if not p_family and stats and(operate or correct or coalesce((base->'capabilities'->>'manage')::boolean,false))then
 select coalesce(jsonb_agg(jsonb_build_object('epoch',f.epoch,'event_cutoff',f.event_sequence,'roster_revision',f.roster_revision,'engine_version',f.engine_version,'current_authoritative',g.status='final'and f.epoch=g.finalization_count,'state',f.state-array['lineups','liberos','used'],'teams',coalesce((select jsonb_agg(jsonb_build_object('side',t.side,'stats',boss_private.tracking_stat_projection(t.stats,se.coverage)))from public.game_volleyball_final_stats t join public.game_finalization_tracking_seals se on se.finalization_id=t.finalization_id and se.side=t.side where t.finalization_id=f.finalization_id and t.roster_id is null),'[]'))order by f.epoch),'[]')into epochs from(select *from public.game_volleyball_finalizations where game_id=g.id order by epoch desc limit 100)f;end if;
 end if;
 vv:=jsonb_build_object('configured',true,'engine_version',s.engine_version,'configuration',s.configuration,'state',s.state-array['lineups','liberos','used'],'lineups',lineups,'server_roster_id',case when(s.configuration->>'strict_rotation')::boolean and(s.state->'lineups'->(s.state->>'serving_side')->>0)::uuid=any(allowed)then s.state->'lineups'->(s.state->>'serving_side')->>0 else null end,'capabilities',jsonb_build_object('configure',false,'operate',operate,'correct',correct and g.status in('live','paused','suspended'),'stats',stats,'lineups',operate and boss_private.games_feature(g.organization_id,'volleyball_lineups',p_configuration)),'entry_roster',entry_rows,'players',players,'teams',teams,'plays',plays,'final_epochs',epochs,'tracking',profiles);
 return base||jsonb_build_object('engine_locked',true,'capabilities',caps,'volleyball',vv);
end$$;
create or replace function boss_private.games_configuration(p_org uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with raw as(select boss_private.coordination_configuration(p_org,'sports') c),keys as(select unnest(array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management','basketball_live_scoring','basketball_stats','basketball_play_by_play','basketball_lineups','soccer_live_scoring','soccer_stats','soccer_play_by_play','soccer_lineups','football_live_scoring','football_stats','football_play_by_play','football_lineups','volleyball_live_scoring','volleyball_stats','volleyball_play_by_play','volleyball_lineups']) k)
 select jsonb_object_agg(k,case when jsonb_typeof(c->k)='boolean' then c->k else 'false'::jsonb end) from raw cross join keys
$$;

create or replace function boss_private.games_feature(p_org uuid,p_key text,p_configuration jsonb default null) returns boolean language sql volatile security definer set search_path='' as $$
 select boss_private.games_module_live(p_org,'sports') and p_key=any(array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management','basketball_live_scoring','basketball_stats','basketball_play_by_play','basketball_lineups','soccer_live_scoring','soccer_stats','soccer_play_by_play','soccer_lineups','football_live_scoring','football_stats','football_play_by_play','football_lineups','volleyball_live_scoring','volleyball_stats','volleyball_play_by_play','volleyball_lineups'])
 and coalesce((coalesce(p_configuration,boss_private.games_configuration(p_org))->>'game_center')::boolean,false)
 and coalesce((coalesce(p_configuration,boss_private.games_configuration(p_org))->>p_key)::boolean,false)
$$;

create or replace function boss_private.games_configure(p_actor uuid,i jsonb,p_request uuid,p_replay boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare organization uuid;module public.organization_modules;key text;prior jsonb;after_state jsonb;
 flags text[]:=array['game_center','game_operations','public_game_center','team_game_management','head_coach_game_management','basketball_live_scoring','basketball_stats','basketball_play_by_play','basketball_lineups','soccer_live_scoring','soccer_stats','soccer_play_by_play','soccer_lineups','football_live_scoring','football_stats','football_play_by_play','football_lineups','volleyball_live_scoring','volleyball_stats','volleyball_play_by_play','volleyball_lineups'];begin
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
do $$declare f record;begin for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and(p.proname like'volleyball_%'or p.proname like'tracking_%'or p.proname in('games_append','games_append_phase5d','games_command','games_command_phase5d','games_projection','games_projection_phase5d','games_configure','games_configuration','games_feature','games_sport_engine_identity'))loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);end loop;end$$;

-- Bounded authorized management choices reuse the existing Game Center context.
alter function boss_private.games_read(jsonb)rename to games_read_phase5d;
create function boss_private.games_read(q jsonb default'{}')returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare base jsonb;org uuid;actor uuid;p public.game_tracking_profiles;existing public.game_tracking_profiles;choices jsonb:='[]';choice jsonb;label text;begin
 base:=boss_private.games_read_phase5d(q);org:=(base->>'organization_id')::uuid;
 if base->>'view'='family'or org is null then return base||jsonb_build_object('tracking_management','[]'::jsonb);end if;
 actor:=boss_private.require_admin_actor();
 for choice in select jsonb_build_object('scope_type','organization','label','Organization','organization_id',org)
 union all select jsonb_build_object('scope_type','organization_unit','label',v->>'label','organization_id',org,'unit_id',v->>'id')from jsonb_array_elements(base->'units')v where v->>'id'=q->>'unit_id'
 union all select jsonb_build_object('scope_type','team','label',v->>'label','organization_id',org,'team_id',v->>'id')from jsonb_array_elements(base->'teams')v where v->>'id'=q->>'team_id'
 union all select jsonb_build_object('scope_type','season','label',v->>'label'||' / current season','organization_id',org,'team_id',t.id,'season_id',t.season_id)from jsonb_array_elements(base->'teams')v join public.teams t on t.id=(v->>'id')::uuid and t.organization_id=org where t.season_id is not null and v->>'id'=q->>'team_id'
 loop
 p:=jsonb_populate_record(null::public.game_tracking_profiles,choice||jsonb_build_object('sport_key','volleyball'));
 if not boss_private.tracking_scope_allowed(actor,p)then continue;end if;
 select *into existing from public.game_tracking_profiles x where x.sport_key=p.sport_key and x.scope_type=p.scope_type and x.organization_id=p.organization_id and x.unit_id is not distinct from p.unit_id and x.team_id is not distinct from p.team_id and x.season_id is not distinct from p.season_id;
 choices:=choices||jsonb_build_array(choice||jsonb_build_object('sport_key',p.sport_key,'profile_version',coalesce(existing.version,0),'selection',case when existing.id is null then boss_private.tracking_selection('volleyball','score_only')else(select selection from public.game_tracking_profile_revisions where profile_id=existing.id and version=existing.version)end,'status',coalesce(existing.status,'inactive')));
 end loop;
 return base||jsonb_build_object('tracking_management',choices);
end$$;
revoke all on function boss_private.games_read(jsonb),boss_private.games_read_phase5d(jsonb)from public,anon,authenticated,service_role;

grant execute on function boss_private.games_read(jsonb)to authenticated;
