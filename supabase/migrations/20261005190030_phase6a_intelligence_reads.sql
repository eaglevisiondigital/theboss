create function boss_private.stat_classify(p_game uuid,p_class text,p_reason text,p_request uuid)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;g public.games;c public.stat_competition_classifications;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 if p_class is null or p_class<>all(array['official','exhibition','scrimmage','practice','controlled_test','excluded','pending'])or p_request is null or p_reason is null or length(btrim(p_reason))not between 1 and 500 then raise exception 'Invalid competition classification'using errcode='PT422';end if;
 perform 1 from public.events e join public.games gg on gg.event_id=e.id where gg.id=p_game for update of e;
 select *into g from public.games where id=p_game for update;
 if g.id is null then raise exception 'Access denied'using errcode='PT403';end if;
 perform boss_private.games_lock_authority(actor,g);perform boss_private.games_require_live_auth();
 if not boss_private.games_permission(actor,'games.manage',g,true)then raise exception 'Access denied'using errcode='PT403';end if;
 select *into c from public.stat_competition_classifications where id=p_request;
 if c.id is not null then
 if c.game_id<>p_game or c.classification<>p_class or c.reason<>btrim(p_reason)or c.actor_person_id<>actor then raise exception 'Receipt conflict'using errcode='PT409';end if;
 return jsonb_build_object('id',c.id,'version',c.version,'classification',c.classification,'replayed',true);end if;
 if g.status='final'then raise exception 'Reopen and refinalize required for classification correction'using errcode='PT409';end if;
 insert into public.stat_competition_classifications(id,organization_id,game_id,version,applies_epoch,classification,reason,actor_person_id)
 select p_request,g.organization_id,g.id,coalesce(max(version),0)+1,g.finalization_count+1,p_class,btrim(p_reason),actor from public.stat_competition_classifications where game_id=g.id returning *into c;
 return jsonb_build_object('id',c.id,'version',c.version,'classification',c.classification,'replayed',false);
end$$;
create function public.boss_stat_competition_classify(p_game uuid,p_class text,p_reason text,p_request uuid)returns jsonb
language sql volatile security invoker set search_path=''as $$select boss_private.stat_classify(p_game,p_class,p_reason,p_request)$$;

