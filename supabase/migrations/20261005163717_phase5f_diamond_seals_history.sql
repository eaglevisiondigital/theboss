-- Diamond seals extend canonical final epochs; old sport/coverage seals unchanged.
create function boss_private.diamond_seal()returns trigger language plpgsql security definer set search_path=''as $$
declare g public.games;s public.game_diamond_states;cutoff bigint;begin
 select *into s from public.game_diamond_states where game_id=new.game_id;if not found then return new;end if;
 select *into g from public.games where id=new.game_id;perform boss_private.games_require_live_auth();
 if new.actor_person_id is distinct from boss_private.require_admin_actor()or not boss_private.games_permission(new.actor_person_id,'games.finalize',g,true)or not boss_private.games_feature(g.organization_id,g.sport_key||'_live_scoring')or not boss_private.games_feature(g.organization_id,'game_operations')then raise exception 'Access denied'using errcode='PT403';end if;
 if g.sport_key is distinct from s.sport_key or g.status<>'final'or g.finalization_count<>new.epoch or s.roster_revision<>new.roster_revision or s.state is distinct from boss_private.diamond_rebuild(g.id)
 or new.primary_score<>(s.state->>'primary_score')::int or new.opponent_score<>(s.state->>'opponent_score')::int then raise exception 'Diamond final reconciliation failed'using errcode='PT409';end if;
 if exists(select 1 from boss_private.diamond_totals(g.id)t where t.roster_id is null and(t.stats->>'runs')::int<>(case t.side when'primary'then new.primary_score else new.opponent_score end))then raise exception 'Diamond batting reconciliation failed'using errcode='PT409';end if;
 select max(sequence)into cutoff from public.game_diamond_events where game_id=g.id and sequence<new.operation_sequence;
 insert into public.game_diamond_finalizations(finalization_id,organization_id,game_id,epoch,sport_key,engine_version,roster_revision,event_sequence,state)
 values(new.id,g.organization_id,g.id,new.epoch,g.sport_key,s.engine_version,s.roster_revision,cutoff,s.state||jsonb_build_object('configuration',s.configuration,'operation_sequence',new.operation_sequence,'game_version',g.version+1));
 insert into public.game_diamond_final_stats(finalization_id,organization_id,game_id,side,roster_id,stats)
 select new.id,g.organization_id,g.id,t.side,t.roster_id,t.stats from boss_private.diamond_totals(g.id)t;
 return new;
end$$;
create trigger diamond_finalization_seal after insert on public.game_finalizations for each row execute function boss_private.diamond_seal();
create or replace function boss_private.tracking_seal()returns trigger language plpgsql security definer set search_path=''as $$
declare s public.game_tracking_snapshots;coverage jsonb;begin
 for s in select distinct on(side)*from public.game_tracking_snapshots where game_id=new.game_id order by side,effective_sequence desc loop
 if s.sport_key='volleyball'then coverage:=boss_private.volleyball_team_coverage(new.game_id,s.side,new.operation_sequence)||jsonb_build_object('player_stat_coverage',boss_private.volleyball_player_coverage(new.game_id,s.side,new.operation_sequence));
 elsif s.sport_key in('baseball','softball')then coverage:=boss_private.diamond_coverage(new.game_id,s.side,new.operation_sequence)||jsonb_build_object('player_stat_coverage',boss_private.diamond_coverage(new.game_id,s.side,new.operation_sequence,true));
 else coverage:=boss_private.tracking_coverage(new.game_id,s.side,new.operation_sequence);end if;
 insert into public.game_finalization_tracking_seals(finalization_id,organization_id,game_id,side,snapshot_id,cutoff,coverage)
 values(new.id,new.organization_id,new.game_id,s.side,s.id,new.operation_sequence,coverage);end loop;return new;