create function boss_private.stat_compose(summaries jsonb)returns jsonb
language plpgsql immutable set search_path=''as $$
declare out_metrics jsonb:='{}';out_rates jsonb:='{}';k text;v jsonb;n numeric;d numeric;s numeric;era_count int;begin
 for k in select distinct key from jsonb_array_elements(summaries)x cross join lateral jsonb_object_keys(x->'metrics')key loop
 select jsonb_build_object('observed_value',case when k like'long_%'then max((x->'metrics'->k->>'observed_value')::numeric)else sum((x->'metrics'->k->>'observed_value')::numeric)end,'complete_value',case when k like'long_%'then max((x->'metrics'->k->>'complete_value')::numeric)else sum((x->'metrics'->k->>'complete_value')::numeric)end,'complete_games',sum((x->'metrics'->k->>'complete_games')::int),'partial_games',sum((x->'metrics'->k->>'partial_games')::int),'legacy_unknown_games',sum((x->'metrics'->k->>'legacy_unknown_games')::int),'untracked_games',sum((x->'metrics'->k->>'untracked_games')::int),'played_complete_value',sum((x->'metrics'->k->>'played_complete_value')::numeric),'per_tracked_game',case when k not like'long_%'then sum((x->'metrics'->k->>'played_complete_value')::numeric)/nullif(sum((x->'metrics'->k->>'played_complete_games')::int),0)end,'played_complete_games',sum((x->'metrics'->k->>'played_complete_games')::int))into v from jsonb_array_elements(summaries)x;
 out_metrics:=out_metrics||jsonb_build_object(k,v);end loop;
 for k in select distinct key from jsonb_array_elements(summaries)x cross join lateral jsonb_object_keys(x->'rates')key where key<>'era_basis_innings'loop
 select sum((x->'rates'->k->>'numerator')::numeric),sum((x->'rates'->k->>'denominator')::numeric),min((x->'rates'->k->>'scale')::numeric),count(distinct x->'rates'->>'era_basis_innings')into n,d,s,era_count from jsonb_array_elements(summaries)x;
 if k='era'and exists(select 1 from jsonb_array_elements(summaries)x where x->'rates'->'era'->>'reason'='mixed_or_unknown_era_convention')then era_count:=0;end if;
 if k='ops'then
 -- OPS components are independently summed only across the same joint cohort.
 select jsonb_build_object('value',sum((x->'rates'->k->'obp'->>'numerator')::numeric)/nullif(sum((x->'rates'->k->'obp'->>'denominator')::numeric),0)+sum((x->'rates'->k->'slg'->>'numerator')::numeric)/nullif(sum((x->'rates'->k->'slg'->>'denominator')::numeric),0))into v from jsonb_array_elements(summaries)x;
 else v:=jsonb_build_object('value',case when d>0 and(k<>'era'or era_count=1)then n*s/d end,'numerator',n,'denominator',d,'scale',s,'reason',case when k='era'and era_count<>1 then'mixed_or_unknown_era_convention'when d is null or d=0 then'no_complete_joint_opportunities'end);end if;
 out_rates:=out_rates||jsonb_build_object(k,v);end loop;
 return jsonb_build_object('participation_partial_games',(select coalesce(sum((x->>'participation_partial_games')::int),0)from jsonb_array_elements(summaries)x),'era_conventions',(select coalesce(jsonb_agg(distinct e),'[]')from jsonb_array_elements(summaries)x cross join lateral jsonb_array_elements(coalesce(x->'era_conventions','[]'))e),'source_game_count',(select coalesce(sum((x->>'source_game_count')::int),0)from jsonb_array_elements(summaries)x),'confirmed_gp',(select coalesce(sum((x->>'confirmed_gp')::int),0)from jsonb_array_elements(summaries)x),'participation_unknown_games',(select coalesce(sum((x->>'participation_unknown_games')::int),0)from jsonb_array_elements(summaries)x),'metrics',out_metrics,'rates',out_rates);
end$$;

-- Origin staff may disclose only explicitly scoped data whose source games
-- remain visible through the existing Game Center resource policy.
create function boss_private.stat_origin_access(p_actor uuid,p_org uuid,p_team uuid,p_sport text,p_season uuid,p_person uuid)returns boolean
language sql volatile security definer set search_path=''as $$
 select p_org is not null and p_team is not null and p_season is not null
 and boss_private.games_role_permission(p_actor,'games.view',p_org,p_team)
 and(p_person is null or boss_private.games_role_permission(p_actor,'team.roster.view',p_org,p_team))
 and boss_private.games_feature(p_org,'game_center')and boss_private.games_module_live(p_org,'calendar')
 and boss_private.games_feature(p_org,p_sport||'_live_scoring')and boss_private.games_feature(p_org,p_sport||'_stats')
 and exists(select 1 from public.seasons where id=p_season and organization_id=p_org)
 and not exists(select 1 from public.stat_game_contributions c join public.stat_game_selections gs on gs.game_id=c.game_id and gs.finalization_id=c.finalization_id join public.games g on g.id=c.game_id where c.organization_id=p_org and c.team_id=p_team and c.sport_key=p_sport and c.season_id=p_season and c.person_id is not distinct from p_person and c.classification='official'and not boss_private.games_can_view(p_actor,g))
$$;