end$$;
-- Roster identifiers are masked recursively before any family/private projection.
create function boss_private.diamond_redact(value jsonb,allowed uuid[])returns jsonb language plpgsql immutable set search_path=''as $$
declare n jsonb;k text;v jsonb;begin
 case jsonb_typeof(value)
 when'object'then n:='{}';for k,v in select *from jsonb_each(value)loop
 if k in('batter','pitcher','roster_id','responsible_pitcher','in_roster_id','out_roster_id')and v<>'null'::jsonb then
 n:=n||jsonb_build_object(k,case when(v#>>'{}')::uuid=any(allowed)then v else'null'::jsonb end);
 elsif k in('order','orders','positions','used','pitchers')then
 -- These mappings contain roster identities as values, not named fields.
 n:=n||jsonb_build_object(k,boss_private.diamond_redact_ids(v,allowed));
 else n:=n||jsonb_build_object(k,boss_private.diamond_redact(v,allowed));end if;end loop;return n;
 when'array'then select coalesce(jsonb_agg(boss_private.diamond_redact(arr.v,allowed)),'[]')into n from jsonb_array_elements(value)arr(v);return n;
 else return value;end case;
end$$;
create function boss_private.diamond_redact_ids(value jsonb,allowed uuid[])returns jsonb language plpgsql immutable set search_path=''as $$
declare n jsonb;k text;v jsonb;begin
 case jsonb_typeof(value)
 when'object'then n:='{}';for k,v in select *from jsonb_each(value)loop n:=n||jsonb_build_object(k,boss_private.diamond_redact_ids(v,allowed));end loop;return n;
 when'array'then select coalesce(jsonb_agg(boss_private.diamond_redact_ids(arr.v,allowed)),'[]')into n from jsonb_array_elements(value)arr(v);return n;
 when'string'then return case when(value#>>'{}')::uuid=any(allowed)then value else'null'::jsonb end;
 else return value;end case;
end$$;
alter function boss_private.games_projection(public.games,uuid,boolean,boolean,uuid,jsonb)rename to games_projection_phase5e;
create function boss_private.games_projection(g public.games,p_actor uuid,p_detail boolean default false,p_family boolean default false,p_child uuid default null,p_configuration jsonb default null)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
<<diamond_projection>>
declare base jsonb;s public.game_diamond_states;live boolean;operate boolean;correct boolean;stats boolean;caps jsonb;value jsonb;
 allowed uuid[]:='{}';visible uuid[]:='{}';entries uuid[]:='{}';entry_rows jsonb:='[]';players jsonb:='[]';teams jsonb:='[]';plays jsonb:='[]';epochs jsonb:='[]';profiles jsonb:='{}';sd text;snap public.game_tracking_snapshots;p public.game_tracking_profiles;cov jsonb;begin
 base:=boss_private.games_projection_phase5e(g,p_actor,p_detail,p_family,p_child,p_configuration);
 select *into s from public.game_diamond_states where game_id=g.id;
 if not found then return base||jsonb_build_object('diamond',case when g.sport_key in('baseball','softball')and boss_private.games_feature(g.organization_id,g.sport_key||'_live_scoring',p_configuration)then jsonb_build_object('configured',false,'sport_key',g.sport_key,'capabilities',jsonb_build_object('configure',not p_family and boss_private.games_permission(p_actor,'games.manage',g,true,p_configuration)and g.status in('scheduled','pregame','delayed')and g.started_at is null and g.roster_revision>0 and g.primary_score=0 and g.opponent_score=0))end);end if;
 live:=boss_private.games_feature(g.organization_id,g.sport_key||'_live_scoring',p_configuration);
 operate:=not p_family and live and coalesce((base->'capabilities'->>'operate')::boolean,false);
 correct:=not p_family and live and coalesce((base->'capabilities'->>'correct')::boolean,false);
 stats:=live and boss_private.games_feature(g.organization_id,g.sport_key||'_stats',p_configuration);
 caps:=base->'capabilities'||jsonb_build_object('roster_snapshot',false,'operate',operate,'start',live and coalesce((base->'capabilities'->>'start')::boolean,false),'resume',live and coalesce((base->'capabilities'->>'resume')::boolean,false),'correct',correct,
 'finalize',live and boss_private.diamond_final_ready(s.configuration,s.state)and coalesce((base->'capabilities'->>'finalize')::boolean,false));
 if p_detail then
 select coalesce(array_agg((r->>'id')::uuid),'{}')into visible from jsonb_array_elements(base->'roster')r;
 if operate or correct then
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'side',case r.team_id when g.primary_team_id then'primary'else'opponent'end,'display_name',r.display_name,'jersey_number',r.jersey_number,'active',r.active)order by r.team_id,r.display_name,r.id),'[]'),coalesce(array_agg(r.id),'{}')into entry_rows,entries
 from public.game_roster_snapshots r where r.game_id=g.id and r.revision=s.roster_revision and boss_private.football_roster_side(p_actor,g,r.team_id);end if;
 allowed:=visible||entries;
 foreach sd in array array['primary','opponent']loop
 snap:=boss_private.tracking_current(g.id,sd);cov:=boss_private.diamond_coverage(g.id,sd,g.last_sequence)||jsonb_build_object('player_stat_coverage',boss_private.diamond_coverage(g.id,sd,g.last_sequence,true));
 select *into p from public.game_tracking_profiles where game_id=g.id and side=sd and scope_type='game';
 profiles:=profiles||jsonb_build_object(sd,jsonb_build_object('snapshot_id',snap.id,'selection',snap.selection,'coverage',cov,'profile_version',case when not p_family then coalesce(p.version,0)end,'can_manage',not p_family and boss_private.tracking_scope_allowed(p_actor,jsonb_populate_record(null::public.game_tracking_profiles,jsonb_build_object('sport_key',g.sport_key,'organization_id',g.organization_id,'scope_type','game','game_id',g.id,'side',sd)))));
 end loop;
 if stats then
 select coalesce(jsonb_agg(jsonb_build_object('roster_id',r.id,'side',t.side,'display_name',r.display_name,'jersey_number',r.jersey_number,'stats',boss_private.tracking_stat_projection(t.stats,profiles->t.side->'coverage',true))order by r.team_id,r.display_name,r.id),'[]')into players
 from boss_private.diamond_totals(g.id)t join public.game_roster_snapshots r on r.id=t.roster_id where r.id=any(allowed);
 select coalesce(jsonb_agg(jsonb_build_object('side',t.side,'stats',boss_private.tracking_stat_projection(t.stats,profiles->t.side->'coverage'))order by t.side),'[]')into teams from boss_private.diamond_totals(g.id)t where t.roster_id is null;end if;
 if live and(boss_private.games_feature(g.organization_id,g.sport_key||'_play_by_play',p_configuration)or operate or correct)then
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'sequence',a.sequence,'origin_sequence',a.origin_sequence,'event_type',a.event_type,'payload',boss_private.diamond_redact(a.payload,allowed),'active',true,'inning',tr.inning,'half',tr.half,'batting_side',tr.batting_side,'outs',tr.outs,'runs',tr.runs)order by a.origin_sequence),'[]')into plays
 from(select *from boss_private.diamond_active_events(g.id)where event_type<>'configure'order by origin_sequence desc limit 500)a join boss_private.diamond_trace(g.id)tr on tr.event_id=a.id;end if;
 if not p_family and stats and(operate or correct or coalesce((base->'capabilities'->>'manage')::boolean,false))then
 select coalesce(jsonb_agg(jsonb_build_object('epoch',f.epoch,'event_cutoff',f.event_sequence,'roster_revision',f.roster_revision,'engine_version',f.engine_version,'current_authoritative',g.status='final'and f.epoch=g.finalization_count,'state',boss_private.diamond_redact(f.state,allowed))order by f.epoch),'[]')into epochs from(select *from public.game_diamond_finalizations where game_id=g.id order by epoch desc limit 100)f;end if;
 end if;
 value:=jsonb_build_object('configured',true,'sport_key',g.sport_key,'engine_version',s.engine_version,'configuration',s.configuration,'state',boss_private.diamond_redact(s.state,allowed),
 'capabilities',jsonb_build_object('configure',false,'operate',operate,'correct',correct and g.status in('live','paused','suspended'),'stats',stats,'lineups',operate and boss_private.games_feature(g.organization_id,g.sport_key||'_lineups',p_configuration)),
 'entry_roster',entry_rows,'players',players,'teams',teams,'plays',plays,'final_epochs',epochs,'tracking',profiles);
 return base||jsonb_build_object('engine_locked',true,'capabilities',caps,'diamond',value);
end$$;

alter function boss_private.athlete_history_rows(uuid,text,uuid,timestamptz,uuid,uuid,integer)rename to athlete_history_rows_phase5e;
create function boss_private.athlete_history_rows(p_person uuid,p_sport text,p_season uuid,p_before_time timestamptz,p_before_finalization uuid,p_before_stat uuid,p_limit integer)
returns table(sealed_at timestamptz,finalization_id uuid,stat_id uuid,payload jsonb)
language sql stable security definer set search_path=''as $$
 select h.*from(
 select *from boss_private.athlete_history_rows_phase5e(p_person,p_sport,p_season,p_before_time,p_before_finalization,p_before_stat,p_limit)
 union all
select cf.created_at sealed_at,cf.id finalization_id,s.id stat_id,
 jsonb_build_object(
 'id',s.id,'sport_key',g.sport_key,'engine_version',f.engine_version,
 'person_id',r.person_id,'participant_id',r.participant_id,
 'organization_id',g.organization_id,'organization_name',o.name,
 'team_id',r.team_id,'team_name',t.name,
 'origin_team_season_id',t.season_id,'origin_team_season_name',ts.name,
 'game_season_id',g.season_id,'game_season_name',gs.name,
 'game_id',g.id,'event_id',g.event_id,'occurrence_key',g.occurrence_key,
 'roster_id',r.id,'roster_revision',r.revision,
 'finalization_id',cf.id,'epoch',cf.epoch,'sealed_at',cf.created_at,
 'event_sequence',f.event_sequence,'operation_sequence',cf.operation_sequence,
 'side',s.side,'current_authoritative',g.status='final' and cf.epoch=g.finalization_count,
 'latest_sealed',cf.epoch=g.finalization_count,'game_status',g.status,
 'stats',(select jsonb_object_agg(k,v->'recorded_value')from jsonb_each(boss_private.tracking_stat_projection(s.stats,se.coverage,true))x(k,v)), 'tracking_coverage',(select jsonb_object_agg(k,v->'coverage')from jsonb_each(boss_private.tracking_stat_projection(s.stats,se.coverage,true))x(k,v))) payload
 from public.game_roster_snapshots r
 join public.game_diamond_final_stats s on s.roster_id=r.id and s.organization_id=r.organization_id and s.game_id=r.game_id
 join public.game_diamond_finalizations f on f.finalization_id=s.finalization_id and f.organization_id=s.organization_id and f.game_id=s.game_id
 join public.game_finalizations cf on cf.id=f.finalization_id and cf.organization_id=f.organization_id and cf.game_id=f.game_id
  and cf.epoch=f.epoch and cf.roster_revision=f.roster_revision
 join public.game_finalization_tracking_seals se on se.finalization_id=cf.id and se.side=s.side and se.game_id=s.game_id and se.organization_id=s.organization_id
 join public.games g on g.id=r.game_id and g.organization_id=r.organization_id and g.sport_key in('baseball','softball')
 join public.organizations o on o.id=g.organization_id
 join public.teams t on t.id=r.team_id and t.organization_id=r.organization_id
 left join public.seasons ts on ts.id=t.season_id and ts.organization_id=t.organization_id
 left join public.seasons gs on gs.id=g.season_id and gs.organization_id=g.organization_id
 where r.person_id=p_person and r.revision=f.roster_revision and f.engine_version='diamond-v1'
 and r.team_id=case s.side when 'primary' then g.primary_team_id else g.opponent_team_id end
 and(p_sport is null or p_sport=g.sport_key) and(p_season is null or t.season_id=p_season)
 and(p_before_time is null or(cf.created_at,cf.id,s.id)<(p_before_time,p_before_finalization,p_before_stat))
 )h order by h.sealed_at desc,h.finalization_id desc,h.stat_id desc limit p_limit