create function boss_private.stat_read(p_kind text,p_query jsonb)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;subject uuid;org uuid;team uuid;season uuid;sport text;g public.games;dirty record;pending boolean:=false;segments jsonb;combined jsonb;payloads jsonb;field text;refresh_n integer:=0;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 if actor is null then raise exception 'Authentication required'using errcode='PT401';end if;
 if p_query is null or jsonb_typeof(p_query)<>'object'or octet_length(p_query::text)>4096 or p_kind is null or p_kind<>all(array['athlete_season','athlete_career','team_season'])then raise exception 'Invalid statistical query'using errcode='PT422';end if;
 if exists(select 1 from jsonb_object_keys(p_query)k where k<>all(array['person_id','sport_key','season_id','team_id','organization_id']))then raise exception 'Invalid statistical query'using errcode='PT422';end if;
 foreach field in array array['person_id','sport_key','season_id','team_id','organization_id']loop
 if p_query?field and(jsonb_typeof(p_query->field)<>'string'or length(p_query->>field)not between 1 and 128)then raise exception 'Invalid statistical query'using errcode='PT422';end if;end loop;
 begin subject:=coalesce((p_query->>'person_id')::uuid,actor);org:=(p_query->>'organization_id')::uuid;team:=(p_query->>'team_id')::uuid;season:=(p_query->>'season_id')::uuid;
 exception when invalid_text_representation then raise exception 'Invalid statistical query'using errcode='PT422';end;
 sport:=p_query->>'sport_key';
 if sport is null or sport<>all(array['basketball','soccer','football','volleyball','baseball','softball'])or(p_kind<>'athlete_career'and season is null)or(p_kind='athlete_career'and season is not null)then raise exception 'Invalid statistical scope'using errcode='PT422';end if;
 if p_kind='team_season'then
 if org is null or team is null or p_query?'person_id'or not boss_private.stat_origin_access(actor,org,team,sport,season,null)then raise exception 'Access denied'using errcode='PT403';end if;
 subject:=null;
 elsif not boss_private.games_person_related(actor,subject)and not(p_kind='athlete_season'and boss_private.stat_origin_access(actor,org,team,sport,season,subject))then raise exception 'Access denied'using errcode='PT403';end if;
 -- Refresh before locking person/guardian authority, preserving game->authority lock order.
 -- This private computation returns no data until current authorization is locked/rechecked.
 for dirty in select gs.game_id from public.stat_game_selections gs join public.games gg on gg.id=gs.game_id
 where gs.generation<>gs.refreshed_generation and gg.sport_key=sport and(season is null or gg.season_id=season)
 and(org is null or gg.organization_id=org)and(team is null or team in(gg.primary_team_id,gg.opponent_team_id))
 and(subject is null or exists(select 1 from public.game_roster_snapshots r where r.game_id=gg.id and r.person_id=subject))order by gg.event_id,gg.id limit 9 loop
 if pending then exit;end if;
 -- Fixed limit: at most eight source games per read.
 if refresh_n>=8 then pending:=true;exit;end if;
 refresh_n:=refresh_n+1;
 if not boss_private.stat_refresh(dirty.game_id)then pending:=true;end if;
 end loop;
 perform 1 from public.people where id in(actor,subject)order by id for share;
 if subject is not null then
 perform 1 from public.guardian_relationships where guardian_person_id=actor and dependent_person_id=subject order by id for share;
 end if;
 if org is not null and team is not null then
 perform 1 from public.role_assignments where person_id=actor and(organization_id=org or scope_type='platform')order by id for share;
 perform 1 from public.organization_memberships where organization_id=org and person_id=actor order by id for share;
 perform 1 from public.team_memberships where organization_id=org and team_id=team and person_id=actor order by id for share;
 end if;
 perform boss_private.games_require_live_auth();
 if actor is distinct from boss_private.current_person_id()or(subject is not null and not boss_private.games_person_related(actor,subject)and not(p_kind='athlete_season'and boss_private.stat_origin_access(actor,org,team,sport,season,subject)))or(subject is null and not boss_private.stat_origin_access(actor,org,team,sport,season,null))then raise exception 'Access denied'using errcode='PT403';end if;
 if pending then return jsonb_build_object('contract','intelligence-v1','is_current',false,'refresh_pending',true,'segments','[]'::jsonb,'summary',null);end if;
 select coalesce(jsonb_agg(jsonb_build_object('organization_id',s.organization_id,'team_id',s.team_id,'season_id',s.season_id,'generation',s.generation,'source_watermark',s.source_watermark,'refreshed_at',s.refreshed_at,'summary',s.summary)order by s.organization_id,s.team_id,s.season_id),'[]'),coalesce(jsonb_agg(s.summary),'[]')into segments,payloads
 from(select *from public.stat_origin_summaries s where ((subject is not null and s.person_id=subject)or(subject is null and s.person_id is null)) and s.sport_key=sport and(season is null or s.season_id=season)and(org is null or s.organization_id=org)and(team is null or s.team_id=team)order by s.organization_id,s.team_id,s.season_id limit 101)s;
 if jsonb_array_length(segments)>100 then return jsonb_build_object('contract','intelligence-v1','is_current',false,'refresh_pending',true,'reason','scope_requires_bounded_report','summary',null,'segments','[]'::jsonb);end if;
 if exists(select 1 from public.stat_origin_summaries s where ((subject is not null and s.person_id=subject)or(subject is null and s.person_id is null)) and s.sport_key=sport and(season is null or s.season_id=season)and(org is null or s.organization_id=org)and(team is null or s.team_id=team)and not s.is_current)then return jsonb_build_object('contract','intelligence-v1','is_current',false,'refresh_pending',true,'summary',null,'segments','[]'::jsonb);end if;
 -- Validate generations again after materialization/authority waits. No stale result is labeled current.
 if exists(select 1 from public.stat_game_selections gs join public.games gg on gg.id=gs.game_id where gs.generation<>gs.refreshed_generation and gg.sport_key=sport and(season is null or gg.season_id=season)and(org is null or gg.organization_id=org)and(team is null or team in(gg.primary_team_id,gg.opponent_team_id))and(subject is null or exists(select 1 from public.game_roster_snapshots r where r.game_id=gg.id and r.person_id=subject)))or exists(select 1 from jsonb_array_elements(segments)x join public.stat_origin_summaries s on s.organization_id=(x->>'organization_id')::uuid and s.team_id=(x->>'team_id')::uuid and s.season_id is not distinct from(x->>'season_id')::uuid and ((subject is not null and s.person_id=subject)or(subject is null and s.person_id is null)) and s.sport_key=sport where s.generation<>(x->>'generation')::bigint)then return jsonb_build_object('contract','intelligence-v1','is_current',false,'refresh_pending',true,'summary',null,'segments','[]'::jsonb);end if;
 combined:=boss_private.stat_compose(payloads);
 return jsonb_build_object('contract','intelligence-v1','kind',p_kind,'person_id',subject,'sport_key',sport,'season_id',season,'is_current',true,'refresh_pending',false,'summary',combined,'segments',segments,'as_of',statement_timestamp(),'unassigned_game_count',(select coalesce(sum((x->'summary'->>'source_game_count')::int),0)from jsonb_array_elements(segments)x where x->>'season_id'is null));
end$$;
create function public.boss_athlete_season_read(p_query jsonb default '{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.stat_read('athlete_season',p_query)$$;
create function public.boss_athlete_career_read(p_query jsonb default '{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.stat_read('athlete_career',p_query)$$;
create function public.boss_team_season_read(p_query jsonb default '{}')returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.stat_read('team_season',p_query)$$;
-- Worker rebuild intentionally private. Public rebuild must pass the same scoped read authority.
create function boss_private.stat_rebuild(p_query jsonb,p_kind text,p_after_game uuid default null)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare result jsonb;g public.games;anchor public.games;processed integer:=0;last_game uuid;remaining boolean;org uuid;sport text;season uuid;team uuid;begin
 perform boss_private.games_require_live_auth();
 begin org:=(p_query->>'organization_id')::uuid;season:=(p_query->>'season_id')::uuid;team:=(p_query->>'team_id')::uuid;
 exception when invalid_text_representation then raise exception 'Invalid statistical query'using errcode='PT422';end;
 sport:=p_query->>'sport_key';
 if org is null or sport is null or sport<>all(array['basketball','soccer','football','volleyball','baseball','softball'])or p_kind is null or p_kind<>all(array['athlete_season','athlete_career','team_season'])then raise exception 'Invalid rebuild scope'using errcode='PT422';end if;
 if not boss_private.games_role_permission(boss_private.current_person_id(),'organization.manage',org,team)then raise exception 'Access denied'using errcode='PT403';end if;
 if p_after_game is not null then
 select *into anchor from public.games where id=p_after_game and organization_id=org and sport_key=sport and(season is null or season_id=season)and(team is null or team in(primary_team_id,opponent_team_id));
 if anchor.id is null then raise exception 'Invalid rebuild cursor'using errcode='PT422';end if;
 end if;
 -- Resume in canonical event/game lock order. One source per transaction bounds
 -- work; explicit rebuild may exceed the eager dashboard reduction threshold.
 for g in select *from public.games where organization_id=org and sport_key=sport and(season is null or season_id=season)and(team is null or team in(primary_team_id,opponent_team_id))and(p_after_game is null or(event_id,id)>(anchor.event_id,anchor.id))order by event_id,id limit 1 loop
 perform 1 from public.events where id=g.event_id for update;
 perform 1 from public.games where id=g.id for update;
 update public.stat_game_selections set generation=generation+1 where game_id=g.id;
 insert into public.stat_refresh_work(game_id,target_generation)select game_id,generation from public.stat_game_selections where game_id=g.id on conflict(game_id)do update set target_generation=excluded.target_generation;
 if not boss_private.stat_refresh(g.id,true)then return jsonb_build_object('contract','intelligence-v1','is_current',false,'refresh_pending',true,'summary',null,'segments','[]'::jsonb,'rebuild_cursor',p_after_game,'rebuild_complete',false);end if;
 processed:=processed+1;last_game:=g.id;
 end loop;
 result:=boss_private.stat_read(p_kind,p_query);
 if not boss_private.games_role_permission(boss_private.current_person_id(),'organization.manage',org,team)then raise exception 'Access denied'using errcode='PT403';end if;
 select exists(select 1 from public.games where organization_id=org and sport_key=sport and(season is null or season_id=season)and(team is null or team in(primary_team_id,opponent_team_id))and(last_game is not null and(event_id,id)>(g.event_id,last_game)))into remaining;
 return result||jsonb_build_object('rebuild_cursor',last_game,'rebuild_complete',not remaining,'rebuild_processed',processed);
end$$;
create function public.boss_stat_rebuild(p_query jsonb,p_kind text,p_after_game uuid default null)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.stat_rebuild(p_query,p_kind,p_after_game)$$;
do $$declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where(n.nspname='boss_private'and p.proname like'stat_%')or(n.nspname='public'and p.proname like'boss_%'and p.proname=any(array['boss_athlete_season_read','boss_athlete_career_read','boss_team_season_read','boss_stat_competition_classify','boss_stat_rebuild']))loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.sig);end loop;end$$;
grant execute on function boss_private.stat_read(text,jsonb),boss_private.stat_classify(uuid,text,text,uuid),boss_private.stat_rebuild(jsonb,text,uuid),public.boss_athlete_season_read(jsonb),public.boss_athlete_career_read(jsonb),public.boss_team_season_read(jsonb),public.boss_stat_competition_classify(uuid,text,text,uuid),public.boss_stat_rebuild(jsonb,text,uuid)to authenticated;