$$;
create or replace function boss_private.athlete_history_read(p_query jsonb default '{}')
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
 caller uuid;actor uuid;subject uuid;subject_ids uuid[];subjects jsonb;records jsonb:='[]';
 sport text;season uuid;before_time timestamptz;before_finalization uuid;before_stat uuid;
 row_count integer;page_limit integer:=20;has_more boolean:=false;next_cursor jsonb:=null;entry record;field text;
begin
 caller:=boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 if actor is null then raise exception 'Authentication required' using errcode='PT401';end if;
 if p_query is null or jsonb_typeof(p_query)<>'object' or octet_length(p_query::text)>4096 then
 raise exception 'Invalid athlete history query' using errcode='PT422';end if;
 if exists(select 1 from jsonb_object_keys(p_query) k where k<>all(array[
 'child_person_id','sport_key','season_id','limit','before_sealed_at','before_finalization_id','before_stat_id'])) then
 raise exception 'Invalid athlete history query' using errcode='PT422';end if;
 -- Strict finite input: explicit JSON null is not an omitted filter.
 foreach field in array array['child_person_id','sport_key','season_id','before_sealed_at','before_finalization_id','before_stat_id'] loop
  if p_query?field and(jsonb_typeof(p_query->field)<>'string' or length(p_query->>field)>128 or length(p_query->>field)=0) then
   raise exception 'Invalid athlete history query' using errcode='PT422';end if;
 end loop;
 if p_query?'limit' and(jsonb_typeof(p_query->'limit')<>'number' or(p_query->>'limit')!~'^[0-9]{1,2}$') then
 raise exception 'Invalid athlete history query' using errcode='PT422';end if;
 begin
  if p_query?'child_person_id' then subject:=(p_query->>'child_person_id')::uuid;end if;
  if p_query?'season_id' then season:=(p_query->>'season_id')::uuid;end if;
  if p_query?'limit' then page_limit:=(p_query->>'limit')::integer;end if;
  if p_query?'before_sealed_at' then before_time:=(p_query->>'before_sealed_at')::timestamptz;end if;
  if p_query?'before_finalization_id' then before_finalization:=(p_query->>'before_finalization_id')::uuid;end if;
  if p_query?'before_stat_id' then before_stat:=(p_query->>'before_stat_id')::uuid;end if;
 exception when invalid_text_representation or datetime_field_overflow or invalid_datetime_format or numeric_value_out_of_range then
  raise exception 'Invalid athlete history query' using errcode='PT422';
 end;
 sport:=p_query->>'sport_key';
 if page_limit not between 1 and 50 or(sport is not null and sport<>all(array['basketball','soccer','football','volleyball','baseball','softball']))
 or((p_query?'before_sealed_at')::integer+(p_query?'before_finalization_id')::integer+(p_query?'before_stat_id')::integer) not in(0,3)
 or(before_time is not null and not isfinite(before_time)) then
 raise exception 'Invalid athlete history query' using errcode='PT422';end if;
 if subject is null then
  select p.id into subject from(
   select actor id union select gr.dependent_person_id from public.guardian_relationships gr
   where gr.guardian_person_id=actor and gr.authority_status='active' and gr.verified_at<=clock_timestamp()
   and gr.starts_at<=clock_timestamp() and(gr.ends_at is null or gr.ends_at>clock_timestamp())
  ) authorized join public.people p on p.id=authorized.id and p.status='active'
  order by(p.id=actor),p.id limit 1;
 end if;
 if subject is null or not boss_private.games_person_related(actor,subject) then
 raise exception 'Access denied' using errcode='PT403';end if;
 -- Subject choices come from persistent identity/current verified guardians,
 -- independently of Attendance children or originating organization membership.
 -- Include an explicitly selected authorized subject even beyond the first 100.
 select array_agg(candidate.id order by candidate.id) into subject_ids from(
  select p.id from(
   select actor id union select gr.dependent_person_id from public.guardian_relationships gr
   where gr.guardian_person_id=actor and gr.authority_status='active' and gr.verified_at<=clock_timestamp()
   and gr.starts_at<=clock_timestamp() and(gr.ends_at is null or gr.ends_at>clock_timestamp())
  ) authorized join public.people p on p.id=authorized.id and p.status='active'
  order by(p.id=subject) desc,(p.id=actor),p.id limit 100
 ) candidate;
 -- Row locks serialize authority revocation with this read. Natural expirations
 -- and native-session deadlines are checked again after any serialization wait.
 perform 1 from public.people p where p.id=any(subject_ids) or p.id=actor order by p.id for share;
 perform 1 from public.guardian_relationships gr
 where gr.guardian_person_id=actor and gr.dependent_person_id=any(subject_ids)
 order by gr.id for share;
 perform boss_private.games_require_live_auth();
 if actor is distinct from boss_private.current_person_id() or not boss_private.games_person_related(actor,subject) then
 raise exception 'Access denied' using errcode='PT403';end if;

 row_count:=0;
 for entry in select * from boss_private.athlete_history_rows(subject,sport,season,before_time,before_finalization,before_stat,page_limit+1) loop
  row_count:=row_count+1;
  if row_count>page_limit then has_more:=true;exit;end if;
  records:=records||jsonb_build_array(entry.payload);
  next_cursor:=jsonb_build_object('sealed_at',entry.sealed_at,'finalization_id',entry.finalization_id,'stat_id',entry.stat_id);
 end loop;
 select coalesce(jsonb_agg(jsonb_build_object(
 'person_id',p.id,'display_name',coalesce(p.display_name,'Boss athlete'),
 'relationship',case when p.id=actor then 'self' else 'dependent' end)
 order by(p.id=actor),p.id),'[]'::jsonb) into subjects
 from public.people p where p.id=any(subject_ids) and boss_private.games_person_related(actor,p.id);
 perform boss_private.games_require_live_auth();
 if actor is distinct from boss_private.current_person_id() or not boss_private.games_person_related(actor,subject) then
 raise exception 'Access denied' using errcode='PT403';end if;
 return jsonb_build_object('version','athlete-history-v1','subjects',subjects,'subject_person_id',subject,
 'records',records,'has_more',has_more,'next_cursor',case when has_more then next_cursor else null end);
end$$;


do $$declare f record;begin for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and(p.proname like'diamond_%'or p.proname in('games_projection','games_projection_phase5e','tracking_seal','athlete_history_rows','athlete_history_rows_phase5e','athlete_history_read'))loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);end loop;end$$;

grant execute on function boss_private.athlete_history_read(jsonb)to authenticated;

alter function boss_private.games_read(jsonb)rename to games_read_phase5e;
create function boss_private.games_read(q jsonb default'{}')returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare base jsonb;org uuid;actor uuid;p public.game_tracking_profiles;existing public.game_tracking_profiles;choices jsonb:='[]';choice jsonb;label text;begin
 base:=boss_private.games_read_phase5e(q);org:=(base->>'organization_id')::uuid;
 if base->>'view'='family'or org is null then return base||jsonb_build_object('tracking_management','[]'::jsonb);end if;
 actor:=boss_private.require_admin_actor();
 for choice in select context.choice||jsonb_build_object('sport_key',sport.key)from(select jsonb_build_object('scope_type','organization','label','Organization','organization_id',org)choice
 union all select jsonb_build_object('scope_type','organization_unit','label',v->>'label','organization_id',org,'unit_id',v->>'id')from jsonb_array_elements(base->'units')v where v->>'id'=q->>'unit_id'
 union all select jsonb_build_object('scope_type','team','label',v->>'label','organization_id',org,'team_id',v->>'id')from jsonb_array_elements(base->'teams')v where v->>'id'=q->>'team_id'
 union all select jsonb_build_object('scope_type','season','label',v->>'label'||' / current season','organization_id',org,'team_id',t.id,'season_id',t.season_id)from jsonb_array_elements(base->'teams')v join public.teams t on t.id=(v->>'id')::uuid and t.organization_id=org where t.season_id is not null and v->>'id'=q->>'team_id'
)context(choice)cross join unnest(array['volleyball','baseball','softball'])sport(key)
 loop
 p:=jsonb_populate_record(null::public.game_tracking_profiles,choice);
 if not boss_private.tracking_scope_allowed(actor,p)then continue;end if;
 select *into existing from public.game_tracking_profiles x where x.sport_key=p.sport_key and x.scope_type=p.scope_type and x.organization_id=p.organization_id and x.unit_id is not distinct from p.unit_id and x.team_id is not distinct from p.team_id and x.season_id is not distinct from p.season_id;
 choices:=choices||jsonb_build_array(choice||jsonb_build_object('sport_key',p.sport_key,'profile_version',coalesce(existing.version,0),'selection',case when existing.id is null then boss_private.tracking_selection(p.sport_key,'score_only')else(select selection from public.game_tracking_profile_revisions where profile_id=existing.id and version=existing.version)end,'status',coalesce(existing.status,'inactive')));
 end loop;
 return base||jsonb_build_object('tracking_management',choices);
end$$;

revoke all on function boss_private.games_read(jsonb),boss_private.games_read_phase5e(jsonb)from public,anon,authenticated,service_role;
grant execute on function boss_private.games_read(jsonb)to authenticated;
